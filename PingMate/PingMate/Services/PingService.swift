import Foundation
import Combine

@MainActor
class PingService: ObservableObject {
    @Published var currentStatus: ConnectionStatus = .unknown
    @Published var previousStatus: ConnectionStatus?
    @Published var lastPingTime: Double?
    @Published var history: [PingResult] = []
    @Published var isMonitoring: Bool = false
    @Published var consecutiveFailures: Int = 0
    @Published var totalFailures: UInt64 = 0
    @Published var totalPings: UInt64 = 0

    private(set) var settings: Settings
    private var currentPingTask: Task<Void, Never>?

    /// Backstop so a short interval with a long retention cannot grow the array without bound.
    /// 3 h at a 500 ms interval is ~21 600 entries, well under this.
    private let maxHistoryHardCap = 50_000

    /// Average over the same window the history covers, so the number and the list agree.
    var average: Double? {
        let times = history.compactMap(\.pingTime)
        guard !times.isEmpty else { return nil }
        return times.reduce(0, +) / Double(times.count)
    }

    var formattedAverage: String {
        guard let avg = average else { return "—" }
        return String(format: "%.0f ms", avg)
    }

    var retentionDescription: String {
        settings.historyRetention.localizedName
    }

    init(settings: Settings = Settings()) {
        self.settings = settings
    }

    func updateSettings(_ newSettings: Settings) {
        let old = settings
        settings = newSettings

        // Only the ping loop's own parameters justify tearing the loop down. Colors,
        // thresholds and retention apply in place — restarting for those drops an
        // in-flight ping and blinks the menubar icon through its stopped state.
        let needsRestart = old.pingTarget != newSettings.pingTarget
            || old.pingInterval != newSettings.pingInterval

        if needsRestart && isMonitoring {
            stop()
            start()
        }

        if old.historyRetention != newSettings.historyRetention {
            trimHistory()
        }
    }

    func start() {
        guard !isMonitoring else { return }
        isMonitoring = true
        Log.ping.info("Starting ping monitoring to \(self.settings.pingTarget)")
        runLoop()
    }

    func stop() {
        isMonitoring = false
        currentPingTask?.cancel()
        currentPingTask = nil
        Log.ping.info("Stopped ping monitoring")
    }

    func clearHistory() {
        history.removeAll()
        consecutiveFailures = 0
        totalFailures = 0
        totalPings = 0
    }

    /// One long-lived task instead of a chain of one-shot `Timer`s.
    ///
    /// The loop sleeps until an explicit `ContinuousClock` deadline that advances by exactly
    /// one interval per cycle, so the ping duration never leaks into the rate. Measured at
    /// 1.000 s between ticks for a 1000 ms interval.
    private func runLoop() {
        currentPingTask = Task {
            var deadline = ContinuousClock.now

            while isMonitoring && !Task.isCancelled {
                let intervalMilliseconds = settings.pingInterval

                let result = await Self.executePing(
                    target: settings.pingTarget,
                    timeoutMilliseconds: min(intervalMilliseconds, 3000),
                    goodThreshold: settings.goodPingThreshold,
                    unstableThreshold: settings.unstablePingThreshold
                )

                // Check if cancelled or stopped while ping was executing
                guard !Task.isCancelled && isMonitoring else { return }

                handlePingResult(result)

                // Advance along the grid rather than measuring from "now", so a slow ping
                // does not stretch every later tick.
                let interval = Duration.milliseconds(intervalMilliseconds)
                deadline += interval
                let now = ContinuousClock.now
                if deadline < now {
                    // Fell behind (long timeout, or the machine slept). Re-anchor instead
                    // of firing a burst of catch-up pings.
                    deadline = now + interval
                }

                do {
                    try await Task.sleep(until: deadline, tolerance: .zero, clock: .continuous)
                } catch {
                    return  // cancelled
                }
            }
        }
    }

    private nonisolated static func executePing(
        target: String,
        timeoutMilliseconds: Int,
        goodThreshold: Int,
        unstableThreshold: Int
    ) async -> PingResult {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/sbin/ping")
                // -W waits for a reply in milliseconds, so sub-second intervals are honoured;
                // -t is a whole-second backstop in case the reply wait is not enough.
                let backstopSeconds = max(1, Int((Double(timeoutMilliseconds) / 1000.0).rounded(.up)))
                process.arguments = [
                    "-c", "1",
                    "-W", String(timeoutMilliseconds),
                    "-t", String(backstopSeconds),
                    target
                ]

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe

                do {
                    try process.run()
                    // Drain before waiting: a full pipe buffer would deadlock the child.
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()

                    let output = String(data: data, encoding: .utf8) ?? ""

                    if let time = parsePingTime(from: output) {
                        let status = determineStatus(
                            pingTime: time,
                            goodThreshold: goodThreshold,
                            unstableThreshold: unstableThreshold
                        )
                        continuation.resume(returning: PingResult(
                            timestamp: Date(),
                            target: target,
                            pingTime: time,
                            status: status
                        ))
                        return
                    }
                } catch {
                    Log.ping.error("Ping process error: \(error.localizedDescription)")
                }

                // Failure case
                continuation.resume(returning: PingResult(
                    timestamp: Date(),
                    target: target,
                    pingTime: nil,
                    status: .problem
                ))
            }
        }
    }

    private nonisolated static func parsePingTime(from output: String) -> Double? {
        // Pattern: "time=45.123 ms" or "time=45 ms"
        let pattern = #"time[=<](\d+\.?\d*)\s*ms"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: output, options: [], range: NSRange(output.startIndex..., in: output)),
              let timeRange = Range(match.range(at: 1), in: output) else {
            return nil
        }
        return Double(output[timeRange])
    }

    private nonisolated static func determineStatus(
        pingTime: Double,
        goodThreshold: Int,
        unstableThreshold: Int
    ) -> ConnectionStatus {
        if pingTime <= Double(goodThreshold) {
            return .good
        } else if pingTime <= Double(unstableThreshold) {
            return .unstable
        }
        return .problem
    }

    private func handlePingResult(_ result: PingResult) {
        // Update previous status before changing current
        if currentStatus != .unknown {
            previousStatus = currentStatus
        }

        // Update current status
        currentStatus = result.status
        lastPingTime = result.pingTime

        // Session counters — deliberately unbounded. They describe the whole session,
        // not the retained window, and cost 8 bytes each.
        totalPings += 1

        if result.isSuccess {
            consecutiveFailures = 0
        } else {
            consecutiveFailures += 1
            totalFailures += 1
        }

        history.insert(result, at: 0)
        trimHistory()

        Log.ping.debug("Ping result: \(result.formattedTime) - \(result.status.rawValue)")
    }

    /// Drops entries older than the configured retention. History is newest-first,
    /// so the expired ones are always at the tail.
    private func trimHistory() {
        let cutoff = Date().addingTimeInterval(-settings.historyRetention.duration)
        if let firstExpired = history.firstIndex(where: { $0.timestamp < cutoff }) {
            history.removeSubrange(firstExpired...)
        }
        if history.count > maxHistoryHardCap {
            history.removeSubrange(maxHistoryHardCap...)
        }
    }
}

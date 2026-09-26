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

    private(set) var settings: Settings
    private var currentPingTask: Task<Void, Never>?

    // Running totals over `history`, kept in step with every insert and trim so the
    // statistics cost nothing per tick even with the full 100 000 entries retained.
    private var replySum: Double = 0
    private var replyCount = 0

    // MARK: - Statistics
    //
    // Every number covers exactly what `history` holds — the retention period — so the tiles,
    // the list and the export always agree. Session-long counters used to sit beside a
    // window-scoped average with nothing telling them apart.

    /// Pings in the retained period.
    var pingCount: Int { history.count }

    /// Pings in the retained period that got no reply at all. A slow reply is not a timeout.
    var timeoutCount: Int { history.count - replyCount }

    var average: Double? {
        replyCount > 0 ? replySum / Double(replyCount) : nil
    }

    var formattedAverage: String {
        guard let avg = average else { return "—" }
        return String(format: "%.0f ms", avg)
    }

    /// How much time the retained pings actually span — less than the retention period after
    /// launch, a wake, or a clear.
    var coveredDuration: TimeInterval {
        guard let newest = history.first, let oldest = history.last else { return 0 }
        return newest.timestamp.timeIntervalSince(oldest.timestamp) + Double(settings.pingInterval) / 1000
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
        replySum = 0
        replyCount = 0
        consecutiveFailures = 0
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

        if result.isSuccess {
            consecutiveFailures = 0
        } else {
            consecutiveFailures += 1
        }

        // One mutation of the published array per tick, so observers redraw once.
        var updated = history
        updated.insert(result, at: 0)
        count(result, sign: 1)
        trim(&updated)
        history = updated

        Log.ping.debug("Ping result: \(result.formattedTime) - \(result.status.rawValue)")
    }

    private func trimHistory() {
        var updated = history
        trim(&updated)
        history = updated
    }

    /// Drops entries older than the retention period, then anything over the entry ceiling.
    /// History is newest-first, so both come off the tail — walking from the tail touches only
    /// what is removed, where a search from the head read the whole array every tick.
    private func trim(_ entries: inout [PingResult]) {
        let cutoff = Date().addingTimeInterval(-settings.historyRetention.duration)
        while let oldest = entries.last,
              oldest.timestamp < cutoff || entries.count > HistoryRetention.maxEntries {
            count(entries.removeLast(), sign: -1)
        }
    }

    private func count(_ result: PingResult, sign: Double) {
        guard let time = result.pingTime else { return }
        replySum += sign * time
        replyCount += Int(sign)
        // Adding and subtracting for days leaves rounding residue; an empty window is exactly 0.
        if replyCount == 0 { replySum = 0 }
    }
}

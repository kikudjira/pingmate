import SwiftUI

/// Tab in the popover's header.
struct TabButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Tokens.Space.x1) {
                Image(systemName: systemImage)
                    .font(.system(size: 12))
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .medium : .regular))
            }
            .foregroundStyle(isSelected ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
            .padding(.vertical, 6)
            .padding(.horizontal, Tokens.Space.x3)
            .contentShape(.rect)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: Tokens.Radius.small)
                        .fill(.quaternary)
                }
            }
        }
        .buttonStyle(.plain)
        // VoiceOver could not tell which tab was active: the custom highlight carried no trait.
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}

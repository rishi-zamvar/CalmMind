import SwiftUI

/// Warm-styled checkbox with haptic feedback
struct WarmCheckbox: View {
    let isChecked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            DesignTokens.Haptics.complete()
            action()
        }) {
            Circle()
                .strokeBorder(
                    isChecked ? Color.clear : DesignTokens.Colors.textTertiary,
                    lineWidth: 2
                )
                .background(
                    Circle().fill(isChecked ? DesignTokens.Colors.sage : Color.clear)
                )
                .frame(width: 24, height: 24)
                .overlay {
                    if isChecked {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
        }
        .buttonStyle(.plain)
        .animation(DesignTokens.defaultAnimation, value: isChecked)
    }
}

#Preview {
    HStack(spacing: 20) {
        WarmCheckbox(isChecked: false, action: {})
        WarmCheckbox(isChecked: true, action: {})
    }
    .padding()
    .ambientBackground()
}

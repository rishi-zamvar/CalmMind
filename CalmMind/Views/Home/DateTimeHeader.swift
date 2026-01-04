import SwiftUI

/// Centered date/time anchor for Home screen
/// Taps open today's journal entry directly
struct DateTimeHeader: View {
    @AppStorage("dateHeaderHintShown") private var hintShownCount = 0
    @State private var currentTime = Date()

    let onTap: () -> Void

    // Timer to update time display
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        Button(action: {
            // Increment hint counter on first few taps
            if hintShownCount < 3 {
                hintShownCount += 1
            }
            onTap()
        }) {
            VStack(spacing: 4) {
                // Day of week
                Text(dayOfWeek)
                    .font(DesignTokens.Typography.largeHeader)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                // Month and day
                Text(monthAndDay)
                    .font(DesignTokens.Typography.largeHeader)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                // Time
                Text(timeString)
                    .font(DesignTokens.Typography.time)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .lineLimit(1)

                // Hint text (shows for first 3 launches)
                if hintShownCount < 3 {
                    Text(WarmCopy.dateHeaderHint)
                        .font(DesignTokens.Typography.meta.italic())
                        .foregroundColor(DesignTokens.Colors.textTertiary)
                        .padding(.top, 8)
                }
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(ScalePressStyle(scale: 0.98))
        .foregroundColor(DesignTokens.Colors.textPrimary)
        .accessibilityIdentifier("dateTimeHeader")
        .accessibilityLabel("\(dayOfWeek), \(monthAndDay), \(timeString)")
        .accessibilityHint("Tap to open today's journal")
        .onReceive(timer) { _ in
            currentTime = Date()
        }
    }

    // MARK: - Date Formatting

    private var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: currentTime)
    }

    private var monthAndDay: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        return formatter.string(from: currentTime)
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: currentTime)
    }
}

#Preview {
    DateTimeHeader(onTap: {})
        .padding()
        .ambientBackground()
}

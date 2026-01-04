import SwiftUI

/// Reusable warm card component with consistent styling
/// Rule: Shadows only on AmbientCard, never on individual rows
struct AmbientCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(DesignTokens.Spacing.cardPad)
            .background(DesignTokens.Colors.elevatedSurface)
            .cornerRadius(DesignTokens.Radii.card)
            .cardShadow()
    }
}

/// Card header with consistent visual hierarchy
struct CardHeader: View {
    let title: String
    let subtitle: String?

    init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(DesignTokens.Typography.sectionHeader)
                .foregroundColor(DesignTokens.Colors.textPrimary)

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(DesignTokens.Typography.meta)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        AmbientCard {
            VStack(alignment: .leading, spacing: 12) {
                CardHeader(
                    title: "Today's Focus",
                    subtitle: "Three small wins is plenty."
                )

                Text("Sample content goes here")
                    .font(DesignTokens.Typography.body)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    .padding()
    .ambientBackground()
}

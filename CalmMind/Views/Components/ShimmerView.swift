import SwiftUI

/// Shimmer loading skeleton for warm loading states
struct ShimmerView: View {
    @State private var phase: CGFloat = 0

    let width: CGFloat
    let height: CGFloat

    init(width: CGFloat = 200, height: CGFloat = 16) {
        self.width = width
        self.height = height
    }

    var body: some View {
        RoundedRectangle(cornerRadius: height / 2)
            .fill(DesignTokens.Colors.subtleSection)
            .frame(width: width, height: height)
            .overlay {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                DesignTokens.Colors.elevatedSurface.opacity(0.6),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .offset(x: phase)
            }
            .clipShape(RoundedRectangle(cornerRadius: height / 2))
            .onAppear {
                withAnimation(
                    .linear(duration: 1.5)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = width
                }
            }
    }
}

/// Two-line shimmer for prompt loading state
struct PromptShimmer: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ShimmerView(width: 240, height: 16)
            ShimmerView(width: 180, height: 16)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        ShimmerView()
        PromptShimmer()
    }
    .padding()
    .ambientBackground()
}

import SwiftUI

/// Onboarding flow for new users
struct OnboardingView: View {
    @Binding var isComplete: Bool
    @State private var currentPage: Int = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "heart.text.square.fill",
            title: "Your Personal Companion",
            description: "CalmMind is here to listen, support, and help you reflect on your day. Everything you share stays private on your device."
        ),
        OnboardingPage(
            icon: "book.closed.fill",
            title: "Automatic Journaling",
            description: "Your conversations become meaningful journal entries. Track your mood and see patterns over time."
        ),
        OnboardingPage(
            icon: "checkmark.circle.fill",
            title: "Stay on Track",
            description: "Create todos during your conversations or manually. CalmMind gently reminds you of what matters."
        ),
        OnboardingPage(
            icon: "lock.shield.fill",
            title: "Privacy First",
            description: "Your data never leaves your device. Only brief summaries are shared with AI to maintain context."
        )
    ]

    var body: some View {
        VStack {
            // Page content
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    OnboardingPageView(page: page)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            // Navigation
            VStack(spacing: 16) {
                if currentPage < pages.count - 1 {
                    Button("Continue") {
                        withAnimation {
                            currentPage += 1
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                } else {
                    NavigationLink {
                        APIKeySetupView(isPresented: $isComplete)
                    } label: {
                        Text("Get Started")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }

                if currentPage > 0 {
                    Button("Back") {
                        withAnimation {
                            currentPage -= 1
                        }
                    }
                    .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
    }
}

/// Data model for an onboarding page
struct OnboardingPage {
    let icon: String
    let title: String
    let description: String
}

/// View for a single onboarding page
struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: page.icon)
                .font(.system(size: 80))
                .foregroundColor(.accentColor)

            VStack(spacing: 16) {
                Text(page.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text(page.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
    }
}

#Preview {
    NavigationStack {
        OnboardingView(isComplete: .constant(false))
    }
}

import SwiftUI

/// Welcome screen that collects user's name
/// First screen of onboarding flow
struct WelcomeNameView: View {
    @Binding var name: String
    let onContinue: () -> Void

    @FocusState private var isNameFocused: Bool

    private var isNameValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // App icon
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 80))
                .foregroundStyle(DesignTokens.Colors.warmClay)

            // Welcome text
            Text("Welcome to CalmMind")
                .font(DesignTokens.Typography.largeHeader)
                .foregroundStyle(DesignTokens.Colors.textPrimary)

            Text("What should I call you?")
                .font(DesignTokens.Typography.sectionHeader)
                .foregroundStyle(DesignTokens.Colors.textSecondary)

            // Name input
            TextField("First name or nickname", text: $name)
                .font(DesignTokens.Typography.sectionHeader)
                .multilineTextAlignment(.center)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 48)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.words)
                .focused($isNameFocused)

            Spacer()

            // Continue button
            Button(action: {
                guard isNameValid else { return }
                onContinue()
            }) {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isNameValid ? DesignTokens.Colors.warmClay : DesignTokens.Colors.textTertiary)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radii.button))
            }
            .disabled(!isNameValid)
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .ambientBackground()
        .onAppear {
            // Auto-focus the name field after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isNameFocused = true
            }
        }
    }
}

#Preview {
    WelcomeNameView(name: .constant("")) {
        print("Continue tapped")
    }
}

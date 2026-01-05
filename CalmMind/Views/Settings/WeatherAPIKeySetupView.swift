import SwiftUI

/// View for entering and saving an OpenWeatherMap API key
struct WeatherAPIKeySetupView: View {
    @Binding var isPresented: Bool
    @State private var apiKey: String = ""
    @State private var isValidating: Bool = false
    @State private var validationError: String?
    @State private var showingError: Bool = false

    private let secretsStore: any SecretsStore

    init(isPresented: Binding<Bool>, secretsStore: any SecretsStore = KeychainSecretsStore.shared) {
        self._isPresented = isPresented
        self.secretsStore = secretsStore
    }

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "cloud.sun.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(DesignTokens.Colors.warmClay)

                Text("Weather API Key")
                    .font(DesignTokens.Typography.sectionHeader)
                    .foregroundColor(DesignTokens.Colors.textPrimary)

                Text("Enter your OpenWeatherMap API key to enable weather features")
                    .font(DesignTokens.Typography.body)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top)

            // Input field
            VStack(alignment: .leading, spacing: 8) {
                TextField("API Key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                Text("Your API key is stored securely in the device Keychain.")
                    .font(DesignTokens.Typography.meta)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
            .padding(.horizontal)

            // Help link
            Link(destination: URL(string: "https://openweathermap.org/api")!) {
                HStack {
                    Text("Get a free API key from OpenWeatherMap")
                    Image(systemName: "arrow.up.right.square")
                }
                .font(DesignTokens.Typography.body)
                .foregroundColor(DesignTokens.Colors.warmClay)
            }

            Spacer()

            // Save button
            Button {
                Task {
                    await saveAPIKey()
                }
            } label: {
                if isValidating {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Save API Key")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(DesignTokens.Colors.warmClay)
            .controlSize(.large)
            .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isValidating)
            .padding(.horizontal)
            .padding(.bottom)
        }
        .ambientBackground()
        .navigationTitle("Weather API Key")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    isPresented = false
                }
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") {
                showingError = false
            }
        } message: {
            Text(validationError ?? "Failed to save API key")
        }
    }

    private func saveAPIKey() async {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedKey.isEmpty else {
            return
        }

        // OpenWeatherMap keys are 32 character hex strings
        guard trimmedKey.count >= 20 else {
            validationError = "API key appears to be too short"
            showingError = true
            return
        }

        isValidating = true

        do {
            try secretsStore.saveWeatherAPIKey(trimmedKey)
            isPresented = false
        } catch {
            validationError = "Failed to save API key: \(error.localizedDescription)"
            showingError = true
        }

        isValidating = false
    }
}

#Preview {
    NavigationStack {
        WeatherAPIKeySetupView(isPresented: .constant(true))
    }
}

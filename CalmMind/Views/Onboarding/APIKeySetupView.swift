import SwiftUI

/// View for entering and validating an OpenAI API key
struct APIKeySetupView: View {
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
                Image(systemName: "key.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)

                Text("OpenAI API Key")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Enter your API key to enable AI features")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top)

            // Input field
            VStack(alignment: .leading, spacing: 8) {
                SecureField("sk-...", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                Text("Your API key is stored securely in the device Keychain and never leaves your device.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)

            // Help link
            Link(destination: URL(string: "https://platform.openai.com/api-keys")!) {
                HStack {
                    Text("Get an API key from OpenAI")
                    Image(systemName: "arrow.up.right.square")
                }
                .font(.subheadline)
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
            .controlSize(.large)
            .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isValidating)
            .padding(.horizontal)
            .padding(.bottom)
        }
        .navigationTitle("API Key")
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

        // Basic format validation
        guard trimmedKey.hasPrefix("sk-") else {
            validationError = "API key should start with 'sk-'"
            showingError = true
            return
        }

        isValidating = true

        do {
            try secretsStore.saveAPIKey(trimmedKey)
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
        APIKeySetupView(isPresented: .constant(true))
    }
}

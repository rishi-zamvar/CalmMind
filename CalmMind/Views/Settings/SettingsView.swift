import SwiftUI

/// Settings view for app configuration
struct SettingsView: View {
    @AppStorage("morningNotificationsEnabled") private var morningNotifications = true
    @AppStorage("eveningNotificationsEnabled") private var eveningNotifications = true
    @AppStorage("privacyMode") private var privacyMode = false
    @AppStorage("notificationPrivacyMode") private var notificationPrivacyMode = "detailed"
    @AppStorage("autoJournalingEnabled") private var autoJournalingEnabled = false
    @AppStorage("weatherEnabled") private var weatherEnabled = true

    @State private var showingDeleteConfirmation = false
    @State private var showingAPIKeySheet = false
    @State private var showingWeatherAPIKeySheet = false

    var body: some View {
        Form {
            // Notifications section
            Section {
                Toggle("Morning Check-in", isOn: $morningNotifications)
                Toggle("Evening Reflection", isOn: $eveningNotifications)

                Picker("Notification Content", selection: $notificationPrivacyMode) {
                    Text("Detailed").tag("detailed")
                    Text("Minimal").tag("minimal")
                }
            } header: {
                Text("Notifications")
                    .font(DesignTokens.Typography.meta)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            } footer: {
                Text("Minimal mode hides todo titles and mood references from notifications.")
                    .font(DesignTokens.Typography.meta)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }

            // Journal section
            Section {
                Toggle("Auto-save to Journal", isOn: $autoJournalingEnabled)
            } header: {
                Text("Journal")
                    .font(DesignTokens.Typography.meta)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            } footer: {
                Text("When enabled, your messages are saved as journal events. At the end of each day, they're synthesized into a personal journal entry.")
                    .font(DesignTokens.Typography.meta)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }

            // Privacy section
            Section {
                Toggle("Privacy Mode", isOn: $privacyMode)
            } header: {
                Text("Privacy")
                    .font(DesignTokens.Typography.meta)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            } footer: {
                Text("When enabled, private items are excluded from AI context.")
                    .font(DesignTokens.Typography.meta)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }

            // Features section
            Section {
                Toggle("Weather", isOn: $weatherEnabled)

                Button {
                    showingWeatherAPIKeySheet = true
                } label: {
                    HStack {
                        Text("Weather API Key")
                            .font(DesignTokens.Typography.body)
                            .foregroundColor(DesignTokens.Colors.textPrimary)
                        Spacer()
                        if KeychainSecretsStore.shared.hasWeatherAPIKey {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(DesignTokens.Colors.sage)
                        } else {
                            Text("Not set")
                                .font(DesignTokens.Typography.meta)
                                .foregroundColor(DesignTokens.Colors.textTertiary)
                        }
                    }
                }
            } header: {
                Text("Features")
                    .font(DesignTokens.Typography.meta)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            } footer: {
                Text("Weather requires a free OpenWeatherMap API key and location access.")
                    .font(DesignTokens.Typography.meta)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }

            // API section
            Section {
                Button {
                    showingAPIKeySheet = true
                } label: {
                    Text("Update API Key")
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(DesignTokens.Colors.warmClay)
                }
            } header: {
                Text("OpenAI")
                    .font(DesignTokens.Typography.meta)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }

            // About section
            Section {
                HStack {
                    Text("Version")
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(DesignTokens.Colors.textPrimary)
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }

                Link("Privacy Policy", destination: URL(string: "https://example.com/privacy")!)
                    .font(DesignTokens.Typography.body)
                    .foregroundColor(DesignTokens.Colors.warmClay)
                Link("Terms of Service", destination: URL(string: "https://example.com/terms")!)
                    .font(DesignTokens.Typography.body)
                    .foregroundColor(DesignTokens.Colors.warmClay)
            } header: {
                Text("About")
                    .font(DesignTokens.Typography.meta)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }

            // Crisis resources - always visible (calm styling)
            Section {
                Link(destination: URL(string: "tel:988")!) {
                    HStack {
                        Image(systemName: "phone.fill")
                            .foregroundColor(DesignTokens.Colors.sage)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("988 Crisis Lifeline")
                                .font(DesignTokens.Typography.body)
                                .foregroundColor(DesignTokens.Colors.textPrimary)
                            Text("Call or text anytime")
                                .font(DesignTokens.Typography.meta)
                                .foregroundColor(DesignTokens.Colors.textSecondary)
                        }
                    }
                }
            } header: {
                Text("Crisis Resources")
                    .font(DesignTokens.Typography.meta)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            } footer: {
                Text("Available 24/7 for anyone in crisis.")
                    .font(DesignTokens.Typography.meta)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }

            // Data section (destructive - extra spacing, subtle background)
            Section {
                Button {
                    // TODO: Implement data export
                } label: {
                    Text("Export All Data")
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(DesignTokens.Colors.warmClay)
                }

                Button {
                    showingDeleteConfirmation = true
                } label: {
                    Text("Delete All Data")
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(DesignTokens.Colors.destructive)
                }
            } header: {
                Text("Data")
                    .font(DesignTokens.Typography.meta)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
                    .padding(.top, 16)
            } footer: {
                Text("Deleting data is permanent and cannot be undone.")
                    .font(DesignTokens.Typography.meta)
                    .foregroundColor(DesignTokens.Colors.textTertiary)
            }
        }
        .scrollContentBackground(.hidden)
        .ambientBackground()
        .navigationTitle("Settings")
        .alert("Delete All Data?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                // TODO: Implement data deletion
            }
        } message: {
            Text("This will permanently delete all your conversations, journals, todos, and settings. This action cannot be undone.")
        }
        .sheet(isPresented: $showingAPIKeySheet) {
            NavigationStack {
                APIKeySetupView(isPresented: $showingAPIKeySheet)
            }
        }
        .sheet(isPresented: $showingWeatherAPIKeySheet) {
            NavigationStack {
                WeatherAPIKeySetupView(isPresented: $showingWeatherAPIKeySheet)
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}

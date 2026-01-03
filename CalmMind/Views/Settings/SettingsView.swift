import SwiftUI

/// Settings view for app configuration
struct SettingsView: View {
    @AppStorage("morningNotificationsEnabled") private var morningNotifications = true
    @AppStorage("eveningNotificationsEnabled") private var eveningNotifications = true
    @AppStorage("privacyMode") private var privacyMode = false
    @AppStorage("notificationPrivacyMode") private var notificationPrivacyMode = "detailed"

    @State private var showingDeleteConfirmation = false
    @State private var showingAPIKeySheet = false

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
            } footer: {
                Text("Minimal mode hides todo titles and mood references from notifications.")
            }

            // Privacy section
            Section {
                Toggle("Privacy Mode", isOn: $privacyMode)
            } header: {
                Text("Privacy")
            } footer: {
                Text("When enabled, private items are excluded from AI context.")
            }

            // API section
            Section {
                Button("Update API Key") {
                    showingAPIKeySheet = true
                }
            } header: {
                Text("OpenAI")
            }

            // Data section
            Section {
                Button("Export All Data") {
                    // TODO: Implement data export
                }

                Button("Delete All Data", role: .destructive) {
                    showingDeleteConfirmation = true
                }
            } header: {
                Text("Data")
            } footer: {
                Text("Deleting data is permanent and cannot be undone.")
            }

            // About section
            Section {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                        .foregroundColor(.secondary)
                }

                Link("Privacy Policy", destination: URL(string: "https://example.com/privacy")!)
                Link("Terms of Service", destination: URL(string: "https://example.com/terms")!)
            } header: {
                Text("About")
            }

            // Crisis resources - always visible
            Section {
                Link(destination: URL(string: "tel:988")!) {
                    HStack {
                        Image(systemName: "phone.fill")
                            .foregroundColor(.green)
                        VStack(alignment: .leading) {
                            Text("988 Crisis Lifeline")
                                .foregroundColor(.primary)
                            Text("Call or text anytime")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } header: {
                Text("Crisis Resources")
            } footer: {
                Text("Available 24/7 for anyone in crisis.")
            }
        }
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
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}

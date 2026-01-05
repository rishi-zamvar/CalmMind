import SwiftUI

/// Compact weather display for home page
/// Single line format: "San Francisco · 58°F ☀️"
/// If state is .hidden, returns EmptyView
/// Permission request happens on user tap when notDetermined
struct WeatherCard: View {
    @Bindable var viewModel: WeatherViewModel

    var body: some View {
        switch viewModel.state {
        case .hidden:
            EmptyView()

        case .needsPermission:
            permissionRequestView

        case .loading:
            loadingView

        case .loaded(let weather, let locationString):
            weatherContent(weather: weather, locationString: locationString)
        }
    }

    // MARK: - Permission Request

    private var permissionRequestView: some View {
        Button {
            Task {
                await viewModel.requestLocationPermission()
            }
        } label: {
            HStack(spacing: DesignTokens.Spacing.cardPad / 2) {
                Image(systemName: "location.fill")
                    .foregroundStyle(DesignTokens.Colors.warmClay)
                Text("Tap to enable weather")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            .padding(.vertical, DesignTokens.Spacing.cardPad / 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Enable location for weather")
        .accessibilityHint("Tapping will request location permission")
        .onAppear {
            // Re-check permission state in case it was stale on initial load
            Task {
                await viewModel.loadWeather()
            }
        }
    }

    // MARK: - Content

    private func weatherContent(weather: Weather, locationString: String) -> some View {
        HStack(spacing: DesignTokens.Spacing.cardPad / 2) {
            // Location · Temp Emoji
            Text(weather.compactLine)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)  // Location truncates, temp/emoji preserved
                .accessibilityLabel("Weather: \(locationString), \(weather.formattedTemperature), \(weather.condition.displayName)")

            Spacer(minLength: 0)

            // Manual refresh button - SEPARATE accessibility element
            Button {
                Task {
                    await viewModel.refreshWeather()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: DesignTokens.Sizing.hitTargetMin, height: DesignTokens.Sizing.hitTargetMin)
                    .contentShape(Rectangle())  // Make entire frame tappable
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Refresh weather")
            .accessibilityHint("Double tap to update weather information")
        }
        .padding(.vertical, DesignTokens.Spacing.cardPad / 2)
    }

    private var loadingView: some View {
        HStack(spacing: DesignTokens.Spacing.cardPad / 2) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Loading weather...")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(.vertical, DesignTokens.Spacing.cardPad / 2)
    }
}

// MARK: - Preview

#Preview("Loaded") {
    WeatherCard(viewModel: {
        let vm = WeatherViewModel(
            locationService: PreviewLocationService(),
            weatherService: PreviewWeatherService()
        )
        return vm
    }())
}

// MARK: - Preview Helpers

private struct PreviewLocationService: LocationServiceProtocol {
    var authorizationStatus: CLAuthorizationStatus { .authorizedWhenInUse }
    var isDenied: Bool { false }
    var permissionState: LocationPermissionState { .authorized }
    func requestPermissionIfNeeded() async -> Bool { false }
    func getLocationThrottled() async -> CLLocationCoordinate2D? {
        CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
    }
    func getLocationString() async -> String? { "San Francisco, CA" }
}

private struct PreviewWeatherService: WeatherServiceProtocol {
    func fetchWeather(for coordinate: CLLocationCoordinate2D) async throws -> Weather {
        Weather(
            temperature: 68,
            condition: .clear,
            description: "clear sky",
            humidity: 55,
            locationName: "San Francisco",
            timestamp: Date()
        )
    }
    func getCachedWeather() -> Weather? { nil }
    func fetchWeatherIfAllowed(for coordinate: CLLocationCoordinate2D) async -> Weather? {
        try? await fetchWeather(for: coordinate)
    }
}

import CoreLocation

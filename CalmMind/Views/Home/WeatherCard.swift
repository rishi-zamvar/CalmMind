import SwiftUI

/// Compact weather display for home page
/// Single line format: "San Francisco · 58°F ☀️"
/// If state is .hidden, returns EmptyView
struct WeatherCard: View {
    let viewModel: WeatherViewModel

    var body: some View {
        switch viewModel.state {
        case .hidden:
            EmptyView()

        case .loading:
            loadingView

        case .loaded(let weather, let locationString):
            weatherContent(weather: weather, locationString: locationString)
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

            Spacer(minLength: 0)
        }
        .padding(.vertical, DesignTokens.Spacing.cardPad / 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Weather: \(locationString), \(Int(weather.temperature)) degrees Fahrenheit, \(weather.condition.displayName)")
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
    func requestAuthorizationOnce() async {}
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

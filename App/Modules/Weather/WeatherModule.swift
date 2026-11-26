import CoreLocation
import Foundation
import Observation

/// Current weather for the home view from Open-Meteo (free, no account). Opt-in.
/// Location comes from a city typed in Settings, or from Core Location (rounded to ~1 km).
@Observable
final class WeatherModule: NSObject, CLLocationManagerDelegate {
    static let shared = WeatherModule()
    struct Snapshot: Equatable {
        var temperature: Int
        var high: Int
        var low: Int
        var symbol: String
    }

    private(set) var current: Snapshot?
    private let location = CLLocationManager()
    private var timer: Timer?
    private var lastFetch = Date.distantPast

    override init() {
        super.init()
        location.delegate = self
    }

    func start() {
        refreshIfNeeded()
        timer = Timer.scheduledTimer(withTimeInterval: 30 * 60, repeats: true) { [weak self] _ in self?.refresh() }
    }

    /// Called when the home view appears so a newly enabled setting shows up quickly.
    func refreshIfNeeded() {
        guard Prefs.on(Prefs.weather), Date().timeIntervalSince(lastFetch) > 10 * 60 || current == nil else { return }
        refresh()
    }

    func refresh() {
        guard Prefs.on(Prefs.weather) else { current = nil; return }
        lastFetch = Date()
        let city = (UserDefaults.standard.string(forKey: Prefs.weatherCity) ?? "").trimmingCharacters(in: .whitespaces)
        if !city.isEmpty {
            Task { await geocodeAndFetch(city) }
        } else {
            location.requestWhenInUseAuthorization()
            location.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let c = locations.last?.coordinate else { return }
        Task { await fetch(latitude: c.latitude, longitude: c.longitude) }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Log.app.error("Weather location failed: \(error.localizedDescription)")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        if status != .notDetermined, status != .denied, status != .restricted, Prefs.on(Prefs.weather) {
            manager.requestLocation()
        }
    }

    private func geocodeAndFetch(_ city: String) async {
        var c = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")
        c?.queryItems = [.init(name: "name", value: city), .init(name: "count", value: "1")]
        guard let url = c?.url, let data = try? await URLSession.shared.data(from: url).0,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let first = (json["results"] as? [[String: Any]])?.first,
              let lat = first["latitude"] as? Double, let lon = first["longitude"] as? Double else { return }
        await fetch(latitude: lat, longitude: lon)
    }

    private func fetch(latitude: Double, longitude: Double) async {
        let fahrenheit = Locale.current.measurementSystem == .us
        var c = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        c?.queryItems = [
            .init(name: "latitude", value: String(format: "%.2f", latitude)),
            .init(name: "longitude", value: String(format: "%.2f", longitude)),
            .init(name: "current", value: "temperature_2m,weather_code,is_day"),
            .init(name: "daily", value: "temperature_2m_max,temperature_2m_min"),
            .init(name: "forecast_days", value: "1"),
            .init(name: "timezone", value: "auto"),
            .init(name: "temperature_unit", value: fahrenheit ? "fahrenheit" : "celsius"),
        ]
        guard let url = c?.url, let data = try? await URLSession.shared.data(from: url).0,
              let snapshot = Self.parse(data) else { return }
        await MainActor.run { self.current = snapshot }
    }

    static func parse(_ data: Data) -> Snapshot? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let now = json["current"] as? [String: Any],
              let temp = now["temperature_2m"] as? Double,
              let code = now["weather_code"] as? Int,
              let daily = json["daily"] as? [String: Any],
              let high = (daily["temperature_2m_max"] as? [Double])?.first,
              let low = (daily["temperature_2m_min"] as? [Double])?.first else { return nil }
        let isDay = (now["is_day"] as? Int ?? 1) == 1
        return Snapshot(temperature: Int(temp.rounded()), high: Int(high.rounded()), low: Int(low.rounded()),
                        symbol: symbol(for: code, isDay: isDay))
    }

    /// WMO weather codes → SF Symbols.
    static func symbol(for code: Int, isDay: Bool) -> String {
        switch code {
        case 0: isDay ? "sun.max.fill" : "moon.stars.fill"
        case 1, 2: isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case 3: "cloud.fill"
        case 45, 48: "cloud.fog.fill"
        case 51...57: "cloud.drizzle.fill"
        case 61...67, 80...82: "cloud.rain.fill"
        case 71...77, 85, 86: "cloud.snow.fill"
        case 95...99: "cloud.bolt.rain.fill"
        default: "cloud.fill"
        }
    }
}

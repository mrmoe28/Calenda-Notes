//
//  WeatherService.swift
//  Calenda Notes
//

import Foundation
import CoreLocation
import WeatherKit

// Main weather service that ActionExecutor uses
final class WeatherServiceImpl {
    private let locationService = LocationService()
    
    func getCurrentWeather() async -> String {
        guard let location = await locationService.getCurrentLocation() else {
            return "❌ Location access required for weather. Please enable in Settings."
        }
        
        // Use Open-Meteo API (free, no key required, works everywhere)
        return await getWeatherFromAPI(location: location)
    }
    
    func getWeatherForecast(days: Int = 5) async -> String {
        guard let location = await locationService.getCurrentLocation() else {
            return "❌ Location access required for weather forecast."
        }
        
        return await getForecastFromAPI(location: location, days: days)
    }
    
    // Using Open-Meteo free API (no key required)
    private func getWeatherFromAPI(location: CLLocation) async -> String {
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m&temperature_unit=fahrenheit&wind_speed_unit=mph"
        
        guard let url = URL(string: urlString) else {
            return "❌ Invalid weather URL"
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let current = json["current"] as? [String: Any] {
                let temp = current["temperature_2m"] as? Double ?? 0
                let feelsLike = current["apparent_temperature"] as? Double ?? 0
                let humidity = current["relative_humidity_2m"] as? Int ?? 0
                let windSpeed = current["wind_speed_10m"] as? Double ?? 0
                let weatherCode = current["weather_code"] as? Int ?? 0
                let (condition, emoji) = weatherCodeToCondition(weatherCode)
                
                return """
                \(emoji) Current Weather:
                • Condition: \(condition)
                • Temperature: \(Int(temp))°F
                • Feels like: \(Int(feelsLike))°F
                • Humidity: \(humidity)%
                • Wind: \(Int(windSpeed)) mph
                """
            }
        } catch {
            print("❌ Weather API error: \(error)")
        }
        
        return "❌ Could not fetch weather data"
    }
    
    private func getForecastFromAPI(location: CLLocation, days: Int) async -> String {
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&daily=temperature_2m_max,temperature_2m_min,weather_code&temperature_unit=fahrenheit&forecast_days=\(days)"
        
        guard let url = URL(string: urlString) else {
            return "❌ Invalid forecast URL"
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let daily = json["daily"] as? [String: Any],
               let dates = daily["time"] as? [String],
               let highs = daily["temperature_2m_max"] as? [Double],
               let lows = daily["temperature_2m_min"] as? [Double],
               let codes = daily["weather_code"] as? [Int] {
                
                var result = "📅 \(days)-Day Forecast:\n"
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                let displayFormatter = DateFormatter()
                displayFormatter.dateFormat = "EEEE"
                
                for i in 0..<min(days, dates.count) {
                    let dayName = i == 0 ? "Today" : displayFormatter.string(from: formatter.date(from: dates[i]) ?? Date())
                    let (condition, emoji) = weatherCodeToCondition(codes[i])
                    result += "\(emoji) \(dayName): \(Int(highs[i]))°/\(Int(lows[i]))°F - \(condition)\n"
                }
                
                return result
            }
        } catch {
            print("❌ Forecast API error: \(error)")
        }
        
        return "❌ Could not fetch forecast data"
    }
    
    private func weatherCodeToCondition(_ code: Int) -> (String, String) {
        switch code {
        case 0: return ("Clear", "☀️")
        case 1, 2, 3: return ("Partly Cloudy", "⛅")
        case 45, 48: return ("Foggy", "🌫️")
        case 51, 53, 55: return ("Drizzle", "🌦️")
        case 61, 63, 65: return ("Rain", "🌧️")
        case 66, 67: return ("Freezing Rain", "🌨️")
        case 71, 73, 75: return ("Snow", "❄️")
        case 77: return ("Snow Grains", "❄️")
        case 80, 81, 82: return ("Rain Showers", "🌧️")
        case 85, 86: return ("Snow Showers", "🌨️")
        case 95: return ("Thunderstorm", "⛈️")
        case 96, 99: return ("Thunderstorm with Hail", "⛈️")
        default: return ("Unknown", "🌡️")
        }
    }
}

// Helper location service for getting user's current location
final class LocationService: NSObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation?, Never>?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }
    
    func getCurrentLocation() async -> CLLocation? {
        // Check and request authorization on main thread
        let status = await MainActor.run {
            locationManager.authorizationStatus
        }
        
        if status == .notDetermined {
            await MainActor.run {
                locationManager.requestWhenInUseAuthorization()
            }
            // Wait for user to respond
            try? await Task.sleep(nanoseconds: 1_500_000_000)
        }
        
        let currentStatus = await MainActor.run {
            locationManager.authorizationStatus
        }
        
        guard currentStatus == .authorizedWhenInUse || currentStatus == .authorizedAlways else {
            return nil
        }
        
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            DispatchQueue.main.async {
                self.locationManager.requestLocation()
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        continuation?.resume(returning: locations.first)
        continuation = nil
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Location error: \(error)")
        continuation?.resume(returning: nil)
        continuation = nil
    }
}

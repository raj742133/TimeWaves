import Foundation

class TideAPIClient {
    private let baseURL = "https://api.tidesandcurrents.noaa.gov/api/prod/datagetter"
    
    enum APIError: Error {
        case invalidURL
        case networkError
        case decodingError
        case apiError(String)
    }
    
    func fetchTideData(latitude: Double, longitude: Double) async throws -> [TideData] {
        print("Starting fetchTideData for lat: \(latitude), lon: \(longitude)")
        
        // Find the nearest station first
        let station = try await findNearestStation(latitude, longitude)
        print("Found nearest station: \(station.name) (ID: \(station.id))")
        
        let now = Date()
        let beginDate = now.addingTimeInterval(-12 * 3600)
        let endDate = now.addingTimeInterval(24 * 3600)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd HH:mm"
        
        // Construct URL with all parameters clearly visible for debugging
        let urlComponents = [
            "station=\(station.id)",
            "begin_date=\(dateFormatter.string(from: beginDate))",
            "end_date=\(dateFormatter.string(from: endDate))",
            "product=predictions",
            "datum=MLLW",
            "time_zone=lst_ldt",
            "interval=30",
            "units=metric",
            "format=json"
        ].joined(separator: "&")
        
        let urlString = "\(baseURL)?\(urlComponents)"
        print("API Request URL: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        let (data, httpResponse) = try await URLSession.shared.data(from: url)
        
        guard let response = httpResponse as? HTTPURLResponse else {
            throw APIError.networkError
        }
        
        if response.statusCode != 200 {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.apiError("Failed to fetch tide data: \(errorText)")
        }
        
        let noaaResponse: NOAAResponse
        do {
            noaaResponse = try JSONDecoder().decode(NOAAResponse.self, from: data)
        } catch {
            print("Decoding error: \(error)")
            throw APIError.decodingError
        }
        
        if let error = noaaResponse.error?.message {
            throw APIError.apiError(error)
        }
        
        guard let predictions = noaaResponse.predictions, !predictions.isEmpty else {
            throw APIError.apiError("No tide data available for this location")
        }
        
        print("Processing \(predictions.count) predictions")
        var tideDatas: [TideData] = []
        
        // Process predictions to identify highs and lows
        for (index, prediction) in predictions.enumerated() {
            guard let height = Double(prediction.v),
                  let timestamp = dateFormatter.date(from: prediction.t) else {
                print("Failed to parse prediction: \(prediction)")
                continue
            }
            
            var type = TideData.TideType.current
            
            // Determine if this is a high or low point
            if index > 0 && index < predictions.count - 1 {
                let prevHeight = Double(predictions[index-1].v) ?? 0
                let nextHeight = Double(predictions[index+1].v) ?? 0
                
                if height > prevHeight && height > nextHeight {
                    type = .high
                } else if height < prevHeight && height < nextHeight {
                    type = .low
                }
            }
            
            // Add significant points (highs, lows, and current)
            if type != .current || timestamp.timeIntervalSince(now) < 300 {
                tideDatas.append(TideData(
                    timestamp: timestamp,
                    height: height,
                    type: timestamp.timeIntervalSince(now) < 300 ? .current : type
                ))
            }
        }
        
        let sortedData = tideDatas.sorted { $0.timestamp < $1.timestamp }
        print("Returning \(sortedData.count) tide entries")
        
        // Ensure we have at least some data
        guard !sortedData.isEmpty else {
            throw APIError.apiError("No tide data available for this location")
        }
        
        return sortedData
    }
    
    private func findNearestStation(_ latitude: Double, _ longitude: Double) async throws -> NOAAStation {
        print("Finding nearest station to lat: \(latitude), lon: \(longitude)")
        
        let urlString = "https://api.tidesandcurrents.noaa.gov/mdapi/prod/webapi/stations.json?type=tidepredictions"
        
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(NOAAStationsResponse.self, from: data)
        
        print("Found \(response.stations.count) total stations")
        
        // Calculate distances outside of min function to avoid circular reference
        var nearestStation: NOAAStation?
        var shortestDistance = Double.infinity
        
        for station in response.stations {
            let dist = calculateDistance(
                lat1: latitude, lon1: longitude,
                lat2: station.lat, lon2: station.lng
            )
            if dist < shortestDistance {
                shortestDistance = dist
                nearestStation = station
            }
        }
        
        guard let station = nearestStation else {
            print("No stations found")
            throw APIError.apiError("No nearby tide stations found")
        }
        
        print("Nearest station: \(station.name) at \(String(format: "%.2f", shortestDistance/1000))km away")
        return station
    }
    
    private func calculateDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let R = 6371e3 // Earth's radius in meters
        let φ1 = lat1 * .pi / 180
        let φ2 = lat2 * .pi / 180
        let Δφ = (lat2 - lat1) * .pi / 180
        let Δλ = (lon2 - lon1) * .pi / 180
        
        let a = sin(Δφ/2) * sin(Δφ/2) +
                cos(φ1) * cos(φ2) *
                sin(Δλ/2) * sin(Δλ/2)
        let c = 2 * atan2(sqrt(a), sqrt(1-a))
        
        return R * c
    }
    
    func searchLocations(_ query: String) async throws -> [Location] {
        // Using OpenStreetMap Nominatim API for location search
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "https://nominatim.openstreetmap.org/search?q=\(encodedQuery)&format=json&limit=5&featuretype=city,town,village&addressdetails=1"
        
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        // Required by Nominatim's usage policy
        request.addValue("TimeWaves/1.0", forHTTPHeaderField: "User-Agent")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        do {
            let searchResults = try JSONDecoder().decode([NominatimResponse].self, from: data)
            return searchResults.compactMap { result in
                // Only return locations that have valid coordinates
                guard result.lat != 0, result.lon != 0 else { return nil }
                
                // Format the display name to be more user-friendly
                let formattedName = formatLocationName(result)
                
                return Location(
                    name: formattedName,
                    latitude: result.lat,
                    longitude: result.lon
                )
            }
        } catch {
            print("Decoding error: \(error)")
            throw APIError.decodingError
        }
    }
    
    private func formatLocationName(_ result: NominatimResponse) -> String {
        // Extract city/town and country from the display name
        let components = result.display_name.components(separatedBy: ", ")
        if components.count >= 2 {
            let city = components[0]
            let country = components.last ?? ""
            return "\(city), \(country)"
        }
        return result.display_name
    }
}

// NOAA API Response Models
struct NOAAResponse: Codable {
    let predictions: [Prediction]?
    let error: NOAAError?
    
    struct NOAAError: Codable {
        let message: String?
    }
}

struct Prediction: Codable {
    let t: String // time
    let v: String // water level
}

struct NOAAStationsResponse: Codable {
    let stations: [NOAAStation]
}

struct NOAAStation: Codable {
    let id: String
    let name: String
    let lat: Double
    let lng: Double
}

// Nominatim API Response Model
struct NominatimResponse: Codable {
    let display_name: String
    let lat: Double
    let lon: Double
    let type: String?
    let address: Address?
    
    struct Address: Codable {
        let city: String?
        let town: String?
        let village: String?
        let state: String?
        let country: String?
    }
    
    enum CodingKeys: String, CodingKey {
        case display_name
        case lat
        case lon
        case type
        case address
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        display_name = try container.decode(String.self, forKey: .display_name)
        
        // Handle lat/lon as String and convert to Double
        let latString = try container.decode(String.self, forKey: .lat)
        let lonString = try container.decode(String.self, forKey: .lon)
        lat = Double(latString) ?? 0
        lon = Double(lonString) ?? 0
        
        type = try? container.decode(String.self, forKey: .type)
        address = try? container.decode(Address.self, forKey: .address)
    }
} 
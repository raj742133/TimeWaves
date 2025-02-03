import Foundation
import CoreLocation

class TideViewModel: NSObject, ObservableObject {
    @Published var currentLocation: Location?
    @Published var recentLocations: [Location] = []
    @Published var tideData: [TideData] = []
    @Published var searchResults: [Location] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let locationManager: CLLocationManager
    private let userDefaults = UserDefaults.standard
    private let apiClient = TideAPIClient()
    
    override init() {
        locationManager = CLLocationManager()
        super.init()
        locationManager.delegate = self
        
        // Load saved data
        loadSavedLocation()
        loadRecentLocations()
    }
    
    private func loadSavedLocation() {
        if let savedData = userDefaults.data(forKey: "savedLocation"),
           let location = try? JSONDecoder().decode(Location.self, from: savedData) {
            self.currentLocation = location
            // Fetch tide data for saved location
            Task {
                await MainActor.run {
                    self.fetchTideData()
                }
            }
        }
    }
    
    private func loadRecentLocations() {
        if let savedData = userDefaults.data(forKey: "recentLocations"),
           let locations = try? JSONDecoder().decode([Location].self, from: savedData) {
            self.recentLocations = locations
        }
    }
    
    func saveLocation(_ location: Location) {
        print("Saving location: \(location.name)")
        
        // Update current location
        self.currentLocation = location
        
        // Save to UserDefaults
        if let encoded = try? JSONEncoder().encode(location) {
            userDefaults.set(encoded, forKey: "savedLocation")
            
            // Update recent locations
            if !recentLocations.contains(where: { $0.name == location.name }) {
                recentLocations.insert(location, at: 0)
                if recentLocations.count > 5 {
                    recentLocations.removeLast()
                }
                
                // Save recent locations
                if let encoded = try? JSONEncoder().encode(recentLocations) {
                    userDefaults.set(encoded, forKey: "recentLocations")
                }
            }
        }
        
        // Fetch tide data for new location
        fetchTideData()
    }
    
    func fetchTideData() {
        guard let location = currentLocation else {
            self.errorMessage = "Please select a location first"
            return
        }
        
        print("Fetching tide data for: \(location.name)")
        
        // Reset state
        self.isLoading = true
        self.errorMessage = nil
        self.tideData = []
        
        Task {
            do {
                let data = try await apiClient.fetchTideData(
                    latitude: location.latitude,
                    longitude: location.longitude
                )
                
                await MainActor.run {
                    print("Received \(data.count) tide entries")
                    self.tideData = data
                    self.isLoading = false
                    
                    if data.isEmpty {
                        self.errorMessage = "No tide data available for this location"
                    }
                }
            } catch let error as TideAPIClient.APIError {
                await MainActor.run {
                    switch error {
                    case .apiError(let message):
                        self.errorMessage = message
                    case .networkError:
                        self.errorMessage = "Network error. Please check your connection."
                    case .invalidURL:
                        self.errorMessage = "Invalid location data."
                    case .decodingError:
                        self.errorMessage = "Error processing tide data."
                    }
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    func searchLocations(_ query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        Task {
            do {
                let results = try await apiClient.searchLocations(query)
                await MainActor.run {
                    self.searchResults = results
                }
            } catch {
                print("Search error: \(error)")
                await MainActor.run {
                    self.errorMessage = "Unable to search locations. Please try again."
                }
            }
        }
    }
}

extension TideViewModel: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        
        Task {
            do {
                let placemark = try await location.fetchPlacemark()
                let newLocation = Location(
                    name: placemark.locality ?? "Unknown Location",
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                )
                await MainActor.run {
                    self.currentLocation = newLocation
                    self.fetchTideData()
                }
            } catch {
                print("Geocoding error: \(error)")
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error)")
    }
}

// Helper extension for reverse geocoding
extension CLLocation {
    func fetchPlacemark() async throws -> CLPlacemark {
        return try await withCheckedThrowingContinuation { continuation in
            CLGeocoder().reverseGeocodeLocation(self) { placemarks, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                if let placemark = placemarks?.first {
                    continuation.resume(returning: placemark)
                } else {
                    continuation.resume(throwing: NSError(domain: "Geocoding", code: -1, userInfo: [NSLocalizedDescriptionKey: "No placemark found"]))
                }
            }
        }
    }
} 

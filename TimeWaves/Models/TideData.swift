import Foundation

struct TideData: Codable, Identifiable {
    let id = UUID()
    let timestamp: Date
    let height: Double
    let type: TideType
    
    enum TideType: String, Codable {
        case high = "HIGH"
        case low = "LOW"
        case current = "CURRENT"
    }
}

struct Location: Codable, Identifiable {
    let id = UUID()
    let name: String
    let latitude: Double
    let longitude: Double
} 
import Foundation

nonisolated struct Location: Identifiable, Codable {
    let id: Int
    let city: String
    let stateRegion: String?
    let country: String
    let latitude: Double?
    let longitude: Double?

    enum CodingKeys: String, CodingKey {
        case id = "location_id"
        case city
        case stateRegion = "state_region"
        case country
        case latitude
        case longitude
    }

    var displayName: String {
        [city, stateRegion, country].compactMap { $0 }.joined(separator: ", ")
    }
}

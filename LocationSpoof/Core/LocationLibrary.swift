import CoreLocation
import Foundation

struct SavedLocation: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var latitude: Double
    var longitude: Double

    init(id: UUID = UUID(), name: String, coordinate: CLLocationCoordinate2D) {
        self.id = id
        self.name = name
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

final class LocationLibrary {
    private enum Key {
        static let favorites = "LocationSpoof.favorites"
        static let recents = "LocationSpoof.recents"
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadFavorites() -> [SavedLocation] { load(Key.favorites) }
    func loadRecents() -> [SavedLocation] { load(Key.recents) }

    func saveFavorites(_ locations: [SavedLocation]) {
        save(locations, key: Key.favorites)
    }

    func addRecent(_ location: SavedLocation) -> [SavedLocation] {
        var values = loadRecents()
        values.removeAll { distance($0.coordinate, location.coordinate) < 5 }
        values.insert(location, at: 0)
        values = Array(values.prefix(20))
        save(values, key: Key.recents)
        return values
    }

    private func load(_ key: String) -> [SavedLocation] {
        guard let data = defaults.data(forKey: key),
              let values = try? decoder.decode([SavedLocation].self, from: data) else { return [] }
        return values
    }

    private func save(_ locations: [SavedLocation], key: String) {
        guard let data = try? encoder.encode(locations) else { return }
        defaults.set(data, forKey: key)
    }

    private func distance(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> CLLocationDistance {
        CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }
}

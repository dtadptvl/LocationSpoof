import CoreLocation
import MapKit

struct PlaceResult: Identifiable {
    let id = UUID()
    let name: String
    let subtitle: String
    let coordinate: CLLocationCoordinate2D
}

struct PlaceSearchService {
    func search(query: String, near center: CLLocationCoordinate2D) async throws -> [PlaceResult] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 2, longitudeDelta: 2)
        )
        let response = try await MKLocalSearch(request: request).start()
        return response.mapItems.prefix(12).map { item in
            PlaceResult(
                name: item.name ?? "Unnamed place",
                subtitle: item.placemark.title ?? "",
                coordinate: item.placemark.coordinate
            )
        }
    }
}

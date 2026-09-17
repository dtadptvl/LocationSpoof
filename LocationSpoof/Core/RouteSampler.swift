import CoreLocation
import Foundation

struct RouteSampler {
    enum RouteError: LocalizedError {
        case insufficientPoints
        var errorDescription: String? { "Route needs at least two distinct points." }
    }

    private let points: [CLLocationCoordinate2D]
    private let cumulative: [CLLocationDistance]
    let totalDistance: CLLocationDistance

    init(points: [CLLocationCoordinate2D]) throws {
        guard points.count > 1 else { throw RouteError.insufficientPoints }
        var cumulative: [CLLocationDistance] = [0]
        var total: CLLocationDistance = 0
        for index in 1..<points.count {
            let a = CLLocation(latitude: points[index - 1].latitude, longitude: points[index - 1].longitude)
            let b = CLLocation(latitude: points[index].latitude, longitude: points[index].longitude)
            total += a.distance(from: b)
            cumulative.append(total)
        }
        guard total > 0.5 else { throw RouteError.insufficientPoints }
        self.points = points
        self.cumulative = cumulative
        self.totalDistance = total
    }

    func coordinate(at distance: CLLocationDistance) -> CLLocationCoordinate2D {
        let target = min(max(0, distance), totalDistance)
        if target >= totalDistance { return points[points.count - 1] }

        var upper = 1
        while upper < cumulative.count && cumulative[upper] < target { upper += 1 }
        let lower = max(0, upper - 1)
        let segmentStart = cumulative[lower]
        let segmentLength = max(0.001, cumulative[upper] - segmentStart)
        let ratio = (target - segmentStart) / segmentLength
        let a = points[lower]
        let b = points[upper]
        return CLLocationCoordinate2D(
            latitude: a.latitude + (b.latitude - a.latitude) * ratio,
            longitude: a.longitude + (b.longitude - a.longitude) * ratio
        )
    }

    static func jitter(_ coordinate: CLLocationCoordinate2D, radiusMeters: Double) -> CLLocationCoordinate2D {
        guard radiusMeters > 0 else { return coordinate }
        let distance = Double.random(in: 0...radiusMeters)
        let bearing = Double.random(in: 0..<(2 * .pi))
        let earthRadius = 6_371_000.0
        let lat = coordinate.latitude * .pi / 180
        let lon = coordinate.longitude * .pi / 180
        let angular = distance / earthRadius
        let newLat = asin(sin(lat) * cos(angular) + cos(lat) * sin(angular) * cos(bearing))
        let newLon = lon + atan2(sin(bearing) * sin(angular) * cos(lat), cos(angular) - sin(lat) * sin(newLat))
        return CLLocationCoordinate2D(latitude: newLat * 180 / .pi, longitude: newLon * 180 / .pi)
    }
}

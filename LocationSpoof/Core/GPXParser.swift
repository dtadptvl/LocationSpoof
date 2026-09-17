import CoreLocation
import Foundation

struct GPXParser {
    enum ParseError: LocalizedError {
        case unreadable, noTrackPoints

        var errorDescription: String? {
            switch self {
            case .unreadable: return "Could not read GPX file."
            case .noTrackPoints: return "GPX file contains no track points."
            }
        }
    }

    static func parse(url: URL) throws -> [CLLocationCoordinate2D] {
        guard let parser = XMLParser(contentsOf: url) else { throw ParseError.unreadable }
        let delegate = Delegate()
        parser.delegate = delegate
        parser.shouldResolveExternalEntities = false
        guard parser.parse() else { throw parser.parserError ?? ParseError.unreadable }
        guard delegate.points.count > 1 else { throw ParseError.noTrackPoints }
        return delegate.points
    }

    private final class Delegate: NSObject, XMLParserDelegate {
        var points: [CLLocationCoordinate2D] = []

        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
            guard elementName == "trkpt" || elementName == "rtept" || elementName == "wpt",
                  let latString = attributeDict["lat"],
                  let lonString = attributeDict["lon"],
                  let lat = Double(latString),
                  let lon = Double(lonString),
                  (-90...90).contains(lat),
                  (-180...180).contains(lon) else { return }
            points.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
        }
    }
}

import CoreLocation
import Foundation

@MainActor
final class AppModel: ObservableObject {
    enum State: Equatable {
        case needsPairing
        case ready
        case connecting
        case spoofing(CLLocationCoordinate2D)
        case error(String)

        static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.needsPairing, .needsPairing), (.ready, .ready), (.connecting, .connecting): return true
            case let (.spoofing(a), .spoofing(b)): return a.latitude == b.latitude && a.longitude == b.longitude
            case let (.error(a), .error(b)): return a == b
            default: return false
            }
        }
    }

    @Published private(set) var state: State = .needsPairing
    @Published var selectedCoordinate = CLLocationCoordinate2D(latitude: 21.0285, longitude: 105.8542)

    private let pairingStore = PairingStore()
    private let tunnel = TunnelController()
    private let location = LocationSimulationService()

    init() {
        state = pairingStore.pairingFileURL == nil ? .needsPairing : .ready
    }

    func importPairingFile(from source: URL) async {
        do {
            try pairingStore.importFile(from: source)
            state = .ready
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func startSpoofing() async {
        guard let pairingURL = pairingStore.pairingFileURL else {
            state = .needsPairing
            return
        }
        state = .connecting
        do {
            try await tunnel.ensureConnected()
            try await location.setLocation(selectedCoordinate, pairingFile: pairingURL)
            state = .spoofing(selectedCoordinate)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func stopSpoofing() async {
        do {
            try await location.clearLocation()
            state = .ready
        } catch {
            state = .error(error.localizedDescription)
        }
    }
}

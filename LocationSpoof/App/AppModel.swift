import CoreLocation
import Foundation

@MainActor
final class AppModel: ObservableObject {
    enum State: Equatable {
        case needsPairing
        case ready
        case connecting
        case spoofing(CLLocationCoordinate2D)
        case routePlaying(CLLocationCoordinate2D, Double)
        case routePaused(CLLocationCoordinate2D, Double)
        case error(String)

        static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.needsPairing, .needsPairing), (.ready, .ready), (.connecting, .connecting):
                return true
            case let (.spoofing(a), .spoofing(b)):
                return a.latitude == b.latitude && a.longitude == b.longitude
            case let (.routePlaying(a, p1), .routePlaying(b, p2)),
                 let (.routePaused(a, p1), .routePaused(b, p2)):
                return a.latitude == b.latitude && a.longitude == b.longitude && p1 == p2
            case let (.error(a), .error(b)):
                return a == b
            default:
                return false
            }
        }
    }

    @Published private(set) var state: State = .needsPairing
    @Published var selectedCoordinate = CLLocationCoordinate2D(latitude: 21.0285, longitude: 105.8542)
    @Published var selectedName = "Pinned location"
    @Published var searchQuery = ""
    @Published private(set) var searchResults: [PlaceResult] = []
    @Published private(set) var favorites: [SavedLocation] = []
    @Published private(set) var recents: [SavedLocation] = []
    @Published private(set) var routePoints: [CLLocationCoordinate2D] = []
    @Published private(set) var routeProgress: Double = 0
    @Published var routeSpeedKPH: Double = 5
    @Published var jitterMeters: Double = 0

    private let pairingStore = PairingStore()
    private let tunnel = TunnelController()
    private let location = LocationSimulationService()
    private let searchService = PlaceSearchService()
    private let library = LocationLibrary()

    private var routeTask: Task<Void, Never>?
    private var routePaused = false
    private var routeDistance: CLLocationDistance = 0

    init() {
        state = pairingStore.pairingFileURL == nil ? .needsPairing : .ready
        favorites = library.loadFavorites()
        recents = library.loadRecents()
    }

    var isSelectedFavorite: Bool {
        favorites.contains { distance($0.coordinate, selectedCoordinate) < 5 }
    }

    var hasActiveSpoof: Bool {
        switch state {
        case .spoofing, .routePlaying, .routePaused:
            return true
        default:
            return false
        }
    }

    func importPairingFile(from source: URL) async {
        do {
            try pairingStore.importFile(from: source)
            state = .ready
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func importGPX(from source: URL) async {
        let accessed = source.startAccessingSecurityScopedResource()
        defer { if accessed { source.stopAccessingSecurityScopedResource() } }

        do {
            let points = try GPXParser.parse(url: source)
            routePoints = points
            routeProgress = 0
            if let first = points.first {
                selectedCoordinate = first
                selectedName = source.deletingPathExtension().lastPathComponent
            }
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func searchPlaces() async {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        do {
            searchResults = try await searchService.search(query: query, near: selectedCoordinate)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func selectPlace(_ result: PlaceResult) {
        selectedCoordinate = result.coordinate
        selectedName = result.name
        searchResults = []
        searchQuery = result.name
    }

    func selectSaved(_ saved: SavedLocation) {
        selectedCoordinate = saved.coordinate
        selectedName = saved.name
    }

    func toggleFavorite() {
        if let index = favorites.firstIndex(where: { distance($0.coordinate, selectedCoordinate) < 5 }) {
            favorites.remove(at: index)
        } else {
            favorites.insert(SavedLocation(name: selectedName, coordinate: selectedCoordinate), at: 0)
        }
        library.saveFavorites(favorites)
    }

    func startSpoofing() async {
        routeTask?.cancel()
        routeTask = nil
        routePaused = false

        guard let pairingURL = pairingStore.pairingFileURL else {
            state = .needsPairing
            return
        }

        state = .connecting
        do {
            try await tunnel.ensureConnected()
            try await location.setLocation(selectedCoordinate, pairingFile: pairingURL)
            state = .spoofing(selectedCoordinate)
            recents = library.addRecent(SavedLocation(name: selectedName, coordinate: selectedCoordinate))
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func startRoute() async {
        routeTask?.cancel()
        routeTask = nil
        routePaused = false
        routeDistance = 0
        routeProgress = 0

        guard let pairingURL = pairingStore.pairingFileURL else {
            state = .needsPairing
            return
        }

        do {
            let sampler = try RouteSampler(points: routePoints)
            state = .connecting
            try await tunnel.ensureConnected()
            let first = sampler.coordinate(at: 0)
            try await location.setLocation(first, pairingFile: pairingURL)
            selectedCoordinate = first
            state = .routePlaying(first, 0)
            routeTask = Task { [weak self] in
                await self?.runRoute(sampler: sampler, pairingURL: pairingURL)
            }
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func pauseRoute() {
        guard case .routePlaying = state else { return }
        routePaused = true
        state = .routePaused(selectedCoordinate, routeProgress)
    }

    func resumeRoute() {
        guard case .routePaused = state else { return }
        routePaused = false
        state = .routePlaying(selectedCoordinate, routeProgress)
    }

    func stopSpoofing() async {
        routeTask?.cancel()
        routeTask = nil
        routePaused = false

        do {
            try await location.clearLocation()
            routeProgress = 0
            state = pairingStore.pairingFileURL == nil ? .needsPairing : .ready
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    private func runRoute(sampler: RouteSampler, pairingURL: URL) async {
        var lastTick = Date()

        while !Task.isCancelled {
            if routePaused {
                lastTick = Date()
                try? await Task.sleep(for: .milliseconds(200))
                continue
            }

            let now = Date()
            let elapsed = max(0, now.timeIntervalSince(lastTick))
            lastTick = now
            routeDistance += max(0.1, routeSpeedKPH / 3.6) * elapsed

            let base = sampler.coordinate(at: routeDistance)
            let actual = RouteSampler.jitter(base, radiusMeters: jitterMeters)

            do {
                try await location.setLocation(actual, pairingFile: pairingURL)
            } catch {
                if !Task.isCancelled { state = .error(error.localizedDescription) }
                routeTask = nil
                return
            }

            selectedCoordinate = actual
            routeProgress = min(1, routeDistance / sampler.totalDistance)
            state = .routePlaying(actual, routeProgress)

            if routeDistance >= sampler.totalDistance {
                routeProgress = 1
                state = .spoofing(actual)
                recents = library.addRecent(SavedLocation(name: selectedName, coordinate: actual))
                routeTask = nil
                return
            }

            try? await Task.sleep(for: .milliseconds(500))
        }
    }

    private func distance(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> CLLocationDistance {
        CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }
}

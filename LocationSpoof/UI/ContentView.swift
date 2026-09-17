import MapKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showPairingImporter = false
    @State private var showGPXImporter = false
    @State private var camera: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 21.0285, longitude: 105.8542),
            span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
        )
    )

    private var gpxType: UTType { UTType(filenameExtension: "gpx") ?? .xml }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    pairingSection
                    searchSection
                    mapSection
                    statusView
                    locationControls
                    routeSection
                }
                .padding()
            }
            .navigationTitle("LocationSpoof")
            .toolbar { locationsMenu }
        }
    }

    private var pairingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Device Pairing", systemImage: "link.badge.plus")
                .font(.headline)

            Text("Import a pairing .plist file before starting location spoofing.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                showPairingImporter = true
            } label: {
                Label("Import Pairing File", systemImage: "doc.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .fileImporter(isPresented: $showPairingImporter, allowedContentTypes: [.item]) { result in
                guard case let .success(url) = result else { return }
                guard url.pathExtension.lowercased() == "plist" else { return }
                Task { await model.importPairingFile(from: url) }
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var searchSection: some View {
        VStack(spacing: 8) {
            HStack {
                TextField("Search place or address", text: $model.searchQuery)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.search)
                    .onSubmit { Task { await model.searchPlaces() } }

                Button("Search") { Task { await model.searchPlaces() } }
                    .buttonStyle(.bordered)
            }

            if !model.searchResults.isEmpty {
                VStack(spacing: 0) {
                    ForEach(model.searchResults) { result in
                        Button {
                            model.selectPlace(result)
                            focus(result.coordinate)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.name).font(.headline)
                                if !result.subtitle.isEmpty {
                                    Text(result.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                }
                .padding(.horizontal, 10)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var mapSection: some View {
        MapReader { proxy in
            Map(position: $camera) {
                Marker(model.selectedName, coordinate: model.selectedCoordinate)

                if model.routePoints.count > 1 {
                    MapPolyline(coordinates: model.routePoints)
                        .stroke(.blue, lineWidth: 4)
                }
            }
            .frame(height: 360)
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .onTapGesture { point in
                if let coordinate = proxy.convert(point, from: .local) {
                    model.selectedCoordinate = coordinate
                    model.selectedName = "Pinned location"
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var statusView: some View {
        Group {
            switch model.state {
            case .needsPairing:
                Label("Pairing file required", systemImage: "doc.badge.plus")
            case .ready:
                Label("Ready", systemImage: "checkmark.circle")
            case .connecting:
                ProgressView("Connecting local tunnel…")
            case let .spoofing(coordinate):
                Label(
                    String(format: "Spoofing %.5f, %.5f", coordinate.latitude, coordinate.longitude),
                    systemImage: "location.fill"
                )
            case let .routePlaying(_, progress):
                Label("Route playing · \(Int(progress * 100))%", systemImage: "figure.walk.motion")
            case let .routePaused(_, progress):
                Label("Route paused · \(Int(progress * 100))%", systemImage: "pause.circle")
            case let .error(message):
                Label(message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var locationControls: some View {
        HStack {
            Button(model.isSelectedFavorite ? "Unfavorite" : "Favorite") {
                model.toggleFavorite()
            }
            .buttonStyle(.bordered)

            Spacer()

            if model.hasActiveSpoof {
                Button("Stop") { Task { await model.stopSpoofing() } }
                    .buttonStyle(.borderedProminent)
            } else {
                Button("Start") { Task { await model.startSpoofing() } }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.state == .needsPairing || model.state == .connecting)
            }
        }
    }

    private var routeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Route", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                    .font(.headline)
                Spacer()
                Button("Import GPX") { showGPXImporter = true }
                    .buttonStyle(.bordered)
                    .fileImporter(isPresented: $showGPXImporter, allowedContentTypes: [gpxType, .xml]) { result in
                        guard case let .success(url) = result else { return }
                        Task { await model.importGPX(from: url) }
                    }
            }

            if model.routePoints.count > 1 {
                Text("\(model.routePoints.count) points")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ProgressView(value: model.routeProgress)

                HStack {
                    Text("Speed")
                    Slider(value: $model.routeSpeedKPH, in: 1...100, step: 1)
                    Text("\(Int(model.routeSpeedKPH)) km/h")
                        .monospacedDigit()
                        .frame(width: 72, alignment: .trailing)
                }

                HStack {
                    Text("Jitter")
                    Slider(value: $model.jitterMeters, in: 0...10, step: 0.5)
                    Text(String(format: "%.1f m", model.jitterMeters))
                        .monospacedDigit()
                        .frame(width: 54, alignment: .trailing)
                }

                HStack {
                    switch model.state {
                    case .routePlaying:
                        Button("Pause") { model.pauseRoute() }
                            .buttonStyle(.borderedProminent)
                    case .routePaused:
                        Button("Resume") { model.resumeRoute() }
                            .buttonStyle(.borderedProminent)
                    default:
                        Button("Play Route") { Task { await model.startRoute() } }
                            .buttonStyle(.borderedProminent)
                            .disabled(model.state == .needsPairing || model.state == .connecting)
                    }
                }
            } else {
                Text("Import a GPX track or route to simulate movement.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    @ToolbarContentBuilder
    private var locationsMenu: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                if !model.favorites.isEmpty {
                    Section("Favorites") {
                        ForEach(model.favorites) { saved in
                            Button(saved.name) {
                                model.selectSaved(saved)
                                focus(saved.coordinate)
                            }
                        }
                    }
                }

                if !model.recents.isEmpty {
                    Section("Recent") {
                        ForEach(model.recents) { saved in
                            Button(saved.name) {
                                model.selectSaved(saved)
                                focus(saved.coordinate)
                            }
                        }
                    }
                }
            } label: {
                Label("Locations", systemImage: "star")
            }
        }
    }

    private func focus(_ coordinate: CLLocationCoordinate2D) {
        camera = .region(
            MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
            )
        )
    }
}

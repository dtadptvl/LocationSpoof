import MapKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showImporter = false
    @State private var camera: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 21.0285, longitude: 105.8542),
            span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
        )
    )

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                MapReader { proxy in
                    Map(position: $camera) {
                        Marker("Spoof location", coordinate: model.selectedCoordinate)
                    }
                    .mapControls { MapCompass(); MapScaleView() }
                    .onTapGesture { point in
                        if let coordinate = proxy.convert(point, from: .local) {
                            model.selectedCoordinate = coordinate
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))

                statusView

                HStack {
                    Button("Import Pairing File") { showImporter = true }
                        .buttonStyle(.bordered)
                    Spacer()
                    if case .spoofing = model.state {
                        Button("Stop") { Task { await model.stopSpoofing() } }
                            .buttonStyle(.borderedProminent)
                    } else {
                        Button("Start Spoofing") { Task { await model.startSpoofing() } }
                            .buttonStyle(.borderedProminent)
                            .disabled(model.state == .needsPairing || model.state == .connecting)
                    }
                }
            }
            .padding()
            .navigationTitle("LocationSpoof")
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.data]) { result in
            guard case let .success(url) = result else { return }
            Task { await model.importPairingFile(from: url) }
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch model.state {
        case .needsPairing: Label("Pairing file required", systemImage: "doc.badge.plus")
        case .ready: Label("Ready", systemImage: "checkmark.circle")
        case .connecting: ProgressView("Connecting local tunnel…")
        case let .spoofing(coordinate):
            Label(String(format: "Spoofing %.5f, %.5f", coordinate.latitude, coordinate.longitude), systemImage: "location.fill")
        case let .error(message):
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
        }
    }
}

import CoreLocation
import Foundation
import idevice

final class LocationSimulationService {
    enum ServiceError: LocalizedError {
        case invalidIP, pairingRead, providerCreate, remoteServer, simulationCreate, setFailed, clearFailed

        var errorDescription: String? {
            switch self {
            case .invalidIP: return "Invalid local device IP."
            case .pairingRead: return "Could not read pairing file."
            case .providerCreate: return "Could not create local device tunnel."
            case .remoteServer: return "Could not connect to RemoteServer."
            case .simulationCreate: return "Could not create location simulation service."
            case .setFailed: return "Could not set simulated location."
            case .clearFailed: return "Could not clear simulated location."
            }
        }
    }

    private let queue = DispatchQueue(label: "com.dtadptvl.locationspoof.location", qos: .userInitiated)
    private var adapter: OpaquePointer?
    private var handshake: OpaquePointer?
    private var remoteServer: OpaquePointer?
    private var simulation: OpaquePointer?
    private let targetIP = "10.7.0.1"

    deinit { cleanup() }

    func setLocation(_ coordinate: CLLocationCoordinate2D, pairingFile: URL) async throws {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    try self.setLocationSync(coordinate, pairingFile: pairingFile)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func clearLocation() async throws {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                guard let simulation = self.simulation else {
                    self.cleanup()
                    continuation.resume()
                    return
                }

                let error = location_simulation_clear(simulation)
                self.cleanup()

                if let error {
                    idevice_error_free(error)
                    continuation.resume(throwing: ServiceError.clearFailed)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func setLocationSync(_ coordinate: CLLocationCoordinate2D, pairingFile: URL) throws {
        if let simulation {
            if let error = location_simulation_set(simulation, coordinate.latitude, coordinate.longitude) {
                idevice_error_free(error)
                cleanup()
            } else {
                return
            }
        }

        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = in_port_t(49152).bigEndian
        guard targetIP.withCString({ inet_pton(AF_INET, $0, &address.sin_addr) }) == 1 else {
            throw ServiceError.invalidIP
        }

        var pairing: OpaquePointer?
        if let error = pairingFile.path.withCString({ rp_pairing_file_read($0, &pairing) }) {
            idevice_error_free(error)
            throw ServiceError.pairingRead
        }
        guard let pairing else { throw ServiceError.pairingRead }
        defer { rp_pairing_file_free(pairing) }

        let createError = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                tunnel_create_rppairing(
                    $0,
                    socklen_t(MemoryLayout<sockaddr_in>.stride),
                    "LocationSpoof",
                    pairing,
                    nil,
                    nil,
                    &adapter,
                    &handshake
                )
            }
        }
        if let createError {
            idevice_error_free(createError)
            cleanup()
            throw ServiceError.providerCreate
        }

        if let error = remote_server_connect_rsd(adapter, handshake, &remoteServer) {
            idevice_error_free(error)
            cleanup()
            throw ServiceError.remoteServer
        }

        if let error = location_simulation_new(remoteServer, &simulation) {
            idevice_error_free(error)
            cleanup()
            throw ServiceError.simulationCreate
        }
        remoteServer = nil

        if let error = location_simulation_set(simulation, coordinate.latitude, coordinate.longitude) {
            idevice_error_free(error)
            cleanup()
            throw ServiceError.setFailed
        }
    }

    private func cleanup() {
        if let simulation {
            location_simulation_free(simulation)
            self.simulation = nil
        }
        if let remoteServer {
            remote_server_free(remoteServer)
            self.remoteServer = nil
        }
        if let handshake {
            rsd_handshake_free(handshake)
            self.handshake = nil
        }
        if let adapter {
            adapter_free(adapter)
            self.adapter = nil
        }
    }
}

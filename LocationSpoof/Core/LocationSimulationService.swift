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

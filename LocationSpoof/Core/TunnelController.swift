import Foundation
import NetworkExtension

@MainActor
final class TunnelController {
    enum TunnelError: LocalizedError {
        case configuration, timeout
        var errorDescription: String? {
            switch self {
            case .configuration: return "Could not configure the local tunnel."
            case .timeout: return "Local tunnel did not connect in time."
            }
        }
    }

    private let providerBundleID = "com.dtadptvl.LocationSpoof.LocalTunnel"

    func ensureConnected() async throws {
        let manager = try await loadOrCreateManager()
        if manager.connection.status == .connected { return }
        try manager.connection.startVPNTunnel()
        for _ in 0..<50 {
            if manager.connection.status == .connected { return }
            if manager.connection.status == .invalid { throw TunnelError.configuration }
            try await Task.sleep(for: .milliseconds(100))
        }
        throw TunnelError.timeout
    }

    private func loadOrCreateManager() async throws -> NETunnelProviderManager {
        let managers = try await NETunnelProviderManager.loadAllFromPreferences()
        if let existing = managers.first(where: { ($0.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == providerBundleID }) {
            return existing
        }
        let manager = NETunnelProviderManager()
        let proto = NETunnelProviderProtocol()
        proto.providerBundleIdentifier = providerBundleID
        proto.serverAddress = "Local device tunnel"
        proto.providerConfiguration = ["TunnelIfaceIP": "10.7.1.1/32", "TunnelPeerIP": "10.7.0.1/32"]
        manager.protocolConfiguration = proto
        manager.localizedDescription = "LocationSpoof Local Tunnel"
        manager.isEnabled = true
        try await manager.saveToPreferences()
        try await manager.loadFromPreferences()
        return manager
    }
}

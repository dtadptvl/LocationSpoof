import NetworkExtension

final class PacketTunnelProvider: NEPacketTunnelProvider {
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "10.7.0.1")
        let ipv4 = NEIPv4Settings(addresses: ["10.7.1.1"], subnetMasks: ["255.255.255.255"])
        ipv4.includedRoutes = [NEIPv4Route(destinationAddress: "10.7.0.1", subnetMask: "255.255.255.255")]
        ipv4.excludedRoutes = [.default()]
        settings.ipv4Settings = ipv4
        setTunnelNetworkSettings(settings) { [weak self] error in
            guard error == nil else { completionHandler(error); return }
            self?.pumpPackets()
            completionHandler(nil)
        }
    }

    private func pumpPackets() {
        packetFlow.readPackets { [weak self] packets, protocols in
            guard let self else { return }
            var packets = packets
            for i in packets.indices where protocols[i].int32Value == AF_INET && packets[i].count >= 20 {
                packets[i].withUnsafeMutableBytes { bytes in
                    guard let words = bytes.baseAddress?.assumingMemoryBound(to: UInt32.self) else { return }
                    let source = words[3]
                    words[3] = words[4]
                    words[4] = source
                }
            }
            self.packetFlow.writePackets(packets, withProtocols: protocols)
            self.pumpPackets()
        }
    }
}

import Foundation

final class PairingStore {
    private let fileManager = FileManager.default
    private let filename = "device-pairing.plist"
    private let bundledResourceName = "pairingFile"

    var pairingFileURL: URL? {
        let stored = storageDirectory.appendingPathComponent(filename)
        if fileManager.fileExists(atPath: stored.path) {
            return stored
        }

        return Bundle.main.url(forResource: bundledResourceName, withExtension: "plist")
    }

    func importFile(from source: URL) throws {
        let accessed = source.startAccessingSecurityScopedResource()
        defer { if accessed { source.stopAccessingSecurityScopedResource() } }

        try fileManager.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
        let destination = storageDirectory.appendingPathComponent(filename)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: source, to: destination)
    }

    private var storageDirectory: URL {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LocationSpoof", isDirectory: true)
    }
}

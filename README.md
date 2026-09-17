# LocationSpoof

Minimal iOS device-level location simulator with an integrated local-only Packet Tunnel. Target: iOS 17.4+.

## Architecture

- SwiftUI + MapKit UI.
- Pairing file stored in Application Support.
- `LocationSimulationService` owns the complete idevice/RSD simulation lifecycle.
- `LocalTunnel` routes only `10.7.0.1/32`; normal Internet traffic is excluded from the tunnel.
- No per-app GPS claim: device-level simulation is global on stock iOS.

## Build

Requirements: Xcode, XcodeGen, curl, and a provisioning profile with the Network Extension `packet-tunnel-provider` capability for on-device use.

```sh
./scripts/bootstrap-vendor.sh
xcodegen generate
open LocationSpoof.xcodeproj
```

`bootstrap-vendor.sh` downloads `idevice.h` and `libidevice_ffi.a` from pinned StikDebug commit `94bc9e8cf3b41f32f125f046abf33d913f4e1b2d`.

CI performs an unsigned device build to catch compile/link/configuration regressions.

## Current scope

V1 implements pairing import, integrated local tunnel, map coordinate selection, start spoofing, update spoofed coordinate, and clear spoofing. Route/GPX simulation and search/favorites are intentionally deferred until the core path is stable.

## License / attribution

See `NOTICE.md`. Code derived from StikDebug carries AGPL-3.0 obligations.

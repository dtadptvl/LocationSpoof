# Attribution

LocationSpoof's initial device-location simulation bridge is derived from StikDebug (https://github.com/StikDebug/StikDebug), licensed under AGPL-3.0.

The local packet-tunnel design is independently implemented against Apple's NetworkExtension API after studying the routing behavior used by LocalDevVPN. No LocalDevVPN source file is copied into this repository.

The pinned `libidevice_ffi.a` and `idevice.h` are downloaded from StikDebug commit `94bc9e8cf3b41f32f125f046abf33d913f4e1b2d` during bootstrap/build and retain their upstream licensing obligations.

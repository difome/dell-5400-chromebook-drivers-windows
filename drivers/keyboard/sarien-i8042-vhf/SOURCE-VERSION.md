# SarienI8042 v0.1.0 source snapshot

This tree contains the source corresponding to the initial unsplit driver
release, `SarienI8042-Release-x64.zip`, built on 2026-10-08.

It predates the separate ActionKeys and FunctionKeys packages. The Chromebook
top row is emitted as consumer/action usages, including the original Snapshot
consumer usage. The later Print Screen correction and FunctionKeys build mode
are intentionally not present.

The project keeps `Inf2CatUseLocalTime` enabled so the v0.1 package can still be
rebuilt after its original release date; this changes build tooling only, not
the driver input behavior.

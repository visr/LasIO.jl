# Changelog

## [Unreleased]

## [0.2.1] - 2018-09-16
### Fixed
- Fixed `load` for LAZ files by updating type signature

## [0.2.0] - 2018-08-17
### Fixed
- Fixed all deprecation warnings in julia 0.7

### Changed
- Minimum supported release is now julia 0.7
- `epsg_code` no longer returns a Nullable, but a `UInt16`, or `nothing` if not present

## [0.1.0] - 2018-08-15
Final release with julia 0.6 support.
### Fixed
- `scan_angle` is changed from `UInt8` to `Int8` ([4c4ad9](https://github.com/visr/LasIO.jl/commit/4c4ad96ecb590fea73b945e03e605d72edccce09))
### Added
- Include setting of SRS by ESPG-code for projected systems in meters ([#9](https://github.com/visr/LasIO.jl/pull/9))
- Streaming / memory map support ([#10](https://github.com/visr/LasIO.jl/pull/10))

## [0.0.1] - 2017-08-22
### Added
- Registered the first version of LasIO.jl

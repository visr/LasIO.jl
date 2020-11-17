|                          **Build Status**                          |
|:------------------------------------------------------------------:|
| [![Actions Status](https://github.com/msbahal/LasIO.jl/workflows/Linux/badge.svg)](https://github.com/msbahal/LasIO.jl/actions) [![Actions Status](https://github.com/msbahal/LasIO.jl/workflows/Windows/badge.svg)](https://github.com/msbahal/LasIO.jl/actions) |


# LasIO

Julia package for reading and writing the LAS lidar format.

This is a pure Julia package for reading and writing ASPRS `.las` files. Currently all LAS versions 1.1 - 1.4 and point formats 0 - 10 are semi-supported. By semi-supported, we mean that we do not read or write the waveform data.

TODO - Support for Waveform data is future work.

If the file fits into memory, it can be loaded using

```julia
using FileIO, LasIO
header, points = load("test.las")
```

where `header` is of type `LasHeader`, and, if it is point format 3, `points` is a `Vector{LasPoint3}`. `LasPoint3` is an immutable that directly corresponds to the binary data in the LAS file. Use functions like `xcoord(p::LasPoint, header::LasHeader)` to take out the desired items in the point.

If the file does not fit into memory, it can be memory mapped using

```julia
using FileIO, LasIO
header, points = load("test.las", mmap=true)
```

where `points` is now a memory mapped `PointVector{LasPoint3}` which behaves in the same way as the `Vector{LasPoint3}`, but reads the points on the fly from disk when indexed, not allocating the complete vector beforehand.

See `test/runtests.jl` for other usages.

## LAZ support
LasIO comes with laszip which will be used to read/write laz files just like LAS file. There is no need for LazIO anymore.
TODO - build the `laszip` instead of having the executable sitting there.

```julia
using FileIO, LasIO
header, points = load("test.laz")
```

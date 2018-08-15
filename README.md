# LasIO

[![Build Status](https://travis-ci.org/visr/LasIO.jl.svg?branch=master)](https://travis-ci.org/visr/LasIO.jl)
[![Build status](https://ci.appveyor.com/api/projects/status/github/visr/LasIO.jl?svg=true&branch=master)](https://ci.appveyor.com/project/visr/lasio-jl/branch/master)

Julia package for reading and writing the LAS lidar format.

This is a pure Julia alternative to [LibLAS.jl](https://github.com/visr/LibLAS.jl) or [Laszip.jl](https://github.com/joa-quim/Laszip.jl). Currently only LAS versions 1.1 - 1.3 and point formats 0 - 3 are supported. For LAZ support see below.

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
The compressed LAZ format is supported, but requires the user to make sure the `laszip` executable can be found in the PATH. LAZ files are piped through `laszip` to provide reading and writing capability. `laszip` is not distributed with this package. One way to get it is to download `LAStools` from https://rapidlasso.com/. The LAStools ZIP file already contains `laszip.exe` for Windows, for Linux or Mac it needs to be compiled first. When this is done this should work just like with LAS:

```julia
using FileIO, LasIO
header, points = load("test.laz")
```

Besides piping through `laszip`, more complete LAZ support is in the works at https://github.com/evetion/LazIO.jl.

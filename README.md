# LasIO

[![Build Status](https://travis-ci.org/visr/LasIO.jl.svg?branch=master)](https://travis-ci.org/visr/LasIO.jl)

Julia package for reading and writing the LAS lidar format.

Currently unregistered, install using
```julia
Pkg.clone("https://github.com/visr/LasIO.jl.git")
```

This is a pure Julia alternative to [LibLAS.jl](https://github.com/visr/LibLAS.jl) or [Laszip.jl](https://github.com/joa-quim/Laszip.jl). Unlike those it does not support the compressed LAZ format. Furthermore currently only LAS versions 1.1 - 1.3 and point formats 0 - 3 are supported.

If the file fits into memory, it can be loaded using

```julia
using LasIO
header, points = load("test.las")
```

where `header` is of type `LasHeader`, and, if it is point format 3, `points` is a `Vector{LasPoint3}`. `LasPoint3` is an immutable that directly corresponds to the binary data in the LAS file. Use functions like `xcoord(p::LasPoint, header::LasHeader)` to take out the desired items in the point.

See `test/runtests.jl` for other usages.

# LasIO

[![Build Status](https://travis-ci.org/visr/LasIO.jl.svg?branch=master)](https://travis-ci.org/visr/LasIO.jl)
[![Build status](https://ci.appveyor.com/api/projects/status/github/visr/LasIO.jl?svg=true&branch=master)](https://ci.appveyor.com/project/visr/lasio-jl/branch/master)

Julia package for reading and writing the LAS lidar format.

This is a pure Julia alternative to [LibLAS.jl](https://github.com/visr/LibLAS.jl) or [Laszip.jl](https://github.com/joa-quim/Laszip.jl). Currently only LAS versions 1.1 - 1.3 and point formats 0 - 3 are supported. For LAZ support see below.

## Usage

```julia
julia> using LasIO
julia> s = LasIO.Source("test/srs.las")
LasIO.Source(Data.Schema:
rows: 10  cols: 10
Columns:
 "x"                   Int32  
 "y"                   Int32  
 "z"                   Int32  
 "intensity"           UInt16 
 "flag_byte"           UInt8  
 "raw_classification"  UInt8  
 "scan_angle"          Int8   
 "user_data"           UInt8  
 "pt_src_id"           UInt16 
 "gps_time"            Float64, LasHeader with 10 points.
, IOStream(<file test/srs.las>), "test/srs.las", 759)

julia> using DataStreams, DataFrames
julia> d = Data.stream!(s, DataFrame);
julia> Data.close!(d)
10×10 DataFrames.DataFrame
│ Row │ x         │ y         │ z      │ intensity │ flag_byte │ raw_classification │ scan_angle │ user_data │ pt_src_id │ gps_time  │
├─────┼───────────┼───────────┼────────┼───────────┼───────────┼────────────────────┼────────────┼───────────┼───────────┼───────────┤
│ 1   │ 2.89814e5 │ 4.32098e6 │ 170.76 │ 0x0104    │ 0x30      │ 0x02               │ 0          │ 0x00      │ 0x0000    │ 4.99451e5 │
│ 2   │ 2.89815e5 │ 4.32098e6 │ 170.76 │ 0x0118    │ 0x30      │ 0x02               │ 0          │ 0x00      │ 0x0000    │ 4.99451e5 │
│ 3   │ 2.89815e5 │ 4.32098e6 │ 170.75 │ 0x0118    │ 0x30      │ 0x02               │ 0          │ 0x00      │ 0x0000    │ 4.99451e5 │
│ 4   │ 2.89816e5 │ 4.32098e6 │ 170.74 │ 0x0118    │ 0x30      │ 0x02               │ 0          │ 0x00      │ 0x0000    │ 4.99451e5 │
│ 5   │ 2.89816e5 │ 4.32098e6 │ 170.68 │ 0x0104    │ 0x30      │ 0x02               │ 0          │ 0x00      │ 0x0000    │ 4.99451e5 │
│ 6   │ 2.89817e5 │ 4.32098e6 │ 170.66 │ 0x00f0    │ 0x30      │ 0x02               │ 0          │ 0x00      │ 0x0000    │ 4.99451e5 │
│ 7   │ 289817.0  │ 4.32098e6 │ 170.63 │ 0x00f0    │ 0x30      │ 0x02               │ 0          │ 0x00      │ 0x0000    │ 4.99451e5 │
│ 8   │ 2.89818e5 │ 4.32098e6 │ 170.62 │ 0x0118    │ 0x30      │ 0x02               │ 0          │ 0x00      │ 0x0000    │ 4.99451e5 │
│ 9   │ 289818.0  │ 4.32098e6 │ 170.61 │ 0x0118    │ 0x30      │ 0x02               │ 0          │ 0x00      │ 0x0000    │ 4.99451e5 │
│ 10  │ 2.89819e5 │ 4.32098e6 │ 170.58 │ 0x0104    │ 0x30      │ 0x02               │ 0          │ 0x00      │ 0x0000    │ 4.99451e5 │

julia> Data.reset!(s)
julia> d = Data.stream!(s, LasIO.Sink, "test_final.las");
julia> Data.close!(d)
LasIO.Sink{LasIO.LasPoint1}(IOStream(<file test_final.las>), LasHeader with 10 points.
, LasIO.LasPoint1)
```

### Legacy API

For backwards compatibility, the legacy API is still provided.

```julia
using FileIO, LasIO
header, points = load("test.las")
```

where `header` is of type `LasHeader`, and, if it is point format 3, `points` is a `Vector{LasPoint3}`. `LasPoint3` is an immutable that directly corresponds to the binary data in the LAS file. Use functions like `xcoord(p::LasPoint, header::LasHeader)` to take out the desired items in the point.

See `test/runtests.jl` for other usages.

## LAZ support
The compressed LAZ format is supported, but requires the user to make sure the `laszip` executable can be found in the PATH. LAZ files are piped through `laszip` to provide reading and writing capability. `laszip` is not distributed with this package. One way to get it is to download `LAStools` from https://rapidlasso.com/. The LAStools ZIP file already contains `laszip.exe` for Windows, for Linux or Mac it needs to be compiled first. When this is done this should work just like with LAS:

```julia
using FileIO, LasIO
header, points = load("test.laz")
```

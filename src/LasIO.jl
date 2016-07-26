module LasIO

using Compat
import Compat.String
using FileIO
using FixedPointNumbers # used for color
using GeometryTypes # for conversion

export
    # Types
    LasHeader,
    LasPoint,
    LasPoint0,
    LasPoint1,
    LasPoint2,
    LasPoint3,

    # Functions on LasHeader
    update!,

    # Functions on LasPoint
    return_number,
    number_of_returns,
    scan_direction,
    edge_of_flight_line,
    classification,
    synthetic,
    key_point,
    withheld,
    xcoord,
    ycoord,
    zcoord

include("header.jl")
include("point.jl")
include("util.jl")
include("fileio.jl")

end # module

__precompile__()

module LasIO

using Compat
import Compat.String
using FileIO
using ColorTypes
using GeometryTypes # for conversion

export
    # Types
    LasHeader,
    LasVariableLengthRecord,
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
    zcoord,
    intensity,
    scan_angle,
    user_data,
    pt_src_id,

    # extended from ColorTypes
    red,
    green,
    blue,
    RGB

include("vlrs.jl")
include("header.jl")
include("point.jl")
include("util.jl")
include("fileio.jl")

function __init__()
    # these should eventually go in
    # https://github.com/JuliaIO/FileIO.jl/blob/master/src/registry.jl
    add_format(format"LAS", "LASF", ".las", [:LasIO])
end

end # module

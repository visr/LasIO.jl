
"Abstract type for ASPRS LAS point data record formats 0 - 3"
abstract type LasPoint end

"""
Custom PointVector struct for memory mapped LasPoints.
Inspiration taken from UnalignedVector.jl
and extended it with custom indexing and packing.
"""
struct PointVector{T} <: AbstractArray{T,1}
    io::IOBuffer
    n::Int
    pointsize::Int

    function PointVector{T}(data::Vector{UInt8}, pointsize::Integer) where {T}
        n = length(data) ÷ pointsize

        # IOBuffer takes (data, readable, writable)
        new{T}(IOBuffer(data; read=true, write=false), n, pointsize)
    end
end

Base.IndexStyle(::Type{PointVector{T}}) where {T} = IndexLinear()
Base.length(pv::PointVector) = pv.n
Base.size(pv::PointVector) = (length(pv),)

function Base.getindex(pv::PointVector{T}, i::Int) where {T}
    offset = (i-1) * pv.pointsize  # seeking uses 0 based indexing!
    position(pv.io) != offset && seek(pv.io, offset)
    read(pv.io, T)
end

function Base.setindex!(pv::PointVector{T}, val::T, i::Int) where {T}
    # offset = (i-1) * pv.pointsize  # seeking uses 0 based indexing!
    # position(pv.io) != offset && seek(pv.io, offset)
    # write(pv.io, val)
    error("Can't write to read only memory mapped file.")
end

function Base.show(io::IO, pointdata::AbstractVector{<:LasPoint})
    n = size(pointdata, 1)
    println(io, "$(typeof(pointdata)) with $n points.")
end

"ASPRS LAS point data record format 0"
@gen_io struct LasPoint0 <: LasPoint
    x::Int32
    y::Int32
    z::Int32
    intensity::UInt16
    flag_byte::UInt8
    raw_classification::UInt8
    scan_angle::Int8
    user_data::UInt8
    pt_src_id::UInt16
end

"ASPRS LAS point data record format 1"
@gen_io struct LasPoint1 <: LasPoint
    x::Int32
    y::Int32
    z::Int32
    intensity::UInt16
    flag_byte::UInt8
    raw_classification::UInt8
    scan_angle::Int8
    user_data::UInt8
    pt_src_id::UInt16
    gps_time::Float64
end

"ASPRS LAS point data record format 2"
@gen_io struct LasPoint2 <: LasPoint
    x::Int32
    y::Int32
    z::Int32
    intensity::UInt16
    flag_byte::UInt8
    raw_classification::UInt8
    scan_angle::Int8
    user_data::UInt8
    pt_src_id::UInt16
    red::N0f16
    green::N0f16
    blue::N0f16
end

"ASPRS LAS point data record format 3"
@gen_io struct LasPoint3 <: LasPoint
    x::Int32
    y::Int32
    z::Int32
    intensity::UInt16
    flag_byte::UInt8
    raw_classification::UInt8
    scan_angle::Int8
    user_data::UInt8
    pt_src_id::UInt16
    gps_time::Float64
    red::N0f16
    green::N0f16
    blue::N0f16
end

# for convenience in function signatures
const LasPointColor = Union{LasPoint2,LasPoint3}
const LasPointTime = Union{LasPoint1,LasPoint3}

function Base.show(io::IO, p::LasPoint)
    x = Int(p.x)
    y = Int(p.y)
    z = Int(p.z)
    cl = Int(classification(p))
    println(io, "LasPoint(x=$x, y=$y, z=$z, classification=$cl)")
end

# Extend base by enabling reading/writing relevant FixedPointNumbers from IO.
Base.read(io::IO, ::Type{N0f16}) = reinterpret(N0f16, read(io, UInt16))
Base.write(io::IO, t::N0f16) = write(io, reinterpret(UInt16, t))

# functions for IO on points

"X coordinate (Float64), apply scale and offset according to the header"
xcoord(p::LasPoint, h::LasHeader) = muladd(p.x, h.x_scale, h.x_offset)
"Y coordinate (Float64), apply scale and offset according to the header"
ycoord(p::LasPoint, h::LasHeader) = muladd(p.y, h.y_scale, h.y_offset)
"Z coordinate (Float64), apply scale and offset according to the header"
zcoord(p::LasPoint, h::LasHeader) = muladd(p.z, h.z_scale, h.z_offset)

# inverse functions of the above
"X value (Int32), as represented in the point data, reversing the offset and scale from the header"
xcoord(x::Real, h::LasHeader) = round(Int32, (x - h.x_offset) / h.x_scale)
"Y value (Int32), as represented in the point data, reversing the offset and scale from the header"
ycoord(y::Real, h::LasHeader) = round(Int32, (y - h.y_offset) / h.y_scale)
"Z value (Int32), as represented in the point data, reversing the offset and scale from the header"
zcoord(z::Real, h::LasHeader) = round(Int32, (z - h.z_offset) / h.z_scale)

# functions to access common LasPoint fields
"Integer representation of the pulse return magnitude."
intensity(p::LasPoint) = p.intensity
"Angle at which the laser point was output, including the roll of the aircraft."
scan_angle(p::LasPoint) = p.scan_angle
"This field may be used at the user’s discretion."
user_data(p::LasPoint) = p.user_data
"This value indicates the file from which this point originated."
pt_src_id(p::LasPoint) = p.pt_src_id

# time
# 1.3159648e9 = 315964800.0 + 1.0e9
# 1.0e9: see LAS spec (for float accuracy)
# 315964800: seconds between 1970 (Unix epoch) and 1980 (GPS epoch), from http://stackoverflow.com/a/20528332
"""Get the DateTime that the point was collected.
Assumes time is recorded in Adjusted Standard GPS Time; see `is_standard_gps`.
Note that DateTime has millisecond precision, any higher precision is lost."""
Dates.DateTime(p::LasPointTime) = Dates.unix2datetime(p.gps_time) + Dates.Second(1315964800)
# A conversion of the GPS Week Time format to DateTime is not yet implemented

"""Time tag value at which the point was aquired,
a Float64; see `is_standard_gps` for what it represents"""
gps_time(p::LasPointTime) = p.gps_time
"""Convert DateTime to GPS Float64, as represented in the point data,
assumes time is recorded in Adjusted Standard GPS Time; see `is_standard_gps`"""
gps_time(d::DateTime) = Dates.datetime2unix(d - Dates.Second(1315964800))

# color
"The red image channel value associated with this point"
ColorTypes.red(p::LasPointColor) = p.red
"The green image channel value associated with this point"
ColorTypes.green(p::LasPointColor) = p.green
"The blue image channel value associated with this point"
ColorTypes.blue(p::LasPointColor) = p.blue
"The RGB color associated with this point"
ColorTypes.RGB(p::LasPointColor) = RGB(red(p), green(p), blue(p))

# functions to extract sub-byte items from a LasPoint's flag_byte
"The pulse return number for a given output pulse, starting at one."
return_number(p::LasPoint) = (p.flag_byte & 0b00000111)
"The total number of returns for a given pulse."
number_of_returns(p::LasPoint) = (p.flag_byte & 0b00111000) >> 3
"If true, the scanner mirror was traveling from left to right at the time of the output pulse."
scan_direction(p::LasPoint) = Bool((p.flag_byte & 0b01000000) >> 6)
"If true, it is the last point before the scanner changes direction."
edge_of_flight_line(p::LasPoint) = Bool((p.flag_byte & 0b10000000) >> 7)

"Flag byte, contains return number, number of returns, scan direction flag and edge of flight line"
flag_byte(p::LasPoint) = p.flag_byte
"Flag byte, as represented in the point data, built up from components"
function flag_byte(return_number::UInt8, number_of_returns::UInt8,
                   scan_direction::Bool, edge_of_flight_line::Bool)
    # Bool to UInt8 conversion because a bit shift on a Bool produces an Int
    UInt8(edge_of_flight_line) << 7 | UInt8(scan_direction) << 6 | number_of_returns << 3 | return_number
end

# functions to extract sub-byte items from a LasPoint's raw_classification
"Classification value as defined in the ASPRS classification table."
classification(p::LasPoint) = (p.raw_classification & 0b00011111)
"If true, the point was not created from lidar collection"
synthetic(p::LasPoint) = Bool((p.raw_classification & 0b00100000) >> 5)
"If true, this point is considered to be a model key-point."
key_point(p::LasPoint) = Bool((p.raw_classification & 0b01000000) >> 6)
"If true, this point should not be included in processing"
withheld(p::LasPoint) = Bool((p.raw_classification & 0b10000000) >> 7)

"Raw classification byte, contains classification, synthetic, key point and withheld"
raw_classification(p::LasPoint) = p.raw_classification
"Raw classification byte, as represented in the point data, built up from components"
function raw_classification(classification::UInt8, synthetic::Bool,
                            key_point::Bool, withheld::Bool)
    UInt8(withheld) << 7 | UInt8(key_point) << 6 | UInt8(synthetic) << 5 | classification
end

function Base.convert(::Type{Point{3, Float64}}, p::LasPoint, h::LasHeader)
    Point{3, Float64}(xcoord(p, h), ycoord(p, h), zcoord(p, h))
end

# beware of the limited precision, for instance with UTM coordinates
function Base.convert(::Type{Point{3, Float32}}, p::LasPoint, h::LasHeader)
    Point{3, Float32}(xcoord(p, h), ycoord(p, h), zcoord(p, h))
end

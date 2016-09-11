
"Abstract type for ASPRS LAS point data record formats 0 - 3"
abstract LasPoint

function Base.show{T<:LasPoint}(io::IO, pointdata::Vector{T})
    n = size(pointdata, 1)
    println(io, "Vector{$T} with $n points.")
end

"ASPRS LAS point data record format 0"
immutable LasPoint0 <: LasPoint
    x::Int32
    y::Int32
    z::Int32
    intensity::UInt16
    flag_byte::UInt8
    raw_classification::UInt8
    scan_angle::UInt8
    user_data::UInt8
    pt_src_id::UInt16
end

"ASPRS LAS point data record format 1"
immutable LasPoint1 <: LasPoint
    x::Int32
    y::Int32
    z::Int32
    intensity::UInt16
    flag_byte::UInt8
    raw_classification::UInt8
    scan_angle::UInt8
    user_data::UInt8
    pt_src_id::UInt16
    gps_time::Float64
end

"ASPRS LAS point data record format 2"
immutable LasPoint2 <: LasPoint
    x::Int32
    y::Int32
    z::Int32
    intensity::UInt16
    flag_byte::UInt8
    raw_classification::UInt8
    scan_angle::UInt8
    user_data::UInt8
    pt_src_id::UInt16
    red::U16
    green::U16
    blue::U16
end

"ASPRS LAS point data record format 3"
immutable LasPoint3 <: LasPoint
    x::Int32
    y::Int32
    z::Int32
    intensity::UInt16
    flag_byte::UInt8
    raw_classification::UInt8
    scan_angle::UInt8
    user_data::UInt8
    pt_src_id::UInt16
    gps_time::Float64
    red::U16
    green::U16
    blue::U16
end

# for convenience in function signatures
typealias LasPointColor Union{LasPoint2, LasPoint3}
typealias LasPointTime Union{LasPoint1, LasPoint3}

function Base.show(io::IO, p::LasPoint)
    z = Int(p.z)
    cl = Int(classification(p))
    println(io, "LasPoint(z=$z, classification=$cl)")
end


"X coordinate (Float64), apply scale and offset according to the header"
xcoord(p::LasPoint, h::LasHeader) = muladd(p.x, h.x_scale, h.x_offset)
"Y coordinate (Float64), apply scale and offset according to the header"
ycoord(p::LasPoint, h::LasHeader) = muladd(p.y, h.y_scale, h.y_offset)
"Z coordinate (Float64), apply scale and offset according to the header"
zcoord(p::LasPoint, h::LasHeader) = muladd(p.z, h.z_scale, h.z_offset)


# functions for reading the points from a stream

function Base.read(io::IO, ::Type{LasPoint0})
    x = read(io, Int32)
    y = read(io, Int32)
    z = read(io, Int32)
    intensity = read(io, UInt16)
    flag_byte = read(io, UInt8)
    raw_classification = read(io, UInt8)
    scan_angle = read(io, UInt8)
    user_data = read(io, UInt8)
    pt_src_id = read(io, UInt16)
    LasPoint0(
        x,
        y,
        z,
        intensity,
        flag_byte,
        raw_classification,
        scan_angle,
        user_data,
        pt_src_id
    )
end

function Base.read(io::IO, ::Type{LasPoint1})
    x = read(io, Int32)
    y = read(io, Int32)
    z = read(io, Int32)
    intensity = read(io, UInt16)
    flag_byte = read(io, UInt8)
    raw_classification = read(io, UInt8)
    scan_angle = read(io, UInt8)
    user_data = read(io, UInt8)
    pt_src_id = read(io, UInt16)
    gps_time = read(io, Float64)
    LasPoint1(
        x,
        y,
        z,
        intensity,
        flag_byte,
        raw_classification,
        scan_angle,
        user_data,
        pt_src_id,
        gps_time
    )
end


function Base.read(io::IO, ::Type{LasPoint2})
    x = read(io, Int32)
    y = read(io, Int32)
    z = read(io, Int32)
    intensity = read(io, UInt16)
    flag_byte = read(io, UInt8)
    raw_classification = read(io, UInt8)
    scan_angle = read(io, UInt8)
    user_data = read(io, UInt8)
    pt_src_id = read(io, UInt16)
    red = reinterpret(U16, read(io, UInt16))
    green = reinterpret(U16, read(io, UInt16))
    blue = reinterpret(U16, read(io, UInt16))
    LasPoint2(
        x,
        y,
        z,
        intensity,
        flag_byte,
        raw_classification,
        scan_angle,
        user_data,
        pt_src_id,
        red,
        green,
        blue
    )
end


function Base.read(io::IO, ::Type{LasPoint3})
    x = read(io, Int32)
    y = read(io, Int32)
    z = read(io, Int32)
    intensity = read(io, UInt16)
    flag_byte = read(io, UInt8)
    raw_classification = read(io, UInt8)
    scan_angle = read(io, UInt8)
    user_data = read(io, UInt8)
    pt_src_id = read(io, UInt16)
    gps_time = read(io, Float64)
    red = reinterpret(U16, read(io, UInt16))
    green = reinterpret(U16, read(io, UInt16))
    blue = reinterpret(U16, read(io, UInt16))
    LasPoint3(
        x,
        y,
        z,
        intensity,
        flag_byte,
        raw_classification,
        scan_angle,
        user_data,
        pt_src_id,
        gps_time,
        red,
        green,
        blue
    )
end


# functions for writing the points to a stream

function Base.write(io::IO, p::LasPoint0)
    write(io, p.x)
    write(io, p.y)
    write(io, p.z)
    write(io, p.intensity)
    write(io, p.flag_byte)
    write(io, p.raw_classification)
    write(io, p.scan_angle)
    write(io, p.user_data)
    write(io, p.pt_src_id)
    nothing
end

function Base.write(io::IO, p::LasPoint1)
    write(io, p.x)
    write(io, p.y)
    write(io, p.z)
    write(io, p.intensity)
    write(io, p.flag_byte)
    write(io, p.raw_classification)
    write(io, p.scan_angle)
    write(io, p.user_data)
    write(io, p.pt_src_id)
    write(io, p.gps_time)
    nothing
end

function Base.write(io::IO, p::LasPoint2)
    write(io, p.x)
    write(io, p.y)
    write(io, p.z)
    write(io, p.intensity)
    write(io, p.flag_byte)
    write(io, p.raw_classification)
    write(io, p.scan_angle)
    write(io, p.user_data)
    write(io, p.pt_src_id)
    write(io, reinterpret(UInt16, p.red))
    write(io, reinterpret(UInt16, p.green))
    write(io, reinterpret(UInt16, p.blue))
    nothing
end

function Base.write(io::IO, p::LasPoint3)
    write(io, p.x)
    write(io, p.y)
    write(io, p.z)
    write(io, p.intensity)
    write(io, p.flag_byte)
    write(io, p.raw_classification)
    write(io, p.scan_angle)
    write(io, p.user_data)
    write(io, p.pt_src_id)
    write(io, p.gps_time)
    write(io, reinterpret(UInt16, p.red))
    write(io, reinterpret(UInt16, p.green))
    write(io, reinterpret(UInt16, p.blue))
    nothing
end

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
Assumes time is recorded in Adjusted Standard GPS Time; see `is_standard_gps`"""
Dates.DateTime(p::LasPointTime) = Dates.unix2datetime(p.gps_time + 1.3159648e9)
# A conversion of the GPS Week Time format to DateTime is not yet implemented

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

# functions to extract sub-byte items from a LasPoint's raw_classification
"Classification value as defined in the ASPRS classification table."
classification(p::LasPoint) = (p.raw_classification & 0b00011111)
"If true, the point was not created from lidar collection"
synthetic(p::LasPoint) = Bool((p.raw_classification & 0b00100000) >> 5)
"If true, this point is considered to be a model key-point."
key_point(p::LasPoint) = Bool((p.raw_classification & 0b01000000) >> 6)
"If true, this point should not be included in processing"
withheld(p::LasPoint) = Bool((p.raw_classification & 0b10000000) >> 7)

function Base.convert(::Type{Point{3, Float64}}, p::LasPoint, h::LasHeader)
    Point{3, Float64}(xcoord(p, h), ycoord(p, h), zcoord(p, h))
end

# beware of the limited precision, for instance with UTM coordinates
function Base.convert(::Type{Point{3, Float32}}, p::LasPoint, h::LasHeader)
    Point{3, Float32}(xcoord(p, h), ycoord(p, h), zcoord(p, h))
end

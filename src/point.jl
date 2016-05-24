
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
    point_source_id::UInt16
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
    point_source_id::UInt16
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
    point_source_id::UInt16
    red::UFixed16
    green::UFixed16
    blue::UFixed16
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
    point_source_id::UInt16
    gps_time::Float64
    red::UFixed16
    green::UFixed16
    blue::UFixed16
end

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
    point_source_id = read(io, UInt16)
    LasPoint0(
        x,
        y,
        z,
        intensity,
        flag_byte,
        raw_classification,
        scan_angle,
        user_data,
        point_source_id
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
    point_source_id = read(io, UInt16)
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
        point_source_id,
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
    point_source_id = read(io, UInt16)
    red = reinterpret(UFixed16, read(io, UInt16))
    green = reinterpret(UFixed16, read(io, UInt16))
    blue = reinterpret(UFixed16, read(io, UInt16))
    LasPoint2(
        x,
        y,
        z,
        intensity,
        flag_byte,
        raw_classification,
        scan_angle,
        user_data,
        point_source_id,
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
    point_source_id = read(io, UInt16)
    gps_time = read(io, Float64)
    red = reinterpret(UFixed16, read(io, UInt16))
    green = reinterpret(UFixed16, read(io, UInt16))
    blue = reinterpret(UFixed16, read(io, UInt16))
    LasPoint3(
        x,
        y,
        z,
        intensity,
        flag_byte,
        raw_classification,
        scan_angle,
        user_data,
        point_source_id,
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
    write(io, p.point_source_id)
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
    write(io, p.point_source_id)
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
    write(io, p.point_source_id)
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
    write(io, p.point_source_id)
    write(io, p.gps_time)
    write(io, reinterpret(UInt16, p.red))
    write(io, reinterpret(UInt16, p.green))
    write(io, reinterpret(UInt16, p.blue))
    nothing
end


# functions to extract sub-byte items from a LasPoint's flag_byte
return_number(p::LasPoint) = (p.flag_byte & 0b11100000) >> 5
number_of_returns(p::LasPoint) = (p.flag_byte & 0b00011100) >> 2
scan_direction(p::LasPoint) = Bool((p.flag_byte & 0b00000010) >> 1)
edge_of_flight_line(p::LasPoint) = Bool(p.flag_byte & 0b00000001)

# functions to extract sub-byte items from a LasPoint's raw_classification
classification(p::LasPoint) = (p.raw_classification & 0b11111000) >> 3
synthetic(p::LasPoint) = Bool((p.raw_classification & 0b00000100) >> 2)
key_point(p::LasPoint) = Bool((p.raw_classification & 0b00000010) >> 1)
withheld(p::LasPoint) = Bool(p.raw_classification & 0b00000001)

function convert(::Type{Point3}, p::LasPoint, h::LasHeader)
    Point3(xcoord(p, header), xcoord(p, header), xcoord(p, header))
end

# beware of the limited precision, for instance with UTM coordinates
function convert(::Type{Point3f0}, p::LasPoint, h::LasHeader)
    Point3f0(xcoord(p, header), xcoord(p, header), xcoord(p, header))
end

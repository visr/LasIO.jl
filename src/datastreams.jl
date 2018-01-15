########
# SOURCE
########

const minimum_coordinate = typemin(Int32)
const maximum_coordinate = typemax(Int32)

mutable struct Source <: Data.Source
    schema::Data.Schema
    header::LasHeader
    io::IO
    fullpath::String
    datapos::Int
end

dict_of_struct(T) = Dict((String(fieldname(typeof(T), i)), getfield(T, i)) for i = 1:nfields(T))

function Source(f::AbstractString)
    !isfile(f) && error("Please provide valid path.")

    io = is_windows() ? open(f) : IOBuffer(Mmap.mmap(f))

    skiplasf(io)
    header = read(io, LasHeader)

    n = header.records_count
    pointtype = pointformat(header)

    # Schema
    columns = Vector{String}(fieldnames(pointtype))
    types = Vector{Type}([fieldtype(pointtype, i) for i in 1:nfields(pointtype)])
    types[1:3] = [Float64, Float64, Float64]  # Convert XYZ coordinates
    sch = Data.Schema(types, columns, n, dict_of_struct(header))

    return Source(sch, header, io, f, position(io))
end

Data.reset!(s::LasIO.Source) = (seek(s.io, s.datapos); return nothing)
Data.schema(source::LasIO.Source) = source.schema
Data.accesspattern(::Type{LasIO.Source}) = Data.Sequential
Data.isdone(source::LasIO.Source, row::Int, col::Int) = eof(source.io) || (row, col) > Data.size(Data.schema(source))
Data.isdone(source::LasIO.Source, row, col, rows, cols) = eof(source.io) || row > rows || col > cols
Data.streamtype(::Type{<:LasIO.Source}, ::Type{Data.Field}) = true

# Data.streamfrom(source::LasIO.Source, st::Type{Data.Row}, t::Type{T}, row::Int) where {T} = read(source.io, pointformat(source.header))
function Data.streamfrom(source::LasIO.Source, ::Type{Data.Field}, ::Type{T}, row::Int, col::Int) where {T}

    # XYZ => scale stored Integers to Floats using header information
    if col == 1
        return muladd(read(source.io, Int32), source.header.x_scale, source.header.x_offset)
    elseif col == 2
        return muladd(read(source.io, Int32), source.header.y_scale, source.header.y_offset)
    elseif col == 3
        return muladd(read(source.io, Int32), source.header.z_scale, source.header.z_offset)

    # Otherwise return read value
    else
        v = read(source.io, T)
    end
end

######
# SINK
######

mutable struct Sink{T} <: Data.Sink where T <: LasPoint
    stream::IO
    header::LasHeader
    pointformat::Type{T}
    bbox::Vector{Float64}
    returncount::Vector{UInt32}
end

# setup header and empty pointvector
function Sink(sch::Data.Schema, S::Type{Data.Field}, append::Bool, fullpath::AbstractString, bbox::Vector{Float64}; scale::Real=0.01, epsg=nothing)

    # validate input
    length(bbox) != 6 && error("Provide bounding box as (xmin, ymin, zmin, xmax, ymax, zmax)")

    s = open(fullpath, "w")

    # determine point version and derivatives
    pointtype = gettype(Data.header(sch))
    data_format_id = pointformat(pointtype)
    data_record_length = packed_size(pointtype)
    n = Data.size(sch, 1)  # rows

    # setup and validate scaling based on bbox and scale
    x_offset = determine_offset(bbox[1], bbox[4], scale)
    y_offset = determine_offset(bbox[2], bbox[5], scale)
    z_offset = determine_offset(bbox[3], bbox[6], scale)

    # create header
    header = LasHeader(data_format_id=data_format_id, data_record_length=data_record_length, records_count=n,
        x_max=bbox[4], x_min=bbox[1], y_max=bbox[5], y_min=bbox[2], z_max=bbox[6], z_min=bbox[3],
        x_scale=scale, y_scale=scale, z_scale=scale,
        x_offset=x_offset, y_offset=y_offset, z_offset=z_offset)
    epsg != nothing && epsg_code!(header, epsg)

    # write header
    write(s, magic(format"LAS"))
    write(s, header)

    # empty return count
    return_count = Array{UInt32}([0, 0, 0, 0, 0])

    # return stream, position is correct for writing points
    return Sink(s, header, pointtype, bbox, return_count)
end

# Update existing Sink
# function Sink(sink::LasIO.Sink, sch::Data.Schema, S::Type{StreamType}, append::Bool; reference::Vector{UInt8}=UInt8[])
    # return Sink
# end

"""Determine LAS versions based on specific columns."""
function gettype(columns::Vector{String})
    # LAS versions only differ in gps_time and rgb color information
    has_gps, has_color = false, false
    ("gps_time" in columns) && (has_gps = true)
    ("red" in columns || "green" in columns || "blue" in columns) && (has_color = true)
    
    has_gps && has_color && return LasPoint3
    has_color && return LasPoint2
    has_gps && return LasPoint1
    return LasPoint0
end

Data.streamtypes(::Type{LasIO.Sink}) = [Data.Field, Data.Row]
Data.cleanup!(sink::LasIO.Sink) = nothing
Data.weakrefstrings(::Type{LasIO.Sink}) = false

function update_sink(sink::LasIO.Sink, col::Integer, val::T) where {T}
    if col == 1
        (val > sink.bbox[1] || sink.bbox[1] == 0.0) && (setindex!(sink.bbox, val, 1))  # xmax
        (val < sink.bbox[2] || sink.bbox[2] == 0.0) && (setindex!(sink.bbox, val, 2))  # xmin
    end
    if col == 2
        (val > sink.bbox[3] || sink.bbox[3] == 0.0) && (setindex!(sink.bbox, val, 3))  # ymax
        (val < sink.bbox[4] || sink.bbox[4] == 0.0) && (setindex!(sink.bbox, val, 4))  # ymin
    end
    if col == 3
        (val > sink.bbox[5] || sink.bbox[5] == 0.0) && (setindex!(sink.bbox, val, 5))  # zmax
        (val < sink.bbox[6] || sink.bbox[6] == 0.0) && (setindex!(sink.bbox, val, 6))  # zmin  
    end
    if col == 5
        return_number = val & 0b00000111
        return_number < 5 && (sink.returncount[return_number+1] += 1)
    end
end

# actually write points to our pointvector
function Data.streamto!(sink::LasIO.Sink, S::Type{Data.Field}, val, row, col)
    # TODO(evetion) check if stream position is at row*col
    update_sink(sink, col, val)

    # XYZ => scale given Floats to Integers using header information
    if col == 1
        write(sink.stream, round(Int32, ((val - sink.header.x_offset) / sink.header.x_scale)))
    elseif col == 2
        write(sink.stream, round(Int32, ((val - sink.header.y_offset) / sink.header.y_scale)))
    elseif col == 3
        write(sink.stream, round(Int32, ((val - sink.header.z_offset) / sink.header.z_scale)))
    else
        write(sink.stream, val)
    end
end

# save file
function Data.close!(sink::LasIO.Sink)

    # update header
    header = sink.header
    header.x_max = sink.bbox[1]
    header.x_min = sink.bbox[2]
    header.y_max = sink.bbox[3]
    header.y_min = sink.bbox[4]
    header.z_max = sink.bbox[5]
    header.z_min = sink.bbox[6]
    header.point_return_count = sink.returncount

    # seek back to beginning and write header
    seekstart(sink.stream)
    skiplasf(sink.stream)
    write(sink.stream, header)

    close(sink.stream)
    return sink
end

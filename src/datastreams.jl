########
# SOURCE
########


mutable struct Source <: Data.Source
    schema::Data.Schema
    header::LasHeader
    io::IO
    fullpath::String
    datapos::Int
end

dict_of_struct(T) = Dict((String(fieldname(typeof(T), i)), getfield(T, i)) for i = 1:nfields(T))

function Source(f::AbstractString)
    # s = is_windows() ? open(f) : IOStream(Mmap.mmap(f))
    io = open(f)

    skiplasf(io)
    header = read(io, LasHeader)

    n = header.records_count
    pointtype = pointformat(header)

    # Schema
    columns = Vector{String}(fieldnames(pointtype))
    types = Vector{Type}([fieldtype(pointtype, i) for i in 1:nfields(pointtype)])
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
    # p = source.pointdata[row]
    # v = getfield(p, fieldname(typeof(p), col))
    read(source.io, T)
end

######
# SINK
######

mutable struct Sink{T} <: Data.Sink where T <: LasPoint
    stream::IO
    header::LasHeader
    # pointdata::Vector{T}
    pointformat::Type{T}
end

# setup header and empty pointvector
function Sink(sch::Data.Schema, S::Type{Data.Field}, append::Bool, fullpath::AbstractString)
    s = open(fullpath, "w")

    # determine point version and derivatives
    pointtype = gettype(Data.header(sch))
    data_format_id = pointformat(pointtype)
    data_record_length = packed_size(pointtype)
    n = Data.size(sch, 1)  # rows

    # create header 
    header = LasHeader(data_format_id=data_format_id, data_record_length=data_record_length, records_count=n)

    # write header
    write(s, magic(format"LAS"))
    write(s, header)
    println("Stream now at $(position(s))")

    # create empty pointdata
    # pointdata = Vector{pointtype}(n)

    # return stream, position is correct for writing points
    return Sink(s, header, pointtype)
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

# actually write points to our pointvector
function Data.streamto!(sink::LasIO.Sink, S::Type{Data.Field}, val, row, col)
    # TODO(evetion) check if stream position is at row*col
    # write points
    write(sink.stream, val)
end

# save file
function Data.close!(sink::LasIO.Sink)
    close(sink.stream)
    # TODO(evetion) check number of points, extents etc
    # change header if possible
    return sink
end

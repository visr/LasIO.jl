
function pointformat(header::LasHeader)
    id = header.data_format_id
    if id == 0x00
        return LasPoint0
    elseif id == 0x01
        return LasPoint1
    elseif id == 0x02
        return LasPoint2
    elseif id == 0x03
        return LasPoint3
    else
        error("unsupported point format $(Int(id))")
    end
end

function pointformat(t::Type{T}) where T <: LasPoint
    if t == LasPoint0
        return 0x00
    elseif t == LasPoint1
        return 0x01
    elseif t == LasPoint2
        return 0x02
    elseif t == LasPoint3
        return 0x03
    else
        error("unsupported point format $t")
    end
end

# skip the LAS file's magic four bytes, "LASF"
skiplasf(s::Union{Stream{format"LAS"}, Stream{format"LAZ"}, IO}) = skip(s, sizeof(UInt32))

function load(f::File{format"LAS"})
    open(f) do s
        load(s)
    end
end

function load(s::Union{Stream{format"LAS"}, Pipe})
    skiplasf(s)
    header = read(s, LasHeader)

    n = header.records_count
    pointtype = pointformat(header)
    pointdata = Vector{pointtype}(n)
    for i=1:n
        pointdata[i] = read(s, pointtype)
    end
    header, pointdata
end

function load(f::File{format"LAZ"})
    # read las from laszip, which decompresses to stdout
    open(`laszip -olas -stdout -i $(filename(f))`) do s
        load(s)
    end
end

function read_header(f::AbstractString)
    open(f) do s
        read_header(s::IO)
    end
end

function read_header(s::IO)
    skiplasf(s)
    read(s, LasHeader)
end

function save(f::File{format"LAS"}, header::LasHeader, pointdata::Vector{T}) where T <: LasPoint
    open(f, "w") do s
        save(s, header, pointdata)
    end
end

function save(s::Stream{format"LAS"}, header::LasHeader, pointdata::Vector{T}) where T <: LasPoint
    # checks
    header_n = header.records_count
    n = length(pointdata)
    msg = "number of records in header ($header_n) does not match data length ($n)"
    @assert header_n == n msg

    # write header
    write(s, magic(format"LAS"))
    write(s, header)

    # write points
    for p in pointdata
        write(s, p)
    end
end

function save(f::File{format"LAZ"}, header::LasHeader, pointdata::Vector{T}) where T <: LasPoint
    # pipes las to laszip to write laz
    open(`laszip -olaz -stdin -o $(filename(f))`, "w") do s
        savebuf(s, header, pointdata)
    end
end

# Uses a buffered write to the stream.
# For saving to LAS this does not increase speed,
# but it speeds up a lot when the result is piped to laszip.
function savebuf(s::IO, header::LasHeader, pointdata::Vector{T}) where T <: LasPoint
    # checks
    header_n = header.records_count
    n = length(pointdata)
    msg = "number of records in header ($header_n) does not match data length ($n)"
    @assert header_n == n msg

    # write header
    write(s, magic(format"LAS"))
    write(s, header)

    # 2048 points seemed to be an optimum for the libLAS_1.2.las testfile
    npoints_buffered = 2048
    bufsize = header.data_record_length * npoints_buffered
    buf = IOBuffer(bufsize)
    # write points
    for (i, p) in enumerate(pointdata)
        write(buf, p)
        if rem(i, npoints_buffered) == 0 || i == n
            write(s, take!(buf))
        end
    end
end

using Mmap

function get_laszip_executable_path()
    if Sys.iswindows()
        return joinpath(dirname(@__DIR__), "resources", "laszip.exe")
    elseif Sys.islinux()
        return joinpath(dirname(@__DIR__), "resources", "laszip")
    else
        error("LasIO  with ZIP functionality is only suported for windows and linux!")
    end
end

function get_record_count(header::LasHeader)
    return header.extended_number_of_point_records > 0 ? Int(header.extended_number_of_point_records) : Int(header.records_count)
end

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
    elseif id == 0x04
        return LasPoint4
    elseif id == 0x05
        return LasPoint5
    elseif id == 0x06
        return LasPoint6
    elseif id == 0x07
        return LasPoint7
    elseif id == 0x08
        return LasPoint8
    elseif id == 0x09
        return LasPoint9
    elseif id == 0x0a
        return LasPoint10
    else
        error("unsupported point format $(Int(id))")
    end
end

# skip the LAS file's magic four bytes, "LASF"
skiplasf(s::Union{Stream{format"LAS"}, Stream{format"LAZ"}, IO}) = read(s, UInt32)

function load(f::File{format"LAS"}; mmap=false)
    open(f) do s
        load(s; mmap=mmap)
    end
end

# Load pipe separately since it can't be memory mapped
function load(s::Base.AbstractPipe)
    skiplasf(s)
    header = read(s, LasHeader)
    n = get_record_count(header)
    pointtype = pointformat(header)

    @info "Reading $(n) '$(pointtype)' points"
    pointdata = Vector{pointtype}(undef, n)
    for i=1:n
        i%1000000 == 0 && @info("Read $(i)/$(n) points")
        pointdata[i] = read(s, pointtype)
    end
    header, pointdata
end

function load(s::Stream{format"LAS"}; mmap=false)
    skiplasf(s)
    header = read(s, LasHeader)
    n = get_record_count(header)
    pointtype = pointformat(header)

    @info "Reading $(n) '$(pointtype)' points"
    if mmap
        pointsize = Int(header.data_record_length)
        pointbytes = Mmap.mmap(s.io, Vector{UInt8}, n*pointsize, position(s))
        pointdata = PointVector{pointtype}(pointbytes, pointsize)
    else
        pointdata = Vector{pointtype}(undef, n)
        for i=1:n
            i%1000000 == 0 && @info("Read $(i)/$(n) points")
            pointdata[i] = read(s, pointtype)
        end
    end

    header, pointdata
end

function load(f::File{format"LAZ"})
    # read las from laszip, which decompresses to stdout
    open(`$(get_laszip_executable_path()) -olas -stdout -i $(filename(f))`) do s
        h,p = load(s)
        read(s)
        return h, p
    end
end

function read_header(f::AbstractString)
    open(f) do s
        skiplasf(s)
        read(s, LasHeader)
    end
end

function read_header(s::IO)
    skiplasf(s)
    read(s, LasHeader)
end

function save(f::File{format"LAS"}, header::LasHeader, pointdata::AbstractVector{<:LasPoint})
    open(f, "w") do s
        save(s, header, pointdata)
    end
end

function save(s::Stream{format"LAS"}, header::LasHeader, pointdata::AbstractVector{<:LasPoint})
    # checks
    header_n = get_record_count(header)
    n = length(pointdata)
    msg = "Number of records in header ($header_n) does not match data length ($n)"
    @info "Writing $(n) '$(typeof(pointdata[1]))' points"

    @assert header_n == n msg

    # write header
    write(s, magic(format"LAS"))
    write(s, header)

    # write points
    for p in pointdata
        write(s, p)
    end
end

function save(f::File{format"LAZ"}, header::LasHeader, pointdata::AbstractVector{<:LasPoint})
    # pipes las to laszip to write laz
    open(`$(get_laszip_executable_path()) -olaz -stdin -o $(filename(f))`, "w") do s
        savebuf(s, header, pointdata)
    end
end

# Uses a buffered write to the stream.
# For saving to LAS this does not increase speed,
# but it speeds up a lot when the result is piped to laszip.
function savebuf(s::IO, header::LasHeader, pointdata::AbstractVector{<:LasPoint})
    # checks
    header_n = get_record_count(header)
    n = length(pointdata)
    msg = "number of records in header ($header_n) does not match data length ($n)"
    @assert header_n == n msg
    @info "Writing $(n) '$(typeof(pointdata[1]))' points to LAZ file"

    # write header
    write(s, magic(format"LAS"))
    write(s, header)

    # 2048 points seemed to be an optimum for the libLAS_1.2.las testfile
    npoints_buffered = 2048
    bufsize = header.data_record_length * npoints_buffered
    buf = IOBuffer(sizehint=bufsize)
    # write points
    for (i, p) in enumerate(pointdata)
        write(buf, p)
        if rem(i, npoints_buffered) == 0 || i == n
            write(s, take!(buf))
        end
    end
end

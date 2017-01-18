
function pointformat(header::LasHeader)
    id = header.data_format_id
    id &= 0x7f # for LAZ first bit is 1, set this bit back to 0 to not confuse this function
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

function load(f::File{format"LAS"})
    open(f) do s
        skipmagic(s) # skip over the magic bytes
        load(s)
    end
end

function load(s::Stream{format"LAS"})
    header = read(s, LasHeader)

    seek(s, header.data_offset)
    n = header.records_count
    pointtype = pointformat(header)
    pointdata = Vector{pointtype}(n)
    for i=1:n
        pointdata[i] = read(s, pointtype)
    end
    header, pointdata
end

function read_header(f::AbstractString)
    open(f) do s
        read(s, LasHeader)
    end
end

function read_header(s::IO)
    read(s, LasHeader)
end

function save{T<:LasPoint}(f::File{format"LAS"}, header::LasHeader, pointdata::Vector{T})
    open(f, "w") do s
        save(s, header, pointdata)
    end
end

function save{T<:LasPoint}(s::Stream{format"LAS"}, header::LasHeader, pointdata::Vector{T})
    # checks
    header_n = header.records_count
    n = length(pointdata)
    msg = "number of records in header ($header_n) does not match data length ($n)"
    @assert header_n == n msg

    # write header
    write(s, magic(format"LAS"))
    write(s, header)
    bytes_togo = header.data_offset - position(s)
    @assert bytes_togo == 0

    # write points
    for i = 1:n
        write(s, pointdata[i])
    end
end

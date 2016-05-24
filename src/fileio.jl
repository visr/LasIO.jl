
# these should eventually go in
# https://github.com/JuliaIO/FileIO.jl/blob/master/src/registry.jl
add_format(format"LAS", "LASF", ".las")

add_loader(format"LAS", :LasIO)
add_saver(format"LAS", :LasIO)

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

function FileIO.load(f::File{format"LAS"})
    open(f) do s
        skipmagic(s) # skip over the magic bytes
        load(s)
    end
end

function FileIO.load(s::Stream{format"LAS"})
    seek(s, 4)
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
        seek(s, 4)
        read(s, LasHeader)
    end
end

function read_header(s::IOStream)
    seek(s, 4)
    read(s, LasHeader)
end

function FileIO.save(f::File{format"LAS"}, header, pointdata)
    open(f, "w") do s
        save(s, header, pointdata)
    end
end

function FileIO.save(s::Stream{format"LAS"}, header, pointdata)
    @assert header.n_vlr == 0  # not yet implemented
    n = length(pointdata)
    @assert header.records_count == n
    write(s, magic(format"LAS"))
    write(s, header)
    # this needs to be fixed
    # it seems like some LAS 1.2 files have the
    # Start of waveform data record
    # even though it is introduced in LAS 1.3
    bytes_togo = header.data_offset - position(s)
    if bytes_togo > 0
        write(s, zeros(UInt8, bytes_togo))
    end
    for i = 1:n
        write(s, pointdata[i])
    end
end

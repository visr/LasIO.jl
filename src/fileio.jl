
# these should eventually go in
# https://github.com/JuliaIO/FileIO.jl/blob/master/src/registry.jl

add_format(format"LAS", "LASF", ".las")

# when writing LAS files works, remove this
# and add this argument at the end of add_format: [:LasIO]
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

function load(f::File{format"LAS"})
    open(f) do s
        skipmagic(s)  # skip over the magic bytes
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

function save(f::File{format"LAS"}, header, pointdata)
    open(f, "w") do s
        save(s, header, pointdata)
    end
end

function save(s::Stream{format"LAS"}, header, pointdata)
    @assert header.n_vlr == 0  # not yet implemented
    n = length(pointdata)
    @assert header.records_count == n
    write(s, magic(format"LAS"))
    write(s, header)
    # this needs to be fixed
    # it seems like our LAS 1.2 files have the
    # Start of waveform data record
    # even though it is introduced in LAS 1.3
    bytes_togo = header.data_offset - position(s)
    # @show bytes_togo
    if bytes_togo > 0
        write(s, zeros(UInt8, bytes_togo))
    end
    for i = 1:n
        write(s, pointdata[i])
    end
end

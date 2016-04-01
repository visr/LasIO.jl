
# these should eventually go in
# https://github.com/JuliaIO/FileIO.jl/blob/master/src/registry.jl

add_format(format"LAS", "LASF", ".las")

# when writing LAS files works, remove this
# and add this argument at the end of add_format: [:LasIO]
add_loader(format"LAS", :LasIO)

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

# function save(f::File{format"PNG"}, data)
#     open(f, "w") do s
#         # Don't forget to write the magic bytes!
#         write(s, magic(format"PNG"))
#         # Do the rest of the stuff needed to save in PNG format
#     end
# end

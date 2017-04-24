@compat abstract type LasHeader ; end

type LasHeader12 <: LasHeader
    file_source_id::UInt16
    global_encoding::UInt16
    guid_1::UInt32
    guid_2::UInt16
    guid_3::UInt16
    guid_4::FixedString{8}
    version_major::UInt8
    version_minor::UInt8
    system_id::FixedString{32}
    software_id::FixedString{32}
    creation_doy::UInt16
    creation_year::UInt16
    header_size::UInt16
    data_offset::UInt32
    n_vlr::UInt32
    data_format_id::UInt8
    data_record_length::UInt16
    records_count::UInt32
    point_return_count::Vector{UInt32}
    x_scale::Float64
    y_scale::Float64
    z_scale::Float64
    x_offset::Float64
    y_offset::Float64
    z_offset::Float64
    x_max::Float64
    x_min::Float64
    y_max::Float64
    y_min::Float64
    z_max::Float64
    z_min::Float64
    variable_length_records::Vector{LasVariableLengthRecord}
    user_defined_bytes::Vector{UInt8}
end

function Base.show(io::IO, header::LasHeader)
    n = Int(header.records_count)
    print(io, "LasHeader12 with $n points.")
end

function Base.showall(io::IO, h::LasHeader)
    show(io, h)
    for name in fieldnames(h)
        if name == :variable_length_records
            println(io, string("\tvariable_length_records = "))
            for vlr in h.variable_length_records
                println(io, "\t\t($(vlr.user_id), $(vlr.record_id)) => ($(vlr.description), $(length(vlr.data)) bytes...)")
            end
        else
            println(io, string("\t$name = $(getfield(h,name))"))
        end
    end
end

function Base.read{Header<:LasHeader}(io::IO, ::Type{Header})
    seek(io, 4)  # after LASF
    file_source_id = read(io, UInt16)
    global_encoding = read(io, UInt16)
    guid_1 = read(io, UInt32)
    guid_2 = read(io, UInt16)
    guid_3 = read(io, UInt16)
    guid_4 = read(io, FixedString{8})
    version_major = read(io, UInt8)
    version_minor = read(io, UInt8)
    system_id = read(io, FixedString{32})
    software_id = read(io, FixedString{32})
    creation_doy = read(io, UInt16)
    creation_year = read(io, UInt16)
    header_size = read(io, UInt16)
    data_offset = read(io, UInt32)
    n_vlr = read(io, UInt32)
    data_format_id = read(io, UInt8)
    data_record_length = read(io, UInt16)
    records_count = read(io, UInt32)
    point_return_count = read(io, UInt32, 5)
    x_scale = read(io, Float64)
    y_scale = read(io, Float64)
    z_scale = read(io, Float64)
    x_offset = read(io, Float64)
    y_offset = read(io, Float64)
    z_offset = read(io, Float64)
    x_max = read(io, Float64)
    x_min = read(io, Float64)
    y_max = read(io, Float64)
    y_min = read(io, Float64)
    z_max = read(io, Float64)
    z_min = read(io, Float64)
    vlrs = [read(io, LasVariableLengthRecord, false) for i=1:n_vlr]
    user_defined_bytes = read(io, data_offset - position(io))

    # put it all in a type
    header = LasHeader12(
        file_source_id,
        global_encoding,
        guid_1,
        guid_2,
        guid_3,
        guid_4,
        version_major,
        version_minor,
        system_id,
        software_id,
        creation_doy,
        creation_year,
        header_size,
        data_offset,
        n_vlr,
        data_format_id,
        data_record_length,
        records_count,
        point_return_count,
        x_scale,
        y_scale,
        z_scale,
        x_offset,
        y_offset,
        z_offset,
        x_max,
        x_min,
        y_max,
        y_min,
        z_max,
        z_min,
        vlrs,
        user_defined_bytes
    )
end


function Base.write(io::IO, h::LasHeader12)
    write(io, h.file_source_id)
    write(io, h.global_encoding)
    write(io, h.guid_1)
    write(io, h.guid_2)
    write(io, h.guid_3)
    write(io, h.guid_4)
    write(io, h.version_major)
    write(io, h.version_minor)
    write(io, h.system_id)
    write(io, h.software_id)
    write(io, h.creation_doy)
    write(io, h.creation_year)
    write(io, h.header_size)
    write(io, h.data_offset)
    @assert length(h.variable_length_records) == h.n_vlr
    write(io, h.n_vlr)
    write(io, h.data_format_id)
    write(io, h.data_record_length)
    write(io, h.records_count)
    @assert length(h.point_return_count) == 5
    write(io, h.point_return_count)
    write(io, h.x_scale)
    write(io, h.y_scale)
    write(io, h.z_scale)
    write(io, h.x_offset)
    write(io, h.y_offset)
    write(io, h.z_offset)
    write(io, h.x_max)
    write(io, h.x_min)
    write(io, h.y_max)
    write(io, h.y_min)
    write(io, h.z_max)
    write(io, h.z_min)
    lasversion = VersionNumber(h.version_major, h.version_minor)
    if lasversion >= v"1.3"
        write(io, 0x0000) # Start of waveform data record (unsupported)
    end
    for i in 1:h.n_vlr
        write(io, h.variable_length_records[i])
    end
    write(io, h.user_defined_bytes)
    # note that for LAS 1.4 a few new parts need to be written
    # possibly introduce typed headers like the points
    nothing
end

"""If true, GPS Time is standard GPS Time (satellite GPS Time) minus 1e9.
If false, GPS Time is GPS Week Time.

Note that not all software sets this encoding correctly."""
is_standard_gps(h::LasHeader12) = isodd(h.global_encoding)

# the header implemented based on LAS 1.2
# TODO: check compatibility other LAS versions

#=
COMPATIBILITY WITH LAS 1.2:
One unavoidable change has been made to the Public Header Block; Start of Waveform
Data Packet Record. This long, long has been added to the end of the block and thus
little or no change will be needed in LAS 1.2 readers that do not need waveform data.
There are no changes to Point Data Record types 0 through 3. The waveform encoded
data types have been added as Point Data Record types 4 and 5.

THE ADDITIONS OF LAS 1.4 INCLUDE:
Backward compatibility with LAS 1.1 – LAS 1.3 when payloads consist of only legacy
content
=#

mutable struct LasHeader
    file_source_id::UInt16
    global_encoding::UInt16
    guid_1::UInt32
    guid_2::UInt16
    guid_3::UInt16
    guid_4::AbstractString
    version_major::UInt8
    version_minor::UInt8
    system_id::AbstractString
    software_id::AbstractString
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
    println(io, "LasHeader with $n points.")
    println(io, string("\tfile_source_id = ", header.file_source_id))
    println(io, string("\tglobal_encoding = ", header.global_encoding))
    println(io, string("\tguid_1 = ", header.guid_1))
    println(io, string("\tguid_2 = ", header.guid_2))
    println(io, string("\tguid_3 = ", header.guid_3))
    println(io, string("\tguid_4 = ", header.guid_4))
    println(io, string("\tversion_major = ", header.version_major))
    println(io, string("\tversion_minor = ", header.version_minor))
    println(io, string("\tsystem_id = ", header.system_id))
    println(io, string("\tsoftware_id = ", header.software_id))
    println(io, string("\tcreation_doy = ", header.creation_doy))
    println(io, string("\tcreation_year = ", header.creation_year))
    println(io, string("\theader_size = ", header.header_size))
    println(io, string("\tdata_offset = ", header.data_offset))
    println(io, string("\tn_vlr = ", header.n_vlr))
    println(io, string("\tdata_format_id = ", header.data_format_id))
    println(io, string("\tdata_record_length = ", header.data_record_length))
    println(io, string("\trecords_count = ", header.records_count))
    println(io, string("\tpoint_return_count = ", header.point_return_count))
    println(io, string("\tx_scale = ", header.x_scale))
    println(io, string("\ty_scale = ", header.y_scale))
    println(io, string("\tz_scale = ", header.z_scale))
    println(io, string("\tx_offset = ", header.x_offset))
    println(io, string("\ty_offset = ", header.y_offset))
    println(io, string("\tz_offset = ", header.z_offset))
    println(io, string("\tx_max = ", header.x_max))
    println(io, string("\tx_min = ", header.x_min))
    println(io, string("\ty_max = ", header.y_max))
    println(io, string("\ty_min = ", header.y_min))
    println(io, string("\tz_max = ", header.z_max))
    println(io, string("\tz_min = ", header.z_min))

    if !isempty(header.variable_length_records)
        nrecords = min(10, size(header.variable_length_records, 1))

        println(io, string("\tvariable_length_records (max 10) = "))
        for vlr in header.variable_length_records[1:nrecords]
            println(io, "\t\t($(vlr.user_id), $(vlr.record_id)) => ($(vlr.description), $(sizeof(vlr.data)) bytes...)")
        end
        println("\t\t...")
    end
end

function readstring(io, nb::Integer)
    bytes = read(io, nb)
    # strip possible null bytes
    lastchar = findlast(bytes .!= 0)
    if lastchar == nothing
        return ""
    else
        return String(bytes[1:lastchar])
    end
end

function writestring(io, str::AbstractString, nb::Integer)
    n = length(str)
    npad = nb - n
    if npad < 0
        error("string too long")
    elseif npad == 0
        write(io, str)
    else
        writestr = string(str * "\0"^npad)
        write(io, writestr)
    end
end

function Base.read(io::IO, ::Type{LasHeader})
    file_source_id = read(io, UInt16)
    global_encoding = read(io, UInt16)
    guid_1 = read(io, UInt32)
    guid_2 = read(io, UInt16)
    guid_3 = read(io, UInt16)
    guid_4 = readstring(io, 8)
    version_major = read(io, UInt8)
    version_minor = read(io, UInt8)
    system_id = readstring(io, 32)
    software_id = readstring(io, 32)
    creation_doy = read(io, UInt16)
    creation_year = read(io, UInt16)
    header_size = read(io, UInt16)
    data_offset = read(io, UInt32)
    n_vlr = read(io, UInt32)
    data_format_id = read(io, UInt8)
    data_record_length = read(io, UInt16)
    records_count = read(io, UInt32)
    point_return_count = read!(io, Vector{UInt32}(undef, 5))
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
    lasversion = VersionNumber(version_major, version_minor)
    if lasversion >= v"1.3"
         # start of waveform data record (unsupported)
        _ = read(io, UInt64)
    end
    vlrs = [read(io, LasVariableLengthRecord, false) for i=1:n_vlr]

    # From here until the data_offset everything is read in
    # as user_defined_bytes. To avoid a seek that we cannot do on STDIN,
    # we calculate how much to read in.
    vlrlength = n_vlr == 0 ? 0 : sum(sizeof, vlrs)
    pos = header_size + vlrlength
    user_defined_bytes = read(io, data_offset - pos)

    # put it all in a type
    header = LasHeader(
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

function Base.write(io::IO, h::LasHeader)
    write(io, h.file_source_id)
    write(io, h.global_encoding)
    write(io, h.guid_1)
    write(io, h.guid_2)
    write(io, h.guid_3)
    writestring(io, h.guid_4, 8)
    write(io, h.version_major)
    write(io, h.version_minor)
    writestring(io, h.system_id, 32)
    writestring(io, h.software_id, 32)
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
        # start of waveform data record (unsupported)
        write(io, UInt64(0))
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
is_standard_gps(h::LasHeader) = isodd(h.global_encoding)

"Check if the projection information is in WKT format (true) or GeoTIFF (false)"
function is_wkt(h::LasHeader)
    wkit_bit = Bool((h.global_encoding & 0x0010) >> 4)
    if !wkit_bit && h.data_format_id > 5
        throw(DomainError("WKT bit must be true for point types higher than 5"))
    end
    wkit_bit
end

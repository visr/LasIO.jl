struct KeyEntry
    keyid::UInt16
    tiff_tag_location::UInt16
    count::UInt16
    value_offset::UInt16
end

struct GeoKeys
    key_directory_version::UInt16
    key_reversion::UInt16
    minor_revision::UInt16
    number_of_keys::UInt16
    keys::Vector{KeyEntry}
end

struct SRID
    authority::Symbol
    code::Int64
end

# version numbers are fixed in the LAS specification
GeoKeys(keys::Vector{KeyEntry}) = GeoKeys(0x0001, 0x0001, 0x0000, UInt16(length(keys)), keys)

struct GeoDoubleParamsTag
    double_params::Vector{Float64}
end

struct GeoAsciiParamsTag
    ascii_params::String
    nb::Int  # number of bytes
    GeoAsciiParamsTag(s::AbstractString, nb::Integer) = new(ascii(s), Int(nb))
end

const id_geokeydirectorytag = UInt16(34735)
const id_geodoubleparamstag = UInt16(34736)
const id_geoasciiparamstag = UInt16(34737)

"test whether a vlr is a GeoKeyDirectoryTag, GeoDoubleParamsTag or GeoAsciiParamsTag"
is_srs(vlr::LasVariableLengthRecord) = vlr.record_id in (
    id_geokeydirectorytag,
    id_geodoubleparamstag,
    id_geoasciiparamstag)

# number of bytes
Base.sizeof(data::GeoKeys) = 8 * Int(data.number_of_keys) + 8
Base.sizeof(data::GeoDoubleParamsTag) = sizeof(data.double_params)
Base.sizeof(data::GeoAsciiParamsTag) = data.nb

"Construct a projection VLR based on an EPSG code"
function LasVariableLengthRecord(header::LasHeader, srid::SRID)
    if srid.authority != :epsg
        throw(ArgumentError("No other code than EPSG-code is implemented"))
    elseif srid.code < 0
        throw(ArgumentError("EPSG is not valid: negative integer input given"))
    end

    reserved = 0xAABB
    user_id = "LASF_Projection"
    description = "GeoTIFF GeoKeyDirectoryTag"
    record_id = id_geokeydirectorytag

    data = GeoKeys(srid.code)

    return LasVariableLengthRecord(
        reserved,
        user_id,
        record_id,
        description,
        data
    )
end

function Base.write(io::IO, data::GeoKeys)
    write(io, data.key_directory_version)
    write(io, data.key_reversion)
    write(io, data.minor_revision)
    write(io, data.number_of_keys)
    for keyEntry in data.keys
        write_key_entry(io, keyEntry)
    end
end

Base.write(io::IO, data::GeoDoubleParamsTag) = write(io, data.double_params)
Base.write(io::IO, data::GeoAsciiParamsTag) = writestring(io, data.ascii_params, data.nb)

"Create GeoKeys from EPSG code. Assumes CRS is projected and in meters."
function GeoKeys(epsg::Integer)
    #Standard types
    is_projected = KeyEntry(UInt16(1024), UInt16(0), UInt16(1), UInt16(1))         # Projected
    proj_linear_units = KeyEntry(UInt16(1025), UInt16(0), UInt16(1), UInt16(1))    # Units in meter
    projected_cs_type = KeyEntry(UInt16(3072), UInt16(0), UInt16(1), UInt16(epsg)) # EPSG code
    vertical_units = KeyEntry(UInt16(3076), UInt16(0), UInt16(1), UInt16(9001))    # Units in meter
    keys = [is_projected, proj_linear_units, projected_cs_type, vertical_units]
    GeoKeys(keys)
end

function write_key_entry(io, entry::KeyEntry)
    write(io, entry.keyid)
    write(io, entry.tiff_tag_location)
    write(io, entry.count)
    write(io, entry.value_offset)
end

"Get the EPSG code of the projection in the header"
function epsg_code(header::LasHeader)
    if is_wkt(header)
        throw(ArgumentError("WKT format projection information not implemented"))
    end
    vlrs = header.variable_length_records
    ind = findfirst(x -> x.record_id == id_geokeydirectorytag, vlrs)
    if ind === nothing
        nothing
    else
        vlrs[ind].data.keys[3].value_offset
    end
end

"Set the projection in the header, without altering the points"
function epsg_code!(header::LasHeader, epsg::Integer)
    # small check if epsg is valid
    if epsg < 0
        throw(ArgumentError("EPSG is not valid: negative integer input given"))
    elseif is_wkt(header)
        throw(ArgumentError("Setting the SRS in WKT format not implemented"))
    end

    # read old header metadata
    old_vlrlength = header.n_vlr == 0 ? 0 : sum(sizeof, header.variable_length_records)
    old_offset = header.data_offset

    # reconstruct VLRs
    vlrs = LasVariableLengthRecord[]
    srid = SRID(:epsg,epsg)
    push!(vlrs, LasVariableLengthRecord(header, srid))
    # keep existing non-SRS VLRs intact
    append!(vlrs, filter(!is_srs, header.variable_length_records))

    # update header
    header.variable_length_records = vlrs
    header.n_vlr = length(header.variable_length_records)
    new_vlrlength = header.n_vlr == 0 ? 0 : sum(sizeof, header.variable_length_records)
    # update offset to point data, assuming the VLRs come before the data, i.e. not extended VLR
    header.data_offset = old_offset - old_vlrlength + new_vlrlength
    header
end

function read_vlr_data(io::IO, record_id::Integer, nb::Integer)
    if record_id == id_geokeydirectorytag
        return read(io, GeoKeys)
    elseif record_id == id_geodoubleparamstag
        double_params = zeros(nb ÷ 8)
        read!(io, double_params)
        return GeoDoubleParamsTag(double_params)
    elseif record_id == id_geoasciiparamstag
        ascii_params = readstring(io, nb)
        return GeoAsciiParamsTag(ascii_params, nb)
    else
        return read(io, nb)
    end
end

function Base.read(io::IO, ::Type{GeoKeys})
    key_directory_version = read(io, UInt16)
    key_reversion = read(io, UInt16)
    minor_revision = read(io, UInt16)
    number_of_keys = read(io, UInt16)
    keys = KeyEntry[]
    for i in 1:number_of_keys
        keyid = read(io, UInt16)
        tiff_tag_location = read(io, UInt16)
        count = read(io, UInt16)
        value_offset = read(io, UInt16)
        push!(keys, KeyEntry(
            keyid,
            tiff_tag_location,
            count,
            value_offset
        ))
    end
    return GeoKeys(
        key_directory_version,
        key_reversion,
        minor_revision,
        number_of_keys,
        keys
    )
end

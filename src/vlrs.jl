"""
A LAS "variable length record" - the generic way to store extra user or
organization defined binary metadata in LAS files.
"""
struct LasVariableLengthRecord
    reserved::UInt16
    user_id::FixedString{16}
    record_id::UInt16
    record_length_after_header::UInt16
    description::FixedString{32}
    data  # anything with read+write+sizeof methods, like GeoKeys or Vector{UInt8}
end

LasVariableLengthRecord(r::UInt16, s::String, i::UInt16, d::String, x::Any) = LasVariableLengthRecord(r, FixedString{16}(s), i, sizeof(x), FixedString{32}(d), x)

"""
A LAS "extended variable length record" - the generic way to store large
extra user or organization defined binary metadata in LAS files.
"""
struct ExtendedLasVariableLengthRecord
    reserved::UInt16
    user_id::FixedString{16}  # 16 bytes
    record_id::UInt16
    record_length_after_header::UInt64
    description::FixedString{32}  # 32 bytes
    data  # anything with read+write+sizeof methods, like GeoKeys or Vector{UInt8}
end

ExtendedLasVariableLengthRecord(r::UInt16, s::String, i::UInt16, d::String, x::Any) = LasVariableLengthRecord(r, FixedString{16}(s), i, sizeof(x), FixedString{32}(d), x)

function Base.show(io::IO, vlr::Union{LasVariableLengthRecord, ExtendedLasVariableLengthRecord})
    println(io, "Variable length record with id: $(vlr.record_id), description: $(vlr.description)")
end

"""Read VLR data record, with specific branches for known record ids."""
function read_vlr_data(io::IO, record_id::Integer, nb::Integer)

    # classification
    if record_id == 0
        @assert nb == 256 * 16 "Size of classification data VLR is wrong."
        return [read(io, Classification) for _=1:256]

    # description
    elseif record_id == 3
        return read(io, FixedString{nb})

    # extra bytes
    elseif record_id == 4
        n_fields = Int(nb // 192)
        return [read(io, ExtraBytes) for _=1:n_fields]

    # spatial reference records
    elseif record_id == id_geokeydirectorytag
        return read(io, GeoKeys)
    elseif record_id == id_geodoubleparamstag
        double_params = zeros(nb ÷ 8)
        read!(io, double_params)
        return GeoDoubleParamsTag(double_params)
    elseif record_id == id_geoasciiparamstag
        return read(io, FixedString{nb})

    # waveform descriptor for LAS 1.3 and 1.4
    elseif (100 <= record_id < 355)
        return read(io, waveform_descriptor)
    else
        return read(io, nb)
    end
end

# Read a variable length metadata record from a stream.
#
# If `extended` is true, the VLR is one of the extended VLR types specified in
# the LAS 1.4 spec which can be larger and come after the point data.
function Base.read(io::IO, ::Type{LasVariableLengthRecord})
    # `reserved` is meant to be 0 according to the LAS spec 1.4, but earlier
    # versions set it to 0xAABB.  Whatever, I guess we just store&ignore for now.
    # See https://groups.google.com/forum/#!topic/lasroom/SVtNBA2y9iI
    reserved = read(io, UInt16)
    user_id = read(io, FixedString{16})
    record_id = read(io, UInt16)
    record_data_length = read(io, UInt16)
    description = read(io, FixedString{32})
    data = read_vlr_data(io, record_id, record_data_length)
    LasVariableLengthRecord(
        reserved,
        user_id,
        record_id,
        record_data_length,
        description,
        data
    )
end

function Base.read(io::IO, ::Type{ExtendedLasVariableLengthRecord})
    # `reserved` is meant to be 0 according to the LAS spec 1.4, but earlier
    # versions set it to 0xAABB.  Whatever, I guess we just store&ignore for now.
    # See https://groups.google.com/forum/#!topic/lasroom/SVtNBA2y9iI
    reserved = read(io, UInt16)
    user_id = read(io, FixedString{16})
    record_id = read(io, UInt16)
    record_data_length = read(io, UInt64)
    description = read(io, FixedString{32})
    data = read_vlr_data(io, record_id, record_data_length)
    ExtendedLasVariableLengthRecord(
        reserved,
        user_id,
        record_id,
        record_data_length,
        description,
        data
    )
end

function Base.write(io::IO, vlr::LasVariableLengthRecord, extended::Bool=false)
    write(io, vlr.reserved)
    write(io, vlr.user_id)
    write(io, vlr.record_id)
    record_data_length = extended ? UInt64(sizeof(vlr.data)) : UInt16(sizeof(vlr.data))
    write(io, record_data_length)
    write(io, vlr.description)
    write(io, vlr.data)
    nothing
end

# size of a VLR in bytes
# assumes it is not extended VLR
Base.sizeof(vlr::LasVariableLengthRecord) = 54 + vlr.record_length_after_header
Base.sizeof(vlr::ExtendedLasVariableLengthRecord) = 60 + vlr.record_length_after_header

"""LASF_Spec record id 0."""
@gen_io struct Classification
    class_number::UInt8
    description::FixedString{15}
end

"""LASF_Spec record id 4 data struct."""
struct ExtraBytes{T<:Real}
    data_type::DataType
    reserved::UInt16  # 2 bytes
    data_type_key::UInt8  # 1 byte
    options::UInt8  # 1 byte
    name::FixedString{32}   # 32 bytes
    unused::SVector{4, UInt8}  # 4 bytes
    no_data::SVector{3, T}  # 24 = 3*8 bytes
    min::SVector{3, T}  # 24 = 3*8 bytes
    max::SVector{3, T}  # 24 = 3*8 bytes
    scale::SVector{3, Float64}  # 24 = 3*8 bytes
    offset::SVector{3, Float64}  # 24 = 3*8 bytes
    description::FixedString{32}  # 32 bytes
end

datatypes = Dict(
    # 0x00 => special case
    # SVector{1,}
    0x01 => UInt8,
    0x02 => Int8,
    0x03 => UInt16,
    0x04 => Int16,
    0x05 => UInt32,
    0x06 => Int32,
    0x07 => UInt64,
    0x08 => Int64,
    0x09 => Float32,
    0x0a => Float64,
    # SVector{2,}
    0x0b => SVector{2, UInt8},
    0x0c => SVector{2, Int8},
    0x0d => SVector{2, UInt16},
    0x0e => SVector{2, Int16},
    0x0f => SVector{2, UInt32},
    0x10 => SVector{2, Int32},
    0x11 => SVector{2, UInt64},
    0x12 => SVector{2, Int64},
    0x13 => SVector{2, Float32},
    0x14 => SVector{2, Float64},
    # SVector{3,}
    0x15 => SVector{3, UInt8},
    0x16 => SVector{3, Int8},
    0x17 => SVector{3, UInt16},
    0x18 => SVector{3, Int16},
    0x19 => SVector{3, UInt32},
    0x1a => SVector{3, Int32},
    0x1b => SVector{3, UInt64},
    0x1c => SVector{3, Int64},
    0x1d => SVector{3, Float32},
    0x1e => SVector{3, Float64})

"""Determine upcasted type for extra_bytes struct."""
function upcasttype(t::UInt8)
    if t in (9, 10, 19, 20, 29, 30)
        return Float64
    elseif iseven(t)
        return Int64
    else
        return UInt64
    end
end

function Base.read(io::IO, ::Type{ExtraBytes})
    reserved = read(io, UInt16)
    data_type_key = read(io, UInt8)
    options = read(io, UInt8)
    name = read(io, FixedString{32})
    # lowercase with _ for use as fieldname
    name = FixedString{32}(replace(lowercase(name), " ", "_"))
    unused = read(io, SVector{4, UInt8})

    # determine datatype
    if data_type_key == 0
        data_type = SVector{Int(options), UInt8}
    elseif data_type_key in keys(datatypes)
        data_type = datatypes[data_type_key]
    else
        error("Invalid extra_bytes structure.")
    end
    upcast_data_type = upcasttype(data_type_key)

    no_data = read(io, SVector{3, upcast_data_type})  # 24 = 3*8 bytes
    min = read(io, SVector{3, upcast_data_type})  # 24 = 3*8 bytes
    max = read(io, SVector{3, upcast_data_type})  # 24 = 3*8 bytes
    scale = read(io, SVector{3, Float64})  # 24 = 3*8 bytes
    offset = read(io, SVector{3, Float64})  # 24 = 3*8 bytes
    description = read(io, FixedString{32})  # 32 bytes
    ExtraBytes(
        data_type,
        reserved,
        data_type_key,
        options,
        name,
        unused,
        no_data,
        min,
        max,
        scale,
        offset,
        description
    )
end

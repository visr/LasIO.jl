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

LasVariableLengthRecord(r::UInt16, s::String, i::UInt16, d::String, x::Any) = LasVariableLengthRecord(r, FixedString{16}(s), i, sizeof(x), FixedString{32}(d), x)


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
    println(record_data_length)
    println(record_id)
    println(description)
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
    println(record_data_length)
    println(record_id)
    println(description)
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
struct classification
    class_number::UInt8
    description::AbstractString
end

# """LASF_Spec record id 4."""
# struct extra_bytes
#     reserved::UInt16; # 2 bytes
#     data_type::UInt8 # 1 byte
#     options::UInt8 # 1 byte
#     char name[32]; # 32 bytes
#     unsigned char unused[4]; # 4 bytes
#     anytype no_data[3]; # 24 = 3*8 bytes
#     anytype min[3]; # 24 = 3*8 bytes
#     anytype max[3]; # 24 = 3*8 bytes
#     double scale[3]; # 24 = 3*8 bytes
#     double offset[3]; # 24 = 3*8 bytes
#     char description[32]; # 32 bytes
# end

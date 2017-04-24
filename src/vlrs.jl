"""
A LAS "variable length record" - the generic way to store extra user or
organization defined binary metadata in LAS files.
"""
immutable LasVariableLengthRecord
    reserved::UInt16
    user_id::FixedString{16}
    record_id::UInt16
    description::FixedString{32}
    data::Vector{UInt8}
end


# Read a variable length metadata record from a stream.
#
# If `extended` is true, the VLR is one of the extended VLR types specified in
# the LAS 1.4 spec which can be larger and come after the point data.
function Base.read(io::IO, ::Type{LasVariableLengthRecord}, extended::Bool=false)
    # `reserved` is meant to be 0 according to the LAS spec 1.4, but earlier
    # versions set it to 0xAABB.  Whatever, I guess we just store&ignore for now.
    # See https://groups.google.com/forum/#!topic/lasroom/SVtNBA2y9iI
    reserved = read(io, UInt16)
    user_id = read(io, FixedString{16})
    record_id = read(io, UInt16)
    record_data_length = extended ? read(io, UInt64) : read(io, UInt16)
    description = read(io, FixedString{32})
    data = read(io, record_data_length)
    LasVariableLengthRecord(
        reserved,
        user_id,
        record_id,
        description,
        data
    )
end

function Base.write(io::IO, vlr::LasVariableLengthRecord, extended::Bool=false)
    write(io, vlr.reserved)
    write(io, vlr.user_id)
    write(io, vlr.record_id)
    record_data_length = extended ? UInt64(length(vlr.data)) : UInt16(length(vlr.data))
    write(io, record_data_length)
    write(io, vlr.description)
    write(io, vlr.data)
    nothing
end

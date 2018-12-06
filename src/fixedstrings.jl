"""
    FixedString{N<:Int}(str, truncate=false, nullterm=true)

A string type with a fixed maximum size `N` in bytes.  This is useful for
serializing to and from binary data formats containing fixed length strings.
When constructing a FixedString, if `truncate` is true, the input string will
be truncated to fit into the number of bytes `N`.  If `nullterm` is true, ensure
that the string has length strictly less than `N`, to fit in a single
terminating byte.

When a FixedString{N} is serialized using `read()` and `write()`, exactly `N`
bytes are read and written, with any padding being set to '0'.
"""
struct FixedString{N} <: AbstractString
    str::String

    function (::Type{FixedString{N}})(str::String) where N
        n = sizeof(str)
        n <= N || throw(ArgumentError("sizeof(str) = $n does not fit into a FixedString{$N}"))
        return new{N}(str)
    end
end

function (::Type{FixedString{N}})(str::AbstractString; nullterm=true, truncate=false) where N
    maxbytes = nullterm ? N-1 : N
    if sizeof(str) > maxbytes
        truncate || throw(ArgumentError("sizeof(str) = $(sizeof(str)) too long for FixedString{$N}"))
        strunc = String(str[1:maxbytes])
        while sizeof(strunc) > maxbytes
            strunc = strunc[1:end-1] # Needed for non-ascii chars
        end
        return FixedString{N}(String(strunc))
    else
        return FixedString{N}(String(str))
    end
end

# Minimal AbstractString required interface
Base.sizeof(f::FixedString{N}) where {N} = N
Base.iterate(f::FixedString{N}) where {N} = iterate(f.str)
Base.iterate(f::FixedString{N}, state::Integer) where {N} = iterate(f.str, state)

# Be permissive by setting nullterm to false for reading by default.
function Base.read(io::IO, ::Type{FixedString{N}}; nullterm=false) where {N}
    bytes = zeros(UInt8, N)
    bytes = read!(io, bytes)
    i = findfirst(isequal(0), bytes)
    idx = i === nothing ? N : i - 1
    FixedString{N}(String(bytes[1:idx]), nullterm=nullterm)
end

function Base.write(io::IO, f::FixedString{N}) where {N}
    write(io, f.str)
    for i=1:N-sizeof(f.str)
        write(io, UInt8(0))
    end
end

"""
    FixedString{N}(str, truncate=false, nullterm=true)

A string type with a fixed maximum size `N` in bytes.  This is useful for
serializing to and from binary data formats containing fixed length strings.
When constructing a FixedString, if `truncate` is true, the input string will
be truncated to fit into the number of bytes `N`.  If `nullterm` is true, ensure
that the string has length strictly less than `N`, to fit in a single
terminating byte.

When a FixedString{N} is serialized using `read()` and `write()`, exactly `N`
bytes are read and written, with any padding being set to '0'.
"""
immutable FixedString{N} <: AbstractString
    str::String

    function (::Type{FixedString{N}}){N}(str::String)
        n = sizeof(str)
        n <= N || throw(ArgumentError("sizeof(str) = $n does not fit into a FixedString{$N}"))
        return new{N}(str)
    end
end

function (::Type{FixedString{N}}){N}(str::AbstractString; nullterm=true, truncate=false)
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
Base.endof{N}(f::FixedString{N})  = endof(f.str)
Base.next{N}(f::FixedString{N}, i::Int)   = next(f.str, i)
Base.sizeof{N}(f::FixedString{N}) = N

# Be permissive by setting nullterm to false for reading by default.
function Base.read{N}(io::IO, ::Type{FixedString{N}}; nullterm=false)
    bytes = read(io, UInt8, N)
    i = findfirst(bytes, 0)
    FixedString{N}(String(bytes[1:(i > 0 ? i-1 : N)]), nullterm=nullterm)
end

function Base.write{N}(io::IO, f::FixedString{N})
    write(io, f.str)
    for i=1:N-sizeof(f.str)
        write(io, UInt8(0))
    end
end

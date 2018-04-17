"""Returns fieldtypes like fieldnames."""
function fieldtypes(T::Type) return [fieldtype(T, i) for i = 1:length(fieldnames(T))] end

"Generate read (unpack) method for structs."
function generate_read(T::Type)
    types = fieldtypes(T)

    # Create unpack function expression
    function_expression = :(function Base.read(io::IO, t::Type{$T}) end)

    # Create Type call expression and add parameters
    type_expression = :((t)())
    for t in types
        read_expression = :(read(io, $t))
        append!(type_expression.args, 0)  # dummy with known length
        type_expression.args[end] = read_expression
    end

    # Replace empty function body with Type call
    function_expression.args[2] = type_expression

    eval(function_expression)
end

"Generate write (pack) method for structs."
function generate_write(T::Type)
    # Create pack function expression
    function_expression = :(function Base.write(io::IO, T::$T) end)

    body_expression = quote end
    for t in fieldnames(T)
        write_expression = :(write(io, T.$t))
        append!(body_expression.args, 0)  # dummy with known length
        body_expression.args[end] = write_expression
    end

    # Return nothing at the end
    append!(body_expression.args, 0)  # dummy with known length
    body_expression.args[end] = :(nothing)

    # Replace empty function body with write calls
    function_expression.args[2] = body_expression

    eval(function_expression)
end

function generate_io(T::Type)
    generate_read(T)
    generate_write(T)
end

"""Generate IO expressions macro."""
macro gen_io(typ::Expr)
    T = typ.args[2]
    if isexpr(T, :(<:))
        T = T.args[1]
    end
    if isexpr(T, :curly)
        T = T.args[1]
    end

    ret = Expr(:toplevel, :(Base.@__doc__ $(typ)))
    push!(ret.args, :(generate_io($T)))
    return esc(ret)
end

"""Combines base struct with provided fieldnames and types to generate new struct."""
function gen_append_struct(T::Type, extrafields::Vector{Tuple{Symbol, DataType}})
    name = gensym("$T")  # this name has # in there (!)
    struct_expression = :(struct $name <: LasPoint end)

    basefields = collect(zip(fieldnames(T), fieldtypes(T)))
    fields = vcat(basefields, extrafields)

    for (fname, ftype) in fields
        field = Expr(:(::), fname, ftype)
        append!(struct_expression.args[3].args, 0)  # dummy with known length
        struct_expression.args[3].args[end] = field
    end

    eval(struct_expression)
    eval(name)
end

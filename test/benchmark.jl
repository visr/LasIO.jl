using FileIO
using LasIO
using Mmap
using BenchmarkTools

workdir = dirname(@__FILE__)
# source: http://www.liblas.org/samples/
filename = "libLAS_1.2.las" # point format 0
testfile = joinpath(workdir, filename)
writefile = joinpath(workdir, "libLAS_1.2-out.las")

function read_original(io::IO, ::Type{LasPoint0})
    x = read(io, Int32)
    y = read(io, Int32)
    z = read(io, Int32)
    intensity = read(io, UInt16)
    flag_byte = read(io, UInt8)
    raw_classification = read(io, UInt8)
    scan_angle = read(io, Int8)
    user_data = read(io, UInt8)
    pt_src_id = read(io, UInt16)
    LasPoint0(
        x,
        y,
        z,
        intensity,
        flag_byte,
        raw_classification,
        scan_angle,
        user_data,
        pt_src_id
    )
end

function test_orignal()
    open(testfile) do s
        LasIO.skiplasf(s)
        header = read(s, LasHeader)

        n = header.records_count
        pointtype = pointformat(header)
        pointdata = Vector{pointtype}(undef, n)
        for i=1:n
            pointdata[i] = read_original(s, pointtype)
        end
        header, pointdata
    end
end

function test_new()
    open(testfile) do s
        LasIO.skiplasf(s)
        header = read(s, LasHeader)

        n = header.records_count
        pointtype = pointformat(header)
        pointdata = Vector{pointtype}(undef, n)
        for i=1:n
            pointdata[i] = read(s, pointtype)
        end
        header, pointdata
    end
end

function test_stream()
    open(testfile) do s
        LasIO.skiplasf(s)
        header = read(s, LasHeader)

        n = header.records_count
        pointtype = pointformat(header)

        pointsize = Int(header.data_record_length)
        pointbytes = Mmap.mmap(s, Vector{UInt8}, n*pointsize, position(s))
        pointdata = PointVector{pointtype}(pointbytes, pointsize)

        for i=1:n
            pointdata[i]
        end

        header, pointdata
    end
end

oh, op = test_orignal()
nh, np = test_new()
sh, sp = test_stream()

println("Original function")
@btime test_orignal()
println("New function using generated read")
@btime test_new()
println("New function using streaming")
@btime test_stream()

@show op, np, sp
@assert op[5] == np[5] == sp[5]

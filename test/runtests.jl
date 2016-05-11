using LasIO
using FileIO
using Base.Test

workdir = dirname(@__FILE__)
filename = "libLAS_1.2.las" # point format 0
testfile = joinpath(workdir, filename)
writefile = joinpath(workdir, "libLAS_1.2-out.las")

io = open(testfile)
seek(io, 4)
header = read(io, LasHeader)
n = Int(header.records_count)

function centroid(io, header)
    x_sum = 0.0
    y_sum = 0.0
    z_sum = 0.0

    for i = 1:n
        p = read(io, LasPoint0)
        x = xcoord(p, header)
        y = ycoord(p, header)
        z = zcoord(p, header)

        x_sum += x
        y_sum += y
        z_sum += z
    end

    x_avg = x_sum / n
    y_avg = y_sum / n
    z_avg = z_sum / n

    x_avg, y_avg, z_avg
end

seek(io, header.data_offset)
centroid(io, header)
seek(io, header.data_offset)
@time x_avg, y_avg, z_avg = centroid(io, header)

@test_approx_eq x_avg 1442694.2739025319
@test_approx_eq y_avg 377449.24373880465
@test_approx_eq z_avg 861.60254888088491

close(io)

headerio, pointdata = load(testfile)
save(writefile, headerio, pointdata)

rm(writefile)

open(filename) do io
    seek(io, header.data_offset)
    ptdata = Mmap.mmap(io, Vector{LasPoint0}, n)
    @test ptdata == pointdata
end

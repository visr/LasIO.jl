using FileIO
using LasIO
using Test

workdir = dirname(@__FILE__)
# source: http://www.liblas.org/samples/
filename = "libLAS_1.2.las" # point format 0
testfile = joinpath(workdir, filename)
writefile = joinpath(workdir, "libLAS_1.2-out.las")

# test if output file matches input file
header, pointdata = load(testfile, mmap=true)
n = length(pointdata)
save(writefile, header, pointdata)
@test hash(read(testfile)) == hash(read(writefile))
rm(writefile)

# testing a las file version 1.0 point format 1 file with VLRs
srsfile = joinpath(workdir, "srs.las")
srsfile_out = joinpath(workdir, "srs-out.las")
srsheader, srspoints = load(srsfile, mmap=true)
save(srsfile_out, srsheader, srspoints)
@test hash(read(srsfile)) == hash(read(srsfile_out))
rm(srsfile_out)

# Test editing stream file
srsfile = joinpath(workdir, "srs.las")
srsfile_out = joinpath(workdir, "srs-out.las")
srsheader, srspoints = load(srsfile, mmap=true)
@test_throws ErrorException srspoints[5] = LasPoint1(1,1,1,1,1,1,1,1,1,1.0)

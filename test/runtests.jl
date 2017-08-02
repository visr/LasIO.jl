using FileIO
using LasIO
using Base.Test

workdir = dirname(@__FILE__)
# source: http://www.liblas.org/samples/
filename = "libLAS_1.2.las" # point format 0
testfile = joinpath(workdir, filename)
writefile = joinpath(workdir, "libLAS_1.2-out.las")

"Find the centroid of all points in a LAS file"
function centroid(io, header)
    x_sum = 0.0
    y_sum = 0.0
    z_sum = 0.0
    n = Int(header.records_count)

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

# reading point by point
open(testfile) do io
    header = read(io, LasHeader)

    seek(io, header.data_offset)
    x_avg, y_avg, z_avg = centroid(io, header)

    @test x_avg ≈ 1442694.2739025319
    @test y_avg ≈ 377449.24373880465
    @test z_avg ≈ 861.60254888088491

    seek(io, header.data_offset)
    p = read(io, LasPoint0)

    @test xcoord(p, header) ≈ 1.44013394e6
    @test xcoord(1.44013394e6, header) ≈ p.x
    @test ycoord(p, header) ≈ 375000.23
    @test ycoord(375000.23, header) ≈ p.y
    @test zcoord(p, header) ≈ 846.66
    @test zcoord(846.66, header) ≈ p.z
    @test intensity(p) === 0x00fa
    @test scan_angle(p) === 0x00
    @test user_data(p) === 0x00
    @test pt_src_id(p) === 0x001d
    @test return_number(p) === 0x00
    @test number_of_returns(p) === 0x00
    @test scan_direction(p) === false
    @test edge_of_flight_line(p) === false
    @test classification(p) === 0x02
    @test synthetic(p) === false
    @test key_point(p) === false
    @test withheld(p) === false

    # raw bytes composed of bit fields
    @test flag_byte(p) === 0x00
    @test raw_classification(p) === 0x02

    # recompose bytes with bit fields
    @test flag_byte(return_number(p),number_of_returns(p),scan_direction(p),edge_of_flight_line(p)) === p.flag_byte
    @test raw_classification(classification(p),synthetic(p),key_point(p),withheld(p)) === p.raw_classification

    # TODO GPS time, colors (not in this test file, is point data format 0)
end

# reading complete file into memory
# test if output file matches input file
header, pointdata = load(testfile)
n = length(pointdata)
save(writefile, header, pointdata)
@test hash(read(testfile)) == hash(read(writefile))
rm(writefile)

# memory mapping the point data
# currently disabled since it was broken by
# https://github.com/JuliaLang/julia/pull/21831
# since the data_offset does not necessarily align on the size of LasPoint
# TODO support this again, probably using
# https://github.com/JuliaArrays/UnalignedVectors.jl
# open(testfile) do io
#     seek(io, header.data_offset)
#     ptdata = Mmap.mmap(io, Vector{LasPoint0}, n)
#     @test ptdata == pointdata
# end

# testing a las file version 1.0 point format 1 file with VLRs
srsfile = joinpath(workdir, "srs.las")
srsfile_out = joinpath(workdir, "srs-out.las")
srsheader, srspoints = load(srsfile)
@test srsheader.version_major == 1
@test srsheader.version_minor == 0
@test srsheader.data_format_id == 1
@test srsheader.n_vlr == 3
@test isa(srsheader.variable_length_records, Vector{LasVariableLengthRecord})
for vlr in srsheader.variable_length_records
    @test vlr.reserved === 0xaabb
    @test vlr.user_id == "LASF_Projection"
    @test vlr.description == ""
end

@test srsheader.variable_length_records[1].record_id == 34735  # GeoKeyDirectoryTag
@test srsheader.variable_length_records[2].record_id == 34736  # GeoDoubleParamsTag
@test srsheader.variable_length_records[3].record_id == 34737  # GeoAsciiParamsTag
@test srsheader.variable_length_records[1].data[1:4] == [0x01,0x00,0x01,0x00]
@test all(x -> x === 0x00, srsheader.variable_length_records[2].data)
@test all(x -> x === 0x00, srsheader.variable_length_records[3].data)

save(srsfile_out, srsheader, srspoints)
@test hash(read(srsfile)) == hash(read(srsfile_out))
rm(srsfile_out)

using FileIO
using LasIO
using Test

include("stream.jl")

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
    # magic bytes
    @test String(read(io, 4)) == "LASF"
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
    @test scan_angle(p) === Int8(0)
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

# testing a las file version 1.0 point format 1 file with VLRs
srsfile = joinpath(workdir, "srs.las")
srsfile_out = joinpath(workdir, "srs-out.las")
srsheader, srspoints = load(srsfile)
for record in srsheader.variable_length_records
    @test record.reserved === 0xaabb
    @test record.user_id == "LASF_Projection"
    @test typeof(record.description) == String
    if record.record_id == 34735
        @test record.data.key_directory_version === UInt16(1)
        @test record.data.key_reversion === UInt16(1)
        @test record.data.minor_revision === UInt16(0)
        @test record.data.number_of_keys === UInt16(length((record.data.keys)))
        @test typeof(record.data.keys) == Vector{LasIO.KeyEntry}
    end
end
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

@test srsheader.variable_length_records[1].record_id == LasIO.id_geokeydirectorytag
@test srsheader.variable_length_records[2].record_id == LasIO.id_geodoubleparamstag
@test srsheader.variable_length_records[3].record_id == LasIO.id_geoasciiparamstag
@test typeof(srsheader.variable_length_records[1].data) == LasIO.GeoKeys
@test typeof(srsheader.variable_length_records[2].data) == LasIO.GeoDoubleParamsTag
@test typeof(srsheader.variable_length_records[3].data) == LasIO.GeoAsciiParamsTag

@test LasIO.epsg_code(header) === nothing
@test LasIO.epsg_code(srsheader) === UInt16(32617)
# set the SRS. Note: this will not change points, but merely set SRS-metadata.
epsgheader = deepcopy(srsheader)
LasIO.epsg_code!(epsgheader, 32633)  # set to WGS 84 / UTM zone 33N, not the actual SRS
@test epsgheader.variable_length_records[1].record_id == LasIO.id_geokeydirectorytag
@test count(LasIO.is_srs, srsheader.variable_length_records) == 3
@test count(LasIO.is_srs, epsgheader.variable_length_records) == 1

save(srsfile_out, srsheader, srspoints)
@test hash(read(srsfile)) == hash(read(srsfile_out))
rm(srsfile_out)

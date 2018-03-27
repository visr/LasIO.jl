using FileIO
using LasIO
using Base.Test

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

@test isnull(LasIO.epsg_code(header))
@test LasIO.epsg_code(srsheader) === Nullable{Int}(32617)
# set the SRS. Note: this will not change points, but merely set SRS-metadata.
epsgheader = deepcopy(srsheader)
LasIO.epsg_code!(epsgheader, 32633)  # set to WGS 84 / UTM zone 33N, not the actual SRS
@test epsgheader.variable_length_records[1].record_id == LasIO.id_geokeydirectorytag
@test count(LasIO.is_srs, srsheader.variable_length_records) == 3
@test count(LasIO.is_srs, epsgheader.variable_length_records) == 1

save(srsfile_out, srsheader, srspoints)
@test hash(read(srsfile)) == hash(read(srsfile_out))
rm(srsfile_out)

# Test editing stream file
srsfile = joinpath(workdir, "srs.las")
srsheader, srspoints = load(srsfile, mmap=true, mutable=true)
p = srspoints[5]
p.x = 2
srspoints[5] = p
sync(srspoints)  # necessary?

_, points = load(srsfile, mmap=false)
@test points[5].x == 2

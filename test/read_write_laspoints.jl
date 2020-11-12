struct TestLasPoint
    x::Int32
    y::Int32
    z::Int32
    intensity::UInt16
    flag_byte::UInt8  # return number (3 bits), number of returns (3 bits), scan direction flag, edge of flight line
    raw_classification::UInt8  # classification (5 bits), classification flags
    flag_byte_1::UInt8  # return number (4 bits) & number of returns (4 bits)
    flag_byte_2::UInt8 # classification flags, scanner channel,
    classification::UInt8
    user_data::UInt8
    scan_angle::Int8
    extended_scan_angle::Int16
    pt_src_id::UInt16
    gps_time::Float64
    red::N0f16
    green::N0f16
    blue::N0f16
    nir::N0f16
    wave_packet_descriptor_index::UInt8
    wave_packet_byte_offset::UInt64
    wave_packet_size_in_bytes::UInt32
    wave_return_location::Float32
    wave_x_t::Float32
    wave_y_t::Float32
    wave_z_t::Float32
end

function TestLasPoint()
    return TestLasPoint(
        rand(Int32), # x
        rand(Int32), # y
        rand(Int32), # z
        rand(UInt16), # intensity::UInt16
        rand(UInt8), # flag_byte::UInt8  # return number (3 bits), number of returns (3 bits), scan direction flag, edge of flight line
        rand(UInt8), # raw_classification::UInt8  # classification (5 bits), classification flags
        rand(UInt8), # flag_byte_1::UInt8  # return number (4 bits) & number of returns (4 bits)
        rand(UInt8), # flag_byte_2::UInt8 # classification flags, scanner channel,
        rand(UInt8), # classification::UInt8
        rand(UInt8), # user_data::UInt8
        rand(Int8), # scan_angle::Int16
        rand(Int16), # scan_angle::Int16
        rand(UInt16), # pt_src_id::UInt16
        rand(Float64), # gps_time::Float64
        rand(N0f16), # red::N0f16
        rand(N0f16), # green::N0f16
        rand(N0f16), # blue::N0f16
        rand(N0f16), # nir::N0f16
        rand(UInt8), # wave_packet_descriptor_index::UInt8
        rand(UInt64), # wave_packet_byte_offset::UInt64
        rand(UInt32), # wave_packet_size_in_bytes::UInt32
        rand(Float32), # wave_return_location::Float32
        rand(Float32), # wave_x_t::Float32
        rand(Float32), # wave_y_t::Float32
        rand(Float32), # wave_z_t::Float32
    )
end

function Base.:(==)(h1::T, h2::T) where T <:Union{LasHeader, LasPoint}
    if typeof(h1) != typeof(h2)
        return false
    end
    header_fields = fieldnames(typeof(h1))
    if all([getproperty(h1, p) == getproperty(h2, p) for p in header_fields])
        return true
    else
        @error "The following LasHeader values did not match: $(header_fields[[getproperty(h1, p) != getproperty(h2, p) for p in header_fields]])"
        return false
    end
end

# point formats 0 - 5
get_constructor_values(::Type{LasPoint0}, t::TestLasPoint) = [t.x, t.y, t.z, t.intensity, t.flag_byte, t.raw_classification, t.scan_angle, t.user_data, t.pt_src_id]
get_constructor_values(::Type{LasPoint1}, t::TestLasPoint) = [get_constructor_values(LasPoint0, t)..., t.gps_time]
get_constructor_values(::Type{LasPoint2}, t::TestLasPoint) = [get_constructor_values(LasPoint0, t)..., t.red, t.green, t.blue]
get_constructor_values(::Type{LasPoint3}, t::TestLasPoint) = [get_constructor_values(LasPoint0, t)..., t.gps_time, t.red, t.green, t.blue]
get_constructor_values(::Type{LasPoint4}, t::TestLasPoint) = [get_constructor_values(LasPoint1, t)..., t.wave_packet_descriptor_index, t.wave_packet_byte_offset, t.wave_packet_size_in_bytes, t.wave_return_location, t.wave_x_t, t.wave_y_t, t.wave_z_t]
get_constructor_values(::Type{LasPoint5}, t::TestLasPoint) = [get_constructor_values(LasPoint3, t)..., t.wave_packet_descriptor_index, t.wave_packet_byte_offset, t.wave_packet_size_in_bytes, t.wave_return_location, t.wave_x_t, t.wave_y_t, t.wave_z_t]

# point formats 6 - 10
get_constructor_values(::Type{LasPoint6}, t::TestLasPoint) = [t.x, t.y, t.z, t.intensity, t.flag_byte_1, t.flag_byte_2, t.classification, t.user_data, t.extended_scan_angle, t.pt_src_id, t.gps_time]
get_constructor_values(::Type{LasPoint7}, t::TestLasPoint) = [get_constructor_values(LasPoint6, t)..., t.red, t.green, t.blue]
get_constructor_values(::Type{LasPoint8}, t::TestLasPoint) = [get_constructor_values(LasPoint7, t)..., t.nir]
get_constructor_values(::Type{LasPoint9}, t::TestLasPoint) = [get_constructor_values(LasPoint6, t)..., t.wave_packet_descriptor_index, t.wave_packet_byte_offset, t.wave_packet_size_in_bytes, t.wave_return_location, t.wave_x_t, t.wave_y_t, t.wave_z_t]
get_constructor_values(::Type{LasPoint10}, t::TestLasPoint) = [get_constructor_values(LasPoint8, t)..., t.wave_packet_descriptor_index, t.wave_packet_byte_offset, t.wave_packet_size_in_bytes, t.wave_return_location, t.wave_x_t, t.wave_y_t, t.wave_z_t]


const SUPPORTED_LAS_POINT_FORMATS = [
    LasPoint0,
    LasPoint1,
    LasPoint2,
    LasPoint3,
    LasPoint4, # with waveform
    LasPoint5, # with waveform
    LasPoint6,
    LasPoint7,
    LasPoint8,
    LasPoint9, # with waveform
    LasPoint10, # with waveform
]

@testset "Test different LAS Versions" begin
    workdir = mktempdir()
    for version_minor = 1 : 4
        for point_type_index = 1 : length(SUPPORTED_LAS_POINT_FORMATS)
            point_type = SUPPORTED_LAS_POINT_FORMATS[point_type_index]
            number_of_points = 10
            max_return_number = version_minor > 3 ? 15 : 5
            return_numbers = rand(1 : max_return_number, max_return_number)
            return_count = [UInt32(sum(i .== return_numbers)) for i = 1 : 5]

            # use LasPoint1
            points = [point_type(get_constructor_values(point_type, TestLasPoint())...) for i = 1 : number_of_points]
            data_record_length = size(point_type)

            point_return_count = version_minor == 4 ? zeros(UInt64, 15) : zeros(UInt32, 5)
            return_number_array = clamp.([return_number(p) for p in points], 1, length(point_return_count))
            @inbounds for i in 1:length(point_return_count)
                point_return_count[i] = sum(return_number_array .== i)
            end

            scale = [0.001, 0.002, 0.003]
            offset = [1.0, 2.0, 3.0]
            x_min, x_max = extrema([p.x * scale[1] + offset[1] for  p in points])
            y_min, y_max = extrema([p.y * scale[2] + offset[2] for  p in points])
            z_min, z_max = extrema([p.z * scale[3] + offset[3] for  p in points])

            header_size = 227
            if version_minor == 3
                header_size = 235
            elseif version_minor == 4
                header_size = 375
            end
            t = Dates.now()
            header = LasHeader( 
                UInt16(0), # file_source_id
                UInt16(0), # global_encoding
                UInt32(0), # guid_1
                UInt16(0), # guid_2
                UInt16(0), # guid_3
                "", # guid_4
                UInt8(1), # LAS version major
                UInt8(version_minor), # LAS version minor
                "OTHER", # System
                "Julia LasIO writer", # Software
                UInt16(dayofyear(t)), # creation_year
                UInt16(year(t)), # creation_dayofyear
                version_minor == 4 ? UInt16(header_size) : UInt16(header_size), # header_size
                version_minor == 4 ? UInt32(header_size) : UInt32(header_size), # data_offset
                UInt32(0), # n_vlr
                UInt8(point_type_index-1), # data_format_id
                UInt16(data_record_length), # data_record_length
                version_minor == 4 ? UInt32(0) : number_of_points,
                version_minor == 4 ? fill(UInt32(0), 5) : point_return_count,
                0.001,
                0.001,
                0.001,
                0.0,
                0.0,
                0.0,
                x_max,
                x_min,
                y_max,
                y_min,
                z_max,
                z_min,
                UInt64(0), # start_of_waveform_data_packet_record
                UInt64(0), # start_of_first_extended_variable_length_record
                UInt32(0), # number_of_extended_variable_length_records
                version_minor == 4 ? number_of_points : UInt64(0),  # extended_number_of_point_records
                version_minor == 4 ? point_return_count : fill(UInt32(0), 15), # extended_number_of_points_by_return
                [], # variable_length_records
                [], # user_defined_bytes
            )

            # save data to LAS file
            las_output_file_path = joinpath(workdir, "test_version_1_$(version_minor)_pointformat_LasPoint$(point_type_index-1).las")
            save(las_output_file_path, header, points)
            
            # read las file
            las_input_header, las_points_read = load(las_output_file_path)
            @test las_input_header == header
            @test all(points .== las_points_read)
            
            # save data to LAZ file
            laz_output_file_path = joinpath(workdir, "test_version_1_$(version_minor)_pointformat_LasPoint$(point_type_index-1).laz")
            save(laz_output_file_path, header, points)
            
            # read laz file
            laz_input_header, laz_points_read = load(las_output_file_path)
            @test laz_input_header == header
            @test all(points .== laz_points_read)

        end
    end
    rm(workdir, recursive=true)
end

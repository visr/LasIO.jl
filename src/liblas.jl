# use LibLAS.jl to support reading in LAZ files with the same LasIO API
# currently only reading, not writing is supported
# loading from a filename, not a stream is supported

"""Remove LAZ characteristics from `LasHeader`

This includes removing the \"laszip encoded\" VLR and adjusting the point format."""
function lasformat(h::LasHeader)
    h = deepcopy(h)
    h.data_format_id &= 0x7f # for LAZ first bit is 1, set this bit back to 0

    newvlrs = LasIO.LasVariableLengthRecord[]
    nbytes_removed = 0
    for vlr in h.variable_length_records
        if vlr.user_id == "laszip encoded"
            nbytes_removed += 2 + 16 + 2 + 2 + 32 + length(vlr.data)
        else
            push!(newvlrs, vlr)
        end
    end
    h.variable_length_records = newvlrs
    h.n_vlr = length(newvlrs)
    # this code assumes these are not extended VLRs
    h.data_offset -= nbytes_removed
    h
end

# no guarantee that compression parameters match
# but these are the ones produced by
# OSGeo4W liblas 1.8.0-1 linked to OSGeo4W laszip 2.2.0-3
# LASzip compression (version 2.2r0 c2 50000): POINT10 2
const laszipvlr = LasIO.LasVariableLengthRecord(0xaabb,"laszip encoded",0x56bc,"http://laszip.org",UInt8[0x02,0x00,0x00,0x00,0x02,0x02,0x00,0x00,0x00,0x00,0x00,0x00,0x50,0xc3,0x00,0x00,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0x01,0x00,0x06,0x00,0x14,0x00,0x02,0x00])

"""Add LAZ characteristics to `LasHeader`

This includes adding the \"laszip encoded\" VLR and adjusting the point format."""
function lazformat(h::LasHeader)
    h = deepcopy(h)
    h.data_format_id |= 0x80 # for LAZ first bit is 1, set this bit to 1
    # check if there is a "laszip encoded" VLR present, if not add one
    laszipvlr_present = any(vlr -> vlr.user_id == "laszip encoded", h.variable_length_records)
    if !laszipvlr_present
        nbytes_added = 2 + 16 + 2 + 2 + 32 + length(laszipvlr.data)
        push!(h.variable_length_records, laszipvlr)
        h.n_vlr = length(h.variable_length_records)
        # this code assumes these are not extended VLRs
        h.data_offset += nbytes_added
    end
    h
end

"Create a LasIO.LasPoint0 from a LibLAS.LASPoint"
function makepoint(p::LibLAS.LASPoint, ::Type{LasPoint0})
    x = LibLAS.raw_xcoord(p)
    y = LibLAS.raw_ycoord(p)
    z = LibLAS.raw_zcoord(p)
    intensity = LibLAS.intensity(p)
    flag_byte = LibLAS.scanflags(p)
    raw_classification = LibLAS.classification(p)
    scan_angle = LibLAS.scan_angle_rank(p)
    user_data = LibLAS.userdata(p)
    pt_src_id = LibLAS.pointsource_id(p)
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

# code that can be shared between the LibLAS.LASPoint(pio::LasPoint)
# for the different point formats
function basic_liblas_point(pio::LasPoint)
    # create an empty point
    pll = LibLAS.create(LibLAS.LASPoint)
    # add all properties one by one
    # using the raw coordinates to save computation
    LibLAS.raw_xcoord!(pll, pio.x)
    LibLAS.raw_ycoord!(pll, pio.y)
    LibLAS.raw_zcoord!(pll, pio.z)
    LibLAS.intensity!(pll, intensity(pio))
    LibLAS.scanflags!(pll, pio.flag_byte)
    LibLAS.classification!(pll, pio.raw_classification)
    LibLAS.scan_angle_rank!(pll, scan_angle(pio))
    LibLAS.userdata!(pll, user_data(pio))
    LibLAS.pointsource_id!(pll, pt_src_id(pio))
    pll
end

"Create a LibLAS.LASPoint from a LasIO.LasPoint0"
function LibLAS.LASPoint(pio::LasPoint0)
    basic_liblas_point(pio)
end

"Create a LibLAS.LASPoint from a LasIO.LasPoint1"
function LibLAS.LASPoint(pio::LasPoint1)
    pll = basic_liblas_point(pio)
    LibLAS.gps_time!(pll, gps_time(pio))
    pll
end

"Create a LibLAS.LASPoint from a LasIO.LasPoint2"
function LibLAS.LASPoint(pio::LasPoint2)
    pll = basic_liblas_point(pio)
    LibLAS.color!(pll, pio)
    pll
end

"Create a LibLAS.LASPoint from a LasIO.LasPoint3"
function LibLAS.LASPoint(pio::LasPoint3)
    pll = basic_liblas_point(pio)
    LibLAS.gps_time!(pll, gps_time(pio))
    LibLAS.color!(pll, pio)
    pll
end

"Returns the number of bytes between the end of the VLRs on the header to the data offset"
function LibLAS.headerpadding(h::LasHeader)
    if h.n_vlr == 0
        vlrsize = 0
    else
        vlrsize = sum((54 + length(vlr.data)) for vlr in h.variable_length_records)
    end
    UInt32(h.data_offset - h.header_size - vlrsize)
end

"Returns whether the LasHeader is compressed Int32(1) or not Int32(0)"
LibLAS.compressed(h::LasHeader) = Int32((h.data_format_id & 0x80) >> 7)

"Add the color from a LasIO.LasPointColor to a LibLAS.LASPoint"
function LibLAS.color!(pll::LibLAS.LASPoint, pio::LasPointColor)
    color = LibLAS.create(LibLAS.LASColor)
    LibLAS.red(color, reinterpret(UInt16, red(pio)))
    LibLAS.green(color, reinterpret(UInt16, green(pio)))
    LibLAS.blue(color, reinterpret(UInt16, blue(pio)))
    LibLAS.color!(pll, color)
end

"Free the memory used to store the color"
function freecolor!{T<:LasPointColor}(pll::LibLAS.LASPoint, pointtype::Type{T})
    color = LibLAS.color(pll)
    LibLAS.destroy(color)
    nothing
end

"Fallback for non color bearing point types, does nothing"
freecolor!{T<:LasPoint}(pll::LibLAS.LASPoint, pointtype::Type{T}) = nothing

"Create a LibLAS.LASHeader from a LasIO.LasHeader"
function LibLAS.LASHeader(hio::LasHeader)
    # create an empty header
    hll = LibLAS.create(LibLAS.LASHeader)

    LibLAS.filesourceid!(hll, hio.file_source_id)
    const guid_string = "00000000-0000-0000-0000-000000000000"
    LibLAS.projectid!(hll, guid_string)
    LibLAS.versionmajor!(hll, hio.version_major)
    LibLAS.versionminor!(hll, hio.version_minor)
    LibLAS.systemid!(hll, hio.system_id)
    LibLAS.softwareid!(hll, hio.software_id)
    LibLAS.reserved!(hll, hio.global_encoding)
    LibLAS.creationdoy!(hll, hio.creation_doy)
    LibLAS.creationyear!(hll, hio.creation_year)
    LibLAS.dataoffset!(hll, hio.data_offset)
    LibLAS.headerpadding!(hll, LibLAS.headerpadding(hio))
    # function no longer exists
    # LibLAS.datarecordlength!(hll, hio.data_record_length)
    # should be 1 for points containing time values, else 0
    LibLAS.dataformatid!(hll, hio.data_format_id & 0x01)
    LibLAS.pointrecordscount!(hll, hio.records_count)
    LibLAS.pointrecordsbyreturncount!(hll, Int32(0), hio.point_return_count[1])
    LibLAS.pointrecordsbyreturncount!(hll, Int32(1), hio.point_return_count[2])
    LibLAS.pointrecordsbyreturncount!(hll, Int32(2), hio.point_return_count[3])
    LibLAS.pointrecordsbyreturncount!(hll, Int32(3), hio.point_return_count[4])
    LibLAS.scale!(hll, hio.x_scale, hio.y_scale, hio.z_scale)
    LibLAS.offset!(hll, hio.x_offset, hio.y_offset, hio.z_offset)
    LibLAS.min!(hll, hio.x_min, hio.y_min, hio.z_min)
    LibLAS.max!(hll, hio.x_max, hio.y_max, hio.z_max)

    # 1 is compressed, 0 otherwise
    LibLAS.compressed!(hll, LibLAS.compressed(hio))
    # LibLAS.schema!(hll, hFormat::LASSchema)
    # LibLAS.srs!(hll, hSRS::LASSRS)

    hll
end

"Create a LasIO.LasPoint1 from a LibLAS.LASPoint"
function makepoint(p::LibLAS.LASPoint, ::Type{LasPoint1})
    x = LibLAS.raw_xcoord(p)
    y = LibLAS.raw_ycoord(p)
    z = LibLAS.raw_zcoord(p)
    intensity = LibLAS.intensity(p)
    flag_byte = LibLAS.scanflags(p)
    raw_classification = LibLAS.classification(p)
    scan_angle = LibLAS.scan_angle_rank(p)
    user_data = LibLAS.userdata(p)
    pt_src_id = LibLAS.pointsource_id(p)
    gps_time = LibLAS.gps_time(p)
    LasPoint1(
        x,
        y,
        z,
        intensity,
        flag_byte,
        raw_classification,
        scan_angle,
        user_data,
        pt_src_id,
        gps_time
    )
end

"Create a LasIO.LasPoint2 from a LibLAS.LASPoint"
function makepoint(p::LibLAS.LASPoint, ::Type{LasPoint2})
    x = LibLAS.raw_xcoord(p)
    y = LibLAS.raw_ycoord(p)
    z = LibLAS.raw_zcoord(p)
    intensity = LibLAS.intensity(p)
    flag_byte = LibLAS.scanflags(p)
    raw_classification = LibLAS.classification(p)
    scan_angle = LibLAS.scan_angle_rank(p)
    user_data = LibLAS.userdata(p)
    pt_src_id = LibLAS.pointsource_id(p)
    color = LibLAS.color(p)
    red = reinterpret(N0f16, LibLAS.red(color))
    green = reinterpret(N0f16, LibLAS.green(color))
    blue = reinterpret(N0f16, LibLAS.blue(color))
    LasPoint2(
        x,
        y,
        z,
        intensity,
        flag_byte,
        raw_classification,
        scan_angle,
        user_data,
        pt_src_id,
        red,
        green,
        blue
    )
end

"Create a LasIO.LasPoint3 from a LibLAS.LASPoint"
function makepoint(p::LibLAS.LASPoint, ::Type{LasPoint3})
    x = LibLAS.raw_xcoord(p)
    y = LibLAS.raw_ycoord(p)
    z = LibLAS.raw_zcoord(p)
    intensity = LibLAS.intensity(p)
    flag_byte = LibLAS.scanflags(p)
    raw_classification = LibLAS.classification(p)
    scan_angle = LibLAS.scan_angle_rank(p)
    user_data = LibLAS.userdata(p)
    pt_src_id = LibLAS.pointsource_id(p)
    gps_time = LibLAS.gps_time(p)
    color = LibLAS.color(p)
    red = reinterpret(N0f16, LibLAS.red(color))
    green = reinterpret(N0f16, LibLAS.green(color))
    blue = reinterpret(N0f16, LibLAS.blue(color))
    LasPoint3(
        x,
        y,
        z,
        intensity,
        flag_byte,
        raw_classification,
        scan_angle,
        user_data,
        pt_src_id,
        gps_time,
        red,
        green,
        blue
    )
end

function load(f::File{format"LAZ"})
    # header is not compressed, use existing LasIO functions
    # not sure how this works with VLRs and if they are compressed
    s = open(f)
    header = read(s, LasHeader)
    n = header.records_count
    pointtype = pointformat(header)
    pointdata = Vector{pointtype}(n)
    close(s)

    # use LibLAS (linked to LASzip) to read the points
    reader = LibLAS.create(LibLAS.LASReader, filename(f))
    for i=1:n
        p = LibLAS.nextpoint(reader)
        pointdata[i] = makepoint(p, pointtype)
    end
    LibLAS.destroy(reader)
    header, pointdata
end

function save{T<:LasPoint}(f::File{format"LAZ"}, header::LasHeader, pointdata::Vector{T})
    validate(header, pointdata)

    # use LibLAS (linked to LASzip) to write LAZ
    llheader = LibLAS.LASHeader(header)
    # create in write mode, directly writes header
    writer = LibLAS.create(LibLAS.LASWriter, filename(f), llheader, Int32(1))
    for pio in pointdata
        pll = LibLAS.LASPoint(pio)
        LibLAS.writepoint(writer, pll)
        freecolor!(pll, T)
        LibLAS.destroy(pll)
    end

    LibLAS.destroy(writer)
    LibLAS.destroy(llheader)
end

# use LibLAS.jl to support reading in LAZ files with the same LasIO API
# currently only reading, not writing is supported
# loading from a filename, not a stream is supported

"""Remove LAZ characteristics from `LasHeader`

This includes removing the \"laszip encoded\" VLR and adjusting the point format."""
function lasformat(h::LasHeader)
    h = deepcopy(h)
    h.data_format_id &= 0x7f

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
    gps_time = LibLAS.time(p)
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
    red = LibLAS.red(color)
    green = LibLAS.green(color)
    blue = LibLAS.blue(color)
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
    gps_time = LibLAS.time(p)
    color = LibLAS.color(p)
    red = LibLAS.red(color)
    green = LibLAS.green(color)
    blue = LibLAS.blue(color)
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

    # use LibLAS to read the points
    reader = LibLAS.create(LibLAS.LASReader, filename(f))
    for i=1:n
        p = LibLAS.nextpoint(reader)
        pointdata[i] = makepoint(p, pointtype)
    end
    LibLAS.destroy(reader)
    header, pointdata
end

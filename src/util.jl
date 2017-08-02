"Update the header bounding box and count based on point data"
function update!(h::LasHeader, pvec::Vector{T}) where T <: LasPoint
    x_min, y_min, z_min = Inf, Inf, Inf
    x_max, y_max, z_max = -Inf, -Inf, -Inf
    for p in pvec
        x, y, z = xcoord(p, h), ycoord(p, h), zcoord(p, h)
        if x < x_min
            x_min = x
        end
        if y < y_min
            y_min = y
        end
        if z < z_min
            z_min = z
        end
        if x > x_max
            x_max = x
        end
        if y > y_max
            y_max = y
        end
        if z > z_max
            z_max = z
        end
    end
    h.x_min = x_min
    h.y_min = y_min
    h.z_min = z_min
    h.x_max = x_max
    h.y_max = y_max
    h.z_max = z_max
    h.records_count = length(pvec)
    nothing
end

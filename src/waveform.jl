"""Waveform Packet Descriptor User Defined Record.
User ID: LASF_Spec Record ID: n: where n > 99 and n <355."""
@gen_io struct waveform_descriptor
    bits_sample::UInt8  # size of sample in bits
    compression_type::UInt8
    n_samples::UInt32
    temp_spacing::UInt32  # The temporal sample spacing in picoseconds
    digitizer_gain::Float64
    digitizer_offset::Float64
end

function waveform(p::LasPoint, header::LasHeader, evlr::ExtendedLasVariableLengthRecord)

    # get waveform descriptor
    wfd = header.variable_length_records[end]
    @assert wfd.record_id == p.wave_packet_descriptor_index + 99
    wfdd = wfd.data

    # get raw waveform
    wf_start = p.waveform_data_offset - 60
    size = p.waveform_packet_size
    raw_waveform = evlr.data[(wf_start+1):(wf_start + size)]
    @assert wfdd.bits_sample * wfdd.n_samples / 8 <= length(raw_waveform)

    # read samples
    # raw_waveform = reinterpret(raw_waveform, wfdd.bits_sample)

    # calculate coordinates and real values for each sample
    waves = Array{Float32}(length(raw_waveform), 5)
    distances = Vector{Float32}(length(raw_waveform))
    for (is, sample) in enumerate(raw_waveform)
        dist = p.waveform_return_point_location - is * wfdd.temp_spacing
        x = p.x + dist * p.xt
        y = p.y + dist * p.yt
        z = p.z + dist * p.zt
        # v = Float32(wfdd.digitizer_offset + wfdd.digitizer_gain * sample)  # Float64
        v = muladd(wfdd.digitizer_gain, sample, wfdd.digitizer_offset)  # Float64
        waves[is, :] .= dist, x, y, z, v
        # distances[is] = dist
        # @show typeof(x), typeof(y), typeof(v)
        # break
    end
    waves
    # AxisArray(waves, Axis{:time}(distances), Axis{:chan}([:x, :y, :z, :voltage]))
end

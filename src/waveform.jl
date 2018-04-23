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

waveform_sample_types = Dict(
    UInt8(8) => UInt8,
    UInt8(16) => UInt16,
    UInt8(32) => UInt32
)

function waveform(p::LasPoint, header::LasHeader)
    @assert LasIO.waveform_internal(header) "Only internal waveforms are supported."
    @assert 0xffff in keys(header.variable_length_records) "No internal waveforms found."
    evlr = header.variable_length_records[0xffff]

    # get waveform descriptor
    record = UInt16(p.wave_packet_descriptor_index + 99)
    @assert record in keys(header.variable_length_records) "Waveform descriptor #$record not found."
    wfd = header.variable_length_records[record]
    wfdd = wfd.data
    @assert wfdd.bits_sample in (8, 16, 32) "Samples with #$(wfdd.bits_sample) bits not supported."

    # get raw waveform
    wf_start = p.waveform_data_offset - 60
    size = p.waveform_packet_size
    raw_waveform = evlr.data[(wf_start+1):(wf_start + size)]
    @assert wfdd.bits_sample * wfdd.n_samples / 8 <= length(raw_waveform)
    raw_waveform = reinterpret(waveform_sample_types[wfdd.bits_sample], raw_waveform)

    # calculate coordinates and real values for each sample
    waves = Array{Float32}(length(raw_waveform), 5)
    distances = Vector{Float32}(length(raw_waveform))
    for (is, sample) in enumerate(raw_waveform)
        dist = p.waveform_return_point_location - is * wfdd.temp_spacing
        x = p.x + dist * p.xt
        y = p.y + dist * p.yt
        z = p.z + dist * p.zt
        v = muladd(wfdd.digitizer_gain, sample, wfdd.digitizer_offset)  # Float64
        waves[is, :] .= dist, x, y, z, v
    end
    waves
end

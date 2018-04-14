using FileIO
using LasIO
using Base.Test

newfields = [(:testfield, Float64)]

nt = LasIO.gen_append_struct(LasPoint0, newfields)
@test :testfield in fieldnames(nt)

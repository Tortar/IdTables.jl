module IndexedStructVectors

isdefined(@__MODULE__, :Memory) || const Memory = Vector # Compat for Julia < 1.11

import Tables

using StructArrays
using Unrolled

export IdTable, SlotMapStructVector, SparseSetStructVector, ids, getid, lastid, isvalid

include("idvectors.jl")
include("idtable.jl")
include("slotmap.jl")
include("sparseset.jl")

end

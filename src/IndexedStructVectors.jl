module IndexedStructVectors

using Unrolled

export IndexedStructVector, SlotMapStructVector, getfields, id, isvalid

include("common.jl")

include("dict.jl")

include("slotmap.jl")

end

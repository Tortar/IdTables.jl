module IndexedStructVectors

isdefined(@__MODULE__, :Memory) || const Memory = Vector # Compat for Julia < 1.11

using StructArrays
using Unrolled

export SlotMapStructVector, SparseSetStructVector, id, isvalid

abstract type AbstractIndexedStructVector end

function remove!(a, i)
    @inbounds a[i], a[end] = a[end], a[i]
    pop!(a)
    return
end

struct Keys
    ID::Vector{Int64}
end
Base.iterate(k::Keys) = Base.iterate(k.ID)
Base.iterate(k::Keys, state) = Base.iterate(k.ID, state)
Base.IteratorSize(::Keys) = Base.HasLength()
Base.length(k::Keys) = length(k.ID)
Base.eltype(::Keys)= Int64

function Base.keys(isv::AbstractIndexedStructVector)
    return Keys(getfield(getcomponents(isv), :id))
end

struct IndexedView{S}
    id::Int64
    isv::S
end

getid(a::IndexedView) = getfield(a, :id)

isvalid(a::IndexedView) = a in getfield(a, :isv)

@inline function Base.getproperty(a::IndexedView, name::Symbol)
    id, isv = getfield(a, :id), getfield(a, :isv)
    comps = getcomponents(isv)
    f = getfield(comps, name)
    i = id_to_index(isv, id)
    @inbounds f[i]
end

@inline function Base.setproperty!(a::IndexedView, name::Symbol, x)
    id, isv = getfield(a, :id), getfield(a, :isv)
    comps = getcomponents(isv)
    f = getfield(comps, name)
    i = id_to_index(isv, id)
    return (@inbounds f[i] = x)
end

function Base.show(io::IO, ::MIME"text/plain", x::IndexedView)
    !isvalid(x) && return print(io, "InvalidIndexView(id = $(getfield(x, :id)))")
    id, isv = getfield(x, :id), getfield(x, :isv)
    comps = getcomponents(isv)
    i = id_to_index(isv, id)
    fields = NamedTuple(y => getfield(comps, y)[i] for y in fieldnames(typeof(comps)))
    return print(io, "IndexedView$fields")
end

Base.getproperty(isv::AbstractIndexedStructVector, name::Symbol) = getcomponents(isv)[name]

@inline function Base.getindex(isv::AbstractIndexedStructVector, id::Int)
    i = id_to_index(isv, id)
    return getindex(getfield(isv, :components), i)
end

@inline function Base.view(isv::AbstractIndexedStructVector, id::Int)
    id ∉ isv && throw(KeyError(id))
    return IndexedView(id, isv)
end

function Base.deleteat!(isv::AbstractIndexedStructVector, i::Int)
    comps = getcomponents(isv)
    ID = getfield(comps, :id)
    delete_id_index!(isv, ID[i], i)
end

function Base.delete!(isv::AbstractIndexedStructVector, id::Int)
    i = id_to_index(isv, id)
    delete_id_index!(isv, id, i)
end

function Base.delete!(isv::AbstractIndexedStructVector, a::IndexedView)
    id = getfield(a, :id)
    i = id_to_index(isv, id)
    delete_id_index!(isv, id, i)
end

function Base.in(a::IndexedView, isv::AbstractIndexedStructVector)
    getfield(a, :id) ∈ isv
end

lastkey(isv::AbstractIndexedStructVector) = getfield(isv, :last_id)

# Copied from base/array.jl because this is not a public function
# https://github.com/JuliaLang/julia/blob/v1.11.6/base/array.jl#L1042-L1056
# Pick new memory size for efficiently growing an array
# TODO: This should know about the size of our GC pools
# Specifically we are wasting ~10% of memory for small arrays
# by not picking memory sizes that max out a GC pool
function overallocation(maxsize)
    maxsize < 8 && return 8;
    # compute maxsize = maxsize + 4*maxsize^(7/8) + maxsize/8
    # for small n, we grow faster than O(n)
    # for large n, we grow at O(n/8)
    # and as we reach O(memory) for memory>>1MB,
    # this means we end by adding about 10% of memory each time
    exp2 = sizeof(maxsize) * 8 - Core.Intrinsics.ctlz_int(maxsize)
    maxsize += (1 << div(exp2 * 7, 8)) * 4 + div(maxsize, 8)
    return maxsize
end

getcomponents(isv::AbstractIndexedStructVector) = getfield(getfield(isv, :components), :components)

include("slotmap.jl")
include("sparseset.jl")

end

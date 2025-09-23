
# for testing purposes
module IndexedStructVectors_Dict

using IndexedStructVectors.Unrolled

mutable struct IndexedStructVector{C}
    del::Bool
    nextlastid::Int64
    const id_to_index::Dict{Int64, Int}
    const components::C
    function IndexedStructVector(components::NamedTuple)
        allequal(length.(values(components))) || error("All components must have equal length")
        len = length(first(components))
        comps = merge((ID=collect(1:len),), components)
        return new{typeof(comps)}(false, len, Dict{Int64,Int}(), comps)
    end
end

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

struct IndexedView{S}
    id::Int64
    lasti::Int
    isv::S
end

id(a::IndexedView) = getfield(a, :id)

isvalid(a::IndexedView) = a in getfield(a, :isv)

@inline function Base.getproperty(a::IndexedView, name::Symbol)
    id, isv = getfield(a, :id), getfield(a, :isv)
    comps = getfield(isv, :components)
    f = getfield(comps, name)
    lasti = getfield(a, :lasti)
    i = id_guess_to_index(isv, id, lasti)
    @inbounds f[i]
end

@inline function Base.setproperty!(a::IndexedView, name::Symbol, x)
    id, isv = getfield(a, :id), getfield(a, :isv)
    comps = getfield(isv, :components)
    f = getfield(comps, name)
    lasti = getfield(a, :lasti)
    i = id_guess_to_index(isv, id, lasti)
    return (@inbounds f[i] = x)
end

function Base.show(io::IO, ::MIME"text/plain", x::IndexedView)
    !isvalid(x) && return print(io, "InvalidIndexView(ID = $(getfield(x, :id)))")
    id, isv = getfield(x, :id), getfield(x, :isv)
    comps = getfield(isv, :components)
    lasti = getfield(x, :lasti)
    i = id_guess_to_index(isv, id, lasti)
    fields = NamedTuple(y => getfield(comps, y)[i] for y in fieldnames(typeof(comps)))
    return print(io, "IndexedView$fields")
end

Base.getproperty(isv::IndexedStructVector, name::Symbol) = getfield(isv, :components)[name]

lastkey(isv::IndexedStructVector) = getfield(isv, :nextlastid)

@inline function id_guess_to_index(isv::IndexedStructVector, id::Int64, lasti::Int)::Int
    del = getfield(isv, :del)
    comps = getfield(isv, :components)
    ID = getfield(comps, :ID)
    if !del
        checkbounds(Bool, ID, id) || throw(KeyError(id))
        id
    else
        if lasti ∈ eachindex(ID) && (@inbounds ID[lasti] == id)
            lasti
        else
            getfield(isv, :id_to_index)[id]
        end
    end
end

@inline function delete_id_index!(isv::IndexedStructVector, id::Int64, i::Int)
    comps, id_to_index = getfield(isv, :components), getfield(isv, :id_to_index)
    del, ID = getfield(isv, :del), getfield(comps, :ID)
    !del && setfield!(isv, :del, true)
    removei! = a -> remove!(a, i)
    unrolled_map(removei!, values(comps))
    delete!(id_to_index, id)
    i <= length(ID) && (id_to_index[(@inbounds ID[i])] = i)
    return isv
end

function Base.deleteat!(isv::IndexedStructVector, i::Int)
    comps = getfield(isv, :components)
    ID = getfield(comps, :ID)
    delete_id_index!(isv, ID[i], i)
end

function Base.delete!(isv::IndexedStructVector, id::Int)
    i = id_guess_to_index(isv, id, id)
    delete_id_index!(isv, id, i)
end

function Base.delete!(isv::IndexedStructVector, a::IndexedView)
    id, lasti = getfield(a, :id), getfield(a, :lasti)
    i = id_guess_to_index(isv, id, lasti)
    delete_id_index!(isv, id, i)
end

function Base.push!(isv::IndexedStructVector, t::NamedTuple)
    comps, id_to_index = getfield(isv, :components), getfield(isv, :id_to_index)
    fieldnames(typeof(comps))[2:end] != keys(t) && error("Tuple fields do not match container fields")
    ID, lastid = getfield(comps, :ID), getfield(isv, :nextlastid)
    nextlastid = setfield!(isv, :nextlastid, lastid + 1)
    push!(ID, nextlastid)
    unrolled_map(push!, values(comps)[2:end], t)
    getfield(isv, :del) && (id_to_index[nextlastid] = length(ID))
    return isv
end

function Base.show(io::IO, ::MIME"text/plain", x::IndexedStructVector{C}) where C
    comps = getfield(x, :components)
    sC = string(C)[13:end]
    print("IndexedStructVector{$sC")
    return display(comps)
end

function Base.keys(isv::IndexedStructVector)
    return Keys(getfield(getfield(isv, :components), :ID))
end

@inline function Base.getindex(isv::IndexedStructVector, id::Int)
    return IndexedView(id, id_guess_to_index(isv, id, id), isv)
end

@inline function Base.view(isv::IndexedStructVector, id::Int)
    return IndexedView(id, id_guess_to_index(isv, id, id), isv)
end

function Base.in(a::IndexedView, isv::IndexedStructVector)
    id, comps = getfield(a, :id), getfield(isv, :components)
    del, ID = getfield(isv, :del), getfield(comps, :ID)
    !del && return 1 <= id <= length(ID)
    lasti = getfield(a, :lasti)
    lasti <= length(ID) && (@inbounds ID[lasti] == id) && return true
    id_to_index = getfield(isv, :id_to_index)
    return id in keys(id_to_index)
end
function Base.in(id::Int64, isv::IndexedStructVector)
    comps = getfield(isv, :components)
    del, ID = getfield(isv, :del), getfield(comps, :ID)
    !del && return 1 <= id <= length(ID)
    id ∈ eachindex(ID) && (@inbounds ID[id] == id) && return true
    id_to_index = getfield(isv, :id_to_index)
    return id in keys(id_to_index)
end

end
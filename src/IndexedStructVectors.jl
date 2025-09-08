module IndexedStructVectors

using Unrolled

export IndexedStructVector, getfields, id, isvalid

function remove!(a, i)
    @inbounds a[i], a[end] = a[end], a[i]
    pop!(a)
    return
end

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

Base.getproperty(isv::IndexedStructVector, name::Symbol) = getfield(isv, :components)[name]

lastkey(isv::IndexedStructVector) = getfield(isv, :nextlastid)

function Base.deleteat!(isv::IndexedStructVector, i::Int)
    comps, id_to_index = getfield(isv, :components), getfield(isv, :id_to_index)
    del, ID = getfield(isv, :del), getfield(comps, :ID)
    pid = ID[i]
    !del && setfield!(isv, :del, true)
    removei! = a -> remove!(a, i)
    unrolled_map(removei!, values(comps))
    delete!(id_to_index, pid)
    i <= length(ID) && (id_to_index[(@inbounds ID[i])] = i)
    return isv
end

function Base.delete!(isv::IndexedStructVector, id::Int)
    comps, id_to_index = getfield(isv, :components), getfield(isv, :id_to_index)
	del, ID = getfield(isv, :del), getfield(comps, :ID)
    !del && setfield!(isv, :del, true)
    i = (1 <= id <= length(ID) && (@inbounds ID[id] == id)) ? id : id_to_index[id]
    removei! = a -> remove!(a, i)
    unrolled_map(removei!, values(comps))
    delete!(id_to_index, id)
    i <= length(ID) && (id_to_index[(@inbounds ID[i])] = i)
    return isv
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

struct Keys
	ID::Vector{Int64}
end
function Base.keys(isv::IndexedStructVector)
    return Keys(getfield(getfield(isv, :components), :ID))
end
Base.iterate(k::Keys) = Base.iterate(k.ID)
Base.iterate(k::Keys, state) = Base.iterate(k.ID, state)
Base.IteratorSize(::Keys) = Base.HasLength()
Base.length(k::Keys) = length(k.ID)
Base.eltype(::Keys)= Int64

@inline function Base.getindex(isv::IndexedStructVector, id::Int)
    comps, id_to_index = getfield(isv, :components), getfield(isv, :id_to_index)
    del, ID = getfield(isv, :del), getfield(comps, :ID)
    if !del
        checkbounds(ID, id)
        i = id
    else
        i = 1 <= id <= length(ID) && (@inbounds ID[id] == id) ? id : id_to_index[id]
    end
    return IndexedView(id, i, isv)
end

struct IndexedView{S<:IndexedStructVector}
    id::Int64
    lasti::Int
    isv::S
end

id(a::IndexedView) = getfield(a, :id)

isvalid(a::IndexedView) = a in getfield(a, :isv)

@inline function Base.getproperty(a::IndexedView, name::Symbol)
    id, isv = getfield(a, :id), getfield(a, :isv)
    comps = getfield(isv, :components)
    del, f = getfield(isv, :del), getfield(comps, name)
    !del && return f[id]
    lasti, ID = getfield(a, :lasti), getfield(comps, :ID)
    lasti <= length(ID) && (@inbounds ID[lasti] == id) && return @inbounds f[lasti]
    id_to_index = getfield(isv, :id_to_index)
    return @inbounds f[id_to_index[id]]
end

@inline function Base.setproperty!(a::IndexedView, name::Symbol, x)
    id, isv = getfield(a, :id), getfield(a, :isv)
    comps = getfield(isv, :components)
    del, f = getfield(isv, :del), getfield(comps, name)
    !del && return (f[id] = x)
    lasti, ID = getfield(a, :lasti), getfield(comps, :ID)
    lasti <= length(ID) && (@inbounds ID[lasti] == id) && return (@inbounds f[lasti] = x)
    id_to_index = getfield(isv, :id_to_index)
    return (@inbounds f[id_to_index[id]] = x)
end

@inline function getfields(a::IndexedView)
    id, isv = getfield(a, :id), getfield(a, :isv)
    comps, id_to_index = getfield(isv, :components), getfield(isv, :id_to_index)
    del = getfield(isv, :del)
    lasti, ID = getfield(a, :lasti), getfield(comps, :ID)
    i = !del ? id : 
        ((lasti <= length(ID) && (@inbounds ID[lasti] == id)) ? lasti : id_to_index[id])
    checkbounds(getfield(comps, :ID), i)
    getindexi = ar -> @inbounds ar[i]
    vals = unrolled_map(getindexi, values(comps)[2:end])
    names = fieldnames(typeof(comps))[2:end]
    return NamedTuple{names}(vals)
end

function Base.show(io::IO, ::MIME"text/plain", x::IndexedView)
	!isvalid(x) && return print(io, "InvalidIndexView(ID = $(getfield(x, :id)))")
    id, isv = getfield(x, :id), getfield(x, :isv)
    comps, id_to_index = getfield(isv, :components), getfield(isv, :id_to_index)
    del = getfield(isv, :del)
    lasti, ID = getfield(x, :lasti), getfield(comps, :ID)
    i = !del ? id : 
        ((lasti <= length(ID) && (@inbounds ID[lasti] == id)) ? lasti : id_to_index[id])
    fields = NamedTuple(y => getfield(comps, y)[i] for y in fieldnames(typeof(comps)))
    return print(io, "IndexedView$fields")
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
function Base.in(id::Int, isv::IndexedStructVector)
    comps = getfield(isv, :components)
    del, ID = getfield(isv, :del), getfield(comps, :ID)
    !del && return 1 <= id <= length(ID)
    id_to_index = getfield(isv, :id_to_index)
    return id in keys(id_to_index)
end

function Base.delete!(isv::IndexedStructVector, a::IndexedView)
    comps, id_to_index = getfield(isv, :components), getfield(isv, :id_to_index)
    del, ID = getfield(isv, :del), getfield(comps, :ID)
    id, lasti = getfield(a, :id), getfield(a, :lasti)
    !del && setfield!(isv, :del, true)
    i = lasti <= length(ID) && (@inbounds ID[lasti] == id) ? lasti : id_to_index[id]
    removei! = a -> remove!(a, i)
    unrolled_map(removei!, values(comps))
    delete!(id_to_index, id)
    i <= length(ID) && (id_to_index[(@inbounds ID[i])] = i)
    return isv
end

end

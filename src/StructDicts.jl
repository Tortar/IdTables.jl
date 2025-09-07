module StructDicts

using Unrolled

export StructDict, getfields

function remove!(a, i)
    @inbounds a[i], a[end] = a[end], a[i]
    pop!(a)
    return
end

mutable struct StructDict{C}
	del::Bool
    nextlastid::Int64
	const id_to_index::Dict{Int64, Int}
	const components::C
	function StructDict(components::NamedTuple)
		allequal(length.(values(components))) || error("All components must have equal length")
		len = length(first(components))
		comps = merge((ID=collect(1:len),), components)
		return new{typeof(comps)}(false, len, Dict{Int64,Int}(), comps)
	end
end

Base.getproperty(sdict::StructDict, name::Symbol) = getfield(sdict, :components)[name]

function Base.deleteat!(sdict::StructDict, i::Int)
    comps, id_to_index = getfield(sdict, :components), getfield(sdict, :id_to_index)
    del, ID = getfield(sdict, :del), getfield(comps, :ID)
    checkbounds(ID, i)
    if !del
        setfield!(sdict, :del, true)
        for pid in ID
            id_to_index[pid] = pid
        end
    end
    removei! = a -> remove!(a, i)
    unrolled_map(removei!, values(comps))
    delete!(id_to_index, id)
    i <= length(ID) && (id_to_index[(@inbounds ID[i])] = i)
    return sdict
end

function Base.delete!(sdict::StructDict, id::Int)
    comps, id_to_index = getfield(sdict, :components), getfield(sdict, :id_to_index)
	del, ID = getfield(sdict, :del), getfield(comps, :ID)
    if !del
        setfield!(sdict, :del, true)
        for pid in ID
            id_to_index[pid] = pid
        end
    end
    i = id_to_index[id]
    removei! = a -> remove!(a, i)
    unrolled_map(removei!, values(comps))
    delete!(id_to_index, id)
    i <= length(ID) && (id_to_index[(@inbounds ID[i])] = i)
    return sdict
end

function Base.push!(sdict::StructDict, t::NamedTuple)
    comps, id_to_index = getfield(sdict, :components), getfield(sdict, :id_to_index)
    fieldnames(typeof(comps))[2:end] != keys(t) && error("Tuple fields do not match container fields")
    ID, lastid = getfield(comps, :ID), getfield(sdict, :nextlastid)
    nextlastid = setfield!(sdict, :nextlastid, lastid + 1)
    push!(ID, nextlastid)
    unrolled_map(push!, values(comps)[2:end], t)
    getfield(sdict, :del) && (id_to_index[nextlastid] = length(ID))
    return sdict
end

function Base.show(io::IO, ::MIME"text/plain", x::StructDict{C}) where C
    comps = getfield(x, :components)
    sC = string(C)[13:end]
    print("IndexedStructVector{$sC")
    return display(comps)
end

struct Keys{T,I}
    t::T
	ID::I
end
function Base.keys(sdict::StructDict)
    ID = getfield(getfield(sdict, :components), :ID)
    return Keys(eltype(ID), ID)
end
Base.iterate(k::Keys) = Base.iterate(k.ID)
Base.iterate(k::Keys, state) = Base.iterate(k.ID, state)
Base.IteratorSize(::Keys) = Base.HasLength()
Base.length(k::Keys) = length(k.ID)
Base.eltype(::Keys{T}) where T = T

lastkey(sdict::StructDict) = getfield(sdict, :nextlastid)

@inline function Base.getindex(sdict::StructDict, id::Int)
    comps, id_to_index = getfield(sdict, :components), getfield(sdict, :id_to_index)
    del = getfield(sdict, :del)
    i = del ? id_to_index[id] : id
    checkbounds(getfield(comps, :ID), i)
    return Struct(id, i, sdict)
end

struct Struct{S<:StructDict}
    id::Int64
    lasti::Int
    sdict::S
end

@inline function Base.getproperty(a::Struct, name::Symbol)
    id, sdict = getfield(a, :id), getfield(a, :sdict)
    comps = getfield(sdict, :components)
    del, f = getfield(sdict, :del), getfield(comps, name)
    !del && return f[id]
    lasti, ID = getfield(a, :lasti), getfield(comps, :ID)
    lasti <= length(ID) && (@inbounds ID[lasti] == id) && return @inbounds f[lasti]
    id_to_index = getfield(sdict, :id_to_index)
    return @inbounds f[id_to_index[id]]
end

@inline function Base.setproperty!(a::Struct, name::Symbol, x)
    id, sdict = getfield(a, :id), getfield(a, :sdict)
    comps = getfield(sdict, :components)
    del, f = getfield(sdict, :del), getfield(comps, name)
    !del && return (f[id] = x)
    lasti, ID = getfield(a, :lasti), getfield(comps, :ID)
    lasti <= length(ID) && (@inbounds ID[lasti] == id) && return (@inbounds f[lasti] = x)
    id_to_index = getfield(sdict, :id_to_index)
    return (@inbounds f[id_to_index[id]] = x)
end

@inline function getfields(a::Struct)
    id, sdict = getfield(a, :id), getfield(a, :sdict)
    comps, id_to_index = getfield(sdict, :components), getfield(sdict, :id_to_index)
    del = getfield(sdict, :del)
    lasti, ID = getfield(a, :lasti), getfield(comps, :ID)
    i = !del ? id : 
        ((lasti <= length(ID) && (@inbounds ID[lasti] == id)) ? lasti : id_to_index[id])
    checkbounds(getfield(comps, :ID), i)
    getindexi = ar -> @inbounds ar[i]
    vals = unrolled_map(getindexi, values(comps))
    names = fieldnames(typeof(comps))
    return NamedTuple{names}(vals)
end

id(a::Struct) = getfield(a, :id)

function Base.show(io::IO, ::MIME"text/plain", x::Struct)
    id, sdict = getfield(x, :id), getfield(x, :sdict)
    comps, id_to_index = getfield(sdict, :components), getfield(sdict, :id_to_index)
    del = getfield(sdict, :del)
    i = del ? id_to_index[id] : id
    fields = NamedTuple(y => getfield(comps, y)[i] for y in fieldnames(typeof(comps)))
    return print(io, "Struct$fields")
end

function Base.in(a::Struct, sdict::StructDict)
    id, comps = getfield(a, :id), getfield(sdict, :components)
    del, ID = getfield(sdict, :del), getfield(comps, :ID)
    !del && return 1 <= id <= length(ID)
    lasti = getfield(a, :lasti)
    lasti <= length(ID) && (@inbounds ID[lasti] == id) && return true
    id_to_index = getfield(sdict, :id_to_index)
    return id in keys(id_to_index)
end
function Base.in(id::Int, sdict::StructDict)
    comps = getfield(sdict, :components)
    del, ID = getfield(sdict, :del), getfield(comps, :ID)
    !del && return 1 <= id <= length(ID)
    id_to_index = getfield(sdict, :id_to_index)
    return id in keys(id_to_index)
end

end

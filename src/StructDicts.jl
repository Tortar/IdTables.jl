module StructDicts

using Unrolled

export StructDict

mutable struct StructDict{C}
	del::Bool
    nextlastid::Int
	const id_to_index::Dict{Int, Int}
	const components::C
	function StructDict(components::NamedTuple)
		allequal(length.(values(components))) || error("All components must have equal length.")
		len = length(first(components))
		comps = merge((ID=collect(1:len),), components)
		return new{typeof(comps)}(false, len, Dict{Int,Int}(), comps)
	end
end

function remove!(a, i)
    @inbounds a[i], a[end] = a[end], a[i]
    pop!(a)
    return
end

Base.getproperty(sdict::StructDict, name::Symbol) = getfield(sdict, :components)[name]

function Base.delete!(sdict::StructDict, id::Int)
    comps, id_to_index = getfield(sdict, :components), getfield(sdict, :id_to_index)
	del, ID = getfield(sdict, :del), getfield(comps, :ID)
    if !(del)
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
    fieldnames(typeof(comps))[2:end] != keys(t) && error("The tuple fields do not match the container fields")
    ID, lastid = getfield(comps, :ID), getfield(sdict, :nextlastid)
    nextlastid = setfield!(sdict, :nextlastid, lastid + 1)
    push!(ID, nextlastid)
    unrolled_map(push!, values(comps)[2:end], t)
    getfield(sdict, :del) && (id_to_index[nextlastid] = length(ID))
    return sdict
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

lastkey(sdict::StructDict) = getfield(sdict, :nextlastid)[]

struct Struct{S}
    id::Int
    lasti::Int
    sdict::S
end

@inline function Base.getindex(sdict::StructDict, id::Int)
    comps, id_to_index = getfield(sdict, :components), getfield(sdict, :id_to_index)
    del = getfield(sdict, :del)
    i = del ? id_to_index[id] : id
    checkbounds(getfield(comps, :ID), i)
    return Struct(id, i, sdict)
end

@inline function Base.getproperty(a::Struct, name::Symbol)
    id, sdict = getfield(a, :id), getfield(a, :sdict)
    comps, id_to_index = getfield(sdict, :components), getfield(sdict, :id_to_index)
    del, f = getfield(sdict, :del), getfield(comps, name)
    !del && return f[id]
    lasti, ID = getfield(a, :lasti), getfield(comps, :ID)
    lasti <= length(ID) && (@inbounds ID[lasti] == id) && return @inbounds f[lasti]
    return @inbounds f[id_to_index[id]]
end

@inline function Base.setproperty!(a::Struct, name::Symbol, x)
    id, sdict = getfield(a, :id), getfield(a, :sdict)
    comps, id_to_index = getfield(sdict, :components), getfield(sdict, :id_to_index)
    del, f = getfield(sdict, :del), getfield(comps, name)
    !del && return (f[id] = x)
    lasti, ID = getfield(a, :lasti), getfield(comps, :ID)
    lasti <= length(ID) && (@inbounds ID[lasti] == id) && return (@inbounds f[lasti] = x)
    return (@inbounds f[id_to_index[id]] = x)
end

function getfields(a::Struct)
    id, sdict = getfield(a, :id), getfield(a, :sdict)
    comps, id_to_index = getfield(sdict, :components), getfield(sdict, :id_to_index)
    del = getfield(sdict, :del)
    i = del ? id_to_index[id] : id
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
    i = del ? id_to_index[id] : id
    fields = NamedTuple(y => getfield(comps, y)[i] for y in fieldnames(typeof(comps)))
    return print(io, "Struct$fields")
end

end

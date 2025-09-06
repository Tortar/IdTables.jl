module StructDicts

using Unrolled

export StructDict

mutable struct StructDict{I,C}
	const del::Base.RefValue{Bool}
	const nextlastid::Base.RefValue{I}
	const id_to_index::Dict{I, Int}
	const components::C
    StructDict(components::NamedTuple) = StructDict{UInt64}(components)
	function StructDict{I}(components::NamedTuple) where {I<:Union{Signed,Unsigned}}
		allequal(length.(values(components))) || error("All components must have equal length.")
		len = I(length(first(components)))
		comps = merge((ID=collect(1:len),), components)
		return new{I,typeof(comps)}(Ref(false), Ref(len), Dict{I,Int}(), comps)
	end
end

function remove!(a, i)
    @inbounds a[i], a[end] = a[end], a[i]
    pop!(a)
    return
end

Base.getproperty(sdict::StructDict, name::Symbol) = getfield(sdict, :components)[name]

function Base.delete!(sdict::StructDict, id::Union{Signed,Unsigned})
    comps, id_to_index = getfield(sdict, :components), getfield(sdict, :id_to_index)
	del, ID = getfield(sdict, :del), getfield(comps, :ID)
    if !(del[])
        del[] = true
        for pid in ID
            id_to_index[pid] = pid % Int
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
    nextlastid = (lastid[] += 1)
    push!(ID, nextlastid)
    unrolled_map(push!, values(comps)[2:end], t)
    getfield(sdict, :del)[] && (id_to_index[nextlastid] = length(ID))
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

struct Struct{I, S}
    id::I
    sdict::S
end

@inline function Base.getindex(sdict::StructDict, id::Union{Signed,Unsigned})
    comps, id_to_index = getfield(sdict, :components), getfield(sdict, :id_to_index)
    del = getfield(sdict, :del)[]
    del && !(id in keys(id_to_index)) && error("No agent with the specified id")
    !del && checkbounds(getfield(comps, :ID), id%Int)
    return Struct(id, sdict)
end

@inline function Base.getproperty(a::Struct, name::Symbol)
    id, sdict = getfield(a, :id), getfield(a, :sdict)
    comps, id_to_index = getfield(sdict, :components), getfield(sdict, :id_to_index)
    del = getfield(sdict, :del)[]
    if del
        i = id_to_index[id]
        return @inbounds getfield(comps, name)[i]
    else
        i = id % Int
        return getfield(comps, name)[i]
    end
end

@inline function Base.setproperty!(a::Struct, name::Symbol, x)
    id, sdict = getfield(a, :id), getfield(a, :sdict)
    comps, id_to_index = getfield(sdict, :components), getfield(sdict, :id_to_index)
    del = getfield(sdict, :del)[]
    if del
        i = id_to_index[id]
        return (@inbounds getfield(comps, name)[i] = x)
    else
        i = id % Int
        return (getfield(comps, name)[i] = x)
    end
end

function getfields(a::Struct)
    id, sdict = getfield(a, :id), getfield(a, :sdict)
    comps, id_to_index = getfield(sdict, :components), getfield(sdict, :id_to_index)
    del = getfield(sdict, :del)[]
    i = del ? id_to_index[id] : id % Int
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
    i = get(id_to_index, id, id % Int)
    fields = NamedTuple(y => getfield(comps, y)[i] for y in fieldnames(typeof(comps)))
    return print(io, "Struct$fields")
end

end

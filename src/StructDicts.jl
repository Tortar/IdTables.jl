module StructDicts

using Unrolled

export StructDict

struct StructDict{I,C}
	del::Base.RefValue{Bool}
	nextlastid::Base.RefValue{I}
	id_to_index::Dict{I, Int}
	components::C
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

function Base.delete!(sdict::StructDict, id::Unsigned)
	comps = getfield(sdict, :components)
	ID = getfield(comps, :ID)
    if !(sdict.del[])
        sdict.del[] = true
        for pid in ID
            sdict.id_to_index[pid] = id % Int
        end
    end
    i = sdict.id_to_index[id]
    removei! = a -> remove!(a, i)
    unrolled_map(removei!, values(comps))
    delete!(sdict.id_to_index, id)
    i <= length(ID) && (sdict.id_to_index[(@inbounds ID[i])] = i)
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

struct Keys{I}
	ID::I
end
Base.iterate(k::Keys) = Base.iterate(k.ID)
Base.iterate(k::Keys, state) = Base.iterate(k.ID, state)

Base.keys(sdict::StructDict) = Keys(getfield(getfield(sdict, :components), :ID))
lastkey(sdict::StructDict) = getfield(sdict, :nextlastid)[]

struct Struct{I, S}
    id::I
    sdict::S
end

Base.getindex(sdict::StructDict, id::Unsigned) = Struct(id, sdict)

function Base.getproperty(a::Struct, name::Symbol)
    id, sdict = getfield(a, :id), getfield(a, :sdict)
    comps, id_to_index = getfield(sdict, :components), getfield(sdict, :id_to_index)
    i = get(id_to_index, id, id % Int)
    return (@inbounds getfield(comps, name)[i])
end

function Base.setproperty!(a::Struct, name::Symbol, x)
    id, sdict = getfield(a, :id), getfield(a, :sdict)
    comps, id_to_index = getfield(sdict, :components), getfield(sdict, :id_to_index)
    i = get(id_to_index, id, id % Int)
    return (@inbounds getfield(comps, name)[i] = x)
end

function getfields(a::Struct)
    id, sdict = getfield(a, :id), getfield(a, :sdict)
    comps, id_to_index = getfield(sdict, :components), getfield(sdict, :id_to_index)
    i = get(id_to_index, id, id % Int)
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
    fields = NamedTuple(y => getfield(comps, y)[i] for y in fieldnames(comps))
    return print(io, "Struct$fields")
end

end


const EMPTY_VEC = Memory{Int}(undef, 0)

mutable struct SparseSetStructVector{C} <: AbstractIndexedStructVector
    idvec::Memory{Int}
    last_id::Int
    const components::C
end

function SparseSetStructVector(components::NamedTuple)
    allequal(length.(values(components))) || error("All components must have equal length")
    len = length(first(components))
    comps = merge((id=collect(1:len),), components)
    SparseSetStructVector{typeof(comps)}(EMPTY_VEC, len, comps)
end

@inline function id_to_index(isv::SparseSetStructVector, id::Int)
    id ∉ isv && throw(KeyError(id))
    idvec = getfield(isv, :idvec)
    iszero(length(idvec)) && return id
    return @inbounds idvec[id]
end

function delete_id_index!(isv::SparseSetStructVector, id::Int, i::Int)
    comps, idvec = getfield(isv, :components), getfield(isv, :idvec)
    ID = getfield(comps, :id)
    if iszero(length(idvec))
        lastid = getfield(isv, :last_id)
        idvec = Memory{Int}(undef, lastid)
        idvec .= 1:lastid
        setfield!(isv, :idvec, idvec)
    end
    removei! = a -> remove!(a, i)
    unrolled_map(removei!, values(comps))
    @inbounds idvec[id] = 0
    i <= length(ID) && (@inbounds idvec[ID[i]] = i)
    return isv
end

function Base.push!(isv::SparseSetStructVector, t::NamedTuple)
    comps, idvec = getfield(isv, :components), getfield(isv, :idvec)
    ID, lastid = getfield(comps, :id), getfield(isv, :last_id)
    lastid == typemax(lastid) && error("SparseSetStructVector is out of capacity")
    Base.tail(fieldnames(typeof(comps))) !== keys(t) && error("Tuple fields do not match container fields")
    newid = lastid + 1
    setfield!(isv, :last_id, newid)
    push!(ID, newid)
    unrolled_map(push!, Base.tail(values(comps)), t)
    old_idvec_capacity = length(idvec)
    if !iszero(old_idvec_capacity)
        if old_idvec_capacity < newid
            new_idvec_capacity = max(
                overallocation(old_idvec_capacity),
                old_idvec_capacity+1,
            )
            new_idvec = Memory{Int}(undef, new_idvec_capacity)
            unsafe_copyto!(new_idvec, 1, idvec, 1, length(idvec))
            @inbounds new_idvec[old_idvec_capacity+1:new_idvec_capacity] .= 0
            setfield!(isv, :idvec, new_idvec)
            idvec = new_idvec
        end
        @inbounds idvec[newid] = length(ID)
    end
    return isv
end

function Base.show(io::IO, ::MIME"text/plain", x::SparseSetStructVector{C}) where {C}
    comps = getfield(x, :components)
    sC = string(C)[13:end]
    print("SparseSetStructVector{$sC")
    return display(comps)
end

function Base.in(id::Int, isv::SparseSetStructVector)
    ID = getfield(getfield(isv, :components), :id)
    idvec = getfield(isv, :idvec)
    idvec_len = length(idvec)
    iszero(idvec_len) && return id ∈ eachindex(ID) 
    1 <= id <= idvec_len || return false 
    return @inbounds idvec[id] != 0
end

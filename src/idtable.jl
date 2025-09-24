
struct IdTable{S<:AbstractIndexedStructVector}
    data::S
end

function IdTable(container::Type=SlotMapStructVector{32}; components...)
	if container == SlotMapStructVector{63}
		return IdTable(SparseSetStructVector(; components...))
	else
		return IdTable(container(; components...))
	end
end

data(tsm::IdTable) = getfield(tsm, :data)

Tables.istable(::Type{<:IdTable}) = true

Tables.columnaccess(::Type{<:IdTable}) = true

function Tables.columns(tsm::IdTable)
    return getcomponents(data(tsm))
end

Tables.rowaccess(::Type{<:IdTable}) = true

function Tables.rows(tsm::IdTable)
    return getfield(data(tsm), :components)
end

function Tables.schema(tsm::IdTable)
    return Tables.schema(getfield(data(tsm), :components))
end

Base.eltype(tsm::IdTable{T}) where {T} = eltype(last(fieldtypes(T)))

Base.length(tsm::IdTable) = length(Tables.rows(tsm))

Base.iterate(tsm::IdTable) = iterate(Tables.rows(tsm))
Base.iterate(tsm::IdTable, state) = iterate(Tables.rows(tsm), state)

Base.getindex(tsm::IdTable, id::Int) = getindex(data(tsm), id)

Base.view(tsm::IdTable, id::Int) = view(data(tsm), id)

Base.push!(tsm::IdTable, nt::NamedTuple) = push!(data(tsm), nt)

Base.deleteat!(tsm::IdTable, i::Int) = deleteat!(data(tsm), i)

Base.delete!(tsm::IdTable, id::Int) = delete!(data(tsm), id)

Base.delete!(tsm::IdTable, a::IdView) = delete!(data(tsm), a)

Base.in(id::Int, tsm::IdTable) = in(a, data(tsm))

Base.in(a::IdView, tsm::IdTable) = in(a, data(tsm))

Base.getproperty(tsm::IdTable, name::Symbol) = getproperty(data(tsm), name)

Base.propertynames(tsm::IdTable) = propertynames(data(tsm))

lastid(tsm::IdTable) = lastid(data(tsm))

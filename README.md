
# IdTables.jl

[![Build Status](https://github.com/Tortar/IdTables.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/Tortar/IdTables.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/Tortar/IdTables.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/Tortar/IdTables.jl)
[![Aqua](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

`IdTables.jl` implements containers with stable identifiers storing data with a structure-of-vectors layout.

The main type exported by the library is `IdTable`, which is a type compatible with the `Tables.jl` interface. Additionally, 
also the struct vectors types `SlotMapStructVector` and `SparseSetStructVector`, which internally are used to store the data
of an `IdTable`, are available.

Differently from other packages such as `DataFrames.jl`, `TypedTables.jl`, etc..., each row of an `IdTable` is assigned a stable
identifier when it's added to the table. This can then be used to index into the container allowing to support `O(1)` access, addition
and deletion of ID-backed rows without compromising the performance of operations on single homogeneous fields, unlike a dictionary
of structs.

## Examples

```julia
julia> using IdTables

julia> table = IdTable(name = ["alice","bob"], age = [30, 40]);

julia> r = table[1] # retrieve row with id 1
(id = 1, name = "alice", age = 30)

julia> rv = @view(table[2])
IdRowView(id = 2, name = "bob", age = 40)

julia> rv.name
"bob"

julia> rv.age = 10
10

julia> push!(table, (name = "carol", age = 25));

julia> delete!(table, 2); # delete row with id 2

julia> table[2] # now 2 is no longer a valid id
ERROR: KeyError: key 2 not found
Stacktrace:
 [1] id_to_index
   @ ~/.julia/dev/IdTables/src/slotmap.jl:48 [inlined]
 [2] getindex
   @ ~/.julia/dev/IdTables/src/idvectors.jl:64 [inlined]
 [3] getindex(tsm::IdTable{SlotMapStructVector{32, StructArrays.StructVector{…}}}, id::Int64)
   @ IdTables ~/.julia/dev/IdTables/src/idtable.jl:41
 [4] top-level scope
   @ REPL[9]:1
Some type information was truncated. Use `show(err)` to see complete types.

julia> sum(table.age) # this will use the stored age vector
55
```

## Contributing

Contributions are welcome! If you encounter any issues, have suggestions for improvements, or would like to add new features,
feel free to open an issue or submit a pull request.

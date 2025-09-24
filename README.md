
# IndexedStructVectors.jl

[![Build Status](https://github.com/Tortar/IndexedStructVectors.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/Tortar/IndexedStructVectors.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/Tortar/IndexedStructVectors.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/Tortar/IndexedStructVectors.jl)
[![Aqua](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

`IndexedStructVectors.jl` implements indexable containers storing data with a structure-of-vectors layout. Differently from [`StructArrays.jl`](https://github.com/JuliaArrays/StructArrays.jl), each
row is assigned a stable identifier when initialized which can then be used to index into the container.
This allows to support `O(1)` access, addition and deletion of ID-backed rows, without compromising the performance of operations of single homogeneous fields of the structure, unlike a vector/dictionary of structs.

## Examples

```julia
julia> using IndexedStructVectors

julia> s = IndexedStructVector((name = ["alice","bob"], age = [30, 40])) # initial IDs are 1 and 2
IndexedStructVector{ID::Vector{Int64}, name::Vector{String}, age::Vector{Int64}}(ID = [1, 2], name = ["alice", "bob"], age = [30, 40])

julia> x = s[1]
IdView(ID = 1, name = "alice", age = 30)

julia> x.name
"alice"

julia> x.age = 41
41

julia> push!(s, (name = "carol", age = 25));

julia> delete!(s, 2); # delete bob by id

julia> s[2] # now 2 is no longer a valid key
ERROR: KeyError: key 2 not found
...

julia> sum(s.age) # this will just use the stored age vector
66
```

## Contributing

Contributions are welcome! If you encounter any issues, have suggestions for improvements, or would like to add new features, feel free to open an issue or submit a pull request.

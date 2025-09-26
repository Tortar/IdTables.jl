
using IndexedStructVectors
using Aqua, Test

@testset "IndexedStructVectors.jl" begin

    if "CI" in keys(ENV)
        @testset "Code quality (Aqua.jl)" begin
            Aqua.test_all(IndexedStructVectors, deps_compat=false)
            Aqua.test_deps_compat(IndexedStructVectors, check_extras=false)
        end
    end

    include("test_idtable_and_sparseset.jl")
    include("test_slotmap.jl")
    include("test_table_interface.jl")
end

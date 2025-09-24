
using IndexedStructVectors
using Test

for (type, name) in [
        (SparseSetStructVector, "SparseSetStructVector"), 
        ((; kwargs...) -> IdTable(SparseSetStructVector; kwargs...), "IdTable")
]
    @testset "$name" begin
        @testset "construction" begin
            s = type(x = [10, 20, 30], y = ["a", "b", "c"])
            @test length(collect(keys(s))) == 3
            @test IndexedStructVectors.lastid(s) == 3
            @test_throws ArgumentError type(x = [1,2], y = ["a"])
        end

        @testset "getindex/getproperty/setproperty!" begin
            s = type(num = [1,2,3], name = ["x","y","z"])
            a = @view(s[2])

            @test typeof(a) <: IndexedStructVectors.IdView
            @test a.num == 2
            @test a.name == "y"

            a.num = 42
            @test s[2].num == a.num == 42
        end

        @testset "deleteat!/delete!/push!" begin
            s = type(num = [10,20,30,40], tag = ['a','b','c','d'])

            ids_before = collect(keys(s))
            @test ids_before == [1,2,3,4]

            deleteat!(s, 2)
            ids_after = collect(keys(s))
            @test length(ids_after) == 3
            @test (2 in ids_after) == false
            @test 1 ∈ ids_after

            push!(s, (num = 111, tag = 'z'))
            new_id = IndexedStructVectors.lastid(s)
            @test new_id == s[new_id].id == 5
            @test new_id in collect(keys(s))
            @test s[new_id].num == 111

            delete!(s, 4)
            ids_after = collect(keys(s))
            @test (4 in ids_after) == false
            @test s.id[2] == 5
            @test s[s.id[2]].num == 111
            @test length(ids_after) == 3

            @test_throws KeyError delete!(s, 9999)
        end
    end
end

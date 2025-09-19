
using IndexedStructVectors
using Test

using IndexedStructVectors: val_mask, gen_mask

function assert_invariants(isv::SlotMapStructVector)
    @assert val_mask(isv) isa UInt64
    @assert ispow2(val_mask(isv) + 1)
    slots = getfield(isv, :slots)
    slots_len = getfield(isv, :slots_len)
    free_head = getfield(isv, :free_head)
    last_id = getfield(isv, :last_id)
    comp = getfield(isv, :components)
    @assert allequal(length.(values(comp)))
    ID = comp.id
    len = length(ID)
    @assert len ≤ val_mask(isv)
    @assert allunique(ID)
    @assert !signbit(last_id)
    for (i, id) in enumerate(ID)
        if iszero(slots_len)
            @assert i == id
        else
            @assert !signbit(id)
            slot_idx = Int(id & val_mask(isv))
            @assert slot_idx ≤ slots_len
            @assert slots[slot_idx] === id & gen_mask(isv) | UInt64(i)
        end
        @assert id ∈ isv
    end
    if iszero(slots_len)
        @assert isempty(slots)
        @assert iszero(free_head)
        @assert iszero(last_id & gen_mask(isv))
    else
        @assert slots_len ≤ length(slots)
        @assert length(slots) ≤ val_mask(isv)
        n_free = 0
        n_dead = 0
        max_gen = UInt64(0)
        for (slot_idx, slot) in enumerate(view(slots, 1:slots_len))
            gen = slot & gen_mask(isv)
            max_gen = max(max_gen, gen)
            if signbit(slot%Int64)
                if gen === gen_mask(isv)
                    n_dead += 1
                    # canonical dead slot
                    @assert slot === ~UInt64(0)
                else
                    n_free += 1
                    @assert slot & val_mask(isv) ≤ slots_len
                end
            else
                i = slot & val_mask(isv)
                @assert ID[i]%UInt64 === gen | UInt64(slot_idx)
            end
        end
        @assert len + n_free + n_dead == slots_len
        @assert last_id & gen_mask(isv) ≤ max_gen
        @assert last_id & val_mask(isv) ≤ slots_len
        # Finally check the free list
        visited = zeros(Bool, slots_len)
        p = free_head
        n = 0
        while !iszero(p)
            @assert p ≤ slots_len
            @assert !visited[p]
            visited[p] = true
            n += 1
            slot = slots[p]
            @assert signbit(slot%Int64)
            p = slot & val_mask(isv)
            gen = slot & gen_mask(isv)
            @assert gen !== gen_mask(isv)
        end
        @assert n == n_free
    end
end

@testset "SlotMapStructVector" begin
    @testset "construction" begin
        s = SlotMapStructVector((x = [10, 20, 30], y = ["a", "b", "c"]))
        assert_invariants(s)
        @test length(collect(keys(s))) == 3
        @test IndexedStructVectors.lastkey(s) == 3
        @test_throws ErrorException SlotMapStructVector((x = [1,2], y = ["a"]))
    end

    @testset "getindex/getproperty/setproperty!/getfields" begin
        s = SlotMapStructVector((num = [1,2,3], name = ["x","y","z"]))
        assert_invariants(s)
        a = s[2]

        @test typeof(a) <: IndexedStructVectors.IndexedView
        @test a.num == 2
        @test a.name == "y"

        a.num = 42
        @test s[2].num == a.num == 42

        nt = getfields(s[2])
        @test nt.num == 42
        @test nt.name == "y"
        @test length(nt) == 2
    end

    @testset "deleteat!/delete!/push!" begin
        s = SlotMapStructVector((num = [10,20,30,40], tag = ['a','b','c','d']))
        assert_invariants(s)

        ids_before = collect(keys(s))
        @test ids_before == [1,2,3,4]

        deleteat!(s, 2)
        assert_invariants(s)
        ids_after = collect(keys(s))
        @test length(ids_after) == 3
        @test (2 in ids_after) == false
        @test 1 ∈ ids_after

        push!(s, (num = 111, tag = 'z'))
        assert_invariants(s)
        new_id = IndexedStructVectors.lastkey(s)
        @test new_id == s[new_id].id == id(s[new_id]) == 1<<32 | 2
        @test new_id in collect(keys(s))
        @test s[new_id].num == 111

        delete!(s, 4)
        assert_invariants(s)
        ids_after = collect(keys(s))
        @test (4 in ids_after) == false
        @test s.id[2] == new_id
        @test s[new_id].num == 111
        @test length(ids_after) == 3
        @test 4 ∉ s
        @test -4 ∉ s
        @test_throws KeyError s[4]
        @test_throws KeyError s[-4]

        @test_throws KeyError delete!(s, 9999)

        # pushing initially empty
        s = SlotMapStructVector((num = Int[], tag = Char[]))
        ids = Int64[]
        assert_invariants(s)
        for i in 1:100
            push!(s, (num = i, tag = Char(i)))
            push!(ids, IndexedStructVectors.lastkey(s))
            assert_invariants(s)
        end
        delete!(s, pop!(ids))
        for i in 101:1000
            push!(s, (num = i, tag = Char(i)))
            push!(ids, IndexedStructVectors.lastkey(s))
            assert_invariants(s)
        end
        while !isempty(ids)
            delete!(s, pop!(ids))
            assert_invariants(s)
        end
        for i in 1:100
            push!(s, (num = i, tag = Char(i)))
            push!(ids, IndexedStructVectors.lastkey(s))
            assert_invariants(s)
        end
    end

    @testset "test logic for dead slots" begin
        # if NBITS=2 capacity is limited to 3 elements
        @test_throws ErrorException SlotMapStructVector{2}((;num = [10,20,30,40]))
        s = SlotMapStructVector{2}((;num = [10,20,30]))
        @test_throws ErrorException push!(s, (; num=10))
        s = SlotMapStructVector{2}((;num = [10,20,30]))
        deleteat!(s, 3)
        assert_invariants(s)
        push!(s, (; num=10))
        assert_invariants(s)
        deleteat!(s, 3)
        push!(s, (; num=10))
        assert_invariants(s)
        @test_throws ErrorException push!(s, (; num=10))

        # Now simulate pushing and deleting 2^61 times so one of the slots becomes dead
        deleteat!(s, 3)
        getfield(s, :slots)[3] = ~UInt64(0)
        setfield!(s, :free_head, 0)
        @test_throws ErrorException push!(s, (; num=10))

        s = SlotMapStructVector{61}((;num = [10,20,30,40]))
        # As the last id is deleted and pushed repeatedly, it should get the following
        # ids.
        expected_last_ids = [
            0<<61 | Int64(4),
            1<<61 | Int64(4),
            2<<61 | Int64(4),
            3<<61 | Int64(4),
            0<<61 | Int64(5),
            1<<61 | Int64(5),
            2<<61 | Int64(5),
            3<<61 | Int64(5),
            0<<61 | Int64(6),
        ]
        for expected_last_id in expected_last_ids
            @test s.id == [1,2,3, expected_last_id]
            delete!(s, expected_last_id)
            assert_invariants(s)
            @test s.id == [1,2,3]
            push!(s, (;num = 50))
            assert_invariants(s)
        end

        s = SlotMapStructVector{61}((;num = [10,20,30,40]))
        delete!(s, Int64(1))
        # As the first id is deleted and pushed repeatedly, it should get the following
        # ids.
        expected_last_ids = [
            1<<61 | Int64(1),
            2<<61 | Int64(1),
            3<<61 | Int64(1),
            0<<61 | Int64(5),
            1<<61 | Int64(5),
            2<<61 | Int64(5),
            3<<61 | Int64(5),
            0<<61 | Int64(6),
        ]
        for expected_last_id in expected_last_ids
            assert_invariants(s)
            push!(s, (;num = 50))
            assert_invariants(s)
            @test s.id == [4,2,3, expected_last_id]
            delete!(s, expected_last_id)
            assert_invariants(s)
            @test s.id == [4,2,3]
        end
    end
end

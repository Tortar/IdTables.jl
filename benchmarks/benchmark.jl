using Chairmarks
using IndexedStructVectors
using Random

"""
    Setup a `size` length vector
    after `size*fract_shuffled` random delete and push pairs
"""
function setup_isv(type, size, fract_shuffled)
    isv = type((;num=ones(size)))
    n_del_push = round(Int, size*fract_shuffled)
    for i in 1:n_del_push
        id = rand(isv.ID)
        delete!(isv, id)
        push!(isv, (;num=rand()))
    end
    isv
end

function bench_rand_access(type, size, fract_shuffled)
    isv = setup_isv(type, size, fract_shuffled)
    ids = shuffle(isv.ID)
    @be rand(ids) isv[_].num seconds=10
end

function bench_rand_in(type, size, fract_shuffled)
    isv = setup_isv(type, size, fract_shuffled)
    @be rand(Int64) ∈(isv) seconds=10
end

function bench_rand_deletes(type, size, fract_shuffled, n_deletes)
    @be(
        let
            isv = setup_isv(type, size, fract_shuffled)
            ids = shuffle(isv.ID)
            (isv, ids)
        end,
        (x)->let
            for i in 1:n_deletes
                delete!(x[1], x[2][i])
            end
        end,
        evals=1,
        seconds=10,
    )
end

function bench_pushes(type, size, fract_shuffled, n_pushes)
    @be(
        setup_isv(type, size, fract_shuffled),
        (x)->let
            for i in 1:n_pushes
                push!(x, (;num=3.14))
            end
        end,
        evals=1,
        seconds=10,
    )
end

# bench_rand_access(SlotMapStructVector, 10_000_000, 10.0)
# bench_rand_access(IndexedStructVector, 10_000_000, 10.0)

#=
julia> bench_rand_access(SlotMapStructVector, 10_000_000, 0.0)
Benchmark: 551559 samples with 8328 evaluations
 min    2.080 ns
 median 2.098 ns
 mean   2.109 ns
 max    5.354 ns

julia> bench_rand_access(IndexedStructVector, 10_000_000, 0.0)
Benchmark: 569861 samples with 8425 evaluations
 min    1.985 ns
 median 2.004 ns
 mean   2.019 ns
 max    6.038 ns


julia> bench_rand_access(SlotMapStructVector, 10_000_000, 10.0)
Benchmark: 467259 samples with 9386 evaluations
 min    2.088 ns
 median 2.206 ns
 mean   2.236 ns
 max    11.180 ns

julia> bench_rand_access(IndexedStructVector, 10_000_000, 10.0)
Benchmark: 402714 samples with 5267 evaluations
 min    2.296 ns
 median 4.482 ns
 mean   4.608 ns
 max    33.148 ns

=#
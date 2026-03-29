using Test

include("../julia/Engines.jl")
using .Engines

const SEED1 = UInt8[
    0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77,
    0x88, 0x99, 0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff,
    0x10, 0x20, 0x30, 0x40, 0x50, 0x60, 0x70, 0x80,
    0x90, 0xa0, 0xb0, 0xc0, 0xd0, 0xe0, 0xf0, 0x01
]

const SEED2 = UInt8[
    0xff, 0xee, 0xdd, 0xcc, 0xbb, 0xaa, 0x99, 0x88,
    0x77, 0x66, 0x55, 0x44, 0x33, 0x22, 0x11, 0x00,
    0x01, 0xf0, 0xe0, 0xd0, 0xc0, 0xb0, 0xa0, 0x90,
    0x80, 0x70, 0x60, 0x50, 0x40, 0x30, 0x20, 0x10
]

function collect_u32(kind::Symbol, seed::Vector{UInt8}, n::Int=10)
    st = init_engine(kind, seed)
    return [next_u32!(st) for _ in 1:n]
end

function collect_bytes(kind::Symbol, seed::Vector{UInt8}, n::Int=10)
    st = init_engine(kind, seed)
    return [next_byte!(st) for _ in 1:n]
end

function collect_idxs(kind::Symbol, seed::Vector{UInt8}, n::Int=20, lim::Int=256)
    st = init_engine(kind, seed)
    return [next_index!(st, lim) for _ in 1:n]
end

function has_bad_state(st)
    vals = Float64[]
    if st isa EngineAState
        append!(vals, [st.x, st.y, st.z, st.r])
    elseif st isa EngineBState
        append!(vals, [st.x, st.y, st.z, st.a, st.b, st.c])
    elseif st isa EngineCState
        append!(vals, [st.x, st.y, st.z, st.a, st.b, st.c, Float64(st.h)])
    end
    return any(isnan, vals) || any(isinf, vals)
end

@testset "Engine deterministic smoke tests" begin
    for kind in (:A, :B, :C)
        out1 = collect_u32(kind, SEED1, 10)
        out2 = collect_u32(kind, SEED1, 10)
        out3 = collect_u32(kind, SEED2, 10)

        println("\nEngine ", kind)
        println("same seed stream 1 = ", out1)
        println("same seed stream 2 = ", out2)
        println("diff seed stream   = ", out3)

        @test out1 == out2
        @test out1 != out3
        @test length(out1) == 10
    end
end

@testset "Byte and index sanity" begin
    for kind in (:A, :B, :C)
        bs = collect_bytes(kind, SEED1, 10)
        idxs = collect_idxs(kind, SEED1, 20, 256)

        println("bytes ", kind, " = ", bs)
        println("idxs  ", kind, " = ", idxs)

        @test all(0x00 <= b <= 0xff for b in bs)
        @test all(1 <= i <= 256 for i in idxs)
    end
end

@testset "No NaN or Inf after warmup and stepping" begin
    for kind in (:A, :B, :C)
        st = init_engine(kind, SEED1)
        @test !has_bad_state(st)

        for _ in 1:200
            next_u32!(st)
            @test !has_bad_state(st)
        end
    end
end

@testset "Parameter range checks" begin
    stA = init_engine(:A, SEED1)
    @test 0.0 < stA.x < 1.0
    @test 0.0 < stA.y < 1.0
    @test 0.0 < stA.z < 1.0
    @test 0.0 <= stA.r <= 3.0e7

    stB = init_engine(:B, SEED1)
    @test -1.0 < stB.x < 1.0
    @test -1.0 < stB.y < 1.0
    @test -1.0 < stB.z < 1.0
    @test stB.a != 0.0
    @test stB.b != 0.0
    @test stB.c != 0.0

    stC = init_engine(:C, SEED1)
    @test -1.0 < stC.x < 1.0
    @test -1.0 < stC.y < 1.0
    @test -1.0 < stC.z < 1.0
    @test 0.0 <= stC.a <= 1.0e7
    @test 0.0 <= stC.b <= 1.0e7
    @test 0.0 <= stC.c <= 1.0e7
    @test 1 <= stC.h <= 10
end

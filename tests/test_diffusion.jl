using Test

include("../julia/Engines.jl")
include("../julia/Diffusion.jl")

using .Engines
using .Diffusion

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

const DATA = UInt8[
    0x00, 0x01, 0x02, 0x03, 0x10, 0x11, 0x12, 0x13,
    0x20, 0x21, 0x22, 0x23, 0x30, 0x31, 0x32, 0x33,
    0x40, 0x41, 0x42, 0x43, 0x50, 0x51, 0x52, 0x53,
    0x60, 0x61, 0x62, 0x63, 0x70, 0x71, 0x72, 0x73
]

@testset "Diffusion reversibility" begin
    for kind in (:A, :B, :C)
        st_enc = init_engine(kind, SEED1)
        cipher = diffuse(DATA, st_enc)

        st_dec = init_engine(kind, SEED1)
        plain = undiffuse(cipher, st_dec)

        println("\nEngine ", kind)
        println("plain  = ", DATA)
        println("cipher = ", cipher)
        println("dec    = ", plain)

        @test plain == DATA
    end
end

@testset "Diffusion determinism" begin
    for kind in (:A, :B, :C)
        st1 = init_engine(kind, SEED1)
        c1 = diffuse(DATA, st1)

        st2 = init_engine(kind, SEED1)
        c2 = diffuse(DATA, st2)

        @test c1 == c2
    end
end

@testset "Diffusion seed sensitivity" begin
    for kind in (:A, :B, :C)
        st1 = init_engine(kind, SEED1)
        c1 = diffuse(DATA, st1)

        st2 = init_engine(kind, SEED2)
        c2 = diffuse(DATA, st2)

        @test c1 != c2
    end
end

@testset "Diffusion chaining effect" begin
    altered = copy(DATA)
    altered[8] = altered[8] ⊻ 0xff

    for kind in (:A, :B, :C)
        st1 = init_engine(kind, SEED1)
        c1 = diffuse(DATA, st1)

        st2 = init_engine(kind, SEED1)
        c2 = diffuse(altered, st2)

        diff_positions = findall(i -> c1[i] != c2[i], eachindex(c1))

        println("changed positions for ", kind, " = ", diff_positions)

        @test 8 in diff_positions
        @test length(diff_positions) > 1
    end
end

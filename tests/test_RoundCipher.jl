using Test

include("../julia/Engines.jl")
include("../julia/Permutation.jl")
include("../julia/Diffusion.jl")
include("../julia/Substitution.jl")
include("../julia/RoundCipher.jl")

using .Engines
using .Permutation
using .Diffusion
using .Substitution
using .RoundCipher

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

@testset "RoundCipher single-round reversibility" begin
    enc = encrypt_round(DATA, SEED1)
    dec = decrypt_round(enc, SEED1)

    println("plain = ", DATA)
    println("enc   = ", enc)
    println("dec   = ", dec)

    @test dec == DATA
    @test enc != DATA
end

@testset "RoundCipher single-round determinism" begin
    enc1 = encrypt_round(DATA, SEED1)
    enc2 = encrypt_round(DATA, SEED1)

    @test enc1 == enc2
end

@testset "RoundCipher seed sensitivity" begin
    enc1 = encrypt_round(DATA, SEED1)
    enc2 = encrypt_round(DATA, SEED2)

    @test enc1 != enc2
end

@testset "RoundCipher multi-round reversibility" begin
    enc = encrypt_chunk(DATA, SEED1; rounds=3)
    dec = decrypt_chunk(enc, SEED1; rounds=3)

    println("enc3 = ", enc)
    println("dec3 = ", dec)

    @test dec == DATA
    @test enc != DATA
end

@testset "RoundCipher multi-round determinism" begin
    enc1 = encrypt_chunk(DATA, SEED1; rounds=3)
    enc2 = encrypt_chunk(DATA, SEED1; rounds=3)

    @test enc1 == enc2
end

@testset "RoundCipher wrong-seed failure" begin
    enc = encrypt_chunk(DATA, SEED1; rounds=2)
    dec_wrong = decrypt_chunk(enc, SEED2; rounds=2)

    @test dec_wrong != DATA
end

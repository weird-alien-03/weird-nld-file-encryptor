using Test

include("../julia/Engines.jl")
include("../julia/Substitution.jl")

using .Engines
using .Substitution

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

@testset "S-box validity" begin
    st = init_engine(:C, SEED1)
    sbox = make_sbox(st)

    @test length(sbox) == 256
    @test sort(Int.(sbox)) == collect(0:255)

    inv = invert_sbox(sbox)
    @test length(inv) == 256
    @test sort(Int.(inv)) == collect(0:255)
end

@testset "S-box determinism" begin
    st1 = init_engine(:C, SEED1)
    s1 = make_sbox(st1)

    st2 = init_engine(:C, SEED1)
    s2 = make_sbox(st2)

    @test s1 == s2
end

@testset "S-box seed sensitivity" begin
    st1 = init_engine(:C, SEED1)
    s1 = make_sbox(st1)

    st2 = init_engine(:C, SEED2)
    s2 = make_sbox(st2)

    @test s1 != s2
end

@testset "Substitution reversibility" begin
    st = init_engine(:C, SEED1)
    sbox = make_sbox(st)
    inv = invert_sbox(sbox)

    enc = substitute(DATA, sbox)
    dec = unsubstitute(enc, inv)

    println("sbox[1:16] = ", sbox[1:16])
    println("data       = ", DATA)
    println("enc        = ", enc)
    println("dec        = ", dec)

    @test dec == DATA
end

@testset "Substitution changes values" begin
    st = init_engine(:C, SEED1)
    sbox = make_sbox(st)

    enc = substitute(DATA, sbox)
    @test enc != DATA
end

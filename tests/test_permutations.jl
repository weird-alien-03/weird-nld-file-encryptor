using Test

include("../julia/Engines.jl")
include("../julia/Permutation.jl")

using .Engines
using .Permutation

const SEED = UInt8[
    0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77,
    0x88, 0x99, 0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff,
    0x10, 0x20, 0x30, 0x40, 0x50, 0x60, 0x70, 0x80,
    0x90, 0xa0, 0xb0, 0xc0, 0xd0, 0xe0, 0xf0, 0x01
]

@testset "Permutation tests" begin
    st1 = init_engine(:A, SEED)
    perm1 = make_permutation(st1, 16)

    st2 = init_engine(:A, SEED)
    perm2 = make_permutation(st2, 16)

    @test perm1 == perm2
    @test sort(perm1) == collect(1:16)

    data = UInt8.(collect(0:15))
    enc = apply_permutation(data, perm1)
    dec = apply_inverse_permutation(enc, perm1)

    println("perm = ", perm1)
    println("data = ", data)
    println("enc  = ", enc)
    println("dec  = ", dec)

    @test dec == data
end

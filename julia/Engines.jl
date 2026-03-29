#= 
This is Engines.jl
it turns seed bytes into deterministic engine state
and then emit bytes, 32-bit words, or indices from that state

mutable struct states the objects for each engine.
I made one shared API exposed through multiple dispatch
=#

module Engines

export AbstractEngine, EngineAState, EngineBState, EngineCState, init_engine, next_u32!, next_byte!, next_index!, warmup!

abstract type AbstractEngine end
# A common parent type for all engines

mutable struct EngineAState <: AbstractEngine
	x::Float64
	y::Float64
	z::Float64
	r::Float64
end

mutable struct EngineBState <: AbstractEngine
	x::Float64
	y::Float64
	z::Float64
	a::Float64
	b::Float64
	c::Float64 
end

mutable struct EngineCState <: AbstractEngine
	x::Float64
	y::Float64
	z::Float64
	a::Float64
	b::Float64
	c::Float64
	h::Int
end

#=
reads 8 bytes starting at an offset 
and packs them into one UInt64.
=#
function bytes_to_u64(seed::Vector{UInt8}, start::Int)
	n = length(seed)
	n == 0 && error("Seed cannot be empty")
	v = UInt64(0)
	for i in 0:7
		idx = mod((start + i - 2),n) + 1
		v = (v << 8) | UInt64(seed[idx])
	end
	return v
end

#=
The following func is the Julia equivalent
of the Splitmix64 algorithm

scrambles bits so nearby 
seed values do not stay too similar.
=#
function mix64(x::UInt64)
	x ⊻= x >> 30
	x *= 0xbf58476d1ce4e5b9
	x ⊻= x >> 27
	x *= 0x94d049bb133111eb
	x ⊻= x >> 31
	return x
end

#=
rescales the mixed UInt64 
into a floating-point number in [0,1]
=#
function u64_to_unit(x::UInt64)
	return Float64(x)/Float64(typemax(UInt64))
end

#=
tretches a [0,1] value 
into a specific required interval.
=#
function unit_to_range(u::Float64,lo::Float64,hi::Float64)
	return lo + (hi-lo)*u
end

#=
gives a deterministic uniform-style real in [0,1]
=#
function seed_to_01(seed::Vector{UInt8}, off::Int)
	return u64_to_unit(mix64(bytes_to_u64(seed,off)))
end

#=
remaps seed_to_01 to [-1,1]
=#
function seed_to_pm1(seed::Vector{UInt8}, off::Int)
	return 2.0 * seed_to_01(seed,off) - 1.0
end

function non_zero_param(seed::Vector{UInt8}, off::Int; scale::Float64=10.0, ε::Float64=1e-6)
	u = seed_to_pm1(seed, off)
	if abs(u) < ε
		return u < 0 ? -ε : ε
	end
	return scale * u
end


#=
to avoid dangerous exact boundary values like 0, 1, 
or values too close to zero when divisions are involved
=#
function safe_state_01(seed::Vector{UInt8}, off::Int, ε::Float64=1e-12)
	x = seed_to_01(seed,off)
	return clamp(x, ε, 1 - ε)
end

function safe_state_pm1(seed::Vector{UInt8}, off::Int, ε::Float64=1e-12)
	x = seed_to_pm1(seed,off)
	if abs(x) < ε
		return x < 0 ? -ε : ε
	end
	return clamp(x, -1.0 + ε, 1.0 - ε)
end

function init_engine(kind::Symbol, seed::Vector{UInt8})::AbstractEngine
	if kind == :A
		#3D - EHCM
		st = EngineAState(
			safe_state_01(seed,1),
			safe_state_01(seed,9),
			safe_state_01(seed,17),
			unit_to_range(seed_to_01(seed,25),0.0,3.0e7)
		)
		warmup!(st,32)
		return st

	elseif kind == :B
		#3D - ICM
		st = EngineBState(
			safe_state_pm1(seed,3),
			safe_state_pm1(seed,11),
			safe_state_pm1(seed,19),
		non_zero_param(seed, 27; scale=10.0),
		non_zero_param(seed, 35; scale=10.0),
		non_zero_param(seed, 43; scale=10.0)
		)
		warmup!(st,32)
		return st
		#3D - SCC
	elseif kind == :C
		st = EngineCState(
			safe_state_pm1(seed,5),
			safe_state_pm1(seed,13),
			safe_state_pm1(seed,21),
			unit_to_range(seed_to_01(seed,29),0.0,1.0e7),
			unit_to_range(seed_to_01(seed,37),0.0,1.0e7),
			unit_to_range(seed_to_01(seed,45),0.0,1.0e7),
			Int(mod(bytes_to_u64(seed,53),10)) + 1
		)
		warmup!(st,32)
		return st

	else
		error("Unknown Engine kind: $kind")
	end
end

#do refer the sources for these maps

# A: 3D EHC Map
function step!(st::EngineAState)
	x,y,z = st.x,st.y,st.z
	r = st.r

	xn = mod(2^(pi+x)*(r - y^2 + z),1.0)
	yn = mod(7^(pi+y)*(r - z^2 + x),1.0)
	zn = mod(11^(pi+z)*(r - x^2 + y),1.0)

	st.x,st.y,st.z = xn,yn,zn
	
	return st
end

function safe_div(num::Float64, den::Float64, ε::Float64=1e-12)
    if abs(den) < ε
        den = den < 0 ? -ε : ε
    end
    return num / den
end

# B: 3D IC Map
function step!(st::EngineBState)
	x,y,z = st.x,st.y,st.z
	a,b,c = st.a,st.b,st.c

	xn = sin(safe_div(a,x))*sin(safe_div(b,y))*sin(safe_div(c,z))
	yn = sin(safe_div(c,z))*sin(safe_div(b,y))
	zn = sin(safe_div(c,y))*sin(safe_div(b,z))
	
	st.x,st.y,st.z = xn,yn,zn
	
	return st
end

# this function is gonna be used in the SCC step!
function g(num::Float64,d1::Float64,d2::Float64,ϵ::Float64 = 0.00001)
	return (num^2)/(d1*d2 + ϵ)
end	

# C: 3D SCC Map
function step!(st::EngineCState)
	x,y,z = st.x,st.y,st.z
	a,b,c = st.a,st.b,st.c
	h = st.h
	
	xn = sin((a*x + g(y,z,x))^h)
	yn = cos((b*y + g(z,x,y))^h)
	zn = cos((c*z + g(x,y,z))^h)
	
	st.x, st.y, st.z = xn, yn, zn
	return st
end

function warmup!(st::AbstractEngine, rounds::Int)
	for _ in 1:rounds
		step!(st)
	end
	return st
end

function state_to_u32(x::Float64,y::Float64,z::Float64)::UInt32
	sx = reinterpret(UInt64,x)
	sy = reinterpret(UInt64,y)
	sz = reinterpret(UInt64,z)

	mixed = mix64(sx ⊻ (sy << 7) ⊻ (sz << 13))
	return UInt32(mixed & 0xffffffff)
end

function next_u32!(st::EngineAState)::UInt32
	step!(st)
	return state_to_u32(st.x,st.y,st.z)
end

function next_u32!(st::EngineBState)::UInt32
	step!(st)
	return state_to_u32(st.x,st.y,st.z)
end

function next_u32!(st::EngineCState)::UInt32
	step!(st)
	return state_to_u32(st.x,st.y,st.z)
end

function next_byte!(st::AbstractEngine)::UInt8
	return UInt8(next_u32!(st) & 0xff)
end

function next_index!(st::AbstractEngine, n::Int)::Int
	n <= 0 && error("n must be positive")
	return Int(mod(next_u32!(st), UInt32(n))) + 1
end

end

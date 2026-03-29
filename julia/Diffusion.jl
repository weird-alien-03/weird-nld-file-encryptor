#=
Diffusion.jl
does three jobs: generate a per-byte mask stream 
from the engine, apply forward diffusion 
to a permuted chunk, and apply inverse diffusion 
to recover the original permuted chunk.
=#

module Diffusion

import ..Engines: AbstractEngine, next_byte!

export make_mask, diffuse, undiffuse

function make_mask(st::AbstractEngine, n::Int)::Vector{UInt8}
	n < 0 && error("n cannot be negative")
	return [next_byte!(st) for _ in 1:n]
end

function diffuse(data::Vector{UInt8}, st::AbstractEngine; iv::UInt8=0xa5)::Vector{UInt8}
	n = length(data)
	mask = make_mask(st,n)
	out = Vector{UInt8}(undef,n)

	prev = iv
	for i in 1:n
		out[i]=data[i] ⊻ mask[i] ⊻ prev
		prev = out[i]
	end

	return out
end

function undiffuse(data::Vector{UInt8}, st::AbstractEngine; iv::UInt8=0xa5)::Vector{UInt8}
	n = length(data)
	mask = make_mask(st,n)
	out = Vector{UInt8}(undef,n)

	prev = iv
	for i in 1:n
		out[i] = data[i] ⊻ mask[i] ⊻ prev
		prev = data[i]
	end

	return out
end

end

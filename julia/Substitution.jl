#=
Substitution.jl
I'll be using a S-box substitution

Fisher–Yates shuffle over the values 0:255, driven by
next_index! from Engine C (SCC)
=#

module Substitution

import ..Engines: AbstractEngine, next_index!

export make_sbox, invert_sbox, substitute, unsubstitute

function make_sbox(st::AbstractEngine)::Vector{UInt8}
	box = UInt8.(collect(0:255))

	for i in 256:-1:2
		j = next_index!(st,i)
		box[i], box[j] = box[j], box[i]
	end

	return box
end

function invert_sbox(sbox::Vector{UInt8})::Vector{UInt8}
	length(sbox) == 256 || error("S-box must have length 256")

	inv = Vector{UInt8}(undef,256)
	for i in 1:256
		v = Int(sbox[i]) + 1
		inv[v] = UInt8(i - 1)
	end

	return inv
end

function substitute(data::Vector{UInt8}, sbox::Vector{UInt8})::Vector{UInt8}
	length(sbox) == 256 || error("S-box must have length 256")
	return [sbox[Int(b)+1] for b in data]
end

function unsubstitute(data::Vector{UInt8}, invsbox::Vector{UInt8})::Vector{UInt8}
	length(invsbox) == 256 || error("S-box must have length 256")
	return [invsbox[Int(b)+1] for b in data]
end

end

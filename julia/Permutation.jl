#= 
Permutations.jl
to build a deterministic permutation of 
byte positions from an engine stream,
apply that permutation, and invert it during decryption.

Equivalent of "Pixel Scrambling"
=#

#=
This layer should answer three questions:
- How to generate a valid shuffle of positions 1:n?
- How do I apply it to a byte vector?
- How do I reverse it exactly?
=#

module Permutation

import ..Engines: AbstractEngine, next_index!

export make_permutation, invert_permutation, apply_permutation, apply_inverse_permutation

#=
starts with the identity permutation [1, 2, 3, ..., n] and 
then shuffles it using engine-generated indices. 
Because the engine is deterministic, 
the same seed and same engine state produce 
the same permutation every time.
=#
function make_permutation(st::AbstractEngine, n::Int)::Vector{Int}
	n < 0 && error("n must be positive")
	perm = collect(1:n)

	for i in n:-1:2
		j = next_index!(st, i)
		perm[i], perm[j] = perm[j], perm[i]
	end

	return perm
end


#=
computes the reverse mapping. 
If perm[i] = k, then inv[k] = i, 
so applying inv after perm restores the original order.
=#
function invert_permutation(perm::Vector{Int})::Vector{Int}
	n = length(perm)
	inv = Vector{Int}(undef,n)

	for i in 1:n
		inv[perm[i]] = i
	end

	return inv
end

#=
returns the bytes in shuffled order
=#
function apply_permutation(data::Vector{UInt8}, perm::Vector{Int})::Vector{UInt8}
	length(data) == length(perm) || error("Data and permutation length mismatch")
	return data[perm]
end

#=
reconstructs the original order using the inverse mapping
=#
function apply_inverse_permutation(data::Vector{UInt8}, perm::Vector{Int})::Vector{UInt8}
	length(data) == length(perm) || error("Data and permutation length mismatch")
	inv = invert_permutation(perm)
	return data[inv]
end

end 

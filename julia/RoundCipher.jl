#=
RoundCipher.jl
to encrypt/decrypt one chunk
=#

module RoundCipher

import ..Engines: init_engine
import ..Permutation: make_permutation, apply_permutation, apply_inverse_permutation
import ..Substitution: make_sbox, invert_sbox, substitute, unsubstitute
import ..Diffusion: diffuse, undiffuse

export encrypt_round, decrypt_round, encrypt_chunk, decrypt_chunk

function derive_round_seed(seed::Vector{UInt8}, round::Int)::Vector{UInt8}
	n = length(seed)
	n == 0 && error("Seed cannot be empty!")

	out = copy(seed)
	r1 = UInt8(mod(round,256))
	r2 = UInt8(mod(73 * round + 19, 256))

	for i in eachindex(out)
		out[i] = out[i] ⊻ UInt8(mod(i+round,256)) ⊻ r1 ⊻ r2
	end

	return out
end

function encrypt_round(data::Vector{UInt8}, seed::Vector{UInt8})::Vector{UInt8}
	st_perm = init_engine(:A, seed)
	st_sub = init_engine(:C,seed)
	st_diff = init_engine(:B,seed)

	perm = make_permutation(st_perm, length(data))
	stage1 = apply_permutation(data, perm)

	sbox = make_sbox(st_sub)
	stage2 = substitute(stage1,sbox)

	stage3 = diffuse(stage2,st_diff)

	return stage3
end

function decrypt_round(data::Vector{UInt8}, seed::Vector{UInt8})::Vector{UInt8}
	st_perm = init_engine(:A, seed)
	st_sub = init_engine(:C,seed)
	st_diff = init_engine(:B,seed)

	stage1 = undiffuse(data,st_diff)

	sbox = make_sbox(st_sub)
	invsbox = invert_sbox(sbox)
	stage2 = unsubstitute(stage1, invsbox)

	perm = make_permutation(st_perm, length(data))
	stage3 = apply_inverse_permutation(stage2, perm)

	return stage3
end

function encrypt_chunk(data::Vector{UInt8},seed::Vector{UInt8}; rounds::Int=1)::Vector{UInt8}
	rounds <= 0 && error("rounds must be positive")

	out = copy(data)
	for r in 1:rounds
		rseed = derive_round_seed(seed,r)
		out = encrypt_round(out,rseed)
	end
	
	return out
end

function decrypt_chunk(data::Vector{UInt8},seed::Vector{UInt8}; rounds::Int=1)::Vector{UInt8}
	rounds <= 0 && error("rounds must be positive")

	out = copy(data)
	for r in rounds:-1:1
		rseed = derive_round_seed(seed,r)
		out = decrypt_round(out,rseed)
	end

	return out
end

end

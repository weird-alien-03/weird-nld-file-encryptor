#=
FileCipher.jl
Its only job is whole-byte-array encryption 
and decryption on top of the already tested round cipher

RoundCipher.jl works on one chunk, while FileCipher.jl 
lifts that logic to an entire byte vector 
by processing chunk-by-chunk. 
The chunking logic is just 
array slicing plus reconstruction.
=#

module FileCipher

import ..RoundCipher: encrypt_chunk, decrypt_chunk

export encrypt_bytes, decrypt_bytes, chunk_ranges

function chunk_ranges(n::Int, chunk_size::Int)::Vector{UnitRange{Int}}
	n < 0 && error("n must not be negative")
	chunk_size <= 0 && error("chunk_size must be positive")

	range = UnitRange{}[]
	i = 1
	while i <= n
		j = min(i + chunk_size -1, n)
		push!(range, i:j)
		i = j+1
	end
	return range
end

function encrypt_bytes(data::Vector{UInt8},seed::Vector{UInt8}; chunk_size::Int=4096, rounds::Int=1)::Vector{UInt8}
	chunk_size <= 0 && error("chunk_size must be positive")
	rounds <= 0 && error("rounds must be positive")

	out = Vector{UInt8}(undef,length(data))

	for r in chunk_ranges(length(data),chunk_size)
		chunk = data[r]
		enc = encrypt_chunk(chunk,seed;rounds=rounds)
		out[r] = enc
	end

	return out
end

function decrypt_bytes(data::Vector{UInt8},seed::Vector{UInt8}; chunk_size::Int=4096, rounds::Int=1)::Vector{UInt8}
	chunk_size <= 0 && error("chunk_size must be positive")
	rounds <= 0 && error("rounds must be positive")

	out = Vector{UInt8}(undef,length(data))
	
	for r in chunk_ranges(length(data),chunk_size)
		chunk = data[r]
		dec = decrypt_chunk(chunk,seed;rounds=rounds)
		out[r] = dec
	end

	return out	
end

end

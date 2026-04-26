# FileCipher — Chaos-Based File Encryption

A symmetric file encryption system with a Python CLI frontend and a Julia cryptographic core. The cipher derives its randomness from three independent nonlinear dynamical systems (chaos maps), which drive a round-based permutation–substitution–diffusion pipeline.

---

## Table of Contents

- [Requirements](#requirements)
- [Project Structure](#project-structure)
- [Installation](#installation)
- [Usage](#usage)
  - [Encrypting a File](#encrypting-a-file)
  - [Decrypting a File](#decrypting-a-file)
  - [CLI Reference](#cli-reference)
- [Output Files](#output-files)
- [How It Works](#how-it-works)
  - [1. Key Derivation](#1-key-derivation)
  - [2. Julia Bridge](#2-julia-bridge)
  - [3. Chunking](#3-chunking)
  - [4. Round Structure](#4-round-structure)
  - [5. Chaotic Engines](#5-chaotic-engines)
  - [6. Permutation Layer](#6-permutation-layer)
  - [7. Substitution Layer (S-box)](#7-substitution-layer-s-box)
  - [8. Diffusion Layer](#8-diffusion-layer)
- [References](#references)

---

## Requirements

- Python 3.10+
- Julia 1.9+
- [`juliacall`](https://github.com/JuliaPy/PythonCall.jl) Python package

Install Python dependencies:

```bash
pip install juliacall
```

No Julia package installation is needed — all Julia modules are loaded at runtime via `include()`.

---

## Project Structure

```
project-root/
├── python/
│   ├── encrypt_file.py     # CLI entry point for encryption
│   ├── decrypt_file.py     # CLI entry point for decryption
│   ├── seedgen.py          # Password-based seed derivation (PBKDF2)
│   └── julia_bridge.py     # Python ↔ Julia interop layer
│
└── julia/
    ├── Engines.jl          # Three chaotic dynamical system engines
    ├── Permutation.jl      # Byte-position permutation layer
    ├── Substitution.jl     # S-box substitution layer
    ├── Diffusion.jl        # XOR-chain diffusion layer
    ├── RoundCipher.jl      # Combines layers into a full cipher round
    └── FileCipher.jl       # Top-level chunk-based file cipher
```

---

## Installation

Clone or copy the repository. No build step is required. The Julia modules are loaded dynamically when the Python scripts first run.

The first run may take a few seconds while Julia JIT-compiles the modules.

---

## Usage

All commands are run from the `python/` directory (or wherever `encrypt_file.py` and `decrypt_file.py` live).

### Encrypting a File

```bash
python encrypt_file.py <input_file> [options]
```

Basic example — will prompt for a password securely:

```bash
python encrypt_file.py secret.pdf
```

This produces two files:
- `secret.pdf.enc` — the encrypted ciphertext
- `secret.pdf.enc.meta.json` — metadata needed for decryption

With all options specified:

```bash
python encrypt_file.py secret.pdf -o output.enc -cs 8192 -r 5 -p "my password"
```

---

### Decrypting a File

```bash
python decrypt_file.py <encrypted_file> [options]
```

Basic example — will prompt for a password securely:

```bash
python decrypt_file.py secret.pdf.enc
```

The decrypted file is written back to the original filename found in the metadata. To specify a custom output path:

```bash
python decrypt_file.py secret.pdf.enc -o recovered.pdf
```

With a custom metadata path:

```bash
python decrypt_file.py secret.pdf.enc --meta my_meta.json
```

> **Important:** The metadata file must match the encrypted file exactly. The chunk size, number of rounds, and salt are all read from the metadata — decryption will fail or produce garbage if these do not match.

---

### CLI Reference

#### `encrypt_file.py`

| Argument | Short | Default | Description |
|---|---|---|---|
| `input` | — | *(required)* | Path to the plaintext input file |
| `--output` | `-o` | `<input>.enc` | Path for the encrypted output file |
| `--chunk-size` | `-cs` | `4096` | Bytes per chunk processed at a time |
| `--rounds` | `-r` | `3` | Number of cipher rounds per chunk |
| `--password` | `-p` | *(prompt)* | Encryption password; omit to prompt securely |

#### `decrypt_file.py`

| Argument | Short | Default | Description |
|---|---|---|---|
| `input` | — | *(required)* | Path to the encrypted `.enc` file |
| `--meta` | — | `<input>.meta.json` | Path to the metadata JSON file |
| `--output` | `-o` | *(from metadata)* | Path for the decrypted output file |
| `--password` | — | *(prompt)* | Decryption password; omit to prompt securely |

---

## Output Files

### Ciphertext file (`.enc`)

A raw binary file of the same size as the original. No header or magic bytes are prepended — the ciphertext is purely the encrypted byte array.

### Metadata file (`.meta.json`)

A JSON file saved alongside the ciphertext. It contains everything needed for decryption except the password:

```json
{
  "version": 1,
  "original_name": "secret.pdf",
  "original_suffix": ".pdf",
  "original_size": 204800,
  "chunk_size": 4096,
  "rounds": 3,
  "salt_hex": "a3f1c2..."
}
```

> **Keep the metadata file.** Without it, decryption is not possible. The salt stored here is what makes the derived seed unique to this encryption, even if the same password is reused.

---

## How It Works

### 1. Key Derivation

The password is never used directly. Instead, `seedgen.py` derives a 64-byte seed using **PBKDF2-HMAC-SHA256** with a randomly generated 16-byte salt and 200,000 iterations. This means:

- Brute-forcing the password requires 200,000 hash computations per attempt.
- The same password with a different salt produces a completely different seed, so reusing a password across files is safe.

```
password + random salt → PBKDF2-HMAC-SHA256 (200,000 iter) → 64-byte seed
```

### 2. Julia Bridge

`julia_bridge.py` loads all Julia source files at runtime using `juliacall` and exposes two Python-callable functions: `encrypt_bytes` and `decrypt_bytes`. The Julia modules are only loaded once per Python process (guarded by a `_LOADED` flag). All byte arrays are converted between Python `bytes` and Julia `Vector{UInt8}` at the bridge boundary.

### 3. Chunking

`FileCipher.jl` splits the input byte array into non-overlapping chunks of `chunk_size` bytes (default: 4096). Each chunk is encrypted or decrypted independently by `RoundCipher.jl`. The final chunk may be smaller than `chunk_size` if the file size is not an exact multiple. After decryption, the output is trimmed back to the original file size (stored in the metadata) to discard any padding.

### 4. Round Structure

Each chunk passes through `rounds` full cipher rounds (default: 3). Every round is identical in structure but uses a **different round seed**, derived by XORing the master seed with a round-dependent pattern:

```
round_seed[i] = seed[i] XOR (i + round) mod 256 XOR r1 XOR r2
```

where `r1 = round mod 256` and `r2 = (73 × round + 19) mod 256`.

This ensures that rounds do not cancel each other out. Decryption applies rounds in reverse order (from `rounds` down to `1`) using the same round seeds.

**One round performs, in order:**

```
plaintext chunk
    → Permutation   (scramble byte positions)
    → Substitution  (remap byte values via S-box)
    → Diffusion     (XOR-chain with mask stream)
    → ciphertext chunk
```

### 5. Chaotic Engines

The cipher uses three independent nonlinear dynamical systems as pseudorandom generators. Each engine is seeded from the round seed and warmed up for 32 steps before use. After warmup, each call to `next_u32!` advances the engine by one step and returns a 32-bit word derived by reinterpreting the floating-point state bits and mixing with Splitmix64.

---

#### Engine A — 3D Exponential Hyperchaotic Map (EHC Map)

Used by: **Permutation layer**

Update equations:

$$x_{n+1} = \left(2^{\pi + x_n}(r - y_n^2 + z_n)\right) \mod 1$$

$$y_{n+1} = \left(7^{\pi + y_n}(r - z_n^2 + x_n)\right) \mod 1$$

$$z_{n+1} = \left(11^{\pi + z_n}(r - x_n^2 + y_n)\right) \mod 1$$

State space: 
$x, y, z \in (0, 1)$, parameter $r \in [0, 3 \times 10^7]$
derived from seed.

> **Reference:** https://doi.org/10.1142/S021812742250095X

---

#### Engine B — 3D Infinite Collapse Map (IC Map)

Used by: **Diffusion layer**

Update equations:

$$x_{n+1} = \sin\!\left(\frac{a}{x_n}\right)\sin\!\left(\frac{b}{y_n}\right)\sin\!\left(\frac{c}{z_n}\right)$$

$$y_{n+1} = \sin\!\left(\frac{c}{z_n}\right)\sin\!\left(\frac{b}{y_n}\right)$$

$$z_{n+1} = \sin\!\left(\frac{c}{y_n}\right)\sin\!\left(\frac{b}{z_n}\right)$$

State space: 
$x, y, z \in [-1, 1]$, parameters $a, b, c \in [-10, 10] \setminus \{0\}$
derived from seed. Division by near-zero is guarded with 
$\varepsilon = 10^{-12}$.

> **Reference:** https://doi.org/10.3390/e23091221

---

#### Engine C — 3D Sine-Cosine Coupled Map (SCC Map)

Used by: **Substitution layer (S-box construction)**

Let $g(u, d_1, d_2) = u^2 / (d_1 d_2 + \varepsilon)$. Update equations:

$$x_{n+1} = \sin\!\left(\left(ax_n + g(y_n, z_n, x_n)\right)^h\right)$$

$$y_{n+1} = \cos\!\left(\left(by_n + g(z_n, x_n, y_n)\right)^h\right)$$

$$z_{n+1} = \cos\!\left(\left(cz_n + g(x_n, y_n, z_n)\right)^h\right)$$

State space: 
$x, y, z \in [-1, 1]$, parameters $a, b, c \in [0, 10^7]$
integer exponent 
$h \in [1, 10]$ 
all derived from seed.

> **Reference:** https://doi.org/10.3390/math10152583

---

### 6. Permutation Layer

`Permutation.jl` uses Engine A to build a **deterministic Fisher–Yates shuffle** of positions $1 \ldots n$ (where $n$ is the chunk size). The shuffle starts with the identity array $[1, 2, \ldots, n]$ and, for each position $i$ from $n$ down to $2$, swaps position $i$ with a randomly chosen position $j \leq i$ drawn from Engine A.

This produces a bijection on byte positions: every byte is moved to a new location, no two bytes swap to the same destination, and the inverse permutation is computable by reversing the index mapping. The same seed always produces the same permutation, so decryption can reconstruct and invert it exactly.

### 7. Substitution Layer (S-box)

`Substitution.jl` uses Engine C to build a **256-entry substitution table** — a bijection on the byte alphabet $\{0, \ldots, 255\}$. Construction begins with the identity array $[0, 1, \ldots, 255]$ and applies the same Fisher–Yates shuffle using Engine C indices.

During encryption, each byte value `b` is replaced by `sbox[b]`. For decryption, the inverse S-box is computed by reversing the mapping: if `sbox[i] = v`, then `inv_sbox[v] = i`. This layer changes byte *values* without changing their positions (complementary to permutation, which changes positions without changing values).

### 8. Diffusion Layer

`Diffusion.jl` uses Engine B to generate a **per-byte mask stream** of length $n$. The mask is then applied with XOR chaining using a fixed initialisation vector (`IV = 0xa5`):

$$\text{out}[i] = \text{data}[i] \oplus \text{mask}[i] \oplus \text{prev}$$

where `prev` is updated to `out[i]` after each step (initialised to `IV`). This means each output byte depends not only on its own plaintext and mask byte, but on all previous output bytes in the chunk — a change to any single byte propagates forward through the rest of the chunk.

Decryption uses the same mask stream but updates `prev` from the *ciphertext* byte (not the recovered plaintext byte), which is mathematically equivalent and correctly reverses the chaining.

---

## References

The nonlinear dynamical systems used as pseudorandom generators in this cipher are based on published chaos maps. The relevant papers are cited below.

- **EHC Map (Engine A):** Constructing a 3D Exponential Hyperchaotic Map with Application to PRNG. Yuanyuan Si, Hongjun Liu and Yuehui Chen. International Journal of Bifurcation and Chaos, Vol. 32, No. 07, 2250095 (2022).

https://doi.org/10.1142/S021812742250095X

- **IC Map (Engine B):** Yan, W.; Jiang, Z.; Huang,
X.; Ding, Q. A Three-Dimensional Infinite Collapse Map with Image Encryption. Entropy 2021, 23, 1221.

https://doi.org/10.3390/e23091221

- **SCC Map (Engine C):** Zhong, H.; Li, G.; Xu, X.;
Song, X. Image Encryption Algorithm Based on a Novel Wide-Range Discrete Hyperchaotic Map. Mathematics 2022, 10, 2583. 

https://doi.org/10.3390/math10152583

The key derivation scheme uses PBKDF2-HMAC-SHA256 as specified in [RFC 8018](https://www.rfc-editor.org/rfc/rfc8018).

The Splitmix64 bit-mixing function used in `state_to_u32` is described in:
> Steele, G., Lea, D., & Flood, C. (2014). Fast splittable pseudorandom number generators. *ACM SIGPLAN Notices*, 49(10), 453–472. https://doi.org/10.1145/2714064.2660195

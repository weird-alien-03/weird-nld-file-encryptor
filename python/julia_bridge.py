#julia_bridge.py

from __future__ import annotations

from pathlib import Path
from juliacall import Main as jl

ROOT = Path(__file__).resolve().parents[1]
JULIA_DIR = ROOT / "julia"

_LOADED = False

def _julia_path(name: str) -> str:
    return str((JULIA_DIR / name).resolve()).replace("\\", "\\\\")

def load_julia() -> None:
    global _LOADED
    if _LOADED:
        return

    for name in [
        "Engines.jl",
        "Permutation.jl",
        "Diffusion.jl",
        "Substitution.jl",
        "RoundCipher.jl",
        "FileCipher.jl",
    ]:
        jl.seval(f'include("{_julia_path(name)}")')

    jl.seval("""
    import .Engines
    import .Permutation
    import .Diffusion
    import .Substitution
    import .RoundCipher
    import .FileCipher

    function encrypt_bytes_py(data,seed,chunk_size::Int,rounds::Int)
        return FileCipher.encrypt_bytes(UInt8.(data), UInt8.(seed); chunk_size=chunk_size, rounds=rounds)
    end

    function decrypt_bytes_py(data,seed,chunk_size::Int,rounds::Int)
        return FileCipher.decrypt_bytes(UInt8.(data), UInt8.(seed); chunk_size=chunk_size, rounds=rounds)
    end    
    """)

    _LOADED = True

def _to_pybytes(julia_vec) -> bytes:
    return bytes(int(x) for x in julia_vec)

def encrypt_bytes(data: bytes, seed:bytes, *, chunk_size:int = 4096, rounds:int =3) -> bytes:
    load_julia()
    out = jl.encrypt_bytes_py(list(data),list(seed),int(chunk_size),int(rounds))
    return _to_pybytes(out)

def decrypt_bytes(data: bytes, seed:bytes, *, chunk_size:int = 4096, rounds:int =3) -> bytes:
    load_julia()
    out = jl.decrypt_bytes_py(list(data),list(seed),int(chunk_size),int(rounds))
    return _to_pybytes(out)

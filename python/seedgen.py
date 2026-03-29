#seedgen.py

from __future__ import annotations

import hashlib as hl
import secrets as sc

SALT_LEN = 16
PBKDF2_ITERS = 200_000
SEED_LEN = 64

def make_salt(n: int = SALT_LEN) -> bytes:
    return sc.token_bytes(n)

def derive_seed(password: str, salt: bytes, seed_len: int = SEED_LEN) -> bytes:
    return hl.pbkdf2_hmac(
        "sha256",
        password.encode("utf-8"),
        salt,
        PBKDF2_ITERS,
        dklen=seed_len, 
    )

'''
encrypt_file.py
this script will parse input/output options, 
derive the seed, call the Julia bridge, 
write the encrypted file, and save the metadata as JSON
'''

from __future__ import annotations

import argparse as ap
import getpass as gp
import json
from pathlib import Path

from julia_bridge import encrypt_bytes
from seedgen import make_salt, derive_seed

def main() -> None:
    parser = ap.ArgumentParser(description="Encrypt a file with julia cipher engine.")
    parser.add_argument("input",help="Path to input file")
    parser.add_argument("-o","--output",help="Path to encrypted output")
    parser.add_argument("-cs","--chunk-size",type=int,default=4096)
    parser.add_argument("-r","--rounds",type=int,default=3)
    parser.add_argument("-p","--password",help="Password; if omitted, prompt securely")
    args = parser.parse_args()

    in_path = Path(args.input)
    out_path = Path(args.output) if args.output else in_path.with_suffix(in_path.suffix + ".enc")
    meta_path = out_path.with_suffix(out_path.suffix + ".meta.json")

    password = args.password or gp.getpass("Password: ")
    plain = in_path.read_bytes()

    salt = make_salt()
    seed = derive_seed(password, salt)

    cipher = encrypt_bytes(plain,seed,chunk_size=args.chunk_size, rounds=args.rounds)
    out_path.write_bytes(cipher)

    meta = {
        "version": 1,
        "original_name": in_path.name,
        "original_suffix": in_path.suffix,
        "original_size": len(plain),
        "chunk_size": args.chunk_size,
        "rounds":args.rounds,
        "salt_hex":salt.hex()
    }
    meta_path.write_text(json.dumps(meta,indent=2),encoding="utf-8")

    print(f"Encrypted file: {out_path}")
    print(f"Metadata file: {meta_path}")

if __name__ == "__main__":
    main()

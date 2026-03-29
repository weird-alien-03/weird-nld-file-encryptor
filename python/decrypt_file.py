'''
decrypt_file.py
This script would read the encrypted file and 
the saved metadata, derive the same seed 
from the password plus stored salt, 
call the Julia decryptor, 
and write the recovered file back out. 
'''

from __future__ import annotations

import argparse as ap
import getpass as gp
import json
from pathlib import Path

from julia_bridge import decrypt_bytes
from seedgen import derive_seed

def main() -> None:
    parser = ap.ArgumentParser(description="Decrypt a file produced by encrypt_file.py")
    parser.add_argument("input",help="Path to encrypted file")
    parser.add_argument("--meta",help="Path to metadata JSON; defaults to <input>.meta.json")
    parser.add_argument("-o","--output",help="Path to decrypted file")
    parser.add_argument("--password",help="Password; if omitted, prompt securely")
    args = parser.parse_args()

    in_path = Path(args.input)
    meta_path = Path(args.meta) if args.meta else in_path.with_suffix(in_path.suffix + ".meta.json")

    meta = json.loads(meta_path.read_text(encoding="utf-8"))
    password = args.password or gp.getpass("Password: ")

    salt = bytes.fromhex(meta["salt_hex"])
    seed = derive_seed(password, salt)

    cipher = in_path.read_bytes()

    plain = decrypt_bytes(
        cipher,
        seed,
        chunk_size=int(meta["chunk_size"]),
        rounds=int(meta["rounds"])
    )

    default_name = meta.get("original_name",in_path.stem+".dec")
    out_path = Path(args.output) if args.output else in_path.with_name(default_name)

    plain = plain[:int(meta["original_size"])]
    out_path.write_bytes(plain)
    
    print(f"Decrypted file: {out_path}")
    
if __name__ == "__main__":
    main()

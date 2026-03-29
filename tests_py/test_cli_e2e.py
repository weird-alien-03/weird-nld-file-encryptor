import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PYTHON_DIR = ROOT / "python"


class TestCliEndToEnd(unittest.TestCase):
    def run_cmd(self, args):
        return subprocess.run(
            [sys.executable, *args],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=True,
        )

    def test_text_file_roundtrip(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            src = tmp / "sample.txt"
            src.write_bytes(b"hello from weird encryptor\n" * 20)

            enc = tmp / "sample.txt.enc"

            self.run_cmd([
                str(PYTHON_DIR / "encrypt_file.py"),
                str(src),
                "-o", str(enc),
                "--password", "test-pass",
                "--chunk-size", "32",
                "--rounds", "3",
            ])

            meta = enc.with_suffix(enc.suffix + ".meta.json")
            self.assertTrue(enc.exists())
            self.assertTrue(meta.exists())

            self.run_cmd([
                str(PYTHON_DIR / "decrypt_file.py"),
                str(enc),
                "--meta", str(meta),
                "--password", "test-pass",
            ])

            dec = tmp / "sample.txt"
            self.assertTrue(dec.exists())
            self.assertEqual(dec.read_bytes(), src.read_bytes())

    def test_binary_roundtrip(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            src = tmp / "blob.bin"
            src.write_bytes(bytes(range(256)) * 8 + b"\x00\xff\x89PNG\r\n\x1a\n")

            enc = tmp / "blob.bin.enc"

            self.run_cmd([
                str(PYTHON_DIR / "encrypt_file.py"),
                str(src),
                "-o", str(enc),
                "--password", "bin-pass",
                "--chunk-size", "50",
                "--rounds", "2",
            ])

            meta = enc.with_suffix(enc.suffix + ".meta.json")

            out = tmp / "restored_blob.bin"
            self.run_cmd([
                str(PYTHON_DIR / "decrypt_file.py"),
                str(enc),
                "--meta", str(meta),
                "--password", "bin-pass",
                "-o", str(out),
            ])

            self.assertEqual(out.read_bytes(), src.read_bytes())

    def test_metadata_written(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            src = tmp / "m.dat"
            src.write_bytes(b"metadata-check")

            enc = tmp / "m.dat.enc"

            self.run_cmd([
                str(PYTHON_DIR / "encrypt_file.py"),
                str(src),
                "-o", str(enc),
                "--password", "meta-pass",
            ])

            meta_path = enc.with_suffix(enc.suffix + ".meta.json")
            meta = json.loads(meta_path.read_text(encoding="utf-8"))

            self.assertEqual(meta["version"], 1)
            self.assertEqual(meta["original_name"], "m.dat")
            self.assertEqual(meta["original_size"], len(b"metadata-check"))
            self.assertIn("salt_hex", meta)
            self.assertIn("chunk_size", meta)
            self.assertIn("rounds", meta)

    def test_wrong_password_does_not_restore_original(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            src = tmp / "wrongpass.bin"
            original = bytes(range(100)) * 3
            src.write_bytes(original)

            enc = tmp / "wrongpass.bin.enc"

            self.run_cmd([
                str(PYTHON_DIR / "encrypt_file.py"),
                str(src),
                "-o", str(enc),
                "--password", "right-pass",
                "--rounds", "2",
            ])

            meta = enc.with_suffix(enc.suffix + ".meta.json")
            out = tmp / "wrong_out.bin"

            self.run_cmd([
                str(PYTHON_DIR / "decrypt_file.py"),
                str(enc),
                "--meta", str(meta),
                "--password", "wrong-pass",
                "-o", str(out),
            ])

            self.assertNotEqual(out.read_bytes(), original)


if __name__ == "__main__":
    unittest.main()

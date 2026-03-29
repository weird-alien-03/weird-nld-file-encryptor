import tempfile
import unittest
from pathlib import Path

from python.julia_bridge import encrypt_bytes, decrypt_bytes
from python.seedgen import derive_seed


class TestPngLikeBinary(unittest.TestCase):
    def test_png_like_bytes_roundtrip(self):
        seed = derive_seed("png-test", b"\x09" * 16)

        png_like = (
            b"\x89PNG\r\n\x1a\n" +
            b"\x00\x00\x00\rIHDR" +
            bytes(range(64)) +
            b"\x00\x00\x00\x00IEND\xaeB`\x82"
        )

        enc = encrypt_bytes(png_like, seed, chunk_size=17, rounds=3)
        dec = decrypt_bytes(enc, seed, chunk_size=17, rounds=3)

        self.assertEqual(dec, png_like)
        self.assertNotEqual(enc, png_like)

    def test_real_small_png_if_available(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            p = Path(tmpdir) / "tiny.png"
            p.write_bytes(
                b"\x89PNG\r\n\x1a\n"
                b"\x00\x00\x00\rIHDR"
                b"\x00\x00\x00\x01\x00\x00\x00\x01\x08\x02\x00\x00\x00"
                b"\x90wS\xde"
                b"\x00\x00\x00\x0cIDAT\x08\xd7c\xf8\xff\xff?\x00\x05\xfe\x02\xfeA\x0c\x1b\xd1"
                b"\x00\x00\x00\x00IEND\xaeB`\x82"
            )

            raw = p.read_bytes()
            seed = derive_seed("real-png", b"\x07" * 16)

            enc = encrypt_bytes(raw, seed, chunk_size=19, rounds=2)
            dec = decrypt_bytes(enc, seed, chunk_size=19, rounds=2)

            self.assertEqual(dec, raw)


if __name__ == "__main__":
    unittest.main()

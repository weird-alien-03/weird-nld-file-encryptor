import unittest

from python.julia_bridge import encrypt_bytes, decrypt_bytes
from python.seedgen import derive_seed


class TestJuliaBridge(unittest.TestCase):
    def setUp(self):
        self.password = "bridge-test-password"
        self.salt = bytes(range(16))
        self.seed = derive_seed(self.password, self.salt)
        self.data = bytes(range(256)) + b"hello-world" + bytes(range(255, -1, -1))

    def test_encrypt_decrypt_roundtrip(self):
        enc = encrypt_bytes(self.data, self.seed, chunk_size=64, rounds=3)
        dec = decrypt_bytes(enc, self.seed, chunk_size=64, rounds=3)

        self.assertNotEqual(enc, self.data)
        self.assertEqual(dec, self.data)

    def test_deterministic_same_seed(self):
        enc1 = encrypt_bytes(self.data, self.seed, chunk_size=64, rounds=3)
        enc2 = encrypt_bytes(self.data, self.seed, chunk_size=64, rounds=3)
        self.assertEqual(enc1, enc2)

    def test_wrong_seed_fails_to_recover(self):
        wrong_seed = derive_seed("wrong-password", self.salt)
        enc = encrypt_bytes(self.data, self.seed, chunk_size=64, rounds=3)
        dec_wrong = decrypt_bytes(enc, wrong_seed, chunk_size=64, rounds=3)

        self.assertNotEqual(dec_wrong, self.data)

    def test_empty_bytes(self):
        data = b""
        enc = encrypt_bytes(data, self.seed, chunk_size=64, rounds=2)
        dec = decrypt_bytes(enc, self.seed, chunk_size=64, rounds=2)
        self.assertEqual(dec, data)

    def test_uneven_chunk_size(self):
        data = b"A" * 137
        enc = encrypt_bytes(data, self.seed, chunk_size=13, rounds=2)
        dec = decrypt_bytes(enc, self.seed, chunk_size=13, rounds=2)
        self.assertEqual(dec, data)


if __name__ == "__main__":
    unittest.main()

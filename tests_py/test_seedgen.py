import unittest

from python.seedgen import make_salt, derive_seed, SALT_LEN, SEED_LEN


class TestSeedgen(unittest.TestCase):
    def test_make_salt_length(self):
        salt = make_salt()
        self.assertEqual(len(salt), SALT_LEN)

    def test_make_salt_random(self):
        s1 = make_salt()
        s2 = make_salt()
        self.assertNotEqual(s1, s2)

    def test_derive_seed_deterministic(self):
        password = "correct horse battery staple"
        salt = b"\x01" * SALT_LEN

        a = derive_seed(password, salt)
        b = derive_seed(password, salt)

        self.assertEqual(a, b)
        self.assertEqual(len(a), SEED_LEN)

    def test_derive_seed_changes_with_password(self):
        salt = b"\x02" * SALT_LEN
        a = derive_seed("pass1", salt)
        b = derive_seed("pass2", salt)
        self.assertNotEqual(a, b)

    def test_derive_seed_changes_with_salt(self):
        password = "same-password"
        a = derive_seed(password, b"\x03" * SALT_LEN)
        b = derive_seed(password, b"\x04" * SALT_LEN)
        self.assertNotEqual(a, b)


if __name__ == "__main__":
    unittest.main()

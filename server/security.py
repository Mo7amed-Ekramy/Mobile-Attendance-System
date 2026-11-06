"""Password and opaque session token helpers; no database credentials in clients."""
import hashlib
import hmac
import secrets


def hash_password(password: str) -> str:
    salt = secrets.token_hex(16)
    value = hashlib.scrypt(password.encode('utf-8'), salt=bytes.fromhex(salt), n=16384, r=8, p=1, dklen=32)
    return f'scrypt$16384$8$1${salt}${value.hex()}'


def verify_password(password: str, encoded: str | None) -> bool:
    if not encoded or not password:
        return False
    try:
        method, n, r, p, salt, expected = encoded.split('$')
        if method != 'scrypt':
            return False
        actual = hashlib.scrypt(password.encode('utf-8'), salt=bytes.fromhex(salt), n=int(n), r=int(r), p=int(p), dklen=32)
        return hmac.compare_digest(actual.hex(), expected)
    except (ValueError, TypeError):
        return False


def token_hash(token: str) -> str:
    return hashlib.sha256(token.encode('utf-8')).hexdigest()

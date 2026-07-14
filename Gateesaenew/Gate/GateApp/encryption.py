import base64
import hashlib
from cryptography.fernet import Fernet, InvalidToken
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
from cryptography.hazmat.primitives import hashes
from django.conf import settings

# QR tokens are valid for this many seconds (2 hours)
QR_TOKEN_TTL = 7200

def get_fernet():
    """Derive a strong Fernet key from Django's SECRET_KEY using PBKDF2."""
    kdf = PBKDF2HMAC(
        algorithm=hashes.SHA256(),
        length=32,
        # Static app-level salt — changing this invalidates all existing tokens
        salt=b'gateease-qr-v1-salt',
        iterations=100_000,
    )
    key = base64.urlsafe_b64encode(kdf.derive(settings.SECRET_KEY.encode()))
    return Fernet(key)

def encrypt_pass_id(pass_id):
    """Encrypt a pass_id into a Fernet token. Includes a timestamp for TTL."""
    f = get_fernet()
    token = f.encrypt(f"pass_id:{pass_id}".encode())
    return token.decode()

def decrypt_pass_id(token, ttl=QR_TOKEN_TTL):
    """
    Decrypt a Fernet token back to a pass_id.
    Returns None if token is invalid, tampered, or expired.
    ttl: max age in seconds. Pass ttl=None to skip expiry check (not recommended).
    """
    f = get_fernet()
    try:
        decrypted = f.decrypt(token.encode(), ttl=ttl).decode()
        if decrypted.startswith("pass_id:"):
            return int(decrypted.split(":")[1])
        return None
    except InvalidToken:
        # Token is expired, tampered, or forged
        return None
    except Exception:
        return None

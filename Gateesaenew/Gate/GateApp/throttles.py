"""
Custom DRF throttle classes for GateEase API rate limiting.

Throttle scopes and their limits are configured in settings.py
under REST_FRAMEWORK['DEFAULT_THROTTLE_RATES'].
"""

from rest_framework.throttling import AnonRateThrottle, SimpleRateThrottle


class LoginRateThrottle(AnonRateThrottle):
    """
    Strict throttle for the login endpoint.
    Prevents brute-force password attacks.
    Limit: 15 requests/minute per IP.
    """
    scope = 'login'


class SignupRateThrottle(AnonRateThrottle):
    """
    Throttle for the student registration endpoint.
    Prevents spam account creation.
    Limit: 15 requests/minute per IP.
    """
    scope = 'signup'


class PasswordResetThrottle(AnonRateThrottle):
    """
    Throttle for forgot-password and reset-password endpoints.
    Prevents OTP spamming / email flooding.
    Limit: 15 requests/minute per IP.
    """
    scope = 'password_reset'


class AuthenticatedAPIThrottle(SimpleRateThrottle):
    """
    Throttle for all JWT-authenticated API endpoints.
    Uses login_id from the JWT token as the cache key so each
    user gets their own independent rate limit bucket.
    Limit: 100 requests/minute per user.
    """
    scope = 'authenticated_api'

    def get_cache_key(self, request, view):
        # Use the login_id embedded in the JWT token as the unique identifier.
        # This works with our custom Logintable model (not Django's built-in User).
        if request.auth:
            login_id = request.auth.get('login_id')
            if login_id:
                return self.cache_format % {
                    'scope': self.scope,
                    'ident': login_id,
                }
        # Fall back to IP-based throttling if token has no login_id
        return self.cache_format % {
            'scope': self.scope,
            'ident': self.get_ident(request),
        }

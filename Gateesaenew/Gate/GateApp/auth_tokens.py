from datetime import datetime, timedelta, timezone

from django.conf import settings
from rest_framework_simplejwt.exceptions import TokenError
from rest_framework_simplejwt.tokens import RefreshToken


REFRESH_COOKIE_MAX_AGE = 7 * 24 * 60 * 60
ACCESS_COOKIE_MAX_AGE = 15 * 60


def _copy_identity_claims(source, target):
    for claim in ('login_id', 'user_id', 'usertype', 'username'):
        if claim in source:
            target[claim] = source[claim]


def create_login_tokens(user):
    refresh = RefreshToken()
    _copy_identity_claims(
        {
            'login_id': user.id,
            'user_id': user.id,
            'usertype': user.usertype,
            'username': user.username,
        },
        refresh,
    )
    refresh['persistent_login_expires'] = int(
        (datetime.now(timezone.utc) + timedelta(seconds=REFRESH_COOKIE_MAX_AGE)).timestamp()
    )
    return refresh


def rotate_refresh_token(raw_token):
    try:
        old_refresh = RefreshToken(raw_token)
        old_refresh.check_blacklist()
        deadline = int(old_refresh.get('persistent_login_expires', old_refresh['exp']))
        now = int(datetime.now(timezone.utc).timestamp())
        if deadline <= now:
            raise TokenError('Refresh token lifetime has expired')

        new_refresh = RefreshToken()
        _copy_identity_claims(old_refresh, new_refresh)
        new_refresh['persistent_login_expires'] = deadline
        new_refresh['exp'] = deadline
        old_refresh.blacklist()
        return new_refresh
    except Exception as exc:
        if isinstance(exc, TokenError):
            raise
        raise TokenError('Invalid refresh token') from exc


def cookie_secure():
    return getattr(settings, 'JWT_COOKIE_SECURE', not settings.DEBUG)


def set_auth_cookies(response, access_token, refresh_token):
    secure = cookie_secure()
    response.set_cookie(
        'access_token',
        str(access_token),
        max_age=ACCESS_COOKIE_MAX_AGE,
        httponly=True,
        secure=secure,
        samesite='Lax',
    )
    response.set_cookie(
        'refresh_token',
        str(refresh_token),
        max_age=REFRESH_COOKIE_MAX_AGE,
        httponly=True,
        secure=secure,
        samesite='Lax',
    )


def delete_auth_cookies(response):
    response.delete_cookie('access_token', samesite='Lax')
    response.delete_cookie('refresh_token', samesite='Lax')
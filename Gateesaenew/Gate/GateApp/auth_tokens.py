from datetime import datetime, timedelta, timezone
from rest_framework_simplejwt.utils import datetime_from_epoch

from django.conf import settings
from django.db import transaction
from django.utils.crypto import constant_time_compare, salted_hmac
from rest_framework_simplejwt.token_blacklist.models import OutstandingToken

from .models import Logintable
from rest_framework_simplejwt.exceptions import TokenError
from rest_framework_simplejwt.tokens import RefreshToken


REFRESH_COOKIE_MAX_AGE = 7 * 24 * 60 * 60
ACCESS_COOKIE_MAX_AGE = 15 * 60


def _copy_identity_claims(source, target):
    for claim in ('login_id', 'user_id', 'usertype', 'username', 'credential_version'):
        if claim in source:
            target[claim] = source[claim]


ACTIVE_ROLES = {'Student', 'mentor', 'security', 'admin'}


def credential_version(user):
    # Preserve sessions issued before this change with staff enrollment disabled.
    legacy_suffix = '' if user.usertype == 'Student' else 'False:'
    value = f'{user.session_version}:{user.password or ""}:{legacy_suffix}'
    return salted_hmac('gateease.credentials', value, algorithm='sha256').hexdigest()


def active_token_user(token):
    user = Logintable.objects.filter(pk=token.get('login_id')).first()
    if (
        user is None
        or user.usertype not in ACTIVE_ROLES
        or user.usertype != token.get('usertype')
        or not constant_time_compare(credential_version(user), token.get('credential_version', ''))
    ):
        raise TokenError('Account session has expired')
    return user


class LoginRefreshToken(RefreshToken):
    @property
    def access_token(self):
        access = super().access_token
        access['exp'] = min(access['exp'], self['persistent_login_expires'])
        return access


def create_login_tokens(user):
    refresh = LoginRefreshToken()
    _copy_identity_claims(
        {
            'login_id': user.id,
            'user_id': user.id,
            'usertype': user.usertype,
            'username': user.username,
            'credential_version': credential_version(user),
        },
        refresh,
    )
    refresh['persistent_login_expires'] = int(
        (datetime.now(timezone.utc) + timedelta(seconds=REFRESH_COOKIE_MAX_AGE)).timestamp()
    )
    store_refresh_token(refresh)
    return refresh


def store_refresh_token(refresh):
    OutstandingToken.objects.create(
        jti=refresh['jti'],
        token=str(refresh),
        created_at=refresh.current_time,
        expires_at=datetime_from_epoch(refresh['exp']),
    )


def rotate_refresh_token(raw_token):
    with transaction.atomic():
        old_refresh = RefreshToken(raw_token)
        outstanding = OutstandingToken.objects.select_for_update().filter(
            jti=old_refresh['jti']
        ).first()
        if outstanding is None:
            raise TokenError('Unknown session')
        old_refresh.check_blacklist()
        active_token_user(old_refresh)
        deadline = int(old_refresh['persistent_login_expires'])
        if deadline <= int(datetime.now(timezone.utc).timestamp()):
            raise TokenError('Refresh token lifetime has expired')
        new_refresh = LoginRefreshToken()
        _copy_identity_claims(old_refresh, new_refresh)
        new_refresh['persistent_login_expires'] = deadline
        new_refresh['exp'] = deadline
        old_refresh.blacklist()
        store_refresh_token(new_refresh)
        return new_refresh


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
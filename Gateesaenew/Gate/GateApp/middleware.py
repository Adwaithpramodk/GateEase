import ipaddress
import logging
import posixpath
import re
from datetime import timedelta
from urllib.parse import unquote

from django.conf import settings
from django.db import IntegrityError, transaction
from django.utils.deprecation import MiddlewareMixin
from django.http import HttpResponse
from rest_framework_simplejwt.tokens import AccessToken
from django.utils import timezone
from django.utils.cache import add_never_cache_headers

from .auth_tokens import active_token_user, rotate_refresh_token, set_auth_cookies
from .models import RateLimitCounter

logger = logging.getLogger(__name__)

def client_ip(request):
    value = request.META.get('REMOTE_ADDR', '')
    if settings.TRUST_PROXY_CLIENT_IP:
        value = request.META.get('HTTP_X_REAL_IP') or value
    try:
        return str(ipaddress.ip_address(value))
    except ValueError:
        return 'unknown'


class JWTWebAuthMiddleware(MiddlewareMixin):
    def process_request(self, request):
        request.jwt_user_id = None
        request.jwt_usertype = None
        request._rotated_auth_tokens = None
        
        token = request.COOKIES.get('access_token')
        if token:
            try:
                access_token = AccessToken(token)
                active_token_user(access_token)
                request.jwt_user_id = access_token.get('login_id')
                request.jwt_usertype = access_token.get('usertype')
            except Exception as e:
                logger.debug(f"JWTWebAuthMiddleware invalid token: {e}")

        # Refresh only when the access token is absent/expired, never on every request.
        if not request.jwt_user_id and request.COOKIES.get('refresh_token') and request.path not in {
            '/auth/refresh/',
            '/api/token/refresh/',
            '/LoginpageAPI',
            '/Logout',
        }:
            try:
                refresh = rotate_refresh_token(request.COOKIES['refresh_token'])
                request.jwt_user_id = refresh.get('login_id')
                request.jwt_usertype = refresh.get('usertype')
                request._rotated_auth_tokens = (refresh.access_token, refresh)
            except Exception:
                # An expired refresh token must not leave an old session authenticated.
                request.session.flush()
        elif not request.jwt_user_id and request.session.get('user_id') and not request.COOKIES.get('refresh_token'):
            # Do not let a database session outlive the persistent authentication cookie.
            request.session.flush()

    def process_response(self, request, response):
        if not request.path.startswith('/static/') and request.path not in {'/sw.js', '/manifest.json'}:
            add_never_cache_headers(response)
        if request._rotated_auth_tokens:
            set_auth_cookies(response, *request._rotated_auth_tokens)
        return response

class RateLimitMiddleware(MiddlewareMixin):
    """
    Database-backed fixed-window limiter shared by all application workers.
    """
    RATE_LIMIT = 60
    WINDOW_SECONDS = 60
    SUSPICIOUS_PATH = re.compile(
        r'(^|/)(?:\.env(?:\.[^/]*)?|\.git(?:/|$)|'
        r'(?:firebase-adminsdk|service-account|credentials|database|backup)'
        r'\.json$|(?:database|backup)\.sql$|terraform\.tfstate$|'
        r'id_rsa(?:\.[^/]*)?$|private\.pem$|wp-config\.php$|'
        r'.*(?:\.sqlite3?|\.bak|\.backup|\.dump|\.db)$)',
        re.IGNORECASE,
    )

    def process_request(self, request):
        normalized_path = self.normalize_path(request.path)
        if self.SUSPICIOUS_PATH.search(normalized_path):
            logger.warning(
                "Blocked suspicious path request: ip=%s path=%s",
                self.get_client_ip(request),
                normalized_path,
            )
            return HttpResponse("Not Found", status=404)

        if normalized_path.startswith('/static/') or normalized_path.startswith('/media/'):
            return None

        ip = self.get_client_ip(request)

        now = timezone.now()
        expires_at = now + timedelta(seconds=self.WINDOW_SECONDS)
        cache_key = f"ip:{ip}"

        with transaction.atomic():
            try:
                counter = RateLimitCounter.objects.select_for_update().get(key=cache_key)
                created = False
            except RateLimitCounter.DoesNotExist:
                try:
                    with transaction.atomic():
                        counter = RateLimitCounter.objects.create(
                            key=cache_key,
                            count=1,
                            expires_at=expires_at,
                        )
                    created = True
                except IntegrityError:
                    counter = RateLimitCounter.objects.select_for_update().get(key=cache_key)
                    created = False

            if created:
                pass
            elif counter.expires_at <= now:
                counter.count = 1
                counter.expires_at = expires_at
                counter.save(update_fields=('count', 'expires_at'))
            elif counter.count >= self.RATE_LIMIT:
                logger.warning(
                    "Rate limit exceeded: ip=%s path=%s limit=%s window=%ss",
                    ip,
                    request.path,
                    self.RATE_LIMIT,
                    self.WINDOW_SECONDS,
                )
                response = HttpResponse(
                    "Too Many Requests. Please wait a minute and try again.",
                    status=429,
                )
                response["Retry-After"] = str(self.WINDOW_SECONDS)
                return response
            else:
                counter.count += 1
                counter.save(update_fields=('count',))

        return None

    @staticmethod
    def normalize_path(path):
        decoded_path = path
        for _ in range(2):
            decoded_path = unquote(decoded_path)
        return posixpath.normpath('/' + decoded_path.lstrip('/'))

    def get_client_ip(self, request):
        return client_ip(request)

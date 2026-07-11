import logging
from django.utils.deprecation import MiddlewareMixin
from django.http import JsonResponse, HttpResponseForbidden
from rest_framework_simplejwt.tokens import AccessToken
from django.core.cache import cache
from django.urls import resolve
from django.conf import settings

logger = logging.getLogger(__name__)

class JWTWebAuthMiddleware(MiddlewareMixin):
    """
    Middleware that reads the JWT access_token from HTTP-Only cookies
    and authenticates the user for Web Views (not just DRF APIs).
    It sets request.jwt_user_id and request.jwt_usertype which can be used by Mixins.
    """
    def process_request(self, request):
        request.jwt_user_id = None
        request.jwt_usertype = None
        
        token = request.COOKIES.get('access_token')
        if token:
            try:
                access_token = AccessToken(token)
                request.jwt_user_id = access_token.get('login_id')
                request.jwt_usertype = access_token.get('usertype')
            except Exception as e:
                logger.debug(f"JWTWebAuthMiddleware invalid token: {e}")
                pass

class RateLimitMiddleware(MiddlewareMixin):
    """
    Simple sliding window rate limiter using Django Cache.
    Limits standard views to a specified number of requests per minute per IP.
    """
    RATE_LIMIT = 60 # Requests per minute
    
    def process_request(self, request):
        # Don't rate limit static/media files
        if request.path.startswith('/static/') or request.path.startswith('/media/'):
            return None
            
        ip = self.get_client_ip(request)
        cache_key = f"rate_limit_{ip}"
        
        # We use a simple counter with a 60 second timeout
        request_count = cache.get(cache_key, 0)
        
        if request_count >= self.RATE_LIMIT:
            logger.warning(f"Rate limit exceeded for IP: {ip}")
            return HttpResponseForbidden("Too Many Requests. Please wait a minute and try again.")
            
        if request_count == 0:
            cache.set(cache_key, 1, 60) # Set timeout for 60 seconds
        else:
            cache.incr(cache_key)
            
        return None

    def get_client_ip(self, request):
        x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
        if x_forwarded_for:
            ip = x_forwarded_for.split(',')[0]
        else:
            ip = request.META.get('REMOTE_ADDR')
        return ip

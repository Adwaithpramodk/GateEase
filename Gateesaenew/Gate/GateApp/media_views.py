import mimetypes
import os

from django.conf import settings
from django.utils import timezone
from django.http import FileResponse, Http404, HttpResponseForbidden
from django.views import View
from rest_framework_simplejwt.exceptions import TokenError
from rest_framework_simplejwt.tokens import AccessToken

from .auth_tokens import active_token_user
from .models import class_assigntable, exitpasstable, mentortable, securitytable, studenttable


class ProtectedMediaView(View):
    def get(self, request, path):
        relative_path = os.path.normpath(path).replace('\\', '/')
        if relative_path.startswith('../') or relative_path == '..':
            raise Http404

        login_id = getattr(request, 'jwt_user_id', None) or request.session.get('user_id')
        usertype = getattr(request, 'jwt_usertype', None) or request.session.get('usertype')
        if not login_id:
            authorization = (
                request.headers.get('Authorization')
                or request.headers.get('X-Authorization')
            )
            if authorization:
                token_value = authorization.split(' ', 1)[-1]
                try:
                    token = AccessToken(token_value)
                    active_token_user(token)
                except TokenError:
                    token = None
                if token:
                    login_id = token.get('login_id')
                    usertype = token.get('usertype')
        if not login_id:
            return HttpResponseForbidden("Authentication required.")

        authorized = self.user_can_access(relative_path, login_id, usertype)
        if not authorized:
            return HttpResponseForbidden("You do not have permission to access this file.")

        full_path = os.path.realpath(os.path.join(str(settings.MEDIA_ROOT), relative_path))
        media_root = os.path.realpath(str(settings.MEDIA_ROOT))
        if not full_path.startswith(media_root + os.sep) or not os.path.isfile(full_path):
            raise Http404

        content_type = mimetypes.guess_type(full_path)[0] or 'application/octet-stream'
        return FileResponse(open(full_path, 'rb'), content_type=content_type)

    @staticmethod
    def user_can_access(path, login_id, usertype):
        if usertype == 'admin' and path.startswith('profile_photos/'):
            return True

        if path.startswith('profile_photos/students/') and usertype == 'mentor':
            classes = class_assigntable.objects.filter(mentor_id__LOGINID_id=login_id)
            return studenttable.objects.filter(
                Photo=path, classs_id__in=classes.values('class_id'),
            ).exists()
        if path.startswith('profile_photos/students/') and usertype == 'security':
            return exitpasstable.objects.filter(
                student_id__Photo=path, mentor_status='approved',
                created_at__date=timezone.localdate(),
            ).exists()

        if path.startswith('profile_photos/students/'):
            return studenttable.objects.filter(
                LOGINID_id=login_id,
                Photo=path,
            ).exists()
        if path.startswith('profile_photos/mentors/'):
            return mentortable.objects.filter(
                LOGINID_id=login_id,
                image=path,
            ).exists()
        if path.startswith('profile_photos/security/'):
            return securitytable.objects.filter(
                LOGINID_id=login_id,
                Photo=path,
            ).exists()
        if path.startswith('qrcodes/'):
            return exitpasstable.objects.filter(
                qrcode=path,
                student_id__LOGINID_id=login_id,
            ).exists()
        return False

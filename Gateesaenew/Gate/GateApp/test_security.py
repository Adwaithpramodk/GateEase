from pathlib import Path
from tempfile import TemporaryDirectory

from django.contrib.auth.hashers import make_password
from django.core import mail
from django.test import TestCase, override_settings
from django.utils import timezone

from .auth_tokens import create_login_tokens
from .models import (
    Logintable, PasswordResetOTP, complainttable, exitpasstable,
    mentortable, securitytable, studenttable,
)


@override_settings(
    SECURE_SSL_REDIRECT=False,
    CACHES={'default': {'BACKEND': 'django.core.cache.backends.locmem.LocMemCache'}},
    EMAIL_BACKEND='django.core.mail.backends.locmem.EmailBackend',
)
class SecurityRegressionTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        cls.student_login = Logintable.objects.create(
            username='student@example.com', usertype='Student',
            password=make_password('Test-account-secret-998!'),
        )
        cls.student = studenttable.objects.create(
            LOGINID=cls.student_login, name='Student', email=cls.student_login.username,
        )
        cls.mentor_login = Logintable.objects.create(username='mentor@example.com', usertype='mentor')
        mentortable.objects.create(LOGINID=cls.mentor_login, name='Mentor')
        cls.guard_login = Logintable.objects.create(username='guard@example.com', usertype='security')
        cls.guard = securitytable.objects.create(LOGINID=cls.guard_login, name='Guard')
        cls.group_pass = exitpasstable.objects.create(
            student_id=cls.student, is_group_pass=True, mentor_status='approved',
            security_status='pending', time=timezone.localtime().time(),
        )

    def authorize(self, user):
        refresh = create_login_tokens(user)
        self.client.defaults['HTTP_AUTHORIZATION'] = f'Bearer {refresh.access_token}'
        return refresh

    def post_json(self, path, data):
        return self.client.post(path, data, content_type='application/json')

    def test_complaint_ownership_and_reply(self):
        self.authorize(self.mentor_login)
        path = f'/ViewcomplaintAPI/{self.student_login.pk}'
        self.assertEqual(self.client.get(path).status_code, 403)
        self.assertEqual(self.post_json(path, {'complaint': 'Hello'}).status_code, 403)
        self.authorize(self.student_login)
        response = self.post_json(path, {'complaint': 'Hello', 'reply': 'Forged reply'})
        self.assertEqual(response.status_code, 201, response.content)
        self.assertIsNone(complainttable.objects.get().reply)

    def test_group_scan_requires_guard_and_eligible_pass(self):
        path = '/ProceedGroupPassAPI'
        self.authorize(self.student_login)
        self.assertEqual(self.post_json(path, {'pass_ids': [self.group_pass.pk]}).status_code, 403)
        self.authorize(self.guard_login)
        other = exitpasstable.objects.create(student_id=self.student, is_group_pass=False)
        self.assertEqual(
            self.post_json(path, {'pass_ids': [self.group_pass.pk, other.pk]}).status_code, 400,
        )
        self.group_pass.refresh_from_db()
        self.assertEqual(self.group_pass.security_status, 'pending')
        response = self.post_json(path, {'pass_ids': [self.group_pass.pk]})
        self.assertEqual(response.status_code, 200, response.content)
        self.group_pass.refresh_from_db()
        self.assertEqual(self.group_pass.scanned_by_id, self.guard.pk)
        self.assertEqual(self.post_json(path, {'pass_ids': [self.group_pass.pk]}).status_code, 400)

    def test_mentor_cannot_manage_unassigned_student_or_change_staff_role(self):
        refresh = create_login_tokens(self.mentor_login)
        self.client.cookies['access_token'] = str(refresh.access_token)
        paths = [
            f'/EditStudent/{self.student.pk}',
            f'/AcceptStudent/{self.student_login.pk}',
            f'/RejectStudent/{self.guard_login.pk}',
            f'/UploadImage/{self.student.pk}',
        ]
        for path in paths:
            with self.subTest(path=path):
                self.assertEqual(self.client.post(path).status_code, 404)
        self.guard_login.refresh_from_db()
        self.assertEqual(self.guard_login.usertype, 'security')

    def test_refresh_rotates_with_fixed_deadline_and_password_change_revokes(self):
        token = self.authorize(self.student_login)
        path = '/api/token/refresh/'
        response = self.post_json(path, {'refresh': str(token)})
        self.assertEqual(response.status_code, 200, response.content)
        from rest_framework_simplejwt.tokens import RefreshToken

        rotated = RefreshToken(response.json()['refresh'])
        self.assertEqual(rotated['exp'], token['persistent_login_expires'])
        self.assertEqual(self.post_json(path, {'refresh': str(token)}).status_code, 401)
        self.student_login.password = make_password('Another-valid-secret-223!')
        self.student_login.save(update_fields=['password'])
        self.assertEqual(self.client.get('/ping').status_code, 401)
        self.assertEqual(self.post_json(path, {'refresh': str(rotated)}).status_code, 401)

    def test_reset_is_bound_to_login_and_code_is_single_use(self):
        email = self.student_login.username
        response = self.post_json('/ForgetPassword', {'Email': email})
        self.assertEqual(response.status_code, 200)
        code = mail.outbox[0].body.split('code is ')[1].split('.')[0]
        self.assertNotEqual(PasswordResetOTP.objects.get().otp, code)
        data = {'email': email, 'otp': code, 'new_password': 'Changed-password-445!'}
        response = self.post_json('/api/password/reset/', data)
        self.assertEqual(response.status_code, 200, response.content)
        self.assertEqual(self.post_json('/api/password/reset/', data).status_code, 400)

    def test_private_responses_cannot_be_cached(self):
        self.authorize(self.student_login)
        response = self.client.get('/ping')
        self.assertEqual(response.status_code, 200)
        self.assertIn('no-store', response.headers['Cache-Control'])


    def test_media_requires_owner(self):
        relative = 'profile_photos/students/security-test.jpg'
        self.student.Photo = relative
        self.student.save_base(update_fields=['Photo'])
        with TemporaryDirectory() as directory, self.settings(MEDIA_ROOT=directory):
            media_file = Path(directory, relative)
            media_file.parent.mkdir(parents=True)
            media_file.write_bytes(b'private avatar')
            self.authorize(self.mentor_login)
            self.assertEqual(self.client.get('/media/' + relative).status_code, 403)
            self.authorize(self.student_login)
            response = self.client.get('/media/' + relative)
            self.assertEqual(response.status_code, 200)
            self.assertEqual(b''.join(response.streaming_content), b'private avatar')
            self.assertIn('no-store', response.headers['Cache-Control'])

    def test_staff_can_sign_in_with_only_a_password(self):
        password = 'Staff-test-password-998!'
        self.mentor_login.password = make_password(password)
        self.mentor_login.save(update_fields=['password'])
        response = self.post_json('/LoginpageAPI', {
            'username': self.mentor_login.username, 'password': password,
        })
        self.assertEqual(response.status_code, 200, response.content)
        self.assertIn('refresh', response.json())
        response = self.client.post('/login/', {
            'email': self.mentor_login.username, 'password': password,
        })
        self.assertRedirects(response, '/MntrHome', fetch_redirect_response=False)

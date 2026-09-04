from django.contrib.auth.hashers import make_password
from django.conf import settings
from django.test import TestCase
from rest_framework_simplejwt.token_blacklist.models import BlacklistedToken

from .models import Logintable


class PersistentLoginTests(TestCase):
	def setUp(self):
		self.user = Logintable.objects.create(
			username='student@example.com',
			password=make_password('correct-password'),
			usertype='Student',
		)

	def login(self):
		return self.client.post('/login/', {
			'email': self.user.username,
			'password': 'correct-password',
		})

	def test_login_sets_short_access_and_seven_day_refresh_cookies(self):
		response = self.login()

		self.assertEqual(response.status_code, 302)
		self.assertEqual(response.cookies['access_token']['max-age'], 900)
		self.assertEqual(response.cookies['refresh_token']['max-age'], 604800)
		self.assertEqual(response.cookies['access_token']['httponly'], True)
		self.assertEqual(response.cookies['refresh_token']['httponly'], True)
		self.assertEqual(response.cookies['access_token']['samesite'], 'Lax')
		self.assertEqual(response.cookies['refresh_token']['samesite'], 'Lax')
		self.assertEqual(settings.SESSION_COOKIE_AGE, 604800)

	def test_refresh_rotates_cookie_and_rejects_reused_token(self):
		self.login()
		old_refresh = self.client.cookies['refresh_token'].value

		response = self.client.post('/auth/refresh/')
		self.assertEqual(response.status_code, 200)
		self.assertNotEqual(response.cookies['refresh_token'].value, old_refresh)

		self.client.cookies['refresh_token'] = old_refresh
		reused_response = self.client.post('/auth/refresh/')
		self.assertEqual(reused_response.status_code, 401)
		self.assertTrue(BlacklistedToken.objects.exists())

	def test_logout_revokes_refresh_token_and_clears_cookies(self):
		self.login()
		refresh = self.client.cookies['refresh_token'].value

		response = self.client.get('/Logout')

		self.assertEqual(response.status_code, 302)
		self.assertEqual(response.cookies['refresh_token']['max-age'], 0)
		self.client.cookies['refresh_token'] = refresh
		refresh_response = self.client.post('/auth/refresh/')
		self.assertEqual(refresh_response.status_code, 401)

# Create your tests here.

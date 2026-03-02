from django.apps import AppConfig


class GateappConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'GateApp'

    def ready(self):
        # Initialize Firebase when the app is ready and settings are loaded
        try:
            from .services.notification_service import initialize_firebase
            initialize_firebase()
        except Exception as e:
            print(f"Firebase initialization skipped in ready(): {e}")

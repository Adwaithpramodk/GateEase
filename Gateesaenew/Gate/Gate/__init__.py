"""
Django initialization file
Initializes Firebase Admin SDK when Django starts
"""

# Initialize Firebase when Django starts
def initialize_firebase_on_startup():
    """
    Initialize Firebase Admin SDK
    Called automatically when Django starts
    """
    try:
        from GateApp.services.notification_service import initialize_firebase
        initialize_firebase()
    except Exception as e:
        print(f"Firebase initialization skipped: {e}")
        print("Push notifications will not work until Firebase is properly configured")

# Call initialization
initialize_firebase_on_startup()

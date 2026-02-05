import os
import django

# Setup Django environment
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "Gate.settings")
django.setup()

from django.contrib.auth import get_user_model
from django.conf import settings

User = get_user_model()

def create_superuser():
    username = os.environ.get("DJANGO_SUPERUSER_USERNAME", "admin")
    email = os.environ.get("DJANGO_SUPERUSER_EMAIL", "admin@example.com")
    password = os.environ.get("DJANGO_SUPERUSER_PASSWORD", "admin123")

    if not User.objects.filter(username=username).exists():
        print(f"Creating superuser: {username}")
        User.objects.create_superuser(username=username, email=email, password=password)
        print("Superuser created successfully!")
    else:
        print(f"Superuser {username} already exists.")

    # Also ensure there is a LoginTable entry for this admin if your app relies on it
    # Based on your views.py, you use Logintable for authentication, not just User
    try:
        from GateApp.models import Logintable
        if not Logintable.objects.filter(username=username).exists():
            print(f"Creating Logintable entry for: {username}")
            Logintable.objects.create(username=username, password=password, usertype='admin')
            print("Logintable entry created!")
    except ImportError:
        print("Could not import Logintable, skipping custom table creation.")
    except Exception as e:
        print(f"Error creating Logintable entry: {e}")

if __name__ == "__main__":
    create_superuser()

# PythonAnywhere Deployment Guide for GateEase

This document outlines the exact steps to completely wipe a previous deployment and re-host the GateEase Django application on PythonAnywhere from scratch, using a MySQL database.

## Phase 1: Wipe the Slate Clean
If you have a pre-existing app on PythonAnywhere that you want to delete to start fresh, follow these steps:
1. **Delete the Web App:** Go to the **Web** tab, scroll to the very bottom, and click the red **Delete** button.
2. **Delete the Files:** Go to your **Consoles** tab, open a new **Bash** console, and run these commands to delete your old code and old virtual environment:
   ```bash
   rm -rf /home/GATEEASEE/GateEase  # Deletes the old code (adjust folder name if your folder is named differently)
   rmvirtualenv gate-env            # Deletes the old virtual environment
   ```

## Phase 2: Upload Code & Set up Environment
1. **Clone your Code:** In the same Bash console, pull down your fresh code from GitHub:
   ```bash
   git clone <your-github-repo-url>
   ```
2. **Create a New Virtual Environment & Install Requirements:**
   ```bash
   mkvirtualenv --python=/usr/bin/python3.10 gate-env
   cd <your-project-folder-with-requirements.txt>
   pip install -r requirements.txt
   ```
   *(Note: Ensure `mysqlclient` is in your `requirements.txt` instead of `psycopg2-binary` before doing this).*

## Phase 3: Set up the MySQL Database & Secrets
1. **Create the Database:** Go to the **Databases** tab, click to initialize MySQL with a password, and note your database name (it will look like `GATEEASEE$default`).
2. **Create the `.env` File:** Go to the **Files** tab, navigate to the folder containing your `manage.py`, create a new file named `.env`, and paste in your secrets:
   ```ini
   SECRET_KEY=your_secure_secret_key
   DEBUG=False
   ALLOWED_HOSTS=GATEEASEE.pythonanywhere.com
   CSRF_TRUSTED_ORIGIN=https://GATEEASEE.pythonanywhere.com
   EMAIL_HOST_PASSWORD=your_gmail_app_password
   DATABASE_URL=mysql://GATEEASEE:YourDbPassword@GATEEASEE.mysql.pythonanywhere-services.com/GATEEASEE$default
   ```
3. **Migrate the Database:** Go back to your Bash console (with `gate-env` active) and run:
   ```bash
   python manage.py migrate
   python manage.py collectstatic
   ```

## Phase 4: Create the New Web App
1. Go to the **Web** tab and click **Add a new web app**.
2. Click **Next**, then select **Manual Configuration** (do NOT choose Django).
3. Select **Python 3.10** and click Next.
4. Once created, scroll down to the **Virtualenv** section and type: `gate-env`
5. Scroll up to the **Source code** section and enter the path to your project (the folder where `manage.py` is):
   `/home/GATEEASEE/GateEase/Gateesaenew/Gate`
6. Click the **WSGI configuration file** link, delete everything in it, and paste this exact code (make sure the path matches your Source code path):
   ```python
   import os
   import sys

   path = '/home/GATEEASEE/GateEase/Gateesaenew/Gate'
   if path not in sys.path:
       sys.path.append(path)

   os.environ['DJANGO_SETTINGS_MODULE'] = 'Gate.settings'

   from dotenv import load_dotenv
   load_dotenv(os.path.join(path, '.env'))

   from django.core.wsgi import get_wsgi_application
   application = get_wsgi_application()
   ```
   ```
7. **Configure Static and Media Files:** Scroll down to the **Static files** section and add these two entries:
   * URL: `/static/` -> Directory: `/home/GATEEASEE/GateEase/Gateesaenew/Gate/staticfiles`
   * URL: `/media/` -> Directory: `/home/GATEEASEE/GateEase/Gateesaenew/Gate/media`
8. Click **Save** on the WSGI file, go back to the Web tab, turn on **Force HTTPS** under the Security section, and click the big green **Reload** button!

Your application should now be live and connected to MySQL.

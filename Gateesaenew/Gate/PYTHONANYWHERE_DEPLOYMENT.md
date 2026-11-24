# GateEase production upgrade on PythonAnywhere

The college uses this installation. Upgrade the existing deployment in place and keep its MySQL database, media files, environment settings, and current Django secret key.

## Before the maintenance window

1. Back up the production MySQL database and media directory. Secure the backups and verify that you can restore them to an isolated staging environment. Save the current release, virtual environment, and hosting configuration so you can switch the application back if needed.
2. Stage the new release and its dependencies separately. Check that the production settings still point to the intended MySQL database. Django falls back to local SQLite when no database URL is configured.
3. On the restored MySQL copy, run the two checks below. Confirm the migration history matches the existing schema and review every pending operation.

   ```bash
   python manage.py showmigrations GateApp
   python manage.py migrate --plan
   ```

   **Stop if `0006_integrity_constraints` is pending or the plan contains unexpected migrations.** Migration 0006 deletes certain duplicate rows before adding constraints. Review the affected data on the restored copy before deciding how to proceed.

4. Rehearse the upgrade on the restored copy. Compare counts for student accounts, staff accounts, passes, complaints, and announcements before and after. Verify that the currently distributed Flutter build and the updated build can perform essential student, mentor, and gate workflows. Keep the current deployment serving students until the rollout is ready.

## What this release changes in the database

| Migration | Effect |
| --- | --- |
| `0007_ratelimitcounter` | Creates the rate-limit counter table. |
| `0008_passwordresetotp_failed_attempts_and_more` | Changes password-reset storage and invalidates previously issued reset codes. Users with a pending reset must request a new code. |
| `0009_logintable_last_totp_step` | Adds an unused column retained for migration compatibility. |
| `0010_logintable_session_version` | Adds a field for session revocation. Existing accounts are retained. |

These four migrations leave existing students, staff, passes, complaints, and announcements in place. The configured rate-limit cache table is created separately.

`0011_passwordresetdelivery` creates a password-reset queue. Migration `0012` adds a pass-notification queue and protects referenced college records from deletion. Neither migration deletes existing records. Before switching traffic, start `python manage.py deliver_password_resets` as a supervised worker on staging and production. It sends password resets and mentor pass notifications outside the web request. Restart the worker after switching the release, and verify both queues drain. Use `--once` only for a one-time drain or a scheduler that runs frequently enough for interactive email. Confirm reset email delivery during the rollout.

## During the maintenance window

1. Pause writes and take a fresh backup. Repeat the migration-plan check against the existing production database before applying changes. MySQL schema changes can lock tables and a failed migration may leave partial changes. [Django migration documentation](https://docs.djangoproject.com/en/5.2/topics/migrations/#mysql)
2. From the release directory with its virtual environment and production settings loaded, run the following in order. Stop if any command fails.

   ```bash
   python manage.py migrate --noinput
   python manage.py createcachetable
   python manage.py collectstatic --noinput
   python manage.py check --deploy
   ```

3. Switch the existing web app to the new release and reload it. Keep the static assets mapping. Remove any direct `/media/` mapping after verifying protected media works from the updated web and Flutter clients. Keep the media directory itself.
4. Verify sign-in, pass requests, approvals, gate scanning, and private media before reopening access. If the rollout fails, stop writes, check the migration state, and assess whether the previous release can run against the resulting schema. A database restore can discard writes made after the backup.

## Sessions and app distribution

- Tell users they will need to sign in again after the upgrade. Existing tokens lack the new revocable session identifiers. The updated Flutter app supports automatic renewal, and an older build may still lose API access after 15 minutes.
- Sign Android updates with the existing production signing key through `GATEEASE_ANDROID_KEYSTORE`, `GATEEASE_ANDROID_KEY_ALIAS`, `GATEEASE_ANDROID_STORE_PASSWORD`, and `GATEEASE_ANDROID_KEY_PASSWORD`.
- Verify that the proxy overwrites HTTPS headers. Enable `TRUST_PROXY_CLIENT_IP=True` only if the proxy also overwrites `X-Real-IP`. After rollout, run `python manage.py cleanup_rate_limit_counters` periodically to remove expired rate-limit counters.

## Campus traffic and staff profile changes

- Preserve the production `DATABASE_URL`. Production startup now fails if it is missing.
- Test access from the campus network. The per-minute limits default to 300 requests per anonymous IP, 120 per signed-in web account, and 60 login attempts per IP. Tune `WEB_ANONYMOUS_IP_LIMIT`, `WEB_SIGNED_IN_REQUEST_LIMIT`, and `LOGIN_IP_LIMIT` based on observed traffic. The separate five-attempt per-account login limit still applies.
- Staff profile edit forms change the contact email. For a sign-in or recovery email change, verify the new address with the staff member and update the linked login through the authorized Django admin workflow.
- The gate scanner scripts are part of the release static assets. Run `collectstatic` before serving the new release.


## Google Play release checks

- Confirm the existing Play listing's package name, upload key, and highest version code. Use a higher build number for an update. Supply the existing release signing environment variables and the Firebase Android client configuration during the build.
- Run `flutter build appbundle --release --build-number=<next-version-code>` from the Flutter directory. Use Play's App Bundle Explorer or bundletool to verify API 36, 64-bit native libraries, and 16 KB page alignment on the final bundle.
- Deploy the privacy page with its `#account-deletion` section. Confirm it opens without sign-in. Assign an operator to monitor the support inbox, verify ownership, and fulfill deletion requests across GateEase and its service providers. Document the college's actual retention periods and exceptions before marking the Play declaration complete.
- Complete Data safety using the deployed data flows and Firebase configuration. Review contact details, student and device identifiers, profile photos, pass records, and complaints. Provide working student, mentor, and guard review access using synthetic data, and document how reviewers can exercise the timed QR workflow.
- Verify the signed bundle on Play internal testing, including small screens, large text, camera denial, expired sessions, logout, and mentor notifications. If Play Console requires a closed test, complete it before applying for production access.

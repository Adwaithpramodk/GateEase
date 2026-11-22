from django.core.management.base import BaseCommand
from django.utils import timezone

from GateApp.models import RateLimitCounter


class Command(BaseCommand):
    help = 'Delete expired global rate-limit counters.'

    def handle(self, *args, **options):
        deleted, _ = RateLimitCounter.objects.filter(
            expires_at__lte=timezone.now()
        ).delete()
        self.stdout.write(f'Deleted {deleted} expired rate-limit counters.')

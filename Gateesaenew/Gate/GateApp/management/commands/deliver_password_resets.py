import logging
from datetime import timedelta
from time import sleep

from django.core.management.base import BaseCommand
from django.db import close_old_connections
from django.db.models import Q
from django.utils import timezone

from GateApp.models import PassNotificationDelivery, PasswordResetDelivery
from GateApp.views import issue_password_reset, notify_assigned_mentors_about_pass

logger = logging.getLogger(__name__)


def deliver_pass_notification(job):
    exit_pass = job.exit_pass
    if exit_pass.student_id and exit_pass.mentor_status == 'pending':
        notify_assigned_mentors_about_pass(exit_pass, exit_pass.student_id, exit_pass.reason or '')


class Command(BaseCommand):
    help = 'Deliver queued password resets and pass notifications.'

    def add_arguments(self, parser):
        parser.add_argument('--once', action='store_true')

    def handle(self, *args, **options):
        while True:
            close_old_connections()
            self.drain(PasswordResetDelivery, lambda job: issue_password_reset(job.email))
            self.drain(PassNotificationDelivery, deliver_pass_notification)
            if options['once']:
                return
            sleep(2)

    def drain(self, model, deliver):
        jobs = model.objects.all()
        jobs.filter(created_at__lt=timezone.now() - timedelta(minutes=10)).delete()
        available = Q(leased_until__isnull=True) | Q(leased_until__lt=timezone.now())
        for job in jobs.filter(available).order_by('pk')[:100]:
            now = timezone.now()
            if not jobs.filter(available, pk=job.pk).update(leased_until=now + timedelta(minutes=2)):
                continue
            try:
                deliver(job)
            except Exception:
                logger.exception('Delivery failed queue=%s job=%s', model.__name__, job.pk)
                jobs.filter(pk=job.pk).update(leased_until=timezone.now() + timedelta(seconds=30))
            else:
                job.delete()

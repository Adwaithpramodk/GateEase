import datetime
import logging
import secrets
from django.contrib.auth.password_validation import validate_password
from django.core.cache import cache
from django.core.exceptions import ValidationError
from django.core.validators import validate_email
from django.utils.crypto import constant_time_compare, salted_hmac
import csv
from django.utils import timezone
from django.shortcuts import get_object_or_404, redirect, render
from django.views import View
from django.contrib import messages
from django.http import HttpResponse
from .serializer import *
from .models import *
from .middleware import client_ip
from .forms import *
from django.template.loader import get_template
from xhtml2pdf import pisa
from django.contrib.auth.hashers import make_password, check_password
from django.db import IntegrityError, transaction
from django.db import models as models
from .auth_tokens import ACTIVE_ROLES, active_token_user, delete_auth_cookies, create_login_tokens, rotate_refresh_token, set_auth_cookies
from django.db.models import Q
logger = logging.getLogger(__name__)
security_log = logging.getLogger('GateApp.security')


def mentor_approval_window_open():
    current_time = timezone.localtime().time()
    return datetime.time(10, 0) <= current_time <= datetime.time(15, 40)


def pass_expired(exit_pass, now=None):
    """Return whether a pass is past its 15-minute scan grace period."""
    if not exit_pass.created_at or exit_pass.time is None:
        return True
    now = now or timezone.localtime()
    pass_date = timezone.localtime(exit_pass.created_at).date()
    exit_datetime = datetime.datetime.combine(pass_date, exit_pass.time)
    exit_datetime = timezone.make_aware(
        exit_datetime,
        timezone.get_current_timezone(),
    )
    return now >= exit_datetime + datetime.timedelta(minutes=15)


def individual_scan_open(exit_pass):
    if not exit_pass.created_at or exit_pass.time is None:
        return False
    now = timezone.localtime()
    exit_date = timezone.localtime(exit_pass.created_at).date()
    exit_time = timezone.make_aware(datetime.datetime.combine(exit_date, exit_pass.time))
    return exit_time - datetime.timedelta(minutes=15) <= now < exit_time + datetime.timedelta(minutes=15)


def submit_individual_pass(student, reason, requested_time, now):
    with transaction.atomic():
        studenttable.objects.select_for_update().get(pk=student.pk)
        existing = exitpasstable.objects.filter(
            student_id=student, created_at__gte=now - datetime.timedelta(hours=1),
        )
        if existing.filter(
            reason=reason, time=requested_time, created_at__gte=now - datetime.timedelta(seconds=15),
        ).exists():
            raise ValueError('This pass application was already submitted.')
        if existing.count() >= 2:
            raise ValueError('You can only apply for 2 passes per hour.')
        return exitpasstable.objects.create(
            student_id=student, reason=reason, time=requested_time,
            mentor_status='pending', security_status='pending',
        )


def process_group_passes(login_id, pass_ids):
    guard = securitytable.objects.filter(LOGINID_id=login_id).first()
    if guard is None:
        raise PermissionError('An active guard profile is required.')
    if not isinstance(pass_ids, list) or not 1 <= len(pass_ids) <= 500:
        raise ValueError('Select between 1 and 500 group passes.')
    if any(type(value) not in (int, str) or not str(value).isascii() or not str(value).isdigit()
           or len(str(value)) > 18 for value in pass_ids):
        raise ValueError('Invalid group pass selection.')
    ids = {int(value) for value in pass_ids}
    with transaction.atomic():
        passes = list(exitpasstable.objects.select_for_update().filter(
            id__in=ids, is_group_pass=True, mentor_status='approved', security_status='pending',
        ).order_by('id'))
        if len(passes) != len(ids) or any(pass_expired(item) for item in passes):
            raise ValueError('The selection contains ineligible or expired group passes.')
        updated = exitpasstable.objects.filter(
            id__in=ids, is_group_pass=True, mentor_status='approved', security_status='pending',
        ).update(security_status='scanned', scanned_at=timezone.now(), scanned_by=guard)
        if updated != len(ids):
            raise ValueError('The pass selection changed. Please reload and retry.')
        transaction.on_commit(lambda: security_log.info(
            'group_scan actor=%s passes=%s', login_id, sorted(ids),
        ))
    return updated


def notify_assigned_mentors_about_pass(exit_pass, student_obj, reason):
    student_class = student_obj.classs
    if not student_class:
        logger.warning("Student %s is not assigned to a class", student_obj.name)
        return

    assignments = class_assigntable.objects.filter(
        class_id=student_class
    ).select_related('mentor_id')
    if not assignments.exists():
        logger.warning("No mentor assigned to class %s", student_class.class_name)
        return

    from GateApp.services.notification_service import send_notification_to_mentor

    for assignment in assignments:
        mentor = assignment.mentor_id
        device_tokens = list(
            MentorDeviceToken.objects.filter(
                mentor=mentor,
                is_active=True,
            ).values_list('device_token', flat=True)
        )
        if not device_tokens:
            logger.warning("No active device tokens found for mentor %s", mentor.name)
            continue

        sent_count = send_notification_to_mentor(
            device_tokens=device_tokens,
            student_name=student_obj.name,
            class_name=student_class.class_name,
            reason=reason,
            pass_id=exit_pass.id,
        )
        logger.info(
            "Sent pass notification to %s device(s) for mentor %s",
            sent_count,
            mentor.name,
        )


# Create your views here.

# Landing page view - Entry point for the application
class LandingPage(View):
    def get(self, request):
        return render(request, 'index.html')

class PrivacyPolicy(View):
    def get(self, request):
        return render(request, 'privacy.html')

#admin role checking
class AdminRequiredMixin:
    def dispatch(self, request, *args, **kwargs):
        # Check if user is logged in
        if not getattr(request, 'jwt_user_id', None) and not request.session.get('user_id'):
            messages.error(request, "Login Required")
            return redirect('LoginPage')

        # Check if user is admin
        usertype = getattr(request, 'jwt_usertype', None) or request.session.get('usertype')
        if usertype != 'admin':
             messages.error(request, "Unauthorized Access: Admins Only")
             return redirect('LoginPage')

        return super().dispatch(request, *args, **kwargs)
#login required for all pages
class LoginRequiredMixin:
    def dispatch(self, request, *args, **kwargs):
        if not getattr(request, 'jwt_user_id', None) and not request.session.get('user_id'):
            messages.error(request, "Login Required")
            return redirect('LoginPage')
        return super().dispatch(request, *args, **kwargs)

class StudentRequiredMixin:
    def dispatch(self, request, *args, **kwargs):
        if not getattr(request, 'jwt_user_id', None) and not request.session.get('user_id'):
            messages.error(request, "Login Required")
            return redirect('LoginPage')

        usertype = getattr(request, 'jwt_usertype', None) or request.session.get('usertype')
        if usertype != 'Student':
             messages.error(request, "Unauthorized Access: Students Only")
             return redirect('LoginPage')
        return super().dispatch(request, *args, **kwargs)

class MentorRequiredMixin:
    def dispatch(self, request, *args, **kwargs):
        if not getattr(request, 'jwt_user_id', None) and not request.session.get('user_id'):
            messages.error(request, "Login Required")
            return redirect('LoginPage')

        usertype = getattr(request, 'jwt_usertype', None) or request.session.get('usertype')
        if usertype != 'mentor':
             messages.error(request, "Unauthorized Access: Mentors Only")
             return redirect('LoginPage')
        return super().dispatch(request, *args, **kwargs)

class AdminOrMentorRequiredMixin:
    def dispatch(self, request, *args, **kwargs):
        if not getattr(request, 'jwt_user_id', None) and not request.session.get('user_id'):
            messages.error(request, "Login Required")
            return redirect('LoginPage')

        usertype = getattr(request, 'jwt_usertype', None) or request.session.get('usertype')
        if usertype not in ['admin', 'mentor']:
             messages.error(request, "Unauthorized Access: Admins or Mentors Only")
             return redirect('LoginPage')
        return super().dispatch(request, *args, **kwargs)

class SecurityRequiredMixin:
    def dispatch(self, request, *args, **kwargs):
        if not getattr(request, 'jwt_user_id', None) and not request.session.get('user_id'):
            messages.error(request, "Login Required")
            return redirect('LoginPage')

        usertype = getattr(request, 'jwt_usertype', None) or request.session.get('usertype')
        if usertype != 'security':
             messages.error(request, "Unauthorized Access: Security Only")
             return redirect('LoginPage')
        return super().dispatch(request, *args, **kwargs)

class Logout(View):
    def _logout(self, request):
        refresh_token = request.COOKIES.get('refresh_token')
        if refresh_token:
            try:
                RefreshToken(refresh_token).blacklist()
            except Exception:
                logger.info("Logout received an invalid or already revoked refresh token")
        request.session.flush()
        messages.success(request, "Logged out successfully")
        response = redirect('LoginPage')
        delete_auth_cookies(response)
        return response

    def post(self, request):
        return self._logout(request)

def password_errors(password, username):
    if not isinstance(password, str) or not password:
        return 'Password is required.'
    try:
        validate_password(password, user=Logintable(username=username))
    except ValidationError as exc:
        return ' '.join(exc.messages)
    return None


RESET_RESPONSE = 'If the account exists, a code will be sent.'


def reset_account(email):
    if not isinstance(email, str) or len(email) > 100:
        return None
    try:
        validate_email(email)
    except ValidationError:
        return None
    try:
        return Logintable.objects.get(username__iexact=email)
    except (Logintable.DoesNotExist, Logintable.MultipleObjectsReturned):
        return None


def otp_digest(login_id, code):
    return salted_hmac('gateease.password-reset', f'{login_id}:{code}', algorithm='sha256').hexdigest()


def issue_password_reset(email):
    user = reset_account(email)
    if user is None or not cache.add(f'gateease-reset-send:{user.pk}', True, timeout=60):
        return
    code = str(secrets.randbelow(900000) + 100000)
    with transaction.atomic():
        Logintable.objects.select_for_update().get(pk=user.pk)
        PasswordResetOTP.objects.filter(email=user.username, is_used=False).update(is_used=True)
        reset = PasswordResetOTP.objects.create(email=user.username, otp=otp_digest(user.pk, code))
    try:
        send_mail(
            'GateEase Password Reset',
            f'Your password reset code is {code}. It expires in 10 minutes.',
            settings.DEFAULT_FROM_EMAIL,
            [user.username],
        )
    except Exception:
        PasswordResetOTP.objects.filter(pk=reset.pk).update(is_used=True)
        logger.exception('Password reset delivery failed')


def complete_password_reset(email, code, password):
    user = reset_account(email)
    if user is None or not isinstance(code, str) or len(code) != 6:
        raise ValidationError('Invalid or expired code.')
    validate_password(password, user=user)
    with transaction.atomic():
        user = Logintable.objects.select_for_update().get(pk=user.pk)
        reset = PasswordResetOTP.objects.filter(email=user.username, is_used=False).order_by('-id').first()
        if reset is None or timezone.now() >= reset.created_at + datetime.timedelta(minutes=10):
            return False
        if not constant_time_compare(reset.otp, otp_digest(user.pk, code)):
            reset.failed_attempts += 1
            reset.is_used = reset.failed_attempts >= 5
            reset.save(update_fields=['failed_attempts', 'is_used'])
            return False
        if PasswordResetOTP.objects.filter(pk=reset.pk, is_used=False).update(is_used=True) != 1:
            return False
        user.password = make_password(password)
        user.save(update_fields=['password'])
    security_log.info('password_reset target=%s', user.pk)
    return True


class ForgotPasswordWeb(View):
    def get(self, request):
        return render(request, 'tables/form/forgot_password.html')

    def post(self, request):
        email = request.POST.get('email', '').strip()
        if not email or len(email) > 100:
            messages.error(request, 'Enter a valid email address.')
            return redirect('ForgotPassword')
        issue_password_reset(email)
        request.session['reset_email'] = email
        messages.success(request, RESET_RESPONSE)
        return redirect('ResetPassword')


class ResetPasswordWeb(View):
    def get(self, request):
        email = request.session.get('reset_email')
        if not email:
            return redirect('ForgotPassword')
        return render(request, 'tables/form/reset_password.html', {'email': email})

    def post(self, request):
        email = request.session.get('reset_email')
        if not email:
            return redirect('ForgotPassword')
        password = request.POST.get('new_password', '')
        if password != request.POST.get('confirm_password'):
            messages.error(request, 'Passwords do not match.')
            return redirect('ResetPassword')
        try:
            if not complete_password_reset(email, request.POST.get('otp'), password):
                raise ValidationError('Invalid or expired code.')
        except ValidationError as exc:
            messages.error(request, ' '.join(exc.messages))
            return redirect('ResetPassword')
        request.session.flush()
        request._rotated_auth_tokens = None
        response = redirect('LoginPage')
        delete_auth_cookies(response)
        messages.success(request, 'Password reset successfully. Please log in.')
        return response


class StudentVerificationPending(View):
    def get(self, request):
        return render(request, 'tables/form/student_verification_pending.html', {
            'contact_email': settings.EMAIL_HOST_USER,
            'status': request.GET.get('status', 'pending'),
        })
class StudentVerificationRejected(View):
    def get(self, request):
        return render(request, 'tables/form/student_verification_reject.html', {
            'contact_email': settings.EMAIL_HOST_USER,
            'status': request.GET.get('status', 'pending'),
        })

class LoginPage(View):
    def get(self,request):
        usertype = getattr(request, 'jwt_usertype', None) or request.session.get('usertype')
        dashboard_by_role = {
            'admin': 'homepage',
            'mentor': 'MntrHome',
            'Student': 'StudentHome',
            'security': 'SecurityHome',
        }
        if (getattr(request, 'jwt_user_id', None) or request.session.get('user_id')) and usertype in dashboard_by_role:
            return redirect(dashboard_by_role[usertype])
        return render(request, 'tables/form/login.html')
    def post(self,request):
        username = request.POST.get('email')
        password = request.POST.get('password')

        # Server-side Validation
        login_key = salted_hmac('gateease.login-limit', f'{(username or "").casefold()}:{client_ip(request)}')
        key = f'gateease-web-login:{login_key.hexdigest()}'
        cache.add(key, 0, timeout=60)
        try:
            attempts = cache.incr(key)
        except ValueError:
            attempts = 1
        if attempts > 5:
            return HttpResponse('Too many login attempts.', status=429)

        if not username or not password:
            messages.error(request, "Login Failed: Email and Password are required!")
            return render(request, 'tables/form/login.html')

        import re
        if not re.match(r"[^@]+@[^@]+\.[^@]+", username):
            messages.error(request, "Login Failed: Please provide a valid email address!")
            return render(request, 'tables/form/login.html')
        try:
            #searching username
            obj = Logintable.objects.filter(username=username).first()
            #checking password
            if obj and check_password(password, obj.password):
                pass
            else:
                messages.error(request, "Login Unsuccessful")
                return render(request, 'tables/form/login.html')

            if obj.usertype == 'pending':
                return redirect(f"/StudentVerificationPending?status={obj.usertype}")
            
            if obj.usertype == 'Rejected':
                return redirect(f"/StudentVerificationRejected?status={obj.usertype}")

            # Issue short-lived access and persistent refresh tokens.
            refresh = create_login_tokens(obj)

            response = None
            if obj.usertype == 'admin':
                messages.success(request, "Login Successful")
                response = redirect('homepage')
            elif obj.usertype == 'mentor':
                messages.success(request, "Login Successful")
                response = redirect('MntrHome')
            elif obj.usertype == 'Student':
                messages.success(request, "Login Successful")
                response = redirect('StudentHome')
            elif obj.usertype == 'security':
                messages.success(request, "Login Successful")
                response = redirect('SecurityHome')
            else:
                messages.error(request, "Login Unsuccessful")
                return render(request, 'tables/form/login.html')

            if response:
                set_auth_cookies(response, refresh.access_token, refresh)
                request.session.cycle_key()
                request.session['user_id'] = obj.id
                request.session['usertype'] = obj.usertype
                return response
            else:
                 messages.error(request, "Login Failed: Invalid Credentials")
                 return render(request, 'tables/form/login.html')
        except Exception as e:
            logger.exception("LoginPage error")
            messages.error(request, f"Login Error")
            return render(request, 'tables/form/login.html')

from django.core.paginator import Paginator
from .models import studenttable


def filter_student_verification_status(queryset, status):
    status_filters = {
        'pending': (
            models.Q(LOGINID__isnull=True) |
            models.Q(LOGINID__usertype__isnull=True) |
            ~models.Q(LOGINID__usertype__in=['Student', 'Rejected'])
        ),
        'verified': models.Q(LOGINID__usertype='Student'),
        'rejected': models.Q(LOGINID__usertype='Rejected'),
        'no_image': models.Q(Photo__isnull=True) | models.Q(Photo=''),
    }
    return queryset.filter(status_filters[status]) if status in status_filters else queryset


class VerifyStudent(AdminRequiredMixin, View):
    def get(self, request):
        q = request.GET.get('q', '').strip()
        status = request.GET.get('status', '').strip()
        students_list = studenttable.objects.all().order_by('-id')
        if q:
            students_list = students_list.filter(
                models.Q(name__icontains=q) |
                models.Q(email__icontains=q) |
                models.Q(admn_no__icontains=q) |
                models.Q(classs__class_name__icontains=q)
            )
        students_list = filter_student_verification_status(students_list, status)
        paginator = Paginator(students_list, 10)
        page_number = request.GET.get('page')
        students = paginator.get_page(page_number)
        return render(
            request,
            'tables/form/verify_student.html',
            {
                'students': students,
                'q': q,
                'status': status,
                'classes': classstable.objects.all().order_by('class_name'),
            }
        )

class AdminAddStudent(AdminRequiredMixin, View):
    """Allow admin to directly add a student without waiting for self-registration."""
    def get(self, request):
        classes = classstable.objects.all().order_by('class_name')
        return render(request, 'tables/form/admin_add_student.html', {'classes': classes})

    def post(self, request):
        name = request.POST.get('name', '').strip()
        email = request.POST.get('email', '').strip()
        admn_no = request.POST.get('admn_no', '').strip()
        phone = request.POST.get('phone', '').strip()
        class_id = request.POST.get('classs', '').strip()
        password = request.POST.get('password', '').strip()
        activate_student = request.POST.get('activate_student') == 'on'

        if not all([name, email, admn_no, phone, class_id, password]):
            messages.error(request, 'All fields are required.')
            return redirect('admin_add_student')
        if not admn_no.isdigit() or len(admn_no) != 4:
            messages.error(request, 'Admission number must be exactly 4 digits (e.g. 5467).')
            return redirect('admin_add_student')
        if error := password_errors(password, email):
            messages.error(request, error)
            return redirect('admin_add_student')
        if Logintable.objects.filter(username=email).exists() or studenttable.objects.filter(email=email).exists():
            messages.error(request, 'Email already registered.')
            return redirect('admin_add_student')
        if studenttable.objects.filter(admn_no=admn_no).exists():
            messages.error(request, 'Admission number already registered.')
            return redirect('admin_add_student')
        try:
            class_obj = classstable.objects.get(id=class_id)
            with transaction.atomic():
                login_obj = Logintable.objects.create(
                    username=email,
                    password=make_password(password),
                    usertype='Student' if activate_student else 'pending'
                )
                studenttable.objects.create(
                    name=name, email=email, admn_no=admn_no,
                    phone=phone, classs=class_obj, LOGINID=login_obj
                )
            account_status = 'immediately active' if activate_student else 'pending approval'
            messages.success(request, f'Student "{name}" added successfully with {account_status} status.')
            return redirect('verify_student')
        except classstable.DoesNotExist:
            messages.error(request, 'Selected class not found.')
        except Exception as e:
            messages.error(request, 'Unable to add the student.')
        return redirect('admin_add_student')

def managed_students(request):
    role = request.jwt_usertype or request.session.get('usertype')
    if role == 'admin':
        return studenttable.objects.all()
    login_id = request.jwt_user_id or request.session.get('user_id')
    classes = class_assigntable.objects.filter(mentor_id__LOGINID_id=login_id)
    return studenttable.objects.filter(classs_id__in=classes.values('class_id'))


class EditStudent(AdminOrMentorRequiredMixin, View):
    def get(self, request, id):
        student = get_object_or_404(managed_students(request), id=id)
        form = EditStudentForm(instance=student)
        user_type = getattr(request, 'jwt_usertype', None) or request.session.get('usertype')
        back_url = 'verify_student' if user_type == 'admin' else 'verify_student_mentor'
        return render(request, 'tables/form/edit_student.html', {'form': form, 'student': student, 'back_url': back_url})

    def post(self, request, id):
        student = get_object_or_404(managed_students(request), id=id)
        data = request.POST.copy()
        if (request.jwt_usertype or request.session.get('usertype')) == 'mentor':
            data.update({'email': student.email, 'classs': student.classs_id})
        form = EditStudentForm(data, instance=student)
        user_type = getattr(request, 'jwt_usertype', None) or request.session.get('usertype')
        back_url = 'verify_student' if user_type == 'admin' else 'verify_student_mentor'
        if form.is_valid():
            form.save()
            messages.success(request, "Student Updated Successfully")
            return redirect(back_url)
        return render(request, 'tables/form/edit_student.html', {'form': form, 'student': student, 'back_url': back_url})

class AcceptStudent(AdminOrMentorRequiredMixin, View):
    def post(self,request, lid):
        login_obj = get_object_or_404(
            Logintable.objects.filter(id__in=managed_students(request).values('LOGINID_id')),
            id=lid, usertype__in=('pending', 'Rejected', 'Student'),
        )
        if login_obj.usertype != 'Student':
            Logintable.objects.filter(pk=login_obj.pk).update(
                usertype='Student', session_version=models.F('session_version') + 1,
            )
        security_log.info('student_verified actor=%s target=%s', request.jwt_user_id, login_obj.pk)
        messages.success(request, "Student Accepted successfully")
        destination = 'verify_student_mentor' if (
            getattr(request, 'jwt_usertype', None) or request.session.get('usertype')
        ) == 'mentor' else 'verify_student'
        return redirect(destination)

class RejectStudent(AdminOrMentorRequiredMixin, View):
    def post(self,request, lid):
        login_obj = get_object_or_404(
            Logintable.objects.filter(id__in=managed_students(request).values('LOGINID_id')),
            id=lid, usertype__in=('pending', 'Rejected', 'Student'),
        )
        if login_obj.usertype != 'Rejected':
            Logintable.objects.filter(pk=login_obj.pk).update(
                usertype='Rejected', session_version=models.F('session_version') + 1,
            )
        security_log.info('student_rejected actor=%s target=%s', request.jwt_user_id, login_obj.pk)
        messages.warning(request, "Student Rejected")
        destination = 'verify_student_mentor' if (
            getattr(request, 'jwt_usertype', None) or request.session.get('usertype')
        ) == 'mentor' else 'verify_student'
        return redirect(destination)

class DeleteStudent(AdminRequiredMixin, View):
    def post(self,request,id):
        destination = 'verify_student_mentor' if (
            getattr(request, 'jwt_usertype', None) or request.session.get('usertype')
        ) == 'mentor' else 'verify_student'
        try:
            s=studenttable.objects.get(id=id)
            if s.LOGINID:
                s.LOGINID.delete()
            else:
                s.delete()

            messages.success(request, "Student Deleted successfully")
            return redirect(destination)
        except Exception:
             messages.error(request, "Error Deleting Student")
             return redirect(destination)

class UploadImage(AdminOrMentorRequiredMixin, View):
    def post(self, request, s_id):
        Photo = request.FILES.get('image')
        student_obj = get_object_or_404(managed_students(request), id=s_id)

        if Photo:
            # Simply assign the file to the Photo field
            # Django will automatically save it to profile_photos/students/ as defined in the model
            student_obj.Photo = Photo
            try:
                student_obj.save()
            except ValidationError as exc:
                messages.error(request, ' '.join(exc.messages))

        return redirect('verify_student' if (request.jwt_usertype or request.session.get('usertype')) == 'admin' else 'verify_student_mentor')

class ManageDepartment(AdminRequiredMixin, View):
    def get(self,request):
        department=departmenttable.objects.all()
        return render(request, 'tables/form/mng_dep.html', {
            'departments': department,
            'department_form': AddDepartmentForm(),
        })

    def post(self, request):
        department_form = AddDepartmentForm(request.POST)
        if department_form.is_valid():
            department_form.save()
            messages.success(request, "Department added successfully")
            return redirect('mng_dep')

        department = departmenttable.objects.all()
        return render(request, 'tables/form/mng_dep.html', {
            'departments': department,
            'department_form': department_form,
        })

class AssignDepartment(AdminRequiredMixin, View):
    def get(self,request):
        return render(request, 'tables/form/assn_dep.html')

#exit pass with admin role checking and report generation
class Pass(AdminRequiredMixin, View):
    def get(self, request):
        month = request.GET.get('month')
        q = request.GET.get('q', '').strip()

        exitpasses = exitpasstable.objects.select_related('student_id__classs__department_id', 'mentor_id').all().order_by('-created_at')

        if month:
            exitpasses = exitpasses.filter(created_at__month=month)
        if q:
            exitpasses = exitpasses.filter(
                models.Q(student_id__name__icontains=q) |
                models.Q(reason__icontains=q) |
                models.Q(student_id__classs__department_id__name__icontains=q)
            )

        # Pagination
        paginator = Paginator(exitpasses, 15) # Show 15 passes per page
        page_number = request.GET.get('page')
        page_obj = paginator.get_page(page_number)

        months = range(1, 13)

        return render(request, 'tables/form/pass.html', {
            'exitpasses': page_obj,  # Using page_obj for the template
            'months': months,
            'selected_month': int(month) if month else None,
            'q': q,
            'page_obj': page_obj, # Pass page_obj explicitly for pagination controls
        })

class ExportPassPDF(AdminRequiredMixin, View):
    def get(self, request):
        exitpasses = exitpasstable.objects.all()

        template = get_template('tables/form/pass_pdf.html')
        html = template.render({'exitpasses': exitpasses})

        response = HttpResponse(content_type='application/pdf')
        response['Content-Disposition'] = 'attachment; filename="exit_pass_report.pdf"'

        pisa.CreatePDF(html, dest=response)
        return response

class ComplaintManage(AdminRequiredMixin, View):
    def get(self,request):
        complaint=complainttable.objects.all().order_by('-id')
        return render(request, 'tables/form/complaint_mng.html',{'complaints':complaint})

class ManageAnnouncements(AdminRequiredMixin, View):
    def get(self, request):
        announcements = announcementtable.objects.all()
        return render(request, 'tables/form/announcement_mng.html', {'announcements': announcements})

class AddAnnouncement(AdminRequiredMixin, View):
    def get(self, request):
        return render(request, 'tables/form/add_announcement.html')

    def post(self, request):
        title = request.POST.get('title', '').strip()
        message = request.POST.get('message', '').strip()
        expires_at = request.POST.get('expires_at', '').strip()

        if not title or not message:
            messages.error(request, 'Title and message are required.')
            return redirect('add_announcement')

        try:
            expiry = datetime.datetime.fromisoformat(expires_at) if expires_at else None
            if expiry and timezone.is_naive(expiry):
                expiry = timezone.make_aware(expiry, timezone.get_current_timezone())
            announcementtable.objects.create(
                title=title,
                message=message,
                expires_at=expiry,
            )
            messages.success(request, 'Announcement published successfully.')
            return redirect('manage_announcements')
        except ValueError:
            messages.error(request, 'Please provide a valid expiry date and time.')
            return redirect('add_announcement')

class DeleteAnnouncement(AdminRequiredMixin, View):
    def post(self, request, id):
        announcement = get_object_or_404(announcementtable, id=id)
        announcement.delete()
        messages.success(request, 'Announcement deleted successfully.')
        return redirect('manage_announcements')

class SendReply(AdminRequiredMixin, View):
    def post(self,request,id):
        complaint=complainttable.objects.get(id=id)
        reply_text=request.POST.get('reply')
        complaint.reply=reply_text
        complaint.save()
        messages.success(request, "Reply successful")
        return redirect('complaint_mng')

class ManageClass(AdminRequiredMixin, View):
    def get(self,request):
        classs_name=classstable.objects.all().order_by('-id')
        departments = departmenttable.objects.all().order_by('name')
        return render(request, 'tables/form/mng_class.html', {
            'classes': classs_name,
            'departments': departments,
        })

class AssignClass(AdminRequiredMixin, View):
    def get(self, request):
        classs_name = classstable.objects.all().order_by('-id')
        mentor = mentortable.objects.all()
        obj=class_assigntable.objects.all()
        return render(
            request,
            'tables/form/assn_class.html',
            {'cls': classs_name, 'mt': mentor,'assign':obj}
        )

    def post(self, request):
        mentor_id = request.POST.get('mentor')
        class_id = request.POST.get('classs')

        try:
            class_assigntable.objects.create(
                mentor_id_id=mentor_id,
                class_id_id=class_id
            )
        except IntegrityError:
            messages.error(request, "This mentor is already assigned to that class.")
            return redirect('AssignClass')
        messages.success(request, "Assigned successfully")
        return redirect('AssignClass')

class DeleteAssignClass(AdminRequiredMixin, View):
    def post(self,request,id):
        s=class_assigntable.objects.get(id=id)
        s.delete()
        messages.success(request, "Deleted successfully")
        return redirect('AssignClass')

class AssignDepartment(AdminRequiredMixin, View):
    def get(self, request):
        dept = departmenttable.objects.all().order_by('-id')
        mentor = mentortable.objects.all()
        obj = dept_assigntable.objects.all()
        return render(
            request,
            'tables/form/assn_dep.html',
            {'dep': dept, 'mt': mentor, 'assign': obj}
        )

    def post(self, request):
        mentor_id = request.POST.get('mentor')
        dept = request.POST.get('dept')
        try:
            dept_assigntable.objects.create(
                mentor_id_id=mentor_id,
                department_id_id=dept
            )
        except IntegrityError:
            messages.error(request, "This mentor is already assigned to that department.")
            return redirect('assn_dep')
        messages.success(request, "Assigned successfully")
        return redirect('assn_dep')

class DeleteAssignDept(AdminRequiredMixin, View):
    def post(self,request,id):
        s=dept_assigntable.objects.get(id=id)
        s.delete()
        messages.success(request, "Deleted successfully")
        return redirect('assn_dep')
#homepage login required
class HomePage(LoginRequiredMixin, AdminRequiredMixin, View):
    def get(self, request):
        from django.db.models import Count
        total_passes = exitpasstable.objects.count()
        pending_passes = exitpasstable.objects.filter(mentor_status='pending').count()
        approved_passes = exitpasstable.objects.filter(mentor_status='approved').count()
        rejected_passes = exitpasstable.objects.filter(
            models.Q(mentor_status='rejected') | models.Q(mentor_status='revoked')
        ).count()
        scanned_passes = exitpasstable.objects.filter(security_status='scanned').count()
        pending_students = studenttable.objects.filter(LOGINID__usertype='pending').count()
        total_students = studenttable.objects.filter(LOGINID__usertype='Student').count()
        total_mentors = mentortable.objects.count()
        return render(request, 'tables/form/homepage.html', {
            'total_passes': total_passes,
            'pending_passes': pending_passes,
            'approved_passes': approved_passes,
            'rejected_passes': rejected_passes,
            'scanned_passes': scanned_passes,
            'pending_students': pending_students,
            'total_students': total_students,
            'total_mentors': total_mentors,
        })

class MentorPendingPasses(MentorRequiredMixin, View):
    def get(self, request):
        user_id = (getattr(request, 'jwt_user_id', None) or request.session.get('user_id'))
        try:
            mentor_obj = mentortable.objects.get(LOGINID_id=user_id)
            assigned_classes = class_assigntable.objects.filter(mentor_id=mentor_obj).values_list('class_id', flat=True)
            pending_passes = exitpasstable.objects.filter(
                mentor_status='pending',
                student_id__classs__id__in=assigned_classes
            ).order_by('-created_at')
        except mentortable.DoesNotExist:
            pending_passes = []
        return render(request, 'tables/form/mentor_pending_passes.html', {'passes': pending_passes, 'mentor': mentor_obj if 'mentor_obj' in locals() else None})

    def post(self, request):
        login_id = request.jwt_user_id or request.session.get('user_id')
        mentor = mentortable.objects.filter(LOGINID_id=login_id).first()
        action = request.POST.get('action')
        scoped_passes = exitpasstable.objects.filter(
            student_id__classs_id__in=class_assigntable.objects.filter(mentor_id=mentor).values('class_id'),
        ) if mentor else exitpasstable.objects.none()
        if action not in ('approve', 'reject'):
            messages.error(request, 'Invalid pass decision.')
        else:
            decision = 'approved' if action == 'approve' else 'rejected'
            try:
                review_pending_pass(
                    scoped_passes, request.POST.get('pass_id'), decision, login_id, mentor,
                    request.POST.get('reject_reason', ''),
                )
            except (ValueError, PermissionError) as exc:
                messages.error(request, str(exc))
            else:
                messages.success(request, f'Pass {decision}.')
        return redirect('MentorPendingPasses')


class MentorApprovedPasses(MentorRequiredMixin, View):
    def get(self, request):
        user_id = (getattr(request, 'jwt_user_id', None) or request.session.get('user_id'))
        try:
            mentor_obj = mentortable.objects.get(LOGINID_id=user_id)
            assigned_classes = class_assigntable.objects.filter(mentor_id=mentor_obj).values_list('class_id', flat=True)
            cutoff = timezone.localtime() - datetime.timedelta(minutes=15)
            approved_passes = exitpasstable.objects.filter(
                mentor_status='approved', security_status='pending',
                student_id__classs__id__in=assigned_classes,
            ).filter(
                Q(created_at__date__gt=cutoff.date())
                | Q(created_at__date=cutoff.date(), time__gt=cutoff.time())
            ).order_by('-approved_at')
        except mentortable.DoesNotExist:
            approved_passes = []
        return render(request, 'tables/form/mentor_approved_passes.html', {'passes': approved_passes, 'mentor': mentor_obj if 'mentor_obj' in locals() else None})

    def post(self, request):
        user_id = (getattr(request, 'jwt_user_id', None) or request.session.get('user_id'))
        pass_id = request.POST.get('pass_id')
        action = request.POST.get('action')

        try:
            mentor_obj = mentortable.objects.get(LOGINID_id=user_id)
            assigned_classes = class_assigntable.objects.filter(mentor_id=mentor_obj).values_list('class_id', flat=True)

            exit_pass = exitpasstable.objects.get(
                id=pass_id,
                mentor_status='approved',
                security_status='pending',
                student_id__classs__id__in=assigned_classes
            )

            if action == 'revoke':
                revoke_reason = request.POST.get('revoke_reason', 'Revoked by mentor')
                updated = exitpasstable.objects.filter(
                    pk=exit_pass.pk, mentor_status='approved', security_status='pending',
                ).update(mentor_status='revoked', reject_reason=revoke_reason[:500])
                if updated:
                    security_log.info('pass_revoked actor=%s pass=%s', user_id, pass_id)
                    messages.success(request, f"Pass for {exit_pass.student_id.name} has been revoked.")
                else:
                    messages.warning(request, 'Pass has already been processed.')

        except (mentortable.DoesNotExist, exitpasstable.DoesNotExist):
            messages.error(request, "Pass not found or unauthorized.")

        return redirect('MentorApprovedPasses')

class MntrHome(MentorRequiredMixin, View):
    def get(self, request):
        user_id = (getattr(request, 'jwt_user_id', None) or request.session.get('user_id'))
        try:
            mentor = mentortable.objects.get(LOGINID_id=user_id)
            assigned_classes = class_assigntable.objects.filter(
                mentor_id=mentor
            ).values_list('class_id', flat=True)
            pending_passes = exitpasstable.objects.filter(
                mentor_status='pending',
                student_id__classs__id__in=assigned_classes
            ).select_related('student_id', 'student_id__classs').order_by('-created_at')[:6]
        except mentortable.DoesNotExist:
            mentor = None
            pending_passes = []
        return render(request, 'tables/form/mntrhome.html', {
            'mentor': mentor,
            'pending_passes': pending_passes,
        })

class MentorProfileUpdate(LoginRequiredMixin, View):
    def get(self, request):
        l_id = (getattr(request, 'jwt_user_id', None) or request.session.get('user_id'))
        try:
            mentor = mentortable.objects.get(LOGINID_id=l_id)
            return render(request, 'tables/form/mentor_profile.html', {'mentor': mentor})
        except mentortable.DoesNotExist:
            return redirect('LoginPage')

    def post(self, request):
        l_id = (getattr(request, 'jwt_user_id', None) or request.session.get('user_id'))
        mentor = mentortable.objects.get(LOGINID_id=l_id)

        name = request.POST.get('name')
        phone = request.POST.get('phone')
        image = request.FILES.get('image')

        if name:
            mentor.name = name
        if phone:
            mentor.phone = phone
        if image:
            mentor.image = image

        mentor.save()
        messages.success(request, "Profile Updated successfully")
        return redirect('MntrHome')

class ManageMentor(AdminRequiredMixin, View):
    def get(self, request):
        q = request.GET.get('q', '').strip()
        mentor = mentortable.objects.all().order_by('-id')
        if q:
            mentor = mentor.filter(
                models.Q(name__icontains=q) |
                models.Q(email__icontains=q) |
                models.Q(department__name__icontains=q)
            )
        departments = departmenttable.objects.all().order_by('name')
        return render(request, 'tables/form/mng_mntr.html', {
            'mentors': mentor,
            'q': q,
            'departments': departments,
        })

class AddMentor(AdminRequiredMixin, View):
    def get(self, request):
        dept = departmenttable.objects.all()
        return render(request, 'tables/form/add_mntr.html', {'depts': dept})

    def post(self, request):
        try:
            mntr = AddMentorForm(request.POST, request.FILES)
            if mntr.is_valid():
                email = request.POST.get('email')
                password = request.POST.get('Password')

                # Validation checks
                if Logintable.objects.filter(username=email).exists():
                     messages.error(request, "Error: Email already registered")
                     return redirect('add_mntr')

                if error := password_errors(password, email):
                     messages.error(request, error)
                     return redirect('add_mntr')

                with transaction.atomic():
                    m = mntr.save(commit=False)
                    # SECURE: Hash password before saving
                    hashed_pwd = make_password(password)
                    l = Logintable.objects.create(username=m.email, password=hashed_pwd, usertype='mentor')
                    m.LOGINID = l
                    m.save()

                messages.success(request, "Mentor registration successful")
                return redirect('mng_mntr')
            else:
                 errors = mntr.errors.as_text().replace('\n', ' ').replace('"', "'")
                 messages.error(request, f"Form Invalid: {errors}")
                 return redirect('add_mntr')
        except Exception as e:
            logger.exception("Error in AddMentor")
            messages.error(request, "Server Error. Please try again.")
            return redirect('add_mntr')

class EditMentor(AdminRequiredMixin, View):
    def get(self,request,id):
        m=mentortable.objects.get(id=id)
        d_qs=departmenttable.objects.all()

        # Prepare data with selected flag to avoid template syntax errors with formatters
        dept_data = []
        mentor_dept_id = m.department.id if m.department else None

        for dept in d_qs:
            dept_data.append({
                'id': dept.id,
                'name': dept.name,
                'selected': dept.id == mentor_dept_id
            })

        return render(request,'tables/form/edit_mentor.html',{'data':dept_data, 'mentor':m})
    def post(self,request,id):
        m=mentortable.objects.get(id=id)
        mt=AddMentorForm(request.POST, request.FILES, instance=m)
        if mt.is_valid():
            password = request.POST.get('password')
            if password and (error := password_errors(password, m.email)):
                messages.error(request, error)
                return redirect('mng_mntr')
            mt.save()
            if password:
                if m.LOGINID:
                    m.LOGINID.password = make_password(password)
                    m.LOGINID.save()
            messages.success(request, "Mentor Updated successfully")
            return redirect('mng_mntr')

class DeleteMentor(AdminRequiredMixin, View):
    def post(self,request,id):
        s=mentortable.objects.get(id=id)
        if s.LOGINID:
            s.LOGINID.delete()
        else:
            s.delete()
        messages.success(request, "Mentor Deleted successfully")
        return redirect('mng_mntr')

class AddDepartment(AdminRequiredMixin, View):
    def get(self,request):
        return render(request,'tables/form/add_dep.html')
    def post(self,request):
        deprt=AddDepartmentForm(request.POST)
        if deprt.is_valid():
            m=deprt.save()
            messages.success(request, "Department Added successfully")
            return redirect('mng_dep')

class DeleteDepartment(AdminRequiredMixin, View):
    def post(self,request,id):
        s=departmenttable.objects.get(id=id)
        s.delete()
        messages.success(request, "Department Deleted successfully")
        return redirect('mng_dep')

class ManageSecurity(AdminRequiredMixin, View):
    def get(self,request):
        security=securitytable.objects.all().order_by('-id')
        return render(request, 'tables/form/mng_security.html',{'securities':security})

class AddSecurity(AdminRequiredMixin, View):
    def get(self,request):
        return render(request,'tables/form/add_security.html')
    def post(self,request):
        try:
            scr=AddSecurityForm(request.POST, request.FILES)
            if scr.is_valid():
                email = request.POST.get('email')
                password = request.POST.get('Password')

                # Validation checks
                if Logintable.objects.filter(username=email).exists():
                     messages.error(request, "Error: Email already registered")
                     return redirect('add_security')

                if error := password_errors(password, email):
                     messages.error(request, error)
                     return redirect('add_security')

                with transaction.atomic():
                    m=scr.save(commit=False)
                    hashed_pwd = make_password(password)
                    l=Logintable.objects.create(username=m.email,password=hashed_pwd,usertype='security')
                    m.LOGINID=l
                    m.save()

                messages.success(request, "Security registration successful")
                return redirect('mng_security')
            else:
                 errors = scr.errors.as_text().replace('\n', ' ').replace('"', "'")
                 messages.error(request, f"Form Invalid: {errors}")
                 return redirect('add_security')
        except Exception as e:
            logger.exception("Error in AddSecurity")
            messages.error(request, "Server Error. Please try again.")
            return redirect('add_security')

class AddClass(AdminRequiredMixin, View):
    def get(self,request):
        obj = departmenttable.objects.all()
        return render(request,'tables/form/add_class.html', {'dept': obj})
    def post(self,request):
        cls=AddClassForm(request.POST)
        if cls.is_valid():
            m=cls.save()
            messages.success(request, "Class Added successfully")
            return redirect('mng_class')

class DeleteClass(AdminRequiredMixin, View):
    def get(self,request,id):
        s=classstable.objects.get(id=id)
        s.delete()
        messages.success(request, "Class Deleted successfully")
        return redirect('mng_class')
#edit security
class EditSecurity(AdminRequiredMixin, View):
    def get(self,request,id):
        s=securitytable.objects.get(id=id)
        return render(request,'tables/form/edit_security.html',{'data':s})
    def post(self,request,id):
        sr=securitytable.objects.get(id=id)
        st=AddSecurityForm(request.POST, request.FILES, instance=sr)
        if st.is_valid():
            password = request.POST.get('password')
            if password and (error := password_errors(password, sr.email)):
                messages.error(request, error)
                return redirect('mng_security')
            st.save()
            if password:
                if sr.LOGINID:
                    sr.LOGINID.password = make_password(password)
                    sr.LOGINID.save()
            messages.success(request, "Security Updated successfully")
            return redirect('mng_security')

#delete security
class DeleteSecurity(AdminRequiredMixin, View):
    def post(self,request,id):
        s=securitytable.objects.get(id=id)
        if s.LOGINID:
            s.LOGINID.delete()
        else:
            s.delete()
        messages.success(request, "Security Deleted successfully")
        return redirect('mng_security')

class AdminPassDecision(AdminRequiredMixin, View):
    decision = None

    def post(self, request, id):
        login_id = request.jwt_user_id or request.session.get('user_id')
        try:
            review_pending_pass(exitpasstable.objects.all(), id, self.decision, login_id)
        except (ValueError, PermissionError) as exc:
            messages.error(request, str(exc))
        else:
            messages.success(request, f'Pass {self.decision}.')
        return redirect('pass')


class Approvepassadmin(AdminPassDecision):
    decision = 'approved'


class Rejectpassadmin(AdminPassDecision):
    decision = 'rejected'


class StudentRegister(View):
    def get(self, request):
        classes = classstable.objects.all()
        return render(request, 'tables/form/student_register.html', {'obj': classes})

    def post(self, request):
        name = request.POST.get('name')
        email = request.POST.get('email')
        admn_no = request.POST.get('admn_no')
        phone = request.POST.get('phone')
        class_id = request.POST.get('classs') # Changed to match HTML form name="classs"
        password = request.POST.get('password')

        if not all([name, email, admn_no, phone, class_id, password]):
            messages.error(request, "All fields are required!")
            return redirect('StudentRegister')

        if not str(admn_no).isdigit() or len(str(admn_no)) != 4:
            messages.error(request, "Admission number must be exactly 4 digits (e.g. 5467).")
            return redirect('StudentRegister')

        if error := password_errors(password, email):
            messages.error(request, error)
            return redirect('StudentRegister')

        if Logintable.objects.filter(username=email).exists() or studenttable.objects.filter(email=email).exists():
            messages.error(request, "Email already registered!")
            return redirect('StudentRegister')

        if studenttable.objects.filter(admn_no=admn_no).exists():
            messages.error(request, "Admission Number already registered!")
            return redirect('StudentRegister')

        try:
            class_obj = classstable.objects.get(id=class_id)
            hashed_pw = make_password(password)

            login_obj = Logintable.objects.create(
                username=email,
                password=hashed_pw,
                usertype='pending'
            )

            studenttable.objects.create(
                name=name,
                email=email,
                admn_no=admn_no,
                phone=phone,
                classs=class_obj,
                LOGINID=login_obj
            )
            messages.success(request, "Registration successful! Please wait for approval.")
            return redirect('login/')
        except Exception as e:
            messages.error(request, 'Unable to complete registration.')
            return redirect('StudentRegister')

class StudentNewPass(StudentRequiredMixin, View):
    def get(self, request):
        user_id = (getattr(request, 'jwt_user_id', None) or request.session.get('user_id'))
        student_obj = studenttable.objects.get(LOGINID_id=user_id)
        return render(request, 'tables/form/student_new_pass.html', {'student': student_obj})

    def post(self, request):
        user_id = (getattr(request, 'jwt_user_id', None) or request.session.get('user_id'))
        try:
            student_obj = studenttable.objects.get(LOGINID_id=user_id)
        except studenttable.DoesNotExist:
            messages.error(request, "Student profile not found.")
            return redirect('StudentHome')

        reason = request.POST.get('reason', '').strip()
        time_str = request.POST.get('time', '').strip()

        if not reason:
            messages.error(request, "Reason is required")
            return redirect('StudentNewPass')
        if len(reason) < 5:
            messages.error(request, "Reason must be at least 5 characters")
            return redirect('StudentNewPass')
        if len(reason) > 500:
            messages.error(request, "Reason must be under 500 characters")
            return redirect('StudentNewPass')
        if not time_str:
            messages.error(request, "Exit time is required")
            return redirect('StudentNewPass')

        try:
            # Parse time from HTML5 time input (HH:MM 24-hour format)
            # The API expects %I:%M %p, but HTML5 form gives %H:%M
            time_obj = datetime.datetime.strptime(time_str, '%H:%M').time()
        except ValueError:
            messages.error(request, "Invalid time format.")
            return redirect('StudentNewPass')

        now_local = timezone.localtime()

        if not mentor_approval_window_open():
            messages.error(request, "Pass applications are only accepted between 10:00 AM and 3:40 PM")
            return redirect('StudentNewPass')

        exit_datetime = datetime.datetime.combine(now_local.date(), time_obj)
        exit_datetime = timezone.make_aware(exit_datetime, timezone.get_current_timezone())

        if exit_datetime <= now_local:
            messages.error(request, "Exit time must be in the future")
            return redirect('StudentNewPass')

        try:
            exit_pass = submit_individual_pass(student_obj, reason, time_obj, now_local)
            try:
                notify_assigned_mentors_about_pass(exit_pass, student_obj, reason)
            except Exception:
                logger.exception("Failed to notify mentors about web pass %s", exit_pass.id)
            messages.success(request, "Pass applied successfully!")
            return redirect('StudentHome')
        except ValueError as exc:
            messages.error(request, str(exc))
            return redirect('StudentNewPass')


class StudentComplaint(StudentRequiredMixin, View):
    def get(self, request):
        user_id = (getattr(request, 'jwt_user_id', None) or request.session.get('user_id'))
        try:
            student_obj = studenttable.objects.get(LOGINID_id=user_id)
            complaints = complainttable.objects.filter(student_id=student_obj).order_by('-id')
        except studenttable.DoesNotExist:
            student_obj = None
            complaints = []
        return render(request, 'tables/form/student_complaint.html', {'student': student_obj, 'complaints': complaints})

    def post(self, request):
        user_id = (getattr(request, 'jwt_user_id', None) or request.session.get('user_id'))
        try:
            student_obj = studenttable.objects.get(LOGINID_id=user_id)
        except studenttable.DoesNotExist:
            messages.error(request, "Student profile not found.")
            return redirect('StudentHome')

        complaint_text = request.POST.get('complaint', '').strip()
        if not complaint_text:
            messages.error(request, "Complaint text cannot be empty.")
            return redirect('StudentComplaint')

        try:
            complainttable.objects.create(
                student_id=student_obj,
                complaint=complaint_text,
                date=timezone.now().date()
            )
            messages.success(request, "Complaint submitted successfully!")
            return redirect('StudentComplaint')
        except Exception as e:
            messages.error(request, 'Unable to submit the complaint.')
            return redirect('StudentComplaint')

class StudentAnnouncements(StudentRequiredMixin, View):
    def get(self, request):
        current_time = timezone.now()
        announcements = announcementtable.objects.filter(is_active=True).filter(
            models.Q(expires_at__isnull=True) | models.Q(expires_at__gt=current_time)
        )
        return render(request, 'tables/form/student_announcements.html', {'announcements': announcements})

class StudentMyPasses(StudentRequiredMixin, View):
    def get(self, request):
        user_id = (getattr(request, 'jwt_user_id', None) or request.session.get('user_id'))
        try:
            student_obj = studenttable.objects.get(LOGINID_id=user_id)
            passes_list = exitpasstable.objects.filter(student_id=student_obj).select_related('mentor_id').order_by('-id')

            # Pagination
            paginator = Paginator(passes_list, 15)
            page_number = request.GET.get('page')
            passes = paginator.get_page(page_number)

            from GateApp.encryption import encrypt_pass_id
            from django.utils import timezone
            import datetime
            now_local = timezone.localtime(timezone.now())
            for p in passes:
                try:
                    pass_date = timezone.localtime(p.created_at).date()
                    exit_dt = timezone.make_aware(datetime.datetime.combine(pass_date, p.time), timezone.get_current_timezone())
                    show_qr_time = exit_dt - datetime.timedelta(minutes=15)
                    p.is_qr_visible = now_local >= show_qr_time
                    if now_local >= exit_dt + datetime.timedelta(minutes=15) and p.security_status == 'pending':
                        p.is_expired = True
                    else:
                        p.is_expired = False
                except Exception:
                    p.is_qr_visible = True
                    p.is_expired = False

                # Only encrypt if the pass is not expired and hasn't been scanned/rejected
                if individual_scan_open(p) and not p.is_group_pass and p.security_status == 'pending' and p.mentor_status == 'approved':
                    p.encrypted_token = encrypt_pass_id(p.id)
                else:
                    p.encrypted_token = None

        except studenttable.DoesNotExist:
            passes = []
        return render(request, 'tables/form/student_my_passes.html', {'passes': passes, 'page_obj': passes if passes else None, 'student': student_obj if 'student_obj' in locals() else None})

    def post(self, request):
        user_id = (getattr(request, 'jwt_user_id', None) or request.session.get('user_id'))
        pass_id = request.POST.get('pass_id')

        try:
            student_obj = studenttable.objects.get(LOGINID_id=user_id)
            exit_pass = exitpasstable.objects.get(id=pass_id, student_id=student_obj)

            if exit_pass.security_status == 'pending' and exit_pass.mentor_status == 'pending':
                if exitpasstable.objects.filter(
                    pk=exit_pass.pk, mentor_status='pending', security_status='pending',
                ).update(mentor_status='cancelled'):
                    security_log.info('pass_cancelled actor=%s pass=%s', user_id, pass_id)
                    messages.success(request, "Pass cancelled successfully.")
                else:
                    messages.warning(request, 'Pass has already been processed.')
            else:
                messages.error(request, "This pass cannot be cancelled.")

        except (studenttable.DoesNotExist, exitpasstable.DoesNotExist):
            messages.error(request, "Pass not found or unauthorized.")

        return redirect('StudentMyPasses')

class StudentHome(StudentRequiredMixin, View):
    def get(self, request):
        user_id = (getattr(request, 'jwt_user_id', None) or request.session.get('user_id'))
        current_time = timezone.now()
        announcements = announcementtable.objects.filter(is_active=True).filter(
            models.Q(expires_at__isnull=True) | models.Q(expires_at__gt=current_time)
        )
        try:
            student = studenttable.objects.get(LOGINID_id=user_id)
            # Fetch recent passes
            recent_passes = exitpasstable.objects.filter(student_id=student).select_related('mentor_id').order_by('-id')[:5]
            # Fetch latest/current pass explicitly
            current_pass = exitpasstable.objects.filter(student_id=student).select_related('mentor_id').order_by('-id').first()
        except studenttable.DoesNotExist:
            student = None
            recent_passes = []
            current_pass = None
        return render(request, 'tables/form/student_home.html', {'student': student, 'recent_passes': recent_passes, 'current_pass': current_pass, 'announcements': announcements})

from django.http import JsonResponse
from GateApp.encryption import encrypt_pass_id, decrypt_pass_id
import qrcode
from io import BytesIO

class WebGenerateQRCode(StudentRequiredMixin, View):
    def get(self, request, token):
        pass_id = decrypt_pass_id(token)
        if not pass_id:
            return HttpResponse("Invalid Token", status=400)
        try:
            exit_pass = exitpasstable.objects.get(id=pass_id, student_id__LOGINID_id=(getattr(request, 'jwt_user_id', None) or request.session.get('user_id')))
            if (exit_pass.is_group_pass or exit_pass.mentor_status != 'approved'
                    or exit_pass.security_status != 'pending' or not individual_scan_open(exit_pass)):
                return HttpResponse('QR code unavailable', status=403)
            qr = qrcode.make(token)
            buffer = BytesIO()
            qr.save(buffer, format="PNG")
            return HttpResponse(buffer.getvalue(), content_type="image/png")
        except exitpasstable.DoesNotExist:
            return HttpResponse("Not Found", status=404)

class WebCheckPassStatus(StudentRequiredMixin, View):
    def get(self, request, token):
        pass_id = decrypt_pass_id(token)
        if not pass_id:
            return JsonResponse({'error': 'Invalid token'}, status=400)
        try:
            exit_pass = exitpasstable.objects.get(id=pass_id, student_id__LOGINID_id=(getattr(request, 'jwt_user_id', None) or request.session.get('user_id')))
            return JsonResponse({'security_status': exit_pass.security_status})
        except exitpasstable.DoesNotExist:
            return JsonResponse({'error': 'Not found'}, status=404)

class WebGetPassDetails(SecurityRequiredMixin, View):
    def post(self, request):
        token = request.POST.get('token')
        if not token:
            return JsonResponse({'success': False, 'message': 'No token provided'})

        guard_id = request.jwt_user_id or request.session.get('user_id')
        guard_key = f'scan_rate_{guard_id}'
        cache.add(guard_key, 0, timeout=60)
        try:
            attempts = cache.incr(guard_key)
        except ValueError:
            attempts = 1
        if attempts > 30:
            return JsonResponse({'success': False, 'message': 'Too many scan attempts.'}, status=429)

        pass_id = decrypt_pass_id(token)
        if not pass_id:
            return JsonResponse({'success': False, 'message': 'Invalid, forged, or expired QR Code'})
        try:
            exit_pass = exitpasstable.objects.get(id=pass_id)

            if (exit_pass.is_group_pass or exit_pass.mentor_status != 'approved'
                    or (exit_pass.security_status == 'pending' and not individual_scan_open(exit_pass))):
                return JsonResponse({'success': False, 'message': 'Pass is outside its scan window or unavailable.'})

            mentor_name = exit_pass.mentor_id.name if exit_pass.mentor_id else 'Unknown'

            message = 'Success'
            if exit_pass.mentor_status == 'cancelled':
                return JsonResponse({'success': False, 'message': 'Pass was cancelled by the student.'})
            elif exit_pass.mentor_status == 'revoked':
                return JsonResponse({'success': False, 'message': f'Pass Revoked by Mentor: {exit_pass.reject_reason}'})

            return JsonResponse({
                'success': True,
                'pass_token': token,           # Return the token, NOT the raw integer pass_id
                'student_name': exit_pass.student_id.name,
                'student_photo': exit_pass.student_id.Photo.url if exit_pass.student_id.Photo else None,
                'mentor_name': mentor_name,
                'time': exit_pass.time.strftime('%I:%M %p') if exit_pass.time else '',
                'date': exit_pass.created_at.strftime('%Y-%m-%d') if exit_pass.created_at else '',
                'mentor_status': exit_pass.mentor_status,
                'security_status': exit_pass.security_status,
            })
        except exitpasstable.DoesNotExist:
            return JsonResponse({'success': False, 'message': 'Pass not found'})

class SecurityScanPass(SecurityRequiredMixin, View):
    def post(self, request):
        token = request.POST.get('token')
        action = request.POST.get('action', 'approve')
        if not token or action not in ('approve', 'reject'):
            return JsonResponse({'success': False, 'message': 'Invalid scan request.'})
        pass_id = decrypt_pass_id(token)
        if not pass_id:
            return JsonResponse({'success': False, 'message': 'Invalid or expired QR code.'})
        login_id = request.jwt_user_id or request.session.get('user_id')
        try:
            process_individual_scan(login_id, pass_id, action)
        except PermissionError:
            return JsonResponse({'success': False, 'message': 'Forbidden'}, status=403)
        except ValueError as exc:
            return JsonResponse({'success': False, 'message': str(exc)})
        return JsonResponse({'success': True, 'message': 'Gate decision recorded.'})


class SecurityHome(SecurityRequiredMixin, View):
    def get(self, request):
        user_id = (getattr(request, 'jwt_user_id', None) or request.session.get('user_id'))
        try:
            security_guard = securitytable.objects.get(LOGINID_id=user_id)
            # Fetch recently scanned passes for today
            today_start = timezone.localtime().replace(hour=0, minute=0, second=0, microsecond=0)
            recent_scans = exitpasstable.objects.filter(
                security_status='scanned',
                scanned_at__gte=today_start
            ).order_by('-id')[:10]
        except securitytable.DoesNotExist:
            security_guard = None
            recent_scans = []
        return render(request, 'tables/form/security_home.html', {'security': security_guard, 'recent_scans': recent_scans})


#/////////////////////////////////////////////////////API/////////////////////////////////////////////
from django.conf import settings
from django.http import JsonResponse
from django.views import View
from django.http import HttpResponse
from django.utils import timezone
from django.core.files import File
from io import BytesIO
import json
import qrcode
from rest_framework.views import APIView
from rest_framework.decorators import api_view, authentication_classes, permission_classes
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import IsAuthenticated, AllowAny, BasePermission
from rest_framework_simplejwt.authentication import JWTAuthentication
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.exceptions import InvalidToken, TokenError
from GateApp.throttles import (
    LoginRateThrottle,
    SignupRateThrottle,
    PasswordResetThrottle,
    AuthenticatedAPIThrottle,
)
from django.core.mail import send_mail
from django.shortcuts import redirect
from django.contrib import messages
# -- JWT Auth Mixin --------------------------------------------------------------

class IsTokenAuthenticated(BasePermission):
    """
    Allows access only to authenticated users via JWT.
    Does not require a Django User object to exist in the database.
    """
    def has_permission(self, request, view):
        return bool(request.auth and 'login_id' in request.auth)

class QuietJWTAuthentication(JWTAuthentication):
    def authenticate(self, request):
        header = self.get_header(request)
        if header is None:
            # Fallback for servers that strip Authorization header (e.g. PythonAnywhere/Apache)
            x_auth = request.headers.get('X-Authorization')
            if x_auth:
                if isinstance(x_auth, str):
                    x_auth = x_auth.encode('utf-8')
                header = x_auth
            else:
                return None

        raw_token = self.get_raw_token(header)
        if raw_token is None:
            return None

        validated_token = self.get_validated_token(raw_token)
        return self.get_user(validated_token), validated_token

    def get_user(self, validated_token):
        try:
            user = active_token_user(validated_token)
        except TokenError as exc:
            raise InvalidToken('Account session has expired') from exc
        user.is_authenticated = True
        user.is_active = True
        return user


class JWTAuthMixin:
    authentication_classes = [QuietJWTAuthentication]
    permission_classes = [IsTokenAuthenticated]
    throttle_classes = [AuthenticatedAPIThrottle]

    def dispatch(self, request, *args, **kwargs):
        return super().dispatch(request, *args, **kwargs)


class PingAPI(APIView):
    """Health-check endpoint. Restricted to authenticated requests only."""
    permission_classes = [IsTokenAuthenticated]
    authentication_classes = [QuietJWTAuthentication]
    def get(self, request):
        return Response({"status": "online"})

#user registration api for student (public -- no token required, rate limited)
class UserReg_api(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []
    throttle_classes = [SignupRateThrottle]
    def get(self, request):
        classes = classstable.objects.all()
        class_serializer = ClassSerializer(classes, many=True)
        return Response(class_serializer.data, status=status.HTTP_200_OK)

    def post(self, request):
        user_serial = StudentSerializer(data=request.data)
        login_serial = LoginSerializer(data=request.data)

        data_valid = user_serial.is_valid()
        login_valid = login_serial.is_valid()

        if data_valid and login_valid:
            email = request.data.get('email')
            admn_no = request.data.get('admn_no')

            if Logintable.objects.filter(username=email).exists():
                return Response({"message": "Email already registered"}, status=status.HTTP_400_BAD_REQUEST)

            if studenttable.objects.filter(email=email).exists():
                return Response({"message": "Email already registered"}, status=status.HTTP_400_BAD_REQUEST)

            if studenttable.objects.filter(admn_no=admn_no).exists():
                return Response({"message": "Admission Number already registered"}, status=status.HTTP_400_BAD_REQUEST)

            if not str(admn_no).isdigit() or len(str(admn_no)) != 4:
                return Response({"message": "Admission number must be exactly 4 digits"}, status=status.HTTP_400_BAD_REQUEST)

            password = request.data.get('password')
            if error := password_errors(password, email):
                return Response({"message": error}, status=status.HTTP_400_BAD_REQUEST)
            hashed_pw = make_password(password)

            login_profile = login_serial.save(
                usertype='pending',
                username=email,
                password=hashed_pw
            )

            user_serial.save(LOGINID=login_profile)

            return Response(user_serial.data, status=status.HTTP_201_CREATED)
        return Response({
            'login_error': login_serial.errors if not login_valid else None,
            'user.error': user_serial.errors if not data_valid else None,
        }, status=status.HTTP_400_BAD_REQUEST)


#login api for student, mentor, security (public -- issues JWT tokens, rate limited)
class LoginpageAPI(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []
    throttle_classes = [LoginRateThrottle]
    def post(self, request):
        username = request.data.get("username")
        password = request.data.get("password")

        if not username or not password:
            return Response(
                {"message": "Username and Password required"},
                status=status.HTTP_400_BAD_REQUEST
            )

        t_user = Logintable.objects.filter(username=username).first()

        if not t_user or not check_password(password, t_user.password):
            return Response(
                {"message": "Invalid Username or Password"},
                status=status.HTTP_401_UNAUTHORIZED
            )

        if t_user.usertype not in ACTIVE_ROLES:
            return Response(
                {"message": "Account not verified. Contact admin.", "usertype": t_user.usertype},
                status=status.HTTP_403_FORBIDDEN
            )

        refresh = create_login_tokens(t_user)

        access = refresh.access_token
        access['login_id'] = t_user.id
        access['user_id'] = t_user.id
        access['usertype'] = t_user.usertype

        response = Response({
            "message": "success",
            "login_id": t_user.id,
            "usertype": t_user.usertype,
            "access": str(access),
            "refresh": str(refresh),
        }, status=status.HTTP_200_OK)

        logger.info("Login successful for login_id=%s usertype=%s", t_user.id, t_user.usertype)
        return response


class WebTokenRefresh(APIView):
    """Rotate the HttpOnly refresh cookie and return a new short-lived access token."""
    permission_classes = [AllowAny]
    authentication_classes = []

    def post(self, request):
        raw_refresh = request.COOKIES.get('refresh_token')
        if not raw_refresh:
            return Response({'detail': 'Refresh token is required.'}, status=status.HTTP_401_UNAUTHORIZED)

        try:
            refresh = rotate_refresh_token(raw_refresh)
        except Exception:
            response = Response({'detail': 'Refresh token is invalid or expired.'}, status=status.HTTP_401_UNAUTHORIZED)
            delete_auth_cookies(response)
            return response

        response = Response(status=status.HTTP_204_NO_CONTENT)
        set_auth_cookies(response, refresh.access_token, refresh)
        return response


class MobileTokenRefresh(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []

    def post(self, request):
        raw_token = request.data.get('refresh')
        if not isinstance(raw_token, str) or not raw_token:
            return Response({'detail': 'Refresh token required.'}, status=400)
        try:
            refresh = rotate_refresh_token(raw_token)
        except (TokenError, KeyError):
            return Response({'detail': 'Session has expired.'}, status=401)
        return Response({'access': str(refresh.access_token), 'refresh': str(refresh)})

    def delete(self, request):
        raw_token = request.data.get('refresh')
        if isinstance(raw_token, str) and raw_token:
            try:
                refresh = RefreshToken(raw_token)
                refresh.blacklist()
                device_token = request.data.get('device_token')
                if isinstance(device_token, str) and len(device_token) <= 255:
                    MentorDeviceToken.objects.filter(
                        mentor__LOGINID_id=refresh.get('login_id'), device_token=device_token,
                    ).delete()
            except TokenError:
                pass
        return Response(status=204)


#apply pass api for student
class ApplypassAPI(JWTAuthMixin, APIView):
    def get(self, request, lid):
        if str(lid) != str(request.auth.get('login_id')):
            return Response({'error': 'Unauthorized'}, status=403)

        student_obj = studenttable.objects.get(LOGINID_id=lid)
        obj = exitpasstable.objects.filter(student_id_id=student_obj).order_by('-id')
        serializer = ExitpassSerializer(obj,many=True)
        return Response(serializer.data, status=status.HTTP_200_OK)

    def post(self, request, lid):
        if str(lid) != str(request.auth.get('login_id')):
            return Response({'error': 'Unauthorized'}, status=403)
        try:
            reason = request.data.get('reason', '').strip()
            time_str = request.data.get('time', '').strip()

            # ── Server-side validation ──
            if not reason:
                return Response({"error": "Reason is required"}, status=status.HTTP_400_BAD_REQUEST)
            if len(reason) < 5:
                return Response({"error": "Reason must be at least 5 characters"}, status=status.HTTP_400_BAD_REQUEST)
            if len(reason) > 500:
                return Response({"error": "Reason must be under 500 characters"}, status=status.HTTP_400_BAD_REQUEST)
            if not time_str:
                return Response({"error": "Exit time is required"}, status=status.HTTP_400_BAD_REQUEST)

            try:
                time_obj = datetime.datetime.strptime(time_str, '%I:%M %p').time()
            except ValueError:
                return Response({"error": "Invalid time format. Expected HH:MM AM/PM"}, status=status.HTTP_400_BAD_REQUEST)

            # ── Ensure exit time is in the future ──
            now_local = timezone.localtime()
            exit_datetime = datetime.datetime.combine(now_local.date(), time_obj)
            exit_datetime = timezone.make_aware(exit_datetime, timezone.get_current_timezone())
            if exit_datetime <= now_local:
                return Response({"error": "Exit time must be in the future"}, status=status.HTTP_400_BAD_REQUEST)

            if not mentor_approval_window_open():
                return Response({'error': 'Pass applications are only accepted between 10:00 AM and 3:40 PM'}, status=400)
            student_obj = get_object_or_404(studenttable, LOGINID_id=lid)
            try:
                exit_pass = submit_individual_pass(student_obj, reason, time_obj, now_local)
            except ValueError as exc:
                return Response({'error': str(exc)}, status=409)
            try:
                notify_assigned_mentors_about_pass(exit_pass, student_obj, reason)
            except Exception:
                logger.exception('Failed to notify mentors about pass %s', exit_pass.pk)

            return Response(
                {"message": "Pass applied successfully"},
                status=status.HTTP_201_CREATED
            )

        except Exception as e:
            logger.exception("ERROR in ApplypassAPI: %s", type(e).__name__)
            return Response(
                {"error": "Unable to complete the request."},
                status=status.HTTP_400_BAD_REQUEST
            )

#student info api
class StudentInfo_api(JWTAuthMixin, APIView):
    def get(self, request, lid):
        try:
            auth_lid = request.auth.get('login_id')


            if auth_lid is None:
                return Response({'error': 'Token missing login_id. Please re-login.'}, status=403)

            if str(lid) != str(auth_lid):

                return Response({'error': 'Unauthorized: ID mismatch'}, status=403)

            student_obj = studenttable.objects.get(LOGINID_id=lid)
            serializer = StudentSerializer1(student_obj)
            return Response(serializer.data, status=status.HTTP_200_OK)

        except studenttable.DoesNotExist:
            logger.warning("StudentInfo_api: Student not found for LOGINID_id=%s", lid)
            return Response({'error': 'Student profile not found'}, status=404)
        except Exception as e:
            logger.exception("StudentInfo_api Error")
            return Response({'error': 'Unable to complete the request.'}, status=500)


#view complaint and view reply api for student
class ViewcomplaintAPI(JWTAuthMixin, APIView):
    def get(self,request,lid):
        if request.auth.get("usertype") != "Student" or request.auth.get("login_id") != lid:
            return Response({"error": "Forbidden"}, status=403)
        complaint = complainttable.objects.filter(student_id__LOGINID__id=lid).order_by('-id')
        complaint_serial = ComplaintSerializer(complaint,many=True)
        return Response(complaint_serial.data,status=status.HTTP_200_OK)
    def post(self,request,lid):
        if request.auth.get("usertype") != "Student" or request.auth.get("login_id") != lid:
            return Response({"error": "Forbidden"}, status=403)
        user = studenttable.objects.get(LOGINID__id = lid)
        complaint_serial = ComplaintSerializer(data=request.data)

        if complaint_serial.is_valid():
            complaint_serial.save(student_id = user)
            return Response({'status':'Complaint sent Successfully'},status=status.HTTP_201_CREATED)
        else:
            return Response({'status':'Complaint sending Failed','errors': complaint_serial.errors},status=status.HTTP_400_BAD_REQUEST)

#exit pass timeline api for student
class ExitPassTimelineAPI(JWTAuthMixin, APIView):
    def get(self, request, lid):
        if str(lid) != str(request.auth.get('login_id')):
            return Response({'error': 'Unauthorized'}, status=403)
        try:

            # Get latest pass for the student
            exit_pass = exitpasstable.objects.filter(
                student_id__LOGINID__id=lid
            ).order_by('-id').first()

            if not exit_pass:
                return Response(
                    {'message': 'No pass found', 'id': -1},
                    status=status.HTTP_200_OK
                )

            serializer = ExitpassSerializer(exit_pass)
            return Response(serializer.data, status=status.HTTP_200_OK)

        except Exception as e:
            return Response(
                {'error': 'Unable to complete the request.'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

#mentor info api
class Mentorinfo_api(JWTAuthMixin, APIView):
    def get(self, request, lid):
        if str(lid) != str(request.auth.get('login_id')):
            return Response({'error': 'Unauthorized'}, status=403)
        mentor_obj = mentortable.objects.get(LOGINID_id=lid)
        serializer = MentorSerializer(mentor_obj)
        return Response(serializer.data, status=status.HTTP_200_OK)

#mentor dashboard statistics api (optimized for performance)
class MentorDashboardStatsAPI(JWTAuthMixin, APIView):
    def get(self, request, lid):
        if str(lid) != str(request.auth.get('login_id')):
            return Response({'error': 'Unauthorized'}, status=403)
        """
        Optimized API to fetch mentor dashboard statistics.
        Returns count of processed passes and pending passes.
        This replaces the heavy counting logic that was previously in LoginpageAPI.
        """
        from django.db.models import Count, Q

        try:
            # Get mentor object with optimized select_related
            mentor = mentortable.objects.select_related('LOGINID').get(LOGINID_id=lid)

            # Get assigned classes (optimized with values_list)
            assigned_classes = class_assigntable.objects.filter(
                mentor_id=mentor
            ).values_list('class_id', flat=True)

            # Optimized count query using aggregation
            stats = exitpasstable.objects.filter(
                Q(mentor_id=mentor) |  # Passes assigned to this mentor
                Q(mentor_status='pending', student_id__classs__id__in=assigned_classes)  # Pending from assigned classes
            ).aggregate(
                total_count=Count('id'),
                pending_count=Count('id', filter=Q(mentor_status='pending'))
            )

            return Response({
                "count": stats['total_count'] or 0,
                "pending_count": stats['pending_count'] or 0
            }, status=status.HTTP_200_OK)

        except mentortable.DoesNotExist:
            return Response(
                {"error": "Mentor not found"},
                status=status.HTTP_404_NOT_FOUND
            )
        except Exception as e:
            logger.exception("Error in MentorDashboardStatsAPI")
            return Response(
                {"error": "Failed to fetch statistics"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

#pending pass list for mentor
class Pendingpass_api(JWTAuthMixin, APIView):
    def get(self,request,lid):
        if request.auth.get('usertype') != 'mentor' or request.auth.get('login_id') != lid:
            return Response({'error': 'Forbidden'}, status=403)

        mentor_obj = mentortable.objects.get(LOGINID_id=lid)
        assigned_classes = class_assigntable.objects.filter(mentor_id=mentor_obj).values_list('class_id', flat=True)
        pending = exitpasstable.objects.filter(mentor_status='pending', created_at__gte=threshold, student_id__classs__id__in=assigned_classes)
        pending_serial = ExitpassSerializer(pending,many=True)
        return Response(pending_serial.data,status=status.HTTP_200_OK)


#approve pass api for mentor
def review_pending_pass(passes, pass_id, decision, login_id, mentor=None, reason=''):
    if type(pass_id) not in (str, int) or not str(pass_id).isascii() or not str(pass_id).isdigit() or len(str(pass_id)) > 18:
        raise ValueError('Invalid pass ID.')
    if not isinstance(reason, str) or len(reason) > 500:
        raise ValueError('Invalid rejection reason.')
    changes = {'mentor_id': mentor, 'mentor_status': decision}
    if decision == 'approved':
        changes['approved_at'] = timezone.now()
    else:
        changes['reject_reason'] = reason
    eligible = passes.filter(id=pass_id, mentor_status='pending', security_status='pending')
    with transaction.atomic():
        exit_pass = eligible.select_for_update().first()
        if exit_pass is None:
            raise PermissionError('No pending pass within your scope.')
        if pass_expired(exit_pass) or eligible.update(**changes) != 1:
            raise ValueError('Pass has expired or been processed.')
        transaction.on_commit(lambda: security_log.info(
            'pass_decision actor=%s pass=%s decision=%s', login_id, pass_id, decision,
        ))


class MentorPassDecisionAPI(JWTAuthMixin, APIView):
    decision = None

    def post(self, request):
        login_id = request.auth.get('login_id')
        if request.auth.get('usertype') != 'mentor':
            return Response({'error': 'Forbidden'}, status=403)
        mentor = mentortable.objects.filter(LOGINID_id=login_id).first()
        if mentor is None:
            return Response({'error': 'Forbidden'}, status=403)
        classes = class_assigntable.objects.filter(mentor_id=mentor).values('class_id')
        passes = exitpasstable.objects.filter(student_id__classs_id__in=classes)
        try:
            review_pending_pass(
                passes, request.data.get('pass_id'), self.decision, login_id, mentor,
                request.data.get('reason', ''),
            )
        except PermissionError as exc:
            return Response({'error': str(exc)}, status=403)
        except ValueError as exc:
            return Response({'error': str(exc)}, status=409)
        return Response({'message': f'Pass {self.decision} successfully.'})


class ApproveExitPassAPI(MentorPassDecisionAPI):
    decision = 'approved'


class RejectExitPassAPI(MentorPassDecisionAPI):
    decision = 'rejected'


class CheckPassStatus(JWTAuthMixin, APIView):
    def post(self, request):
        if request.auth.get('usertype') != 'security':
            return Response({'error': 'Forbidden'}, status=403)
        token = request.data.get("token")
        pass_id = decrypt_pass_id(token) if token else None
        if not pass_id:
            return Response({"error": "Invalid QR code"}, status=400)

        try:
            exit_pass = exitpasstable.objects.select_related(
                'student_id', 'student_id__classs', 'mentor_id'
            ).get(id=pass_id)
            if not individual_scan_open(exit_pass) and exit_pass.security_status == 'pending':
                return Response(
                    {"error": "This pass has expired and cannot be scanned."},
                    status=status.HTTP_410_GONE,
                )
            if exit_pass.mentor_status != 'approved':
                return Response(
                    {"error": "This pass has not been approved by a mentor."},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            student_class = exit_pass.student_id.classs.class_name if exit_pass.student_id.classs else '-'
            return Response({
                "pass_id": exit_pass.id,
                "name": exit_pass.student_id.name,
                "reason": exit_pass.reason or '-',
                "time": exit_pass.time.strftime("%I:%M %p") if exit_pass.time else '-',
                "approved_at": exit_pass.approved_at,
                "class": student_class,
                "mentor": exit_pass.mentor_id.name if exit_pass.mentor_id else 'Unknown',
                "security_status": exit_pass.security_status,
                "mentor_status": exit_pass.mentor_status
            }, status=200)
        except (exitpasstable.DoesNotExist, TypeError, ValueError):
            return Response({"error": "Pass not found"}, status=404)

#student list api for mentor class wise display
class StudentListAPI(JWTAuthMixin, APIView):
    def get(self, request, lid):
        if str(lid) != str(request.auth.get('login_id')):
            return Response({'error': 'Unauthorized'}, status=403)
        mentor_obj = mentortable.objects.get(LOGINID_id=lid)
        assigned_classes = class_assigntable.objects.filter(mentor_id=mentor_obj).values_list('class_id', flat=True)
        students = studenttable.objects.filter(classs__id__in=assigned_classes).select_related('classs', 'classs__department_id')
        from collections import defaultdict
        students_by_class = defaultdict(list)

        for student in students:
            class_name = student.classs.class_name if student.classs else "No Class"
            students_by_class[class_name].append({
                'id': student.id,
                'name': student.name,
                'email': student.email,
                'admn_no': student.admn_no,
                'phone': student.phone,
                'Photo': student.Photo.url if student.Photo else None,
                'class_name': class_name,
                'department': student.classs.department_id.name if student.classs and student.classs.department_id else None
            })
        result = []
        for class_name, student_list in students_by_class.items():
            result.append({
                'class_name': class_name,
                'student_count': len(student_list),
                'students': student_list
            })
        return Response(result, status=status.HTTP_200_OK)

#group pass api for mentor
class GroupPassAPI(JWTAuthMixin, APIView):
    def post(self, request, lid):
        if request.auth.get('usertype') != 'mentor' or request.auth.get('login_id') != lid:
            return Response({'error': 'Forbidden'}, status=403)
        try:
            student_ids = request.data.get('student_ids', [])
            reason = request.data.get('reason', 'Group Pass')
            if not isinstance(student_ids, list) or not student_ids:
                return Response({'error': 'Select at least one student'}, status=400)

            if not mentor_approval_window_open():
                return Response(
                    {'error': 'Group pass approvals are only allowed between 10:00 AM and 3:40 PM'},
                    status=400,
                )

            try:
                mentor = mentortable.objects.get(LOGINID_id=lid)
            except mentortable.DoesNotExist:
                return Response({'error': 'Mentor not found'}, status=404)

            now = timezone.localtime()
            current_time = now.time()
            student_ids = list(dict.fromkeys(student_ids))
            assigned_class_ids = set(
                class_assigntable.objects.filter(
                    mentor_id=mentor
                ).values_list('class_id', flat=True)
            )
            students = list(
                studenttable.objects.filter(
                    id__in=student_ids,
                    classs_id__in=assigned_class_ids, LOGINID__usertype='Student',
                )
            )
            if len(students) != len(student_ids):
                return Response(
                    {'error': 'One or more selected students are not assigned to this mentor.'},
                    status=400,
                )

            with transaction.atomic():
                exitpasstable.objects.bulk_create([
                    exitpasstable(
                        student_id=student,
                        mentor_id=mentor,
                        reason=reason,
                        time=current_time,
                        mentor_status='approved',
                        security_status='pending',
                        approved_at=now,
                        is_group_pass=True,
                    )
                    for student in students
                ])

            return Response(
                {'message': f'Group Pass Approved for {len(students)} students'},
                status=200,
            )

        except Exception as e:
            return Response({'error': 'Invalid request.'}, status=400)


#mentor exit report api
class MentorExitReportAPI(JWTAuthMixin, APIView):
    def get(self, request, lid):
        if str(lid) != str(request.auth.get('login_id')):
            return Response({'error': 'Unauthorized'}, status=403)
        try:
            # Verify mentor exists
            try:
                mentor = mentortable.objects.get(LOGINID_id=lid)
            except mentortable.DoesNotExist:
                return Response({'error': 'Mentor not found'}, status=404)

            # Get query parameters for filtering
            search_name = request.GET.get('search', '').strip()
            class_filter = request.GET.get('class', '').strip()
            date_filter = request.GET.get('date', '').strip()  # Expected format: YYYY-MM-DD

            # --- 1. Get assigned classes for this mentor ---
            assigned_classes_ids = class_assigntable.objects.filter(mentor_id=mentor).values_list('class_id', flat=True)


            # If no classes assigned, return empty results immediately
            if not assigned_classes_ids:

                 return Response({
                    'passes': [],
                    'classes': []
                })

            # Base query: passes from assigned classes where the MENTOR has taken action
            from django.db.models import Q
            passes = exitpasstable.objects.filter(
                student_id__classs__id__in=assigned_classes_ids
            ).filter(
                Q(mentor_status='approved') | Q(mentor_status='rejected')
            ).select_related(
                'student_id',
                'student_id__classs',
                'student_id__classs__department_id'
            )

            # --- 3. Apply Filters ---

            # Search by Student Name
            if search_name:
                passes = passes.filter(student_id__name__icontains=search_name)

            # Filter by Class Name
            if class_filter and class_filter != 'All Classes':
                 passes = passes.filter(student_id__classs__class_name__iexact=class_filter)

            # Filter by Date (scanned_at)
            if date_filter:
                try:
                    from datetime import datetime
                    # Parse YYYY-MM-DD
                    filter_date_obj = datetime.strptime(date_filter, '%Y-%m-%d').date()
                    # Filter matching date part of created_at datetime
                    passes = passes.filter(created_at__date=filter_date_obj)
                except ValueError:
                    print(f"Invalid date format received: {date_filter}")
                    # Optionally handle error or just ignore invalid date

            # Order by most recent request
            passes = passes.order_by('-created_at')

            # --- 4. Serialize Data ---
            data = []
            for p in passes:
                # Safety checks for related objects
                curr_student = p.student_id
                curr_class = curr_student.classs if curr_student else None
                curr_dept = curr_class.department_id if curr_class else None

                # CRITICAL: Convert to local timezone before formatting
                local_time = timezone.localtime(p.created_at) if p.created_at else None

                display_time = local_time.strftime('%I:%M %p') if local_time else '-'
                display_date = local_time.strftime('%d-%m-%Y') if local_time else '-'

                data.append({
                    'id': p.id,
                    'student_name': curr_student.name if curr_student else 'Unknown',
                    'department': curr_dept.name if curr_dept else '-',
                    'class': curr_class.class_name if curr_class else '-',
                    'date': display_date,
                    'time': display_time,
                    'status': 'Exited',
                    'reason': p.reason or '-',
                    'mentor_status': p.mentor_status or '-',
                    'security_status': p.security_status or '-'
                })

            # --- 5. Get Filter Options (Classes) ---
            # Get distinct class names assigned to this mentor
            class_options = classstable.objects.filter(
                id__in=assigned_classes_ids
            ).values_list('class_name', flat=True).distinct()

            # Filter out None/Empty and sort
            class_options_list = sorted([str(c).strip() for c in class_options if c])

            return Response({
                'passes': data,
                'classes': class_options_list
            })

        except Exception as e:
            logger.exception("Error in MentorExitReportAPI")
            return Response({'error': 'Unable to complete the request.'}, status=500)

#generate qr code for exit pass 15mins delayed
class GenerateQRCodeAPI(JWTAuthMixin, APIView):
    def post(self, request):
        pass_id = request.data.get("pass_id")

        try:
            exit_pass = exitpasstable.objects.select_related(
                "student_id", "student_id__classs"
            ).get(id=pass_id)
        except exitpasstable.DoesNotExist:
            return Response({"error": "Pass not found"}, status=404)

        if str(exit_pass.student_id.LOGINID_id) != str(request.auth.get('login_id')):
            return Response({"error": "Unauthorized"}, status=403)

        # Group passes don't need QR codes
        if exit_pass.is_group_pass:
            return Response({
                "error": "QR code not required",
                "message": "This is a group pass. No QR code needed - security will approve directly."
            }, status=400)

        # Check if pass is approved
        if exit_pass.mentor_status != "approved":
            return Response({"error": "Pass not approved yet"}, status=400)

        # Check if pass is already scanned or rejected
        if exit_pass.security_status in ["scanned", "rejected"]:
            return Response({"error": "Pass already processed"}, status=400)

        now = timezone.localtime()

        exit_datetime = datetime.datetime.combine(
            timezone.localtime(exit_pass.created_at).date(),
            exit_pass.time
        )
        exit_datetime = timezone.make_aware(exit_datetime, timezone.get_current_timezone())

        time_until_exit = (exit_datetime - now).total_seconds() / 60

        if time_until_exit > 15:
            minutes_remaining = int(time_until_exit)
            minutes_until_available = minutes_remaining - 15
            return Response({
                "error": "QR code not yet available",
                "message": f"QR code will be available in {minutes_until_available} minutes (15 min before your exit time)",
                "minutes_remaining": minutes_until_available,
                "exit_time": exit_pass.time.strftime("%I:%M %p")
            }, status=403)

        if time_until_exit <= -15:
            return Response({
                "error": "QR code expired",
                "message": "QR code is no longer available 15 minutes after the requested exit time",
            }, status=400)

        # Keep the app QR payload identical to the web student QR payload.
        token = encrypt_pass_id(exit_pass.id)
        qr = qrcode.make(token)
        buffer = BytesIO()
        qr.save(buffer, format="PNG")
        buffer.seek(0)

        filename = f"exitpass_{exit_pass.id}.png"
        exit_pass.qrcode.save(filename, File(buffer), save=True)

        return Response({
            "message": "QR code generated successfully",
            "qrcode_url": exit_pass.qrcode.url
        }, status=200)

#list passes for security,mentor approved
class SecurityApprovedPassAPI(JWTAuthMixin, APIView):
    def get(self, request, lid):
        if request.auth.get('usertype') != 'security':
            return Response({'error': 'Forbidden'}, status=403)
        if str(lid) != str(request.auth.get('login_id')):
            return Response({'error': 'Unauthorized'}, status=403)
        passes = exitpasstable.objects.filter(
            mentor_status='approved',  # not scanned yet
            security_status='pending',
        ).select_related('student_id')

        data = []
        for p in passes:
            data.append({
                'id': p.id,
                'name': p.student_id.name,
                'reason': p.reason,
                'date': p.created_at,
                'time': p.time.strftime("%I:%M %p"),
                'security_status': p.security_status,
            })

        return Response(data)

#security info api
class Securityinfo_api(JWTAuthMixin, APIView):
    def get(self, request, lid):
        if str(lid) != str(request.auth.get('login_id')):
            return Response({'error': 'Unauthorized'}, status=403)
        security_obj = securitytable.objects.get(LOGINID_id=lid)
        serializer = SecuritySerializer(security_obj)
        return Response(serializer.data, status=status.HTTP_200_OK)

#get all passes for mentor analytics api
class getallpasses(JWTAuthMixin, APIView):
    def get(self, request, lid):
        if str(lid) != str(request.auth.get('login_id')):
            return Response({'error': 'Unauthorized'}, status=403)
        mentor_obj = mentortable.objects.get(LOGINID_id=lid)
        assigned_classes = class_assigntable.objects.filter(
            mentor_id=mentor_obj
        ).values_list('class_id', flat=True)
        threshold = timezone.now() - datetime.timedelta(hours=24)
        security_obj = exitpasstable.objects.filter(
            models.Q(mentor_id=mentor_obj) |
            models.Q(
                mentor_status='pending',
                student_id__classs__id__in=assigned_classes,
            ),
            created_at__gte=threshold,
        ).order_by('-created_at')

        serializer = ExitpassSerializer1(security_obj,many=True)
        return Response(serializer.data, status=status.HTTP_200_OK)

#forget password api
class ForgetPassword(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []
    throttle_classes = [PasswordResetThrottle]

    def post(self, request):
        email = request.data.get('Email')
        if not isinstance(email, str) or not email.strip():
            return Response({'error': 'Email required.'}, status=400)
        issue_password_reset(email.strip())
        return Response({'message': RESET_RESPONSE})


class ResetPasswordAPI(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []
    throttle_classes = [PasswordResetThrottle]

    def post(self, request):
        password = request.data.get('new_password')
        if not isinstance(password, str):
            return Response({'error': 'New password required.'}, status=400)
        try:
            if not complete_password_reset(request.data.get('email'), request.data.get('otp'), password):
                raise ValidationError('Invalid or expired code.')
        except ValidationError as exc:
            return Response({'error': ' '.join(exc.messages)}, status=400)
        return Response({'message': 'Password reset successfully.'})


def process_individual_scan(login_id, pass_id, action):
    guard = securitytable.objects.filter(LOGINID_id=login_id).first()
    if guard is None:
        raise PermissionError('An active guard profile is required.')
    with transaction.atomic():
        eligible = exitpasstable.objects.filter(
            id=pass_id, is_group_pass=False, mentor_status='approved', security_status='pending',
        )
        exit_pass = eligible.select_for_update().first()
        if exit_pass is None or not individual_scan_open(exit_pass):
            raise ValueError('Pass is unavailable, outside its scan window, or already processed.')
        if eligible.update(
            security_status='scanned' if action == 'approve' else 'rejected',
            scanned_at=timezone.now(), scanned_by=guard,
        ) != 1:
            raise ValueError('Pass has already been processed.')
        transaction.on_commit(lambda: security_log.info(
            'individual_scan actor=%s pass=%s decision=%s', login_id, pass_id, action,
        ))


class IndividualScanAPI(JWTAuthMixin, APIView):
    action = None

    def post(self, request):
        if request.auth.get('usertype') != 'security':
            return Response({'error': 'Forbidden'}, status=403)
        token = request.data.get('token')
        pass_id = decrypt_pass_id(token) if isinstance(token, str) else None
        if not pass_id:
            return Response({'error': 'Invalid or expired QR code.'}, status=400)
        try:
            process_individual_scan(request.auth['login_id'], pass_id, self.action)
        except PermissionError:
            return Response({'error': 'Forbidden'}, status=403)
        except ValueError as exc:
            return Response({'error': str(exc)}, status=409)
        return Response(status=200)


class AcceptPass(IndividualScanAPI):
    action = 'approve'


class RejectPass(IndividualScanAPI):
    action = 'reject'


class SecurityGroupPassListAPI(JWTAuthMixin, APIView):
    def get(self, request):
        if request.auth.get('usertype') != 'security':
            return Response({'error': 'Forbidden'}, status=403)
        today = timezone.localtime().date()

        passes = exitpasstable.objects.filter(
            created_at__date=today,
            is_group_pass=True,
            security_status='pending',
            mentor_status='approved'
        ).select_related('student_id', 'mentor_id', 'student_id__classs')


        from collections import defaultdict
        groups = defaultdict(list)

        for p in passes:
            # Group by mentor and approved_at (batch timestamp)
            key = (p.mentor_id, p.approved_at)
            groups[key].append(p)

        result = []
        for (mentor, approved_at), pass_list in groups.items():
            if not pass_list: continue

            classes = set()
            students = []
            pass_ids = []

            for p in pass_list:
                cname = p.student_id.classs.class_name if p.student_id.classs else "Unknown"
                classes.add(cname)
                students.append(p.student_id.name)
                pass_ids.append(p.id)

            display_students = ", ".join(students)

            # Check if all students in class
            if len(classes) == 1:
                cname = list(classes)[0]
                try:
                    cls_obj = pass_list[0].student_id.classs
                    if cls_obj:
                        total_in_class = studenttable.objects.filter(classs=cls_obj).count()
                        if len(students) == total_in_class and total_in_class > 0:
                            display_students = "All Students"
                except Exception:
                    pass

            local_dt = timezone.localtime(approved_at) if approved_at else None

            result.append({
                'mentor_name': mentor.name if mentor else "Unknown",
                'class_names': ", ".join(classes),
                'student_names': display_students,
                'time': local_dt.strftime('%I:%M %p') if local_dt else "",
                'date': local_dt.strftime('%d-%m-%Y') if local_dt else "",
                'pass_ids': pass_ids
            })

        # Sort by latest first
        result.sort(key=lambda x: x['time'], reverse=True)

        return Response(result)

#security proceed group pass
class ProceedGroupPassAPI(JWTAuthMixin, APIView):
    def post(self, request):
        if request.auth.get('usertype') != 'security':
            return Response({'error': 'Forbidden'}, status=403)
        try:
            count = process_group_passes(request.auth['login_id'], request.data.get('pass_ids'))
        except PermissionError:
            return Response({'error': 'Forbidden'}, status=403)
        except ValueError as exc:
            return Response({'error': str(exc)}, status=400)
        return Response({'message': 'Processed successfully', 'count': count})


#register device token to send notification
class RegisterDeviceTokenAPI(JWTAuthMixin, APIView):
    """
    API to register FCM device token for mentors
    """
    def post(self, request):
        try:
            if request.auth.get('usertype') != 'mentor':
                return Response({'error': 'Forbidden'}, status=403)
            login_id = request.auth.get('login_id')
            device_token = request.data.get('device_token')
            platform = request.data.get('platform', 'android')

            if not login_id or not device_token:
                return Response(
                    {'error': 'login_id and device_token are required'},
                    status=status.HTTP_400_BAD_REQUEST
                )

            # Get mentor
            try:
                login_obj = Logintable.objects.get(id=login_id)
                mentor = mentortable.objects.get(LOGINID=login_obj)
            except (Logintable.DoesNotExist, mentortable.DoesNotExist):
                return Response(
                    {'error': 'Mentor not found'},
                    status=status.HTTP_404_NOT_FOUND
                )

            # Create or update device token
            device, created = MentorDeviceToken.objects.update_or_create(
                mentor=mentor,
                device_token=device_token,
                defaults={'platform': platform, 'is_active': True}
            )

            action = 'registered' if created else 'updated'
            return Response(
                {'message': f'Device token {action} successfully'},
                status=status.HTTP_201_CREATED if created else status.HTTP_200_OK
            )

        except Exception as e:
            return Response(
                {'error': 'Unable to complete the request.'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

#update device token
class UpdateDeviceTokenAPI(JWTAuthMixin, APIView):
    """
    API to update FCM device token when it refreshes
    """
    def put(self, request):
        try:
            if request.auth.get('usertype') != 'mentor':
                return Response({'error': 'Forbidden'}, status=403)
            login_id = request.auth.get('login_id')
            old_token = request.data.get('old_token')
            new_token = request.data.get('new_token')

            if not all([login_id, new_token]):
                return Response(
                    {'error': 'login_id and new_token are required'},
                    status=status.HTTP_400_BAD_REQUEST
                )

            # Get mentor
            try:
                login_obj = Logintable.objects.get(id=login_id)
                mentor = mentortable.objects.get(LOGINID=login_obj)
            except (Logintable.DoesNotExist, mentortable.DoesNotExist):
                return Response(
                    {'error': 'Mentor not found'},
                    status=status.HTTP_404_NOT_FOUND
                )

            # Update token
            if old_token:
                MentorDeviceToken.objects.filter(
                    mentor=mentor,
                    device_token=old_token
                ).update(device_token=new_token)
            else:
                # If no old token provided, just create/update with new token
                MentorDeviceToken.objects.update_or_create(
                    mentor=mentor,
                    device_token=new_token,
                    defaults={'is_active': True}
                )

            return Response(
                {'message': 'Device token updated successfully'},
                status=status.HTTP_200_OK
            )

        except Exception as e:
            return Response(
                {'error': 'Unable to complete the request.'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

#delete device token api for mentor
class DeleteDeviceTokenAPI(JWTAuthMixin, APIView):
    """
    API to delete FCM device token on logout
    """
    def delete(self, request):
        try:
            if request.auth.get('usertype') != 'mentor':
                return Response({'error': 'Forbidden'}, status=403)
            login_id = request.auth.get('login_id')
            device_token = request.data.get('device_token')

            if not login_id or not device_token:
                return Response(
                    {'error': 'login_id and device_token are required'},
                    status=status.HTTP_400_BAD_REQUEST
               )

            # Get mentor
            try:
                login_obj = Logintable.objects.get(id=login_id)
                mentor = mentortable.objects.get(LOGINID=login_obj)
            except (Logintable.DoesNotExist, mentortable.DoesNotExist):
                return Response(
                    {'error': 'Mentor not found'},
                    status=status.HTTP_404_NOT_FOUND
                )

            # Delete or deactivate token
            deleted_count = MentorDeviceToken.objects.filter(
                mentor=mentor,
                device_token=device_token
            ).delete()[0]

            if deleted_count > 0:
                return Response(
                    {'message': 'Device token deleted successfully'},
                    status=status.HTTP_200_OK
                )
            else:
                return Response(
                    {'message': 'Device token not found'},
                    status=status.HTTP_404_NOT_FOUND
                )

        except Exception as e:
            return Response(
                {'error': 'Unable to complete the request.'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

# Duplicate MentorRequiredMixin removed (the authoritative definition is at the top of this file)

class MentorGroupPassCreate(MentorRequiredMixin, View):
    def get(self, request):
        mentor_dept_id = (getattr(request, 'jwt_user_id', None) or request.session.get('user_id'))
        mentor_obj = mentortable.objects.filter(LOGINID__id=mentor_dept_id).first()
        if not mentor_obj:
            messages.error(request, "Mentor Profile Not Found")
            return redirect('LoginPage')

        assigned_classes_objs = class_assigntable.objects.filter(mentor_id=mentor_obj).select_related('class_id')
        assigned_classes_ids = [obj.class_id.id for obj in assigned_classes_objs]
        class_names = ", ".join([obj.class_id.class_name for obj in assigned_classes_objs])

        students_list = studenttable.objects.filter(classs_id__in=assigned_classes_ids).select_related('classs').order_by('classs__class_name', 'name')

        grouped_students = {}
        for student in students_list:
            c_name = student.classs.class_name if student.classs else "No Class"
            if c_name not in grouped_students:
                grouped_students[c_name] = []
            grouped_students[c_name].append(student)

        return render(
            request,
            'tables/form/mentor_group_pass.html',
            {
                'grouped_students': grouped_students,
                'mentor_name': mentor_obj.name,
                'class_names': class_names,
                'mentor': mentor_obj
            }
        )

    def post(self, request):
        mentor_dept_id = (getattr(request, 'jwt_user_id', None) or request.session.get('user_id'))
        mentor_obj = mentortable.objects.filter(LOGINID__id=mentor_dept_id).first()
        if not mentor_obj:
            messages.error(request, "Mentor Profile Not Found")
            return redirect('LoginPage')

        student_ids = request.POST.getlist('student_ids')
        reason = request.POST.get('reason', 'Group Pass')

        if not student_ids:
            messages.error(request, "Please select at least one student.")
            return redirect('MentorGroupPassCreate')

        if not mentor_approval_window_open():
            messages.error(request, "Group pass approvals are only allowed between 10:00 AM and 3:40 PM")
            return redirect('MentorGroupPassCreate')

        count = 0
        now = timezone.localtime()
        current_time = now.time()
        students_to_pass = studenttable.objects.filter(id__in=student_ids)
        student_map = {s.id: s for s in students_to_pass}
        passes_to_create = []
        for sid in student_ids:
            try:
                student = student_map.get(int(sid))
                if student:
                    passes_to_create.append(exitpasstable(
                        student_id=student,
                        mentor_id=mentor_obj,
                        reason=reason,
                        time=current_time,
                        mentor_status='approved',
                        security_status='pending',
                        approved_at=now,
                        is_group_pass=True
                    ))
                    count += 1
            except Exception as e:
                logger.warning("Error preparing group pass for student_id=%s: %s", sid, e)
        if passes_to_create:
            exitpasstable.objects.bulk_create(passes_to_create)

        messages.success(request, f"Group Pass Approved for {count} students.")
        return redirect('MntrHome')

import csv
from collections import defaultdict

class MentorAnalyticsView(MentorRequiredMixin, View):
    def get(self, request):
        mentor_dept_id = (getattr(request, 'jwt_user_id', None) or request.session.get('user_id'))
        mentor_obj = mentortable.objects.filter(LOGINID__id=mentor_dept_id).first()
        if not mentor_obj:
            messages.error(request, "Mentor Profile Not Found")
            return redirect('LoginPage')

        assigned_classes_objs = class_assigntable.objects.filter(mentor_id=mentor_obj).select_related('class_id')
        assigned_classes_ids = [obj.class_id.id for obj in assigned_classes_objs]

        students_list = studenttable.objects.filter(classs_id__in=assigned_classes_ids)
        passes = exitpasstable.objects.filter(student_id__in=students_list)

        from django.db.models import Count, Q
        stats = passes.aggregate(
            total_passes=Count('id'),
            approved_passes=Count('id', filter=Q(mentor_status='approved')),
            rejected_passes=Count('id', filter=Q(mentor_status='rejected')),
            pending_passes=Count('id', filter=Q(mentor_status='pending')),
        )

        recent_passes = passes.select_related(
            'student_id', 'student_id__classs'
        ).order_by('-created_at')[:50]

        return render(request, 'tables/form/mentor_analytics.html', {
            'mentor': mentor_obj,
            'total_passes': stats['total_passes'] or 0,
            'approved_passes': stats['approved_passes'] or 0,
            'rejected_passes': stats['rejected_passes'] or 0,
            'pending_passes': stats['pending_passes'] or 0,
            'passes': recent_passes
        })

def spreadsheet_text(value):
    text = str(value or '')
    if text.lstrip().startswith(('=', '+', '-', '@')) or text.startswith(('\t', '\r', '\n')):
        return "'" + text
    return text


class MentorAnalyticsExportCSVView(MentorRequiredMixin, View):
    def get(self, request):
        mentor_dept_id = (getattr(request, 'jwt_user_id', None) or request.session.get('user_id'))
        mentor_obj = mentortable.objects.filter(LOGINID__id=mentor_dept_id).first()
        if not mentor_obj:
            messages.error(request, "Mentor Profile Not Found")
            return redirect('LoginPage')

        assigned_classes_objs = class_assigntable.objects.filter(mentor_id=mentor_obj).select_related('class_id')
        assigned_classes_ids = [obj.class_id.id for obj in assigned_classes_objs]

        students_list = studenttable.objects.filter(classs_id__in=assigned_classes_ids)
        passes = exitpasstable.objects.filter(
            student_id__in=students_list
        ).select_related(
            'student_id', 'student_id__classs'
        ).order_by('-created_at')

        response = HttpResponse(content_type='text/csv')
        response['Content-Disposition'] = 'attachment; filename="mentor_analytics_report.csv"'

        writer = csv.writer(response)
        writer.writerow(['Student Name', 'Admission No', 'Batch', 'Reason', 'Date Requested', 'Time', 'Mentor Status', 'Security Status', 'Scanned At'])

        for p in passes:
            writer.writerow([
                spreadsheet_text(p.student_id.name) if p.student_id else 'N/A',
                spreadsheet_text(p.student_id.admn_no) if p.student_id else 'N/A',
                spreadsheet_text(p.student_id.classs.class_name) if (p.student_id and p.student_id.classs) else 'N/A',
                spreadsheet_text(p.reason),
                p.created_at.strftime('%Y-%m-%d') if p.created_at else 'N/A',
                p.time.strftime('%I:%M %p') if p.time else 'N/A',
                p.mentor_status,
                p.security_status,
                p.scanned_at.strftime('%Y-%m-%d %I:%M %p') if p.scanned_at else 'Not Scanned'
            ])

        return response

class VerifyStudentMentor(MentorRequiredMixin, View):
    def get(self, request):
        q = request.GET.get('q', '').strip()
        status = request.GET.get('status', '').strip()
        mentor_dept_id = (getattr(request, 'jwt_user_id', None) or request.session.get('user_id'))
        # Use LOGINID_id or connect via LOGINID object
        mentor_obj = mentortable.objects.filter(LOGINID__id=mentor_dept_id).first()

        if not mentor_obj:
            messages.error(request, "Mentor Profile Not Found")
            return redirect('LoginPage')

        # Get assigned classes for this mentor
        assigned_classes_objs = class_assigntable.objects.filter(mentor_id=mentor_obj).select_related('class_id')
        assigned_classes_ids = [obj.class_id.id for obj in assigned_classes_objs]
        class_names = ", ".join([obj.class_id.class_name for obj in assigned_classes_objs])

        # Filter students strictly by the mentor's assigned classes
        students_list = studenttable.objects.filter(classs_id__in=assigned_classes_ids).order_by('-id')
        if q:
            students_list = students_list.filter(
                models.Q(name__icontains=q) |
                models.Q(email__icontains=q) |
                models.Q(admn_no__icontains=q) |
                models.Q(classs__class_name__icontains=q)
            )
        students_list = filter_student_verification_status(students_list, status)

        paginator = Paginator(students_list, 10)
        page_number = request.GET.get('page')
        students = paginator.get_page(page_number)

        return render(
            request,
            'tables/form/verify_student_mentor.html',
            {
                'students': students,
                'mentor_name': mentor_obj.name,
                'class_names': class_names,
                'mentor': mentor_obj,
                'q': q,
                'status': status,
                'classes': classstable.objects.all().order_by('class_name'),
            }
        )

class SecurityGroupPass(SecurityRequiredMixin, View):
    def get(self, request):
        today = timezone.localtime().date()
        passes = exitpasstable.objects.filter(
            created_at__date=today,
            is_group_pass=True,
            security_status='pending',
            mentor_status='approved'
        ).select_related('student_id', 'mentor_id', 'student_id__classs')

        from collections import defaultdict
        groups = defaultdict(list)

        for p in passes:
            key = (p.mentor_id, p.approved_at)
            groups[key].append(p)

        result = []
        for (mentor, approved_at), pass_list in groups.items():
            if not pass_list: continue

            classes = set()
            students = []
            pass_ids = []

            for p in pass_list:
                cname = p.student_id.classs.class_name if p.student_id.classs else "Unknown"
                classes.add(cname)
                students.append(p.student_id.name)
                pass_ids.append(str(p.id))

            display_students = ", ".join(students)

            if len(classes) == 1:
                cname = list(classes)[0]
                try:
                    cls_obj = pass_list[0].student_id.classs
                    if cls_obj:
                        total_in_class = studenttable.objects.filter(classs=cls_obj).count()
                        if len(students) == total_in_class and total_in_class > 0:
                            display_students = "All Students"
                except Exception:
                    pass

            local_dt = timezone.localtime(approved_at) if approved_at else None

            result.append({
                'mentor_name': mentor.name if mentor else "Unknown",
                'class_names': ", ".join(classes),
                'student_names': display_students,
                'time': local_dt.strftime('%I:%M %p') if local_dt else "",
                'date': local_dt.strftime('%d-%m-%Y') if local_dt else "",
                'pass_ids': ",".join(pass_ids)
            })

        result.sort(key=lambda x: x['time'] if x['time'] else "", reverse=True)

        user_id = (getattr(request, 'jwt_user_id', None) or request.session.get('user_id'))
        try:
            security_guard = securitytable.objects.get(LOGINID_id=user_id)
        except securitytable.DoesNotExist:
            security_guard = None

        return render(request, 'tables/form/security_group_passes.html', {'groups': result, 'security': security_guard})

    def post(self, request):
        login_id = request.jwt_user_id or request.session.get('user_id')
        pass_ids = request.POST.get('pass_ids', '').split(',')
        try:
            count = process_group_passes(login_id, pass_ids)
        except (PermissionError, ValueError) as exc:
            messages.error(request, str(exc))
        else:
            messages.success(request, f'{count} passes scanned successfully.')
        return redirect('SecurityGroupPass')


@api_view(['GET'])
@authentication_classes([QuietJWTAuthentication])
@permission_classes([IsTokenAuthenticated])
def ViewannouncementAPI(request):
    if request.auth.get('usertype') != 'Student':
        return Response({'error': 'Forbidden'}, status=403)
    announcements = announcementtable.objects.filter(
        is_active=True
    ).filter(
        Q(expires_at__isnull=True) |
        Q(expires_at__gt=timezone.now())
    ).order_by('-created_at')

    data = list(
        announcements.values(
            'id',
            'title',
            'message',
            'created_at',
            'expires_at'
        )
    )

    return JsonResponse(data, safe=False)
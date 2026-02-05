import datetime
from django.utils import timezone
from django.shortcuts import get_object_or_404, redirect, render
from django.views import View
from django.http import HttpResponse
from .serializer import *
from .models import *
from .forms import *
from django.http import HttpResponse
from django.views import View
from django.template.loader import get_template
from xhtml2pdf import pisa
from .models import exitpasstable
from django.contrib.auth.hashers import make_password, check_password

# Create your views here.
#admin role checking
class AdminRequiredMixin:
    def dispatch(self, request, *args, **kwargs):
        # Check if user is logged in
        if not request.session.get('user_id'):
            return HttpResponse('<script>alert("Login Required");window.location="/"</script>')
        
        # Check if user is admin
        if request.session.get('usertype') != 'admin':
             return HttpResponse('<script>alert("Unauthorized Access: Admins Only");window.location="/"</script>')
        
        return super().dispatch(request, *args, **kwargs)

#login page for admin
class LoginPage(View):
    def get(self,request):
        return render(request, 'tables/form/login.html')
    def post(self,request):
        username = request.POST.get('username')
        password = request.POST.get('password')
        try:
            #searching username
            obj = Logintable.objects.filter(username=username).first()
            #checking password
            if obj and check_password(password, obj.password):
                request.session['user_id']=obj.id
                request.session['usertype']=obj.usertype #storing usertype
                
                if obj.usertype=='admin':
                    return HttpResponse('''<script>alert("Login Successful");window.location='HomePage'</script>''')
                else:
                     return HttpResponse('''<script>alert("Login UnSuccessful");window.location='/'</script>''')
            
            #if password is not hashed
            elif obj and obj.password == password:
                #hashing the password
                obj.password = make_password(password)
                obj.save()
                
                request.session['user_id']=obj.id
                request.session['usertype']=obj.usertype
                
                if obj.usertype=='admin':
                    return HttpResponse('''<script>alert("Login Successful (Security Updated)");window.location='HomePage'</script>''')
                else:
                     return HttpResponse('''<script>alert("Login UnSuccessful");window.location='/'</script>''')
                     
            else:
                 return HttpResponse('''<script>alert("Login Failed: Invalid Credentials");window.location='/'</script>''')
        except Exception as e:
             print(e)
             return HttpResponse('''<script>alert("Login Error");window.location='/'</script>''')

from django.views import View
from django.shortcuts import render
from django.core.paginator import Paginator
from .models import studenttable

class VerifyStudent(AdminRequiredMixin, View):
    def get(self, request):
        students_list = studenttable.objects.all().order_by('-id')

        paginator = Paginator(students_list, 15)
        page_number = request.GET.get('page')
        students = paginator.get_page(page_number)

        return render(
            request,
            'tables/form/verify_student.html',
            {'students': students}
        )

class EditStudent(View):
    def get(self, request, id):
        student = get_object_or_404(studenttable, id=id)
        form = EditStudentForm(instance=student)
        return render(request, 'tables/form/edit_student.html', {'form': form, 'student': student})

    def post(self, request, id):
        student = get_object_or_404(studenttable, id=id)
        form = EditStudentForm(request.POST, instance=student)
        if form.is_valid():
            form.save()
            return HttpResponse('<script>alert("Student Updated Successfully");window.location="/VerifyStudent"</script>')
        return render(request, 'tables/form/edit_student.html', {'form': form, 'student': student})
    
class AcceptStudent(View):
    def get(self,request, lid):
        login_obj=Logintable.objects.get(id=lid)
        login_obj.usertype='Student'
        login_obj.save()
        return redirect('verify_student')

class RejectStudent(View):
    def get(self,request, lid):
        login_obj=Logintable.objects.get(id=lid)
        login_obj.usertype='Rejected'
        login_obj.save()
        return redirect('verify_student')   
    
class DeleteStudent(View):
    def get(self,request,id):
        s=studenttable.objects.get(id=id)
        if s.LOGINID:
            s.LOGINID.delete()
        else:
            s.delete()
        return HttpResponse('''<script>alert("Student Deleted succesfull");window.location='/VerifyStudent'</script>''')

class UploadImage(View):
    def post(self, request, s_id):
        Photo = request.FILES.get('image')
        student_obj = studenttable.objects.get(id=s_id)
        
        if Photo:
            # Simply assign the file to the Photo field
            # Django will automatically save it to profile_photos/students/ as defined in the model
            student_obj.Photo = Photo
            student_obj.save()

        return redirect('verify_student')

class AddDepartment(View):
    def get(self,request):
        return render(request,'tables/form/add_dep.html')
    def post(self,request):
        deprt=AddDepartmentForm(request.POST)
        if deprt.is_valid():
            m=deprt.save()
            return HttpResponse('''<script>alert("Department Added succesfull");window.location='ManageDepartment'</script>''')

class ManageDepartment(View):
    def get(self,request):
        department=departmenttable.objects.all()
        return render(request, 'tables/form/mng_dep.html',{'departments':department})
    
class AssignDepartment(View):
    def get(self,request):
        return render(request, 'tables/form/assn_dep.html')

#exit pass with admin role checking and report generation
class Pass(AdminRequiredMixin, View):
    def get(self, request):
        # Cleanup expired passes
        threshold = timezone.now() - datetime.timedelta(hours=24)
        exitpasstable.objects.filter(mentor_status='pending', created_at__lt=threshold).delete()

        month = request.GET.get('month')

        exitpasses = exitpasstable.objects.all().order_by('-created_at')

        if month:
            exitpasses = exitpasses.filter(created_at__month=month)

        months = range(1, 13)

        return render(request, 'tables/form/pass.html', {
            'exitpasses': exitpasses,
            'months': months,
            'selected_month': int(month) if month else None
        })
    
class ExportPassPDF(View):
    def get(self, request):
        exitpasses = exitpasstable.objects.all()

        template = get_template('tables/form/pass_pdf.html')
        html = template.render({'exitpasses': exitpasses})

        response = HttpResponse(content_type='application/pdf')
        response['Content-Disposition'] = 'attachment; filename="exit_pass_report.pdf"'

        pisa.CreatePDF(html, dest=response)
        return response    
    
class ComplaintManage(View):
    def get(self,request):
        complaint=complainttable.objects.all().order_by('-id')
        return render(request, 'tables/form/complaint_mng.html',{'complaints':complaint})
    
class SendReply(View):
    def post(self,request,id):
        complaint=complainttable.objects.get(id=id)
        reply_text=request.POST.get('reply')
        complaint.reply=reply_text
        complaint.save()
        return HttpResponse('''<script>alert("Reply succesfull");window.location='/ComplaintManage'</script>''')

class AddClass(View):
    def get(self,request):
        obj = departmenttable.objects.all()
        return render(request,'tables/form/add_class.html', {'dept': obj})
    def post(self,request):
        cls=AddClassForm(request.POST)
        if cls.is_valid():
            m=cls.save()
            return HttpResponse('''<script>alert("Class Added succesfull");window.location='ManageClass'</script>''')
        
class DeleteClass(View):
    def get(self,request,id):
        s=classstable.objects.get(id=id)
        s.delete()
        return HttpResponse('''<script>alert("Class Deleted succesfull");window.location='/ManageClass'</script>''')

class ManageClass(AdminRequiredMixin, View):
    def get(self,request):
        classs_name=classstable.objects.all().order_by('-id')
        return render(request, 'tables/form/mng_class.html',{'classes':classs_name})
    
class AssignClass(View):
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

        class_assigntable.objects.create(
            mentor_id_id=mentor_id,
            class_id_id=class_id
        )
        return HttpResponse('''<script>alert("Assigned succesfully");window.location='/AssignClass'</script>''')

class DeleteAssignClass(View):
    def get(self,request,id):
        s=class_assigntable.objects.get(id=id)
        s.delete()
        return HttpResponse('''<script>alert("Deleted succesfull");window.location='/AssignClass'</script>''')

class AssignDepartment(View):
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
        dept_assigntable.objects.create(          
            mentor_id_id=mentor_id,
            department_id_id=dept
        )
        return HttpResponse(
            '''<script>alert("Assigned succesfully");window.location='/AssignDepartment'</script>'''
        )

class DeleteAssignDept(View):
    def get(self,request,id):
        s=dept_assigntable.objects.get(id=id)
        s.delete()
        return HttpResponse('''<script>alert("Deleted succesfull");window.location='/AssignDepartment'</script>''') 
#homepage with admin role checking
class HomePage(AdminRequiredMixin, View):
    def get(self,request):
        return render(request,'tables/form/homepage.html')

class ManageMentor(AdminRequiredMixin, View):
    def get(self,request):
        mentor=mentortable.objects.all().order_by('-id')
        return render(request, 'tables/form/mng_mntr.html',{'mentors':mentor})

class AddMentor(View):
    def get(self,request):
        dept = departmenttable.objects.all()
        return render(request,'tables/form/add_mntr.html',{'depts':dept})
    def post(self,request):
        mntr=AddMentorForm(request.POST, request.FILES)
        if mntr.is_valid():
            m=mntr.save(commit=False)
            # SECURE: Hash password before saving
            hashed_pwd = make_password(request.POST.get('Password'))
            l=Logintable.objects.create(username=m.email,password=hashed_pwd,usertype='mentor')
            m.LOGINID=l
            m.save()
            return HttpResponse('''<script>alert("Mentor registraion succesfull");window.location='ManageMentor'</script>''')

class EditMentor(View):
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
            mt.save()
            return HttpResponse('''<script>alert("Mentor Updated succesfull");window.location='/ManageMentor'</script>''')

class DeleteMentor(View):
    def get(self,request,id):
        s=mentortable.objects.get(id=id)
        if s.LOGINID:
            s.LOGINID.delete()
        else:
            s.delete()
        return HttpResponse('''<script>alert("Mentor Deleted succesfull");window.location='/ManageMentor'</script>''')

class AddDepartment(View):
    def get(self,request):
        return render(request,'tables/form/add_dep.html')
    def post(self,request):
        deprt=AddDepartmentForm(request.POST)
        if deprt.is_valid():
            m=deprt.save()
            return HttpResponse('''<script>alert("Department Added succesfull");window.location='ManageDepartment'</script>''')
        
class DeleteDepartment(View):
    def get(self,request,id):
        s=departmenttable.objects.get(id=id)
        s.delete()
        return HttpResponse('''<script>alert("Department Deleted succesfull");window.location='/ManageDepartment'</script>''')
 
class ManageSecurity(AdminRequiredMixin, View):
    def get(self,request):
        security=securitytable.objects.all().order_by('-id')
        return render(request, 'tables/form/mng_security.html',{'securities':security})

class AddSecurity(View):
    def get(self,request):
        return render(request,'tables/form/add_security.html')
    def post(self,request):
        scr=AddSecurityForm(request.POST, request.FILES)
        if scr.is_valid():
            m=scr.save(commit=False)
            # SECURE: Hash password before saving
            hashed_pwd = make_password(request.POST.get('Password'))
            l=Logintable.objects.create(username=m.email,password=hashed_pwd,usertype='security')
            m.LOGINID=l
            m.save()
            return HttpResponse('''<script>alert("Security registraion succesfull");window.location='ManageSecurity'</script>''')
    
class AddClass(View):
    def get(self,request):
        obj = departmenttable.objects.all()
        return render(request,'tables/form/add_class.html', {'dept': obj})
    def post(self,request):
        cls=AddClassForm(request.POST)
        if cls.is_valid():
            m=cls.save()
            return HttpResponse('''<script>alert("Class Added succesfull");window.location='ManageClass'</script>''')
        
class DeleteClass(View):
    def get(self,request,id):
        s=classstable.objects.get(id=id)
        s.delete()
        return HttpResponse('''<script>alert("Class Deleted succesfull");window.location='/ManageClass'</script>''')
#edit security
class EditSecurity(View):
    def get(self,request,id):
        s=securitytable.objects.get(id=id)
        return render(request,'tables/form/edit_security.html',{'data':s})
    def post(self,request,id):
        sr=securitytable.objects.get(id=id)
        st=AddSecurityForm(request.POST, request.FILES, instance=sr)
        if st.is_valid():
            st.save()
            return HttpResponse('''<script>alert("Security Updated succesfull");window.location='/ManageSecurity'</script>''')
  
#delete security
class DeleteSecurity(View):
    def get(self,request,id):
        s=securitytable.objects.get(id=id)
        if s.LOGINID:
            s.LOGINID.delete()
        else:
            s.delete()
        return HttpResponse('''<script>alert("Security Deleted succesfull");window.location='/ManageSecurity'</script>''')

#admin approve pass
class Approvepassadmin(View):
    def get(self, request, id):
        exit_pass = exitpasstable.objects.get(id=id)
        exit_pass.mentor_status = "approved"
        exit_pass.approved_at = timezone.now()
        exit_pass.save()
        
        return HttpResponse(
            '<script>alert("Pass Approved");window.location="/Pass"</script>'
        )

#admin reject pass
class Rejectpassadmin(View):
    def get(self,request,id):
        obj = exitpasstable.objects.get(id=id)
        obj.mentor_status = "rejected"
        obj.save()
        return HttpResponse('<script>alert("pass Rejected");window.location="/Pass"</script>')

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
from rest_framework.response import Response
from rest_framework  import status
from django.core.mail import send_mail
from django.shortcuts import redirect
from django.contrib import messages

#user registration api for student
class UserReg_api(APIView):
    def get(self, request):
        classes = classstable.objects.all()
        class_serializer = ClassSerializer(classes, many=True)#change to json
        print("---------", class_serializer.data)
        return Response(class_serializer.data, status=status.HTTP_200_OK)
    
    def post(self,request):
        print('####################################################',request.data)

        user_serial= StudentSerializer(data=request.data)
        login_serial=LoginSerializer(data=request.data)

        data_valid= user_serial.is_valid()
        login_valid=login_serial.is_valid()
        print(data_valid, login_valid)

        if data_valid and login_valid:
            #checking for duplicates
            email = request.data.get('email')
            admn_no = request.data.get('admn_no')
            
            if Logintable.objects.filter(username=email).exists():
                 return Response({"message": "Email already registered"}, status=status.HTTP_400_BAD_REQUEST)
            
            if studenttable.objects.filter(email=email).exists():
                 return Response({"message": "Email already registered"}, status=status.HTTP_400_BAD_REQUEST)

            if studenttable.objects.filter(admn_no=admn_no).exists():
                 return Response({"message": "Admission Number already registered"}, status=status.HTTP_400_BAD_REQUEST)

            #Hash password
            password = request.data.get('password')
            hashed_pw = make_password(password)
            
            login_profile=login_serial.save(
                usertype='pending', 
                username=email,
                password=hashed_pw
            )

            user_serial.save(LOGINID=login_profile)

            return Response(user_serial.data,status.HTTP_201_CREATED)
        return Response({
            'login_error':login_serial.errors if not login_valid else None,
            'user.error':user_serial.errors if not data_valid else None

        },status=status.HTTP_400_BAD_REQUEST)

#login api for student,mentor,security
class LoginpageAPI(APIView):
    def post(self, request):
        print("-------------------", request.data)
        response_dict = {}

        username = request.data.get("username")
        password = request.data.get("password")
        #checking empty or not
        if not username or not password:
            return Response(
                {"message": "Username and Password required"},
                status=status.HTTP_400_BAD_REQUEST
            )
        # Get user by username first
        t_user = Logintable.objects.filter(username=username).first()
        # Verify password hash
        if not t_user or not check_password(password, t_user.password):
            return Response(
                {"message": "Invalid Username or Password"},
                status=status.HTTP_401_UNAUTHORIZED
            )
        response_dict["message"] = "success"
        response_dict["login_id"] = t_user.id
        response_dict["usertype"] = t_user.usertype
        # Default counts
        response_dict["count"] = 0
        response_dict["pending_count"] = 0

        if t_user.usertype == 'mentor':
            # get mentor object
            mentor = mentortable.objects.filter(LOGINID=t_user).first()
            
            if mentor:
                # 1. Passes already processed/assigned to this mentor
                processed_passes = exitpasstable.objects.filter(mentor_id=mentor)
                
                # 2. Pending passes from assigned classes
                assigned_classes = class_assigntable.objects.filter(mentor_id=mentor).values_list('class_id', flat=True)
                pending_requests = exitpasstable.objects.filter(mentor_status='pending', student_id__classs__id__in=assigned_classes)

                response_dict["count"] = processed_passes.count() + pending_requests.count()
                response_dict["pending_count"] = pending_requests.count()

        print("-----login details--------->", response_dict)
        return Response(response_dict, status=status.HTTP_200_OK)


#apply pass api for student
class ApplypassAPI(APIView):
    def get(self, request, lid):
        # Cleanup expired passes
        threshold = timezone.now() - datetime.timedelta(hours=24)
        exitpasstable.objects.filter(mentor_status='pending', created_at__lt=threshold).delete()

        student_obj = studenttable.objects.get(LOGINID_id=lid)
        obj = exitpasstable.objects.filter(student_id_id=student_obj).order_by('-id')
        serializer = ExitpassSerializer(obj,many=True)
        print("---------", serializer.data)
        return Response(serializer.data, status=status.HTTP_200_OK)
    
    def post(self, request, lid):
        try:
            reason = request.data.get('reason')
            time_str = request.data.get('time')
            time_obj = datetime.datetime.strptime(time_str, '%I:%M %p').time()
            student_obj = studenttable.objects.get(LOGINID_id=lid)
            
            # Create exit pass
            exit_pass = exitpasstable.objects.create(
                student_id=student_obj,
                reason=reason,
                time=time_obj,
                mentor_status = 'pending',
                security_status = 'pending',
            )
            try:
                # Find mentor assigned to this student's class
                student_class = student_obj.classs
                if student_class:
                    # Get class assignment
                    class_assignments = class_assigntable.objects.filter(class_id=student_class)
                    
                    if class_assignments.exists():
                        for assignment in class_assignments:
                            mentor = assignment.mentor_id
                            
                            # Get all active device tokens for this mentor
                            device_tokens_objs = MentorDeviceToken.objects.filter(
                                mentor=mentor,
                                is_active=True
                            )
                            
                            if device_tokens_objs.exists():
                                device_tokens = [token.device_token for token in device_tokens_objs]
                                
                                # Send notification
                                from GateApp.services.notification_service import send_notification_to_mentor
                                sent_count = send_notification_to_mentor(
                                    device_tokens=device_tokens,
                                    student_name=student_obj.name,
                                    class_name=student_class.class_name,
                                    reason=reason,
                                    pass_id=exit_pass.id
                                )
                                
                                if sent_count > 0:
                                    print(f"[SUCCESS] Notification sent to {sent_count} device(s) for mentor {mentor.name}")
                                else:
                                    print(f"[WARNING] Failed to send notification to mentor {mentor.name}")
                            else:
                                print(f"[WARNING] No active device tokens found for mentor {mentor.name}")
                    else:
                        print(f"[WARNING] No mentor assigned  to class {student_class.class_name}")
                else:
                    print(f"[WARNING] Student {student_obj.name} is not assigned to any class")
                    
            except Exception as e:
                print(f"[ERROR] Error sending push notification: {e}")
                # Don't fail the pass creation if notification fails
            # ================================================================

            return Response(
                {"message": "Pass applied successfully"},
                status=status.HTTP_201_CREATED
            )

        except Exception as e:
            print(f"ERROR in ApplypassAPI: {str(e)}")
            print(f"Error type: {type(e).__name__}")
            import traceback
            traceback.print_exc()
            return Response(
                {"error": str(e)},
                status=status.HTTP_400_BAD_REQUEST
            )      

#student info api
class StudentInfo_api(APIView):
    def get(self, request, lid):
        student_obj = studenttable.objects.get(LOGINID_id=lid)
        print(student_obj)
        
        serializer = StudentSerializer1(student_obj)
        print("---------", serializer.data)
        return Response(serializer.data, status=status.HTTP_200_OK)
    

#view complaint and view reply api for student
class ViewcomplaintAPI(APIView):
    def get(self,request,lid):
        complaint = complainttable.objects.filter(student_id__LOGINID__id=lid).order_by('-id')
        complaint_serial = ComplaintSerializer(complaint,many=True)
        return Response(complaint_serial.data,status=status.HTTP_200_OK)
    def post(self,request,lid):
        user = studenttable.objects.get(LOGINID__id = lid)
        complaint_serial = ComplaintSerializer(data=request.data)

        if complaint_serial.is_valid():
            complaint_serial.save(student_id = user)
            print(complaint_serial.data)
            return Response({'status':'Complaint sent Successfully'},status=status.HTTP_201_CREATED)
        else:
            return Response({'status':'Complaint sending Failed','errors': complaint_serial.errors},status=status.HTTP_400_BAD_REQUEST)

#exit pass timeline api for student
class ExitPassTimelineAPI(APIView):
    def get(self, request, lid):
        try:
            # Cleanup expired passes
            threshold = timezone.now() - datetime.timedelta(hours=24)
            exitpasstable.objects.filter(mentor_status='pending', created_at__lt=threshold).delete()

            # Get latest pass for the student
            exit_pass = exitpasstable.objects.filter(
                student_id__LOGINID__id=lid
            ).order_by('-id').first()

            if not exit_pass:
                return Response(
                    {'message': 'No pass found'},
                    status=status.HTTP_404_NOT_FOUND
                )

            serializer = ExitpassSerializer(exit_pass)
            print(serializer.data)
            return Response(serializer.data, status=status.HTTP_200_OK)

        except Exception as e:
            return Response(
                {'error': str(e)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

#mentor info api
class Mentorinfo_api(APIView):
    def get(self, request, lid):
        mentor_obj = mentortable.objects.get(LOGINID_id=lid)
        serializer = MentorSerializer(mentor_obj)
        print("---------", serializer.data)
        return Response(serializer.data, status=status.HTTP_200_OK)
    
#pending pass list for mentor
class Pendingpass_api(APIView):
    def get(self,request,lid):
        # Cleanup expired passes
        threshold = timezone.now() - datetime.timedelta(hours=24)
        exitpasstable.objects.filter(mentor_status='pending', created_at__lt=threshold).delete()

        mentor_obj = mentortable.objects.get(LOGINID_id=lid)
        assigned_classes = class_assigntable.objects.filter(mentor_id=mentor_obj).values_list('class_id', flat=True)
        pending = exitpasstable.objects.filter(mentor_status='pending', student_id__classs__id__in=assigned_classes)#if pending and student is in assigned class
        pending_serial = ExitpassSerializer(pending,many=True)
        print("---------", pending_serial.data)
        return Response(pending_serial.data,status=status.HTTP_200_OK)
    
import qrcode
import json
from io import BytesIO
from django.core.files import File
from django.utils import timezone
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status

#approve pass api for mentor
class ApproveExitPassAPI(APIView):
    def post(self, request):
        pass_id = request.data.get("pass_id")
        role = request.data.get("role")
        mentor_id=request.data.get('loginid')
        print("----------", request.data)
        mentor_obj = mentortable.objects.get(LOGINID_id=mentor_id)
        if not pass_id or not role:
            return Response({"error": "pass_id and role required"}, status=400)

        try:
            exit_pass = exitpasstable.objects.select_related(
                "student_id", "student_id__classs"
            ).get(id=pass_id)
        except exitpasstable.DoesNotExist:
            return Response({"error": "Pass not found"}, status=404)

        # ---------------- MENTOR APPROVAL ----------------
        if role == "mentor":
            if exit_pass.mentor_status != "pending":
                return Response({"error": "Already processed"}, status=400)

            exit_pass.mentor_status = "approved"
            exit_pass.approved_at = timezone.now()
            exit_pass.mentor_id=mentor_obj
            # QR code will be generated on-demand when requested

        # ---------------- SECURITY APPROVAL ----------------
        elif role == "security":
            if exit_pass.security_status != "pending":
                return Response({"error": "Already processed"}, status=400)

            exit_pass.security_status = "approved"
            exit_pass.scanned_at = timezone.now()

        else:
            return Response({"error": "Invalid role"}, status=400)

        exit_pass.save()
        return Response({"message": "Pass approved successfully"}, status=200)
    
#reject pass api for mentor
class RejectExitPassAPI(APIView):
    def post(self, request):
        pass_id = request.data.get("pass_id")
        role = request.data.get("role")
        reason = request.data.get("reason")
        mentor_id = request.data.get('loginid')
        print("----------", request.data)

        try:
            exit_pass = exitpasstable.objects.get(id=pass_id)
        except exitpasstable.DoesNotExist:
            return Response(
                {"error": "Pass not found"},
                status=status.HTTP_404_NOT_FOUND
            )

        if role == "mentor":
            # Fetch mentor object only if role is mentor
            try:
                mentor_obj = mentortable.objects.get(LOGINID_id=mentor_id)
            except mentortable.DoesNotExist:
                return Response({"error": "Mentor not found"}, status=400)

            if exit_pass.mentor_status in ["approved", "rejected"]:
                return Response({"error": "Already processed"}, status=400)
            exit_pass.mentor_status = "rejected"
            exit_pass.mentor_id = mentor_obj
            
        elif role == "security":
            if exit_pass.security_status in ["approved", "rejected"]:
                return Response({"error": "Already processed"}, status=400)
            exit_pass.security_status = "rejected"
            
        else:
            return Response({"error": "Invalid role"}, status=400)

        exit_pass.reject_reason = reason
        exit_pass.save()

        return Response(
            {"message": "Pass rejected", "reason": reason},
            status=status.HTTP_200_OK
        )
#checking pass is already scanned or not for security
class CheckPassStatus(APIView):
    def post(self, request):
        pass_id = request.data.get("pass_id")
        
        try:
            exit_pass = exitpasstable.objects.get(id=pass_id)
            return Response({
                "security_status": exit_pass.security_status,
                "mentor_status": exit_pass.mentor_status
            }, status=200)
        except exitpasstable.DoesNotExist:
            return Response({"error": "Pass not found"}, status=404)

#student list api for mentor class wise display
class StudentListAPI(APIView):
    def get(self, request, lid):
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
        print(result)
        return Response(result, status=status.HTTP_200_OK)

#group pass api for mentor
class GroupPassAPI(APIView):
    def post(self, request, lid):
        try:
            student_ids = request.data.get('student_ids', [])
            reason = request.data.get('reason', 'Group Pass')
            
            try:
                mentor = mentortable.objects.get(LOGINID=lid)
            except mentortable.DoesNotExist:
                 return Response({'error': 'Mentor not found'}, status=404)
            
            now = timezone.localtime()
            current_time = now.time()
            
            count = 0
            for sid in student_ids:
                try:
                    student = studenttable.objects.get(id=sid)
                    exitpasstable.objects.create(
                        student_id=student,
                        mentor_id=mentor,
                        reason=reason,
                        time=current_time,
                        mentor_status='approved',
                        security_status='pending',
                        approved_at=now
                    )
                    count += 1
                except Exception as inner_e:
                    print(f"Error for student {sid}: {inner_e}")
            
            return Response({'message': f'Group Pass Approved for {count} students'}, status=200)

        except Exception as e:
            return Response({'error': str(e)}, status=400)

#mentor pass analytics api
class MentorPassAnalytics(APIView):
    def get(self, request, lid):
        from datetime import date
        
        mentor = mentortable.objects.get(LOGINID_id=lid)

        # Get assigned classes
        assigned_classes = class_assigntable.objects.filter(mentor_id=mentor).values_list('class_id', flat=True)

        # Get today's date
        today = date.today()

        # Filter passes for today only
        passes = exitpasstable.objects.filter(
            student_id__classs__id__in=assigned_classes,
            created_at__date=today  # Only today's passes
        ).values(
            'id', 'reason', 'time',
            'mentor_status', 'security_status',
            'student_id__name',
            'student_id__classs__class_name'
        )

        data = []
        for p in passes:
            data.append({
                'id': p['id'],
                'reason': p['reason'],
                'time': p['time'].strftime("%I:%M %p") if hasattr(p['time'], 'strftime') else p['time'],
                'mentor_status': p['mentor_status'],
                'security_status': p['security_status'],
                'name': p['student_id__name'],
            })

        return Response(data)

#mentor exit report api
class MentorExitReportAPI(APIView):
    def get(self, request, lid):
        mentor = mentortable.objects.get(LOGINID_id=lid)
        
        # Get query parameters for filtering
        search_name = request.GET.get('search', '')
        class_filter = request.GET.get('class', '')
        date_filter = request.GET.get('date', '')  # Expected format: YYYY-MM-DD
        
        # Get assigned classes
        assigned_classes = class_assigntable.objects.filter(mentor_id=mentor).values_list('class_id', flat=True)
        
        # Base query: only scanned passes from assigned classes
        passes = exitpasstable.objects.filter(
            student_id__classs__id__in=assigned_classes,
            security_status='scanned'
        ).select_related('student_id', 'student_id__classs', 'student_id__classs__department_id')
        
        # Apply search filter
        if search_name:
            passes = passes.filter(student_id__name__icontains=search_name)
        
        # Apply class filter
        if class_filter:
            passes = passes.filter(student_id__classs__class_name=class_filter)
        
        # Apply date filter
        if date_filter:
            try:
                from datetime import datetime
                filter_date = datetime.strptime(date_filter, '%Y-%m-%d').date()
                passes = passes.filter(scanned_at__date=filter_date)
            except ValueError:
                pass  # Invalid date format, skip filter
        
        # Order by scanned_at descending (most recent first)
        passes = passes.order_by('-scanned_at')
        
        data = []
        for p in passes:
            scanned_time = p.scanned_at.strftime('%I:%M %p') if p.scanned_at else '-'
            scanned_date = p.scanned_at.strftime('%b %d, %Y') if p.scanned_at else '-'
            
            data.append({
                'id': p.id,
                'student_name': p.student_id.name,
                'department': p.student_id.classs.department_id.name if p.student_id.classs and p.student_id.classs.department_id else '-',
                'class': p.student_id.classs.class_name if p.student_id.classs else '-',
                'date': scanned_date,
                'time': scanned_time,
                'status': 'Exited',
                'reason': p.reason
            })
        
        # Get list of unique classes for filter dropdown
        classes = set()
        for class_id in assigned_classes:
            try:
                cls = classstable.objects.get(id=class_id)
                classes.add(cls.class_name)
            except:
                pass
        
        return Response({
            'passes': data,
            'classes': sorted(list(classes))
        })

#generate qr code for exit pass 15mins delayed
class GenerateQRCodeAPI(APIView):
    def post(self, request):
        pass_id = request.data.get("pass_id")
        
        try:
            exit_pass = exitpasstable.objects.select_related(
                "student_id", "student_id__classs"
            ).get(id=pass_id)
        except exitpasstable.DoesNotExist:
            return Response({"error": "Pass not found"}, status=404)
        
        # Check if pass is approved
        if exit_pass.mentor_status != "approved":
            return Response({"error": "Pass not approved yet"}, status=400)
        
        # Check if pass is already scanned or rejected
        if exit_pass.security_status in ["scanned", "rejected"]:
            return Response({"error": "Pass already processed"}, status=400)
        
        # Get current time and requested exit time
        # Use localtime() to get time in server's configured timezone (not UTC)
        now = timezone.localtime()
        
        # Combine TODAY's date with the exit time (not created_at date)
        # This ensures we check if it's 15 minutes before exit TODAY
        exit_datetime = datetime.datetime.combine(
            now.date(),  # Use today's date, not created_at
            exit_pass.time
        )
        # Make timezone aware using current timezone (not default UTC)
        exit_datetime = timezone.make_aware(exit_datetime, timezone.get_current_timezone())
        
        # Check if we're within 15 minutes before the exit time
        time_until_exit = (exit_datetime - now).total_seconds() / 60

        # If exit time has passed or we're past the 15-min window, allow QR generation
        # Only block if we're MORE than 15 minutes away from exit time
        if time_until_exit > 15:
            minutes_remaining = int(time_until_exit)
            # Calculate when QR will be available (15 min before exit)
            minutes_until_available = minutes_remaining - 15
            return Response({
                "error": "QR code not yet available",
                "message": f"QR code will be available in {minutes_until_available} minutes (15 min before your exit time)",
                "minutes_remaining": minutes_until_available,
                "exit_time": exit_pass.time.strftime("%I:%M %p")
            }, status=403)
        
        # If time_until_exit is negative or very small, we're at or past exit time - allow generation
        print(f"[QR Generation] Time check passed - allowing QR generation")
        
        # If QR already exists and is still valid, return it
        if exit_pass.qrcode:
            return Response({
                "message": "QR code already generated",
                "qrcode_url": exit_pass.qrcode.url
            }, status=200)
        
        # Generate QR code
        student = exit_pass.student_id
        qr_data = {
            "pass_id": exit_pass.id,
            "name": student.name,
            "email": student.email,
            "admn_no": student.admn_no,
            "phone": student.phone,
            "class": str(student.classs.class_name),
            "security_status": exit_pass.security_status,
            "reason": exit_pass.reason,
            "time": exit_pass.time.strftime("%I:%M %p"),
            "approved_at": str(exit_pass.approved_at),
            "created_at": str(exit_pass.created_at),
            "mentor": exit_pass.mentor_id.name if exit_pass.mentor_id else "Unknown",
        }
        
        qr = qrcode.make(json.dumps(qr_data))
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
class SecurityApprovedPassAPI(APIView):
    def get(self, request, lid):
        passes = exitpasstable.objects.filter(
            mentor_status='approved',  # not scanned yet
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
class Securityinfo_api(APIView):
    def get(self, request, lid):
        security_obj = securitytable.objects.get(LOGINID_id=lid)
        serializer = SecuritySerializer(security_obj)
        print("---------", serializer.data)
        return Response(serializer.data, status=status.HTTP_200_OK)

#get all passes for menntor analytics api
class getallpasses(APIView):
    def get(self, request, lid):
        security_obj = exitpasstable.objects.filter(mentor_id__LOGINID_id=lid)
        serializer = ExitpassSerializer1(security_obj,many=True)
        print("-----hhhhhh----", serializer.data)
        return Response(serializer.data, status=status.HTTP_200_OK)

#forget password api   
class ForgetPassword(APIView):
    def post(self, request):
        print(request.data)
        email = request.data.get('Email')
        print(email)
        if not email:
            return Response({"error": "Email required"}, status=400)

        # 1. Verify user exists in any role table
        user_tables = [studenttable, mentortable, securitytable]
        user_found = False
        
        for table in user_tables:
            if table.objects.filter(email=email).exists():
                user_found = True
                break
        
        if not user_found and not Logintable.objects.filter(username=email).exists():
             return Response({"error": "Email not registered"}, status=404)

        # 2. Generate 6-digit OTP
        import random
        otp = str(random.randint(100000, 999999))
        
        # 3. Save to DB
        PasswordResetOTP.objects.create(email=email, otp=otp)
        
        # 4. Send Email
        try:
            send_mail(
                'GateEase Password Reset',
                f'Your OTP for password reset is: {otp}\nValid for 10 minutes.',
                'Any queries contact: [gateeaseapp@gmail.com]',
                'gateeaseapp@gmail.com',
                [email],
                fail_silently=False,
            )
            return Response({"message": "OTP sent successfully"}, status=200)
        except Exception as e:
            print("Mail Error:", e)
            return Response({"error": "Failed to send email"}, status=500)

#reset password api
class ResetPasswordAPI(APIView):
    def post(self, request):
        email = request.data.get('email')
        otp = request.data.get('otp')
        new_password = request.data.get('new_password')
        
        if not all([email, otp, new_password]):
             return Response({"error": "All fields required"}, status=400)
             
        #first Verify OTP
        # Get latest OTP for this email
        otp_obj = PasswordResetOTP.objects.filter(email=email, is_used=False).order_by('-created_at').first()
        
        if not otp_obj or otp_obj.otp != otp:
            return Response({"error": "Invalid or expired OTP"}, status=400)
            
        #Check Expiry of otp
        time_diff = timezone.now() - otp_obj.created_at
        if time_diff.total_seconds() > 600:
             return Response({"error": "OTP Expired"}, status=400)
             
        #Reset Password
        # Find login object (username is usually email)
        login_obj = Logintable.objects.filter(username=email).first()
        
        # If username != email, try to find via Student/Mentor tables
        if not login_obj:
             for table in [studenttable, mentortable, securitytable]:
                 u = table.objects.filter(email=email).first()
                 if u and u.LOGINID:
                     login_obj = u.LOGINID
                     break
        #hash the password
        if login_obj:
            login_obj.password = make_password(new_password)
            login_obj.save()
            
            # Mark OTP as used
            otp_obj.is_used = True
            otp_obj.save()
            
            return Response({"message": "Password reset successfully"}, status=200)
        else:
            return Response({"error": "User account not found"}, status=404) 

#security accept/reject pass
class AcceptPass(APIView):
    def post(self, request):
        print(request.data)    
        obj = exitpasstable.objects.get(id=request.data.get('pass_id'))
        obj.security_status = 'scanned'
        obj.scanned_at = timezone.now()
        obj.save()
        return Response(status=status.HTTP_200_OK)

class RejectPass(APIView):
    def post(self, request):
        print(request.data)    
        obj = exitpasstable.objects.get(id=request.data.get('pass_id'))
        obj.security_status = 'rejected'
        obj.save()
        return Response(status=status.HTTP_200_OK)

#security group pass list
class SecurityGroupPassListAPI(APIView):
    def get(self, request):
        today = timezone.localtime().date()
        print(f"DEBUG: Checking for passes on {today}")
        passes = exitpasstable.objects.filter(
            created_at__date=today, 
            reason='Group Pass', 
            security_status='pending',
            mentor_status='approved'
        ).select_related('student_id', 'mentor_id', 'student_id__classs')
        print(f"DEBUG: Found {passes.count()} pending group passes")
        
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
                except:
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
class ProceedGroupPassAPI(APIView):
    def post(self, request):
        try:
            pass_ids = request.data.get('pass_ids', [])
            current_time = timezone.localtime()
            for pid in pass_ids:
                try:
                    obj = exitpasstable.objects.get(id=pid)
                    obj.security_status = 'scanned'
                    obj.scanned_at = current_time
                    obj.save()
                except exitpasstable.DoesNotExist:
                    continue
            return Response({'message': 'Processed successfully'})
        except Exception as e:
            return Response({'error': str(e)}, status=400)

#register device token to send notification
class RegisterDeviceTokenAPI(APIView):
    """
    API to register FCM device token for mentors
    """
    def post(self, request):
        try:
            login_id = request.data.get('login_id')
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
                {'error': str(e)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

#update device token
class UpdateDeviceTokenAPI(APIView):
    """
    API to update FCM device token when it refreshes
    """
    def put(self, request):
        try:
            login_id = request.data.get('login_id')
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
                {'error': str(e)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

#delete device token api for mentor
class DeleteDeviceTokenAPI(APIView):
    """
    API to delete FCM device token on logout
    """
    def delete(self, request):
        try:
            login_id = request.data.get('login_id')
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
                {'error': str(e)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
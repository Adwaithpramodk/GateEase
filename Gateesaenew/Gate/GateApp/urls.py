"""
URL configuration for Gate project.

The `urlpatterns` list routes URLs to views. For more information please see:
    https://docs.djangoproject.com/en/4.2/topics/http/urls/
Examples:
Function views
    1. Add an import:  from my_app import views
    2. Add a URL to urlpatterns:  path('', views.home, name='home')
Class-based views
    1. Add an import:  from other_app.views import Home
    2. Add a URL to urlpatterns:  path('', Home.as_view(), name='home')
Including another URLconf
    1. Import the include() function: from django.urls import include, path
    2. Add a URL to urlpatterns:  path('blog/', include('blog.urls'))
"""
from django.contrib import admin
from django.urls import path,include
from .views import *
urlpatterns = [
    path('', LandingPage.as_view(), name='landing'),
    path('login/', LoginPage.as_view(), name='LoginPage'),
   path('VerifyStudent',VerifyStudent.as_view(),name='verify_student'),
   path('Logout',Logout.as_view(),name='logout'),
   path('EditStudent/<int:id>',EditStudent.as_view(),name='edit_student'),
   path('AcceptStudent/<int:lid>',AcceptStudent.as_view(),name='AcceptStudent'),
   path('RejectStudent/<int:lid>',RejectStudent.as_view(),name='RejectStudent'),
   path('DeleteStudent/<int:id>',DeleteStudent.as_view(),name='DeleteStudent'),
   path('ManageMentor',ManageMentor.as_view(),name='mng_mntr'),
   path('EditMentor/<int:id>',EditMentor.as_view(),name='edit_mentor'),
   path('DeleteMentor/<int:id>',DeleteMentor.as_view(),name='edit_mentor'),
   path('ManageDepartment',ManageDepartment.as_view(),name='mng_dep'),
   path('DeleteDepartment/<int:id>',DeleteDepartment.as_view(),name='mng_dep'),
   path('AssignDepartment',AssignDepartment.as_view(),name='assn_dep'),
   path('DeleteAssignDept/<int:id>',DeleteAssignDept.as_view(),name='DeleteAssignDept'),
    path('Pass',Pass.as_view(),name='pass'),
    path('export-pass-pdf/',ExportPassPDF.as_view(), name='export_pass_pdf'),
    path('ComplaintManage',ComplaintManage.as_view(),name='complaint_mng'),
    path('SendReply/<int:id>',SendReply.as_view(),name='complaint_mng'),
    path('ManageSecurity',ManageSecurity.as_view(),name='mng_security'),
    path('ManageClass',ManageClass.as_view(),name='mng_class'),
    path('DeleteClass/<int:id>',DeleteClass.as_view(),name='mng_class'),
    path('AssignClass',AssignClass.as_view(),name='AssignClass'),
    path('DeleteAssignClass/<int:id>',DeleteAssignClass.as_view(),name='DeleteAssignClass'),
    path('HomePage',HomePage.as_view(),name='homepage'),
    path('AddMentor',AddMentor.as_view(),name='add_mntr'),
    path('AddDepartment',AddDepartment.as_view(),name='add_dep'),
    path('AddSecurity',AddSecurity.as_view(),name='add_security'),
    path('EditSecurity/<int:id>',EditSecurity.as_view(),name='edit_security'),
    path('DeleteSecurity/<int:id>',DeleteSecurity.as_view(),name='edit_security'),
    path('AddClass',AddClass.as_view(),name='add_class'),
    path('UploadImage/<int:s_id>',UploadImage.as_view(),name='UploadImage'),


########################API#############################

    path('UserReg',UserReg_api.as_view(),name='userreg'), 
    path('LoginpageAPI',LoginpageAPI.as_view(),name='loginpageapi'),
    path('ApplypassAPI/<int:lid>',ApplypassAPI.as_view(),name='applypassapi'),
    path('StudentInfo_api/<int:lid>',StudentInfo_api.as_view(),name='StudentInfo_api'),
    path('ViewcomplaintAPI/<int:lid>',ViewcomplaintAPI.as_view(),name='viewcomplaint_api'),
    path('ExitPassTimelineAPI/<int:lid>/', ExitPassTimelineAPI.as_view()),
    
################################################################################
    path('Mentorinfo_api/<int:lid>',Mentorinfo_api.as_view()),
    path('MentorDashboardStatsAPI/<int:lid>', MentorDashboardStatsAPI.as_view()),
    path('Pendingpass_api/<int:lid>',Pendingpass_api.as_view()),
    path('approve',ApproveExitPassAPI.as_view()),
    path("reject", RejectExitPassAPI.as_view()),
    path("StudentListAPI/<int:lid>", StudentListAPI.as_view()),
    path('GroupPassAPI/<int:lid>', GroupPassAPI.as_view()),
    path("MentorPassAnalytics/<int:lid>", getallpasses.as_view()),
    path('MentorExitReportAPI/<int:lid>', MentorExitReportAPI.as_view()),
    path('SecurityApprovedPassAPI/<int:lid>', SecurityApprovedPassAPI.as_view()),
    path('Securityinfo_api/<int:lid>',Securityinfo_api.as_view()),
    path('ForgetPassword',ForgetPassword.as_view()),
    path('ResetPassword', ResetPasswordAPI.as_view()),
    path('AcceptPass',AcceptPass.as_view()),
    path('RejectPass',RejectPass.as_view()),
    path('Approvepassadmin/<int:id>',Approvepassadmin.as_view(),name='Approvepassadmin'),
    path('Rejectpassadmin/<int:id>',Rejectpassadmin.as_view(),name='Rejectpassadmin'),
    path('CheckPassStatus', CheckPassStatus.as_view()),
    path('GenerateQRCode', GenerateQRCodeAPI.as_view()),
    path('SecurityGroupPassListAPI', SecurityGroupPassListAPI.as_view()),
    path('ProceedGroupPassAPI', ProceedGroupPassAPI.as_view()),
    path('register_device_token/', RegisterDeviceTokenAPI.as_view()),
    path('update_device_token/', UpdateDeviceTokenAPI.as_view()),
    path('delete_device_token/', DeleteDeviceTokenAPI.as_view()),




]

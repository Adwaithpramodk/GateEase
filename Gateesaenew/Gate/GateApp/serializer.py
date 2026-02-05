from .models import *
from rest_framework.serializers import ModelSerializer
from rest_framework import serializers

class LoginSerializer(ModelSerializer):
    class Meta:
        model=Logintable
        fields='__all__'

class DepartmentSerializer(ModelSerializer):
    class Meta:
        model=departmenttable
        fields='__all__'


class ClassSerializer(ModelSerializer):
    class Meta:
        model=classstable
        fields=['id','class_name', 'year']
    

class StudentSerializer(ModelSerializer):
    class Meta:
        model=studenttable
        fields='__all__'

class StudentSerializer1(ModelSerializer):
    dept = serializers.CharField(source='classs.department_id.name')
    stu_class = serializers.CharField(source='classs.class_name')
    class Meta:
        model=studenttable
        fields=['name', 'dept','admn_no','stu_class','Photo']

class MentorSerializer(ModelSerializer):
    departmentname=serializers.CharField(source='department.name')
    class Meta:
        model=mentortable
        fields=['name','email','phone','departmentname','image']

class ExitpassSerializer(serializers.ModelSerializer):
    name = serializers.CharField(source='student_id.name', read_only=True)
    final_status = serializers.ReadOnlyField()
    time = serializers.TimeField(format='%I:%M %p')

    classs = serializers.CharField(
        source='student_id.classs.class_name',
        read_only=True
    )

    class Meta:
        model = exitpasstable
        fields = '__all__' 
        # [    'id','reason','time','mentor_status','security_status',
        #     'created_at','approved_at','scanned_at',
        #     'qrcode','reject_reason','name','classs'
        # ]
class ExitpassSerializer1(serializers.ModelSerializer):
    name = serializers.CharField(source='student_id.name', read_only=True)
    time = serializers.TimeField(format='%I:%M %p')
    
    class Meta:
        model = exitpasstable
        fields = ['mentor_status', 'security_status','reason','time','name']




class ComplaintSerializer(ModelSerializer):
    class Meta:
        model=complainttable
        fields='__all__'

class SecuritySerializer(ModelSerializer):
    class Meta:
        model=securitytable
        fields=['id','name','email','phone','LOGINID','Photo']

class ClassasignSerializer(ModelSerializer):
    class Meta:
        model=class_assigntable
        fields='__all__'

class DepartmentassignSerializer(ModelSerializer):
    class Meta:
        model=dept_assigntable
        fields='__all__'

class AlertSerializer(ModelSerializer):
    class Meta:
        model=alerttable
        fields='__all__'
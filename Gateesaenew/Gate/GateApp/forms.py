from django.forms import ModelForm

from GateApp.models import *


class AddMentorForm(ModelForm):
    class Meta:
        model=mentortable
        fields=['name','email','phone','department','image']
class AddDepartmentForm(ModelForm):
    class Meta:
        model=departmenttable
        fields=['name']

class ComplaintReplyForm(ModelForm):
    class Meta:
        model=complainttable
        fields=['reply']

class AddSecurityForm(ModelForm):
    class Meta:
        model=securitytable
        fields=['name','phone','email','Photo']

class AddClassForm(ModelForm):
    class Meta:
        model=classstable
        fields=['class_name','admission_year', 'department_id']

# class EditStudentForm(ModelForm):
#     class Meta:
#         model = studenttable
#         fields = ['name', 'email', 'phone', 'admn_no', 'classs']
from django import forms
from django.forms import ModelForm
from .models import studenttable

class EditStudentForm(ModelForm):
    class Meta:
        model = studenttable
        fields = ['name', 'email', 'phone', 'admn_no', 'classs']

        widgets = {
            "name": forms.TextInput(attrs={
                "required": True,
                "minlength": 3,
                "placeholder": "Enter student name"
            }),
            "email": forms.EmailInput(attrs={
                "required": True,
                "placeholder": "Enter email address"
            }),
            "phone": forms.TextInput(attrs={
                "required": True,
                "pattern": "[0-9]{10}",
                "maxlength": 10,
                "placeholder": "10-digit phone number",
                "title": "Enter a valid 10 digit number"
            }),
            "admn_no": forms.TextInput(attrs={
                "required": True,
                "placeholder": "Admission number"
            }),
            "classs": forms.Select(attrs={
    "required": True
})

        }
    def clean_name(self):
        name = self.cleaned_data.get("name")
        if len(name) < 3:
            raise forms.ValidationError("Name must have at least 3 characters")
        return name
    def clean_admn_no(self):
        admn_no = self.cleaned_data.get("admn_no")

        if admn_no < 1000:
            raise forms.ValidationError("Admission number must be at least 4 digits")

        return admn_no



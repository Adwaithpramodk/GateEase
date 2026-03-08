from django import forms
from django.forms import ModelForm
from .models import *
from datetime import datetime as dt


class AddMentorForm(ModelForm):
    class Meta:
        model = mentortable
        fields = ['name', 'email', 'phone', 'department', 'image']
        widgets = {
            'name': forms.TextInput(attrs={
                'required': True,
                'minlength': 3,
                'placeholder': 'Full name',
            }),
            'email': forms.EmailInput(attrs={
                'required': True,
                'placeholder': 'mentor@example.com',
            }),
            'phone': forms.TextInput(attrs={
                'required': True,
                'pattern': '[0-9]{10}',
                'maxlength': 10,
                'placeholder': '10-digit phone number',
                'title': 'Enter a valid 10-digit phone number',
            }),
        }

    def clean_name(self):
        name = self.cleaned_data.get('name', '').strip()
        if len(name) < 3:
            raise forms.ValidationError("Name must be at least 3 characters")
        return name

    def clean_phone(self):
        phone = str(self.cleaned_data.get('phone', '')).strip()
        if not phone.isdigit() or len(phone) != 10:
            raise forms.ValidationError("Enter a valid 10-digit phone number (digits only)")
        return int(phone)


class AddDepartmentForm(ModelForm):
    class Meta:
        model = departmenttable
        fields = ['name']
        widgets = {
            'name': forms.TextInput(attrs={
                'required': True,
                'minlength': 2,
                'placeholder': 'Department name',
            }),
        }

    def clean_name(self):
        name = self.cleaned_data.get('name', '').strip()
        if not name or len(name) < 2:
            raise forms.ValidationError("Department name must be at least 2 characters")
        if departmenttable.objects.filter(name__iexact=name).exclude(pk=self.instance.pk if self.instance else None).exists():
            raise forms.ValidationError("A department with this name already exists")
        return name


class ComplaintReplyForm(ModelForm):
    class Meta:
        model = complainttable
        fields = ['reply']
        widgets = {
            'reply': forms.Textarea(attrs={
                'required': True,
                'rows': 4,
                'minlength': 5,
                'placeholder': 'Type your reply here...',
            }),
        }

    def clean_reply(self):
        reply = self.cleaned_data.get('reply', '').strip()
        if not reply or len(reply) < 5:
            raise forms.ValidationError("Reply must be at least 5 characters")
        return reply


class AddSecurityForm(ModelForm):
    class Meta:
        model = securitytable
        fields = ['name', 'phone', 'email', 'Photo']
        widgets = {
            'name': forms.TextInput(attrs={
                'required': True,
                'minlength': 3,
                'placeholder': 'Full name',
            }),
            'email': forms.EmailInput(attrs={
                'required': True,
                'placeholder': 'security@example.com',
            }),
            'phone': forms.TextInput(attrs={
                'required': True,
                'pattern': '[0-9]{10}',
                'maxlength': 10,
                'placeholder': '10-digit phone number',
                'title': 'Enter a valid 10-digit phone number',
            }),
        }

    def clean_name(self):
        name = self.cleaned_data.get('name', '').strip()
        if len(name) < 3:
            raise forms.ValidationError("Name must be at least 3 characters")
        return name

    def clean_phone(self):
        phone = str(self.cleaned_data.get('phone', '')).strip()
        if not phone.isdigit() or len(phone) != 10:
            raise forms.ValidationError("Enter a valid 10-digit phone number (digits only)")
        return int(phone)


class AddClassForm(ModelForm):
    class Meta:
        model = classstable
        fields = ['class_name', 'admission_year', 'department_id']
        widgets = {
            'class_name': forms.TextInput(attrs={
                'required': True,
                'minlength': 2,
                'placeholder': 'e.g. CSE-A',
            }),
            'admission_year': forms.NumberInput(attrs={
                'required': True,
                'min': 2000,
                'max': dt.now().year,
                'placeholder': str(dt.now().year),
            }),
        }

    def clean_class_name(self):
        name = self.cleaned_data.get('class_name', '').strip()
        if not name or len(name) < 2:
            raise forms.ValidationError("Class name must be at least 2 characters")
        return name

    def clean_admission_year(self):
        year = self.cleaned_data.get('admission_year')
        current_year = dt.now().year
        if year is None or year < 2000 or year > current_year:
            raise forms.ValidationError(f"Admission year must be between 2000 and {current_year}")
        return year


class EditStudentForm(ModelForm):
    class Meta:
        model = studenttable
        fields = ['name', 'email', 'phone', 'admn_no', 'classs']
        widgets = {
            "name": forms.TextInput(attrs={
                "required": True,
                "minlength": 3,
                "placeholder": "Enter student name",
            }),
            "email": forms.EmailInput(attrs={
                "required": True,
                "placeholder": "Enter email address",
            }),
            "phone": forms.TextInput(attrs={
                "required": True,
                "pattern": "[0-9]{10}",
                "maxlength": 10,
                "placeholder": "10-digit phone number",
                "title": "Enter a valid 10-digit number",
            }),
            "admn_no": forms.TextInput(attrs={
                "required": True,
                "placeholder": "Admission number",
            }),
            "classs": forms.Select(attrs={
                "required": True,
            }),
        }

    def clean_name(self):
        name = self.cleaned_data.get("name", "").strip()
        if len(name) < 3:
            raise forms.ValidationError("Name must have at least 3 characters")
        return name

    def clean_phone(self):
        phone = str(self.cleaned_data.get("phone", "")).strip()
        if not phone.isdigit() or len(phone) != 10:
            raise forms.ValidationError("Enter a valid 10-digit phone number (digits only)")
        return int(phone)

    def clean_admn_no(self):
        admn_no = self.cleaned_data.get("admn_no")
        if admn_no < 1000:
            raise forms.ValidationError("Admission number must be at least 4 digits")
        return admn_no

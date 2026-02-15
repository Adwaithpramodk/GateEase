from django.db import models

class Logintable(models.Model):
    username=models.CharField(max_length=100,null=True,blank=True)
    password=models.CharField(max_length=100,null=True,blank=True)
    usertype=models.CharField(max_length=100,null=True,blank=True)

class departmenttable(models.Model):
    name=models.CharField(max_length=100,null=True,blank=True)

class classstable(models.Model):
    class_name=models.CharField(max_length=100,null=True,blank=True)
    admission_year=models.IntegerField(null=True,blank=True)
    department_id=models.ForeignKey(departmenttable,on_delete=models.CASCADE,null=True,blank=True)
    
    def __str__(self):
        return self.class_name
    
    @property
    def current_year(self):
        if not self.admission_year:
            return None
        
        from datetime import datetime
        current_year = datetime.now().year
        current_month = datetime.now().month
        if current_month >= 6:
            academic_year = current_year
        else:
            academic_year = current_year - 1
        
        years_since_admission = academic_year - self.admission_year
        batch_current_year = years_since_admission + 1
        
        return max(1, min(4, batch_current_year))
    
    @property
    def is_graduated(self):
        if not self.current_year:
            return False
        return self.current_year > 4
    
    def get_year_label(self):
        year = self.current_year
        if not year:
            return "Unknown"
        
        year_labels = {
            1: "1st Year",
            2: "2nd Year", 
            3: "3rd Year",
            4: "4th Year"
        }
        return year_labels.get(year, "Graduated")

class studenttable(models.Model):
    name=models.CharField(max_length=100,null=True,blank=True)
    email=models.CharField(max_length=100,null=True,blank=True)
    admn_no=models.IntegerField(null=True,blank=True)
    phone=models.BigIntegerField(null=True,blank=True)
    LOGINID=models.ForeignKey(Logintable,on_delete=models.CASCADE,null=True,blank=True)
    
    classs=models.ForeignKey(classstable,on_delete=models.CASCADE,null=True,blank=True)
    
    Photo = models.FileField(upload_to='profile_photos/students/', null=True, blank=True)
    
    @property
    def current_year(self):
        if not self.classs:
            return None
        return self.classs.current_year
    
    @property
    def department(self):
        if not self.classs:
            return None
        return self.classs.department_id
    
    @property
    def admission_year(self):
        if not self.classs:
            return None
        return self.classs.admission_year
    
    def get_year_label(self):
        if not self.classs:
            return "No Batch Assigned"
        return self.classs.get_year_label()
    
    def get_assigned_mentor(self):
        if not self.classs:
            return None
        
        try:
            assignment = class_assigntable.objects.filter(class_id=self.classs).first()
            return assignment.mentor_id if assignment else None
        except:
            return None
    
    def __str__(self):
        batch_name = self.classs.class_name if self.classs else "No Batch"
        return f"{self.name} ({batch_name})"


class mentortable(models.Model):
    name=models.CharField(max_length=100,null=True,blank=True)
    email=models.CharField(max_length=100,null=True,blank=True)
    phone=models.BigIntegerField(null=True,blank=True)
    LOGINID=models.ForeignKey(Logintable,on_delete=models.CASCADE,null=True,blank=True)
    department=models.ForeignKey(departmenttable,on_delete=models.CASCADE,null=True,blank=True)
    image = models.FileField(upload_to='profile_photos/mentors/', null=True, blank=True)


class exitpasstable(models.Model):
    student_id=models.ForeignKey(studenttable,on_delete=models.CASCADE,null=True,blank=True)
    mentor_id=models.ForeignKey(mentortable,on_delete=models.CASCADE,null=True,blank=True)
    reason=models.TextField(max_length=100,null=True,blank=True)
    time=models.TimeField(null=True,blank=True)
    mentor_status=models.CharField(max_length=100,null=True,blank=True)
    security_status=models.CharField(max_length=100,null=True,blank=True)
    created_at=models.DateTimeField(auto_now_add=True)
    approved_at=models.DateTimeField(null=True,blank=True)
    scanned_at=models.DateTimeField(null=True,blank=True)
    qrcode = models.FileField(null=True, blank=True)
    reject_reason = models.TextField(null=True, blank=True)
    is_group_pass = models.BooleanField(default=False)


class complainttable(models.Model):
    student_id=models.ForeignKey(studenttable,on_delete=models.CASCADE,null=True,blank=True)
    complaint=models.TextField(max_length=200,null=True,blank=True)
    reply=models.TextField(max_length=200,null=True,blank=True)
    date=models.DateField(auto_now_add=True)

class securitytable(models.Model):
    name=models.CharField(max_length=100,null=True,blank=True)
    email=models.CharField(max_length=100,null=True,blank=True)
    phone=models.BigIntegerField(null=True,blank=True)
    LOGINID=models.ForeignKey(Logintable,on_delete=models.CASCADE,null=True,blank=True)
    Photo = models.FileField(upload_to='profile_photos/security/', null=True, blank=True)


class class_assigntable(models.Model):
    class_id=models.ForeignKey(classstable,on_delete=models.CASCADE,null=True,blank=True)
    
    # The mentor managing this batch
    mentor_id=models.ForeignKey(mentortable,on_delete=models.CASCADE,null=True,blank=True,)
    
    def get_current_students(self):
        return studenttable.objects.filter(classs=self.class_id)
    
    def get_batch_current_year(self):
        if self.class_id:
            return self.class_id.current_year
        return None
    
    def __str__(self):
        mentor_name = self.mentor_id.name if self.mentor_id else "No Mentor"
        batch_name = self.class_id.class_name if self.class_id else "No Batch"
        return f"{mentor_name} → {batch_name}"

class dept_assigntable(models.Model):
    department_id=models.ForeignKey(departmenttable,on_delete=models.CASCADE,null=True,blank=True)
    mentor_id=models.ForeignKey(mentortable,on_delete=models.CASCADE,null=True,blank=True)
    status=models.CharField(max_length=100,null=True,blank=True)
    date=models.DateField(null=True,blank=True)

class alerttable(models.Model):
    image_url=models.CharField(max_length=200,null=True,blank=True)
    status=models.CharField(max_length=100,null=True,blank=True)

class MentorDeviceToken(models.Model):
    mentor = models.ForeignKey(mentortable, on_delete=models.CASCADE, related_name='device_tokens')
    device_token = models.CharField(max_length=255, unique=True)
    platform = models.CharField(max_length=10, choices=[('android', 'Android'), ('ios', 'iOS')])
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = 'Mentor Device Token'
        verbose_name_plural = 'Mentor Device Tokens'
        unique_together = ('mentor', 'device_token')

    def __str__(self):
        return f"{self.mentor.name} - {self.platform} - {self.device_token[:20]}..."

class PasswordResetOTP(models.Model):
    email = models.EmailField()
    otp = models.CharField(max_length=6)
    created_at = models.DateTimeField(auto_now_add=True)
    is_used = models.BooleanField(default=False)


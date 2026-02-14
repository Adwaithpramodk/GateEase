from django.db import models

class Logintable(models.Model):
    username=models.CharField(max_length=100,null=True,blank=True)
    password=models.CharField(max_length=100,null=True,blank=True)
    usertype=models.CharField(max_length=100,null=True,blank=True)

class departmenttable(models.Model):
    name=models.CharField(max_length=100,null=True,blank=True)

class classstable(models.Model):
    class_name=models.CharField(max_length=100,null=True,blank=True)
    year=models.IntegerField(null=True,blank=True)
    department_id=models.ForeignKey(departmenttable,on_delete=models.CASCADE,null=True,blank=True)

    def __str__(self):
        return self.class_name

class studenttable(models.Model):
    name=models.CharField(max_length=100,null=True,blank=True)
    email=models.CharField(max_length=100,null=True,blank=True)
    admn_no=models.IntegerField(null=True,blank=True)
    phone=models.BigIntegerField(null=True,blank=True)
    LOGINID=models.ForeignKey(Logintable,on_delete=models.CASCADE,null=True,blank=True)
    classs=models.ForeignKey(classstable,on_delete=models.CASCADE,null=True,blank=True)
    Photo = models.FileField(upload_to='profile_photos/students/', null=True, blank=True)


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
    mentor_id=models.ForeignKey(mentortable,on_delete=models.CASCADE,null=True,blank=True)

class dept_assigntable(models.Model):
    department_id=models.ForeignKey(departmenttable,on_delete=models.CASCADE,null=True,blank=True)
    mentor_id=models.ForeignKey(mentortable,on_delete=models.CASCADE,null=True,blank=True)
    status=models.CharField(max_length=100,null=True,blank=True)
    date=models.DateField(null=True,blank=True)

class alerttable(models.Model):
    image_url=models.CharField(max_length=200,null=True,blank=True)
    status=models.CharField(max_length=100,null=True,blank=True)

class MentorDeviceToken(models.Model):
    """
    Model to store FCM device tokens for mentors
    Allows sending push notifications when students request passes
    """
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


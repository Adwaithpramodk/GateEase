from django.contrib import admin

from .models import *


# Register your models here.
admin.site.register(Logintable)
admin.site.register(departmenttable)
admin.site.register(classstable)
admin.site.register(studenttable)
admin.site.register(mentortable)
admin.site.register(exitpasstable)
admin.site.register(complainttable)
admin.site.register(securitytable)
admin.site.register(class_assigntable)
admin.site.register(dept_assigntable)
admin.site.register(alerttable)


# Custom admin for MentorDeviceToken
@admin.register(MentorDeviceToken)
class MentorDeviceTokenAdmin(admin.ModelAdmin):
    list_display = ('mentor', 'platform', 'is_active', 'created_at', 'updated_at', 'token_preview')
    list_filter = ('platform', 'is_active', 'created_at')
    search_fields = ('mentor__name', 'device_token')
    readonly_fields = ('created_at', 'updated_at')
    
    def token_preview(self, obj):
        """Show first 20 characters of token"""
        return f"{obj.device_token[:20]}..." if obj.device_token else ""
    token_preview.short_description = 'Token Preview'


@admin.register(PasswordResetOTP)
class PasswordResetOTPAdmin(admin.ModelAdmin):
    list_display = ('email', 'otp', 'is_used', 'created_at')
    list_filter = ('is_used', 'created_at')
    search_fields = ('email',)

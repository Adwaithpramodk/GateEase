from django.contrib import admin
from django.db.models import F

from .models import *


# Register your models here.
@admin.register(Logintable)
class LoginAdmin(admin.ModelAdmin):
    exclude = ('password', 'last_totp_step', 'session_version')
    list_display = ('username', 'usertype')
    actions = ('revoke_sessions',)

    def has_add_permission(self, request):
        return False

    def save_model(self, request, obj, form, change):
        if change and {'username', 'usertype'} & set(form.changed_data):
            obj.session_version = F('session_version') + 1
        super().save_model(request, obj, form, change)

    @admin.action(description='Revoke selected GateEase sessions')
    def revoke_sessions(self, request, queryset):
        count = queryset.update(session_version=F('session_version') + 1)
        self.message_user(request, f'Sessions revoked for {count} accounts.')


admin.site.register(departmenttable)
admin.site.register(classstable)
admin.site.register(studenttable)
admin.site.register(mentortable)
admin.site.register(exitpasstable)
admin.site.register(complainttable)
admin.site.register(announcementtable)
admin.site.register(securitytable)
admin.site.register(class_assigntable)
admin.site.register(dept_assigntable)


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
    list_display = ('email', 'is_used', 'created_at')
    list_filter = ('is_used', 'created_at')
    search_fields = ('email',)

    exclude = ('otp',)

    def has_add_permission(self, request):
        return False

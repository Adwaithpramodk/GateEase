"""
Firebase Cloud Messaging service for sending push notifications to mentors
"""
import firebase_admin
from firebase_admin import credentials, messaging
from django.conf import settings
import os

# Initialize Firebase Admin SDK
def initialize_firebase():
    """
    Initialize Firebase Admin SDK with service account credentials
    This should be called when Django starts
    """
    try:
        # Check if Firebase is already initialized
        if not firebase_admin._apps:
            # Check for generic environment variable for the whole JSON content
            service_account_json = os.environ.get('FIREBASE_SERVICE_ACCOUNT_JSON')
            
            if service_account_json:
                import json
                cred_dict = json.loads(service_account_json)
                cred = credentials.Certificate(cred_dict)
                firebase_admin.initialize_app(cred)
                print("Firebase Admin SDK initialized from environment variable")
            else:
                # Path to your Firebase service account JSON file
                cred_path = os.path.join(settings.BASE_DIR, 'firebase-service-account.json')
                
                if os.path.exists(cred_path):
                    cred = credentials.Certificate(cred_path)
                    firebase_admin.initialize_app(cred)
                    print("Firebase Admin SDK initialized successfully from file")
                else:
                    print(f"Firebase service account file not found at: {cred_path}")
                    print("Push notifications will not work until you add the file or set FIREBASE_SERVICE_ACCOUNT_JSON env var")
    except Exception as e:
        print(f"Firebase initialization error: {e}")


def send_notification_to_mentor(device_tokens, student_name, class_name, reason, pass_id):
    """
    Send push notification to mentor when student requests a pass
    
    Args:
        device_tokens (list): List of FCM device tokens
        student_name (str): Name of the student
        class_name (str): Name of the class
        reason (str): Reason for the pass
        pass_id (int): ID of the pass request
    
    Returns:
        int: Number of successful notifications sent
    """
    if not device_tokens:
        print("⚠️ No device tokens provided")
        return 0
    
    # Create notification message
    title = "New Pass Request 📝"
    body = f"{student_name} from {class_name} requested a pass"
    
    # Data payload to send with notification
    data = {
        'pass_id': str(pass_id),
        'student_name': student_name,
        'class_name': class_name,
        'reason': reason,
        'type': 'pass_request'
    }
    
    successful_sends = 0
    failed_tokens = []
    
    for token in device_tokens:
        try:
            # Create message
            message = messaging.Message(
                notification=messaging.Notification(
                    title=title,
                    body=body,
                ),
                data=data,
                token=token,
                android=messaging.AndroidConfig(
                    priority='high',
                    notification=messaging.AndroidNotification(
                        icon='ic_notification',
                        color='#7B6CF6',
                        sound='default'
                    )
                ),
                apns=messaging.APNSConfig(
                    payload=messaging.APNSPayload(
                        aps=messaging.Aps(
                            sound='default',
                            badge=1
                        )
                    )
                )
            )
            
            # Send message
            response = messaging.send(message)
            successful_sends += 1
            print(f"✅ Notification sent successfully to token: {token[:20]}... | Response: {response}")
            
        except messaging.UnregisteredError:
            print(f"❌ Token is unregistered: {token[:20]}...")
            failed_tokens.append(token)
        except messaging.SenderIdMismatchError:
            print(f"❌ Sender ID mismatch for token: {token[:20]}...")
            failed_tokens.append(token)
        except Exception as e:
            print(f"❌ Error sending notification to {token[:20]}...: {e}")
            failed_tokens.append(token)
    
    # You can handle failed tokens here (e.g., mark them as inactive in DB)
    if failed_tokens:
        print(f"⚠️ Failed to send to {len(failed_tokens)} tokens")
    
    return successful_sends


def send_pass_status_notification(device_tokens, student_name, status, reason=None):
    """
    Send notification when pass status changes (approved/rejected)
    
    Args:
        device_tokens (list): List of FCM device tokens
        student_name (str): Name of the student
        status (str): Status of the pass ('approved' or 'rejected')
        reason (str, optional): Rejection reason if applicable
    
    Returns:
        int: Number of successful notifications sent
    """
    if not device_tokens:
        return 0
    
    if status == 'approved':
        title = "Pass Approved ✅"
        body = f"Your pass request has been approved by the mentor"
    else:
        title = "Pass Rejected ❌"
        body = f"Your pass request has been rejected"
        if reason:
            body += f". Reason: {reason}"
    
    data = {
        'type': 'pass_status_update',
        'status': status,
        'student_name': student_name
    }
    
    if reason:
        data['reason'] = reason
    
    successful_sends = 0
    
    for token in device_tokens:
        try:
            message = messaging.Message(
                notification=messaging.Notification(
                    title=title,
                    body=body,
                ),
                data=data,
                token=token,
            )
            
            messaging.send(message)
            successful_sends += 1
            
        except Exception as e:
            print(f"❌ Error sending status notification: {e}")
    
    return successful_sends

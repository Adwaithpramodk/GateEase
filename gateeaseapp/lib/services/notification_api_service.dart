import 'package:flutter/foundation.dart';
import 'package:gateeaseapp/api_config.dart';

/// Service class to handle API calls related to notifications
class NotificationApiService {
  /// Register device token with the backend
  ///
  /// [loginId] - The login ID of the mentor
  /// [deviceToken] - The FCM device token
  /// [platform] - The platform (android/ios)
  static Future<bool> registerDeviceToken({
    required int loginId,
    required String deviceToken,
    required String platform,
  }) async {
    try {
      final response = await dio.post(
        '$baseurl/register_device_token/',
        data: {
          'login_id': loginId,
          'device_token': deviceToken,
          'platform': platform,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('✅ Device token registered successfully');
        return true;
      } else {
        debugPrint('❌ Failed to register device token: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error registering device token: $e');
      return false;
    }
  }

  /// Update device token (in case of token refresh)
  ///
  /// [loginId] - The login ID of the mentor
  /// [oldToken] - The old FCM device token
  /// [newToken] - The new FCM device token
  static Future<bool> updateDeviceToken({
    required int loginId,
    required String oldToken,
    required String newToken,
  }) async {
    try {
      final response = await dio.put(
        '$baseurl/update_device_token/',
        data: {
          'login_id': loginId,
          'old_token': oldToken,
          'new_token': newToken,
        },
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Device token updated successfully');
        return true;
      } else {
        debugPrint('❌ Failed to update device token: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error updating device token: $e');
      return false;
    }
  }

  /// Delete device token (on logout)
  ///
  /// [loginId] - The login ID of the mentor
  /// [deviceToken] - The FCM device token to delete
  static Future<bool> deleteDeviceToken({
    required int loginId,
    required String deviceToken,
  }) async {
    try {
      final response = await dio.delete(
        '$baseurl/delete_device_token/',
        data: {'login_id': loginId, 'device_token': deviceToken},
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Device token deleted successfully');
        return true;
      } else {
        debugPrint('❌ Failed to delete device token: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error deleting device token: $e');
      return false;
    }
  }
}

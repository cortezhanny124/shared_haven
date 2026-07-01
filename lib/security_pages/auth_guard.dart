import 'package:flutter_wallet/main.dart';
import 'package:hive/hive.dart';

class AuthGuard {
  static const String _lastActiveKey = 'lastActiveTimestamp';
  static const String _isAuthenticatedKey = 'isAuthenticated';
  static const int timeoutDuration = 10; // minutes

  // Track if we've already handled the resume to avoid duplicate checks
  static bool _isResumeCheckInProgress = false;

  static Future<void> checkAuthenticationOnResume() async {
    if (_isResumeCheckInProgress) {
      return;
    }

    _isResumeCheckInProgress = true;

    try {
      final box = Hive.box('walletBox');

      bool? isAuth = box.get(_isAuthenticatedKey);

      if (isAuth != true) {
        return;
      }

      int? lastActive = box.get(_lastActiveKey);

      if (lastActive != null) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final diffInMinutes = (now - lastActive) / (1000 * 60);

        if (diffInMinutes >= timeoutDuration) {
          await box.put(_isAuthenticatedKey, false);

          // Use NavigationService instead of context
          await NavigationService.navigateToPinVerification();
        }
      }
    } catch (e) {
      throw Exception('AuthGuard: ERROR - $e');
    } finally {
      _isResumeCheckInProgress = false;
    }
  }

  // Update last active timestamp (call this on user interaction)
  static Future<void> updateLastActive() async {
    final box = Hive.box('walletBox');
    await box.put(_lastActiveKey, DateTime.now().millisecondsSinceEpoch);
  }

  // Save timestamp when app goes to background
  static Future<void> saveLastActiveTimestamp() async {
    final box = Hive.box('walletBox');
    await box.put(_lastActiveKey, DateTime.now().millisecondsSinceEpoch);
  }

  // Set authentication status (call after successful PIN verification)
  static Future<void> setAuthenticated(bool value) async {
    final box = Hive.box('walletBox');
    await box.put(_isAuthenticatedKey, value);
    if (value) {
      // Update timestamp when setting authenticated
      await updateLastActive();
    }
  }

  // Clear authentication (logout)
  static Future<void> clearAuthentication() async {
    final box = Hive.box('walletBox');
    await box.put(_isAuthenticatedKey, false);
    await box.delete(_lastActiveKey);
  }

  // Check if user is currently authenticated
  static Future<bool> isAuthenticated() async {
    final box = Hive.box('walletBox');
    bool? isAuth = box.get(_isAuthenticatedKey);
    return isAuth == true;
  }
}

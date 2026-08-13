import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ErrorDialog {
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String message,
    String? actionText,
    VoidCallback? onAction,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF1E293B).withValues(alpha: 0.95),
                  const Color(0xFF0F172A).withValues(alpha: 0.95),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.red.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Error icon
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Title
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),

                  // Message
                  Text(
                    message,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: Colors.white70,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // Action button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        onAction?.call();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        actionText ?? 'OK',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Helper method to parse Firebase auth errors and show user-friendly messages
  static Future<void> showAuthError(BuildContext context, String errorCode) {
    // Clean up the error code if it contains "Exception: " or is a raw Firebase error
    String cleanErrorCode = errorCode.replaceAll('Exception: ', '').trim();

    // Extract code from format like "[firebase_auth/invalid-credential] ..."
    final RegExp regex = RegExp(r'\[(firebase_auth\/[\w-]+)\]');
    final match = regex.firstMatch(cleanErrorCode);
    if (match != null) {
      cleanErrorCode = match.group(1) ?? cleanErrorCode;
    }

    String title = 'Authentication Error';
    String message = 'An error occurred. Please try again.';

    switch (cleanErrorCode) {
      case 'firebase_auth/invalid-credential':
      case 'firebase_auth/wrong-password':
        title = 'Incorrect Credentials';
        message =
            'The ID Number or password you entered is incorrect. Please check and try again.';
        break;
      case 'firebase_auth/user-not-found':
        title = 'Account Not Found';
        message =
            'No account exists with this ID Number. Please check your ID Number or create a new account.';
        break;
      case 'firebase_auth/user-disabled':
        title = 'Account Disabled';
        message =
            'This account has been disabled. Please contact your institution administrator.';
        break;
      case 'firebase_auth/too-many-requests':
        title = 'Too Many Attempts';
        message =
            'Too many failed login attempts. Please wait a few minutes and try again.';
        break;
      case 'firebase_auth/email-already-in-use':
        title = 'Account Already Exists';
        message =
            'An account with this email already exists. Please use a different email or try logging in.';
        break;
      case 'firebase_auth/invalid-email':
        title = 'Invalid Email';
        message =
            'The email address format is invalid. Please check and try again.';
        break;
      case 'firebase_auth/operation-not-allowed':
        title = 'Operation Not Allowed';
        message = 'This sign-in method is not enabled. Please contact support.';
        break;
      case 'firebase_auth/weak-password':
        title = 'Weak Password';
        message =
            'Your password is too weak. Please use at least 6 characters with a mix of letters and numbers.';
        break;
      case 'firebase_auth/network-request-failed':
        title = 'Network Error';
        message =
            'Unable to connect to the server. Please check your internet connection and try again.';
        break;
      case 'id-already-taken':
        title = 'ID Number Taken';
        message =
            'This ID Number is already registered. Please check your ID Number or contact your administrator.';
        break;
      case 'invalid-institution-email':
        title = 'Invalid Email Domain';
        message =
            'Please use your institutional email address (e.g., your@institution.edu).';
        break;
      case 'password-mismatch':
        title = 'Passwords Don\'t Match';
        message =
            'The passwords you entered don\'t match. Please make sure both passwords are identical.';
        break;
      case 'account-already-exists':
        title = 'Account Already Exists';
        message =
            'You already have an account with this email. Please log in instead.';
        break;
      case 'firebase_auth/unauthorized-domain':
      case 'unauthorized-domain':
        title = 'Unauthorized Domain';
        message =
            'This domain is not authorized for authentication. Please add it to the Authorized Domains list in the Firebase Console.';
        break;
      case 'firebase_auth/popup-closed-by-user':
      case 'popup-closed-by-user':
        title = 'Sign In Cancelled';
        message =
            'The sign-in popup was closed before completion. Please try again.';
        break;
      case 'firebase_auth/cancelled-popup-request':
      case 'cancelled-popup-request':
        title = 'Request Cancelled';
        message = 'The sign-in request was cancelled. Please try again.';
        break;
      default:
        message = cleanErrorCode;
        break;
    }

    return show(context, title: title, message: message);
  }
}

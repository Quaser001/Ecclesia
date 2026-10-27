import '../../services/api_service.dart';

/// Produces a short, user-facing message for an error without leaking
/// stack traces or server internals.
class UserMessage {
  static String fromError(Object error) {
    if (error is ApiException) return error.message;
    final text = error.toString();
    if (text.toLowerCase().contains('socket') ||
        text.toLowerCase().contains('connection')) {
      return "Can't reach the CalFit server. Check your internet and try again.";
    }
    if (text.toLowerCase().contains('timeout')) {
      return 'That took too long. Please try again.';
    }
    return 'Something went wrong. Please try again.';
  }
}

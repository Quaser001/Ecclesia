import 'package:flutter/widgets.dart';

import '../../l10n/l10n.dart';

/// A short, user-facing message for an error, in the user's language,
/// without stack traces or server internals.
class UserMessage {
  static String of(BuildContext context, Object error) =>
      context.l10n.errorMessage(error);
}

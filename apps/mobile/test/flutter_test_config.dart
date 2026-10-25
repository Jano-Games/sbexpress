import 'dart:async';

import 'package:sbexpress/l10n/l10n.dart';

/// Most widget tests assert the Bangla text, so they run in Bangla. Tests of
/// the English default switch to it explicitly.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  appLanguage.value = AppLanguage.bn;
  await testMain();
}

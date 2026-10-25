import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../data/session/secure_session_store.dart';
import 'bn.dart';

/// UI language. English is the default; Bangla is chosen in More.
enum AppLanguage { en, bn }

/// The language every [tr] call reads. The app remounts when it changes.
final appLanguage = ValueNotifier<AppLanguage>(AppLanguage.en);

bool get isBangla => appLanguage.value == AppLanguage.bn;

String _fill(String text, Map<String, Object?> args) {
  var out = text;
  args.forEach((key, value) => out = out.replaceAll('{$key}', '$value'));
  return out;
}

/// [english] is both the English text and the key into [bnStrings].
/// Placeholders such as `{code}` are filled from [args] in either language.
String tr(String english, [Map<String, Object?> args = const {}]) =>
    _fill(isBangla ? (bnStrings[english] ?? english) : english, args);

/// Counted text. English picks [one] or [other]; Bangla has one form, keyed
/// by [other]. `{n}` is the count.
String trn(int n, String one, String other,
        [Map<String, Object?> args = const {}]) =>
    isBangla
        ? tr(other, {'n': n, ...args})
        : _fill(n == 1 ? one : other, {'n': n, ...args});

/// Remembers the chosen language on the device.
class LanguageStore {
  LanguageStore({FlutterSecureStorage? storage})
      : _storage = storage ?? SecureSessionStore.secureSessionStorage();

  static const key = 'sbx.language';
  final FlutterSecureStorage _storage;

  Future<void> load() async {
    try {
      final saved = await _storage.read(key: key);
      appLanguage.value =
          saved == AppLanguage.bn.name ? AppLanguage.bn : AppLanguage.en;
    } catch (_) {
      appLanguage.value = AppLanguage.en;
    }
  }

  Future<void> save(AppLanguage language) async {
    appLanguage.value = language;
    try {
      await _storage.write(key: key, value: language.name);
    } catch (_) {
      // The choice still applies for this run.
    }
  }
}

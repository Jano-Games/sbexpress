import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sbexpress/l10n/bn.dart';
import 'package:sbexpress/l10n/bn_admin.dart';
import 'package:sbexpress/l10n/bn_billing.dart';
import 'package:sbexpress/l10n/bn_core.dart';
import 'package:sbexpress/l10n/bn_finance.dart';
import 'package:sbexpress/l10n/bn_finance_ui.dart';
import 'package:sbexpress/l10n/bn_flights.dart';
import 'package:sbexpress/l10n/bn_flights_ui.dart';
import 'package:sbexpress/l10n/bn_flow.dart';
import 'package:sbexpress/l10n/bn_hub.dart';
import 'package:sbexpress/l10n/bn_photos.dart';
import 'package:sbexpress/l10n/bn_quick.dart';
import 'package:sbexpress/l10n/bn_round5.dart';
import 'package:sbexpress/l10n/bn_round6.dart';
import 'package:sbexpress/l10n/bn_round7a.dart';
import 'package:sbexpress/l10n/bn_round7b.dart';
import 'package:sbexpress/l10n/bn_scan.dart';
import 'package:sbexpress/l10n/bn_shared.dart';
import 'package:sbexpress/l10n/bn_team_ui.dart';
import 'package:sbexpress/l10n/l10n.dart';

/// Bangla letters; the taka sign ৳ (U+09F3) is a currency symbol, not text.
final _bangla = RegExp('[ঀ-৲৴-৿]');
final _literal = RegExp(r"'(?:[^'\\\n]|\\.)*'|" r'"(?:[^"\\\n]|\\.)*"');
final _trCall =
    RegExp(r"""\btr\(\s*('(?:[^'\\\n]|\\.)*'|"(?:[^"\\\n]|\\.)*")""");
final _trnCall = RegExp(
    r"""\btrn\([^,]+,\s*('(?:[^'\\\n]|\\.)*'|"(?:[^"\\\n]|\\.)*")\s*,\s*('(?:[^'\\\n]|\\.)*'|"(?:[^"\\\n]|\\.)*")""");
final _placeholder = RegExp(r'\{(\w+)\}');

/// Language names are written in their own script on purpose.
const _allowedBangla = {'বাংলা'};

Iterable<File> _sources() =>
    Directory('lib').listSync(recursive: true).whereType<File>().where((file) =>
        file.path.endsWith('.dart') &&
        !file.path.replaceAll(r'\', '/').contains('lib/l10n/'));

/// Source without whole-line comments, so examples in docs are not counted.
String _code(File file) => file
    .readAsLinesSync()
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

String _unquote(String literal) =>
    literal.substring(1, literal.length - 1).replaceAllMapped(RegExp(r'\\(.)'),
        (m) => switch (m.group(1)!) { 'n' => '\n', 't' => '\t', final c => c });

Set<String> _placeholders(String text) =>
    {for (final m in _placeholder.allMatches(text)) m.group(1)!};

void main() {
  test('screens hold no Bangla text outside the translation tables', () {
    final leftovers = <String>[];
    for (final file in _sources()) {
      for (final match in _literal.allMatches(_code(file))) {
        final value = _unquote(match.group(0)!);
        if (_bangla.hasMatch(value) && !_allowedBangla.contains(value)) {
          leftovers.add('${file.path}: ${match.group(0)}');
        }
      }
    }
    expect(leftovers, isEmpty);
  });

  test('every translated English string has a Bangla entry', () {
    final missing = <String>{};
    final interpolated = <String>[];
    for (final file in _sources()) {
      final text = _code(file);
      final keys = [
        for (final m in _trCall.allMatches(text)) m.group(1)!,
        for (final m in _trnCall.allMatches(text)) m.group(2)!,
      ];
      for (final literal in keys) {
        if (RegExp(r'(?<!\\)\$').hasMatch(literal)) {
          interpolated.add('${file.path}: $literal');
          continue;
        }
        final key = _unquote(literal);
        if (!bnStrings.containsKey(key)) missing.add('${file.path}: $key');
      }
    }
    expect(interpolated, isEmpty,
        reason: 'use {placeholders} instead of \$ inside tr()');
    expect(missing, isEmpty);
  });

  test('Bangla entries keep the same placeholders as their English keys', () {
    final mismatched = [
      for (final entry in bnStrings.entries)
        if (!_setEquals(_placeholders(entry.key), _placeholders(entry.value)))
          '${entry.key} → ${entry.value}'
    ];
    expect(mismatched, isEmpty);
  });

  test('a key shared by two tables has the same Bangla in both', () {
    const tables = {
      'shared': bnShared,
      'hub': bnHub,
      'admin': bnAdmin,
      'billing': bnBilling,
      'finance': bnFinance,
      'flights': bnFlights,
      'flightsUi': bnFlightsUi,
      'teamUi': bnTeamUi,
      'financeUi': bnFinanceUi,
      'flow': bnFlow,
      'quick': bnQuick,
      'round5': bnRound5,
      'round6': bnRound6,
      'scan': bnScan,
      'round7b': bnRound7b,
      'round7a': bnRound7a,
      'photos': bnPhotos,
      'core': bnCore,
    };
    final seen = <String, (String, String)>{};
    final clashes = <String>[];
    for (final MapEntry(key: table, value: strings) in tables.entries) {
      for (final MapEntry(:key, :value) in strings.entries) {
        final earlier = seen[key];
        if (earlier != null && earlier.$2 != value) {
          clashes.add('$key: ${earlier.$1} "${earlier.$2}" vs $table "$value"');
        }
        seen[key] ??= (table, value);
      }
    }
    expect(clashes, isEmpty);
  });

  test('English is the default and Bangla is looked up by the English text',
      () {
    final previous = appLanguage.value;
    addTearDown(() => appLanguage.value = previous);
    appLanguage.value = AppLanguage.en;
    expect(tr('Today'), 'Today');
    expect(trn(1, 'In {n} day', 'In {n} days'), 'In 1 day');
    expect(trn(3, 'In {n} day', 'In {n} days'), 'In 3 days');
    appLanguage.value = AppLanguage.bn;
    expect(tr('Today'), 'আজ');
    expect(trn(3, 'In {n} day', 'In {n} days'), '3 দিন পর');
    expect(tr('No Bangla yet {x}', {'x': 1}), 'No Bangla yet 1');
  });
}

bool _setEquals(Set<String> a, Set<String> b) =>
    a.length == b.length && a.containsAll(b);

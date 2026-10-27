/// Reads the machine-readable zone (MRZ) at the bottom of a passport or visa
/// page from the text found on a photo (ICAO 9303).
///
/// Only the kind of document, the name and the issuing country come out. The
/// document number and birth date are used to check the reading and are then
/// dropped; nothing else on the page is kept.
library;

enum TravelDocument { passport, visa }

/// What a good reading gives the flyer form.
class MrzReading {
  const MrzReading(
      {required this.kind,
      required this.surname,
      required this.givenNames,
      required this.issuingCountry});

  final TravelDocument kind;

  /// Title-cased, e.g. "Eriksson". Empty when the document has one name only.
  final String surname;

  /// Title-cased, e.g. "Anna Maria" or "Md Rifat".
  final String givenNames;

  /// The issuing state's code, e.g. "BGD"; one- and two-letter codes such as
  /// "D" lose their filler.
  final String issuingCountry;

  /// The name for the form's First name field: the given names, or the only
  /// name when there is just one.
  String get firstName => givenNames.isEmpty ? surname : givenNames;

  /// The name for the form's Last name field.
  String get lastName => givenNames.isEmpty ? '' : surname;
}

/// A two-line MRZ layout: TD3 passports and MRV-A / MRV-B visas.
class _Layout {
  const _Layout(this.kind, this.letter, this.length);
  final TravelDocument kind;
  final String letter;
  final int length;
}

const _layouts = [
  _Layout(TravelDocument.passport, 'P', 44),
  _Layout(TravelDocument.visa, 'V', 44),
  _Layout(TravelDocument.visa, 'V', 36),
];

/// A line may come out this many characters longer or shorter than it is.
const _slack = 2;

/// Finds the two MRZ lines in [text] and reads them. Null when no pair of
/// lines passes the document number and birth date check digits.
MrzReading? readMrz(String text) {
  final raw = text.split(RegExp(r'[\r\n]+'));
  // "«" is usually two chevrons read as one; when that fails, try one.
  for (final doubleChevron in const [true, false]) {
    final lines = [
      for (final line in raw)
        if (_clean(line, doubleChevron: doubleChevron) case final clean
            when clean.length >= 4)
          clean
    ];
    // The reader sometimes breaks one long line in two.
    final rows = [
      ...lines,
      for (var i = 0; i + 1 < lines.length; i++) lines[i] + lines[i + 1],
    ];
    for (final layout in _layouts) {
      for (var i = 0; i < rows.length; i++) {
        final first = rows[i];
        if (!first.startsWith(layout.letter) || !_fits(first, layout)) {
          continue;
        }
        for (var j = 0; j < rows.length; j++) {
          if (j == i || !_fits(rows[j], layout)) continue;
          final reading = _read(layout, first, rows[j]);
          if (reading != null) return reading;
        }
      }
    }
  }
  return null;
}

/// Uppercase, no spaces, look-alikes of the "<" filler turned into "<", and
/// anything else that cannot be in an MRZ dropped.
String _clean(String line, {required bool doubleChevron}) {
  // « is often "<<" read as one mark; right after the P or V it can only
  // be one.
  var out = line
      .toUpperCase()
      .replaceAll(RegExp(r'\s'), '')
      .replaceFirstMapped(RegExp('^([PV])«'), (m) => '${m[1]}<');
  if (doubleChevron) out = out.replaceAll('«', '<<');
  // «, ‹, 《, 〈, ⟨, ≤, a full-width <, (, [ and {.
  out = out.replaceAll(RegExp(r'[«‹《〈⟨≤＜(\[{]'), '<');
  return out.replaceAll(RegExp('[^A-Z0-9<]'), '');
}

bool _fits(String line, _Layout layout) =>
    (line.length - layout.length).abs() <= _slack;

MrzReading? _read(_Layout layout, String first, String second) {
  final number = second.substring(0, 9);
  final numberCheck = _digits(second.substring(9, 10));
  final birth = _digits(second.substring(13, 19));
  final birthCheck = _digits(second.substring(19, 20));
  if (!RegExp(r'^\d{6}$').hasMatch(birth)) return null;
  if (mrzCheckDigit(number) != int.tryParse(numberCheck) ||
      mrzCheckDigit(birth) != int.tryParse(birthCheck)) {
    return null;
  }
  // A state code is letters padded with fillers, e.g. "BGD" or "D<<".
  final country = _letters(first.substring(2, 5));
  if (!RegExp(r'^[A-Z]+<*$').hasMatch(country)) return null;
  final names = _names(_letters(first.substring(5)));
  if (names == null) return null;
  return MrzReading(
      kind: layout.kind,
      surname: names.surname,
      givenNames: names.given,
      issuingCountry: country.replaceAll('<', ''));
}

/// ICAO 9303 check digit: values 0–9, A=10 … Z=35, "<"=0, weighted 7-3-1,
/// summed, modulo 10. Null when [field] holds another character.
int? mrzCheckDigit(String field) {
  const weights = [7, 3, 1];
  var sum = 0;
  for (var i = 0; i < field.length; i++) {
    final code = field.codeUnitAt(i);
    final int value;
    if (code >= 0x30 && code <= 0x39) {
      value = code - 0x30;
    } else if (code >= 0x41 && code <= 0x5A) {
      value = code - 0x41 + 10;
    } else if (code == 0x3C) {
      value = 0;
    } else {
      return null;
    }
    sum += value * weights[i % 3];
  }
  return sum % 10;
}

/// Letters the reader confuses with digits, for fields that hold digits only.
const _asDigit = {
  'O': '0',
  'Q': '0',
  'D': '0',
  'I': '1',
  'L': '1',
  'Z': '2',
  'S': '5',
  'G': '6',
  'B': '8',
};

/// Digits the reader confuses with letters, for fields that hold letters only.
const _asLetter = {'0': 'O', '1': 'I', '2': 'Z', '5': 'S', '8': 'B'};

String _digits(String field) =>
    field.split('').map((c) => _asDigit[c] ?? c).join();

String _letters(String field) =>
    field.split('').map((c) => _asLetter[c] ?? c).join();

/// Splits `SURNAME<<GIVEN<NAMES<<<<` into title-cased parts.
({String surname, String given})? _names(String field) {
  var text = field;
  // The filler starts at the first run of three; a filler "<" is
  // sometimes read as K.
  final end = RegExp('<<<|K{3,}').firstMatch(text);
  if (end != null) text = text.substring(0, end.start);
  final split = text.indexOf('<<');
  final surname = split < 0 ? text : text.substring(0, split);
  var given = split < 0 ? '' : text.substring(split + 2);
  // Given names are joined by single fillers; a second "<<" is filler noise.
  final noise = given.indexOf('<<');
  if (noise >= 0) given = given.substring(0, noise);
  final names = (surname: _words(surname), given: _words(given));
  if (names.surname.isEmpty && names.given.isEmpty) return null;
  return names;
}

String _words(String part) => part
    .split('<')
    .where((word) => word.isNotEmpty)
    .map((word) => word[0] + word.substring(1).toLowerCase())
    .join(' ');

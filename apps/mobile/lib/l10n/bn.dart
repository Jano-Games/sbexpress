/// Bangla text keyed by the English source string passed to `tr`.
///
/// Each part covers one area of the app; keys must stay identical to the
/// English literal in code, including `{placeholders}`.
library;

import 'bn_admin.dart';
import 'bn_billing.dart';
import 'bn_core.dart';
import 'bn_finance.dart';
import 'bn_flights.dart';
import 'bn_hub.dart';
import 'bn_shared.dart';

final Map<String, String> bnStrings = {
  ...bnShared,
  ...bnHub,
  ...bnAdmin,
  ...bnBilling,
  ...bnFinance,
  ...bnFlights,
  ...bnCore,
};

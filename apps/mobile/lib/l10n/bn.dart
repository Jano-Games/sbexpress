/// Bangla text keyed by the English source string passed to `tr`.
///
/// Each part covers one area of the app; keys must stay identical to the
/// English literal in code, including `{placeholders}`.
library;

import 'bn_admin.dart';
import 'bn_billing.dart';
import 'bn_core.dart';
import 'bn_finance.dart';
import 'bn_finance_ui.dart';
import 'bn_flights.dart';
import 'bn_flights_ui.dart';
import 'bn_flow.dart';
import 'bn_hub.dart';
import 'bn_photos.dart';
import 'bn_quick.dart';
import 'bn_round5.dart';
import 'bn_round6.dart';
import 'bn_round7a.dart';
import 'bn_round7b.dart';
import 'bn_scan.dart';
import 'bn_shared.dart';
import 'bn_team_ui.dart';

final Map<String, String> bnStrings = {
  ...bnShared,
  ...bnHub,
  ...bnAdmin,
  ...bnBilling,
  ...bnFinance,
  ...bnFlights,
  ...bnFlightsUi,
  ...bnTeamUi,
  ...bnFinanceUi,
  ...bnFlow,
  ...bnQuick,
  ...bnRound5,
  ...bnRound6,
  ...bnScan,
  ...bnRound7b,
  ...bnRound7a,
  ...bnPhotos,
  ...bnCore,
};

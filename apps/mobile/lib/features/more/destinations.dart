import '../../data/models/session_user.dart';
import '../../l10n/l10n.dart';

/// One tool on the More list. [body] is the line under the title when the
/// screen has no live figure for it.
class MoreDestination {
  const MoreDestination(
      {required this.id, required this.title, required this.body});

  final String id;
  final String title;
  final String body;
}

/// Everything that is not on the bottom bar. Flights, Finance and New
/// shipment live there and on the + button, so they are not repeated here.
List<MoreDestination> moreDestinations(UserRole role) {
  switch (role) {
    case UserRole.hub:
      return [
        MoreDestination(
          id: 'imei',
          title: tr('IMEI photos'),
          body: tr('Save device serials and photos'),
        ),
        MoreDestination(
          id: 'media',
          title: tr('Photos / media'),
          body: tr('View and add shipment photos'),
        ),
        _fingerprint(),
      ];
    case UserRole.admin:
      return [
        MoreDestination(
          id: 'customers',
          title: tr('Customers'),
          body: tr('Dues and shipment accounts'),
        ),
        MoreDestination(
          id: 'flyers',
          title: tr('Flyers'),
          body: tr('Profiles and travel documents'),
        ),
        MoreDestination(
          id: 'team',
          title: tr('Team'),
          body: tr('Admins and hub managers · add someone'),
        ),
        MoreDestination(
          id: 'review',
          title: tr('Payment review'),
          body: tr('Receipts customers sent'),
        ),
        MoreDestination(
          id: 'pay-methods',
          title: tr('Payment methods'),
          body: tr('Shown on the customer link'),
        ),
        MoreDestination(
          id: 'rate',
          title: tr('Exchange rate'),
          body: tr('New transactions use this rate.'),
        ),
        MoreDestination(
          id: 'invoice-share',
          title: tr('Bills and customer links'),
          body: tr('Pick a shipment to see its bill and link'),
        ),
        MoreDestination(
          id: 'media',
          title: tr('Photos and media'),
          body: tr('Parcel and device photos'),
        ),
        MoreDestination(
          id: 'weight',
          title: tr('Weight alert'),
          body: tr('Booked vs weighed difference'),
        ),
        MoreDestination(
          id: 'tasks',
          title: tr('Tasks and notes'),
          body: tr('Team tasks and daily notes'),
        ),
        _fingerprint(),
        MoreDestination(
          id: 'system',
          title: tr('System check'),
          body: tr('Connections and required settings'),
        ),
      ];
  }
}

MoreDestination _fingerprint() => MoreDestination(
      id: 'fingerprint',
      title: tr('Fingerprint sign-in'),
      body: tr('Sign in with your finger on this phone'),
    );

class MoreGroup {
  const MoreGroup(this.title, this.ids);

  final String title;
  final List<String> ids;
}

List<MoreGroup> moreGroups(UserRole role) {
  switch (role) {
    case UserRole.hub:
      return [
        MoreGroup(tr('Shipment tools'), const ['imei', 'media']),
        MoreGroup(tr('Security'), const ['fingerprint']),
      ];
    case UserRole.admin:
      return [
        MoreGroup(tr('People'), const ['customers', 'flyers', 'team']),
        MoreGroup(tr('Money'), const ['review', 'pay-methods', 'rate']),
        MoreGroup(
            tr('Shipment tools'), const ['invoice-share', 'media', 'weight']),
        MoreGroup(tr('Work'), const ['tasks']),
        MoreGroup(tr('Security'), const ['fingerprint', 'system']),
      ];
  }
}

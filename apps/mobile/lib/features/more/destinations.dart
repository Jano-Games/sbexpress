import '../../data/models/session_user.dart';
import '../../l10n/l10n.dart';

class MoreDestination {
  const MoreDestination(
      {required this.id, required this.title, required this.body});

  final String id;
  final String title;
  final String body;
}

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
      ];
    case UserRole.admin:
      return [
        MoreDestination(
            id: 'tasks',
            title: tr('Tasks & notes'),
            body: tr('Team tasks and daily notes')),
        MoreDestination(
            id: 'review',
            title: tr('Payment review'),
            body: tr('Receipts and payment screenshots')),
        MoreDestination(
          id: 'intake',
          title: tr('Shipment intake'),
          body: tr('Book a new parcel'),
        ),
        MoreDestination(
          id: 'invoice-share',
          title: tr('Issue & share invoices'),
          body: tr('Prepare bills and customer links'),
        ),
        MoreDestination(
          id: 'flights',
          title: tr('Flights'),
          body: tr('Schedules and baggage capacity'),
        ),
        MoreDestination(
          id: 'flyers',
          title: tr('Flyers'),
          body: tr('Profiles and travel documents'),
        ),
        MoreDestination(
          id: 'customers',
          title: tr('Customers'),
          body: tr('Dues and shipment accounts'),
        ),
        MoreDestination(
          id: 'finance',
          title: tr('Finance overview'),
          body: tr('Accounts, transactions and reports'),
        ),
        MoreDestination(
          id: 'assign',
          title: tr('Assign tasks'),
          body: tr('Share out team tasks'),
        ),
        MoreDestination(
          id: 'settings',
          title: tr('Settings'),
          body: tr('Business setup and team'),
        ),
        MoreDestination(
          id: 'media',
          title: tr('Photos / media'),
          body: tr('Shipment photos and attachments'),
        ),
        MoreDestination(
          id: 'staff-add',
          title: tr('Add admin or hub manager'),
          body: tr('A new sign-in for the team'),
        ),
        MoreDestination(
          id: 'staff',
          title: tr('Staff'),
          body: tr('Everyone who can sign in'),
        ),
      ];
  }
}

class MoreGroup {
  const MoreGroup(this.title, this.ids);

  final String title;
  final List<String> ids;
}

List<MoreGroup> moreGroups(UserRole role) {
  switch (role) {
    case UserRole.hub:
      return [
        MoreGroup(tr('Hub tasks'), const ['imei', 'media']),
      ];
    case UserRole.admin:
      return [
        MoreGroup(tr('Partners'), const ['customers', 'flyers']),
        MoreGroup(
            tr('Shipment tools'), const ['intake', 'invoice-share', 'media']),
        MoreGroup(tr('Tasks & finance'),
            const ['tasks', 'assign', 'review', 'finance']),
        MoreGroup(tr('Management'), const ['flights', 'settings']),
        MoreGroup(tr('Team'), const ['staff-add', 'staff']),
      ];
  }
}

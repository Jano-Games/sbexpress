import '../../data/models/session_user.dart';

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
      return const [
        MoreDestination(
          id: 'imei',
          title: 'IMEI ছবি',
          body: 'ডিভাইসের সিরিয়াল ও ছবি সংরক্ষণ',
        ),
        MoreDestination(
          id: 'media',
          title: 'ছবি / মিডিয়া',
          body: 'শিপমেন্টের ছবি দেখুন ও যোগ করুন',
        ),
      ];
    case UserRole.admin:
      return const [
        MoreDestination(
            id: 'tasks', title: 'কাজ ও নোট', body: 'টিমের কাজ ও দৈনন্দিন নোট'),
        MoreDestination(
            id: 'review',
            title: 'পেমেন্ট যাচাই',
            body: 'রসিদ ও পেমেন্ট স্ক্রিনশট'),
        MoreDestination(
          id: 'intake',
          title: 'শিপমেন্ট ইনটেক',
          body: 'নতুন পার্সেল বুকিং',
        ),
        MoreDestination(
          id: 'invoice-share',
          title: 'ইনভয়েস ইস্যু ও শেয়ার',
          body: 'বিল প্রস্তুত ও customer link',
        ),
        MoreDestination(
          id: 'flights',
          title: 'ফ্লাইট',
          body: 'শিডিউল ও লাগেজ ক্যাপাসিটি',
        ),
        MoreDestination(
          id: 'flyers',
          title: 'ফ্লায়ার',
          body: 'প্রোফাইল ও ট্রাভেল ডকুমেন্ট',
        ),
        MoreDestination(
          id: 'customers',
          title: 'কাস্টমার',
          body: 'বকেয়া ও শিপমেন্টের হিসাব',
        ),
        MoreDestination(
          id: 'finance',
          title: 'ফাইন্যান্স',
          body: 'অ্যাকাউন্ট, লেনদেন ও রিপোর্ট',
        ),
        MoreDestination(
          id: 'assign',
          title: 'কাজ অ্যাসাইন',
          body: 'টিমের কাজ বণ্টন',
        ),
        MoreDestination(
          id: 'settings',
          title: 'সেটিংস',
          body: 'ব্যবসার সেটআপ ও টিম',
        ),
        MoreDestination(
          id: 'media',
          title: 'ছবি / মিডিয়া',
          body: 'শিপমেন্টের ছবি ও সংযুক্তি',
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
      return const [
        MoreGroup('হাবের কাজ', ['imei', 'media']),
      ];
    case UserRole.admin:
      return const [
        MoreGroup('পার্টনার', ['customers', 'flyers']),
        MoreGroup('শিপমেন্ট টুলস', ['intake', 'invoice-share', 'media']),
        MoreGroup('কাজ ও হিসাব', ['tasks', 'assign', 'review', 'finance']),
        MoreGroup('ব্যবস্থাপনা', ['flights', 'settings']),
      ];
  }
}

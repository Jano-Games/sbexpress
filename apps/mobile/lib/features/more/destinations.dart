import '../../data/models/session_user.dart';

class MoreDestination {
  const MoreDestination({required this.id, required this.title, required this.body});

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
          body: 'ডিভাইস বেছে নিয়ে গাইড ফ্রেমে সিরিয়ালের ছবি নিন। কাস্টমারের সাথে শেয়ার হয় না।',
        ),
        MoreDestination(
          id: 'media',
          title: 'ছবি / মিডিয়া',
          body: 'শিপমেন্ট খুলে সাধারণ ছবি দেখুন ও যোগ করুন। শেয়ার টগল অ্যাডমিনের।',
        ),
      ];
    case UserRole.admin:
      return const [
        MoreDestination(
          id: 'intake',
          title: 'শিপমেন্ট ইনটেক',
          body: 'কাস্টমার, ক্যাটাগরি, ওজন ও চাইলে ফ্লাইট।',
        ),
        MoreDestination(
          id: 'invoice-share',
          title: 'ইনভয়েস ইস্যু ও শেয়ার',
          body: 'লাইন, ছাড়, PDF দেখা ও শেয়ার, ট্র্যাকিং বা ইনভয়েস লিংক।',
        ),
        MoreDestination(
          id: 'flights',
          title: 'ফ্লাইট',
          body: 'ক্যাপাসিটি, ফ্লায়ার অ্যাসাইন ও বুকিং।',
        ),
        MoreDestination(
          id: 'flyers',
          title: 'ফ্লায়ার',
          body: 'প্রোফাইল, ফোন ও ডকুমেন্ট যাচাই।',
        ),
        MoreDestination(
          id: 'customers',
          title: 'কাস্টমার',
          body: 'নাম, বকেয়া, অ্যাকাউন্ট হিসাব ও শিপমেন্ট।',
        ),
        MoreDestination(
          id: 'finance',
          title: 'ফাইন্যান্স',
          body: 'ক্যাশ, ট্রান্সফার, শুরুর ব্যালেন্স, মিল, জমা, খরচ ও লেজার।',
        ),
        MoreDestination(
          id: 'assign',
          title: 'কাজ অ্যাসাইন',
          body: 'হাব ম্যানেজারকে নোট কাজ দিন।',
        ),
        MoreDestination(
          id: 'settings',
          title: 'সেটিংস',
          body: 'CNY রেট, পেমেন্ট মেথড, স্টোরেজ ও স্টাফ।',
        ),
        MoreDestination(
          id: 'media',
          title: 'ছবি / মিডিয়া',
          body: 'শিপমেন্টের ছবি দেখুন, যোগ করুন ও শেয়ার করুন।',
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
        MoreGroup('অপারেশন', ['intake', 'flights', 'flyers', 'customers', 'invoice-share', 'media']),
        MoreGroup('টাকা ও সেটআপ', ['finance', 'assign', 'settings']),
      ];
  }
}

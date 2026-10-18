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
          body: 'গাইড ফ্রেমের ক্যামেরা এই স্লাইসে নেই। শিপমেন্টের সাধারণ ছবি যোগ করলে ডিভাইসেই JPEG-এ কমপ্রেস হয়। IMEI ছবি কাস্টমারের সাথে শেয়ার হয় না।',
        ),
        MoreDestination(
          id: 'media',
          title: 'ছবি / মিডিয়া',
          body: 'হাব শুধু নিজের শিপমেন্টের ছবি দেখে ও যোগ করে। একটি Shipment খুলে ছবি যোগ করুন। শেয়ার টগল অ্যাডমিনের।',
        ),
      ];
    case UserRole.admin:
      return const [
        MoreDestination(
          id: 'intake',
          title: 'শিপমেন্ট ইনটেক',
          body: 'তিন ধাপের ইনটেক (কাস্টমার, ক্যাটাগরি, পেমেন্ট টার্ম) এই স্লাইসে নেই।',
        ),
        MoreDestination(
          id: 'invoice-share',
          title: 'ইনভয়েস ইস্যু ও শেয়ার',
          body: 'Issue করে পাঠান এই স্লাইসে নেই। শিপমেন্ট ডিটেইলে শুধু tracking লিংক শেয়ার করা যায়।',
        ),
        MoreDestination(
          id: 'flights',
          title: 'ফ্লাইট',
          body: 'ফ্লাইট তালিকা ও ফ্লায়ার অ্যাসাইন এই স্লাইসে নেই।',
        ),
        MoreDestination(
          id: 'customers',
          title: 'কাস্টমার',
          body: 'কাস্টমার তালিকা ও বকেয়া এই স্লাইসে নেই।',
        ),
        MoreDestination(
          id: 'finance',
          title: 'ফাইন্যান্স',
          body: 'আজকের আয়-ব্যয়ের স্ন্যাপশট এই স্লাইসে নেই। পেমেন্ট রিভিউ হোম থেকে খোলা যায়।',
        ),
        MoreDestination(
          id: 'assign',
          title: 'কাজ অ্যাসাইন',
          body: 'হাব ম্যানেজারকে ম্যানুয়াল কাজ দেওয়ার পিপল পিকার এই স্লাইসে নেই। নিজের নোট কাজ ট্যাবে লেখা যায়।',
        ),
        MoreDestination(
          id: 'settings',
          title: 'সেটিংস',
          body: 'পেমেন্ট মেথড, রেট ও স্টোরেজ স্ট্যাটাস এই স্লাইসে নেই।',
        ),
        MoreDestination(
          id: 'media',
          title: 'ছবি / মিডিয়া',
          body: 'শিপমেন্ট খুলে ছবি ট্যাবে ব্রাউজ, যোগ ও কাস্টমার শেয়ার টগল করা যায়।',
        ),
      ];
  }
}

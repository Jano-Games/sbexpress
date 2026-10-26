/// The owner's sixth round: deleting flights, shipments, flyers and
/// customers, archiving and restoring flyers and customers, and the
/// Active / Archived lists.
const bnRound6 = <String, String>{
  // Deleting.
  'Delete': 'মুছে ফেলুন',
  'Not deleted': 'মুছে ফেলা হয়নি',
  'Archive instead': 'বরং আর্কাইভ করুন',
  'Archiving hides it from lists and new bookings. History stays.':
      'আর্কাইভ করলে তালিকা ও নতুন বুকিংয়ে আর দেখাবে না। আগের ইতিহাস থেকে যাবে।',
  'Delete flight': 'ফ্লাইট মুছে ফেলুন',
  'Delete flight {code}? This cannot be undone.':
      'ফ্লাইট {code} মুছে ফেলবেন? এটি আর ফেরানো যাবে না।',
  'This flight cannot be deleted': 'এই ফ্লাইট মুছে ফেলা যাবে না',
  'Delete shipment': 'শিপমেন্ট মুছে ফেলুন',
  'Delete shipment {code}? This cannot be undone.':
      'শিপমেন্ট {code} মুছে ফেলবেন? এটি আর ফেরানো যাবে না।',
  'This shipment cannot be deleted': 'এই শিপমেন্ট মুছে ফেলা যাবে না',
  'Delete flyer': 'ফ্লায়ার মুছে ফেলুন',
  'Delete flyer {name}? This cannot be undone.':
      'ফ্লায়ার {name} মুছে ফেলবেন? এটি আর ফেরানো যাবে না।',
  'This flyer cannot be deleted': 'এই ফ্লায়ার মুছে ফেলা যাবে না',
  'Delete customer': 'কাস্টমার মুছে ফেলুন',
  'Delete customer {name}? This cannot be undone.':
      'কাস্টমার {name} মুছে ফেলবেন? এটি আর ফেরানো যাবে না।',
  'This customer cannot be deleted': 'এই কাস্টমার মুছে ফেলা যাবে না',
  // Archiving and restoring.
  'Archive': 'আর্কাইভ করুন',
  'Archive {name}?': '{name} আর্কাইভ করবেন?',
  'Hidden from lists and new bookings; history stays.':
      'তালিকা ও নতুন বুকিংয়ে আর দেখাবে না; আগের ইতিহাস থেকে যাবে।',
  'Not archived': 'আর্কাইভ হয়নি',
  'Not restored': 'ফিরিয়ে আনা যায়নি',
  'Archived {date}': '{date} তারিখে আর্কাইভ করা',
  'Restore flyer': 'ফ্লায়ার ফিরিয়ে আনুন',
  'Archive customer': 'কাস্টমার আর্কাইভ করুন',
  'Restore customer': 'কাস্টমার ফিরিয়ে আনুন',
  'The server needs an update before customers can be archived.':
      'কাস্টমার আর্কাইভ করতে আগে সার্ভার আপডেট করতে হবে।',
  // Active / Archived lists.
  'Active · {n}': 'সক্রিয় · {n}',
  'Archived · {n}': 'আর্কাইভ করা · {n}',
  'Archived flyers': 'আর্কাইভ করা ফ্লায়ার',
  'No archived flyers': 'আর্কাইভ করা কোনো ফ্লায়ার নেই',
  'Flyers you archive appear here. Their history stays.':
      'যে ফ্লায়ারদের আর্কাইভ করবেন, তারা এখানে দেখাবে। আগের ইতিহাস থেকে যাবে।',
  'Archived customers': 'আর্কাইভ করা কাস্টমার',
  'No archived customers': 'আর্কাইভ করা কোনো কাস্টমার নেই',
  'Customers you archive appear here. Their history stays.':
      'যে কাস্টমারদের আর্কাইভ করবেন, তারা এখানে দেখাবে। আগের ইতিহাস থেকে যাবে।',
};

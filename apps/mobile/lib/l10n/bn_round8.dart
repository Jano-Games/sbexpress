/// The owner's eighth round: default rates and piece prices, a flight's own
/// rates, and changing an order's weight and rate.
const bnRound8 = <String, String>{
  // Rates and prices in More.
  'Rates and prices': 'রেট ও দাম',
  'New orders start with these': 'নতুন অর্ডার এগুলো দিয়ে শুরু হয়',
  'No rate per kg yet': 'এখনো প্রতি kg রেট নেই',
  '{rate} per kg': 'প্রতি kg {rate}',
  '{n} piece prices': '{n}টি পিসের দাম',
  'For the weighed cargo': 'ওজনের মালের জন্য',
  'per kg': 'প্রতি kg',
  'Piece prices': 'পিসের দাম',
  'Devices are charged per piece, not by weight':
      'ডিভাইসের চার্জ পিস হিসেবে, ওজনে নয়',
  'No piece prices yet.': 'এখনো পিসের দাম নেই।',
  'Add a price for': 'দাম যোগ করুন',
  'Device name': 'ডিভাইসের নাম',
  'How these are used': 'এগুলো কীভাবে কাজে লাগে',
  'A new order fills in these rates. A flight can have its own rates, and each order can still be changed. Orders already booked keep their price.':
      'নতুন অর্ডারে এই রেট বসে যায়। কোনো ফ্লাইটের নিজস্ব রেট থাকতে পারে, আর প্রতিটি অর্ডার পরেও বদলানো যায়। আগে বুক করা অর্ডারের দাম বদলায় না।',
  'Save rates': 'রেট সেভ করুন',
  'Rates saved': 'রেট সেভ হয়েছে',
  'Enter the rate per kg as a number.': 'প্রতি kg রেট সংখ্যায় লিখুন।',
  'Enter the price for {name} as a number.': '{name}-এর দাম সংখ্যায় লিখুন।',
  'Piece prices are saved. The server needs an update to keep the rate per kg.':
      'পিসের দাম সেভ হয়েছে। প্রতি kg রেট রাখতে সার্ভার আপডেট করতে হবে।',
  '{name} price': '{name}-এর দাম',
  'Remove {name}': '{name} সরান',
  'Fewer {name}': '{name} কমান',
  'More {name}': '{name} বাড়ান',
  // A flight's own rates.
  'Rates for this flight': 'এই ফ্লাইটের রেট',
  'New orders on {flight} start with these':
      '{flight}-এর নতুন অর্ডার এই রেট দিয়ে শুরু হয়',
  'Own rate': 'নিজস্ব রেট',
  'Default': 'ডিফল্ট',
  '{amount} / pc': '{amount} / পিস',
  'Rates saved · {n} orders updated':
      'রেট সেভ হয়েছে · {n}টি অর্ডার আপডেট হয়েছে',
  'Rates for {flight}': '{flight}-এর রেট',
  'Default is {rate} per kg': 'ডিফল্ট প্রতি kg {rate}',
  'No default rate per kg yet': 'এখনো ডিফল্ট প্রতি kg রেট নেই',
  "Enter this flight's rate per kg.": 'এই ফ্লাইটের প্রতি kg রেট লিখুন।',
  'The server needs an update before flight rates can be saved.':
      'ফ্লাইটের রেট সেভ করতে সার্ভার আপডেট করতে হবে।',
  'New orders on this flight use the rates from Rates and prices in More.':
      'এই ফ্লাইটের নতুন অর্ডার আরও-তে থাকা রেট ও দাম ব্যবহার করবে।',
  'Use the default': 'ডিফল্ট ব্যবহার করুন',
  'Own rates': 'নিজস্ব রেট',
  'Also change the {n} orders already on this flight':
      'এই ফ্লাইটে আগে থেকে থাকা {n}টি অর্ডারও বদলান',
  'Unpaid orders still on the old rates move to the new ones. Paid orders and orders with another rate stay as they are. Their bills update by themselves.':
      'পুরনো রেটে থাকা বাকি অর্ডারগুলো নতুন রেটে যাবে। পরিশোধিত অর্ডার আর অন্য রেটের অর্ডার যেমন আছে তেমন থাকবে। তাদের বিল নিজে থেকে আপডেট হবে।',
  // A new order.
  'Default rate': 'ডিফল্ট রেট',
  "{flight}'s rate": '{flight}-এর রেট',
  // An order's weight and rate.
  'Weight and rate saved': 'ওজন ও রেট সেভ হয়েছে',
  '{kg} kg weighed × {rate}': '{kg} kg (মাপা) × {rate}',
  'Enter the booked kg as a number.': 'বুক করা kg সংখ্যায় লিখুন।',
  'Default {rate}': 'ডিফল্ট {rate}',
  '{code} · now {amount}': '{code} · এখন {amount}',
  'Quick rate': 'দ্রুত রেট',
  'Pieces': 'পিস',
  'Was {amount}': 'আগে ছিল {amount}',
  'Save · {amount}': 'সেভ করুন · {amount}',
  'The bill and the customer link update by themselves. After the hub weighs it, the charge uses the weighed kg.':
      'বিল আর কাস্টমার লিংক নিজে থেকে আপডেট হয়। হাবে ওজন মাপার পর চার্জ মাপা kg ধরে হয়।',
  'Weighed at the hub: {kg} kg. The charge uses the weighed kg; the bill updates by itself.':
      'হাবে মাপা ওজন: {kg} kg। চার্জ মাপা kg ধরে হয়; বিল নিজে থেকে আপডেট হয়।',
  // Flight capacity.
  'Flight capacity': 'ফ্লাইটের ক্যাপাসিটি',
  'New flights start with this': 'নতুন ফ্লাইট এটা দিয়ে শুরু হয়',
  'New flights start with {kg} kg': 'নতুন ফ্লাইট {kg} kg দিয়ে শুরু হয়',
  'New flights and tickets start with this. Each flight can still have its own.':
      'নতুন ফ্লাইট আর টিকিট এটা দিয়ে শুরু হয়। প্রতিটি ফ্লাইটে আলাদা রাখা যায়।',
  'The server needs an update to keep the default capacity.':
      'ডিফল্ট ক্যাপাসিটি রাখতে সার্ভার আপডেট করতে হবে।',
  'Capacity for {flight}': '{flight}-এর ক্যাপাসিটি',
  '{kg} kg booked so far': 'এ পর্যন্ত {kg} kg বুকড',
  'Enter the capacity in whole kg, 1 or more.':
      'ক্যাপাসিটি পূর্ণ kg-তে লিখুন, ১ বা তার বেশি।',
  '{kg} kg is already booked on this flight. The capacity cannot be less than that.':
      'এই ফ্লাইটে ইতিমধ্যে {kg} kg বুক করা আছে। ক্যাপাসিটি এর চেয়ে কম হতে পারবে না।',
  'Save capacity': 'ক্যাপাসিটি সেভ করুন',
  'Capacity saved': 'ক্যাপাসিটি সেভ হয়েছে',
};

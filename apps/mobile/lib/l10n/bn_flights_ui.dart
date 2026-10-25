/// Redesigned admin flights, ticket money, shipment detail and bill, and the
/// booking wizard.
const bnFlightsUi = <String, String>{
  // Flights list and detail.
  '{kg} kg booked in total': 'মোট বুকড {kg} kg',
  'Next · {when}': 'পরেরটি · {when}',
  '{booked} / {space} kg booked': '{booked} / {space} kg বুকড',
  'via {stop}': '{stop} হয়ে',
  'Bookings · {n}': 'বুকিং · {n}',
  'Flyers · {n}': 'ফ্লায়ার · {n}',
  '{amount} still to collect': '{amount} আদায় বাকি',
  '{n} flyers': '{n} জন ফ্লায়ার',
  'Who else carries cargo on this ticket.': 'এই টিকিটে আর কে মাল নেবেন।',
  "Flyers' share": 'ফ্লায়ারদের ভাগ',
  'Mobiles {n}': 'মোবাইল {n}',
  'Laptops {n}': 'ল্যাপটপ {n}',
  'Ref {code}': 'রেফারেন্স {code}',
  'Shipment charges on this flight': 'এই ফ্লাইটের শিপমেন্ট বিল',
  'Ticket cost': 'টিকিট খরচ',
  'Paid up': 'পরিশোধ হয়েছে',
  '{amount} due': 'বাকি {amount}',
  // Ticket money and its forms.
  'Record flyer payment': 'ফ্লায়ারের জমা লিখুন',
  'Actual ticket cost': 'আসল টিকিট খরচ',
  "Agency share {agency}, flyers' share {flyers}":
      'এজেন্সি শেয়ার {agency}, ফ্লায়ারদের ভাগ {flyers}',
  '{amount} was received before the split and is not assigned to a flyer yet. Assign it once in the split.':
      'ভাগের আগে {amount} জমা হয়েছে, এখনো কোনো ফ্লায়ারের নামে বসেনি। ভাগ করার সময় একবার বসিয়ে দিন।',
  'Split the share between the flyers before recording their payments.':
      'ফ্লায়ারদের জমা লেখার আগে ভাগ ঠিক করুন।',
  'From flyers': 'ফ্লায়ারদের কাছ থেকে',
  'Split the {amount} share, then record payments':
      '{amount} ভাগ করুন, তারপর জমা লিখুন',
  '{amount} received': '{amount} জমা হয়েছে',
  '{amount} to go': 'আরও {amount} বাকি',
  'Separate from flyer payments': 'ফ্লায়ারের জমা থেকে আলাদা',
  'Settling posts only the outstanding ticket cost (or a refund) to the account you choose. Nothing else changes.':
      'সেটল করলে শুধু বাকি টিকিট খরচ (বা রিফান্ড) বাছাই করা অ্যাকাউন্টে বসে। আর কিছু বদলায় না।',
  'Refund into account': 'যে অ্যাকাউন্টে রিফান্ড আসবে',
  'Entered': 'লেখা হয়েছে',
  'Left to split': 'ভাগ বাকি',
  'Too much': 'বেশি হয়েছে',
  '{amount} was received before the split. Enter who paid it under each flyer, once in total.':
      'ভাগের আগে {amount} জমা হয়েছে। কে কত দিয়েছেন, প্রতিটি ফ্লায়ারের ঘরে লিখুন — মোট একবার।',
  '{amount} of the earlier payment still to assign.':
      'আগের জমার {amount} এখনো বসানো বাকি।',
  'Who paid': 'কে দিয়েছেন',
  'Received in': 'যে অ্যাকাউন্টে এসেছে',
  '{amount} due from this flyer.': 'এই ফ্লায়ারের বাকি {amount}।',
  // Shipment detail.
  'Status': 'স্ট্যাটাস',
  'Step {step} of {total}': 'ধাপ {step} / {total}',
  'Next: {status}': 'পরের ধাপ: {status}',
  'Next: {status}, when {flight} departs': 'পরের ধাপ: {status}, {flight} ছাড়লে',
  'Delivered to the customer.': 'কাস্টমারের কাছে পৌঁছে গেছে।',
  'China hub': 'চায়না হাব',
  'Booking': 'বুকিং',
  'Filled in by the Dhaka hub after landing':
      'ফ্লাইট নামার পর ঢাকা হাব পূরণ করে',
  'Tracking for the customer': 'কাস্টমারের জন্য ট্র্যাকিং',
  'A link that shows where the parcel is.':
      'এই লিংকে পার্সেল কোথায় আছে দেখা যায়।',
  'Link copied': 'লিংক কপি হয়েছে',
  '{n} pieces': '{n} পিস',
  '{n} photos': '{n}টি ছবি',
  // Bill.
  'Paid in full': 'পুরো পরিশোধ',
  'Edit lines': 'লাইন এডিট',
  'Where the money arrived, and how much.': 'টাকা কোথায় এসেছে আর কত।',
  // Booking wizard.
  'Step 3 of 3 · check and create': 'ধাপ 3 / 3 · দেখে তৈরি করুন',
  'Cargo': 'কার্গো',
  'Billing': 'বিলিং',
  'Review': 'যাচাই',
  'Previous': 'আগের ধাপ',
  'Next: Billing': 'পরের ধাপ: বিলিং',
  'Next: Review': 'পরের ধাপ: যাচাই',
  'Change': 'বদলান',
  '{n} chosen': '{n}টি বাছাই',
  '{name} pieces': '{name} পিস',
  "Count, price and each device's model and IMEI":
      'সংখ্যা, দাম এবং প্রতিটি ডিভাইসের মডেল ও IMEI',
  '/ pc': '/ পিস',
  'Price is prefilled from settings when a rate is saved.':
      'সেটিংসে রেট সেভ থাকলে দাম আগে থেকেই বসে যায়।',
  'IMEI number': 'IMEI নম্বর',
  'One fewer': 'একটি কম',
  'One more': 'একটি বেশি',
  'Charged on the booked weight; pieces are billed apart.':
      'বুকড ওজনে চার্জ হয়; পিস আলাদা বিল হয়।',
  'Shipping charge': 'শিপিং চার্জ',
  'Shown on the bill and to the hub.': 'বিলে এবং হাবে দেখা যায়।',
  'Contents and terms': 'পণ্য ও পেমেন্ট টার্ম',
  'Estimated charge · at booked weight': 'আনুমানিক চার্জ · বুকড ওজনে',
  'Shipping · {kg} kg × {currency} {rate}':
      'শিপিং · {kg} kg × {currency} {rate}',
  '{name} · {n} pcs × {currency} {rate}':
      '{name} · {n} পিস × {currency} {rate}',
  'Edit': 'এডিট',
  '{flight} has {n} flyers. Who carries this cargo?':
      '{flight}-এ {n} জন ফ্লায়ার। এই কার্গো কে নেবেন?',
  '{left} kg left · {after} kg after this booking':
      'বাকি {left} kg · এই বুকিংয়ের পর {after} kg',
  '{kg} kg left': 'বাকি {kg} kg',
  'Fits': 'জায়গা আছে',
  'Over capacity': 'ক্যাপাসিটির বেশি',
};

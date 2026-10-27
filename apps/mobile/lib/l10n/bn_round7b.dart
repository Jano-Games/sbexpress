/// The owner's seventh round, part B: the one-page shipment, costs on the
/// bill, the automatic invoice, the saved customer link and flight costs.
const bnRound7b = <String, String>{
  // The one-page shipment.
  'Photos · {n}': 'ছবি · {n}',
  'Pays monthly': 'মাসিক পরিশোধ',
  'Pays after delivery': 'ডেলিভারির পর পরিশোধ',
  'Charge {charge} + costs on the bill {costs}':
      'চার্জ {charge} + বিলে যোগ করা খরচ {costs}',
  'Share of flight costs': 'ফ্লাইট খরচের ভাগ',
  'Not on a flight yet': 'এখনো কোনো ফ্লাইটে নেই',
  '{kg} of {total} kg on {flight}': '{flight}-এর {total} kg-এর মধ্যে {kg} kg',
  'Costs on the bill': 'বিলে যোগ করা খরচ',
  'Other costs (not on the bill)': 'অন্যান্য খরচ (বিলে নেই)',
  '{amount} in, {amount} out': '{amount} এসেছে, {amount} গেছে',
  'Ticket and flyer money are counted on the flight.':
      'টিকিট আর ফ্লায়ারের টাকা ফ্লাইটের হিসাবে ধরা হয়।',
  'paid from {account}': '{account} থেকে দেওয়া',
  'Pay later · unpaid': 'পরে পরিশোধ · বাকি',
  '{amount} still to pay': '{amount} দেওয়া বাকি',
  'The customer pays these': 'এগুলো কাস্টমার দেবেন',
  'Nothing added to this bill yet.': 'এই বিলে এখনো কিছু যোগ করা হয়নি।',
  'Booked on': 'বুকিংয়ের তারিখ',
  // The invoice the server makes.
  'Made automatically · updates when the charge or costs change':
      'নিজে থেকে তৈরি · চার্জ বা খরচ বদলালে আপডেট হয়',
  'Edited by hand · check it when the charge changes':
      'হাতে এডিট করা · চার্জ বদলালে মিলিয়ে দেখুন',
  'Confirm the bill': 'বিল নিশ্চিত করুন',
  'This server still keeps the bill as a draft.':
      'এই সার্ভারে বিলটি এখনো ড্রাফট হিসেবে আছে।',
  'PDF': 'PDF',
  'Paid · {n} payments': 'পরিশোধ · {n}টি জমা',
  // The customer link.
  'Customer link': 'কাস্টমার লিংক',
  'Tracking and bill': 'ট্র্যাকিং ও বিল',
  'Tracking only': 'শুধু ট্র্যাকিং',
  'valid until {date}': '{date} পর্যন্ত চালু',
  'Made once, stays here.': 'একবার তৈরি হলে এখানেই থাকে।',
  'Make a new link': 'নতুন লিংক তৈরি করুন',
  'Turn off': 'বন্ধ করুন',
  'Turn off the customer link?': 'কাস্টমার লিংক বন্ধ করবেন?',
  'The customer can no longer open it. You can make a new link any time.':
      'কাস্টমার আর এটি খুলতে পারবেন না। যেকোনো সময় নতুন লিংক তৈরি করা যাবে।',
  'Create customer link': 'কাস্টমার লিংক তৈরি করুন',
  'New customer link': 'নতুন কাস্টমার লিংক',
  'Valid for': 'কতদিন চালু থাকবে',
  'The customer sees where the parcel is, the bill and what is paid.':
      'কাস্টমার দেখবেন পার্সেল কোথায়, বিল আর কত পরিশোধ হয়েছে।',
  'The customer sees where the parcel is. The bill joins once it is issued.':
      'কাস্টমার দেখবেন পার্সেল কোথায়। বিল ইস্যু হলে সেটিও যোগ হবে।',
  'Make link': 'লিংক তৈরি করুন',
  // Adding a cost to the bill.
  'Add cost to the bill': 'বিলে খরচ যোগ করুন',
  '{code} · {name} pays this': '{code} · {name} এটি দেবেন',
  'What for': 'কিসের জন্য',
  'Name on the bill': 'বিলে যে নাম থাকবে',
  'e.g. Courier to customer': 'যেমন: কাস্টমারের কাছে কুরিয়ার',
  'We paid it from': 'যে অ্যাকাউন্ট থেকে দিয়েছি',
  'or pay later': 'বা পরে পরিশোধ',
  'Saved unpaid': 'বাকি হিসেবে সেভ',
  'Choose the account it was paid from, or Pay later.':
      'যে অ্যাকাউন্ট থেকে দেওয়া হয়েছে তা বেছে নিন, বা পরে পরিশোধ।',
  "Added to {name}'s bill": '{name}-এর বিলে যোগ হবে',
  'Add to bill': 'বিলে যোগ করুন',
  // Flight costs.
  'Flight costs': 'ফ্লাইটের খরচ',
  'For the whole flight · not on any bill':
      'পুরো ফ্লাইটের জন্য · কোনো বিলে যায় না',
  'No flight costs yet.': 'এখনো কোনো ফ্লাইট খরচ নেই।',
  "Costs on customers' bills are paid back by them, so they are left out.":
      'কাস্টমারের বিলে যোগ করা খরচ তাঁরাই ফেরত দেন, তাই এখানে ধরা হয়নি।',
  'How the flight costs reach each shipment':
      'ফ্লাইটের খরচ কীভাবে প্রতিটি শিপমেন্টে ভাগ হয়',
  "Each shipment's profit takes a share by weight.":
      'ওজন অনুযায়ী প্রতিটি শিপমেন্টের প্রফিট থেকে একটি ভাগ কাটা হয়।',
  '{code} carries {kg} of {total} kg, so its share is {share} of {costs}.':
      '{code}-এ {total} kg-এর মধ্যে {kg} kg, তাই {costs}-এর মধ্যে এর ভাগ {share}।',
  'bill {amount}': 'বিল {amount}',
  '{n} days late': '{n} দিন দেরি',
  'Remove': 'সরিয়ে দিন',
  'Remove this flight cost?': 'এই ফ্লাইট খরচ সরিয়ে দেবেন?',
  '{name} · {amount} is reversed. If it was paid, the money goes back to its account.':
      '{name} · {amount} বাতিল হবে। টাকা দেওয়া হয়ে থাকলে তা আবার সেই অ্যাকাউন্টে ফিরবে।',
  'Not removed': 'সরানো হয়নি',
  'Older shipment costs': 'শিপমেন্টের আগের খরচ',
  'Mark paid': 'পরিশোধ লিখুন',
  'Not paid': 'পরিশোধ লেখা হয়নি',
  'The server needs an update before flight costs can be marked paid.':
      'ফ্লাইট খরচ পরিশোধ লিখতে আগে সার্ভার আপডেট করতে হবে।',
  'The server needs an update before flight costs can be removed.':
      'ফ্লাইট খরচ সরাতে আগে সার্ভার আপডেট করতে হবে।',
  // Adding a flight cost.
  'Add flight cost': 'ফ্লাইটের খরচ যোগ করুন',
  '{flight} · flight costs so far {amount}':
      '{flight} · এ পর্যন্ত ফ্লাইট খরচ {amount}',
  'Pick one': 'একটি বেছে নিন',
  'Labour': 'লেবার',
  'Pick what the cost was for.': 'খরচটা কিসের, বেছে নিন।',
  'Type what the cost was for.': 'খরচটা কিসের, লিখে দিন।',
  'Or choose "Pay later" to save it as unpaid.':
      'অথবা বাকি হিসেবে সেভ করতে "পরে পরিশোধ" বেছে নিন।',
  'Our cost only': 'শুধু আমাদের খরচ',
  "Not added to any customer's bill.": 'কোনো কাস্টমারের বিলে যোগ হয় না।',
  'The server needs an update before flight costs can be added.':
      'ফ্লাইট খরচ যোগ করতে আগে সার্ভার আপডেট করতে হবে।',
  // Booking done.
  'The bill is made from this charge by itself.':
      'এই চার্জ থেকে বিল নিজে থেকেই তৈরি হয়।',
  // Flyer's part: the Paid tick.
  'Paid the rest': 'বাকিটা পেইড',
  'Part paid': 'কিছু পেইড',
  // Editing a flyer.
  'Edit flyer': 'ফ্লায়ার এডিট',
  'Save changes': 'পরিবর্তন সেভ করুন',
};

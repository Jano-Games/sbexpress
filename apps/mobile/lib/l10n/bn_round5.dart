/// The owner's fifth round: flyers paying when a flight is saved, adding a
/// flyer from where one is needed, flyers missing documents and the China →
/// Bangladesh route labels.
const bnRound5 = <String, String>{
  // Flyers paying their part when the ticket is saved.
  'Already paid': 'আগেই দিয়েছেন',
  'Paid now': 'এখন দিলেন',
  'Paid now, in addition': 'এখন আরও দিলেন',
  '{amount} already recorded': '{amount} আগেই লেখা আছে',
  'Paid up · {amount} recorded': 'পরিশোধ হয়েছে · {amount} লেখা আছে',
  '{name} can pay at most {amount} now.':
      '{name} এখন সর্বোচ্চ {amount} দিতে পারেন।',
  'Choose the account the flyers paid into.':
      'ফ্লায়ারদের টাকা যে অ্যাকাউন্টে এসেছে, সেটি বেছে নিন।',
  'Flyer payments': 'ফ্লায়ারদের জমা',
  '{amount} from {flyer} goes into {account}.':
      '{flyer}-এর {amount} {account}-এ ঢুকবে।',
  'The amounts are in BDT; the {currency} balance changes at the saved rate.':
      'অঙ্কগুলো BDT; {currency} ব্যালেন্স সেভ করা রেটে বদলাবে।',
  'Recording payments · {done} of {total}':
      'জমা লেখা হচ্ছে · {total}টির {done}টি',
  'The ticket is saved, but these payments were not recorded: {list}. Record them from Payments so far.':
      'টিকিট সেভ হয়েছে, কিন্তু এই জমা লেখা হয়নি: {list}। পরে এ পর্যন্ত লেনদেন থেকে লিখে নিন।',
  'The flight is saved, but these payments were not recorded: {list}. Record them later in Ticket and flyers.':
      'ফ্লাইট সেভ হয়েছে, কিন্তু এই জমা লেখা হয়নি: {list}। পরে টিকিট ও ফ্লায়ার থেকে লিখে নিন।',
  "Enter the ticket cost and each flyer's part first.":
      'আগে টিকিট খরচ আর প্রত্যেক ফ্লায়ারের অংশ লিখুন।',
  // Adding a flyer from where one is needed.
  '+ New flyer': '+ নতুন ফ্লায়ার',
  "{n} files did not upload. Add them on the flyer's page.":
      '{n}টি ফাইল আপলোড হয়নি। ফ্লায়ারের পেজে গিয়ে যোগ করুন।',
  'Add {name} as a flyer': '{name}-কে ফ্লায়ার হিসেবে যোগ করুন',
  'Add the passenger as a flyer': 'যাত্রীকে ফ্লায়ার হিসেবে যোগ করুন',
  // Flyers missing documents.
  '{name} is missing {documents}': '{name}-এর {documents} নেই',
  'Flyer documents': 'ফ্লায়ারের ডকুমেন্ট',
  '{n} more flyers are missing documents': 'আরও {n} জন ফ্লায়ারের ডকুমেন্ট বাকি',
  'student ID': 'স্টুডেন্ট আইডি',
  'visa': 'ভিসা',
  'admission letter': 'অ্যাডমিশন লেটার',
  'documents': 'ডকুমেন্ট',
  '{list} and {last}': '{list} ও {last}',
  // Route labels.
  'Arriving in Bangladesh from China': 'চীন থেকে বাংলাদেশে যা আসছে',
};

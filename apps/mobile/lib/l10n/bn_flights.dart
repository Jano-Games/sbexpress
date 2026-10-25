/// Admin flights, flyers and settings.
const bnFlights = <String, String>{
  // Flights list.
  'Flights': 'ফ্লাইট',
  'Schedule and capacity': 'সময়সূচি ও ক্যাপাসিটি',
  'New': 'নতুন',
  'Upcoming': 'আসছে',
  'Departed': 'উড়েছে',
  'Completed': 'শেষ',
  'All': 'সব',
  'No flights in this filter': 'এই ফিল্টারে ফ্লাইট নেই',
  'New flights will appear here.': 'নতুন ফ্লাইট যোগ করলে এখানে দেখা যাবে।',
  '{n} flights': '{n}টি ফ্লাইট',
  'No flyer assigned': 'ফ্লায়ার অ্যাসাইন করা হয়নি',
  '{n} shipments · Mobiles {mobiles} · Laptops {laptops}':
      '{n} শিপমেন্ট · মোবাইল {mobiles} · ল্যাপটপ {laptops}',
  'Date has passed · Confirm the status':
      'তারিখ পেরিয়েছে · স্ট্যাটাস নিশ্চিত করুন',
  // Flight detail.
  '{kg} kg left · Reference {code}': 'বাকি {kg} kg · রেফারেন্স {code}',
  'Bookings': 'বুকিং',
  'Flyers': 'ফ্লায়ার',
  'Money': 'হিসাব',
  'Ticket': 'টিকিট',
  'Cash settlement, contributions and flyer payments are on a separate page.':
      'ক্যাশ সেটল, কনট্রিবিউশন ও ফ্লায়ার জমা আলাদা পেজে।',
  'Actual cost': 'আসল খরচ',
  'Agency share': 'এজেন্সি শেয়ার',
  'Due from flyers': 'ফ্লায়ার বাকি',
  'Ticket paid': 'টিকিট পরিশোধ',
  'Ticket due': 'টিকিট বাকি',
  'Ticket refund': 'টিকিট রিফান্ড',
  'Shipment charges': 'শিপমেন্ট বিল',
  'Ticket and contributions': 'টিকিট ও কনট্রিবিউশন',
  'No flyers': 'ফ্লায়ার নেই',
  'Add one below.': 'নিচ থেকে একজন যোগ করুন।',
  'Contribution {contribution} · Paid {paid}':
      'কনট্রিবিউশন {contribution} · পেইড {paid}',
  'No active flyers left to add.': 'যোগ করার মতো সক্রিয় ফ্লায়ার নেই।',
  'Add flyer': 'ফ্লায়ার যোগ করুন',
  'Add to flight': 'ফ্লাইটে যোগ করুন',
  '{n} shipments': '{n}টি শিপমেন্ট',
  'No bookings': 'বুকিং নেই',
  'Choose this flight from shipment intake.':
      'শিপমেন্ট ইনটেক থেকে এই ফ্লাইট বেছে নিন।',
  '{supplier} · {kg} · {due} due': '{supplier} · {kg} · বাকি {due}',
  // New flight form.
  'Enter the airline flight number.': 'এয়ারলাইন ফ্লাইট নম্বর দিন।',
  'Choose a date.': 'তারিখ বেছে নিন।',
  'Choose at least one flyer.': 'অন্তত একজন ফ্লায়ার বেছে নিন।',
  'Ticket cost and agency share must be 0 or more, with up to two decimals. Blank counts as 0. Agency share cannot exceed the actual cost.':
      'টিকিট ও এজেন্সি শেয়ার ০ বা তার বেশি, দুই দশমিক পর্যন্ত। খালি রাখলে ০। এজেন্সি শেয়ার আসল খরচের বেশি হতে পারে না।',
  'Ticket payment': 'টিকিট ক্যাশ',
  'Choose date': 'তারিখ বেছে নিন',
  'New flight': 'নতুন ফ্লাইট',
  'Save flight': 'ফ্লাইট সেভ করুন',
  'Flight numbers repeat every day; the server creates the booking reference. Nothing is deducted unless you pay. If you choose an account, the ticket money is paid from it.':
      'ফ্লাইট নম্বর প্রতিদিন আবার আসে। বুকিং রেফারেন্স সার্ভার বানাবে। টাকা না দিলে কিছু কাটে না। অ্যাকাউন্ট বাছলে টিকিটের টাকা সেখান থেকে যায়।',
  'Airline flight number': 'এয়ারলাইন ফ্লাইট নম্বর',
  'Who will fly on this ticket.': 'যারা এই টিকিটে উড়বেন।',
  'Create a flyer profile first.': 'আগে ফ্লায়ার প্রোফাইল খুলুন।',
  'Capacity kg': 'ক্যাপাসিটি kg',
  'Usually 44 or 52': 'সাধারণত ৪৪ বা ৫২',
  'Actual ticket cost (BDT)': 'আসল টিকিট খরচ (BDT)',
  'Leave blank if unknown': 'জানা না থাকলে খালি রাখুন',
  'Pay from account': 'যে অ্যাকাউন্ট থেকে যাবে',
  'If none is chosen, no cash moves now. You can settle it from the flight later.':
      'না বাছলে এখন কোনো ক্যাশ নড়ে না। পরে ফ্লাইট থেকে সেটল করা যায়।',
  // Flight ticket money, settlement, contributions and flyer payments.
  'Ticket money': 'টিকিটের টাকা',
  'Split contributions first, then record flyer payments. Ticket payment is separate.':
      'আগে কনট্রিবিউশন ভাগ করুন, তারপর ফ্লায়ারের জমা। টিকিট ক্যাশ আলাদা।',
  'Unallocated payments': 'অবণ্টিত জমা',
  'Settle ticket payment': 'টিকিট ক্যাশ সেটল',
  'Split contributions': 'কনট্রিবিউশন ভাগ',
  'Flyer payment': 'ফ্লায়ার জমা',
  'Choose an account.': 'অ্যাকাউন্ট বেছে নিন।',
  'Nothing is due or to refund on this ticket.':
      'টিকিটে সেটল করার মতো বাকি বা রিফান্ড নেই।',
  'Due: {movement}': 'বাকি {movement}',
  'Refund: {movement}': 'রিফান্ড {movement}',
  'Settle ticket': 'টিকিট সেটল',
  'Settle now': 'সেটল করুন',
  'Only the outstanding ticket cost or refund is posted to this account. Nothing else changes.':
      'শুধু বাকি টিকিট খরচ বা রিফান্ড এই অ্যাকাউন্টে বসবে। অন্য ফিল্ড বদলায় না।',
  'Due': 'বাকি',
  'Refund': 'রিফান্ড',
  'Enter 0 or more for each flyer.':
      'প্রতিটি ফ্লায়ারের অঙ্ক ০ বা তার বেশি দিন।',
  'Contributions must add up to {amount}.':
      'কনট্রিবিউশন মিলিয়ে {amount} হতে হবে।',
  'Split the earlier unallocated payments of {amount} exactly once.':
      'আগের অবণ্টিত জমা {amount} ঠিক একবার ভাগ করুন।',
  'Contributions': 'কনট্রিবিউশন',
  'The flyer share of {amount} will be locked. Later payments cannot exceed it.':
      'ফ্লায়ার ভাগ {amount} লক হবে। পরে জমা এই ভাগের বেশি হতে পারবে না।',
  'Save split': 'ভাগ সেভ',
  'Shares must add up to {amount}. One entry per flyer.':
      'সবার ভাগ মিলিয়ে {amount}। প্রতিটি ফ্লায়ার একবার।',
  'Add flyers to the flight first.': 'আগে ফ্লাইটে ফ্লায়ার যোগ করুন।',
  'Contribution': 'কনট্রিবিউশন',
  'Earlier payment': 'আগের জমা',
  'Total {amount}': 'মোট {amount}',
  'Save the split first, then choose the flyer, account and amount.':
      'আগে ভাগ সেভ করুন, তারপর ফ্লায়ার, অ্যাকাউন্ট ও অঙ্ক দিন।',
  "Enter no more than this flyer's {amount} due.":
      'এই ফ্লায়ারের বাকি {amount}-এর বেশি নয়।',
  '{amount} goes into {account} as a payment from {flyer}.':
      '{amount} {account}-এ {flyer}-এর জমা হিসেবে ঢুকবে।',
  'Save flyer payment': 'জমা সেভ',
  'Record the account the money arrived in and the flyer who paid.':
      'যে অ্যাকাউন্টে টাকা এসেছে এবং যে ফ্লায়ার দিয়েছেন, সেটাই লিখুন।',
  'Split not saved yet': 'ভাগ এখনো সেভ হয়নি',
  'Share {share} · Paid {paid}': 'ভাগ {share} · পেইড {paid}',
  'Amount received': 'অঙ্ক',
  // Flyers list and new flyer form.
  'Search name or phone': 'নাম বা ফোন খুঁজুন',
  'Profiles and travel documents': 'প্রোফাইল ও ট্রাভেল ডকুমেন্ট',
  'New profiles will appear here.': 'নতুন প্রোফাইল যোগ করলে এখানে দেখা যাবে।',
  '{verified}/{total} documents verified': 'ডকুমেন্ট {verified}/{total} যাচাই',
  'Docs verified': 'যাচাই',
  'Docs pending': 'বাকি',
  'Enter the first name.': 'নামের প্রথম অংশ দিন।',
  'New flyer': 'নতুন ফ্লায়ার',
  'Save flyer': 'সেভ করুন',
  'A name is enough to create the profile. Other fields can stay blank.':
      'নাম দিয়ে প্রোফাইল খোলে। বাকি ঘর খালি রাখা যায়।',
  'First name': 'নামের প্রথম অংশ',
  'Last name': 'নামের শেষ অংশ',
  'Bangladesh phone': 'বাংলাদেশ ফোন',
  'China phone': 'চায়না ফোন',
  'University': 'বিশ্ববিদ্যালয়',
  'Program': 'প্রোগ্রাম',
  'Batch': 'ব্যাচ',
  'Emergency contact': 'ইমার্জেন্সি কন্টাক্ট',
  // Flyer detail and documents.
  'The PDF is over 10 MB. Choose a smaller file.':
      'PDF ১০ MB-এর বেশি। আরও ছোট ফাইল দিন।',
  'Profile': 'প্রোফাইল',
  'Documents': 'ডকুমেন্ট',
  'Emergency {contact}': 'ইমার্জেন্সি {contact}',
  'Student ID': 'স্টুডেন্ট আইডি',
  'ID pending': 'আইডি বাকি',
  'Visa': 'ভিসা',
  'Visa pending': 'ভিসা বাকি',
  'Admission': 'অ্যাডমিশন',
  'Admission pending': 'অ্যাডমিশন বাকি',
  'Total booked {kg} kg': 'মোট বুকড {kg} kg',
  'Reactivate flyer': 'আবার সক্রিয় করুন',
  'Archive flyer': 'আর্কাইভ করুন',
  'No flights': 'ফ্লাইট নেই',
  'Flights appear here once created or assigned.':
      'ফ্লাইট তৈরি বা অ্যাসাইন করলে এখানে আসবে।',
  'Add ID, visa and other travel documents.':
      'আইডি, ভিসা ও অন্যান্য ট্রাভেল ডকুমেন্ট যোগ করুন।',
  'Storage is not set up yet. Uploads are off until setup is complete.':
      'স্টোরেজ এখনো তৈরি হয়নি। সেটআপ শেষ না হওয়া পর্যন্ত আপলোড বন্ধ।',
  'Type': 'ধরন',
  'Camera': 'ক্যামেরা',
  'Gallery': 'গ্যালারি',
  'Upload PDF': 'PDF আপলোড',
  'Send the same photo again': 'একই ছবি আবার পাঠান',
  'No documents': 'ডকুমেন্ট নেই',
  'Verified files will appear here.': 'যাচাই করা ফাইল এখানে থাকবে।',
  'View in app': 'অ্যাপে দেখুন',
  'Share': 'শেয়ার',
  'Remove verification': 'যাচাই তুলে নিন',
  'Mark verified': 'যাচাই করুন',
  // Settings and payment methods.
  'Enter the real CNY rate. Blank or 0 will not be saved.':
      'আসল CNY রেট লিখুন। খালি বা ০ সেভ হবে না।',
  'Settings': 'সেটিংস',
  'Payments, exchange rate and your team': 'পেমেন্ট, এক্সচেঞ্জ রেট ও আপনার টিম',
  'Exchange rate': 'এক্সচেঞ্জ রেট',
  'New transactions use this rate.': 'নতুন লেনদেনে এই রেট ব্যবহার হবে।',
  'BDT per CNY': 'প্রতি CNY-তে BDT',
  'Save rate': 'সেভ',
  'Payment methods': 'পেমেন্ট মেথড',
  'Shown on the customer link': 'Customer link-এ প্রদর্শিত হবে',
  'No methods': 'মেথড নেই',
  'Add bKash, bank or wallet details.':
      'বিকাশ, ব্যাংক বা ওয়ালেটের তথ্য যোগ করুন।',
  'Team and operations': 'টিম ও অপারেশন',
  'Staff management': 'স্টাফ ব্যবস্থাপনা',
  '{count} active · Access and passwords':
      '{count} জন সক্রিয় · অ্যাক্সেস ও পাসওয়ার্ড',
  'Alert when the weight difference exceeds {kg} kg':
      'ওজনের পার্থক্য {kg} kg ছাড়ালে সতর্কতা',
  'System setup': 'সিস্টেম সেটআপ',
  'Connections and required settings': 'সংযোগ ও প্রয়োজনীয় সেটিংস',
  'CNY rate confirmed': 'CNY রেট নিশ্চিত',
  'Fund accounts: {n}': 'ফান্ড অ্যাকাউন্ট {n}',
  'Payment methods: {n}': 'পেমেন্ট মেথড {n}',
  'Active staff: {n}': 'সক্রিয় স্টাফ {n}',
  'Storage': 'স্টোরেজ',
  'Media cleanup': 'মিডিয়া ক্লিনআপ',
  'Last cleanup {at}': 'শেষ ক্লিনআপ {at}',
  'The QR image could not be brought under 300 KB. Choose a smaller image.':
      'QR ছবি ৩০০ KB-এর নিচে আসেনি। আরও ছোট ছবি দিন।',
  'Enter the provider and number. Do not guess the number.':
      'প্রোভাইডার ও নম্বর লিখুন। নম্বর আন্দাজ করবেন না।',
  'Enter the bank, account number and account holder name.':
      'ব্যাংক, অ্যাকাউন্ট নম্বর ও হোল্ডারের নাম লিখুন।',
  'Payment method': 'পেমেন্ট মেথড',
  'It will show on the tracking page and a fund account will be created: {fund} ({currency}).':
      'ট্র্যাকিং পেজে দেখাবে এবং ফান্ড অ্যাকাউন্ট তৈরি হবে: {fund} ({currency})।',
  'New payment method': 'নতুন পেমেন্ট মেথড',
  'Save method': 'মেথড সেভ',
  'Customers see this number on the tracking page. The server blocks it if a fund with the same number already exists.':
      'কাস্টমার ট্র্যাকিং পেজে এই নম্বর দেখে। একই নম্বরের ফান্ড আগে থাকলে সার্ভার আটকাবে।',
  'bKash / mobile': 'বিকাশ / মোবাইল',
  'Bank': 'ব্যাংক',
  'Currency': 'মুদ্রা',
  'Provider': 'প্রোভাইডার',
  'Number': 'নম্বর',
  'Label (optional)': 'লেবেল (ঐচ্ছিক)',
  'Note (optional)': 'নোট (ঐচ্ছিক)',
  'QR image (optional)': 'QR ছবি (ঐচ্ছিক)',
  'QR added': 'QR যোগ হয়েছে',
  'Remove QR': 'QR সরান',
  'Bank name': 'ব্যাংকের নাম',
  'Account number': 'অ্যাকাউন্ট নম্বর',
  'Account holder': 'অ্যাকাউন্ট হোল্ডার',
  'Branch (optional)': 'শাখা (ঐচ্ছিক)',
  'District (optional)': 'জেলা (ঐচ্ছিক)',
  // Staff.
  'Staff': 'স্টাফ',
  'New staff': 'নতুন স্টাফ',
  'Admins see everything. Hub managers do not see money or customer names.':
      'অ্যাডমিন সব দেখে। হাব ম্যানেজার টাকা ও কাস্টমারের নাম দেখে না।',
  'Hub': 'হাব',
  'Admin': 'অ্যাডমিন',
  'You': 'আপনি',
  'Active': 'সক্রিয়',
  'Inactive': 'বন্ধ',
  'Enter a name, email and a password of 8–128 characters.':
      'নাম, ইমেইল ও ৮–১২৮ অক্ষরের পাসওয়ার্ড দিন।',
  'Create staff': 'স্টাফ তৈরি',
  'Hub managers handle shipments. Money is handled by admins.':
      'হাব ম্যানেজার শিপমেন্ট হ্যান্ডেল করে। টাকার কাজ অ্যাডমিনের।',
  'Name': 'নাম',
  'Email': 'ইমেইল',
  'Password': 'পাসওয়ার্ড',
  '8–128 characters': '৮–১২৮ অক্ষর',
  'Check the name and email.': 'নাম ও ইমেইল ঠিক করুন।',
  'Another admin must change your own role.': 'নিজের রোল অন্য অ্যাডমিন বদলাবে।',
  'Another admin must deactivate your own account.':
      'নিজের অ্যাকাউন্ট অন্য অ্যাডমিন বন্ধ করবে।',
  'The new password must be 8–128 characters.': 'নতুন পাসওয়ার্ড ৮–১২৮ অক্ষর।',
  'Enter your current password to change your own password.':
      'নিজের পাসওয়ার্ড বদলাতে বর্তমান পাসওয়ার্ড দিন।',
  'Your password': 'নিজের পাসওয়ার্ড',
  'All sessions will end and you will need to sign in again.':
      'সব সেশন কেটে যাবে এবং আবার লগইন করতে হবে।',
  'Save password': 'পাসওয়ার্ড সেভ',
  'You cannot change your own role. Changing your password signs you out.':
      'নিজের রোল বদলানো যায় না। পাসওয়ার্ড বদলালে লগআউট হবে।',
  'Role and password are saved separately.': 'রোল ও পাসওয়ার্ড আলাদা সেভ হয়।',
  'Role: Admin (your own role cannot be changed here)':
      'রোল: অ্যাডমিন (নিজের রোল এখানে বদলায় না)',
  'Role': 'রোল',
  'Save profile': 'প্রোফাইল সেভ',
  'Current password': 'বর্তমান পাসওয়ার্ড',
  'New password': 'নতুন পাসওয়ার্ড',
};

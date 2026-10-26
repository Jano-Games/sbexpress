/// Quick add: the overview, the Add menu, the customer and flyer forms and
/// the one-page booking.
const bnQuick = <String, String>{
  // Overview.
  'Customers owe us': 'কাস্টমারের কাছে পাওনা',
  'Flyers owe us': 'ফ্লায়ারের কাছে পাওনা',
  'ticket parts': 'টিকিটের ভাগ',
  'We owe': 'আমাদের দেনা',
  'tickets · costs': 'টিকিট · খরচ',
  'Nothing needs attention right now': 'এখন দেখার মতো কিছু নেই',
  '{amount} to collect from handed-over shipments':
      'হ্যান্ডওভার হওয়া শিপমেন্ট থেকে {amount} আদায় বাকি',
  'Overdue': 'দেরি হয়েছে',
  '{code} weighed {kg} kg more than booked':
      '{code}-এর ওজন বুকিংয়ের চেয়ে {kg} kg বেশি',
  '{code} weighed {kg} kg less than booked':
      '{code}-এর ওজন বুকিংয়ের চেয়ে {kg} kg কম',
  '{customer} · {weighed} kg vs {booked} kg':
      '{customer} · ওজন {weighed} kg, বুকিং {booked} kg',
  'Monthly bill: {name} owes {amount}': 'মাসিক বিল: {name}-এর বাকি {amount}',
  'Monthly · cycle closes {date}': 'মাসিক · হিসাব বন্ধ {date}',
  '{month} bills: {amount} still due': '{month} মাসের বিল: {amount} বাকি',
  'Cash in hand · all accounts': 'হাতে টাকা · সব অ্যাকাউন্ট',
  '{bdt} + {cny} at {rate}': '{bdt} + {cny} ({rate} রেটে)',
  'Money in {in}, money out {out}': 'টাকা এসেছে {in}, গেছে {out}',
  'Net': 'নিট',
  'Shipments by stage': 'কোন ধাপে কত শিপমেন্ট',
  'On a flight': 'ফ্লাইটে',
  'Charges {amount}': 'চার্জ {amount}',
  'Profit so far {amount}': 'এ পর্যন্ত প্রফিট {amount}',
  'Landed': 'নেমেছে',
  'profit {amount}': 'প্রফিট {amount}',
  '{n} bills are overdue after delivery': 'ডেলিভারির পর {n}টি বিলে দেরি হয়েছে',
  '{n} shipments are missing costs': '{n}টি শিপমেন্টে খরচ বাকি',

  // Add menu.
  'Add new': 'নতুন যোগ করুন',
  'Book cargo for a customer': 'কাস্টমারের মাল বুক করুন',
  'Enter it or import the e-ticket': 'নিজে লিখুন বা ই-টিকিট থেকে আনুন',
  'Code fills in by itself': 'কোড নিজে থেকেই বসে যায়',
  'Profile with ID, visa and admission': 'আইডি, ভিসা ও অ্যাডমিশনসহ প্রোফাইল',
  'Import flight from e-ticket PDF': 'ই-টিকিট PDF থেকে ফ্লাইট আনুন',

  // Customer form.
  '{code} is already used by another customer.':
      '{code} কোডটি আরেকজন কাস্টমারের। অন্য কোড দিন।',
  'The next free code. Type your own if you prefer — it must not be used already.':
      'পরের খালি কোড। চাইলে নিজের কোড লিখুন — তবে আগে ব্যবহার হওয়া কোড চলবে না।',
  'Leave empty for an automatic code': 'খালি রাখলে কোড নিজে থেকে বসবে',
  'Auto': 'অটো',
  'How does this customer usually pay?': 'এই কাস্টমার সাধারণত কীভাবে টাকা দেন?',
  'Pays for each shipment once it arrives':
      'প্রতিটি শিপমেন্ট পৌঁছানোর পর টাকা দেন',
  'One bill for the whole month': 'পুরো মাসের জন্য একটি বিল',
  'New bookings for this customer start with this choice; each booking can still change it.':
      'এই কাস্টমারের নতুন বুকিংয়ে এটিই আগে থেকে বাছা থাকবে; প্রতিটি বুকিংয়ে বদলানো যাবে।',

  // Flyer form.
  'Admission letter': 'অ্যাডমিশন লেটার',
  'Profile and travel documents in one go': 'প্রোফাইল ও ভ্রমণের কাগজ একবারে',
  'Uploading {done} of {total}': '{total}টির মধ্যে {done}টি আপলোড হয়েছে',
  '{n} of {total} added': '{total}টির মধ্যে {n}টি যোগ হয়েছে',
  "Files upload right after the flyer is saved. Optional — you can add them later on the flyer's page too.":
      'ফ্লায়ার সেভ হলেই ফাইল আপলোড হবে। এটি ঐচ্ছিক — পরে ফ্লায়ারের পেজ থেকেও যোগ করা যাবে।',
  'Save flyer and upload {n} files': 'ফ্লায়ার সেভ করে {n}টি ফাইল আপলোড করুন',
  'Files still to upload': 'যে ফাইল এখনও আপলোড বাকি',

  // Booking.
  'One page · fill top to bottom': 'এক পেজে · ওপর থেকে নিচে পূরণ করুন',
  '{n} of 5 done': '{n}/5 হয়েছে',
  'Create shipment · {amount}': 'শিপমেন্ট তৈরি করুন · {amount}',
  'No customer yet': 'কাস্টমার বাছা হয়নি',
  'Flight later': 'ফ্লাইট পরে',
  'No flight yet': 'ফ্লাইট বাছা হয়নি',
  '1 · Customer': '1 · কাস্টমার',
  '2 · Which flight?': '2 · কোন ফ্লাইট?',
  '3 · What is inside?': '3 · ভেতরে কী আছে?',
  '4 · Weight and charge': '4 · ওজন ও চার্জ',
  'How will they pay?': 'কীভাবে টাকা দেবেন?',
  'optional': 'ঐচ্ছিক',
  '{devices} allowed': '{devices} নেওয়া যাবে',
  '{n} mobiles': '{n}টি মোবাইল',
  '{n} laptops': '{n}টি ল্যাপটপ',
  'No flyer yet': 'ফ্লায়ার এখনও নেই',
  'Chosen on the flight page': 'ফ্লাইটের পেজ থেকে বাছা',
  'Decide later': 'পরে ঠিক করব',
  'Only the model is needed — no IMEI or serial.':
      'শুধু মডেল লাগবে — IMEI বা সিরিয়াল লাগবে না।',
  'Model, e.g. {example}': 'মডেল, যেমন {example}',
  'Remove this model': 'এই মডেল বাদ দিন',
  'Add another model': 'আরেকটি মডেল যোগ করুন',
  '{name} · {n} pieces': '{name} · {n} পিস',
  '{name} photos': '{name}-এর ছবি',
  'Add {name} photos': '{name}-এর ছবি যোগ করুন',
  '{name} usually pays monthly.': '{name} সাধারণত মাসিক টাকা দেন।',
  '{name} usually pays after delivery.':
      '{name} সাধারণত ডেলিভারির পর টাকা দেন।',
  'Parcel photos': 'পার্সেলের ছবি',
  'as many as you like': 'যত খুশি',
  'Add parcel photos': 'পার্সেলের ছবি যোগ করুন',
  'Description (optional)': 'বিবরণ (ঐচ্ছিক)',
  'Step {n} done': 'ধাপ {n} হয়েছে',
  'Step {n}': 'ধাপ {n}',

  // Photos and files.
  'Remove photo': 'ছবি বাদ দিন',
  'Add photos': 'ছবি যোগ করুন',
  'Take a photo': 'ছবি তুলুন',
  'Choose from gallery': 'গ্যালারি থেকে বাছুন',
  '{file} · ready to upload': '{file} · আপলোডের জন্য তৈরি',
  'Remove {document} file': '{document} ফাইল বাদ দিন',
  'Photo or PDF': 'ছবি বা PDF',
  'Uploading photos': 'ছবি আপলোড হচ্ছে',
  'Uploading files': 'ফাইল আপলোড হচ্ছে',
  'Photos uploaded': 'ছবি আপলোড হয়েছে',
  'Files uploaded': 'ফাইল আপলোড হয়েছে',
  '{done} of {total}': '{total}টির মধ্যে {done}টি',
  '{done} of {total} uploaded': '{total}টির মধ্যে {done}টি আপলোড হয়েছে',
  '{n} photos did not upload': '{n}টি ছবি আপলোড হয়নি',
  '{n} files did not upload': '{n}টি ফাইল আপলোড হয়নি',

  // Booked.
  '{cargo} on {flight}': '{flight}-এ {cargo}',
  'pays monthly': 'মাসিক টাকা দেবেন',
  'pays after delivery': 'ডেলিভারির পর টাকা দেবেন',
  '{code} is booked': '{code} বুক হয়েছে',
  'You can leave this screen — the rest keeps uploading.':
      'এই পেজ ছেড়ে গেলেও বাকিগুলো আপলোড হতে থাকবে।',
  'Open {code}': '{code} খুলুন',
  'Costs, bill and tracking': 'খরচ, বিল ও ট্র্যাকিং',
  'Send it to {name}': '{name}-কে পাঠান',
  'Book another': 'আরেকটি বুক করুন',
  '{flight} space left': '{flight}-এ জায়গা বাকি',

  // More: team.
  'Team': 'টিম',
  'Add admin or hub manager': 'অ্যাডমিন বা হাব ম্যানেজার যোগ',
  'A new sign-in for the team': 'টিমের জন্য নতুন লগইন',
  'Everyone who can sign in': 'যারা লগইন করতে পারেন',
};

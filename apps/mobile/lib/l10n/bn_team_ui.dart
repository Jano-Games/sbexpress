/// Flyers, tasks, settings, staff, payment methods, invoice editor and the
/// new fund form (redesigned screens).
const bnTeamUi = <String, String>{
  // Flyer list.
  'Search name, phone or university': 'নাম, ফোন বা বিশ্ববিদ্যালয় খুঁজুন',
  'Active flyers': 'সক্রিয় ফ্লায়ার',
  'All flyers': 'সব ফ্লায়ার',
  '{n} profiles': '{n}টি প্রোফাইল',
  'No flyers match': 'মিলে যায় এমন ফ্লায়ার নেই',
  'Try another name, phone or university.':
      'অন্য নাম, ফোন বা বিশ্ববিদ্যালয় দিয়ে খুঁজুন।',
  'A flyer counts as verified once the student ID and visa are both checked. Open a profile to verify files.':
      'স্টুডেন্ট আইডি ও ভিসা দুটোই যাচাই হলে ফ্লায়ার যাচাই হয়েছে ধরা হয়। ফাইল যাচাই করতে প্রোফাইল খুলুন।',
  '{verified} of {total} documents verified':
      '{total}টির মধ্যে {verified}টি ডকুমেন্ট যাচাই হয়েছে',
  '{verified} of {total} verified · ID and visa waiting':
      '{total}টির মধ্যে {verified}টি যাচাই · আইডি ও ভিসা বাকি',
  '{verified} of {total} verified · student ID waiting':
      '{total}টির মধ্যে {verified}টি যাচাই · স্টুডেন্ট আইডি বাকি',
  '{verified} of {total} verified · visa waiting':
      '{total}টির মধ্যে {verified}টি যাচাই · ভিসা বাকি',
  'Archived': 'আর্কাইভ করা',
  'No documents uploaded yet': 'এখনো কোনো ডকুমেন্ট আপলোড হয়নি',
  // Flyer profile.
  'Profile, documents and flights': 'প্রোফাইল, ডকুমেন্ট ও ফ্লাইট',
  'Total booked': 'মোট বুকিং',
  'Batch {batch}': 'ব্যাচ {batch}',
  'Contact': 'যোগাযোগ',
  'BD phone': 'বাংলাদেশ ফোন',
  'CN phone': 'চায়না ফোন',
  'Emergency': 'ইমার্জেন্সি',
  '{verified} of {total} verified': '{total}টির মধ্যে {verified}টি যাচাই',
  '{kind} · by {name}': '{kind} · {name} দিয়েছেন',
  'Verified': 'যাচাই হয়েছে',
  'Verified by {name}': '{name} যাচাই করেছেন',
  'No documents yet': 'এখনো ডকুমেন্ট নেই',
  'Upload the student ID and visa to verify this flyer.':
      'ফ্লায়ার যাচাই করতে স্টুডেন্ট আইডি ও ভিসা আপলোড করুন।',
  'Add a document': 'ডকুমেন্ট যোগ করুন',
  'PDF up to 10 MB': 'PDF সর্বোচ্চ ১০ MB',
  'Archived flyers leave the list. You can reactivate them.':
      'আর্কাইভ করা ফ্লায়ার তালিকা থেকে সরে যায়। পরে আবার সক্রিয় করা যায়।',
  'This flyer is archived. Reactivate to show this flyer in the list again.':
      'এই ফ্লায়ার আর্কাইভ করা। তালিকায় আবার দেখাতে সক্রিয় করুন।',
  // New flyer.
  'Personal details': 'ব্যক্তিগত তথ্য',
  'Study': 'পড়াশোনা',
  // Tasks.
  'Payment reviews': 'পেমেন্ট যাচাই',
  'Close on their own': 'নিজে থেকেই বন্ধ হয়',
  'Shipment steps': 'শিপমেন্টের ধাপ',
  'Your notes': 'আপনার নোট',
  'Tick when done': 'শেষ হলে টিক দিন',
  'Who does it': 'কে করবে',
  // Settings.
  'Confirmed': 'নিশ্চিত',
  'Not confirmed': 'নিশ্চিত নয়',
  'bank account': 'ব্যাংক অ্যাকাউন্ট',
  'hidden': 'লুকানো',
  'Weight alert': 'ওজন সতর্কতা',
  'Booked vs weighed difference': 'বুকিং আর মাপা ওজনের পার্থক্য',
  'CNY rate': 'CNY রেট',
  'Fund accounts': 'ফান্ড অ্যাকাউন্ট',
  'Active staff': 'সক্রিয় স্টাফ',
  'Set up': 'সেটআপ হয়েছে',
  'Not set up': 'সেটআপ হয়নি',
  'On': 'চালু',
  'Off': 'বন্ধ',
  // Staff.
  'Access and passwords': 'অ্যাক্সেস ও পাসওয়ার্ড',
  '{n} active': '{n} জন সক্রিয়',
  'Admins': 'অ্যাডমিন',
  'Sees everything, including money': 'টাকাসহ সবকিছু দেখে',
  'Handles shipments. No money or customer names':
      'শিপমেন্ট সামলায়। টাকা বা কাস্টমারের নাম দেখে না',
  "can't sign in": 'লগইন করতে পারবে না',
  'Open a person to change their role, switch them off or set a new password. Another admin has to change your own role.':
      'রোল বদলাতে, অ্যাকাউন্ট বন্ধ করতে বা নতুন পাসওয়ার্ড দিতে নাম খুলুন। আপনার নিজের রোল অন্য অ্যাডমিনকে বদলাতে হবে।',
  'Can sign in': 'লগইন করতে পারবে',
  'Switched off accounts cannot sign in.':
      'বন্ধ অ্যাকাউন্ট দিয়ে লগইন করা যায় না।',
  // Payment method form.
  'Shown on the customer tracking page': 'কাস্টমারের ট্র্যাকিং পেজে দেখা যাবে',
  'Pick one above, or type another provider.':
      'ওপর থেকে একটি বাছুন, অথবা অন্য প্রোভাইডার লিখুন।',
  'Copy it from the account. Do not guess.':
      'অ্যাকাউন্ট থেকে কপি করুন। আন্দাজে লিখবেন না।',
  'From the gallery, kept under 300 KB':
      'গ্যালারি থেকে, ৩০০ KB-এর মধ্যে রাখা হয়',
  'Choose': 'বাছুন',
  'How customers see it': 'কাস্টমার যেভাবে দেখবে',
  'Preview': 'প্রিভিউ',
  'Payment number': 'পেমেন্ট নম্বর',
  'Saving also creates the fund account {fund} ({currency}). It is blocked if a fund with this number already exists.':
      'সেভ করলে {fund} ({currency}) ফান্ড অ্যাকাউন্টও তৈরি হবে। এই নম্বরে আগে থেকে ফান্ড থাকলে সেভ হবে না।',
  // Invoice editor.
  'Shipment {code}': 'শিপমেন্ট {code}',
  'Draft': 'ড্রাফট',
  'Issuing locks the total. Lowering it later creates a credit note.':
      'ইস্যু করলে মোট অঙ্ক লক হয়ে যায়। পরে কমালে ক্রেডিট নোট তৈরি হয়।',
  'Item': 'আইটেম',
  '{n} of 30': '৩০টির মধ্যে {n}টি',
  'Subtotal': 'সাবটোটাল',
  '{n} lines': '{n}টি লাইন',
  '{amount} discount': '{amount} ছাড়',
  'Issue {amount}': '{amount} ইস্যু করুন',
  'After issuing, any change needs a revision reason. A ৳0 invoice can only be issued once you tick "free of charge".':
      'ইস্যুর পর যেকোনো পরিবর্তনে রিভিশনের কারণ লাগবে। ৳০ ইনভয়েস কেবল "ফ্রি অব চার্জ" টিক দিলে ইস্যু করা যায়।',
  // New fund.
  'A cash or general fund account': 'ক্যাশ বা সাধারণ ফান্ড অ্যাকাউন্ট',
  "In the account's currency. Empty means 0 and no ledger line.":
      'অ্যাকাউন্টের মুদ্রায়। খালি রাখলে ০, লেজারে কোনো লাইন হবে না।',
  'New account': 'নতুন অ্যাকাউন্ট',
  '{type} · {currency} · new account': '{type} · {currency} · নতুন অ্যাকাউন্ট',
  'Opens with': 'শুরুর ব্যালেন্স',
  'Goes to the ledger as capital. It is not income.':
      'লেজারে মূলধন হিসেবে যাবে। এটি আয় নয়।',
  'No ledger line. Add money later with income or a transfer.':
      'লেজারে লাইন হবে না। পরে আয় বা ট্রান্সফার দিয়ে টাকা যোগ করুন।',
  'Bank and bKash accounts are added from Settings, under payment methods.':
      'ব্যাংক ও বিকাশ অ্যাকাউন্ট সেটিংসের পেমেন্ট মেথড থেকে যোগ হয়।',
};

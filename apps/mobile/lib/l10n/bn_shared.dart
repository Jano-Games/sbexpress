/// Shared widgets, data labels, uploads, login and the More menu.
const bnShared = <String, String>{
  // Shared widgets.
  '{kg} kg over': '{kg} kg বেশি',
  '{kg} kg free': '{kg} kg খালি',
  'Step {step}/{total}': 'ধাপ {step}/{total}',
  'Try again': 'আবার চেষ্টা',
  'Home': 'হোম',
  'Shipments': 'শিপমেন্ট',
  'Flights': 'ফ্লাইট',
  'Tasks': 'কাজ',
  'Finance': 'হিসাব',
  'More': 'আরও',
  'Back': 'পিছনে',
  'Go back': 'ফিরে যান',
  'Confirm': 'নিশ্চিত',
  'Reason': 'কারণ',
  'At least 3 characters': 'কমপক্ষে ৩ অক্ষর',
  'No accounts yet. Add a fund in Finance first.':
      'অ্যাকাউন্ট নেই। আগে ফাইন্যান্সে একটি ফান্ড যোগ করুন।',
  'Choose an account': 'অ্যাকাউন্ট বেছে নিন',
  // Hub chain steps.
  'Weigh': 'ওজন',
  'Pack': 'প্যাক',
  'Courier': 'কুরিয়ার',
  'Dispatch': 'ডিসপ্যাচ',
  'Handover': 'হ্যান্ডওভার',
  'No hub step right now': 'এখন হাবের ধাপ নেই',
  // Shipment statuses.
  'Pending': 'অপেক্ষমাণ',
  'Arrived at China hub': 'চায়না হাবে এসেছে',
  'Ready for shipment': 'পাঠানোর জন্য প্রস্তুত',
  'In transit': 'পথে আছে',
  'Customs cleared': 'কাস্টমস ক্লিয়ার',
  'At Dhaka hub': 'ঢাকা হাবে',
  'Ready for last mile': 'লাস্ট মাইলের জন্য প্রস্তুত',
  'Out for delivery': 'ডেলিভারিতে বেরিয়েছে',
  'Delivered': 'ডেলিভারি হয়েছে',
  // Customer activity.
  'Payment': 'পেমেন্ট',
  'Advance': 'অগ্রিম',
  'Refund': 'রিফান্ড',
  'Credit applied': 'ক্রেডিট প্রয়োগ',
  'Credit adjustment': 'ক্রেডিট সমন্বয়',
  // Flyer document kinds and cost categories.
  'Student ID': 'স্টুডেন্ট আইডি',
  'Visa': 'ভিসা',
  'Admission': 'অ্যাডমিশন',
  'Passport': 'পাসপোর্ট',
  'Ticket': 'টিকিট',
  'Other': 'অন্যান্য',
  'Packaging': 'প্যাকেজিং',
  'Service': 'সার্ভিস',
  'Transport': 'ট্রান্সপোর্ট',
  'Customs': 'কাস্টমস',
  // Repositories and session.
  'Choose an account to settle a due cost.':
      'বকেয়া খরচ মিটাতে অ্যাকাউন্ট বেছে নিন।',
  'Choose the account the money will come from.':
      'যে অ্যাকাউন্ট থেকে টাকা যাবে সেটা বেছে নিন।',
  'Your session has not been checked yet. It will retry when the network is back.':
      'সেশন যাচাই এখনো হয়নি। নেটওয়ার্ক ফিরলে আবার চেষ্টা হবে।',
  'Could not open the file ({status})': 'ফাইল খোলা যায়নি ({status})',
  // Uploads.
  'The upload link is not valid.': 'আপলোড লিংক সঠিক নয়।',
  'The upload link must use HTTPS.': 'আপলোড লিংক HTTPS হতে হবে।',
  'Empty files are not accepted.': 'খালি ফাইল নেওয়া যায় না।',
  'The PDF is over 10 MB. Choose a smaller file.':
      'PDF ১০ MB-এর বেশি। আরও ছোট ফাইল দিন।',
  'This HEIC photo could not be converted to JPEG on this device. Export it as JPEG and try again.':
      'এই HEIC ছবি এই ডিভাইসে JPEG-এ রূপান্তর হয়নি। JPEG হিসেবে এক্সপোর্ট করে আবার দিন।',
  'Location data removed': 'লোকেশন তথ্য মুছে দেওয়া হয়েছে',
  'The photo is over 25 MB. Choose a smaller file.':
      'ছবিটি 25 MB-এর বেশি। আরও ছোট ফাইল দিন।',
  'Unsupported format. SVG is not accepted. Use JPEG, PNG, WebP or HEIC.':
      'ফরম্যাট মেলেনি। SVG নেওয়া হয় না। JPEG, PNG, WebP বা HEIC দিন।',
  'Unsupported format. Use JPEG, PNG, WebP or HEIC.':
      'ফরম্যাট মেলেনি। JPEG, PNG, WebP বা HEIC দিন।',
  'Unsupported format. The photo could not be read. Use JPEG, PNG, WebP or HEIC.':
      'ফরম্যাট মেলেনি। ছবিটি পড়া যায়নি। JPEG, PNG, WebP বা HEIC দিন।',
  'The photo is still over 10 MB after compression. Choose a smaller photo.':
      'কমপ্রেসের পরেও ছবিটি 10 MB-এর বেশি। আরও ছোট ছবি দিন।',
  // Matched inside upload errors so an already-described error is kept.
  'expired': 'মেয়াদ',
  'Storage': 'স্টোরেজ',
  'Unsupported format': 'ফরম্যাট মেলেনি',
  'format': 'ফরম্যাট',
  'Storage is not set up yet. Uploads start once an admin finishes storage setup.':
      'স্টোরেজ এখনো তৈরি হয়নি। অ্যাডমিন স্টোরেজ সেটআপ শেষ করলে আপলোড চালু হবে।',
  'Too many uploads in a short time. Wait a minute and try again with the same photo.':
      'অল্প সময়ে অনেক আপলোড হয়েছে। এক মিনিট পর একই ছবি দিয়ে চেষ্টা করুন।',
  'The upload expired. Try again with the same photo.':
      'আপলোডের মেয়াদ শেষ। একই ছবি দিয়ে আবার চেষ্টা করুন।',
  'The upload did not reach storage (network or storage CORS). Try again with the same photo.':
      'নেটওয়ার্ক বা স্টোরেজ CORS-এর কারণে আপলোড পৌঁছায়নি। একই ছবি দিয়ে আবার চেষ্টা করুন।',
  'Upload failed ({status}): {message} Try again with the same photo.':
      'আপলোড ব্যর্থ ({status}): {message} একই ছবি দিয়ে আবার চেষ্টা করুন।',
  'Upload failed. Try again with the same photo.':
      'আপলোড ব্যর্থ। একই ছবি দিয়ে আবার চেষ্টা করুন।',
  // Login.
  'Enter a valid email.': 'সঠিক ইমেইল দিন।',
  'Enter your password.': 'পাসওয়ার্ড দিন।',
  'Sign in': 'লগইন করুন',
  'Enter your staff email and password. Your account decides whether you get hub or admin.':
      'স্টাফ ইমেইল ও পাসওয়ার্ড দিন। হাব না অ্যাডমিন — অ্যাকাউন্ট থেকেই ঠিক হবে।',
  'Email': 'ইমেইল',
  'Your email': 'আপনার ইমেইল',
  'Password': 'পাসওয়ার্ড',
  'Show password': 'পাসওয়ার্ড দেখুন',
  'Hide password': 'পাসওয়ার্ড লুকান',
  'Forgot your password? Tell an admin.':
      'পাসওয়ার্ড ভুলে গেলে অ্যাডমিনকে জানান',
  'China': 'চীন',
  'Chengdu': 'চেংদু',
  'Bangladesh': 'বাংলাদেশ',
  'Dhaka': 'ঢাকা',
  'All your air cargo work,\nin one app.': 'এয়ার কার্গোর সব কাজ,\nএক অ্যাপে।',
  // More menu.
  'IMEI photos': 'IMEI ছবি',
  'Save device serials and photos': 'ডিভাইসের সিরিয়াল ও ছবি সংরক্ষণ',
  'Photos / media': 'ছবি / মিডিয়া',
  'View and add shipment photos': 'শিপমেন্টের ছবি দেখুন ও যোগ করুন',
  'Tasks & notes': 'কাজ ও নোট',
  'Team tasks and daily notes': 'টিমের কাজ ও দৈনন্দিন নোট',
  'Payment review': 'পেমেন্ট যাচাই',
  'Receipts and payment screenshots': 'রসিদ ও পেমেন্ট স্ক্রিনশট',
  'Shipment intake': 'শিপমেন্ট ইনটেক',
  'Book a new parcel': 'নতুন পার্সেল বুকিং',
  'Issue & share invoices': 'ইনভয়েস ইস্যু ও শেয়ার',
  'Prepare bills and customer links': 'বিল প্রস্তুত ও customer link',
  'Schedules and baggage capacity': 'শিডিউল ও লাগেজ ক্যাপাসিটি',
  'Flyers': 'ফ্লায়ার',
  'Profiles and travel documents': 'প্রোফাইল ও ট্রাভেল ডকুমেন্ট',
  'Customers': 'কাস্টমার',
  'Dues and shipment accounts': 'বকেয়া ও শিপমেন্টের হিসাব',
  'Finance overview': 'ফাইন্যান্স',
  'Accounts, transactions and reports': 'অ্যাকাউন্ট, লেনদেন ও রিপোর্ট',
  'Assign tasks': 'কাজ অ্যাসাইন',
  'Share out team tasks': 'টিমের কাজ বণ্টন',
  'Settings': 'সেটিংস',
  'Business setup and team': 'ব্যবসার সেটআপ ও টিম',
  'Shipment photos and attachments': 'শিপমেন্টের ছবি ও সংযুক্তি',
  'Hub tasks': 'হাবের কাজ',
  'Partners': 'পার্টনার',
  'Shipment tools': 'শিপমেন্ট টুলস',
  'Tasks & finance': 'কাজ ও হিসাব',
  'Management': 'ব্যবস্থাপনা',
  // PDF viewer.
  'Share': 'শেয়ার',
  'This PDF is empty.': 'এই PDF খালি।',
  'PDF {n} bytes': 'PDF {n} বাইট',
};

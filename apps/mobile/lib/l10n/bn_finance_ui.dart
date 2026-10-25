/// Customers and finance (redesigned screens): customer list and profile,
/// statement, account activity, transfer, deposit or expense, ledger and
/// reconciliation.
const bnFinanceUi = <String, String>{
  // Months.
  'January': 'জানুয়ারি',
  'February': 'ফেব্রুয়ারি',
  'March': 'মার্চ',
  'April': 'এপ্রিল',
  'May': 'মে',
  'June': 'জুন',
  'July': 'জুলাই',
  'August': 'আগস্ট',
  'September': 'সেপ্টেম্বর',
  'October': 'অক্টোবর',
  'November': 'নভেম্বর',
  'December': 'ডিসেম্বর',
  // Shared parts.
  'Open shipment {code}': 'শিপমেন্ট {code} খুলুন',
  'Clear search': 'খোঁজা মুছুন',
  '{n} lines': '{n}টি লাইন',
  '{n} lines · page {page} of {pages}': '{n}টি লাইন · পৃষ্ঠা {page}/{pages}',
  'Money in': 'টাকা এসেছে',
  'Money out': 'টাকা গেছে',
  'Balance {amount}': 'ব্যালেন্স {amount}',
  '1 CNY = {rate}': '1 CNY = {rate}',
  'Paid from': 'যে অ্যাকাউন্ট থেকে',
  'Paid into': 'যে অ্যাকাউন্টে',
  // Customer list.
  'No matching customers': 'মিলে যায় এমন কাস্টমার নেই',
  'Try another name, code or phone.': 'অন্য নাম, কোড বা ফোন দিয়ে খুঁজুন।',
  'Owe money': 'টাকা বাকি',
  'Settled': 'পরিশোধিত',
  'Total due': 'মোট বাকি',
  '{n} to price': '{n}টির দাম বাকি',
  'Credit {amount}': 'ক্রেডিট {amount}',
  'due': 'বাকি',
  'settled': 'পরিশোধিত',
  // Customer profile.
  'Monthly terms': 'মাসিক টার্ম',
  'Instant terms': 'সাথে সাথে পরিশোধ',
  'Shipments · {n}': 'শিপমেন্ট · {n}',
  '{pct}% of billed amount paid': 'বিলের {pct}% পরিশোধ হয়েছে',
  'Nothing billed yet': 'এখনো কোনো বিল হয়নি',
  'Payments, advances, credit and refunds':
      'পেমেন্ট, অগ্রিম, ক্রেডিট ও রিফান্ড',
  'Advance and credit balance · {amount}':
      'অগ্রিম ও ক্রেডিট ব্যালেন্স · {amount}',
  'All activity': 'সব হিসাব',
  'Discount {amount}': 'ছাড় {amount}',
  // Account activity.
  'Amounts in BDT': 'অঙ্ক BDT-তে',
  'From credit balance': 'ক্রেডিট ব্যালেন্স থেকে',
  'Ref {reference}': 'রেফ {reference}',
  'Reason: {reason}': 'কারণ: {reason}',
  // Customer credit.
  'Advances and adjustments the customer has not used yet.':
      'কাস্টমারের অগ্রিম ও সমন্বয়, যা এখনো ব্যবহার হয়নি।',
  'No credit to use or refund right now.':
      'এখন ব্যবহার বা ফেরত দেওয়ার মতো ক্রেডিট নেই।',
  'Use the credit': 'ক্রেডিট ব্যবহার',
  'Pay part of an issued invoice from the credit':
      'ক্রেডিট দিয়ে ইস্যু করা ইনভয়েসের টাকা মেটান',
  'Give the credit back from an account': 'অ্যাকাউন্ট থেকে ক্রেডিট ফেরত দিন',
  'Credit balance {amount}': 'ক্রেডিট ব্যালেন্স {amount}',
  // New customer.
  'Save customer': 'কাস্টমার সেভ করুন',
  'Shop or person name': 'দোকান বা ব্যক্তির নাম',
  'House, road and area': 'বাড়ি, রোড ও এলাকা',
  'Billed per shipment': 'প্রতি শিপমেন্টে বিল',
  'One statement a month': 'মাসে একটি স্টেটমেন্ট',
  // Monthly statement.
  'Link copied': 'লিংক কপি হয়েছে',
  '{n} to review': '{n}টি যাচাই বাকি',
  'Revoke all': 'সব বাতিল',
  'Previous month': 'আগের মাস',
  'Statement month': 'স্টেটমেন্টের মাস',
  'Next month': 'পরের মাস',
  'Due for {month}': '{month} মাসের বাকি',
  'Waiting': 'অপেক্ষায়',
  'Accepted': 'অনুমোদিত',
  'Rejected': 'বাতিল হয়েছে',
  '{month} statement': '{month} মাসের স্টেটমেন্ট',
  'New payment link': 'নতুন পেমেন্ট লিংক',
  'Only issued, reviewed invoices can be shared.':
      'শুধু ইস্যু ও রিভিউ করা ইনভয়েস শেয়ার করা যায়।',
  'Link works for': 'লিংক চলবে',
  'Leave empty to ask for the full {amount} due.':
      'খালি রাখলে পুরো {amount} বাকি চাওয়া হবে।',
  'Until {date}': '{date} পর্যন্ত',
  'Expired': 'মেয়াদ শেষ',
  'Ended {date}': '{date} শেষ হয়েছে',
  'Revoked': 'বাতিল করা',
  // Account transfer.
  'From': 'যেখান থেকে',
  'To': 'যেখানে',
  'Different currencies, so enter what actually arrives.':
      'মুদ্রা আলাদা, তাই আসলে যা পৌঁছাবে সেটা লিখুন।',
  'Different currencies, so enter what actually arrives. Works out to {rate}.':
      'মুদ্রা আলাদা, তাই আসলে যা পৌঁছাবে সেটা লিখুন। হিসাবে দাঁড়ায় {rate}।',
  'What is this transfer for?': 'ট্রান্সফার কিসের জন্য?',
  'After this transfer': 'ট্রান্সফারের পরে',
  // Deposit or expense.
  'Office money outside shipments': 'শিপমেন্টের বাইরে অফিসের টাকা',
  'Save capital': 'মূলধন সেভ করুন',
  'Save expense': 'খরচ সেভ করুন',
  'Save income': 'আয় সেভ করুন',
  'What is it?': 'কিসের টাকা?',
  'Owner adds': 'মালিক দেন',
  'Money the owner puts in. Cash goes up, profit does not.':
      'মালিকের দেওয়া টাকা। ক্যাশ বাড়বে, প্রফিট নয়।',
  "Office costs only. Shipment costs go on the shipment's costs page.":
      'শুধু অফিসের খরচ। শিপমেন্টের খরচ শিপমেন্টের খরচ পেজে।',
  'Office income outside shipments. Customer payments are recorded on the shipment.':
      'শিপমেন্টের বাইরে অফিসের আয়। কাস্টমারের পেমেন্ট শিপমেন্টে লেখা হয়।',
  'Category': 'ক্যাটাগরি',
  'What was it for?': 'কিসের জন্য খরচ?',
  'Where did the money come from?': 'টাকা কোথা থেকে এলো?',
  // Ledger.
  'Customer payment': 'কাস্টমারের পেমেন্ট',
  'Customer advance': 'কাস্টমারের অগ্রিম',
  'Period': 'সময়',
  'All accounts': 'সব অ্যাকাউন্ট',
  'No account': 'অ্যাকাউন্ট ছাড়া',
  'All types': 'সব ধরন',
  'Both sides of the transfer from {from} to {to} will be reversed.':
      '{from} থেকে {to}-এ ট্রান্সফারের দুই পাশই বাতিল হবে।',
  'Every money movement, newest first': 'টাকার সব লেনদেন, নতুনগুলো আগে',
  'Description, reference or shipment': 'বিবরণ, রেফারেন্স বা শিপমেন্ট',
  'Nothing matches these filters.': 'এই ফিল্টারে কিছু মেলেনি।',
  'both sides of a transfer reverse together':
      'ট্রান্সফারের দুই পাশ একসাথে বাতিল হয়',
  'Payment received': 'পেমেন্ট জমা হয়েছে',
  'Reversal': 'উল্টানো এন্ট্রি',
  'Reversed': 'উল্টে দেওয়া হয়েছে',
  'Reverse both': 'দুই পাশ বাতিল',
  // Reconciliation.
  'Balances checked against the ledger': 'লেজারের সাথে ব্যালেন্স মিলিয়ে দেখা',
  'All clear': 'সব ঠিক আছে',
  '{n} to check': '{n}টি দেখতে হবে',
  "Opening balance + ledger movement = current, in each account's own currency":
      'শুরুর ব্যালেন্স + লেজারের নড়াচড়া = বর্তমান, প্রতিটি অ্যাকাউন্টের নিজের মুদ্রায়',
  'All in BDT': 'সব BDT-তে',
  'Opening balances are worked out as current balance minus recorded movement. An older balance is normal for accounts that existed before the ledger.':
      'বর্তমান ব্যালেন্স থেকে লেজারে লেখা নড়াচড়া বাদ দিয়ে শুরুর ব্যালেন্স বের হয়। লেজারের আগে থেকে থাকা অ্যাকাউন্টে পুরনো ব্যালেন্স থাকা স্বাভাবিক।',
  'Everything adds up': 'সব মিলে গেছে',
  'Every shipment payment matches the ledger and every line has an account.':
      'প্রতিটি শিপমেন্টের পেমেন্ট লেজারের সাথে মেলে, আর প্রতিটি লাইনে অ্যাকাউন্ট আছে।',
  'Nothing is fixed automatically. Check them against bank or cash records.':
      'কিছুই নিজে থেকে ঠিক হয় না। ব্যাংক বা ক্যাশ রেকর্ডের সাথে মিলিয়ে নিন।',
  'Has opening balance': 'শুরুর ব্যালেন্স আছে',
  'All in ledger': 'সবই লেজারে',
  '{opening} opening and {ledger} from the ledger':
      'শুরুতে {opening}, লেজার থেকে {ledger}',
  'Opening': 'শুরু',
  'Difference {amount}': 'পার্থক্য {amount}',
  'Allocated as paid': 'পেইড হিসেবে বরাদ্দ',
  'In the ledger': 'লেজারে আছে',
  'no account recorded': 'অ্যাকাউন্ট লেখা নেই',
  "{n} things don't add up": '{n}টি হিসাব মিলছে না',
  'Shipments with mismatched payments': 'পেমেন্ট মিলছে না এমন শিপমেন্ট',
  'Lines with no account snapshot': 'অ্যাকাউন্ট স্ন্যাপশট ছাড়া লাইন',
};

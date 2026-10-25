/// Finance screens and customers.
const bnFinance = <String, String>{
  // Finance home.
  'Finance': 'হিসাব',
  'BDT and CNY · reports in BDT': 'BDT ও CNY · রিপোর্ট BDT-তে',
  'Accounts': 'অ্যাকাউন্ট',
  'Reports': 'রিপোর্ট',
  'Transactions': 'লেনদেন',
  'Total account balance · BDT': 'মোট অ্যাকাউন্ট ব্যালেন্স · BDT',
  'Taka · BDT': 'টাকা · BDT',
  'Yuan · CNY': 'ইউয়ান · CNY',
  'Transfer': 'ট্রান্সফার',
  'Deposit / expense': 'জমা / খরচ',
  'Reconcile': 'মিলিয়ে দেখা',
  'Ledger': 'লেজার',
  'Your accounts': 'আপনার অ্যাকাউন্ট',
  'New': 'নতুন',
  'No accounts': 'অ্যাকাউন্ট নেই',
  'Add a bank, cash or wallet account.':
      'ব্যাংক, ক্যাশ বা ওয়ালেট অ্যাকাউন্ট যোগ করুন।',
  'This week': 'এই সপ্তাহ',
  'All time': 'সর্বমোট',
  'Cash flow': 'ক্যাশ ফ্লো',
  'Deposits': 'জমা',
  'Expenses': 'ব্যয়',
  'Net cash': 'নেট ক্যাশ',
  'Exchange rate': 'এক্সচেঞ্জ রেট',
  'Receivables and payables': 'পাওনা ও পরিশোধযোগ্য',
  'Customer receivables': 'কাস্টমারের কাছে পাওনা',
  'Flyer receivables': 'ফ্লায়ারের কাছে পাওনা',
  'Flight tickets to pay': 'টিকিট বাবদ দিতে হবে',
  'Other costs to pay': 'অন্যান্য খরচ বাকি',
  'Booking results': 'বুকিংয়ের ফলাফল',
  'Billing and costs for the selected period': 'নির্বাচিত সময়ের বিল ও খরচ',
  'Shipments': 'শিপমেন্ট',
  'Billed': 'বিল',
  'Costs': 'খরচ',
  'Booking profit': 'বুকিং প্রফিট',
  'Margin': 'মার্জিন',
  'Opening balances and capital count as cash received, not profit.':
      'শুরুর ব্যালেন্স ও মূলধন ক্যাশ জমায় থাকে; প্রফিটে যোগ হয় না।',
  'New transaction': 'নতুন লেনদেন',
  'Account transfer': 'অ্যাকাউন্ট ট্রান্সফার',
  'Move money between your own accounts': 'নিজস্ব অ্যাকাউন্টের মধ্যে টাকা সরান',
  'Deposit or expense': 'জমা বা খরচ',
  'Office income, expenses and capital': 'অফিসের আয়, ব্যয় ও মূলধন',
  'Review and history': 'যাচাই ও ইতিহাস',
  'Payment review': 'পেমেন্ট যাচাই',
  'Check receipts sent by customers': 'কাস্টমারের পাঠানো রসিদ দেখুন',
  'Transaction ledger': 'লেনদেনের লেজার',
  'History of deposits, expenses and transfers':
      'জমা, খরচ ও ট্রান্সফারের ইতিহাস',
  'Deposits {received}, expenses {expenses}':
      'জমা {received}, ব্যয় {expenses}',
  'Money received': 'জমা হয়েছে',
  // New fund.
  'Enter a real account name.': 'অ্যাকাউন্টের আসল নাম লিখুন।',
  'Opening balance must be 0 or more, with up to two decimals.':
      'শুরুর ব্যালেন্স ০ বা তার বেশি, দুই দশমিক পর্যন্ত।',
  '{name} ({currency}) will open with a zero opening balance. Use income or a transfer to add money.':
      '{name} ({currency}) খুলবে। শুরুর ব্যালেন্স ০। টাকা ঢোকাতে আয় বা ট্রান্সফার ব্যবহার করুন।',
  'The {amount} opening balance of {name} goes to the ledger as capital. It is not income.':
      '{name}-এ {amount} শুরুর ব্যালেন্স ক্যাপিটাল হিসেবে লেজারে যাবে। এটা আয় নয়।',
  'New fund': 'নতুন ফান্ড',
  'Create fund': 'ফান্ড তৈরি',
  'A cash or general fund. The opening amount is a capital payment; leave it empty for 0 and no ledger line. Bank and bKash accounts are added from payment methods.':
      'ক্যাশ বা সাধারণ ফান্ড। শুরুর টাকা ক্যাপিটাল পেমেন্ট। খালি রাখলে ০, কোনো লেজার লাইন হয় না। ব্যাংক ও বিকাশ পেমেন্ট মেথড থেকে যোগ হয়।',
  'Account name': 'অ্যাকাউন্টের নাম',
  'Opening balance ({currency})': 'শুরুর ব্যালেন্স ({currency})',
  "In the account's currency. Empty means 0.":
      'অ্যাকাউন্টের মুদ্রায়। খালি মানে ০।',
  'Type': 'ধরন',
  'Cash': 'ক্যাশ',
  'Fund': 'ফান্ড',
  'Currency': 'মুদ্রা',
  // Ledger and reversals.
  'Reverse entry': 'এন্ট্রি বাতিল',
  'The reason must be at least 3 characters.': 'বাতিলের কারণ কমপক্ষে ৩ অক্ষর।',
  'Reverse ledger entry': 'লেজার বাতিল',
  '{description} will be reversed. The money returns to the original account.':
      '{description} উল্টে দেওয়া হবে। টাকা আগের অ্যাকাউন্টে ফিরবে।',
  'The latest 50 lines. Both sides of a transfer are reversed together.':
      'সাম্প্রতিক ৫০টি লাইন। ট্রান্সফারের দুই পাশ একবার বাতিল হয়।',
  'No lines': 'লাইন নেই',
  'Money movements appear here when they are recorded.':
      'টাকা নড়লে এখানে আসবে।',
  'Reverse': 'বাতিল',
  // Deposit or expense.
  'Enter an account, amount and note. Income notes are up to 160 characters.':
      'অ্যাকাউন্ট, অঙ্ক ও নোট দিন। আয়ের নোট ১৬০ অক্ষরের মধ্যে।',
  'Owner capital': 'মালিকের মূলধন',
  'Office expense': 'অফিস খরচ',
  'Income': 'আয়',
  '{amount} leaves {account}.': '{amount} {account} থেকে যাবে।',
  '{amount} goes into {account}.': '{amount} {account}-এ ঢুকবে।',
  'Cash goes up, profit does not.': 'ক্যাশ বাড়বে, প্রফিট নয়।',
  'Save': 'সেভ করুন',
  "Office income, capital or expenses outside shipments. Shipment costs go on the shipment's costs page.":
      'শিপমেন্ট ছাড়া অফিসের আয়, মূলধন বা খরচ। শিপমেন্ট খরচ শিপমেন্টের খরচ পেজে।',
  'Capital': 'মূলধন',
  'Expense': 'খরচ',
  'Amount': 'অঙ্ক',
  'Reason': 'কারণ',
  'Note': 'নোট',
  // Reconciliation.
  'Reconciliation': 'মিলিয়ে দেখা',
  'Account amounts are in their own currency; shipment differences are in BDT. Older balances not in the ledger are shown separately as opening balance.':
      'অ্যাকাউন্টের টাকা তার মুদ্রায়। শিপমেন্টের পার্থক্য BDT। পুরনো ব্যালেন্স যা লেজারে নেই, সেটা শুরুর ব্যালেন্স হিসেবে আলাদা।',
  '{n} lines have no account snapshot.': '{n} লাইনে অ্যাকাউন্ট স্ন্যাপশট নেই।',
  '{n} shipments have mismatched payments.': '{n} শিপমেন্টে পেমেন্ট মিলছে না।',
  'Current balance, ledger movement, and the part not in the ledger.':
      'বর্তমান ব্যালেন্স, লেজারে নড়া, এবং যে অংশ লেজারে নেই।',
  'Open a fund to see its reconciliation here.':
      'ফান্ড খুললে এখানে মিল দেখা যাবে।',
  'Current': 'বর্তমান',
  'Opening (implied)': 'শুরু (অনুমান)',
  'Shipment differences': 'শিপমেন্ট পার্থক্য',
  'All amounts in BDT.': 'সব অংক BDT।',
  'No differences': 'পার্থক্য নেই',
  'Issued payments match the ledger.': 'ইস্যু করা পেমেন্ট আর লেজার একই।',
  'Allocated': 'বরাদ্দ',
  'Difference': 'পার্থক্য',
  'Open shipment': 'শিপমেন্ট খুলুন',
  'Missing snapshots': 'স্ন্যাপশট নেই',
  'These are not rebuilt. Check them against bank or cash records.':
      'এগুলো আবার বানানো হয় না। ব্যাংক বা ক্যাশ রেকর্ডের সাথে মিলিয়ে নিন।',
  // Account transfer.
  'Choose two different accounts, an amount and a 1–200 character note.':
      'আলাদা দুটি অ্যাকাউন্ট, অঙ্ক ও ১–২০০ অক্ষরের নোট দিন।',
  'Enter the amount arriving in the {currency} account.':
      '{currency} অ্যাকাউন্টে যা ঢুকবে সেই অঙ্ক লিখুন।',
  '{amount} moves from {from} to {to}.': '{amount} {from} থেকে {to}-এ যাবে।',
  '{amount} leaves {from} and {received} arrives in {to}.':
      '{amount} {from} ছাড়বে এবং {received} {to}-এ ঢুকবে।',
  'Save transfer': 'ট্রান্সফার সেভ',
  'From one fund to another. Profit does not change.':
      'এক ফান্ড থেকে অন্য ফান্ডে। প্রফিট বদলায় না।',
  'Two accounts needed': 'দুটি অ্যাকাউন্ট লাগে',
  'Add payment methods or funds to move money from here.':
      'পেমেন্ট মেথড বা ফান্ড যোগ করলে এখান থেকে সরানো যাবে।',
  'From account': 'যেখান থেকে',
  'To account': 'যেখানে',
  'Amount ({currency})': 'অঙ্ক ({currency})',
  'Amount arriving ({currency})': 'গন্তব্যে ঢুকবে ({currency})',
  // Customers.
  'Customers': 'কাস্টমার',
  'Search name, code or phone': 'নাম, কোড বা ফোন খুঁজুন',
  'Contacts, shipments and receivables': 'যোগাযোগ, শিপমেন্ট ও পাওনা',
  'No customers': 'কাস্টমার নেই',
  'New customers you add will appear here.':
      'নতুন কাস্টমার যোগ করলে এখানে দেখা যাবে।',
  '{n} shipments · {kg} kg': '{n} শিপমেন্ট · {kg} kg',
  'Summary': 'সারসংক্ষেপ',
  'Terms': 'টার্ম',
  'Monthly': 'মাসিক',
  'Instant': 'সাথে সাথে',
  'Address': 'ঠিকানা',
  'Paid': 'পেইড',
  'Due': 'বাকি',
  'Credit': 'ক্রেডিট',
  'Discount': 'ছাড়',
  'Pricing pending': 'দাম বাকি',
  'Monthly statement': 'মাসিক স্টেটমেন্ট',
  'Account activity': 'অ্যাকাউন্ট হিসাব',
  'No shipments': 'শিপমেন্ট নেই',
  'Shipments appear here after intake.': 'ইনটেক করলে এখানে আসবে।',
  'Due {amount}': 'বাকি {amount}',
  'Recent payments': 'সাম্প্রতিক পেমেন্ট',
  'No payments': 'পেমেন্ট নেই',
  'Payments appear here once money reaches the ledger.':
      'লেজারে টাকা ঢুকলে এখানে দেখা যাবে।',
  'Invoices': 'ইনভয়েস',
  // Customer account activity.
  'Reverse transaction': 'হিসাব বাতিল',
  '{label} {amount} will be reversed.': '{label} {amount} উল্টে দেওয়া হবে।',
  '{name} · payments, advances, credit and refunds, in the original currency and BDT.':
      '{name} · পেমেন্ট, অগ্রিম, ক্রেডিট ও রিফান্ড। মূল মুদ্রা আর BDT একসাথে।',
  'No activity': 'হিসাব নেই',
  'Original': 'মূল',
  'Rate': 'রেট',
  'Account': 'অ্যাকাউন্ট',
  'Credit balance': 'ক্রেডিট ব্যালেন্স',
  '{n} lines · page {page}': '{n} লাইন · পৃষ্ঠা {page}',
  'Previous page': 'আগের',
  'Next page': 'পরের',
  // Customer credit.
  'Customer credit': 'কাস্টমার ক্রেডিট',
  'Apply to bill': 'বিলে বসান',
  'Refund': 'রিফান্ড',
  'Choose a shipment and enter an amount within the credit.':
      'শিপমেন্ট বেছে নিন এবং ক্রেডিটের মধ্যে অঙ্ক দিন।',
  'Apply credit': 'ক্রেডিট বসান',
  '{amount} will be applied to the issued invoice for {shipment}. Draft bills are not affected.':
      '{amount} {shipment}-এর ইস্যু করা ইনভয়েসে বসবে। ড্রাফট বিলে বসবে না।',
  'Apply': 'বসান',
  'Balance {amount}. Applies only to issued invoices that are not under review.':
      'ব্যালেন্স {amount}। ইস্যু করা ও রিভিউ-মুক্ত ইনভয়েসেই বসবে।',
  'Credit can be applied here once an invoice is issued.':
      'ইনভয়েস ইস্যু হলে এখান থেকে বসানো যাবে।',
  'Choose an account, an amount within the credit and a reason of at least 3 characters.':
      'অ্যাকাউন্ট, ক্রেডিটের মধ্যে অঙ্ক ও ৩ অক্ষরের কারণ দিন।',
  'Refund credit': 'ক্রেডিট রিফান্ড',
  '{amount} will be refunded from {account}.':
      '{amount} {account} থেকে ফেরত যাবে।',
  'Save refund': 'রিফান্ড সেভ',
  'Balance {amount}. Choose the account the money leaves from.':
      'ব্যালেন্স {amount}। যে অ্যাকাউন্ট থেকে টাকা বের হবে সেটা বেছে নিন।',
  // New customer.
  'Enter the customer name.': 'কাস্টমারের নাম দিন।',
  'New customer': 'নতুন কাস্টমার',
  'The server assigns the code. Payment accounts are not added here.':
      'কোড সার্ভার দেবে। পেমেন্ট অ্যাকাউন্ট এখানে যোগ করা হয় না।',
  'Name': 'নাম',
  'Phone': 'ফোন',
  'Billing terms': 'বিলিং টার্ম',
  // Monthly statement.
  'Enter the month as 2026-10.': 'মাস ২০২৬-১০ এই ফর্মে লিখুন।',
  'Leave the requested amount empty or enter a positive amount.':
      'অনুরোধের অঙ্ক খালি রাখুন অথবা ধনাত্মক দিন।',
  'The request cannot exceed the {amount} due.':
      'অনুরোধ বকেয়া {amount}-এর বেশি নয়।',
  'Revoke all links': 'সব লিংক বাতিল',
  "This customer's active statement links will stop opening.":
      'এই কাস্টমারের চালু স্টেটমেন্ট লিংক আর খুলবে না।',
  'Approve receipt': 'রসিদ অনুমোদন',
  '{amount} via {method} will be recorded as received.':
      '{amount} {method} জমা হিসেবে ঢুকবে।',
  'Reject receipt': 'রসিদ বাতিল',
  '{name}. A link can be made only when there are issued, reviewed invoices.':
      '{name}। শুধু ইস্যু ও রিভিউ করা ইনভয়েস থাকলে লিংক হয়।',
  'Month': 'মাস',
  'For example 2026-10': 'যেমন ২০২৬-১০',
  'Show this month': 'এই মাস দেখুন',
  'New link': 'নতুন লিংক',
  '7 days': '৭ দিন',
  '14 days': '১৪ দিন',
  '30 days': '৩০ দিন',
  'Requested amount (optional)': 'অনুরোধের অঙ্ক (ঐচ্ছিক)',
  'Leave empty to request the full due amount': 'খালি রাখলে পুরো বকেয়া',
  'Create and copy link': 'লিংক তৈরি ও কপি',
  'Saved links': 'সেভ করা লিংক',
  'No links': 'লিংক নেই',
  'Nothing shared for this month yet.': 'এই মাসে এখনো শেয়ার করা হয়নি।',
  'This link can no longer be copied': 'লিংক আর কপি করা যায় না',
  'Copy': 'কপি',
  'Receipts': 'রসিদ',
  'No receipts': 'রসিদ নেই',
  'Receipts customers submit on the public link will appear here.':
      'কাস্টমার পাবলিক লিংকে রসিদ দিলে এখানে আসবে।',
  'Accept': 'অনুমোদন',
  'Reject': 'বাতিল',
};

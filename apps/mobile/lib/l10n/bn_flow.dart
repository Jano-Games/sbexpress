/// The core business flow: home, Get paid, ticket and flyers, flight profit,
/// booking terms, shipment costs and usual cost amounts.
const bnFlow = <String, String>{
  // Home.
  'All flights': 'সব ফ্লাইট',
  'Customer balance due {amount}': 'কাস্টমারের বাকি {amount}',
  'Get paid': 'টাকা আদায়',
  'Still to collect from customers': 'কাস্টমারদের কাছ থেকে আদায় বাকি',
  'To collect after delivery': 'ডেলিভারির পর আদায়',
  '{n} overdue': '{n}টি দেরি হয়েছে',
  'Monthly bills · {month}': 'মাসিক বিল · {month}',
  'Flight profit so far': 'এ পর্যন্ত ফ্লাইটের প্রফিট',
  '{n} shipments handed over': '{n}টি শিপমেন্ট হ্যান্ডওভার হয়েছে',
  'Due from {n} customers': '{n} জন কাস্টমারের বাকি',
  '{n} shipments missing costs': '{n}টি শিপমেন্টে খরচ বাকি',
  '{n} missing costs': '{n}টিতে খরচ বাকি',
  // Payment ways.
  'After delivery': 'ডেলিভারির পর',
  'After-delivery and monthly bills still owed':
      'ডেলিভারির পরের ও মাসিক বিলের বাকি টাকা',
  // Get paid.
  'No phone number saved for {name}.': '{name}-এর ফোন নম্বর সেভ করা নেই।',
  '{phone} copied. Paste it in your phone app to call.':
      '{phone} কপি হয়েছে। কল করতে ফোন অ্যাপে পেস্ট করুন।',
  'Money customers still owe · {day}': 'কাস্টমারদের বাকি টাকা · {day}',
  'After delivery · {n}': 'ডেলিভারির পর · {n}',
  'Monthly · {n}': 'মাসিক · {n}',
  'The server needs an update': 'সার্ভার আপডেট করতে হবে',
  'Get paid needs the newer server. Once the owner updates it, pull down to refresh.':
      'টাকা আদায়ের তালিকার জন্য নতুন সার্ভার লাগবে। মালিক আপডেট করলে নিচে টেনে রিফ্রেশ করুন।',
  'Sent by customers from their links': 'কাস্টমাররা লিংক থেকে পাঠিয়েছেন',
  'Waiting over a week · {n}': 'এক সপ্তাহের বেশি অপেক্ষা · {n}',
  'Delivered this week · {n}': 'এই সপ্তাহে ডেলিভারি · {n}',
  'Handed over, not paid': 'হ্যান্ডওভার হয়েছে, টাকা আসেনি',
  'Oldest first': 'পুরনোগুলো আগে',
  'Nothing to collect': 'আদায়ের কিছু নেই',
  'No handed-over shipment is waiting for payment.':
      'হ্যান্ডওভার হওয়া কোনো শিপমেন্টের টাকা বাকি নেই।',
  'Coming soon': 'শিগগির আসছে',
  'Due once handed over': 'হ্যান্ডওভারের পর বাকি হবে',
  'One bill per customer for the month': 'প্রতি কাস্টমারের মাসে একটি বিল',
  'No monthly bills yet': 'এখনো মাসিক বিল নেই',
  'Monthly customers appear here once a bill for this month is issued.':
      'এই মাসের বিল দেওয়া হলে মাসিক কাস্টমাররা এখানে দেখা যাবে।',
  'Delivered today': 'আজ ডেলিভারি হয়েছে',
  'Delivered yesterday': 'গতকাল ডেলিভারি হয়েছে',
  '{n} days since delivery': 'ডেলিভারির {n} দিন হলো',
  'delivered {date}': 'ডেলিভারি {date}',
  'Call {name}': '{name}-কে কল করুন',
  'Link not sent': 'লিংক পাঠানো হয়নি',
  'Link sent {date}': 'লিংক পাঠানো {date}',
  'Link sent {date} · expired': 'লিংক পাঠানো {date} · মেয়াদ শেষ',
  'Billed {billed} · paid {paid}': 'বিল {billed} · পরিশোধ {paid}',
  'Send bill link': 'বিলের লিংক পাঠান',
  '{n} shipments handed over and not paid':
      '{n}টি শিপমেন্ট হ্যান্ডওভার হয়েছে, টাকা আসেনি',
  '{n} customers still owe this month': 'এই মাসে {n} জন কাস্টমারের বাকি',
  // Record payment.
  'Enter the amount received.': 'যত টাকা এসেছে তা লিখুন।',
  'Enter no more than the {amount} due.': 'বাকি {amount}-এর বেশি লিখবেন না।',
  'Choose where the money came in.': 'টাকা কোন অ্যাকাউন্টে এসেছে বেছে নিন।',
  'Full due': 'পুরো বাকি',
  'Lower it if the customer paid only part.':
      'কাস্টমার কিছু অংশ দিলে অঙ্ক কমিয়ে দিন।',
  '{code} becomes Paid': '{code} পরিশোধ হবে',
  '{amount} goes into {account} · nothing left to collect':
      '{amount} {account}-এ যাবে · আর কিছু আদায় বাকি থাকবে না',
  '{code} stays part paid': '{code} আংশিক পরিশোধ থাকবে',
  '{amount} goes into {account} · {left} still to collect':
      '{amount} {account}-এ যাবে · {left} আদায় বাকি থাকবে',
  // Flight profit.
  'Ticket and flyers': 'টিকিট ও ফ্লায়ার',
  'No flyers yet': 'এখনো ফ্লায়ার নেই',
  'Book shipment · {kg} kg free': 'শিপমেন্ট বুক · {kg} kg খালি',
  'Ticket cost not added yet': 'টিকিট খরচ এখনো যোগ হয়নি',
  'We pay all · {amount}': 'পুরোটা আমরা দিই · {amount}',
  'Flyers pay part · we pay {amount}': 'ফ্লায়াররা কিছু দেন · আমরা দিই {amount}',
  'No shipments booked yet': 'এখনো কোনো শিপমেন্ট বুক হয়নি',
  'So far · {code} has no costs added yet':
      'এ পর্যন্ত · {code}-এ এখনো খরচ যোগ হয়নি',
  'So far · {n} shipments have no costs added yet':
      'এ পর্যন্ত · {n}টি শিপমেন্টে এখনো খরচ যোগ হয়নি',
  'So far · some costs are still to be added':
      'এ পর্যন্ত · কিছু খরচ এখনো যোগ করা বাকি',
  'So far': 'এ পর্যন্ত',
  'Flight profit': 'ফ্লাইটের প্রফিট',
  'Shipment costs': 'শিপমেন্টের খরচ',
  'Our ticket share': 'টিকিটে আমাদের অংশ',
  'of {amount}': '{amount}-এর মধ্যে',
  'Still to come in': 'এখনো আসা বাকি',
  'Customers · {amount} paid': 'কাস্টমার · {amount} পরিশোধ',
  'before costs': 'খরচের আগে',
  'profit': 'প্রফিট',
  '{name} · {kg} · charge {amount}': '{name} · {kg} · চার্জ {amount}',
  // Ticket and flyers.
  'Enter the ticket cost as a number with up to two decimals.':
      'টিকিট খরচ সংখ্যায় লিখুন, দশমিকের পর সর্বোচ্চ দুই ঘর।',
  "The flyers' parts add up to more than the ticket.":
      'ফ্লায়ারদের অংশ টিকিটের চেয়ে বেশি হয়ে গেছে।',
  'Who pays the ticket?': 'টিকিটের টাকা কে দেবে?',
  'We pay all': 'পুরোটা আমরা দিই',
  'Our company pays the whole ticket': 'পুরো টিকিট আমাদের কোম্পানি দেয়',
  'Flyers pay part': 'ফ্লায়াররা কিছু দেন',
  'Each flyer pays a part, we pay the rest':
      'প্রত্যেক ফ্লায়ার একটি অংশ দেন, বাকিটা আমরা',
  'Choose the flyers above first.': 'আগে ওপরে ফ্লায়ার বেছে নিন।',
  'Assign the earlier {amount} in Split contributions first.':
      'আগের {amount} আগে কনট্রিবিউশন ভাগে বসিয়ে দিন।',
  '{name} has already paid {amount}, so their part cannot be lower.':
      '{name} ইতিমধ্যে {amount} দিয়েছেন, তাই তাঁর অংশ এর কম হতে পারে না।',
  'Add the flyers who carry cargo on this ticket.':
      'এই টিকিটে যাঁরা মাল নিয়ে যাবেন সেই ফ্লায়ারদের যোগ করুন।',
  "Each flyer's part": 'প্রত্যেক ফ্লায়ারের অংশ',
  '{amount} of the ticket is not split between the flyers yet.':
      'টিকিটের {amount} এখনো ফ্লায়ারদের মধ্যে ভাগ হয়নি।',
  'Payments so far': 'এ পর্যন্ত লেনদেন',
  'Money in from flyers and out to the ticket seller':
      'ফ্লায়ারদের কাছ থেকে আসা আর টিকিট বিক্রেতাকে দেওয়া টাকা',
  'Save the changes first to record payments.':
      'জমা লিখতে আগে পরিবর্তন সেভ করুন।',
  'Flyers paid us': 'ফ্লায়াররা দিয়েছেন',
  'We pay the whole ticket, so no flyer pays.':
      'পুরো টিকিট আমরা দিচ্ছি, তাই কোনো ফ্লায়ার দেবেন না।',
  '{amount} left': '{amount} বাকি',
  'We paid the ticket seller': 'টিকিট বিক্রেতাকে দিয়েছি',
  'Pay ticket': 'টিকিটের টাকা দিন',
  '{amount} refund due': '{amount} ফেরত পাওনা',
  '{amount} left to pay': '{amount} দেওয়া বাকি',
  '{name} · no part': '{name} · অংশ নেই',
  '{name} · paid up': '{name} · পরিশোধ হয়েছে',
  '{name} · {left} left of {part}': '{name} · {part}-এর {left} বাকি',
  'From e-ticket': 'ই-টিকিট থেকে',
  'Remove {name} from {flight}': '{flight} থেকে {name}-কে সরান',
  // Booking terms.
  'A change here applies to this booking only.':
      'এখানে বদলালে শুধু এই বুকিংয়ে লাগবে।',
  '{name} usually pays monthly, so Monthly is chosen. A change here applies to this booking only.':
      '{name} সাধারণত মাসিক দেন, তাই মাসিক বেছে রাখা হলো। এখানে বদলালে শুধু এই বুকিংয়ে লাগবে।',
  '{name} usually pays after delivery, so After delivery is chosen. A change here applies to this booking only.':
      '{name} সাধারণত ডেলিভারির পর দেন, তাই ডেলিভারির পর বেছে রাখা হলো। এখানে বদলালে শুধু এই বুকিংয়ে লাগবে।',
  '{name} usually pays monthly. This booking will be collected after delivery instead.':
      '{name} সাধারণত মাসিক দেন। এই বুকিংয়ের টাকা ডেলিভারির পর নেওয়া হবে।',
  '{name} usually pays after delivery. This booking goes on the monthly bill instead.':
      '{name} সাধারণত ডেলিভারির পর দেন। এই বুকিং মাসিক বিলে যাবে।',
  'The flight is chosen on the next step.': 'ফ্লাইট পরের ধাপে বেছে নেওয়া হবে।',
  'Device pieces': 'ডিভাইস পিস',
  'None in this shipment': 'এই শিপমেন্টে নেই',
  'Add in Cargo': 'কার্গো ধাপে যোগ করুন',
  'Charge for this booking': 'এই বুকিংয়ের চার্জ',
  'Updates as you type': 'লিখতে লিখতে বদলায়',
  'Shipping · {kg} kg × {rate}': 'শিপিং · {kg} kg × {rate}',
  'Device pieces · none': 'ডিভাইস পিস · নেই',
  'How will the customer pay?': 'কাস্টমার কীভাবে টাকা দেবেন?',
  'Pays when the parcel is handed over': 'পার্সেল হাতে পেলে টাকা দেন',
  'Goes on one bill for the month': 'মাসের একটি বিলে যায়',
  'Usual costs will be added': 'নিয়মিত খরচগুলো যোগ হবে',
  'As a checklist on the shipment. Amounts come later.':
      'শিপমেন্টে চেকলিস্ট হিসেবে। অঙ্ক পরে।',
  'Other costs can be added on the shipment at any time.':
      'অন্য খরচ যেকোনো সময় শিপমেন্টে যোগ করা যায়।',
  '{kg} kg left after this booking': 'এই বুকিংয়ের পর {kg} kg বাকি',
  // Shipment money and costs.
  'flyer {name}': 'ফ্লায়ার {name}',
  'Bill and payments': 'বিল ও পেমেন্ট',
  'No bill issued yet': 'এখনো বিল দেওয়া হয়নি',
  'Goes on the {month} bill': '{month}-এর বিলে যাবে',
  '{number} · on the {month} bill': '{number} · {month}-এর বিলে',
  '{n} {name} pieces × {rate}': '{n}টি {name} × {rate}',
  'Pays': 'পরিশোধ',
  'Still due': 'এখনো বাকি',
  'The usual four, plus anything extra': 'নিয়মিত চারটি, সাথে বাড়তি যা লাগে',
  'All {n} added': '{n}টিই যোগ হয়েছে',
  '{done} of {total} added': '{total}টির {done}টি যোগ হয়েছে',
  'Other costs': 'অন্যান্য খরচ',
  'Other cost': 'অন্য খরচ',
  'All costs': 'সব খরচ',
  'Total costs': 'মোট খরচ',
  'Not added yet': 'এখনো যোগ হয়নি',
  'Add {cost} cost': '{cost} খরচ যোগ করুন',
  'Profit on this shipment': 'এই শিপমেন্টের প্রফিট',
  'Profit': 'প্রফিট',
  'Not added yet: {costs}. The profit goes down when they are.':
      'এখনো যোগ হয়নি: {costs}। যোগ হলে প্রফিট কমবে।',
  'Weighed': 'ওজন',
  'Not yet': 'এখনো না',
  'Packed': 'প্যাক',
  'Pickup': 'পিকআপ',
  'Dhaka hub steps': 'ঢাকা হাবের ধাপ',
  // Add cost.
  'Enter the cost amount.': 'খরচের অঙ্ক লিখুন।',
  'Add a note to say what this cost was.': 'খরচটা কিসের, নোটে লিখে দিন।',
  '{cost} is usually {amount}. Change it if this one was different.':
      '{cost} সাধারণত {amount}। এবার আলাদা হলে বদলে দিন।',
  'No usual amount saved for {cost} yet. Set one in Settings.':
      '{cost}-এর নিয়মিত অঙ্ক এখনো সেভ করা নেই। সেটিংসে ঠিক করুন।',
  'Add cost · {code}': 'খরচ যোগ · {code}',
  '{name} · costs so far {amount}': '{name} · এ পর্যন্ত খরচ {amount}',
  'Usual amount': 'নিয়মিত অঙ্ক',
  'Paid now from': 'এখন যে অ্যাকাউন্ট থেকে',
  'Pay later': 'পরে পরিশোধ',
  'Save it as unpaid. Nothing leaves an account.':
      'বাকি হিসেবে সেভ হবে। কোনো অ্যাকাউন্ট থেকে টাকা যাবে না।',
  'Add a note': 'নোট যোগ করুন',
  '(optional)': '(ঐচ্ছিক)',
  'After saving': 'সেভ করার পর',
  'Costs {costs} · Profit {profit}': 'খরচ {costs} · প্রফিট {profit}',
  'was {amount}': 'আগে {amount}',
  'and {amount}': 'ও {amount}',
  // Usual cost amounts in Settings.
  'Enter each usual cost as a number, or leave it empty for none.':
      'প্রতিটি নিয়মিত খরচ সংখ্যায় লিখুন, না থাকলে খালি রাখুন।',
  'Usual shipment costs': 'শিপমেন্টের নিয়মিত খরচ',
  'Filled in when one is added to a shipment':
      'শিপমেন্টে খরচ যোগ করার সময় আগে থেকে বসে যায়',
  'Not set': 'ঠিক করা নেই',
  // Shared flow parts.
  'Local transport': 'লোকাল ট্রান্সপোর্ট',
  'Costs done': 'খরচ সম্পূর্ণ',
  'Costs not due yet': 'খরচের সময় হয়নি',
  '{done} of {total} costs': '{total}টির {done}টি খরচ',
  'We pay': 'আমরা দিই',
  'We pay {ours}, flyers pay {flyers}':
      'আমরা দিই {ours}, ফ্লায়াররা দেন {flyers}',
  'Adds up to the {amount} ticket': '{amount} টিকিটের সাথে মিলে গেছে',
};

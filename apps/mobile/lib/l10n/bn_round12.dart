/// Round 12: notifications, Track on the map, hub sorting per customer,
/// admin approval and delivery partners.
const bnRound12 = <String, String>{
  // Notification text, built in the app from the event's facts.
  ' at {time}': ' {time}-এ',
  'today': 'আজ',
  'tomorrow': 'আগামীকাল',
  'in {n} days': '{n} দিন পর',
  'flyer {names}': 'ফ্লায়ার {names}',
  'New flight {flight}. Lands in Dhaka {date}{at}, {when}.':
      'নতুন ফ্লাইট {flight}। ঢাকায় নামবে {date}{at}, {when}।',
  '{flight} now lands in Dhaka {date}{at}.':
      '{flight} এখন ঢাকায় নামবে {date}{at}।',
  '{flight} lands today{at}. {orders}.': '{flight} আজ{at} নামবে। {orders}।',
  '{flight} lands tomorrow{at}. {orders}.':
      '{flight} আগামীকাল{at} নামবে। {orders}।',
  '{flight} has left{at}.': '{flight}{at} ছেড়েছে।',
  '{flight} left {from}{at}.': '{flight} {from} থেকে{at} ছেড়েছে।',
  'Lands in Dhaka{at}.': 'ঢাকায় নামবে{at}।',
  '{flight} lands in about 1 hour{at}.':
      '{flight} প্রায় ১ ঘণ্টার মধ্যে নামবে{at}।',
  '{flight} landed in Dhaka{at}. {orders} to receive.':
      '{flight} ঢাকায় নেমেছে{at}। {orders} গ্রহণ করতে হবে।',
  'The airline cancelled {flight} on {date}. Nothing was changed here.':
      'এয়ারলাইন {date} তারিখের {flight} বাতিল করেছে। এখানে কিছু বদলানো হয়নি।',
  '{flight} was due on {date}. The airline has no update. Confirm what happened.':
      '{flight} আসার কথা ছিল {date}। এয়ারলাইন থেকে আপডেট নেই। কী হয়েছে নিশ্চিত করুন।',
  '{by} received {orders} from {flight} at the Dhaka hub.':
      '{by} ঢাকা হাবে {flight} থেকে {orders} গ্রহণ করেছেন।',
  '{by} sorted {customer} from {flight}: {orders}, {kg} kg. Waiting for approval.':
      '{by} {flight} থেকে {customer} সর্ট করেছেন: {orders}, {kg} kg। অ্যাপ্রুভের অপেক্ষায়।',
  '{customer} from {flight} sent back by {by}: {note}':
      '{flight} থেকে {customer} ফেরত পাঠিয়েছেন {by}: {note}',
  '{customer} from {flight} approved. {orders} ready for pickup at the hub.':
      '{flight} থেকে {customer} অ্যাপ্রুভ হয়েছে। {orders} হাবে পিকআপের জন্য তৈরি।',
  '{customer} from {flight} approved. {orders} In delivery with {partner}.':
      '{flight} থেকে {customer} অ্যাপ্রুভ হয়েছে। {orders} {partner}-এর সাথে ডেলিভারিতে।',
  '{by} confirmed {orders} of {customer} from {flight} delivered.':
      '{by} নিশ্চিত করেছেন, {flight} থেকে {customer}-এর {orders} ডেলিভারি হয়েছে।',
  '{order} has a problem ({type}): {reason}':
      '{order}-এ সমস্যা ({type}): {reason}',
  '{n} orders are In transit.': '{n}টি অর্ডার এখন পথে আছে।',
  'on hold': 'আটকে আছে',
  'delivery failed': 'ডেলিভারি হয়নি',
  'lost': 'হারিয়ে গেছে',
  'returned': 'ফেরত গেছে',
  'cancelled': 'বাতিল',

  // The bell and the list.
  'Notifications': 'নোটিফিকেশন',
  'All read': 'সব পড়া হয়েছে',
  '{n} unread': '{n}টি পড়া হয়নি',
  'Mark all read': 'সব পড়েছি',
  'No notifications yet': 'এখনো কোনো নোটিফিকেশন নেই',
  'New flights, landings and sorting steps show up here.':
      'নতুন ফ্লাইট, ল্যান্ডিং আর সর্টিংয়ের ধাপ এখানে দেখা যাবে।',
  '{n} unread notifications': '{n}টি নোটিফিকেশন পড়া হয়নি',

  // Sort states.
  'Not received': 'গ্রহণ হয়নি',
  'To sort': 'সর্ট বাকি',
  'Sent back': 'ফেরত এসেছে',
  'Waiting for admin': 'অ্যাডমিনের অপেক্ষায়',
  'In delivery': 'ডেলিভারিতে',
  'Ready for pickup': 'পিকআপের জন্য তৈরি',
  'Problem': 'সমস্যা',
  'Waiting for approval': 'অ্যাপ্রুভের অপেক্ষায়',

  // Hub flight page.
  'They move to Received at BD Hub with your name and photo. Sorting comes next.':
      'আপনার নাম ও ছবিসহ এগুলো ঢাকা হাবে গ্রহণ হয়েছে হিসেবে যাবে। এরপর সর্ট করতে হবে।',
  'Sort by customer': 'কাস্টমার ধরে সর্ট করুন',
  'Coming on this flight': 'এই ফ্লাইটে আসছে',
  'Once customs clears them, receive the orders here. Sorting comes next.':
      'কাস্টমস ক্লিয়ার হলে এখানে অর্ডারগুলো গ্রহণ করুন। এরপর সর্ট করতে হবে।',
  'Carried by {name}': 'নিয়ে আসছেন {name}',
  'Device photos': 'ডিভাইসের ছবি',
  'Track this flight': 'ফ্লাইট ট্র্যাক করুন',

  // Track.
  'Where is {flight} now': '{flight} এখন কোথায়',
  'This flight is not in the air': 'ফ্লাইটটি এখন আকাশে নেই',
  'The map shows the plane while it is flying. Check the flight page for times.':
      'প্লেন উড়ন্ত অবস্থায় থাকলে ম্যাপে দেখা যায়। সময় দেখতে ফ্লাইটের পেজ খুলুন।',
  'The airline has no position for this flight right now. Try again later.':
      'এই মুহূর্তে এয়ারলাইনের কাছে ফ্লাইটটির অবস্থান নেই। পরে আবার চেষ্টা করুন।',
  'Sample position. Add the flight data key on the server for live positions.':
      'এটি নমুনা অবস্থান। আসল অবস্থানের জন্য সার্ভারে ফ্লাইট ডেটা কি যোগ করুন।',
  '{route}, via {stops}': '{route}, {stops} হয়ে',
  'Plane': 'প্লেন',
  'Height': 'উচ্চতা',
  '{n} m': '{n} মি',
  'Speed': 'গতি',
  '{n} km/h': '{n} কিমি/ঘণ্টা',
  'Position from the airline feed · {time}':
      'এয়ারলাইনের তথ্য থেকে অবস্থান · {time}',
  'No refreshes left today': 'আজ আর রিফ্রেশ বাকি নেই',
  'Refresh now': 'এখন রিফ্রেশ করুন',
  'Refresh again at {time}': '{time}-এ আবার রিফ্রেশ করা যাবে',
  'Live refresh once every 15 min · {left} of {total} left today':
      'প্রতি ১৫ মিনিটে একবার রিফ্রেশ · আজ {total}টির মধ্যে {left}টি বাকি',

  // Hub home.
  'To do today': 'আজকের কাজ',
  'Nothing to do right now': 'এখন কোনো কাজ নেই',
  'Work shows up here when a flight is received or the admin sends a customer back.':
      'ফ্লাইট গ্রহণ হলে বা অ্যাডমিন কোনো কাস্টমার ফেরত পাঠালে কাজ এখানে আসবে।',
  'Fix and send again': 'ঠিক করে আবার পাঠান',
  '{customers} · {flight} · sent back by the admin':
      '{customers} · {flight} · অ্যাডমিন ফেরত পাঠিয়েছেন',
  'Sort {flight}': '{flight} সর্ট করুন',
  'Waiting for admin · {flight}': 'অ্যাডমিনের অপেক্ষায় · {flight}',
  'In delivery · {flight}': 'ডেলিভারিতে · {flight}',
  'Confirm each one when the customer has it':
      'কাস্টমার পেলে প্রতিটি নিশ্চিত করুন',
  'Next flight · {flight}': 'পরবর্তী ফ্লাইট · {flight}',
  'Track': 'ট্র্যাক করুন',
  'Open flight': 'ফ্লাইট খুলুন',
  '{n} customers': '{n} জন কাস্টমার',

  // More and the admin home.
  'Delivery partners': 'ডেলিভারি পার্টনার',
  'Couriers the hub picks from when it sorts':
      'সর্ট করার সময় হাব যেসব কুরিয়ার থেকে বেছে নেয়',
  'Customers the hub sorted': 'হাব যেসব কাস্টমার সর্ট করেছে',
  '{n} customers sorted by the hub': 'হাব {n} জন কাস্টমার সর্ট করেছে',

  // Delivery partners.
  '{name} is already on the list': '{name} আগে থেকেই তালিকায় আছে',
  'Remove {name}?': '{name} সরাবেন?',
  'The hub will not see it when sorting. Orders already booked with it keep it.':
      'সর্ট করার সময় হাব এটি আর দেখবে না। যেসব অর্ডারে আগে থেকে বুক করা আছে, সেগুলোতে থাকবে।',
  'The hub picks one of these when it sorts a customer.':
      'কাস্টমার সর্ট করার সময় হাব এগুলোর একটি বেছে নেয়।',
  'Customer collects at the hub': 'কাস্টমার হাব থেকে নিয়ে যান',
  'Always on': 'সবসময় চালু',
  'Add a partner': 'পার্টনার যোগ করুন',
  'e.g. eCourier': 'যেমন eCourier',
  'Add partner': 'পার্টনার যোগ করুন',
  'Drag to reorder': 'টেনে ক্রম বদলান',

  // Hub order page.
  'The admin handles this order': 'এই অর্ডারটি অ্যাডমিন দেখবেন',
  'It is not on a flight, so it is not sorted at the hub.':
      'এটি কোনো ফ্লাইটে নেই, তাই হাবে সর্ট হবে না।',
  "Weight, packing and courier are done with the customer's other orders when you sort the flight.":
      'ফ্লাইট সর্ট করার সময় একই কাস্টমারের অন্য অর্ডারের সাথে ওজন, প্যাকিং ও কুরিয়ার ঠিক করা হয়।',
  'Open sorting': 'সর্টিং খুলুন',

  // Waiting for approval.
  'Courier orders go In delivery and Hub pickup orders become ready for pickup. The hub gets a notification for each.':
      'কুরিয়ারের অর্ডার ডেলিভারিতে যাবে, হাব পিকআপের অর্ডার পিকআপের জন্য তৈরি হবে। প্রতিটির জন্য হাব নোটিফিকেশন পাবে।',
  'Approve all': 'সব অ্যাপ্রুভ করুন',
  'Nothing waiting': 'কিছু অপেক্ষায় নেই',
  'When the hub sorts a customer, it shows up here for you to check.':
      'হাব কোনো কাস্টমার সর্ট করলে আপনার দেখার জন্য এখানে আসবে।',
  'Approve all works when no customer needs a look. {names} weighs more or less than booked.':
      'কোনো কাস্টমার দেখার দরকার না থাকলে সব অ্যাপ্রুভ করা যায়। {names}-এর ওজন বুকিংয়ের চেয়ে কম বা বেশি।',
  'No partner': 'পার্টনার নেই',
  '{diff}, check': '{diff}, দেখে নিন',
  'sorted {when}': 'সর্ট {when}',
  '{booked} booked · {measured} measured': 'বুকিং {booked} · মাপা {measured}',
  'Approve {n} customers?': '{n} জন কাস্টমার অ্যাপ্রুভ করবেন?',
  '{n} orders approved': '{n}টি অর্ডার অ্যাপ্রুভ হয়েছে',
  '{n} customers sorted': '{n} জন কাস্টমার সর্ট হয়েছে',
  '{n} customers sorted by {by}': '{by} {n} জন কাস্টমার সর্ট করেছেন',

  // Checking one customer.
  'Approved. Ready for pickup at the hub.':
      'অ্যাপ্রুভ হয়েছে। হাবে পিকআপের জন্য তৈরি।',
  'Approved. In delivery with {partner}.':
      'অ্যাপ্রুভ হয়েছে। {partner}-এর সাথে ডেলিভারিতে।',
  'Sent back to the hub': 'হাবে ফেরত পাঠানো হয়েছে',
  'Send back': 'ফেরত পাঠান',
  'Approve makes the orders ready for pickup and tells the hub.':
      'অ্যাপ্রুভ করলে অর্ডারগুলো পিকআপের জন্য তৈরি হবে এবং হাব জানবে।',
  'Approve moves the orders to In delivery and tells the hub.':
      'অ্যাপ্রুভ করলে অর্ডারগুলো ডেলিভারিতে যাবে এবং হাব জানবে।',
  'Customer not on this flight': 'এই কাস্টমার এই ফ্লাইটে নেই',
  'Go back and open the flight again.': 'ফিরে গিয়ে ফ্লাইটটি আবার খুলুন।',
  'Approved': 'অ্যাপ্রুভ হয়েছে',
  'Approved by {by} at {time}': '{by} {time}-এ অ্যাপ্রুভ করেছেন',
  'Sorted by {name}': 'সর্ট করেছেন {name}',
  'Dhaka hub · {when}': 'ঢাকা হাব · {when}',
  '{kg} measured': 'মাপা {kg}',
  '{bill} · due {due}': '{bill} · বাকি {due}',
  'Partner': 'পার্টনার',
  'Not picked': 'বাছা হয়নি',
  'Courier ID': 'কুরিয়ার আইডি',
  'Packages': 'প্যাকেজ',
  'Deliver to': 'ডেলিভারির ঠিকানা',
  'Notes': 'নোট',
  'Packing photos': 'প্যাকিংয়ের ছবি',
  'Booked': 'বুকিং',
  'Measured': 'মাপা',
  'Bill was {amount} at the booked weight': 'বুকিংয়ের ওজনে বিল ছিল {amount}',
  'Bill unchanged': 'বিল বদলায়নি',
  'Photos of the goods': 'মালের ছবি',
  'Send back to the hub?': 'হাবে ফেরত পাঠাবেন?',
  'Weight looks wrong': 'ওজন ঠিক মনে হচ্ছে না',
  'Photo missing': 'ছবি নেই',
  'Wrong partner': 'ভুল পার্টনার',
  'What needs fixing?': 'কী ঠিক করতে হবে?',
  'e.g. SH-42 needs a photo with the carton open.':
      'যেমন SH-42 এর কার্টন খোলা অবস্থায় ছবি লাগবে।',
  'The hub gets this note. The orders stay at the hub until they are sent again.':
      'হাব এই নোট পাবে। আবার পাঠানো পর্যন্ত অর্ডারগুলো হাবেই থাকবে।',

  // Sorting one customer.
  'Pick the delivery partner': 'ডেলিভারি পার্টনার বেছে নিন',
  'Fill in the weight and what arrived for each order':
      'প্রতিটি অর্ডারের ওজন আর কী এসেছে লিখুন',
  'Wait for the photos to finish': 'ছবি আপলোড শেষ হওয়া পর্যন্ত অপেক্ষা করুন',
  'Sent to the admin': 'অ্যাডমিনের কাছে পাঠানো হয়েছে',
  'Courier ID saved': 'কুরিয়ার আইডি সেভ হয়েছে',
  'Delivery confirmed': 'ডেলিভারি নিশ্চিত হয়েছে',
  'Sort · {who}': 'সর্ট · {who}',
  'Send to admin': 'অ্যাডমিনের কাছে পাঠান',
  'Admin checks the weight and photos before it goes out.':
      'পাঠানোর আগে অ্যাডমিন ওজন আর ছবি দেখে নেবেন।',
  'Confirm delivered': 'ডেলিভারি নিশ্চিত করুন',
  'Write who received it. The admin gets a notification.':
      'কে বুঝে নিয়েছেন লিখুন। অ্যাডমিন নোটিফিকেশন পাবেন।',
  'Sent back by {by}': '{by} ফেরত পাঠিয়েছেন',
  'the admin': 'অ্যাডমিন',
  'Has a problem. Open the order to see it.':
      'সমস্যা আছে। দেখতে অর্ডারটি খুলুন।',
  'Not at the hub yet. Sort it when it arrives.':
      'এখনো হাবে আসেনি। এলে সর্ট করুন।',
  'for both orders': 'দুটি অর্ডারের জন্য',
  'for all {n} orders': '{n}টি অর্ডারের জন্য',
  'After packing': 'প্যাক করার পর',
  'Delivery partner': 'ডেলিভারি পার্টনার',
  'No delivery partners yet. Ask the admin to add them in Settings.':
      'এখনো কোনো ডেলিভারি পার্টনার নেই। অ্যাডমিনকে সেটিংসে যোগ করতে বলুন।',
  'Add now or after booking': 'এখন বা বুক করার পর যোগ করুন',
  'Optional. You can add it until the order is delivered.':
      'ঐচ্ছিক। ডেলিভারি হওয়া পর্যন্ত যোগ করা যাবে।',
  'e.g. Customer asked for delivery after 5 pm.':
      'যেমন কাস্টমার বিকেল ৫টার পর ডেলিভারি চেয়েছেন।',
  'Sent {when}. You get a notification when the admin approves it or sends it back.':
      'পাঠানো হয়েছে {when}। অ্যাডমিন অ্যাপ্রুভ করলে বা ফেরত পাঠালে নোটিফিকেশন পাবেন।',
  '{orders} ready for pickup at the hub. Confirm when the customer collects them.':
      '{orders} হাবে পিকআপের জন্য তৈরি। কাস্টমার নিয়ে গেলে নিশ্চিত করুন।',
  '{orders} In delivery with {partner}. Add the courier ID when you have it.':
      '{orders} {partner}-এর সাথে ডেলিভারিতে। কুরিয়ার আইডি পেলে যোগ করুন।',
  'The customer has these orders.': 'কাস্টমার অর্ডারগুলো পেয়েছেন।',
  'An order has a problem': 'একটি অর্ডারে সমস্যা আছে',
  'Open the order to see what happened.': 'কী হয়েছে দেখতে অর্ডারটি খুলুন।',
  'Not received yet': 'এখনো গ্রহণ হয়নি',
  'Receive the flight first, then sort this customer.':
      'আগে ফ্লাইট গ্রহণ করুন, তারপর এই কাস্টমার সর্ট করুন।',
  'No partner yet': 'এখনো পার্টনার নেই',
  'At the hub': 'হাবে আছে',
  'Enter the weight': 'ওজন লিখুন',
  'What arrived': 'কী এসেছে',
  'e.g. 3 cartons of ladies kurtis': 'যেমন মেয়েদের কুর্তির ৩টি কার্টন',
  'Write what arrived': 'কী এসেছে লিখুন',
  'Who received it?': 'কে বুঝে নিয়েছেন?',
  'e.g. Received by the owner at the shop': 'যেমন দোকানে মালিক বুঝে নিয়েছেন',

  // A flight's customers.
  '{day} · received': '{day} · গ্রহণ হয়েছে',
  'Received at the Dhaka hub': 'ঢাকা হাবে গ্রহণ হয়েছে',
  '{kg} booked': 'বুকিং {kg}',
  'Same as booked': 'বুকিংয়ের সমান',
  '{kg} kg more than booked': 'বুকিংয়ের চেয়ে {kg} kg বেশি',
  '{kg} kg less than booked': 'বুকিংয়ের চেয়ে {kg} kg কম',
  'Same': 'সমান',
  '{kg} kg more': '{kg} kg বেশি',
  '{kg} kg less': '{kg} kg কম',
  'yesterday {time}': 'গতকাল {time}',
};

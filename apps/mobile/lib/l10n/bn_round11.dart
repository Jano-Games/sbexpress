/// Round 11: flight status from the airline, Confirm status and the Status
/// choice in Edit flight.
const bnRound11 = <String, String>{
  // How late or early.
  'on time': 'সময়মতো',
  '{n} min late': '{n} মিনিট দেরিতে',
  '{h} h late': '{h} ঘণ্টা দেরিতে',
  '{h} h {m} min late': '{h} ঘণ্টা {m} মিনিট দেরিতে',
  '{n} min early': '{n} মিনিট আগে',
  '{h} h early': '{h} ঘণ্টা আগে',
  '{h} h {m} min early': '{h} ঘণ্টা {m} মিনিট আগে',

  // Status pills and the line under each flight.
  'Landed {time}': 'নেমেছে {time}',
  'Landed {late}': '{late} নেমেছে',
  'Lands {late}': '{late} নামবে',
  'from the airline': 'এয়ারলাইন থেকে',
  'Left {time}': 'ছেড়েছে {time}',
  'lands {time}, {late}': 'নামবে {time}, {late}',
  'lands {time}': 'নামবে {time}',
  'Left, planned {time}': 'ছেড়েছে, নির্ধারিত ছিল {time}',
  'Left on time': 'সময়মতো ছেড়েছে',
  'Cancelled by airline': 'এয়ারলাইন বাতিল করেছে',
  'Nothing changed here. Move it to the new date.':
      'এখানে কিছু বদলায়নি। নতুন তারিখে সরিয়ে দিন।',
  'Date has passed': 'তারিখ পার হয়েছে',
  'No update from the airline. Confirm what happened.':
      'এয়ারলাইন থেকে আপডেট নেই। কী হয়েছে নিশ্চিত করুন।',
  'Leaves {time}, {late}': 'ছাড়বে {time}, {late}',
  'Leaves {time}': 'ছাড়বে {time}',
  'Confirm status': 'স্ট্যাটাস নিশ্চিত করুন',
  'Change date': 'তারিখ বদলান',

  // Banners on the flight page.
  'What happened to this flight?': 'এই ফ্লাইটের কী হয়েছে?',
  'The date is over and the status was not updated. Tell us, so the orders and the hub stay right.':
      'তারিখ পার হয়ে গেছে, কিন্তু স্ট্যাটাস আপডেট হয়নি। জানিয়ে দিন, যাতে অর্ডার আর হাবের তথ্য ঠিক থাকে।',
  'The date is over and the airline has no update for {code}. Tell us, so the orders and the hub stay right.':
      'তারিখ পার হয়ে গেছে, আর এয়ারলাইনের কাছে {code} নিয়ে কোনো আপডেট নেই। জানিয়ে দিন, যাতে অর্ডার আর হাবের তথ্য ঠিক থাকে।',
  'The date is over and the airline has not said that {code} left. Tell us, so the orders and the hub stay right.':
      'তারিখ পার হয়ে গেছে, কিন্তু এয়ারলাইন বলেনি যে {code} ছেড়েছে। জানিয়ে দিন, যাতে অর্ডার আর হাবের তথ্য ঠিক থাকে।',
  'The airline cancelled {code} on {date}':
      'এয়ারলাইন {date} তারিখের {code} বাতিল করেছে',
  'Nothing was changed here. The orders and the flyer are still on this flight. Move it to the new date, or confirm it flew.':
      'এখানে কিছুই বদলানো হয়নি। অর্ডার আর ফ্লায়ার এখনও এই ফ্লাইটেই আছে। নতুন তারিখে সরান, অথবা উড়েছে কিনা নিশ্চিত করুন।',
  'Flight saved · {n} orders moved to In transit':
      'ফ্লাইট সেভ হয়েছে · {n}টি অর্ডার "পথে আছে" হয়েছে',

  // Flight tracking card.
  'Flight tracking': 'ফ্লাইট ট্র্যাকিং',
  'Checked {time}': 'চেক {time}',
  '{from} to {to}': '{from} থেকে {to}',
  'In the air': 'আকাশে',
  'Not left yet': 'এখনও ছাড়েনি',
  'No data': 'তথ্য নেই',
  'Left {dep} · landed {arr}': 'ছেড়েছে {dep} · নেমেছে {arr}',
  'Left {time}, planned {planned}': 'ছেড়েছে {time}, নির্ধারিত ছিল {planned}',
  'Airline status: cancelled': 'এয়ারলাইনের স্ট্যাটাস: বাতিল',
  'No data from the airline for this day':
      'এই দিনের কোনো তথ্য এয়ারলাইনের কাছে নেই',
  'Updated from the airline by itself. Next check soon after it lands. You can still change the status in Edit.':
      'এয়ারলাইন থেকে নিজে নিজে আপডেট হয়। পরের চেক নামার কিছুক্ষণ পর। এডিটে গিয়ে স্ট্যাটাস এখনও বদলাতে পারবেন।',
  'Updated from the airline by itself. Next check soon after it takes off. You can still change the status in Edit.':
      'এয়ারলাইন থেকে নিজে নিজে আপডেট হয়। পরের চেক ওড়ার কিছুক্ষণ পর। এডিটে গিয়ে স্ট্যাটাস এখনও বদলাতে পারবেন।',
  'Updated from the airline by itself. You can still change the status in Edit.':
      'এয়ারলাইন থেকে নিজে নিজে আপডেট হয়। এডিটে গিয়ে স্ট্যাটাস এখনও বদলাতে পারবেন।',

  // Orders that moved, and the ones that did not.
  '{n} orders moved to In transit': '{n}টি অর্ডার "পথে আছে" হয়েছে',
  '{n} orders moved to In transit.': '{n}টি অর্ডার "পথে আছে" হয়েছে।',
  'They moved when the flight left at {time}.':
      'ফ্লাইট {time}-এ ছাড়ার সময় এগুলো সরেছে।',
  'They moved when the airline said the flight left.':
      'এয়ারলাইন যখন জানাল ফ্লাইট ছেড়েছে, তখন এগুলো সরেছে।',
  'They moved when {name} set the flight as left.':
      '{name} ফ্লাইটকে "উড়েছে" করার সময় এগুলো সরেছে।',
  '{code} did not move': '{code} সরেনি',
  '{n} orders did not move': '{n}টি অর্ডার সরেনি',
  'Open each one to check if it is on this flight: {codes}.':
      'প্রতিটি খুলে দেখুন এই ফ্লাইটে আছে কিনা: {codes}।',
  'It was not at the China hub yet. Check if it is on this flight.':
      'এটা তখনও চায়না হাবে পৌঁছায়নি। এটা এই ফ্লাইটে আছে কিনা দেখুন।',
  'It was still at the China hub, not ready for shipment. Check if it is on this flight.':
      'এটা তখনও চায়না হাবে ছিল, পাঠানোর জন্য প্রস্তুত ছিল না। এটা এই ফ্লাইটে আছে কিনা দেখুন।',
  'It has no carrying flyer. Pick the flyer on the order to move it.':
      'এটার কোনো বহনকারী ফ্লায়ার নেই। সরাতে অর্ডারে ফ্লায়ার বেছে নিন।',
  'It has a problem to sort out first. Open the order.':
      'আগে এটার একটা সমস্যা মেটাতে হবে। অর্ডারটি খুলুন।',
  'It is ready for shipment but did not move. Open the order to move it.':
      'এটা পাঠানোর জন্য প্রস্তুত, কিন্তু সরেনি। সরাতে অর্ডারটি খুলুন।',

  // Confirm status sheet.
  'What happened to {code}?': '{code} ফ্লাইটের কী হয়েছে?',
  'Planned {when}': 'নির্ধারিত ছিল {when}',
  '{time} from {place}': '{place} থেকে {time}',
  'It flew, on the way': 'উড়েছে, পথে আছে',
  'It landed': 'নেমে গেছে',
  'It flies on another day': 'অন্য দিন উড়বে',
  'Status becomes Departed.': 'স্ট্যাটাস হবে "উড়েছে"।',
  'Status becomes Departed. Orders ready for shipment move to In transit.':
      'স্ট্যাটাস হবে "উড়েছে"। পাঠানোর জন্য প্রস্তুত অর্ডারগুলো "পথে আছে" হয়ে যাবে।',
  'Status becomes Departed. The {n} orders ready for shipment move to In transit.':
      'স্ট্যাটাস হবে "উড়েছে"। পাঠানোর জন্য প্রস্তুত {n}টি অর্ডার "পথে আছে" হয়ে যাবে।',
  'Status becomes Landed. The hub receives the orders after customs.':
      'স্ট্যাটাস হবে "নেমেছে"। কাস্টমসের পর হাব অর্ডারগুলো গ্রহণ করবে।',
  'Status becomes Landed. The {n} orders ready for shipment move to In transit; the hub receives them after customs.':
      'স্ট্যাটাস হবে "নেমেছে"। পাঠানোর জন্য প্রস্তুত {n}টি অর্ডার "পথে আছে" হবে; কাস্টমসের পর হাব সেগুলো গ্রহণ করবে।',
  'Opens Edit flight to change the date. Nothing else changes.':
      'তারিখ বদলাতে ফ্লাইট এডিট খুলবে। আর কিছু বদলাবে না।',
  'Your name goes on this change. If the airline sends an update later, it can only move the flight forward.':
      'এই পরিবর্তনে আপনার নাম থাকবে। পরে এয়ারলাইন আপডেট দিলে ফ্লাইট শুধু সামনের ধাপে যেতে পারবে।',
  '{code} has landed.': '{code} নেমেছে।',
  '{code} is on the way.': '{code} পথে আছে।',

  // Status in Edit flight.
  'Moved from {date}. The orders and the flyer stay on this flight.':
      '{date} থেকে সরানো হয়েছে। অর্ডার আর ফ্লায়ার এই ফ্লাইটেই থাকবে।',
  'Set by itself from the airline. Change it here if it is wrong.':
      'এয়ারলাইন থেকে নিজে নিজে বসে। ভুল হলে এখানে বদলান।',
  'Change it here if it is wrong.': 'ভুল হলে এখানে বদলান।',
  'Not checked with the airline yet. It is checked soon after take-off and after landing.':
      'এখনও এয়ারলাইনের সাথে চেক হয়নি। ওড়ার কিছুক্ষণ পর আর নামার পর চেক হয়।',
  'Last airline check: no data for {date}. On the new date it is checked again after take-off and after landing.':
      'শেষ এয়ারলাইন চেক: {date} তারিখের কোনো তথ্য নেই। নতুন তারিখে ওড়ার পর আর নামার পর আবার চেক হবে।',
  'On the new date it is checked with the airline again after take-off and after landing.':
      'নতুন তারিখে ওড়ার পর আর নামার পর আবার এয়ারলাইনের সাথে চেক হবে।',
  'Last airline check {time}: no data for {date}.':
      'শেষ এয়ারলাইন চেক {time}: {date} তারিখের কোনো তথ্য নেই।',
  'Last airline check {time}: the airline cancelled it.':
      'শেষ এয়ারলাইন চেক {time}: এয়ারলাইন বাতিল করেছে।',
  'Last airline check {time}: landed {arr}.':
      'শেষ এয়ারলাইন চেক {time}: নেমেছে {arr}।',
  'Last airline check {time}: on the way.': 'শেষ এয়ারলাইন চেক {time}: পথে আছে।',
  'Last airline check {time}: on the way, lands {arr}.':
      'শেষ এয়ারলাইন চেক {time}: পথে আছে, নামবে {arr}।',
  'Last airline check {time}: not left yet.':
      'শেষ এয়ারলাইন চেক {time}: এখনও ছাড়েনি।',
  'Departed or Landed moves the orders ready for shipment to In transit. The hub receives them after customs.':
      '"উড়েছে" বা "নেমেছে" দিলে পাঠানোর জন্য প্রস্তুত অর্ডারগুলো "পথে আছে" হয়ে যায়। কাস্টমসের পর হাব সেগুলো গ্রহণ করে।',

  // Hub.
  'The airline cancelled it. The admin sets the new date.':
      'এয়ারলাইন বাতিল করেছে। নতুন তারিখ অ্যাডমিন ঠিক করবেন।',
  'Lands in {place}': '{place} পৌঁছাবে',
  'Landed in {place}': '{place} পৌঁছেছে',
  'Planned {time}': 'নির্ধারিত {time}',
  'left {place} {time}': '{place} ছেড়েছে {time}',
  'From the airline · checked {time}': 'এয়ারলাইন থেকে · চেক {time}',
};

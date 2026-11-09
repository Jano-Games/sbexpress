/// The owner's ninth round: flight times on a new flight, connections,
/// airline schedule lookup, the flyer list and Edit flight.
const bnRound9 = <String, String>{
  // Number, date and times.
  'e.g. BG305. A connection: join both with +, like MU5842+MU2035':
      'যেমন BG305। কানেকশন হলে দুটো + দিয়ে লিখুন, যেমন MU5842+MU2035',
  '"{number}" is not a flight number. Write it like BG305.':
      '"{number}" কোনো ফ্লাইট নম্বর না। BG305 এর মতো লিখুন।',
  '{n} flights, one ticket': '{n}টি ফ্লাইট, একটি টিকিট',
  'Date': 'তারিখ',
  'Lands': 'নামবে',
  'Required': 'দিতে হবে',
  'Pick a time': 'সময় বাছুন',
  'Use 24-hour time, 09:40': '২৪ ঘণ্টার সময় দিন, 09:40',
  'Choose the departure time.': 'ছাড়ার সময় দিন।',
  'Write the departure time like 09:40.': 'ছাড়ার সময় 09:40 এর মতো লিখুন।',
  'Choose the landing time.': 'নামার সময় দিন।',
  'Write the landing time like 17:25.': 'নামার সময় 17:25 এর মতো লিখুন।',
  'Local time at each airport.': 'প্রতিটি এয়ারপোর্টের স্থানীয় সময়।',
  'Local time at each airport: when the first flight leaves and the last one lands.':
      'প্রতিটি এয়ারপোর্টের স্থানীয় সময়: প্রথম ফ্লাইট কখন ছাড়বে আর শেষটা কখন নামবে।',
  'Changes planes at (optional)': 'কোথায় প্লেন বদল (না দিলেও চলবে)',
  'Shows on the flight as "via Shanghai". For two stops, put a comma between them.':
      'ফ্লাইটে "Shanghai হয়ে" দেখাবে। দুটো স্টপ হলে মাঝে কমা দিন।',
  'Connection': 'কানেকশন',

  // Airline schedule lookup.
  'Times from the airline schedule': 'এয়ারলাইনের শিডিউল থেকে সময়',
  'Tap Find times to fill them in from the number and date.':
      'নম্বর আর তারিখ থেকে সময় বসাতে "সময় খুঁজুন" চাপুন।',
  'Enter the flight number and date to look up the times.':
      'সময় খুঁজতে ফ্লাইট নম্বর আর তারিখ দিন।',
  'Looking up {number}': '{number} খোঁজা হচ্ছে',
  'Checking the airline schedule.': 'এয়ারলাইনের শিডিউল দেখা হচ্ছে।',
  'Found on the airline schedule': 'এয়ারলাইনের শিডিউলে পাওয়া গেছে',
  'The times are filled in. Check them before you save.':
      'সময় বসানো হয়েছে। সেভ করার আগে মিলিয়ে নিন।',
  'Your times are different from the schedule.':
      'আপনার দেওয়া সময় শিডিউলের সাথে মিলছে না।',
  'Not on the schedule: {list}': 'শিডিউলে নেই: {list}',
  'Check the number and date, or type the times yourself.':
      'নম্বর আর তারিখ দেখুন, অথবা নিজে সময় লিখুন।',
  'Automatic times are not set up': 'অটো সময় এখনো চালু হয়নি',
  'The server has no flight data key yet. Type the times yourself.':
      'সার্ভারে এখনো ফ্লাইট ডেটার কী নেই। নিজে সময় লিখুন।',
  'Could not look up the times': 'সময় খোঁজা যায়নি',
  'The server needs an update to look up flight times.':
      'ফ্লাইটের সময় খুঁজতে সার্ভার আপডেট করা লাগবে।',
  'Find times': 'সময় খুঁজুন',
  'Use these times': 'এই সময় নিন',
  'Look again': 'আবার খুঁজুন',

  // Flyer list.
  'Choose flyers': 'ফ্লায়ার বাছুন',
  'Pick one or more for this ticket': 'এই টিকিটের জন্য এক বা একাধিক জন বাছুন',
  'No flyer matches "{query}".': '"{query}" এর সাথে কোনো ফ্লায়ার মেলেনি।',
  'Add a new flyer': 'নতুন ফ্লায়ার যোগ করুন',
  'Tap to choose': 'বাছতে চাপুন',
  'Done · {n} chosen': 'হয়ে গেছে · {n} জন বাছা হয়েছে',

  // Edit flight.
  'Edit flight': 'ফ্লাইট এডিট',
  '{flight} · {n} orders': '{flight} · {n}টি অর্ডার',
  'Enter 0 or more mobiles and laptops.': 'মোবাইল আর ল্যাপটপ ০ বা তার বেশি দিন।',
  '{kg} kg is booked, so the capacity cannot go below that.':
      '{kg} kg বুক হয়ে আছে, তাই ক্যাপাসিটি এর কম হবে না।',
  'The orders stay on this flight': 'অর্ডারগুলো এই ফ্লাইটেই থাকবে',
  "If you change the number or the date, the flight's reference changes with it. Flyers and the ticket money are changed in Ticket and flyers.":
      'নম্বর বা তারিখ বদলালে ফ্লাইটের রেফারেন্সও বদলাবে। ফ্লায়ার আর টিকিটের টাকা "টিকিট ও ফ্লায়ার" থেকে বদলান।',
  'Flight saved': 'ফ্লাইট সেভ হয়েছে',
};

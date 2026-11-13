# Help guides (HELP-001): one source for web and mobile, English and Hindi.
# Facts come from docs/FEATURES.md and the backend code (see notes inline).
# Block kinds: 'p' paragraph, 'li' bullet (consecutive bullets form one list).

TOPICS = [
    ('start', 'Getting started', 'शुरुआत'),
    ('calculations', 'How Montra calculates', 'Montra हिसाब कैसे लगाता है'),
    ('statements', 'Statements and reconciliation', 'स्टेटमेंट और मिलान'),
    ('account', 'Privacy, security and limits', 'गोपनीयता, सुरक्षा और सीमाएँ'),
    ('troubleshooting', 'Troubleshooting', 'समस्या का समाधान'),
]

GUIDES = [
    {
        'id': 'gettingStarted',
        'topic': 'start',
        'title': ('Getting started without a bank link', 'बैंक जोड़े बिना शुरुआत करें'),
        'summary': (
            'Set up accounts, record or import what happens, and plan ahead. Montra never needs your bank login.',
            'खाते बनाएँ, लेन-देन दर्ज या आयात करें और आगे की योजना बनाएँ। Montra को कभी आपके बैंक लॉगिन की ज़रूरत नहीं होती।',
        ),
        'link': ('Add an account', 'खाता जोड़ें'),
        'sections': [
            ('how', ('How Montra works', 'Montra कैसे काम करता है'), [
                ('p', 'Montra doesn’t connect to your bank. You tell it what happens: you add your accounts, then record transactions as they happen or import a statement your bank gives you. Your numbers are “tracked”, not verified by a bank.',
                 'Montra आपके बैंक से नहीं जुड़ता। आप उसे बताते हैं कि क्या हुआ: पहले अपने खाते जोड़ें, फिर लेन-देन होते ही दर्ज करें या बैंक से मिला स्टेटमेंट आयात करें। आपकी रकम “ट्रैक की गई” है, बैंक से सत्यापित नहीं।'),
                ('p', 'The first-time setup is optional and you can skip any step after the welcome. Nothing in it asks for bank details.',
                 'पहली बार का सेटअप वैकल्पिक है और स्वागत के बाद कोई भी चरण छोड़ा जा सकता है। इसमें बैंक की कोई जानकारी नहीं माँगी जाती।'),
            ]),
            ('steps', ('First steps', 'पहले कदम'), [
                ('li', 'Add your accounts: cash, bank, savings, card, wallet, UPI, loan and more. Enter today’s balance as the opening balance (for a card or loan, what you owe).',
                 'अपने खाते जोड़ें: नकद, बैंक, बचत, कार्ड, वॉलेट, UPI, लोन और बहुत कुछ। आज की रकम को शुरुआती बैलेंस के रूप में दर्ज करें (कार्ड या लोन के लिए, जितना बकाया है)।'),
                ('li', 'Record expenses and income as they happen, and use a transfer when money moves between your own accounts.',
                 'खर्च और आमदनी होते ही दर्ज करें, और जब पैसा आपके अपने खातों के बीच जाए तो ट्रांसफ़र का इस्तेमाल करें।'),
                ('li', 'To bring in many transactions at once, import a statement file (CSV, XLSX, OFX or QFX). To keep a bill, add a photo of the receipt.',
                 'एक साथ कई लेन-देन लाने के लिए स्टेटमेंट फ़ाइल (CSV, XLSX, OFX या QFX) आयात करें। बिल रखने के लिए रसीद की फ़ोटो जोड़ें।'),
                ('li', 'Add salary, rent and other repeating money as recurring transactions or bills, so they show on the calendar before they’re due.',
                 'वेतन, किराया और दूसरी बार-बार होने वाली रकम को आवर्ती लेन-देन या बिल के रूप में जोड़ें, ताकि वे तय तारीख से पहले कैलेंडर पर दिखें।'),
                ('li', 'Then set a budget or a savings goal when you’re ready.',
                 'फिर जब आप तैयार हों, बजट या बचत का लक्ष्य बनाएँ।'),
            ]),
            ('accurate', ('Keeping it accurate', 'हिसाब सही रखना'), [
                ('p', 'Now and then, compare a balance with your bank app or statement. If it’s different, reconcile the account or record a balance adjustment with a reason; the adjustment keeps a history and never counts as income or spending.',
                 'समय-समय पर किसी बैलेंस की तुलना अपने बैंक ऐप या स्टेटमेंट से करें। अगर फ़र्क हो, तो खाते का मिलान करें या कारण के साथ बैलेंस समायोजन दर्ज करें; समायोजन का इतिहास रहता है और वह कभी आमदनी या खर्च में नहीं गिना जाता।'),
            ]),
        ],
    },
    {
        'id': 'noBank',
        'topic': 'start',
        'title': ('Why don’t I see my bank?', 'मुझे अपना बैंक क्यों नहीं दिखता?'),
        'summary': (
            'Montra can’t connect to any bank yet. Here’s why, and what to use instead.',
            'Montra अभी किसी बैंक से नहीं जुड़ सकता। जानिए क्यों, और इसके बदले क्या इस्तेमाल करें।',
        ),
        'link': ('See connected services', 'जुड़ी सेवाएँ देखें'),
        'sections': [
            ('today', ('No bank linking yet', 'अभी बैंक जोड़ना उपलब्ध नहीं'), [
                ('p', 'Montra doesn’t link to any bank today, so no bank appears in the list. The connected services page shows the one option being considered, Account Aggregator (India), as unavailable: it needs an approved partner, registration and a legal review first.',
                 'Montra आज किसी बैंक से नहीं जुड़ता, इसलिए सूची में कोई बैंक नहीं दिखता। जुड़ी सेवाओं वाले पेज पर विचाराधीन एकमात्र विकल्प, अकाउंट एग्रीगेटर (भारत), अनुपलब्ध दिखता है: इसके लिए पहले एक स्वीकृत साझेदार, पंजीकरण और कानूनी समीक्षा ज़रूरी है।'),
                ('p', 'It isn’t a setting you’ve missed, and it isn’t a paid feature. When a connection becomes available, it will appear on that page.',
                 'यह कोई छूटी हुई सेटिंग नहीं है, और न ही कोई सशुल्क सुविधा। जब कोई कनेक्शन उपलब्ध होगा, वह उसी पेज पर दिखेगा।'),
            ]),
            ('never', ('What Montra will never do', 'Montra क्या कभी नहीं करेगा'), [
                ('li', 'Ask for your bank password, PIN, card number or OTP.',
                 'आपका बैंक पासवर्ड, PIN, कार्ड नंबर या OTP माँगना।'),
                ('li', 'Read your SMS or notifications, or scrape your bank’s website.',
                 'आपके SMS या सूचनाएँ पढ़ना, या आपके बैंक की वेबसाइट से डेटा निकालना।'),
                ('li', 'Move money or make payments for you.',
                 'आपकी ओर से पैसा भेजना या भुगतान करना।'),
            ]),
            ('instead', ('What to use instead', 'इसके बदले क्या इस्तेमाल करें'), [
                ('li', 'Import the statement file your bank lets you download.',
                 'वह स्टेटमेंट फ़ाइल आयात करें जो आपका बैंक डाउनलोड करने देता है।'),
                ('li', 'Add receipts from photos, and turn them into transactions.',
                 'फ़ोटो से रसीदें जोड़ें और उन्हें लेन-देन में बदलें।'),
                ('li', 'Set up recurring transactions so regular income and bills record themselves.',
                 'आवर्ती लेन-देन सेट करें ताकि नियमित आमदनी और बिल अपने-आप दर्ज हों।'),
            ]),
        ],
    },
    {
        'id': 'balances',
        'topic': 'calculations',
        'title': ('How balances are calculated', 'बैलेंस का हिसाब कैसे होता है'),
        'summary': (
            'Opening balance plus every counted transaction, with transfers and adjustments kept apart from spending.',
            'शुरुआती बैलेंस और हर गिना गया लेन-देन, जिसमें ट्रांसफ़र और समायोजन खर्च से अलग रहते हैं।',
        ),
        'link': ('Go to accounts', 'खातों पर जाएँ'),
        'sections': [
            ('formula', ('The balance', 'बैलेंस'), [
                ('p', 'An account’s balance is its opening balance plus every posted and pending transaction in it. Drafts and deleted (voided) transactions don’t change it. Restoring a deleted transaction counts it again.',
                 'किसी खाते का बैलेंस उसका शुरुआती बैलेंस और उसमें हर पोस्ट किया गया और लंबित लेन-देन है। ड्राफ़्ट और हटाए गए (रद्द) लेन-देन इसे नहीं बदलते। हटाया गया लेन-देन वापस लाने पर वह फिर गिना जाता है।'),
                ('p', 'Credit cards and loans are money you owe, so spending on them increases what you owe.',
                 'क्रेडिट कार्ड और लोन वह रकम हैं जो आप पर बकाया है, इसलिए उन पर खर्च करने से बकाया बढ़ता है।'),
            ]),
            ('notSpending', ('What isn’t income or spending', 'क्या आमदनी या खर्च नहीं है'), [
                ('li', 'Transfers between your own accounts change both balances but are never income or spending. A transfer fee is recorded as its own expense.',
                 'आपके अपने खातों के बीच ट्रांसफ़र दोनों बैलेंस बदलते हैं, पर कभी आमदनी या खर्च नहीं होते। ट्रांसफ़र शुल्क एक अलग खर्च के रूप में दर्ज होता है।'),
                ('li', 'Balance adjustments correct a balance to match reality. They keep a history with your reason and never count as income or spending.',
                 'बैलेंस समायोजन बैलेंस को असलियत से मिलाते हैं। इनका इतिहास आपके कारण के साथ रहता है और ये कभी आमदनी या खर्च में नहीं गिने जाते।'),
                ('li', 'Refunds reduce spending instead of counting as income.',
                 'रिफ़ंड आमदनी में गिनने के बजाय खर्च घटाते हैं।'),
            ]),
            ('currencies', ('Several currencies', 'कई मुद्राएँ'), [
                ('p', 'Amounts in different currencies are never simply added together. Totals are shown per currency, unless you choose a display currency; then Montra converts them and tells you which rate it used.',
                 'अलग-अलग मुद्राओं की रकम कभी सीधे नहीं जोड़ी जाती। कुल रकम हर मुद्रा के लिए अलग दिखती है, जब तक आप कोई डिस्प्ले मुद्रा न चुनें; तब Montra उन्हें बदलता है और बताता है कि कौन-सी दर इस्तेमाल हुई।'),
                ('p', 'An account shared with you by your household is read-only for you, and its balance is the owner’s record.',
                 'आपके घर के किसी सदस्य द्वारा साझा किया गया खाता आपके लिए केवल पढ़ने योग्य है, और उसका बैलेंस मालिक का रिकॉर्ड है।'),
            ]),
        ],
    },
    {
        'id': 'budgets',
        'topic': 'calculations',
        'title': ('How budgets are calculated', 'बजट का हिसाब कैसे होता है'),
        'summary': (
            'What counts as spent, how pace and projections work, and how refunds and rollover change a budget.',
            'खर्च में क्या गिना जाता है, रफ़्तार और अनुमान कैसे काम करते हैं, और रिफ़ंड और रोलओवर बजट को कैसे बदलते हैं।',
        ),
        'link': ('Go to budgets', 'बजट पर जाएँ'),
        'sections': [
            ('spent', ('What counts as spent', 'खर्च में क्या गिना जाता है'), [
                ('p', 'A budget adds up the expenses in its period that match it: its accounts, categories and merchants, and only in the budget’s currency. Transactions in other currencies aren’t counted; the budget tells you how many were left out.',
                 'बजट अपनी अवधि के वे खर्च जोड़ता है जो उससे मेल खाते हैं: उसके खाते, श्रेणियाँ और व्यापारी, और केवल बजट की मुद्रा में। दूसरी मुद्राओं के लेन-देन नहीं गिने जाते; बजट बताता है कि कितने छोड़े गए।'),
                ('li', 'Transfers and balance adjustments never count.', 'ट्रांसफ़र और बैलेंस समायोजन कभी नहीं गिने जाते।'),
                ('li', 'Pending transactions count only if the budget includes pending.', 'लंबित लेन-देन तभी गिने जाते हैं जब बजट में लंबित शामिल हों।'),
                ('li', 'Your share of group expenses counts when the budget includes group shares (the default).', 'जब बजट में समूह के हिस्से शामिल हों (डिफ़ॉल्ट), तो समूह खर्चों में आपका हिस्सा गिना जाता है।'),
            ]),
            ('refunds', ('Refunds', 'रिफ़ंड'), [
                ('p', 'When “refunds restore the budget” is on (the default), refunds and reimbursements are subtracted from what you spent. Spent never goes below zero. When it’s off, refunds don’t change the budget.',
                 'जब “रिफ़ंड बजट वापस भरते हैं” चालू हो (डिफ़ॉल्ट), तो रिफ़ंड और प्रतिपूर्ति आपके खर्च से घटा दिए जाते हैं। खर्च कभी शून्य से नीचे नहीं जाता। बंद होने पर रिफ़ंड बजट को नहीं बदलते।'),
            ]),
            ('pace', ('Pace and projection', 'रफ़्तार और अनुमान'), [
                ('p', 'Pace compares what you’ve spent with an even pace through the period: the limit × days passed ÷ days in the period.',
                 'रफ़्तार आपके खर्च की तुलना पूरी अवधि में बराबर रफ़्तार से करती है: सीमा × बीते दिन ÷ अवधि के कुल दिन।'),
                ('li', 'On track: within 10% of the even pace.', 'सही राह पर: बराबर रफ़्तार के 10% के भीतर।'),
                ('li', 'Spending faster than expected: more than 10% above it.', 'उम्मीद से तेज़ खर्च: उससे 10% से ज़्यादा ऊपर।'),
                ('li', 'Spending slower than expected: more than 10% below it.', 'उम्मीद से धीमा खर्च: उससे 10% से ज़्यादा नीचे।'),
                ('li', 'Over the limit: you’ve spent more than the limit.', 'सीमा से ज़्यादा: आपने सीमा से ज़्यादा खर्च किया है।'),
                ('p', 'The projection is what you’d spend by the end of the period at your current pace. It’s an estimate, not a promise. The daily amount left is what remains ÷ days left.',
                 'अनुमान वह रकम है जो मौजूदा रफ़्तार पर अवधि के अंत तक खर्च होगी। यह एक अंदाज़ा है, वादा नहीं। रोज़ बची रकम = बची रकम ÷ बचे दिन।'),
            ]),
            ('rollover', ('Rollover', 'रोलओवर'), [
                ('p', 'Rollover carries money from one period into the next. The carried amount is added to (or taken from) the next period’s limit.',
                 'रोलओवर एक अवधि का पैसा अगली अवधि में ले जाता है। आगे ले जाई गई रकम अगली अवधि की सीमा में जोड़ी (या उससे घटाई) जाती है।'),
                ('li', 'Carry unused: what you didn’t spend is added.', 'बचा हुआ आगे ले जाएँ: जो खर्च नहीं हुआ, वह जुड़ता है।'),
                ('li', 'Carry overspend: what you overspent is taken off.', 'ज़्यादा खर्च आगे ले जाएँ: जितना ज़्यादा खर्च हुआ, वह घटता है।'),
                ('li', 'Both: either one, whichever happened.', 'दोनों: जो भी हुआ हो।'),
                ('p', 'An optional cap limits how much is carried either way. Budgets with a custom period don’t roll over. Editing a budget applies from the current period onward.',
                 'एक वैकल्पिक सीमा तय करती है कि किसी भी दिशा में कितना आगे जाए। कस्टम अवधि वाले बजट में रोलओवर नहीं होता। बजट में बदलाव मौजूदा अवधि से आगे लागू होता है।'),
            ]),
            ('alerts', ('Alerts', 'अलर्ट'), [
                ('p', 'Each threshold you choose (for example 50%, 80% and 100%) alerts you once per period. A forecast alert warns when your pace would take you over the limit. You can dismiss or snooze alerts, and an empty threshold list turns threshold alerts off.',
                 'आपकी चुनी हर सीमा (जैसे 50%, 80% और 100%) हर अवधि में एक बार अलर्ट देती है। अनुमान अलर्ट तब चेतावनी देता है जब आपकी रफ़्तार आपको सीमा से ऊपर ले जाएगी। आप अलर्ट ख़ारिज या कुछ समय के लिए बंद कर सकते हैं, और खाली सूची सीमा अलर्ट बंद कर देती है।'),
            ]),
        ],
    },
    {
        'id': 'recurring',
        'topic': 'calculations',
        'title': ('Recurring, bills and subscriptions', 'आवर्ती, बिल और सब्सक्रिप्शन'),
        'summary': (
            'How repeating transactions are scheduled and posted, how bill status works, and how subscription totals and detection are worked out.',
            'बार-बार होने वाले लेन-देन कैसे तय और दर्ज होते हैं, बिल की स्थिति कैसे तय होती है, और सब्सक्रिप्शन का कुल और पहचान कैसे होती है।',
        ),
        'link': ('Go to bills and recurring', 'बिल और आवर्ती पर जाएँ'),
        'sections': [
            ('schedule', ('Schedules', 'शेड्यूल'), [
                ('p', 'Every date is worked out from the start date, so a rule on the 31st lands on 31 January, 28 or 29 February and 31 March. Montra checks schedules about every 15 minutes and catches up after any downtime.',
                 'हर तारीख शुरुआती तारीख से निकाली जाती है, इसलिए 31 तारीख वाला नियम 31 जनवरी, 28 या 29 फ़रवरी और 31 मार्च को पड़ता है। Montra लगभग हर 15 मिनट में शेड्यूल जाँचता है और किसी रुकावट के बाद छूटे हुए काम पूरे करता है।'),
                ('p', 'Automatic posting needs a fixed amount and an account, and records exactly one transaction per occurrence. Otherwise you confirm each occurrence, or skip, postpone, change its amount or link a transaction you already recorded.',
                 'अपने-आप दर्ज होने के लिए तय रकम और खाता ज़रूरी है, और हर बार ठीक एक लेन-देन दर्ज होता है। वरना आप हर बार की पुष्टि करते हैं, या उसे छोड़ते, टालते, उसकी रकम बदलते या पहले से दर्ज लेन-देन से जोड़ते हैं।'),
            ]),
            ('bills', ('Bills', 'बिल'), [
                ('p', 'A bill’s status comes from its due date and payments: overdue, due today, due soon, upcoming or paid. Mark it paid by linking the real payment (Montra suggests matching transactions) or by recording a new one. Reminders arrive the number of days before that you chose.',
                 'बिल की स्थिति उसकी तय तारीख और भुगतानों से तय होती है: बकाया, आज देय, जल्द देय, आने वाला या भुगतान हो चुका। असली भुगतान से जोड़कर (Montra मिलते-जुलते लेन-देन सुझाता है) या नया दर्ज करके उसे भुगतान किया हुआ बताएँ। रिमाइंडर आपके चुने दिनों पहले आते हैं।'),
            ]),
            ('subscriptions', ('Subscriptions', 'सब्सक्रिप्शन'), [
                ('p', 'Monthly and yearly totals convert each price to a common cycle: a yearly plan counts as one twelfth of its price per month, and a weekly one as 52 payments a year. Totals are kept separate per currency.',
                 'मासिक और सालाना कुल हर कीमत को एक जैसे चक्र में बदलते हैं: सालाना प्लान हर महीने अपनी कीमत का बारहवाँ हिस्सा गिना जाता है, और साप्ताहिक प्लान साल में 52 भुगतान। कुल हर मुद्रा के लिए अलग रहते हैं।'),
                ('p', 'Once a day, Montra looks for charges at the same merchant at a regular interval (weekly to yearly) with similar amounts, and shows them for review. You confirm or dismiss each one. Montra never cancels anything for you; it gives you a checklist and records the cancellation once the provider confirms it.',
                 'दिन में एक बार Montra एक ही व्यापारी पर नियमित अंतराल (साप्ताहिक से सालाना) पर मिलती-जुलती रकम के शुल्क ढूँढता है और उन्हें समीक्षा के लिए दिखाता है। आप हर एक की पुष्टि करते हैं या ख़ारिज करते हैं। Montra कभी आपके लिए कुछ रद्द नहीं करता; वह एक चेकलिस्ट देता है और सेवा प्रदाता की पुष्टि के बाद रद्द होना दर्ज करता है।'),
            ]),
        ],
    },
    {
        'id': 'goals',
        'topic': 'calculations',
        'title': ('How goals are calculated', 'लक्ष्यों का हिसाब कैसे होता है'),
        'summary': (
            'What counts as saved, how milestones are reached and what the forecast assumes.',
            'बचत में क्या गिना जाता है, पड़ाव कैसे पूरे होते हैं और अनुमान किन बातों पर आधारित है।',
        ),
        'link': ('Go to goals', 'लक्ष्यों पर जाएँ'),
        'sections': [
            ('saved', ('Saved so far', 'अब तक की बचत'), [
                ('p', 'Saved is the starting amount plus recorded contributions minus recorded withdrawals. Planned contributions don’t count until you record them. A withdrawal can’t be more than what’s saved.',
                 'बचत = शुरुआती रकम + दर्ज योगदान − दर्ज निकासी। योजनाबद्ध योगदान तब तक नहीं गिने जाते जब तक आप उन्हें दर्ज न करें। निकासी बचत से ज़्यादा नहीं हो सकती।'),
                ('p', 'Linking a contribution to a real transaction marks it verified; one transaction can back only one contribution. In a shared goal, contributions a member hides still count towards progress.',
                 'किसी योगदान को असली लेन-देन से जोड़ने पर वह सत्यापित हो जाता है; एक लेन-देन केवल एक योगदान का आधार हो सकता है। साझा लक्ष्य में किसी सदस्य के छिपाए योगदान भी प्रगति में गिने जाते हैं।'),
            ]),
            ('milestones', ('Milestones', 'पड़ाव'), [
                ('p', 'Milestones are reached at 25%, 50%, 75% and 100% of the target unless you set your own. Each one notifies the goal’s members once. Reaching the target marks the goal achieved.',
                 'जब तक आप अपने पड़ाव तय न करें, लक्ष्य के 25%, 50%, 75% और 100% पर पड़ाव पूरे होते हैं। हर पड़ाव पर लक्ष्य के सदस्यों को एक बार सूचना मिलती है। लक्ष्य तक पहुँचने पर वह पूरा माना जाता है।'),
            ]),
            ('forecast', ('Forecast', 'अनुमान'), [
                ('p', 'The forecast shows how much you’d need to add each month (or week) to reach the target by its date, and when you’d reach it at your recent pace: what you saved in the last 90 days. If you planned contributions, it also shows when that plan would finish. It uses exact amounts with no interest or growth.',
                 'अनुमान बताता है कि तय तारीख तक लक्ष्य पाने के लिए हर महीने (या हफ़्ते) कितना जोड़ना होगा, और हाल की रफ़्तार से आप कब पहुँचेंगे: पिछले 90 दिनों में आपकी बचत। अगर आपने योगदान की योजना बनाई है, तो यह भी दिखता है कि वह योजना कब पूरी होगी। इसमें ब्याज या बढ़त के बिना सटीक रकम ली जाती है।'),
            ]),
        ],
    },
    {
        'id': 'groupBalances',
        'topic': 'calculations',
        'title': ('How group balances are calculated', 'समूह के बकाये का हिसाब कैसे होता है'),
        'summary': (
            'Who owes whom: what each person paid, their share, and settlements that were confirmed.',
            'किसका किस पर कितना बकाया है: हर व्यक्ति ने कितना दिया, उसका हिस्सा, और पुष्टि हुए निपटान।',
        ),
        'link': ('Go to groups', 'समूहों पर जाएँ'),
        'sections': [
            ('net', ('Your net balance', 'आपका कुल बकाया'), [
                ('p', 'For each person: what they paid, minus their share of the expenses, plus settlements they paid, minus settlements they received. A positive number means others owe them; a negative number means they owe.',
                 'हर व्यक्ति के लिए: उसने जो दिया, उसमें से खर्चों में उसका हिस्सा घटाएँ, उसके दिए निपटान जोड़ें और उसे मिले निपटान घटाएँ। धनात्मक संख्या का मतलब है दूसरों पर उसका बकाया है; ऋणात्मक का मतलब है उस पर बकाया है।'),
                ('p', 'Splits (equal, exact amounts, percentages, shares or items) are worked out exactly in the smallest unit of the currency, and any leftover paisa or cent goes to members in a fixed order, so totals always add up.',
                 'बँटवारे (बराबर, सटीक रकम, प्रतिशत, हिस्से या आइटम) मुद्रा की सबसे छोटी इकाई में सटीक निकाले जाते हैं, और बचा हुआ पैसा या सेंट तय क्रम से सदस्यों को जाता है, ताकि कुल हमेशा मेल खाए।'),
            ]),
            ('settlements', ('Settlements', 'निपटान'), [
                ('p', 'Montra never moves money. When you record that you paid someone, it counts in balances only after they confirm it; until then it shows as pending. Settlement suggestions propose fewer payments that clear the same debts, but they don’t change any record.',
                 'Montra कभी पैसा नहीं भेजता। जब आप दर्ज करते हैं कि आपने किसी को भुगतान किया, तो वह उनकी पुष्टि के बाद ही बकाये में गिना जाता है; तब तक वह लंबित दिखता है। निपटान सुझाव कम भुगतानों से वही कर्ज़ चुकाने का रास्ता बताते हैं, पर कोई रिकॉर्ड नहीं बदलते।'),
            ]),
            ('personal', ('Your own spending', 'आपका अपना खर्च'), [
                ('p', 'When you record a group payment in your own account, only your share counts as your spending. Expenses in another currency are converted with the rate typed in or Montra’s rate for the expense date.',
                 'जब आप किसी समूह भुगतान को अपने खाते में दर्ज करते हैं, तो केवल आपका हिस्सा आपके खर्च में गिना जाता है। दूसरी मुद्रा के खर्च दर्ज की गई दर से या खर्च की तारीख की Montra दर से बदले जाते हैं।'),
                ('p', 'The home screen shows only your own net balance in each group. Group members never see your personal accounts or transactions.',
                 'होम स्क्रीन हर समूह में केवल आपका अपना कुल बकाया दिखाती है। समूह के सदस्य कभी आपके निजी खाते या लेन-देन नहीं देखते।'),
            ]),
        ],
    },
    {
        'id': 'imports',
        'topic': 'statements',
        'title': ('Importing statements and fixing a failed import', 'स्टेटमेंट आयात करना और असफल आयात ठीक करना'),
        'summary': (
            'Upload a statement file, check the columns, review rows and duplicates, and recover when something goes wrong.',
            'स्टेटमेंट फ़ाइल अपलोड करें, कॉलम जाँचें, पंक्तियाँ और डुप्लिकेट देखें, और कुछ गलत होने पर उसे ठीक करें।',
        ),
        'link': ('Go to imports', 'आयात पर जाएँ'),
        'sections': [
            ('steps', ('How an import works', 'आयात कैसे होता है'), [
                ('li', 'Download a statement from your bank as CSV, XLSX, OFX or QFX, and choose the account it belongs to. The statement must be in the account’s currency.',
                 'अपने बैंक से CSV, XLSX, OFX या QFX में स्टेटमेंट डाउनलोड करें, और वह खाता चुनें जिसका यह है। स्टेटमेंट खाते की मुद्रा में होना चाहिए।'),
                ('li', 'Check the column mapping: which column is the date, amount or description, the date format and whether spending is shown as negative.',
                 'कॉलम मैपिंग जाँचें: कौन-सा कॉलम तारीख, रकम या विवरण है, तारीख का प्रारूप क्या है और क्या खर्च ऋणात्मक दिखाया गया है।'),
                ('li', 'Review the rows. Rows already imported, and possible duplicates of transactions you entered, are flagged. Correct a value or skip a row.',
                 'पंक्तियाँ देखें। पहले से आयात हुई पंक्तियाँ और आपके दर्ज लेन-देन के संभावित डुप्लिकेट चिह्नित होते हैं। कोई मान ठीक करें या पंक्ति छोड़ दें।'),
                ('li', 'Confirm. Montra creates the transactions in the background and notifies you when it’s done.',
                 'पुष्टि करें। Montra पृष्ठभूमि में लेन-देन बनाता है और पूरा होने पर आपको सूचना देता है।'),
            ]),
            ('failed', ('If the file can’t be read', 'अगर फ़ाइल पढ़ी न जा सके'), [
                ('p', 'The import page says why. Common reasons and fixes:',
                 'आयात पेज कारण बताता है। आम कारण और उपाय:'),
                ('li', 'Unsupported or damaged file: download the statement again as CSV or XLSX and upload that.',
                 'असमर्थित या खराब फ़ाइल: स्टेटमेंट को फिर से CSV या XLSX में डाउनलोड करके अपलोड करें।'),
                ('li', 'Empty, too many rows or too many columns: split the period into smaller statements. One file can have up to 20,000 rows and 64 columns.',
                 'खाली, बहुत ज़्यादा पंक्तियाँ या कॉलम: अवधि को छोटे स्टेटमेंट में बाँटें। एक फ़ाइल में 20,000 पंक्तियाँ और 64 कॉलम तक हो सकते हैं।'),
                ('li', 'Currency doesn’t match: choose the account in the statement’s currency, or create one.',
                 'मुद्रा मेल नहीं खाती: स्टेटमेंट की मुद्रा वाला खाता चुनें, या नया बनाएँ।'),
                ('li', 'PDF statements: PDFs can’t be read today. Download CSV, XLSX, OFX or QFX instead.',
                 'PDF स्टेटमेंट: आज PDF नहीं पढ़े जा सकते। इसके बदले CSV, XLSX, OFX या QFX डाउनलोड करें।'),
            ]),
            ('rows', ('If some rows fail', 'अगर कुछ पंक्तियाँ असफल हों'), [
                ('p', 'Each refused row names the value to fix, such as a date or amount that can’t be read. Correct it in the row and confirm again. If the import finished with errors, retry the failed rows once you’ve fixed them.',
                 'हर अस्वीकृत पंक्ति बताती है कि कौन-सा मान ठीक करना है, जैसे ऐसी तारीख या रकम जो पढ़ी नहीं जा सकी। पंक्ति में उसे ठीक करें और फिर से पुष्टि करें। अगर आयात त्रुटियों के साथ पूरा हुआ, तो ठीक करने के बाद असफल पंक्तियाँ दोबारा आज़माएँ।'),
                ('p', 'Imported the wrong file or into the wrong account? Undo the import: it deletes the transactions it created, except ones you edited since.',
                 'गलत फ़ाइल या गलत खाते में आयात हो गया? आयात वापस लें: इससे बने लेन-देन हट जाते हैं, सिवाय उनके जिन्हें आपने बाद में बदला।'),
            ]),
        ],
    },
    {
        'id': 'reconciliation',
        'topic': 'statements',
        'title': ('Reconciling an account', 'खाते का मिलान करना'),
        'summary': (
            'Match statement lines with your transactions and check a balance against your statement.',
            'स्टेटमेंट की पंक्तियों को अपने लेन-देन से मिलाएँ और बैलेंस की तुलना स्टेटमेंट से करें।',
        ),
        'link': ('Go to accounts', 'खातों पर जाएँ'),
        'sections': [
            ('matches', ('Matching', 'मिलान'), [
                ('p', 'After an import, Montra suggests matches: a statement line and the transaction you already entered for it, a pending transaction and its posted version, or a manual entry and an imported one. Each suggestion shows how sure it is and why.',
                 'आयात के बाद Montra मिलान सुझाता है: स्टेटमेंट की कोई पंक्ति और उसके लिए आपका पहले से दर्ज लेन-देन, कोई लंबित लेन-देन और उसका पोस्ट किया गया रूप, या कोई हाथ से दर्ज और आयात किया गया लेन-देन। हर सुझाव बताता है कि वह कितना पक्का है और क्यों।'),
                ('p', 'Confirming a match keeps one record, so nothing is counted twice. You can also match a line by hand with one or more transactions whose amounts add up, and undo a match later.',
                 'मिलान की पुष्टि करने पर एक ही रिकॉर्ड रहता है, ताकि कुछ भी दो बार न गिना जाए। आप किसी पंक्ति को हाथ से एक या ज़्यादा ऐसे लेन-देन से भी मिला सकते हैं जिनकी रकम का जोड़ बराबर हो, और बाद में मिलान वापस ले सकते हैं।'),
                ('li', 'Both sides must be money in or both money out, and the amounts must add up exactly.', 'दोनों तरफ़ या तो पैसा आना हो या दोनों तरफ़ जाना, और रकम का जोड़ बिल्कुल बराबर हो।'),
                ('li', 'A transaction can be in only one match.', 'एक लेन-देन केवल एक मिलान में हो सकता है।'),
                ('li', 'A pair more than a week apart is shown without confidence: check it yourself.', 'एक हफ़्ते से ज़्यादा दूर की जोड़ी बिना भरोसे के दिखती है: इसे खुद जाँचें।'),
            ]),
            ('balance', ('Balance check', 'बैलेंस जाँच'), [
                ('p', 'Enter the balance on your statement (for a card, the amount owed) and its date. Montra compares it with the account on that date and records whether it balanced. A balanced check is remembered as the last reconciled date.',
                 'अपने स्टेटमेंट का बैलेंस (कार्ड के लिए, बकाया रकम) और उसकी तारीख दर्ज करें। Montra उसी तारीख पर खाते से तुलना करता है और दर्ज करता है कि मेल हुआ या नहीं। मेल खाने वाली जाँच को आख़िरी मिलान की तारीख के रूप में याद रखा जाता है।'),
                ('p', 'If it doesn’t balance, look for missing or duplicate transactions around that date, unconfirmed matches and pending items. If the difference is real, record a balance adjustment with a reason.',
                 'अगर मेल न हो, तो उस तारीख के आसपास छूटे या दोहराए गए लेन-देन, बिना पुष्टि वाले मिलान और लंबित चीज़ें देखें। अगर अंतर सही है, तो कारण के साथ बैलेंस समायोजन दर्ज करें।'),
            ]),
        ],
    },
    {
        'id': 'privacy',
        'topic': 'account',
        'title': ('Privacy, export and deletion', 'गोपनीयता, एक्सपोर्ट और खाता हटाना'),
        'summary': (
            'Choose optional consents, download a copy of your data, pause your account or delete it.',
            'वैकल्पिक सहमतियाँ चुनें, अपने डेटा की कॉपी डाउनलोड करें, खाता रोकें या हटाएँ।',
        ),
        'link': ('Go to privacy and data', 'गोपनीयता और डेटा पर जाएँ'),
        'sections': [
            ('consents', ('Consents', 'सहमतियाँ'), [
                ('p', 'The terms and privacy policy are accepted at sign-up. Everything else (location, notifications, and others) is optional, and you can turn it off at any time. Some choices are only recorded today because the feature they’d enable doesn’t exist yet.',
                 'शर्तें और गोपनीयता नीति साइन-अप के समय स्वीकार होती हैं। बाकी सब (लोकेशन, सूचनाएँ आदि) वैकल्पिक है, और आप इसे कभी भी बंद कर सकते हैं। कुछ विकल्प आज केवल दर्ज होते हैं, क्योंकि जिस सुविधा के लिए वे हैं वह अभी मौजूद नहीं है।'),
                ('p', 'Montra’s staff have no default access to your financial data, and logs never contain your amounts, merchants or descriptions.',
                 'Montra के कर्मचारियों की आपके वित्तीय डेटा तक कोई डिफ़ॉल्ट पहुँच नहीं है, और लॉग में कभी आपकी रकम, व्यापारी या विवरण नहीं होते।'),
            ]),
            ('export', ('Download your data', 'अपना डेटा डाउनलोड करें'), [
                ('p', 'Ask for an export and confirm it’s you. Montra prepares a ZIP file with your data in the background and notifies you when it’s ready. The download link stays valid for 7 days.',
                 'एक्सपोर्ट माँगें और पुष्टि करें कि यह आप हैं। Montra पृष्ठभूमि में आपके डेटा की ZIP फ़ाइल तैयार करता है और तैयार होने पर सूचना देता है। डाउनलोड लिंक 7 दिन तक मान्य रहता है।'),
            ]),
            ('deactivate', ('Deactivate', 'खाता निष्क्रिय करें'), [
                ('p', 'Deactivating signs you out everywhere and keeps your data. Signing in again reactivates the account.',
                 'निष्क्रिय करने से आप हर जगह से साइन आउट हो जाते हैं और आपका डेटा रहता है। फिर से साइन इन करने पर खाता सक्रिय हो जाता है।'),
            ]),
            ('delete', ('Delete your account', 'अपना खाता हटाएँ'), [
                ('p', 'Deletion starts after a 7-day grace period, and you can cancel it until then. Montra shows what will happen to each group first. When it runs, your personal records and files are deleted, groups you own are handed over or archived, and what you shared in groups and communities stays as “Deleted member”. A confirmation is emailed to you.',
                 'खाता हटाना 7 दिन की छूट अवधि के बाद शुरू होता है, और तब तक आप इसे रद्द कर सकते हैं। Montra पहले बताता है कि हर समूह का क्या होगा। हटाते समय आपके निजी रिकॉर्ड और फ़ाइलें हटा दी जाती हैं, आपके बनाए समूह किसी और को सौंपे या संग्रहित किए जाते हैं, और समूहों व समुदायों में साझा की गई चीज़ें “हटाया गया सदस्य” के नाम से रहती हैं। पुष्टि आपको ईमेल की जाती है।'),
                ('p', 'Download an export first if you want to keep a copy.', 'अगर कॉपी रखनी है, तो पहले एक्सपोर्ट डाउनलोड करें।'),
            ]),
        ],
    },
    {
        'id': 'twoStep',
        'topic': 'account',
        'title': ('Two-step verification and recovery', 'दो-चरणीय सत्यापन और रिकवरी'),
        'summary': (
            'Protect sign-in with an authenticator app, and keep recovery codes for when your phone isn’t available.',
            'ऑथेंटिकेटर ऐप से साइन-इन सुरक्षित करें, और फ़ोन न होने की स्थिति के लिए रिकवरी कोड रखें।',
        ),
        'link': ('Go to security settings', 'सुरक्षा सेटिंग पर जाएँ'),
        'sections': [
            ('setup', ('Turning it on', 'इसे चालू करना'), [
                ('li', 'In security settings, choose to turn on two-step verification and confirm your password.', 'सुरक्षा सेटिंग में दो-चरणीय सत्यापन चालू करना चुनें और अपना पासवर्ड पक्का करें।'),
                ('li', 'Scan the QR code (or type the key) into an authenticator app, then enter the 6-digit code it shows.', 'QR कोड को किसी ऑथेंटिकेटर ऐप में स्कैन करें (या कुंजी टाइप करें), फिर उसमें दिखा 6 अंकों का कोड दर्ज करें।'),
                ('li', 'Save the 10 recovery codes somewhere safe and offline. Each code works once.', '10 रिकवरी कोड किसी सुरक्षित और ऑफ़लाइन जगह पर सहेजें। हर कोड एक बार काम करता है।'),
            ]),
            ('signIn', ('Signing in', 'साइन इन करना'), [
                ('p', 'After your password, enter the current code from the app, or one of your recovery codes. Codes change every 30 seconds and each code can be used only once, so if one is refused, wait for the next.',
                 'पासवर्ड के बाद ऐप का मौजूदा कोड या अपना कोई रिकवरी कोड दर्ज करें। कोड हर 30 सेकंड में बदलते हैं और हर कोड एक ही बार इस्तेमाल हो सकता है, इसलिए अगर कोई अस्वीकार हो, तो अगले का इंतज़ार करें।'),
                ('p', 'Sensitive actions (changing two-step verification, new recovery codes, exporting data, deactivating or deleting the account) ask you to confirm it’s you again if you haven’t in the last few minutes.',
                 'संवेदनशील काम (दो-चरणीय सत्यापन बदलना, नए रिकवरी कोड, डेटा एक्सपोर्ट, खाता निष्क्रिय करना या हटाना) तब फिर से आपकी पुष्टि माँगते हैं जब आपने पिछले कुछ मिनटों में पुष्टि न की हो।'),
            ]),
            ('recovery', ('Lost your phone?', 'फ़ोन खो गया?'), [
                ('p', 'Sign in with a recovery code. Then, in security settings, turn two-step verification off and on again to set up your new phone, or create new recovery codes. New codes replace all the old ones.',
                 'किसी रिकवरी कोड से साइन इन करें। फिर सुरक्षा सेटिंग में नया फ़ोन सेट करने के लिए दो-चरणीय सत्यापन बंद करके फिर चालू करें, या नए रिकवरी कोड बनाएँ। नए कोड सभी पुराने कोड की जगह ले लेते हैं।'),
                ('p', 'Montra staff can’t see your codes or skip the second step for you, so without your app or a recovery code you can’t sign in. Keep the recovery codes safe.',
                 'Montra के कर्मचारी आपके कोड नहीं देख सकते और न ही आपके लिए दूसरा चरण छोड़ सकते हैं, इसलिए ऐप या रिकवरी कोड के बिना आप साइन इन नहीं कर सकते। रिकवरी कोड सुरक्षित रखें।'),
                ('p', 'Montra emails you whenever two-step verification is turned on or off.',
                 'दो-चरणीय सत्यापन चालू या बंद होने पर Montra आपको ईमेल करता है।'),
            ]),
        ],
    },
    {
        'id': 'fairUse',
        'topic': 'account',
        'title': ('Fair-use limits', 'उचित उपयोग की सीमाएँ'),
        'summary': (
            'The same limits apply to everyone. They keep Montra fast; they are never paid tiers.',
            'सभी पर एक जैसी सीमाएँ लागू होती हैं। ये Montra को तेज़ रखती हैं; ये कभी सशुल्क स्तर नहीं हैं।',
        ),
        'link': ('See the limits and your usage', 'सीमाएँ और अपना उपयोग देखें'),
        'sections': [
            ('what', ('What’s limited', 'क्या सीमित है'), [
                ('p', 'Every feature is free, and the limits are the same for every person. The limits page shows the exact values and how much storage you use. The usual defaults are:',
                 'हर सुविधा मुफ़्त है, और सीमाएँ हर व्यक्ति के लिए एक जैसी हैं। सीमाओं वाला पेज सटीक मान और आपका स्टोरेज उपयोग दिखाता है। सामान्य डिफ़ॉल्ट ये हैं:'),
                ('li', 'Storage: 2 GB of files in total, and up to 20 MB per file (some kinds of file have a lower limit).', 'स्टोरेज: कुल 2 GB फ़ाइलें, और हर फ़ाइल 20 MB तक (कुछ तरह की फ़ाइलों की सीमा कम है)।'),
                ('li', 'Imports: up to 20,000 rows per statement.', 'आयात: हर स्टेटमेंट में 20,000 पंक्तियाँ तक।'),
                ('li', 'Open records: 500 recurring rules, 200 bills, 500 subscriptions and 200 goals.', 'खुले रिकॉर्ड: 500 आवर्ती नियम, 200 बिल, 500 सब्सक्रिप्शन और 200 लक्ष्य।'),
                ('li', 'Support: 10 new requests and 10 messages a day.', 'सहायता: रोज़ 10 नए अनुरोध और 10 संदेश।'),
            ]),
            ('reached', ('When you reach a limit', 'जब आप सीमा तक पहुँचें'), [
                ('p', 'Montra tells you which limit you reached. For open records, archive, end or delete ones you no longer need. For storage, delete files you don’t need. If you’re asked to wait, Montra shows how long; daily caps reset the next day.',
                 'Montra बताता है कि आप किस सीमा तक पहुँचे। खुले रिकॉर्ड के लिए जिनकी अब ज़रूरत नहीं उन्हें संग्रहित करें, ख़त्म करें या हटाएँ। स्टोरेज के लिए गैर-ज़रूरी फ़ाइलें हटाएँ। अगर इंतज़ार करने को कहा जाए, तो Montra बताता है कितनी देर; रोज़ की सीमाएँ अगले दिन फिर शुरू होती हैं।'),
                ('p', 'Before uploading, Montra makes large photos smaller, so receipts and pictures use less of your storage. PDFs are uploaded as they are.',
                 'अपलोड करने से पहले Montra बड़ी फ़ोटो को छोटा करता है, ताकि रसीदें और तस्वीरें कम स्टोरेज लें। PDF जैसी हैं वैसी ही अपलोड होती हैं।'),
            ]),
        ],
    },
    {
        'id': 'troubleshooting',
        'topic': 'troubleshooting',
        'title': ('Troubleshooting sign-in, sync and notifications', 'साइन-इन, सिंक और सूचनाओं की समस्याएँ'),
        'summary': (
            'What to check when you can’t sign in, your data looks out of date, or notifications don’t arrive.',
            'जब साइन इन न हो पाए, डेटा पुराना लगे, या सूचनाएँ न आएँ, तो क्या जाँचें।',
        ),
        'link': ('Go to notification settings', 'सूचना सेटिंग पर जाएँ'),
        'sections': [
            ('signIn', ('Can’t sign in', 'साइन इन नहीं हो रहा'), [
                ('li', 'New account? Open the link in the verification email first. You can ask for a new link; links expire after 24 hours.', 'नया खाता? पहले सत्यापन ईमेल का लिंक खोलें। आप नया लिंक माँग सकते हैं; लिंक 24 घंटे बाद समाप्त हो जाते हैं।'),
                ('li', 'The error doesn’t say whether the email or the password is wrong, to protect accounts. If you’re unsure, reset your password; the reset link works for 1 hour, and only the newest one counts.', 'खातों की सुरक्षा के लिए त्रुटि यह नहीं बताती कि ईमेल गलत है या पासवर्ड। अगर संदेह हो, तो पासवर्ड रीसेट करें; रीसेट लिंक 1 घंटे तक चलता है, और केवल सबसे नया मान्य है।'),
                ('li', 'After several failed attempts you’ll be asked to wait; the screen shows how long. Resetting your password also works.', 'कई असफल कोशिशों के बाद आपको इंतज़ार करने को कहा जाएगा; स्क्रीन बताती है कितनी देर। पासवर्ड रीसेट करना भी काम करता है।'),
                ('li', 'Two-step code refused? Make sure your phone sets its time automatically, and wait for a new code. Or use a recovery code.', 'दो-चरणीय कोड अस्वीकार? पक्का करें कि आपका फ़ोन समय अपने-आप सेट करता है, और नए कोड का इंतज़ार करें। या कोई रिकवरी कोड इस्तेमाल करें।'),
                ('li', 'On the web, Montra needs cookies for this site. Changing or resetting your password signs you out on your other devices.', 'वेब पर Montra को इस साइट के लिए कुकीज़ चाहिए। पासवर्ड बदलने या रीसेट करने से आप अपने दूसरे डिवाइस पर साइन आउट हो जाते हैं।'),
            ]),
            ('sync', ('Data looks out of date', 'डेटा पुराना लग रहा है'), [
                ('p', 'There is no bank sync: Montra shows what you’ve recorded or imported. The web and the app read the same account, so a change on one appears on the other when the screen refreshes. Reload the page, or pull down to refresh in the app.',
                 'कोई बैंक सिंक नहीं है: Montra वही दिखाता है जो आपने दर्ज या आयात किया है। वेब और ऐप एक ही खाता पढ़ते हैं, इसलिए एक पर किया बदलाव स्क्रीन रीफ़्रेश होने पर दूसरे पर दिखता है। पेज रीलोड करें, या ऐप में नीचे खींचकर रीफ़्रेश करें।'),
                ('li', 'Some figures update in the background a moment after a change: budget progress, imports, recurring occurrences (about every 15 minutes) and subscription suggestions (daily).', 'कुछ आँकड़े बदलाव के कुछ देर बाद पृष्ठभूमि में अपडेट होते हैं: बजट की प्रगति, आयात, आवर्ती घटनाएँ (लगभग हर 15 मिनट) और सब्सक्रिप्शन सुझाव (रोज़)।'),
                ('li', 'When your phone is offline, the app shows a banner and changes can’t be saved. Try again when you’re back online: the same save is never recorded twice.', 'फ़ोन ऑफ़लाइन होने पर ऐप एक बैनर दिखाता है और बदलाव सहेजे नहीं जा सकते। ऑनलाइन होने पर फिर से कोशिश करें: एक ही सहेजना कभी दो बार दर्ज नहीं होता।'),
            ]),
            ('notifications', ('Notifications don’t arrive', 'सूचनाएँ नहीं आ रहीं'), [
                ('li', 'Check notification settings: each kind of notification can be on or off for in-app, email and browser notifications. Security and account messages are always on.', 'सूचना सेटिंग जाँचें: हर तरह की सूचना इन-ऐप, ईमेल और ब्राउज़र सूचनाओं के लिए चालू या बंद हो सकती है। सुरक्षा और खाते के संदेश हमेशा चालू रहते हैं।'),
                ('li', 'Quiet hours delay email and push until they end, and a daily or weekly digest collects non-urgent email (sent at 08:00 your time; weekly on Mondays).', 'शांत घंटे ईमेल और पुश को उनके ख़त्म होने तक रोकते हैं, और रोज़ या साप्ताहिक सारांश गैर-ज़रूरी ईमेल इकट्ठा करता है (आपके समय से 08:00 बजे; साप्ताहिक सोमवार को)।'),
                ('li', 'Browser notifications need your browser’s permission, and the server must support them; if the option isn’t offered, they aren’t available yet. The phone app doesn’t receive push notifications yet: open the notification centre instead.', 'ब्राउज़र सूचनाओं के लिए ब्राउज़र की अनुमति चाहिए, और सर्वर को इनका समर्थन करना चाहिए; अगर विकल्प नहीं दिखता, तो ये अभी उपलब्ध नहीं हैं। फ़ोन ऐप में अभी पुश सूचनाएँ नहीं आतीं: इसके बदले सूचना केंद्र खोलें।'),
                ('li', 'No email? Check your spam folder. Using an unsubscribe link turns off only that kind of email.', 'ईमेल नहीं आया? स्पैम फ़ोल्डर देखें। अनसब्सक्राइब लिंक केवल उस तरह का ईमेल बंद करता है।'),
            ]),
            ('stillStuck', ('Still stuck?', 'अब भी समस्या है?'), [
                ('p', 'Send a support request and include the reference shown with the error, if there was one. Never include card numbers, PINs, OTPs or passwords.',
                 'सहायता अनुरोध भेजें और अगर त्रुटि के साथ कोई संदर्भ दिखा हो, तो उसे शामिल करें। कभी भी कार्ड नंबर, PIN, OTP या पासवर्ड न डालें।'),
            ]),
        ],
    },
]

# Interface strings around the guides.
UI = [
    ('title', 'Guides', 'गाइड'),
    ('description', 'Step-by-step guides and how Montra works out your numbers.', 'चरण-दर-चरण गाइड और Montra आपकी संख्याएँ कैसे निकालता है।'),
    ('search', 'Search the guides', 'गाइड में खोजें'),
    ('searchHelp', 'Searches titles and text in the current language.', 'मौजूदा भाषा में शीर्षक और लिखाई में खोजता है।'),
    ('noResults', 'No guide matches “{query}”. Try another word, or send us a request below.', '“{query}” से कोई गाइड मेल नहीं खाती। कोई दूसरा शब्द आज़माएँ, या नीचे हमें अनुरोध भेजें।'),
    ('resultCount', '{count} guides found', '{count} गाइड मिलीं'),
    ('open', 'Read the guide', 'गाइड पढ़ें'),
    ('back', 'All guides', 'सभी गाइड'),
    ('onThisPage', 'On this page', 'इस पेज पर'),
    ('related', 'Where to do this', 'यह कहाँ करें'),
    ('notFound', 'This guide doesn’t exist. It may have moved.', 'यह गाइड मौजूद नहीं है। हो सकता है यह कहीं और चली गई हो।'),
    ('contact', 'Didn’t find an answer? Send a support request.', 'जवाब नहीं मिला? सहायता अनुरोध भेजें।'),
    ('status', 'Service status', 'सेवा की स्थिति'),
    ('statusHelp', 'Check whether Montra is having problems right now.', 'देखें कि क्या Montra में अभी कोई समस्या है।'),
    ('affordance', 'How this works', 'यह कैसे काम करता है'),
]

import type { NamespaceTranslation } from '../../types';
import type en from '../en/organize';

/** Hindi `organize` messages; missing keys fall back to English. */
const messages = {
  // Round 2: organize (categories, category rules, tags, merchants)
  'organize.subnav.label': 'व्यवस्थित करें',
  'organize.subnav.categories': 'श्रेणियाँ',
  'organize.subnav.rules': 'नियम',
  'organize.subnav.tags': 'टैग',
  'organize.subnav.merchants': 'व्यापारी',
  'organize.archived': 'संग्रहित',
  'organize.showArchived': 'संग्रहित दिखाएँ',
  'organize.actionsFor': '{name} के लिए कार्रवाइयाँ',
  'organize.viewTransactions': 'लेन-देन देखें',
  'organize.transactionCount': { one: '{count} लेन-देन', other: '{count} लेन-देन' },
  'organize.color.label': 'रंग',
  'organize.color.help': 'सूचियों में पहचानने में मदद करता है। नाम हमेशा साथ में दिखता है।',
  'organize.color.none': 'कोई रंग नहीं',
  'organize.color.current': 'मौजूदा रंग',
  'organize.color.teal': 'हरा-नीला',
  'organize.color.blue': 'नीला',
  'organize.color.indigo': 'गहरा नीला',
  'organize.color.purple': 'बैंगनी',
  'organize.color.pink': 'गुलाबी',
  'organize.color.red': 'लाल',
  'organize.color.orange': 'नारंगी',
  'organize.color.yellow': 'पीला',
  'organize.color.green': 'हरा',
  'organize.color.gray': 'स्लेटी',
  'organize.categories.title': 'श्रेणियाँ',
  'organize.categories.description':
    'अपने खर्च और आय को समूहों में रखें। शुरुआती श्रेणियों के नाम बदलें, अपनी श्रेणियाँ जोड़ें, या जिनकी ज़रूरत नहीं उन्हें मिला दें।',
  'organize.categories.add': 'श्रेणी जोड़ें',
  'organize.categories.merge': 'श्रेणियाँ मिलाएँ',
  'organize.categories.list.title': 'आपकी श्रेणियाँ',
  'organize.categories.loading': 'श्रेणियाँ लोड हो रही हैं…',
  'organize.categories.error': 'हम आपकी श्रेणियाँ लोड नहीं कर सके',
  'organize.categories.empty.title': 'अभी कोई श्रेणी नहीं',
  'organize.categories.empty.body':
    '“किराना” या “वेतन” जैसी श्रेणियाँ जोड़ें ताकि पता चले कि आपका पैसा कहाँ जाता है।',
  'organize.categories.notInBudgets': 'बजट में नहीं गिनी जाती',
  'organize.categories.subcategories': '{name} की उप-श्रेणियाँ',
  'organize.categories.merged': 'मिला दी गई',
  'organize.categories.addSub': 'उप-श्रेणी जोड़ें',
  'organize.categories.notFound': 'वह श्रेणी अब मौजूद नहीं है।',
  'organize.categories.changedElsewhere':
    'यह श्रेणी कहीं और बदली गई थी। हमने नया संस्करण लोड किया है; उसे देखें और फिर से सहेजें।',
  'organize.categories.archive.action': 'संग्रहित करें',
  'organize.categories.archive.title': 'यह श्रेणी संग्रहित करें?',
  'organize.categories.archive.body':
    '{name} नए लेन-देन के लिए नहीं दिखेगी। पिछले लेन-देन में यह बनी रहेगी, और आप इसे कभी भी वापस ला सकते हैं।',
  'organize.categories.archive.confirm': 'संग्रहित करें',
  'organize.categories.archive.done': 'श्रेणी संग्रहित की गई',
  'organize.categories.restore.action': 'वापस लाएँ',
  'organize.categories.restore.done': 'श्रेणी वापस लाई गई',
  'organize.categories.restore.failed': 'हम श्रेणी वापस नहीं ला सके',
  'organize.categories.delete.action': 'हटाएँ',
  'organize.categories.delete.title': 'यह श्रेणी हटाएँ?',
  'organize.categories.delete.body':
    '{name} किसी लेन-देन में इस्तेमाल नहीं हुई है, इसलिए इसे हटाया जा सकता है। इसे वापस नहीं किया जा सकता।',
  'organize.categories.delete.confirm': 'हटाएँ',
  'organize.categories.delete.done': 'श्रेणी हटा दी गई',
  'organize.categories.delete.inUse':
    'यह श्रेणी अभी दूसरे रिकॉर्ड, जैसे नियम, बजट या बिल में इस्तेमाल हो रही है। इसके बजाय इसे संग्रहित करें या किसी दूसरी श्रेणी में मिला दें।',
  'organize.categories.create.title': 'श्रेणी जोड़ें',
  'organize.categories.createSub.title': 'उप-श्रेणी जोड़ें',
  'organize.categories.create.submit': 'श्रेणी जोड़ें',
  'organize.categories.create.done': 'श्रेणी जोड़ दी गई',
  'organize.categories.edit.title': 'श्रेणी बदलें',
  'organize.categories.edit.done': 'श्रेणी अपडेट हो गई',
  'organize.categories.form.name': 'नाम',
  'organize.categories.form.nameRequired': 'नाम दर्ज करें।',
  'organize.categories.form.kind': 'किसके लिए',
  'organize.categories.form.parent': 'मुख्य श्रेणी',
  'organize.categories.form.parentNone': 'कोई नहीं (मुख्य स्तर)',
  'organize.categories.form.parentHelp':
    'उप-श्रेणियाँ ज़्यादा जानकारी देती हैं, जैसे “किराना” के अंदर “फल”। सिर्फ़ एक स्तर संभव है।',
  'organize.categories.form.parentLocked':
    'इस श्रेणी में उप-श्रेणियाँ हैं, इसलिए यह मुख्य स्तर पर ही रहेगी।',
  'organize.categories.form.budgets': 'बजट में गिनें',
  'organize.categories.form.budgetsHelp':
    'जो पैसा आप सिर्फ़ इधर-उधर रखते हैं, जैसे बचत में जमा, उसके लिए इसे बंद करें ताकि बजट में असली खर्च ही गिना जाए।',
  'organize.categories.form.duplicate': 'इस स्तर पर इस नाम की श्रेणी पहले से है।',
  'organize.categories.form.depth': 'उप-श्रेणियों के अंदर और उप-श्रेणियाँ नहीं बन सकतीं।',
  'organize.merge.title': 'श्रेणियाँ मिलाएँ',
  'organize.merge.description':
    'कुछ श्रेणियों का सब कुछ एक श्रेणी में ले जाएँ, जैसे जब “खाना” और “खाना और रेस्टोरेंट” का मतलब एक ही हो।',
  'organize.merge.target': 'यह श्रेणी रखें',
  'organize.merge.targetPlaceholder': 'श्रेणी चुनें',
  'organize.merge.targetRequired': 'रखने के लिए श्रेणी चुनें।',
  'organize.merge.sources': 'इन्हें उसमें मिलाएँ',
  'organize.merge.sourcesRequired': 'मिलाने के लिए कम से कम एक श्रेणी चुनें।',
  'organize.merge.chooseTargetFirst': 'पहले रखने वाली श्रेणी चुनें।',
  'organize.merge.preview': 'देखें क्या बदलेगा',
  'organize.merge.previewTitle': 'क्या बदलेगा',
  'organize.merge.previewIntro': '{target} में मिलाने पर ये चीज़ें उसमें जाएँगी:',
  'organize.merge.nothing':
    'अभी इन श्रेणियों का कहीं इस्तेमाल नहीं हुआ है, इसलिए सिर्फ़ श्रेणियाँ ही मिलाई जाएँगी।',
  'organize.merge.affected.transactions': { one: '{count} लेन-देन', other: '{count} लेन-देन' },
  'organize.merge.affected.subcategories': {
    one: '{count} उप-श्रेणी',
    other: '{count} उप-श्रेणियाँ',
  },
  'organize.merge.affected.rules': { one: '{count} श्रेणी नियम', other: '{count} श्रेणी नियम' },
  'organize.merge.affected.budget_allocations': {
    one: '{count} बजट सीमा',
    other: '{count} बजट सीमाएँ',
  },
  'organize.merge.affected.recurring_rules': {
    one: '{count} आवर्ती भुगतान',
    other: '{count} आवर्ती भुगतान',
  },
  'organize.merge.affected.bills': { one: '{count} बिल', other: '{count} बिल' },
  'organize.merge.affected.subscriptions': {
    one: '{count} सब्सक्रिप्शन',
    other: '{count} सब्सक्रिप्शन',
  },
  'organize.merge.affected.merchants': {
    one: '{count} व्यापारी की डिफ़ॉल्ट श्रेणी',
    other: '{count} व्यापारियों की डिफ़ॉल्ट श्रेणी',
  },
  'organize.merge.affected.other': {
    one: '{count} अन्य जुड़ा रिकॉर्ड',
    other: '{count} अन्य जुड़े रिकॉर्ड',
  },
  'organize.merge.warning':
    'मिलाई गई श्रेणियाँ हटा दी जाएँगी और उन्हें फिर से अलग नहीं किया जा सकता।',
  'organize.merge.confirm': 'श्रेणियाँ मिलाएँ',
  'organize.merge.done': 'श्रेणियाँ मिला दी गईं',
  'organize.merge.topLevelOnly':
    'उप-श्रेणियों वाली श्रेणी सिर्फ़ किसी मुख्य श्रेणी में मिलाई जा सकती है।',
  'organize.merge.notEnough': 'मिलाने के लिए कम से कम दो सक्रिय श्रेणियाँ चाहिए।',
  'organize.merge.affected.budget_filters': {
    one: '{count} बजट फ़िल्टर (वह बजट अब {target} को बाहर रखेगा)',
    other: '{count} बजट फ़िल्टर (वे बजट अब {target} को बाहर रखेंगे)',
  },
  'organize.categories.inUse.budget_filters': {
    one: '{count} बजट जो इसे बाहर रखता है',
    other: '{count} बजट जो इसे बाहर रखते हैं',
  },
  'organize.categories.delete.inUseList':
    'यह श्रेणी अभी भी इनमें इस्तेमाल हो रही है: {list}। इसके बजाय इसे संग्रहित करें या किसी दूसरी श्रेणी में मिलाएँ।',
  'organize.categories.form.duplicateNamed': 'इस स्तर पर “{name}” नाम की श्रेणी पहले से है।',
  'organize.categories.form.removeIcon': 'सहेजा गया आइकन हटाएँ',
  'organize.categories.form.removeIconHelp':
    'इस श्रेणी में शुरुआती सेट का एक आइकन है। इसे हटाने से नाम या रंग नहीं बदलता।',
  'organize.errors.category_merged':
    'यह श्रेणी किसी दूसरी श्रेणी में मिला दी गई है, इसलिए इसे बदला नहीं जा सकता।',
  'organize.errors.category_already_merged':
    'इनमें से एक श्रेणी पहले ही मिला दी गई है। इसे बंद करें और अपनी श्रेणियाँ फिर से देखें।',
  'organize.errors.merge_target_inactive': 'रखने के लिए कोई सक्रिय श्रेणी चुनें।',
  'organize.errors.parent_category_archived':
    'इसकी मूल श्रेणी संग्रहित है। पहले मूल श्रेणी वापस लाएँ, या कोई दूसरी मूल श्रेणी चुनें।',
  'organize.errors.name_taken': '“{name}” नाम पहले से इस्तेमाल हो रहा है। कोई दूसरा नाम चुनें।',
  'organize.errors.name_taken_generic': 'यह नाम पहले से इस्तेमाल हो रहा है। कोई दूसरा नाम चुनें।',
} as const satisfies NamespaceTranslation<typeof en>;

export default messages;

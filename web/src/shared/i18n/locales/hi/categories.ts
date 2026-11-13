import type { NamespaceTranslation } from '../../types';
import type en from '../en/categories';

/** Hindi `categories` messages; missing keys fall back to English. */
const messages = {
  // Categories (starter names are localized by system key)
  'categories.uncategorized': 'बिना श्रेणी',
  'categories.starter.food_dining': 'खाना और रेस्टोरेंट',
  'categories.starter.groceries': 'किराना',
  'categories.starter.transport': 'आवागमन',
  'categories.starter.fuel': 'ईंधन',
  'categories.starter.housing_rent': 'घर और किराया',
  'categories.starter.utilities': 'बिजली, पानी और बिल',
  'categories.starter.shopping': 'खरीदारी',
  'categories.starter.healthcare': 'स्वास्थ्य',
  'categories.starter.education': 'शिक्षा',
  'categories.starter.entertainment': 'मनोरंजन',
  'categories.starter.travel': 'यात्रा',
  'categories.starter.personal_care': 'व्यक्तिगत देखभाल',
  'categories.starter.insurance': 'बीमा',
  'categories.starter.taxes_fees': 'कर और शुल्क',
  'categories.starter.gifts_donations': 'उपहार और दान',
  'categories.starter.family': 'परिवार',
  'categories.starter.work_expenses': 'काम के खर्च',
  'categories.starter.salary': 'वेतन',
  'categories.starter.freelance_income': 'फ़्रीलांस आय',
  'categories.starter.interest': 'ब्याज',
  'categories.starter.refunds': 'रिफ़ंड',
  'categories.starter.other': 'अन्य',
  'categories.kind.expense': 'खर्च',
  'categories.kind.income': 'आय',
  'categories.kind.both': 'खर्च और आय',
} as const satisfies NamespaceTranslation<typeof en>;

export default messages;

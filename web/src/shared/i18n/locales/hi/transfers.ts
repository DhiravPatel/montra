import type { NamespaceTranslation } from '../../types';
import type en from '../en/transfers';

/** Hindi `transfers` messages; missing keys fall back to English. */
const messages = {
  'transfers.add': 'ट्रांसफ़र',
  'transfers.create.title': 'अपने खातों के बीच ट्रांसफ़र',
  'transfers.create.description':
    'अपने एक खाते से दूसरे में पैसा ले जाएँ, जैसे बैंक खाते से क्रेडिट कार्ड का भुगतान।',
  'transfers.create.done': 'ट्रांसफ़र सहेज लिया गया',
  'transfers.form.from': 'किस खाते से',
  'transfers.form.to': 'किस खाते में',
  'transfers.form.fromRequired': 'वह खाता चुनें जिससे पैसा जाता है।',
  'transfers.form.toRequired': 'वह खाता चुनें जिसमें पैसा जाता है।',
  'transfers.form.sameAccount': 'दो अलग-अलग खाते चुनें।',
  'transfers.form.amount': 'भेजी गई राशि',
  'transfers.form.amountHelp': '“से” वाले खाते की मुद्रा में।',
  'transfers.form.crossCurrency':
    'इन खातों की मुद्राएँ अलग हैं ({from} और {to})। बताएँ कितना पहुँचा, या विनिमय दर।',
  'transfers.form.fxMode': 'आपको क्या पता है?',
  'transfers.form.fxAmount': 'मिली राशि',
  'transfers.form.fxRate': 'विनिमय दर',
  'transfers.form.toAmount': 'मिली राशि',
  'transfers.form.rate': 'विनिमय दर',
  'transfers.form.rateHelp': '1 {from} के बदले कितने {to}, जैसे 83.1234।',
  'transfers.form.fee': 'शुल्क',
  'transfers.form.feeHelp': '“से” वाले खाते से लिया गया और अलग खर्च के रूप में दर्ज।',
  'transfers.form.submit': 'ट्रांसफ़र सहेजें',
  'transfers.form.notAllowed': 'यह ट्रांसफ़र संभव नहीं है। दोनों खाते आपके और सक्रिय होने चाहिए।',
  'transfers.form.needTwoTitle': 'आपको दो खातों की ज़रूरत है',
  'transfers.form.needTwoBody':
    'ट्रांसफ़र आपके दो सक्रिय खातों के बीच पैसा ले जाता है। पहले एक और खाता जोड़ें।',
} as const satisfies NamespaceTranslation<typeof en>;

export default messages;

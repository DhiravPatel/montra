// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appTitle => 'Montra';

  @override
  String get actionRetry => 'फिर से कोशिश करें';

  @override
  String get actionCancel => 'रद्द करें';

  @override
  String get actionContinue => 'जारी रखें';

  @override
  String get actionDone => 'हो गया';

  @override
  String get actionCopy => 'कॉपी करें';

  @override
  String get actionClose => 'बंद करें';

  @override
  String get copiedToClipboard => 'कॉपी हो गया';

  @override
  String get loadingLabel => 'लोड हो रहा है';

  @override
  String requestReference(String requestId) {
    return 'संदर्भ: $requestId';
  }

  @override
  String get copyReference => 'संदर्भ कॉपी करें';

  @override
  String get offlineBanner =>
      'आप ऑफ़लाइन हैं। दोबारा कनेक्ट होने तक बदलाव सहेजे नहीं जा सकते।';

  @override
  String get errorOfflineTitle => 'आप ऑफ़लाइन हैं';

  @override
  String get errorOfflineBody =>
      'अपना इंटरनेट कनेक्शन जाँचें और फिर से कोशिश करें।';

  @override
  String get errorTimeout =>
      'Montra जवाब देने में बहुत समय ले रहा है। थोड़ी देर में फिर से कोशिश करें।';

  @override
  String get errorGenericTitle => 'कुछ गड़बड़ हो गई';

  @override
  String get errorGenericBody =>
      'हम यह अनुरोध पूरा नहीं कर सके। थोड़ी देर में फिर से कोशिश करें।';

  @override
  String get errorServiceUnavailable =>
      'Montra अभी उपलब्ध नहीं है। कुछ मिनट बाद फिर से कोशिश करें।';

  @override
  String get errorInvalidResponse =>
      'हमें एक अनपेक्षित जवाब मिला। फिर से कोशिश करें, और अगर ऐसा बार-बार हो तो ऐप अपडेट करें।';

  @override
  String get errorPermissionTitle => 'आपके पास पहुँच नहीं है';

  @override
  String get errorPermissionBody =>
      'आपको इसे देखने या बदलने की अनुमति नहीं है।';

  @override
  String get errorNotFound =>
      'हमें यह नहीं मिला। हो सकता है इसे हटा दिया गया हो।';

  @override
  String get errorConflict =>
      'इसे कहीं और बदला गया है। रीफ़्रेश करें और फिर से कोशिश करें।';

  @override
  String get errorRateLimited =>
      'बहुत ज़्यादा कोशिशें। थोड़ा रुककर फिर से कोशिश करें।';

  @override
  String errorRateLimitedRetry(String wait) {
    return 'बहुत ज़्यादा कोशिशें। $wait बाद फिर से कोशिश करें।';
  }

  @override
  String get errorSessionEnded =>
      'आपका सत्र समाप्त हो गया। फिर से साइन इन करें।';

  @override
  String get errorValidation => 'कुछ जानकारी पर ध्यान देने की ज़रूरत है।';

  @override
  String durationSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count सेकंड',
      one: '1 सेकंड',
    );
    return '$_temp0';
  }

  @override
  String durationMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count मिनट',
      one: '1 मिनट',
    );
    return '$_temp0';
  }

  @override
  String shortSeconds(int count) {
    return '$count सेकंड';
  }

  @override
  String shortMinutes(int count) {
    return '$count मिनट';
  }

  @override
  String retryIn(String wait) {
    return '$wait में फिर कोशिश करें';
  }

  @override
  String get welcomeTagline =>
      'अपने पैसे को समझें, मिलकर पैसे का प्रबंधन करें, और बेहतर वित्तीय फ़ैसले लें।';

  @override
  String get welcomeFreeTitle => 'सभी के लिए मुफ़्त';

  @override
  String get welcomeFreeBody =>
      'हर सुविधा मुफ़्त है। कोई पेड प्लान या लॉक की गई सुविधा नहीं है।';

  @override
  String get welcomePrivateTitle => 'डिफ़ॉल्ट रूप से निजी';

  @override
  String get welcomePrivateBody =>
      'आपका वित्तीय डेटा कभी बेचा नहीं जाता और कभी सार्वजनिक रूप से नहीं दिखाया जाता।';

  @override
  String get welcomeManualTitle => 'बैंक जोड़ने की ज़रूरत नहीं';

  @override
  String get welcomeManualBody =>
      'अपना हिसाब खुद दर्ज करके अपने पैसे पर नज़र रखें। बैंक जोड़ना कभी ज़रूरी नहीं है।';

  @override
  String get welcomeCreateAccount => 'खाता बनाएँ';

  @override
  String get welcomeSignIn => 'मेरा खाता पहले से है';

  @override
  String get emailLabel => 'ईमेल पता';

  @override
  String get passwordLabel => 'पासवर्ड';

  @override
  String get showPassword => 'पासवर्ड दिखाएँ';

  @override
  String get hidePassword => 'पासवर्ड छिपाएँ';

  @override
  String get validationEmailRequired => 'अपना ईमेल पता दर्ज करें।';

  @override
  String get validationEmailInvalid => 'मान्य ईमेल पता दर्ज करें।';

  @override
  String get validationPasswordRequired => 'अपना पासवर्ड दर्ज करें।';

  @override
  String get signInTitle => 'साइन इन करें';

  @override
  String get signInButton => 'साइन इन करें';

  @override
  String get forgotPasswordLink => 'पासवर्ड भूल गए?';

  @override
  String get noAccountPrompt => 'Montra पर नए हैं?';

  @override
  String get createAccountLink => 'खाता बनाएँ';

  @override
  String get signInInvalidCredentials => 'ईमेल या पासवर्ड गलत है।';

  @override
  String get signInAccountLocked =>
      'यह खाता लॉक है। पहुँच वापस पाने के लिए सहायता टीम से संपर्क करें।';

  @override
  String get signInThrottled =>
      'साइन इन की बहुत सारी कोशिशें विफल रहीं। बाद में फिर से कोशिश करें या अपना पासवर्ड रीसेट करें।';

  @override
  String signInThrottledRetry(String wait) {
    return 'साइन इन की बहुत सारी कोशिशें विफल रहीं। $wait बाद फिर से कोशिश करें, या अपना पासवर्ड रीसेट करें।';
  }

  @override
  String get signInEmailNotVerifiedTitle =>
      'साइन इन करने के लिए अपना ईमेल सत्यापित करें';

  @override
  String get signInEmailNotVerifiedBody =>
      'हमने आपको सत्यापन का नया लिंक भेजा है। इसे इसी डिवाइस पर खोलें, या यहाँ पेस्ट करें।';

  @override
  String get sessionExpiredNotice =>
      'आपका सत्र समाप्त हो गया। जारी रखने के लिए फिर से साइन इन करें।';

  @override
  String get signedOutEverywhereNotice =>
      'आपको सभी डिवाइस से साइन आउट कर दिया गया है।';

  @override
  String get passwordResetNotice =>
      'आपका पासवर्ड बदल दिया गया है। नए पासवर्ड से साइन इन करें।';

  @override
  String get mfaTitle => 'दो-चरणीय सत्यापन';

  @override
  String get mfaBody => 'अपने ऑथेंटिकेटर ऐप से 6 अंकों का कोड दर्ज करें।';

  @override
  String get mfaRecoveryBody =>
      'दो-चरणीय सत्यापन चालू करते समय सहेजे गए रिकवरी कोड में से कोई एक दर्ज करें। हर कोड सिर्फ़ एक बार काम करता है।';

  @override
  String get mfaCodeLabel => 'सत्यापन कोड';

  @override
  String get mfaRecoveryLabel => 'रिकवरी कोड';

  @override
  String get mfaUseRecovery => 'इसके बजाय रिकवरी कोड इस्तेमाल करें';

  @override
  String get mfaUseCode => 'इसके बजाय ऑथेंटिकेटर कोड इस्तेमाल करें';

  @override
  String get mfaVerifyButton => 'सत्यापित करें';

  @override
  String get mfaStartOver => 'फिर से शुरू करें';

  @override
  String get validationCodeRequired => '6 अंकों का कोड दर्ज करें।';

  @override
  String get validationCodeFormat => 'कोड 6 अंकों का होता है।';

  @override
  String get validationRecoveryRequired => 'रिकवरी कोड दर्ज करें।';

  @override
  String get mfaCodeInvalid =>
      'यह कोड काम नहीं किया। अपना ऑथेंटिकेटर ऐप जाँचें और फिर से कोशिश करें।';

  @override
  String get mfaRecoveryCodeInvalid =>
      'यह रिकवरी कोड काम नहीं किया। उसे जाँचें और फिर से कोशिश करें; हर कोड सिर्फ़ एक बार काम करता है।';

  @override
  String get mfaChallengeExpired =>
      'साइन इन की यह कोशिश समाप्त हो गई है। फिर से शुरू करने के लिए अपना पासवर्ड दर्ज करें।';

  @override
  String get signUpTitle => 'अपना खाता बनाएँ';

  @override
  String get displayNameLabel => 'नाम';

  @override
  String get displayNameHelp => 'Montra आपको किस नाम से बुलाए?';

  @override
  String get validationDisplayNameRequired => 'नाम दर्ज करें।';

  @override
  String validationDisplayNameLength(int max) {
    return '$max या उससे कम अक्षरों का इस्तेमाल करें।';
  }

  @override
  String get passwordRulesTitle => 'आपका पासवर्ड';

  @override
  String passwordRuleLength(int min) {
    return 'कम से कम $min अक्षरों का हो';
  }

  @override
  String get passwordRuleNotEmail => 'उसमें आपका ईमेल पता न हो';

  @override
  String get passwordRuleVariety => 'उसमें कम से कम 4 अलग-अलग अक्षर हों';

  @override
  String get passwordRuleCommon =>
      'आम तौर पर इस्तेमाल होने वाला पासवर्ड न हो (सबमिट करने पर जाँचा जाएगा)';

  @override
  String get passwordRuleMet => 'पूरा हुआ';

  @override
  String get passwordRuleNotMet => 'अभी नहीं';

  @override
  String get passwordRuleServerChecked => 'Montra जाँचेगा';

  @override
  String validationPasswordTooShort(int min) {
    return 'कम से कम $min अक्षरों का इस्तेमाल करें।';
  }

  @override
  String validationPasswordTooLong(int max) {
    return '$max या उससे कम अक्षरों का इस्तेमाल करें।';
  }

  @override
  String get currencyLabel => 'मुख्य मुद्रा';

  @override
  String get currencyHelp =>
      'वह मुद्रा जिसका आप सबसे ज़्यादा इस्तेमाल करते हैं।';

  @override
  String get currencyPickerTitle => 'मुद्रा चुनें';

  @override
  String get currencySearchHint => 'नाम या कोड से खोजें';

  @override
  String currencyNoResults(String query) {
    return '\"$query\" से मेल खाती कोई मुद्रा नहीं मिली।';
  }

  @override
  String get currencyLoadError => 'हम मुद्राओं की सूची लोड नहीं कर सके।';

  @override
  String get currencyNotChosen => 'नहीं चुनी गई';

  @override
  String get validationCurrencyRequired => 'मुद्रा चुनें।';

  @override
  String get deviceSettingsTitle => 'इस डिवाइस से ली गई जानकारी';

  @override
  String deviceTimezone(String timezone) {
    return 'समय क्षेत्र: $timezone';
  }

  @override
  String get deviceTimezoneUnknown =>
      'समय क्षेत्र: पता नहीं चला (Montra का डिफ़ॉल्ट इस्तेमाल होगा)';

  @override
  String deviceLocale(String locale) {
    return 'भाषा और क्षेत्र: $locale';
  }

  @override
  String termsCheckbox(String version) {
    return 'मैं सेवा की शर्तों और गोपनीयता नीति (संस्करण $version) से सहमत हूँ।';
  }

  @override
  String get termsLink => 'सेवा की शर्तें पढ़ें';

  @override
  String get privacyLink => 'गोपनीयता नीति पढ़ें';

  @override
  String get validationTermsRequired =>
      'खाता बनाने के लिए शर्तें स्वीकार करें।';

  @override
  String get adultCheckbox => 'मेरी उम्र कम से कम 18 वर्ष है।';

  @override
  String get validationAdultRequired =>
      'Montra इस्तेमाल करने के लिए आपकी उम्र कम से कम 18 वर्ष होनी चाहिए।';

  @override
  String get signUpButton => 'खाता बनाएँ';

  @override
  String get signUpClosed =>
      'नए साइन-अप अभी रोके गए हैं। कृपया बाद में फिर से कोशिश करें।';

  @override
  String get haveAccountPrompt => 'क्या आपका खाता पहले से है?';

  @override
  String get signInLink => 'साइन इन करें';

  @override
  String get checkEmailTitle => 'अपना ईमेल देखें';

  @override
  String checkEmailBody(String email) {
    return 'हमने $email पर सत्यापन लिंक भेजा है। अपना खाता सेट करने के लिए इसे इसी डिवाइस पर खोलें।';
  }

  @override
  String get checkEmailBodyNoAddress =>
      'हमने आपको सत्यापन लिंक भेजा है। अपना खाता सेट करने के लिए इसे इसी डिवाइस पर खोलें।';

  @override
  String get checkEmailSpamHint =>
      'ईमेल नहीं मिला? अपना स्पैम या जंक फ़ोल्डर देखें।';

  @override
  String get haveLinkButton => 'मेरे पास लिंक है';

  @override
  String get resendEmailButton => 'ईमेल फिर से भेजें';

  @override
  String resendEmailCooldown(String wait) {
    return '$wait में फिर से भेजें';
  }

  @override
  String get resendEmailSent =>
      'अगर आपके खाते को सत्यापन की ज़रूरत है, तो नया लिंक भेजा जा रहा है।';

  @override
  String get backToSignIn => 'साइन इन पर वापस जाएँ';

  @override
  String get verifyEmailTitle => 'अपना ईमेल सत्यापित करें';

  @override
  String get verifyingEmail => 'आपका ईमेल सत्यापित किया जा रहा है…';

  @override
  String get verifyEmailSuccessTitle => 'ईमेल सत्यापित हो गया';

  @override
  String get verifyEmailSuccessBody =>
      'अपने ईमेल पते की पुष्टि करने के लिए धन्यवाद। अब आप साइन इन कर सकते हैं।';

  @override
  String get verifyEmailSuccessSignedInBody =>
      'अपने ईमेल पते की पुष्टि करने के लिए धन्यवाद।';

  @override
  String get verifyEmailExpired =>
      'यह सत्यापन लिंक अमान्य है या इसकी समय-सीमा खत्म हो गई है। नीचे नया लिंक माँगें।';

  @override
  String get verifyEmailPasteBody => 'अपने ईमेल से सत्यापन लिंक पेस्ट करें।';

  @override
  String get verifyEmailButton => 'ईमेल सत्यापित करें';

  @override
  String get resendSectionTitle => 'नया लिंक चाहिए?';

  @override
  String get resendSectionBody =>
      'अपना ईमेल पता दर्ज करें और हम सत्यापन का नया लिंक भेज देंगे।';

  @override
  String get pasteLinkLabel => 'ईमेल में मिला लिंक';

  @override
  String get pasteFromClipboard => 'क्लिपबोर्ड से पेस्ट करें';

  @override
  String get validationLinkRequired => 'ईमेल में मिला लिंक पेस्ट करें।';

  @override
  String get validationLinkInvalid =>
      'यह Montra का लिंक नहीं लगता। ईमेल से पूरा लिंक कॉपी करें।';

  @override
  String get validationLinkIsReset =>
      'यह पासवर्ड रीसेट करने का लिंक है। इसे पासवर्ड रीसेट स्क्रीन पर इस्तेमाल करें।';

  @override
  String get validationLinkIsVerify =>
      'यह ईमेल सत्यापन का लिंक है। इसे ईमेल सत्यापन स्क्रीन पर इस्तेमाल करें।';

  @override
  String get forgotTitle => 'अपना पासवर्ड रीसेट करें';

  @override
  String get forgotBody =>
      'अपने खाते का ईमेल पता दर्ज करें और हम आपको नया पासवर्ड चुनने का लिंक भेजेंगे।';

  @override
  String get forgotButton => 'रीसेट लिंक भेजें';

  @override
  String get forgotSentTitle => 'अपना ईमेल देखें';

  @override
  String forgotSentBody(String email) {
    return 'अगर $email के लिए कोई खाता है, तो रीसेट लिंक भेजा जा रहा है। इसे इसी डिवाइस पर खोलें।';
  }

  @override
  String get resetTitle => 'नया पासवर्ड चुनें';

  @override
  String get resetPasteBody => 'पासवर्ड रीसेट ईमेल से लिंक पेस्ट करें।';

  @override
  String get newPasswordLabel => 'नया पासवर्ड';

  @override
  String get confirmPasswordLabel => 'नए पासवर्ड की पुष्टि करें';

  @override
  String get validationConfirmPasswordRequired =>
      'नया पासवर्ड फिर से दर्ज करें।';

  @override
  String get validationPasswordsDontMatch => 'पासवर्ड मेल नहीं खाते।';

  @override
  String get resetButton => 'पासवर्ड अपडेट करें';

  @override
  String get resetSuccessTitle => 'पासवर्ड अपडेट हो गया';

  @override
  String get resetSuccessBody =>
      'आपका पासवर्ड बदल दिया गया है और सभी डिवाइस से साइन आउट कर दिया गया है। अपने नए पासवर्ड से साइन इन करें।';

  @override
  String get resetExpired =>
      'यह रीसेट लिंक अमान्य है या इसकी समय-सीमा खत्म हो गई है। नया लिंक माँगें।';

  @override
  String get requestNewLink => 'नया लिंक माँगें';

  @override
  String get splashRestoring => 'आपको साइन इन किया जा रहा है…';

  @override
  String get splashRestoreFailedTitle => 'हम Montra तक नहीं पहुँच सके';

  @override
  String get splashRestoreFailedBody =>
      'आप इस डिवाइस पर अब भी साइन इन हैं। अपना कनेक्शन जाँचें और फिर से कोशिश करें।';

  @override
  String get splashSignOut => 'इसके बजाय साइन आउट करें';

  @override
  String get notFoundTitle => 'पेज नहीं मिला';

  @override
  String get notFoundBody => 'यह लिंक ऐप में उपलब्ध नहीं है।';

  @override
  String get goHome => 'Montra पर जाएँ';

  @override
  String get configErrorTitle => 'Montra शुरू नहीं हो सकता';

  @override
  String get configErrorBody =>
      'ऐप का यह बिल्ड सही तरह से कॉन्फ़िगर नहीं है। कृपया आधिकारिक बिल्ड इंस्टॉल करें।';

  @override
  String get navProfile => 'प्रोफ़ाइल';

  @override
  String get profileTitle => 'प्रोफ़ाइल';

  @override
  String profileSignedInAs(String name) {
    return '$name के रूप में साइन इन';
  }

  @override
  String get emailVerifiedStatus => 'ईमेल सत्यापित';

  @override
  String get emailNotVerifiedStatus => 'ईमेल सत्यापित नहीं';

  @override
  String get securityTitle => 'सुरक्षा';

  @override
  String get securitySubtitle => 'पासवर्ड, दो-चरणीय सत्यापन और डिवाइस';

  @override
  String get appearanceTitle => 'दिखावट';

  @override
  String get themeSystem => 'सिस्टम';

  @override
  String get themeLight => 'हल्की';

  @override
  String get themeDark => 'गहरी';

  @override
  String get signOutButton => 'साइन आउट करें';

  @override
  String get signedOutOffline =>
      'आप इस डिवाइस पर साइन आउट हो गए हैं। हम Montra तक नहीं पहुँच सके, इसलिए वह सत्र अपनी अवधि पूरी होने पर खुद समाप्त हो जाएगा।';

  @override
  String get statusOn => 'चालू';

  @override
  String get statusOff => 'बंद';

  @override
  String get twoStepTitle => 'दो-चरणीय सत्यापन';

  @override
  String twoStepStatus(String status) {
    return 'दो-चरणीय सत्यापन: $status';
  }

  @override
  String get twoStepSubtitle => 'साइन इन करते समय ऑथेंटिकेटर ऐप से एक कोड';

  @override
  String get sessionsTitle => 'डिवाइस और सत्र';

  @override
  String get sessionsSubtitle =>
      'देखें कि आप कहाँ साइन इन हैं और दूर से साइन आउट करें';

  @override
  String get changePasswordTitle => 'पासवर्ड बदलें';

  @override
  String get changePasswordSubtitle => 'दूसरे डिवाइस साइन आउट हो जाएँगे';

  @override
  String get signOutEverywhereButton => 'सभी डिवाइस से साइन आउट करें';

  @override
  String get signOutEverywhereConfirmTitle => 'सभी डिवाइस से साइन आउट करें?';

  @override
  String get signOutEverywhereConfirmBody =>
      'आप इस डिवाइस समेत हर जगह से साइन आउट हो जाएँगे और आपको फिर से साइन इन करना होगा।';

  @override
  String get signOutEverywhereConfirm => 'हर जगह से साइन आउट करें';

  @override
  String get sessionsEmpty => 'कोई सक्रिय सत्र नहीं है।';

  @override
  String get sessionCurrentDevice => 'यह डिवाइस';

  @override
  String sessionLastActive(String time) {
    return 'आख़िरी बार सक्रिय $time';
  }

  @override
  String sessionSignedInOn(String date) {
    return '$date को साइन इन';
  }

  @override
  String get sessionTwoStepVerified => 'दो-चरणीय सत्यापन से पुष्टि की गई';

  @override
  String get sessionClientAndroid => 'Android ऐप';

  @override
  String get sessionClientIos => 'iPhone या iPad ऐप';

  @override
  String get sessionClientWeb => 'वेब ब्राउज़र';

  @override
  String get sessionClientUnknown => 'अनजान डिवाइस';

  @override
  String get sessionRevoke => 'साइन आउट करें';

  @override
  String sessionRevokeLabel(String device) {
    return '$device से साइन आउट करें';
  }

  @override
  String get sessionRevokeConfirmTitle => 'इस डिवाइस से साइन आउट करें?';

  @override
  String sessionRevokeConfirmBody(String device) {
    return '$device साइन आउट हो जाएगा और उसे फिर से साइन इन करना होगा।';
  }

  @override
  String get sessionRevoked => 'डिवाइस साइन आउट हो गया।';

  @override
  String get sessionAlreadyEnded => 'वह सत्र पहले ही समाप्त हो चुका था।';

  @override
  String get relativeJustNow => 'अभी-अभी';

  @override
  String relativeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count मिनट पहले',
      one: '1 मिनट पहले',
    );
    return '$_temp0';
  }

  @override
  String relativeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count घंटे पहले',
      one: '1 घंटा पहले',
    );
    return '$_temp0';
  }

  @override
  String relativeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count दिन पहले',
      one: 'कल',
    );
    return '$_temp0';
  }

  @override
  String get currentPasswordLabel => 'मौजूदा पासवर्ड';

  @override
  String get changePasswordButton => 'पासवर्ड बदलें';

  @override
  String get changePasswordSuccess =>
      'पासवर्ड बदल गया। आपके दूसरे डिवाइस साइन आउट हो गए हैं।';

  @override
  String get twoStepIntro =>
      'हर बार साइन इन करते समय आप ऑथेंटिकेटर ऐप का एक कोड भी डालेंगे। अगर किसी को आपका पासवर्ड पता चल जाए, तब भी आपका खाता सुरक्षित रहता है।';

  @override
  String get twoStepSetupButton => 'दो-चरणीय सत्यापन सेट करें';

  @override
  String get twoStepScanTitle => '1. अपने ऑथेंटिकेटर ऐप में Montra जोड़ें';

  @override
  String get twoStepScanBody =>
      'किसी दूसरे डिवाइस के ऑथेंटिकेटर ऐप से यह QR कोड स्कैन करें, या इस डिवाइस के ऑथेंटिकेटर ऐप में सेटअप लिंक खोलें।';

  @override
  String get twoStepQrSemantics => 'ऑथेंटिकेटर ऐप में Montra जोड़ने का QR कोड';

  @override
  String get twoStepOpenApp => 'ऑथेंटिकेटर ऐप में खोलें';

  @override
  String get twoStepNoApp =>
      'इस डिवाइस पर कोई ऐप सेटअप लिंक नहीं खोल सका। इसकी जगह सेटअप कुंजी डालें।';

  @override
  String get twoStepManualTitle => 'या यह सेटअप कुंजी डालें';

  @override
  String get twoStepCopyKey => 'सेटअप कुंजी कॉपी करें';

  @override
  String get twoStepVerifyTitle => '2. उसमें दिखने वाला 6 अंकों का कोड डालें';

  @override
  String get twoStepActivateButton => 'दो-चरणीय सत्यापन चालू करें';

  @override
  String get twoStepCancelSetup => 'सेटअप रद्द करें';

  @override
  String get twoStepEnabledBody =>
      'दो-चरणीय सत्यापन चालू है। साइन इन करते समय आप अपने ऑथेंटिकेटर ऐप का कोड डालेंगे।';

  @override
  String get twoStepEnabledNotice => 'दो-चरणीय सत्यापन चालू है।';

  @override
  String get twoStepRegenerate => 'नए रिकवरी कोड बनाएँ';

  @override
  String get twoStepRegenerateConfirmTitle => 'नए रिकवरी कोड बनाएँ?';

  @override
  String get twoStepRegenerateConfirmBody =>
      'आपके मौजूदा रिकवरी कोड तुरंत काम करना बंद कर देंगे।';

  @override
  String get twoStepRegenerateConfirm => 'नए कोड बनाएँ';

  @override
  String get twoStepDisable => 'दो-चरणीय सत्यापन बंद करें';

  @override
  String get twoStepDisableBody =>
      'दो-चरणीय सत्यापन बंद करने के लिए अपने ऑथेंटिकेटर ऐप का कोड या अपना कोई रिकवरी कोड डालें।';

  @override
  String get twoStepDisableConfirm => 'बंद करें';

  @override
  String get twoStepDisabledNotice => 'दो-चरणीय सत्यापन बंद है।';

  @override
  String get twoStepDisableCodeRejected =>
      'वह कोड काम नहीं किया। हर कोड सिर्फ़ एक बार काम करता है: अगर आपने अभी पुष्टि के लिए इसका इस्तेमाल किया है, तो अगले कोड का इंतज़ार करें और फिर से कोशिश करें, या रिकवरी कोड इस्तेमाल करें।';

  @override
  String get recoveryCodesTitle => 'अपने रिकवरी कोड सहेजें';

  @override
  String get recoveryCodesBody =>
      'अगर आप अपने ऑथेंटिकेटर ऐप तक नहीं पहुँच पाते, तो इनमें से किसी कोड से साइन इन कर सकते हैं। हर कोड एक बार काम करता है। ये सिर्फ़ इसी बार दिखाए जाएँगे।';

  @override
  String get recoveryCodesListLabel => 'रिकवरी कोड';

  @override
  String get recoveryCodesCopy => 'कोड कॉपी करें';

  @override
  String get recoveryCodesCopied =>
      'रिकवरी कोड कॉपी हो गए। इन्हें किसी सुरक्षित जगह, जैसे पासवर्ड मैनेजर में रखें।';

  @override
  String get recoveryCodesConfirm => 'मैंने अपने रिकवरी कोड सहेज लिए हैं';

  @override
  String get recoveryCodesLeaveTitle => 'सहेजे बिना जाएँ?';

  @override
  String get recoveryCodesLeaveBody =>
      'ये कोड दोबारा नहीं दिखाए जाएँगे। आप बाद में नए कोड बना सकते हैं, जो इनकी जगह ले लेंगे।';

  @override
  String get recoveryCodesLeave => 'जाएँ';

  @override
  String get recoveryCodesStay => 'रुकें';

  @override
  String get reauthTitle => 'पुष्टि करें कि यह आप ही हैं';

  @override
  String get reauthBody =>
      'आपकी सुरक्षा के लिए, जारी रखने हेतु अपना पासवर्ड दर्ज करें।';

  @override
  String get reauthBodyWithCode =>
      'आपकी सुरक्षा के लिए, जारी रखने हेतु अपना पासवर्ड और ऑथेंटिकेटर ऐप का कोड दर्ज करें।';

  @override
  String get reauthBodyWithRecovery =>
      'आपकी सुरक्षा के लिए, जारी रखने हेतु अपना पासवर्ड और कोई अप्रयुक्त रिकवरी कोड दर्ज करें।';

  @override
  String get reauthButton => 'पुष्टि करें';

  @override
  String get reauthWrongPassword => 'पासवर्ड गलत है।';

  @override
  String get reauthCodeInvalid => 'अपने ऑथेंटिकेटर ऐप से मान्य कोड दर्ज करें।';

  @override
  String get reauthRecoveryInvalid => 'कोई अप्रयुक्त रिकवरी कोड दर्ज करें।';

  @override
  String get confirmDestructiveDefault => 'पुष्टि करें';

  @override
  String get errorStillSaving =>
      'आपका पिछला अनुरोध अभी सहेजा जा रहा है। थोड़ा रुकें, फिर दोबारा कोशिश करने से पहले जाँच लें।';

  @override
  String get errorRequestChanged =>
      'भेजते समय यह अनुरोध बदल गया। जानकारी देखें और फिर से सहेजें।';

  @override
  String get versionConflictReloaded =>
      'इसे कहीं और बदला गया था, इसलिए हमने नया संस्करण लोड किया है। उसे देखें और अपना बदलाव फिर से करें।';

  @override
  String get moneyMinusWord => 'माइनस';

  @override
  String moneyInflowSemantics(String amount) {
    return '$amount मिले';
  }

  @override
  String moneyOutflowSemantics(String amount) {
    return '$amount खर्च';
  }

  @override
  String get amountRequired => 'राशि दर्ज करें।';

  @override
  String get amountInvalid => 'एक संख्या दर्ज करें, जैसे 1250.50।';

  @override
  String amountTooPrecise(int decimals) {
    String _temp0 = intl.Intl.pluralLogic(
      decimals,
      locale: localeName,
      other: 'ज़्यादा से ज़्यादा $decimals दशमलव अंक',
      one: 'ज़्यादा से ज़्यादा 1 दशमलव अंक',
    );
    return '$_temp0 इस्तेमाल करें।';
  }

  @override
  String get amountNoDecimals => 'इस मुद्रा में दशमलव अंक नहीं होते।';

  @override
  String get amountNotPositive => 'शून्य से ज़्यादा राशि दर्ज करें।';

  @override
  String get amountNegative => 'राशि ऋणात्मक नहीं हो सकती।';

  @override
  String get amountTooLarge => 'यह राशि बहुत बड़ी है।';

  @override
  String get selectorNotChosen => 'नहीं चुना गया';

  @override
  String get selectorChangeHint => 'बदलने के लिए दो बार टैप करें';

  @override
  String selectorClear(String field) {
    return '$field हटाएँ';
  }

  @override
  String get selectedLabel => 'चुना गया';

  @override
  String get chartShowTable => 'सूची के रूप में दिखाएँ';

  @override
  String get chartShowChart => 'चार्ट के रूप में दिखाएँ';

  @override
  String get actionSave => 'सहेजें';

  @override
  String get actionEdit => 'बदलें';

  @override
  String get actionDelete => 'हटाएँ';

  @override
  String get actionRestore => 'वापस लाएँ';

  @override
  String get actionAdd => 'जोड़ें';

  @override
  String get actionApply => 'लागू करें';

  @override
  String get actionReset => 'रीसेट करें';

  @override
  String get actionSeeAll => 'सभी देखें';

  @override
  String get actionSkip => 'छोड़ें';

  @override
  String get actionBack => 'वापस';

  @override
  String get actionNext => 'आगे';

  @override
  String get actionMore => 'और विकल्प';

  @override
  String get actionClear => 'साफ़ करें';

  @override
  String get actionLoadMore => 'और लोड करें';

  @override
  String optionalLabel(String field) {
    return '$field (वैकल्पिक)';
  }

  @override
  String get dateToday => 'आज';

  @override
  String refreshFailedStale(String time) {
    return 'हम रीफ़्रेश नहीं कर सके। $time के आँकड़े दिखा रहे हैं।';
  }

  @override
  String updatedAt(String time) {
    return '$time अपडेट किया गया';
  }

  @override
  String get noneOption => 'कोई नहीं';

  @override
  String get searchHint => 'खोजें';

  @override
  String get validationRequired => 'यह जानकारी ज़रूरी है।';

  @override
  String validationTooLong(int max) {
    return '$max या उससे कम अक्षर इस्तेमाल करें।';
  }

  @override
  String get offlineSaveHint =>
      'आप ऑफ़लाइन हैं। आपकी भरी जानकारी बनी रहेगी; ऑनलाइन होने पर फिर से सहेजें।';

  @override
  String possibleDuplicateNotice(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count दूसरे लेन-देन',
      one: 'एक दूसरे लेन-देन',
    );
    return 'यह $_temp0 जैसा लगता है। कुछ भी मिलाया नहीं गया।';
  }

  @override
  String get possibleDuplicateReview => 'देखें';

  @override
  String get starterFoodDining => 'खाना और रेस्तराँ';

  @override
  String get starterGroceries => 'किराना';

  @override
  String get starterTransport => 'आना-जाना';

  @override
  String get starterFuel => 'ईंधन';

  @override
  String get starterHousingRent => 'घर और किराया';

  @override
  String get starterUtilities => 'बिजली-पानी और बिल';

  @override
  String get starterShopping => 'खरीदारी';

  @override
  String get starterHealthcare => 'स्वास्थ्य';

  @override
  String get starterEducation => 'शिक्षा';

  @override
  String get starterEntertainment => 'मनोरंजन';

  @override
  String get starterTravel => 'यात्रा';

  @override
  String get starterPersonalCare => 'निजी देखभाल';

  @override
  String get starterInsurance => 'बीमा';

  @override
  String get starterTaxesFees => 'कर और शुल्क';

  @override
  String get starterGiftsDonations => 'उपहार और दान';

  @override
  String get starterFamily => 'परिवार';

  @override
  String get starterWorkExpenses => 'काम के खर्च';

  @override
  String get starterSalary => 'वेतन';

  @override
  String get starterFreelanceIncome => 'फ्रीलांस आय';

  @override
  String get starterInterest => 'ब्याज';

  @override
  String get starterRefunds => 'रिफ़ंड';

  @override
  String get starterOther => 'अन्य';

  @override
  String subcategoryOf(String name, String parent) {
    return '$name, $parent की उपश्रेणी';
  }

  @override
  String get categoryPickerTitle => 'श्रेणी चुनें';

  @override
  String get categoryPickerEmpty => 'चुनने के लिए कोई श्रेणी नहीं है।';

  @override
  String get categoryNone => 'कोई श्रेणी नहीं';

  @override
  String get categoryUncategorized => 'बिना श्रेणी';

  @override
  String get selectionEmpty => 'अभी चुनने के लिए कुछ नहीं है।';

  @override
  String selectionNoMatches(String query) {
    return '\"$query\" से कुछ मेल नहीं खाता।';
  }

  @override
  String get tagPickerTitle => 'टैग चुनें';

  @override
  String get tagPickerEmpty =>
      'आपके पास अभी कोई टैग नहीं है। नया बनाने के लिए नाम लिखें।';

  @override
  String tagCreate(String name) {
    return '\"$name\" टैग बनाएँ';
  }

  @override
  String tagUsage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count बार इस्तेमाल हुआ',
      one: 'एक बार इस्तेमाल हुआ',
      zero: 'अभी इस्तेमाल नहीं हुआ',
    );
    return '$_temp0';
  }

  @override
  String get merchantPickerTitle => 'व्यापारी चुनें';

  @override
  String get merchantSearchLabel => 'खोजें या नया नाम लिखें';

  @override
  String get merchantSearchPrompt =>
      'पहले इस्तेमाल किया गया व्यापारी ढूँढने के लिए कुछ अक्षर लिखें।';

  @override
  String merchantUseName(String name) {
    return '\"$name\" इस्तेमाल करें';
  }

  @override
  String get merchantUseNameHelp =>
      'किसी मौजूदा व्यापारी से मिलाया जाएगा या नया जोड़ा जाएगा';

  @override
  String get merchantNone => 'कोई व्यापारी नहीं';

  @override
  String merchantNoMatches(String query) {
    return '\"$query\" से कोई सहेजा गया व्यापारी मेल नहीं खाता।';
  }

  @override
  String merchantTransactionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count लेन-देन',
      one: '1 लेन-देन',
      zero: 'कोई लेन-देन नहीं',
    );
    return '$_temp0';
  }

  @override
  String get accountTypeCash => 'नकद बटुआ';

  @override
  String get accountTypeBank => 'बैंक खाता';

  @override
  String get accountTypeSavings => 'बचत खाता';

  @override
  String get accountTypeCreditCard => 'क्रेडिट कार्ड';

  @override
  String get accountTypeDebitCard => 'डेबिट कार्ड';

  @override
  String get accountTypePrepaidCard => 'प्रीपेड कार्ड';

  @override
  String get accountTypeDigitalWallet => 'डिजिटल वॉलेट';

  @override
  String get accountTypeUpi => 'UPI / पेमेंट वॉलेट';

  @override
  String get accountTypeLoan => 'ऋण';

  @override
  String get accountTypeInvestment => 'निवेश';

  @override
  String get accountTypeHouseholdLedger => 'घर का खाता';

  @override
  String get accountTypeCustom => 'अन्य खाता';

  @override
  String get balanceSourceManual => 'आपके द्वारा दर्ज';

  @override
  String get balanceSourceCalculated => 'आपकी प्रविष्टियों से गणना';

  @override
  String get balanceSourceImported => 'आयात किए गए स्टेटमेंट से';

  @override
  String get balanceSourceProvider => 'प्रदाता से सिंक किया गया';

  @override
  String get accountStatusActive => 'सक्रिय';

  @override
  String get accountStatusArchived => 'संग्रहित';

  @override
  String get accountStatusClosed => 'बंद';

  @override
  String get accountPickerTitle => 'खाता चुनें';

  @override
  String get accountPickerEmpty =>
      'आपके पास अभी कोई सक्रिय खाता नहीं है। प्रोफ़ाइल → खाते से एक जोड़ें।';

  @override
  String get balanceOwed => 'बकाया';

  @override
  String get balanceInCredit => 'क्रेडिट में';

  @override
  String get balanceOverdrawn => 'ओवरड्रॉन';

  @override
  String get accountBalanceLabel => 'शेष राशि';

  @override
  String get accountSharedReadOnly => 'आपके साथ साझा · सिर्फ़ देखने के लिए';

  @override
  String get accountNotInOverview => 'ओवरव्यू में शामिल नहीं';

  @override
  String get accountsTitle => 'खाते';

  @override
  String get accountAdd => 'खाता जोड़ें';

  @override
  String get accountAddFirst => 'अपना पहला खाता जोड़ें';

  @override
  String get accountsShowArchived => 'संग्रहित और बंद खाते दिखाएँ';

  @override
  String get accountsEmptyTitle => 'अभी कोई खाता नहीं';

  @override
  String get accountsEmptyBody =>
      'हिसाब रखना शुरू करने के लिए नकद बटुआ, बैंक खाता या कार्ड जोड़ें। बैंक जोड़ना कभी ज़रूरी नहीं है।';

  @override
  String accountGroupHeading(String type, int count) {
    return '$type ($count)';
  }

  @override
  String get accountsTotalsTitle => 'कुल (आपके हिसाब से)';

  @override
  String currencyHeading(String currency) {
    return '$currency में';
  }

  @override
  String get netWorthLabel => 'कुल संपत्ति (शुद्ध)';

  @override
  String get assetsLabel => 'संपत्ति';

  @override
  String get liabilitiesLabel => 'कार्ड और ऋण पर बकाया';

  @override
  String get trackedBalanceNote =>
      'शेष राशि आपकी प्रविष्टियों और आयात से गिनी जाती है। बैंक इसकी पुष्टि नहीं करता।';

  @override
  String get providerBalanceNote =>
      'यह शेष राशि जुड़े हुए प्रदाता से सिंक की गई है।';

  @override
  String get accountDetailTitle => 'खाता';

  @override
  String get accountAdjustBalance => 'शेष राशि ठीक करें';

  @override
  String get accountArchive => 'संग्रहित करें';

  @override
  String get accountClose => 'खाता बंद करें';

  @override
  String get accountArchiveConfirmTitle => 'यह खाता संग्रहित करें?';

  @override
  String accountArchiveConfirmBody(String name) {
    return '$name और उसका इतिहास आपकी रिपोर्ट में बना रहेगा, लेकिन वापस लाने तक आप इसमें नए लेन-देन नहीं जोड़ पाएँगे।';
  }

  @override
  String get accountCloseConfirmTitle => 'यह खाता बंद करें?';

  @override
  String accountCloseConfirmBody(String name) {
    return '$name को बंद माना जाएगा और इतिहास में रखा जाएगा। सिर्फ़ शून्य शेष राशि वाला खाता बंद हो सकता है। आप इसे बाद में वापस ला सकते हैं।';
  }

  @override
  String get accountArchived => 'खाता संग्रहित हो गया।';

  @override
  String get accountRestored => 'खाता वापस आ गया।';

  @override
  String get accountClosed => 'खाता बंद हो गया।';

  @override
  String get accountArchivedNotice =>
      'यह खाता संग्रहित है। इसका इतिहास सुरक्षित है; लेन-देन जोड़ने के लिए इसे वापस लाएँ।';

  @override
  String get accountClosedNotice =>
      'यह खाता बंद है। इसका इतिहास सुरक्षित है; फिर से इस्तेमाल करने के लिए इसे वापस लाएँ।';

  @override
  String get creditLimitLabel => 'क्रेडिट सीमा';

  @override
  String get availableCreditLabel => 'उपलब्ध क्रेडिट';

  @override
  String get statementDayLabel => 'स्टेटमेंट की तारीख';

  @override
  String get paymentDueDayLabel => 'भुगतान की आख़िरी तारीख';

  @override
  String dayOfMonth(int day) {
    return 'महीने की $day तारीख';
  }

  @override
  String get notSetLabel => 'तय नहीं';

  @override
  String get transactionAddExpense => 'खर्च जोड़ें';

  @override
  String get transactionAddIncome => 'आय जोड़ें';

  @override
  String get transferAdd => 'ट्रांसफ़र';

  @override
  String get balanceHistoryTitle => 'पिछले 30 दिनों की शेष राशि';

  @override
  String get balanceHistoryEmpty => 'अभी शेष राशि का कोई इतिहास नहीं है।';

  @override
  String balanceHistorySummary(
    String fromDate,
    String fromAmount,
    String toDate,
    String toAmount,
    String low,
    String high,
  ) {
    return 'शेष राशि $fromDate को $fromAmount से $toDate को $toAmount हुई। सबसे कम $low, सबसे ज़्यादा $high।';
  }

  @override
  String get recentTransactionsTitle => 'हाल के लेन-देन';

  @override
  String accountSeeAllTransactions(String name) {
    return '$name के सभी लेन-देन देखें';
  }

  @override
  String get accountNoTransactions => 'इस खाते में अभी कोई लेन-देन नहीं है।';

  @override
  String get accountDetailsTitle => 'जानकारी';

  @override
  String get currencyFieldLabel => 'मुद्रा';

  @override
  String get openingDateLabel => 'शुरुआती तारीख';

  @override
  String get includeInOverviewLabel => 'ओवरव्यू में शामिल करें';

  @override
  String get includeInOverviewHelp =>
      'होम पर दिखने वाली शेष राशि में गिना जाता है।';

  @override
  String get lastReconciledLabel => 'आख़िरी मिलान';

  @override
  String get lastImportLabel => 'आख़िरी आयात';

  @override
  String get notesLabel => 'नोट्स';

  @override
  String get colorTeal => 'हरा-नीला';

  @override
  String get colorBlue => 'नीला';

  @override
  String get colorPurple => 'बैंगनी';

  @override
  String get colorRose => 'गुलाबी';

  @override
  String get colorOrange => 'नारंगी';

  @override
  String get colorSand => 'रेतीला';

  @override
  String get colorGreen => 'हरा';

  @override
  String get colorGrey => 'स्लेटी';

  @override
  String get colorNone => 'कोई रंग नहीं';

  @override
  String get accountNewTitle => 'नया खाता';

  @override
  String get accountEditTitle => 'खाता बदलें';

  @override
  String get accountCreated => 'खाता जुड़ गया।';

  @override
  String get accountSaved => 'खाता सहेजा गया।';

  @override
  String get accountNameLabel => 'खाते का नाम';

  @override
  String get accountNameHelp => 'जैसे \"HDFC बचत\" या \"बटुआ\"।';

  @override
  String get accountTypeLabel => 'प्रकार';

  @override
  String get accountTypeFixed => 'खाता बनने के बाद प्रकार नहीं बदला जा सकता।';

  @override
  String get accountCurrencyChangeHelp =>
      'पहला लेन-देन दर्ज होने तक ही आप मुद्रा बदल सकते हैं।';

  @override
  String get openingBalanceSection => 'शुरुआती शेष राशि';

  @override
  String get openingOwed => 'यह मुझ पर बकाया है';

  @override
  String get openingInCredit => 'यह क्रेडिट में है';

  @override
  String get openingOwedLabel => 'अभी बकाया राशि';

  @override
  String get openingCreditLabel => 'अभी क्रेडिट शेष';

  @override
  String get openingBalanceLabel => 'अभी की शेष राशि';

  @override
  String get openingBalanceHelp =>
      'शून्य से शुरू करने के लिए खाली छोड़ें। खाता ओवरड्रॉन हो तो माइनस चिह्न लगाएँ।';

  @override
  String get openingLiabilityHelp => 'अगर कुछ बकाया नहीं है तो खाली छोड़ें।';

  @override
  String get accountMoreDetails => 'और जानकारी';

  @override
  String get institutionLabel => 'बैंक या प्रदाता का नाम';

  @override
  String get maskedNumberLabel => 'आख़िरी अंक';

  @override
  String get maskedNumberHelp =>
      'सिर्फ़ आख़िरी 2–4 अंक। पूरा कार्ड या खाता नंबर, CVV या PIN कभी न डालें।';

  @override
  String get maskedNumberInvalid => '2 से 4 अंक डालें।';

  @override
  String get accountColorLabel => 'रंग';

  @override
  String get accountCreateButton => 'खाता जोड़ें';

  @override
  String get adjustTitle => 'शेष राशि ठीक करें';

  @override
  String adjustIntro(String name) {
    return 'अगर $name आपके बैंक या वॉलेट से मेल नहीं खाता, तो सुधार दर्ज करें। यह आपके कारण के साथ समायोजन के रूप में सहेजा जाता है, ताकि आपका इतिहास पूरा रहे।';
  }

  @override
  String get adjustCurrentBalance => 'अभी की गिनी गई शेष राशि';

  @override
  String get adjustModeTarget => 'शेष राशि तय करें';

  @override
  String get adjustModeDelta => 'इतना बदलें';

  @override
  String get adjustTargetLabel => 'सही शेष राशि';

  @override
  String get adjustDeltaLabel => 'बदलाव';

  @override
  String get adjustTargetHelp =>
      'खाते में जो शेष राशि दिखनी चाहिए। ओवरड्राफ़्ट के लिए माइनस चिह्न लगाएँ।';

  @override
  String get adjustTargetLiabilityHelp =>
      'कार्ड या ऋण के लिए बकाया राशि को ऋणात्मक संख्या के रूप में डालें, जैसे -2500।';

  @override
  String get adjustDeltaHelp => 'धनात्मक राशि जोड़ती है, ऋणात्मक घटाती है।';

  @override
  String get adjustReasonLabel => 'कारण';

  @override
  String get adjustReasonHelp =>
      'खाते के इतिहास में रखा जाता है, जैसे \"बैंक ऐप से मिलाया\"।';

  @override
  String get adjustReasonTooShort => 'कम से कम 3 अक्षरों का कारण लिखें।';

  @override
  String get adjustDateLabel => 'लागू होने की तारीख';

  @override
  String get adjustButton => 'समायोजन सहेजें';

  @override
  String get adjustDone => 'शेष राशि ठीक हो गई।';

  @override
  String get paymentKindCash => 'नकद';

  @override
  String get paymentKindUpi => 'UPI';

  @override
  String get paymentKindDebitCard => 'डेबिट कार्ड';

  @override
  String get paymentKindCreditCard => 'क्रेडिट कार्ड';

  @override
  String get paymentKindBankTransfer => 'बैंक ट्रांसफ़र';

  @override
  String get paymentKindWallet => 'वॉलेट';

  @override
  String get paymentKindCheque => 'चेक';

  @override
  String get paymentKindOther => 'अन्य';

  @override
  String get paymentNetworkOther => 'अन्य नेटवर्क';

  @override
  String get paymentDefault => 'डिफ़ॉल्ट';

  @override
  String get paymentPickerTitle => 'भुगतान का तरीका चुनें';

  @override
  String get paymentPickerEmpty => 'आपने अभी कोई भुगतान तरीका नहीं जोड़ा है।';

  @override
  String get paymentNone => 'कोई भुगतान तरीका नहीं';

  @override
  String get paymentMethodsTitle => 'भुगतान के तरीके';

  @override
  String get paymentMethodsIntro =>
      'आपने कैसे भुगतान किया, जैसे UPI, नकद या कार्ड, दर्ज करें। सिर्फ़ नाम और आख़िरी अंक रखें — पूरा कार्ड नंबर, CVV या PIN कभी नहीं।';

  @override
  String get paymentShowArchived => 'संग्रहित तरीके दिखाएँ';

  @override
  String get paymentEmptyTitle => 'अभी कोई भुगतान तरीका नहीं';

  @override
  String get paymentEmptyBody =>
      'भुगतान के तरीके जोड़ें ताकि आप तरीके के हिसाब से खर्च देख सकें।';

  @override
  String get paymentAdd => 'भुगतान तरीका जोड़ें';

  @override
  String paymentLinkedTo(String account) {
    return '$account से जुड़ा';
  }

  @override
  String get paymentRemove => 'हटाएँ';

  @override
  String paymentRemoveLabel(String label) {
    return '$label हटाएँ';
  }

  @override
  String get paymentRemoveConfirmTitle => 'यह भुगतान तरीका हटाएँ?';

  @override
  String paymentRemoveConfirmBody(String label) {
    return '$label अब नहीं दिखेगा। अगर लेन-देन में पहले से इस्तेमाल हुआ है, तो इसे संग्रहित किया जाएगा ताकि उनका इतिहास बना रहे।';
  }

  @override
  String get paymentRemoved => 'भुगतान तरीका हटा दिया गया।';

  @override
  String get paymentNewTitle => 'नया भुगतान तरीका';

  @override
  String get paymentEditTitle => 'भुगतान तरीका बदलें';

  @override
  String get paymentCreated => 'भुगतान तरीका जुड़ गया।';

  @override
  String get paymentSaved => 'भुगतान तरीका सहेजा गया।';

  @override
  String get paymentKindLabel => 'प्रकार';

  @override
  String get paymentLabelLabel => 'नाम';

  @override
  String get paymentLabelHelp => 'जैसे \"GPay\" या \"HDFC क्रेडिट कार्ड\"।';

  @override
  String get paymentHintLabel => 'छिपा हुआ संकेत';

  @override
  String get paymentHintHelp =>
      'सिर्फ़ आख़िरी अंक या छिपा हुआ UPI हैंडल, जैसे •••• 4821।';

  @override
  String get paymentHintTooManyDigits =>
      'ज़्यादा से ज़्यादा 4 अंक इस्तेमाल करें। पूरा कार्ड या खाता नंबर, CVV या PIN कभी न डालें।';

  @override
  String get paymentNetworkLabel => 'नेटवर्क';

  @override
  String get paymentAccountLabel => 'किस खाते से भुगतान';

  @override
  String get paymentAccountHelp =>
      'इस तरीके से जिस खाते से पैसे जाते हैं, उससे वैकल्पिक जुड़ाव।';

  @override
  String get paymentAccountUnknown => 'खाता उपलब्ध नहीं';

  @override
  String get paymentMakeDefault => 'डिफ़ॉल्ट के रूप में इस्तेमाल करें';

  @override
  String get navHome => 'होम';

  @override
  String get navTransactions => 'लेन-देन';

  @override
  String get txTypeExpense => 'खर्च';

  @override
  String get txTypeIncome => 'आय';

  @override
  String get txTypeTransfer => 'ट्रांसफ़र';

  @override
  String get txTypeRefund => 'रिफ़ंड';

  @override
  String get txTypeReimbursement => 'प्रतिपूर्ति';

  @override
  String get txTypeAdjustment => 'शेष राशि समायोजन';

  @override
  String get txTypeOpeningBalance => 'शुरुआती शेष राशि';

  @override
  String get txTypeGroupExpense => 'ग्रुप खर्च';

  @override
  String get txTypeSettlement => 'हिसाब चुकता';

  @override
  String get txTypeOther => 'लेन-देन';

  @override
  String get txStatusDraft => 'ड्राफ़्ट';

  @override
  String get txStatusPending => 'लंबित';

  @override
  String get txStatusPosted => 'दर्ज';

  @override
  String get txStatusDeleted => 'हटाया गया';

  @override
  String get txStatusReversed => 'उलटा गया';

  @override
  String get txSourceManual => 'आपके द्वारा दर्ज';

  @override
  String get txSourceImport => 'स्टेटमेंट आयात';

  @override
  String get txSourceReceipt => 'रसीद';

  @override
  String get txSourceRecurring => 'दोहराने वाला नियम';

  @override
  String get txSourceIntegration => 'जुड़ा हुआ प्रदाता';

  @override
  String get txSourceCorrection => 'सुधार';

  @override
  String get txSourceGroup => 'ग्रुप';

  @override
  String get txSourceSystem => 'Montra';

  @override
  String get reconUnreconciled => 'मिलान नहीं हुआ';

  @override
  String get reconMatched => 'मेल खाया';

  @override
  String get reconReconciled => 'मिलान हो गया';

  @override
  String get reconExcluded => 'मिलान से बाहर';

  @override
  String txRefundedAmount(String amount) {
    return '$amount रिफ़ंड हुआ';
  }

  @override
  String get quickAddTitle => 'लेन-देन जोड़ें';

  @override
  String get quickAddExpenseHelp => 'आपने जो पैसे खर्च किए';

  @override
  String get quickAddIncomeHelp => 'आपको जो पैसे मिले';

  @override
  String get quickAddTransferHelp => 'अपने ही खातों के बीच पैसे भेजें';

  @override
  String get transactionsSearchHint => 'विवरण, नोट्स या व्यापारी खोजें';

  @override
  String get searchOpen => 'लेन-देन खोजें';

  @override
  String get searchClose => 'खोज बंद करें';

  @override
  String get filtersTitle => 'फ़िल्टर';

  @override
  String filtersActiveTooltip(int count) {
    return 'फ़िल्टर, $count लागू';
  }

  @override
  String get filtersApply => 'नतीजे दिखाएँ';

  @override
  String get filtersClearAll => 'फ़िल्टर हटाएँ';

  @override
  String filterRemove(String label) {
    return 'फ़िल्टर $label हटाएँ';
  }

  @override
  String get filterDates => 'तारीखें';

  @override
  String get filterType => 'प्रकार';

  @override
  String get filterDirection => 'पैसे आए या गए';

  @override
  String get directionIn => 'पैसे आए';

  @override
  String get directionOut => 'पैसे गए';

  @override
  String get filterAny => 'कोई भी';

  @override
  String get filterOneSelected => '1 चुना गया';

  @override
  String get filterAccounts => 'खाते';

  @override
  String filterAccountsCount(int count) {
    return '$count खाते';
  }

  @override
  String get filterCategories => 'श्रेणियाँ';

  @override
  String filterCategoriesCount(int count) {
    return '$count श्रेणियाँ';
  }

  @override
  String get filterTags => 'टैग';

  @override
  String filterTagsCount(int count) {
    return '$count टैग';
  }

  @override
  String get filterMerchant => 'व्यापारी';

  @override
  String get filterPaymentMethod => 'भुगतान का तरीका';

  @override
  String get filterAmount => 'राशि';

  @override
  String get filterAmountCurrency => 'राशि सीमा की मुद्रा';

  @override
  String get filterMinAmount => 'कम से कम';

  @override
  String get filterMaxAmount => 'ज़्यादा से ज़्यादा';

  @override
  String filterAmountChip(String min, String max, String currency) {
    return 'राशि $min से $max $currency';
  }

  @override
  String get filterMore => 'और फ़िल्टर';

  @override
  String get filterStatus => 'स्थिति';

  @override
  String get filterStatusActive => 'सक्रिय (हटाए नहीं गए)';

  @override
  String get filterStatusDeleted => 'सिर्फ़ हटाए गए';

  @override
  String get filterStatusAll => 'सभी, हटाए गए भी';

  @override
  String get filterSource => 'स्रोत';

  @override
  String get filterReconciliation => 'मिलान';

  @override
  String get filterHasAttachment => 'अटैचमेंट वाले';

  @override
  String get filterWithAttachments => 'अटैचमेंट के साथ';

  @override
  String get filterWithoutAttachments => 'बिना अटैचमेंट';

  @override
  String get filterRecurring => 'दोहराने वाले नियम से';

  @override
  String get filterRecurringOnly => 'सिर्फ़ दोहराने वाले';

  @override
  String get filterNotRecurring => 'दोहराने वाले नहीं';

  @override
  String get filterYes => 'हाँ';

  @override
  String get filterNo => 'नहीं';

  @override
  String get filterSort => 'क्रम';

  @override
  String get sortDateDesc => 'नए पहले';

  @override
  String get sortDateAsc => 'पुराने पहले';

  @override
  String get sortAmountDesc => 'बड़ी राशि पहले';

  @override
  String get sortAmountAsc => 'छोटी राशि पहले';

  @override
  String get rangePickerTitle => 'तारीखें चुनें';

  @override
  String get rangeToday => 'आज';

  @override
  String get rangeYesterday => 'कल';

  @override
  String get rangeThisWeek => 'इस हफ़्ते';

  @override
  String get rangeLastWeek => 'पिछले हफ़्ते';

  @override
  String get rangeThisMonth => 'इस महीने';

  @override
  String get rangeLastMonth => 'पिछले महीने';

  @override
  String get rangeThisYear => 'इस साल';

  @override
  String get rangeLastYear => 'पिछले साल';

  @override
  String get rangeLast7Days => 'पिछले 7 दिन';

  @override
  String get rangeLast30Days => 'पिछले 30 दिन';

  @override
  String get rangeLast90Days => 'पिछले 90 दिन';

  @override
  String get rangeCustom => 'अपनी तारीखें';

  @override
  String get rangeAnyTime => 'कभी भी';

  @override
  String rangeFrom(String date) {
    return '$date से';
  }

  @override
  String rangeUntil(String date) {
    return '$date तक';
  }

  @override
  String get transactionsEmptyTitle => 'अभी कोई लेन-देन नहीं';

  @override
  String get transactionsEmptyBody =>
      'आपका पैसा कहाँ जाता है यह देखने के लिए खर्च और आय जोड़ें। बैंक जोड़ने की ज़रूरत नहीं।';

  @override
  String get transactionAddFirst => 'खर्च जोड़ें';

  @override
  String get transactionsNoMatchTitle => 'कोई लेन-देन मेल नहीं खाता';

  @override
  String get transactionsNoMatchBody =>
      'दूसरी तारीखें आज़माएँ या कुछ फ़िल्टर हटाएँ।';

  @override
  String transactionsEnd(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'कुल $count लेन-देन।',
      one: 'कुल 1 लेन-देन।',
    );
    return '$_temp0';
  }

  @override
  String get loadingMore => 'और लेन-देन लोड हो रहे हैं';

  @override
  String selectionCount(int count) {
    return '$count चुने गए';
  }

  @override
  String get selectionCancel => 'चुनना रद्द करें';

  @override
  String get bulkEditTitle => 'चुने गए बदलें';

  @override
  String bulkEditTitleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count लेन-देन बदलें',
      one: '1 लेन-देन बदलें',
    );
    return '$_temp0';
  }

  @override
  String get bulkSetCategory => 'श्रेणी तय करें';

  @override
  String get bulkClearCategory => 'श्रेणी हटाएँ';

  @override
  String get bulkAddTags => 'टैग जोड़ें';

  @override
  String get bulkRemoveTags => 'टैग हटाएँ';

  @override
  String get bulkMoveAccount => 'दूसरे खाते में ले जाएँ';

  @override
  String get bulkMoveAccountHelp =>
      'सिर्फ़ उसी मुद्रा वाले खाते में। ट्रांसफ़र नहीं ले जाए जा सकते।';

  @override
  String bulkSetCategoryConfirm(int count, String category) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count लेन-देन',
      one: '1 लेन-देन',
    );
    return '$_temp0 की श्रेणी $category करें?';
  }

  @override
  String bulkClearCategoryConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count लेन-देन',
      one: '1 लेन-देन',
    );
    return '$_temp0 से श्रेणी हटाएँ?';
  }

  @override
  String bulkAddTagsConfirm(int count, int tags) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count लेन-देन',
      one: '1 लेन-देन',
    );
    String _temp1 = intl.Intl.pluralLogic(
      tags,
      locale: localeName,
      other: '$tags टैग',
      one: '1 टैग',
    );
    return '$_temp0 में $_temp1 जोड़ें?';
  }

  @override
  String bulkRemoveTagsConfirm(int count, int tags) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count लेन-देन',
      one: '1 लेन-देन',
    );
    String _temp1 = intl.Intl.pluralLogic(
      tags,
      locale: localeName,
      other: '$tags टैग',
      one: '1 टैग',
    );
    return '$_temp0 से $_temp1 हटाएँ?';
  }

  @override
  String bulkMoveConfirm(int count, String account) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count लेन-देन',
      one: '1 लेन-देन',
    );
    return '$_temp0 को $account में ले जाएँ?';
  }

  @override
  String bulkUpdated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count लेन-देन अपडेट हुए।',
      one: '1 लेन-देन अपडेट हुआ।',
    );
    return '$_temp0';
  }

  @override
  String get bulkDeleteTooltip => 'चुने गए हटाएँ';

  @override
  String bulkDeleteConfirmTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count लेन-देन हटाएँ?',
      one: '1 लेन-देन हटाएँ?',
    );
    return '$_temp0';
  }

  @override
  String get bulkDeleteConfirmBody =>
      'इन्हें शेष राशि और रिपोर्ट से हटा दिया जाएगा। कुछ भी मिटाया नहीं जाता: \"हटाए गए\" फ़िल्टर से इन्हें ढूँढकर वापस ला सकते हैं।';

  @override
  String bulkDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count लेन-देन हटाए गए।',
      one: '1 लेन-देन हटाया गया।',
    );
    return '$_temp0';
  }

  @override
  String get amountLabel => 'राशि';

  @override
  String get amountChooseAccountFirst =>
      'मुद्रा तय करने के लिए पहले खाता चुनें।';

  @override
  String get accountFieldLabel => 'खाता';

  @override
  String get accountFieldPlaceholder => 'खाता चुनें';

  @override
  String get validationAccountRequired => 'खाता चुनें।';

  @override
  String get moveAccountHelp =>
      'आप इसे उसी मुद्रा वाले दूसरे खाते में ले जा सकते हैं।';

  @override
  String get dateLabel => 'तारीख';

  @override
  String get categoryFieldLabel => 'श्रेणी';

  @override
  String get merchantFieldLabel => 'व्यापारी';

  @override
  String get merchantNewHelp =>
      'नया व्यापारी: इसी नाम वाले मौजूदा व्यापारी से मिलाया जाएगा, या जोड़ा जाएगा।';

  @override
  String get paymentMethodFieldLabel => 'भुगतान का तरीका';

  @override
  String get tagsLabel => 'टैग';

  @override
  String get tagAdd => 'टैग जोड़ें';

  @override
  String tagRemove(String name) {
    return 'टैग $name हटाएँ';
  }

  @override
  String get descriptionLabel => 'विवरण';

  @override
  String get notesPrivacyHelp =>
      'यहाँ कभी कार्ड नंबर, CVV, PIN या OTP न लिखें।';

  @override
  String get moreOptions => 'और विकल्प';

  @override
  String get statusLabel => 'स्थिति';

  @override
  String get foreignCurrencyToggle => 'दूसरी मुद्रा में भुगतान';

  @override
  String get foreignCurrencyHelp =>
      'ऊपर वह राशि डालें जो आपके खाते से कटी, और यहाँ मूल राशि।';

  @override
  String get originalCurrencyLabel => 'मूल मुद्रा';

  @override
  String get originalAmountLabel => 'मूल राशि';

  @override
  String get originalAmountHelp =>
      'जिस मुद्रा में आपने असल में भुगतान किया, उसकी राशि।';

  @override
  String get fxFeeLabel => 'मुद्रा बदलने का शुल्क';

  @override
  String get fxFeeHelp => 'ऊपर की राशि का हिस्सा, आपके रिकॉर्ड के लिए।';

  @override
  String get fxRateLabel => 'विनिमय दर';

  @override
  String rateWithSource(String rate, String source) {
    return '$rate ($source)';
  }

  @override
  String get expenseNewTitle => 'नया खर्च';

  @override
  String get incomeNewTitle => 'नई आय';

  @override
  String get transactionEditTitle => 'लेन-देन बदलें';

  @override
  String transactionLimitedEdit(String type) {
    return 'यह $type है। यहाँ सिर्फ़ विवरण, नोट्स, व्यापारी और टैग बदले जा सकते हैं।';
  }

  @override
  String get expenseSaved => 'खर्च सहेजा गया।';

  @override
  String get incomeSaved => 'आय सहेजी गई।';

  @override
  String get transactionSaved => 'लेन-देन सहेजा गया।';

  @override
  String get transactionDetailTitle => 'लेन-देन';

  @override
  String get transactionDeletedNotice =>
      'यह लेन-देन हटाया गया है। वापस लाने तक यह शेष राशि या रिपोर्ट में नहीं गिना जाता।';

  @override
  String get transactionSharedReadOnly =>
      'यह लेन-देन आपके साथ साझा किए गए खाते का है। आप इसे देख सकते हैं, बदल नहीं सकते।';

  @override
  String get transactionDeleteConfirmTitle => 'यह लेन-देन हटाएँ?';

  @override
  String get transactionDeleteConfirmBody =>
      'इसे शेष राशि और रिपोर्ट से हटा दिया जाएगा। कुछ मिटाया नहीं जाता; आप इसे बाद में वापस ला सकते हैं।';

  @override
  String get transactionDeleteTransferBody =>
      'यह एक ट्रांसफ़र का हिस्सा है। इसे हटाने से पूरा ट्रांसफ़र हट जाएगा: दोनों खाते और कोई भी शुल्क। आप इसे बाद में वापस ला सकते हैं।';

  @override
  String get transactionDeleted => 'लेन-देन हटाया गया।';

  @override
  String get transactionRestored => 'लेन-देन वापस आ गया।';

  @override
  String get duplicateAction => 'कॉपी बनाएँ';

  @override
  String get duplicateDateTitle => 'कॉपी की तारीख';

  @override
  String get duplicateConfirm => 'कॉपी बनाएँ';

  @override
  String get duplicateCreated => 'कॉपी बन गई।';

  @override
  String get refundAction => 'रिफ़ंड दर्ज करें';

  @override
  String get reimbursementAction => 'प्रतिपूर्ति दर्ज करें';

  @override
  String personalShareLabel(String amount) {
    return 'आपका हिस्सा: $amount';
  }

  @override
  String get correctionLabel => 'सुधार';

  @override
  String get partOfTransfer => 'एक ट्रांसफ़र का हिस्सा';

  @override
  String get partOfTransferHelp => 'दोनों खाते और शुल्क देखें';

  @override
  String get refundOf => 'एक खर्च का रिफ़ंड';

  @override
  String get reimbursementOf => 'एक खर्च की प्रतिपूर्ति';

  @override
  String get groupLinkedRecord => 'एक ग्रुप से जुड़ा';

  @override
  String get groupLinkedRecordHelp =>
      'बदलाव ग्रुप से आते हैं और अपने आप उसके साथ चलते हैं।';

  @override
  String get locationLabel => 'जगह';

  @override
  String get sourceLabel => 'किसने जोड़ा';

  @override
  String get reconciliationLabel => 'मिलान';

  @override
  String get createdLabel => 'बनाया गया';

  @override
  String get updatedLabel => 'आख़िरी बदलाव';

  @override
  String get attachmentsTitle => 'अटैचमेंट';

  @override
  String get attachmentsEmpty => 'कोई फ़ाइल जुड़ी नहीं है।';

  @override
  String get attachmentUnnamed => 'बिना नाम की फ़ाइल';

  @override
  String attachedOn(String time) {
    return '$time को जोड़ा';
  }

  @override
  String get attachmentRemove => 'हटाएँ';

  @override
  String attachmentRemoveLabel(String name) {
    return '$name को इस लेन-देन से हटाएँ';
  }

  @override
  String get attachmentRemoveConfirmTitle => 'यह अटैचमेंट हटाएँ?';

  @override
  String attachmentRemoveConfirmBody(String name) {
    return '$name अब इस लेन-देन से जुड़ी नहीं रहेगी।';
  }

  @override
  String get attachmentRemoved => 'अटैचमेंट हटाया गया।';

  @override
  String sizeBytes(int count) {
    return '$count B';
  }

  @override
  String sizeKilobytes(int count) {
    return '$count KB';
  }

  @override
  String sizeMegabytes(String size) {
    return '$size MB';
  }

  @override
  String get historyTitle => 'इतिहास';

  @override
  String get historyEmpty => 'कोई बदलाव दर्ज नहीं है।';

  @override
  String auditWhenWho(String time, String who) {
    return '$time · $who';
  }

  @override
  String get auditActorYou => 'आपके द्वारा';

  @override
  String get auditActorMontra => 'Montra द्वारा';

  @override
  String get auditCreated => 'बनाया गया';

  @override
  String get auditUpdated => 'बदला गया';

  @override
  String get auditVoided => 'हटाया गया';

  @override
  String get auditRestored => 'वापस लाया गया';

  @override
  String get auditDuplicated => 'कॉपी के रूप में बनाया गया';

  @override
  String get auditBulkUpdated => 'दूसरों के साथ बदला गया';

  @override
  String get auditAttachmentAdded => 'फ़ाइल जोड़ी गई';

  @override
  String get auditAttachmentRemoved => 'फ़ाइल हटाई गई';

  @override
  String get auditRuleCategorized => 'नियम से श्रेणी तय हुई';

  @override
  String get auditRefundAdded => 'रिफ़ंड दर्ज हुआ';

  @override
  String get auditReimbursementAdded => 'प्रतिपूर्ति दर्ज हुई';

  @override
  String get auditTagsAdded => 'टैग जोड़े गए';

  @override
  String get auditTagsRemoved => 'टैग हटाए गए';

  @override
  String auditChanged(String field) {
    return '$field बदला गया';
  }

  @override
  String auditChangedFromTo(String field, String from, String to) {
    return '$field: $from → $to';
  }

  @override
  String auditLinkedAmount(String amount) {
    return 'राशि: $amount';
  }

  @override
  String get refundTitle => 'रिफ़ंड दर्ज करें';

  @override
  String get reimbursementTitle => 'प्रतिपूर्ति दर्ज करें';

  @override
  String get refundOriginalTitle => 'मूल खर्च';

  @override
  String get refundOriginalLabel => 'खर्च';

  @override
  String get refundAlreadyLabel => 'पहले से रिफ़ंड या प्रतिपूर्ति';

  @override
  String get refundCapNote =>
      'रिफ़ंड और प्रतिपूर्ति मिलाकर मूल राशि से ज़्यादा नहीं हो सकते। सहेजते समय Montra इसकी जाँच करता है।';

  @override
  String get refundHelp =>
      'जो पैसे विक्रेता ने लौटाए। इससे आपका खर्च कम होता है।';

  @override
  String get reimbursementHelp =>
      'जो पैसे किसी ने आपको लौटाए, जैसे नियोक्ता ने। इससे आपका खर्च कम होता है।';

  @override
  String get refundAmountLabel => 'लौटाई गई राशि';

  @override
  String get refundAccountLabel => 'किस खाते में मिला';

  @override
  String get refundAccountHelp => 'डिफ़ॉल्ट रूप से मूल खर्च वाला खाता।';

  @override
  String get refundCorrectionLabel => 'यह एक सुधार है';

  @override
  String get refundCorrectionHelp =>
      'मूल राशि से ज़्यादा की अनुमति देता है, जैसे गलत मूल राशि ठीक करने के लिए। सिर्फ़ जान-बूझकर इस्तेमाल करें।';

  @override
  String get refundNotAllowedTitle => 'इसका रिफ़ंड नहीं हो सकता';

  @override
  String get refundNotAllowedBody =>
      'सिर्फ़ आपके अपने, न हटाए गए खर्चों का रिफ़ंड या प्रतिपूर्ति हो सकती है।';

  @override
  String get refundSave => 'रिफ़ंड सहेजें';

  @override
  String get reimbursementSave => 'प्रतिपूर्ति सहेजें';

  @override
  String get refundSaved => 'रिफ़ंड सहेजा गया।';

  @override
  String get reimbursementSaved => 'प्रतिपूर्ति सहेजी गई।';

  @override
  String get transferNewTitle => 'नया ट्रांसफ़र';

  @override
  String get transferIntro =>
      'अपने ही खातों के बीच पैसे भेजें। ट्रांसफ़र को आय या खर्च नहीं गिना जाता।';

  @override
  String get transferFromLabel => 'कहाँ से';

  @override
  String get transferToLabel => 'कहाँ';

  @override
  String get transferAmountLabel => 'भेजी गई राशि';

  @override
  String get transferAmountHelp => 'जिस खाते से जा रहा है, उसकी मुद्रा में।';

  @override
  String get transferFxSection => 'अलग-अलग मुद्राएँ';

  @override
  String transferFxHelp(String from, String to) {
    return 'पैसे $from में जाते हैं और $to में पहुँचते हैं। जो राशि पहुँची या विनिमय दर डालें।';
  }

  @override
  String get transferFxReceived => 'मिली राशि';

  @override
  String get transferFxRate => 'विनिमय दर';

  @override
  String get transferToAmountLabel => 'मिली राशि';

  @override
  String transferRateLabel(String from, String to) {
    return '1 $from पर $to';
  }

  @override
  String get transferRateHelp => 'एक सटीक दर, जैसे 0.0119।';

  @override
  String get transferRateInvalid => 'धनात्मक दर डालें, जैसे 83.12।';

  @override
  String get transferFeeLabel => 'शुल्क';

  @override
  String get transferFeeHelp =>
      'जिस खाते से पैसे जाते हैं उससे कटता है। अलग खर्च के रूप में सहेजा जाता है।';

  @override
  String get transferSave => 'ट्रांसफ़र सहेजें';

  @override
  String get transferSaved => 'ट्रांसफ़र सहेजा गया।';

  @override
  String get transferDetailTitle => 'ट्रांसफ़र';

  @override
  String transferBetween(String from, String to) {
    return '$from → $to';
  }

  @override
  String get transferNotIncomeNote =>
      'ट्रांसफ़र आपके अपने पैसे को इधर-उधर करते हैं, इसलिए इन्हें आय या खर्च नहीं गिना जाता।';

  @override
  String transferSentFrom(String account) {
    return '$account से भेजा';
  }

  @override
  String transferReceivedIn(String account) {
    return '$account में मिला';
  }

  @override
  String transferRateShown(String from, String to) {
    return 'विनिमय दर (प्रति $from $to)';
  }

  @override
  String get transferLegsTitle => 'इस रूप में दर्ज';

  @override
  String get transferLegOut => 'पहले खाते से गए पैसे';

  @override
  String get transferLegIn => 'दूसरे खाते में आए पैसे';

  @override
  String get transferVoidedNotice =>
      'यह ट्रांसफ़र हटाया गया है। वापस लाने तक कोई भी खाता इसे नहीं गिनता।';

  @override
  String get transferDelete => 'ट्रांसफ़र हटाएँ';

  @override
  String get transferDeleteConfirmTitle => 'यह ट्रांसफ़र हटाएँ?';

  @override
  String get transferDeleteConfirmBody =>
      'दोनों हिस्से साथ में हटेंगे। कुछ मिटाया नहीं जाता; आप इसे बाद में वापस ला सकते हैं।';

  @override
  String get transferDeleteConfirmBodyFee =>
      'दोनों हिस्से और शुल्क साथ में हटेंगे। कुछ मिटाया नहीं जाता; आप इसे बाद में वापस ला सकते हैं।';

  @override
  String get transferDeleted => 'ट्रांसफ़र हटाया गया।';

  @override
  String get transferRestore => 'ट्रांसफ़र वापस लाएँ';

  @override
  String get transferRestored => 'ट्रांसफ़र वापस आ गया।';

  @override
  String get widgetBalances => 'शेष राशि';

  @override
  String get widgetBalancesHelp =>
      'हर मुद्रा में गिनी गई कुल संपत्ति, संपत्ति और बकाया';

  @override
  String get widgetCashFlow => 'पैसों का आना-जाना';

  @override
  String get widgetCashFlowHelp => 'इस अवधि की आय, खर्च और शुद्ध नकदी प्रवाह';

  @override
  String get widgetIncomeVsExpense => 'आय बनाम खर्च';

  @override
  String get widgetIncomeVsExpenseHelp =>
      'आने और जाने वाले पैसों की तुलना का चार्ट';

  @override
  String get widgetCashFlowTrend => 'नकदी प्रवाह का रुझान';

  @override
  String get widgetCashFlowTrendHelp => 'समय के साथ आय और खर्च';

  @override
  String get widgetCategoryBreakdown => 'श्रेणी के अनुसार खर्च';

  @override
  String get widgetCategoryBreakdownHelp => 'आपका पैसा कहाँ गया';

  @override
  String get widgetTopMerchants => 'सबसे ज़्यादा खर्च वाले व्यापारी';

  @override
  String get widgetTopMerchantsHelp => 'किसके पास सबसे ज़्यादा खर्च किया';

  @override
  String get widgetRecentTransactions => 'हाल के लेन-देन';

  @override
  String get widgetRecentTransactionsHelp => 'आपकी ताज़ा प्रविष्टियाँ';

  @override
  String get widgetDataCoverage => 'इन आँकड़ों के बारे में';

  @override
  String get widgetDataCoverageHelp =>
      'आँकड़े किस पर आधारित हैं और कैसे गिने जाते हैं';

  @override
  String get widgetUnknownHelp => 'ऐप के नए संस्करण में उपलब्ध';

  @override
  String get widgetSettingsTitle => 'होम को अपने हिसाब से बनाएँ';

  @override
  String get widgetSettingsIntro =>
      'होम पर क्या और किस क्रम में दिखे, यह चुनें। इससे सिर्फ़ लेआउट बदलता है, आपके रिकॉर्ड नहीं।';

  @override
  String widgetPosition(int position, int total) {
    return '$total में से $positionवाँ स्थान';
  }

  @override
  String widgetMoveUp(String name) {
    return '$name को ऊपर ले जाएँ';
  }

  @override
  String widgetMoveDown(String name) {
    return '$name को नीचे ले जाएँ';
  }

  @override
  String get widgetSettingsSaved => 'होम का लेआउट सहेजा गया।';

  @override
  String get widgetSettingsResetTitle => 'होम का लेआउट रीसेट करें?';

  @override
  String get widgetSettingsResetBody =>
      'सभी विजेट फिर से डिफ़ॉल्ट क्रम में दिखेंगे।';

  @override
  String get widgetSettingsResetDone => 'होम का लेआउट रीसेट हो गया।';

  @override
  String get dashboardCustomize => 'होम को अपने हिसाब से बनाएँ';

  @override
  String get dashboardChangePeriod => 'अवधि बदलें';

  @override
  String get dashboardLoading => 'आपका ओवरव्यू लोड हो रहा है';

  @override
  String get dashboardLayoutFallback =>
      'हम आपका होम लेआउट लोड नहीं कर सके, इसलिए डिफ़ॉल्ट दिखाया जा रहा है।';

  @override
  String get dashboardCurrencyTitle => 'मुद्रा';

  @override
  String dashboardCurrencyChip(String currency) {
    return '$currency के आँकड़े दिखाएँ';
  }

  @override
  String get dashboardCurrencyNote =>
      'अलग-अलग मुद्राओं की राशियाँ अलग दिखाई जाती हैं और कभी जोड़ी नहीं जातीं।';

  @override
  String get dashboardGetStartedTitle => 'चलिए हिसाब रखना शुरू करें';

  @override
  String get dashboardGetStartedBody =>
      'अपना बटुआ या बैंक खाता जैसा कोई खाता जोड़ें, फिर खर्च और आय दर्ज करें। बैंक जोड़ना कभी ज़रूरी नहीं।';

  @override
  String get dashboardViewAccounts => 'खाते';

  @override
  String get dashboardSeeAllTransactions => 'सभी लेन-देन देखें';

  @override
  String get dashboardNoAccounts =>
      'अभी आपके ओवरव्यू में कोई खाता शामिल नहीं है।';

  @override
  String dashboardAccountCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count खातों में',
      one: '1 खाते में',
    );
    return '$_temp0';
  }

  @override
  String dashboardNoActivity(String period) {
    return '$period में कोई आय या खर्च नहीं।';
  }

  @override
  String dashboardNoSpending(String period) {
    return '$period में कोई खर्च नहीं।';
  }

  @override
  String dashboardNoMerchants(String period) {
    return '$period में व्यापारियों पर कोई खर्च नहीं।';
  }

  @override
  String get dashboardNoRecent => 'अभी कोई लेन-देन नहीं।';

  @override
  String dashboardPreviousValue(String amount) {
    return 'पिछली अवधि: $amount';
  }

  @override
  String dashboardWithPrevious(String now, String before) {
    return '$now; पिछली अवधि $before';
  }

  @override
  String get dashboardPreviousExplained =>
      'पिछली अवधि इतनी ही लंबी है, ठीक इससे पहले की।';

  @override
  String dashboardSpendingDetail(String gross, String refunds) {
    return '$gross खर्च हुए, जिनमें से $refunds रिफ़ंड और प्रतिपूर्ति में लौटे।';
  }

  @override
  String dashboardTransactionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count लेन-देन पर आधारित',
      one: '1 लेन-देन पर आधारित',
    );
    return '$_temp0';
  }

  @override
  String get dashboardHowCalculated => 'ये आँकड़े कैसे गिने जाते हैं';

  @override
  String get incomeLabel => 'आय';

  @override
  String get spendingLabel => 'खर्च';

  @override
  String get netCashFlowLabel => 'शुद्ध नकदी प्रवाह';

  @override
  String get netCashFlowPositive => 'जितना गया उससे ज़्यादा आया।';

  @override
  String get netCashFlowNegative => 'जितना आया उससे ज़्यादा गया।';

  @override
  String get savingsRateLabel => 'बचत दर';

  @override
  String incomeVsExpenseSummary(String period, String income, String spending) {
    return '$period में आय $income और खर्च $spending रहा।';
  }

  @override
  String get trendUnitDay => 'दिन';

  @override
  String get trendUnitWeek => 'हफ़्ते';

  @override
  String get trendUnitMonth => 'महीने';

  @override
  String trendSummary(
    String unit,
    String period,
    int count,
    String amount,
    String bucket,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count अवधियों में गतिविधि',
      one: '1 अवधि में गतिविधि',
    );
    return '$period में हर $unit की आय और खर्च, $_temp0। सबसे ज़्यादा खर्च: $amount ($bucket)।';
  }

  @override
  String trendBucketStarting(String date) {
    return '$date से';
  }

  @override
  String trendRow(String income, String spending, String net) {
    return 'आए $income · गए $spending · शुद्ध $net';
  }

  @override
  String categorySummary(String name, String amount, String share, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count श्रेणियाँ दिखाई गईं।',
      one: '1 श्रेणी दिखाई गई।',
    );
    return 'सबसे ज़्यादा खर्च $name पर हुआ: $amount, कुल का $share। $_temp0';
  }

  @override
  String categoryShareDetail(String share, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count लेन-देन',
      one: '1 लेन-देन',
    );
    return '$share · $_temp0';
  }

  @override
  String categoryTableValue(String amount, String share) {
    return '$amount ($share)';
  }

  @override
  String get coverageTransactions => 'लेन-देन';

  @override
  String coverageTransactionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'इस अवधि में $count',
      one: 'इस अवधि में 1',
      zero: 'कोई नहीं',
    );
    return '$_temp0';
  }

  @override
  String get coverageSpan => 'कब से – कब तक';

  @override
  String get coverageUncategorized => 'बिना श्रेणी';

  @override
  String get coveragePending => 'लंबित (गिने नहीं गए)';

  @override
  String get coverageLastImport => 'आख़िरी स्टेटमेंट आयात';

  @override
  String get coverageNoImports => 'अभी कोई आयात नहीं';

  @override
  String get onboardingTitle => 'Montra सेट करें';

  @override
  String onboardingProgress(int step, int total) {
    return '$total में से चरण $step';
  }

  @override
  String get onboardingSkipAll => 'सेटअप छोड़ें';

  @override
  String get onboardingSkipStep => 'यह चरण छोड़ें';

  @override
  String onboardingWelcomeTitle(String name) {
    return 'स्वागत है, $name';
  }

  @override
  String get onboardingWelcomeBody =>
      'कुछ छोटे, वैकल्पिक चरणों में Montra तैयार हो जाएगा। आप कोई भी चरण छोड़ सकते हैं और बाद में सब बदल सकते हैं।';

  @override
  String get onboardingPrivacyTitle => 'आपका डेटा आपका ही रहता है';

  @override
  String get onboardingPrivacyNotSold =>
      'Montra आपका वित्तीय डेटा कभी नहीं बेचता और कभी सार्वजनिक नहीं करता।';

  @override
  String get onboardingPrivacyNoBank =>
      'बैंक जोड़ने की ज़रूरत नहीं। खाते और लेन-देन खुद जोड़ें।';

  @override
  String get onboardingPrivacyNoSms =>
      'Montra आपके SMS या नोटिफ़िकेशन नहीं पढ़ता। अगर किसी सुविधा को कभी अनुमति चाहिए, तो हम पहले कारण बताएँगे।';

  @override
  String get onboardingPrivacyControl =>
      'आप कभी भी प्रोफ़ाइल से अपना डेटा निर्यात या हटा सकते हैं।';

  @override
  String get onboardingRegionTitle => 'मुद्रा और समय क्षेत्र';

  @override
  String get onboardingRegionBody =>
      'Montra इन्हें कुल और तारीखों के लिए इस्तेमाल करता है। बाद में बदलने से पुरानी राशियाँ या तारीखें नहीं बदलतीं।';

  @override
  String get onboardingCurrencyLabel => 'मुख्य मुद्रा';

  @override
  String get onboardingCurrencyHelp =>
      'खाते फिर भी दूसरी मुद्राएँ इस्तेमाल कर सकते हैं।';

  @override
  String get onboardingTimezoneLabel => 'समय क्षेत्र';

  @override
  String get onboardingTimezoneHelp =>
      'यह तय करता है कि लेन-देन किस दिन का है।';

  @override
  String onboardingUseDeviceTimezone(String timezone) {
    return 'इस डिवाइस का समय क्षेत्र इस्तेमाल करें ($timezone)';
  }

  @override
  String get onboardingCountryLabel => 'देश या क्षेत्र कोड';

  @override
  String get onboardingCountryHelp => 'दो अक्षर, जैसे IN।';

  @override
  String get onboardingCountryInvalid => 'दो अक्षर इस्तेमाल करें, जैसे IN।';

  @override
  String get onboardingIncomeTitle => 'महीने की आय (वैकल्पिक)';

  @override
  String get onboardingIncomeBody =>
      'रुपये में महीने की आय का मोटा अंदाज़ा सिर्फ़ Montra को सुझाव बेहतर करने में मदद करता है। यह कभी किसी को नहीं दिखता, और आप इसे छोड़ सकते हैं।';

  @override
  String get incomeUnder25k => '₹25,000 से कम';

  @override
  String get income25k50k => '₹25,000 – ₹50,000';

  @override
  String get income50k1l => '₹50,000 – ₹1 लाख';

  @override
  String get income1l2l => '₹1 लाख – ₹2 लाख';

  @override
  String get income2l5l => '₹2 लाख – ₹5 लाख';

  @override
  String get incomeAbove5l => '₹5 लाख से ज़्यादा';

  @override
  String get incomePreferNot => 'बताना नहीं चाहते';

  @override
  String get onboardingAccountsTitle => 'खाता जोड़ें (वैकल्पिक)';

  @override
  String get onboardingAccountsBody =>
      'जिस बटुए या खाते का सबसे ज़्यादा इस्तेमाल करते हैं, उससे शुरू करें। आप कभी भी और जोड़ सकते हैं।';

  @override
  String get onboardingAddAnother => 'एक और खाता जोड़ें';

  @override
  String get onboardingCategoriesTitle => 'आपकी शुरुआती श्रेणियाँ';

  @override
  String get onboardingCategoriesBody =>
      'हमने ये श्रेणियाँ जोड़ दी हैं ताकि आप तुरंत शुरू कर सकें। आप बाद में श्रेणियों का नाम बदल सकते हैं, नई जोड़ सकते हैं या संग्रहित कर सकते हैं।';

  @override
  String get onboardingCategoriesSpending => 'खर्च के लिए';

  @override
  String get onboardingCategoriesIncome => 'आय के लिए';

  @override
  String get onboardingFinish => 'सेटअप पूरा करें';

  @override
  String get onboardingFinishNote => 'आप यह सब बाद में बदल सकते हैं।';

  @override
  String get profileAccountsTitle => 'खाते';

  @override
  String get profileAccountsSubtitle => 'बटुए, बैंक खाते, कार्ड और ऋण';

  @override
  String get profilePaymentMethodsTitle => 'भुगतान के तरीके';

  @override
  String get profilePaymentMethodsSubtitle => 'UPI, नकद, कार्ड और भी';

  @override
  String get profileHomeLayout => 'होम का लेआउट';

  @override
  String get profileHomeLayoutSubtitle =>
      'होम विजेट दिखाएँ, छिपाएँ और क्रम बदलें';

  @override
  String get widgetUnknownTitle => 'नए संस्करण का विजेट';

  @override
  String get paymentArchivedResult =>
      'संग्रहित किया गया क्योंकि लेन-देन में इसका इस्तेमाल हुआ है। आप इसे संग्रहित सूची से वापस ला सकते हैं।';

  @override
  String get paymentRestored => 'भुगतान तरीका वापस आ गया।';

  @override
  String paymentRestoreLabel(String label) {
    return '$label वापस लाएँ';
  }

  @override
  String get auditReconciled => 'मिलान हुआ';

  @override
  String get auditUnreconciled => 'मिलान हटाया गया';

  @override
  String get auditImported => 'आयात किया गया';

  @override
  String get auditReceiptLinked => 'रसीद जोड़ी गई';

  @override
  String get auditTagsChanged => 'टैग बदले गए';

  @override
  String get auditOther => 'बदला गया';

  @override
  String get auditActorImport => 'आयात से';

  @override
  String get auditActorRecurring => 'दोहराने वाले नियम से';

  @override
  String get auditActorIntegration => 'जुड़े हुए प्रदाता से';

  @override
  String get trendUnitYear => 'साल';

  @override
  String get noteExcludesTransfers =>
      'आपके खातों के बीच ट्रांसफ़र, शेष राशि समायोजन और शुरुआती शेष राशि को आय या खर्च नहीं गिना जाता।';

  @override
  String get noteRefundsReduceSpending =>
      'रिफ़ंड और प्रतिपूर्ति खर्च कम करते हैं; ग्रुप खर्च में सिर्फ़ आपका हिस्सा गिना जाता है।';

  @override
  String get noteCurrenciesSeparate =>
      'अलग-अलग मुद्राओं की राशियाँ अलग दिखाई जाती हैं और कभी जोड़ी नहीं जातीं।';

  @override
  String get noteBalancesTracked =>
      'शेष राशि आपकी प्रविष्टियों और आयात से गिनी जाती है; बैंक इसकी पुष्टि नहीं करता।';

  @override
  String possibleDuplicateNoticeReasons(int count, String reasons) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count दूसरे लेन-देन',
      one: 'एक दूसरे लेन-देन',
    );
    return 'सहेजा गया। यह $_temp0 जैसा लगता है ($reasons)। कुछ भी मिलाया नहीं गया।';
  }

  @override
  String get duplicateSameAccountAmount => 'वही खाता और राशि';

  @override
  String get duplicateSameDate => 'वही तारीख';

  @override
  String duplicateDaysApart(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days दिन का अंतर',
      one: '1 दिन का अंतर',
      zero: 'उसी दिन',
    );
    return '$_temp0';
  }

  @override
  String get duplicateSameDescription => 'वही विवरण';

  @override
  String get filterUncategorized => 'बिना श्रेणी';

  @override
  String get filterUncategorizedHelp =>
      'सिर्फ़ वे लेन-देन जिनकी अभी कोई श्रेणी नहीं है।';

  @override
  String ruleRefundExceedsRemaining(String remaining, String currency) {
    return 'रिफ़ंड और प्रतिपूर्ति मूल राशि से ज़्यादा नहीं हो सकते। अभी $remaining $currency रिफ़ंड हो सकते हैं। अगर यह जान-बूझकर है तो इसे सुधार के रूप में चिह्नित करें।';
  }

  @override
  String get ruleOriginalNotRefundable =>
      'सिर्फ़ आपके अपने, न हटाए गए खर्चों का रिफ़ंड या प्रतिपूर्ति हो सकती है।';

  @override
  String ruleCurrencyMismatch(String currency) {
    return 'मूल राशि वाली मुद्रा ($currency) ही इस्तेमाल करें।';
  }

  @override
  String get ruleAccountInactive =>
      'यह खाता संग्रहित या बंद है। लेन-देन जोड़ने या बदलने के लिए इसे वापस लाएँ।';

  @override
  String get ruleGroupLinked =>
      'यह एक ग्रुप रिकॉर्ड से जुड़ा है, इसलिए इसे ग्रुप से बदलें।';

  @override
  String get ruleHasLinkedRefunds =>
      'पहले जुड़े हुए रिफ़ंड या प्रतिपूर्ति हटाएँ।';

  @override
  String get frequencyDaily => 'रोज़';

  @override
  String get frequencyWeekly => 'हर हफ़्ते';

  @override
  String get frequencyBiweekly => 'हर 2 हफ़्ते';

  @override
  String get frequencyMonthly => 'हर महीने';

  @override
  String get frequencyBimonthly => 'हर 2 महीने';

  @override
  String get frequencyQuarterly => 'हर 3 महीने';

  @override
  String get frequencySemiannual => 'हर 6 महीने';

  @override
  String get frequencyYearly => 'हर साल';

  @override
  String get frequencyCustom => 'अपने हिसाब से';

  @override
  String frequencyEveryDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'हर $count दिन',
      one: 'हर दिन',
    );
    return '$_temp0';
  }

  @override
  String frequencyEveryWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'हर $count हफ़्ते',
      one: 'हर हफ़्ते',
    );
    return '$_temp0';
  }

  @override
  String frequencyEveryMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'हर $count महीने',
      one: 'हर महीने',
    );
    return '$_temp0';
  }

  @override
  String frequencyEveryYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'हर $count साल',
      one: 'हर साल',
    );
    return '$_temp0';
  }

  @override
  String get intervalUnitDays => 'दिन';

  @override
  String get intervalUnitWeeks => 'हफ़्ते';

  @override
  String get intervalUnitMonths => 'महीने';

  @override
  String get intervalUnitYears => 'साल';

  @override
  String get reminderDaysLabel => 'मुझे याद दिलाएँ';

  @override
  String get reminderOnTheDay => 'उसी दिन';

  @override
  String reminderDaysBefore(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days दिन पहले',
      one: '1 दिन पहले',
    );
    return '$_temp0';
  }

  @override
  String reminderDaysHelp(int max) {
    return 'ज़्यादा से ज़्यादा $max चुनें।';
  }

  @override
  String get reminderNone => 'कोई रिमाइंडर नहीं।';

  @override
  String get personPickerTitle => 'व्यक्ति चुनें';

  @override
  String get personPickerEmpty =>
      'अभी कोई कनेक्शन नहीं है। Montra में जिनसे आप जुड़ते हैं, वे यहाँ दिखेंगे।';

  @override
  String get groupMemberPickerTitle => 'समूह का सदस्य चुनें';

  @override
  String get groupMemberPickerEmpty => 'इस समूह में अभी कोई और नहीं है।';

  @override
  String get groupPickerTitle => 'समूह चुनें';

  @override
  String get groupPickerEmpty => 'आप अभी किसी समूह में नहीं हैं।';

  @override
  String get groupNone => 'कोई समूह नहीं';

  @override
  String groupMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count सदस्य',
      one: '1 सदस्य',
    );
    return '$_temp0';
  }

  @override
  String get transactionPickerTitle => 'लेन-देन चुनें';

  @override
  String get transactionPickerSearch => 'लेन-देन खोजें';

  @override
  String get transactionPickerEmpty => 'कोई मिलता-जुलता लेन-देन नहीं मिला।';

  @override
  String get recurringTitle => 'नियमित लेन-देन';

  @override
  String get recurringAdd => 'नियमित लेन-देन जोड़ें';

  @override
  String get recurringAddFirst => 'पहला नियमित लेन-देन जोड़ें';

  @override
  String get recurringEmptyTitle => 'अभी कोई नियमित लेन-देन नहीं';

  @override
  String get recurringEmptyBody =>
      'किराया, वेतन या हर महीने का ट्रांसफ़र एक बार जोड़ें। तारीख़ आने पर Montra उसे दिखाएगा, और क्या दर्ज करना है, यह आप तय करेंगे।';

  @override
  String get recurringNoMatchTitle => 'इन फ़िल्टर से कुछ नहीं मिला';

  @override
  String get recurringNoMatchBody => 'कोई दूसरा प्रकार या स्थिति चुनकर देखें।';

  @override
  String get recurringFilterAllKinds => 'सभी प्रकार';

  @override
  String get recurringFilterExpenses => 'खर्च';

  @override
  String get recurringFilterIncome => 'आय';

  @override
  String get recurringFilterTransfers => 'ट्रांसफ़र';

  @override
  String get recurringFilterBills => 'बिल';

  @override
  String get recurringFilterAllStatuses => 'कोई भी स्थिति';

  @override
  String get recurringStatusActive => 'चालू';

  @override
  String get recurringStatusPaused => 'रुका हुआ';

  @override
  String get recurringStatusEnded => 'ख़त्म';

  @override
  String recurringStatusSemantics(String status) {
    return 'स्थिति: $status';
  }

  @override
  String get recurringKindExpense => 'खर्च';

  @override
  String get recurringKindIncome => 'आय';

  @override
  String get recurringKindTransfer => 'ट्रांसफ़र';

  @override
  String get recurringKindBill => 'बिल';

  @override
  String get recurringKindSubscription => 'सब्सक्रिप्शन';

  @override
  String get recurringKindGroupExpense => 'समूह का खर्च';

  @override
  String get recurringKindOther => 'नियमित';

  @override
  String get recurringKindLabel => 'प्रकार';

  @override
  String get recurringKindFixed =>
      'बदलते समय प्रकार वही रहता है। प्रकार बदलना हो तो नया नियमित लेन-देन जोड़ें।';

  @override
  String recurringNextOn(String date) {
    return 'अगली बार: $date';
  }

  @override
  String get recurringVaries => 'बदलती है';

  @override
  String get recurringAmountVaries => 'राशि हर बार अलग';

  @override
  String get recurringNewTitle => 'नया नियमित लेन-देन';

  @override
  String get recurringEditTitle => 'नियमित लेन-देन बदलें';

  @override
  String get recurringEditFutureNote =>
      'बदलाव इस बार और आगे के लिए लागू होंगे। पिछले वैसे ही रहेंगे।';

  @override
  String get recurringNameLabel => 'नाम';

  @override
  String get recurringNameHelp => 'जैसे \"किराया\" या \"वेतन\"।';

  @override
  String get recurringAmountSection => 'राशि और खाता';

  @override
  String get recurringVariableLabel => 'राशि हर बार बदलती है';

  @override
  String get recurringVariableHelp => 'दर्ज करते समय आप राशि लिखेंगे।';

  @override
  String get recurringAmountLabel => 'अनुमानित राशि';

  @override
  String get recurringFromAccountLabel => 'किस खाते से';

  @override
  String get recurringToAccountLabel => 'किस खाते में';

  @override
  String get recurringAccountRequired => 'खाता चुनें।';

  @override
  String get recurringAutoPostLabel => 'अपने-आप दर्ज करें';

  @override
  String get recurringAutoPostHelp =>
      'तारीख़ आने पर Montra आपके लिए लेन-देन जोड़ देगा।';

  @override
  String get recurringAutoPostNeedsAmount =>
      'इसके लिए तय राशि और खाता ज़रूरी है।';

  @override
  String get recurringAutoPostOn => 'अपने-आप दर्ज होता है';

  @override
  String get recurringAutoPostOff => 'हर बार आप पुष्टि करते हैं';

  @override
  String get recurringMoreSection => 'और जानकारी';

  @override
  String get recurringCreateButton => 'नियमित लेन-देन जोड़ें';

  @override
  String get recurringCreated => 'नियमित लेन-देन जुड़ गया।';

  @override
  String get recurringSaved => 'इस बार और आगे के लिए सेव हो गया।';

  @override
  String get recurringDetailTitle => 'नियमित लेन-देन';

  @override
  String get recurringUpcomingTitle => 'आगे आने वाले';

  @override
  String get recurringHistoryTitle => 'पिछले';

  @override
  String get recurringDetailsTitle => 'जानकारी';

  @override
  String get recurringNextLabel => 'अगली बार';

  @override
  String get recurringNothingUpcoming => 'आगे कुछ नहीं है।';

  @override
  String get recurringNoHistory => 'अभी तक कुछ दर्ज नहीं हुआ।';

  @override
  String get recurringCompletedLabel => 'अब तक दर्ज या भुगतान';

  @override
  String get recurringManagedByBill =>
      'यह शेड्यूल एक बिल का है। इसे बिल से ही बदलें या रोकें।';

  @override
  String get recurringManagedBySubscription =>
      'यह शेड्यूल एक सब्सक्रिप्शन का है। इसे सब्सक्रिप्शन से ही संभालें।';

  @override
  String get recurringManagedByGroup =>
      'यह एक समूह का साझा खर्च है। इसे समूह से ही संभालें।';

  @override
  String get recurringOpenBill => 'बिल खोलें';

  @override
  String get recurringSharedReadOnly => 'आपके साथ साझा · सिर्फ़ देखने के लिए';

  @override
  String get recurringPausedNotice =>
      'रुका हुआ है। दोबारा चालू करने तक कुछ नया नहीं जुड़ेगा।';

  @override
  String get recurringEndedNotice => 'ख़त्म हो गया। पिछला रिकॉर्ड रखा गया है।';

  @override
  String get recurringPause => 'रोकें';

  @override
  String get recurringResume => 'फिर से चालू करें';

  @override
  String get recurringSkipNext => 'अगली बार छोड़ें';

  @override
  String get recurringStop => 'बंद करें';

  @override
  String get recurringPaused => 'रोक दिया गया।';

  @override
  String get recurringResumed => 'फिर से चालू हो गया।';

  @override
  String get recurringSkippedNext => 'अगली बार छोड़ दी गई।';

  @override
  String get recurringStopped => 'बंद कर दिया गया। पिछला रिकॉर्ड रखा गया है।';

  @override
  String get recurringSkipNextConfirmTitle => 'अगली बार छोड़ें?';

  @override
  String recurringSkipNextConfirmBody(String name) {
    return '$name की अगली बार छोड़ दी जाएगी। उसके बाद वाली पहले जैसी रहेंगी।';
  }

  @override
  String get recurringStopConfirmTitle => 'यह नियमित लेन-देन बंद करें?';

  @override
  String recurringStopConfirmBody(String name) {
    return '$name आगे नहीं जुड़ेगा। जो पहले दर्ज हो चुका है, वह रहेगा।';
  }

  @override
  String get recurringDeleteConfirmTitle => 'यह नियमित लेन-देन हटाएँ?';

  @override
  String recurringDeleteConfirmBody(String name) {
    return 'अगर $name कभी इस्तेमाल नहीं हुआ, तो हटा दिया जाएगा। अगर इसका पिछला रिकॉर्ड है, तो यह ख़त्म होगा और रिकॉर्ड रहेगा।';
  }

  @override
  String get recurringDeleted => 'नियमित लेन-देन हटा दिया गया।';

  @override
  String get recurringEndedKept =>
      'इसका पिछला रिकॉर्ड है, इसलिए इसे ख़त्म किया गया। पिछले रिकॉर्ड रखे गए हैं।';

  @override
  String get occurrenceStatusScheduled => 'तय है';

  @override
  String get occurrenceStatusPosted => 'दर्ज हुआ';

  @override
  String get occurrenceStatusPaid => 'भुगतान हुआ';

  @override
  String get occurrenceStatusSkipped => 'छोड़ा गया';

  @override
  String get occurrenceStatusOverdue => 'तारीख़ निकल गई';

  @override
  String get occurrenceStatusOther => 'योजना में';

  @override
  String occurrenceMovedFrom(String date) {
    return '$date से आगे बढ़ाया';
  }

  @override
  String get occurrenceHasTransaction => 'लेन-देन से जुड़ा';

  @override
  String occurrenceSheetTitle(String date) {
    return '$date को देय';
  }

  @override
  String get occurrenceConfirm => 'अभी दर्ज करें';

  @override
  String get occurrenceConfirmHelp => 'आपके खाते में लेन-देन जोड़ता है।';

  @override
  String get occurrenceLink => 'पहले से दर्ज लेन-देन से जोड़ें';

  @override
  String get occurrenceLinkHelp =>
      'कुछ नया नहीं जुड़ता, इसलिए दोहराव नहीं होगा।';

  @override
  String get occurrenceLinkTitle => 'लेन-देन चुनें';

  @override
  String get occurrenceSetAmount => 'राशि बदलें';

  @override
  String get occurrencePostpone => 'दूसरी तारीख़ पर करें';

  @override
  String get occurrencePostponeTitle => 'नई तारीख़';

  @override
  String get occurrenceSkip => 'इस बार छोड़ें';

  @override
  String get occurrenceReopen => 'छोड़ना वापस लें';

  @override
  String get occurrenceOpenTransaction => 'लेन-देन खोलें';

  @override
  String get occurrenceSkipConfirmTitle => 'इस बार छोड़ें?';

  @override
  String occurrenceSkipConfirmBody(String date) {
    return '$date के लिए कुछ दर्ज नहीं होगा। आप इसे बाद में वापस ले सकते हैं।';
  }

  @override
  String get occurrenceConfirmTitle => 'इसे दर्ज करें';

  @override
  String occurrenceConfirmBody(String name, String date) {
    return '$name, $date को देय।';
  }

  @override
  String get occurrenceAmountLabel => 'राशि';

  @override
  String get occurrenceAmountHelp => 'अगर असल राशि अलग थी तो बदलें।';

  @override
  String get occurrenceDateDefault => 'देय तारीख़ (जल्दी हो तो आज)';

  @override
  String get occurrenceConfirmButton => 'दर्ज करें';

  @override
  String get occurrenceSetAmountTitle => 'राशि बदलें';

  @override
  String get occurrenceSetAmountBody => 'सिर्फ़ इसी बार की राशि बदलेगी।';

  @override
  String get occurrenceRecorded => 'दर्ज हो गया।';

  @override
  String get occurrenceLinked => 'लेन-देन से जोड़ दिया गया।';

  @override
  String get occurrenceSkipped => 'छोड़ दिया गया।';

  @override
  String get occurrencePostponed => 'नई तारीख़ पर कर दिया गया।';

  @override
  String get occurrenceAmountSet => 'राशि बदल दी गई।';

  @override
  String get occurrenceReopened => 'यह फिर से सूची में है।';

  @override
  String get occurrenceUpdated => 'अपडेट हो गया।';

  @override
  String get scheduleTitle => 'शेड्यूल';

  @override
  String get scheduleFrequencyLabel => 'कितनी बार';

  @override
  String get scheduleEveryLabel => 'हर';

  @override
  String get scheduleUnitLabel => 'अवधि';

  @override
  String get scheduleIntervalInvalid => '1 से 366 तक कोई संख्या लिखें।';

  @override
  String get scheduleWeekdayLabel => 'हफ़्ते का दिन';

  @override
  String get scheduleSameWeekday => 'शुरू होने की तारीख़ वाला दिन';

  @override
  String get scheduleDayLabel => 'कौन-सा दिन';

  @override
  String get scheduleAnchorStart => 'शुरू होने वाली तारीख़';

  @override
  String get scheduleAnchorMonthDay => 'महीने की कोई तारीख़';

  @override
  String get scheduleAnchorNthWeekday => 'महीने का कोई वार';

  @override
  String get scheduleMonthDayLabel => 'तारीख़';

  @override
  String get scheduleLastDay => 'महीने का आख़िरी दिन';

  @override
  String get scheduleMonthDayHelp => 'छोटे महीनों में यह आख़िरी दिन पड़ेगा।';

  @override
  String get scheduleWeekOfMonthLabel => 'हफ़्ता';

  @override
  String scheduleOrdinal(String n) {
    String _temp0 = intl.Intl.selectLogic(n, {
      '1': 'पहला',
      '2': 'दूसरा',
      '3': 'तीसरा',
      '4': 'चौथा',
      '5': 'पाँचवाँ',
      'other': 'आख़िरी',
    });
    return '$_temp0';
  }

  @override
  String scheduleOnWeekday(String weekday) {
    return '$weekday को';
  }

  @override
  String scheduleOnNthWeekday(String week, String weekday) {
    String _temp0 = intl.Intl.selectLogic(week, {
      '1': 'पहले',
      '2': 'दूसरे',
      '3': 'तीसरे',
      '4': 'चौथे',
      '5': 'पाँचवें',
      'other': 'आख़िरी',
    });
    return '$_temp0 $weekday को';
  }

  @override
  String scheduleOnMonthDay(int day) {
    return '$day तारीख़ को';
  }

  @override
  String get scheduleOnLastDay => 'महीने के आख़िरी दिन';

  @override
  String get scheduleStartLabel => 'शुरू होने की तारीख़';

  @override
  String get scheduleEndsLabel => 'कब तक';

  @override
  String get scheduleEndsNever => 'कभी नहीं';

  @override
  String get scheduleEndsOnDate => 'किसी तारीख़ पर';

  @override
  String get scheduleEndsAfter => 'कुछ बार के बाद';

  @override
  String get scheduleEndDateLabel => 'ख़त्म होने की तारीख़';

  @override
  String get scheduleEndDateChoose => 'तारीख़ चुनें';

  @override
  String get scheduleEndBeforeStart =>
      'शुरू होने की तारीख़ के बाद की तारीख़ चुनें।';

  @override
  String get scheduleTimesLabel => 'कितनी बार';

  @override
  String get scheduleTimesInvalid => '1 से 10,000 तक कोई संख्या लिखें।';

  @override
  String get scheduleTimeLabel => 'समय';

  @override
  String get scheduleTimeHelp =>
      'रिमाइंडर और अपने-आप होने वाली एंट्री इसी समय होंगी।';

  @override
  String scheduleFrom(String start) {
    return '$start से';
  }

  @override
  String scheduleFromUntil(String start, String end) {
    return '$start से $end तक';
  }

  @override
  String scheduleFromTimes(String start, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count बार',
      one: 'एक बार',
    );
    return '$start से, $_temp0';
  }

  @override
  String get billsTitle => 'बिल';

  @override
  String get billAdd => 'बिल जोड़ें';

  @override
  String get billAddFirst => 'अपना पहला बिल जोड़ें';

  @override
  String get billsEmptyTitle => 'अभी कोई बिल नहीं';

  @override
  String get billsEmptyBody =>
      'किराया, बिजली या फ़ोन के बिल जोड़ें, ताकि पता रहे कि क्या देना है और भुगतान दर्ज कर सकें।';

  @override
  String get billsNoMatchTitle => 'यहाँ कोई बिल नहीं';

  @override
  String get billFilterActive => 'चालू';

  @override
  String get billFilterPaused => 'रुके हुए';

  @override
  String get billFilterArchived => 'संग्रहित';

  @override
  String get billFilterAll => 'सभी';

  @override
  String get billStateOverdue => 'तारीख़ निकल गई';

  @override
  String get billStateDueToday => 'आज देय';

  @override
  String get billStateDueSoon => 'जल्द देय';

  @override
  String get billStatePaid => 'भुगतान हो गया';

  @override
  String get billStateUpcoming => 'आने वाला';

  @override
  String get billStatePaused => 'रुका हुआ';

  @override
  String get billStateArchived => 'संग्रहित';

  @override
  String get billStateEnded => 'ख़त्म';

  @override
  String get billStateOther => 'स्थिति उपलब्ध नहीं';

  @override
  String billStateSemantics(String state) {
    return 'भुगतान की स्थिति: $state';
  }

  @override
  String billDueOn(String date) {
    return '$date को देय';
  }

  @override
  String billPaidOn(String date) {
    return '$date को भुगतान हुआ';
  }

  @override
  String billLastPaidOn(String date) {
    return 'पिछला भुगतान $date';
  }

  @override
  String get billVaries => 'बदलती है';

  @override
  String get billNewTitle => 'नया बिल';

  @override
  String get billEditTitle => 'बिल बदलें';

  @override
  String get billNameLabel => 'बिल का नाम';

  @override
  String get billNameHelp => 'जैसे \"बिजली\" या \"फ़ोन\"।';

  @override
  String get billProviderLabel => 'कंपनी';

  @override
  String get billProviderHelp => 'जिसे आप भुगतान करते हैं, जैसे बिजली कंपनी।';

  @override
  String get billAmountSection => 'राशि और भुगतान';

  @override
  String get billVariableLabel => 'राशि हर बार बदलती है';

  @override
  String get billVariableHelp => 'भुगतान दर्ज करते समय आप राशि लिखेंगे।';

  @override
  String get billExpectedAmountLabel => 'अनुमानित राशि';

  @override
  String get billPaymentAccountLabel => 'किस खाते से भुगतान';

  @override
  String get billPaymentAccountHelp =>
      'भुगतान दर्ज करते समय यही खाता चुना जाएगा।';

  @override
  String get billNoPaymentAccount => 'तय नहीं';

  @override
  String get billScheduleSection => 'कब देना है';

  @override
  String get billCreateButton => 'बिल जोड़ें';

  @override
  String get billCreated => 'बिल जुड़ गया।';

  @override
  String get billSaved => 'बिल सेव हो गया।';

  @override
  String get billDetailTitle => 'बिल';

  @override
  String get billDetailsTitle => 'जानकारी';

  @override
  String get billHistoryTitle => 'भुगतान';

  @override
  String get billNoHistory => 'अभी कोई भुगतान नहीं।';

  @override
  String get billMarkPaid => 'भुगतान दर्ज करें';

  @override
  String get billSkip => 'इस बार छोड़ें';

  @override
  String get billSkipThis => 'इस बार का भुगतान छोड़ें';

  @override
  String get billSkipConfirmTitle => 'इस बार का भुगतान छोड़ें?';

  @override
  String billSkipConfirmBody(String date) {
    return '$date को देय बिल छोड़ा हुआ माना जाएगा। कुछ दर्ज नहीं होगा।';
  }

  @override
  String get billSkippedDone => 'छोड़ दिया गया।';

  @override
  String get billPause => 'रोकें';

  @override
  String get billResume => 'फिर से चालू करें';

  @override
  String get billArchive => 'संग्रहित करें';

  @override
  String get billPausedDone => 'बिल रोक दिया गया।';

  @override
  String get billResumedDone => 'बिल फिर से चालू हो गया।';

  @override
  String get billRestoredDone => 'बिल वापस आ गया।';

  @override
  String get billArchivedDone => 'बिल संग्रहित हो गया।';

  @override
  String get billArchiveConfirmTitle => 'यह बिल संग्रहित करें?';

  @override
  String billArchiveConfirmBody(String name) {
    return '$name अब देय नहीं दिखेगा। भुगतान का रिकॉर्ड रहेगा, और आप इसे वापस ला सकते हैं।';
  }

  @override
  String get billPausedNotice =>
      'रुका हुआ है। दोबारा चालू करने तक यह देय नहीं दिखेगा।';

  @override
  String get billArchivedNotice => 'संग्रहित है। भुगतान का रिकॉर्ड रखा गया है।';

  @override
  String get billSharedReadOnly => 'आपके साथ साझा · सिर्फ़ देखने के लिए';

  @override
  String get billPayTitle => 'भुगतान दर्ज करें';

  @override
  String get billNothingToPay => 'इस बिल पर अभी कुछ देय नहीं है।';

  @override
  String billPayIntro(String name, String date) {
    return '$name, $date को देय';
  }

  @override
  String get billPayLinkMode => 'दर्ज भुगतान चुनें';

  @override
  String get billPayRecordMode => 'नया दर्ज करें';

  @override
  String get billPayLinkHelp =>
      'पहले से दर्ज भुगतान चुनें। कुछ नया नहीं जुड़ेगा।';

  @override
  String get billPayRecordHelp => 'इस भुगतान के लिए नया खर्च जोड़ता है।';

  @override
  String get billCandidatesError => 'सुझाए गए भुगतान लोड नहीं हो सके।';

  @override
  String get billNoCandidates =>
      'कोई मिलता-जुलता भुगतान नहीं मिला। कोई लेन-देन चुनें या नया भुगतान दर्ज करें।';

  @override
  String get billChooseOtherPayment => 'कोई दूसरा लेन-देन चुनें';

  @override
  String get billChosenPayment => 'चुना गया भुगतान';

  @override
  String get billChoosePayment => 'जोड़ने के लिए भुगतान चुनें।';

  @override
  String get billPaidAmountLabel => 'चुकाई गई राशि';

  @override
  String get billPaidAmountHelp => 'अगर अलग राशि चुकाई हो तो बदलें।';

  @override
  String get billPaidFromLabel => 'किस खाते से';

  @override
  String get billPaidOnLabel => 'भुगतान की तारीख़';

  @override
  String get billAccountRequired => 'वह खाता चुनें जिससे भुगतान किया।';

  @override
  String get billMarkedPaid => 'भुगतान दर्ज हो गया।';

  @override
  String get calendarTitle => 'कैलेंडर';

  @override
  String get calendarPreviousMonth => 'पिछला महीना';

  @override
  String get calendarNextMonth => 'अगला महीना';

  @override
  String get calendarThisMonth => 'इस महीने पर जाएँ';

  @override
  String calendarEmptyTitle(String month) {
    return '$month में कुछ तय नहीं है';
  }

  @override
  String get calendarEmptyBody =>
      'बिल, नियमित लेन-देन, सब्सक्रिप्शन रिन्यूअल और लक्ष्य की तारीख़ें यहाँ दिखेंगी।';

  @override
  String calendarMonthCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'इस महीने $count चीज़ें',
      one: 'इस महीने 1 चीज़',
    );
    return '$_temp0';
  }

  @override
  String calendarTodayHeading(String date) {
    return 'आज · $date';
  }

  @override
  String get calendarKindRecurring => 'नियमित';

  @override
  String get calendarKindBill => 'बिल';

  @override
  String get calendarKindGroupExpense => 'समूह का खर्च';

  @override
  String get calendarKindRenewal => 'सब्सक्रिप्शन रिन्यूअल';

  @override
  String get calendarKindTrialEnd => 'ट्रायल ख़त्म';

  @override
  String get calendarKindGoal => 'लक्ष्य की तारीख़';

  @override
  String get calendarKindOther => 'योजना में';

  @override
  String get calendarStatusProjected => 'अनुमानित';

  @override
  String get calendarStatusExpected => 'अपेक्षित';

  @override
  String get subscriptionsTitle => 'सब्सक्रिप्शन';

  @override
  String get subscriptionListTitle => 'आपके सब्सक्रिप्शन';

  @override
  String get subscriptionAdd => 'सब्सक्रिप्शन जोड़ें';

  @override
  String get subscriptionNewTitle => 'सब्सक्रिप्शन जोड़ें';

  @override
  String get subscriptionEditTitle => 'सब्सक्रिप्शन बदलें';

  @override
  String get subscriptionDetailTitle => 'सब्सक्रिप्शन';

  @override
  String get subscriptionEmptyTitle => 'अभी कोई सब्सक्रिप्शन नहीं';

  @override
  String get subscriptionEmptyBody =>
      'जिन सेवाओं के लिए आप नियमित रूप से पैसे देते हैं, उन्हें जोड़ें और देखें कि हर महीने कितना खर्च होता है।';

  @override
  String get subscriptionEmptyFiltered =>
      'इस स्थिति वाला कोई सब्सक्रिप्शन नहीं है।';

  @override
  String get subscriptionSummaryError => 'हम सारांश लोड नहीं कर सके।';

  @override
  String get subscriptionStatusTrial => 'मुफ़्त ट्रायल';

  @override
  String get subscriptionStatusActive => 'चालू';

  @override
  String get subscriptionStatusPaused => 'रुका हुआ';

  @override
  String get subscriptionStatusCancelling => 'रद्द हो रहा है';

  @override
  String get subscriptionStatusCancelled => 'रद्द';

  @override
  String get subscriptionStatusUnknown => 'अन्य स्थिति';

  @override
  String get subscriptionFilterCurrent => 'मौजूदा';

  @override
  String get subscriptionFilterAll => 'सभी';

  @override
  String get subscriptionTotalsTitle => 'इनका खर्च';

  @override
  String subscriptionTotalCount(int count, String currency) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count सब्सक्रिप्शन',
      one: '1 सब्सक्रिप्शन',
    );
    return '$currency में $_temp0';
  }

  @override
  String get subscriptionMonthlyCost => 'हर महीने';

  @override
  String get subscriptionAnnualCost => 'हर साल';

  @override
  String get subscriptionTotalsNote =>
      'इसमें मुफ़्त ट्रायल, चालू सब्सक्रिप्शन और रद्द हो रहे सब्सक्रिप्शन शामिल हैं। हर मुद्रा का जोड़ अलग से दिखाया गया है।';

  @override
  String get subscriptionTrialsTitle => 'जल्द ख़त्म होने वाले मुफ़्त ट्रायल';

  @override
  String get subscriptionRenewalsTitle => 'अगले 30 दिनों में रिन्यू होने वाले';

  @override
  String subscriptionDetectionsPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'देखने के लिए $count संभावित सब्सक्रिप्शन',
      one: 'देखने के लिए 1 संभावित सब्सक्रिप्शन',
    );
    return '$_temp0';
  }

  @override
  String get subscriptionDetectionsReview =>
      'आपके लेन-देन में मिले। आपकी पुष्टि के बिना कुछ नहीं जोड़ा जाता।';

  @override
  String subscriptionTrialEnds(String date) {
    return 'ट्रायल $date को ख़त्म होगा';
  }

  @override
  String subscriptionRenews(String date) {
    return '$date को रिन्यू होगा';
  }

  @override
  String subscriptionNextCharge(String date) {
    return 'अगला भुगतान $date को';
  }

  @override
  String get subscriptionSharedLabel => 'आपके साथ साझा';

  @override
  String get subscriptionNameLabel => 'नाम';

  @override
  String get subscriptionNameHelp =>
      'जैसे, वह सेवा जिसके लिए आप भुगतान करते हैं।';

  @override
  String get subscriptionPlanLabel => 'प्लान';

  @override
  String get subscriptionPriceSection => 'कीमत और बिलिंग';

  @override
  String get subscriptionAmountLabel => 'हर बिलिंग चक्र की कीमत';

  @override
  String get subscriptionFrequencyLabel => 'बिलिंग चक्र';

  @override
  String get subscriptionFrequencyRequired => 'बिलिंग चक्र चुनें।';

  @override
  String get subscriptionIntervalCountLabel => 'कितने अंतराल पर दोहराए';

  @override
  String get subscriptionIntervalUnitLabel => 'इकाई';

  @override
  String get subscriptionIntervalInvalid => '1 से 366 तक की पूरी संख्या लिखें।';

  @override
  String get subscriptionDatesSection => 'तारीख़ें';

  @override
  String get subscriptionStartLabel => 'शुरू होने की तारीख़';

  @override
  String get subscriptionTrialLabel => 'मुफ़्त ट्रायल ख़त्म होने की तारीख़';

  @override
  String get subscriptionNoTrial => 'कोई मुफ़्त ट्रायल नहीं';

  @override
  String get subscriptionNextRenewalLabel => 'अगला रिन्यूअल';

  @override
  String get subscriptionNextRenewalAuto => 'मेरे लिए तय करें';

  @override
  String get subscriptionNextRenewalHelp =>
      'इसे ख़ाली छोड़ दें, Montra शुरू होने की तारीख़ से इसे तय कर देगा।';

  @override
  String get subscriptionPaymentSection => 'भुगतान और साझा करना';

  @override
  String get subscriptionPaymentAccountLabel => 'किस खाते से भुगतान';

  @override
  String get subscriptionPaymentAccountNone => 'तय नहीं';

  @override
  String get subscriptionCategoryUnavailable => 'श्रेणी उपलब्ध नहीं';

  @override
  String get subscriptionGroupLabel => 'समूह के साथ साझा';

  @override
  String get subscriptionGroupHelp =>
      'इसे अपने किसी समूह के साथ साझा के रूप में ट्रैक करें।';

  @override
  String get subscriptionGroupUnavailable => 'समूह उपलब्ध नहीं';

  @override
  String get subscriptionRemindersSection => 'रिमाइंडर';

  @override
  String get subscriptionRemindersLabel => 'रिन्यू होने से पहले याद दिलाएँ';

  @override
  String get subscriptionRemindersHelp =>
      'मुफ़्त ट्रायल के दौरान Montra ट्रायल ख़त्म होने से पहले भी याद दिलाएगा।';

  @override
  String get subscriptionCancellationSection => 'रद्द करना';

  @override
  String get subscriptionCancellationUrlLabel => 'रद्द करने का पेज';

  @override
  String get subscriptionCancellationUrlHelp =>
      'सेवा देने वाले का आधिकारिक पेज, जो https:// से शुरू हो';

  @override
  String get subscriptionCancellationUrlInvalid =>
      'सेवा देने वाले का आधिकारिक https:// पेज डालें।';

  @override
  String get subscriptionCancellationHowLabel => 'रद्द कैसे करें';

  @override
  String get subscriptionChecklistTitle => 'रद्द करने की चेकलिस्ट';

  @override
  String get subscriptionChecklistHelp =>
      'रद्द करने से पहले या उस दौरान पूरे करने वाले कदम, जैसे अपना डेटा डाउनलोड करना।';

  @override
  String get subscriptionChecklistAdd => 'कदम जोड़ें';

  @override
  String get subscriptionChecklistAddButton => 'यह कदम जोड़ें';

  @override
  String subscriptionChecklistRemove(String item) {
    return 'कदम हटाएँ: $item';
  }

  @override
  String subscriptionChecklistFull(int max) {
    return 'आप ज़्यादा से ज़्यादा $max कदम जोड़ सकते हैं।';
  }

  @override
  String get subscriptionChecklistEmpty =>
      'इस सब्सक्रिप्शन को बदलकर चेकलिस्ट में कदम जोड़ें।';

  @override
  String get subscriptionCreated => 'सब्सक्रिप्शन जोड़ दिया गया।';

  @override
  String get subscriptionSaved => 'सब्सक्रिप्शन सेव हो गया।';

  @override
  String get subscriptionPriceLabel => 'कीमत';

  @override
  String get subscriptionSourceLabel => 'कैसे जोड़ा गया';

  @override
  String get subscriptionSourceDetected => 'आपके लेन-देन में मिला';

  @override
  String get subscriptionSourceManual => 'आपने जोड़ा';

  @override
  String get subscriptionDuplicateTitle => 'यह दोहराया हुआ हो सकता है';

  @override
  String subscriptionDuplicateBody(String name, String reason) {
    return 'यह $name जैसा लगता है: $reason।';
  }

  @override
  String get subscriptionDuplicateSameMerchant => 'वही व्यापारी';

  @override
  String get subscriptionDuplicateSameName => 'वही नाम';

  @override
  String get subscriptionDuplicateSamePrice => 'वही कीमत और बिलिंग चक्र';

  @override
  String get subscriptionDuplicateOpen => 'खोलें';

  @override
  String subscriptionDuplicateOpenLabel(String name) {
    return '$name खोलें';
  }

  @override
  String get subscriptionSharedNotice =>
      'यह सब्सक्रिप्शन एक समूह के ज़रिए आपके साथ साझा है। इसे सिर्फ़ इसका मालिक बदल सकता है।';

  @override
  String get subscriptionCostTitle => 'इसका खर्च';

  @override
  String get subscriptionCostNote =>
      'Montra ने कीमत और बिलिंग चक्र से इसका हिसाब लगाया है।';

  @override
  String get subscriptionPaymentsTitle => 'भुगतान';

  @override
  String get subscriptionNoPayments => 'अभी कोई भुगतान जुड़ा नहीं है।';

  @override
  String get subscriptionLastPayment => 'पिछला भुगतान';

  @override
  String get subscriptionPaidAmount => 'चुकाई गई राशि';

  @override
  String get subscriptionViewTransaction => 'लेन-देन देखें';

  @override
  String get subscriptionRecordPayment => 'भुगतान दर्ज करें';

  @override
  String get subscriptionPaymentPickerTitle => 'यह भुगतान कौन-सा लेन-देन था?';

  @override
  String subscriptionPaymentCurrencyMismatch(String currency) {
    return '$currency में हुआ लेन-देन चुनें, जो इस सब्सक्रिप्शन की मुद्रा है।';
  }

  @override
  String get subscriptionRecordPaymentTitle => 'यह भुगतान दर्ज करें?';

  @override
  String subscriptionRecordPaymentBody(
    String title,
    String date,
    String amount,
  ) {
    return '$date को $title का $amount का लेन-देन इस सब्सक्रिप्शन से जोड़ा जाएगा। लेन-देन में कोई बदलाव नहीं होगा।';
  }

  @override
  String subscriptionPriceDiffers(String price) {
    return 'यह मौजूदा कीमत $price से अलग है।';
  }

  @override
  String subscriptionUpdatePrice(String amount) {
    return 'कीमत बदलकर $amount करें';
  }

  @override
  String get subscriptionRecordPaymentConfirm => 'भुगतान दर्ज करें';

  @override
  String get subscriptionPaymentRecorded => 'भुगतान दर्ज हो गया।';

  @override
  String get subscriptionPaymentDuplicate =>
      'यह भुगतान पहले से किसी सब्सक्रिप्शन से जुड़ा है।';

  @override
  String get subscriptionActionUnavailable =>
      'सब्सक्रिप्शन की मौजूदा स्थिति में यह नहीं हो सकता। हमने ताज़ा जानकारी लोड कर दी है।';

  @override
  String get subscriptionCancellingNotice =>
      'आपने रद्द करना शुरू कर दिया है। सेवा देने वाले की पुष्टि के बाद इसे रद्द के रूप में चिह्नित करें।';

  @override
  String get subscriptionOpenPage => 'पेज खोलें';

  @override
  String get subscriptionCopyLink => 'लिंक कॉपी करें';

  @override
  String get subscriptionOpenPageFailed =>
      'हम पेज नहीं खोल सके। इसके बजाय आप लिंक कॉपी कर सकते हैं।';

  @override
  String get subscriptionLinkCopied => 'लिंक कॉपी हो गया।';

  @override
  String get subscriptionCancelledOn => 'रद्द होने की तारीख़';

  @override
  String get subscriptionLastChecked => 'पिछली बार जाँचा गया';

  @override
  String get subscriptionNeverChecked => 'अभी तक नहीं';

  @override
  String get subscriptionDetailsSection => 'विवरण';

  @override
  String get subscriptionHistoryTitle => 'इतिहास';

  @override
  String get subscriptionHistoryEmpty => 'अभी कोई इतिहास नहीं।';

  @override
  String subscriptionHistoryShowAll(int count) {
    return 'सभी $count एंट्री दिखाएँ';
  }

  @override
  String subscriptionPriceHistorySummary(
    String firstPrice,
    String firstDate,
    String lastPrice,
    String lastDate,
  ) {
    return 'कीमत $firstDate को $firstPrice थी और $lastDate को $lastPrice हो गई।';
  }

  @override
  String subscriptionPriceChange(String from, String to) {
    return '$from से $to';
  }

  @override
  String get subscriptionEventCreated => 'जोड़ा गया';

  @override
  String get subscriptionEventEdited => 'जानकारी बदली गई';

  @override
  String get subscriptionEventPriceChanged => 'कीमत बदली';

  @override
  String get subscriptionEventPayment => 'भुगतान दर्ज हुआ';

  @override
  String get subscriptionEventTrialStarted => 'मुफ़्त ट्रायल शुरू हुआ';

  @override
  String get subscriptionEventTrialEnding => 'मुफ़्त ट्रायल जल्द ख़त्म होगा';

  @override
  String get subscriptionEventPaused => 'रोका गया';

  @override
  String get subscriptionEventResumed => 'फिर से शुरू हुआ';

  @override
  String get subscriptionEventCancellationStarted => 'रद्द करना शुरू हुआ';

  @override
  String get subscriptionEventCancelled => 'रद्द हुआ';

  @override
  String get subscriptionEventReactivated => 'फिर से चालू हुआ';

  @override
  String get subscriptionEventVerified => 'जाँचा गया';

  @override
  String get subscriptionEventOther => 'अपडेट हुआ';

  @override
  String get subscriptionActionVerify => 'जाँचा हुआ मानें';

  @override
  String get subscriptionActionPause => 'रोकें';

  @override
  String get subscriptionActionResume => 'फिर से शुरू करें';

  @override
  String get subscriptionActionCancellationStarted =>
      'मैंने रद्द करना शुरू किया है';

  @override
  String get subscriptionActionCancelled => 'रद्द के रूप में चिह्नित करें';

  @override
  String get subscriptionActionReactivate => 'फिर से चालू करें';

  @override
  String get subscriptionVerifiedDone => 'आज जाँचा हुआ मान लिया गया।';

  @override
  String get subscriptionPausedDone => 'सब्सक्रिप्शन रोक दिया गया।';

  @override
  String get subscriptionResumedDone => 'सब्सक्रिप्शन फिर से शुरू हो गया।';

  @override
  String get subscriptionCancellationStartedDone =>
      'नोट कर लिया। रद्द करते समय चेकलिस्ट का इस्तेमाल करें।';

  @override
  String get subscriptionCancelledDone => 'रद्द के रूप में चिह्नित किया गया।';

  @override
  String get subscriptionReactivatedDone => 'सब्सक्रिप्शन फिर से चालू हो गया।';

  @override
  String get subscriptionCancelledConfirmTitle => 'क्या यह रद्द हो गया है?';

  @override
  String subscriptionCancelledConfirmBody(String name) {
    return '$name को रद्द तभी चिह्नित करें जब सेवा देने वाले ने इसकी पुष्टि कर दी हो। Montra आपके लिए सब्सक्रिप्शन रद्द नहीं करता।';
  }

  @override
  String get subscriptionCancelledConfirm => 'हाँ, यह रद्द हो गया है';

  @override
  String get detectionsTitle => 'संभावित सब्सक्रिप्शन';

  @override
  String get detectionsHint => 'अपने लेन-देन में नियमित भुगतान खोजें।';

  @override
  String get detectionsIntro =>
      'Montra ऐसे भुगतान खोजता है जो नियमित अंतराल पर लगभग एक जैसी राशि के साथ दोहराए जाते हैं। आपकी पुष्टि के बिना कुछ नहीं जोड़ा जाता।';

  @override
  String get detectionsRefresh => 'फिर से खोजें';

  @override
  String get detectionsRefreshStarted =>
      'नियमित भुगतान खोजे जा रहे हैं। यह बैकग्राउंड में चलता है, इसलिए कुछ मिनट बाद फिर देखें।';

  @override
  String get detectionsEmptyTitle => 'देखने के लिए कुछ नहीं';

  @override
  String get detectionsEmptyBody =>
      'जब कोई भुगतान नियमित रूप से दोहराया जाता है, तो वह यहाँ आपके देखने के लिए दिखेगा।';

  @override
  String get detectionTypicalAmount => 'आम तौर पर राशि';

  @override
  String detectionTolerance(String amount) {
    return 'राशि में $amount तक का फ़र्क होता है।';
  }

  @override
  String detectionStrong(int percent) {
    return 'पक्का मेल ($percent%)';
  }

  @override
  String detectionLikely(int percent) {
    return 'अच्छा मेल ($percent%)';
  }

  @override
  String detectionPossible(int percent) {
    return 'हो सकता है ($percent%)';
  }

  @override
  String get detectionConfidenceHelp =>
      'यह इस पर आधारित है कि तारीख़ें कितनी नियमित हैं, राशियाँ कितनी मिलती-जुलती हैं और कितने भुगतान हुए हैं।';

  @override
  String detectionEvidenceCharges(int count, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count भुगतान',
      one: '1 भुगतान',
    );
    String _temp1 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days दिन',
      one: '1 दिन',
    );
    return '$_temp0, आम तौर पर $_temp1 के अंतर पर';
  }

  @override
  String detectionEvidenceLast(String date) {
    return 'पिछला भुगतान $date को';
  }

  @override
  String detectionEvidenceNext(String date) {
    return 'अगला भुगतान लगभग $date को होने की उम्मीद';
  }

  @override
  String get detectionConfirm => 'सब्सक्रिप्शन के रूप में जोड़ें';

  @override
  String detectionConfirmLabel(String name) {
    return '$name को सब्सक्रिप्शन के रूप में जोड़ें';
  }

  @override
  String get detectionDismiss => 'यह सब्सक्रिप्शन नहीं है';

  @override
  String detectionDismissLabel(String name) {
    return '$name सब्सक्रिप्शन नहीं है';
  }

  @override
  String get detectionDismissTitle => 'सब्सक्रिप्शन नहीं है?';

  @override
  String detectionDismissBody(String name) {
    return '$name को इस सूची से हटा दिया जाएगा। आपके लेन-देन जैसे हैं वैसे ही रहेंगे।';
  }

  @override
  String get detectionDismissed => 'सूची से हटा दिया गया।';

  @override
  String get detectionSeeCharges => 'भुगतान देखें';

  @override
  String detectionSeeChargesLabel(String name) {
    return '$name के भुगतान देखें';
  }

  @override
  String get detectionConfirmTitle => 'सब्सक्रिप्शन के रूप में जोड़ें';

  @override
  String get detectionConfirmBody =>
      'जानकारी जाँच लें। जो आप नहीं बदलेंगे, उसके लिए मिली हुई जानकारी इस्तेमाल होगी।';

  @override
  String get detectionAccountDefault => 'पिछले भुगतान वाला खाता';

  @override
  String get detectionConfirmed => 'सब्सक्रिप्शन जोड़ दिया गया।';

  @override
  String get subscriptionListError => 'हम आपके सब्सक्रिप्शन लोड नहीं कर सके।';

  @override
  String get goalsTitle => 'लक्ष्य';

  @override
  String get goalNew => 'नया लक्ष्य';

  @override
  String get goalAddFirst => 'लक्ष्य जोड़ें';

  @override
  String get goalsEmptyTitle => 'अभी कोई लक्ष्य नहीं';

  @override
  String get goalsEmptyBody =>
      'किसी ज़रूरी चीज़ के लिए बचत करें, जैसे आपात फ़ंड, कोई यात्रा या नया फ़ोन। लक्ष्य जोड़ें और अपनी रफ़्तार से आगे बढ़ें।';

  @override
  String get goalsNoMatchTitle => 'यहाँ कोई लक्ष्य नहीं';

  @override
  String get goalsNoMatchBody => 'कोई दूसरा फ़िल्टर चुनें।';

  @override
  String get goalFilterLabel => 'लक्ष्य दिखाएँ';

  @override
  String get goalFilterCurrent => 'मौजूदा';

  @override
  String get goalFilterAll => 'सभी, संग्रहीत भी';

  @override
  String get goalStatusActive => 'चालू';

  @override
  String get goalStatusPaused => 'रुका हुआ';

  @override
  String get goalStatusAchieved => 'पूरा हुआ';

  @override
  String get goalStatusCancelled => 'समाप्त';

  @override
  String get goalStatusArchived => 'संग्रहीत';

  @override
  String get goalStatusUnknown => 'अन्य स्थिति';

  @override
  String goalProgressSummary(String percent, String saved, String target) {
    return '$percent बचत · $target में से $saved';
  }

  @override
  String goalTargetDateShort(String date) {
    return '$date तक';
  }

  @override
  String get goalSharedWithYou => 'आपके साथ साझा';

  @override
  String goalSharedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count लोगों के साथ साझा',
      one: '1 व्यक्ति के साथ साझा',
    );
    return '$_temp0';
  }

  @override
  String get goalTypeEmergencyFund => 'आपात फ़ंड';

  @override
  String get goalTypeTravel => 'यात्रा';

  @override
  String get goalTypeEducation => 'पढ़ाई';

  @override
  String get goalTypeDevice => 'फ़ोन या गैजेट';

  @override
  String get goalTypeVehicle => 'गाड़ी';

  @override
  String get goalTypeHome => 'घर';

  @override
  String get goalTypeEvent => 'कार्यक्रम या जश्न';

  @override
  String get goalTypeDebtPayoff => 'कर्ज़ चुकाना';

  @override
  String get goalTypeLargePurchase => 'बड़ी ख़रीदारी';

  @override
  String get goalTypeCustom => 'कुछ और';

  @override
  String get goalDetailTitle => 'लक्ष्य';

  @override
  String goalPercentSaved(String percent) {
    return '$percent बचत हो गई';
  }

  @override
  String goalSavedOfTarget(String saved, String target) {
    return '$target में से $saved';
  }

  @override
  String get goalSavedLabel => 'अब तक की बचत';

  @override
  String get goalTargetLabel => 'लक्ष्य राशि';

  @override
  String get goalRemainingLabel => 'अभी बाकी';

  @override
  String get goalVerifiedLabel => 'लेन-देन से पुष्टि';

  @override
  String get goalPlannedLabel => 'योजना में, अभी गिना नहीं गया';

  @override
  String get goalStartingLabel => 'ट्रैकिंग से पहले की बचत';

  @override
  String goalContributionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count योगदान',
      one: '1 योगदान',
      zero: 'अभी कोई योगदान नहीं',
    );
    return '$_temp0';
  }

  @override
  String get goalPausedNotice =>
      'यह लक्ष्य रुका हुआ है। योगदान जोड़ने के लिए इसे फिर से शुरू करें।';

  @override
  String goalAchievedNotice(String date) {
    return 'आपने $date को यह लक्ष्य पूरा किया।';
  }

  @override
  String get goalAchievedNoticeNoDate => 'आपने यह लक्ष्य पूरा किया।';

  @override
  String get goalCancelledNotice =>
      'यह लक्ष्य समाप्त हो चुका है। इसका इतिहास सुरक्षित है।';

  @override
  String get goalArchivedNotice =>
      'यह लक्ष्य संग्रहीत है। इसका इतिहास सुरक्षित है।';

  @override
  String get goalViewerNotice =>
      'आप यह लक्ष्य देख सकते हैं, पर इसमें जोड़ नहीं सकते।';

  @override
  String get goalAddContribution => 'योगदान जोड़ें';

  @override
  String get goalExport => 'CSV में निर्यात करें';

  @override
  String get goalPause => 'लक्ष्य रोकें';

  @override
  String get goalResume => 'लक्ष्य फिर शुरू करें';

  @override
  String get goalMarkAchieved => 'पूरा हुआ मार्क करें';

  @override
  String get goalCancel => 'लक्ष्य समाप्त करें';

  @override
  String get goalArchive => 'लक्ष्य संग्रह में रखें';

  @override
  String get goalLeave => 'लक्ष्य छोड़ें';

  @override
  String get goalPausedDone => 'लक्ष्य रोका गया।';

  @override
  String get goalResumedDone => 'लक्ष्य फिर शुरू हुआ।';

  @override
  String get goalAchievedDone => 'लक्ष्य पूरा मार्क किया गया।';

  @override
  String get goalCancelledDone => 'लक्ष्य समाप्त किया गया।';

  @override
  String get goalArchivedDone => 'लक्ष्य संग्रह में रखा गया।';

  @override
  String get goalLeftDone => 'आपने लक्ष्य छोड़ दिया।';

  @override
  String get goalAchieveConfirmTitle => 'क्या यह लक्ष्य पूरा मार्क करें?';

  @override
  String goalAchieveConfirmBody(String name) {
    return '$name पूरा मार्क हो जाएगा। उसके बाद इसमें योगदान नहीं जोड़े जा सकेंगे।';
  }

  @override
  String get goalCancelConfirmTitle => 'क्या यह लक्ष्य समाप्त करें?';

  @override
  String goalCancelConfirmBody(String name) {
    return '$name बंद हो जाएगा और इसके योगदान इतिहास में रहेंगे। आप कभी भी नया लक्ष्य शुरू कर सकते हैं।';
  }

  @override
  String get goalArchiveConfirmTitle => 'क्या यह लक्ष्य संग्रह में रखें?';

  @override
  String goalArchiveConfirmBody(String name) {
    return '$name अपने इतिहास के साथ संग्रह में चला जाएगा। संग्रहीत लक्ष्य बदले नहीं जा सकते।';
  }

  @override
  String get goalLeaveConfirmTitle => 'क्या यह लक्ष्य छोड़ें?';

  @override
  String goalLeaveConfirmBody(String name) {
    return 'आप अब $name नहीं देख पाएँगे। आपके पिछले योगदान इसके इतिहास में रहेंगे।';
  }

  @override
  String get goalForecastTitle => 'आगे का अनुमान';

  @override
  String get goalForecastAchieved => 'आप लक्ष्य राशि तक पहुँच गए हैं';

  @override
  String get goalForecastOnTrack => 'सही रास्ते पर';

  @override
  String get goalForecastNeedsMore => 'समय पर पूरा करने के लिए थोड़ा और चाहिए';

  @override
  String goalForecastDaysLeft(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days दिन बाकी',
      one: '1 दिन बाकी',
      zero: 'आज तक',
    );
    return '$_temp0';
  }

  @override
  String goalForecastRequired(String perMonth, String perWeek) {
    return 'तय तारीख़ तक पूरा करने के लिए हर महीने लगभग $perMonth (हर हफ़्ते $perWeek) अलग रखें।';
  }

  @override
  String goalForecastRequiredMonthOnly(String perMonth) {
    return 'तय तारीख़ तक पूरा करने के लिए हर महीने लगभग $perMonth अलग रखें।';
  }

  @override
  String goalForecastPace(String pace) {
    return 'हाल की रफ़्तार: हर महीने $pace (पिछले 90 दिन)।';
  }

  @override
  String goalForecastProjected(String date) {
    return 'इसी रफ़्तार से आप लगभग $date तक पहुँच जाएँगे।';
  }

  @override
  String get goalForecastNoPace =>
      'पूरा होने की तारीख़ का अनुमान लगाने के लिए अभी हाल की कोई प्रगति नहीं है।';

  @override
  String goalForecastPlanned(String date) {
    return 'आपके योजना वाले योगदानों से लगभग $date तक।';
  }

  @override
  String get goalForecastAssumptions => 'यह कैसे निकाला गया';

  @override
  String get milestonesTitle => 'पड़ाव';

  @override
  String get milestonesEmpty => 'कोई पड़ाव नहीं।';

  @override
  String milestonePercent(int percent) {
    return 'लक्ष्य का $percent%';
  }

  @override
  String milestoneReachedOn(String date) {
    return '$date को पूरा हुआ';
  }

  @override
  String get milestoneNotReached => 'अभी बाकी है';

  @override
  String get milestonesHelp =>
      'ज़्यादा से ज़्यादा 10। हर पड़ाव पूरा होने पर चिह्नित हो जाता है।';

  @override
  String get milestoneAdd => 'पड़ाव जोड़ें';

  @override
  String get milestoneRemove => 'पड़ाव हटाएँ';

  @override
  String get milestonePercentLabel => 'लक्ष्य का प्रतिशत';

  @override
  String get milestoneNameLabel => 'नाम';

  @override
  String get milestonePercentInvalid => '1 से 100 के बीच कोई पूरा अंक लिखें।';

  @override
  String get milestoneDuplicate => 'हर पड़ाव का प्रतिशत अलग होना चाहिए।';

  @override
  String get contributionsTitle => 'योगदान';

  @override
  String get contributionsEmpty =>
      'अभी कोई योगदान नहीं। जब पैसे अलग रखें, तब जोड़ें।';

  @override
  String get contributionKindContribution => 'योगदान';

  @override
  String get contributionKindWithdrawal => 'निकासी';

  @override
  String get contributionStatusPlanned => 'योजना में';

  @override
  String get contributionStatusRecorded => 'दर्ज';

  @override
  String get contributionStatusVerified => 'पुष्टि हुई';

  @override
  String get contributionStatusUnknown => 'अन्य';

  @override
  String get contributionVoided => 'रद्द';

  @override
  String get contributionYou => 'आप';

  @override
  String get contributionAmountHidden => 'राशि छिपी है';

  @override
  String contributionShareOfTarget(String percent) {
    return 'लक्ष्य का $percent';
  }

  @override
  String get contributionLinkedTransaction => 'लेन-देन से जुड़ा है';

  @override
  String get contributionOpenTransaction => 'जुड़ा हुआ लेन-देन खोलें';

  @override
  String get contributionVoid => 'रद्द करें';

  @override
  String contributionVoidTooltip(String date) {
    return '$date का अपना योगदान रद्द करें';
  }

  @override
  String get contributionVoidConfirmTitle => 'क्या यह योगदान रद्द करें?';

  @override
  String get contributionVoidConfirmBody =>
      'यह लक्ष्य में गिना जाना बंद हो जाएगा, पर इतिहास में रहेगा।';

  @override
  String get contributionVoidedDone => 'योगदान रद्द किया गया।';

  @override
  String contributionNewTitle(String name) {
    return '$name में जोड़ें';
  }

  @override
  String get contributionAmountLabel => 'जोड़ी गई राशि';

  @override
  String get contributionWithdrawalAmountLabel => 'निकाली गई राशि';

  @override
  String get contributionPlannedHelp =>
      'योजना में: जो पैसे आप अलग रखना चाहते हैं। इन्हें अभी बचत में नहीं गिना जाता।';

  @override
  String get contributionRecordedHelp =>
      'दर्ज: आपने पैसे अलग रख दिए हैं। इन्हें बचत में गिना जाता है।';

  @override
  String get contributionTransactionLabel => 'जुड़ा हुआ लेन-देन';

  @override
  String get contributionTransactionPlaceholder =>
      'वह लेन-देन चुनें जिससे पैसे गए';

  @override
  String get contributionTransactionPickerTitle => 'किस लेन-देन से पैसे गए?';

  @override
  String get contributionTransactionHelp =>
      'इसे जोड़ने पर यह पुष्टि वाला हो जाता है। हर लेन-देन एक ही बार गिना जाता है।';

  @override
  String get contributionNoteLabel => 'नोट';

  @override
  String get contributionSave => 'योगदान सहेजें';

  @override
  String get contributionWithdrawalSave => 'निकासी सहेजें';

  @override
  String get contributionSavedDone => 'योगदान जोड़ा गया।';

  @override
  String get contributionWithdrawalSavedDone => 'निकासी दर्ज की गई।';

  @override
  String get contributionGoalInactive =>
      'योगदान सिर्फ़ चालू लक्ष्यों में जोड़े जा सकते हैं।';

  @override
  String get goalMembersTitle => 'किसके साथ साझा';

  @override
  String get goalMembersEmpty => 'अभी किसी के साथ साझा नहीं किया गया।';

  @override
  String get goalAddMember => 'व्यक्ति जोड़ें';

  @override
  String get goalAddFromConnections => 'अपने कनेक्शन से';

  @override
  String get goalAddFromGroup => 'इस लक्ष्य के समूह से';

  @override
  String goalMemberYou(String name) {
    return '$name (आप)';
  }

  @override
  String goalMemberRoleTitle(String name) {
    return '$name क्या कर सकते हैं?';
  }

  @override
  String get goalMemberRoleContributor => 'योगदान जोड़ सकते हैं';

  @override
  String get goalMemberRoleViewer => 'सिर्फ़ देख सकते हैं';

  @override
  String get goalMemberVisibilityAmounts => 'राशि दिखाते हैं';

  @override
  String get goalMemberVisibilityPercent => 'सिर्फ़ प्रतिशत दिखाते हैं';

  @override
  String get goalMemberVisibilityHidden => 'योगदान निजी रखते हैं';

  @override
  String get goalMyVisibilityTitle => 'दूसरों को आपके योगदान में क्या दिखे';

  @override
  String goalMemberAddedDone(String name) {
    return '$name जोड़े गए।';
  }

  @override
  String get goalMemberUpdatedDone => 'साझा करने की सेटिंग बदली गई।';

  @override
  String get goalMemberRemove => 'लक्ष्य से हटाएँ';

  @override
  String goalMemberRemoveConfirmTitle(String name) {
    return '$name को हटाएँ?';
  }

  @override
  String goalMemberRemoveConfirmBody(String name) {
    return '$name अब यह लक्ष्य नहीं देख पाएँगे। उनके पिछले योगदान इतिहास में रहेंगे।';
  }

  @override
  String goalMemberRemovedDone(String name) {
    return '$name हटाए गए।';
  }

  @override
  String get goalDetailsTitle => 'विवरण';

  @override
  String get goalVisibilityLabel => 'कौन देख सकता है';

  @override
  String get goalRemindersDetail => 'रिमाइंडर';

  @override
  String get goalEditTitle => 'लक्ष्य बदलें';

  @override
  String get goalNameLabel => 'लक्ष्य का नाम';

  @override
  String get goalNameHelp => 'जैसे \"आपात फ़ंड\" या \"गोवा यात्रा\"।';

  @override
  String get goalTypeLabel => 'लक्ष्य का प्रकार';

  @override
  String get goalTypeRequired => 'चुनें कि यह किस तरह का लक्ष्य है।';

  @override
  String get goalTargetAmountLabel => 'लक्ष्य राशि';

  @override
  String get goalStartingAmountLabel => 'पहले से बचत';

  @override
  String get goalStartingAmountHelp =>
      'इस लक्ष्य को ट्रैक करने से पहले की बचत।';

  @override
  String get goalDatesSection => 'तारीख़ें';

  @override
  String get goalStartDateLabel => 'शुरू होने की तारीख़';

  @override
  String get goalTargetDateLabel => 'पूरा करने की तारीख़';

  @override
  String get goalTargetDateHelp => 'इससे पता चलता है कि कितना अलग रखना है।';

  @override
  String get goalPlanSection => 'योजना';

  @override
  String get goalScheduleLabel => 'आप कितनी बार जोड़ना चाहते हैं';

  @override
  String get goalScheduleNone => 'कोई तय योजना नहीं';

  @override
  String get goalPlannedContributionLabel => 'हर बार की तय राशि';

  @override
  String get goalRemindersLabel => 'इस लक्ष्य के बारे में याद दिलाएँ';

  @override
  String get goalPriorityLabel => 'प्राथमिकता';

  @override
  String get goalPriorityHelp => '1 सबसे ज़रूरी है।';

  @override
  String get goalPriorityHighest => 'सबसे ज़्यादा';

  @override
  String get goalPriorityHigh => 'ज़्यादा';

  @override
  String get goalPriorityMedium => 'मध्यम';

  @override
  String get goalPriorityLow => 'कम';

  @override
  String get goalPriorityLowest => 'सबसे कम';

  @override
  String get goalLinkedAccountLabel => 'जुड़ा हुआ खाता';

  @override
  String get goalLinkedAccountNone => 'कोई खाता नहीं';

  @override
  String get goalLinkedAccountHelp =>
      'सिर्फ़ आपकी जानकारी के लिए। इसका बैलेंस अपने-आप नहीं गिना जाता।';

  @override
  String get goalSharingSection => 'साझा करना';

  @override
  String get goalVisibilityPrivate => 'निजी';

  @override
  String get goalVisibilityMembers => 'सदस्य';

  @override
  String get goalVisibilityHelp =>
      'निजी: सिर्फ़ आप देखते हैं। सदस्य: जिन्हें आप जोड़ते हैं वे इसे देख सकते हैं और अनुमति हो तो योगदान कर सकते हैं।';

  @override
  String get goalGroupLabel => 'समूह';

  @override
  String get goalGroupHelp =>
      'किसी समूह के साथ साझा करें ताकि उसके सदस्य भी जुड़ सकें।';

  @override
  String get goalMoreSection => 'और जानकारी';

  @override
  String get goalCreate => 'लक्ष्य बनाएँ';

  @override
  String get goalCreatedDone => 'लक्ष्य बनाया गया।';

  @override
  String get goalSavedDone => 'लक्ष्य सहेजा गया।';

  @override
  String get goalExportTitle => 'योगदान निर्यात करें';

  @override
  String get goalExportIntro =>
      'इस CSV में हर योगदान है, रद्द किए गए भी। इसे कॉपी करके किसी स्प्रेडशीट या नोट में चिपकाएँ।';

  @override
  String get goalExportFileLabel => 'फ़ाइल का नाम';

  @override
  String get goalExportRowsLabel => 'पंक्तियाँ';

  @override
  String goalExportRows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count पंक्तियाँ',
      one: '1 पंक्ति',
      zero: 'अभी कोई पंक्ति नहीं',
    );
    return '$_temp0';
  }

  @override
  String get goalExportEmpty =>
      'अभी कोई योगदान नहीं है, इसलिए सिर्फ़ कॉलम के नाम शामिल हैं।';

  @override
  String get goalExportCopy => 'CSV कॉपी करें';

  @override
  String get goalExportCopied =>
      'CSV कॉपी हो गई। इसमें आपकी राशियाँ और नोट हैं, इसलिए इसे सिर्फ़ भरोसेमंद जगह पर चिपकाएँ।';

  @override
  String get goalExportPreviewTitle => 'झलक';

  @override
  String get budgetsTitle => 'बजट';

  @override
  String get budgetAdd => 'नया बजट';

  @override
  String get budgetAddFirst => 'बजट बनाएँ';

  @override
  String get budgetsShowArchived => 'संग्रहित बजट भी दिखाएँ';

  @override
  String get budgetsEmptyTitle => 'अभी कोई बजट नहीं';

  @override
  String get budgetsEmptyBody =>
      'बजट एक हफ़्ते, महीने या साल के खर्च की सीमा तय करता है। Montra दिखाता है कि कितना बचा है और खर्च सही रफ़्तार पर है या नहीं।';

  @override
  String get budgetAlertsTitle => 'बजट अलर्ट';

  @override
  String get budgetTypeTotal => 'कुल खर्च';

  @override
  String get budgetTypeCategory => 'श्रेणी के हिसाब से';

  @override
  String get budgetTypeMerchant => 'व्यापारी के हिसाब से';

  @override
  String get budgetTypeAccount => 'खाते के हिसाब से';

  @override
  String get budgetTypeEnvelope => 'लिफ़ाफ़े';

  @override
  String get budgetTypeZeroBased => 'ज़ीरो-बेस्ड';

  @override
  String get budgetTypeUnknown => 'अन्य बजट';

  @override
  String get budgetTypeTotalHelp => 'आपके पूरे खर्च के लिए एक सीमा।';

  @override
  String get budgetTypeCategoryHelp => 'आपकी चुनी हुई श्रेणियों के लिए सीमाएँ।';

  @override
  String get budgetTypeMerchantHelp => 'आपके चुने हुए व्यापारियों पर खर्च।';

  @override
  String get budgetTypeAccountHelp => 'आपके चुने हुए खातों से खर्च।';

  @override
  String get budgetTypeEnvelopeHelp =>
      'सीमा को लिफ़ाफ़ों में बाँटें, हर श्रेणी के लिए एक।';

  @override
  String get budgetTypeZeroBasedHelp =>
      'सीमा के हर हिस्से को काम दें: लिफ़ाफ़ों का जोड़ ठीक सीमा के बराबर होना चाहिए।';

  @override
  String get budgetTypeGroupHelp => 'समूह बजट समूह के सभी साझा खर्च गिनते हैं।';

  @override
  String get budgetPeriodWeekly => 'साप्ताहिक';

  @override
  String get budgetPeriodMonthly => 'मासिक';

  @override
  String get budgetPeriodAnnual => 'सालाना';

  @override
  String get budgetPeriodCustom => 'अपनी तारीखें';

  @override
  String get budgetPeriodUnknown => 'अन्य अवधि';

  @override
  String get budgetStatusActive => 'चालू';

  @override
  String get budgetStatusPaused => 'रुका हुआ';

  @override
  String get budgetStatusArchived => 'संग्रहित';

  @override
  String get budgetStatusUnknown => 'उपलब्ध नहीं';

  @override
  String get budgetAccessEditor => 'आपके साथ साझा · बदल सकते हैं';

  @override
  String get budgetAccessViewer => 'आपके साथ साझा · सिर्फ़ देख सकते हैं';

  @override
  String budgetSharedWith(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count लोगों के साथ साझा',
      one: '1 व्यक्ति के साथ साझा',
    );
    return '$_temp0';
  }

  @override
  String budgetGroupLabel(String name) {
    return 'समूह: $name';
  }

  @override
  String get budgetGroupUnknown => 'एक समूह';

  @override
  String get budgetPaceUnder => 'योजना से धीमा खर्च';

  @override
  String get budgetPaceOnTrack => 'सही रफ़्तार पर';

  @override
  String get budgetPaceAhead => 'योजना से तेज़ खर्च';

  @override
  String get budgetPaceOver => 'सीमा से ज़्यादा';

  @override
  String get budgetPaceUnknown => 'रफ़्तार की जानकारी नहीं';

  @override
  String budgetSpentOf(String spent, String limit) {
    return '$limit में से $spent खर्च';
  }

  @override
  String budgetLeft(String amount) {
    return '$amount बचा है';
  }

  @override
  String budgetOverBy(String amount) {
    return 'सीमा से $amount ज़्यादा';
  }

  @override
  String budgetPercentUsed(String percent) {
    return '$percent इस्तेमाल हुआ';
  }

  @override
  String get budgetNoProgressPaused => 'रुका रहने तक प्रगति नहीं गिनी जाती।';

  @override
  String get budgetNoProgressArchived => 'इसका इतिहास सुरक्षित है।';

  @override
  String get budgetDetailTitle => 'बजट';

  @override
  String get budgetThisPeriod => 'यह अवधि';

  @override
  String budgetDayOf(int day, int total) {
    return '$total में से दिन $day';
  }

  @override
  String get budgetRemainingLabel => 'खर्च के लिए बचा';

  @override
  String get budgetOverspentLabel => 'सीमा से इतना ज़्यादा';

  @override
  String get budgetDailyAllowanceLabel => 'बाकी अवधि में हर दिन';

  @override
  String get budgetExpectedByNowLabel => 'बराबर रफ़्तार से अब तक का अनुमान';

  @override
  String get budgetProjectedLabel => 'पूरी अवधि का अनुमान';

  @override
  String get budgetProjectedOverLabel => 'इतना ज़्यादा हो सकता है';

  @override
  String get budgetRolloverInLabel => 'पिछली अवधि से आगे आया';

  @override
  String get budgetBaseLimitLabel => 'मूल सीमा';

  @override
  String get budgetLimitLabel => 'सीमा';

  @override
  String get budgetCountedLabel => 'गिने गए लेन-देन';

  @override
  String budgetAsOf(String time) {
    return '$time तक के कुल आँकड़े';
  }

  @override
  String get budgetHowCalculated => 'यह कैसे गिना जाता है';

  @override
  String budgetExplainSpent(
    String spent,
    String limit,
    String from,
    String to,
  ) {
    return '$from और $to के बीच $limit में से $spent खर्च हुआ।';
  }

  @override
  String get budgetExplainRefundsRestore =>
      'ट्रांसफ़र और शेष राशि समायोजन कभी नहीं गिने जाते। रिफ़ंड इस बजट में पैसे वापस जोड़ते हैं।';

  @override
  String get budgetExplainRefundsIgnored =>
      'ट्रांसफ़र और शेष राशि समायोजन कभी नहीं गिने जाते। रिफ़ंड से इस बजट पर कोई असर नहीं पड़ता।';

  @override
  String get budgetExplainPending => 'लंबित लेन-देन भी गिने जाते हैं।';

  @override
  String get budgetExplainPostedOnly =>
      'सिर्फ़ दर्ज हो चुके लेन-देन गिने जाते हैं।';

  @override
  String budgetExplainCarry(String amount) {
    return 'इसमें पिछली अवधि से आगे आए $amount शामिल हैं।';
  }

  @override
  String budgetExplainProjected(String amount) {
    return 'इसी रफ़्तार से आप अवधि के अंत तक लगभग $amount खर्च करेंगे। यह सिर्फ़ एक अनुमान है।';
  }

  @override
  String budgetExplainOtherCurrency(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'दूसरी मुद्राओं के $count मिलते-जुलते लेन-देन शामिल नहीं हैं।',
      one: 'दूसरी मुद्रा का 1 मिलता-जुलता लेन-देन शामिल नहीं है।',
    );
    return '$_temp0';
  }

  @override
  String get budgetExplainCollaborator =>
      'आपको सिर्फ़ मालिक के कुल आँकड़े दिखते हैं; उनके लेन-देन निजी रहते हैं।';

  @override
  String get budgetExplainGroup => 'यह बजट समूह के साझा खर्च गिनता है।';

  @override
  String get budgetHistoryTitle => 'अवधियों की तुलना';

  @override
  String get budgetHistoryEarlier => 'पिछली अवधि';

  @override
  String get budgetHistoryLater => 'अगली अवधि';

  @override
  String budgetHistoryRow(String period, String spent, String limit) {
    return '$period: $limit में से $spent खर्च।';
  }

  @override
  String get budgetTransactionsTitle => 'गिने गए लेन-देन';

  @override
  String get budgetTransactionsEmpty =>
      'इस अवधि में अभी तक कुछ भी इस बजट में नहीं गिना गया।';

  @override
  String get budgetTransactionsOwnerOnly =>
      'अलग-अलग लेन-देन सिर्फ़ मालिक देख सकता है। आपको कुल आँकड़े दिखते हैं।';

  @override
  String get budgetTransactionsGroup =>
      'समूह बजट समूह के खर्च गिनते हैं। उन्हें देखने के लिए समूह खोलें।';

  @override
  String budgetTransactionsShowAll(int count) {
    return 'सभी $count दिखाएँ';
  }

  @override
  String budgetTransactionsCapped(int count) {
    return 'पहले $count लेन-देन दिखाए जा रहे हैं।';
  }

  @override
  String get budgetAllocationsTitle => 'इस बजट के अंदर की सीमाएँ';

  @override
  String get budgetEnvelopesTitle => 'लिफ़ाफ़े';

  @override
  String budgetAllocationMember(String name) {
    return '$name का हिस्सा';
  }

  @override
  String get budgetAllocationYou => 'आपका हिस्सा';

  @override
  String get budgetAllocationUnnamed => 'बिना नाम की सीमा';

  @override
  String get budgetAllocationRemoved => 'हटाया गया आइटम';

  @override
  String get budgetAllocationAdd => 'सीमा जोड़ें';

  @override
  String get budgetAllocationEdit => 'सीमा बदलें';

  @override
  String get budgetAllocationTargetLabel => 'किस पर लागू';

  @override
  String get budgetAllocationTargetCategory => 'एक श्रेणी';

  @override
  String get budgetAllocationTargetMerchant => 'एक व्यापारी';

  @override
  String get budgetAllocationTargetAccount => 'एक खाता';

  @override
  String get budgetAllocationTargetMember => 'समूह के सदस्य का हिस्सा';

  @override
  String get budgetAllocationTargetName => 'सिर्फ़ एक नाम';

  @override
  String get budgetAllocationNameLabel => 'इस सीमा का नाम';

  @override
  String get budgetAllocationChoose => 'चुनें';

  @override
  String get budgetAllocationTargetRequired =>
      'चुनें कि यह सीमा किस पर लागू है।';

  @override
  String get budgetAllocationsNeeded => 'कम से कम एक सीमा जोड़ें।';

  @override
  String get budgetAllocationsHelp =>
      'इस बजट के हिस्सों के लिए वैकल्पिक सीमाएँ।';

  @override
  String get budgetZeroBasedHelp =>
      'लिफ़ाफ़ों का जोड़ ठीक सीमा के बराबर होना चाहिए।';

  @override
  String get budgetZeroBasedUnallocated =>
      'लिफ़ाफ़ों का जोड़ अभी सीमा के बराबर नहीं है। किसी लिफ़ाफ़े या सीमा को बदलें ताकि दोनों ठीक बराबर हों।';

  @override
  String budgetRemoveItem(String name) {
    return '$name हटाएँ';
  }

  @override
  String budgetEditItem(String name) {
    return '$name बदलें';
  }

  @override
  String budgetAllocationValue(String spent, String limit) {
    return '$limit में से $spent';
  }

  @override
  String get budgetNewTitle => 'नया बजट';

  @override
  String get budgetEditTitle => 'बजट बदलें';

  @override
  String get budgetNameLabel => 'बजट का नाम';

  @override
  String get budgetNameHelp => 'जैसे \"महीने का खर्च\" या \"राशन\"।';

  @override
  String get budgetTypeLabel => 'प्रकार';

  @override
  String get budgetPeriodLabel => 'अवधि';

  @override
  String get budgetStartsOnLabel => 'शुरू होने की तारीख';

  @override
  String get budgetEndsOnLabel => 'खत्म होने की तारीख';

  @override
  String get budgetEndsOnRequired =>
      'अपनी तारीखों वाले बजट में खत्म होने की तारीख ज़रूरी है।';

  @override
  String get budgetLimitHelp =>
      'हर अवधि में आप ज़्यादा से ज़्यादा कितना खर्च करना चाहते हैं।';

  @override
  String get budgetGroupField => 'समूह';

  @override
  String get budgetGroupHelp =>
      'किसी परिवार, यात्रा या दूसरे समूह के साझा खर्च पर नज़र रखें।';

  @override
  String get budgetGroupFixed => 'बजट बनने के बाद समूह नहीं बदला जा सकता।';

  @override
  String get budgetCurrencyFromGroup =>
      'समूह बजट में समूह की मुद्रा इस्तेमाल होती है।';

  @override
  String get budgetScopeSection => 'क्या गिना जाएगा';

  @override
  String get budgetMerchantsLabel => 'व्यापारी';

  @override
  String get budgetMerchantsNeeded => 'कम से कम एक व्यापारी चुनें।';

  @override
  String get budgetAddMerchant => 'व्यापारी जोड़ें';

  @override
  String get budgetAccountsLabel => 'सिर्फ़ ये खाते';

  @override
  String get budgetAccountsAll => 'सभी खाते';

  @override
  String get budgetAccountsNeeded => 'कम से कम एक खाता चुनें।';

  @override
  String get budgetExcludedLabel => 'इन श्रेणियों को छोड़ दें';

  @override
  String get budgetNothingExcluded => 'कुछ नहीं छोड़ा गया';

  @override
  String get budgetIncludePending => 'लंबित लेन-देन भी गिनें';

  @override
  String get budgetRefundsRestore => 'रिफ़ंड से बजट में पैसे वापस जुड़ें';

  @override
  String get budgetCountGroupShares => 'समूह के खर्च में मेरा हिस्सा गिनें';

  @override
  String get budgetRolloverSection => 'आगे ले जाना';

  @override
  String get budgetRolloverLabel => 'अवधि के अंत में';

  @override
  String get budgetRolloverNone => 'हर अवधि नए सिरे से शुरू करें';

  @override
  String get budgetRolloverUnused => 'बचे हुए पैसे आगे ले जाएँ';

  @override
  String get budgetRolloverOverspend => 'ज़्यादा खर्च को आगे ले जाएँ';

  @override
  String get budgetRolloverBoth => 'दोनों को आगे ले जाएँ';

  @override
  String get budgetRolloverUnknown => 'अन्य';

  @override
  String get budgetRolloverCapLabel =>
      'ज़्यादा से ज़्यादा कितना आगे जा सकता है';

  @override
  String get budgetRolloverCapHelp => 'कोई सीमा न रखनी हो तो खाली छोड़ें।';

  @override
  String get budgetRolloverCustomNote =>
      'अपनी तारीखों वाले बजट में कुछ भी आगे नहीं जाता।';

  @override
  String get budgetAlertsSection => 'अलर्ट';

  @override
  String get budgetThresholdsLabel => 'मुझे बताएँ जब इतना इस्तेमाल हो जाए';

  @override
  String budgetThresholdsHelp(int max) {
    return '1 से $max तक चुनें।';
  }

  @override
  String budgetThresholdValue(int value) {
    return '$value%';
  }

  @override
  String get budgetForecastAlert =>
      'अगर सीमा पार होने की संभावना हो तो मुझे बताएँ';

  @override
  String get budgetForecastHelp =>
      'आपके खर्च की रफ़्तार पर आधारित। यह एक अनुमान है।';

  @override
  String get budgetVisibilityLabel => 'इसे कौन देख सकता है';

  @override
  String get budgetVisibilityMembers => 'समूह के सभी लोग';

  @override
  String get budgetVisibilityPrivate => 'सिर्फ़ मैं और जिन्हें मैं जोड़ूँ';

  @override
  String get budgetCreateButton => 'बजट बनाएँ';

  @override
  String get budgetCreated => 'बजट बन गया।';

  @override
  String get budgetSaved => 'बजट सेव हो गया।';

  @override
  String get budgetEditAppliesNote =>
      'बदलाव इस अवधि से आगे लागू होंगे। पिछली अवधियों के आँकड़े वैसे ही रहेंगे।';

  @override
  String get budgetTypeUnknownNote =>
      'ऐप का यह संस्करण इस बजट प्रकार को नहीं समझता। बदलाव सेव करने के लिए कोई प्रकार चुनें।';

  @override
  String get budgetSettingsTitle => 'सेटिंग';

  @override
  String get budgetThresholdsShort => 'अलर्ट के स्तर';

  @override
  String get budgetForecastShort => 'ज़्यादा खर्च का अनुमान';

  @override
  String get budgetTimezoneLabel => 'समय क्षेत्र';

  @override
  String get budgetMembersTitle => 'किनके साथ साझा';

  @override
  String get budgetYouOwn => 'यह बजट आपका है।';

  @override
  String get budgetMembersEmpty => 'यह बजट सिर्फ़ आप देख सकते हैं।';

  @override
  String get budgetMembersGroupNote =>
      'अगर आप \"समूह के सभी लोग\" चुनें, तो समूह के सदस्य इसे देख सकते हैं।';

  @override
  String get budgetMemberAdd => 'व्यक्ति जोड़ें';

  @override
  String get budgetRoleEditor => 'बदल सकते हैं';

  @override
  String get budgetRoleViewer => 'देख सकते हैं';

  @override
  String get budgetRoleLabel => 'पहुँच';

  @override
  String get budgetMemberAllocationLabel => 'सीमा में उनका हिस्सा';

  @override
  String get budgetMemberAllocationHelp =>
      'वैकल्पिक। उन्हें सीमा में उनके हिस्से के रूप में दिखेगा।';

  @override
  String budgetMemberShareTitle(String name) {
    return '$name के साथ साझा करें';
  }

  @override
  String budgetMemberEditTitle(String name) {
    return '$name की पहुँच';
  }

  @override
  String get budgetMemberShareButton => 'साझा करें';

  @override
  String get budgetMemberRemove => 'बजट से हटाएँ';

  @override
  String budgetMemberRemoveTitle(String name) {
    return '$name को हटाएँ?';
  }

  @override
  String get budgetMemberRemoveBody =>
      'वे अब यह बजट नहीं देख पाएँगे। आप उन्हें बाद में फिर से जोड़ सकते हैं।';

  @override
  String budgetMemberAdded(String name) {
    return '$name अब यह बजट देख सकते हैं।';
  }

  @override
  String get budgetMemberUpdated => 'पहुँच बदल दी गई।';

  @override
  String budgetMemberRemoved(String name) {
    return '$name को हटा दिया गया।';
  }

  @override
  String budgetMemberShare(String amount) {
    return 'हिस्सा: $amount';
  }

  @override
  String get budgetLeave => 'यह बजट छोड़ें';

  @override
  String get budgetLeaveTitle => 'यह बजट छोड़ें?';

  @override
  String get budgetLeaveBody =>
      'यह आपको दिखना बंद हो जाएगा। मालिक आपको फिर से जोड़ सकता है।';

  @override
  String get budgetLeaveDone => 'आपने बजट छोड़ दिया।';

  @override
  String get budgetPause => 'रोकें';

  @override
  String get budgetResume => 'फिर से चालू करें';

  @override
  String get budgetArchive => 'संग्रहित करें';

  @override
  String get budgetPaused => 'बजट रोक दिया गया।';

  @override
  String get budgetResumed => 'बजट फिर से चालू हो गया।';

  @override
  String get budgetArchived => 'बजट संग्रहित हो गया। इसका इतिहास सुरक्षित है।';

  @override
  String get budgetRestored => 'बजट वापस आ गया।';

  @override
  String get budgetArchiveTitle => 'यह बजट संग्रहित करें?';

  @override
  String budgetArchiveBody(String name) {
    return '$name खर्च गिनना बंद कर देगा, और इसका इतिहास सुरक्षित रहेगा। आप इसे बाद में वापस ला सकते हैं।';
  }

  @override
  String get budgetPausedNotice =>
      'यह बजट रुका हुआ है। फिर से चालू करने तक इसमें खर्च नहीं गिना जाएगा।';

  @override
  String get budgetArchivedNotice =>
      'यह बजट संग्रहित है। इसका इतिहास सुरक्षित है; फिर से खर्च गिनने के लिए इसे वापस लाएँ।';

  @override
  String get budgetAlertStatusActive => 'चालू';

  @override
  String get budgetAlertStatusSnoozed => 'स्नूज़ किए गए';

  @override
  String get budgetAlertStatusDismissed => 'हटाए गए';

  @override
  String get budgetAlertStatusAll => 'सभी';

  @override
  String get budgetAlertFilterLabel => 'अलर्ट दिखाएँ';

  @override
  String budgetAlertThreshold(String name, int percent) {
    return '$name: सीमा का $percent% इस्तेमाल हुआ';
  }

  @override
  String budgetAlertFullyUsed(String name) {
    return '$name: पूरी सीमा इस्तेमाल हो गई';
  }

  @override
  String budgetAlertForecast(String name) {
    return '$name की सीमा पार हो सकती है';
  }

  @override
  String get budgetAlertForecastBody =>
      'इसी रफ़्तार से अवधि खत्म होने से पहले यह बजट पार हो सकता है। यह एक अनुमान है।';

  @override
  String budgetAlertUnusual(String name) {
    return '$name में असामान्य खर्च';
  }

  @override
  String budgetAlertOther(String name) {
    return '$name के बारे में जानकारी';
  }

  @override
  String budgetAlertPeriod(String date) {
    return '$date से शुरू अवधि';
  }

  @override
  String budgetAlertTriggered(String time) {
    return '$time को दिखा';
  }

  @override
  String budgetAlertSnoozedUntil(String time) {
    return '$time तक स्नूज़';
  }

  @override
  String get budgetAlertDismiss => 'हटाएँ';

  @override
  String get budgetAlertSnooze => 'स्नूज़ करें';

  @override
  String get budgetAlertReactivate => 'फिर से दिखाएँ';

  @override
  String get budgetAlertDismissed => 'अलर्ट हटा दिया गया।';

  @override
  String budgetAlertSnoozedDone(String time) {
    return '$time तक अलर्ट स्नूज़ किया गया।';
  }

  @override
  String get budgetAlertReactivated => 'अलर्ट फिर से चालू है।';

  @override
  String get budgetSnoozeTitle => 'कब तक स्नूज़ करें';

  @override
  String get budgetSnoozeDay => '1 दिन के लिए';

  @override
  String get budgetSnooze3Days => '3 दिन के लिए';

  @override
  String get budgetSnoozeWeek => 'एक हफ़्ते के लिए';

  @override
  String get budgetSnoozePickDate => 'किसी तारीख तक…';

  @override
  String get budgetAlertsEmptyActive =>
      'कोई चालू अलर्ट नहीं है। जब कोई बजट आपके चुने हुए स्तर तक पहुँचेगा, तो अलर्ट यहाँ दिखेगा।';

  @override
  String get budgetAlertsEmptyOther => 'यहाँ कुछ नहीं है।';

  @override
  String budgetAlertsBannerTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count बजट अलर्ट',
      one: '1 बजट अलर्ट',
    );
    return '$_temp0';
  }

  @override
  String get budgetAlertsBannerReview => 'देखें';

  @override
  String get budgetHistoryEmpty => 'इस अवधि के अभी कोई आँकड़े नहीं हैं।';

  @override
  String get categoriesTitle => 'श्रेणियाँ';

  @override
  String get categoriesIntro =>
      'श्रेणियाँ आपके खर्च और आय को समूहों में रखती हैं। उप-श्रेणियाँ किसी मुख्य श्रेणी के नीचे रहती हैं।';

  @override
  String get categoriesShowArchived => 'संग्रहित और मिलाई गई भी दिखाएँ';

  @override
  String get categoriesEmptyTitle => 'अभी कोई श्रेणी नहीं है';

  @override
  String get categoriesEmptyBody =>
      'अपने लेन-देन छाँटने के लिए एक श्रेणी जोड़ें।';

  @override
  String get categoryNew => 'नई श्रेणी';

  @override
  String get categoryNewTitle => 'नई श्रेणी';

  @override
  String get categoryEditTitle => 'श्रेणी बदलें';

  @override
  String get categoryEdit => 'बदलें';

  @override
  String categoryActionsFor(String name) {
    return '$name के लिए और विकल्प';
  }

  @override
  String get categoryAddSubcategory => 'उप-श्रेणी जोड़ें';

  @override
  String get categoryMergeInto => 'दूसरी श्रेणी में मिलाएँ';

  @override
  String get categoryMergeIntoHelp =>
      'इसके लेन-देन और सेटिंग्स दूसरी श्रेणी में चले जाते हैं, फिर यह बंद हो जाती है।';

  @override
  String get categoryArchive => 'संग्रहित करें';

  @override
  String get categoryArchiveHelp =>
      'चुनने की सूची से छिप जाती है; पुराने लेन-देन में बनी रहती है।';

  @override
  String get categoryRestore => 'वापस लाएँ';

  @override
  String get categoryDelete => 'हटाएँ';

  @override
  String categoryDeleteTitle(String name) {
    return '“$name” हटाएँ?';
  }

  @override
  String get categoryDeleteBody =>
      'इस श्रेणी का कहीं उपयोग नहीं हो रहा है। हटाने के बाद इसे वापस नहीं लाया जा सकता।';

  @override
  String categoryDeleted(String name) {
    return '“$name” हटा दी गई।';
  }

  @override
  String categoryArchived(String name) {
    return '“$name” संग्रहित की गई। पुराने लेन-देन में यह बनी रहेगी।';
  }

  @override
  String categoryRestored(String name) {
    return '“$name” वापस लाई गई।';
  }

  @override
  String get categoryInUse =>
      'कुछ रिकॉर्ड अभी भी इस श्रेणी का उपयोग करते हैं। इसके बजाय इसे दूसरी श्रेणी में मिलाएँ या संग्रहित करें।';

  @override
  String get categoryMerge => 'मिलाएँ';

  @override
  String categoryMergeTargetTitle(String name) {
    return '“$name” को किसमें मिलाएँ…';
  }

  @override
  String categoryMergeTitle(String source, String target) {
    return '“$source” को “$target” में मिलाएँ?';
  }

  @override
  String categoryMergeBody(String moves, String name) {
    return 'ये नई श्रेणी में चले जाएँगे:\n$moves\n\nइसके बाद “$name” मिलाई गई के रूप में दिखेगी। इसे वापस नहीं किया जा सकता।';
  }

  @override
  String categoryMergeNothing(String name) {
    return 'अभी “$name” का कहीं उपयोग नहीं है। इसे मिलाई गई के रूप में दिखाया जाएगा। इसे वापस नहीं किया जा सकता।';
  }

  @override
  String categoryMerged(String source, String target) {
    return '“$source” को “$target” में मिला दिया गया।';
  }

  @override
  String categoryCreated(String name) {
    return 'श्रेणी “$name” जोड़ी गई।';
  }

  @override
  String get categorySaved => 'श्रेणी सहेजी गई।';

  @override
  String get categoryNotFound => 'यह श्रेणी अब उपलब्ध नहीं है।';

  @override
  String get categoryStarterNote =>
      'यह Montra की शुरुआती श्रेणियों में से एक है। आप इसका नाम बदल सकते हैं; तब तक यह आपकी भाषा में दिखेगी।';

  @override
  String get categoryNameLabel => 'नाम';

  @override
  String get categoryNameRequired => 'नाम लिखें।';

  @override
  String get categoryKindLabel => 'किसके लिए';

  @override
  String get categoryKindExpense => 'खर्च';

  @override
  String get categoryKindIncome => 'आय';

  @override
  String get categoryKindBoth => 'दोनों';

  @override
  String get categoryKindOther => 'अन्य';

  @override
  String get categoryParentLabel => 'मुख्य श्रेणी';

  @override
  String get categoryParentNone => 'कोई नहीं (यह मुख्य श्रेणी है)';

  @override
  String get categoryParentHelp => 'इसे उप-श्रेणी बनाने के लिए एक चुनें।';

  @override
  String get categoryParentHasChildren =>
      'इस श्रेणी में उप-श्रेणियाँ हैं, इसलिए यह मुख्य श्रेणी ही रहेगी।';

  @override
  String get categoryIconLabel => 'आइकन';

  @override
  String get categoryIncludeInBudgets => 'बजट में गिनें';

  @override
  String get categoryIncludeInBudgetsHelp =>
      'जिन चीज़ों को बजट में नहीं गिनना है, उनके लिए बंद करें।';

  @override
  String get categoryNotInBudgets => 'बजट में नहीं';

  @override
  String get categorySortLabel => 'सूची में क्रम (वैकल्पिक)';

  @override
  String get categorySortHelp => 'छोटी संख्या पहले आती है।';

  @override
  String get categoryStatusArchived => 'संग्रहित';

  @override
  String get categoryStatusMerged => 'मिलाई गई';

  @override
  String categoryTransactionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count लेन-देन',
      one: '1 लेन-देन',
      zero: 'कोई लेन-देन नहीं',
    );
    return '$_temp0';
  }

  @override
  String get categoryIconCart => 'किराना';

  @override
  String get categoryIconFood => 'खाना';

  @override
  String get categoryIconTransport => 'आना-जाना';

  @override
  String get categoryIconFuel => 'ईंधन';

  @override
  String get categoryIconHome => 'घर';

  @override
  String get categoryIconUtilities => 'बिजली-पानी';

  @override
  String get categoryIconShopping => 'खरीदारी';

  @override
  String get categoryIconHealth => 'स्वास्थ्य';

  @override
  String get categoryIconEducation => 'पढ़ाई';

  @override
  String get categoryIconEntertainment => 'मनोरंजन';

  @override
  String get categoryIconTravel => 'यात्रा';

  @override
  String get categoryIconPersonalCare => 'निजी देखभाल';

  @override
  String get categoryIconInsurance => 'बीमा';

  @override
  String get categoryIconBills => 'बिल';

  @override
  String get categoryIconGifts => 'उपहार';

  @override
  String get categoryIconFamily => 'परिवार';

  @override
  String get categoryIconWork => 'काम';

  @override
  String get categoryIconMoney => 'पैसे';

  @override
  String get categoryIconTech => 'गैजेट';

  @override
  String get categoryIconSavings => 'बचत';

  @override
  String get categoryIconOther => 'अन्य';

  @override
  String get labelColorLabel => 'रंग';

  @override
  String get labelColorNone => 'कोई रंग नहीं';

  @override
  String get labelColorCustom => 'अपना रंग';

  @override
  String get labelColorRed => 'लाल';

  @override
  String get labelColorOrange => 'नारंगी';

  @override
  String get labelColorYellow => 'पीला';

  @override
  String get labelColorGreen => 'हरा';

  @override
  String get labelColorTeal => 'हरा-नीला';

  @override
  String get labelColorBlue => 'नीला';

  @override
  String get labelColorPurple => 'बैंगनी';

  @override
  String get labelColorPink => 'गुलाबी';

  @override
  String get labelColorBrown => 'भूरा';

  @override
  String get labelColorGrey => 'स्लेटी';

  @override
  String mergeAffectedTransactions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count लेन-देन',
      one: '1 लेन-देन',
    );
    return '$_temp0';
  }

  @override
  String mergeAffectedSubcategories(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count उप-श्रेणियाँ',
      one: '1 उप-श्रेणी',
    );
    return '$_temp0';
  }

  @override
  String mergeAffectedRules(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count श्रेणी नियम',
      one: '1 श्रेणी नियम',
    );
    return '$_temp0';
  }

  @override
  String mergeAffectedBudgets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count बजट सीमाएँ',
      one: '1 बजट सीमा',
    );
    return '$_temp0';
  }

  @override
  String mergeAffectedMerchants(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count दुकानों की डिफ़ॉल्ट श्रेणी',
      one: '1 दुकान की डिफ़ॉल्ट श्रेणी',
    );
    return '$_temp0';
  }

  @override
  String mergeAffectedRecurring(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count दोहराने वाले नियम',
      one: '1 दोहराने वाला नियम',
    );
    return '$_temp0';
  }

  @override
  String mergeAffectedBills(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count बिल',
      one: '1 बिल',
    );
    return '$_temp0';
  }

  @override
  String mergeAffectedSubscriptions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count सब्सक्रिप्शन',
      one: '1 सब्सक्रिप्शन',
    );
    return '$_temp0';
  }

  @override
  String mergeAffectedOther(String kind, int count) {
    return '$kind: $count';
  }

  @override
  String get categoryRulesTitle => 'श्रेणी नियम';

  @override
  String get categoryRulesIntro =>
      'जब किसी लेन-देन की दुकान या विवरण मेल खाता है, तो नियम अपने-आप श्रेणी लगा देते हैं। नियम क्रम से चलते हैं; पहला मेल खाने वाला नियम लागू होता है।';

  @override
  String get categoryRulesEmptyTitle => 'अभी कोई नियम नहीं है';

  @override
  String get categoryRulesEmptyBody =>
      'एक नियम जोड़ें, जैसे: दुकान में “swiggy” हो → खाना।';

  @override
  String get ruleNew => 'नया नियम';

  @override
  String get ruleNewTitle => 'नया नियम';

  @override
  String get ruleEditTitle => 'नियम बदलें';

  @override
  String get ruleNotFound => 'यह नियम अब उपलब्ध नहीं है।';

  @override
  String ruleSummary(
    String field,
    String match,
    String pattern,
    String category,
  ) {
    return '$field · $match · “$pattern” → $category';
  }

  @override
  String rulePriorityValue(int priority) {
    return 'क्रम $priority';
  }

  @override
  String get ruleStatusOff => 'बंद है';

  @override
  String get ruleCategoryMissing => 'श्रेणी उपलब्ध नहीं';

  @override
  String get ruleNameLabel => 'नियम का नाम';

  @override
  String get ruleNameHelp => 'सिर्फ़ आपके लिए, जैसे “खाना डिलीवरी”।';

  @override
  String get ruleNameRequired => 'नाम लिखें।';

  @override
  String get ruleWhenSection => 'कब';

  @override
  String get ruleThenSection => 'तब यह श्रेणी लगाएँ';

  @override
  String get ruleLimitsSection => 'सिर्फ़ इनके लिए (वैकल्पिक)';

  @override
  String get ruleFieldLabel => 'किसमें देखें';

  @override
  String get ruleFieldMerchant => 'दुकान';

  @override
  String get ruleFieldDescription => 'विवरण';

  @override
  String get ruleFieldAny => 'दुकान या विवरण';

  @override
  String get ruleMatchTypeLabel => 'मिलान';

  @override
  String get ruleMatchContains => 'में शामिल हो';

  @override
  String get ruleMatchEquals => 'बिल्कुल यही हो';

  @override
  String get ruleMatchStartsWith => 'से शुरू हो';

  @override
  String get ruleMatchRegex => 'पैटर्न से मेल खाए';

  @override
  String get rulePatternLabel => 'मिलाने वाला शब्द';

  @override
  String get rulePatternHelp => 'बड़े-छोटे अक्षरों से फ़र्क नहीं पड़ता।';

  @override
  String get rulePatternRegexHelp => 'उन्नत: एक रेगुलर एक्सप्रेशन।';

  @override
  String get rulePatternRequired => 'मिलाने वाला शब्द लिखें।';

  @override
  String get ruleCategoryLabel => 'श्रेणी';

  @override
  String get ruleCategoryPlaceholder => 'श्रेणी चुनें';

  @override
  String get ruleCategoryRequired => 'लगाने के लिए श्रेणी चुनें।';

  @override
  String get ruleTypeLabel => 'लेन-देन का प्रकार';

  @override
  String get ruleTypeAny => 'कोई भी प्रकार';

  @override
  String get ruleTypeExpense => 'खर्च';

  @override
  String get ruleTypeIncome => 'आय';

  @override
  String get ruleAccountLabel => 'खाता';

  @override
  String get ruleAccountAny => 'कोई भी खाता';

  @override
  String get ruleAmountMin => 'सबसे कम राशि (वैकल्पिक)';

  @override
  String get ruleAmountMax => 'सबसे ज़्यादा राशि (वैकल्पिक)';

  @override
  String ruleAmountHelp(String currency) {
    return 'राशि $currency में है। किसी भी राशि के लिए खाली छोड़ें।';
  }

  @override
  String get ruleApplyToLabel => 'नए लेन-देन पर लागू करें';

  @override
  String get ruleApplyAll => 'मेरे जोड़े और इम्पोर्ट किए हुए';

  @override
  String get ruleApplyManual => 'सिर्फ़ मेरे जोड़े हुए';

  @override
  String get ruleApplyImports => 'सिर्फ़ इम्पोर्ट किए हुए';

  @override
  String get rulePriorityLabel => 'क्रम';

  @override
  String get rulePriorityHelp =>
      '0 से 10000। छोटी संख्या पहले चलती है; पहला मेल खाने वाला नियम लागू होता है।';

  @override
  String get rulePriorityInvalid => '0 से 10000 के बीच संख्या लिखें।';

  @override
  String get ruleEnabledLabel => 'नियम चालू है';

  @override
  String get ruleEnabledHelp => 'बंद नियम रखे रहते हैं, पर चलते नहीं।';

  @override
  String get rulePreviewSection => 'पुराने लेन-देन पर आज़माएँ';

  @override
  String get ruleOnlyUncategorized => 'सिर्फ़ बिना श्रेणी वाले लेन-देन';

  @override
  String get rulePreviewAction => 'मेल खाने वाले देखें';

  @override
  String get rulePreviewNone => 'कोई पुराना लेन-देन मेल नहीं खाता।';

  @override
  String rulePreviewCount(int count, int shown) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count लेन-देन मेल खाते हैं',
      one: '1 लेन-देन मेल खाता है',
    );
    return '$_temp0 ($shown दिखाए गए)।';
  }

  @override
  String ruleApplyAction(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'इन $count लेन-देन पर लागू करें',
      one: 'इस लेन-देन पर लागू करें',
    );
    return '$_temp0';
  }

  @override
  String ruleApplyTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count लेन-देन बदलें?',
      one: '1 लेन-देन बदलें?',
    );
    return '$_temp0';
  }

  @override
  String ruleApplyBody(String category) {
    return 'इनकी श्रेणी $category हो जाएगी। बाद में आप किसी को भी फिर से बदल सकते हैं।';
  }

  @override
  String get ruleApplyConfirm => 'बदलें';

  @override
  String ruleApplied(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count लेन-देन अपडेट हुए।',
      one: '1 लेन-देन अपडेट हुआ।',
      zero: 'किसी लेन-देन को बदलने की ज़रूरत नहीं थी।',
    );
    return '$_temp0';
  }

  @override
  String get ruleSaved => 'नियम सहेजा गया।';

  @override
  String get ruleDelete => 'नियम हटाएँ';

  @override
  String ruleDeleteTitle(String name) {
    return 'नियम “$name” हटाएँ?';
  }

  @override
  String get ruleDeleteBody =>
      'जिन लेन-देन को इसने पहले बदला है, उनकी श्रेणी वैसी ही रहेगी।';

  @override
  String get ruleDeleted => 'नियम हटाया गया।';

  @override
  String get tagsTitle => 'टैग';

  @override
  String get tagsIntro =>
      'टैग आपके अपने लेबल हैं, जैसे “यात्रा” या “काम”। एक लेन-देन पर कई टैग लग सकते हैं।';

  @override
  String get tagsShowArchived => 'संग्रहित टैग भी दिखाएँ';

  @override
  String get tagsEmptyTitle => 'अभी कोई टैग नहीं है';

  @override
  String get tagsEmptyBody => 'यहाँ या लेन-देन सहेजते समय टैग जोड़ें।';

  @override
  String get tagNew => 'नया टैग';

  @override
  String get tagEdit => 'नाम या रंग बदलें';

  @override
  String get tagNameLabel => 'टैग का नाम';

  @override
  String get tagNameRequired => 'नाम लिखें।';

  @override
  String get tagNameTaken => 'इस नाम का टैग पहले से है।';

  @override
  String tagCreated(String name) {
    return 'टैग “$name” जोड़ा गया।';
  }

  @override
  String get tagSaved => 'टैग सहेजा गया।';

  @override
  String get tagSeeTransactions => 'लेन-देन देखें';

  @override
  String get tagArchive => 'संग्रहित करें';

  @override
  String get tagArchiveHelp =>
      'चुनने की सूची से छिप जाता है; लेन-देन पर बना रहता है।';

  @override
  String get tagUnarchive => 'संग्रह से निकालें';

  @override
  String tagArchived(String name) {
    return '“$name” संग्रहित किया गया।';
  }

  @override
  String tagUnarchived(String name) {
    return '“$name” फिर से आपकी टैग सूची में है।';
  }

  @override
  String get tagDelete => 'हटाएँ';

  @override
  String tagDeleteTitle(String name) {
    return 'टैग “$name” हटाएँ?';
  }

  @override
  String tagDeleteBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'यह $count लेन-देन से हट जाएगा। लेन-देन बने रहेंगे।',
      one: 'यह 1 लेन-देन से हट जाएगा। लेन-देन बना रहेगा।',
      zero: 'यह किसी लेन-देन पर नहीं है।',
    );
    return '$_temp0';
  }

  @override
  String tagDeleted(String name) {
    return '“$name” हटाया गया।';
  }

  @override
  String get tagStatusArchived => 'संग्रहित';

  @override
  String get merchantsTitle => 'दुकानें';

  @override
  String get merchantsSearch => 'नाम या दूसरे नाम से खोजें';

  @override
  String get merchantsEmptyTitle => 'अभी कोई दुकान नहीं है';

  @override
  String get merchantsEmptyBody =>
      'दुकान वाले लेन-देन सहेजने पर दुकानें अपने-आप जुड़ती हैं।';

  @override
  String get merchantsNoMatch => 'कोई दुकान मेल नहीं खाती।';

  @override
  String get merchantDetailTitle => 'दुकान';

  @override
  String merchantLastUsed(String date) {
    return 'आख़िरी बार $date';
  }

  @override
  String merchantAlsoKnownAs(String names) {
    return 'दूसरे नाम: $names';
  }

  @override
  String get merchantStatusArchived => 'संग्रहित';

  @override
  String get merchantEdit => 'दुकान बदलें';

  @override
  String get merchantMoreActions => 'और विकल्प';

  @override
  String get merchantDetailsSection => 'जानकारी';

  @override
  String get merchantDefaultCategory => 'डिफ़ॉल्ट श्रेणी';

  @override
  String get merchantDefaultCategoryHelp =>
      'यहाँ लेन-देन जोड़ते समय यह श्रेणी सुझाई जाती है।';

  @override
  String get merchantNoDefaultCategory => 'कोई नहीं';

  @override
  String get merchantTransactionsLabel => 'लेन-देन';

  @override
  String get merchantLastUsedLabel => 'आख़िरी उपयोग';

  @override
  String get merchantWebsiteLabel => 'वेबसाइट';

  @override
  String get merchantWebsiteFailed => 'यह वेबसाइट नहीं खुल सकी।';

  @override
  String get merchantNotesLabel => 'नोट';

  @override
  String get merchantSpendingSection => 'पिछले 12 महीनों का खर्च';

  @override
  String get merchantNoSpending =>
      'पिछले 12 महीनों में यहाँ कोई खर्च नहीं हुआ।';

  @override
  String merchantSpendingSummary(
    String currency,
    int months,
    String month,
    String amount,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: '$months महीनों',
      one: '1 महीने',
    );
    return '$currency में, $_temp0 में खर्च हुआ; सबसे ज़्यादा $month में $amount रहा। रिफ़ंड घटा दिए गए हैं।';
  }

  @override
  String merchantSpendingSummaryNone(String currency) {
    return '$currency में, इन महीनों में रिफ़ंड ने खर्च को बराबर कर दिया।';
  }

  @override
  String get merchantAliasesSection => 'दूसरे नाम';

  @override
  String get merchantAliasesHelp =>
      'जिन नामों से यह दुकान दिखती है, जैसे बैंक स्टेटमेंट में।';

  @override
  String get merchantNoAliases => 'अभी कोई दूसरा नाम नहीं है।';

  @override
  String get merchantAddAlias => 'दूसरा नाम जोड़ें';

  @override
  String merchantAliasDialogBody(String name) {
    return 'इस नाम वाले लेन-देन $name से जोड़े जाएँगे।';
  }

  @override
  String get merchantAliasLabel => 'दूसरा नाम';

  @override
  String get merchantAliasRequired => 'नाम लिखें।';

  @override
  String merchantAliasAdded(String alias) {
    return '“$alias” दूसरे नाम के रूप में जोड़ा गया।';
  }

  @override
  String get merchantSeeTransactions => 'लेन-देन देखें';

  @override
  String get merchantMergeAction => 'किसी दूसरी दुकान को इसमें मिलाएँ';

  @override
  String get merchantMergeHelp => 'एक ही जगह की दोहरी दुकानों के लिए।';

  @override
  String merchantMergePickTitle(String name) {
    return '“$name” में मिलाएँ';
  }

  @override
  String merchantMergeTitle(String source, String target) {
    return '“$source” को “$target” में मिलाएँ?';
  }

  @override
  String merchantMergeBody(int count, String source, String target) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'इसके $count लेन-देन “$target” में चले जाएँगे।',
      one: 'इसका 1 लेन-देन “$target” में चला जाएगा।',
      zero: '“$source” का कोई लेन-देन नहीं है।',
    );
    return '$_temp0 इसके नाम “$target” के दूसरे नाम बन जाएँगे। इसे वापस नहीं किया जा सकता।';
  }

  @override
  String get merchantMergeConfirm => 'मिलाएँ';

  @override
  String merchantMerged(String source, String target) {
    return '“$source” को “$target” में मिला दिया गया।';
  }

  @override
  String get merchantMergedNote =>
      'यह दुकान किसी दूसरी दुकान में मिला दी गई है।';

  @override
  String get merchantArchive => 'संग्रहित करें';

  @override
  String get merchantArchiveHelp =>
      'सुझावों से छिप जाती है; पुराने लेन-देन में बनी रहती है।';

  @override
  String get merchantUnarchive => 'संग्रह से निकालें';

  @override
  String merchantArchived(String name) {
    return '“$name” संग्रहित की गई।';
  }

  @override
  String merchantUnarchived(String name) {
    return '“$name” फिर से सुझावों में है।';
  }

  @override
  String get merchantArchivedNote =>
      'संग्रहित: नए लेन-देन के लिए यह सुझाई नहीं जाती।';

  @override
  String get merchantNameLabel => 'नाम';

  @override
  String get merchantNameRequired => 'नाम लिखें।';

  @override
  String get merchantNameTaken =>
      'इस नाम की दूसरी दुकान पहले से है। इसके बजाय दोनों को मिलाएँ।';

  @override
  String get merchantSaved => 'दुकान सहेजी गई।';

  @override
  String get recurringOpenTooltip => 'दोहराने वाले भुगतान';

  @override
  String get profileOrganizeTitle => 'व्यवस्थित करें';

  @override
  String get profileCategoriesSubtitle => 'मुख्य श्रेणियाँ और उप-श्रेणियाँ';

  @override
  String get profileRulesSubtitle => 'श्रेणियाँ अपने-आप लगाएँ';

  @override
  String get profileTagsSubtitle => 'लेन-देन के लिए आपके अपने लेबल';

  @override
  String get profileMerchantsSubtitle => 'नाम, दूसरे नाम और खर्च';

  @override
  String get homePlanTitle => 'आगे की योजना';

  @override
  String get homePlanBudgets => 'बजट';

  @override
  String get homePlanGoals => 'लक्ष्य';

  @override
  String get homePlanBills => 'बिल';

  @override
  String get homePlanSubscriptions => 'सब्सक्रिप्शन';

  @override
  String get homePlanRecurring => 'दोहराने वाले';

  @override
  String get homePlanCalendar => 'कैलेंडर';

  @override
  String get errorStorageUnavailable =>
      'फ़ाइल स्टोरेज अभी उपलब्ध नहीं है। कुछ मिनट बाद फिर से कोशिश करें।';

  @override
  String get errorFeatureNotConfigured =>
      'यह सुविधा इस सर्वर पर अभी सेट नहीं है।';

  @override
  String get errorPayloadTooLarge =>
      'यह फ़ाइल बहुत बड़ी है। कोई छोटी फ़ाइल चुनें।';

  @override
  String get errorUnsupportedFile =>
      'यह फ़ाइल प्रकार स्वीकार नहीं है, या इसकी सामग्री इसके प्रकार से मेल नहीं खाती। कोई दूसरी फ़ाइल आज़माएँ।';

  @override
  String get errorRuleTransactionVoided => 'पहले यह लेन-देन वापस लाएँ।';

  @override
  String get errorRuleFileNotReady => 'पहले फ़ाइल का अपलोड पूरा करें।';

  @override
  String get errorRuleFileNotAttachable =>
      'यह फ़ाइल किसी लेन-देन से नहीं जोड़ी जा सकती।';

  @override
  String errorRuleStatusTransition(String from, String to) {
    return 'इसे $from से $to में नहीं बदला जा सकता। इसकी मौजूदा स्थिति देखने के लिए फिर से लोड करें।';
  }

  @override
  String errorRuleRecordLimit(String resource, String limit) {
    String _temp0 = intl.Intl.selectLogic(resource, {
      'bills': 'आप अधिकतम $limit खुले बिल रख सकते हैं।',
      'recurring_rules': 'आप अधिकतम $limit नियमित भुगतान रख सकते हैं।',
      'subscriptions': 'आप अधिकतम $limit सदस्यताएँ रख सकते हैं।',
      'goals': 'आप अधिकतम $limit लक्ष्य रख सकते हैं।',
      'other': 'आप इनमें से अधिकतम $limit रख सकते हैं।',
    });
    return '$_temp0 जिनकी अब ज़रूरत नहीं है, उन्हें समाप्त करें, संग्रहित करें या हटाएँ।';
  }

  @override
  String errorMerchantNameTaken(String name) {
    return '“$name” नाम का एक और व्यापारी पहले से है। इसके बजाय दोनों को मिला दें।';
  }

  @override
  String errorNameTaken(String name) {
    return '“$name” पहले से इस्तेमाल में है। कोई दूसरा नाम चुनें।';
  }

  @override
  String get errorCategoryInUse =>
      'यह श्रेणी मौजूदा रिकॉर्ड में इस्तेमाल हो रही है। इसे किसी दूसरी श्रेणी में मिलाएँ या इसके बजाय संग्रहित करें।';

  @override
  String get errorRuleCategoryUnavailable =>
      'इस नियम की श्रेणी संग्रहित है या अब नियम के अनुकूल नहीं है। श्रेणी वापस लाएँ या कोई दूसरी श्रेणी चुनें।';

  @override
  String get errorRuleCategoryMerged =>
      'यह श्रेणी मिलाई जा चुकी है और अब बदली नहीं जा सकती।';

  @override
  String get errorRuleCategoryAlreadyMerged =>
      'इनमें से एक श्रेणी पहले ही मिलाई जा चुकी है।';

  @override
  String get errorRuleCategoryDepth =>
      'श्रेणियों में उप-श्रेणियों का केवल एक स्तर हो सकता है।';

  @override
  String get errorRuleParentArchived =>
      'मुख्य श्रेणी संग्रहित है। पहले उसे वापस लाएँ।';

  @override
  String get errorRuleMergeTargetInactive => 'किसी सक्रिय श्रेणी में मिलाएँ।';

  @override
  String get errorRuleMergeTargetTopLevel =>
      'उप-श्रेणियों वाली श्रेणी केवल किसी मुख्य श्रेणी में मिलाई जा सकती है।';

  @override
  String get errorRuleGroupBudgetType =>
      'समूह बजट समूह के सभी खर्चों को ट्रैक करते हैं। कुल बजट इस्तेमाल करें, या इसे सदस्यों के बीच बाँटें।';

  @override
  String get errorRuleGroupBudgetFilter =>
      'समूह बजट समूह के सभी खर्च गिनते हैं, इसलिए खाता, श्रेणी और व्यापारी फ़िल्टर लागू नहीं होते।';

  @override
  String get errorRuleGroupBudgetAllocation =>
      'समूह बजट सदस्यों के बीच बाँटे जाते हैं, श्रेणियों, व्यापारियों या खातों में नहीं।';

  @override
  String get errorRuleGroupBudget =>
      'समूह बजट समूह के खर्चों को ट्रैक करते हैं। उन्हें देखने के लिए समूह खोलें।';

  @override
  String get errorRuleZeroBasedUnallocated =>
      'ज़ीरो-बेस्ड बजट में पूरी सीमा ठीक-ठीक बाँटनी होती है।';

  @override
  String get errorRuleScheduleEnded =>
      'यह शेड्यूल समाप्त हो चुका है। नई तारीखें तय करने के लिए इसे संपादित करें।';

  @override
  String get errorRuleRecurringInUse =>
      'इसका इतिहास है, इसलिए इसे हटाया नहीं जा सकता। इसके बजाय इसे रोकें।';

  @override
  String get errorRuleNoOpenOccurrence => 'अभी कुछ भी बकाया नहीं है।';

  @override
  String get errorRuleOccurrenceNotOpen =>
      'वह भुगतान पहले ही चुकाया या छोड़ा जा चुका है, या अब इस बिल का हिस्सा नहीं है।';

  @override
  String get errorRuleOccurrenceNotSkipped =>
      'केवल छोड़े गए भुगतान फिर से खोले जा सकते हैं।';

  @override
  String get errorRuleOccurrenceHandled =>
      'यह भुगतान पहले ही निपटाया जा चुका है।';

  @override
  String get errorRulePostponeLater =>
      'किसी खुले भुगतान को बाद की तारीख पर ले जाएँ।';

  @override
  String get errorRuleUseBillScreen => 'बिल उसकी अपनी स्क्रीन से बदलें।';

  @override
  String get errorRuleAutoPostNeeds =>
      'अपने-आप दर्ज करने के लिए तय राशि और एक खाता चाहिए।';

  @override
  String get errorRuleBillInactive => 'भुगतान दर्ज करने से पहले बिल वापस लाएँ।';

  @override
  String get errorRuleBillsNotAutoPosted =>
      'बिल असली भुगतान को जोड़कर या दर्ज करके पक्के किए जाते हैं।';

  @override
  String get errorRuleTransferTwoAccounts =>
      'नियमित ट्रांसफ़र के लिए दो अलग-अलग खाते चाहिए।';

  @override
  String get errorRuleTransferDestination =>
      'इस ट्रांसफ़र का कोई गंतव्य खाता नहीं है।';

  @override
  String get errorRuleCrossCurrencyAutoPost =>
      'अलग-अलग मुद्राओं के बीच ट्रांसफ़र में हर बार मिली राशि चाहिए, इसलिए उन्हें अपने-आप दर्ज नहीं किया जा सकता।';

  @override
  String get errorRuleSubscriptionInactive =>
      'नए भुगतान दर्ज करने से पहले सदस्यता फिर से चालू करें।';

  @override
  String get errorRuleSubscriptionNotCancelled =>
      'केवल रद्द की गई सदस्यता की रद्द करने की तारीख होती है।';

  @override
  String get errorRuleDetectionDecided =>
      'इस संभावित सदस्यता की समीक्षा पहले ही हो चुकी है।';

  @override
  String get errorRuleDetectionEvidenceMissing =>
      'इस मिलान के पीछे के लेन-देन अब मौजूद नहीं हैं। इसे खारिज करें।';

  @override
  String get errorPaymentAlreadyLinked =>
      'यह भुगतान इस सदस्यता के लिए पहले से दर्ज है।';

  @override
  String get errorPaymentLinkedElsewhere =>
      'यह भुगतान किसी दूसरी सदस्यता के लिए पहले से दर्ज है।';

  @override
  String get errorCancellationConfirmationRequired =>
      'पुष्टि करें कि आपने सेवा प्रदाता के पास सदस्यता रद्द कर दी है।';

  @override
  String get errorRuleGoalInactive =>
      'योगदान केवल सक्रिय लक्ष्यों में जोड़े जा सकते हैं।';

  @override
  String get errorRuleOwnerRoleFixed => 'मालिक की भूमिका नहीं बदल सकती।';

  @override
  String get errorRuleOwnerCannotLeave =>
      'मालिक लक्ष्य नहीं छोड़ सकता और न ही हटाया जा सकता है। इसके बजाय लक्ष्य संग्रहित करें।';

  @override
  String get errorRuleMemberVisibility =>
      'सदस्य खुद चुनते हैं कि उनके योगदान कौन देखे।';

  @override
  String get errorRuleContributionNotPlanned => 'यह योगदान पहले से दर्ज है।';

  @override
  String get errorRuleContributionVoided => 'यह योगदान रद्द किया जा चुका है।';

  @override
  String get errorTransactionAlreadyCounted =>
      'यह लेन-देन पहले से किसी लक्ष्य में गिना जा चुका है।';

  @override
  String errorRuleWithdrawalExceedsSaved(String saved, String currency) {
    return 'निकासी बचत ($saved $currency) से ज़्यादा नहीं हो सकती।';
  }

  @override
  String errorRuleStorageQuota(String quota) {
    return 'यह अपलोड आपकी $quota स्टोरेज सीमा से ज़्यादा हो जाएगा। पहले वे फ़ाइलें हटाएँ जिनकी अब ज़रूरत नहीं है।';
  }

  @override
  String get errorRuleReceiptIncomplete =>
      'पहले रसीद की तारीख और कुल राशि जोड़ें।';

  @override
  String get errorRuleReceiptNotReviewed =>
      'खरीदारी दर्ज करने से पहले रसीद का विवरण सहेजें।';

  @override
  String get errorRuleNoRows => 'आयात करने के लिए कोई पंक्ति नहीं है।';

  @override
  String get errorRuleRowInvalid =>
      'आयात करने से पहले इस पंक्ति की तारीख, राशि या दिशा ठीक करें।';

  @override
  String get errorRuleDirectionMismatch =>
      'स्टेटमेंट की पंक्तियाँ और लेन-देन दोनों आने वाले पैसे के हों, या दोनों जाने वाले पैसे के।';

  @override
  String get errorRuleInvalidMatchShape =>
      'एक स्टेटमेंट पंक्ति को कई लेन-देन से, या कई पंक्तियों को एक लेन-देन से मिलाएँ।';

  @override
  String get errorRuleInvalidPair =>
      'एक लंबित और एक पोस्ट किया गया लेन-देन चुनें, जो एक ही दिशा में हों।';

  @override
  String errorRuleSumsDiffer(String statement, String ledger, String currency) {
    return 'स्टेटमेंट की ओर ($statement $currency) और लेन-देन ($ledger $currency) का जोड़ बराबर नहीं है।';
  }

  @override
  String get errorRuleReportTooLarge =>
      'रिपोर्ट में बहुत ज़्यादा लेन-देन हैं। छोटी अवधि या कम फ़िल्टर चुनें।';

  @override
  String get errorRuleBalanceAlreadyMatches =>
      'बैलेंस पहले से मेल खाता है, इसलिए कुछ भी बदलने की ज़रूरत नहीं है।';

  @override
  String get statusWordActive => 'सक्रिय';

  @override
  String get statusWordPaused => 'रुका हुआ';

  @override
  String get statusWordArchived => 'संग्रहित';

  @override
  String get statusWordEnded => 'समाप्त';

  @override
  String get statusWordAchieved => 'हासिल';

  @override
  String get statusWordCancelled => 'रद्द';

  @override
  String get statusWordCancelling => 'रद्द हो रहा';

  @override
  String get statusWordTrial => 'ट्रायल पर';

  @override
  String get statusWordVoided => 'हटाया गया';

  @override
  String get statusWordPending => 'लंबित';

  @override
  String get statusWordPosted => 'पोस्ट किया गया';

  @override
  String get statusWordUnknown => 'मौजूदा स्थिति';

  @override
  String get fileEmpty => 'यह फ़ाइल खाली है। कोई दूसरी फ़ाइल चुनें।';

  @override
  String fileTooLarge(String size) {
    return 'यह फ़ाइल $size से बड़ी है। कोई छोटी फ़ाइल चुनें।';
  }

  @override
  String fileTypeNotAccepted(String types) {
    return 'यह फ़ाइल प्रकार यहाँ स्वीकार नहीं है। $types इस्तेमाल करें।';
  }

  @override
  String get fileCameraUnavailable =>
      'कैमरा उपलब्ध नहीं है। इसके बजाय कोई फ़ोटो या फ़ाइल चुनें।';

  @override
  String get fileSourceTitle => 'फ़ाइल जोड़ें';

  @override
  String get fileSourceCamera => 'फ़ोटो लें';

  @override
  String get fileSourcePhotos => 'फ़ोटो चुनें';

  @override
  String get fileSourceFiles => 'फ़ाइल चुनें';

  @override
  String fileAcceptedTypes(String types, String size) {
    return '$types, अधिकतम $size';
  }

  @override
  String get uploadStageChecking => 'फ़ाइल जाँची जा रही है…';

  @override
  String get uploadStageAuthorizing => 'अपलोड की तैयारी हो रही है…';

  @override
  String get uploadStageSending => 'अपलोड हो रहा है…';

  @override
  String uploadStageSendingPercent(int percent) {
    return 'अपलोड हो रहा है… $percent%';
  }

  @override
  String get uploadStageFinishing => 'पूरा हो रहा है…';

  @override
  String get uploadCancel => 'अपलोड रद्द करें';

  @override
  String get uploadCancelled => 'अपलोड रद्द किया गया।';

  @override
  String get fileShare => 'शेयर करें';

  @override
  String get fileSave => 'डिवाइस पर सहेजें';

  @override
  String get fileSaved => 'सहेजा गया।';

  @override
  String get fileOpen => 'खोलें';

  @override
  String get fileDownloading => 'डाउनलोड हो रहा है…';

  @override
  String filePreviewLabel(String name) {
    return '$name का पूर्वावलोकन';
  }

  @override
  String get homeToolsTitle => 'अपने पैसे की समीक्षा करें';

  @override
  String get entryReceipts => 'रसीदें';

  @override
  String get entryReceiptsSubtitle =>
      'रसीदों की फ़ोटो और PDF, जिन्हें आप जाँचते हैं';

  @override
  String get entryImports => 'स्टेटमेंट आयात';

  @override
  String get entryImportsShort => 'स्टेटमेंट आयात करें';

  @override
  String get entryImportsSubtitle =>
      'अपने बैंक की CSV, XLSX या OFX फ़ाइल से लेन-देन लाएँ';

  @override
  String get entryAnalytics => 'विश्लेषण';

  @override
  String get entryAnalyticsSubtitle =>
      'नकदी प्रवाह, खर्च और रुझान, एक बार में एक मुद्रा';

  @override
  String get entryReports => 'रिपोर्ट';

  @override
  String get entryReportsSubtitle =>
      'डाउनलोड या शेड्यूल करने के लिए सारांश और एक्सपोर्ट';

  @override
  String get entryExchangeRates => 'विनिमय दरें';

  @override
  String get entryExchangeRatesSubtitle =>
      'मुद्राओं के बीच की दरें, आपकी अपनी दरों सहित';

  @override
  String get profileDataTitle => 'रिकॉर्ड और जानकारी';

  @override
  String get entryReconcile => 'मिलान करें';

  @override
  String get entryReconcileSubtitle => 'इस खाते को स्टेटमेंट से मिलाएँ';

  @override
  String get entryImportStatement => 'स्टेटमेंट आयात करें';

  @override
  String get billNoChanges => 'कुछ नहीं बदला।';

  @override
  String get billScheduleUnknown =>
      'यह बिल ऐसे दोहराता है जिसे Montra का यह संस्करण नहीं दिखा सकता। इसकी नियत तारीख बदलने के लिए ऐप अपडेट करें; बाकी विवरण आप अब भी बदल सकते हैं।';

  @override
  String get billReasonSameProvider => 'वही प्रदाता';

  @override
  String get billReasonSameAmount => 'वही राशि';

  @override
  String get billReasonAmountClose => 'अपेक्षित राशि के करीब';

  @override
  String get billReasonOnDueDate => 'नियत तारीख पर चुकाया';

  @override
  String billReasonDaysBefore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'नियत तारीख से $count दिन पहले',
      one: 'नियत तारीख से 1 दिन पहले',
    );
    return '$_temp0';
  }

  @override
  String billReasonDaysAfter(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'नियत तारीख के $count दिन बाद',
      one: 'नियत तारीख के 1 दिन बाद',
    );
    return '$_temp0';
  }

  @override
  String get billReasonOther => 'मिलता-जुलता लगता है';

  @override
  String get recurringNoChanges => 'कुछ नहीं बदला।';

  @override
  String get recurringScheduleUnknown =>
      'यह ऐसे दोहराता है जिसे Montra का यह संस्करण नहीं दिखा सकता। इसका शेड्यूल बदलने के लिए ऐप अपडेट करें; बाकी विवरण आप अब भी बदल सकते हैं।';

  @override
  String occurrenceMovedTo(String date) {
    return '$date पर ले जाया गया';
  }

  @override
  String get calendarStatusTarget => 'लक्ष्य की तारीख';

  @override
  String get subscriptionNoChanges => 'कुछ नहीं बदला।';

  @override
  String get subscriptionCancelledOnHelp =>
      'ज़रूरत हो तो वह तारीख ठीक करें जब सदस्यता रद्द हुई थी।';

  @override
  String get subscriptionCancelledOnPickHelp =>
      'जब सेवा प्रदाता ने इसकी पुष्टि की। जब तक आप न बदलें, आज की तारीख।';

  @override
  String get subscriptionEventPaymentUnlinked => 'भुगतान अलग किया गया';

  @override
  String get subscriptionEventRenewed => 'नवीनीकृत';

  @override
  String get subscriptionNoteMatchedByDetection =>
      'जब आपने इस सदस्यता को अपने लेन-देन से जोड़ा, तब जोड़ा गया';

  @override
  String get subscriptionLinkedPaymentsTitle => 'जुड़े भुगतान';

  @override
  String get subscriptionUnlinkPayment => 'अलग करें';

  @override
  String subscriptionUnlinkPaymentLabel(String date) {
    return '$date का भुगतान अलग करें';
  }

  @override
  String get subscriptionUnlinkConfirmTitle => 'यह भुगतान अलग करें?';

  @override
  String subscriptionUnlinkConfirmBody(String name) {
    return 'लेन-देन जैसा है वैसा ही रहेगा। बस यह अब $name का भुगतान नहीं गिना जाएगा, और आप इसे बाद में फिर से जोड़ सकते हैं।';
  }

  @override
  String get subscriptionPaymentUnlinked => 'भुगतान अलग किया गया।';

  @override
  String get subscriptionCandidatesIntro =>
      'ऐसे खर्च जो इस सदस्यता के भुगतान जैसे लगते हैं। एक चुनें, या कोई दूसरा लेन-देन चुनें।';

  @override
  String get subscriptionCandidatesEmpty =>
      'कोई मिलता-जुलता खर्च नहीं मिला। कोई दूसरा लेन-देन चुनें।';

  @override
  String get subscriptionCandidatesError => 'सुझाए गए खर्च लोड नहीं हो सके।';

  @override
  String get subscriptionChooseOtherCharge => 'कोई दूसरा लेन-देन चुनें';

  @override
  String subscriptionCandidateExpected(String date) {
    return 'लगभग $date को अपेक्षित';
  }

  @override
  String get subscriptionReasonSameMerchant => 'वही व्यापारी';

  @override
  String get subscriptionReasonMatchesName => 'नाम से मेल खाता है';

  @override
  String get subscriptionReasonSameAmount => 'वही राशि';

  @override
  String get subscriptionReasonAmountClose => 'कीमत के करीब';

  @override
  String get subscriptionReasonOnRenewalDate => 'नवीनीकरण की तारीख पर';

  @override
  String subscriptionReasonDaysBefore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'नवीनीकरण की तारीख से $count दिन पहले',
      one: 'नवीनीकरण की तारीख से 1 दिन पहले',
    );
    return '$_temp0';
  }

  @override
  String subscriptionReasonDaysAfter(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'नवीनीकरण की तारीख के $count दिन बाद',
      one: 'नवीनीकरण की तारीख के 1 दिन बाद',
    );
    return '$_temp0';
  }

  @override
  String get subscriptionReasonOther => 'मिलता-जुलता लगता है';

  @override
  String subscriptionListCapped(int count) {
    return 'पहली $count सदस्यताएँ दिखाई जा रही हैं।';
  }

  @override
  String get subscriptionChecklistUpdated => 'चेकलिस्ट अपडेट की गई।';

  @override
  String detectionReasonIntervals(int fit, int total) {
    return 'खर्चों के बीच के $total अंतरालों में से $fit इस पैटर्न से मेल खाते हैं';
  }

  @override
  String detectionReasonAmounts(int within, int count, String percent) {
    return '$count में से $within राशियाँ सामान्य राशि के $percent% के भीतर हैं';
  }

  @override
  String budgetSharedByEditor(String name) {
    return '$name ने साझा किया · बदल सकते हैं';
  }

  @override
  String budgetSharedByViewer(String name) {
    return '$name ने साझा किया · केवल देख सकते हैं';
  }

  @override
  String get budgetThresholdsNone => 'कोई स्तर अलर्ट नहीं';

  @override
  String budgetThresholdsChooseHelp(int max) {
    return 'अधिकतम $max स्तर चुनें। कोई स्तर न चुनने पर सीमा के किसी हिस्से तक पहुँचने के अलर्ट नहीं मिलेंगे।';
  }

  @override
  String get budgetThresholdsClear => 'स्तर अलर्ट बंद करें';

  @override
  String budgetTransactionsShowing(int shown, int total) {
    return '$total में से $shown दिखाए जा रहे हैं';
  }

  @override
  String get budgetMemberCannotAdd =>
      'इस व्यक्ति को नहीं जोड़ा जा सकता। आप बजट दोस्तों और अपने समूहों के सदस्यों के साथ साझा कर सकते हैं।';

  @override
  String get budgetMemberShareInvalid => 'उनके हिस्से की राशि जाँचें।';

  @override
  String get budgetNothingChanged =>
      'कुछ नहीं बदला, इसलिए सहेजने को कुछ नहीं था।';

  @override
  String get budgetTypeGroupChoiceHelp =>
      'समूह बजट समूह के सभी खर्च गिनते हैं: एक कुल राशि के रूप में, या सदस्यों के बीच लिफ़ाफ़ों या ज़ीरो-बेस्ड बजट के रूप में बाँटकर।';

  @override
  String get budgetAllocationsGroupHelp =>
      'चाहें तो सीमा को समूह के मौजूदा सदस्यों के बीच बाँटें।';

  @override
  String get budgetAllocationsMerchantHelp =>
      'श्रेणी, दुकान या अपने दिए नाम के अनुसार वैकल्पिक सीमाएँ।';

  @override
  String get budgetAllocationsAccountHelp =>
      'श्रेणी, खाते या अपने दिए नाम के अनुसार वैकल्पिक सीमाएँ।';

  @override
  String budgetAllocationOver(String spent, String limit, String over) {
    return '$limit में से $spent खर्च · $over ज़्यादा';
  }

  @override
  String get budgetTransactionsOwnerOnlyError =>
      'केवल मालिक अलग-अलग लेन-देन देख सकते हैं। आपको मालिक के कुल आँकड़े दिखते हैं।';

  @override
  String get goalMemberRoleOwner => 'मालिक';

  @override
  String goalSharedBy(String name) {
    return '$name ने साझा किया';
  }

  @override
  String goalAssumptionExact(String currency) {
    return 'राशियाँ $currency में सटीक हैं; कोई ब्याज, रिटर्न या महँगाई नहीं मानी गई है।';
  }

  @override
  String goalAssumptionPace(String days, String months) {
    return 'हाल की गति पिछले $days दिनों के दर्ज और सत्यापित योगदानों का शुद्ध जोड़ है, जिसे $months से भाग दिया गया है।';
  }

  @override
  String get goalAssumptionPlanned =>
      'योजनाबद्ध योगदान इरादे हैं, अलग रखा गया पैसा नहीं, इसलिए उन्हें बचत में नहीं गिना जाता।';

  @override
  String get goalCurrencyFixed => 'लक्ष्य बनने के बाद मुद्रा नहीं बदल सकती।';

  @override
  String get goalNothingChanged =>
      'कुछ नहीं बदला, इसलिए सहेजने को कुछ नहीं था।';

  @override
  String get goalOwnerNote =>
      'यह लक्ष्य आपका है। आप इसे छोड़ नहीं सकते, लेकिन यह चुन सकते हैं कि दूसरों को आपके योगदान में क्या दिखे।';

  @override
  String get goalExportIntroShare =>
      'इस CSV में हर योगदान है, रद्द किए गए भी। इसे शेयर करें, डिवाइस पर सहेजें या कॉपी करें।';

  @override
  String get contributionRecord => 'दर्ज करें';

  @override
  String contributionRecordTooltip(String date) {
    return '$date का अपना योजनाबद्ध योगदान दर्ज करें';
  }

  @override
  String get contributionRecordTitle => 'यह योजनाबद्ध योगदान दर्ज करें';

  @override
  String get contributionRecordIntro =>
      'यह बचत में गिना जाएगा। अगर आपने अलग राशि अलग रखी है तो राशि बदलें, और सत्यापित करने के लिए वह लेन-देन जोड़ें जिससे पैसा गया।';

  @override
  String get contributionRecordAmountHelp =>
      'अगर आपने योजना वाली राशि ही अलग रखी है तो इसे वैसे ही छोड़ दें।';

  @override
  String get contributionRecordSave => 'योगदान दर्ज करें';

  @override
  String get contributionRecordedDone => 'योगदान दर्ज किया गया।';

  @override
  String mergeAffectedBudgetFilters(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count बजट मिलाने के बाद नई जगह से गिनेंगे',
      one: '1 बजट मिलाने के बाद नई जगह से गिनेगा',
    );
    return '$_temp0';
  }

  @override
  String mergeAffectedAliases(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count दूसरे नाम',
      one: '1 दूसरा नाम',
    );
    return '$_temp0';
  }

  @override
  String merchantMergePreviewBody(String target, String moves, String source) {
    return 'ये “$target” में चले जाएँगे:\n$moves\n\nइसके बाद “$source” मिलाई गई के रूप में दिखेगी और इसके नाम “$target” के दूसरे नाम बन जाएँगे। इसे वापस नहीं किया जा सकता।';
  }

  @override
  String merchantMergePreviewNothing(String source, String target) {
    return 'अभी “$source” का कहीं उपयोग नहीं है। इसे “$target” में मिलाई गई के रूप में दिखाया जाएगा। इसे वापस नहीं किया जा सकता।';
  }

  @override
  String get merchantAliasRemove => 'हटाएँ';

  @override
  String merchantAliasRemoveTooltip(String alias) {
    return 'दूसरा नाम “$alias” हटाएँ';
  }

  @override
  String merchantAliasRemoveTitle(String alias) {
    return '“$alias” हटाएँ?';
  }

  @override
  String merchantAliasRemoveBody(String name) {
    return 'इस नाम वाले नए लेन-देन $name से नहीं जोड़े जाएँगे। पहले से जुड़े लेन-देन वैसे ही रहेंगे।';
  }

  @override
  String merchantAliasRemoved(String alias) {
    return '“$alias” हटाया गया।';
  }

  @override
  String get merchantOpenMergedInto => 'जिस दुकान में मिलाई गई, उसे खोलें';

  @override
  String get merchantStatusMerged => 'मिलाई गई';

  @override
  String get merchantsFilterLabel => 'दुकानें दिखाएँ';

  @override
  String get merchantsFilterActive => 'सक्रिय';

  @override
  String get merchantsFilterArchived => 'संग्रहित';

  @override
  String get merchantsFilterMerged => 'मिलाई गईं';

  @override
  String get merchantsFilterAll => 'सभी';

  @override
  String get merchantsEmptyFiltered => 'यहाँ कोई दुकान नहीं है।';

  @override
  String get ruleCurrencyLabel => 'राशियों की मुद्रा';

  @override
  String ruleAmountCurrencyNote(String currency) {
    return 'राशि की सीमाएँ केवल $currency वाले लेन-देन से मेल खाती हैं।';
  }

  @override
  String ruleAmountsBetween(String min, String max) {
    return '$min से $max तक की राशियाँ';
  }

  @override
  String ruleAmountsAtLeast(String min) {
    return '$min या उससे ज़्यादा की राशियाँ';
  }

  @override
  String ruleAmountsAtMost(String max) {
    return '$max तक की राशियाँ';
  }

  @override
  String get rulePriorityOptionalHelp =>
      'वैकल्पिक: 0 से 10000। कम संख्या वाले नियम पहले चलते हैं और पहला मेल खाने वाला नियम लागू होता है। खाली छोड़ने पर 100।';

  @override
  String get attachmentAdd => 'फ़ाइल जोड़ें';

  @override
  String get attachmentAdded => 'फ़ाइल जोड़ दी गई।';

  @override
  String get attachmentsEmptyAdd =>
      'कोई फ़ाइल जुड़ी नहीं है। कोई फ़ोटो या PDF जोड़ें, जैसे बिल या वारंटी।';

  @override
  String get attachmentReceiptLink => 'रसीद';

  @override
  String get attachmentReceiptLinkHelp =>
      'यह लेन-देन एक रसीद से दर्ज किया गया था।';

  @override
  String get receiptsTitle => 'रसीदें';

  @override
  String get receiptAdd => 'रसीद जोड़ें';

  @override
  String get receiptAdded => 'रसीद जोड़ दी गई। अब उसका विवरण भरें।';

  @override
  String get receiptUploadTitle => 'अपलोड हो रहा है';

  @override
  String get receiptsManualNote =>
      'Montra रसीदें अपने-आप नहीं पढ़ता: आप विवरण भरते हैं, फिर रसीद को किसी खर्च से जोड़ते हैं या नया खर्च दर्ज करते हैं।';

  @override
  String get receiptsEmptyTitle => 'अभी कोई रसीद नहीं';

  @override
  String get receiptsEmptyFiltered => 'यहाँ कोई रसीद नहीं';

  @override
  String get receiptsEmptyBody =>
      'किसी रसीद की फ़ोटो लें या कोई फ़ोटो या PDF चुनें। विवरण आप खुद भरते हैं।';

  @override
  String get receiptFilterOpen => 'इनबॉक्स में';

  @override
  String get receiptFilterToReview => 'भरना बाकी';

  @override
  String get receiptFilterReviewed => 'तैयार';

  @override
  String get receiptFilterLinked => 'जुड़ी हुई';

  @override
  String get receiptFilterDiscarded => 'हटाई गईं';

  @override
  String get receiptUntitled => 'रसीद';

  @override
  String get receiptNoDetails => 'विवरण अभी नहीं भरा गया';

  @override
  String receiptPages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count पेज',
      one: '1 पेज',
    );
    return '$_temp0';
  }

  @override
  String get receiptPossibleDuplicate => 'शायद दोबारा जोड़ी गई';

  @override
  String get receiptStatusUploaded => 'अपलोड हुई';

  @override
  String get receiptStatusProcessing => 'प्रोसेस हो रही है';

  @override
  String get receiptStatusNeedsReview => 'विवरण चाहिए';

  @override
  String get receiptStatusReviewed => 'दर्ज करने के लिए तैयार';

  @override
  String get receiptStatusMatched => 'लेन-देन से जुड़ी';

  @override
  String get receiptStatusFailed => 'पढ़ी नहीं जा सकी';

  @override
  String get receiptStatusDiscarded => 'हटाई गई';

  @override
  String get receiptStatusOther => 'अन्य';

  @override
  String get receiptHelpNeedsReview =>
      'रसीद से विवरण भरें, ताकि आप उसे किसी खर्च से जोड़ सकें या दर्ज कर सकें।';

  @override
  String get receiptHelpReviewed =>
      'इसे पहले से दर्ज किसी खर्च से जोड़ें, या नए खर्च के रूप में दर्ज करें।';

  @override
  String get receiptHelpMatched =>
      'यह रसीद एक लेन-देन से जुड़ी है। इसके पेज उस लेन-देन के साथ जुड़े हैं।';

  @override
  String get receiptHelpDiscarded =>
      'यह रसीद आपके इनबॉक्स से हटा दी गई है। इसकी फ़ाइलें तब तक रहती हैं जब तक आप उन्हें न हटाएँ।';

  @override
  String get receiptHelpProcessing =>
      'यह रसीद प्रोसेस हो रही है। ताज़ा करने के लिए नीचे खींचें।';

  @override
  String get receiptTitle => 'रसीद';

  @override
  String get receiptEnterDetails => 'विवरण भरें';

  @override
  String get receiptEditDetails => 'विवरण बदलें';

  @override
  String get receiptMatchAction => 'खर्च खोजें';

  @override
  String get receiptRecordAction => 'नए खर्च के रूप में दर्ज करें';

  @override
  String get receiptOpenTransaction => 'लेन-देन खोलें';

  @override
  String get receiptUnlink => 'जोड़ हटाएँ';

  @override
  String get receiptUnlinkConfirmTitle => 'इस रसीद का जोड़ हटाएँ?';

  @override
  String get receiptUnlinkConfirmBody =>
      'लेन-देन जैसा है वैसा ही रहेगा; उससे केवल रसीद के पेज हटेंगे। आप रसीद को बाद में फिर से जोड़ सकते हैं।';

  @override
  String get receiptUnlinked => 'रसीद का जोड़ हटा दिया गया।';

  @override
  String get receiptDiscard => 'हटाएँ';

  @override
  String get receiptDiscardConfirmTitle => 'यह रसीद हटाएँ?';

  @override
  String get receiptDiscarded => 'रसीद हटा दी गई।';

  @override
  String get receiptDuplicateNotice =>
      'यह आपकी पहले से जोड़ी गई किसी रसीद जैसी लगती है।';

  @override
  String get receiptOpenOther => 'दूसरी रसीद खोलें';

  @override
  String get receiptWarningArithmetic =>
      'उप-योग, टैक्स, टिप और छूट का जोड़ कुल राशि के बराबर नहीं है। संख्याएँ जाँचें।';

  @override
  String get receiptWarningLineItems =>
      'आइटम का जोड़ उप-योग के बराबर नहीं है। संख्याएँ जाँचें।';

  @override
  String get receiptPagesTitle => 'पेज';

  @override
  String get receiptNoPages => 'इस रसीद में कोई पेज नहीं है।';

  @override
  String receiptPageLabel(int index, int count) {
    return 'रसीद का पेज $index / $count';
  }

  @override
  String receiptOpenPage(int index) {
    return 'पेज $index खोलें';
  }

  @override
  String get receiptPdfPage => 'PDF – शेयर या सहेजकर खुलता है';

  @override
  String get receiptFilePage => 'फ़ाइल – शेयर या सहेजकर खुलती है';

  @override
  String get receiptPreviewUnavailable => 'यह तस्वीर नहीं दिखाई जा सकती।';

  @override
  String get receiptPdfHelp =>
      'PDF फ़ाइलें किसी दूसरे ऐप में खुलती हैं। शेयर करें या सहेजें इस्तेमाल करें।';

  @override
  String get receiptFileHelp =>
      'यह फ़ाइल Montra में नहीं दिखाई जा सकती। शेयर करें या सहेजें इस्तेमाल करें।';

  @override
  String get receiptDetailsTitle => 'विवरण';

  @override
  String get receiptMerchant => 'दुकान या व्यापारी';

  @override
  String get receiptMerchantHelp => 'जैसा रसीद पर छपा है।';

  @override
  String get receiptDate => 'रसीद की तारीख';

  @override
  String get receiptDateChoose => 'तारीख चुनें';

  @override
  String get receiptDateRequired => 'रसीद की तारीख चुनें।';

  @override
  String get receiptTime => 'समय (वैकल्पिक)';

  @override
  String get receiptTimeNone => 'कोई समय नहीं';

  @override
  String get receiptCurrency => 'मुद्रा';

  @override
  String get receiptCurrencyHelp => 'रसीद पर छपी मुद्रा।';

  @override
  String get receiptTotal => 'कुल राशि';

  @override
  String get receiptSubtotal => 'उप-योग';

  @override
  String get receiptTax => 'टैक्स';

  @override
  String get receiptTip => 'टिप';

  @override
  String get receiptDiscount => 'छूट';

  @override
  String get receiptNumber => 'रसीद संख्या';

  @override
  String get receiptPaymentHint => 'आपने कैसे भुगतान किया';

  @override
  String get receiptLinkedTransaction => 'जुड़ा हुआ लेन-देन';

  @override
  String get receiptLineItemsTitle => 'आइटम';

  @override
  String receiptLineItemUnnamed(int position) {
    return 'आइटम $position';
  }

  @override
  String receiptQuantityValue(String quantity) {
    return 'मात्रा $quantity';
  }

  @override
  String receiptUnitPriceValue(String price) {
    return '$price प्रति इकाई';
  }

  @override
  String receiptTaxValue(String tax) {
    return 'टैक्स $tax';
  }

  @override
  String get receiptNotes => 'नोट्स';

  @override
  String get receiptHistoryTitle => 'संस्करण';

  @override
  String receiptVersionTitle(int version, String method) {
    return 'संस्करण $version · $method';
  }

  @override
  String get receiptMethodManual => 'आपने भरा';

  @override
  String get receiptMethodAutomatic => 'फ़ाइल से पढ़ा गया';

  @override
  String get receiptReviewTitle => 'रसीद का विवरण';

  @override
  String get receiptReviewIntro =>
      'विवरण वैसे ही भरें जैसे रसीद पर दिखते हैं। केवल तारीख और कुल राशि ज़रूरी हैं।';

  @override
  String get receiptReviewUnavailable => 'यह विवरण अभी बदला नहीं जा सकता';

  @override
  String get receiptBreakdownTitle => 'ब्योरा (वैकल्पिक)';

  @override
  String get receiptBreakdownHelp =>
      'अगर रसीद पर ये दिखते हैं तो जोड़ें। अगर इनका जोड़ नहीं मिलता, तो Montra आपको बताएगा।';

  @override
  String get receiptAddLineItem => 'आइटम जोड़ें';

  @override
  String receiptLineItemTitle(int index) {
    return 'आइटम $index';
  }

  @override
  String receiptRemoveLineItem(int index) {
    return 'आइटम $index हटाएँ';
  }

  @override
  String get receiptLineDescription => 'विवरण';

  @override
  String get receiptQuantity => 'मात्रा';

  @override
  String get receiptQuantityInvalid =>
      'कोई संख्या लिखें, अधिकतम 3 दशमलव अंकों तक।';

  @override
  String get receiptUnitPrice => 'प्रति इकाई कीमत';

  @override
  String get receiptLineAmount => 'आइटम की राशि';

  @override
  String get receiptLineTax => 'आइटम का टैक्स';

  @override
  String get receiptReviewSave => 'विवरण सहेजें';

  @override
  String get receiptReviewSaved => 'रसीद का विवरण सहेजा गया।';

  @override
  String get receiptMatchTitle => 'खर्च खोजें';

  @override
  String get receiptMatchIntro =>
      'ये दर्ज खर्च राशि और तारीख में मिलते-जुलते हैं। जोड़ने से कोई नया पैसा दर्ज नहीं होता।';

  @override
  String get receiptMatchNone =>
      'कोई दर्ज खर्च इस रसीद जैसा नहीं दिखता। खुद कोई चुनें, या नया खर्च दर्ज करें।';

  @override
  String get receiptChooseTransaction => 'कोई दूसरा खर्च चुनें';

  @override
  String get receiptLinkThis => 'जोड़ें';

  @override
  String get receiptLinked => 'रसीद खर्च से जोड़ दी गई।';

  @override
  String get receiptUnnamedTransaction => 'खर्च';

  @override
  String get receiptCandidateAmount => 'राशि';

  @override
  String get receiptReasonSameAmount => 'कुल राशि के बराबर';

  @override
  String get receiptReasonCloseAmount =>
      'राशि कुल से 20% के अंदर (टिप या शुल्क)';

  @override
  String get receiptReasonSameDate => 'वही तारीख';

  @override
  String get receiptReasonNearDate => '3 दिनों के अंदर';

  @override
  String get receiptReasonSameMerchant => 'वही व्यापारी';

  @override
  String get receiptRecordTitle => 'खर्च दर्ज करें';

  @override
  String get receiptRecordIntro =>
      'राशि, तारीख और व्यापारी रसीद के विवरण से आते हैं। वह खाता चुनें जिससे आपने भुगतान किया।';

  @override
  String get receiptRecordUnavailable => 'यह रसीद अभी दर्ज नहीं की जा सकती';

  @override
  String get receiptRecordAccount => 'किस खाते से भुगतान';

  @override
  String receiptRecordAccountHelp(String currency) {
    return '$currency वाले खाते, जो रसीद की मुद्रा है।';
  }

  @override
  String get receiptChooseAccount => 'खाता चुनें';

  @override
  String get receiptAccountRequired => 'वह खाता चुनें जिससे आपने भुगतान किया।';

  @override
  String get receiptRecordCategory => 'श्रेणी (वैकल्पिक)';

  @override
  String get receiptRecordDescription => 'विवरण (वैकल्पिक)';

  @override
  String get receiptRecordDescriptionHelp =>
      'व्यापारी का नाम इस्तेमाल करने के लिए खाली छोड़ें।';

  @override
  String get receiptRecordSave => 'खर्च दर्ज करें';

  @override
  String get receiptRecorded => 'रसीद से खर्च दर्ज किया गया।';

  @override
  String get importsTitle => 'स्टेटमेंट आयात';

  @override
  String get importNew => 'स्टेटमेंट आयात करें';

  @override
  String get importsEmptyTitle => 'अभी कोई आयात नहीं';

  @override
  String get importsEmptyBody =>
      'अपने बैंक का CSV, XLSX या OFX स्टेटमेंट आयात करें। कुछ भी जोड़ने से पहले आप हर पंक्ति जाँचते हैं।';

  @override
  String importsForAccount(String account) {
    return '$account में आयात';
  }

  @override
  String get importsShowAll => 'सभी खाते दिखाएँ';

  @override
  String get importUnknownAccount => 'खाता उपलब्ध नहीं';

  @override
  String importStartedOn(String time) {
    return '$time को शुरू हुआ';
  }

  @override
  String importCountsSummary(int imported, int skipped, int failed) {
    return '$imported आयात हुईं · $skipped छोड़ी गईं · $failed विफल';
  }

  @override
  String get importWizardTitle => 'स्टेटमेंट आयात करें';

  @override
  String get importWizardIntro =>
      'खाता और अपने बैंक की स्टेटमेंट फ़ाइल चुनें। कुछ भी जोड़ने से पहले आप हर पंक्ति देखेंगे।';

  @override
  String get importFormatsNote =>
      'CSV, XLSX और OFX फ़ाइलें काम करती हैं। PDF स्टेटमेंट समर्थित नहीं हैं: उन्हें पढ़ने के लिए AI चाहिए, जिसका Montra इस्तेमाल नहीं करता। ज़्यादातर बैंक CSV या XLSX डाउनलोड करने देते हैं।';

  @override
  String get importStepAccount => '1. खाता';

  @override
  String get importStepFile => '2. स्टेटमेंट फ़ाइल';

  @override
  String get importAccountLabel => 'खाता';

  @override
  String get importChooseAccount => 'खाता चुनें';

  @override
  String get importAccountHelp =>
      'पंक्तियाँ खाते की मुद्रा में जोड़ी जाती हैं।';

  @override
  String get importAccountRequired => 'वह खाता चुनें जिसका यह स्टेटमेंट है।';

  @override
  String get importFileLabel => 'स्टेटमेंट फ़ाइल';

  @override
  String get importChooseFile => 'फ़ाइल चुनें';

  @override
  String get importFileRequired => 'स्टेटमेंट फ़ाइल चुनें।';

  @override
  String get importStart => 'अपलोड करें और पढ़ें';

  @override
  String get importStatusReading => 'फ़ाइल पढ़ी जा रही है';

  @override
  String get importStatusNeedsMapping => 'कॉलम चुनने हैं';

  @override
  String get importStatusPreviewReady => 'जाँचने के लिए तैयार';

  @override
  String get importStatusImporting => 'आयात हो रहा है';

  @override
  String get importStatusCompleted => 'आयात हो गया';

  @override
  String get importStatusCompletedWithErrors => 'कुछ समस्याओं के साथ आयात हुआ';

  @override
  String get importStatusFailed => 'आयात नहीं हो सका';

  @override
  String get importStatusCancelled => 'रद्द';

  @override
  String get importStatusOther => 'अन्य';

  @override
  String get importHelpReading =>
      'Montra आपकी फ़ाइल पढ़ रहा है। इसमें आमतौर पर कुछ सेकंड लगते हैं।';

  @override
  String get importHelpNeedsMapping =>
      'Montra यह नहीं समझ पाया कि किस कॉलम में क्या है। आगे बढ़ने के लिए कॉलम चुनें।';

  @override
  String get importHelpPreviewReady =>
      'पंक्तियाँ जाँचें, फिर आयात करें। संभावित दोहराव और आपकी छोड़ी गई पंक्तियाँ शामिल नहीं होतीं।';

  @override
  String get importHelpImporting =>
      'आपकी पंक्तियाँ जोड़ी जा रही हैं। आप यह स्क्रीन छोड़ सकते हैं।';

  @override
  String get importHelpCompleted => 'पंक्तियाँ खाते में जोड़ दी गईं।';

  @override
  String get importHelpCompletedWithErrors =>
      'कुछ पंक्तियाँ जोड़ी नहीं जा सकीं। उन्हें ठीक करके फिर से कोशिश करें, या छोड़ दें।';

  @override
  String get importHelpFailed => 'खाते में कुछ भी नहीं जोड़ा गया।';

  @override
  String get importHelpCancelled =>
      'यह आयात रोक दिया गया। रुकने से पहले आयात हुई पंक्तियाँ तब तक रहेंगी जब तक आप उन्हें वापस न लें।';

  @override
  String get importStillWorking =>
      'काम अभी जारी है। फिर से देखने के लिए नीचे खींचें।';

  @override
  String get importCancelRequested => 'मौजूदा पंक्ति के बाद रुक रहा है।';

  @override
  String get importErrorEmpty => 'फ़ाइल में कोई पंक्ति नहीं है।';

  @override
  String get importErrorUnsupported =>
      'यह फ़ाइल प्रकार आयात नहीं किया जा सकता। अपने बैंक से CSV, XLSX या OFX इस्तेमाल करें।';

  @override
  String get importErrorMalformed =>
      'फ़ाइल पढ़ी नहीं जा सकी। इसे अपने बैंक से फिर से डाउनलोड करें।';

  @override
  String get importErrorTooManyRows =>
      'फ़ाइल में बहुत ज़्यादा पंक्तियाँ हैं। छोटी अवधि का स्टेटमेंट डाउनलोड करें।';

  @override
  String get importErrorTooManyColumns => 'फ़ाइल में बहुत ज़्यादा कॉलम हैं।';

  @override
  String get importErrorCurrency =>
      'स्टेटमेंट की मुद्रा खाते से मेल नहीं खाती। इसे उसी मुद्रा वाले खाते में आयात करें।';

  @override
  String get importErrorFileUnavailable =>
      'अपलोड की गई फ़ाइल अब उपलब्ध नहीं है। इसे फिर से अपलोड करें।';

  @override
  String get importErrorGeneric => 'आयात पूरा नहीं हो सका।';

  @override
  String get importRolledBack =>
      'यह आयात वापस ले लिया गया। आयात के बाद बदले गए लेन-देन रखे गए।';

  @override
  String importRolledBackCounts(int removed, int kept) {
    return 'वापस लिया गया: $removed लेन-देन हटाए गए, $kept रखे गए क्योंकि आयात के बाद उन्हें बदला या जोड़ा गया था।';
  }

  @override
  String get importDetailTitle => 'स्टेटमेंट आयात';

  @override
  String get importChooseColumns => 'कॉलम चुनें';

  @override
  String get importChangeColumns => 'कॉलम बदलें';

  @override
  String get importReviewRows => 'पंक्तियाँ जाँचें';

  @override
  String get importSeeRows => 'पंक्तियाँ देखें';

  @override
  String get importReviewFailed => 'विफल पंक्तियाँ ठीक करें';

  @override
  String get importRetryFailed => 'विफल पंक्तियाँ फिर से आज़माएँ';

  @override
  String get importRetrying => 'विफल पंक्तियाँ फिर से आज़माई जा रही हैं।';

  @override
  String get importConfirmAction => 'पंक्तियाँ आयात करें';

  @override
  String get importConfirmTitle => 'ये पंक्तियाँ आयात करें?';

  @override
  String importConfirmBody(String account) {
    return 'आयात के लिए चुनी गई पंक्तियाँ $account में जोड़ी जाएँगी। संभावित दोहराव और छोड़ी गई पंक्तियाँ शामिल नहीं होंगी। आप बाद में आयात वापस ले सकते हैं।';
  }

  @override
  String get importConfirmed => 'आयात शुरू हो गया।';

  @override
  String get importCancelAction => 'आयात रद्द करें';

  @override
  String get importCancelTitle => 'यह आयात रद्द करें?';

  @override
  String get importCancelBody =>
      'अभी तक कुछ भी नहीं जोड़ा गया है, और कुछ जोड़ा भी नहीं जाएगा।';

  @override
  String get importCancelProcessingBody =>
      'Montra मौजूदा पंक्ति के बाद रुक जाएगा। पहले से जोड़ी गई पंक्तियाँ तब तक रहेंगी जब तक आप उन्हें वापस न लें।';

  @override
  String get importCancelled => 'आयात रद्द किया गया।';

  @override
  String get importRollbackAction => 'वापस लें';

  @override
  String get importRollbackTitle => 'यह आयात वापस लें?';

  @override
  String importRollbackBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'आयात हुए $count लेन-देन हटा दिए जाएँगे, सिवाय उनके जिन्हें बाद में बदला या जोड़ा गया है।',
      one: 'आयात हुआ लेन-देन हटा दिया जाएगा, अगर उसके बाद उसे बदला या जोड़ा नहीं गया है।',
    );
    return '$_temp0';
  }

  @override
  String get importRollingBack => 'आयात वापस लिया जा रहा है।';

  @override
  String get importTryAnotherFile => 'कोई दूसरी फ़ाइल आज़माएँ';

  @override
  String get importCheckStatement => 'स्टेटमेंट से मिलान करें';

  @override
  String get importPreviousFile =>
      'आपने यह फ़ाइल पहले भी इस खाते में आयात की थी। पहले से आयात हुई पंक्तियाँ चिह्नित करके छोड़ दी जाती हैं।';

  @override
  String get importOpenPrevious => 'पहले वाला आयात खोलें';

  @override
  String get importSummaryTitle => 'सारांश';

  @override
  String get importFormatLabel => 'फ़ाइल प्रकार';

  @override
  String get importStartedLabel => 'शुरू हुआ';

  @override
  String get importPeriodLabel => 'स्टेटमेंट अवधि';

  @override
  String get importRowsInFile => 'फ़ाइल में पंक्तियाँ';

  @override
  String get importRowsValid => 'पढ़ने योग्य पंक्तियाँ';

  @override
  String get importRowsNeedFixing => 'ठीक करने वाली पंक्तियाँ';

  @override
  String get importRowsPossibleDuplicates => 'संभावित दोहराव';

  @override
  String get importRowsImportedLabel => 'आयात हुईं';

  @override
  String get importRowsSkippedLabel => 'छोड़ी गईं';

  @override
  String get importRowsFailedLabel => 'विफल';

  @override
  String get importTotalsTitle => 'फ़ाइल से कुल योग';

  @override
  String get importBalanceOk => 'चालू बैलेंस का हिसाब मिलता है';

  @override
  String get importBalanceMismatch => 'चालू बैलेंस का हिसाब नहीं मिलता';

  @override
  String get importBalanceNotAvailable =>
      'फ़ाइल में जाँचने के लिए कोई बैलेंस नहीं';

  @override
  String importMismatchedRows(String rows) {
    return 'पंक्तियाँ $rows जाँचें।';
  }

  @override
  String get importTotalIn => 'आया पैसा';

  @override
  String get importTotalOut => 'गया पैसा';

  @override
  String get importTotalNet => 'शुद्ध';

  @override
  String get importOpeningBalance => 'शुरुआती बैलेंस';

  @override
  String get importClosingBalance => 'अंतिम बैलेंस';

  @override
  String get importMappingTitle => 'कॉलम चुनें';

  @override
  String get importMappingIntro =>
      'Montra को बताएँ कि हर जानकारी किस कॉलम में है। जाँचने के लिए आपकी फ़ाइल की पहली पंक्तियाँ दिखाई गई हैं।';

  @override
  String get importMappingUnavailable => 'कॉलम अभी नहीं बदले जा सकते';

  @override
  String get importSampleTitle => 'फ़ाइल की पहली पंक्तियाँ';

  @override
  String importSampleRow(int number, String cells) {
    return 'पंक्ति $number: $cells';
  }

  @override
  String get importHeaderSection => 'शीर्षक पंक्ति';

  @override
  String get importHeaderRowLabel => 'कॉलम के नामों वाली पंक्ति';

  @override
  String get importHeaderRowHelp => 'इसके ऊपर की पंक्तियाँ अनदेखी की जाती हैं।';

  @override
  String get importNoHeaderRow => 'कोई शीर्षक पंक्ति नहीं';

  @override
  String get importColumnNone => 'कोई नहीं';

  @override
  String importColumnNumber(int number) {
    return 'कॉलम $number';
  }

  @override
  String importColumnExample(String name, String example) {
    return '$name (जैसे $example)';
  }

  @override
  String get importDateSection => 'तारीख';

  @override
  String get importDateColumn => 'तारीख का कॉलम';

  @override
  String get importDateFormat => 'तारीख का प्रारूप';

  @override
  String importDateFormatExample(String example) {
    return 'फ़ाइल में तारीखें ऐसी दिखती हैं: $example।';
  }

  @override
  String get importAmountSection => 'राशि';

  @override
  String get importAmountSingle => 'राशि का एक कॉलम';

  @override
  String get importAmountSplit => 'पैसा जाने और आने के कॉलम';

  @override
  String get importAmountColumn => 'राशि का कॉलम';

  @override
  String get importSignNegativeOut => 'ऋणात्मक राशियाँ जाने वाला पैसा हैं';

  @override
  String get importSignPositiveOut => 'धनात्मक राशियाँ जाने वाला पैसा हैं';

  @override
  String get importDebitColumn => 'जाने वाले पैसे का कॉलम (निकासी)';

  @override
  String get importCreditColumn => 'आने वाले पैसे का कॉलम (जमा)';

  @override
  String get importIndicatorColumn => 'Dr/Cr कॉलम (वैकल्पिक)';

  @override
  String get importIndicatorHelp => 'Dr या Cr बताने वाला कॉलम दिशा तय करता है।';

  @override
  String get importDecimalLabel => 'दशमलव चिह्न';

  @override
  String get importDecimalPoint => 'बिंदु (1,234.50)';

  @override
  String get importDecimalComma => 'अल्पविराम (1.234,50)';

  @override
  String get importDescriptionSection => 'विवरण';

  @override
  String get importDescriptionHelp =>
      'एक या ज़्यादा कॉलम चुनें; उन्हें जोड़ दिया जाता है।';

  @override
  String get importOptionalSection => 'और कॉलम (वैकल्पिक)';

  @override
  String get importReferenceColumn => 'संदर्भ कॉलम';

  @override
  String get importBalanceColumn => 'बैलेंस कॉलम';

  @override
  String get importBalanceColumnHelp =>
      'इससे Montra जाँच पाता है कि पंक्तियों का हिसाब मिलता है।';

  @override
  String get importCurrencyColumn => 'मुद्रा कॉलम';

  @override
  String get importExternalIdColumn => 'बैंक लेन-देन ID कॉलम';

  @override
  String get importExternalIdHelp =>
      'इससे Montra पहले से आयात हुई पंक्तियाँ पहचान पाता है।';

  @override
  String get importMappingNeedsDate => 'तारीख का कॉलम चुनें।';

  @override
  String get importMappingNeedsDateFormat => 'तारीख का प्रारूप चुनें।';

  @override
  String get importMappingNeedsAmount => 'राशि का कॉलम चुनें।';

  @override
  String get importMappingNeedsDebitCredit =>
      'पैसा जाने और आने, दोनों के कॉलम चुनें।';

  @override
  String get importMappingSave => 'सहेजें और फिर से पढ़ें';

  @override
  String get importMappingSaved =>
      'कॉलम सहेजे गए। Montra पंक्तियाँ फिर से पढ़ रहा है।';

  @override
  String get importRowsTitle => 'स्टेटमेंट की पंक्तियाँ';

  @override
  String get importRowsHelp =>
      'किसी पंक्ति को छोड़ने, आयात करने, उसकी श्रेणी तय करने या उसे ठीक करने के लिए उस पर टैप करें।';

  @override
  String get importRowsEmpty => 'यहाँ कोई पंक्ति नहीं है।';

  @override
  String get importRowsAll => 'सभी';

  @override
  String get importRowsReady => 'तैयार';

  @override
  String get importRowsDuplicate => 'संभावित दोहराव';

  @override
  String get importRowsInvalid => 'ठीक करनी हैं';

  @override
  String get importRowsSkipped => 'छोड़ी गईं';

  @override
  String get importRowsImported => 'आयात हुईं';

  @override
  String get importRowsFailed => 'विफल';

  @override
  String get importRowStatusParsed => 'पढ़ी गई';

  @override
  String get importRowStatusReady => 'तैयार';

  @override
  String get importRowStatusDuplicate => 'संभावित दोहराव';

  @override
  String get importRowStatusInvalid => 'ठीक करनी है';

  @override
  String get importRowStatusSkipped => 'छोड़ी गई';

  @override
  String get importRowStatusImported => 'आयात हुई';

  @override
  String get importRowStatusFailed => 'विफल';

  @override
  String get importRowWillImport => 'आयात होगी';

  @override
  String get importRowWillSkip => 'शामिल नहीं होगी';

  @override
  String importRowNumber(int number) {
    return 'पंक्ति $number';
  }

  @override
  String get importReasonHeader => 'शीर्षक पंक्ति';

  @override
  String get importReasonPreamble => 'शीर्षक पंक्ति से पहले का टेक्स्ट';

  @override
  String get importReasonMissingDate => 'तारीख खाली है।';

  @override
  String get importReasonBadDate => 'तारीख चुने गए प्रारूप से मेल नहीं खाती।';

  @override
  String get importReasonCurrency => 'यह पंक्ति किसी दूसरी मुद्रा में है।';

  @override
  String get importReasonBadAmount => 'राशि इस मुद्रा में कोई संख्या नहीं है।';

  @override
  String get importReasonZeroAmount => 'राशि खाली या शून्य है।';

  @override
  String get importReasonBothColumns =>
      'जाने और आने वाले पैसे, दोनों में राशि है।';

  @override
  String get importReasonPossibleDuplicate =>
      'खाते में पहले से मौजूद किसी लेन-देन जैसी लगती है।';

  @override
  String get importReasonAlreadyImported =>
      'इस खाते में पहले ही आयात हो चुकी है।';

  @override
  String get importReasonRolledBack => 'यह आयात वापस लेने से हटाई गई।';

  @override
  String get importRowInclude => 'यह पंक्ति आयात करें';

  @override
  String get importRowSkip => 'यह पंक्ति छोड़ें';

  @override
  String get importRowCategory => 'श्रेणी तय करें';

  @override
  String get importRowCorrect => 'यह पंक्ति ठीक करें';

  @override
  String get importRowOpenTransaction => 'लेन-देन खोलें';

  @override
  String get importRowOpenExisting => 'मौजूदा लेन-देन खोलें';

  @override
  String get importRowSaved => 'पंक्ति अपडेट हो गई।';

  @override
  String importRowCorrectTitle(int number) {
    return 'पंक्ति $number ठीक करें';
  }

  @override
  String importRowAsRead(String cells) {
    return 'फ़ाइल से पढ़ी गई: $cells';
  }

  @override
  String get importRowDate => 'तारीख';

  @override
  String get importRowDateRequired => 'तारीख चुनें।';

  @override
  String get importRowAmount => 'राशि';

  @override
  String get importRowMoneyOut => 'जाने वाला पैसा';

  @override
  String get importRowMoneyIn => 'आने वाला पैसा';

  @override
  String get importRowDirectionRequired => 'जाने वाला या आने वाला पैसा चुनें।';

  @override
  String get importRowDescription => 'विवरण';

  @override
  String get importRowSaveCorrection => 'सुधार सहेजें';

  @override
  String get analyticsTitle => 'विश्लेषण';

  @override
  String get analyticsLoading => 'आपके आँकड़े लोड हो रहे हैं';

  @override
  String get analyticsSummaryTitle => 'यह अवधि';

  @override
  String get analyticsNoActivityBody =>
      'यहाँ अपने आँकड़े देखने के लिए लेन-देन जोड़ें या स्टेटमेंट आयात करें।';

  @override
  String get analyticsPeriodReportsTitle => 'इस अवधि को ध्यान से देखें';

  @override
  String get analyticsNowTitle => 'अभी की स्थिति';

  @override
  String get analyticsUnknownReport => 'यह रिपोर्ट उपलब्ध नहीं है।';

  @override
  String get analyticsCashFlowTitle => 'नकदी प्रवाह';

  @override
  String get analyticsCashFlowSubtitle => 'समय के साथ आया और गया पैसा';

  @override
  String get analyticsCategoriesTitle => 'श्रेणी के अनुसार खर्च';

  @override
  String get analyticsCategoriesSubtitle => 'आपका पैसा कहाँ गया';

  @override
  String get analyticsExpensesTitle => 'समय के साथ खर्च';

  @override
  String get analyticsExpensesSubtitle => 'खर्च, रिफ़ंड और प्रतिपूर्ति';

  @override
  String get analyticsIncomeTitle => 'समय के साथ आय';

  @override
  String get analyticsIncomeSubtitle => 'हर अवधि में मिला पैसा';

  @override
  String get analyticsMerchantsTitle => 'मुख्य व्यापारी';

  @override
  String get analyticsMerchantsSubtitle => 'आपने सबसे ज़्यादा कहाँ खर्च किया';

  @override
  String get analyticsAccountsTitle => 'कुल संपत्ति';

  @override
  String get analyticsAccountsSubtitle =>
      'आपके पास क्या है और आप पर कितना बकाया है, हर मुद्रा में';

  @override
  String get analyticsBudgetsTitle => 'बजट का हाल';

  @override
  String get analyticsBudgetsSubtitle =>
      'मौजूदा अवधि में आपके बजट कैसे चल रहे हैं';

  @override
  String get analyticsGoalsTitle => 'लक्ष्यों की प्रगति';

  @override
  String get analyticsGoalsSubtitle => 'आपके लक्ष्यों के लिए अब तक की बचत';

  @override
  String get analyticsSubscriptionsTitle => 'सदस्यताओं का खर्च';

  @override
  String get analyticsSubscriptionsSubtitle =>
      'आपकी सदस्यताओं का हर महीने और साल का खर्च';

  @override
  String get analyticsRecurringTitle => 'नियमित प्रतिबद्धताएँ';

  @override
  String get analyticsRecurringSubtitle => 'नियमित भुगतान और आय, हर महीने';

  @override
  String get analyticsCompareTitle => 'अवधियों की तुलना करें';

  @override
  String get analyticsCompareSubtitle => 'यह अवधि किसी दूसरी अवधि के साथ';

  @override
  String get analyticsGranularityLabel => 'इसके अनुसार समूह बनाएँ';

  @override
  String get analyticsGranularityAuto => 'अपने-आप';

  @override
  String get analyticsGranularityDay => 'दिन';

  @override
  String get analyticsGranularityWeek => 'सप्ताह';

  @override
  String get analyticsGranularityMonth => 'महीना';

  @override
  String get analyticsGranularityYear => 'साल';

  @override
  String get analyticsOverTimeTitle => 'समय के साथ';

  @override
  String get analyticsGrossSpendingLabel => 'रिफ़ंड से पहले खर्च';

  @override
  String get analyticsRefundsLabel => 'रिफ़ंड और प्रतिपूर्ति';

  @override
  String analyticsExpensesSummary(
    String unit,
    String period,
    String amount,
    String bucket,
  ) {
    return '$period में हर $unit का खर्च। सबसे ज़्यादा: $amount ($bucket)।';
  }

  @override
  String analyticsIncomeSummary(
    String unit,
    String period,
    String amount,
    String bucket,
  ) {
    return '$period में हर $unit की आय। सबसे ज़्यादा: $amount ($bucket)।';
  }

  @override
  String get analyticsShowSubcategories => 'उप-श्रेणियाँ अलग से दिखाएँ';

  @override
  String get analyticsShowSubcategoriesHelp =>
      'नहीं तो वे अपनी मुख्य श्रेणी में जोड़ी जाती हैं।';

  @override
  String analyticsMerchantsSummary(String name, String amount, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count व्यापारी दिखाए गए।',
      one: '1 व्यापारी दिखाया गया।',
    );
    return 'सबसे ज़्यादा खर्च $name पर हुआ: $amount। $_temp0';
  }

  @override
  String analyticsMerchantRow(String amount, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count लेन-देन',
      one: '1 लेन-देन',
    );
    return '$amount · $_temp0';
  }

  @override
  String get analyticsOverviewOnly => 'केवल मेरे सारांश वाले खाते';

  @override
  String get analyticsOverviewOnlyHelp =>
      'होम के कुल योग से बाहर रखे गए खाते छोड़ दें।';

  @override
  String get analyticsBudgetsEmpty => 'अभी कोई सक्रिय बजट नहीं है।';

  @override
  String get analyticsBudgetsCreate => 'बजट बनाएँ';

  @override
  String get analyticsBudgetsPaceTitle => 'वे कैसे चल रहे हैं';

  @override
  String analyticsBudgetsOverCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count बजट अपनी सीमा से ऊपर हैं।',
      one: '1 बजट अपनी सीमा से ऊपर है।',
      zero: 'कोई बजट अपनी सीमा से ऊपर नहीं है।',
    );
    return '$_temp0';
  }

  @override
  String get analyticsBudgetsUseTitle => 'हर सीमा का कितना हिस्सा इस्तेमाल हुआ';

  @override
  String analyticsBudgetsSummary(int count, int over) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count बजट',
      one: '1 बजट',
    );
    return '$_temp0 की सीमा का इस्तेमाल। सीमा से ऊपर: $over।';
  }

  @override
  String get analyticsWithinLimit => 'सीमा के अंदर';

  @override
  String analyticsBudgetRow(
    String spent,
    String limit,
    String percent,
    String pace,
  ) {
    return '$limit में से $spent ($percent) · $pace';
  }

  @override
  String get analyticsBudgetNoProgress => 'इस अवधि के आँकड़े अभी नहीं हैं।';

  @override
  String get analyticsGoalsEmpty => 'अभी कोई लक्ष्य नहीं है।';

  @override
  String get analyticsGoalsCreate => 'लक्ष्य बनाएँ';

  @override
  String analyticsGoalsCount(int count, int achieved) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count लक्ष्य',
      one: '1 लक्ष्य',
    );
    return '$_temp0; पूरे हुए: $achieved';
  }

  @override
  String get analyticsGoalsProgressTitle => 'हर लक्ष्य की प्रगति';

  @override
  String analyticsGoalsSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count लक्ष्यों',
      one: '1 लक्ष्य',
    );
    return '$_temp0 के लिए बचाया गया हिस्सा।';
  }

  @override
  String analyticsGoalRow(
    String saved,
    String target,
    String percent,
    String status,
  ) {
    return '$target में से $saved ($percent) · $status';
  }

  @override
  String get analyticsSubscriptionsEmpty => 'अभी कोई सदस्यता नहीं है।';

  @override
  String get analyticsSubscriptionsCreate => 'सदस्यता जोड़ें';

  @override
  String get analyticsNoRenewals =>
      'अगले 30 दिनों में कुछ भी रिन्यू नहीं होगा।';

  @override
  String get analyticsRecurringNote =>
      'मासिक राशि में केवल तय राशियाँ गिनी जाती हैं। बिल और आय अनुमान हैं, दर्ज किया गया पैसा नहीं।';

  @override
  String get analyticsRecurringEmpty => 'कोई सक्रिय नियमित भुगतान या आय नहीं।';

  @override
  String get analyticsRecurringCreate => 'नियमित भुगतान जोड़ें';

  @override
  String analyticsRecurringSummary(String kind, String amount) {
    return 'हर प्रकार की मासिक राशि। सबसे बड़ी $kind है: $amount प्रति माह।';
  }

  @override
  String analyticsPerMonth(String amount) {
    return '$amount प्रति माह';
  }

  @override
  String analyticsRecurringRules(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count सक्रिय',
      one: '1 सक्रिय',
    );
    return '$_temp0';
  }

  @override
  String analyticsNext30Days(String kind) {
    return '$kind: अगले 30 दिनों में देय';
  }

  @override
  String analyticsVariableRules(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'अलग-अलग राशि वाले $count शामिल नहीं हैं।',
      one: 'अलग-अलग राशि वाला 1 शामिल नहीं है।',
    );
    return '$_temp0';
  }

  @override
  String get analyticsCompareNoteSameRules =>
      'दोनों अवधियों में एक जैसे फ़िल्टर और नियम लगते हैं: ट्रांसफ़र नहीं गिने जाते और रिफ़ंड खर्च घटाते हैं।';

  @override
  String get analyticsCompareNoteTotals =>
      'अलग-अलग लंबाई की अवधियों की तुलना कुल योग से होती है, प्रति दिन से नहीं।';

  @override
  String get analyticsCompareThisPeriod => 'यह अवधि';

  @override
  String get analyticsCompareWith => 'इससे तुलना';

  @override
  String get analyticsComparePreviousHelp => 'ठीक पहले के उतने ही दिन।';

  @override
  String analyticsCompareEmpty(String now, String then) {
    return '$now या $then में कोई आय या खर्च नहीं।';
  }

  @override
  String analyticsCompareWindows(String now, String then) {
    return '$now की तुलना $then से';
  }

  @override
  String analyticsCompareSummary(
    String spendingNow,
    String spendingThen,
    String incomeNow,
    String incomeThen,
  ) {
    return 'खर्च $spendingNow रहा, पहले $spendingThen था। आय $incomeNow रही, पहले $incomeThen थी।';
  }

  @override
  String analyticsCompareRow(String now, String then) {
    return 'अभी $now · पहले $then';
  }

  @override
  String analyticsCompareThen(String amount) {
    return 'पहले: $amount';
  }

  @override
  String get analyticsCategoryChangesTitle => 'श्रेणी के अनुसार बदलाव';

  @override
  String get analyticsCategoryChangesEmpty =>
      'किसी भी अवधि में श्रेणी वाला खर्च नहीं।';

  @override
  String analyticsCategoryChangeSpoken(String now, String then, String change) {
    return 'अभी $now, पहले $then, बदलाव $change';
  }

  @override
  String get analyticsChangeNew => 'नया';

  @override
  String analyticsCategoryChange(String amount, String percent) {
    return 'बदलाव: $amount ($percent)';
  }

  @override
  String get reportsLoading => 'आपकी रिपोर्ट लोड हो रही हैं';

  @override
  String get reportsEmptyTitle => 'अभी कोई रिपोर्ट नहीं';

  @override
  String get reportsEmptyBody =>
      'डाउनलोड करने, शेयर करने या रखने के लिए अपने लेन-देन का सारांश या एक्सपोर्ट बनाएँ।';

  @override
  String get reportsWorkingNote =>
      'बन रही रिपोर्ट यहाँ अपने-आप अपडेट होती हैं।';

  @override
  String get reportsStillWorking =>
      'अभी बन रही है। फिर से जाँचने के लिए नीचे खींचें।';

  @override
  String get reportNew => 'नई रिपोर्ट';

  @override
  String get reportNewTitle => 'नई रिपोर्ट';

  @override
  String get reportNewIntro =>
      'रिपोर्ट पीछे से बनती हैं और कुछ दिनों तक डाउनलोड की जा सकती हैं।';

  @override
  String get reportCreate => 'रिपोर्ट बनाएँ';

  @override
  String get reportQueued =>
      'आपकी रिपोर्ट बन रही है। तैयार होने पर यहाँ दिखेगी।';

  @override
  String get reportMaking =>
      'आपकी रिपोर्ट बन रही है। यह पेज अपने-आप अपडेट होता है।';

  @override
  String get reportReadyBody =>
      'इसे किसी दूसरे ऐप से शेयर करें या अपने डिवाइस पर सहेजें।';

  @override
  String get reportExpiredBody =>
      'इस रिपोर्ट की समय-सीमा खत्म हो गई है। डाउनलोड करने के लिए इसे फिर से बनाएँ।';

  @override
  String get reportGenerateAgain => 'फिर से बनाएँ';

  @override
  String get reportNoDeleteNote =>
      'रिपोर्ट फ़ाइलें समय-सीमा खत्म होने पर अपने-आप हट जाती हैं।';

  @override
  String get reportDetailsTitle => 'विवरण';

  @override
  String get reportTypeLabel => 'रिपोर्ट';

  @override
  String get reportFormatLabel => 'फ़ाइल फ़ॉर्मैट';

  @override
  String get reportPeriodLabel => 'अवधि';

  @override
  String get reportPeriodDefault => 'इस रिपोर्ट की सामान्य अवधि';

  @override
  String get reportIncludePending => 'लंबित लेन-देन शामिल करें';

  @override
  String get reportIncludePendingHelp =>
      'नहीं तो केवल पोस्ट किए गए लेन-देन गिने जाते हैं।';

  @override
  String get reportTitleLabel => 'शीर्षक';

  @override
  String get reportTitleHelp => 'वैकल्पिक। जैसे \"टैक्स कागज़ात 2026\"।';

  @override
  String get reportRequestedLabel => 'माँगी गई';

  @override
  String reportRequestedAt(String time) {
    return '$time को माँगी गई';
  }

  @override
  String get reportCompletedLabel => 'तैयार हुई';

  @override
  String get reportExpiresLabel => 'कब तक उपलब्ध';

  @override
  String reportAvailableUntil(String date) {
    return '$date तक उपलब्ध';
  }

  @override
  String get reportRowsLabel => 'आकार';

  @override
  String reportRows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count पंक्तियाँ',
      one: '1 पंक्ति',
    );
    return '$_temp0';
  }

  @override
  String get reportTimezoneLabel => 'समय क्षेत्र';

  @override
  String reportTypeAndFormat(String type, String format) {
    return '$type · $format';
  }

  @override
  String get reportStatusQueued => 'शुरू होने की प्रतीक्षा';

  @override
  String get reportStatusRunning => 'बन रही है';

  @override
  String get reportStatusReady => 'डाउनलोड के लिए तैयार';

  @override
  String get reportStatusFailed => 'नहीं बन सकी';

  @override
  String get reportStatusExpired => 'समय-सीमा खत्म';

  @override
  String get reportStatusOther => 'अन्य स्थिति';

  @override
  String reportStatusSemantics(String status) {
    return 'स्थिति: $status';
  }

  @override
  String get reportFailedTooManyRows =>
      'रिपोर्ट में बहुत ज़्यादा लेन-देन हैं। छोटी अवधि चुनें।';

  @override
  String get reportFailedPdfTooLarge =>
      'यह रिपोर्ट PDF के लिए बहुत लंबी है। CSV या Excel, या छोटी अवधि चुनें।';

  @override
  String get reportFailedInvalid =>
      'इन विकल्पों से रिपोर्ट नहीं बन सकी। कोई दूसरी अवधि या रिपोर्ट आज़माएँ।';

  @override
  String get reportFailedUnavailable =>
      'इस सर्वर पर अभी रिपोर्ट नहीं बन सकतीं।';

  @override
  String get reportFailedOther => 'रिपोर्ट नहीं बन सकी। फिर से कोशिश करें।';

  @override
  String get reportFormatCsv => 'CSV';

  @override
  String get reportFormatXlsx => 'Excel (XLSX)';

  @override
  String get reportFormatPdf => 'PDF';

  @override
  String get reportFormatJson => 'JSON';

  @override
  String get reportFormatCsvHelp => 'किसी भी स्प्रेडशीट ऐप में खुलती है।';

  @override
  String get reportFormatXlsxHelp => 'Excel और ऐसे ही ऐप के लिए।';

  @override
  String get reportFormatPdfHelp => 'पढ़ने या प्रिंट करने के लिए तैयार।';

  @override
  String get reportFormatJsonHelp => 'दूसरे ऐप और टूल के लिए।';

  @override
  String get reportTypeMonthlySummary => 'मासिक सारांश';

  @override
  String get reportTypeMonthlySummaryHelp =>
      'एक महीने की आय, खर्च और मुख्य श्रेणियाँ।';

  @override
  String get reportTypeYearlySummary => 'सालाना सारांश';

  @override
  String get reportTypeYearlySummaryHelp => 'पूरे साल की झलक, महीने दर महीने।';

  @override
  String get reportTypeCashFlow => 'नकदी प्रवाह';

  @override
  String get reportTypeCashFlowHelp => 'अवधि में आया और गया पैसा।';

  @override
  String get reportTypeIncome => 'आय';

  @override
  String get reportTypeIncomeHelp =>
      'अवधि में मिला पैसा, श्रेणी के अनुसार। खर्च शामिल नहीं है।';

  @override
  String get reportTypeExpense => 'खर्च';

  @override
  String get reportTypeExpenseHelp =>
      'अवधि में खर्च, रिफ़ंड और प्रतिपूर्ति। आय शामिल नहीं है।';

  @override
  String get reportTypeCategory => 'श्रेणी के अनुसार खर्च';

  @override
  String get reportTypeCategoryHelp => 'हर श्रेणी का कुल योग।';

  @override
  String get reportTypeMerchant => 'व्यापारी के अनुसार खर्च';

  @override
  String get reportTypeMerchantHelp => 'आपने सबसे ज़्यादा कहाँ खर्च किया।';

  @override
  String get reportTypeAccount => 'खाते';

  @override
  String get reportTypeAccountHelp => 'बैलेंस, संपत्ति और आपका बकाया।';

  @override
  String get reportTypeBudget => 'बजट';

  @override
  String get reportTypeBudgetHelp => 'हर बजट कैसा चल रहा है।';

  @override
  String get reportTypeSubscription => 'सदस्यताएँ';

  @override
  String get reportTypeSubscriptionHelp => 'आपकी सदस्यताओं का खर्च।';

  @override
  String get reportTypeRecurring => 'नियमित प्रतिबद्धताएँ';

  @override
  String get reportTypeRecurringHelp => 'हर महीने के नियमित भुगतान और आय।';

  @override
  String get reportTypeGoal => 'लक्ष्य';

  @override
  String get reportTypeGoalHelp => 'हर लक्ष्य की प्रगति।';

  @override
  String get reportTypeTransactions => 'लेन-देन';

  @override
  String get reportTypeTransactionsHelp =>
      'अवधि का हर लेन-देन, हर पंक्ति में एक।';

  @override
  String get reportTypeOther => 'रिपोर्ट';

  @override
  String get reportSchedulesTitle => 'शेड्यूल की गई रिपोर्ट';

  @override
  String get schedulesEmptyTitle => 'कोई शेड्यूल की गई रिपोर्ट नहीं';

  @override
  String get schedulesEmptyBody =>
      'हर बार माँगे बिना हर सप्ताह या महीने सारांश पाएँ।';

  @override
  String get schedulesNote =>
      'शेड्यूल की गई रिपोर्ट तैयार होने पर आपकी रिपोर्ट सूची में दिखती हैं।';

  @override
  String get scheduleNew => 'रिपोर्ट शेड्यूल करें';

  @override
  String get scheduleNewTitle => 'रिपोर्ट शेड्यूल करें';

  @override
  String get scheduleCreate => 'रिपोर्ट शेड्यूल करें';

  @override
  String get scheduleCreated => 'रिपोर्ट शेड्यूल हो गई।';

  @override
  String get scheduleCadenceLabel => 'कितनी बार';

  @override
  String get scheduleCadenceWeekly => 'हर सप्ताह';

  @override
  String get scheduleCadenceMonthly => 'हर महीने';

  @override
  String get scheduleWeeklyHelp => 'हर रिपोर्ट पिछले पूरे सप्ताह की होती है।';

  @override
  String get scheduleMonthlyHelp => 'हर रिपोर्ट पिछले पूरे महीने की होती है।';

  @override
  String scheduleCadenceAndFormat(String cadence, String format) {
    return '$cadence · $format';
  }

  @override
  String scheduleNextRun(String time) {
    return 'अगली: $time';
  }

  @override
  String get scheduleOff => 'बंद';

  @override
  String scheduleTitleWeekly(String type) {
    return '$type (साप्ताहिक)';
  }

  @override
  String scheduleTitleMonthly(String type) {
    return '$type (मासिक)';
  }

  @override
  String get scheduleDeleteTitle => 'यह शेड्यूल हटाएँ?';

  @override
  String scheduleDeleteBody(String title) {
    return '“$title” अब नहीं बनेगी। पहले बनी रिपोर्ट समय-सीमा खत्म होने तक आपकी सूची में रहेंगी।';
  }

  @override
  String scheduleDeleteLabel(String title) {
    return 'शेड्यूल $title हटाएँ';
  }

  @override
  String get scheduleDeleted => 'शेड्यूल हटा दिया गया।';

  @override
  String get fxIntro =>
      'दरें बताती हैं कि एक मुद्रा की एक इकाई दूसरी मुद्रा में कितनी है। आपकी अपनी दरें प्रकाशित दरों से पहले इस्तेमाल होती हैं।';

  @override
  String get fxEmptyTitle => 'अभी कोई विनिमय दर नहीं';

  @override
  String get fxNoMatchTitle => 'इन मुद्राओं की कोई दर नहीं';

  @override
  String get fxEmptyBody => 'मुद्राओं के बीच बदलने के लिए अपनी दर जोड़ें।';

  @override
  String get fxFilterFrom => 'से';

  @override
  String get fxFilterTo => 'में';

  @override
  String get fxFilterAny => 'कोई भी';

  @override
  String get fxAddRate => 'दर जोड़ें';

  @override
  String fxRatePair(String base, String rate, String quote) {
    return '1 $base = $rate $quote';
  }

  @override
  String fxAsOf(String source, String date) {
    return '$source · $date तक';
  }

  @override
  String get fxYourRate => 'आपकी दर';

  @override
  String get fxSourceManual => 'आपकी दर';

  @override
  String get fxSourceEcb => 'यूरोपीय सेंट्रल बैंक';

  @override
  String get fxSourceProvider => 'दर प्रदाता';

  @override
  String get fxSourceOther => 'अन्य स्रोत';

  @override
  String get fxSourceLabel => 'स्रोत';

  @override
  String get fxDeleteTitle => 'यह दर हटाएँ?';

  @override
  String fxDeleteBody(String base, String quote) {
    return 'आपकी $base से $quote की दर हटा दी जाएगी। अगर प्रकाशित दरें हैं, तो उनका इस्तेमाल होगा।';
  }

  @override
  String fxDeleteLabel(String base, String quote) {
    return 'अपनी $base से $quote की दर हटाएँ';
  }

  @override
  String get fxDeleted => 'दर हटा दी गई।';

  @override
  String get fxManualIntro =>
      'वह दर जोड़ें जो आपको मिली, जैसे अपने बैंक से। आपकी पिछली दरें रखी जाती हैं।';

  @override
  String get fxBaseLabel => 'इस मुद्रा से';

  @override
  String get fxQuoteLabel => 'इस मुद्रा में';

  @override
  String get fxRateHelp =>
      'पहली मुद्रा की एक इकाई दूसरी मुद्रा की कितनी इकाइयों के बराबर है।';

  @override
  String fxRateHelpPair(String base, String quote) {
    return 'एक $base कितने $quote के बराबर है, जैसे 83.12';
  }

  @override
  String get fxRateInvalid =>
      'शून्य से बड़ी संख्या लिखें, जिसमें अधिकतम 12 दशमलव अंक हों, जैसे 83.12।';

  @override
  String get fxAsOfLabel => 'दर की तारीख';

  @override
  String get fxAsOfNow => 'अभी';

  @override
  String get fxAsOfHelp =>
      'अभी के लिए खाली छोड़ें। तारीख़ का मतलब आपके समय क्षेत्र में वह पूरा दिन है (आज भी चलेगा); यह आगे की नहीं हो सकती।';

  @override
  String get fxPairRequired => 'दोनों मुद्राएँ चुनें।';

  @override
  String get fxPairDifferent => 'दो अलग-अलग मुद्राएँ चुनें।';

  @override
  String get fxSaveRate => 'दर सहेजें';

  @override
  String get fxSaved => 'दर सहेजी गई।';

  @override
  String get fxConvertTitle => 'मुद्रा बदलें';

  @override
  String get fxConvertIntro =>
      'मॉन्ट्रा इस्तेमाल की गई दर, उसका स्रोत और तारीख दिखाता है। आपकी अपनी दरें पहले इस्तेमाल होती हैं।';

  @override
  String get fxFromLabel => 'से';

  @override
  String get fxToLabel => 'में';

  @override
  String get fxUseDate => 'किसी तारीख की दर इस्तेमाल करें';

  @override
  String get fxUseDateHelp => 'नहीं तो नवीनतम दर इस्तेमाल होगी।';

  @override
  String get fxDateLabel => 'दर की तारीख';

  @override
  String get fxDateRequired => 'तारीख चुनें।';

  @override
  String get fxConvertAction => 'बदलें';

  @override
  String get fxResultTitle => 'परिणाम';

  @override
  String fxResultLine(String from, String to) {
    return '$from = $to';
  }

  @override
  String get fxRateDateLabel => 'दर इस समय की';

  @override
  String get fxPolicyLabel => 'इस्तेमाल की गई दर';

  @override
  String get fxPolicyCurrent => 'नवीनतम दर';

  @override
  String get fxPolicyHistorical => 'किसी तारीख की दर';

  @override
  String fxInvertedNote(String quote, String base) {
    return '$quote से $base की दर से निकाली गई।';
  }

  @override
  String fxRoundingNote(String delta) {
    return 'मुद्रा की सबसे छोटी इकाई तक पूर्णांकित (अंतर: उस इकाई का $delta)।';
  }

  @override
  String fxNoRate(String from, String to) {
    return '$from से $to की कोई विनिमय दर उपलब्ध नहीं है। अपनी दर जोड़ें।';
  }

  @override
  String get reconTitle => 'मिलान करें';

  @override
  String reconTitleOf(String account) {
    return '$account का मिलान';
  }

  @override
  String get reconLoading => 'मिलान लोड हो रहा है';

  @override
  String get reconTabBalances => 'बैलेंस';

  @override
  String get reconTabSuggestions => 'सुझाव';

  @override
  String get reconTabMatched => 'मिलान हुए';

  @override
  String get reconBalancesIntro =>
      'अपने स्टेटमेंट के अंतिम बैलेंस की तुलना उसी तारीख के मॉन्ट्रा बैलेंस से करें। मेल खाने पर, उस तारीख तक के लेन-देन मिलान किए गए के रूप में चिह्नित हो जाते हैं।';

  @override
  String get reconCheckBalance => 'स्टेटमेंट बैलेंस जाँचें';

  @override
  String get reconBalancesEmpty => 'अभी तक स्टेटमेंट बैलेंस की कोई जाँच नहीं।';

  @override
  String reconStatementOf(String date) {
    return '$date का स्टेटमेंट';
  }

  @override
  String get reconBalanced => 'मेल खाता है';

  @override
  String reconOffBy(String amount) {
    return '$amount का अंतर';
  }

  @override
  String get reconOffByHelp =>
      'इस तारीख तक छूटे, दोहराए गए या लंबित लेन-देन देखें, फिर दोबारा जाँचें।';

  @override
  String get reconStatementBalance => 'स्टेटमेंट बैलेंस';

  @override
  String get reconLedgerBalance => 'मॉन्ट्रा का बैलेंस';

  @override
  String get reconDifference => 'अंतर';

  @override
  String reconReconciledCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count लेन-देन मिलान किए गए चिह्नित हुए।',
      one: '1 लेन-देन मिलान किया गया चिह्नित हुआ।',
    );
    return '$_temp0';
  }

  @override
  String reconUnreconciledCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'इस तारीख तक के $count लेन-देन अभी मिलान नहीं हुए।',
      one: 'इस तारीख तक का 1 लेन-देन अभी मिलान नहीं हुआ।',
    );
    return '$_temp0';
  }

  @override
  String reconUnmatchedRows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'स्टेटमेंट की $count पंक्तियों का अभी मिलान नहीं हुआ।',
      one: 'स्टेटमेंट की 1 पंक्ति का अभी मिलान नहीं हुआ।',
    );
    return '$_temp0';
  }

  @override
  String get reconSuggestionsIntro =>
      'मॉन्ट्रा को मिले संभावित मिलान। जब तक आप पक्का न करें, कुछ नहीं बदलता, और आप इसे बाद में पलट सकते हैं।';

  @override
  String get reconSuggestionsEmpty => 'अभी कोई सुझाया गया मिलान नहीं।';

  @override
  String get reconSuggestionsEmptyBody =>
      'आयात की गई स्टेटमेंट पंक्तियों, पोस्ट हो चुके लंबित लेन-देन और दो बार दर्ज लेन-देन के लिए सुझाव दिखते हैं।';

  @override
  String reconConfidence(int percent) {
    return 'मिलान की संभावना: $percent%';
  }

  @override
  String get reconConfirm => 'मिलान पक्का करें';

  @override
  String get reconConfirmPendingTitle => 'लंबित लेन-देन बदलें?';

  @override
  String get reconConfirmPendingBody =>
      'लंबित लेन-देन हटा दिया जाएगा, क्योंकि पोस्ट किया गया लेन-देन उसकी जगह लेता है। आप इसे बाद में पलट सकते हैं।';

  @override
  String get reconKeepTitle => 'कौन सा रहना चाहिए?';

  @override
  String get reconKeepImported => 'आयात वाला रखें';

  @override
  String get reconKeepManual => 'आपका दर्ज किया हुआ रखें';

  @override
  String reconWhy(String reasons) {
    return 'क्यों: $reasons';
  }

  @override
  String get reconKindStatement => 'स्टेटमेंट की पंक्ति';

  @override
  String get reconKindStatementHelp =>
      'स्टेटमेंट की एक पंक्ति मॉन्ट्रा में पहले से मौजूद लेन-देन से मिलती है। पक्का करने पर वे मिलान किए गए हो जाते हैं; पंक्ति दोबारा आयात नहीं होती।';

  @override
  String get reconKindPending => 'लंबित अब पोस्ट हुआ';

  @override
  String get reconKindPendingHelp =>
      'एक लंबित लेन-देन पोस्ट हो गया है। पक्का करने पर लंबित वाला हट जाएगा।';

  @override
  String get reconKindDuplicate => 'दो बार दर्ज';

  @override
  String get reconKindDuplicateHelp =>
      'एक ही लेन-देन आपने दर्ज किया और आयात भी हुआ। पक्का करने पर एक रहेगा और दूसरा हटेगा।';

  @override
  String get reconKindOther => 'मिलान';

  @override
  String get reconSideStatement => 'स्टेटमेंट पर';

  @override
  String get reconSideLedger => 'मॉन्ट्रा में';

  @override
  String get reconSidePending => 'लंबित';

  @override
  String get reconSideImported => 'आयात किया गया';

  @override
  String get reconMatchesEmpty => 'अभी कोई मिलान नहीं।';

  @override
  String reconMatchedOn(String date) {
    return '$date को मिलान';
  }

  @override
  String get reconMatchConfirmed => 'मिलान हुआ';

  @override
  String get reconMatchUndone => 'पलटा गया';

  @override
  String get reconMatchSuggested => 'सुझाया गया';

  @override
  String get reconMatchRejected => 'अस्वीकार';

  @override
  String get reconMatchOther => 'अन्य स्थिति';

  @override
  String get reconEffectVoided => 'हटाया गया (पलटने पर वापस आ जाएगा)';

  @override
  String get reconEffectRowSkipped => 'स्टेटमेंट की पंक्ति आयात नहीं हुई';

  @override
  String get reconUndo => 'मिलान पलटें';

  @override
  String get reconUndoTitle => 'यह मिलान पलटें?';

  @override
  String get reconUndoBody =>
      'हटाए गए लेन-देन वापस आ जाएँगे और स्टेटमेंट पंक्तियाँ अपने आयात में लौट जाएँगी।';

  @override
  String get reconUndone => 'मिलान पलटा गया।';

  @override
  String get reconReasonSameAmount => 'एक ही राशि और दिशा';

  @override
  String get reconReasonSameDate => 'एक ही तारीख';

  @override
  String get reconReasonOneDay => 'एक दिन का अंतर';

  @override
  String get reconReasonThreeDays => '3 दिन के अंदर';

  @override
  String get reconReasonWeek => 'एक सप्ताह के अंदर';

  @override
  String get reconReasonReference => 'एक ही संदर्भ';

  @override
  String get reconReasonDescription => 'मिलता-जुलता विवरण';

  @override
  String get reconReasonAddsUp => 'राशियों का जोड़ बिल्कुल बराबर है';

  @override
  String get reconReasonAllWeek => 'सभी एक सप्ताह के अंदर';

  @override
  String get reconReasonPendingReplaced =>
      'पोस्ट किया गया लेन-देन लंबित वाले की जगह लेता है';

  @override
  String get reconReasonEnteredTwice =>
      'एक ही लेन-देन आपने दर्ज किया और आयात भी हुआ';

  @override
  String reconReasonAmountsDiffer(String pending, String posted) {
    return 'राशियाँ अलग हैं ($pending लंबित, $posted पोस्ट)';
  }

  @override
  String reconFormIntro(String account) {
    return '$account के स्टेटमेंट पर दिखाया गया अंतिम बैलेंस दर्ज करें।';
  }

  @override
  String get reconFromImport => 'यह जाँच आयात किए गए स्टेटमेंट से जुड़ी है।';

  @override
  String get reconStatementDate => 'स्टेटमेंट की तारीख';

  @override
  String get reconChooseDate => 'तारीख चुनें';

  @override
  String get reconDateRequired => 'स्टेटमेंट की तारीख चुनें।';

  @override
  String get reconBalanceKindLabel => 'स्टेटमेंट में दिखता है';

  @override
  String get reconKindOwed => 'आपका बकाया';

  @override
  String get reconKindBalance => 'बैलेंस';

  @override
  String get reconAmountOwedLabel => 'स्टेटमेंट पर बकाया राशि';

  @override
  String get reconAmountOwedHelp =>
      'स्टेटमेंट पर आपका बकाया, धनात्मक संख्या के रूप में।';

  @override
  String get reconStatementBalanceHelp =>
      'जैसा स्टेटमेंट में दिखा है। ओवरड्रॉन बैलेंस के लिए माइनस चिह्न लगाएँ।';

  @override
  String get reconWhatHappens =>
      'मॉन्ट्रा इसकी तुलना उस तारीख के अपने बैलेंस से करता है। मेल खाने पर, उस तारीख तक के पोस्ट किए गए लेन-देन मिलान किए गए चिह्नित होते हैं। और कुछ नहीं बदलता।';

  @override
  String get reconCompare => 'तुलना करें';

  @override
  String get reconResultBalanced => 'बैलेंस मेल खाते हैं।';

  @override
  String get reconResultOff => 'बैलेंस अभी मेल नहीं खाते।';

  @override
  String get reconCheckAgain => 'दूसरा बैलेंस जाँचें';

  @override
  String get limitsStorageTitle => 'फ़ाइल स्टोरेज';

  @override
  String limitsStorageUsed(String used, String quota) {
    return '$quota में से $used इस्तेमाल हुआ';
  }

  @override
  String get limitsTitle => 'उचित उपयोग की सीमाएँ';

  @override
  String get limitsFreeNote =>
      'Montra की हर सुविधा मुफ़्त है। ये सीमाएँ सभी के लिए एक जैसी हैं और Montra को तेज़ रखती हैं।';

  @override
  String limitsOpenBills(String count) {
    return 'खुले बिल: अधिकतम $count';
  }

  @override
  String limitsRecurring(String count) {
    return 'नियमित भुगतान: अधिकतम $count';
  }

  @override
  String limitsSubscriptions(String count) {
    return 'सदस्यताएँ: अधिकतम $count';
  }

  @override
  String limitsGoals(String count) {
    return 'लक्ष्य: अधिकतम $count';
  }

  @override
  String limitsImportRows(String count) {
    return 'एक स्टेटमेंट आयात में पंक्तियाँ: अधिकतम $count';
  }

  @override
  String limitsExportDays(String days) {
    return 'रिपोर्ट डाउनलोड $days दिनों तक रखे जाते हैं';
  }

  @override
  String get errorFileInUse => 'यह पेज पहले से किसी दूसरी रसीद का हिस्सा है।';

  @override
  String get errorPageNotReady =>
      'एक पेज अभी अपलोड हो रहा है। थोड़ी देर रुककर फिर कोशिश करें।';

  @override
  String get errorReceiptLinked =>
      'यह रसीद पहले से किसी लेन-देन से जुड़ी है। पहले उसे अलग करें।';

  @override
  String get errorReceiptDiscarded =>
      'यह रसीद हटा दी गई थी। पहले उसे वापस लाएँ।';

  @override
  String get errorReceiptProcessing =>
      'यह रसीद अभी तैयार हो रही है। थोड़ी देर बाद फिर कोशिश करें।';

  @override
  String get errorReceiptNotLinked => 'यह रसीद किसी लेन-देन से जुड़ी नहीं है।';

  @override
  String get errorReceiptNotDiscarded =>
      'केवल हटाई गई रसीदें वापस लाई जा सकती हैं।';

  @override
  String get errorTransactionHasReceipt => 'उस लेन-देन की पहले से एक रसीद है।';

  @override
  String receiptWarningLineItemsAmounts(String total, String subtotal) {
    return 'आइटम का जोड़ $total है, उप-योग $subtotal नहीं। संख्याएँ जाँचें।';
  }

  @override
  String receiptWarningAmountUnreadable(String value) {
    return 'एक राशि पढ़ी नहीं जा सकी (“$value”)। इसे जाँचें।';
  }

  @override
  String get receiptWarningAmountUnreadableGeneric =>
      'एक राशि पढ़ी नहीं जा सकी। राशियाँ जाँचें।';

  @override
  String get receiptWarningDateUnreadable =>
      'तारीख पढ़ी नहीं जा सकी। इसे जाँचें।';

  @override
  String get receiptWarningCurrencyUnrecognized =>
      'मुद्रा पहचानी नहीं गई। इसे जाँचें।';

  @override
  String get receiptWarningReadingFailed =>
      'यह रसीद अपने-आप पढ़ी नहीं जा सकी। विवरण खुद भरें।';

  @override
  String get receiptDiscardBodyRestorable =>
      'यह आपके इनबॉक्स से हट जाएगी। आप इसे बाद में वापस ला सकते हैं; इसकी फ़ाइलें रखी जाती हैं।';

  @override
  String get receiptDiscardLinkedBodyRestorable =>
      'यह आपके इनबॉक्स से हटेगी और अपने लेन-देन से अलग हो जाएगी; लेन-देन जैसा है वैसा ही रहेगा। बाद में रसीद वापस लाने पर भी वह अलग ही रहेगी।';

  @override
  String get receiptRestore => 'वापस लाएँ';

  @override
  String get receiptRestored => 'रसीद वापस लाई गई।';

  @override
  String get receiptCheckDetails => 'विवरण जाँचें';

  @override
  String get receiptHelpCheckManual =>
      'ये मान आपने नहीं भरे हैं। खरीदारी दर्ज करने से पहले इन्हें जाँचकर सहेजें।';

  @override
  String get receiptAddFailedTitle => 'रसीद जोड़ी नहीं गई';

  @override
  String get receiptAddForget => 'न जोड़ें';

  @override
  String get receiptPaymentMethodHelp =>
      'उदाहरण: नकद, UPI या कार्ड। कार्ड या खाता नंबर न लिखें।';

  @override
  String get navInsights => 'इनसाइट';

  @override
  String get navTogether => 'साथ में';

  @override
  String get searchTitle => 'खोजें';

  @override
  String get notificationsTitle => 'सूचनाएँ';

  @override
  String notificationsUnreadBadge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count बिना पढ़ी सूचनाएँ',
      one: '1 बिना पढ़ी सूचना',
    );
    return '$_temp0';
  }

  @override
  String get fieldRequired => 'यह ज़रूरी है।';

  @override
  String fieldTooShort(String min) {
    return 'कम से कम $min अक्षर लिखें।';
  }

  @override
  String fieldTooLong(String max) {
    return 'अधिकतम $max अक्षर लिखें।';
  }

  @override
  String fieldTooFew(String min) {
    return 'कम से कम $min चुनें।';
  }

  @override
  String fieldTooMany(String max) {
    return 'अधिकतम $max चुनें।';
  }

  @override
  String get fieldTooSmall => 'यह मान बहुत छोटा है।';

  @override
  String get fieldTooLarge => 'यह मान बहुत बड़ा है।';

  @override
  String get fieldInvalidChoice => 'दिए गए विकल्पों में से एक चुनें।';

  @override
  String get fieldInvalidFormat => 'इस मान का प्रारूप जाँचें।';

  @override
  String get fieldInvalidType => 'यह मान सही प्रकार का नहीं है।';

  @override
  String get fieldUnexpected => 'यह फ़ील्ड यहाँ स्वीकार नहीं है।';

  @override
  String get fieldInvalidCharacters => 'असमर्थित अक्षर हटाएँ।';

  @override
  String get fieldContainsSecret =>
      'भेजने से पहले कार्ड नंबर, PIN, वन-टाइम कोड और पासवर्ड हटाएँ।';

  @override
  String fieldTooManyLinks(String max) {
    return 'अधिकतम $max लिंक जोड़ें।';
  }

  @override
  String get fieldInsecureLink => 'लिंक https:// से शुरू होने चाहिए।';

  @override
  String get fieldLinkRequired => 'एक लिंक जोड़ें।';

  @override
  String get fieldModeratorsOnly => 'केवल मॉडरेटर ही यह पोस्ट कर सकते हैं।';

  @override
  String get fieldPollMismatch =>
      'पोल के लिए विकल्प ज़रूरी हैं; अन्य पोस्ट में विकल्प नहीं हो सकते।';

  @override
  String get fieldDuplicateOption => 'हर पोल विकल्प अलग होना चाहिए।';

  @override
  String get fieldMustBeFuture => 'आगे की कोई तारीख़ चुनें।';

  @override
  String get fieldInvalidParent => 'उस टिप्पणी का जवाब नहीं दिया जा सकता।';

  @override
  String get fieldInvalidOption => 'यह विकल्प इस पोल में नहीं है।';

  @override
  String get fieldInvalidTopic => 'एक विषय मान्य नहीं है।';

  @override
  String get fieldSelfNotAllowed => 'आप यह अपने लिए नहीं कर सकते।';

  @override
  String get fieldReasonRequired => 'कारण बताएँ।';

  @override
  String get fieldShareRequired =>
      'लीडरबोर्ड पर दिखने के लिए अपनी प्रगति साझा करें।';

  @override
  String get fieldSlugTaken =>
      'यह URL नाम पहले से लिया जा चुका है। दूसरा चुनें।';

  @override
  String errorDailyCapRetry(String limit, String wait) {
    return 'आज की सीमा पूरी हो गई (प्रति दिन $limit)। $wait बाद फिर से कोशिश करें।';
  }

  @override
  String errorDailyCap(String limit) {
    return 'आज की सीमा पूरी हो गई (प्रति दिन $limit)। कल फिर से कोशिश करें।';
  }

  @override
  String get profileYouTitle => 'आप और आपका डेटा';

  @override
  String get profileNotificationsSubtitle =>
      'Montra आपको क्या और कैसे बताता है';

  @override
  String get profileFriendsTitle => 'दोस्त';

  @override
  String get profileFriendsSubtitle =>
      'अनुरोध, ब्लॉक किए गए लोग और आपको कौन ढूँढ सकता है';

  @override
  String get profileIntegrationsTitle => 'जुड़ी सेवाएँ';

  @override
  String get profileIntegrationsSubtitle =>
      'बैंक और अन्य कनेक्शन, और उनकी स्थिति';

  @override
  String get profilePrivacySubtitle =>
      'सहमतियाँ, आपके डेटा की कॉपी, खाता बंद करना';

  @override
  String get profileModerationTitle => 'मॉडरेशन के फ़ैसले';

  @override
  String get profileModerationSubtitle =>
      'आपके बारे में फ़ैसले, आपकी अपीलें और रिपोर्ट';

  @override
  String get profileHelpSubtitle => 'आम सवाल और आपके सहायता अनुरोध';

  @override
  String get contactEntry => 'मदद चाहिए? सहायता से संपर्क करें';

  @override
  String get helpTitle => 'मदद और सहायता';

  @override
  String get helpIntro =>
      'नीचे जल्दी जवाब पाएँ, या Montra सहायता से पूछें। Montra में सब कुछ मुफ़्त है, सहायता भी।';

  @override
  String get helpNewRequest => 'मदद माँगें';

  @override
  String get helpYourRequests => 'आपके अनुरोध';

  @override
  String get helpNoRequests => 'आपने अभी तक मदद नहीं माँगी है।';

  @override
  String helpRequestMeta(String kind, String reference, String date) {
    return '$kind · $reference · $date';
  }

  @override
  String helpMessageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count संदेश',
      one: '1 संदेश',
    );
    return '$_temp0';
  }

  @override
  String get helpTopicsTitle => 'आम सवाल';

  @override
  String get helpTopicMoneyTitle => 'Montra आपका पैसा कैसे गिनता है';

  @override
  String get helpTopicMoneyBody =>
      'आपके अपने खातों के बीच ट्रांसफ़र खर्च या आय नहीं हैं। रिफ़ंड खर्च कम करते हैं। अलग-अलग मुद्राओं की राशियाँ कभी नहीं जोड़ी जातीं। लंबित लेन-देन तभी गिने जाते हैं जब आप उन्हें शामिल करना चुनें।';

  @override
  String get helpTopicMoneyLink => 'अपना विश्लेषण देखें';

  @override
  String get helpTopicPrivacyTitle => 'आपकी निजता';

  @override
  String get helpTopicPrivacyBody =>
      'आपके रिकॉर्ड सिर्फ़ आपको दिखते हैं, जब तक आप उन्हें किसी समूह में साझा न करें। Montra कभी बैंक पासवर्ड, UPI PIN, OTP या कार्ड नंबर नहीं माँगता। आप कभी भी अपना डेटा डाउनलोड कर सकते हैं या खाता हटा सकते हैं।';

  @override
  String get helpTopicPrivacyLink => 'निजता और डेटा';

  @override
  String get helpTopicImportsTitle => 'स्टेटमेंट इंपोर्ट करना';

  @override
  String get helpTopicImportsBody =>
      'अपने बैंक से CSV, XLSX या OFX स्टेटमेंट इंपोर्ट करें। कुछ भी जोड़ने से पहले आप हर पंक्ति जाँचते हैं, और इंपोर्ट वापस ले सकते हैं।';

  @override
  String get helpTopicImportsLink => 'इंपोर्ट पर जाएँ';

  @override
  String get helpTopicGroupsTitle => 'समूह और साझा खर्च';

  @override
  String get helpTopicGroupsBody =>
      'घर के साथियों, यात्राओं या दोस्तों के साथ खर्च बाँटें। Montra हिसाब रखता है; पैसे कभी नहीं भेजता। भुगतान आप दर्ज करते हैं और दूसरा व्यक्ति पुष्टि करता है।';

  @override
  String get helpTopicGroupsLink => 'समूहों पर जाएँ';

  @override
  String get helpTopicLimitsTitle => 'क्या कुछ सशुल्क है?';

  @override
  String get helpTopicLimitsBody =>
      'नहीं। Montra में सब कुछ मुफ़्त है। कुछ उचित-उपयोग सीमाएँ, जो सबके लिए एक जैसी हैं, इसे तेज़ रखती हैं।';

  @override
  String get helpTopicLimitsLink => 'सीमाएँ देखें';

  @override
  String get helpTopicModerationTitle => 'कोई पोस्ट हटाई गई या पाबंदी लगी?';

  @override
  String get helpTopicModerationBody =>
      'अपने बारे में फ़ैसले देखें और 30 दिनों के भीतर समीक्षा माँगें।';

  @override
  String get helpTopicModerationLink => 'मॉडरेशन के फ़ैसले';

  @override
  String get helpKindLabel => 'यह किस बारे में है?';

  @override
  String get helpKindSupport => 'Montra इस्तेमाल करने में मदद';

  @override
  String get helpKindBug => 'कुछ काम नहीं कर रहा';

  @override
  String get helpKindSecurity => 'सुरक्षा से जुड़ी चिंता';

  @override
  String get helpKindPrivacy => 'निजता या मेरा डेटा';

  @override
  String get helpKindFeedback => 'सुझाव या कोई विचार';

  @override
  String get helpStatusOpen => 'खुला';

  @override
  String get helpStatusInProgress => 'देखा जा रहा है';

  @override
  String get helpStatusResolved => 'हल हो गया';

  @override
  String get helpStatusClosed => 'बंद';

  @override
  String get helpNoSecretsNote =>
      'कभी भी कार्ड नंबर, PIN, वन-टाइम कोड या पासवर्ड न लिखें। Montra सहायता को इनकी कभी ज़रूरत नहीं होती।';

  @override
  String get helpNoSecretsShort => 'कार्ड नंबर, PIN, कोड या पासवर्ड नहीं।';

  @override
  String get helpSubjectLabel => 'विषय';

  @override
  String get helpBodyLabel => 'आपका संदेश';

  @override
  String get helpBodyHelp =>
      'बताएँ कि आपने क्या किया और क्या हुआ। राशि या खाते का विवरण तभी लिखें जब ज़रूरी हो।';

  @override
  String get helpSend => 'भेजें';

  @override
  String helpRequestSent(String reference) {
    return 'भेज दिया। आपका संदर्भ $reference है।';
  }

  @override
  String get helpRequestTitle => 'सहायता अनुरोध';

  @override
  String get helpReferenceLabel => 'संदर्भ';

  @override
  String get helpSentOn => 'भेजा गया';

  @override
  String get helpConversation => 'बातचीत';

  @override
  String get helpNoMessages =>
      'अभी कोई जवाब नहीं। Montra सहायता यहाँ जवाब देगी, और आपको सूचना मिलेगी।';

  @override
  String get helpFromSupport => 'Montra सहायता';

  @override
  String get helpFromYou => 'आप';

  @override
  String get helpFromRequester => 'अनुरोधकर्ता';

  @override
  String get helpReplyLabel => 'जवाब जोड़ें';

  @override
  String get helpSendReply => 'जवाब भेजें';

  @override
  String get helpReplySent => 'जवाब भेज दिया।';

  @override
  String get helpRequestClosedNote =>
      'यह अनुरोध बंद है। अगर अब भी मदद चाहिए, तो मदद और सहायता से फिर पूछें।';

  @override
  String get helpRequestClosedError =>
      'यह अनुरोध बंद है, इसलिए इसमें और जवाब नहीं जोड़े जा सकते। मदद और सहायता से फिर पूछें।';

  @override
  String get contactTitle => 'सहायता से संपर्क करें';

  @override
  String get contactIntro =>
      'साइन इन नहीं हो पा रहा, या अभी Montra इस्तेमाल नहीं करते? हमें संदेश भेजें, हम ईमेल से जवाब देंगे।';

  @override
  String get contactEmailLabel => 'आपका ईमेल';

  @override
  String get contactEmailHelp =>
      'हम इसका उपयोग सिर्फ़ इस संदेश का जवाब देने के लिए करते हैं।';

  @override
  String get contactEmailInvalid => 'name@example.com जैसा ईमेल पता लिखें।';

  @override
  String get contactSentTitle => 'संदेश भेज दिया';

  @override
  String contactSentBody(String reference) {
    return 'आपका संदर्भ $reference है। हम आपके ईमेल पर जवाब देंगे।';
  }

  @override
  String get privacyTitle => 'निजता और डेटा';

  @override
  String get privacyIntro =>
      'चुनें कि Montra आपके डेटा के साथ क्या कर सकता है, सब कुछ की कॉपी लें, या अपना खाता बंद करें।';

  @override
  String get privacyConsentsTitle => 'सहमतियाँ';

  @override
  String privacyConsentAccepted(String version) {
    return 'स्वीकार की गई (संस्करण $version)';
  }

  @override
  String get privacyConsentTerms => 'उपयोग की शर्तें';

  @override
  String get privacyConsentPrivacyPolicy => 'निजता सूचना';

  @override
  String get privacyConsentRequiredBody =>
      'Montra इस्तेमाल करने के लिए ज़रूरी। इसे वापस लेने के लिए अपना खाता हटाएँ।';

  @override
  String get privacyConsentLocation => 'लेन-देन पर स्थान';

  @override
  String get privacyConsentLocationBody =>
      'आपको लेन-देन के साथ जगह का नाम सहेजने देता है, जैसे वह दुकान जहाँ आपने भुगतान किया। बंद होने पर आप स्थान नहीं जोड़ सकते।';

  @override
  String get privacyConsentPush => 'पुश सूचनाएँ';

  @override
  String get privacyConsentPushBody =>
      'दर्ज करता है कि क्या Montra आपके डिवाइस पर अलर्ट भेज सकता है। ऐप के इस संस्करण में पुश अलर्ट सेट नहीं हैं; आप सब कुछ सूचना केंद्र में देखते हैं।';

  @override
  String get privacyConsentMarketing => 'ईमेल से उत्पाद समाचार';

  @override
  String get privacyConsentMarketingBody =>
      'नई सुविधाओं के बारे में कभी-कभी ईमेल। Montra आज ये नहीं भेजता; यह आपकी पसंद दर्ज करता है। खाते और सुरक्षा के ईमेल हमेशा भेजे जाते हैं।';

  @override
  String get privacyConsentAnalytics => 'उत्पाद विश्लेषण';

  @override
  String get privacyConsentAnalyticsBody =>
      'सुविधाओं के उपयोग के कुल आँकड़ों की अनुमति देता है। Montra आज ऐसा कुछ नहीं जुटाता और इस ऐप में कोई विश्लेषण टूल नहीं है; यह आपकी पसंद दर्ज करता है।';

  @override
  String get privacyConsentContacts => 'अपने संपर्कों द्वारा खोजे जाएँ';

  @override
  String get privacyConsentContactsBody =>
      'जिनके पास पहले से आपका संपर्क है, उन्हें आपको ढूँढने देता है। Montra में आज संपर्क मिलान नहीं है; यूज़रनेम से खोजा जाना दोस्त में एक अलग सेटिंग है।';

  @override
  String get privacyConsentAi => 'AI सुविधाएँ';

  @override
  String get privacyConsentAiBody =>
      'इस ऐप में कोई AI सुविधा नहीं है। आपने यह सहमति किसी और Montra ऐप में दी थी; इसे वापस लेने से AI हर जगह बंद हो जाता है।';

  @override
  String get privacyConsentAiReceipts => 'रसीदों को AI से पढ़ना';

  @override
  String get privacyConsentAiReceiptsBody =>
      'यह ऐप रसीदें कभी अपने-आप नहीं पढ़ता। वापस लेने पर रसीदें हर जगह हाथ से ही भरी जाएँगी।';

  @override
  String get privacyConsentOther => 'अन्य सहमति';

  @override
  String get privacyConsentGiven => 'सहमति दी गई।';

  @override
  String get privacyConsentWithdrawn => 'सहमति वापस ली गई।';

  @override
  String get privacyConsentVersionMissing =>
      'मौजूदा शब्दावली लोड नहीं हो सकी। रीफ़्रेश करने के लिए नीचे खींचें, फिर से कोशिश करें।';

  @override
  String get privacyRequiredConsentError =>
      'Montra इस्तेमाल करने के लिए शर्तों और निजता की सहमति ज़रूरी है। इन्हें वापस लेने के लिए अपना खाता हटाएँ।';

  @override
  String get privacyExportTitle => 'आपके डेटा की कॉपी';

  @override
  String get privacyExportIntro =>
      'Montra आपके बारे में जो कुछ रखता है, उसे एक ZIP फ़ाइल में पाएँ। यह पीछे बनती है; तैयार होने पर यहाँ डाउनलोड करें, फिर शेयर करें या डिवाइस पर सहेजें।';

  @override
  String get privacyExportRequest => 'कॉपी माँगें';

  @override
  String get privacyExportRequested =>
      'आपकी कॉपी बन रही है। यह पेज अपने-आप अपडेट होता है।';

  @override
  String get privacyExportNone => 'आपने अभी तक कोई कॉपी नहीं माँगी है।';

  @override
  String get privacyExportStillWorking =>
      'अभी बन रही है। फिर से जाँचने के लिए नीचे खींचें।';

  @override
  String privacyExportRequestedOn(String date) {
    return '$date को माँगी गई';
  }

  @override
  String get privacyExportQueued => 'शुरू होने की प्रतीक्षा';

  @override
  String get privacyExportRunning => 'बन रही है';

  @override
  String get privacyExportReady => 'डाउनलोड के लिए तैयार';

  @override
  String get privacyExportFailed => 'नहीं बन सकी';

  @override
  String get privacyExportExpired => 'समय समाप्त';

  @override
  String privacyExportExpires(String date) {
    return '$date तक उपलब्ध';
  }

  @override
  String get privacyExportFailedHelp =>
      'बनाते समय कुछ गड़बड़ हुई। नई कॉपी माँगें।';

  @override
  String get privacyExportExpiredHelp =>
      'इसकी डाउनलोड अवधि खत्म हो गई और फ़ाइल हटा दी गई। नई कॉपी माँगें।';

  @override
  String get privacyExportDownload => 'अपना डेटा डाउनलोड करें';

  @override
  String get privacyExportReadyTitle => 'आपका डेटा तैयार है';

  @override
  String get privacyAccountTitle => 'आपका खाता';

  @override
  String get privacyLimitsSubtitle => 'उचित-उपयोग सीमाएँ और आपका स्टोरेज';

  @override
  String get privacyDeactivateSubtitle =>
      'विराम लें; वापस आने के लिए फिर से साइन इन करें';

  @override
  String get privacyDeletionSubtitle => 'अपना खाता और डेटा हमेशा के लिए हटाएँ';

  @override
  String get privacyDeletionScheduledSubtitle =>
      'तारीख़ देखें या इसे रद्द करें';

  @override
  String get deactivateTitle => 'अभी के लिए खाता बंद करें';

  @override
  String get deactivateIntro => 'खाता बंद करना एक विराम है, हटाना नहीं।';

  @override
  String get deactivatePointSignedOut => 'आप हर डिवाइस से साइन आउट हो जाएँगे।';

  @override
  String get deactivatePointKept =>
      'आपके रिकॉर्ड जैसे हैं वैसे रहेंगे; कुछ नहीं हटाया जाएगा।';

  @override
  String get deactivatePointHidden =>
      'बंद रहने तक दूसरे आपको ढूँढ या अनुरोध नहीं भेज सकते।';

  @override
  String get deactivatePointReturn => 'वापस आने के लिए बस फिर से साइन इन करें।';

  @override
  String get deactivateAction => 'मेरा खाता बंद करें';

  @override
  String get deactivateConfirmTitle => 'अपना खाता बंद करें?';

  @override
  String get deactivateConfirmBody =>
      'आप हर जगह से साइन आउट हो जाएँगे। जब भी वापस आना चाहें, फिर से साइन इन करें।';

  @override
  String get deletionTitle => 'अपना खाता हटाएँ';

  @override
  String get deletionIntro =>
      'थोड़ी प्रतीक्षा अवधि के बाद खाता हटाना स्थायी है। तब तक आप इसे रद्द कर सकते हैं।';

  @override
  String get deletionWhatHappens => 'क्या होगा';

  @override
  String get deletionWhatIsKept => 'क्या रखा जाएगा, और क्यों';

  @override
  String get deletionGroupsTitle => 'आपके समूह';

  @override
  String get deletionConsequenceSignedOut =>
      'आप हर डिवाइस से साइन आउट होंगे और जुड़ी सेवाएँ अलग कर दी जाएँगी।';

  @override
  String get deletionConsequenceRecords =>
      'आपके खाते, लेन-देन, बजट, लक्ष्य, सब्सक्रिप्शन, रसीदें, इंपोर्ट और रिपोर्ट हमेशा के लिए हटा दिए जाएँगे।';

  @override
  String get deletionConsequenceDocuments =>
      'आपकी अपलोड की गई फ़ाइलें स्टोरेज से हटा दी जाएँगी।';

  @override
  String get deletionConsequenceProfile =>
      'आपकी प्रोफ़ाइल हटा दी जाएगी; आपकी कम्युनिटी पोस्ट और टिप्पणियों पर अब आपका नाम नहीं दिखेगा।';

  @override
  String get deletionConsequenceIrreversible =>
      'तय तारीख़ के बाद इसे वापस नहीं किया जा सकता।';

  @override
  String get deletionRetainedGroupRecords =>
      'साझा समूह खर्च और भुगतान आपके नाम के बिना रहेंगे, ताकि दूसरे सदस्यों का हिसाब सही रहे।';

  @override
  String get deletionRetainedAudit =>
      'सुरक्षा रिकॉर्ड कानून के अनुसार सीमित समय तक रखे जाते हैं।';

  @override
  String deletionGroupTransfer(String group) {
    return '$group: स्वामित्व सबसे पुराने एडमिन या सदस्य को मिलेगा।';
  }

  @override
  String deletionGroupDeleted(String group) {
    return '$group: इसमें कोई और सदस्य नहीं है, इसलिए इसे हटा दिया जाएगा।';
  }

  @override
  String get deletionExportFirst =>
      'शायद आप पहले अपने डेटा की कॉपी चाहें: इसे निजता और डेटा स्क्रीन पर माँगें।';

  @override
  String get deletionReasonLabel => 'आप क्यों जा रहे हैं? (वैकल्पिक)';

  @override
  String get deletionReasonHelp =>
      'इससे हमें सुधार करने में मदद मिलती है। निजी जानकारी न लिखें।';

  @override
  String deletionConfirmLabel(String word) {
    return 'पुष्टि के लिए $word लिखें';
  }

  @override
  String deletionConfirmMismatch(String word) {
    return 'पुष्टि के लिए ठीक $word लिखें।';
  }

  @override
  String get deletionAction => 'मेरा खाता हटाएँ';

  @override
  String get deletionScheduledDone =>
      'हटाना तय हो गया। दिखाई गई तारीख़ तक आप इसे रद्द कर सकते हैं।';

  @override
  String get deletionScheduledTitle => 'खाता हटाना तय है';

  @override
  String deletionScheduledFor(String date) {
    return 'आपका खाता $date को हटा दिया जाएगा। तब तक आप रद्द कर सकते हैं।';
  }

  @override
  String get deletionScheduledNoDate =>
      'आपका खाता हटाया जाना तय है। आप अभी भी रद्द कर सकते हैं।';

  @override
  String get deletionCancelAction => 'मेरा खाता रखें';

  @override
  String get deletionCancelledDone => 'हटाना रद्द हुआ। आपका खाता बना रहेगा।';

  @override
  String get limitsFairUseNote =>
      'हर सुविधा सबके लिए मुफ़्त है। ये सीमाएँ सबके लिए एक जैसी हैं और Montra को तेज़ और सस्ता चलाने में मदद करती हैं।';

  @override
  String limitsStoragePercent(int percent) {
    return '$percent प्रतिशत उपयोग हुआ';
  }

  @override
  String limitsUploadSize(String size) {
    return 'एक बार में सबसे बड़ी अपलोड: $size';
  }

  @override
  String get limitsOpenRecordsTitle => 'आप कितने खुले रिकॉर्ड रख सकते हैं';

  @override
  String get limitsOpenBillsLabel => 'खुले बिल';

  @override
  String get limitsOpenRecurringLabel => 'आवर्ती भुगतान';

  @override
  String get limitsOpenSubscriptionsLabel => 'सब्सक्रिप्शन';

  @override
  String get limitsOpenGoalsLabel => 'लक्ष्य';

  @override
  String get limitsOpenRecordsHelp =>
      'खत्म, संग्रहीत और हटाए गए नहीं गिने जाते।';

  @override
  String get limitsOtherTitle => 'इंपोर्ट, सहायता और डाउनलोड';

  @override
  String get limitsImportRowsLabel => 'हर स्टेटमेंट इंपोर्ट में पंक्तियाँ';

  @override
  String get limitsSupportPerDayLabel => 'प्रति दिन सहायता अनुरोध';

  @override
  String get limitsExportDaysLabel =>
      'रिपोर्ट और डेटा कॉपी डाउनलोड के लिए उपलब्ध रहती हैं';

  @override
  String get limitsDeletionGraceLabel => 'हटाने से पहले प्रतीक्षा अवधि';

  @override
  String limitsDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count दिन',
      one: '1 दिन',
    );
    return '$_temp0';
  }

  @override
  String get limitsRatesTitle => 'प्रति मिनट अनुरोध';

  @override
  String get limitsRatesHelp =>
      'इनसे थोड़ा ऊपर कुछ देर ठीक है। सीमा पार होने पर ऐप बताता है कि फिर कब कोशिश करें।';

  @override
  String limitsPerMinute(String count) {
    return '$count प्रति मिनट';
  }

  @override
  String get limitsPolicyDefault => 'पढ़ना';

  @override
  String get limitsPolicyAuth => 'साइन इन';

  @override
  String get limitsPolicyWrite => 'बदलाव सहेजना';

  @override
  String get limitsPolicyUpload => 'अपलोड';

  @override
  String get limitsPolicyAi => 'AI';

  @override
  String get limitsPolicyExport => 'एक्सपोर्ट';

  @override
  String get limitsPolicySocial => 'दोस्त और कम्युनिटी';

  @override
  String get limitsPolicyOther => 'अन्य';

  @override
  String get notifViewInbox => 'इनबॉक्स';

  @override
  String get notifViewUnread => 'बिना पढ़ी';

  @override
  String get notifViewArchive => 'संग्रह';

  @override
  String get notifCategoryFilter => 'इनके बारे में सूचनाएँ दिखाएँ';

  @override
  String get notifCategoryAll => 'सभी विषय';

  @override
  String get notifReadAll => 'सभी को पढ़ा हुआ मानें';

  @override
  String notifReadAllDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count सूचनाएँ पढ़ी हुई मानी गईं।',
      one: '1 सूचना पढ़ी हुई मानी गई।',
      zero: 'कुछ भी बिना पढ़ा नहीं था।',
    );
    return '$_temp0';
  }

  @override
  String get notifSettingsTitle => 'सूचना सेटिंग';

  @override
  String get notifActions => 'और विकल्प';

  @override
  String get notifMarkRead => 'पढ़ा हुआ मानें';

  @override
  String get notifMarkUnread => 'बिना पढ़ा मानें';

  @override
  String get notifArchive => 'संग्रह में रखें';

  @override
  String get notifMoveToInbox => 'वापस इनबॉक्स में रखें';

  @override
  String get notifMarkedRead => 'पढ़ा हुआ माना गया।';

  @override
  String get notifMarkedUnread => 'बिना पढ़ा माना गया।';

  @override
  String get notifArchived => 'संग्रह में रखा गया।';

  @override
  String get notifMovedToInbox => 'वापस इनबॉक्स में रखा गया।';

  @override
  String get notifNothingToOpen => 'इस सूचना में खोलने के लिए और कुछ नहीं है।';

  @override
  String get notifUnreadLabel => 'बिना पढ़ी';

  @override
  String get notifEmptyTitle => 'कोई सूचना नहीं';

  @override
  String get notifEmptyUnreadTitle => 'आपने सब देख लिया है';

  @override
  String get notifEmptyArchiveTitle => 'संग्रह में कुछ नहीं है';

  @override
  String get notifEmptyBody =>
      'आपके पैसे, समूहों और खाते से जुड़े रिमाइंडर और अपडेट यहाँ दिखते हैं।';

  @override
  String get notifPriorityHigh => 'ज़रूरी';

  @override
  String get notifPriorityCritical => 'तुरंत ध्यान दें';

  @override
  String get notifCategoryBudget => 'बजट';

  @override
  String get notifCategoryBill => 'बिल';

  @override
  String get notifCategorySubscription => 'सब्सक्रिप्शन';

  @override
  String get notifCategoryRecurring => 'नियमित भुगतान';

  @override
  String get notifCategoryGoal => 'लक्ष्य';

  @override
  String get notifCategoryGroup => 'समूह';

  @override
  String get notifCategorySettlement => 'हिसाब चुकता';

  @override
  String get notifCategoryTrip => 'यात्राएँ';

  @override
  String get notifCategoryCommunity => 'समुदाय';

  @override
  String get notifCategoryChallenge => 'चुनौतियाँ';

  @override
  String get notifCategorySecurity => 'सुरक्षा';

  @override
  String get notifCategoryImport => 'स्टेटमेंट इम्पोर्ट';

  @override
  String get notifCategoryReceipt => 'रसीदें';

  @override
  String get notifCategoryExport => 'डेटा एक्सपोर्ट';

  @override
  String get notifCategoryAccount => 'आपका अकाउंट';

  @override
  String get notifCategoryInsight => 'इनसाइट';

  @override
  String get notifCategorySystem => 'Montra की जानकारी';

  @override
  String get notifCategorySocial => 'दोस्त';

  @override
  String get notifChannelInApp => 'ऐप में';

  @override
  String get notifChannelEmail => 'ईमेल';

  @override
  String get notifChannelPush => 'फ़ोन सूचनाएँ';

  @override
  String get notifChannelWebPush => 'ब्राउज़र सूचनाएँ';

  @override
  String get notifDigestFollowAccount => 'आपकी ईमेल सारांश सेटिंग जैसा';

  @override
  String get notifDigestDaily => 'रोज़ का सारांश';

  @override
  String get notifDigestWeekly => 'हफ़्ते का सारांश (सोमवार)';

  @override
  String get notifDigestOff => 'बंद: हर ईमेल तुरंत भेजें';

  @override
  String get notifPushTitle => 'फ़ोन सूचनाएँ सेट नहीं हैं';

  @override
  String get notifPushNotConfigured =>
      'ऐप का यह संस्करण पुश सूचनाएँ नहीं पाता। नीचे आप जो भी चालू करेंगे, वह ऐप के सूचना केंद्र में दिखेगा, और जहाँ आप ईमेल चुनें वहाँ ईमेल से भी आएगा।';

  @override
  String get notifPushChannelNote => 'ऐप के इस संस्करण में सेट नहीं है';

  @override
  String get notifWebPushChannelNote => 'ब्राउज़र में Montra वेबसाइट के लिए';

  @override
  String get notifAlwaysOn => 'हमेशा चालू';

  @override
  String get notifAlwaysOnNote =>
      'सुरक्षा और अकाउंट की सूचनाएँ हमेशा ऐप में और ईमेल से आती हैं, ताकि कोई साइन-इन या अकाउंट बदलाव आपसे न छूटे।';

  @override
  String get notifAlwaysOnError =>
      'सुरक्षा और अकाउंट की सूचनाएँ बंद नहीं की जा सकतीं।';

  @override
  String get notifEmailTiming => 'ईमेल कब आएँ';

  @override
  String notifEmailTimingFor(String category) {
    return '$category के बारे में ईमेल';
  }

  @override
  String get notifSettingsSaved => 'सहेजा गया।';

  @override
  String get notifEmailAndQuietTitle => 'ईमेल सारांश और शांत समय';

  @override
  String get notifAccountDigestTitle => 'ईमेल सारांश';

  @override
  String get notifAccountDigestHelp =>
      'वैकल्पिक ईमेल आपके समय के अनुसार सुबह 08:00 बजे एक ईमेल में इकट्ठे भेजे जा सकते हैं (साप्ताहिक हो तो सोमवार को)। सुरक्षा, अकाउंट और ज़रूरी ईमेल हमेशा तुरंत आते हैं।';

  @override
  String get notifQuietHoursTitle => 'शांत समय';

  @override
  String get notifQuietHoursHelp =>
      'शांत समय में ईमेल और दूसरे अलर्ट शांत समय ख़त्म होने तक रुकते हैं। सुरक्षा और ज़रूरी सूचनाएँ फिर भी आती हैं। ऐप का सूचना केंद्र हमेशा की तरह अपडेट होता है।';

  @override
  String get notifQuietHoursFrom => 'शुरू होने का समय';

  @override
  String get notifQuietHoursTo => 'ख़त्म होने का समय';

  @override
  String notifQuietHoursZone(String zone) {
    return 'समय आपके टाइम ज़ोन ($zone) के अनुसार है।';
  }

  @override
  String get notifGroupOverridesTitle => 'समूह सेटिंग';

  @override
  String get notifGroupOverridesHelp =>
      'इन समूहों की कुछ विषयों के लिए अपनी अलग सेटिंग है।';

  @override
  String get notifGroupUnknown => 'एक समूह';

  @override
  String get integrationsTitle => 'बैंक कनेक्शन';

  @override
  String get integrationIntro =>
      'Montra बिना कनेक्शन के भी पूरी तरह काम करता है: लेन-देन खुद जोड़ें या स्टेटमेंट इम्पोर्ट करें। बैंक या प्रदाता के यहाँ आपकी मंज़ूरी के बाद कनेक्शन आपके बैंक से लेन-देन ला सकता है; Montra कभी आपका बैंक पासवर्ड नहीं माँगता।';

  @override
  String get integrationConnectionsTitle => 'आपके कनेक्शन';

  @override
  String get integrationNoConnections => 'आपका कोई कनेक्शन नहीं है।';

  @override
  String get integrationProvidersTitle => 'प्रदाता';

  @override
  String get integrationNoProviders => 'कोई प्रदाता सूचीबद्ध नहीं है।';

  @override
  String get integrationCallbackNote =>
      'प्रदाता के यहाँ मंज़ूरी देने के बाद वह आपको Montra वेबसाइट पर वापस भेजता है, जो कनेक्शन पूरा करती है। फिर यहाँ लौटें और रीफ़्रेश करने के लिए नीचे खींचें।';

  @override
  String get integrationStatusAvailable => 'उपलब्ध';

  @override
  String get integrationStatusNotConfigured => 'सेट नहीं है';

  @override
  String get integrationStatusUnavailable => 'अभी उपलब्ध नहीं';

  @override
  String get integrationNotConfiguredHelp =>
      'यह प्रदाता इस Montra सर्वर पर सेट नहीं है, इसलिए इससे जुड़ा नहीं जा सकता।';

  @override
  String get integrationUnavailableHelp =>
      'इस प्रदाता से अभी जुड़ा नहीं जा सकता।';

  @override
  String integrationReason(String reason) {
    return 'Montra से जानकारी: $reason';
  }

  @override
  String get integrationKindBankData => 'बैंक डेटा';

  @override
  String get integrationKindAccountAggregator => 'अकाउंट एग्रीगेटर';

  @override
  String get integrationKindCard => 'कार्ड';

  @override
  String get integrationKindPayments => 'भुगतान';

  @override
  String get integrationKindOther => 'अन्य प्रदाता';

  @override
  String integrationCountries(String countries) {
    return 'देश: $countries';
  }

  @override
  String integrationCapabilities(String items) {
    return 'क्या लाता है: $items';
  }

  @override
  String get integrationScopeTransactions => 'लेन-देन';

  @override
  String get integrationScopeBalances => 'बैलेंस';

  @override
  String get integrationScopeAccounts => 'खाते';

  @override
  String get integrationScopeStatements => 'स्टेटमेंट';

  @override
  String get integrationConnect => 'जोड़ें';

  @override
  String get integrationChooseAccount => 'जोड़ने के लिए खाता';

  @override
  String integrationConsentTitle(String provider) {
    return '$provider जोड़ें?';
  }

  @override
  String get integrationConsentPurpose => 'Montra क्यों पूछता है:';

  @override
  String integrationConsentScope(String items) {
    return 'Montra क्या पढ़ सकता है: $items';
  }

  @override
  String integrationConsentDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'पहुँच $days दिन तक रहती है; आप कभी भी डिस्कनेक्ट कर सकते हैं।',
      one: 'पहुँच 1 दिन तक रहती है; आप कभी भी डिस्कनेक्ट कर सकते हैं।',
    );
    return '$_temp0';
  }

  @override
  String get integrationNoCredentials =>
      'आप मंज़ूरी प्रदाता के यहाँ देते हैं। Montra कभी आपका बैंक पासवर्ड या PIN नहीं माँगता।';

  @override
  String get integrationConsentCheck =>
      'मैं यह डेटा Montra के साथ साझा करने के लिए सहमत हूँ';

  @override
  String get integrationContinueTitle => 'प्रदाता के यहाँ जारी रखें';

  @override
  String integrationContinueBody(String provider) {
    return '$provider आपके ब्राउज़र में खुला है। वहाँ मंज़ूरी दें। आपको Montra वेबसाइट पर वापस भेजा जाएगा, जो कनेक्शन पूरा करेगी; फिर कनेक्शन देखने के लिए यहाँ नीचे खींचें।';
  }

  @override
  String get integrationOpenFailedTitle => 'प्रदाता नहीं खुल सका';

  @override
  String get integrationOpenFailedBody =>
      'आपका ब्राउज़र नहीं खुल सका। फिर से कोशिश करें, या Montra वेबसाइट से जोड़ें।';

  @override
  String get integrationNeverSynced => 'अभी सिंक नहीं हुआ';

  @override
  String integrationLastSync(String when) {
    return 'आख़िरी सिंक $when';
  }

  @override
  String get integrationLastSyncLabel => 'आख़िरी सिंक';

  @override
  String get integrationConnectionTitle => 'कनेक्शन';

  @override
  String get integrationConnPending => 'मंज़ूरी का इंतज़ार';

  @override
  String get integrationConnConnected => 'जुड़ा हुआ';

  @override
  String get integrationConnSyncing => 'सिंक हो रहा है';

  @override
  String get integrationConnPartial => 'आंशिक रूप से सिंक';

  @override
  String get integrationConnFailed => 'सिंक नहीं हो सका';

  @override
  String get integrationConnConsentExpired => 'सहमति की अवधि ख़त्म';

  @override
  String get integrationConnDisconnected => 'डिस्कनेक्ट';

  @override
  String get integrationConnRevoked => 'पहुँच हटाई गई';

  @override
  String get integrationScopeLabel => 'साझा डेटा';

  @override
  String get integrationConsentGranted => 'सहमति दी गई';

  @override
  String get integrationConsentExpires => 'सहमति ख़त्म होगी';

  @override
  String get integrationLinkedAccount => 'खाता';

  @override
  String get integrationOpenAccount => 'खाता खोलें';

  @override
  String get integrationLastProblem => 'आख़िरी समस्या';

  @override
  String get integrationSyncNow => 'अभी सिंक करें';

  @override
  String get integrationSyncStarted =>
      'सिंक शुरू हो गया। प्रगति देखने के लिए नीचे खींचें।';

  @override
  String get integrationSyncRunning =>
      'एक सिंक पहले से चल रहा है। उसके ख़त्म होने पर फिर से कोशिश करें।';

  @override
  String get integrationDisconnect => 'डिस्कनेक्ट करें';

  @override
  String get integrationDisconnectTitle => 'डिस्कनेक्ट करें?';

  @override
  String get integrationDisconnectBody =>
      'Montra इस प्रदाता से पढ़ना बंद कर देगा और जुड़ने के लिए रखी जानकारी मिटा देगा। जो लेन-देन आए थे वे बने रहेंगे, जब तक आप नीचे न चुनें।';

  @override
  String get integrationDeleteData => 'जो लेन-देन आए थे उन्हें भी हटाएँ';

  @override
  String get integrationDeleteDataHelp =>
      'उन्हें रद्द किया जाएगा, इसलिए बैलेंस और रिपोर्ट में वे नहीं गिने जाएँगे।';

  @override
  String get integrationDisconnected => 'डिस्कनेक्ट हो गया।';

  @override
  String integrationDisconnectedVoided(int voided) {
    String _temp0 = intl.Intl.pluralLogic(
      voided,
      locale: localeName,
      other: 'डिस्कनेक्ट हो गया। $voided लेन-देन हटाए गए।',
      one: 'डिस्कनेक्ट हो गया। 1 लेन-देन हटाया गया।',
      zero: 'डिस्कनेक्ट हो गया। कोई लेन-देन हटाना नहीं पड़ा।',
    );
    return '$_temp0';
  }

  @override
  String get integrationRunsTitle => 'हाल के सिंक';

  @override
  String get integrationNoRuns => 'अभी कोई सिंक नहीं।';

  @override
  String get integrationRunQueued => 'इंतज़ार में';

  @override
  String get integrationRunRunning => 'चल रहा है';

  @override
  String get integrationRunSucceeded => 'पूरा हुआ';

  @override
  String get integrationRunPartial => 'आंशिक रूप से पूरा';

  @override
  String get integrationRunFailed => 'नहीं हो सका';

  @override
  String get integrationTriggerManual => 'आपने शुरू किया';

  @override
  String get integrationTriggerScheduled => 'तय समय पर';

  @override
  String get integrationTriggerWebhook => 'प्रदाता ने भेजा';

  @override
  String get integrationTriggerBackfill => 'पहला इम्पोर्ट';

  @override
  String integrationRunCounts(
    int fetched,
    int created,
    int updated,
    int skipped,
  ) {
    return 'लाए गए $fetched · जोड़े गए $created · अपडेट $updated · छोड़े गए $skipped';
  }

  @override
  String get integrationConsentExpired =>
      'इस कनेक्शन के लिए आपकी सहमति की अवधि ख़त्म हो गई। इसे नया करने के लिए फिर से जोड़ें।';

  @override
  String get integrationReconnectRequired => 'सिंक करने से पहले फिर से जोड़ें।';

  @override
  String get integrationLinkedNotReversible =>
      'जुड़े हुए लेन-देन प्रदाता से नहीं बदलते।';

  @override
  String get integrationErrorProviderUnavailable =>
      'प्रदाता ने जवाब नहीं दिया। बाद में फिर से कोशिश करें।';

  @override
  String integrationErrorCode(String code) {
    return 'समस्या कोड: $code';
  }

  @override
  String get searchFieldLabel => 'अपने पैसे, समूह और पोस्ट खोजें';

  @override
  String get searchFieldHelp =>
      'कम से कम 2 अक्षर लिखें। हाल की खोजों में रखने के लिए खोज बटन दबाएँ।';

  @override
  String get searchSubmit => 'खोजें';

  @override
  String get searchScopeAll => 'सब कुछ';

  @override
  String get searchSortTitle => 'नतीजे क्रम में लगाएँ';

  @override
  String get searchSortRelevance => 'सबसे अच्छा मेल';

  @override
  String get searchSortName => 'नाम';

  @override
  String get searchSortRecent => 'नए पहले';

  @override
  String searchSortedBy(String sort) {
    return 'क्रम: $sort';
  }

  @override
  String get searchSectionTransactions => 'लेन-देन';

  @override
  String get searchSectionMerchants => 'दुकानें';

  @override
  String get searchSectionAccounts => 'खाते';

  @override
  String get searchSectionCategories => 'श्रेणियाँ';

  @override
  String get searchSectionBudgets => 'बजट';

  @override
  String get searchSectionGoals => 'लक्ष्य';

  @override
  String get searchSectionBills => 'बिल';

  @override
  String get searchSectionSubscriptions => 'सब्सक्रिप्शन';

  @override
  String get searchSectionRecurring => 'नियमित भुगतान';

  @override
  String get searchSectionGroups => 'समूह';

  @override
  String get searchSectionPosts => 'समुदाय की पोस्ट';

  @override
  String get searchSectionPeople => 'लोग';

  @override
  String get searchPeopleNote =>
      'लोग केवल अपने पूरे सटीक यूज़रनेम से मिलते हैं, और केवल तब जब वे इसकी अनुमति दें।';

  @override
  String get searchKindExpense => 'खर्च';

  @override
  String get searchKindIncome => 'आय';

  @override
  String get searchKindTransfer => 'ट्रांसफ़र';

  @override
  String get searchGroupHousehold => 'घर-परिवार';

  @override
  String get searchGroupRoommates => 'रूममेट';

  @override
  String get searchGroupTrip => 'यात्रा';

  @override
  String get searchGroupEvent => 'कार्यक्रम';

  @override
  String get searchGroupFriends => 'दोस्त';

  @override
  String get searchGroupCustom => 'समूह';

  @override
  String get searchShared => 'साझा';

  @override
  String get searchUntitled => 'लेन-देन';

  @override
  String get searchNoResults => 'कुछ नहीं मिला';

  @override
  String get searchNoResultsBody => 'दूसरे शब्द या कोई दूसरा भाग आज़माएँ।';

  @override
  String get searchStartTitle => 'Montra में खोजें';

  @override
  String get searchStartBody =>
      'लेन-देन, दुकानें, खाते, बजट, लक्ष्य, बिल, सब्सक्रिप्शन, समूह और समुदाय की पोस्ट खोजें।';

  @override
  String get searchRecentTitle => 'हाल की खोजें';

  @override
  String get searchClearRecent => 'मिटाएँ';

  @override
  String get searchClearRecentTitle => 'हाल की खोजें मिटाएँ?';

  @override
  String get searchClearRecentBody =>
      'आपका खोज इतिहास Montra से हटा दिया जाएगा।';

  @override
  String get searchRecentCleared => 'हाल की खोजें मिटा दी गईं।';

  @override
  String get insightViewActive => 'देखने लायक';

  @override
  String get insightViewAll => 'सभी, निपटाए गए भी';

  @override
  String get insightKindFilter => 'इनसाइट का प्रकार';

  @override
  String get insightKindAll => 'सभी प्रकार';

  @override
  String get insightKindLabel => 'प्रकार';

  @override
  String get insightKindAnomaly => 'असामान्य गतिविधि';

  @override
  String get insightKindSavings => 'बचत के मौके';

  @override
  String get insightKindSummary => 'सारांश';

  @override
  String get insightKindForecast => 'अनुमान';

  @override
  String get insightKindBudget => 'बजट';

  @override
  String get insightKindSubscription => 'सब्सक्रिप्शन';

  @override
  String get insightKindRecurring => 'नियमित भुगतान';

  @override
  String get insightKindOther => 'अन्य';

  @override
  String get insightMutesTitle => 'म्यूट किए गए इनसाइट';

  @override
  String get insightRulesNote =>
      'इनसाइट आपके अपने रिकॉर्ड पर तय नियमों से बनते हैं; कोई AI इस्तेमाल नहीं होता। ये आपके रिकॉर्ड कभी नहीं बदलते।';

  @override
  String get insightEmptyTitle => 'कुछ भी देखने लायक नहीं';

  @override
  String get insightEmptyBody =>
      'Montra असामान्य गतिविधि और बचत के तरीकों के लिए आपके रिकॉर्ड जाँचता है। नई बातें यहाँ दिखेंगी।';

  @override
  String get insightSeverityWarning => 'ध्यान दें';

  @override
  String get insightSeverityNotice => 'देखने लायक';

  @override
  String get insightSeverityInfo => 'आपकी जानकारी के लिए';

  @override
  String get insightStatusActive => 'खुला';

  @override
  String get insightStatusDismissed => 'हटाया गया';

  @override
  String get insightStatusSnoozed => 'बाद के लिए टाला गया';

  @override
  String get insightStatusExpected => 'अपेक्षित';

  @override
  String get insightStatusResolved => 'सुलझा हुआ';

  @override
  String get insightStatusMuted => 'म्यूट';

  @override
  String get insightDetailTitle => 'इनसाइट';

  @override
  String get insightNotFoundTitle => 'यह इनसाइट उपलब्ध नहीं है';

  @override
  String get insightNotFoundBody =>
      'हो सकता है यह यहाँ दिखाने के लिए बहुत पुराना हो।';

  @override
  String insightSnoozedUntil(String when) {
    return '$when तक टाला गया';
  }

  @override
  String get insightWhyTitle => 'आपको यह क्यों दिख रहा है';

  @override
  String get insightRuleUnknown =>
      'आपके अपने रिकॉर्ड पर लागू एक नियम ने यह पाया।';

  @override
  String get insightPeriod => 'अवधि';

  @override
  String get insightOpenTransaction => 'लेन-देन खोलें';

  @override
  String get insightOpenBudget => 'बजट खोलें';

  @override
  String get insightOpenSubscription => 'सब्सक्रिप्शन खोलें';

  @override
  String get insightOpenRecurring => 'नियमित भुगतान खोलें';

  @override
  String get insightOpenMerchant => 'दुकान खोलें';

  @override
  String get insightOpenCategory => 'इस श्रेणी के लेन-देन देखें';

  @override
  String get insightOpenAccount => 'खाता खोलें';

  @override
  String get insightActionsTitle => 'आप क्या करना चाहते हैं?';

  @override
  String get insightActionsHelp =>
      'ये केवल इस इनसाइट को बदलते हैं, आपके रिकॉर्ड को कभी नहीं।';

  @override
  String get insightActionExpected => 'यह अपेक्षित था';

  @override
  String get insightActionResolved => 'मैंने इसे निपटा दिया';

  @override
  String get insightActionSnooze => 'बाद में याद दिलाएँ';

  @override
  String get insightActionDismiss => 'हटाएँ';

  @override
  String get insightActionMute => 'इस प्रकार के इनसाइट न दिखाएँ';

  @override
  String get insightActionReopen => 'फिर से खोलें';

  @override
  String get insightSnoozeTitle => 'इतने समय बाद याद दिलाएँ';

  @override
  String insightSnoozeDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days दिन',
      one: '1 दिन',
    );
    return '$_temp0';
  }

  @override
  String insightSnoozed(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days दिन के लिए टाला गया।',
      one: '1 दिन के लिए टाला गया।',
    );
    return '$_temp0';
  }

  @override
  String get insightDismissed => 'हटा दिया गया।';

  @override
  String get insightMarkedExpected => 'अपेक्षित माना गया।';

  @override
  String get insightMarkedResolved => 'सुलझा हुआ माना गया।';

  @override
  String get insightMuted =>
      'म्यूट किया गया। आप इसे म्यूट किए गए इनसाइट में फिर चालू कर सकते हैं।';

  @override
  String get insightReopened => 'फिर से खोला गया।';

  @override
  String get insightSaved => 'सहेजा गया।';

  @override
  String get insightMute => 'म्यूट करें';

  @override
  String get insightMuteTitle => 'इस प्रकार के इनसाइट दिखाना बंद करें?';

  @override
  String insightMuteBody(String kind) {
    return 'Montra इस बारे में \"$kind\" इनसाइट दिखाना बंद कर देगा। आप इन्हें कभी भी म्यूट किए गए इनसाइट में फिर चालू कर सकते हैं।';
  }

  @override
  String get insightFeedbackTitle => 'क्या यह मददगार था?';

  @override
  String insightFeedbackYours(String answer) {
    return 'आपका जवाब: $answer';
  }

  @override
  String get insightFeedbackNote => 'नोट (वैकल्पिक)';

  @override
  String get insightFeedbackNoteHelp =>
      'आपके जवाब के साथ भेजा जाएगा। पहले भेजा नोट हटाने के लिए इसे ख़ाली छोड़ें। कार्ड नंबर या पासवर्ड न लिखें।';

  @override
  String get insightFeedbackHelpful => 'मददगार';

  @override
  String get insightFeedbackNotHelpful => 'मददगार नहीं';

  @override
  String get insightFeedbackIncorrect => 'सही नहीं';

  @override
  String get insightFeedbackExpected => 'अपेक्षित';

  @override
  String get insightFeedbackSaved => 'धन्यवाद, आपका जवाब सहेजा गया।';

  @override
  String get insightMutesHelp =>
      'म्यूट किए गए प्रकार के इनसाइट नहीं दिखते। म्यूट हटाने पर छिपे हुए इनसाइट वापस आ जाते हैं।';

  @override
  String get insightMutesEmptyTitle => 'कुछ भी म्यूट नहीं है';

  @override
  String get insightMutesEmptyBody =>
      'जिन प्रकार के इनसाइट को आप म्यूट करेंगे, वे यहाँ दिखेंगे।';

  @override
  String get insightMuteEverywhere => 'हर जगह';

  @override
  String get insightMuteOneRecord => 'एक रिकॉर्ड के लिए';

  @override
  String insightMutedOn(String date) {
    return '$date को म्यूट किया';
  }

  @override
  String get insightUnmute => 'म्यूट हटाएँ';

  @override
  String insightUnmuted(int reopened) {
    String _temp0 = intl.Intl.pluralLogic(
      reopened,
      locale: localeName,
      other: 'म्यूट हटाया गया। $reopened इनसाइट वापस आए।',
      one: 'म्यूट हटाया गया। 1 इनसाइट वापस आया।',
      zero: 'म्यूट हटाया गया।',
    );
    return '$_temp0';
  }

  @override
  String get insightSubtypeUnusualAmount => 'असामान्य रूप से बड़ा खर्च';

  @override
  String get insightSubtypeCategorySpike =>
      'श्रेणी में सामान्य महीने से ज़्यादा';

  @override
  String get insightSubtypeNewMerchant => 'किसी दुकान पर बड़ी पहली ख़रीद';

  @override
  String get insightSubtypeDuplicate => 'संभावित दोहराव';

  @override
  String get insightSubtypePriceIncrease => 'सब्सक्रिप्शन की क़ीमत बढ़ी';

  @override
  String get insightSubtypeMissingRecurring => 'नियमित भुगतान दर्ज नहीं हुआ';

  @override
  String get insightSubtypeCashFlow => 'महीने के नकद प्रवाह में बदलाव';

  @override
  String get insightSubtypeSubscriptionCosts => 'सब्सक्रिप्शन का ख़र्च';

  @override
  String get insightSubtypeFrequency => 'सामान्य से ज़्यादा ख़रीदारी';

  @override
  String get insightSubtypeRecurringChange => 'नियमित राशि बदली';

  @override
  String get insightSubtypeOverspend => 'बजट अक्सर पार हुआ';

  @override
  String get insightRuleUnusualAmount =>
      'राशि पिछले 6 महीनों में इस श्रेणी की आपकी सामान्य (मध्य) राशि से कम से कम 3 गुना है, और उन 95% लेन-देन से ज़्यादा है।';

  @override
  String get insightRuleCategorySpike =>
      'इस महीने अब तक इस श्रेणी में आपका खर्च पिछले 3 महीनों के औसत महीने से ज़्यादा है।';

  @override
  String get insightRuleNewMerchant =>
      'यह इस दुकान पर आपका पहला लेन-देन है और आपके सामान्य (मध्य) खर्च का कम से कम दोगुना है।';

  @override
  String get insightRuleDuplicate =>
      'एक ही खाते में 2 दिन के अंदर एक जैसी राशि के दो लेन-देन हैं, एक ही दुकान या विवरण के साथ।';

  @override
  String get insightRulePriceChange =>
      'आपके दर्ज किए एक भुगतान से इस सब्सक्रिप्शन की क़ीमत बदली।';

  @override
  String get insightRuleMissingRecurring =>
      'एक नियमित भुगतान की तारीख़ निकल चुकी है और उससे कोई भुगतान जुड़ा नहीं है।';

  @override
  String get insightRuleCashFlow =>
      'पिछले महीने आपका खर्च उससे पहले के 3 महीनों के औसत से कम से कम 25% ज़्यादा था, या आपकी आय कम से कम 20% कम थी।';

  @override
  String get insightRuleSubscriptionCosts =>
      'आपके चालू सब्सक्रिप्शन, हर एक को उसके बिल की आवृत्ति के हिसाब से महीने के ख़र्च में बदलकर।';

  @override
  String get insightRuleFrequency =>
      'इस दुकान पर 7 दिनों में कम से कम 4 ख़रीदारी, और पिछले 12 हफ़्तों के आपके साप्ताहिक औसत से कम से कम 3 गुना।';

  @override
  String get insightRuleRecurringChange =>
      'आख़िरी भुगतान पिछले अधिकतम 6 भुगतानों की मध्य राशि से कम से कम 10% अलग है।';

  @override
  String get insightRuleOverspend =>
      'पिछली 3 पूरी हो चुकी अवधियों में से कम से कम 2 में आपने सीमा से ज़्यादा खर्च किया।';

  @override
  String get insightAmountAmount => 'राशि';

  @override
  String get insightAmountUsual => 'सामान्य राशि';

  @override
  String get insightAmountP95 => 'आपके ज़्यादातर लेन-देन इससे कम रहते हैं';

  @override
  String get insightAmountTypical => 'आपका सामान्य खर्च';

  @override
  String get insightAmountSoFar => 'इस महीने अब तक';

  @override
  String get insightAmountMonthlyAverage => 'औसत महीना';

  @override
  String get insightAmountOld => 'पिछली क़ीमत';

  @override
  String get insightAmountNew => 'नई क़ीमत';

  @override
  String get insightAmountSpending => 'खर्च';

  @override
  String get insightAmountUsualSpending => 'सामान्य खर्च';

  @override
  String get insightAmountIncome => 'आय';

  @override
  String get insightAmountUsualIncome => 'सामान्य आय';

  @override
  String get insightAmountMonthly => 'हर महीने';

  @override
  String get insightAmountYearly => 'हर साल';

  @override
  String get insightAmountAverageSpent => 'औसत खर्च';

  @override
  String get insightAmountAverageOverspend => 'औसतन कितना ज़्यादा';

  @override
  String get insightAmountLimit => 'सीमा';

  @override
  String insightMsgUnusualAmountTitle(String category) {
    return 'असामान्य रूप से बड़ा $category खर्च';
  }

  @override
  String insightMsgUnusualAmountBody(
    String amount,
    String label,
    String date,
    String ratio,
    String category,
    String median,
    int count,
    int months,
  ) {
    return '$date को $label के लिए $amount आपके सामान्य $category लेन-देन का लगभग $ratio× है (पिछले $months महीनों में $count लेन-देन की मध्य राशि $median)। अगर यह अपेक्षित है, तो ऐसा चिह्नित करें।';
  }

  @override
  String insightMsgCategorySpikeTitle(String category) {
    return '$category में खर्च आपके सामान्य महीने से ज़्यादा है';
  }

  @override
  String insightMsgCategorySpikeBody(
    String soFar,
    String category,
    String average,
    int months,
  ) {
    return 'इस महीने अब तक आपने $category पर $soFar खर्च किए हैं, जो आपके सामान्य $average प्रति माह से ज़्यादा है (पिछले $months महीनों का औसत)।';
  }

  @override
  String insightMsgNewMerchantTitle(String merchant) {
    return '$merchant पर पहली ख़रीद';
  }

  @override
  String insightMsgNewMerchantBody(
    String amount,
    String merchant,
    String date,
    String typical,
  ) {
    return '$date को $merchant पर $amount वहाँ आपका पहला लेन-देन है और आपके सामान्य खर्च ($typical) से बड़ा है। अगर आप इसे पहचानते हैं, तो इसे अपेक्षित चिह्नित करें।';
  }

  @override
  String insightMsgDuplicateTitle(String label) {
    return 'संभावित दोहराव: $label';
  }

  @override
  String insightMsgDuplicateBody(
    String amount,
    String label,
    String first,
    String second,
  ) {
    return 'एक ही खाते में $label के लिए $first और $second को $amount के दो लेन-देन एक जैसे दिखते हैं। अगर कोई दो बार दर्ज हुआ है, तो उसे रद्द करें; Montra उसे आपके लिए कभी नहीं मिटाता।';
  }

  @override
  String insightMsgPriceIncreaseTitle(String name) {
    return '$name महँगा हो गया';
  }

  @override
  String insightMsgPriceIncreaseBody(
    String name,
    String before,
    String after,
    String percent,
    String date,
  ) {
    return '$date को $name की क़ीमत हर बिल पर $before से $after हो गई ($percent ज़्यादा)।';
  }

  @override
  String insightMsgMissingRecurringTitle(String name) {
    return '$name दर्ज नहीं हुआ';
  }

  @override
  String insightMsgMissingRecurringBody(String name, String date) {
    return '$name की तारीख़ $date थी, लेकिन अभी कोई भुगतान जुड़ा नहीं है। इसे दर्ज करें या जोड़ें, या इस बार को छोड़ दें।';
  }

  @override
  String insightMsgMissingRecurringAmountBody(
    String name,
    String amount,
    String date,
  ) {
    return '$name ($amount) की तारीख़ $date थी, लेकिन अभी कोई भुगतान जुड़ा नहीं है। इसे दर्ज करें या जोड़ें, या इस बार को छोड़ दें।';
  }

  @override
  String get insightMsgCashFlowTitle => 'पिछले महीने का नकद प्रवाह बदला';

  @override
  String insightMsgCashFlowSpendingBody(
    String month,
    String spending,
    String usual,
    int months,
  ) {
    return '$month में खर्च $spending रहा, जबकि सामान्य $usual रहता है (उससे पहले के $months महीनों का औसत)।';
  }

  @override
  String insightMsgCashFlowIncomeBody(
    String month,
    String income,
    String usual,
    int months,
  ) {
    return '$month में आय $income रही, जबकि सामान्य $usual रहती है (उससे पहले के $months महीनों का औसत)।';
  }

  @override
  String insightMsgCashFlowBothBody(
    String month,
    String spending,
    String usualSpending,
    String income,
    String usualIncome,
    int months,
  ) {
    return '$month में खर्च $spending रहा (सामान्य $usualSpending), और आय $income रही (सामान्य $usualIncome) (उससे पहले के $months महीनों का औसत)।';
  }

  @override
  String insightMsgSubscriptionCostsTitle(int count, String monthly) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count सब्सक्रिप्शन का ख़र्च लगभग $monthly प्रति माह है',
      one: '1 सब्सक्रिप्शन का ख़र्च लगभग $monthly प्रति माह है',
    );
    return '$_temp0';
  }

  @override
  String insightMsgSubscriptionCostsBody(String yearly) {
    return 'यह लगभग $yearly प्रति वर्ष है। जिसका आप अब इस्तेमाल नहीं करते उसे रद्द करने से केवल आगे के नवीनीकरण रुकते हैं; Montra आपके लिए कुछ भी रद्द नहीं करता।';
  }

  @override
  String insightMsgFrequencyTitle(String merchant) {
    return '$merchant पर सामान्य से ज़्यादा ख़रीदारी';
  }

  @override
  String insightMsgFrequencyBody(
    int count,
    String merchant,
    int days,
    String average,
    int weeks,
  ) {
    return 'आपने पिछले $days दिनों में $merchant पर $count ख़रीदारी कीं, जबकि पिछले $weeks हफ़्तों में यह लगभग $average प्रति हफ़्ता थी। यह आपके लिए असामान्य है, ज़रूरी नहीं कि ग़लत हो; अगर यह अपेक्षित है, तो ऐसा चिह्नित करें।';
  }

  @override
  String insightMsgRecurringHigherTitle(String name) {
    return '$name सामान्य से ज़्यादा था';
  }

  @override
  String insightMsgRecurringLowerTitle(String name) {
    return '$name सामान्य से कम था';
  }

  @override
  String insightMsgRecurringChangeBody(
    String name,
    String amount,
    String date,
    String usual,
    int count,
    String percent,
  ) {
    return '$name का आख़िरी भुगतान ($date को $amount) सामान्य $usual से अलग है (पिछले $count भुगतानों की मध्य राशि), $percent% का बदलाव। अगर राशि हमेशा के लिए बदल गई है, तो नियमित भुगतान अपडेट करें ताकि आपकी योजनाएँ सही रहें।';
  }

  @override
  String insightMsgOverspendTitle(String budget, int over, int periods) {
    return '$budget बजट पिछली $periods अवधियों में से $over में पार हुआ';
  }

  @override
  String insightMsgOverspendBody(
    int periods,
    String average,
    String limit,
    String overspend,
  ) {
    return 'पिछली $periods अवधियों में आपने $limit की सीमा के मुक़ाबले औसतन $average खर्च किए, और सीमा पार होने पर औसतन $overspend ज़्यादा। आप सीमा लगभग $average कर सकते हैं ताकि बजट आपके असली खर्च से मेल खाए, या इसे रखकर देख सकते हैं कि खर्च किस वजह से बढ़ता है। यह केवल पिछली अवधियों पर आधारित है।';
  }

  @override
  String get importErrorTooLarge =>
      'फ़ाइल इंपोर्ट करने के लिए बहुत बड़ी है। स्टेटमेंट को छोटी अवधियों में बाँटें।';

  @override
  String importErrorCurrencyNamed(String statement, String account) {
    return 'स्टेटमेंट $statement में है, लेकिन खाता $account में है। इसे $statement वाले किसी खाते में इंपोर्ट करें।';
  }

  @override
  String get importNotesTitle => 'कॉलम जाँचें';

  @override
  String get importNoteNoHeader =>
      'कोई हेडर पंक्ति नहीं मिली, इसलिए कॉलम को नंबर दिए गए हैं। जाँचें कि किस कॉलम में क्या है।';

  @override
  String importNoteAmbiguousDate(String assumed, String alternative) {
    return 'तारीख़ें दिन-पहले या महीना-पहले हो सकती हैं; $assumed माना गया है। अगर यह गलत है तो $alternative चुनें।';
  }

  @override
  String get importNoteAmbiguousDateGeneric =>
      'तारीख़ें दिन-पहले या महीना-पहले हो सकती हैं। तारीख़ का प्रारूप जाँचें।';

  @override
  String get importNoteUnknownDateFormat =>
      'तारीख़ का प्रारूप पहचाना नहीं गया। इसे कॉलम में चुनें।';

  @override
  String get importNoteDecimalComma =>
      'राशियों में दशमलव के लिए कॉमा है। जाँचें कि वे सही पढ़ी गई हैं।';

  @override
  String get importNoteMappingIncomplete =>
      'कुछ ज़रूरी कॉलम नहीं मिले। उन्हें कॉलम में चुनें।';

  @override
  String get importNoteCheckSign =>
      'जाँचें कि ऋणात्मक राशियाँ जाने वाला पैसा हैं या आने वाला।';

  @override
  String get importNotePdfRead =>
      'यह स्टेटमेंट अपने-आप पढ़ा गया था। इंपोर्ट करने से पहले हर पंक्ति जाँचें।';

  @override
  String importReasonBadDateFormat(String format) {
    return 'तारीख़ $format से मेल नहीं खाती।';
  }

  @override
  String importReasonCurrencyNamed(String currency, String account) {
    return 'यह पंक्ति $currency में है, लेकिन खाता $account में है।';
  }

  @override
  String importReasonBadAmountIn(String currency) {
    return 'राशि $currency में कोई संख्या नहीं है।';
  }

  @override
  String get importReasonAlreadyImportedReference =>
      'इस खाते में पहले ही इंपोर्ट हो चुका है (वही बैंक संदर्भ)।';

  @override
  String get importReasonInvalidDate =>
      'इस तारीख़ का उपयोग नहीं हो सकता (जैसे, यह बहुत आगे की है)। इसे सुधारें।';

  @override
  String get importReasonInvalidAmount =>
      'इस राशि का उपयोग नहीं हो सकता। इसे सुधारें।';

  @override
  String get importReasonInvalidCategory =>
      'इस श्रेणी का उपयोग नहीं हो सकता। कोई दूसरी चुनें।';

  @override
  String get importReasonInvalidDescription =>
      'इस विवरण का उपयोग नहीं हो सकता। इसे सुधारें।';

  @override
  String get importReasonInvalidReference => 'इस संदर्भ का उपयोग नहीं हो सकता।';

  @override
  String get importReasonInvalidRow =>
      'यह पंक्ति जैसी है वैसी इंपोर्ट नहीं हो सकती। इसे सुधारें या छोड़ दें।';

  @override
  String get importReasonRejected => 'Montra यह पंक्ति इंपोर्ट नहीं कर सका।';

  @override
  String get importReasonReconciled => 'खाते के एक लेन-देन से मिलाया गया।';

  @override
  String importReasonPossibleDuplicateWhy(String reasons) {
    return 'खाते में पहले से मौजूद लेन-देन जैसा लगता है: $reasons।';
  }

  @override
  String importConfirmBodyCount(int count, String account) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count पंक्तियाँ $account में जोड़ी जाएँगी।',
      one: '1 पंक्ति $account में जोड़ी जाएगी।',
    );
    return '$_temp0 संभावित डुप्लिकेट और छोड़ी गई पंक्तियाँ नहीं जोड़ी जाएँगी। आप बाद में इंपोर्ट वापस ले सकते हैं।';
  }

  @override
  String importConfirmCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count पंक्तियाँ इंपोर्ट करें',
      one: '1 पंक्ति इंपोर्ट करें',
    );
    return '$_temp0';
  }

  @override
  String get importNothingToImport =>
      'इंपोर्ट के लिए कोई पंक्ति चुनी नहीं गई है। जो पंक्तियाँ चाहिए उन्हें चुनें, या इंपोर्ट रद्द करें।';

  @override
  String get importRowsToImportLabel => 'इंपोर्ट होंगी';

  @override
  String get importFixDate => 'तारीख़ सुधारें';

  @override
  String get importFixAmount => 'राशि सुधारें';

  @override
  String get importFixDescription => 'विवरण सुधारें';

  @override
  String get reconReasonFarApart =>
      'तारीख़ों में एक हफ़्ते से ज़्यादा का अंतर है (हाथ से मिलाया गया)';

  @override
  String reconReasonFarApartDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'तारीख़ों में $days दिन का अंतर है (हाथ से मिलाया गया)',
      one: 'तारीख़ों में 1 दिन का अंतर है (हाथ से मिलाया गया)',
    );
    return '$_temp0';
  }

  @override
  String budgetOwnAlertsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'इस बजट के $count अलर्ट',
      one: 'इस बजट का 1 अलर्ट',
    );
    return '$_temp0';
  }

  @override
  String get lastReconciledBalanceLabel => 'पिछली बार मिलान के समय शेष राशि';

  @override
  String calendarMovedFrom(String date) {
    return '$date से खिसकाया गया';
  }

  @override
  String get analyticsCategoriesSpending => 'खर्च';

  @override
  String get analyticsCategoriesIncome => 'आय';

  @override
  String analyticsNoIncome(String period) {
    return '$period में कोई आय नहीं।';
  }

  @override
  String categoryIncomeSummary(
    String name,
    String amount,
    String share,
    int count,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count श्रेणियाँ दिखाई गईं।',
      one: '1 श्रेणी दिखाई गई।',
    );
    return 'सबसे ज़्यादा आय $name से आई: $amount, कुल का $share। $_temp0';
  }

  @override
  String get analyticsCompareNoteCurrencies =>
      'हर मुद्रा की तुलना अलग से होती है; अलग-अलग मुद्राओं की राशियाँ कभी नहीं जोड़ी जातीं।';

  @override
  String analyticsCompareRowChange(String now, String then, String change) {
    return 'अभी $now · पहले $then · $change';
  }

  @override
  String get analyticsCompareCountLabel => 'लेन-देन';

  @override
  String analyticsCompareCount(int now, int then) {
    return 'अभी $now · पहले $then';
  }

  @override
  String analyticsPreviousWindow(String dates) {
    return '$dates से तुलना, जो ठीक पहले की उतनी ही लंबी अवधि है।';
  }

  @override
  String get reconMatchByHand => 'हाथ से मिलाएँ';

  @override
  String get reconMatchTotal => 'रखी गई राशि';

  @override
  String get reconLineDuplicate => 'डुप्लिकेट जैसा लगा, इंपोर्ट नहीं हुआ';

  @override
  String get reconLineSkipped => 'इंपोर्ट में छोड़ा गया';

  @override
  String get reconLineNotImported => 'इंपोर्ट नहीं हुआ';

  @override
  String get reconLineFailed => 'इंपोर्ट नहीं हो सका';

  @override
  String get reconLineMatched => 'हाथ से मिलाया गया';

  @override
  String get reconLineNoDescription => 'कोई विवरण नहीं';

  @override
  String get reconLinesUnmatched => 'मिलाए नहीं गए';

  @override
  String get reconLinesMatched => 'हाथ से मिलाए गए';

  @override
  String get reconLinesIntro =>
      'ये स्टेटमेंट पंक्तियाँ न इंपोर्ट हुईं, न मिलाई गईं। एक पंक्ति चुनें, फिर Montra के वे लेन-देन जिनसे यह बनी है। उनकी राशियाँ जोड़कर पंक्ति के बराबर होनी चाहिए।';

  @override
  String get reconLinesMatchedIntro =>
      'जो पंक्तियाँ आपने हाथ से मिलाईं। मिलान वापस लेने के लिए किसी पर टैप करें।';

  @override
  String get reconLinesEmpty =>
      'हर स्टेटमेंट पंक्ति इंपोर्ट या मिलाई जा चुकी है।';

  @override
  String get reconLinesMatchedEmpty =>
      'आपने अभी तक कोई पंक्ति हाथ से नहीं मिलाई है।';

  @override
  String get reconChooseTransactionsTitle => 'लेन-देन चुनें';

  @override
  String reconChooseTransactionsIntro(String date, String account) {
    return '$account के बिना मिलाए लेन-देन, जो $date की स्टेटमेंट पंक्ति की दिशा में हैं। एक चुनें, या कई जो जोड़कर उसके बराबर हों।';
  }

  @override
  String get reconStatementLineAmount => 'स्टेटमेंट पंक्ति';

  @override
  String get reconNoUnreconciled =>
      'इस खाते में इस दिशा का कोई बिना मिलाया लेन-देन नहीं है।';

  @override
  String reconMatchChosen(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count लेन-देन मिलाएँ',
      one: '1 लेन-देन मिलाएँ',
      zero: 'लेन-देन चुनें',
    );
    return '$_temp0';
  }

  @override
  String get reportFailedStorageUnavailable =>
      'फ़ाइल स्टोरेज उपलब्ध नहीं था, इसलिए फ़ाइल सहेजी नहीं जा सकी। थोड़ी देर बाद इसे फिर से बनाएँ।';

  @override
  String get reportFailedGeneration =>
      'रिपोर्ट बनाना हर कोशिश में विफल रहा। इसे फिर से बनाएँ, या अवधि छोटी करें।';

  @override
  String reportWindowDays(String dates, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days दिन',
      one: '1 दिन',
    );
    return '$dates ($_temp0)';
  }

  @override
  String get reportCurrentState => 'जब आपने माँगा था, उस समय की स्थिति';

  @override
  String get reportDeleteAction => 'रिपोर्ट हटाएँ';

  @override
  String get reportDeleteTitle => 'यह रिपोर्ट हटाएँ?';

  @override
  String reportDeleteBody(String title) {
    return '\"$title\" और उसकी फ़ाइल हटा दी जाएँगी। जो लिंक आप पहले शेयर कर चुके हैं, वे काम करना बंद कर देंगे।';
  }

  @override
  String reportDeleteBodyRunning(String title) {
    return '\"$title\" अभी बन रही है। इसे बनाना रुक जाएगा और रिपोर्ट हटा दी जाएगी।';
  }

  @override
  String get reportDeleted => 'रिपोर्ट हटा दी गई।';

  @override
  String get scheduleEditTitle => 'शेड्यूल बदलें';

  @override
  String get scheduleNotFound => 'यह शेड्यूल अब मौजूद नहीं है।';

  @override
  String get scheduleNothingChanged =>
      'कुछ नहीं बदला, इसलिए सहेजने को कुछ नहीं था।';

  @override
  String get scheduleSaved => 'शेड्यूल सहेजा गया।';

  @override
  String get scheduleTypeFixed =>
      'रिपोर्ट का प्रकार नहीं बदल सकता। दूसरे प्रकार के लिए नया शेड्यूल बनाएँ।';

  @override
  String get scheduleEditNote =>
      'नया अंतराल अगले हफ़्ते या महीने से शुरू होगा। सामान्य नाम के लिए शीर्षक खाली छोड़ें।';

  @override
  String get schedulePause => 'रोकें';

  @override
  String get schedulePauseHelp =>
      'जब तक आप इसे फिर से शुरू नहीं करते, कोई रिपोर्ट नहीं बनेगी।';

  @override
  String get scheduleResume => 'फिर से शुरू करें';

  @override
  String get scheduleResumeHelp =>
      'अगले हफ़्ते या महीने से फिर शुरू होगा; छूटी अवधियों की रिपोर्ट नहीं बनेगी।';

  @override
  String get schedulePaused => 'शेड्यूल रोका गया।';

  @override
  String get scheduleResumed => 'शेड्यूल फिर से शुरू हुआ।';

  @override
  String scheduleActionsLabel(String title) {
    return '$title के विकल्प';
  }

  @override
  String get friendsTitle => 'दोस्त';

  @override
  String get friendsTabFriends => 'दोस्त';

  @override
  String get friendsTabRequests => 'अनुरोध';

  @override
  String friendsTabRequestsCount(int count) {
    return 'अनुरोध ($count)';
  }

  @override
  String get friendsTabFind => 'किसी को खोजें';

  @override
  String get friendsEmptyTitle => 'अभी कोई दोस्त नहीं';

  @override
  String get friendsEmptyBody =>
      'लोगों को उनके सटीक यूज़रनेम से खोजें और उन्हें दोस्ती का अनुरोध भेजें।';

  @override
  String get friendsBlockedAndMutedTitle => 'ब्लॉक और म्यूट किए गए';

  @override
  String get friendsBlockedTab => 'ब्लॉक किए गए';

  @override
  String get friendsMutedTab => 'म्यूट किए गए';

  @override
  String get friendsBlockedEmptyTitle => 'आपने किसी को ब्लॉक नहीं किया है';

  @override
  String get friendsBlockedHelp =>
      'जिन्हें आप ब्लॉक करते हैं, वे Montra में आपको खोज, जोड़ या देख नहीं सकते, और आप भी उन्हें नहीं देखेंगे। उन्हें इसकी सूचना नहीं दी जाती।';

  @override
  String get friendsMutedEmptyTitle => 'आपने किसी को म्यूट नहीं किया है';

  @override
  String get friendBlockedLabel => 'ब्लॉक किया गया';

  @override
  String get friendMutedLabel => 'म्यूट किया गया';

  @override
  String get friendConnectionSelf => 'यह आप हैं';

  @override
  String get friendConnectionFriend => 'दोस्त';

  @override
  String get friendConnectionRequestSent => 'अनुरोध भेजा गया';

  @override
  String get friendConnectionRequestReceived => 'आपका दोस्त बनना चाहते हैं';

  @override
  String get friendRequestsIncoming => 'मिले हुए';

  @override
  String get friendRequestsOutgoing => 'आपके भेजे हुए';

  @override
  String get friendRequestsEmptyTitle => 'कोई अनुरोध बाकी नहीं';

  @override
  String get friendRequestsEmptyBody =>
      'आपको मिले या आपके भेजे दोस्ती के अनुरोध जवाब मिलने तक यहाँ दिखते हैं।';

  @override
  String friendRequestMessage(String message) {
    return '“$message”';
  }

  @override
  String get friendRequestAccept => 'स्वीकार करें';

  @override
  String get friendRequestDecline => 'अस्वीकार करें';

  @override
  String get friendRequestCancel => 'अनुरोध रद्द करें';

  @override
  String get friendRequestSend => 'दोस्ती का अनुरोध भेजें';

  @override
  String get friendRequestAcceptTheirs => 'उनका अनुरोध स्वीकार करें';

  @override
  String friendRequestSentDone(String name) {
    return '$name को दोस्ती का अनुरोध भेजा गया।';
  }

  @override
  String friendNowFriends(String name) {
    return 'आप और $name अब दोस्त हैं।';
  }

  @override
  String get friendRequestDeclinedDone => 'अनुरोध अस्वीकार किया गया।';

  @override
  String get friendRequestCancelledDone => 'अनुरोध रद्द किया गया।';

  @override
  String get friendFindIntro =>
      'जिस व्यक्ति को आप खोज रहे हैं, उसका पूरा यूज़रनेम लिखें। अधूरे नाम से कोई नहीं मिलता, और केवल वही लोग मिलते हैं जिन्होंने “लोग मुझे यूज़रनेम से खोज सकें” चालू किया है।';

  @override
  String get friendFindLabel => 'यूज़रनेम';

  @override
  String get friendFindHelp => 'उदाहरण: asha_r';

  @override
  String get friendFindTooShort => 'पूरा यूज़रनेम लिखें (कम से कम 3 अक्षर)।';

  @override
  String get friendFindButton => 'खोजें';

  @override
  String friendFindNobody(String username) {
    return '@$username यूज़रनेम वाला कोई नहीं मिला। वर्तनी जाँचें, या उनसे पूछें कि क्या उन्होंने यूज़रनेम से खोजे जाने की अनुमति दी है।';
  }

  @override
  String get friendFindDiscoveryNote =>
      'क्या आप चाहते हैं कि दूसरे आपको खोज सकें? अपनी गोपनीयता सेटिंग में यूज़रनेम रखें और “लोग मुझे यूज़रनेम से खोज सकें” चालू करें।';

  @override
  String get friendMute => 'म्यूट करें';

  @override
  String get friendMuteHelp =>
      'म्यूट किए गए लोग जुड़े रहते हैं, लेकिन उनकी गतिविधियों की सूचनाएँ आपको नहीं मिलेंगी।';

  @override
  String get friendUnmute => 'म्यूट हटाएँ';

  @override
  String get friendBlock => 'ब्लॉक करें';

  @override
  String get friendBlockHelp =>
      'वे आपको खोज, जोड़ या देख नहीं सकेंगे, और आप भी उन्हें नहीं देखेंगे।';

  @override
  String get friendUnblock => 'अनब्लॉक करें';

  @override
  String get friendRemove => 'दोस्त हटाएँ';

  @override
  String friendBlockConfirmTitle(String name) {
    return '$name को ब्लॉक करें?';
  }

  @override
  String get friendBlockConfirmBody =>
      'आप अब दोस्त नहीं रहेंगे और Montra में एक-दूसरे को नहीं देखेंगे। उन्हें इसकी सूचना नहीं दी जाती। बाद में आप “ब्लॉक और म्यूट किए गए” से उन्हें अनब्लॉक कर सकते हैं।';

  @override
  String friendRemoveConfirmTitle(String name) {
    return '$name को दोस्तों से हटाएँ?';
  }

  @override
  String get friendRemoveConfirmBody =>
      'आप बाद में फिर से दोस्ती का अनुरोध भेज सकते हैं। जिन समूहों, साझा बजट या लक्ष्यों में आप दोनों हैं, वे नहीं बदलते।';

  @override
  String friendMutedDone(String name) {
    return '$name को म्यूट किया गया।';
  }

  @override
  String friendUnmutedDone(String name) {
    return '$name से म्यूट हटा दिया गया।';
  }

  @override
  String friendBlockedDone(String name) {
    return '$name को ब्लॉक किया गया।';
  }

  @override
  String friendUnblockedDone(String name) {
    return '$name को अनब्लॉक किया गया।';
  }

  @override
  String friendRemovedDone(String name) {
    return '$name को आपके दोस्तों से हटा दिया गया।';
  }

  @override
  String get friendCodeAlreadyFriends => 'आप पहले से दोस्त हैं।';

  @override
  String get friendCodeRequestPending =>
      'आप इस व्यक्ति को पहले ही दोस्ती का अनुरोध भेज चुके हैं।';

  @override
  String get friendCodeRequestsClosed =>
      'यह व्यक्ति अभी दोस्ती के अनुरोध स्वीकार नहीं कर रहा है।';

  @override
  String get socialSettingsTitle => 'दोस्तों के लिए गोपनीयता';

  @override
  String get socialSettingsSaved => 'गोपनीयता सेटिंग सहेजी गई।';

  @override
  String get socialNothingChanged =>
      'कुछ नहीं बदला, इसलिए सहेजने को कुछ नहीं था।';

  @override
  String get usernameSection => 'आपका यूज़रनेम';

  @override
  String get usernameLabel => 'यूज़रनेम';

  @override
  String get usernameRules =>
      '3 से 30 अक्षर, अंक, “_” या “.”। यह छोटे अक्षरों में सहेजा जाता है। यूज़रनेम हटाने के लिए इसे खाली छोड़ें।';

  @override
  String get usernameLengthRule => '3 से 30 अक्षर इस्तेमाल करें।';

  @override
  String get usernameCharactersRule =>
      'केवल अक्षर, अंक, “_” और “.” इस्तेमाल करें।';

  @override
  String get usernameTaken =>
      'यह यूज़रनेम पहले से लिया जा चुका है। कोई दूसरा आज़माएँ।';

  @override
  String get socialDiscoverySection => 'आपको कौन खोज सकता है';

  @override
  String get socialDiscoverableLabel => 'लोग मुझे यूज़रनेम से खोज सकें';

  @override
  String get socialDiscoverableHelp =>
      'यह चालू होने पर, जो कोई आपका सटीक यूज़रनेम लिखता है, वह आपको खोजकर दोस्ती का अनुरोध भेज सकता है। आपके दोस्त आपको हमेशा समूहों में जोड़ सकते हैं।';

  @override
  String get socialDiscoverableOffNote =>
      'जब तक आप इसे चालू नहीं करते, यह बंद रहता है: कोई भी आपको आपके यूज़रनेम से नहीं खोज सकता, भले ही वे उसे जानते हों। आप फिर भी अनुरोध भेज सकते हैं और लिंक से समूहों में शामिल हो सकते हैं।';

  @override
  String get socialRequestsLabel => 'आपको दोस्ती के अनुरोध कौन भेज सकता है';

  @override
  String get socialRequestsHelp =>
      'जो आपको खोजते हैं, वे केवल अनुरोध कर सकते हैं; स्वीकार करना आपके हाथ में है।';

  @override
  String get socialRequestsEveryone => 'कोई भी';

  @override
  String get socialRequestsFriendsOfFriends => 'मेरे दोस्तों के दोस्त';

  @override
  String get socialRequestsNobody => 'कोई नहीं';

  @override
  String get groupsTitle => 'समूह';

  @override
  String get groupNew => 'नया समूह';

  @override
  String get groupsShowArchived => 'संग्रहीत समूह दिखाएँ';

  @override
  String get groupsEmptyTitle => 'अभी कोई समूह नहीं';

  @override
  String get groupsEmptyBody =>
      'अपने घर, रूममेट्स, किसी यात्रा या दोस्तों के साथ खर्च बाँटने के लिए समूह बनाएँ, या किसी के भेजे लिंक से किसी समूह में शामिल हों।';

  @override
  String groupTypeAndMembers(String type, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count सदस्य',
      one: '1 सदस्य',
    );
    return '$type · $_temp0';
  }

  @override
  String get groupArchivedLabel => 'संग्रहीत';

  @override
  String get groupTypeHousehold => 'घर';

  @override
  String get groupTypeRoommates => 'रूममेट्स';

  @override
  String get groupTypeTrip => 'यात्रा';

  @override
  String get groupTypeEvent => 'कार्यक्रम';

  @override
  String get groupTypeFriends => 'दोस्त';

  @override
  String get groupTypeCustom => 'अन्य';

  @override
  String get groupSplitEqual => 'बराबर';

  @override
  String get groupSplitExact => 'सटीक राशियाँ';

  @override
  String get groupSplitPercentage => 'प्रतिशत';

  @override
  String get groupSplitShares => 'हिस्से';

  @override
  String get groupSplitItemized => 'चीज़ों के अनुसार';

  @override
  String get groupRoleOwner => 'मालिक';

  @override
  String get groupRoleAdmin => 'एडमिन';

  @override
  String get groupRoleMember => 'सदस्य';

  @override
  String get groupNotifyAll => 'सब कुछ';

  @override
  String get groupNotifyImportant => 'केवल ज़रूरी बातें';

  @override
  String get groupNotifyNone => 'कुछ नहीं';

  @override
  String groupNetOwedToYou(String amount) {
    return 'आपको $amount मिलने हैं';
  }

  @override
  String groupNetYouOwe(String amount) {
    return 'आपको $amount देने हैं';
  }

  @override
  String get groupNetSettled => 'हिसाब बराबर';

  @override
  String groupMemberIsOwed(String amount) {
    return 'को $amount मिलने हैं';
  }

  @override
  String groupMemberOwes(String amount) {
    return 'को $amount देने हैं';
  }

  @override
  String get groupInvitationsForYou => 'आपके लिए आमंत्रण';

  @override
  String get groupInvitationReceived => 'आपको शामिल होने का आमंत्रण मिला है';

  @override
  String groupInvitationFrom(String name) {
    return '$name ने आमंत्रित किया';
  }

  @override
  String get groupInvitationAccept => 'शामिल हों';

  @override
  String get groupInvitationDecline => 'अस्वीकार करें';

  @override
  String get groupInvitationDeclinedDone => 'आमंत्रण अस्वीकार किया गया।';

  @override
  String groupJoinedDone(String name) {
    return 'आप $name में शामिल हो गए।';
  }

  @override
  String get groupEditTitle => 'समूह बदलें';

  @override
  String get groupNameLabel => 'समूह का नाम';

  @override
  String get groupNameRequired => 'समूह का नाम लिखें।';

  @override
  String get groupTypeLabel => 'समूह का प्रकार';

  @override
  String get groupCurrencyLabel => 'समूह की मुद्रा';

  @override
  String get groupCurrencyDefault => 'आपकी मुख्य मुद्रा';

  @override
  String get groupCurrencyHelp =>
      'हिसाब इसी मुद्रा में रखा जाता है। समूह में खर्च या भुगतान दर्ज होने के बाद इसे बदला नहीं जा सकता।';

  @override
  String get groupSplitLabel => 'बाँटने का सामान्य तरीका';

  @override
  String get groupSplitHelp =>
      'नए खर्च इसी से शुरू होते हैं; आप हर खर्च के लिए इसे बदल सकते हैं।';

  @override
  String get groupTripSection => 'यात्रा का विवरण';

  @override
  String get groupDestinationLabel => 'गंतव्य';

  @override
  String get groupStartDateLabel => 'शुरुआत';

  @override
  String get groupEndDateLabel => 'समाप्ति';

  @override
  String get groupAboutSection => 'जानकारी';

  @override
  String get groupDescriptionLabel => 'विवरण (वैकल्पिक)';

  @override
  String get groupRulesLabel => 'समूह के नियम (वैकल्पिक)';

  @override
  String get groupRulesHelp =>
      'जैसे, आप किराने का सामान कैसे बाँटते हैं या हिसाब कब करते हैं।';

  @override
  String get groupTimezoneLabel => 'समय क्षेत्र (वैकल्पिक)';

  @override
  String get groupTimezoneHelp =>
      'जैसे Asia/Kolkata। खाली छोड़ने पर आपका अपना समय क्षेत्र इस्तेमाल होगा।';

  @override
  String get groupOptionsSection => 'विकल्प';

  @override
  String get groupSimplifyLabel => 'कर्ज़ आसान करें';

  @override
  String get groupSimplifyHelp =>
      'हिसाब बराबर करने के लिए कम भुगतान सुझाता है। सबका बकाया वही रहता है।';

  @override
  String get groupAllowInvitesLabel => 'सदस्य लोगों को आमंत्रित कर सकते हैं';

  @override
  String get groupAllowInvitesHelp =>
      'बंद होने पर केवल मालिक और एडमिन आमंत्रित कर सकते हैं।';

  @override
  String get groupRequireApprovalLabel =>
      'लिंक से जुड़ने वालों को एडमिन मंज़ूरी दें';

  @override
  String get groupRequireApprovalHelp =>
      'डिफ़ॉल्ट रूप से बंद। चालू होने पर आमंत्रण लिंक खोलने से एक अनुरोध जाता है जिसे एडमिन मंज़ूर करते हैं; यूज़रनेम से आमंत्रित लोग सीधे शामिल होते हैं।';

  @override
  String get groupCreateButton => 'समूह बनाएँ';

  @override
  String groupCreatedDone(String name) {
    return 'समूह $name बनाया गया।';
  }

  @override
  String get groupSavedDone => 'समूह सहेजा गया।';

  @override
  String get groupNothingChanged =>
      'कुछ नहीं बदला, इसलिए सहेजने को कुछ नहीं था।';

  @override
  String get groupJoinTitle => 'लिंक से समूह में शामिल हों';

  @override
  String get groupJoinIntro =>
      'किसी के भेजे आमंत्रण लिंक को यहाँ पेस्ट करें। शामिल होने से पहले आप समूह देख सकेंगे।';

  @override
  String get groupJoinLinkLabel => 'आमंत्रण लिंक';

  @override
  String get groupJoinLinkInvalid => 'यह Montra का आमंत्रण लिंक नहीं लगता।';

  @override
  String get groupJoinCheckLink => 'लिंक जाँचें';

  @override
  String get groupJoinLinkGone =>
      'यह लिंक इस्तेमाल नहीं हो सकता: हो सकता है इसकी अवधि खत्म हो गई हो, यह पूरा इस्तेमाल हो चुका हो या बंद कर दिया गया हो। नया लिंक माँगें।';

  @override
  String get groupMembersLabel => 'सदस्य';

  @override
  String get groupInvitedByLabel => 'आमंत्रित करने वाले';

  @override
  String get groupInvitationExpiresLabel => 'लिंक की वैधता';

  @override
  String get groupJoinAlreadyMember => 'आप पहले से इस समूह के सदस्य हैं।';

  @override
  String groupJoinLinkNotActive(String status) {
    return 'यह लिंक अब इस्तेमाल नहीं हो सकता ($status)। नया लिंक माँगें।';
  }

  @override
  String get groupJoinNeedsApproval =>
      'इस समूह के नए सदस्यों को एडमिन मंज़ूरी देते हैं। आपके अनुरोध करने पर उन्हें बताया जाएगा, और किसी एक के मंज़ूर करते ही आप शामिल हो जाएँगे।';

  @override
  String get groupJoinDirect =>
      'आप तुरंत शामिल हो जाएँगे। सदस्य समूह में आपका नाम और यूज़रनेम देखेंगे।';

  @override
  String get groupJoinButton => 'समूह में शामिल हों';

  @override
  String get groupJoinAskToJoin => 'शामिल होने का अनुरोध करें';

  @override
  String get groupOpen => 'समूह खोलें';

  @override
  String get groupJoinPendingTitle => 'अनुरोध भेजा गया';

  @override
  String groupJoinPendingBody(String group) {
    return '$group के एडमिन आपका अनुरोध देखेंगे। शामिल होने पर आपको सूचना मिलेगी।';
  }

  @override
  String get groupJoinBackToGroups => 'समूहों पर वापस जाएँ';

  @override
  String get groupSettingsTitle => 'समूह सेटिंग';

  @override
  String get groupArchivedBanner =>
      'यह समूह संग्रहीत है। इसके रिकॉर्ड बने रहते हैं, लेकिन मालिक के इसे बहाल करने तक कुछ नहीं बदल सकता।';

  @override
  String get groupBalanceTitle => 'हिसाब';

  @override
  String groupFormerMember(String name) {
    return '$name (पूर्व सदस्य)';
  }

  @override
  String groupDisputedExpenses(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count खर्चों पर आपत्ति है और ये बदल सकते हैं।',
      one: '1 खर्च पर आपत्ति है और यह बदल सकता है।',
    );
    return '$_temp0';
  }

  @override
  String get groupBalancesUnavailable =>
      'हिसाब लोड नहीं हो सका। फिर से कोशिश करने के लिए नीचे खींचें।';

  @override
  String get groupSettleUp => 'हिसाब करें';

  @override
  String get groupMoneySection => 'पैसे';

  @override
  String get groupLinkExpenses => 'खर्च';

  @override
  String get groupLinkBalances => 'हिसाब और सुझाए गए भुगतान';

  @override
  String get groupLinkSettlements => 'सदस्यों के बीच भुगतान';

  @override
  String get groupLinkRecurring => 'बार-बार होने वाले साझा खर्च';

  @override
  String get groupLinkReports => 'रिपोर्ट और निर्यात';

  @override
  String groupMemberYou(String name) {
    return '$name (आप)';
  }

  @override
  String get groupMemberLeft => 'छोड़ दिया';

  @override
  String get groupMemberRemoved => 'हटाए गए';

  @override
  String get groupActivityTitle => 'गतिविधि';

  @override
  String get groupActivityEmpty => 'इस समूह में अभी तक कुछ नहीं हुआ है।';

  @override
  String get groupActivityUnavailable => 'गतिविधि लोड नहीं हो सकी।';

  @override
  String get groupActivitySomeone => 'किसी ने';

  @override
  String groupActivityCreated(String actor, String type) {
    return '$actor ने यह $type समूह बनाया।';
  }

  @override
  String groupActivityUpdated(String actor) {
    return '$actor ने समूह का विवरण बदला।';
  }

  @override
  String groupActivityArchived(String actor) {
    return '$actor ने समूह को संग्रहीत किया।';
  }

  @override
  String groupActivityRestored(String actor) {
    return '$actor ने समूह को बहाल किया।';
  }

  @override
  String groupActivityDeleted(String actor) {
    return '$actor ने समूह हटाया।';
  }

  @override
  String groupActivityInvited(String actor) {
    return '$actor ने किसी को यूज़रनेम से आमंत्रित किया।';
  }

  @override
  String groupActivityLinkCreated(String actor) {
    return '$actor ने एक आमंत्रण लिंक बनाया।';
  }

  @override
  String groupActivityInvitationRevoked(String actor) {
    return '$actor ने एक आमंत्रण बंद किया।';
  }

  @override
  String groupActivityJoinRequested(String actor) {
    return '$actor ने शामिल होने का अनुरोध किया।';
  }

  @override
  String groupActivityJoined(String name) {
    return '$name समूह में शामिल हुए।';
  }

  @override
  String groupActivityJoinedApproved(String name) {
    return 'एडमिन की मंज़ूरी के बाद $name शामिल हुए।';
  }

  @override
  String groupActivityLeft(String name) {
    return '$name ने समूह छोड़ा।';
  }

  @override
  String groupActivityRemoved(String actor, String name) {
    return '$actor ने $name को हटाया।';
  }

  @override
  String groupActivityRoleChanged(String actor, String name, String role) {
    return '$actor ने $name को $role बनाया।';
  }

  @override
  String groupActivityOwnershipTransferred(String actor, String name) {
    return '$actor ने $name को मालिक बनाया।';
  }

  @override
  String groupActivityExpenseAdded(String actor, String name) {
    return '$actor ने खर्च “$name” जोड़ा।';
  }

  @override
  String groupActivityExpenseUpdated(String actor, String name) {
    return '$actor ने खर्च “$name” बदला।';
  }

  @override
  String groupActivityExpenseDeleted(String actor, String name) {
    return '$actor ने खर्च “$name” हटाया।';
  }

  @override
  String groupActivityExpenseCommented(String actor, String name) {
    return '$actor ने “$name” पर टिप्पणी की।';
  }

  @override
  String groupActivityExpenseDisputed(String actor, String name) {
    return '$actor ने “$name” पर आपत्ति उठाई।';
  }

  @override
  String groupActivityDisputeResolved(String actor, String name) {
    return '$actor ने “$name” पर उठी आपत्ति सुलझाई।';
  }

  @override
  String groupActivityDisputeWithdrawn(String actor, String name) {
    return '$actor ने “$name” पर उठाई आपत्ति वापस ली।';
  }

  @override
  String groupActivitySettlementDisputeResolved(String actor) {
    return '$actor ने एक भुगतान पर उठी आपत्ति सुलझाई।';
  }

  @override
  String groupActivitySettlementDisputeWithdrawn(String actor) {
    return '$actor ने एक भुगतान पर उठाई आपत्ति वापस ली।';
  }

  @override
  String groupActivitySettlementProposed(String actor) {
    return '$actor ने एक भुगतान प्रस्तावित किया।';
  }

  @override
  String groupActivitySettlementReported(String actor) {
    return '$actor ने एक भुगतान दर्ज किया।';
  }

  @override
  String groupActivitySettlementConfirmed(String actor) {
    return '$actor ने एक भुगतान की पुष्टि की।';
  }

  @override
  String groupActivitySettlementDisputed(String actor) {
    return '$actor ने एक भुगतान पर आपत्ति की।';
  }

  @override
  String groupActivitySettlementVoided(String actor) {
    return '$actor ने एक भुगतान रिकॉर्ड रद्द किया।';
  }

  @override
  String groupActivitySettlementCorrected(String actor) {
    return '$actor ने एक भुगतान सुधारा।';
  }

  @override
  String groupActivityRecurringCreated(String actor, String name) {
    return '$actor ने बार-बार होने वाला खर्च “$name” बनाया।';
  }

  @override
  String groupActivityRecurringUpdated(String actor, String name) {
    return '$actor ने बार-बार होने वाला खर्च “$name” बदला।';
  }

  @override
  String groupActivityRecurringPaused(String actor, String name) {
    return '$actor ने बार-बार होने वाले खर्च “$name” को रोका।';
  }

  @override
  String groupActivityRecurringResumed(String actor, String name) {
    return '$actor ने बार-बार होने वाला खर्च “$name” फिर से शुरू किया।';
  }

  @override
  String groupActivityRecurringStopped(String actor, String name) {
    return '$actor ने बार-बार होने वाला खर्च “$name” बंद किया।';
  }

  @override
  String groupActivityRecurringSkipped(String actor, String name) {
    return '$actor ने “$name” का एक बार छोड़ा।';
  }

  @override
  String groupActivityOther(String actor) {
    return '$actor ने एक बदलाव किया।';
  }

  @override
  String get groupDetailsSection => 'समूह का विवरण';

  @override
  String get groupAddMember => 'सदस्य जोड़ें';

  @override
  String get groupAddFromFriends => 'अपने दोस्तों में से';

  @override
  String get groupAddFromFriendsHelp =>
      'दोस्तों को जोड़ा जा सकता है, भले ही वे यूज़रनेम से न मिलें।';

  @override
  String get groupAddByUsername => 'यूज़रनेम से';

  @override
  String get groupAddByUsernameHelp =>
      'इस तरह केवल उन्हीं लोगों को आमंत्रित किया जा सकता है जिन्होंने यूज़रनेम से खोजे जाने की अनुमति दी है।';

  @override
  String get groupInvite => 'आमंत्रित करें';

  @override
  String groupInvitedDone(String name) {
    return '$name को आमंत्रण भेजा गया। स्वीकार करते ही वे शामिल हो जाएँगे।';
  }

  @override
  String get groupMakeAdmin => 'एडमिन बनाएँ';

  @override
  String get groupAdminHelp =>
      'एडमिन समूह बदल सकते हैं, सदस्यों को संभाल सकते हैं और अनुरोध मंज़ूर कर सकते हैं।';

  @override
  String get groupMakeMember => 'सदस्य बनाएँ';

  @override
  String groupRoleChangedDone(String name, String role) {
    return '$name अब $role हैं।';
  }

  @override
  String get groupTransferOwnership => 'मालिक बनाएँ';

  @override
  String groupTransferConfirmTitle(String name) {
    return '$name को मालिक बनाएँ?';
  }

  @override
  String groupTransferConfirmBody(String name) {
    return '$name समूह के मालिक होंगे और इसे संग्रहीत या हटा सकेंगे। आप समूह में एडमिन के रूप में रहेंगे।';
  }

  @override
  String groupTransferredDone(String name) {
    return '$name अब मालिक हैं।';
  }

  @override
  String get groupRemoveMember => 'समूह से हटाएँ';

  @override
  String groupRemoveConfirmTitle(String name) {
    return '$name को समूह से हटाएँ?';
  }

  @override
  String groupRemoveConfirmBody(String name) {
    return '$name की पहुँच तुरंत खत्म हो जाएगी। उनके खर्च, हिस्से और भुगतान रिकॉर्ड में बने रहेंगे। अगर उन्हें अभी पैसे देने या लेने हैं, तो वह बकाया हिसाब, सुझाए गए भुगतानों और रिपोर्ट में गिना जाता रहेगा, कोई भी उनके साथ भुगतान दर्ज कर सकता है, और एडमिन उन्हें किए गए भुगतान की पुष्टि कर सकते हैं।';
  }

  @override
  String groupRemovedDone(String name) {
    return '$name को समूह से हटा दिया गया।';
  }

  @override
  String get groupRemovalPolicy =>
      'सदस्य को हटाने पर उनके रिकॉर्ड बने रहते हैं। बकाया राशि हिसाब होने तक समूह में बनी रहती है।';

  @override
  String get groupInvitationsTitle => 'आमंत्रण';

  @override
  String get groupCreateLink => 'आमंत्रण लिंक बनाएँ';

  @override
  String get groupCreateLinkHelp =>
      'लिंक वाला कोई भी समूह का नाम देख सकता है और शामिल होने का अनुरोध कर सकता है।';

  @override
  String get groupInvitationsUnavailable => 'आमंत्रण लोड नहीं हो सके।';

  @override
  String get groupInvitationsEmpty => 'अभी कोई आमंत्रण नहीं।';

  @override
  String groupInvitationLinkTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'आमंत्रण लिंक · $count बार इस्तेमाल हुआ',
      one: 'आमंत्रण लिंक · एक बार इस्तेमाल हुआ',
      zero: 'आमंत्रण लिंक · अभी इस्तेमाल नहीं हुआ',
    );
    return '$_temp0';
  }

  @override
  String groupInvitationForPerson(String name) {
    return '$name के लिए आमंत्रण';
  }

  @override
  String groupInvitationCreated(String name, String date) {
    return '$name ने $date को बनाया';
  }

  @override
  String get groupInvitationStatusActive => 'सक्रिय';

  @override
  String get groupInvitationStatusAccepted => 'स्वीकार किया गया';

  @override
  String get groupInvitationStatusDeclined => 'अस्वीकार किया गया';

  @override
  String get groupInvitationStatusRevoked => 'बंद किया गया';

  @override
  String get groupInvitationStatusExpired => 'समय समाप्त';

  @override
  String get groupInvitationRevoke => 'बंद करें';

  @override
  String get groupInvitationRevokeTitle => 'यह आमंत्रण बंद करें?';

  @override
  String get groupInvitationRevokeBody =>
      'इससे अब कोई शामिल नहीं हो सकेगा। जो पहले शामिल हो चुके हैं, वे समूह में बने रहेंगे।';

  @override
  String get groupInvitationRevokedDone => 'आमंत्रण बंद किया गया।';

  @override
  String get groupLinkCreatedDone => 'आमंत्रण लिंक बनाया गया।';

  @override
  String get groupLinkExpiresLabel => 'वैधता';

  @override
  String groupLinkDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count दिन',
      one: '1 दिन',
    );
    return '$_temp0';
  }

  @override
  String get groupLinkUsesLabel => 'कितनी बार इस्तेमाल हो सकता है';

  @override
  String groupLinkUses(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count बार',
      one: 'एक बार',
    );
    return '$_temp0';
  }

  @override
  String get groupLinkUsesAny => 'कितनी भी बार';

  @override
  String get groupLinkReadyTitle => 'अपना आमंत्रण लिंक साझा करें';

  @override
  String get groupLinkShownOnce =>
      'यह लिंक केवल अभी दिखाया जा रहा है। इस विंडो को बंद करने से पहले इसे कॉपी या साझा करें। आप इसे कभी भी बंद कर सकते हैं।';

  @override
  String groupLinkShareText(String group, String link) {
    return 'Montra पर $group से जुड़ें: $link';
  }

  @override
  String get groupJoinRequestsTitle => 'शामिल होने के अनुरोध';

  @override
  String get groupJoinRequestsOnHelp =>
      'आमंत्रण लिंक खोलने वाले लोग यहाँ तब तक इंतज़ार करते हैं जब तक कोई एडमिन उन्हें मंज़ूर न करे।';

  @override
  String get groupJoinRequestsOffHelp =>
      'मंज़ूरी बंद है: आमंत्रण लिंक वाले लोग सीधे शामिल होते हैं। इसे समूह के विवरण में चालू करें।';

  @override
  String get groupJoinRequestsUnavailable => 'अनुरोध लोड नहीं हो सके।';

  @override
  String get groupJoinRequestsEmpty => 'कोई इंतज़ार में नहीं है।';

  @override
  String get groupJoinRequestApprove => 'मंज़ूर करें';

  @override
  String get groupJoinRequestDecline => 'अस्वीकार करें';

  @override
  String groupJoinRequestApprovedDone(String name) {
    return '$name समूह में शामिल हुए।';
  }

  @override
  String groupJoinRequestDeclinedDone(String name) {
    return '$name का अनुरोध अस्वीकार किया गया।';
  }

  @override
  String get groupJoinRequestStatusPending => 'इंतज़ार में';

  @override
  String get groupJoinRequestStatusApproved => 'मंज़ूर';

  @override
  String get groupJoinRequestStatusDeclined => 'अस्वीकार';

  @override
  String get groupJoinRequestStatusCancelled => 'रद्द';

  @override
  String get groupYourNotifications => 'इस समूह से आपकी सूचनाएँ';

  @override
  String get groupNotificationsSaved => 'सूचना का विकल्प सहेजा गया।';

  @override
  String get groupActionsSection => 'समूह के काम';

  @override
  String get groupArchive => 'समूह संग्रहीत करें';

  @override
  String get groupArchiveHelp =>
      'संग्रहीत करने पर हर रिकॉर्ड बना रहता है और बार-बार होने वाले खर्च रुक जाते हैं। बहाल करने तक कुछ नहीं बदल सकता।';

  @override
  String groupArchiveConfirmTitle(String name) {
    return '$name को संग्रहीत करें?';
  }

  @override
  String get groupArchivedDone => 'समूह संग्रहीत किया गया।';

  @override
  String get groupRestore => 'समूह बहाल करें';

  @override
  String get groupRestoredDone => 'समूह बहाल किया गया।';

  @override
  String get groupLeave => 'समूह छोड़ें';

  @override
  String get groupLeaveHelp =>
      'समूह में आपका हिसाब बराबर होने के बाद आप इसे छोड़ सकते हैं। आपके पिछले खर्च और भुगतान समूह के रिकॉर्ड में बने रहेंगे।';

  @override
  String groupLeaveConfirmTitle(String name) {
    return '$name छोड़ें?';
  }

  @override
  String groupLeftDone(String name) {
    return 'आपने $name छोड़ दिया।';
  }

  @override
  String get groupOwnerLeaveNote =>
      'मालिक होने के नाते, समूह छोड़ने से पहले (सदस्य में जाकर) किसी और को मालिक बनाएँ।';

  @override
  String get groupDelete => 'समूह हटाएँ';

  @override
  String get groupDeleteHelp =>
      'पहले सबका हिसाब बराबर होना चाहिए। हटाने से समूह हर सदस्य के लिए हट जाता है और उसके आमंत्रण बंद हो जाते हैं। इसे वापस नहीं किया जा सकता।';

  @override
  String groupDeleteConfirmTitle(String name) {
    return '$name हटाएँ?';
  }

  @override
  String groupDeletedDone(String name) {
    return '$name हटा दिया गया।';
  }

  @override
  String get groupCodeAlreadyMember => 'यह व्यक्ति पहले से समूह का सदस्य है।';

  @override
  String get groupCodeJoinRequestPending =>
      'शामिल होने का आपका अनुरोध पहले से एडमिन के पास इंतज़ार में है।';

  @override
  String groupCodeInvitationUsed(String status) {
    return 'यह आमंत्रण पहले ही $status हो चुका है।';
  }

  @override
  String get groupCodeInvitationInactive => 'यह आमंत्रण अब सक्रिय नहीं है।';

  @override
  String get groupCodeArchived =>
      'यह समूह संग्रहीत है। बदलाव के लिए मालिक इसे बहाल कर सकते हैं।';

  @override
  String get groupCodeNotArchived => 'यह समूह संग्रहीत नहीं है।';

  @override
  String get groupCodeBalanceOpen =>
      'समूह छोड़ने से पहले अपना हिसाब बराबर करें।';

  @override
  String get groupCodeBalancesOpen =>
      'समूह हटाने से पहले सबका हिसाब बराबर होना चाहिए।';

  @override
  String get groupCodeTransferFirst => 'छोड़ने से पहले किसी और को मालिक बनाएँ।';

  @override
  String get groupCodeCurrencyLocked =>
      'समूह में खर्च, भुगतान या बार-बार होने वाले खर्च होने के बाद मुद्रा नहीं बदल सकती।';

  @override
  String get togetherIntro =>
      'अपने आसपास के लोगों के साथ खर्च बाँटें, समुदायों से सीखें और चुनौतियाँ लें। यहाँ सब कुछ मुफ़्त है।';

  @override
  String get togetherFriendsSubtitle =>
      'यूज़रनेम से लोगों को खोजें और अनुरोध संभालें';

  @override
  String togetherFriendRequests(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'दोस्ती के $count अनुरोध इंतज़ार में हैं',
      one: 'दोस्ती का 1 अनुरोध इंतज़ार में है',
    );
    return '$_temp0';
  }

  @override
  String get togetherGroupsSubtitle =>
      'घर, यात्रा या दोस्तों के साथ खर्च बाँटें';

  @override
  String togetherGroupsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count समूह',
      one: '1 समूह',
    );
    return '$_temp0';
  }

  @override
  String togetherGroupInvitations(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'आपके लिए समूह के $count आमंत्रण',
      one: 'आपके लिए समूह का 1 आमंत्रण',
    );
    return '$_temp0';
  }

  @override
  String get togetherCommunities => 'समुदाय';

  @override
  String get togetherCommunitiesSubtitle =>
      'दूसरों के साथ पैसों से जुड़े विषयों पर चर्चा करें';

  @override
  String get togetherChallenges => 'चुनौतियाँ';

  @override
  String get togetherChallengesSubtitle => 'अकेले या साथ मिलकर आदतें बनाएँ';

  @override
  String get togetherJoinSection => 'क्या आपके पास आमंत्रण लिंक है?';

  @override
  String get togetherJoinGroupSubtitle => 'समूह का आमंत्रण लिंक पेस्ट करें';

  @override
  String get togetherJoinCommunity => 'लिंक से समुदाय में शामिल हों';

  @override
  String get togetherJoinCommunitySubtitle =>
      'समुदाय का आमंत्रण लिंक पेस्ट करें';

  @override
  String get communityVisibilityPublic => 'सार्वजनिक';

  @override
  String get communityVisibilityPrivate => 'निजी';

  @override
  String get communityVisibilityInviteOnly => 'केवल आमंत्रण से';

  @override
  String get communityVisibilityPublicHelp =>
      'कोई भी इसे ढूँढ सकता है और जुड़ सकता है।';

  @override
  String get communityVisibilityPrivateHelp =>
      'कोई भी इसे ढूँढ सकता है; कौन जुड़ेगा, यह मॉडरेटर तय करते हैं।';

  @override
  String get communityVisibilityInviteOnlyHelp =>
      'सूची में नहीं दिखता; लोग आमंत्रण से जुड़ते हैं।';

  @override
  String get communityRoleOwner => 'मालिक';

  @override
  String get communityRoleModerator => 'मॉडरेटर';

  @override
  String get communityRoleMember => 'सदस्य';

  @override
  String get communityMemberStatusActive => 'सदस्य';

  @override
  String get communityMemberStatusPending => 'मंज़ूरी का इंतज़ार';

  @override
  String get communityMemberStatusBanned => 'प्रतिबंधित';

  @override
  String get communityMemberStatusLeft => 'छोड़ दिया';

  @override
  String get postKindDiscussion => 'चर्चा';

  @override
  String get postKindQuestion => 'सवाल';

  @override
  String get postKindResource => 'उपयोगी लिंक';

  @override
  String get postKindPoll => 'पोल';

  @override
  String get postKindChallengeUpdate => 'चुनौती की खबर';

  @override
  String get postLabelPersonalExperience => 'निजी अनुभव';

  @override
  String get postLabelVerifiedGuidance => 'जाँची हुई सलाह';

  @override
  String get postLabelQuestion => 'सवाल';

  @override
  String get postLabelResource => 'संसाधन';

  @override
  String get reactionLike => 'पसंद';

  @override
  String get reactionHelpful => 'मददगार';

  @override
  String get reactionInsightful => 'समझदारी भरा';

  @override
  String get reactionSupport => 'साथ';

  @override
  String get contentReportReasonSpam => 'स्पैम';

  @override
  String get contentReportReasonAbuse => 'दुर्व्यवहार';

  @override
  String get contentReportReasonHarassment => 'परेशान करना';

  @override
  String get contentReportReasonScam => 'धोखाधड़ी';

  @override
  String get contentReportReasonImpersonation => 'किसी और होने का दिखावा';

  @override
  String get contentReportReasonMisinformation => 'गलत या भ्रामक';

  @override
  String get contentReportReasonPrivacy => 'निजी जानकारी साझा करता है';

  @override
  String get contentReportReasonOther => 'कुछ और';

  @override
  String get communityErrorAccountRestricted =>
      'आपका खाता अभी समुदायों में हिस्सा नहीं ले सकता।';

  @override
  String get communityErrorAlreadyDeleted => 'यह पहले ही हटाया जा चुका है।';

  @override
  String get communityErrorCommentLocked => 'यह टिप्पणी अब बदली नहीं जा सकती।';

  @override
  String get communityErrorCommentsClosed => 'इस पोस्ट पर टिप्पणियाँ बंद हैं।';

  @override
  String get communityErrorSuspended =>
      'यह समुदाय निलंबित है। इसे केवल Montra स्टाफ़ फिर से चालू कर सकता है।';

  @override
  String get communityErrorContentUnavailable => 'यह अब उपलब्ध नहीं है।';

  @override
  String get communityErrorInvitationOnly =>
      'यह समुदाय केवल आमंत्रण से है। किसी मॉडरेटर से आमंत्रण माँगें।';

  @override
  String get communityErrorJoinFirst => 'हिस्सा लेने के लिए समुदाय से जुड़ें।';

  @override
  String get communityErrorNewAccountLinks =>
      'नए खाते पहले दिन के बाद लिंक साझा कर सकते हैं।';

  @override
  String get communityErrorNotAcceptingMembers =>
      'यह समुदाय अभी नए सदस्य नहीं ले रहा है।';

  @override
  String get communityErrorNotAcceptingPosts =>
      'यह समुदाय अभी नई पोस्ट नहीं ले रहा है।';

  @override
  String get communityErrorOwnContent =>
      'अपनी सामग्री या खाते पर कार्रवाई के लिए किसी दूसरे मॉडरेटर से कहें।';

  @override
  String get communityErrorOwnerProtected =>
      'मालिक को उनके अपने समुदाय से प्रतिबंधित नहीं किया जा सकता।';

  @override
  String get communityErrorPollClosed => 'यह पोल बंद हो चुका है।';

  @override
  String get communityErrorPostLocked => 'यह पोस्ट अब बदली नहीं जा सकती।';

  @override
  String communityErrorPostingRestrictedUntil(String until) {
    return 'एक मॉडरेटर ने यहाँ आपकी पोस्टिंग $until तक रोकी है।';
  }

  @override
  String get communityErrorPostingRestricted =>
      'एक मॉडरेटर ने यहाँ आपकी पोस्टिंग अभी के लिए रोकी है।';

  @override
  String get communityErrorTransferOwnershipFirst =>
      'छोड़ने से पहले मालिकाना हक किसी और को दें।';

  @override
  String get communityErrorAlreadyMember => 'आप पहले से सदस्य हैं।';

  @override
  String get communityErrorInvitationUsed =>
      'इस आमंत्रण का जवाब पहले ही दिया जा चुका है।';

  @override
  String get communityErrorInvitationInactive =>
      'यह आमंत्रण अब सक्रिय नहीं है।';

  @override
  String get challengeErrorCancelled => 'यह चुनौती रद्द कर दी गई।';

  @override
  String get challengeErrorInactive => 'यह चुनौती अब सक्रिय नहीं है।';

  @override
  String get challengeErrorNotOpen => 'यह चुनौती खुली नहीं है।';

  @override
  String get challengeErrorJoinFirst => 'पहले चुनौती से जुड़ें।';

  @override
  String get challengeErrorLeaderboardOptIn =>
      'लीडरबोर्ड दोनों तरफ़ से साझा होता है: इसे देखने के लिए अपनी प्रगति साझा करें और उस पर दिखना चुनें।';

  @override
  String get challengeErrorNoLeaderboard =>
      'इस चुनौती का कोई लीडरबोर्ड नहीं है।';

  @override
  String get challengeTypeNoSpend => 'बिना खर्च';

  @override
  String get challengeTypeSavingsStreak => 'बचत का सिलसिला';

  @override
  String get challengeTypeGroceryBudget => 'राशन का बजट';

  @override
  String get challengeTypeMealPlanning => 'खाने की योजना';

  @override
  String get challengeTypeTravelSavings => 'यात्रा के लिए बचत';

  @override
  String get challengeTypeCustom => 'अपनी तरह की';

  @override
  String get challengeMetricDays => 'चेक-इन वाले दिन';

  @override
  String get challengeMetricStreak => 'सबसे लंबा सिलसिला';

  @override
  String get challengeMetricMilestones => 'कुल चेक-इन';

  @override
  String get challengeMetricPercent => 'आपका अपना प्रतिशत';

  @override
  String get challengeMetricDaysHelp =>
      'हर वह दिन गिना जाता है जिस दिन आप \"पूरा\" चेक-इन करते हैं।';

  @override
  String get challengeMetricStreakHelp =>
      'लगातार दिनों का आपका सबसे लंबा सिलसिला गिना जाता है।';

  @override
  String get challengeMetricMilestonesHelp =>
      'हर चेक-इन जुड़ता है, उतनी गिनती से जितनी आप लिखते हैं।';

  @override
  String get challengeMetricPercentHelp =>
      'आप बताते हैं कि आप कितनी दूर पहुँचे हैं, 0 से 100 % तक।';

  @override
  String challengeTargetDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count दिन',
      one: '1 दिन',
    );
    return '$_temp0';
  }

  @override
  String challengeTargetStreak(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'लगातार $count दिन',
      one: 'लगातार 1 दिन',
    );
    return '$_temp0';
  }

  @override
  String challengeTargetCheckIns(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count चेक-इन',
      one: '1 चेक-इन',
    );
    return '$_temp0';
  }

  @override
  String challengeTargetPercent(int count) {
    return '$count %';
  }

  @override
  String get challengeStatusDraft => 'मसौदा';

  @override
  String get challengeStatusActive => 'सक्रिय';

  @override
  String get challengeStatusEnded => 'समाप्त';

  @override
  String get challengeStatusCompleted => 'पूरी हुई';

  @override
  String get challengeStatusCancelled => 'रद्द';

  @override
  String get challengeScopePrivate => 'केवल आप';

  @override
  String get challengeScopeGroup => 'एक समूह';

  @override
  String get challengeScopeCommunity => 'एक समुदाय';

  @override
  String get challengeScopePublic => 'सभी';

  @override
  String get challengeMilestoneHalfway => 'आधा रास्ता पूरा';

  @override
  String get challengeMilestoneDone => 'लक्ष्य पूरा';

  @override
  String challengeMilestonePercent(int percent) {
    return 'लक्ष्य का $percent %';
  }

  @override
  String get moderationErrorOtherModerator =>
      'आपकी अपनी कार्रवाई के ख़िलाफ़ अपील की समीक्षा किसी दूसरे मॉडरेटर को करनी होगी।';

  @override
  String get moderationErrorAppealWindowPassed =>
      'फ़ैसले के 30 दिनों के अंदर ही अपील की जा सकती है।';

  @override
  String get moderationErrorNotAppealable =>
      'इस फ़ैसले के ख़िलाफ़ अपील नहीं की जा सकती।';

  @override
  String get moderationActionHide => 'छिपाया गया';

  @override
  String get moderationActionRemove => 'हटाया गया';

  @override
  String get moderationActionRestore => 'वापस लाया गया';

  @override
  String get moderationActionPin => 'ऊपर लगाया गया';

  @override
  String get moderationActionUnpin => 'ऊपर से हटाया गया';

  @override
  String get moderationActionLock => 'बंद किया गया';

  @override
  String get moderationActionUnlock => 'खोला गया';

  @override
  String get moderationActionWarn => 'चेतावनी';

  @override
  String get moderationActionRestrict => 'पोस्टिंग रोकी गई';

  @override
  String get moderationActionBan => 'प्रतिबंधित';

  @override
  String get moderationActionUnban => 'प्रतिबंध हटाया गया';

  @override
  String get moderationActionDismissReport => 'रिपोर्ट खारिज';

  @override
  String get moderationActionEscalate => 'Montra स्टाफ़ को भेजा गया';

  @override
  String get moderationActionSuspend => 'निलंबित';

  @override
  String get moderationActionUnsuspend => 'निलंबन हटाया गया';

  @override
  String get moderationTargetPost => 'पोस्ट';

  @override
  String get moderationTargetComment => 'टिप्पणी';

  @override
  String get moderationTargetMember => 'सदस्यता';

  @override
  String get moderationTargetProfile => 'प्रोफ़ाइल';

  @override
  String get moderationTargetGroup => 'समूह';

  @override
  String get moderationTargetCommunity => 'समुदाय';

  @override
  String get appealStatusOpen => 'अपील की समीक्षा चल रही है';

  @override
  String get appealStatusUpheld => 'फ़ैसला कायम है';

  @override
  String get appealStatusOverturned => 'फ़ैसला पलटा गया';

  @override
  String get appealStatusOpenHelp =>
      'जिस मॉडरेटर ने फ़ैसला नहीं लिया, वह आपकी अपील की समीक्षा करेगा।';

  @override
  String get appealStatusUpheldHelp =>
      'आपकी अपील की समीक्षा हुई और फ़ैसला कायम है।';

  @override
  String get appealStatusOverturnedHelp =>
      'आपकी अपील मानी गई और फ़ैसला पलट दिया गया।';

  @override
  String get contentReportStatusOpen => 'समीक्षा का इंतज़ार';

  @override
  String get contentReportStatusUnderReview => 'समीक्षा चल रही है';

  @override
  String get contentReportStatusActioned => 'कार्रवाई की गई';

  @override
  String get contentReportStatusDismissed => 'कार्रवाई की ज़रूरत नहीं';

  @override
  String get contentReportStatusEscalated => 'Montra स्टाफ़ को भेजा गया';

  @override
  String get contentReportStatusOpenHelp =>
      'मॉडरेटर इसे देखेंगे। माहौल अच्छा रखने में मदद के लिए धन्यवाद।';

  @override
  String get contentReportStatusActionedHelp =>
      'आपकी रिपोर्ट पर मॉडरेटर ने कार्रवाई की।';

  @override
  String get contentReportStatusDismissedHelp =>
      'मॉडरेटर ने इसे देखा और नियमों के अनुसार पाया।';

  @override
  String get contentReportStatusEscalatedHelp =>
      'मॉडरेटर ने इसे समीक्षा के लिए Montra स्टाफ़ को भेजा।';

  @override
  String get communityEdited => 'बदला गया';

  @override
  String reactionSemantics(String reaction, int count) {
    return '$reaction, $count';
  }

  @override
  String get pollVoted => 'आपका वोट सहेज लिया गया।';

  @override
  String pollTotalVotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count वोट',
      one: '1 वोट',
      zero: 'अभी कोई वोट नहीं',
    );
    return '$_temp0';
  }

  @override
  String get pollChooseSeveral => 'एक या ज़्यादा चुनें';

  @override
  String get pollClosed => 'बंद';

  @override
  String pollClosesAt(String date) {
    return '$date को बंद होगा';
  }

  @override
  String get pollVote => 'वोट दें';

  @override
  String get pollChangeVote => 'मेरा वोट बदलें';

  @override
  String get pollPrivacyNote =>
      'केवल कुल गिनती दिखती है; कोई नहीं देखता कि किसने किसे वोट दिया।';

  @override
  String pollOptionResult(int votes, int percent) {
    String _temp0 = intl.Intl.pluralLogic(
      votes,
      locale: localeName,
      other: '$votes वोट',
      one: '1 वोट',
    );
    return '$_temp0 · $percent %';
  }

  @override
  String pollYourChoice(String option) {
    return '$option (आपका वोट)';
  }

  @override
  String get communityLinkNotOpened =>
      'यह लिंक नहीं खुल सकता। केवल वेब लिंक (https) खोले जाते हैं।';

  @override
  String get contentReportSent =>
      'धन्यवाद। मॉडरेटर आपकी रिपोर्ट की समीक्षा करेंगे।';

  @override
  String get contentReportAlreadySent =>
      'आप इसकी रिपोर्ट पहले ही कर चुके हैं। मॉडरेटर इसकी समीक्षा करेंगे।';

  @override
  String get contentReportTitle => 'रिपोर्ट करें';

  @override
  String get contentReportIntro =>
      'मॉडरेटर को बताएँ कि क्या गलत है। जिसकी रिपोर्ट की गई है, उसे यह नहीं बताया जाता कि रिपोर्ट किसने की।';

  @override
  String get contentReportDetailsLabel => 'और जानकारी (वैकल्पिक)';

  @override
  String get contentReportDetailsHelp => 'कार्ड नंबर, PIN या पासवर्ड न लिखें।';

  @override
  String get contentReportSend => 'रिपोर्ट भेजें';

  @override
  String get moderationDoHide => 'छिपाएँ';

  @override
  String get moderationDoRemove => 'हटाएँ';

  @override
  String get moderationDoRestore => 'वापस लाएँ';

  @override
  String get moderationDoPin => 'सबसे ऊपर लगाएँ';

  @override
  String get moderationDoUnpin => 'ऊपर से हटाएँ';

  @override
  String get moderationDoLock => 'टिप्पणियाँ बंद करें';

  @override
  String get moderationDoUnlock => 'टिप्पणियाँ खोलें';

  @override
  String get moderationDoWarn => 'चेतावनी भेजें';

  @override
  String get moderationDoRestrict => 'पोस्टिंग रोकें';

  @override
  String get moderationDoBan => 'समुदाय से प्रतिबंधित करें';

  @override
  String get moderationDoUnban => 'प्रतिबंध हटाएँ';

  @override
  String get moderationDoDismiss => 'रिपोर्ट खारिज करें';

  @override
  String get moderationDoEscalate => 'Montra स्टाफ़ को भेजें';

  @override
  String get moderationChooseAction => 'कार्रवाई चुनें';

  @override
  String get moderationDone => 'हो गया। कार्रवाई मॉडरेशन लॉग में दर्ज हो गई।';

  @override
  String get moderationReasonLabel => 'कारण';

  @override
  String get moderationNoteLabel => 'टिप्पणी (वैकल्पिक)';

  @override
  String get moderationReasonHelp =>
      'प्रभावित व्यक्ति यह कारण देखता है और 30 दिनों के अंदर अपील कर सकता है।';

  @override
  String get moderationDurationLabel => 'कितने समय के लिए';

  @override
  String moderationDuration(String span) {
    String _temp0 = intl.Intl.selectLogic(span, {
      'h1': '1 घंटा',
      'd1': '1 दिन',
      'd3': '3 दिन',
      'w1': '1 हफ़्ता',
      'd30': '30 दिन',
      'other': '$span',
    });
    return '$_temp0';
  }

  @override
  String get communitiesTitle => 'समुदाय';

  @override
  String get communityJoinWithLink => 'लिंक से जुड़ें';

  @override
  String get communitiesTabDiscover => 'खोजें';

  @override
  String get communitiesTabYours => 'आपके';

  @override
  String get communitiesTabInvitations => 'आमंत्रण';

  @override
  String get communityCreate => 'समुदाय शुरू करें';

  @override
  String get communitiesSearchLabel => 'समुदाय खोजें';

  @override
  String get communitiesEmptyTitle => 'अभी दिखाने के लिए कोई समुदाय नहीं';

  @override
  String communitiesNoMatches(String query) {
    return '“$query” से मेल खाता कोई समुदाय नहीं।';
  }

  @override
  String get communitiesEmptyBody =>
      'समुदाय पैसों से जुड़ी सलाह साझा करने और सवाल पूछने की जगह हैं। आप खुद भी एक शुरू कर सकते हैं।';

  @override
  String get communitiesYoursEmptyTitle =>
      'आप अभी तक किसी समुदाय से नहीं जुड़े हैं';

  @override
  String get communitiesYoursEmptyBody =>
      '“खोजें” में कोई समुदाय ढूँढें, या आमंत्रण लिंक से जुड़ें।';

  @override
  String communityJoinedDone(String name) {
    return 'आप $name से जुड़ गए।';
  }

  @override
  String get communityInvitationDeclineTitle => 'यह आमंत्रण अस्वीकार करें?';

  @override
  String communityInvitationDeclineBody(String name) {
    return 'आप $name से नहीं जुड़ेंगे। कोई आपको बाद में फिर से आमंत्रित कर सकता है।';
  }

  @override
  String get communityInvitationDecline => 'अस्वीकार करें';

  @override
  String get communityInvitationDeclined => 'आमंत्रण अस्वीकार किया गया।';

  @override
  String get communityUnnamed => 'एक समुदाय';

  @override
  String get communityInvitationsEmptyTitle => 'कोई आमंत्रण नहीं';

  @override
  String get communityInvitationsEmptyBody =>
      'जब कोई आपके यूज़रनेम से आपको किसी समुदाय में आमंत्रित करता है, तो वह यहाँ दिखता है।';

  @override
  String communityInvitedBy(String name) {
    return '$name ने आमंत्रित किया';
  }

  @override
  String communityInvitationExpires(String date) {
    return '$date तक मान्य';
  }

  @override
  String get communityInvitationAccept => 'जुड़ें';

  @override
  String communityMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count सदस्य',
      one: '1 सदस्य',
    );
    return '$_temp0';
  }

  @override
  String get communityStatusArchived => 'संग्रहित';

  @override
  String get communityStatusSuspended => 'निलंबित';

  @override
  String get communityInvitationStatusActive => 'सक्रिय';

  @override
  String get communityInvitationStatusUsed => 'इस्तेमाल हो चुका';

  @override
  String get communityInvitationStatusDeclined => 'अस्वीकार';

  @override
  String get communityInvitationStatusRevoked => 'वापस लिया गया';

  @override
  String get communityInvitationStatusExpired => 'समय समाप्त';

  @override
  String get communityCreated => 'समुदाय बन गया। आप इसके मालिक हैं।';

  @override
  String get communityCreateTitle => 'नया समुदाय';

  @override
  String get communityCreateIntro =>
      'समुदाय मुफ़्त हैं। माहौल अच्छा रखें: पोस्ट सादा टेक्स्ट होती हैं, और सदस्य कुछ भी गलत लगे तो रिपोर्ट कर सकते हैं।';

  @override
  String get communityNameLabel => 'नाम';

  @override
  String get communitySlugLabel => 'URL नाम (वैकल्पिक)';

  @override
  String get communitySlugHelp =>
      '3–60 छोटे अक्षर, अंक या डैश। बाद में बदला नहीं जा सकता; न देने पर नाम से बनता है।';

  @override
  String get communitySlugInvalid =>
      '3–60 छोटे अक्षर, अंक या डैश इस्तेमाल करें।';

  @override
  String get communityDescriptionLabel => 'यह किस बारे में है (वैकल्पिक)';

  @override
  String get communityRulesLabel => 'समुदाय के नियम (वैकल्पिक)';

  @override
  String get communityRulesHelp =>
      'सदस्य पोस्ट करने से पहले ये नियम देखते हैं।';

  @override
  String get communityTopicsLabel => 'विषय (वैकल्पिक)';

  @override
  String get communityTopicsHelp =>
      'विषयों को कॉमा से अलग करें, जैसे: बचत, बजट';

  @override
  String get communityVisibilityLabel => 'कौन जुड़ सकता है';

  @override
  String get communityJoinLinkInvalid =>
      'यह समुदाय का आमंत्रण लिंक या कोड नहीं है।';

  @override
  String get communityJoinTitle => 'समुदाय से जुड़ें';

  @override
  String get communityJoinIntro =>
      'मिला हुआ आमंत्रण लिंक या कोड चिपकाएँ। जुड़ने से पहले आप देखेंगे कि यह कौन सा समुदाय है।';

  @override
  String get communityJoinLinkLabel => 'आमंत्रण लिंक या कोड';

  @override
  String get communityJoinCheck => 'आमंत्रण जाँचें';

  @override
  String get communityJoinFailedTitle => 'यह आमंत्रण इस्तेमाल नहीं हो सका';

  @override
  String get communityJoinLinkGone =>
      'यह आमंत्रण अब काम नहीं करता: इसका इस्तेमाल हो चुका है, इसे वापस लिया गया है या इसका समय समाप्त हो गया है। नया आमंत्रण माँगें।';

  @override
  String get communityOpen => 'समुदाय खोलें';

  @override
  String communityJoinLinkNotActive(String status) {
    return 'यह आमंत्रण इस्तेमाल नहीं हो सकता: $status।';
  }

  @override
  String get communityJoinDirectly => 'इस आमंत्रण से आप सीधे जुड़ सकते हैं।';

  @override
  String get communityJoin => 'जुड़ें';

  @override
  String get postNew => 'नई पोस्ट';

  @override
  String communityLeaveTitle(String name) {
    return '$name छोड़ें?';
  }

  @override
  String get communityLeaveBody =>
      'आपकी पोस्ट और टिप्पणियाँ बनी रहेंगी। अगर समुदाय अनुमति दे तो आप बाद में फिर जुड़ सकते हैं।';

  @override
  String get communityLeave => 'समुदाय छोड़ें';

  @override
  String get communityLeftDone => 'आपने समुदाय छोड़ दिया।';

  @override
  String get communityMembersTitle => 'सदस्य';

  @override
  String get communitySettingsTitle => 'समुदाय की सेटिंग';

  @override
  String get communityModerationTitle => 'मॉडरेशन';

  @override
  String get communityStartChallenge => 'यहाँ एक चुनौती शुरू करें';

  @override
  String get communityReport => 'समुदाय की रिपोर्ट करें';

  @override
  String get communityJoinRequested =>
      'अनुरोध भेजा गया। मॉडरेटर इसकी समीक्षा करेंगे।';

  @override
  String get communityFeedMembersOnly =>
      'इस समुदाय की पोस्ट केवल सदस्य देखते हैं।';

  @override
  String get communityFeedEmptyTitle => 'अभी कोई पोस्ट नहीं';

  @override
  String communityFeedNoMatches(String query) {
    return '“$query” से मेल खाती कोई पोस्ट नहीं।';
  }

  @override
  String get communityFeedEmptyBody => 'किसी सवाल या सलाह से बातचीत शुरू करें।';

  @override
  String get communityStaffModerates => 'Montra स्टाफ़';

  @override
  String communityTopicsLine(String topics) {
    return 'विषय: $topics';
  }

  @override
  String get communityRulesTitle => 'समुदाय के नियम';

  @override
  String get communityArchivedNote =>
      'यह समुदाय संग्रहित है। आप इसे पढ़ सकते हैं, लेकिन नया कुछ पोस्ट नहीं किया जा सकता।';

  @override
  String get communityPendingNote =>
      'जुड़ने का आपका अनुरोध मॉडरेटर के इंतज़ार में है।';

  @override
  String get communityBannedNote => 'आप इस समुदाय में हिस्सा नहीं ले सकते।';

  @override
  String get communityAskToJoinHelp =>
      'इस समुदाय में कौन जुड़ेगा, यह मॉडरेटर मंज़ूर करते हैं।';

  @override
  String get communityAskToJoin => 'जुड़ने का अनुरोध करें';

  @override
  String get communityFeedTitle => 'पोस्ट';

  @override
  String get communityFeedSortNew => 'नई';

  @override
  String get communityFeedSortTop => 'सबसे पसंदीदा';

  @override
  String get communityFeedSortActive => 'सक्रिय';

  @override
  String get communityFeedSearchLabel => 'पोस्ट खोजें';

  @override
  String postCommentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count टिप्पणियाँ',
      one: '1 टिप्पणी',
      zero: 'कोई टिप्पणी नहीं',
    );
    return '$_temp0';
  }

  @override
  String get postPinned => 'ऊपर लगी';

  @override
  String get postLocked => 'टिप्पणियाँ बंद';

  @override
  String get postHidden => 'मॉडरेटर ने छिपाया';

  @override
  String get postRemoved => 'मॉडरेटर ने हटाया';

  @override
  String get postDeleted => 'हटाई गई';

  @override
  String get postEditTitle => 'पोस्ट बदलें';

  @override
  String get postSaved => 'पोस्ट सहेजी गई।';

  @override
  String get postPublished => 'पोस्ट प्रकाशित हुई।';

  @override
  String get postComposerIntro =>
      'पोस्ट सादा टेक्स्ट होती हैं। कभी भी कार्ड नंबर, PIN, वन-टाइम कोड या पासवर्ड साझा न करें।';

  @override
  String get postKindHeading => 'पोस्ट का प्रकार';

  @override
  String get postLabelHeading => 'लेबल';

  @override
  String get postTitleLabel => 'शीर्षक';

  @override
  String get postBodyLabel => 'टेक्स्ट (वैकल्पिक)';

  @override
  String get postBodyHelp => 'जैसा आप लिखते हैं, ठीक वैसा ही दिखता है।';

  @override
  String get postLinkLabel => 'लिंक';

  @override
  String get postLinkHelp => 'https:// से शुरू होने वाला एक सार्वजनिक वेब लिंक';

  @override
  String get postPollFixed =>
      'पोस्ट करने के बाद पोल का सवाल और विकल्प नहीं बदल सकते।';

  @override
  String get postPublish => 'प्रकाशित करें';

  @override
  String get postPollTitle => 'पोल';

  @override
  String get postPollQuestionLabel => 'सवाल';

  @override
  String postPollOptionLabel(int number) {
    return 'विकल्प $number';
  }

  @override
  String postPollRemoveOption(int number) {
    return 'विकल्प $number हटाएँ';
  }

  @override
  String get postPollAddOption => 'विकल्प जोड़ें';

  @override
  String get postPollAllowMultiple => 'लोग एक से ज़्यादा चुन सकते हैं';

  @override
  String get postPollClosesLabel => 'बंद होने की तारीख़';

  @override
  String get postPollNoEnd => 'खुला रहेगा';

  @override
  String get postTitle => 'पोस्ट';

  @override
  String get postDeleteTitle => 'यह पोस्ट हटाएँ?';

  @override
  String get postDeleteBody =>
      'यह अपनी टिप्पणियों के साथ सबके लिए हट जाएगी। इसे वापस नहीं लाया जा सकता।';

  @override
  String get postDeletedDone => 'पोस्ट हटा दी गई।';

  @override
  String get postOpenCommunity => 'समुदाय खोलें';

  @override
  String get moderationModerate => 'मॉडरेट करें';

  @override
  String get commentPosted => 'टिप्पणी पोस्ट हुई।';

  @override
  String postRemovedReason(String reason) {
    return 'मॉडरेटर का बताया कारण: $reason';
  }

  @override
  String postOpenLink(String host) {
    return 'लिंक खोलें ($host)';
  }

  @override
  String commentsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count टिप्पणियाँ',
      one: '1 टिप्पणी',
      zero: 'टिप्पणियाँ',
    );
    return '$_temp0';
  }

  @override
  String get commentJoinToComment => 'टिप्पणी करने के लिए समुदाय से जुड़ें।';

  @override
  String get commentsEmpty => 'अभी कोई टिप्पणी नहीं।';

  @override
  String commentReplyingTo(String name) {
    return '$name को जवाब';
  }

  @override
  String get commentCancelReply => 'जवाब रद्द करें';

  @override
  String get commentAddLabel => 'आपकी टिप्पणी';

  @override
  String get commentReplyLabel => 'आपका जवाब';

  @override
  String get commentPlainTextHelp => 'सादा टेक्स्ट। विनम्र रहें।';

  @override
  String get commentSend => 'भेजें';

  @override
  String get commentSaved => 'टिप्पणी सहेजी गई।';

  @override
  String get commentDeleteTitle => 'यह टिप्पणी हटाएँ?';

  @override
  String get commentDeleteBody =>
      'इसके जवाब बने रहेंगे। इसे वापस नहीं लाया जा सकता।';

  @override
  String get commentDeletedDone => 'टिप्पणी हटा दी गई।';

  @override
  String get commentActions => 'टिप्पणी के विकल्प';

  @override
  String get commentHiddenLabel =>
      'मॉडरेटर ने छिपाई; इसे केवल आप और मॉडरेटर देखते हैं';

  @override
  String get commentDeletedText => 'यह टिप्पणी हटा दी गई।';

  @override
  String get commentRemovedText => 'यह टिप्पणी मॉडरेटर ने हटा दी।';

  @override
  String get commentReply => 'जवाब दें';

  @override
  String get commentEditTitle => 'टिप्पणी बदलें';

  @override
  String get communitySettingsModeratorsOnly =>
      'केवल मालिक और मॉडरेटर इस समुदाय को संभाल सकते हैं।';

  @override
  String get communityMembersSettingsHelp =>
      'अनुरोध मंज़ूर करें, भूमिकाएँ बदलें, चेतावनी दें या प्रतिबंधित करें।';

  @override
  String get communityModerationSettingsHelp => 'रिपोर्ट, अपील और मॉडरेशन लॉग।';

  @override
  String get communityNothingChanged =>
      'कुछ नहीं बदला, इसलिए सहेजने को कुछ नहीं था।';

  @override
  String get communitySaved => 'समुदाय सहेजा गया।';

  @override
  String get communityDetailsTitle => 'विवरण';

  @override
  String get communityVisibilityOwnerOnly =>
      'कौन जुड़ सकता है, यह केवल मालिक बदल सकते हैं।';

  @override
  String get communityInviteLinkExpiresTitle => 'लिंक कितने समय तक काम करे?';

  @override
  String communityInviteLinkDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count दिन',
      one: '1 दिन',
    );
    return '$_temp0';
  }

  @override
  String communityInviteSent(String username) {
    return '@$username को आमंत्रण भेजा गया।';
  }

  @override
  String get communityInviteUserNotFound =>
      'इस यूज़रनेम वाले किसी व्यक्ति को आमंत्रित नहीं किया जा सकता। लोग अपने सही यूज़रनेम से तभी मिलते हैं जब वे इसकी अनुमति दें।';

  @override
  String get communityInviteRevokeTitle => 'यह आमंत्रण वापस लें?';

  @override
  String get communityInviteRevokeBody =>
      'यह तुरंत काम करना बंद कर देगा। जो पहले से जुड़ चुके हैं, वे सदस्य बने रहेंगे।';

  @override
  String get communityInviteRevoke => 'वापस लें';

  @override
  String get communityInviteRevoked => 'आमंत्रण वापस लिया गया।';

  @override
  String get communityInvitationsTitle => 'आमंत्रण';

  @override
  String get communityInvitationsHelp =>
      'आमंत्रित लोग सीधे जुड़ते हैं, तब भी जब सदस्यों को मॉडरेटर मंज़ूर करते हैं।';

  @override
  String get communityInviteCreateLink => 'आमंत्रण लिंक बनाएँ';

  @override
  String get communityInviteUsernameLabel => 'यूज़रनेम से आमंत्रित करें';

  @override
  String get communityInviteUsernameHelp =>
      'उनका सही यूज़रनेम। वे ऐप में स्वीकार या अस्वीकार करते हैं।';

  @override
  String get communityInviteSend => 'आमंत्रण भेजें';

  @override
  String get communityInvitationsShowInactive =>
      'इस्तेमाल हुए, अस्वीकार, वापस लिए और समाप्त भी दिखाएँ';

  @override
  String get communityInvitationsNone => 'यहाँ कोई आमंत्रण नहीं।';

  @override
  String get communityInviteKindLink => 'आमंत्रण लिंक';

  @override
  String communityInviteKindPerson(String name) {
    return '$name के लिए आमंत्रण';
  }

  @override
  String get communityInviteLinkTitle => 'आपका आमंत्रण';

  @override
  String get communityInviteCodeIntro =>
      'यह कोड साझा करें। लोग समुदाय खोलें, “लिंक से जुड़ें” चुनें और इसे चिपकाएँ। यह केवल एक बार दिखता है।';

  @override
  String get communityInviteLinkIntro =>
      'यह लिंक उन लोगों से साझा करें जिन्हें आप आमंत्रित करना चाहते हैं। यह केवल एक बार दिखता है।';

  @override
  String communityInviteShareCode(String code) {
    return 'Montra पर मेरे समुदाय से जुड़ें: समुदाय खोलें, “लिंक से जुड़ें” चुनें और यह कोड चिपकाएँ: $code';
  }

  @override
  String get communityInviteShare => 'साझा करें';

  @override
  String get communityTransferNobody =>
      'अभी समुदाय सौंपने के लिए कोई दूसरा सदस्य नहीं है।';

  @override
  String get communityTransferChoose => 'नए मालिक चुनें';

  @override
  String communityTransferTitle(String name) {
    return '$name को मालिक बनाएँ?';
  }

  @override
  String communityTransferBody(String name) {
    return '$name समुदाय के मालिक होंगे और आप मॉडरेटर बन जाएँगे। केवल नए मालिक ही इसे वापस दे सकते हैं।';
  }

  @override
  String get communityTransfer => 'मालिकाना हक सौंपें';

  @override
  String communityTransferredDone(String name) {
    return 'अब $name समुदाय के मालिक हैं।';
  }

  @override
  String get communityRestoreTitle => 'यह समुदाय फिर से चालू करें?';

  @override
  String get communityArchiveTitle => 'यह समुदाय संग्रहित करें?';

  @override
  String get communityRestoreBody => 'सदस्य फिर से पोस्ट और टिप्पणी कर सकेंगे।';

  @override
  String get communityArchiveBody =>
      'यह केवल पढ़ने लायक हो जाएगा: कुछ नया पोस्ट नहीं होगा और कोई नया नहीं जुड़ पाएगा। आप इसे बाद में फिर से चालू कर सकते हैं।';

  @override
  String get communityArchive => 'संग्रहित करें';

  @override
  String get communityRestoredDone => 'समुदाय फिर से चालू हुआ।';

  @override
  String get communityArchivedDone => 'समुदाय संग्रहित हुआ।';

  @override
  String get communityOwnerSectionTitle => 'मालिकाना हक';

  @override
  String get communityRestoreHelp =>
      'फिर से चालू करने पर सदस्य दोबारा पोस्ट कर सकेंगे।';

  @override
  String get communityArchiveHelp =>
      'संग्रहित करने पर सब कुछ पढ़ा जा सकता है, पर नई पोस्ट बंद हो जाती हैं।';

  @override
  String get communityMembersFilterActive => 'सदस्य';

  @override
  String get communityMembersFilterPending => 'मंज़ूरी का इंतज़ार';

  @override
  String get communityMembersFilterBanned => 'प्रतिबंधित';

  @override
  String get communityMembersModeratorsOnlyNote =>
      'ये लोग इस समुदाय को मॉडरेट करते हैं।';

  @override
  String get communityMembersNoRequests => 'कोई जुड़ने के इंतज़ार में नहीं है।';

  @override
  String get communityMembersEmpty => 'यहाँ कोई नहीं।';

  @override
  String communityMemberYou(String name) {
    return '$name (आप)';
  }

  @override
  String communityMemberRestrictedUntil(String date) {
    return '$date तक पोस्टिंग रुकी है';
  }

  @override
  String communityMemberApproved(String name) {
    return '$name अब सदस्य हैं।';
  }

  @override
  String get communityMemberApprove => 'मंज़ूर करें';

  @override
  String communityMemberRejected(String name) {
    return '$name का अनुरोध अस्वीकार किया गया।';
  }

  @override
  String get communityMemberReject => 'अस्वीकार करें';

  @override
  String communityMemberActions(String name) {
    return '$name के लिए विकल्प';
  }

  @override
  String communityMemberNowModerator(String name) {
    return '$name अब मॉडरेटर हैं।';
  }

  @override
  String communityMemberNowMember(String name) {
    return '$name अब सदस्य हैं।';
  }

  @override
  String get communityMemberMakeModerator => 'मॉडरेटर बनाएँ';

  @override
  String get communityMemberMakeMember => 'सामान्य सदस्य बनाएँ';

  @override
  String get moderationTabReports => 'रिपोर्ट';

  @override
  String get moderationTabAppeals => 'अपील';

  @override
  String get moderationTabLog => 'लॉग';

  @override
  String get moderationReportsEmptyOpen =>
      'कोई रिपोर्ट इंतज़ार में नहीं। माहौल अच्छा रखने के लिए धन्यवाद।';

  @override
  String get moderationReportsEmpty => 'यहाँ कोई रिपोर्ट नहीं।';

  @override
  String moderationReportHeadline(String target, String reason) {
    return '$target · $reason';
  }

  @override
  String moderationReportPreview(String text) {
    return 'रिपोर्ट किया गया टेक्स्ट: $text';
  }

  @override
  String moderationReportDetails(String text) {
    return 'रिपोर्ट करने वाले ने लिखा: $text';
  }

  @override
  String moderationOpenReports(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'इस पर $count खुली रिपोर्ट',
      one: 'इस पर 1 खुली रिपोर्ट',
      zero: 'कोई और खुली रिपोर्ट नहीं',
    );
    return '$_temp0';
  }

  @override
  String get moderationOpenPost => 'पोस्ट खोलें';

  @override
  String get moderationActOnContent => 'सामग्री पर कार्रवाई';

  @override
  String get moderationActOnAuthor => 'लेखक पर कार्रवाई';

  @override
  String get moderationUpholdTitle => 'फ़ैसला कायम रखें?';

  @override
  String get moderationOverturnTitle => 'फ़ैसला पलटें?';

  @override
  String get moderationUpholdBody =>
      'फ़ैसला कायम रहेगा। व्यक्ति को बताया जाएगा, आपकी टिप्पणी के साथ अगर आप जोड़ें।';

  @override
  String get moderationOverturnBody =>
      'कार्रवाई पलट दी जाएगी। व्यक्ति को बताया जाएगा, आपकी टिप्पणी के साथ अगर आप जोड़ें।';

  @override
  String get moderationUphold => 'फ़ैसला कायम रखें';

  @override
  String get moderationOverturn => 'फ़ैसला पलटें';

  @override
  String get moderationAppealDecided =>
      'अपील पर फ़ैसला हो गया। व्यक्ति को बता दिया गया है।';

  @override
  String get moderationAppealsEmpty => 'कोई खुली अपील नहीं।';

  @override
  String moderationAppealAgainst(String action, String target) {
    return 'इसके ख़िलाफ़ अपील: $action ($target)';
  }

  @override
  String moderationDecisionReason(String reason) {
    return 'कारण: $reason';
  }

  @override
  String moderationAppealStatement(String text) {
    return 'अपील: $text';
  }

  @override
  String get moderationReverseTitle => 'यह कार्रवाई पलटें?';

  @override
  String get moderationReverseBody =>
      'कार्रवाई हट जाएगी। यह लॉग में पलटी गई के रूप में बनी रहेगी।';

  @override
  String get moderationReverse => 'पलटें';

  @override
  String get moderationReversed => 'कार्रवाई पलट दी गई।';

  @override
  String get moderationLogEmpty => 'लॉग में अभी कुछ नहीं।';

  @override
  String moderationLogLine(String action, String target) {
    return '$action · $target';
  }

  @override
  String moderationUntil(String date) {
    return '$date तक';
  }

  @override
  String moderationReversedAt(String date) {
    return '$date को पलटा गया';
  }

  @override
  String get myModerationTitle => 'मॉडरेशन और रिपोर्ट';

  @override
  String get myModerationTabDecisions => 'आपके बारे में';

  @override
  String get myModerationTabAppeals => 'आपकी अपील';

  @override
  String get myModerationTabReports => 'आपकी रिपोर्ट';

  @override
  String get myModerationDecisionsEmptyTitle => 'यहाँ कुछ नहीं';

  @override
  String get myModerationDecisionsEmptyBody =>
      'किसी मॉडरेटर ने आपकी पोस्ट, टिप्पणियों या सदस्यता पर कार्रवाई नहीं की है।';

  @override
  String get myModerationIntro =>
      'मॉडरेटर ने आपकी सामग्री या सदस्यता के बारे में जो फ़ैसले लिए। आप 30 दिनों के अंदर अपील कर सकते हैं; कोई दूसरा मॉडरेटर इसकी समीक्षा करता है।';

  @override
  String get appealSent => 'अपील भेजी गई। आपको नतीजा बताया जाएगा।';

  @override
  String get appealAlreadySent =>
      'आप इस फ़ैसले के ख़िलाफ़ पहले ही अपील कर चुके हैं।';

  @override
  String get myModerationByStaff => 'Montra स्टाफ़ का फ़ैसला';

  @override
  String myModerationEnded(String date) {
    return '$date को समाप्त';
  }

  @override
  String appealDecisionNote(String note) {
    return 'समीक्षक की टिप्पणी: $note';
  }

  @override
  String appealDecidedOn(String date) {
    return '$date को फ़ैसला हुआ';
  }

  @override
  String appealWindow(String date) {
    return 'आप $date तक अपील कर सकते हैं।';
  }

  @override
  String get appealAction => 'अपील करें';

  @override
  String get appealTitle => 'इस फ़ैसले के ख़िलाफ़ अपील करें';

  @override
  String get appealIntro =>
      'बताएँ कि आपको क्यों लगता है कि फ़ैसला बदलना चाहिए। जिस मॉडरेटर ने यह फ़ैसला नहीं लिया, वह आपकी अपील की समीक्षा करेगा।';

  @override
  String get appealStatementLabel => 'आपकी अपील';

  @override
  String get appealSend => 'अपील भेजें';

  @override
  String get myModerationAppealsEmpty => 'आपने कोई अपील नहीं की है।';

  @override
  String appealSentOn(String date) {
    return '$date को भेजी गई';
  }

  @override
  String get myModerationReportsEmpty =>
      'आपने किसी चीज़ की रिपोर्ट नहीं की है।';

  @override
  String get challengesTitle => 'चुनौतियाँ';

  @override
  String get challengesTabMine => 'आपकी';

  @override
  String get challengesTabDiscover => 'किसी से जुड़ें';

  @override
  String get challengeCreate => 'चुनौती शुरू करें';

  @override
  String get challengesMineEmptyTitle => 'अभी कोई चुनौती नहीं';

  @override
  String get challengesMineEmptyBody =>
      'अपने लिए, किसी समूह या समुदाय के लिए एक शुरू करें, या किसी से जुड़ें।';

  @override
  String get challengesDiscoverEmptyTitle => 'अभी जुड़ने के लिए कुछ नहीं';

  @override
  String get challengesDiscoverEmptyBody =>
      'आपके समूहों और समुदायों की चुनौतियाँ यहाँ दिखती हैं।';

  @override
  String challengeParticipants(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count हिस्सा ले रहे हैं',
      one: '1 हिस्सा ले रहे हैं',
      zero: 'अभी कोई नहीं जुड़ा',
    );
    return '$_temp0';
  }

  @override
  String challengeYourProgress(int percent) {
    return '$percent % पूरा';
  }

  @override
  String get challengeCreateTitle => 'नई चुनौती';

  @override
  String get challengeEditTitle => 'चुनौती बदलें';

  @override
  String get challengePickCommunity => 'समुदाय चुनें';

  @override
  String get challengePickCommunityEmpty =>
      'आप अभी किसी समुदाय के सदस्य नहीं हैं।';

  @override
  String get challengeScopeRequired => 'चुनें कि चुनौती कहाँ चलेगी।';

  @override
  String get challengeCreated => 'चुनौती शुरू हुई।';

  @override
  String get challengeCreateIntro =>
      'रोज़ के चेक-इन वाला एक दोस्ताना लक्ष्य। जब तक कोई ख़ुद साझा न करे, प्रगति निजी रहती है।';

  @override
  String get challengeTitleLabel => 'शीर्षक';

  @override
  String get challengeTypeHeading => 'प्रकार';

  @override
  String get challengeMetricHeading => 'प्रगति कैसे गिनी जाती है';

  @override
  String get challengeTargetLabel => 'लक्ष्य';

  @override
  String get challengeTargetPercentHelp => '1 से 100 तक की पूरी संख्या लिखें।';

  @override
  String get challengeTargetInvalid => 'कम से कम 1 की पूरी संख्या लिखें।';

  @override
  String get challengeStartsLabel => 'शुरू होने की तारीख़';

  @override
  String get challengeEndsLabel => 'खत्म होने की तारीख़';

  @override
  String get challengeEndsHelp => 'शुरुआत से अधिकतम एक साल बाद।';

  @override
  String get challengeScopeHeading => 'यह किसके लिए है';

  @override
  String get challengeGroupLabel => 'समूह';

  @override
  String get challengeGroupChosen => 'चुना गया समूह';

  @override
  String get challengeCommunityLabel => 'समुदाय';

  @override
  String get challengeCommunityChosen => 'चुना गया समुदाय';

  @override
  String get challengeLeaderboardLabel => 'लीडरबोर्ड';

  @override
  String get challengeLeaderboardHelp =>
      'इसमें केवल वे लोग होते हैं जो दिखना चुनते हैं, प्रतिशत में, कभी राशि में नहीं।';

  @override
  String get challengePrivateNoLeaderboard =>
      'केवल आपके लिए वाली चुनौती का कोई लीडरबोर्ड नहीं होता।';

  @override
  String get challengeDescriptionLabel => 'विवरण (वैकल्पिक)';

  @override
  String get challengeRulesLabel => 'नियम (वैकल्पिक)';

  @override
  String get challengeNothingChanged =>
      'कुछ नहीं बदला, इसलिए सहेजने को कुछ नहीं था।';

  @override
  String get challengeSaved => 'चुनौती सहेजी गई।';

  @override
  String get challengeEditIntro =>
      'आप शीर्षक, विवरण, नियम और लीडरबोर्ड बदल सकते हैं, और खत्म होने की तारीख़ आगे बढ़ा सकते हैं।';

  @override
  String get challengeEndsLaterHelp =>
      'खत्म होने की तारीख़ केवल आगे बढ़ सकती है, शुरुआत से एक साल के अंदर।';

  @override
  String get challengeCancelTitle => 'यह चुनौती रद्द करें?';

  @override
  String get challengeCancelBody =>
      'अब कोई चेक-इन नहीं कर सकेगा। इसे वापस नहीं लाया जा सकता।';

  @override
  String get challengeCancel => 'चुनौती रद्द करें';

  @override
  String get challengeCancelledDone => 'चुनौती रद्द कर दी गई।';

  @override
  String get challengeNotOpenNote => 'यह चुनौती नए प्रतिभागी नहीं ले रही है।';

  @override
  String get challengeGoalLabel => 'लक्ष्य';

  @override
  String get challengeDatesLabel => 'तारीख़ें';

  @override
  String get challengeParticipantsLabel => 'हिस्सा ले रहे हैं';

  @override
  String get challengeJoinedDone => 'आप चुनौती से जुड़ गए। शुभकामनाएँ!';

  @override
  String get challengeJoinTitle => 'इस चुनौती से जुड़ें';

  @override
  String get challengePrivacyNote =>
      'आपके चेक-इन और टिप्पणियाँ निजी हैं। दूसरे आपकी प्रगति तभी देखते हैं जब आप उसे साझा करें।';

  @override
  String get challengeShareProgress => 'मेरी प्रगति साझा करें';

  @override
  String get challengeShareProgressHelp =>
      'चुनौती में शामिल लोग देखते हैं कि आप कितनी दूर पहुँचे हैं, प्रतिशत में।';

  @override
  String get challengeShowOnLeaderboard => 'लीडरबोर्ड पर दिखें';

  @override
  String get challengeShowOnLeaderboardHelp =>
      'इसके लिए साझा करना ज़रूरी है। केवल वे लोग लीडरबोर्ड देख सकते हैं जो उस पर दिखते हैं।';

  @override
  String get challengeJoin => 'जुड़ें';

  @override
  String get challengeCheckInSaved => 'चेक-इन सहेजा गया।';

  @override
  String get challengeSharingSaved => 'साझा करने की आपकी पसंद सहेजी गई।';

  @override
  String get challengeLeaveTitle => 'यह चुनौती छोड़ें?';

  @override
  String get challengeLeaveBody =>
      'आपकी प्रगति गिनी जाना बंद हो जाएगी और आप लीडरबोर्ड से हट जाएँगे।';

  @override
  String get challengeLeave => 'चुनौती छोड़ें';

  @override
  String get challengeLeftDone => 'आपने चुनौती छोड़ दी।';

  @override
  String get challengeYourProgressTitle => 'आपकी प्रगति';

  @override
  String challengeProgressLine(int value, String target) {
    return '$target में से $value';
  }

  @override
  String challengeStreaks(int current, int best) {
    return 'मौजूदा सिलसिला: $current · सबसे अच्छा: $best';
  }

  @override
  String challengeCompletedOn(String date) {
    return '$date को पूरी हुई';
  }

  @override
  String get challengeMilestoneReached => 'पूरा हुआ';

  @override
  String get challengeMilestoneAhead => 'अभी नहीं';

  @override
  String get challengeCheckInTitle => 'चेक-इन करें';

  @override
  String get challengeCheckInHelp =>
      'उसी दिन के लिए फिर से चेक-इन करने पर वह सुधर जाता है।';

  @override
  String get challengeCheckInDate => 'दिन';

  @override
  String get challengeCheckInDone => 'पूरा किया';

  @override
  String get challengeCheckInMissed => 'छूट गया';

  @override
  String get challengeCheckInPercent => 'आप कितनी दूर पहुँचे (0–100 %)';

  @override
  String get challengeCheckInCount => 'कितने';

  @override
  String get challengeCheckInNote => 'टिप्पणी (वैकल्पिक)';

  @override
  String get challengeCheckInNoteHelp => 'यह टिप्पणी केवल आप देखते हैं।';

  @override
  String get challengeCheckIn => 'चेक-इन सहेजें';

  @override
  String get challengeSharingTitle => 'आप क्या साझा करते हैं';

  @override
  String get challengeLeaderboardEmpty => 'अभी लीडरबोर्ड पर कोई नहीं है।';

  @override
  String challengeLeaderboardYou(String name) {
    return '$name (आप)';
  }

  @override
  String challengeStreakNow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count दिन का सिलसिला',
      one: '1 दिन का सिलसिला',
    );
    return '$_temp0';
  }

  @override
  String get challengeLeaderboardNote =>
      'केवल लक्ष्य का प्रतिशत; राशियाँ और टिप्पणियाँ कभी नहीं दिखतीं।';

  @override
  String get challengeLeaderboardTitle => 'लीडरबोर्ड';

  @override
  String get entryConnectAccount => 'बैंक से जोड़ें';

  @override
  String get gxExpensesTitle => 'साझा खर्च';

  @override
  String gxExpensesTitleOf(String group) {
    return 'खर्च · $group';
  }

  @override
  String get gxExpenseTitle => 'खर्च';

  @override
  String get gxBalancesTitle => 'बकाया';

  @override
  String get gxSettlementsTitle => 'भुगतान';

  @override
  String get gxSettlementTitle => 'भुगतान';

  @override
  String get gxRecurringTitle => 'दोहराए जाने वाले खर्च';

  @override
  String get gxReportsTitle => 'समूह रिपोर्ट';

  @override
  String get gxMoreScreens => 'और';

  @override
  String get gxArchivedReadOnly =>
      'यह समूह संग्रहीत है, इसलिए कुछ जोड़ा या बदला नहीं जा सकता।';

  @override
  String get gxYou => 'आप';

  @override
  String get gxFormerMember => 'पूर्व सदस्य';

  @override
  String get gxMemberLeft => 'छोड़ चुके';

  @override
  String get gxMemberRemoved => 'हटाए गए';

  @override
  String get gxNoOneToPick => 'चुनने के लिए कोई और नहीं है।';

  @override
  String get gxStatusActive => 'सक्रिय';

  @override
  String get gxStatusDisputed => 'आपत्ति दर्ज';

  @override
  String get gxStatusDeleted => 'हटाया गया';

  @override
  String get gxStatusOther => 'अन्य';

  @override
  String get gxSplitEqual => 'बराबर';

  @override
  String get gxSplitExact => 'सटीक राशि';

  @override
  String get gxSplitPercentage => 'प्रतिशत';

  @override
  String get gxSplitShares => 'हिस्से';

  @override
  String get gxSplitItemized => 'चीज़ों के हिसाब से';

  @override
  String get gxSplitOther => 'अन्य बँटवारा';

  @override
  String get gxSplitEqualHelp => 'चुने गए सभी लोग बराबर हिस्सा देते हैं।';

  @override
  String get gxSplitExactHelp =>
      'हर व्यक्ति की राशि लिखें। राशियाँ कुल राशि के बराबर होनी चाहिए।';

  @override
  String get gxSplitPercentageHelp =>
      'हर व्यक्ति का प्रतिशत लिखें (दशमलव के बाद 2 अंक तक)। कुल 100% होना चाहिए।';

  @override
  String get gxSplitSharesHelp =>
      'हर व्यक्ति को पूरे अंकों में हिस्से दें, जैसे किसी जोड़े के लिए 2।';

  @override
  String get gxSplitItemizedHelp =>
      'चीज़ें और उन्हें बाँटने वाले लोग लिखें। टैक्स, टिप या राउंडिंग (कुल राशि में से चीज़ों का जोड़ घटाकर) अनुपात में बाँटा जाता है।';

  @override
  String get gxSplitSection => 'बँटवारा';

  @override
  String get gxSplitMethodLabel => 'कैसे बाँटा गया';

  @override
  String get gxSplitNeedsPeople =>
      'इसे बाँटने के लिए कम से कम एक व्यक्ति चुनें।';

  @override
  String gxPercentValue(String value) {
    return '$value %';
  }

  @override
  String gxSharesValue(String value) {
    return '$value हिस्से';
  }

  @override
  String get gxSharesEqually => 'बराबर हिस्सा';

  @override
  String gxValueAmountFor(String name) {
    return '$name की राशि';
  }

  @override
  String gxValuePercentFor(String name) {
    return '$name का प्रतिशत';
  }

  @override
  String gxValueSharesFor(String name) {
    return '$name के हिस्से';
  }

  @override
  String get gxPercentInvalid =>
      '100 तक का प्रतिशत लिखें, दशमलव के बाद 2 अंक तक।';

  @override
  String get gxSharesInvalid => '0 से बड़ी पूरी संख्या लिखें।';

  @override
  String gxPreview(String text) {
    return 'पूर्वावलोकन (अंतिम बँटवारा सर्वर तय करता है): $text';
  }

  @override
  String gxPreviewPeople(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count लोगों में बराबर',
      one: '1 व्यक्ति के बीच',
    );
    return '$_temp0';
  }

  @override
  String get gxPreviewPercentOk => 'प्रतिशत का जोड़ 100% है।';

  @override
  String gxPreviewPercentTotal(String total) {
    return 'प्रतिशत का जोड़ $total% है, 100% नहीं।';
  }

  @override
  String gxPreviewShares(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'कुल $count हिस्से।',
      one: 'कुल 1 हिस्सा।',
    );
    return '$_temp0';
  }

  @override
  String gxPreviewAssigned(String assigned) {
    return '$assigned बाँटा गया।';
  }

  @override
  String get gxPreviewExactOk => 'राशियों का जोड़ कुल राशि के बराबर है।';

  @override
  String get gxPreviewPayersOk => 'भुगतानों का जोड़ कुल राशि के बराबर है।';

  @override
  String gxPreviewLeft(String assigned, String left) {
    return 'अब तक $assigned, $left बाकी।';
  }

  @override
  String gxPreviewTooMuch(String assigned, String over) {
    return 'अब तक $assigned, कुल राशि से $over ज़्यादा।';
  }

  @override
  String get gxAddExpense => 'खर्च जोड़ें';

  @override
  String get gxEditExpense => 'खर्च बदलें';

  @override
  String get gxFilterAll => 'सभी';

  @override
  String get gxFilterPayer => 'किसने चुकाया';

  @override
  String gxFilterPaidBy(String name) {
    return '$name ने चुकाया';
  }

  @override
  String get gxFilterCategory => 'श्रेणी';

  @override
  String get gxFilterDates => 'तारीख़ें';

  @override
  String get gxExpensesEmptyTitle => 'अभी कोई साझा खर्च नहीं';

  @override
  String get gxExpensesEmptyBody =>
      'समूह के लिए किसी ने जो चुकाया वह जोड़ें, और Montra बताएगा कि किसका किस पर कितना बकाया है।';

  @override
  String get gxExpensesEmptyFiltered => 'इन फ़िल्टरों से कुछ नहीं मिला';

  @override
  String gxExpenseLine(String date, String category) {
    return '$date · $category';
  }

  @override
  String gxYouPaidShare(String paid, String share) {
    return 'आपने चुकाया $paid · आपका हिस्सा $share';
  }

  @override
  String gxPaidInOriginal(String amount) {
    return '$amount में चुकाया';
  }

  @override
  String get gxDescriptionHelp => 'यह किस लिए था? जैसे: खाना, किराना, टैक्सी।';

  @override
  String get gxAmountSection => 'राशि';

  @override
  String get gxForeignLabel => 'किसी दूसरी मुद्रा में चुकाया';

  @override
  String gxForeignHelp(String currency) {
    return 'जो चुकाया वह लिखें; Montra उसे $currency में बदलेगा।';
  }

  @override
  String get gxOriginalCurrency => 'चुकाने की मुद्रा';

  @override
  String get gxOriginalAmount => 'चुकाई गई राशि';

  @override
  String get gxRateLookup => 'उस तारीख़ के लिए Montra की दर लें';

  @override
  String get gxRateLookupHelp =>
      'उस दिन के लिए आपकी सहेजी दर पहले ली जाती है, फिर प्रकाशित दर।';

  @override
  String get gxRateManual => 'मेरी इस्तेमाल की गई दर लिखें';

  @override
  String gxRateManualHelp(String currency) {
    return 'एक इकाई कितने $currency की पड़ी, जैसे आपके कार्ड स्टेटमेंट से।';
  }

  @override
  String gxRateLabel(String currency, String group) {
    return '$currency 1 = ? $group';
  }

  @override
  String get gxRateInvalid => 'शून्य से बड़ी दर लिखें, जैसे 83.25।';

  @override
  String gxForeignServerAmount(String currency) {
    return 'Montra दर से $currency में राशि निकालेगा और सहेजने के बाद दिखाएगा।';
  }

  @override
  String get gxChooseCurrency => 'वह मुद्रा चुनें जिसमें आपने चुकाया।';

  @override
  String get gxDateToday => 'आज (समूह के समय क्षेत्र के अनुसार)';

  @override
  String get gxItemsSection => 'चीज़ें';

  @override
  String get gxItemsHelp =>
      'चीज़ों की राशि समूह की मुद्रा में है। हर चीज़ किसने बाँटी, चुनें।';

  @override
  String gxItemName(int number) {
    return 'चीज़ $number';
  }

  @override
  String get gxItemAmount => 'चीज़ की राशि';

  @override
  String get gxItemSharedBy => 'किसने बाँटा';

  @override
  String get gxItemRemove => 'चीज़ हटाएँ';

  @override
  String get gxItemAdd => 'चीज़ जोड़ें';

  @override
  String get gxItemNeedsPeople => 'हर चीज़ किसने बाँटी, चुनें।';

  @override
  String get gxWhoPaid => 'किसने चुकाया';

  @override
  String get gxPayerYou => 'मैंने चुकाया';

  @override
  String get gxPayerOne => 'किसी और ने चुकाया';

  @override
  String get gxPayerSeveral => 'कई लोगों ने चुकाया';

  @override
  String gxPaidBy(String name) {
    return '$name ने चुकाया';
  }

  @override
  String get gxChoosePayer => 'चुनें किसने चुकाया।';

  @override
  String gxForeignPayerNote(String currency) {
    return 'कई चुकाने वालों के लिए राशि $currency में चाहिए: भुगतान बाँटना हो तो राशि $currency में लिखें।';
  }

  @override
  String get gxRecordInAccount => 'मेरा भुगतान किसी खाते में दर्ज करें';

  @override
  String get gxRecordInAccountHelp =>
      'आपके खर्च में केवल आपका हिस्सा गिना जाता है।';

  @override
  String get gxMoreSection => 'और जानकारी';

  @override
  String get gxAttachReceipt => 'रसीद जोड़ें';

  @override
  String get gxReceiptAttached => 'रसीद जुड़ी है';

  @override
  String get gxReceiptHelp => 'समूह के सदस्य इसे देख सकते हैं।';

  @override
  String get gxReceiptRemove => 'फ़ाइल हटाएँ';

  @override
  String gxFormerParticipants(String names) {
    return '$names अब समूह में नहीं हैं। सहेजने पर वे बँटवारे से बाहर हो जाएँगे।';
  }

  @override
  String get gxExpenseAdded => 'खर्च जोड़ा गया।';

  @override
  String get gxExpenseSaved => 'खर्च सहेजा गया।';

  @override
  String get gxDeletedNotice =>
      'यह खर्च हटा दिया गया। अब यह बकाया में नहीं गिना जाता।';

  @override
  String get gxDisputedNotice =>
      'किसी ने इस खर्च पर आपत्ति की है। आपत्ति सुलझने या खर्च बदलने/हटाने तक यह गिना जाता है।';

  @override
  String get gxYourShare => 'आपका हिस्सा';

  @override
  String get gxYouPaid => 'आपने चुकाया';

  @override
  String get gxHistory => 'इतिहास';

  @override
  String gxEditedTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count बार बदला गया',
      one: 'एक बार बदला गया',
    );
    return '$_temp0';
  }

  @override
  String get gxForeignTitle => 'दूसरी मुद्रा';

  @override
  String get gxRateUsed => 'इस्तेमाल की गई दर';

  @override
  String gxRateValue(String from, String rate, String to) {
    return '1 $from = $rate $to';
  }

  @override
  String get gxRateSource => 'दर का स्रोत';

  @override
  String get gxRateTime => 'दर का समय';

  @override
  String get gxConverted => 'समूह की मुद्रा में';

  @override
  String get gxFxSourceManual => 'सदस्य ने लिखी';

  @override
  String get gxFxSourceEcb => 'यूरोपियन सेंट्रल बैंक';

  @override
  String get gxFxSourceProvider => 'दर प्रदाता';

  @override
  String get gxFxSourceOther => 'अन्य स्रोत';

  @override
  String get gxPaidBySection => 'किसने चुकाया';

  @override
  String get gxSharesSection => 'हिस्से';

  @override
  String get gxSharesByServer =>
      'हिस्से Montra सटीक रूप से निकालता है, आख़िरी पैसे तक।';

  @override
  String get gxReceipt => 'रसीद';

  @override
  String get gxRecordedInAccount => 'आपके खाते में दर्ज';

  @override
  String get gxRecordedInAccountHelp =>
      'आपका भुगतान आपके लेन-देन में है; इस खर्च के बदलाव उसमें भी आते हैं।';

  @override
  String get gxRecorded => 'आपके खाते में दर्ज किया गया।';

  @override
  String get gxUnlink => 'मेरे खाते से हटाएँ';

  @override
  String get gxUnlinkTitle => 'अपने खाते का रिकॉर्ड हटाएँ?';

  @override
  String get gxUnlinkBody =>
      'आपके खाते का लेन-देन हट जाएगा। समूह का खर्च वैसा ही रहेगा।';

  @override
  String get gxUnlinkSettlementBody =>
      'आपके खाते का लेन-देन हट जाएगा। भुगतान समूह में दर्ज रहेगा।';

  @override
  String get gxUnlinked => 'आपके खाते से हटाया गया।';

  @override
  String get gxDeleteTitle => 'यह खर्च हटाएँ?';

  @override
  String gxDeleteBody(String name) {
    return '\"$name\" अब बकाया में नहीं गिना जाएगा। सदस्य इसे हटाया हुआ देखेंगे।';
  }

  @override
  String get gxExpenseDeleted => 'खर्च हटाया गया।';

  @override
  String get gxDisputesSection => 'आपत्तियाँ';

  @override
  String get gxNoDisputes => 'इस खर्च पर किसी ने आपत्ति नहीं की।';

  @override
  String get gxDispute => 'कुछ गलत है';

  @override
  String get gxDisputeTitle => 'क्या गलत है?';

  @override
  String get gxDisputeBody =>
      'सदस्य आपकी बात देखेंगे। ठीक होने तक खर्च गिना जाता रहेगा।';

  @override
  String get gxDisputeReason => 'क्या गलत है';

  @override
  String get gxDisputeSend => 'भेजें';

  @override
  String get gxDisputeSent => 'आपकी बात समूह को भेज दी गई।';

  @override
  String get gxDisputeOpen => 'खुली';

  @override
  String get gxDisputeResolved => 'सुलझी';

  @override
  String get gxDisputeWithdrawn => 'वापस ली गई';

  @override
  String gxRaisedBy(String name) {
    return '$name ने उठाई';
  }

  @override
  String gxResolutionText(String text) {
    return 'समाधान: $text';
  }

  @override
  String get gxWithdraw => 'वापस लें';

  @override
  String get gxWithdrawTitle => 'अपनी आपत्ति वापस लें?';

  @override
  String get gxWithdrawBody => 'खर्च वैसा ही रहेगा।';

  @override
  String get gxWithdrawn => 'आपत्ति वापस ली गई।';

  @override
  String get gxResolve => 'सुलझाएँ';

  @override
  String get gxResolveTitle => 'यह आपत्ति सुलझाएँ';

  @override
  String get gxResolveBody =>
      'बताएँ कि क्या तय हुआ। कुछ बदलना हो तो पहले खर्च बदलें।';

  @override
  String get gxResolution => 'क्या तय हुआ';

  @override
  String get gxResolved => 'आपत्ति सुलझाई गई।';

  @override
  String get gxCommentsSection => 'टिप्पणियाँ';

  @override
  String get gxNoComments => 'अभी कोई टिप्पणी नहीं।';

  @override
  String get gxCommentLabel => 'टिप्पणी जोड़ें';

  @override
  String get gxCommentSend => 'भेजें';

  @override
  String get gxCommentSent => 'टिप्पणी जोड़ी गई।';

  @override
  String get gxYourBalance => 'आपका बकाया';

  @override
  String gxYouAreOwed(String amount) {
    return 'आपको $amount मिलने हैं';
  }

  @override
  String gxYouOwe(String amount) {
    return 'आपको $amount देने हैं';
  }

  @override
  String get gxYouSettled => 'आपका हिसाब बराबर है';

  @override
  String gxIsOwed(String name, String amount) {
    return '$name को $amount मिलने हैं';
  }

  @override
  String gxOwes(String name, String amount) {
    return '$name को $amount देने हैं';
  }

  @override
  String gxSettled(String name) {
    return '$name का हिसाब बराबर है';
  }

  @override
  String gxComputedAt(String time) {
    return '$time पर निकाला गया';
  }

  @override
  String gxDisputedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'आपत्ति वाले $count खर्च सुलझने, बदलने या हटने तक गिने जाते हैं।',
      one: 'आपत्ति वाला 1 खर्च सुलझने, बदलने या हटने तक गिना जाता है।',
    );
    return '$_temp0';
  }

  @override
  String get gxSuggestionsTitle => 'सुझाए गए भुगतान';

  @override
  String get gxSuggestionsHelp =>
      'ये केवल सुझाव हैं। Montra पैसे नहीं भेजता; Montra के बाहर भुगतान करने के बाद उसे दर्ज करें।';

  @override
  String get gxOnlyMine => 'सिर्फ़ मेरे';

  @override
  String get gxNoSuggestionsMine => 'आपको कुछ देना या लेना नहीं है।';

  @override
  String get gxNothingOwed => 'सबका हिसाब बराबर है।';

  @override
  String get gxWhoOwesWhom => 'किसका किस पर बकाया';

  @override
  String get gxDebtsSimplified => 'सबसे कम भुगतान';

  @override
  String get gxDebtsOriginal => 'जैसा दर्ज है';

  @override
  String get gxDebtsSimplifiedHelp =>
      'सबका हिसाब बराबर करने वाले सबसे कम भुगतान। दोनों तरीकों का कुल बकाया एक जैसा है।';

  @override
  String get gxDebtsOriginalHelp =>
      'खर्चों के हिसाब से हर व्यक्ति का दूसरे पर बकाया, हर जोड़ी के लिए घटाकर।';

  @override
  String gxPays(String from, String to) {
    return '$from → $to को देना';
  }

  @override
  String get gxInvolvesYou => 'इसमें आप शामिल हैं';

  @override
  String gxRecordThisPayment(String from, String to, String amount) {
    return '$from से $to को $amount का भुगतान दर्ज करें';
  }

  @override
  String get gxMembersSection => 'सदस्य';

  @override
  String get gxBalancePaid => 'समूह के लिए चुकाया';

  @override
  String get gxBalanceShare => 'खर्चों में हिस्सा';

  @override
  String get gxBalanceSent => 'किए गए भुगतान (पुष्ट)';

  @override
  String get gxBalanceReceived => 'मिले भुगतान (पुष्ट)';

  @override
  String get gxBalancePendingOut => 'बताया गया, पुष्टि बाकी';

  @override
  String get gxBalancePendingIn => 'पुष्टि करनी है';

  @override
  String get gxFormerBalanceNote =>
      'उनका बकाया समूह में बना रहता है। कोई भी उनके साथ भुगतान दर्ज कर सकता है, और उन्हें किए गए भुगतान की पुष्टि एडमिन करते हैं।';

  @override
  String get gxNoMoneyMoves =>
      'Montra कभी पैसे नहीं भेजता। यहाँ के भुगतान Montra के बाहर किए गए भुगतानों का रिकॉर्ड हैं।';

  @override
  String get gxRecordPayment => 'भुगतान दर्ज करें';

  @override
  String get gxShowVoided => 'रद्द किए हुए दिखाएँ';

  @override
  String get gxSettlementsHelp => 'बकाया में केवल पुष्ट भुगतान गिने जाते हैं।';

  @override
  String get gxSettlementsEmptyTitle => 'अभी कोई भुगतान नहीं';

  @override
  String get gxSettlementsEmptyBody =>
      'जब कोई पैसे लौटाए, यहाँ दर्ज करें ताकि बकाया सही रहे।';

  @override
  String gxPaid(String from, String to) {
    return '$from ने $to को चुकाया';
  }

  @override
  String get gxSettlementProposed => 'योजना में';

  @override
  String get gxSettlementReported => 'पुष्टि का इंतज़ार';

  @override
  String get gxSettlementConfirmed => 'पुष्ट';

  @override
  String get gxSettlementDisputed => 'आपत्ति दर्ज';

  @override
  String get gxSettlementVoided => 'रद्द';

  @override
  String get gxMethodCash => 'नकद';

  @override
  String get gxMethodBank => 'बैंक ट्रांसफ़र';

  @override
  String get gxMethodUpi => 'UPI';

  @override
  String get gxMethodOther => 'अन्य';

  @override
  String get gxMethodLabel => 'कैसे चुकाया';

  @override
  String get gxWhoReceived => 'किसे मिला';

  @override
  String get gxWhoPays => 'कौन चुकाएगा';

  @override
  String get gxRecordIntro =>
      'Montra कभी पैसे नहीं भेजता। नकद, बैंक ट्रांसफ़र या UPI से किया गया भुगतान दर्ज करें; दूसरा व्यक्ति पुष्टि करता है, फिर यह बकाया में गिना जाता है।';

  @override
  String get gxCorrectIntro =>
      'सुधार सही भुगतान दर्ज करता है और पुराना रद्द करता है। दोनों इतिहास में रहते हैं।';

  @override
  String get gxCorrectTitle => 'यह भुगतान सुधारें';

  @override
  String get gxCorrectButton => 'सुधार सहेजें';

  @override
  String get gxCorrect => 'सुधारें';

  @override
  String get gxPartialAllowed => 'आंशिक भुगतान भी ठीक है।';

  @override
  String get gxProposedLabel => 'अभी चुकाया नहीं';

  @override
  String get gxProposedHelp =>
      'इसे योजना या अनुरोध के रूप में दर्ज करें; चुकाने वाला बाद में चुकाया चिह्नित करेगा।';

  @override
  String get gxFormerPayeeNote =>
      'वे अब सदस्य नहीं हैं, इसलिए समूह के एडमिन उनके लिए इस भुगतान की पुष्टि करेंगे।';

  @override
  String get gxSettlementAccountHelp =>
      'भुगतान को आपके खाते में बाहर गए पैसे के रूप में जोड़ता है (खर्च नहीं)।';

  @override
  String get gxAttachProof => 'सबूत जोड़ें (वैकल्पिक)';

  @override
  String get gxPaymentRecorded => 'भुगतान दर्ज किया गया।';

  @override
  String get gxCorrected => 'भुगतान सुधारा गया।';

  @override
  String get gxVerification => 'जाँच';

  @override
  String get gxReportedByMembers => 'सदस्यों द्वारा बताया गया';

  @override
  String get gxVerifiedByProvider => 'भुगतान प्रदाता द्वारा सत्यापित';

  @override
  String get gxCounts => 'बकाया में गिना जाता है';

  @override
  String get gxCountsYes => 'हाँ';

  @override
  String get gxCountsNo => 'अभी नहीं';

  @override
  String get gxRecordedBy => 'किसने दर्ज किया';

  @override
  String get gxConfirmedBy => 'किसने पुष्टि की';

  @override
  String get gxDisputeReasonLabel => 'आपत्ति';

  @override
  String get gxVoidReasonLabel => 'रद्द करने का कारण';

  @override
  String get gxCorrectsOriginal => 'यह पहले के भुगतान का सुधार है';

  @override
  String get gxCorrectedBy => 'सुधारा गया भुगतान देखें';

  @override
  String get gxProof => 'भुगतान का सबूत';

  @override
  String get gxSettlementRecordedHelp => 'यह भुगतान आपके लेन-देन में है।';

  @override
  String get gxProposedStatusHelp =>
      'योजना में। पैसा भेजने के बाद चुकाने वाला इसे चुकाया चिह्नित करता है।';

  @override
  String get gxReportedStatusHelp =>
      'चुकाया बताया गया। पाने वाले की पुष्टि के बाद गिना जाएगा।';

  @override
  String get gxConfirmedStatusHelp =>
      'पाने वाले ने पुष्टि की। यह बकाया में गिना जाता है।';

  @override
  String get gxDisputedStatusHelp =>
      'किसी ने कहा कि यह सही नहीं है। पाने वाले की पुष्टि या किसी के रद्द करने पर यह खत्म होगा।';

  @override
  String get gxVoidedStatusHelp => 'रद्द। अब यह नहीं गिना जाता।';

  @override
  String get gxSettlementMarkPaid => 'चुकाया चिह्नित करें';

  @override
  String get gxSettlementConfirm => 'पुष्टि करें कि मुझे मिला';

  @override
  String get gxSettlementDispute => 'आपत्ति करें';

  @override
  String get gxSettlementVoid => 'रद्द करें';

  @override
  String get gxSettlementDisputeTitle => 'इस भुगतान पर आपत्ति करें?';

  @override
  String get gxSettlementDisputeBody =>
      'बताएँ क्या गलत है। पाने वाले की दोबारा पुष्टि तक यह नहीं गिना जाएगा।';

  @override
  String get gxSettlementVoidTitle => 'यह भुगतान रद्द करें?';

  @override
  String get gxSettlementVoidBody =>
      'यह इतिहास में रहेगा पर अब नहीं गिना जाएगा। कारण बताएँ।';

  @override
  String get gxReasonLabel => 'कारण';

  @override
  String get gxConfirmTitle => 'इस भुगतान की पुष्टि करें?';

  @override
  String gxConfirmBody(String amount) {
    return 'पुष्टि तभी करें जब आपको $amount मिल गए हों। फिर यह बकाया में गिना जाएगा।';
  }

  @override
  String get gxConfirmOnBehalfBody =>
      'पाने वाले अब सदस्य नहीं हैं, इसलिए एडमिन के रूप में आप पुष्टि कर रहे हैं। पुष्टि तभी करें जब आपको पता हो कि पैसा पहुँच गया।';

  @override
  String get gxMarkPaidTitle => 'चुकाया चिह्नित करें?';

  @override
  String get gxMarkPaidBody =>
      'पैसा भेजने के बाद ही यह करें। फिर दूसरा व्यक्ति पुष्टि करेगा।';

  @override
  String get gxMarkedPaid => 'चुकाया चिह्नित किया गया।';

  @override
  String get gxConfirmed => 'भुगतान की पुष्टि हुई।';

  @override
  String get gxDisputed => 'भुगतान पर आपत्ति दर्ज हुई।';

  @override
  String get gxVoided => 'भुगतान रद्द किया गया।';

  @override
  String get gxRecurringAdd => 'दोहराया जाने वाला खर्च जोड़ें';

  @override
  String get gxRecurringEdit => 'दोहराया जाने वाला खर्च बदलें';

  @override
  String get gxRecurringEmptyTitle => 'कोई दोहराया जाने वाला खर्च नहीं';

  @override
  String get gxRecurringEmptyBody =>
      'किराया, सफ़ाई या साझा सब्सक्रिप्शन एक बार सेट करें, और हर बार देय होने पर जोड़ें।';

  @override
  String get gxRecurringName => 'नाम';

  @override
  String get gxRecurringNameHelp => 'जैसे: किराया, सफ़ाई, इंटरनेट।';

  @override
  String get gxRecurringAmount => 'हर बार की राशि';

  @override
  String get gxRecurringDescriptionHelp =>
      'हर खर्च का विवरण (डिफ़ॉल्ट रूप से नाम)।';

  @override
  String get gxScheduleSection => 'समय-सारणी';

  @override
  String get gxScheduleDates => 'तारीख़ें';

  @override
  String get gxScheduleFixed =>
      'समय-सारणी नहीं बदल सकती। बदलने के लिए इसे रोकें और नया जोड़ें।';

  @override
  String get gxAutoAddLabel => 'देय होने पर अपने-आप जोड़ें';

  @override
  String get gxAutoAddHelp => 'वरना देय होने पर कोई भी सदस्य इसे जोड़ता है।';

  @override
  String get gxAutoAddOn => 'अपने-आप जुड़ता है';

  @override
  String get gxAutoAddOff => 'देय होने पर सदस्य जोड़ते हैं';

  @override
  String get gxPayerAdder => 'जो जोड़ेगा';

  @override
  String get gxPayerAdderHelp =>
      'जो खर्च जोड़ता है वही चुकाता है (अपने-आप जुड़ने पर बनाने वाला)।';

  @override
  String get gxRecurringAdded => 'दोहराया जाने वाला खर्च जोड़ा गया।';

  @override
  String get gxRecurringSaved => 'दोहराया जाने वाला खर्च सहेजा गया।';

  @override
  String gxNextOn(String date) {
    return 'अगला: $date';
  }

  @override
  String get gxNextLabel => 'अगला';

  @override
  String get gxCreatedBy => 'किसने सेट किया';

  @override
  String get gxOccurrencesTitle => 'बारियाँ';

  @override
  String get gxOccurrencesEmpty => 'कुछ तय नहीं है।';

  @override
  String get gxOccurrenceAdd => 'खर्च अभी जोड़ें';

  @override
  String get gxOccurrenceAddTitle => 'यह खर्च जोड़ें?';

  @override
  String gxOccurrenceAddBody(String name, String date) {
    return '$name, देय $date। जब तक बँटवारे में चुकाने वाले तय न हों, आपको चुकाने वाला माना जाएगा।';
  }

  @override
  String get gxOccurrenceAdded => 'खर्च जोड़ा गया।';

  @override
  String get gxOccurrenceSkipped => 'छोड़ दिया गया।';

  @override
  String get gxOpenExpense => 'खर्च खोलें';

  @override
  String get gxRecurringStopTitle => 'यह दोहराया जाने वाला खर्च रोकें?';

  @override
  String gxRecurringStopBody(String name) {
    return '$name के आगे के खर्च तय नहीं होंगे। पहले जोड़े गए खर्च बने रहेंगे।';
  }

  @override
  String get gxAllTime => 'अब तक का सब';

  @override
  String get gxReportPeriod => 'रिपोर्ट की अवधि';

  @override
  String get gxReportEmptyTitle => 'अभी रिपोर्ट के लिए कुछ नहीं';

  @override
  String get gxReportEmptyBody => 'इस अवधि में कोई खर्च नहीं है।';

  @override
  String get gxReportSummary => 'सारांश';

  @override
  String get gxTotalSpent => 'कुल खर्च';

  @override
  String get gxExpenseCount => 'खर्च';

  @override
  String gxExpensesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count खर्च',
      one: '1 खर्च',
    );
    return '$_temp0';
  }

  @override
  String get gxDisputedLabel => 'आपत्ति वाले';

  @override
  String get gxParticipants => 'बाँटने वाले लोग';

  @override
  String gxPeopleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count लोग',
      one: '1 व्यक्ति',
    );
    return '$_temp0';
  }

  @override
  String get gxPerPerson => 'प्रति व्यक्ति औसत';

  @override
  String get gxTripTitle => 'यात्रा';

  @override
  String get gxDestination => 'गंतव्य';

  @override
  String get gxTripDates => 'तारीख़ें';

  @override
  String get gxTripDays => 'अवधि';

  @override
  String gxDaysCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count दिन',
      one: '1 दिन',
    );
    return '$_temp0';
  }

  @override
  String get gxDailyAverage => 'प्रति दिन औसत';

  @override
  String get gxByCategory => 'श्रेणी के अनुसार';

  @override
  String get gxByMember => 'व्यक्ति के अनुसार';

  @override
  String get gxByMonth => 'महीने के अनुसार';

  @override
  String gxMemberPaidShare(String paid, String share) {
    return 'चुकाया $paid · हिस्सा $share';
  }

  @override
  String gxChartSummary(String label, String amount) {
    return 'सबसे बड़ा: $label, $amount।';
  }

  @override
  String get gxOriginalCurrencies => 'दूसरी मुद्राओं में चुकाया';

  @override
  String gxOriginalConverted(String original, String converted) {
    return '$original → $converted';
  }

  @override
  String get gxOriginalCurrenciesHelp => 'हर खर्च की अपनी दर से बदला गया।';

  @override
  String get gxSettlementsConfirmed => 'पुष्ट';

  @override
  String get gxSettlementsPending => 'पुष्टि का इंतज़ार';

  @override
  String get gxSettlementsDisputedCount => 'आपत्ति वाले';

  @override
  String get gxSettlementsCount => 'दर्ज भुगतान';

  @override
  String get gxExport => 'CSV के रूप में निर्यात करें';

  @override
  String get gxExportTitle => 'समूह के खर्च (CSV)';

  @override
  String get gxExportIntro =>
      'समूह का हर खर्च (हटाए गए भी) और हर भुगतान, शेयर करने या सहेजने के लिए। सदस्यों के नाम हैं; खाते की कोई जानकारी नहीं है।';

  @override
  String get gxExportFile => 'फ़ाइल';

  @override
  String get gxExportRowsLabel => 'पंक्तियाँ';

  @override
  String gxExportRows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count पंक्तियाँ',
      one: '1 पंक्ति',
    );
    return '$_temp0';
  }

  @override
  String get gxErrSplitMismatch =>
      'बँटवारा सही नहीं बैठ रहा। राशियाँ, प्रतिशत (कुल 100%) या हिस्से जाँचें।';

  @override
  String get gxErrPayersMismatch =>
      'चुकाने वालों की राशि का जोड़ कुल राशि के बराबर होना चाहिए।';

  @override
  String get gxErrItemsExceedTotal => 'चीज़ों का जोड़ कुल राशि से ज़्यादा है।';

  @override
  String get gxErrItemsNeedAmount => 'कम से कम एक चीज़ की राशि चाहिए।';

  @override
  String get gxErrPayerOnly =>
      'यह खर्च खाते में वही दर्ज कर सकता है जिसने चुकाया।';

  @override
  String gxErrFxUnavailable(String from, String to, String date) {
    return 'Montra के पास $date के लिए $from से $to की दर नहीं है। आपकी इस्तेमाल की गई दर लिखें।';
  }

  @override
  String get gxErrExpenseDeleted =>
      'यह खर्च हटा दिया गया, इसलिए अब बदला नहीं जा सकता।';

  @override
  String get gxErrExpenseAlreadyRecorded =>
      'यह खर्च पहले से आपके खाते में दर्ज है।';

  @override
  String get gxErrSettlementVoided =>
      'यह भुगतान रद्द हो चुका है। इसकी जगह नया दर्ज करें।';

  @override
  String gxErrSettlementNotProposed(String status) {
    return 'केवल योजना वाला भुगतान चुकाया चिह्नित हो सकता है। अभी इसकी स्थिति: $status।';
  }

  @override
  String gxErrSettlementNotConfirmable(String status) {
    return 'इस भुगतान की अब पुष्टि नहीं हो सकती। अभी इसकी स्थिति: $status।';
  }

  @override
  String gxErrSettlementNotDisputable(String status) {
    return 'केवल बताए गए या पुष्ट भुगतान पर आपत्ति हो सकती है। अभी इसकी स्थिति: $status।';
  }

  @override
  String get gxErrSettlementAlreadyRecorded =>
      'यह भुगतान पहले से आपके खाते में दर्ज है।';

  @override
  String get gxErrSettlementNotConfirmed =>
      'खाते में दर्ज करने से पहले भुगतान की पुष्टि करें।';

  @override
  String get gxErrSettlementNotPaid =>
      'खाते में दर्ज करने से पहले इसे चुकाया चिह्नित करें।';

  @override
  String get gxErrSettlementDispute =>
      'भुगतान की आपत्ति तब खत्म होती है जब पाने वाला पुष्टि करे या कोई इसे रद्द करे।';

  @override
  String get gxErrRecurringMemberInactive =>
      'इस खर्च को बाँटने या चुकाने वाला कोई व्यक्ति अब सदस्य नहीं है। बाँटने वाले बदलें, फिर जोड़ें।';

  @override
  String gxErrRecurringMemberInactiveNamed(String name) {
    return '$name अब सदस्य नहीं हैं। इस खर्च को बाँटने या चुकाने वाले बदलें, फिर जोड़ें।';
  }

  @override
  String get gxErrRecurringTemplateInvalid =>
      'जैसे सेट है, वैसे यह खर्च जोड़ा नहीं जा सकता। इसका बँटवारा बदलें, फिर जोड़ें।';

  @override
  String get gxErrGroupArchived =>
      'यह समूह संग्रहीत है; बदलाव के लिए इसे वापस लाएँ।';

  @override
  String get errorAlreadyMember => 'पहले से सदस्य हैं, इसलिए कुछ नहीं बदला।';

  @override
  String gxErrConvertedTooSmall(String currency) {
    return 'इस दर पर $currency में राशि शून्य हो जाती है। मूल राशि और दर जाँचें।';
  }

  @override
  String privacyConsentOutdated(String version) {
    return 'इस सहमति की शब्दावली बदल गई है (संस्करण $version)। हमने इसे लोड कर लिया है; फिर से कोशिश करें।';
  }

  @override
  String get moderationErrorAppealDecided =>
      'इस अपील पर पहले ही फ़ैसला हो चुका है। नतीजा देखने के लिए फिर से लोड करें।';

  @override
  String codeQueryTooShort(String min) {
    return 'यूज़रनेम के कम से कम $min अक्षर लिखें।';
  }

  @override
  String get codeUsernameInvalid =>
      '3 से 30 छोटे अक्षर, अंक, “_” या “.” इस्तेमाल करें।';

  @override
  String get codeUsernameReserved => 'यह यूज़रनेम आरक्षित है। कोई दूसरा चुनें।';

  @override
  String get codeAvatarFileInvalid =>
      'यह फ़ोटो अभी इस्तेमाल नहीं हो सकती। इसे प्रोफ़ाइल फ़ोटो के रूप में फिर से अपलोड करें और अपलोड पूरा होने तक रुकें।';

  @override
  String get codeUsernameOrUserId =>
      'किसे आमंत्रित करना है चुनें: यूज़रनेम लिखें या कोई दोस्त चुनें, दोनों नहीं।';

  @override
  String codeConfirmWordMismatch(String word) {
    return 'पुष्टि के लिए ठीक-ठीक $word लिखें।';
  }

  @override
  String get codeDeletionAlreadyScheduled =>
      'आपका खाता पहले से हटाने के लिए तय है। आप इसे निजता और डेटा स्क्रीन पर रद्द कर सकते हैं।';

  @override
  String get codeNoDeletionScheduled =>
      'रद्द करने के लिए कोई तय की गई खाता-हटाने की प्रक्रिया नहीं है।';

  @override
  String get codeDuplicateItem =>
      'हर लेन-देन या स्टेटमेंट की पंक्ति सिर्फ़ एक बार चुनी जा सकती है।';

  @override
  String get codeTransactionAlreadyMatched =>
      'इनमें से कोई लेन-देन पहले ही मिलाया जा चुका है। ताज़ा स्थिति देखने के लिए फिर से लोड करें।';

  @override
  String get codeSyncRunning =>
      'एक सिंक पहले से चल रहा है। उसके पूरा होने तक रुकें, फिर से कोशिश करें।';

  @override
  String get codeAlreadyReported =>
      'आप इसकी रिपोर्ट पहले ही कर चुके हैं; मॉडरेटर इसकी समीक्षा करेंगे।';

  @override
  String get widgetBudgets => 'बजट';

  @override
  String get widgetBudgetsHelp => 'सबसे ज़्यादा भरे बजट और उनकी रफ़्तार';

  @override
  String get widgetUpcoming => 'आने वाले भुगतान';

  @override
  String get widgetUpcomingHelp =>
      'बकाया और आने वाले बिल, आवर्ती भुगतान, नवीनीकरण और लक्ष्य की तारीखें';

  @override
  String get widgetGoals => 'लक्ष्य';

  @override
  String get widgetGoalsHelp => 'सबसे नज़दीकी लक्ष्यों की प्रगति';

  @override
  String get widgetGroupBalances => 'समूह के हिसाब';

  @override
  String get widgetGroupBalancesHelp =>
      'वे समूह जिनमें आपको पैसे मिलने हैं या आपको देने हैं';

  @override
  String get dashPlanLoading => 'लोड हो रहा है…';

  @override
  String dashPlanError(String reason) {
    return 'यह कार्ड लोड नहीं हो सका। $reason';
  }

  @override
  String dashPlanBudgetsSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count चालू बजट',
      one: '1 चालू बजट',
    );
    return '$_temp0';
  }

  @override
  String dashPlanBudgetsOver(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count बजट से ज़्यादा खर्च हुआ',
      one: '1 बजट से ज़्यादा खर्च हुआ',
    );
    return '$_temp0';
  }

  @override
  String get dashPlanBudgetsNoneOver => 'कोई भी बजट पार नहीं हुआ';

  @override
  String get dashPlanBudgetsEmpty =>
      'कोई चालू बजट नहीं है। बजट दिखाता है कि आपने सीमा में से कितना खर्च किया।';

  @override
  String get dashPlanBudgetsCreate => 'बजट बनाएँ';

  @override
  String get dashPlanBudgetsSeeAll => 'सभी बजट देखें';

  @override
  String get dashPlanBudgetPaused => 'इस अवधि के आँकड़े अभी नहीं हैं';

  @override
  String dashPlanUpcomingSummary(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$date तक $count भुगतान',
      one: '$date तक 1 भुगतान',
    );
    return '$_temp0';
  }

  @override
  String dashPlanUpcomingOverdue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count का समय निकल गया',
      one: '1 का समय निकल गया',
    );
    return '$_temp0';
  }

  @override
  String get dashPlanUpcomingNoneOverdue => 'किसी का समय नहीं निकला';

  @override
  String get dashPlanUpcomingEmpty =>
      'अगले 14 दिनों में कुछ देय नहीं है, और कुछ भी बकाया नहीं है।';

  @override
  String get dashPlanUpcomingAddBill => 'बिल जोड़ें';

  @override
  String get dashPlanUpcomingSeeAll => 'कैलेंडर खोलें';

  @override
  String dashPlanUpcomingMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'कैलेंडर में $count और',
      one: 'कैलेंडर में 1 और',
    );
    return '$_temp0';
  }

  @override
  String dashPlanDueOn(String date) {
    return 'देय तिथि $date';
  }

  @override
  String get dashPlanDueToday => 'आज देय';

  @override
  String dashPlanWasDue(String date) {
    return '$date को देय था';
  }

  @override
  String dashPlanGoalsSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count चालू लक्ष्य',
      one: '1 चालू लक्ष्य',
    );
    return '$_temp0';
  }

  @override
  String get dashPlanGoalsEmpty =>
      'कोई चालू लक्ष्य नहीं है। किसी चीज़ के लिए बचत करने को लक्ष्य बनाएँ।';

  @override
  String get dashPlanGoalsCreate => 'लक्ष्य बनाएँ';

  @override
  String get dashPlanGoalsSeeAll => 'सभी लक्ष्य देखें';

  @override
  String get dashPlanGoalNoDate => 'कोई लक्ष्य तिथि नहीं';

  @override
  String dashPlanGroupsSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count समूहों में हिसाब बाकी',
      one: '1 समूह में हिसाब बाकी',
    );
    return '$_temp0';
  }

  @override
  String get dashPlanGroupsEmpty => 'हर समूह में आपका हिसाब बराबर है।';

  @override
  String get dashPlanGroupsSeeAll => 'सभी समूह देखें';

  @override
  String get dashPlanGroupSettled => 'हिसाब बराबर';

  @override
  String dashPlanShowingFirst(int shown, int total) {
    return '$total में से $shown दिखाए गए';
  }

  @override
  String get profileEditTitle => 'प्रोफ़ाइल बदलें';

  @override
  String get profileEditEntry => 'प्रोफ़ाइल बदलें';

  @override
  String get profileEditEntrySubtitle =>
      'नाम, फ़ोटो, यूज़रनेम, परिचय और आपकी प्रोफ़ाइल कौन देख सकता है';

  @override
  String get profileEditPhotoSection => 'प्रोफ़ाइल फ़ोटो';

  @override
  String get profileEditPhotoNone =>
      'अभी कोई फ़ोटो नहीं है। लोग इसकी जगह आपके नाम के पहले अक्षर देखते हैं।';

  @override
  String get profileEditPhotoLabel => 'आपकी प्रोफ़ाइल फ़ोटो';

  @override
  String profileEditPhotoInitials(String name) {
    return '$name के नाम के पहले अक्षर';
  }

  @override
  String get profileEditPhotoChoose => 'फ़ोटो चुनें';

  @override
  String get profileEditPhotoChange => 'फ़ोटो बदलें';

  @override
  String get profileEditPhotoRemove => 'फ़ोटो हटाएँ';

  @override
  String get profileEditPhotoRemoveTitle => 'प्रोफ़ाइल फ़ोटो हटाएँ?';

  @override
  String get profileEditPhotoRemoveBody =>
      'लोग इसकी जगह आपके नाम के पहले अक्षर देखेंगे। आप कभी भी फिर से फ़ोटो जोड़ सकते हैं।';

  @override
  String get profileEditPhotoSaved => 'प्रोफ़ाइल फ़ोटो बदल गई।';

  @override
  String get profileEditPhotoRemoved => 'प्रोफ़ाइल फ़ोटो हटा दी गई।';

  @override
  String get profileEditPhotoUnavailable => 'फ़ोटो अभी दिखाई नहीं जा सकी।';

  @override
  String profileEditPhotoHelp(String size) {
    return 'JPG, PNG या WEBP, $size तक। आपकी फ़ोटो वहाँ दिखती है जहाँ आपकी प्रोफ़ाइल दिखती है।';
  }

  @override
  String get profileEditDetailsSection => 'आपके बारे में';

  @override
  String get profileEditDisplayName => 'दिखने वाला नाम';

  @override
  String get profileEditDisplayNameHelp =>
      'दोस्तों, समूहों और समुदायों को दिखता है।';

  @override
  String get profileEditBio => 'परिचय';

  @override
  String get profileEditBioHelp =>
      'अपने बारे में एक छोटी पंक्ति। हटाने के लिए खाली छोड़ दें।';

  @override
  String get profileEditLocation => 'स्थान';

  @override
  String get profileEditLocationHelp =>
      'कोई शहर या क्षेत्र, अपना पता कभी नहीं। हटाने के लिए खाली छोड़ दें।';

  @override
  String get profileEditInterests => 'रुचियाँ';

  @override
  String profileEditInterestsHelp(int max) {
    return '$max तक छोटे विषय, जैसे खाना बनाना या क्रिकेट।';
  }

  @override
  String get profileEditInterestAdd => 'रुचि जोड़ें';

  @override
  String get profileEditInterestNew => 'नई रुचि';

  @override
  String profileEditInterestRemove(String name) {
    return 'रुचि $name हटाएँ';
  }

  @override
  String get profileEditInterestTooLong =>
      'हर रुचि छोटी रखें (अंग्रेज़ी में 40 अक्षर तक, हिंदी में इससे कम)।';

  @override
  String get profileEditInterestDuplicate =>
      'यह रुचि आप पहले ही जोड़ चुके हैं।';

  @override
  String profileEditInterestsFull(int max) {
    return 'आप $max तक रुचियाँ जोड़ सकते हैं।';
  }

  @override
  String get profileEditInterestsNone => 'कोई रुचि नहीं जोड़ी गई।';

  @override
  String get profileEditVisibility => 'आपकी प्रोफ़ाइल कौन देख सकता है';

  @override
  String get profileEditVisibilityPrivate => 'निजी';

  @override
  String get profileEditVisibilityPrivateHelp =>
      'केवल आप, आपके साथ किसी सक्रिय समूह के सदस्य, और वे लोग जिनके और आपके बीच दोस्ती का अनुरोध लंबित है, आपकी प्रोफ़ाइल और फ़ोटो देख सकते हैं।';

  @override
  String get profileEditVisibilityConnections => 'दोस्त';

  @override
  String get profileEditVisibilityConnectionsHelp =>
      'आपके दोस्त आपकी प्रोफ़ाइल और फ़ोटो देख सकते हैं, और साथ ही आप, आपके साथ किसी सक्रिय समूह के सदस्य, और वे लोग जिनके और आपके बीच दोस्ती का अनुरोध लंबित है।';

  @override
  String get profileEditVisibilityPublic => 'Montra पर सभी';

  @override
  String get profileEditVisibilityPublicHelp =>
      'Montra में साइन इन किया कोई भी व्यक्ति आपकी प्रोफ़ाइल और फ़ोटो देख सकता है।';

  @override
  String get profileEditUsernameHelp =>
      '3 से 30 छोटे अक्षर, अंक, “_” या “.”। हटाने के लिए खाली छोड़ दें। इससे आपको कौन ढूँढ सकता है, यह दोस्त में तय होता है।';

  @override
  String get profileEditSaved => 'प्रोफ़ाइल सहेजी गई।';

  @override
  String get profileEditFinanceNote =>
      'आपकी प्रोफ़ाइल में आपके खाते, राशियाँ या लेन-देन कभी नहीं दिखते।';

  @override
  String get prefsTitle => 'प्राथमिकताएँ';

  @override
  String get prefsEntrySubtitle =>
      'मुद्रा, क्षेत्र, प्रारूप, डिफ़ॉल्ट, थीम और सुलभता';

  @override
  String get prefsSaved => 'प्राथमिकताएँ सहेजी गईं।';

  @override
  String get prefsMoneySection => 'पैसा';

  @override
  String get prefsBaseCurrency => 'मुख्य मुद्रा';

  @override
  String get prefsBaseCurrencyExplain =>
      'आपकी मुख्य मुद्रा नए खातों, बजट, लक्ष्यों, बिलों और रसीदों के लिए डिफ़ॉल्ट होती है, और होम पर पहले दिखती है। इसे बदलने से कुछ भी बदला (कन्वर्ट) नहीं होता: मौजूदा खाते, लेन-देन, बजट और लक्ष्य अपनी मुद्रा में रहते हैं, और अलग-अलग मुद्राओं की राशियाँ कभी जोड़ी नहीं जातीं।';

  @override
  String prefsBaseCurrencyChanged(String currency) {
    return 'अब से नए रिकॉर्ड डिफ़ॉल्ट रूप से $currency में होंगे। जो आपने पहले दर्ज किया है, वह नहीं बदलेगा।';
  }

  @override
  String get prefsDisplayCurrency => 'दिखाने के लिए दूसरी मुद्रा';

  @override
  String get prefsDisplayCurrencyHelp =>
      'वैकल्पिक। जहाँ विनिमय दरें इस्तेमाल होती हैं, वहाँ राशियाँ इस मुद्रा में भी दिख सकती हैं; आपके रिकॉर्ड अपनी मुद्रा में रहते हैं।';

  @override
  String get prefsNone => 'कोई नहीं';

  @override
  String get prefsDefaultAccount => 'डिफ़ॉल्ट खाता';

  @override
  String get prefsDefaultAccountHelp =>
      'खर्च या आय जोड़ते समय सबसे पहले यही चुना जाता है।';

  @override
  String get prefsDefaultAccountMissing => 'ऐसा खाता जो अब सक्रिय नहीं है';

  @override
  String get prefsDefaultRange => 'डिफ़ॉल्ट अवधि';

  @override
  String get prefsDefaultRangeHelp => 'होम इसी अवधि के साथ खुलता है।';

  @override
  String get prefsRegionSection => 'क्षेत्र और भाषा';

  @override
  String get prefsCountryHelp =>
      'दो अक्षर, जैसे IN। हटाने के लिए खाली छोड़ दें।';

  @override
  String get prefsTimezoneHelp =>
      '\"आज\", बजट की अवधियाँ और रिमाइंडर इसी समय क्षेत्र के अनुसार चलते हैं। इसे बदलने से पहले दर्ज की गई चीज़ें नहीं खिसकतीं।';

  @override
  String get prefsTimezoneSearch => 'समय क्षेत्र खोजें';

  @override
  String prefsTimezoneUseTyped(String zone) {
    return '“$zone” इस्तेमाल करें';
  }

  @override
  String prefsTimezoneDevice(String zone) {
    return 'यह डिवाइस: $zone';
  }

  @override
  String get prefsLocale => 'भाषा और क्षेत्र';

  @override
  String get prefsLocaleHelp => 'ऐप की भाषा इसी सेटिंग के अनुसार होती है।';

  @override
  String get prefsLocaleEnIn => 'अंग्रेज़ी (भारत)';

  @override
  String get prefsLocaleEnUs => 'अंग्रेज़ी (अमेरिका)';

  @override
  String get prefsLocaleEnGb => 'अंग्रेज़ी (ब्रिटेन)';

  @override
  String get prefsLocaleHiIn => 'हिन्दी (भारत)';

  @override
  String get prefsFormatsSection => 'प्रारूप';

  @override
  String get prefsDateFormat => 'तारीख़ का प्रारूप';

  @override
  String get prefsDateFormatLocale => 'भाषा के अनुसार';

  @override
  String get prefsDateFormatDmy => 'दिन, महीना, वर्ष (31/12/2026)';

  @override
  String get prefsDateFormatMdy => 'महीना, दिन, वर्ष (12/31/2026)';

  @override
  String get prefsDateFormatYmd => 'वर्ष, महीना, दिन (2026-12-31)';

  @override
  String get prefsDateFormatHelp =>
      'ऐप, निर्यात, रिपोर्ट और ईमेल में तारीख़ें इसी तरह लिखी जाती हैं।';

  @override
  String get prefsNumberFormat => 'संख्या का प्रारूप';

  @override
  String get prefsNumberFormatLocale => 'भाषा और क्षेत्र के अनुसार';

  @override
  String prefsNumberFormatIndian(String example) {
    return 'लाख और करोड़ ($example)';
  }

  @override
  String prefsNumberFormatInternational(String example) {
    return 'हज़ार और मिलियन ($example)';
  }

  @override
  String prefsNumberFormatHelp(String example) {
    return 'ऐप में राशियाँ कैसे समूहित होती हैं, जैसे $example।';
  }

  @override
  String get prefsWeekStart => 'सप्ताह किस दिन शुरू हो';

  @override
  String get prefsWeekStartHelp =>
      'साप्ताहिक बजट, रिपोर्ट, साप्ताहिक योग और तारीख़ चुनने वाले कैलेंडर में इस्तेमाल होता है।';

  @override
  String get prefsMonthStart => 'महीना किस तारीख़ से शुरू हो';

  @override
  String get prefsMonthStartHelp =>
      'जैसे 25, अगर आपका वेतन 25 तारीख़ को आता है। 1 से 28 तक।';

  @override
  String prefsMonthStartDay(int day) {
    return '$day तारीख़';
  }

  @override
  String get prefsAppearanceSection => 'थीम';

  @override
  String get prefsThemeHelp =>
      'आपके खाते में सहेजी जाती है और इस डिवाइस पर इस्तेमाल होती है।';

  @override
  String get a11yTitle => 'सुलभता';

  @override
  String get a11yIntro =>
      'सहेजते ही ये सेटिंग ऐप में लागू हो जाती हैं, आपके फ़ोन की अपनी सुलभता सेटिंग के साथ।';

  @override
  String get a11yReducedMotion => 'हलचल कम करें';

  @override
  String get a11yReducedMotionHelp =>
      'स्क्रीन बदलने के प्रभाव और दूसरे एनिमेशन बंद करता है।';

  @override
  String get a11yHighContrast => 'उच्च कंट्रास्ट';

  @override
  String get a11yHighContrastHelp =>
      'ज़्यादा गहरे रंग और किनारे, जिन्हें पहचानना आसान है।';

  @override
  String get a11yTextSize => 'टेक्स्ट का आकार';

  @override
  String a11yTextSizeValue(int percent) {
    return '$percent%';
  }

  @override
  String get a11yTextSizeHelp =>
      'आपके फ़ोन के टेक्स्ट आकार को 80% से 200% तक बढ़ाता या घटाता है।';

  @override
  String get a11yTextSizeSmaller => 'छोटा टेक्स्ट';

  @override
  String get a11yTextSizeLarger => 'बड़ा टेक्स्ट';

  @override
  String get a11yTextSizePreview =>
      'झलक: इस हफ़्ते किराने पर ₹1,250.50 खर्च हुए।';

  @override
  String get prefsUnsavedTitle => 'बदलाव छोड़ दें?';

  @override
  String get prefsUnsavedBody => 'आपने कुछ सेटिंग बदलीं, पर उन्हें सहेजा नहीं।';

  @override
  String get prefsDiscard => 'छोड़ दें';

  @override
  String get receiptPagesAddTitle => 'रसीद जोड़ें';

  @override
  String receiptPagesIntro(int max) {
    return 'रसीद की हर फ़ोटो या PDF क्रम से जोड़ें। लंबी रसीद में $max तक पेज हो सकते हैं। कुछ भी अपने-आप नहीं पढ़ा जाता: विवरण आप आगे खुद भरते हैं।';
  }

  @override
  String get receiptPagesNoneTitle => 'अभी कोई पेज नहीं';

  @override
  String get receiptPagesNoneBody =>
      'फ़ोटो लें, या फ़ोटो या फ़ाइलें चुनें। हर एक एक पेज बनता है।';

  @override
  String get receiptPagesTakePhoto => 'फ़ोटो लें';

  @override
  String get receiptPagesChoosePhotos => 'फ़ोटो चुनें';

  @override
  String get receiptPagesChooseFiles => 'फ़ाइलें चुनें';

  @override
  String receiptPagesPage(int position, int total) {
    return '$total में से पेज $position';
  }

  @override
  String receiptPagesFile(int position, int total) {
    return '$total में से फ़ाइल $position';
  }

  @override
  String receiptPagesMoveUp(String name) {
    return '$name को ऊपर ले जाएँ';
  }

  @override
  String receiptPagesMoveDown(String name) {
    return '$name को नीचे ले जाएँ';
  }

  @override
  String receiptPagesRemove(String name) {
    return '$name हटाएँ';
  }

  @override
  String get receiptPagesStateWaiting => 'अपलोड के लिए तैयार';

  @override
  String get receiptPagesStateUploaded => 'अपलोड हो गया';

  @override
  String get receiptPagesStateCreating => 'रसीद जोड़ी जा रही है…';

  @override
  String receiptPagesStateFailed(String reason) {
    return 'नहीं जुड़ा: $reason';
  }

  @override
  String get receiptPagesStateDone => 'जुड़ गया';

  @override
  String get receiptPagesModeTitle => 'ये फ़ाइलें हैं';

  @override
  String get receiptPagesModePages => 'एक ही रसीद के पेज';

  @override
  String get receiptPagesModePagesHelp => 'ऊपर दिखाए गए क्रम में।';

  @override
  String get receiptPagesModeSeparate => 'अलग-अलग रसीदें';

  @override
  String get receiptPagesModeSeparateHelp => 'हर फ़ाइल अपनी अलग रसीद बनती है।';

  @override
  String get receiptPagesNotes => 'नोट';

  @override
  String get receiptPagesNotesHelp =>
      'जैसे किसके लिए थी। रसीद के साथ रखा जाता है।';

  @override
  String receiptPagesSave(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count पेज वाली रसीद जोड़ें',
      one: 'रसीद जोड़ें',
    );
    return '$_temp0';
  }

  @override
  String receiptPagesSaveSeparate(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count रसीदें जोड़ें',
      one: '1 रसीद जोड़ें',
    );
    return '$_temp0';
  }

  @override
  String get receiptPagesStop => 'अपलोड रोकें';

  @override
  String get receiptPagesStopped =>
      'रोक दिया गया। कुछ नहीं जुड़ा; अपलोड हुए पेज इस स्क्रीन से निकलने तक रखे जाते हैं।';

  @override
  String receiptPagesTooMany(int max) {
    return 'एक रसीद में $max तक पेज हो सकते हैं।';
  }

  @override
  String receiptPagesAlreadyAdded(String name) {
    return '$name पहले से सूची में है।';
  }

  @override
  String receiptPagesRefused(String name, String reason) {
    return '$name नहीं जोड़ी गई: $reason';
  }

  @override
  String get receiptPagesUploadFailed =>
      'कुछ पेज अपलोड नहीं हो सके। बाकी अपलोड करने के लिए फिर से कोशिश करें; अपलोड हुए पेज दोबारा नहीं भेजे जाते।';

  @override
  String receiptPagesSomeFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count रसीदें नहीं जुड़ीं। इन्हें जोड़ने के लिए फिर से कोशिश करें।',
      one: '1 रसीद नहीं जुड़ी। इसे जोड़ने के लिए फिर से कोशिश करें।',
    );
    return '$_temp0';
  }

  @override
  String receiptPagesAddedMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count रसीदें जुड़ गईं। आगे इनका विवरण भरें।',
      one: '1 रसीद जुड़ गई। आगे इसका विवरण भरें।',
    );
    return '$_temp0';
  }

  @override
  String get receiptPagesLeaveTitle => 'बिना जोड़े निकलें?';

  @override
  String get receiptPagesLeaveBody =>
      'आपके चुने पेज नहीं जोड़े जाएँगे, और अपलोड हुए पेज मिटा दिए जाएँगे।';

  @override
  String get receiptPagesLeave => 'निकलें';

  @override
  String get widgetAlerts => 'बजट अलर्ट';

  @override
  String get widgetAlertsHelp =>
      'जो बजट आपकी तय सीमा तक पहुँच गए हैं, उन्हें स्नूज़ करें या हटाएँ';

  @override
  String get widgetRenewals => 'रिन्यूअल';

  @override
  String get widgetRenewalsHelp =>
      'अगले 30 दिनों में सब्सक्रिप्शन रिन्यूअल और ट्रायल का ख़त्म होना';

  @override
  String get widgetRecurring => 'नियमित प्रतिबद्धताएँ';

  @override
  String get widgetRecurringHelp =>
      'नियमित भुगतान और आय, मासिक राशि के रूप में';

  @override
  String dashPlanAlertsSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count चालू अलर्ट',
      one: '1 चालू अलर्ट',
    );
    return '$_temp0';
  }

  @override
  String get dashPlanAlertsEmpty =>
      'कोई चालू बजट अलर्ट नहीं है। जब कोई बजट आपकी तय सीमा तक पहुँचेगा, तो अलर्ट यहाँ दिखेगा।';

  @override
  String get dashPlanAlertsSeeAll => 'सभी बजट अलर्ट देखें';

  @override
  String dashPlanAlertSnoozeFor(String budget) {
    return '$budget का अलर्ट स्नूज़ करें';
  }

  @override
  String dashPlanAlertDismissFor(String budget) {
    return '$budget का अलर्ट हटाएँ';
  }

  @override
  String dashPlanRenewalsSummary(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$date तक $count रिन्यूअल और ट्रायल के अंत',
      one: '$date तक 1 रिन्यूअल या ट्रायल का अंत',
    );
    return '$_temp0';
  }

  @override
  String get dashPlanRenewalsEmpty =>
      'अगले 30 दिनों में कोई सब्सक्रिप्शन रिन्यूअल या ट्रायल ख़त्म नहीं हो रहा है।';

  @override
  String get dashPlanRenewalsAdd => 'सब्सक्रिप्शन जोड़ें';

  @override
  String get dashPlanRenewalsSeeAll => 'सभी सब्सक्रिप्शन देखें';

  @override
  String get dashPlanRenewalToday => 'आज';

  @override
  String dashPlanRenewalOn(String date) {
    return '$date को';
  }

  @override
  String get dashPlanRecurringSeeAll => 'नियमित प्रतिबद्धताएँ खोलें';

  @override
  String get onboardingCalendarSection => 'हफ़्ते और महीने';

  @override
  String get onboardingGoalsTitle => 'किसी चीज़ के लिए बचत करें (वैकल्पिक)';

  @override
  String get onboardingGoalsBody =>
      'अभी एक लक्ष्य जोड़ें, जैसे आपातकालीन फ़ंड या कोई यात्रा। योजना, पड़ाव और दूसरे लक्ष्य आप बाद में जोड़ सकते हैं, या इसे छोड़ दें।';

  @override
  String get onboardingGoalCreate => 'लक्ष्य बनाएँ';

  @override
  String get onboardingGoalCreated => 'लक्ष्य बन गया';

  @override
  String onboardingGoalTarget(String amount) {
    return 'लक्ष्य राशि $amount';
  }

  @override
  String get onboardingGoalLater =>
      '“लक्ष्य” में आप इसमें पैसे जोड़ सकते हैं, इसे बदल सकते हैं या और लक्ष्य जोड़ सकते हैं।';

  @override
  String get onboardingNotificationsTitle => 'ईमेल सारांश';

  @override
  String get onboardingNotificationsBody =>
      'चुनें कि Montra बिल रिमाइंडर और बजट अलर्ट जैसे वैकल्पिक ईमेल कैसे भेजे।';

  @override
  String get onboardingDigestOff => 'हर ईमेल तुरंत भेजें';

  @override
  String get onboardingDigestOffHelp =>
      'वैकल्पिक ईमेल उसी समय आते हैं जब कुछ होता है।';

  @override
  String get onboardingDigestDaily => 'रोज़ का सारांश';

  @override
  String get onboardingDigestDailyHelp =>
      'वैकल्पिक ईमेल रोके जाते हैं और हर सुबह 8:00 बजे एक साथ भेजे जाते हैं।';

  @override
  String get onboardingDigestWeekly => 'हफ़्ते का सारांश';

  @override
  String get onboardingDigestWeeklyHelp =>
      'वैकल्पिक ईमेल रोके जाते हैं और हर सोमवार सुबह 8:00 बजे एक साथ भेजे जाते हैं।';

  @override
  String get onboardingDigestSecurity =>
      'सुरक्षा और खाते से जुड़े ईमेल, जैसे साइन-इन अलर्ट, हमेशा तुरंत भेजे जाते हैं। हर तरह के ईमेल के लिए आप बाद में सूचना सेटिंग में चुन सकते हैं।';

  @override
  String get profileEditVisibilityBlocked =>
      'आप जिन्हें ब्लॉक करते हैं, वे आपकी प्रोफ़ाइल कभी नहीं देखते, चाहे आप यहाँ कुछ भी चुनें, और आप भी उनकी प्रोफ़ाइल नहीं देखते।';
}

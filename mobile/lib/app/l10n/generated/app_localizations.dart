import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Montra'**
  String get appTitle;

  /// No description provided for @actionRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get actionRetry;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get actionContinue;

  /// No description provided for @actionDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get actionDone;

  /// No description provided for @actionCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get actionCopy;

  /// No description provided for @actionClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get actionClose;

  /// No description provided for @copiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copiedToClipboard;

  /// No description provided for @loadingLabel.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get loadingLabel;

  /// Support correlation ID shown under errors.
  ///
  /// In en, this message translates to:
  /// **'Reference: {requestId}'**
  String requestReference(String requestId);

  /// No description provided for @copyReference.
  ///
  /// In en, this message translates to:
  /// **'Copy reference'**
  String get copyReference;

  /// No description provided for @offlineBanner.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline. Changes can\'t be saved until you reconnect.'**
  String get offlineBanner;

  /// No description provided for @errorOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline'**
  String get errorOfflineTitle;

  /// No description provided for @errorOfflineBody.
  ///
  /// In en, this message translates to:
  /// **'Check your internet connection and try again.'**
  String get errorOfflineBody;

  /// No description provided for @errorTimeout.
  ///
  /// In en, this message translates to:
  /// **'Montra is taking too long to respond. Try again in a moment.'**
  String get errorTimeout;

  /// No description provided for @errorGenericTitle.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get errorGenericTitle;

  /// No description provided for @errorGenericBody.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t complete that request. Try again in a moment.'**
  String get errorGenericBody;

  /// No description provided for @errorServiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Montra is temporarily unavailable. Try again in a few minutes.'**
  String get errorServiceUnavailable;

  /// No description provided for @errorInvalidResponse.
  ///
  /// In en, this message translates to:
  /// **'We received an unexpected response. Try again, and update the app if this keeps happening.'**
  String get errorInvalidResponse;

  /// No description provided for @errorPermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have access'**
  String get errorPermissionTitle;

  /// No description provided for @errorPermissionBody.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have permission to view or change this.'**
  String get errorPermissionBody;

  /// No description provided for @errorNotFound.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find that. It may have been removed.'**
  String get errorNotFound;

  /// No description provided for @errorConflict.
  ///
  /// In en, this message translates to:
  /// **'This was changed somewhere else. Refresh and try again.'**
  String get errorConflict;

  /// No description provided for @errorRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Wait a moment and try again.'**
  String get errorRateLimited;

  /// No description provided for @errorRateLimitedRetry.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again in {wait}.'**
  String errorRateLimitedRetry(String wait);

  /// No description provided for @errorSessionEnded.
  ///
  /// In en, this message translates to:
  /// **'Your session ended. Sign in again.'**
  String get errorSessionEnded;

  /// No description provided for @errorValidation.
  ///
  /// In en, this message translates to:
  /// **'Some details need your attention.'**
  String get errorValidation;

  /// No description provided for @durationSeconds.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 second} other{{count} seconds}}'**
  String durationSeconds(int count);

  /// No description provided for @durationMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 minute} other{{count} minutes}}'**
  String durationMinutes(int count);

  /// No description provided for @shortSeconds.
  ///
  /// In en, this message translates to:
  /// **'{count}s'**
  String shortSeconds(int count);

  /// No description provided for @shortMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count} min'**
  String shortMinutes(int count);

  /// Disabled submit button label while throttled.
  ///
  /// In en, this message translates to:
  /// **'Try again in {wait}'**
  String retryIn(String wait);

  /// No description provided for @welcomeTagline.
  ///
  /// In en, this message translates to:
  /// **'Understand your money, manage money together, and make better financial decisions.'**
  String get welcomeTagline;

  /// No description provided for @welcomeFreeTitle.
  ///
  /// In en, this message translates to:
  /// **'Free for everyone'**
  String get welcomeFreeTitle;

  /// No description provided for @welcomeFreeBody.
  ///
  /// In en, this message translates to:
  /// **'Every feature is free. There are no paid tiers or locked features.'**
  String get welcomeFreeBody;

  /// No description provided for @welcomePrivateTitle.
  ///
  /// In en, this message translates to:
  /// **'Private by default'**
  String get welcomePrivateTitle;

  /// No description provided for @welcomePrivateBody.
  ///
  /// In en, this message translates to:
  /// **'Your financial data is never sold and never shown publicly.'**
  String get welcomePrivateBody;

  /// No description provided for @welcomeManualTitle.
  ///
  /// In en, this message translates to:
  /// **'No bank linking needed'**
  String get welcomeManualTitle;

  /// No description provided for @welcomeManualBody.
  ///
  /// In en, this message translates to:
  /// **'Track your money by entering it yourself. Connecting a bank is never required.'**
  String get welcomeManualBody;

  /// No description provided for @welcomeCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get welcomeCreateAccount;

  /// No description provided for @welcomeSignIn.
  ///
  /// In en, this message translates to:
  /// **'I already have an account'**
  String get welcomeSignIn;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get emailLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @validationEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your email address.'**
  String get validationEmailRequired;

  /// No description provided for @validationEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get validationEmailInvalid;

  /// No description provided for @validationPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your password.'**
  String get validationPasswordRequired;

  /// No description provided for @signInTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInTitle;

  /// No description provided for @signInButton.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInButton;

  /// No description provided for @forgotPasswordLink.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPasswordLink;

  /// No description provided for @noAccountPrompt.
  ///
  /// In en, this message translates to:
  /// **'New to Montra?'**
  String get noAccountPrompt;

  /// No description provided for @createAccountLink.
  ///
  /// In en, this message translates to:
  /// **'Create an account'**
  String get createAccountLink;

  /// No description provided for @signInInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Incorrect email or password.'**
  String get signInInvalidCredentials;

  /// No description provided for @signInAccountLocked.
  ///
  /// In en, this message translates to:
  /// **'This account is locked. Contact support to restore access.'**
  String get signInAccountLocked;

  /// No description provided for @signInThrottled.
  ///
  /// In en, this message translates to:
  /// **'Too many failed sign-in attempts. Try again later or reset your password.'**
  String get signInThrottled;

  /// No description provided for @signInThrottledRetry.
  ///
  /// In en, this message translates to:
  /// **'Too many failed sign-in attempts. Try again in {wait}, or reset your password.'**
  String signInThrottledRetry(String wait);

  /// No description provided for @signInEmailNotVerifiedTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify your email to sign in'**
  String get signInEmailNotVerifiedTitle;

  /// No description provided for @signInEmailNotVerifiedBody.
  ///
  /// In en, this message translates to:
  /// **'We\'ve sent you a new verification link. Open it on this device, or paste it here.'**
  String get signInEmailNotVerifiedBody;

  /// No description provided for @sessionExpiredNotice.
  ///
  /// In en, this message translates to:
  /// **'Your session ended. Sign in again to continue.'**
  String get sessionExpiredNotice;

  /// No description provided for @signedOutEverywhereNotice.
  ///
  /// In en, this message translates to:
  /// **'You\'ve been signed out of all devices.'**
  String get signedOutEverywhereNotice;

  /// No description provided for @passwordResetNotice.
  ///
  /// In en, this message translates to:
  /// **'Your password was changed. Sign in with your new password.'**
  String get passwordResetNotice;

  /// No description provided for @mfaTitle.
  ///
  /// In en, this message translates to:
  /// **'Two-step verification'**
  String get mfaTitle;

  /// No description provided for @mfaBody.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code from your authenticator app.'**
  String get mfaBody;

  /// No description provided for @mfaRecoveryBody.
  ///
  /// In en, this message translates to:
  /// **'Enter one of the recovery codes you saved when you turned on two-step verification. Each code works once.'**
  String get mfaRecoveryBody;

  /// No description provided for @mfaCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Verification code'**
  String get mfaCodeLabel;

  /// No description provided for @mfaRecoveryLabel.
  ///
  /// In en, this message translates to:
  /// **'Recovery code'**
  String get mfaRecoveryLabel;

  /// No description provided for @mfaUseRecovery.
  ///
  /// In en, this message translates to:
  /// **'Use a recovery code instead'**
  String get mfaUseRecovery;

  /// No description provided for @mfaUseCode.
  ///
  /// In en, this message translates to:
  /// **'Use an authenticator code instead'**
  String get mfaUseCode;

  /// No description provided for @mfaVerifyButton.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get mfaVerifyButton;

  /// No description provided for @mfaStartOver.
  ///
  /// In en, this message translates to:
  /// **'Start over'**
  String get mfaStartOver;

  /// No description provided for @validationCodeRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code.'**
  String get validationCodeRequired;

  /// No description provided for @validationCodeFormat.
  ///
  /// In en, this message translates to:
  /// **'The code is 6 digits.'**
  String get validationCodeFormat;

  /// No description provided for @validationRecoveryRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a recovery code.'**
  String get validationRecoveryRequired;

  /// No description provided for @mfaCodeInvalid.
  ///
  /// In en, this message translates to:
  /// **'That code didn\'t work. Check your authenticator app and try again.'**
  String get mfaCodeInvalid;

  /// No description provided for @mfaRecoveryCodeInvalid.
  ///
  /// In en, this message translates to:
  /// **'That recovery code didn\'t work. Check it and try again; each code works only once.'**
  String get mfaRecoveryCodeInvalid;

  /// No description provided for @mfaChallengeExpired.
  ///
  /// In en, this message translates to:
  /// **'This sign-in attempt expired. Enter your password to start again.'**
  String get mfaChallengeExpired;

  /// No description provided for @signUpTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get signUpTitle;

  /// No description provided for @displayNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get displayNameLabel;

  /// No description provided for @displayNameHelp.
  ///
  /// In en, this message translates to:
  /// **'What should Montra call you?'**
  String get displayNameHelp;

  /// No description provided for @validationDisplayNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a name.'**
  String get validationDisplayNameRequired;

  /// No description provided for @validationDisplayNameLength.
  ///
  /// In en, this message translates to:
  /// **'Use {max} characters or fewer.'**
  String validationDisplayNameLength(int max);

  /// No description provided for @passwordRulesTitle.
  ///
  /// In en, this message translates to:
  /// **'Your password must'**
  String get passwordRulesTitle;

  /// No description provided for @passwordRuleLength.
  ///
  /// In en, this message translates to:
  /// **'Be at least {min} characters long'**
  String passwordRuleLength(int min);

  /// No description provided for @passwordRuleNotEmail.
  ///
  /// In en, this message translates to:
  /// **'Not contain your email address'**
  String get passwordRuleNotEmail;

  /// No description provided for @passwordRuleVariety.
  ///
  /// In en, this message translates to:
  /// **'Use at least 4 different characters'**
  String get passwordRuleVariety;

  /// No description provided for @passwordRuleCommon.
  ///
  /// In en, this message translates to:
  /// **'Not be a commonly used password (checked when you submit)'**
  String get passwordRuleCommon;

  /// No description provided for @passwordRuleMet.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get passwordRuleMet;

  /// No description provided for @passwordRuleNotMet.
  ///
  /// In en, this message translates to:
  /// **'Not yet'**
  String get passwordRuleNotMet;

  /// No description provided for @passwordRuleServerChecked.
  ///
  /// In en, this message translates to:
  /// **'Checked by Montra'**
  String get passwordRuleServerChecked;

  /// No description provided for @validationPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Use at least {min} characters.'**
  String validationPasswordTooShort(int min);

  /// No description provided for @validationPasswordTooLong.
  ///
  /// In en, this message translates to:
  /// **'Use {max} characters or fewer.'**
  String validationPasswordTooLong(int max);

  /// No description provided for @currencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Main currency'**
  String get currencyLabel;

  /// No description provided for @currencyHelp.
  ///
  /// In en, this message translates to:
  /// **'The currency you use most often.'**
  String get currencyHelp;

  /// No description provided for @currencyPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a currency'**
  String get currencyPickerTitle;

  /// No description provided for @currencySearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by name or code'**
  String get currencySearchHint;

  /// No description provided for @currencyNoResults.
  ///
  /// In en, this message translates to:
  /// **'No currencies match \"{query}\".'**
  String currencyNoResults(String query);

  /// No description provided for @currencyLoadError.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t load the list of currencies.'**
  String get currencyLoadError;

  /// No description provided for @currencyNotChosen.
  ///
  /// In en, this message translates to:
  /// **'Not chosen'**
  String get currencyNotChosen;

  /// No description provided for @validationCurrencyRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose a currency.'**
  String get validationCurrencyRequired;

  /// No description provided for @deviceSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Taken from this device'**
  String get deviceSettingsTitle;

  /// No description provided for @deviceTimezone.
  ///
  /// In en, this message translates to:
  /// **'Time zone: {timezone}'**
  String deviceTimezone(String timezone);

  /// No description provided for @deviceTimezoneUnknown.
  ///
  /// In en, this message translates to:
  /// **'Time zone: not detected (Montra\'s default will be used)'**
  String get deviceTimezoneUnknown;

  /// No description provided for @deviceLocale.
  ///
  /// In en, this message translates to:
  /// **'Language and region: {locale}'**
  String deviceLocale(String locale);

  /// No description provided for @termsCheckbox.
  ///
  /// In en, this message translates to:
  /// **'I agree to the Terms of Service and Privacy Policy (version {version}).'**
  String termsCheckbox(String version);

  /// No description provided for @termsLink.
  ///
  /// In en, this message translates to:
  /// **'Read the Terms of Service'**
  String get termsLink;

  /// No description provided for @privacyLink.
  ///
  /// In en, this message translates to:
  /// **'Read the Privacy Policy'**
  String get privacyLink;

  /// No description provided for @validationTermsRequired.
  ///
  /// In en, this message translates to:
  /// **'Accept the terms to create an account.'**
  String get validationTermsRequired;

  /// No description provided for @adultCheckbox.
  ///
  /// In en, this message translates to:
  /// **'I\'m at least 18 years old.'**
  String get adultCheckbox;

  /// No description provided for @validationAdultRequired.
  ///
  /// In en, this message translates to:
  /// **'You must be at least 18 to use Montra.'**
  String get validationAdultRequired;

  /// No description provided for @signUpButton.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get signUpButton;

  /// No description provided for @signUpClosed.
  ///
  /// In en, this message translates to:
  /// **'New sign-ups are paused right now. Please try again later.'**
  String get signUpClosed;

  /// No description provided for @haveAccountPrompt.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get haveAccountPrompt;

  /// No description provided for @signInLink.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInLink;

  /// No description provided for @checkEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Check your email'**
  String get checkEmailTitle;

  /// No description provided for @checkEmailBody.
  ///
  /// In en, this message translates to:
  /// **'We\'ve sent a verification link to {email}. Open it on this device to finish setting up your account.'**
  String checkEmailBody(String email);

  /// No description provided for @checkEmailBodyNoAddress.
  ///
  /// In en, this message translates to:
  /// **'We\'ve sent you a verification link. Open it on this device to finish setting up your account.'**
  String get checkEmailBodyNoAddress;

  /// No description provided for @checkEmailSpamHint.
  ///
  /// In en, this message translates to:
  /// **'Can\'t find it? Check your spam or junk folder.'**
  String get checkEmailSpamHint;

  /// No description provided for @haveLinkButton.
  ///
  /// In en, this message translates to:
  /// **'I have the link'**
  String get haveLinkButton;

  /// No description provided for @resendEmailButton.
  ///
  /// In en, this message translates to:
  /// **'Resend email'**
  String get resendEmailButton;

  /// No description provided for @resendEmailCooldown.
  ///
  /// In en, this message translates to:
  /// **'Resend in {wait}'**
  String resendEmailCooldown(String wait);

  /// No description provided for @resendEmailSent.
  ///
  /// In en, this message translates to:
  /// **'If your account needs verification, a new link is on its way.'**
  String get resendEmailSent;

  /// No description provided for @backToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get backToSignIn;

  /// No description provided for @verifyEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify your email'**
  String get verifyEmailTitle;

  /// No description provided for @verifyingEmail.
  ///
  /// In en, this message translates to:
  /// **'Verifying your email…'**
  String get verifyingEmail;

  /// No description provided for @verifyEmailSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Email verified'**
  String get verifyEmailSuccessTitle;

  /// No description provided for @verifyEmailSuccessBody.
  ///
  /// In en, this message translates to:
  /// **'Thanks for confirming your email address. You can now sign in.'**
  String get verifyEmailSuccessBody;

  /// No description provided for @verifyEmailSuccessSignedInBody.
  ///
  /// In en, this message translates to:
  /// **'Thanks for confirming your email address.'**
  String get verifyEmailSuccessSignedInBody;

  /// No description provided for @verifyEmailExpired.
  ///
  /// In en, this message translates to:
  /// **'This verification link is invalid or has expired. Request a new one below.'**
  String get verifyEmailExpired;

  /// No description provided for @verifyEmailPasteBody.
  ///
  /// In en, this message translates to:
  /// **'Paste the verification link from your email.'**
  String get verifyEmailPasteBody;

  /// No description provided for @verifyEmailButton.
  ///
  /// In en, this message translates to:
  /// **'Verify email'**
  String get verifyEmailButton;

  /// No description provided for @resendSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Need a new link?'**
  String get resendSectionTitle;

  /// No description provided for @resendSectionBody.
  ///
  /// In en, this message translates to:
  /// **'Enter your email address and we\'ll send a new verification link.'**
  String get resendSectionBody;

  /// No description provided for @pasteLinkLabel.
  ///
  /// In en, this message translates to:
  /// **'Link from the email'**
  String get pasteLinkLabel;

  /// No description provided for @pasteFromClipboard.
  ///
  /// In en, this message translates to:
  /// **'Paste from clipboard'**
  String get pasteFromClipboard;

  /// No description provided for @validationLinkRequired.
  ///
  /// In en, this message translates to:
  /// **'Paste the link from the email.'**
  String get validationLinkRequired;

  /// No description provided for @validationLinkInvalid.
  ///
  /// In en, this message translates to:
  /// **'That doesn\'t look like a Montra link. Copy the whole link from the email.'**
  String get validationLinkInvalid;

  /// No description provided for @validationLinkIsReset.
  ///
  /// In en, this message translates to:
  /// **'This is a password reset link. Use it on the reset password screen.'**
  String get validationLinkIsReset;

  /// No description provided for @validationLinkIsVerify.
  ///
  /// In en, this message translates to:
  /// **'This is an email verification link. Use it on the verify email screen.'**
  String get validationLinkIsVerify;

  /// No description provided for @forgotTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset your password'**
  String get forgotTitle;

  /// No description provided for @forgotBody.
  ///
  /// In en, this message translates to:
  /// **'Enter the email address for your account and we\'ll send you a link to choose a new password.'**
  String get forgotBody;

  /// No description provided for @forgotButton.
  ///
  /// In en, this message translates to:
  /// **'Send reset link'**
  String get forgotButton;

  /// No description provided for @forgotSentTitle.
  ///
  /// In en, this message translates to:
  /// **'Check your email'**
  String get forgotSentTitle;

  /// No description provided for @forgotSentBody.
  ///
  /// In en, this message translates to:
  /// **'If an account exists for {email}, a reset link is on its way. Open it on this device.'**
  String forgotSentBody(String email);

  /// No description provided for @resetTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a new password'**
  String get resetTitle;

  /// No description provided for @resetPasteBody.
  ///
  /// In en, this message translates to:
  /// **'Paste the link from your password reset email.'**
  String get resetPasteBody;

  /// No description provided for @newPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPasswordLabel;

  /// No description provided for @confirmPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get confirmPasswordLabel;

  /// No description provided for @validationConfirmPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the new password again.'**
  String get validationConfirmPasswordRequired;

  /// No description provided for @validationPasswordsDontMatch.
  ///
  /// In en, this message translates to:
  /// **'The passwords don\'t match.'**
  String get validationPasswordsDontMatch;

  /// No description provided for @resetButton.
  ///
  /// In en, this message translates to:
  /// **'Update password'**
  String get resetButton;

  /// No description provided for @resetSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Password updated'**
  String get resetSuccessTitle;

  /// No description provided for @resetSuccessBody.
  ///
  /// In en, this message translates to:
  /// **'Your password has been changed and every device was signed out. Sign in with your new password.'**
  String get resetSuccessBody;

  /// No description provided for @resetExpired.
  ///
  /// In en, this message translates to:
  /// **'This reset link is invalid or has expired. Request a new one.'**
  String get resetExpired;

  /// No description provided for @requestNewLink.
  ///
  /// In en, this message translates to:
  /// **'Request a new link'**
  String get requestNewLink;

  /// No description provided for @splashRestoring.
  ///
  /// In en, this message translates to:
  /// **'Signing you in…'**
  String get splashRestoring;

  /// No description provided for @splashRestoreFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t reach Montra'**
  String get splashRestoreFailedTitle;

  /// No description provided for @splashRestoreFailedBody.
  ///
  /// In en, this message translates to:
  /// **'You\'re still signed in on this device. Check your connection and try again.'**
  String get splashRestoreFailedBody;

  /// No description provided for @splashSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out instead'**
  String get splashSignOut;

  /// No description provided for @notFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Page not found'**
  String get notFoundTitle;

  /// No description provided for @notFoundBody.
  ///
  /// In en, this message translates to:
  /// **'This link isn\'t available in the app.'**
  String get notFoundBody;

  /// No description provided for @goHome.
  ///
  /// In en, this message translates to:
  /// **'Go to Montra'**
  String get goHome;

  /// No description provided for @configErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Montra can\'t start'**
  String get configErrorTitle;

  /// No description provided for @configErrorBody.
  ///
  /// In en, this message translates to:
  /// **'This build of the app is not configured correctly. Please install an official build.'**
  String get configErrorBody;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profileSignedInAs.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {name}'**
  String profileSignedInAs(String name);

  /// No description provided for @emailVerifiedStatus.
  ///
  /// In en, this message translates to:
  /// **'Email verified'**
  String get emailVerifiedStatus;

  /// No description provided for @emailNotVerifiedStatus.
  ///
  /// In en, this message translates to:
  /// **'Email not verified'**
  String get emailNotVerifiedStatus;

  /// No description provided for @securityTitle.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get securityTitle;

  /// No description provided for @securitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Password, two-step verification and devices'**
  String get securitySubtitle;

  /// No description provided for @appearanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearanceTitle;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @signOutButton.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOutButton;

  /// No description provided for @signedOutOffline.
  ///
  /// In en, this message translates to:
  /// **'You\'re signed out on this device. We couldn\'t reach Montra, so that session will end on its own when it expires.'**
  String get signedOutOffline;

  /// No description provided for @statusOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get statusOn;

  /// No description provided for @statusOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get statusOff;

  /// No description provided for @twoStepTitle.
  ///
  /// In en, this message translates to:
  /// **'Two-step verification'**
  String get twoStepTitle;

  /// No description provided for @twoStepStatus.
  ///
  /// In en, this message translates to:
  /// **'Two-step verification: {status}'**
  String twoStepStatus(String status);

  /// No description provided for @twoStepSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A code from an authenticator app when you sign in'**
  String get twoStepSubtitle;

  /// No description provided for @sessionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Devices and sessions'**
  String get sessionsTitle;

  /// No description provided for @sessionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'See where you\'re signed in and sign out remotely'**
  String get sessionsSubtitle;

  /// No description provided for @changePasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePasswordTitle;

  /// No description provided for @changePasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Other devices will be signed out'**
  String get changePasswordSubtitle;

  /// No description provided for @signOutEverywhereButton.
  ///
  /// In en, this message translates to:
  /// **'Sign out of all devices'**
  String get signOutEverywhereButton;

  /// No description provided for @signOutEverywhereConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out of all devices?'**
  String get signOutEverywhereConfirmTitle;

  /// No description provided for @signOutEverywhereConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'You\'ll be signed out everywhere, including this device, and will need to sign in again.'**
  String get signOutEverywhereConfirmBody;

  /// No description provided for @signOutEverywhereConfirm.
  ///
  /// In en, this message translates to:
  /// **'Sign out everywhere'**
  String get signOutEverywhereConfirm;

  /// No description provided for @sessionsEmpty.
  ///
  /// In en, this message translates to:
  /// **'There are no active sessions.'**
  String get sessionsEmpty;

  /// No description provided for @sessionCurrentDevice.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get sessionCurrentDevice;

  /// No description provided for @sessionLastActive.
  ///
  /// In en, this message translates to:
  /// **'Last active {time}'**
  String sessionLastActive(String time);

  /// No description provided for @sessionSignedInOn.
  ///
  /// In en, this message translates to:
  /// **'Signed in {date}'**
  String sessionSignedInOn(String date);

  /// No description provided for @sessionTwoStepVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified with two-step verification'**
  String get sessionTwoStepVerified;

  /// No description provided for @sessionClientAndroid.
  ///
  /// In en, this message translates to:
  /// **'Android app'**
  String get sessionClientAndroid;

  /// No description provided for @sessionClientIos.
  ///
  /// In en, this message translates to:
  /// **'iPhone or iPad app'**
  String get sessionClientIos;

  /// No description provided for @sessionClientWeb.
  ///
  /// In en, this message translates to:
  /// **'Web browser'**
  String get sessionClientWeb;

  /// No description provided for @sessionClientUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown device'**
  String get sessionClientUnknown;

  /// No description provided for @sessionRevoke.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get sessionRevoke;

  /// No description provided for @sessionRevokeLabel.
  ///
  /// In en, this message translates to:
  /// **'Sign out {device}'**
  String sessionRevokeLabel(String device);

  /// No description provided for @sessionRevokeConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out this device?'**
  String get sessionRevokeConfirmTitle;

  /// No description provided for @sessionRevokeConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'{device} will be signed out and will need to sign in again.'**
  String sessionRevokeConfirmBody(String device);

  /// No description provided for @sessionRevoked.
  ///
  /// In en, this message translates to:
  /// **'Device signed out.'**
  String get sessionRevoked;

  /// No description provided for @sessionAlreadyEnded.
  ///
  /// In en, this message translates to:
  /// **'That session had already ended.'**
  String get sessionAlreadyEnded;

  /// No description provided for @relativeJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get relativeJustNow;

  /// No description provided for @relativeMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 minute ago} other{{count} minutes ago}}'**
  String relativeMinutesAgo(int count);

  /// No description provided for @relativeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hour ago} other{{count} hours ago}}'**
  String relativeHoursAgo(int count);

  /// No description provided for @relativeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{yesterday} other{{count} days ago}}'**
  String relativeDaysAgo(int count);

  /// No description provided for @currentPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get currentPasswordLabel;

  /// No description provided for @changePasswordButton.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePasswordButton;

  /// No description provided for @changePasswordSuccess.
  ///
  /// In en, this message translates to:
  /// **'Password changed. Your other devices have been signed out.'**
  String get changePasswordSuccess;

  /// No description provided for @twoStepIntro.
  ///
  /// In en, this message translates to:
  /// **'Each time you sign in, you\'ll also enter a code from an authenticator app. This keeps your account safe even if someone learns your password.'**
  String get twoStepIntro;

  /// No description provided for @twoStepSetupButton.
  ///
  /// In en, this message translates to:
  /// **'Set up two-step verification'**
  String get twoStepSetupButton;

  /// No description provided for @twoStepScanTitle.
  ///
  /// In en, this message translates to:
  /// **'1. Add Montra to your authenticator app'**
  String get twoStepScanTitle;

  /// No description provided for @twoStepScanBody.
  ///
  /// In en, this message translates to:
  /// **'Scan this QR code with an authenticator app on another device, or open the setup link with an authenticator app on this device.'**
  String get twoStepScanBody;

  /// No description provided for @twoStepQrSemantics.
  ///
  /// In en, this message translates to:
  /// **'QR code for adding Montra to an authenticator app'**
  String get twoStepQrSemantics;

  /// No description provided for @twoStepOpenApp.
  ///
  /// In en, this message translates to:
  /// **'Open in authenticator app'**
  String get twoStepOpenApp;

  /// No description provided for @twoStepNoApp.
  ///
  /// In en, this message translates to:
  /// **'No app on this device could open the setup link. Enter the setup key instead.'**
  String get twoStepNoApp;

  /// No description provided for @twoStepManualTitle.
  ///
  /// In en, this message translates to:
  /// **'Or enter this setup key'**
  String get twoStepManualTitle;

  /// No description provided for @twoStepCopyKey.
  ///
  /// In en, this message translates to:
  /// **'Copy setup key'**
  String get twoStepCopyKey;

  /// No description provided for @twoStepVerifyTitle.
  ///
  /// In en, this message translates to:
  /// **'2. Enter the 6-digit code it shows'**
  String get twoStepVerifyTitle;

  /// No description provided for @twoStepActivateButton.
  ///
  /// In en, this message translates to:
  /// **'Turn on two-step verification'**
  String get twoStepActivateButton;

  /// No description provided for @twoStepCancelSetup.
  ///
  /// In en, this message translates to:
  /// **'Cancel setup'**
  String get twoStepCancelSetup;

  /// No description provided for @twoStepEnabledBody.
  ///
  /// In en, this message translates to:
  /// **'Two-step verification is on. You\'ll enter a code from your authenticator app when you sign in.'**
  String get twoStepEnabledBody;

  /// No description provided for @twoStepEnabledNotice.
  ///
  /// In en, this message translates to:
  /// **'Two-step verification is on.'**
  String get twoStepEnabledNotice;

  /// No description provided for @twoStepRegenerate.
  ///
  /// In en, this message translates to:
  /// **'Generate new recovery codes'**
  String get twoStepRegenerate;

  /// No description provided for @twoStepRegenerateConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Generate new recovery codes?'**
  String get twoStepRegenerateConfirmTitle;

  /// No description provided for @twoStepRegenerateConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Your current recovery codes will stop working immediately.'**
  String get twoStepRegenerateConfirmBody;

  /// No description provided for @twoStepRegenerateConfirm.
  ///
  /// In en, this message translates to:
  /// **'Generate new codes'**
  String get twoStepRegenerateConfirm;

  /// No description provided for @twoStepDisable.
  ///
  /// In en, this message translates to:
  /// **'Turn off two-step verification'**
  String get twoStepDisable;

  /// No description provided for @twoStepDisableBody.
  ///
  /// In en, this message translates to:
  /// **'To turn off two-step verification, enter a code from your authenticator app or one of your recovery codes.'**
  String get twoStepDisableBody;

  /// No description provided for @twoStepDisableConfirm.
  ///
  /// In en, this message translates to:
  /// **'Turn off'**
  String get twoStepDisableConfirm;

  /// No description provided for @twoStepDisabledNotice.
  ///
  /// In en, this message translates to:
  /// **'Two-step verification is off.'**
  String get twoStepDisabledNotice;

  /// No description provided for @twoStepDisableCodeRejected.
  ///
  /// In en, this message translates to:
  /// **'That code didn\'t work. Each code works only once: if you just used it to confirm it\'s you, wait for the next code and try again, or use a recovery code.'**
  String get twoStepDisableCodeRejected;

  /// No description provided for @recoveryCodesTitle.
  ///
  /// In en, this message translates to:
  /// **'Save your recovery codes'**
  String get recoveryCodesTitle;

  /// No description provided for @recoveryCodesBody.
  ///
  /// In en, this message translates to:
  /// **'If you lose access to your authenticator app, you can sign in with one of these codes. Each code works once. This is the only time they\'ll be shown.'**
  String get recoveryCodesBody;

  /// No description provided for @recoveryCodesListLabel.
  ///
  /// In en, this message translates to:
  /// **'Recovery codes'**
  String get recoveryCodesListLabel;

  /// No description provided for @recoveryCodesCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy codes'**
  String get recoveryCodesCopy;

  /// No description provided for @recoveryCodesCopied.
  ///
  /// In en, this message translates to:
  /// **'Recovery codes copied. Store them somewhere safe, such as a password manager.'**
  String get recoveryCodesCopied;

  /// No description provided for @recoveryCodesConfirm.
  ///
  /// In en, this message translates to:
  /// **'I\'ve saved my recovery codes'**
  String get recoveryCodesConfirm;

  /// No description provided for @recoveryCodesLeaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave without saving?'**
  String get recoveryCodesLeaveTitle;

  /// No description provided for @recoveryCodesLeaveBody.
  ///
  /// In en, this message translates to:
  /// **'These codes won\'t be shown again. You can generate new ones later, which replaces them.'**
  String get recoveryCodesLeaveBody;

  /// No description provided for @recoveryCodesLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get recoveryCodesLeave;

  /// No description provided for @recoveryCodesStay.
  ///
  /// In en, this message translates to:
  /// **'Stay'**
  String get recoveryCodesStay;

  /// No description provided for @reauthTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm it\'s you'**
  String get reauthTitle;

  /// No description provided for @reauthBody.
  ///
  /// In en, this message translates to:
  /// **'For your security, enter your password to continue.'**
  String get reauthBody;

  /// No description provided for @reauthBodyWithCode.
  ///
  /// In en, this message translates to:
  /// **'For your security, enter your password and a code from your authenticator app to continue.'**
  String get reauthBodyWithCode;

  /// No description provided for @reauthBodyWithRecovery.
  ///
  /// In en, this message translates to:
  /// **'For your security, enter your password and one of your unused recovery codes to continue.'**
  String get reauthBodyWithRecovery;

  /// No description provided for @reauthButton.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get reauthButton;

  /// No description provided for @reauthWrongPassword.
  ///
  /// In en, this message translates to:
  /// **'The password is incorrect.'**
  String get reauthWrongPassword;

  /// No description provided for @reauthCodeInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid code from your authenticator app.'**
  String get reauthCodeInvalid;

  /// No description provided for @reauthRecoveryInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter an unused recovery code.'**
  String get reauthRecoveryInvalid;

  /// No description provided for @confirmDestructiveDefault.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirmDestructiveDefault;

  /// No description provided for @errorStillSaving.
  ///
  /// In en, this message translates to:
  /// **'Your last request is still being saved. Wait a moment, then check before trying again.'**
  String get errorStillSaving;

  /// No description provided for @errorRequestChanged.
  ///
  /// In en, this message translates to:
  /// **'This request changed while it was being sent. Review the details and save again.'**
  String get errorRequestChanged;

  /// No description provided for @versionConflictReloaded.
  ///
  /// In en, this message translates to:
  /// **'This was changed somewhere else, so we loaded the latest version. Review it and make your change again.'**
  String get versionConflictReloaded;

  /// No description provided for @moneyMinusWord.
  ///
  /// In en, this message translates to:
  /// **'minus'**
  String get moneyMinusWord;

  /// Screen-reader text for money coming in.
  ///
  /// In en, this message translates to:
  /// **'received {amount}'**
  String moneyInflowSemantics(String amount);

  /// Screen-reader text for money going out.
  ///
  /// In en, this message translates to:
  /// **'spent {amount}'**
  String moneyOutflowSemantics(String amount);

  /// No description provided for @amountRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount.'**
  String get amountRequired;

  /// No description provided for @amountInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a number, for example 1250.50.'**
  String get amountInvalid;

  /// No description provided for @amountTooPrecise.
  ///
  /// In en, this message translates to:
  /// **'Use at most {decimals, plural, =1{1 decimal place} other{{decimals} decimal places}}.'**
  String amountTooPrecise(int decimals);

  /// No description provided for @amountNoDecimals.
  ///
  /// In en, this message translates to:
  /// **'This currency has no decimal places.'**
  String get amountNoDecimals;

  /// No description provided for @amountNotPositive.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount greater than zero.'**
  String get amountNotPositive;

  /// No description provided for @amountNegative.
  ///
  /// In en, this message translates to:
  /// **'The amount can\'t be negative.'**
  String get amountNegative;

  /// No description provided for @amountTooLarge.
  ///
  /// In en, this message translates to:
  /// **'That amount is too large.'**
  String get amountTooLarge;

  /// No description provided for @selectorNotChosen.
  ///
  /// In en, this message translates to:
  /// **'Not chosen'**
  String get selectorNotChosen;

  /// No description provided for @selectorChangeHint.
  ///
  /// In en, this message translates to:
  /// **'Double-tap to change'**
  String get selectorChangeHint;

  /// No description provided for @selectorClear.
  ///
  /// In en, this message translates to:
  /// **'Clear {field}'**
  String selectorClear(String field);

  /// No description provided for @selectedLabel.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get selectedLabel;

  /// No description provided for @chartShowTable.
  ///
  /// In en, this message translates to:
  /// **'Show as a list'**
  String get chartShowTable;

  /// No description provided for @chartShowChart.
  ///
  /// In en, this message translates to:
  /// **'Show as a chart'**
  String get chartShowChart;

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// No description provided for @actionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get actionEdit;

  /// No description provided for @actionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actionDelete;

  /// No description provided for @actionRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get actionRestore;

  /// No description provided for @actionAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get actionAdd;

  /// No description provided for @actionApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get actionApply;

  /// No description provided for @actionReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get actionReset;

  /// No description provided for @actionSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get actionSeeAll;

  /// No description provided for @actionSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get actionSkip;

  /// No description provided for @actionBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get actionBack;

  /// No description provided for @actionNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get actionNext;

  /// No description provided for @actionMore.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get actionMore;

  /// No description provided for @actionClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get actionClear;

  /// No description provided for @actionLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get actionLoadMore;

  /// No description provided for @optionalLabel.
  ///
  /// In en, this message translates to:
  /// **'{field} (optional)'**
  String optionalLabel(String field);

  /// No description provided for @dateToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get dateToday;

  /// No description provided for @refreshFailedStale.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t refresh. Showing figures from {time}.'**
  String refreshFailedStale(String time);

  /// No description provided for @updatedAt.
  ///
  /// In en, this message translates to:
  /// **'Updated {time}'**
  String updatedAt(String time);

  /// No description provided for @noneOption.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get noneOption;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchHint;

  /// No description provided for @validationRequired.
  ///
  /// In en, this message translates to:
  /// **'This field is required.'**
  String get validationRequired;

  /// No description provided for @validationTooLong.
  ///
  /// In en, this message translates to:
  /// **'Use {max} characters or fewer.'**
  String validationTooLong(int max);

  /// No description provided for @offlineSaveHint.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline. We\'ll keep what you entered; save again when you\'re back online.'**
  String get offlineSaveHint;

  /// No description provided for @possibleDuplicateNotice.
  ///
  /// In en, this message translates to:
  /// **'This looks similar to {count, plural, =1{another transaction} other{{count} other transactions}}. Nothing was merged.'**
  String possibleDuplicateNotice(int count);

  /// No description provided for @possibleDuplicateReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get possibleDuplicateReview;

  /// No description provided for @starterFoodDining.
  ///
  /// In en, this message translates to:
  /// **'Food & dining'**
  String get starterFoodDining;

  /// No description provided for @starterGroceries.
  ///
  /// In en, this message translates to:
  /// **'Groceries'**
  String get starterGroceries;

  /// No description provided for @starterTransport.
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get starterTransport;

  /// No description provided for @starterFuel.
  ///
  /// In en, this message translates to:
  /// **'Fuel'**
  String get starterFuel;

  /// No description provided for @starterHousingRent.
  ///
  /// In en, this message translates to:
  /// **'Housing & rent'**
  String get starterHousingRent;

  /// No description provided for @starterUtilities.
  ///
  /// In en, this message translates to:
  /// **'Utilities'**
  String get starterUtilities;

  /// No description provided for @starterShopping.
  ///
  /// In en, this message translates to:
  /// **'Shopping'**
  String get starterShopping;

  /// No description provided for @starterHealthcare.
  ///
  /// In en, this message translates to:
  /// **'Healthcare'**
  String get starterHealthcare;

  /// No description provided for @starterEducation.
  ///
  /// In en, this message translates to:
  /// **'Education'**
  String get starterEducation;

  /// No description provided for @starterEntertainment.
  ///
  /// In en, this message translates to:
  /// **'Entertainment'**
  String get starterEntertainment;

  /// No description provided for @starterTravel.
  ///
  /// In en, this message translates to:
  /// **'Travel'**
  String get starterTravel;

  /// No description provided for @starterPersonalCare.
  ///
  /// In en, this message translates to:
  /// **'Personal care'**
  String get starterPersonalCare;

  /// No description provided for @starterInsurance.
  ///
  /// In en, this message translates to:
  /// **'Insurance'**
  String get starterInsurance;

  /// No description provided for @starterTaxesFees.
  ///
  /// In en, this message translates to:
  /// **'Taxes & fees'**
  String get starterTaxesFees;

  /// No description provided for @starterGiftsDonations.
  ///
  /// In en, this message translates to:
  /// **'Gifts & donations'**
  String get starterGiftsDonations;

  /// No description provided for @starterFamily.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get starterFamily;

  /// No description provided for @starterWorkExpenses.
  ///
  /// In en, this message translates to:
  /// **'Work expenses'**
  String get starterWorkExpenses;

  /// No description provided for @starterSalary.
  ///
  /// In en, this message translates to:
  /// **'Salary'**
  String get starterSalary;

  /// No description provided for @starterFreelanceIncome.
  ///
  /// In en, this message translates to:
  /// **'Freelance income'**
  String get starterFreelanceIncome;

  /// No description provided for @starterInterest.
  ///
  /// In en, this message translates to:
  /// **'Interest'**
  String get starterInterest;

  /// No description provided for @starterRefunds.
  ///
  /// In en, this message translates to:
  /// **'Refunds'**
  String get starterRefunds;

  /// No description provided for @starterOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get starterOther;

  /// No description provided for @subcategoryOf.
  ///
  /// In en, this message translates to:
  /// **'{name}, subcategory of {parent}'**
  String subcategoryOf(String name, String parent);

  /// No description provided for @categoryPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a category'**
  String get categoryPickerTitle;

  /// No description provided for @categoryPickerEmpty.
  ///
  /// In en, this message translates to:
  /// **'There are no categories to choose from.'**
  String get categoryPickerEmpty;

  /// No description provided for @categoryNone.
  ///
  /// In en, this message translates to:
  /// **'No category'**
  String get categoryNone;

  /// No description provided for @categoryUncategorized.
  ///
  /// In en, this message translates to:
  /// **'Uncategorized'**
  String get categoryUncategorized;

  /// No description provided for @selectionEmpty.
  ///
  /// In en, this message translates to:
  /// **'There\'s nothing to choose yet.'**
  String get selectionEmpty;

  /// No description provided for @selectionNoMatches.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches \"{query}\".'**
  String selectionNoMatches(String query);

  /// No description provided for @tagPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a tag'**
  String get tagPickerTitle;

  /// No description provided for @tagPickerEmpty.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have any tags yet. Type a name to create one.'**
  String get tagPickerEmpty;

  /// No description provided for @tagCreate.
  ///
  /// In en, this message translates to:
  /// **'Create tag \"{name}\"'**
  String tagCreate(String name);

  /// No description provided for @tagUsage.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Not used yet} =1{Used once} other{Used {count} times}}'**
  String tagUsage(int count);

  /// No description provided for @merchantPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a merchant'**
  String get merchantPickerTitle;

  /// No description provided for @merchantSearchLabel.
  ///
  /// In en, this message translates to:
  /// **'Search or type a new name'**
  String get merchantSearchLabel;

  /// No description provided for @merchantSearchPrompt.
  ///
  /// In en, this message translates to:
  /// **'Type a few letters to find a merchant you\'ve used before.'**
  String get merchantSearchPrompt;

  /// No description provided for @merchantUseName.
  ///
  /// In en, this message translates to:
  /// **'Use \"{name}\"'**
  String merchantUseName(String name);

  /// No description provided for @merchantUseNameHelp.
  ///
  /// In en, this message translates to:
  /// **'Matched to an existing merchant or added as a new one'**
  String get merchantUseNameHelp;

  /// No description provided for @merchantNone.
  ///
  /// In en, this message translates to:
  /// **'No merchant'**
  String get merchantNone;

  /// No description provided for @merchantNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No saved merchants match \"{query}\".'**
  String merchantNoMatches(String query);

  /// No description provided for @merchantTransactionCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No transactions} =1{1 transaction} other{{count} transactions}}'**
  String merchantTransactionCount(int count);

  /// No description provided for @accountTypeCash.
  ///
  /// In en, this message translates to:
  /// **'Cash wallet'**
  String get accountTypeCash;

  /// No description provided for @accountTypeBank.
  ///
  /// In en, this message translates to:
  /// **'Bank account'**
  String get accountTypeBank;

  /// No description provided for @accountTypeSavings.
  ///
  /// In en, this message translates to:
  /// **'Savings account'**
  String get accountTypeSavings;

  /// No description provided for @accountTypeCreditCard.
  ///
  /// In en, this message translates to:
  /// **'Credit card'**
  String get accountTypeCreditCard;

  /// No description provided for @accountTypeDebitCard.
  ///
  /// In en, this message translates to:
  /// **'Debit card'**
  String get accountTypeDebitCard;

  /// No description provided for @accountTypePrepaidCard.
  ///
  /// In en, this message translates to:
  /// **'Prepaid card'**
  String get accountTypePrepaidCard;

  /// No description provided for @accountTypeDigitalWallet.
  ///
  /// In en, this message translates to:
  /// **'Digital wallet'**
  String get accountTypeDigitalWallet;

  /// No description provided for @accountTypeUpi.
  ///
  /// In en, this message translates to:
  /// **'UPI / payment wallet'**
  String get accountTypeUpi;

  /// No description provided for @accountTypeLoan.
  ///
  /// In en, this message translates to:
  /// **'Loan'**
  String get accountTypeLoan;

  /// No description provided for @accountTypeInvestment.
  ///
  /// In en, this message translates to:
  /// **'Investment'**
  String get accountTypeInvestment;

  /// No description provided for @accountTypeHouseholdLedger.
  ///
  /// In en, this message translates to:
  /// **'Household ledger'**
  String get accountTypeHouseholdLedger;

  /// No description provided for @accountTypeCustom.
  ///
  /// In en, this message translates to:
  /// **'Other account'**
  String get accountTypeCustom;

  /// No description provided for @balanceSourceManual.
  ///
  /// In en, this message translates to:
  /// **'Entered by you'**
  String get balanceSourceManual;

  /// No description provided for @balanceSourceCalculated.
  ///
  /// In en, this message translates to:
  /// **'Calculated from your entries'**
  String get balanceSourceCalculated;

  /// No description provided for @balanceSourceImported.
  ///
  /// In en, this message translates to:
  /// **'From imported statements'**
  String get balanceSourceImported;

  /// No description provided for @balanceSourceProvider.
  ///
  /// In en, this message translates to:
  /// **'Synced from a provider'**
  String get balanceSourceProvider;

  /// No description provided for @accountStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get accountStatusActive;

  /// No description provided for @accountStatusArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get accountStatusArchived;

  /// No description provided for @accountStatusClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get accountStatusClosed;

  /// No description provided for @accountPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose an account'**
  String get accountPickerTitle;

  /// No description provided for @accountPickerEmpty.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have an active account yet. Add one from Profile → Accounts.'**
  String get accountPickerEmpty;

  /// No description provided for @balanceOwed.
  ///
  /// In en, this message translates to:
  /// **'Owed'**
  String get balanceOwed;

  /// No description provided for @balanceInCredit.
  ///
  /// In en, this message translates to:
  /// **'In credit'**
  String get balanceInCredit;

  /// No description provided for @balanceOverdrawn.
  ///
  /// In en, this message translates to:
  /// **'Overdrawn'**
  String get balanceOverdrawn;

  /// No description provided for @accountBalanceLabel.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get accountBalanceLabel;

  /// No description provided for @accountSharedReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Shared with you · read-only'**
  String get accountSharedReadOnly;

  /// No description provided for @accountNotInOverview.
  ///
  /// In en, this message translates to:
  /// **'Not in overview'**
  String get accountNotInOverview;

  /// No description provided for @accountsTitle.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get accountsTitle;

  /// No description provided for @accountAdd.
  ///
  /// In en, this message translates to:
  /// **'Add account'**
  String get accountAdd;

  /// No description provided for @accountAddFirst.
  ///
  /// In en, this message translates to:
  /// **'Add your first account'**
  String get accountAddFirst;

  /// No description provided for @accountsShowArchived.
  ///
  /// In en, this message translates to:
  /// **'Show archived and closed accounts'**
  String get accountsShowArchived;

  /// No description provided for @accountsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No accounts yet'**
  String get accountsEmptyTitle;

  /// No description provided for @accountsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add a cash wallet, bank account or card to start tracking. You never need to connect a bank.'**
  String get accountsEmptyBody;

  /// No description provided for @accountGroupHeading.
  ///
  /// In en, this message translates to:
  /// **'{type} ({count})'**
  String accountGroupHeading(String type, int count);

  /// No description provided for @accountsTotalsTitle.
  ///
  /// In en, this message translates to:
  /// **'Totals (tracked)'**
  String get accountsTotalsTitle;

  /// No description provided for @currencyHeading.
  ///
  /// In en, this message translates to:
  /// **'In {currency}'**
  String currencyHeading(String currency);

  /// No description provided for @netWorthLabel.
  ///
  /// In en, this message translates to:
  /// **'Net worth'**
  String get netWorthLabel;

  /// No description provided for @assetsLabel.
  ///
  /// In en, this message translates to:
  /// **'Assets'**
  String get assetsLabel;

  /// No description provided for @liabilitiesLabel.
  ///
  /// In en, this message translates to:
  /// **'Owed on cards and loans'**
  String get liabilitiesLabel;

  /// No description provided for @trackedBalanceNote.
  ///
  /// In en, this message translates to:
  /// **'Balances are tracked from your entries and imports. They are not verified by a bank.'**
  String get trackedBalanceNote;

  /// No description provided for @providerBalanceNote.
  ///
  /// In en, this message translates to:
  /// **'This balance is synced from a connected provider.'**
  String get providerBalanceNote;

  /// No description provided for @accountDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountDetailTitle;

  /// No description provided for @accountAdjustBalance.
  ///
  /// In en, this message translates to:
  /// **'Adjust balance'**
  String get accountAdjustBalance;

  /// No description provided for @accountArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get accountArchive;

  /// No description provided for @accountClose.
  ///
  /// In en, this message translates to:
  /// **'Close account'**
  String get accountClose;

  /// No description provided for @accountArchiveConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Archive this account?'**
  String get accountArchiveConfirmTitle;

  /// No description provided for @accountArchiveConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'{name} and its history stay in your reports, but you can\'t add new transactions to it until you restore it.'**
  String accountArchiveConfirmBody(String name);

  /// No description provided for @accountCloseConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Close this account?'**
  String get accountCloseConfirmTitle;

  /// No description provided for @accountCloseConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'{name} will be marked closed and kept in your history. Only an account with a zero balance can be closed. You can restore it later.'**
  String accountCloseConfirmBody(String name);

  /// No description provided for @accountArchived.
  ///
  /// In en, this message translates to:
  /// **'Account archived.'**
  String get accountArchived;

  /// No description provided for @accountRestored.
  ///
  /// In en, this message translates to:
  /// **'Account restored.'**
  String get accountRestored;

  /// No description provided for @accountClosed.
  ///
  /// In en, this message translates to:
  /// **'Account closed.'**
  String get accountClosed;

  /// No description provided for @accountArchivedNotice.
  ///
  /// In en, this message translates to:
  /// **'This account is archived. Its history is kept; restore it to add transactions.'**
  String get accountArchivedNotice;

  /// No description provided for @accountClosedNotice.
  ///
  /// In en, this message translates to:
  /// **'This account is closed. Its history is kept; restore it to use it again.'**
  String get accountClosedNotice;

  /// No description provided for @creditLimitLabel.
  ///
  /// In en, this message translates to:
  /// **'Credit limit'**
  String get creditLimitLabel;

  /// No description provided for @availableCreditLabel.
  ///
  /// In en, this message translates to:
  /// **'Available credit'**
  String get availableCreditLabel;

  /// No description provided for @statementDayLabel.
  ///
  /// In en, this message translates to:
  /// **'Statement day'**
  String get statementDayLabel;

  /// No description provided for @paymentDueDayLabel.
  ///
  /// In en, this message translates to:
  /// **'Payment due day'**
  String get paymentDueDayLabel;

  /// No description provided for @dayOfMonth.
  ///
  /// In en, this message translates to:
  /// **'Day {day} of the month'**
  String dayOfMonth(int day);

  /// No description provided for @notSetLabel.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get notSetLabel;

  /// No description provided for @transactionAddExpense.
  ///
  /// In en, this message translates to:
  /// **'Add expense'**
  String get transactionAddExpense;

  /// No description provided for @transactionAddIncome.
  ///
  /// In en, this message translates to:
  /// **'Add income'**
  String get transactionAddIncome;

  /// No description provided for @transferAdd.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get transferAdd;

  /// No description provided for @balanceHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Balance over the last 30 days'**
  String get balanceHistoryTitle;

  /// No description provided for @balanceHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'There\'s no balance history yet.'**
  String get balanceHistoryEmpty;

  /// No description provided for @balanceHistorySummary.
  ///
  /// In en, this message translates to:
  /// **'The balance went from {fromAmount} on {fromDate} to {toAmount} on {toDate}. Lowest {low}, highest {high}.'**
  String balanceHistorySummary(
    String fromDate,
    String fromAmount,
    String toDate,
    String toAmount,
    String low,
    String high,
  );

  /// No description provided for @recentTransactionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent transactions'**
  String get recentTransactionsTitle;

  /// No description provided for @accountSeeAllTransactions.
  ///
  /// In en, this message translates to:
  /// **'See all transactions in {name}'**
  String accountSeeAllTransactions(String name);

  /// No description provided for @accountNoTransactions.
  ///
  /// In en, this message translates to:
  /// **'No transactions in this account yet.'**
  String get accountNoTransactions;

  /// No description provided for @accountDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get accountDetailsTitle;

  /// No description provided for @currencyFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get currencyFieldLabel;

  /// No description provided for @openingDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Opening date'**
  String get openingDateLabel;

  /// No description provided for @includeInOverviewLabel.
  ///
  /// In en, this message translates to:
  /// **'Include in overview'**
  String get includeInOverviewLabel;

  /// No description provided for @includeInOverviewHelp.
  ///
  /// In en, this message translates to:
  /// **'Counts towards the balances on Home.'**
  String get includeInOverviewHelp;

  /// No description provided for @lastReconciledLabel.
  ///
  /// In en, this message translates to:
  /// **'Last reconciled'**
  String get lastReconciledLabel;

  /// No description provided for @lastImportLabel.
  ///
  /// In en, this message translates to:
  /// **'Last import'**
  String get lastImportLabel;

  /// No description provided for @notesLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notesLabel;

  /// No description provided for @colorTeal.
  ///
  /// In en, this message translates to:
  /// **'Teal'**
  String get colorTeal;

  /// No description provided for @colorBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get colorBlue;

  /// No description provided for @colorPurple.
  ///
  /// In en, this message translates to:
  /// **'Purple'**
  String get colorPurple;

  /// No description provided for @colorRose.
  ///
  /// In en, this message translates to:
  /// **'Rose'**
  String get colorRose;

  /// No description provided for @colorOrange.
  ///
  /// In en, this message translates to:
  /// **'Orange'**
  String get colorOrange;

  /// No description provided for @colorSand.
  ///
  /// In en, this message translates to:
  /// **'Sand'**
  String get colorSand;

  /// No description provided for @colorGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get colorGreen;

  /// No description provided for @colorGrey.
  ///
  /// In en, this message translates to:
  /// **'Grey'**
  String get colorGrey;

  /// No description provided for @colorNone.
  ///
  /// In en, this message translates to:
  /// **'No color'**
  String get colorNone;

  /// No description provided for @accountNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New account'**
  String get accountNewTitle;

  /// No description provided for @accountEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit account'**
  String get accountEditTitle;

  /// No description provided for @accountCreated.
  ///
  /// In en, this message translates to:
  /// **'Account added.'**
  String get accountCreated;

  /// No description provided for @accountSaved.
  ///
  /// In en, this message translates to:
  /// **'Account saved.'**
  String get accountSaved;

  /// No description provided for @accountNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Account name'**
  String get accountNameLabel;

  /// No description provided for @accountNameHelp.
  ///
  /// In en, this message translates to:
  /// **'For example \"HDFC savings\" or \"Wallet\".'**
  String get accountNameHelp;

  /// No description provided for @accountTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get accountTypeLabel;

  /// No description provided for @accountTypeFixed.
  ///
  /// In en, this message translates to:
  /// **'The type can\'t change after the account is created.'**
  String get accountTypeFixed;

  /// No description provided for @accountCurrencyChangeHelp.
  ///
  /// In en, this message translates to:
  /// **'You can change the currency only until the first transaction is recorded.'**
  String get accountCurrencyChangeHelp;

  /// No description provided for @openingBalanceSection.
  ///
  /// In en, this message translates to:
  /// **'Opening balance'**
  String get openingBalanceSection;

  /// No description provided for @openingOwed.
  ///
  /// In en, this message translates to:
  /// **'I owe this'**
  String get openingOwed;

  /// No description provided for @openingInCredit.
  ///
  /// In en, this message translates to:
  /// **'It\'s in credit'**
  String get openingInCredit;

  /// No description provided for @openingOwedLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount owed now'**
  String get openingOwedLabel;

  /// No description provided for @openingCreditLabel.
  ///
  /// In en, this message translates to:
  /// **'Credit balance now'**
  String get openingCreditLabel;

  /// No description provided for @openingBalanceLabel.
  ///
  /// In en, this message translates to:
  /// **'Balance now'**
  String get openingBalanceLabel;

  /// No description provided for @openingBalanceHelp.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to start at zero. Use a minus sign if the account is overdrawn.'**
  String get openingBalanceHelp;

  /// No description provided for @openingLiabilityHelp.
  ///
  /// In en, this message translates to:
  /// **'Leave empty if nothing is owed.'**
  String get openingLiabilityHelp;

  /// No description provided for @accountMoreDetails.
  ///
  /// In en, this message translates to:
  /// **'More details'**
  String get accountMoreDetails;

  /// No description provided for @institutionLabel.
  ///
  /// In en, this message translates to:
  /// **'Bank or provider name'**
  String get institutionLabel;

  /// No description provided for @maskedNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Last digits'**
  String get maskedNumberLabel;

  /// No description provided for @maskedNumberHelp.
  ///
  /// In en, this message translates to:
  /// **'Only the last 2–4 digits. Never enter a full card or account number, CVV or PIN.'**
  String get maskedNumberHelp;

  /// No description provided for @maskedNumberInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter 2 to 4 digits.'**
  String get maskedNumberInvalid;

  /// No description provided for @accountColorLabel.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get accountColorLabel;

  /// No description provided for @accountCreateButton.
  ///
  /// In en, this message translates to:
  /// **'Add account'**
  String get accountCreateButton;

  /// No description provided for @adjustTitle.
  ///
  /// In en, this message translates to:
  /// **'Adjust balance'**
  String get adjustTitle;

  /// No description provided for @adjustIntro.
  ///
  /// In en, this message translates to:
  /// **'If {name} doesn\'t match your bank or wallet, record a correction. It\'s saved as an adjustment with your reason, so your history stays complete.'**
  String adjustIntro(String name);

  /// No description provided for @adjustCurrentBalance.
  ///
  /// In en, this message translates to:
  /// **'Current tracked balance'**
  String get adjustCurrentBalance;

  /// No description provided for @adjustModeTarget.
  ///
  /// In en, this message translates to:
  /// **'Set the balance'**
  String get adjustModeTarget;

  /// No description provided for @adjustModeDelta.
  ///
  /// In en, this message translates to:
  /// **'Change by'**
  String get adjustModeDelta;

  /// No description provided for @adjustTargetLabel.
  ///
  /// In en, this message translates to:
  /// **'Correct balance'**
  String get adjustTargetLabel;

  /// No description provided for @adjustDeltaLabel.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get adjustDeltaLabel;

  /// No description provided for @adjustTargetHelp.
  ///
  /// In en, this message translates to:
  /// **'The balance the account should show. Use a minus sign for an overdraft.'**
  String get adjustTargetHelp;

  /// No description provided for @adjustTargetLiabilityHelp.
  ///
  /// In en, this message translates to:
  /// **'For a card or loan, enter what you owe as a negative number, for example -2500.'**
  String get adjustTargetLiabilityHelp;

  /// No description provided for @adjustDeltaHelp.
  ///
  /// In en, this message translates to:
  /// **'Positive adds money, negative removes it.'**
  String get adjustDeltaHelp;

  /// No description provided for @adjustReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get adjustReasonLabel;

  /// No description provided for @adjustReasonHelp.
  ///
  /// In en, this message translates to:
  /// **'Kept in the account\'s history, for example \"Matched bank app\".'**
  String get adjustReasonHelp;

  /// No description provided for @adjustReasonTooShort.
  ///
  /// In en, this message translates to:
  /// **'Enter a reason of at least 3 characters.'**
  String get adjustReasonTooShort;

  /// No description provided for @adjustDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Effective date'**
  String get adjustDateLabel;

  /// No description provided for @adjustButton.
  ///
  /// In en, this message translates to:
  /// **'Save adjustment'**
  String get adjustButton;

  /// No description provided for @adjustDone.
  ///
  /// In en, this message translates to:
  /// **'Balance adjusted.'**
  String get adjustDone;

  /// No description provided for @paymentKindCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get paymentKindCash;

  /// No description provided for @paymentKindUpi.
  ///
  /// In en, this message translates to:
  /// **'UPI'**
  String get paymentKindUpi;

  /// No description provided for @paymentKindDebitCard.
  ///
  /// In en, this message translates to:
  /// **'Debit card'**
  String get paymentKindDebitCard;

  /// No description provided for @paymentKindCreditCard.
  ///
  /// In en, this message translates to:
  /// **'Credit card'**
  String get paymentKindCreditCard;

  /// No description provided for @paymentKindBankTransfer.
  ///
  /// In en, this message translates to:
  /// **'Bank transfer'**
  String get paymentKindBankTransfer;

  /// No description provided for @paymentKindWallet.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get paymentKindWallet;

  /// No description provided for @paymentKindCheque.
  ///
  /// In en, this message translates to:
  /// **'Cheque'**
  String get paymentKindCheque;

  /// No description provided for @paymentKindOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get paymentKindOther;

  /// No description provided for @paymentNetworkOther.
  ///
  /// In en, this message translates to:
  /// **'Other network'**
  String get paymentNetworkOther;

  /// No description provided for @paymentDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get paymentDefault;

  /// No description provided for @paymentPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a payment method'**
  String get paymentPickerTitle;

  /// No description provided for @paymentPickerEmpty.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t added any payment methods yet.'**
  String get paymentPickerEmpty;

  /// No description provided for @paymentNone.
  ///
  /// In en, this message translates to:
  /// **'No payment method'**
  String get paymentNone;

  /// No description provided for @paymentMethodsTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment methods'**
  String get paymentMethodsTitle;

  /// No description provided for @paymentMethodsIntro.
  ///
  /// In en, this message translates to:
  /// **'Record how you paid, such as UPI, cash or a card. Store only a label and the last digits — never full card numbers, CVVs or PINs.'**
  String get paymentMethodsIntro;

  /// No description provided for @paymentShowArchived.
  ///
  /// In en, this message translates to:
  /// **'Show archived methods'**
  String get paymentShowArchived;

  /// No description provided for @paymentEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No payment methods yet'**
  String get paymentEmptyTitle;

  /// No description provided for @paymentEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add the ways you pay to filter and review spending by method.'**
  String get paymentEmptyBody;

  /// No description provided for @paymentAdd.
  ///
  /// In en, this message translates to:
  /// **'Add payment method'**
  String get paymentAdd;

  /// No description provided for @paymentLinkedTo.
  ///
  /// In en, this message translates to:
  /// **'Linked to {account}'**
  String paymentLinkedTo(String account);

  /// No description provided for @paymentRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get paymentRemove;

  /// No description provided for @paymentRemoveLabel.
  ///
  /// In en, this message translates to:
  /// **'Remove {label}'**
  String paymentRemoveLabel(String label);

  /// No description provided for @paymentRemoveConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove this payment method?'**
  String get paymentRemoveConfirmTitle;

  /// No description provided for @paymentRemoveConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'{label} will no longer be offered. If transactions already use it, it\'s archived so their history stays intact.'**
  String paymentRemoveConfirmBody(String label);

  /// No description provided for @paymentRemoved.
  ///
  /// In en, this message translates to:
  /// **'Payment method removed.'**
  String get paymentRemoved;

  /// No description provided for @paymentNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New payment method'**
  String get paymentNewTitle;

  /// No description provided for @paymentEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit payment method'**
  String get paymentEditTitle;

  /// No description provided for @paymentCreated.
  ///
  /// In en, this message translates to:
  /// **'Payment method added.'**
  String get paymentCreated;

  /// No description provided for @paymentSaved.
  ///
  /// In en, this message translates to:
  /// **'Payment method saved.'**
  String get paymentSaved;

  /// No description provided for @paymentKindLabel.
  ///
  /// In en, this message translates to:
  /// **'Kind'**
  String get paymentKindLabel;

  /// No description provided for @paymentLabelLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get paymentLabelLabel;

  /// No description provided for @paymentLabelHelp.
  ///
  /// In en, this message translates to:
  /// **'For example \"GPay\" or \"HDFC credit card\".'**
  String get paymentLabelHelp;

  /// No description provided for @paymentHintLabel.
  ///
  /// In en, this message translates to:
  /// **'Masked hint'**
  String get paymentHintLabel;

  /// No description provided for @paymentHintHelp.
  ///
  /// In en, this message translates to:
  /// **'Last digits or a masked UPI handle only, for example •••• 4821.'**
  String get paymentHintHelp;

  /// No description provided for @paymentHintTooManyDigits.
  ///
  /// In en, this message translates to:
  /// **'Use at most 4 digits. Never enter full card or account numbers, CVVs or PINs.'**
  String get paymentHintTooManyDigits;

  /// No description provided for @paymentNetworkLabel.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get paymentNetworkLabel;

  /// No description provided for @paymentAccountLabel.
  ///
  /// In en, this message translates to:
  /// **'Paid from account'**
  String get paymentAccountLabel;

  /// No description provided for @paymentAccountHelp.
  ///
  /// In en, this message translates to:
  /// **'Optional link to the account this method draws from.'**
  String get paymentAccountHelp;

  /// No description provided for @paymentAccountUnknown.
  ///
  /// In en, this message translates to:
  /// **'Account not available'**
  String get paymentAccountUnknown;

  /// No description provided for @paymentMakeDefault.
  ///
  /// In en, this message translates to:
  /// **'Use as default'**
  String get paymentMakeDefault;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navTransactions.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get navTransactions;

  /// No description provided for @txTypeExpense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get txTypeExpense;

  /// No description provided for @txTypeIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get txTypeIncome;

  /// No description provided for @txTypeTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get txTypeTransfer;

  /// No description provided for @txTypeRefund.
  ///
  /// In en, this message translates to:
  /// **'Refund'**
  String get txTypeRefund;

  /// No description provided for @txTypeReimbursement.
  ///
  /// In en, this message translates to:
  /// **'Reimbursement'**
  String get txTypeReimbursement;

  /// No description provided for @txTypeAdjustment.
  ///
  /// In en, this message translates to:
  /// **'Balance adjustment'**
  String get txTypeAdjustment;

  /// No description provided for @txTypeOpeningBalance.
  ///
  /// In en, this message translates to:
  /// **'Opening balance'**
  String get txTypeOpeningBalance;

  /// No description provided for @txTypeGroupExpense.
  ///
  /// In en, this message translates to:
  /// **'Group expense'**
  String get txTypeGroupExpense;

  /// No description provided for @txTypeSettlement.
  ///
  /// In en, this message translates to:
  /// **'Settlement'**
  String get txTypeSettlement;

  /// No description provided for @txTypeOther.
  ///
  /// In en, this message translates to:
  /// **'Transaction'**
  String get txTypeOther;

  /// No description provided for @txStatusDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get txStatusDraft;

  /// No description provided for @txStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get txStatusPending;

  /// No description provided for @txStatusPosted.
  ///
  /// In en, this message translates to:
  /// **'Posted'**
  String get txStatusPosted;

  /// No description provided for @txStatusDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get txStatusDeleted;

  /// No description provided for @txStatusReversed.
  ///
  /// In en, this message translates to:
  /// **'Reversed'**
  String get txStatusReversed;

  /// No description provided for @txSourceManual.
  ///
  /// In en, this message translates to:
  /// **'Entered by you'**
  String get txSourceManual;

  /// No description provided for @txSourceImport.
  ///
  /// In en, this message translates to:
  /// **'Statement import'**
  String get txSourceImport;

  /// No description provided for @txSourceReceipt.
  ///
  /// In en, this message translates to:
  /// **'Receipt'**
  String get txSourceReceipt;

  /// No description provided for @txSourceRecurring.
  ///
  /// In en, this message translates to:
  /// **'Recurring rule'**
  String get txSourceRecurring;

  /// No description provided for @txSourceIntegration.
  ///
  /// In en, this message translates to:
  /// **'Connected provider'**
  String get txSourceIntegration;

  /// No description provided for @txSourceCorrection.
  ///
  /// In en, this message translates to:
  /// **'Correction'**
  String get txSourceCorrection;

  /// No description provided for @txSourceGroup.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get txSourceGroup;

  /// No description provided for @txSourceSystem.
  ///
  /// In en, this message translates to:
  /// **'Montra'**
  String get txSourceSystem;

  /// No description provided for @reconUnreconciled.
  ///
  /// In en, this message translates to:
  /// **'Not reconciled'**
  String get reconUnreconciled;

  /// No description provided for @reconMatched.
  ///
  /// In en, this message translates to:
  /// **'Matched'**
  String get reconMatched;

  /// No description provided for @reconReconciled.
  ///
  /// In en, this message translates to:
  /// **'Reconciled'**
  String get reconReconciled;

  /// No description provided for @reconExcluded.
  ///
  /// In en, this message translates to:
  /// **'Excluded from reconciliation'**
  String get reconExcluded;

  /// No description provided for @txRefundedAmount.
  ///
  /// In en, this message translates to:
  /// **'Refunded {amount}'**
  String txRefundedAmount(String amount);

  /// No description provided for @quickAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a transaction'**
  String get quickAddTitle;

  /// No description provided for @quickAddExpenseHelp.
  ///
  /// In en, this message translates to:
  /// **'Money you spent'**
  String get quickAddExpenseHelp;

  /// No description provided for @quickAddIncomeHelp.
  ///
  /// In en, this message translates to:
  /// **'Money you received'**
  String get quickAddIncomeHelp;

  /// No description provided for @quickAddTransferHelp.
  ///
  /// In en, this message translates to:
  /// **'Move money between your own accounts'**
  String get quickAddTransferHelp;

  /// No description provided for @transactionsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search description, notes or merchant'**
  String get transactionsSearchHint;

  /// No description provided for @searchOpen.
  ///
  /// In en, this message translates to:
  /// **'Search transactions'**
  String get searchOpen;

  /// No description provided for @searchClose.
  ///
  /// In en, this message translates to:
  /// **'Close search'**
  String get searchClose;

  /// No description provided for @filtersTitle.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filtersTitle;

  /// No description provided for @filtersActiveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Filters, {count} active'**
  String filtersActiveTooltip(int count);

  /// No description provided for @filtersApply.
  ///
  /// In en, this message translates to:
  /// **'Show results'**
  String get filtersApply;

  /// No description provided for @filtersClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get filtersClearAll;

  /// No description provided for @filterRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove filter {label}'**
  String filterRemove(String label);

  /// No description provided for @filterDates.
  ///
  /// In en, this message translates to:
  /// **'Dates'**
  String get filterDates;

  /// No description provided for @filterType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get filterType;

  /// No description provided for @filterDirection.
  ///
  /// In en, this message translates to:
  /// **'Money in or out'**
  String get filterDirection;

  /// No description provided for @directionIn.
  ///
  /// In en, this message translates to:
  /// **'Money in'**
  String get directionIn;

  /// No description provided for @directionOut.
  ///
  /// In en, this message translates to:
  /// **'Money out'**
  String get directionOut;

  /// No description provided for @filterAny.
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get filterAny;

  /// No description provided for @filterOneSelected.
  ///
  /// In en, this message translates to:
  /// **'1 selected'**
  String get filterOneSelected;

  /// No description provided for @filterAccounts.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get filterAccounts;

  /// No description provided for @filterAccountsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} accounts'**
  String filterAccountsCount(int count);

  /// No description provided for @filterCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get filterCategories;

  /// No description provided for @filterCategoriesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} categories'**
  String filterCategoriesCount(int count);

  /// No description provided for @filterTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get filterTags;

  /// No description provided for @filterTagsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} tags'**
  String filterTagsCount(int count);

  /// No description provided for @filterMerchant.
  ///
  /// In en, this message translates to:
  /// **'Merchant'**
  String get filterMerchant;

  /// No description provided for @filterPaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get filterPaymentMethod;

  /// No description provided for @filterAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get filterAmount;

  /// No description provided for @filterAmountCurrency.
  ///
  /// In en, this message translates to:
  /// **'Currency for the amount range'**
  String get filterAmountCurrency;

  /// No description provided for @filterMinAmount.
  ///
  /// In en, this message translates to:
  /// **'At least'**
  String get filterMinAmount;

  /// No description provided for @filterMaxAmount.
  ///
  /// In en, this message translates to:
  /// **'At most'**
  String get filterMaxAmount;

  /// No description provided for @filterAmountChip.
  ///
  /// In en, this message translates to:
  /// **'Amount {min} to {max} {currency}'**
  String filterAmountChip(String min, String max, String currency);

  /// No description provided for @filterMore.
  ///
  /// In en, this message translates to:
  /// **'More filters'**
  String get filterMore;

  /// No description provided for @filterStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get filterStatus;

  /// No description provided for @filterStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active (not deleted)'**
  String get filterStatusActive;

  /// No description provided for @filterStatusDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted only'**
  String get filterStatusDeleted;

  /// No description provided for @filterStatusAll.
  ///
  /// In en, this message translates to:
  /// **'All, including deleted'**
  String get filterStatusAll;

  /// No description provided for @filterSource.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get filterSource;

  /// No description provided for @filterReconciliation.
  ///
  /// In en, this message translates to:
  /// **'Reconciliation'**
  String get filterReconciliation;

  /// No description provided for @filterHasAttachment.
  ///
  /// In en, this message translates to:
  /// **'Has attachments'**
  String get filterHasAttachment;

  /// No description provided for @filterWithAttachments.
  ///
  /// In en, this message translates to:
  /// **'With attachments'**
  String get filterWithAttachments;

  /// No description provided for @filterWithoutAttachments.
  ///
  /// In en, this message translates to:
  /// **'Without attachments'**
  String get filterWithoutAttachments;

  /// No description provided for @filterRecurring.
  ///
  /// In en, this message translates to:
  /// **'From a recurring rule'**
  String get filterRecurring;

  /// No description provided for @filterRecurringOnly.
  ///
  /// In en, this message translates to:
  /// **'Recurring only'**
  String get filterRecurringOnly;

  /// No description provided for @filterNotRecurring.
  ///
  /// In en, this message translates to:
  /// **'Not recurring'**
  String get filterNotRecurring;

  /// No description provided for @filterYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get filterYes;

  /// No description provided for @filterNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get filterNo;

  /// No description provided for @filterSort.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get filterSort;

  /// No description provided for @sortDateDesc.
  ///
  /// In en, this message translates to:
  /// **'Newest first'**
  String get sortDateDesc;

  /// No description provided for @sortDateAsc.
  ///
  /// In en, this message translates to:
  /// **'Oldest first'**
  String get sortDateAsc;

  /// No description provided for @sortAmountDesc.
  ///
  /// In en, this message translates to:
  /// **'Largest amount first'**
  String get sortAmountDesc;

  /// No description provided for @sortAmountAsc.
  ///
  /// In en, this message translates to:
  /// **'Smallest amount first'**
  String get sortAmountAsc;

  /// No description provided for @rangePickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose dates'**
  String get rangePickerTitle;

  /// No description provided for @rangeToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get rangeToday;

  /// No description provided for @rangeYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get rangeYesterday;

  /// No description provided for @rangeThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get rangeThisWeek;

  /// No description provided for @rangeLastWeek.
  ///
  /// In en, this message translates to:
  /// **'Last week'**
  String get rangeLastWeek;

  /// No description provided for @rangeThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get rangeThisMonth;

  /// No description provided for @rangeLastMonth.
  ///
  /// In en, this message translates to:
  /// **'Last month'**
  String get rangeLastMonth;

  /// No description provided for @rangeThisYear.
  ///
  /// In en, this message translates to:
  /// **'This year'**
  String get rangeThisYear;

  /// No description provided for @rangeLastYear.
  ///
  /// In en, this message translates to:
  /// **'Last year'**
  String get rangeLastYear;

  /// No description provided for @rangeLast7Days.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days'**
  String get rangeLast7Days;

  /// No description provided for @rangeLast30Days.
  ///
  /// In en, this message translates to:
  /// **'Last 30 days'**
  String get rangeLast30Days;

  /// No description provided for @rangeLast90Days.
  ///
  /// In en, this message translates to:
  /// **'Last 90 days'**
  String get rangeLast90Days;

  /// No description provided for @rangeCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom dates'**
  String get rangeCustom;

  /// No description provided for @rangeAnyTime.
  ///
  /// In en, this message translates to:
  /// **'Any time'**
  String get rangeAnyTime;

  /// No description provided for @rangeFrom.
  ///
  /// In en, this message translates to:
  /// **'From {date}'**
  String rangeFrom(String date);

  /// No description provided for @rangeUntil.
  ///
  /// In en, this message translates to:
  /// **'Until {date}'**
  String rangeUntil(String date);

  /// No description provided for @transactionsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet'**
  String get transactionsEmptyTitle;

  /// No description provided for @transactionsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add what you spend and receive to see where your money goes. No bank connection needed.'**
  String get transactionsEmptyBody;

  /// No description provided for @transactionAddFirst.
  ///
  /// In en, this message translates to:
  /// **'Add an expense'**
  String get transactionAddFirst;

  /// No description provided for @transactionsNoMatchTitle.
  ///
  /// In en, this message translates to:
  /// **'No transactions match'**
  String get transactionsNoMatchTitle;

  /// No description provided for @transactionsNoMatchBody.
  ///
  /// In en, this message translates to:
  /// **'Try other dates or remove some filters.'**
  String get transactionsNoMatchBody;

  /// No description provided for @transactionsEnd.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{That\'s 1 transaction.} other{That\'s all {count} transactions.}}'**
  String transactionsEnd(int count);

  /// No description provided for @loadingMore.
  ///
  /// In en, this message translates to:
  /// **'Loading more transactions'**
  String get loadingMore;

  /// No description provided for @selectionCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String selectionCount(int count);

  /// No description provided for @selectionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel selection'**
  String get selectionCancel;

  /// No description provided for @bulkEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Change selected'**
  String get bulkEditTitle;

  /// No description provided for @bulkEditTitleCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Change 1 transaction} other{Change {count} transactions}}'**
  String bulkEditTitleCount(int count);

  /// No description provided for @bulkSetCategory.
  ///
  /// In en, this message translates to:
  /// **'Set category'**
  String get bulkSetCategory;

  /// No description provided for @bulkClearCategory.
  ///
  /// In en, this message translates to:
  /// **'Remove category'**
  String get bulkClearCategory;

  /// No description provided for @bulkAddTags.
  ///
  /// In en, this message translates to:
  /// **'Add tags'**
  String get bulkAddTags;

  /// No description provided for @bulkRemoveTags.
  ///
  /// In en, this message translates to:
  /// **'Remove tags'**
  String get bulkRemoveTags;

  /// No description provided for @bulkMoveAccount.
  ///
  /// In en, this message translates to:
  /// **'Move to another account'**
  String get bulkMoveAccount;

  /// No description provided for @bulkMoveAccountHelp.
  ///
  /// In en, this message translates to:
  /// **'Only to an account with the same currency. Transfers can\'t be moved.'**
  String get bulkMoveAccountHelp;

  /// No description provided for @bulkSetCategoryConfirm.
  ///
  /// In en, this message translates to:
  /// **'Set the category of {count, plural, =1{1 transaction} other{{count} transactions}} to {category}?'**
  String bulkSetCategoryConfirm(int count, String category);

  /// No description provided for @bulkClearCategoryConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove the category from {count, plural, =1{1 transaction} other{{count} transactions}}?'**
  String bulkClearCategoryConfirm(int count);

  /// No description provided for @bulkAddTagsConfirm.
  ///
  /// In en, this message translates to:
  /// **'Add {tags, plural, =1{1 tag} other{{tags} tags}} to {count, plural, =1{1 transaction} other{{count} transactions}}?'**
  String bulkAddTagsConfirm(int count, int tags);

  /// No description provided for @bulkRemoveTagsConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove {tags, plural, =1{1 tag} other{{tags} tags}} from {count, plural, =1{1 transaction} other{{count} transactions}}?'**
  String bulkRemoveTagsConfirm(int count, int tags);

  /// No description provided for @bulkMoveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Move {count, plural, =1{1 transaction} other{{count} transactions}} to {account}?'**
  String bulkMoveConfirm(int count, String account);

  /// No description provided for @bulkUpdated.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 transaction updated.} other{{count} transactions updated.}}'**
  String bulkUpdated(int count);

  /// No description provided for @bulkDeleteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete selected'**
  String get bulkDeleteTooltip;

  /// No description provided for @bulkDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Delete 1 transaction?} other{Delete {count} transactions?}}'**
  String bulkDeleteConfirmTitle(int count);

  /// No description provided for @bulkDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'They\'re removed from balances and reports. Nothing is erased: you can find them with the Deleted filter and restore them.'**
  String get bulkDeleteConfirmBody;

  /// No description provided for @bulkDeleted.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 transaction deleted.} other{{count} transactions deleted.}}'**
  String bulkDeleted(int count);

  /// No description provided for @amountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amountLabel;

  /// No description provided for @amountChooseAccountFirst.
  ///
  /// In en, this message translates to:
  /// **'Choose the account first to set the currency.'**
  String get amountChooseAccountFirst;

  /// No description provided for @accountFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountFieldLabel;

  /// No description provided for @accountFieldPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Choose an account'**
  String get accountFieldPlaceholder;

  /// No description provided for @validationAccountRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose an account.'**
  String get validationAccountRequired;

  /// No description provided for @moveAccountHelp.
  ///
  /// In en, this message translates to:
  /// **'You can move it to another account with the same currency.'**
  String get moveAccountHelp;

  /// No description provided for @dateLabel.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get dateLabel;

  /// No description provided for @categoryFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get categoryFieldLabel;

  /// No description provided for @merchantFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Merchant'**
  String get merchantFieldLabel;

  /// No description provided for @merchantNewHelp.
  ///
  /// In en, this message translates to:
  /// **'New merchant: matched to an existing one with the same name, or added.'**
  String get merchantNewHelp;

  /// No description provided for @paymentMethodFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get paymentMethodFieldLabel;

  /// No description provided for @tagsLabel.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get tagsLabel;

  /// No description provided for @tagAdd.
  ///
  /// In en, this message translates to:
  /// **'Add tag'**
  String get tagAdd;

  /// No description provided for @tagRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove tag {name}'**
  String tagRemove(String name);

  /// No description provided for @descriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get descriptionLabel;

  /// No description provided for @notesPrivacyHelp.
  ///
  /// In en, this message translates to:
  /// **'Never write card numbers, CVVs, PINs or OTPs here.'**
  String get notesPrivacyHelp;

  /// No description provided for @moreOptions.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get moreOptions;

  /// No description provided for @statusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get statusLabel;

  /// No description provided for @foreignCurrencyToggle.
  ///
  /// In en, this message translates to:
  /// **'Paid in another currency'**
  String get foreignCurrencyToggle;

  /// No description provided for @foreignCurrencyHelp.
  ///
  /// In en, this message translates to:
  /// **'Enter the amount your account was charged above, and the original amount here.'**
  String get foreignCurrencyHelp;

  /// No description provided for @originalCurrencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Original currency'**
  String get originalCurrencyLabel;

  /// No description provided for @originalAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Original amount'**
  String get originalAmountLabel;

  /// No description provided for @originalAmountHelp.
  ///
  /// In en, this message translates to:
  /// **'The amount in the currency you actually paid.'**
  String get originalAmountHelp;

  /// No description provided for @fxFeeLabel.
  ///
  /// In en, this message translates to:
  /// **'Currency conversion fee'**
  String get fxFeeLabel;

  /// No description provided for @fxFeeHelp.
  ///
  /// In en, this message translates to:
  /// **'Part of the amount above, for your records.'**
  String get fxFeeHelp;

  /// No description provided for @fxRateLabel.
  ///
  /// In en, this message translates to:
  /// **'Exchange rate'**
  String get fxRateLabel;

  /// No description provided for @rateWithSource.
  ///
  /// In en, this message translates to:
  /// **'{rate} ({source})'**
  String rateWithSource(String rate, String source);

  /// No description provided for @expenseNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New expense'**
  String get expenseNewTitle;

  /// No description provided for @incomeNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New income'**
  String get incomeNewTitle;

  /// No description provided for @transactionEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit transaction'**
  String get transactionEditTitle;

  /// No description provided for @transactionLimitedEdit.
  ///
  /// In en, this message translates to:
  /// **'This is a {type}. Only the description, notes, merchant and tags can be changed here.'**
  String transactionLimitedEdit(String type);

  /// No description provided for @expenseSaved.
  ///
  /// In en, this message translates to:
  /// **'Expense saved.'**
  String get expenseSaved;

  /// No description provided for @incomeSaved.
  ///
  /// In en, this message translates to:
  /// **'Income saved.'**
  String get incomeSaved;

  /// No description provided for @transactionSaved.
  ///
  /// In en, this message translates to:
  /// **'Transaction saved.'**
  String get transactionSaved;

  /// No description provided for @transactionDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Transaction'**
  String get transactionDetailTitle;

  /// No description provided for @transactionDeletedNotice.
  ///
  /// In en, this message translates to:
  /// **'This transaction is deleted. It doesn\'t count in balances or reports until you restore it.'**
  String get transactionDeletedNotice;

  /// No description provided for @transactionSharedReadOnly.
  ///
  /// In en, this message translates to:
  /// **'This transaction belongs to an account shared with you. You can view it but not change it.'**
  String get transactionSharedReadOnly;

  /// No description provided for @transactionDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this transaction?'**
  String get transactionDeleteConfirmTitle;

  /// No description provided for @transactionDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'It\'s removed from balances and reports. Nothing is erased; you can restore it later.'**
  String get transactionDeleteConfirmBody;

  /// No description provided for @transactionDeleteTransferBody.
  ///
  /// In en, this message translates to:
  /// **'This is part of a transfer. Deleting it deletes the whole transfer: both accounts and any fee. You can restore it later.'**
  String get transactionDeleteTransferBody;

  /// No description provided for @transactionDeleted.
  ///
  /// In en, this message translates to:
  /// **'Transaction deleted.'**
  String get transactionDeleted;

  /// No description provided for @transactionRestored.
  ///
  /// In en, this message translates to:
  /// **'Transaction restored.'**
  String get transactionRestored;

  /// No description provided for @duplicateAction.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get duplicateAction;

  /// No description provided for @duplicateDateTitle.
  ///
  /// In en, this message translates to:
  /// **'Date for the copy'**
  String get duplicateDateTitle;

  /// No description provided for @duplicateConfirm.
  ///
  /// In en, this message translates to:
  /// **'Create copy'**
  String get duplicateConfirm;

  /// No description provided for @duplicateCreated.
  ///
  /// In en, this message translates to:
  /// **'Copy created.'**
  String get duplicateCreated;

  /// No description provided for @refundAction.
  ///
  /// In en, this message translates to:
  /// **'Record a refund'**
  String get refundAction;

  /// No description provided for @reimbursementAction.
  ///
  /// In en, this message translates to:
  /// **'Record a reimbursement'**
  String get reimbursementAction;

  /// No description provided for @personalShareLabel.
  ///
  /// In en, this message translates to:
  /// **'Your share: {amount}'**
  String personalShareLabel(String amount);

  /// No description provided for @correctionLabel.
  ///
  /// In en, this message translates to:
  /// **'Correction'**
  String get correctionLabel;

  /// No description provided for @partOfTransfer.
  ///
  /// In en, this message translates to:
  /// **'Part of a transfer'**
  String get partOfTransfer;

  /// No description provided for @partOfTransferHelp.
  ///
  /// In en, this message translates to:
  /// **'See both accounts and any fee'**
  String get partOfTransferHelp;

  /// No description provided for @refundOf.
  ///
  /// In en, this message translates to:
  /// **'Refund of an expense'**
  String get refundOf;

  /// No description provided for @reimbursementOf.
  ///
  /// In en, this message translates to:
  /// **'Reimbursement of an expense'**
  String get reimbursementOf;

  /// No description provided for @groupLinkedRecord.
  ///
  /// In en, this message translates to:
  /// **'Linked to a group'**
  String get groupLinkedRecord;

  /// No description provided for @groupLinkedRecordHelp.
  ///
  /// In en, this message translates to:
  /// **'Changes come from the group and follow it automatically.'**
  String get groupLinkedRecordHelp;

  /// No description provided for @locationLabel.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get locationLabel;

  /// No description provided for @sourceLabel.
  ///
  /// In en, this message translates to:
  /// **'Added by'**
  String get sourceLabel;

  /// No description provided for @reconciliationLabel.
  ///
  /// In en, this message translates to:
  /// **'Reconciliation'**
  String get reconciliationLabel;

  /// No description provided for @createdLabel.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get createdLabel;

  /// No description provided for @updatedLabel.
  ///
  /// In en, this message translates to:
  /// **'Last changed'**
  String get updatedLabel;

  /// No description provided for @attachmentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Attachments'**
  String get attachmentsTitle;

  /// No description provided for @attachmentsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No files are attached.'**
  String get attachmentsEmpty;

  /// No description provided for @attachmentUnnamed.
  ///
  /// In en, this message translates to:
  /// **'Unnamed file'**
  String get attachmentUnnamed;

  /// No description provided for @attachedOn.
  ///
  /// In en, this message translates to:
  /// **'Attached {time}'**
  String attachedOn(String time);

  /// No description provided for @attachmentRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get attachmentRemove;

  /// No description provided for @attachmentRemoveLabel.
  ///
  /// In en, this message translates to:
  /// **'Remove {name} from this transaction'**
  String attachmentRemoveLabel(String name);

  /// No description provided for @attachmentRemoveConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove this attachment?'**
  String get attachmentRemoveConfirmTitle;

  /// No description provided for @attachmentRemoveConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'{name} will no longer be attached to this transaction.'**
  String attachmentRemoveConfirmBody(String name);

  /// No description provided for @attachmentRemoved.
  ///
  /// In en, this message translates to:
  /// **'Attachment removed.'**
  String get attachmentRemoved;

  /// No description provided for @sizeBytes.
  ///
  /// In en, this message translates to:
  /// **'{count} B'**
  String sizeBytes(int count);

  /// No description provided for @sizeKilobytes.
  ///
  /// In en, this message translates to:
  /// **'{count} KB'**
  String sizeKilobytes(int count);

  /// No description provided for @sizeMegabytes.
  ///
  /// In en, this message translates to:
  /// **'{size} MB'**
  String sizeMegabytes(String size);

  /// No description provided for @historyTitle.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get historyTitle;

  /// No description provided for @historyEmpty.
  ///
  /// In en, this message translates to:
  /// **'No changes recorded.'**
  String get historyEmpty;

  /// No description provided for @auditWhenWho.
  ///
  /// In en, this message translates to:
  /// **'{time} · {who}'**
  String auditWhenWho(String time, String who);

  /// No description provided for @auditActorYou.
  ///
  /// In en, this message translates to:
  /// **'by you'**
  String get auditActorYou;

  /// No description provided for @auditActorMontra.
  ///
  /// In en, this message translates to:
  /// **'by Montra'**
  String get auditActorMontra;

  /// No description provided for @auditCreated.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get auditCreated;

  /// No description provided for @auditUpdated.
  ///
  /// In en, this message translates to:
  /// **'Changed'**
  String get auditUpdated;

  /// No description provided for @auditVoided.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get auditVoided;

  /// No description provided for @auditRestored.
  ///
  /// In en, this message translates to:
  /// **'Restored'**
  String get auditRestored;

  /// No description provided for @auditDuplicated.
  ///
  /// In en, this message translates to:
  /// **'Created as a copy'**
  String get auditDuplicated;

  /// No description provided for @auditBulkUpdated.
  ///
  /// In en, this message translates to:
  /// **'Changed with others'**
  String get auditBulkUpdated;

  /// No description provided for @auditAttachmentAdded.
  ///
  /// In en, this message translates to:
  /// **'File attached'**
  String get auditAttachmentAdded;

  /// No description provided for @auditAttachmentRemoved.
  ///
  /// In en, this message translates to:
  /// **'File removed'**
  String get auditAttachmentRemoved;

  /// No description provided for @auditRuleCategorized.
  ///
  /// In en, this message translates to:
  /// **'Categorized by a rule'**
  String get auditRuleCategorized;

  /// No description provided for @auditRefundAdded.
  ///
  /// In en, this message translates to:
  /// **'Refund recorded'**
  String get auditRefundAdded;

  /// No description provided for @auditReimbursementAdded.
  ///
  /// In en, this message translates to:
  /// **'Reimbursement recorded'**
  String get auditReimbursementAdded;

  /// No description provided for @auditTagsAdded.
  ///
  /// In en, this message translates to:
  /// **'Tags added'**
  String get auditTagsAdded;

  /// No description provided for @auditTagsRemoved.
  ///
  /// In en, this message translates to:
  /// **'Tags removed'**
  String get auditTagsRemoved;

  /// No description provided for @auditChanged.
  ///
  /// In en, this message translates to:
  /// **'{field} changed'**
  String auditChanged(String field);

  /// No description provided for @auditChangedFromTo.
  ///
  /// In en, this message translates to:
  /// **'{field}: {from} → {to}'**
  String auditChangedFromTo(String field, String from, String to);

  /// No description provided for @auditLinkedAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount: {amount}'**
  String auditLinkedAmount(String amount);

  /// No description provided for @refundTitle.
  ///
  /// In en, this message translates to:
  /// **'Record a refund'**
  String get refundTitle;

  /// No description provided for @reimbursementTitle.
  ///
  /// In en, this message translates to:
  /// **'Record a reimbursement'**
  String get reimbursementTitle;

  /// No description provided for @refundOriginalTitle.
  ///
  /// In en, this message translates to:
  /// **'Original expense'**
  String get refundOriginalTitle;

  /// No description provided for @refundOriginalLabel.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get refundOriginalLabel;

  /// No description provided for @refundAlreadyLabel.
  ///
  /// In en, this message translates to:
  /// **'Already refunded or reimbursed'**
  String get refundAlreadyLabel;

  /// No description provided for @refundCapNote.
  ///
  /// In en, this message translates to:
  /// **'Refunds and reimbursements together can\'t be more than the original amount. Montra checks this when you save.'**
  String get refundCapNote;

  /// No description provided for @refundHelp.
  ///
  /// In en, this message translates to:
  /// **'Money the seller gave back. It reduces your spending.'**
  String get refundHelp;

  /// No description provided for @reimbursementHelp.
  ///
  /// In en, this message translates to:
  /// **'Money someone paid you back, such as an employer. It reduces your spending.'**
  String get reimbursementHelp;

  /// No description provided for @refundAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount returned'**
  String get refundAmountLabel;

  /// No description provided for @refundAccountLabel.
  ///
  /// In en, this message translates to:
  /// **'Received in'**
  String get refundAccountLabel;

  /// No description provided for @refundAccountHelp.
  ///
  /// In en, this message translates to:
  /// **'Defaults to the account of the original expense.'**
  String get refundAccountHelp;

  /// No description provided for @refundCorrectionLabel.
  ///
  /// In en, this message translates to:
  /// **'This is a correction'**
  String get refundCorrectionLabel;

  /// No description provided for @refundCorrectionHelp.
  ///
  /// In en, this message translates to:
  /// **'Allows more than the original amount, for example to fix a wrong original. Use only on purpose.'**
  String get refundCorrectionHelp;

  /// No description provided for @refundNotAllowedTitle.
  ///
  /// In en, this message translates to:
  /// **'This can\'t be refunded'**
  String get refundNotAllowedTitle;

  /// No description provided for @refundNotAllowedBody.
  ///
  /// In en, this message translates to:
  /// **'Only your own expenses that aren\'t deleted can get a refund or reimbursement.'**
  String get refundNotAllowedBody;

  /// No description provided for @refundSave.
  ///
  /// In en, this message translates to:
  /// **'Save refund'**
  String get refundSave;

  /// No description provided for @reimbursementSave.
  ///
  /// In en, this message translates to:
  /// **'Save reimbursement'**
  String get reimbursementSave;

  /// No description provided for @refundSaved.
  ///
  /// In en, this message translates to:
  /// **'Refund saved.'**
  String get refundSaved;

  /// No description provided for @reimbursementSaved.
  ///
  /// In en, this message translates to:
  /// **'Reimbursement saved.'**
  String get reimbursementSaved;

  /// No description provided for @transferNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New transfer'**
  String get transferNewTitle;

  /// No description provided for @transferIntro.
  ///
  /// In en, this message translates to:
  /// **'Move money between your own accounts. Transfers aren\'t counted as income or spending.'**
  String get transferIntro;

  /// No description provided for @transferFromLabel.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get transferFromLabel;

  /// No description provided for @transferToLabel.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get transferToLabel;

  /// No description provided for @transferAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount sent'**
  String get transferAmountLabel;

  /// No description provided for @transferAmountHelp.
  ///
  /// In en, this message translates to:
  /// **'In the currency of the account it leaves.'**
  String get transferAmountHelp;

  /// No description provided for @transferFxSection.
  ///
  /// In en, this message translates to:
  /// **'Different currencies'**
  String get transferFxSection;

  /// No description provided for @transferFxHelp.
  ///
  /// In en, this message translates to:
  /// **'Money leaves in {from} and arrives in {to}. Enter what arrived, or the exchange rate.'**
  String transferFxHelp(String from, String to);

  /// No description provided for @transferFxReceived.
  ///
  /// In en, this message translates to:
  /// **'Amount received'**
  String get transferFxReceived;

  /// No description provided for @transferFxRate.
  ///
  /// In en, this message translates to:
  /// **'Exchange rate'**
  String get transferFxRate;

  /// No description provided for @transferToAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount received'**
  String get transferToAmountLabel;

  /// No description provided for @transferRateLabel.
  ///
  /// In en, this message translates to:
  /// **'{to} per 1 {from}'**
  String transferRateLabel(String from, String to);

  /// No description provided for @transferRateHelp.
  ///
  /// In en, this message translates to:
  /// **'An exact rate such as 0.0119.'**
  String get transferRateHelp;

  /// No description provided for @transferRateInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a positive rate, for example 83.12.'**
  String get transferRateInvalid;

  /// No description provided for @transferFeeLabel.
  ///
  /// In en, this message translates to:
  /// **'Fee'**
  String get transferFeeLabel;

  /// No description provided for @transferFeeHelp.
  ///
  /// In en, this message translates to:
  /// **'Charged to the account the money leaves. Saved as a separate expense.'**
  String get transferFeeHelp;

  /// No description provided for @transferSave.
  ///
  /// In en, this message translates to:
  /// **'Save transfer'**
  String get transferSave;

  /// No description provided for @transferSaved.
  ///
  /// In en, this message translates to:
  /// **'Transfer saved.'**
  String get transferSaved;

  /// No description provided for @transferDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get transferDetailTitle;

  /// No description provided for @transferBetween.
  ///
  /// In en, this message translates to:
  /// **'{from} → {to}'**
  String transferBetween(String from, String to);

  /// No description provided for @transferNotIncomeNote.
  ///
  /// In en, this message translates to:
  /// **'Transfers move your own money, so they aren\'t counted as income or spending.'**
  String get transferNotIncomeNote;

  /// No description provided for @transferSentFrom.
  ///
  /// In en, this message translates to:
  /// **'Sent from {account}'**
  String transferSentFrom(String account);

  /// No description provided for @transferReceivedIn.
  ///
  /// In en, this message translates to:
  /// **'Received in {account}'**
  String transferReceivedIn(String account);

  /// No description provided for @transferRateShown.
  ///
  /// In en, this message translates to:
  /// **'Exchange rate ({to} per {from})'**
  String transferRateShown(String from, String to);

  /// No description provided for @transferLegsTitle.
  ///
  /// In en, this message translates to:
  /// **'Recorded as'**
  String get transferLegsTitle;

  /// No description provided for @transferLegOut.
  ///
  /// In en, this message translates to:
  /// **'Money out of the first account'**
  String get transferLegOut;

  /// No description provided for @transferLegIn.
  ///
  /// In en, this message translates to:
  /// **'Money into the second account'**
  String get transferLegIn;

  /// No description provided for @transferVoidedNotice.
  ///
  /// In en, this message translates to:
  /// **'This transfer is deleted. Neither account counts it until you restore it.'**
  String get transferVoidedNotice;

  /// No description provided for @transferDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete transfer'**
  String get transferDelete;

  /// No description provided for @transferDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this transfer?'**
  String get transferDeleteConfirmTitle;

  /// No description provided for @transferDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Both sides are removed together. Nothing is erased; you can restore it later.'**
  String get transferDeleteConfirmBody;

  /// No description provided for @transferDeleteConfirmBodyFee.
  ///
  /// In en, this message translates to:
  /// **'Both sides and the fee are removed together. Nothing is erased; you can restore it later.'**
  String get transferDeleteConfirmBodyFee;

  /// No description provided for @transferDeleted.
  ///
  /// In en, this message translates to:
  /// **'Transfer deleted.'**
  String get transferDeleted;

  /// No description provided for @transferRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore transfer'**
  String get transferRestore;

  /// No description provided for @transferRestored.
  ///
  /// In en, this message translates to:
  /// **'Transfer restored.'**
  String get transferRestored;

  /// No description provided for @widgetBalances.
  ///
  /// In en, this message translates to:
  /// **'Balances'**
  String get widgetBalances;

  /// No description provided for @widgetBalancesHelp.
  ///
  /// In en, this message translates to:
  /// **'Tracked net worth, assets and what you owe, per currency'**
  String get widgetBalancesHelp;

  /// No description provided for @widgetCashFlow.
  ///
  /// In en, this message translates to:
  /// **'Cash flow'**
  String get widgetCashFlow;

  /// No description provided for @widgetCashFlowHelp.
  ///
  /// In en, this message translates to:
  /// **'Income, spending and net cash flow for the period'**
  String get widgetCashFlowHelp;

  /// No description provided for @widgetIncomeVsExpense.
  ///
  /// In en, this message translates to:
  /// **'Income vs spending'**
  String get widgetIncomeVsExpense;

  /// No description provided for @widgetIncomeVsExpenseHelp.
  ///
  /// In en, this message translates to:
  /// **'A chart comparing money in and out'**
  String get widgetIncomeVsExpenseHelp;

  /// No description provided for @widgetCashFlowTrend.
  ///
  /// In en, this message translates to:
  /// **'Cash-flow trend'**
  String get widgetCashFlowTrend;

  /// No description provided for @widgetCashFlowTrendHelp.
  ///
  /// In en, this message translates to:
  /// **'Income and spending over time'**
  String get widgetCashFlowTrendHelp;

  /// No description provided for @widgetCategoryBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Spending by category'**
  String get widgetCategoryBreakdown;

  /// No description provided for @widgetCategoryBreakdownHelp.
  ///
  /// In en, this message translates to:
  /// **'Where your money went'**
  String get widgetCategoryBreakdownHelp;

  /// No description provided for @widgetTopMerchants.
  ///
  /// In en, this message translates to:
  /// **'Top merchants'**
  String get widgetTopMerchants;

  /// No description provided for @widgetTopMerchantsHelp.
  ///
  /// In en, this message translates to:
  /// **'Who you spent the most with'**
  String get widgetTopMerchantsHelp;

  /// No description provided for @widgetRecentTransactions.
  ///
  /// In en, this message translates to:
  /// **'Recent transactions'**
  String get widgetRecentTransactions;

  /// No description provided for @widgetRecentTransactionsHelp.
  ///
  /// In en, this message translates to:
  /// **'Your latest entries'**
  String get widgetRecentTransactionsHelp;

  /// No description provided for @widgetDataCoverage.
  ///
  /// In en, this message translates to:
  /// **'About these figures'**
  String get widgetDataCoverage;

  /// No description provided for @widgetDataCoverageHelp.
  ///
  /// In en, this message translates to:
  /// **'What the figures are based on and how they\'re calculated'**
  String get widgetDataCoverageHelp;

  /// No description provided for @widgetUnknownHelp.
  ///
  /// In en, this message translates to:
  /// **'Available in a newer version of the app'**
  String get widgetUnknownHelp;

  /// No description provided for @widgetSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Customize Home'**
  String get widgetSettingsTitle;

  /// No description provided for @widgetSettingsIntro.
  ///
  /// In en, this message translates to:
  /// **'Choose what Home shows and in which order. This only changes the layout, never your records.'**
  String get widgetSettingsIntro;

  /// No description provided for @widgetPosition.
  ///
  /// In en, this message translates to:
  /// **'Position {position} of {total}'**
  String widgetPosition(int position, int total);

  /// No description provided for @widgetMoveUp.
  ///
  /// In en, this message translates to:
  /// **'Move {name} up'**
  String widgetMoveUp(String name);

  /// No description provided for @widgetMoveDown.
  ///
  /// In en, this message translates to:
  /// **'Move {name} down'**
  String widgetMoveDown(String name);

  /// No description provided for @widgetSettingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Home layout saved.'**
  String get widgetSettingsSaved;

  /// No description provided for @widgetSettingsResetTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset Home layout?'**
  String get widgetSettingsResetTitle;

  /// No description provided for @widgetSettingsResetBody.
  ///
  /// In en, this message translates to:
  /// **'All widgets will be shown again in the default order.'**
  String get widgetSettingsResetBody;

  /// No description provided for @widgetSettingsResetDone.
  ///
  /// In en, this message translates to:
  /// **'Home layout reset.'**
  String get widgetSettingsResetDone;

  /// No description provided for @dashboardCustomize.
  ///
  /// In en, this message translates to:
  /// **'Customize Home'**
  String get dashboardCustomize;

  /// No description provided for @dashboardChangePeriod.
  ///
  /// In en, this message translates to:
  /// **'Change the period'**
  String get dashboardChangePeriod;

  /// No description provided for @dashboardLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading your overview'**
  String get dashboardLoading;

  /// No description provided for @dashboardLayoutFallback.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t load your Home layout, so the default is shown.'**
  String get dashboardLayoutFallback;

  /// No description provided for @dashboardCurrencyTitle.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get dashboardCurrencyTitle;

  /// No description provided for @dashboardCurrencyChip.
  ///
  /// In en, this message translates to:
  /// **'Show figures in {currency}'**
  String dashboardCurrencyChip(String currency);

  /// No description provided for @dashboardCurrencyNote.
  ///
  /// In en, this message translates to:
  /// **'Amounts in different currencies are shown separately and never added together.'**
  String get dashboardCurrencyNote;

  /// No description provided for @dashboardGetStartedTitle.
  ///
  /// In en, this message translates to:
  /// **'Let\'s start tracking'**
  String get dashboardGetStartedTitle;

  /// No description provided for @dashboardGetStartedBody.
  ///
  /// In en, this message translates to:
  /// **'Add an account such as your wallet or bank account, then record what you spend and receive. You never need to connect a bank.'**
  String get dashboardGetStartedBody;

  /// No description provided for @dashboardViewAccounts.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get dashboardViewAccounts;

  /// No description provided for @dashboardSeeAllTransactions.
  ///
  /// In en, this message translates to:
  /// **'See all transactions'**
  String get dashboardSeeAllTransactions;

  /// No description provided for @dashboardNoAccounts.
  ///
  /// In en, this message translates to:
  /// **'No accounts are included in your overview yet.'**
  String get dashboardNoAccounts;

  /// No description provided for @dashboardAccountCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Across 1 account} other{Across {count} accounts}}'**
  String dashboardAccountCount(int count);

  /// No description provided for @dashboardNoActivity.
  ///
  /// In en, this message translates to:
  /// **'No income or spending for {period}.'**
  String dashboardNoActivity(String period);

  /// No description provided for @dashboardNoSpending.
  ///
  /// In en, this message translates to:
  /// **'No spending for {period}.'**
  String dashboardNoSpending(String period);

  /// No description provided for @dashboardNoMerchants.
  ///
  /// In en, this message translates to:
  /// **'No spending with merchants for {period}.'**
  String dashboardNoMerchants(String period);

  /// No description provided for @dashboardNoRecent.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet.'**
  String get dashboardNoRecent;

  /// No description provided for @dashboardPreviousValue.
  ///
  /// In en, this message translates to:
  /// **'Previous period: {amount}'**
  String dashboardPreviousValue(String amount);

  /// No description provided for @dashboardWithPrevious.
  ///
  /// In en, this message translates to:
  /// **'{now}; previous period {before}'**
  String dashboardWithPrevious(String now, String before);

  /// No description provided for @dashboardPreviousExplained.
  ///
  /// In en, this message translates to:
  /// **'The previous period has the same length, just before this one.'**
  String get dashboardPreviousExplained;

  /// No description provided for @dashboardSpendingDetail.
  ///
  /// In en, this message translates to:
  /// **'Spent {gross}, minus {refunds} in refunds and reimbursements.'**
  String dashboardSpendingDetail(String gross, String refunds);

  /// No description provided for @dashboardTransactionCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Based on 1 transaction} other{Based on {count} transactions}}'**
  String dashboardTransactionCount(int count);

  /// No description provided for @dashboardHowCalculated.
  ///
  /// In en, this message translates to:
  /// **'How these figures are calculated'**
  String get dashboardHowCalculated;

  /// No description provided for @incomeLabel.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get incomeLabel;

  /// No description provided for @spendingLabel.
  ///
  /// In en, this message translates to:
  /// **'Spending'**
  String get spendingLabel;

  /// No description provided for @netCashFlowLabel.
  ///
  /// In en, this message translates to:
  /// **'Net cash flow'**
  String get netCashFlowLabel;

  /// No description provided for @netCashFlowPositive.
  ///
  /// In en, this message translates to:
  /// **'More came in than went out.'**
  String get netCashFlowPositive;

  /// No description provided for @netCashFlowNegative.
  ///
  /// In en, this message translates to:
  /// **'More went out than came in.'**
  String get netCashFlowNegative;

  /// No description provided for @savingsRateLabel.
  ///
  /// In en, this message translates to:
  /// **'Savings rate'**
  String get savingsRateLabel;

  /// No description provided for @incomeVsExpenseSummary.
  ///
  /// In en, this message translates to:
  /// **'For {period}, income was {income} and spending was {spending}.'**
  String incomeVsExpenseSummary(String period, String income, String spending);

  /// No description provided for @trendUnitDay.
  ///
  /// In en, this message translates to:
  /// **'day'**
  String get trendUnitDay;

  /// No description provided for @trendUnitWeek.
  ///
  /// In en, this message translates to:
  /// **'week'**
  String get trendUnitWeek;

  /// No description provided for @trendUnitMonth.
  ///
  /// In en, this message translates to:
  /// **'month'**
  String get trendUnitMonth;

  /// No description provided for @trendSummary.
  ///
  /// In en, this message translates to:
  /// **'Income and spending per {unit} for {period}, {count, plural, =1{1 period with activity} other{{count} periods with activity}}. Highest spending: {amount} ({bucket}).'**
  String trendSummary(
    String unit,
    String period,
    int count,
    String amount,
    String bucket,
  );

  /// No description provided for @trendBucketStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting {date}'**
  String trendBucketStarting(String date);

  /// No description provided for @trendRow.
  ///
  /// In en, this message translates to:
  /// **'In {income} · out {spending} · net {net}'**
  String trendRow(String income, String spending, String net);

  /// No description provided for @categorySummary.
  ///
  /// In en, this message translates to:
  /// **'Most spending went to {name}: {amount}, {share} of the total. {count, plural, =1{1 category shown.} other{{count} categories shown.}}'**
  String categorySummary(String name, String amount, String share, int count);

  /// No description provided for @categoryShareDetail.
  ///
  /// In en, this message translates to:
  /// **'{share} · {count, plural, =1{1 transaction} other{{count} transactions}}'**
  String categoryShareDetail(String share, int count);

  /// No description provided for @categoryTableValue.
  ///
  /// In en, this message translates to:
  /// **'{amount} ({share})'**
  String categoryTableValue(String amount, String share);

  /// No description provided for @coverageTransactions.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get coverageTransactions;

  /// No description provided for @coverageTransactionCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{None} =1{1 in this period} other{{count} in this period}}'**
  String coverageTransactionCount(int count);

  /// No description provided for @coverageSpan.
  ///
  /// In en, this message translates to:
  /// **'From – to'**
  String get coverageSpan;

  /// No description provided for @coverageUncategorized.
  ///
  /// In en, this message translates to:
  /// **'Without a category'**
  String get coverageUncategorized;

  /// No description provided for @coveragePending.
  ///
  /// In en, this message translates to:
  /// **'Pending (not counted)'**
  String get coveragePending;

  /// No description provided for @coverageLastImport.
  ///
  /// In en, this message translates to:
  /// **'Last statement import'**
  String get coverageLastImport;

  /// No description provided for @coverageNoImports.
  ///
  /// In en, this message translates to:
  /// **'No imports yet'**
  String get coverageNoImports;

  /// No description provided for @onboardingTitle.
  ///
  /// In en, this message translates to:
  /// **'Set up Montra'**
  String get onboardingTitle;

  /// No description provided for @onboardingProgress.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of {total}'**
  String onboardingProgress(int step, int total);

  /// No description provided for @onboardingSkipAll.
  ///
  /// In en, this message translates to:
  /// **'Skip setup'**
  String get onboardingSkipAll;

  /// No description provided for @onboardingSkipStep.
  ///
  /// In en, this message translates to:
  /// **'Skip this step'**
  String get onboardingSkipStep;

  /// No description provided for @onboardingWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome, {name}'**
  String onboardingWelcomeTitle(String name);

  /// No description provided for @onboardingWelcomeBody.
  ///
  /// In en, this message translates to:
  /// **'A few quick, optional steps get Montra ready. You can skip any of them and change everything later.'**
  String get onboardingWelcomeBody;

  /// No description provided for @onboardingPrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your data stays yours'**
  String get onboardingPrivacyTitle;

  /// No description provided for @onboardingPrivacyNotSold.
  ///
  /// In en, this message translates to:
  /// **'Montra never sells your financial data and never shows it publicly.'**
  String get onboardingPrivacyNotSold;

  /// No description provided for @onboardingPrivacyNoBank.
  ///
  /// In en, this message translates to:
  /// **'You don\'t need to connect a bank. Add accounts and transactions yourself.'**
  String get onboardingPrivacyNoBank;

  /// No description provided for @onboardingPrivacyNoSms.
  ///
  /// In en, this message translates to:
  /// **'Montra doesn\'t read your SMS or notifications. If a feature ever needs a permission, we\'ll explain why first.'**
  String get onboardingPrivacyNoSms;

  /// No description provided for @onboardingPrivacyControl.
  ///
  /// In en, this message translates to:
  /// **'You can export or delete your data at any time from your profile.'**
  String get onboardingPrivacyControl;

  /// No description provided for @onboardingRegionTitle.
  ///
  /// In en, this message translates to:
  /// **'Currency and time zone'**
  String get onboardingRegionTitle;

  /// No description provided for @onboardingRegionBody.
  ///
  /// In en, this message translates to:
  /// **'Montra uses these for totals and dates. Changing them later never rewrites past amounts or dates.'**
  String get onboardingRegionBody;

  /// No description provided for @onboardingCurrencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Main currency'**
  String get onboardingCurrencyLabel;

  /// No description provided for @onboardingCurrencyHelp.
  ///
  /// In en, this message translates to:
  /// **'Accounts can still use other currencies.'**
  String get onboardingCurrencyHelp;

  /// No description provided for @onboardingTimezoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Time zone'**
  String get onboardingTimezoneLabel;

  /// No description provided for @onboardingTimezoneHelp.
  ///
  /// In en, this message translates to:
  /// **'Decides which day a transaction belongs to.'**
  String get onboardingTimezoneHelp;

  /// No description provided for @onboardingUseDeviceTimezone.
  ///
  /// In en, this message translates to:
  /// **'Use this device\'s time zone ({timezone})'**
  String onboardingUseDeviceTimezone(String timezone);

  /// No description provided for @onboardingCountryLabel.
  ///
  /// In en, this message translates to:
  /// **'Country or region code'**
  String get onboardingCountryLabel;

  /// No description provided for @onboardingCountryHelp.
  ///
  /// In en, this message translates to:
  /// **'Two letters, for example IN.'**
  String get onboardingCountryHelp;

  /// No description provided for @onboardingCountryInvalid.
  ///
  /// In en, this message translates to:
  /// **'Use two letters, for example IN.'**
  String get onboardingCountryInvalid;

  /// No description provided for @onboardingIncomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Monthly income (optional)'**
  String get onboardingIncomeTitle;

  /// No description provided for @onboardingIncomeBody.
  ///
  /// In en, this message translates to:
  /// **'A rough monthly range in rupees only helps Montra tailor tips. It\'s never shown to anyone, and you can skip it.'**
  String get onboardingIncomeBody;

  /// No description provided for @incomeUnder25k.
  ///
  /// In en, this message translates to:
  /// **'Under ₹25,000'**
  String get incomeUnder25k;

  /// No description provided for @income25k50k.
  ///
  /// In en, this message translates to:
  /// **'₹25,000 – ₹50,000'**
  String get income25k50k;

  /// No description provided for @income50k1l.
  ///
  /// In en, this message translates to:
  /// **'₹50,000 – ₹1 lakh'**
  String get income50k1l;

  /// No description provided for @income1l2l.
  ///
  /// In en, this message translates to:
  /// **'₹1 lakh – ₹2 lakh'**
  String get income1l2l;

  /// No description provided for @income2l5l.
  ///
  /// In en, this message translates to:
  /// **'₹2 lakh – ₹5 lakh'**
  String get income2l5l;

  /// No description provided for @incomeAbove5l.
  ///
  /// In en, this message translates to:
  /// **'Above ₹5 lakh'**
  String get incomeAbove5l;

  /// No description provided for @incomePreferNot.
  ///
  /// In en, this message translates to:
  /// **'Prefer not to say'**
  String get incomePreferNot;

  /// No description provided for @onboardingAccountsTitle.
  ///
  /// In en, this message translates to:
  /// **'Add an account (optional)'**
  String get onboardingAccountsTitle;

  /// No description provided for @onboardingAccountsBody.
  ///
  /// In en, this message translates to:
  /// **'Start with the wallet or account you use most. You can add more anytime.'**
  String get onboardingAccountsBody;

  /// No description provided for @onboardingAddAnother.
  ///
  /// In en, this message translates to:
  /// **'Add another account'**
  String get onboardingAddAnother;

  /// No description provided for @onboardingCategoriesTitle.
  ///
  /// In en, this message translates to:
  /// **'Your starter categories'**
  String get onboardingCategoriesTitle;

  /// No description provided for @onboardingCategoriesBody.
  ///
  /// In en, this message translates to:
  /// **'We\'ve added these categories so you can start right away. You can rename, add or archive categories later.'**
  String get onboardingCategoriesBody;

  /// No description provided for @onboardingCategoriesSpending.
  ///
  /// In en, this message translates to:
  /// **'For spending'**
  String get onboardingCategoriesSpending;

  /// No description provided for @onboardingCategoriesIncome.
  ///
  /// In en, this message translates to:
  /// **'For income'**
  String get onboardingCategoriesIncome;

  /// No description provided for @onboardingFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish setup'**
  String get onboardingFinish;

  /// No description provided for @onboardingFinishNote.
  ///
  /// In en, this message translates to:
  /// **'You can change all of this later.'**
  String get onboardingFinishNote;

  /// No description provided for @profileAccountsTitle.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get profileAccountsTitle;

  /// No description provided for @profileAccountsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Wallets, bank accounts, cards and loans'**
  String get profileAccountsSubtitle;

  /// No description provided for @profilePaymentMethodsTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment methods'**
  String get profilePaymentMethodsTitle;

  /// No description provided for @profilePaymentMethodsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'UPI, cash, cards and more'**
  String get profilePaymentMethodsSubtitle;

  /// No description provided for @profileHomeLayout.
  ///
  /// In en, this message translates to:
  /// **'Home layout'**
  String get profileHomeLayout;

  /// No description provided for @profileHomeLayoutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show, hide and reorder Home widgets'**
  String get profileHomeLayoutSubtitle;

  /// No description provided for @widgetUnknownTitle.
  ///
  /// In en, this message translates to:
  /// **'Widget from a newer version'**
  String get widgetUnknownTitle;

  /// No description provided for @paymentArchivedResult.
  ///
  /// In en, this message translates to:
  /// **'Archived because transactions use it. You can restore it from the archived list.'**
  String get paymentArchivedResult;

  /// No description provided for @paymentRestored.
  ///
  /// In en, this message translates to:
  /// **'Payment method restored.'**
  String get paymentRestored;

  /// No description provided for @paymentRestoreLabel.
  ///
  /// In en, this message translates to:
  /// **'Restore {label}'**
  String paymentRestoreLabel(String label);

  /// No description provided for @auditReconciled.
  ///
  /// In en, this message translates to:
  /// **'Reconciled'**
  String get auditReconciled;

  /// No description provided for @auditUnreconciled.
  ///
  /// In en, this message translates to:
  /// **'Reconciliation undone'**
  String get auditUnreconciled;

  /// No description provided for @auditImported.
  ///
  /// In en, this message translates to:
  /// **'Imported'**
  String get auditImported;

  /// No description provided for @auditReceiptLinked.
  ///
  /// In en, this message translates to:
  /// **'Receipt linked'**
  String get auditReceiptLinked;

  /// No description provided for @auditTagsChanged.
  ///
  /// In en, this message translates to:
  /// **'Tags changed'**
  String get auditTagsChanged;

  /// No description provided for @auditOther.
  ///
  /// In en, this message translates to:
  /// **'Changed'**
  String get auditOther;

  /// No description provided for @auditActorImport.
  ///
  /// In en, this message translates to:
  /// **'from an import'**
  String get auditActorImport;

  /// No description provided for @auditActorRecurring.
  ///
  /// In en, this message translates to:
  /// **'by a recurring rule'**
  String get auditActorRecurring;

  /// No description provided for @auditActorIntegration.
  ///
  /// In en, this message translates to:
  /// **'from a connected provider'**
  String get auditActorIntegration;

  /// No description provided for @trendUnitYear.
  ///
  /// In en, this message translates to:
  /// **'year'**
  String get trendUnitYear;

  /// No description provided for @noteExcludesTransfers.
  ///
  /// In en, this message translates to:
  /// **'Transfers between your accounts, balance adjustments and opening balances are not counted as income or spending.'**
  String get noteExcludesTransfers;

  /// No description provided for @noteRefundsReduceSpending.
  ///
  /// In en, this message translates to:
  /// **'Refunds and reimbursements reduce spending; for group expenses only your share counts.'**
  String get noteRefundsReduceSpending;

  /// No description provided for @noteCurrenciesSeparate.
  ///
  /// In en, this message translates to:
  /// **'Amounts in different currencies are shown separately and never added together.'**
  String get noteCurrenciesSeparate;

  /// No description provided for @noteBalancesTracked.
  ///
  /// In en, this message translates to:
  /// **'Balances are tracked from your entries and imports; they are not verified by a bank.'**
  String get noteBalancesTracked;

  /// No description provided for @possibleDuplicateNoticeReasons.
  ///
  /// In en, this message translates to:
  /// **'Saved. It looks like {count, plural, =1{another transaction} other{{count} other transactions}} ({reasons}). Nothing was merged.'**
  String possibleDuplicateNoticeReasons(int count, String reasons);

  /// No description provided for @duplicateSameAccountAmount.
  ///
  /// In en, this message translates to:
  /// **'same account and amount'**
  String get duplicateSameAccountAmount;

  /// No description provided for @duplicateSameDate.
  ///
  /// In en, this message translates to:
  /// **'same date'**
  String get duplicateSameDate;

  /// No description provided for @duplicateDaysApart.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =0{same day} =1{1 day apart} other{{days} days apart}}'**
  String duplicateDaysApart(int days);

  /// No description provided for @duplicateSameDescription.
  ///
  /// In en, this message translates to:
  /// **'same description'**
  String get duplicateSameDescription;

  /// No description provided for @filterUncategorized.
  ///
  /// In en, this message translates to:
  /// **'Without a category'**
  String get filterUncategorized;

  /// No description provided for @filterUncategorizedHelp.
  ///
  /// In en, this message translates to:
  /// **'Only transactions that have no category yet.'**
  String get filterUncategorizedHelp;

  /// No description provided for @ruleRefundExceedsRemaining.
  ///
  /// In en, this message translates to:
  /// **'Refunds and reimbursements can\'t be more than the original. {remaining} {currency} can still be refunded. Mark it as a correction if this is intentional.'**
  String ruleRefundExceedsRemaining(String remaining, String currency);

  /// No description provided for @ruleOriginalNotRefundable.
  ///
  /// In en, this message translates to:
  /// **'Only your own expenses that aren\'t deleted can get a refund or reimbursement.'**
  String get ruleOriginalNotRefundable;

  /// No description provided for @ruleCurrencyMismatch.
  ///
  /// In en, this message translates to:
  /// **'Use the same currency as the original ({currency}).'**
  String ruleCurrencyMismatch(String currency);

  /// No description provided for @ruleAccountInactive.
  ///
  /// In en, this message translates to:
  /// **'This account is archived or closed. Restore it to add or change transactions.'**
  String get ruleAccountInactive;

  /// No description provided for @ruleGroupLinked.
  ///
  /// In en, this message translates to:
  /// **'This is linked to a group record, so change it from the group.'**
  String get ruleGroupLinked;

  /// No description provided for @ruleHasLinkedRefunds.
  ///
  /// In en, this message translates to:
  /// **'Delete the linked refunds or reimbursements first.'**
  String get ruleHasLinkedRefunds;

  /// No description provided for @frequencyDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get frequencyDaily;

  /// No description provided for @frequencyWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get frequencyWeekly;

  /// No description provided for @frequencyBiweekly.
  ///
  /// In en, this message translates to:
  /// **'Every 2 weeks'**
  String get frequencyBiweekly;

  /// No description provided for @frequencyMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get frequencyMonthly;

  /// No description provided for @frequencyBimonthly.
  ///
  /// In en, this message translates to:
  /// **'Every 2 months'**
  String get frequencyBimonthly;

  /// No description provided for @frequencyQuarterly.
  ///
  /// In en, this message translates to:
  /// **'Every 3 months'**
  String get frequencyQuarterly;

  /// No description provided for @frequencySemiannual.
  ///
  /// In en, this message translates to:
  /// **'Every 6 months'**
  String get frequencySemiannual;

  /// No description provided for @frequencyYearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get frequencyYearly;

  /// No description provided for @frequencyCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get frequencyCustom;

  /// No description provided for @frequencyEveryDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Every day} other{Every {count} days}}'**
  String frequencyEveryDays(int count);

  /// No description provided for @frequencyEveryWeeks.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Every week} other{Every {count} weeks}}'**
  String frequencyEveryWeeks(int count);

  /// No description provided for @frequencyEveryMonths.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Every month} other{Every {count} months}}'**
  String frequencyEveryMonths(int count);

  /// No description provided for @frequencyEveryYears.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Every year} other{Every {count} years}}'**
  String frequencyEveryYears(int count);

  /// No description provided for @intervalUnitDays.
  ///
  /// In en, this message translates to:
  /// **'Days'**
  String get intervalUnitDays;

  /// No description provided for @intervalUnitWeeks.
  ///
  /// In en, this message translates to:
  /// **'Weeks'**
  String get intervalUnitWeeks;

  /// No description provided for @intervalUnitMonths.
  ///
  /// In en, this message translates to:
  /// **'Months'**
  String get intervalUnitMonths;

  /// No description provided for @intervalUnitYears.
  ///
  /// In en, this message translates to:
  /// **'Years'**
  String get intervalUnitYears;

  /// No description provided for @reminderDaysLabel.
  ///
  /// In en, this message translates to:
  /// **'Remind me'**
  String get reminderDaysLabel;

  /// No description provided for @reminderOnTheDay.
  ///
  /// In en, this message translates to:
  /// **'On the day'**
  String get reminderOnTheDay;

  /// No description provided for @reminderDaysBefore.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{1 day before} other{{days} days before}}'**
  String reminderDaysBefore(int days);

  /// No description provided for @reminderDaysHelp.
  ///
  /// In en, this message translates to:
  /// **'Choose up to {max}.'**
  String reminderDaysHelp(int max);

  /// No description provided for @reminderNone.
  ///
  /// In en, this message translates to:
  /// **'No reminders.'**
  String get reminderNone;

  /// No description provided for @personPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a person'**
  String get personPickerTitle;

  /// No description provided for @personPickerEmpty.
  ///
  /// In en, this message translates to:
  /// **'No connections yet. People you connect with in Montra show up here.'**
  String get personPickerEmpty;

  /// No description provided for @groupMemberPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a group member'**
  String get groupMemberPickerTitle;

  /// No description provided for @groupMemberPickerEmpty.
  ///
  /// In en, this message translates to:
  /// **'There\'s no one else in this group yet.'**
  String get groupMemberPickerEmpty;

  /// No description provided for @groupPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a group'**
  String get groupPickerTitle;

  /// No description provided for @groupPickerEmpty.
  ///
  /// In en, this message translates to:
  /// **'You\'re not in any groups yet.'**
  String get groupPickerEmpty;

  /// No description provided for @groupNone.
  ///
  /// In en, this message translates to:
  /// **'No group'**
  String get groupNone;

  /// No description provided for @groupMemberCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 member} other{{count} members}}'**
  String groupMemberCount(int count);

  /// No description provided for @transactionPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a transaction'**
  String get transactionPickerTitle;

  /// No description provided for @transactionPickerSearch.
  ///
  /// In en, this message translates to:
  /// **'Search transactions'**
  String get transactionPickerSearch;

  /// No description provided for @transactionPickerEmpty.
  ///
  /// In en, this message translates to:
  /// **'No matching transactions.'**
  String get transactionPickerEmpty;

  /// No description provided for @recurringTitle.
  ///
  /// In en, this message translates to:
  /// **'Recurring'**
  String get recurringTitle;

  /// No description provided for @recurringAdd.
  ///
  /// In en, this message translates to:
  /// **'Add recurring'**
  String get recurringAdd;

  /// No description provided for @recurringAddFirst.
  ///
  /// In en, this message translates to:
  /// **'Add your first recurring item'**
  String get recurringAddFirst;

  /// No description provided for @recurringEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No recurring items yet'**
  String get recurringEmptyTitle;

  /// No description provided for @recurringEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add rent, salary or a monthly transfer once. Montra shows each one when it\'s due, and you decide what to record.'**
  String get recurringEmptyBody;

  /// No description provided for @recurringNoMatchTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches these filters'**
  String get recurringNoMatchTitle;

  /// No description provided for @recurringNoMatchBody.
  ///
  /// In en, this message translates to:
  /// **'Try another type or status.'**
  String get recurringNoMatchBody;

  /// No description provided for @recurringFilterAllKinds.
  ///
  /// In en, this message translates to:
  /// **'All types'**
  String get recurringFilterAllKinds;

  /// No description provided for @recurringFilterExpenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get recurringFilterExpenses;

  /// No description provided for @recurringFilterIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get recurringFilterIncome;

  /// No description provided for @recurringFilterTransfers.
  ///
  /// In en, this message translates to:
  /// **'Transfers'**
  String get recurringFilterTransfers;

  /// No description provided for @recurringFilterBills.
  ///
  /// In en, this message translates to:
  /// **'Bills'**
  String get recurringFilterBills;

  /// No description provided for @recurringFilterAllStatuses.
  ///
  /// In en, this message translates to:
  /// **'Any status'**
  String get recurringFilterAllStatuses;

  /// No description provided for @recurringStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get recurringStatusActive;

  /// No description provided for @recurringStatusPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get recurringStatusPaused;

  /// No description provided for @recurringStatusEnded.
  ///
  /// In en, this message translates to:
  /// **'Ended'**
  String get recurringStatusEnded;

  /// No description provided for @recurringStatusSemantics.
  ///
  /// In en, this message translates to:
  /// **'Status: {status}'**
  String recurringStatusSemantics(String status);

  /// No description provided for @recurringKindExpense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get recurringKindExpense;

  /// No description provided for @recurringKindIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get recurringKindIncome;

  /// No description provided for @recurringKindTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get recurringKindTransfer;

  /// No description provided for @recurringKindBill.
  ///
  /// In en, this message translates to:
  /// **'Bill'**
  String get recurringKindBill;

  /// No description provided for @recurringKindSubscription.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get recurringKindSubscription;

  /// No description provided for @recurringKindGroupExpense.
  ///
  /// In en, this message translates to:
  /// **'Group expense'**
  String get recurringKindGroupExpense;

  /// No description provided for @recurringKindOther.
  ///
  /// In en, this message translates to:
  /// **'Recurring'**
  String get recurringKindOther;

  /// No description provided for @recurringKindLabel.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get recurringKindLabel;

  /// No description provided for @recurringKindFixed.
  ///
  /// In en, this message translates to:
  /// **'The type stays the same when you edit. To change it, add a new recurring item.'**
  String get recurringKindFixed;

  /// No description provided for @recurringNextOn.
  ///
  /// In en, this message translates to:
  /// **'Next: {date}'**
  String recurringNextOn(String date);

  /// No description provided for @recurringVaries.
  ///
  /// In en, this message translates to:
  /// **'Varies'**
  String get recurringVaries;

  /// No description provided for @recurringAmountVaries.
  ///
  /// In en, this message translates to:
  /// **'Amount varies'**
  String get recurringAmountVaries;

  /// No description provided for @recurringNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New recurring item'**
  String get recurringNewTitle;

  /// No description provided for @recurringEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit recurring item'**
  String get recurringEditTitle;

  /// No description provided for @recurringEditFutureNote.
  ///
  /// In en, this message translates to:
  /// **'Changes apply to this and future occurrences. Past ones stay as they are.'**
  String get recurringEditFutureNote;

  /// No description provided for @recurringNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get recurringNameLabel;

  /// No description provided for @recurringNameHelp.
  ///
  /// In en, this message translates to:
  /// **'For example \"Rent\" or \"Salary\".'**
  String get recurringNameHelp;

  /// No description provided for @recurringAmountSection.
  ///
  /// In en, this message translates to:
  /// **'Amount and account'**
  String get recurringAmountSection;

  /// No description provided for @recurringVariableLabel.
  ///
  /// In en, this message translates to:
  /// **'The amount changes each time'**
  String get recurringVariableLabel;

  /// No description provided for @recurringVariableHelp.
  ///
  /// In en, this message translates to:
  /// **'You\'ll enter the amount when you record it.'**
  String get recurringVariableHelp;

  /// No description provided for @recurringAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Expected amount'**
  String get recurringAmountLabel;

  /// No description provided for @recurringFromAccountLabel.
  ///
  /// In en, this message translates to:
  /// **'From account'**
  String get recurringFromAccountLabel;

  /// No description provided for @recurringToAccountLabel.
  ///
  /// In en, this message translates to:
  /// **'To account'**
  String get recurringToAccountLabel;

  /// No description provided for @recurringAccountRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose an account.'**
  String get recurringAccountRequired;

  /// No description provided for @recurringAutoPostLabel.
  ///
  /// In en, this message translates to:
  /// **'Record automatically'**
  String get recurringAutoPostLabel;

  /// No description provided for @recurringAutoPostHelp.
  ///
  /// In en, this message translates to:
  /// **'When it\'s due, Montra adds the transaction for you.'**
  String get recurringAutoPostHelp;

  /// No description provided for @recurringAutoPostNeedsAmount.
  ///
  /// In en, this message translates to:
  /// **'Needs a fixed amount and an account.'**
  String get recurringAutoPostNeedsAmount;

  /// No description provided for @recurringAutoPostOn.
  ///
  /// In en, this message translates to:
  /// **'Recorded automatically'**
  String get recurringAutoPostOn;

  /// No description provided for @recurringAutoPostOff.
  ///
  /// In en, this message translates to:
  /// **'You confirm each one'**
  String get recurringAutoPostOff;

  /// No description provided for @recurringMoreSection.
  ///
  /// In en, this message translates to:
  /// **'More details'**
  String get recurringMoreSection;

  /// No description provided for @recurringCreateButton.
  ///
  /// In en, this message translates to:
  /// **'Add recurring item'**
  String get recurringCreateButton;

  /// No description provided for @recurringCreated.
  ///
  /// In en, this message translates to:
  /// **'Recurring item added.'**
  String get recurringCreated;

  /// No description provided for @recurringSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved for this and future occurrences.'**
  String get recurringSaved;

  /// No description provided for @recurringDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Recurring item'**
  String get recurringDetailTitle;

  /// No description provided for @recurringUpcomingTitle.
  ///
  /// In en, this message translates to:
  /// **'Coming up'**
  String get recurringUpcomingTitle;

  /// No description provided for @recurringHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get recurringHistoryTitle;

  /// No description provided for @recurringDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get recurringDetailsTitle;

  /// No description provided for @recurringNextLabel.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get recurringNextLabel;

  /// No description provided for @recurringNothingUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Nothing coming up.'**
  String get recurringNothingUpcoming;

  /// No description provided for @recurringNoHistory.
  ///
  /// In en, this message translates to:
  /// **'Nothing recorded yet.'**
  String get recurringNoHistory;

  /// No description provided for @recurringCompletedLabel.
  ///
  /// In en, this message translates to:
  /// **'Recorded or paid so far'**
  String get recurringCompletedLabel;

  /// No description provided for @recurringManagedByBill.
  ///
  /// In en, this message translates to:
  /// **'This schedule belongs to a bill. Change or pause it from the bill.'**
  String get recurringManagedByBill;

  /// No description provided for @recurringManagedBySubscription.
  ///
  /// In en, this message translates to:
  /// **'This schedule belongs to a subscription. Manage it from the subscription.'**
  String get recurringManagedBySubscription;

  /// No description provided for @recurringManagedByGroup.
  ///
  /// In en, this message translates to:
  /// **'This is a shared expense of a group. Manage it from the group.'**
  String get recurringManagedByGroup;

  /// No description provided for @recurringOpenBill.
  ///
  /// In en, this message translates to:
  /// **'Open bill'**
  String get recurringOpenBill;

  /// No description provided for @recurringSharedReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Shared with you · read-only'**
  String get recurringSharedReadOnly;

  /// No description provided for @recurringPausedNotice.
  ///
  /// In en, this message translates to:
  /// **'Paused. Nothing new is added until you resume it.'**
  String get recurringPausedNotice;

  /// No description provided for @recurringEndedNotice.
  ///
  /// In en, this message translates to:
  /// **'Ended. Its history is kept.'**
  String get recurringEndedNotice;

  /// No description provided for @recurringPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get recurringPause;

  /// No description provided for @recurringResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get recurringResume;

  /// No description provided for @recurringSkipNext.
  ///
  /// In en, this message translates to:
  /// **'Skip the next one'**
  String get recurringSkipNext;

  /// No description provided for @recurringStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get recurringStop;

  /// No description provided for @recurringPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused.'**
  String get recurringPaused;

  /// No description provided for @recurringResumed.
  ///
  /// In en, this message translates to:
  /// **'Resumed.'**
  String get recurringResumed;

  /// No description provided for @recurringSkippedNext.
  ///
  /// In en, this message translates to:
  /// **'The next one is skipped.'**
  String get recurringSkippedNext;

  /// No description provided for @recurringStopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped. Its history is kept.'**
  String get recurringStopped;

  /// No description provided for @recurringSkipNextConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Skip the next one?'**
  String get recurringSkipNextConfirmTitle;

  /// No description provided for @recurringSkipNextConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'The next occurrence of {name} will be skipped. Later ones stay as planned.'**
  String recurringSkipNextConfirmBody(String name);

  /// No description provided for @recurringStopConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Stop this recurring item?'**
  String get recurringStopConfirmTitle;

  /// No description provided for @recurringStopConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'No more occurrences of {name} will be added. What\'s already recorded stays.'**
  String recurringStopConfirmBody(String name);

  /// No description provided for @recurringDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this recurring item?'**
  String get recurringDeleteConfirmTitle;

  /// No description provided for @recurringDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'If {name} was never used, it\'s removed. If it has history, it ends instead and the history is kept.'**
  String recurringDeleteConfirmBody(String name);

  /// No description provided for @recurringDeleted.
  ///
  /// In en, this message translates to:
  /// **'Recurring item deleted.'**
  String get recurringDeleted;

  /// No description provided for @recurringEndedKept.
  ///
  /// In en, this message translates to:
  /// **'It has history, so it was ended instead. Past occurrences are kept.'**
  String get recurringEndedKept;

  /// No description provided for @occurrenceStatusScheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get occurrenceStatusScheduled;

  /// No description provided for @occurrenceStatusPosted.
  ///
  /// In en, this message translates to:
  /// **'Recorded'**
  String get occurrenceStatusPosted;

  /// No description provided for @occurrenceStatusPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get occurrenceStatusPaid;

  /// No description provided for @occurrenceStatusSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get occurrenceStatusSkipped;

  /// No description provided for @occurrenceStatusOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get occurrenceStatusOverdue;

  /// No description provided for @occurrenceStatusOther.
  ///
  /// In en, this message translates to:
  /// **'Planned'**
  String get occurrenceStatusOther;

  /// No description provided for @occurrenceMovedFrom.
  ///
  /// In en, this message translates to:
  /// **'Moved from {date}'**
  String occurrenceMovedFrom(String date);

  /// No description provided for @occurrenceHasTransaction.
  ///
  /// In en, this message translates to:
  /// **'Linked to a transaction'**
  String get occurrenceHasTransaction;

  /// No description provided for @occurrenceSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Due {date}'**
  String occurrenceSheetTitle(String date);

  /// No description provided for @occurrenceConfirm.
  ///
  /// In en, this message translates to:
  /// **'Record it now'**
  String get occurrenceConfirm;

  /// No description provided for @occurrenceConfirmHelp.
  ///
  /// In en, this message translates to:
  /// **'Adds the transaction to your account.'**
  String get occurrenceConfirmHelp;

  /// No description provided for @occurrenceLink.
  ///
  /// In en, this message translates to:
  /// **'Link a transaction I already added'**
  String get occurrenceLink;

  /// No description provided for @occurrenceLinkHelp.
  ///
  /// In en, this message translates to:
  /// **'Nothing new is added, so there\'s no duplicate.'**
  String get occurrenceLinkHelp;

  /// No description provided for @occurrenceLinkTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose the transaction'**
  String get occurrenceLinkTitle;

  /// No description provided for @occurrenceSetAmount.
  ///
  /// In en, this message translates to:
  /// **'Change the amount'**
  String get occurrenceSetAmount;

  /// No description provided for @occurrencePostpone.
  ///
  /// In en, this message translates to:
  /// **'Move to another date'**
  String get occurrencePostpone;

  /// No description provided for @occurrencePostponeTitle.
  ///
  /// In en, this message translates to:
  /// **'Move to'**
  String get occurrencePostponeTitle;

  /// No description provided for @occurrenceSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip this one'**
  String get occurrenceSkip;

  /// No description provided for @occurrenceReopen.
  ///
  /// In en, this message translates to:
  /// **'Undo skip'**
  String get occurrenceReopen;

  /// No description provided for @occurrenceOpenTransaction.
  ///
  /// In en, this message translates to:
  /// **'Open transaction'**
  String get occurrenceOpenTransaction;

  /// No description provided for @occurrenceSkipConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Skip this one?'**
  String get occurrenceSkipConfirmTitle;

  /// No description provided for @occurrenceSkipConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Nothing will be recorded for {date}. You can undo this later.'**
  String occurrenceSkipConfirmBody(String date);

  /// No description provided for @occurrenceConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Record this one'**
  String get occurrenceConfirmTitle;

  /// No description provided for @occurrenceConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'{name}, due {date}.'**
  String occurrenceConfirmBody(String name, String date);

  /// No description provided for @occurrenceAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get occurrenceAmountLabel;

  /// No description provided for @occurrenceAmountHelp.
  ///
  /// In en, this message translates to:
  /// **'Change it if the actual amount was different.'**
  String get occurrenceAmountHelp;

  /// No description provided for @occurrenceDateDefault.
  ///
  /// In en, this message translates to:
  /// **'Due date (or today if early)'**
  String get occurrenceDateDefault;

  /// No description provided for @occurrenceConfirmButton.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get occurrenceConfirmButton;

  /// No description provided for @occurrenceSetAmountTitle.
  ///
  /// In en, this message translates to:
  /// **'Change the amount'**
  String get occurrenceSetAmountTitle;

  /// No description provided for @occurrenceSetAmountBody.
  ///
  /// In en, this message translates to:
  /// **'Only this occurrence changes.'**
  String get occurrenceSetAmountBody;

  /// No description provided for @occurrenceRecorded.
  ///
  /// In en, this message translates to:
  /// **'Recorded.'**
  String get occurrenceRecorded;

  /// No description provided for @occurrenceLinked.
  ///
  /// In en, this message translates to:
  /// **'Linked to the transaction.'**
  String get occurrenceLinked;

  /// No description provided for @occurrenceSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped.'**
  String get occurrenceSkipped;

  /// No description provided for @occurrencePostponed.
  ///
  /// In en, this message translates to:
  /// **'Moved to the new date.'**
  String get occurrencePostponed;

  /// No description provided for @occurrenceAmountSet.
  ///
  /// In en, this message translates to:
  /// **'Amount changed.'**
  String get occurrenceAmountSet;

  /// No description provided for @occurrenceReopened.
  ///
  /// In en, this message translates to:
  /// **'It\'s back on the list.'**
  String get occurrenceReopened;

  /// No description provided for @occurrenceUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated.'**
  String get occurrenceUpdated;

  /// No description provided for @scheduleTitle.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get scheduleTitle;

  /// No description provided for @scheduleFrequencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Repeats'**
  String get scheduleFrequencyLabel;

  /// No description provided for @scheduleEveryLabel.
  ///
  /// In en, this message translates to:
  /// **'Every'**
  String get scheduleEveryLabel;

  /// No description provided for @scheduleUnitLabel.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get scheduleUnitLabel;

  /// No description provided for @scheduleIntervalInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a number from 1 to 366.'**
  String get scheduleIntervalInvalid;

  /// No description provided for @scheduleWeekdayLabel.
  ///
  /// In en, this message translates to:
  /// **'Day of the week'**
  String get scheduleWeekdayLabel;

  /// No description provided for @scheduleSameWeekday.
  ///
  /// In en, this message translates to:
  /// **'Same day as the start date'**
  String get scheduleSameWeekday;

  /// No description provided for @scheduleDayLabel.
  ///
  /// In en, this message translates to:
  /// **'Which day'**
  String get scheduleDayLabel;

  /// No description provided for @scheduleAnchorStart.
  ///
  /// In en, this message translates to:
  /// **'Same date as the start date'**
  String get scheduleAnchorStart;

  /// No description provided for @scheduleAnchorMonthDay.
  ///
  /// In en, this message translates to:
  /// **'A date of the month'**
  String get scheduleAnchorMonthDay;

  /// No description provided for @scheduleAnchorNthWeekday.
  ///
  /// In en, this message translates to:
  /// **'A weekday of the month'**
  String get scheduleAnchorNthWeekday;

  /// No description provided for @scheduleMonthDayLabel.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get scheduleMonthDayLabel;

  /// No description provided for @scheduleLastDay.
  ///
  /// In en, this message translates to:
  /// **'Last day of the month'**
  String get scheduleLastDay;

  /// No description provided for @scheduleMonthDayHelp.
  ///
  /// In en, this message translates to:
  /// **'In shorter months it falls on the last day.'**
  String get scheduleMonthDayHelp;

  /// No description provided for @scheduleWeekOfMonthLabel.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get scheduleWeekOfMonthLabel;

  /// No description provided for @scheduleOrdinal.
  ///
  /// In en, this message translates to:
  /// **'{n, select, 1{First} 2{Second} 3{Third} 4{Fourth} 5{Fifth} other{Last}}'**
  String scheduleOrdinal(String n);

  /// No description provided for @scheduleOnWeekday.
  ///
  /// In en, this message translates to:
  /// **'on {weekday}'**
  String scheduleOnWeekday(String weekday);

  /// No description provided for @scheduleOnNthWeekday.
  ///
  /// In en, this message translates to:
  /// **'on the {week, select, 1{first} 2{second} 3{third} 4{fourth} 5{fifth} other{last}} {weekday}'**
  String scheduleOnNthWeekday(String week, String weekday);

  /// No description provided for @scheduleOnMonthDay.
  ///
  /// In en, this message translates to:
  /// **'on day {day}'**
  String scheduleOnMonthDay(int day);

  /// No description provided for @scheduleOnLastDay.
  ///
  /// In en, this message translates to:
  /// **'on the last day'**
  String get scheduleOnLastDay;

  /// No description provided for @scheduleStartLabel.
  ///
  /// In en, this message translates to:
  /// **'Starts on'**
  String get scheduleStartLabel;

  /// No description provided for @scheduleEndsLabel.
  ///
  /// In en, this message translates to:
  /// **'Ends'**
  String get scheduleEndsLabel;

  /// No description provided for @scheduleEndsNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get scheduleEndsNever;

  /// No description provided for @scheduleEndsOnDate.
  ///
  /// In en, this message translates to:
  /// **'On a date'**
  String get scheduleEndsOnDate;

  /// No description provided for @scheduleEndsAfter.
  ///
  /// In en, this message translates to:
  /// **'After a number of times'**
  String get scheduleEndsAfter;

  /// No description provided for @scheduleEndDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Ends on'**
  String get scheduleEndDateLabel;

  /// No description provided for @scheduleEndDateChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose a date'**
  String get scheduleEndDateChoose;

  /// No description provided for @scheduleEndBeforeStart.
  ///
  /// In en, this message translates to:
  /// **'Choose a date after the start date.'**
  String get scheduleEndBeforeStart;

  /// No description provided for @scheduleTimesLabel.
  ///
  /// In en, this message translates to:
  /// **'Number of times'**
  String get scheduleTimesLabel;

  /// No description provided for @scheduleTimesInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a number from 1 to 10,000.'**
  String get scheduleTimesInvalid;

  /// No description provided for @scheduleTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get scheduleTimeLabel;

  /// No description provided for @scheduleTimeHelp.
  ///
  /// In en, this message translates to:
  /// **'Reminders and automatic entries use this time.'**
  String get scheduleTimeHelp;

  /// No description provided for @scheduleFrom.
  ///
  /// In en, this message translates to:
  /// **'From {start}'**
  String scheduleFrom(String start);

  /// No description provided for @scheduleFromUntil.
  ///
  /// In en, this message translates to:
  /// **'From {start} until {end}'**
  String scheduleFromUntil(String start, String end);

  /// No description provided for @scheduleFromTimes.
  ///
  /// In en, this message translates to:
  /// **'From {start}, {count, plural, =1{once} other{{count} times}}'**
  String scheduleFromTimes(String start, int count);

  /// No description provided for @billsTitle.
  ///
  /// In en, this message translates to:
  /// **'Bills'**
  String get billsTitle;

  /// No description provided for @billAdd.
  ///
  /// In en, this message translates to:
  /// **'Add bill'**
  String get billAdd;

  /// No description provided for @billAddFirst.
  ///
  /// In en, this message translates to:
  /// **'Add your first bill'**
  String get billAddFirst;

  /// No description provided for @billsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No bills yet'**
  String get billsEmptyTitle;

  /// No description provided for @billsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add rent, electricity or phone bills to see what\'s due and mark them paid.'**
  String get billsEmptyBody;

  /// No description provided for @billsNoMatchTitle.
  ///
  /// In en, this message translates to:
  /// **'No bills here'**
  String get billsNoMatchTitle;

  /// No description provided for @billFilterActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get billFilterActive;

  /// No description provided for @billFilterPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get billFilterPaused;

  /// No description provided for @billFilterArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get billFilterArchived;

  /// No description provided for @billFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get billFilterAll;

  /// No description provided for @billStateOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get billStateOverdue;

  /// No description provided for @billStateDueToday.
  ///
  /// In en, this message translates to:
  /// **'Due today'**
  String get billStateDueToday;

  /// No description provided for @billStateDueSoon.
  ///
  /// In en, this message translates to:
  /// **'Due soon'**
  String get billStateDueSoon;

  /// No description provided for @billStatePaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get billStatePaid;

  /// No description provided for @billStateUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get billStateUpcoming;

  /// No description provided for @billStatePaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get billStatePaused;

  /// No description provided for @billStateArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get billStateArchived;

  /// No description provided for @billStateEnded.
  ///
  /// In en, this message translates to:
  /// **'Ended'**
  String get billStateEnded;

  /// No description provided for @billStateOther.
  ///
  /// In en, this message translates to:
  /// **'Status unavailable'**
  String get billStateOther;

  /// No description provided for @billStateSemantics.
  ///
  /// In en, this message translates to:
  /// **'Payment state: {state}'**
  String billStateSemantics(String state);

  /// No description provided for @billDueOn.
  ///
  /// In en, this message translates to:
  /// **'Due {date}'**
  String billDueOn(String date);

  /// No description provided for @billPaidOn.
  ///
  /// In en, this message translates to:
  /// **'Paid {date}'**
  String billPaidOn(String date);

  /// No description provided for @billLastPaidOn.
  ///
  /// In en, this message translates to:
  /// **'Last paid {date}'**
  String billLastPaidOn(String date);

  /// No description provided for @billVaries.
  ///
  /// In en, this message translates to:
  /// **'Varies'**
  String get billVaries;

  /// No description provided for @billNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New bill'**
  String get billNewTitle;

  /// No description provided for @billEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit bill'**
  String get billEditTitle;

  /// No description provided for @billNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Bill name'**
  String get billNameLabel;

  /// No description provided for @billNameHelp.
  ///
  /// In en, this message translates to:
  /// **'For example \"Electricity\" or \"Phone\".'**
  String get billNameHelp;

  /// No description provided for @billProviderLabel.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get billProviderLabel;

  /// No description provided for @billProviderHelp.
  ///
  /// In en, this message translates to:
  /// **'Who you pay, for example your power company.'**
  String get billProviderHelp;

  /// No description provided for @billAmountSection.
  ///
  /// In en, this message translates to:
  /// **'Amount and payment'**
  String get billAmountSection;

  /// No description provided for @billVariableLabel.
  ///
  /// In en, this message translates to:
  /// **'The amount changes each time'**
  String get billVariableLabel;

  /// No description provided for @billVariableHelp.
  ///
  /// In en, this message translates to:
  /// **'You\'ll enter the amount when you pay.'**
  String get billVariableHelp;

  /// No description provided for @billExpectedAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Expected amount'**
  String get billExpectedAmountLabel;

  /// No description provided for @billPaymentAccountLabel.
  ///
  /// In en, this message translates to:
  /// **'Paid from'**
  String get billPaymentAccountLabel;

  /// No description provided for @billPaymentAccountHelp.
  ///
  /// In en, this message translates to:
  /// **'Used when you record a payment.'**
  String get billPaymentAccountHelp;

  /// No description provided for @billNoPaymentAccount.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get billNoPaymentAccount;

  /// No description provided for @billScheduleSection.
  ///
  /// In en, this message translates to:
  /// **'When it\'s due'**
  String get billScheduleSection;

  /// No description provided for @billCreateButton.
  ///
  /// In en, this message translates to:
  /// **'Add bill'**
  String get billCreateButton;

  /// No description provided for @billCreated.
  ///
  /// In en, this message translates to:
  /// **'Bill added.'**
  String get billCreated;

  /// No description provided for @billSaved.
  ///
  /// In en, this message translates to:
  /// **'Bill saved.'**
  String get billSaved;

  /// No description provided for @billDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Bill'**
  String get billDetailTitle;

  /// No description provided for @billDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get billDetailsTitle;

  /// No description provided for @billHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get billHistoryTitle;

  /// No description provided for @billNoHistory.
  ///
  /// In en, this message translates to:
  /// **'No payments yet.'**
  String get billNoHistory;

  /// No description provided for @billMarkPaid.
  ///
  /// In en, this message translates to:
  /// **'Mark as paid'**
  String get billMarkPaid;

  /// No description provided for @billSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip this one'**
  String get billSkip;

  /// No description provided for @billSkipThis.
  ///
  /// In en, this message translates to:
  /// **'Skip this payment'**
  String get billSkipThis;

  /// No description provided for @billSkipConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Skip this payment?'**
  String get billSkipConfirmTitle;

  /// No description provided for @billSkipConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'The bill due {date} will be marked as skipped. Nothing is recorded.'**
  String billSkipConfirmBody(String date);

  /// No description provided for @billSkippedDone.
  ///
  /// In en, this message translates to:
  /// **'Skipped.'**
  String get billSkippedDone;

  /// No description provided for @billPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get billPause;

  /// No description provided for @billResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get billResume;

  /// No description provided for @billArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get billArchive;

  /// No description provided for @billPausedDone.
  ///
  /// In en, this message translates to:
  /// **'Bill paused.'**
  String get billPausedDone;

  /// No description provided for @billResumedDone.
  ///
  /// In en, this message translates to:
  /// **'Bill resumed.'**
  String get billResumedDone;

  /// No description provided for @billRestoredDone.
  ///
  /// In en, this message translates to:
  /// **'Bill restored.'**
  String get billRestoredDone;

  /// No description provided for @billArchivedDone.
  ///
  /// In en, this message translates to:
  /// **'Bill archived.'**
  String get billArchivedDone;

  /// No description provided for @billArchiveConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Archive this bill?'**
  String get billArchiveConfirmTitle;

  /// No description provided for @billArchiveConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'{name} stops showing as due. Its payment history is kept, and you can restore it.'**
  String billArchiveConfirmBody(String name);

  /// No description provided for @billPausedNotice.
  ///
  /// In en, this message translates to:
  /// **'Paused. It won\'t show as due until you resume it.'**
  String get billPausedNotice;

  /// No description provided for @billArchivedNotice.
  ///
  /// In en, this message translates to:
  /// **'Archived. Its payment history is kept.'**
  String get billArchivedNotice;

  /// No description provided for @billSharedReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Shared with you · read-only'**
  String get billSharedReadOnly;

  /// No description provided for @billPayTitle.
  ///
  /// In en, this message translates to:
  /// **'Mark as paid'**
  String get billPayTitle;

  /// No description provided for @billNothingToPay.
  ///
  /// In en, this message translates to:
  /// **'Nothing is due on this bill right now.'**
  String get billNothingToPay;

  /// No description provided for @billPayIntro.
  ///
  /// In en, this message translates to:
  /// **'{name}, due {date}'**
  String billPayIntro(String name, String date);

  /// No description provided for @billPayLinkMode.
  ///
  /// In en, this message translates to:
  /// **'Link a payment'**
  String get billPayLinkMode;

  /// No description provided for @billPayRecordMode.
  ///
  /// In en, this message translates to:
  /// **'Record new'**
  String get billPayRecordMode;

  /// No description provided for @billPayLinkHelp.
  ///
  /// In en, this message translates to:
  /// **'Choose the payment you already recorded. Nothing new is added.'**
  String get billPayLinkHelp;

  /// No description provided for @billPayRecordHelp.
  ///
  /// In en, this message translates to:
  /// **'Adds a new expense for this payment.'**
  String get billPayRecordHelp;

  /// No description provided for @billCandidatesError.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t load suggested payments.'**
  String get billCandidatesError;

  /// No description provided for @billNoCandidates.
  ///
  /// In en, this message translates to:
  /// **'No matching payments found. Choose a transaction or record a new payment.'**
  String get billNoCandidates;

  /// No description provided for @billChooseOtherPayment.
  ///
  /// In en, this message translates to:
  /// **'Choose another transaction'**
  String get billChooseOtherPayment;

  /// No description provided for @billChosenPayment.
  ///
  /// In en, this message translates to:
  /// **'Chosen payment'**
  String get billChosenPayment;

  /// No description provided for @billChoosePayment.
  ///
  /// In en, this message translates to:
  /// **'Choose the payment to link.'**
  String get billChoosePayment;

  /// No description provided for @billPaidAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount paid'**
  String get billPaidAmountLabel;

  /// No description provided for @billPaidAmountHelp.
  ///
  /// In en, this message translates to:
  /// **'Change it if you paid a different amount.'**
  String get billPaidAmountHelp;

  /// No description provided for @billPaidFromLabel.
  ///
  /// In en, this message translates to:
  /// **'Paid from'**
  String get billPaidFromLabel;

  /// No description provided for @billPaidOnLabel.
  ///
  /// In en, this message translates to:
  /// **'Paid on'**
  String get billPaidOnLabel;

  /// No description provided for @billAccountRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose the account you paid from.'**
  String get billAccountRequired;

  /// No description provided for @billMarkedPaid.
  ///
  /// In en, this message translates to:
  /// **'Marked as paid.'**
  String get billMarkedPaid;

  /// No description provided for @calendarTitle.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get calendarTitle;

  /// No description provided for @calendarPreviousMonth.
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get calendarPreviousMonth;

  /// No description provided for @calendarNextMonth.
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get calendarNextMonth;

  /// No description provided for @calendarThisMonth.
  ///
  /// In en, this message translates to:
  /// **'Go to this month'**
  String get calendarThisMonth;

  /// No description provided for @calendarEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing planned in {month}'**
  String calendarEmptyTitle(String month);

  /// No description provided for @calendarEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Bills, recurring items, subscription renewals and goal dates show up here.'**
  String get calendarEmptyBody;

  /// No description provided for @calendarMonthCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item this month} other{{count} items this month}}'**
  String calendarMonthCount(int count);

  /// No description provided for @calendarTodayHeading.
  ///
  /// In en, this message translates to:
  /// **'Today · {date}'**
  String calendarTodayHeading(String date);

  /// No description provided for @calendarKindRecurring.
  ///
  /// In en, this message translates to:
  /// **'Recurring'**
  String get calendarKindRecurring;

  /// No description provided for @calendarKindBill.
  ///
  /// In en, this message translates to:
  /// **'Bill'**
  String get calendarKindBill;

  /// No description provided for @calendarKindGroupExpense.
  ///
  /// In en, this message translates to:
  /// **'Group expense'**
  String get calendarKindGroupExpense;

  /// No description provided for @calendarKindRenewal.
  ///
  /// In en, this message translates to:
  /// **'Subscription renewal'**
  String get calendarKindRenewal;

  /// No description provided for @calendarKindTrialEnd.
  ///
  /// In en, this message translates to:
  /// **'Trial ends'**
  String get calendarKindTrialEnd;

  /// No description provided for @calendarKindGoal.
  ///
  /// In en, this message translates to:
  /// **'Goal target date'**
  String get calendarKindGoal;

  /// No description provided for @calendarKindOther.
  ///
  /// In en, this message translates to:
  /// **'Planned'**
  String get calendarKindOther;

  /// No description provided for @calendarStatusProjected.
  ///
  /// In en, this message translates to:
  /// **'Planned'**
  String get calendarStatusProjected;

  /// No description provided for @calendarStatusExpected.
  ///
  /// In en, this message translates to:
  /// **'Expected'**
  String get calendarStatusExpected;

  /// No description provided for @subscriptionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions'**
  String get subscriptionsTitle;

  /// No description provided for @subscriptionListTitle.
  ///
  /// In en, this message translates to:
  /// **'Your subscriptions'**
  String get subscriptionListTitle;

  /// No description provided for @subscriptionAdd.
  ///
  /// In en, this message translates to:
  /// **'Add subscription'**
  String get subscriptionAdd;

  /// No description provided for @subscriptionNewTitle.
  ///
  /// In en, this message translates to:
  /// **'Add subscription'**
  String get subscriptionNewTitle;

  /// No description provided for @subscriptionEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit subscription'**
  String get subscriptionEditTitle;

  /// No description provided for @subscriptionDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get subscriptionDetailTitle;

  /// No description provided for @subscriptionEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No subscriptions yet'**
  String get subscriptionEmptyTitle;

  /// No description provided for @subscriptionEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add the services you pay for regularly to see what they cost each month.'**
  String get subscriptionEmptyBody;

  /// No description provided for @subscriptionEmptyFiltered.
  ///
  /// In en, this message translates to:
  /// **'No subscriptions with this status.'**
  String get subscriptionEmptyFiltered;

  /// No description provided for @subscriptionSummaryError.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t load the overview.'**
  String get subscriptionSummaryError;

  /// No description provided for @subscriptionStatusTrial.
  ///
  /// In en, this message translates to:
  /// **'Free trial'**
  String get subscriptionStatusTrial;

  /// No description provided for @subscriptionStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get subscriptionStatusActive;

  /// No description provided for @subscriptionStatusPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get subscriptionStatusPaused;

  /// No description provided for @subscriptionStatusCancelling.
  ///
  /// In en, this message translates to:
  /// **'Being cancelled'**
  String get subscriptionStatusCancelling;

  /// No description provided for @subscriptionStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get subscriptionStatusCancelled;

  /// No description provided for @subscriptionStatusUnknown.
  ///
  /// In en, this message translates to:
  /// **'Other status'**
  String get subscriptionStatusUnknown;

  /// No description provided for @subscriptionFilterCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get subscriptionFilterCurrent;

  /// No description provided for @subscriptionFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get subscriptionFilterAll;

  /// No description provided for @subscriptionTotalsTitle.
  ///
  /// In en, this message translates to:
  /// **'What they cost'**
  String get subscriptionTotalsTitle;

  /// No description provided for @subscriptionTotalCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 subscription} other{{count} subscriptions}} in {currency}'**
  String subscriptionTotalCount(int count, String currency);

  /// No description provided for @subscriptionMonthlyCost.
  ///
  /// In en, this message translates to:
  /// **'Per month'**
  String get subscriptionMonthlyCost;

  /// No description provided for @subscriptionAnnualCost.
  ///
  /// In en, this message translates to:
  /// **'Per year'**
  String get subscriptionAnnualCost;

  /// No description provided for @subscriptionTotalsNote.
  ///
  /// In en, this message translates to:
  /// **'Includes free trials, active subscriptions and ones being cancelled. Each currency is added up separately.'**
  String get subscriptionTotalsNote;

  /// No description provided for @subscriptionTrialsTitle.
  ///
  /// In en, this message translates to:
  /// **'Free trials ending soon'**
  String get subscriptionTrialsTitle;

  /// No description provided for @subscriptionRenewalsTitle.
  ///
  /// In en, this message translates to:
  /// **'Renewing in the next 30 days'**
  String get subscriptionRenewalsTitle;

  /// No description provided for @subscriptionDetectionsPending.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 possible subscription to review} other{{count} possible subscriptions to review}}'**
  String subscriptionDetectionsPending(int count);

  /// No description provided for @subscriptionDetectionsReview.
  ///
  /// In en, this message translates to:
  /// **'Found in your transactions. Nothing is added until you confirm.'**
  String get subscriptionDetectionsReview;

  /// No description provided for @subscriptionTrialEnds.
  ///
  /// In en, this message translates to:
  /// **'Trial ends {date}'**
  String subscriptionTrialEnds(String date);

  /// No description provided for @subscriptionRenews.
  ///
  /// In en, this message translates to:
  /// **'Renews {date}'**
  String subscriptionRenews(String date);

  /// No description provided for @subscriptionNextCharge.
  ///
  /// In en, this message translates to:
  /// **'Next charge {date}'**
  String subscriptionNextCharge(String date);

  /// No description provided for @subscriptionSharedLabel.
  ///
  /// In en, this message translates to:
  /// **'Shared with you'**
  String get subscriptionSharedLabel;

  /// No description provided for @subscriptionNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get subscriptionNameLabel;

  /// No description provided for @subscriptionNameHelp.
  ///
  /// In en, this message translates to:
  /// **'For example, the service you pay for.'**
  String get subscriptionNameHelp;

  /// No description provided for @subscriptionPlanLabel.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get subscriptionPlanLabel;

  /// No description provided for @subscriptionPriceSection.
  ///
  /// In en, this message translates to:
  /// **'Price and billing'**
  String get subscriptionPriceSection;

  /// No description provided for @subscriptionAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Price per billing cycle'**
  String get subscriptionAmountLabel;

  /// No description provided for @subscriptionFrequencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Billing cycle'**
  String get subscriptionFrequencyLabel;

  /// No description provided for @subscriptionFrequencyRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose a billing cycle.'**
  String get subscriptionFrequencyRequired;

  /// No description provided for @subscriptionIntervalCountLabel.
  ///
  /// In en, this message translates to:
  /// **'Repeats every'**
  String get subscriptionIntervalCountLabel;

  /// No description provided for @subscriptionIntervalUnitLabel.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get subscriptionIntervalUnitLabel;

  /// No description provided for @subscriptionIntervalInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a whole number from 1 to 366.'**
  String get subscriptionIntervalInvalid;

  /// No description provided for @subscriptionDatesSection.
  ///
  /// In en, this message translates to:
  /// **'Dates'**
  String get subscriptionDatesSection;

  /// No description provided for @subscriptionStartLabel.
  ///
  /// In en, this message translates to:
  /// **'Started on'**
  String get subscriptionStartLabel;

  /// No description provided for @subscriptionTrialLabel.
  ///
  /// In en, this message translates to:
  /// **'Free trial ends'**
  String get subscriptionTrialLabel;

  /// No description provided for @subscriptionNoTrial.
  ///
  /// In en, this message translates to:
  /// **'No free trial'**
  String get subscriptionNoTrial;

  /// No description provided for @subscriptionNextRenewalLabel.
  ///
  /// In en, this message translates to:
  /// **'Next renewal'**
  String get subscriptionNextRenewalLabel;

  /// No description provided for @subscriptionNextRenewalAuto.
  ///
  /// In en, this message translates to:
  /// **'Work it out for me'**
  String get subscriptionNextRenewalAuto;

  /// No description provided for @subscriptionNextRenewalHelp.
  ///
  /// In en, this message translates to:
  /// **'Leave it empty and Montra works it out from the start date.'**
  String get subscriptionNextRenewalHelp;

  /// No description provided for @subscriptionPaymentSection.
  ///
  /// In en, this message translates to:
  /// **'Payment and sharing'**
  String get subscriptionPaymentSection;

  /// No description provided for @subscriptionPaymentAccountLabel.
  ///
  /// In en, this message translates to:
  /// **'Paid from'**
  String get subscriptionPaymentAccountLabel;

  /// No description provided for @subscriptionPaymentAccountNone.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get subscriptionPaymentAccountNone;

  /// No description provided for @subscriptionCategoryUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Category not available'**
  String get subscriptionCategoryUnavailable;

  /// No description provided for @subscriptionGroupLabel.
  ///
  /// In en, this message translates to:
  /// **'Shared with a group'**
  String get subscriptionGroupLabel;

  /// No description provided for @subscriptionGroupHelp.
  ///
  /// In en, this message translates to:
  /// **'Track it as shared with a group you belong to.'**
  String get subscriptionGroupHelp;

  /// No description provided for @subscriptionGroupUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Group not available'**
  String get subscriptionGroupUnavailable;

  /// No description provided for @subscriptionRemindersSection.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get subscriptionRemindersSection;

  /// No description provided for @subscriptionRemindersLabel.
  ///
  /// In en, this message translates to:
  /// **'Remind me before it renews'**
  String get subscriptionRemindersLabel;

  /// No description provided for @subscriptionRemindersHelp.
  ///
  /// In en, this message translates to:
  /// **'During a free trial, Montra also reminds you before the trial ends.'**
  String get subscriptionRemindersHelp;

  /// No description provided for @subscriptionCancellationSection.
  ///
  /// In en, this message translates to:
  /// **'Cancelling'**
  String get subscriptionCancellationSection;

  /// No description provided for @subscriptionCancellationUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Cancellation page'**
  String get subscriptionCancellationUrlLabel;

  /// No description provided for @subscriptionCancellationUrlHelp.
  ///
  /// In en, this message translates to:
  /// **'The provider\'s official page, starting with https://'**
  String get subscriptionCancellationUrlHelp;

  /// No description provided for @subscriptionCancellationUrlInvalid.
  ///
  /// In en, this message translates to:
  /// **'Use the provider\'s official https:// page.'**
  String get subscriptionCancellationUrlInvalid;

  /// No description provided for @subscriptionCancellationHowLabel.
  ///
  /// In en, this message translates to:
  /// **'How to cancel'**
  String get subscriptionCancellationHowLabel;

  /// No description provided for @subscriptionChecklistTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancellation checklist'**
  String get subscriptionChecklistTitle;

  /// No description provided for @subscriptionChecklistHelp.
  ///
  /// In en, this message translates to:
  /// **'Steps to finish before or while you cancel, such as downloading your data.'**
  String get subscriptionChecklistHelp;

  /// No description provided for @subscriptionChecklistAdd.
  ///
  /// In en, this message translates to:
  /// **'Add a step'**
  String get subscriptionChecklistAdd;

  /// No description provided for @subscriptionChecklistAddButton.
  ///
  /// In en, this message translates to:
  /// **'Add this step'**
  String get subscriptionChecklistAddButton;

  /// No description provided for @subscriptionChecklistRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove step: {item}'**
  String subscriptionChecklistRemove(String item);

  /// No description provided for @subscriptionChecklistFull.
  ///
  /// In en, this message translates to:
  /// **'You can add up to {max} steps.'**
  String subscriptionChecklistFull(int max);

  /// No description provided for @subscriptionChecklistEmpty.
  ///
  /// In en, this message translates to:
  /// **'Add steps to the checklist by editing this subscription.'**
  String get subscriptionChecklistEmpty;

  /// No description provided for @subscriptionCreated.
  ///
  /// In en, this message translates to:
  /// **'Subscription added.'**
  String get subscriptionCreated;

  /// No description provided for @subscriptionSaved.
  ///
  /// In en, this message translates to:
  /// **'Subscription saved.'**
  String get subscriptionSaved;

  /// No description provided for @subscriptionPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get subscriptionPriceLabel;

  /// No description provided for @subscriptionSourceLabel.
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get subscriptionSourceLabel;

  /// No description provided for @subscriptionSourceDetected.
  ///
  /// In en, this message translates to:
  /// **'Found in your transactions'**
  String get subscriptionSourceDetected;

  /// No description provided for @subscriptionSourceManual.
  ///
  /// In en, this message translates to:
  /// **'Added by you'**
  String get subscriptionSourceManual;

  /// No description provided for @subscriptionDuplicateTitle.
  ///
  /// In en, this message translates to:
  /// **'This may be a duplicate'**
  String get subscriptionDuplicateTitle;

  /// No description provided for @subscriptionDuplicateBody.
  ///
  /// In en, this message translates to:
  /// **'It looks like {name}: {reason}.'**
  String subscriptionDuplicateBody(String name, String reason);

  /// No description provided for @subscriptionDuplicateSameMerchant.
  ///
  /// In en, this message translates to:
  /// **'same merchant'**
  String get subscriptionDuplicateSameMerchant;

  /// No description provided for @subscriptionDuplicateSameName.
  ///
  /// In en, this message translates to:
  /// **'same name'**
  String get subscriptionDuplicateSameName;

  /// No description provided for @subscriptionDuplicateSamePrice.
  ///
  /// In en, this message translates to:
  /// **'same price and billing cycle'**
  String get subscriptionDuplicateSamePrice;

  /// No description provided for @subscriptionDuplicateOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get subscriptionDuplicateOpen;

  /// No description provided for @subscriptionDuplicateOpenLabel.
  ///
  /// In en, this message translates to:
  /// **'Open {name}'**
  String subscriptionDuplicateOpenLabel(String name);

  /// No description provided for @subscriptionSharedNotice.
  ///
  /// In en, this message translates to:
  /// **'This subscription is shared with you through a group. Only its owner can change it.'**
  String get subscriptionSharedNotice;

  /// No description provided for @subscriptionCostTitle.
  ///
  /// In en, this message translates to:
  /// **'What it costs'**
  String get subscriptionCostTitle;

  /// No description provided for @subscriptionCostNote.
  ///
  /// In en, this message translates to:
  /// **'Worked out by Montra from the price and billing cycle.'**
  String get subscriptionCostNote;

  /// No description provided for @subscriptionPaymentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get subscriptionPaymentsTitle;

  /// No description provided for @subscriptionNoPayments.
  ///
  /// In en, this message translates to:
  /// **'No payments linked yet.'**
  String get subscriptionNoPayments;

  /// No description provided for @subscriptionLastPayment.
  ///
  /// In en, this message translates to:
  /// **'Last payment'**
  String get subscriptionLastPayment;

  /// No description provided for @subscriptionPaidAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount paid'**
  String get subscriptionPaidAmount;

  /// No description provided for @subscriptionViewTransaction.
  ///
  /// In en, this message translates to:
  /// **'View transaction'**
  String get subscriptionViewTransaction;

  /// No description provided for @subscriptionRecordPayment.
  ///
  /// In en, this message translates to:
  /// **'Record a payment'**
  String get subscriptionRecordPayment;

  /// No description provided for @subscriptionPaymentPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Which charge was this payment?'**
  String get subscriptionPaymentPickerTitle;

  /// No description provided for @subscriptionPaymentCurrencyMismatch.
  ///
  /// In en, this message translates to:
  /// **'Choose a charge in {currency}, the subscription\'s currency.'**
  String subscriptionPaymentCurrencyMismatch(String currency);

  /// No description provided for @subscriptionRecordPaymentTitle.
  ///
  /// In en, this message translates to:
  /// **'Record this payment?'**
  String get subscriptionRecordPaymentTitle;

  /// No description provided for @subscriptionRecordPaymentBody.
  ///
  /// In en, this message translates to:
  /// **'{title} on {date} for {amount} will be linked to this subscription. The transaction itself won\'t change.'**
  String subscriptionRecordPaymentBody(
    String title,
    String date,
    String amount,
  );

  /// No description provided for @subscriptionPriceDiffers.
  ///
  /// In en, this message translates to:
  /// **'This is different from the current price of {price}.'**
  String subscriptionPriceDiffers(String price);

  /// No description provided for @subscriptionUpdatePrice.
  ///
  /// In en, this message translates to:
  /// **'Change the price to {amount}'**
  String subscriptionUpdatePrice(String amount);

  /// No description provided for @subscriptionRecordPaymentConfirm.
  ///
  /// In en, this message translates to:
  /// **'Record payment'**
  String get subscriptionRecordPaymentConfirm;

  /// No description provided for @subscriptionPaymentRecorded.
  ///
  /// In en, this message translates to:
  /// **'Payment recorded.'**
  String get subscriptionPaymentRecorded;

  /// No description provided for @subscriptionPaymentDuplicate.
  ///
  /// In en, this message translates to:
  /// **'This payment is already linked to a subscription.'**
  String get subscriptionPaymentDuplicate;

  /// No description provided for @subscriptionActionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'That isn\'t possible in the subscription\'s current status. We\'ve loaded the latest details.'**
  String get subscriptionActionUnavailable;

  /// No description provided for @subscriptionCancellingNotice.
  ///
  /// In en, this message translates to:
  /// **'You\'ve started cancelling. Once the provider confirms, mark it as cancelled.'**
  String get subscriptionCancellingNotice;

  /// No description provided for @subscriptionOpenPage.
  ///
  /// In en, this message translates to:
  /// **'Open page'**
  String get subscriptionOpenPage;

  /// No description provided for @subscriptionCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get subscriptionCopyLink;

  /// No description provided for @subscriptionOpenPageFailed.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t open the page. You can copy the link instead.'**
  String get subscriptionOpenPageFailed;

  /// No description provided for @subscriptionLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied.'**
  String get subscriptionLinkCopied;

  /// No description provided for @subscriptionCancelledOn.
  ///
  /// In en, this message translates to:
  /// **'Cancelled on'**
  String get subscriptionCancelledOn;

  /// No description provided for @subscriptionLastChecked.
  ///
  /// In en, this message translates to:
  /// **'Last checked'**
  String get subscriptionLastChecked;

  /// No description provided for @subscriptionNeverChecked.
  ///
  /// In en, this message translates to:
  /// **'Not yet'**
  String get subscriptionNeverChecked;

  /// No description provided for @subscriptionDetailsSection.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get subscriptionDetailsSection;

  /// No description provided for @subscriptionHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get subscriptionHistoryTitle;

  /// No description provided for @subscriptionHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No history yet.'**
  String get subscriptionHistoryEmpty;

  /// No description provided for @subscriptionHistoryShowAll.
  ///
  /// In en, this message translates to:
  /// **'Show all {count} entries'**
  String subscriptionHistoryShowAll(int count);

  /// No description provided for @subscriptionPriceHistorySummary.
  ///
  /// In en, this message translates to:
  /// **'The price went from {firstPrice} on {firstDate} to {lastPrice} on {lastDate}.'**
  String subscriptionPriceHistorySummary(
    String firstPrice,
    String firstDate,
    String lastPrice,
    String lastDate,
  );

  /// No description provided for @subscriptionPriceChange.
  ///
  /// In en, this message translates to:
  /// **'{from} to {to}'**
  String subscriptionPriceChange(String from, String to);

  /// No description provided for @subscriptionEventCreated.
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get subscriptionEventCreated;

  /// No description provided for @subscriptionEventEdited.
  ///
  /// In en, this message translates to:
  /// **'Details changed'**
  String get subscriptionEventEdited;

  /// No description provided for @subscriptionEventPriceChanged.
  ///
  /// In en, this message translates to:
  /// **'Price changed'**
  String get subscriptionEventPriceChanged;

  /// No description provided for @subscriptionEventPayment.
  ///
  /// In en, this message translates to:
  /// **'Payment recorded'**
  String get subscriptionEventPayment;

  /// No description provided for @subscriptionEventTrialStarted.
  ///
  /// In en, this message translates to:
  /// **'Free trial started'**
  String get subscriptionEventTrialStarted;

  /// No description provided for @subscriptionEventTrialEnding.
  ///
  /// In en, this message translates to:
  /// **'Free trial ending soon'**
  String get subscriptionEventTrialEnding;

  /// No description provided for @subscriptionEventPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get subscriptionEventPaused;

  /// No description provided for @subscriptionEventResumed.
  ///
  /// In en, this message translates to:
  /// **'Resumed'**
  String get subscriptionEventResumed;

  /// No description provided for @subscriptionEventCancellationStarted.
  ///
  /// In en, this message translates to:
  /// **'Cancellation started'**
  String get subscriptionEventCancellationStarted;

  /// No description provided for @subscriptionEventCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get subscriptionEventCancelled;

  /// No description provided for @subscriptionEventReactivated.
  ///
  /// In en, this message translates to:
  /// **'Reactivated'**
  String get subscriptionEventReactivated;

  /// No description provided for @subscriptionEventVerified.
  ///
  /// In en, this message translates to:
  /// **'Checked'**
  String get subscriptionEventVerified;

  /// No description provided for @subscriptionEventOther.
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get subscriptionEventOther;

  /// No description provided for @subscriptionActionVerify.
  ///
  /// In en, this message translates to:
  /// **'Mark as checked'**
  String get subscriptionActionVerify;

  /// No description provided for @subscriptionActionPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get subscriptionActionPause;

  /// No description provided for @subscriptionActionResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get subscriptionActionResume;

  /// No description provided for @subscriptionActionCancellationStarted.
  ///
  /// In en, this message translates to:
  /// **'I\'ve started cancelling'**
  String get subscriptionActionCancellationStarted;

  /// No description provided for @subscriptionActionCancelled.
  ///
  /// In en, this message translates to:
  /// **'Mark as cancelled'**
  String get subscriptionActionCancelled;

  /// No description provided for @subscriptionActionReactivate.
  ///
  /// In en, this message translates to:
  /// **'Reactivate'**
  String get subscriptionActionReactivate;

  /// No description provided for @subscriptionVerifiedDone.
  ///
  /// In en, this message translates to:
  /// **'Marked as checked today.'**
  String get subscriptionVerifiedDone;

  /// No description provided for @subscriptionPausedDone.
  ///
  /// In en, this message translates to:
  /// **'Subscription paused.'**
  String get subscriptionPausedDone;

  /// No description provided for @subscriptionResumedDone.
  ///
  /// In en, this message translates to:
  /// **'Subscription resumed.'**
  String get subscriptionResumedDone;

  /// No description provided for @subscriptionCancellationStartedDone.
  ///
  /// In en, this message translates to:
  /// **'Noted. Use the checklist while you cancel.'**
  String get subscriptionCancellationStartedDone;

  /// No description provided for @subscriptionCancelledDone.
  ///
  /// In en, this message translates to:
  /// **'Marked as cancelled.'**
  String get subscriptionCancelledDone;

  /// No description provided for @subscriptionReactivatedDone.
  ///
  /// In en, this message translates to:
  /// **'Subscription reactivated.'**
  String get subscriptionReactivatedDone;

  /// No description provided for @subscriptionCancelledConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Has it been cancelled?'**
  String get subscriptionCancelledConfirmTitle;

  /// No description provided for @subscriptionCancelledConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Mark {name} as cancelled only after the provider has confirmed it. Montra doesn\'t cancel subscriptions for you.'**
  String subscriptionCancelledConfirmBody(String name);

  /// No description provided for @subscriptionCancelledConfirm.
  ///
  /// In en, this message translates to:
  /// **'Yes, it\'s cancelled'**
  String get subscriptionCancelledConfirm;

  /// No description provided for @detectionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Possible subscriptions'**
  String get detectionsTitle;

  /// No description provided for @detectionsHint.
  ///
  /// In en, this message translates to:
  /// **'Look for regular charges in your transactions.'**
  String get detectionsHint;

  /// No description provided for @detectionsIntro.
  ///
  /// In en, this message translates to:
  /// **'Montra looks for charges that repeat at a regular interval with a similar amount. Nothing is added until you confirm it.'**
  String get detectionsIntro;

  /// No description provided for @detectionsRefresh.
  ///
  /// In en, this message translates to:
  /// **'Look again'**
  String get detectionsRefresh;

  /// No description provided for @detectionsRefreshStarted.
  ///
  /// In en, this message translates to:
  /// **'Looking for regular charges. This runs in the background, so check back in a few minutes.'**
  String get detectionsRefreshStarted;

  /// No description provided for @detectionsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing to review'**
  String get detectionsEmptyTitle;

  /// No description provided for @detectionsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'When charges repeat regularly, they show up here for you to review.'**
  String get detectionsEmptyBody;

  /// No description provided for @detectionTypicalAmount.
  ///
  /// In en, this message translates to:
  /// **'Usual amount'**
  String get detectionTypicalAmount;

  /// No description provided for @detectionTolerance.
  ///
  /// In en, this message translates to:
  /// **'Amounts vary by up to {amount}.'**
  String detectionTolerance(String amount);

  /// No description provided for @detectionStrong.
  ///
  /// In en, this message translates to:
  /// **'Strong match ({percent}%)'**
  String detectionStrong(int percent);

  /// No description provided for @detectionLikely.
  ///
  /// In en, this message translates to:
  /// **'Likely match ({percent}%)'**
  String detectionLikely(int percent);

  /// No description provided for @detectionPossible.
  ///
  /// In en, this message translates to:
  /// **'Possible match ({percent}%)'**
  String detectionPossible(int percent);

  /// No description provided for @detectionConfidenceHelp.
  ///
  /// In en, this message translates to:
  /// **'Based on how regular the dates are, how similar the amounts are and how many charges there are.'**
  String get detectionConfidenceHelp;

  /// No description provided for @detectionEvidenceCharges.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 charge} other{{count} charges}}, usually {days, plural, =1{1 day} other{{days} days}} apart'**
  String detectionEvidenceCharges(int count, int days);

  /// No description provided for @detectionEvidenceLast.
  ///
  /// In en, this message translates to:
  /// **'Last charge on {date}'**
  String detectionEvidenceLast(String date);

  /// No description provided for @detectionEvidenceNext.
  ///
  /// In en, this message translates to:
  /// **'Next charge expected around {date}'**
  String detectionEvidenceNext(String date);

  /// No description provided for @detectionConfirm.
  ///
  /// In en, this message translates to:
  /// **'Add as subscription'**
  String get detectionConfirm;

  /// No description provided for @detectionConfirmLabel.
  ///
  /// In en, this message translates to:
  /// **'Add {name} as a subscription'**
  String detectionConfirmLabel(String name);

  /// No description provided for @detectionDismiss.
  ///
  /// In en, this message translates to:
  /// **'Not a subscription'**
  String get detectionDismiss;

  /// No description provided for @detectionDismissLabel.
  ///
  /// In en, this message translates to:
  /// **'{name} is not a subscription'**
  String detectionDismissLabel(String name);

  /// No description provided for @detectionDismissTitle.
  ///
  /// In en, this message translates to:
  /// **'Not a subscription?'**
  String get detectionDismissTitle;

  /// No description provided for @detectionDismissBody.
  ///
  /// In en, this message translates to:
  /// **'{name} will be removed from this list. Your transactions stay as they are.'**
  String detectionDismissBody(String name);

  /// No description provided for @detectionDismissed.
  ///
  /// In en, this message translates to:
  /// **'Removed from the list.'**
  String get detectionDismissed;

  /// No description provided for @detectionSeeCharges.
  ///
  /// In en, this message translates to:
  /// **'See charges'**
  String get detectionSeeCharges;

  /// No description provided for @detectionSeeChargesLabel.
  ///
  /// In en, this message translates to:
  /// **'See charges from {name}'**
  String detectionSeeChargesLabel(String name);

  /// No description provided for @detectionConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Add as a subscription'**
  String get detectionConfirmTitle;

  /// No description provided for @detectionConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Check the details. Anything you leave as it is uses what we found.'**
  String get detectionConfirmBody;

  /// No description provided for @detectionAccountDefault.
  ///
  /// In en, this message translates to:
  /// **'Account of the latest charge'**
  String get detectionAccountDefault;

  /// No description provided for @detectionConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Subscription added.'**
  String get detectionConfirmed;

  /// No description provided for @subscriptionListError.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t load your subscriptions.'**
  String get subscriptionListError;

  /// No description provided for @goalsTitle.
  ///
  /// In en, this message translates to:
  /// **'Goals'**
  String get goalsTitle;

  /// No description provided for @goalNew.
  ///
  /// In en, this message translates to:
  /// **'New goal'**
  String get goalNew;

  /// No description provided for @goalAddFirst.
  ///
  /// In en, this message translates to:
  /// **'Add a goal'**
  String get goalAddFirst;

  /// No description provided for @goalsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No goals yet'**
  String get goalsEmptyTitle;

  /// No description provided for @goalsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Save towards something that matters to you, like an emergency fund, a trip or a new phone. Add a goal and go at your own pace.'**
  String get goalsEmptyBody;

  /// No description provided for @goalsNoMatchTitle.
  ///
  /// In en, this message translates to:
  /// **'No goals here'**
  String get goalsNoMatchTitle;

  /// No description provided for @goalsNoMatchBody.
  ///
  /// In en, this message translates to:
  /// **'Try another filter.'**
  String get goalsNoMatchBody;

  /// No description provided for @goalFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Show goals'**
  String get goalFilterLabel;

  /// No description provided for @goalFilterCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get goalFilterCurrent;

  /// No description provided for @goalFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All, including archived'**
  String get goalFilterAll;

  /// No description provided for @goalStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get goalStatusActive;

  /// No description provided for @goalStatusPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get goalStatusPaused;

  /// No description provided for @goalStatusAchieved.
  ///
  /// In en, this message translates to:
  /// **'Achieved'**
  String get goalStatusAchieved;

  /// No description provided for @goalStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Ended'**
  String get goalStatusCancelled;

  /// No description provided for @goalStatusArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get goalStatusArchived;

  /// No description provided for @goalStatusUnknown.
  ///
  /// In en, this message translates to:
  /// **'Other status'**
  String get goalStatusUnknown;

  /// No description provided for @goalProgressSummary.
  ///
  /// In en, this message translates to:
  /// **'{percent} saved · {saved} of {target}'**
  String goalProgressSummary(String percent, String saved, String target);

  /// No description provided for @goalTargetDateShort.
  ///
  /// In en, this message translates to:
  /// **'By {date}'**
  String goalTargetDateShort(String date);

  /// No description provided for @goalSharedWithYou.
  ///
  /// In en, this message translates to:
  /// **'Shared with you'**
  String get goalSharedWithYou;

  /// No description provided for @goalSharedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Shared with 1 person} other{Shared with {count} people}}'**
  String goalSharedCount(int count);

  /// No description provided for @goalTypeEmergencyFund.
  ///
  /// In en, this message translates to:
  /// **'Emergency fund'**
  String get goalTypeEmergencyFund;

  /// No description provided for @goalTypeTravel.
  ///
  /// In en, this message translates to:
  /// **'Travel'**
  String get goalTypeTravel;

  /// No description provided for @goalTypeEducation.
  ///
  /// In en, this message translates to:
  /// **'Education'**
  String get goalTypeEducation;

  /// No description provided for @goalTypeDevice.
  ///
  /// In en, this message translates to:
  /// **'Phone or gadget'**
  String get goalTypeDevice;

  /// No description provided for @goalTypeVehicle.
  ///
  /// In en, this message translates to:
  /// **'Vehicle'**
  String get goalTypeVehicle;

  /// No description provided for @goalTypeHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get goalTypeHome;

  /// No description provided for @goalTypeEvent.
  ///
  /// In en, this message translates to:
  /// **'Event or celebration'**
  String get goalTypeEvent;

  /// No description provided for @goalTypeDebtPayoff.
  ///
  /// In en, this message translates to:
  /// **'Paying off a loan'**
  String get goalTypeDebtPayoff;

  /// No description provided for @goalTypeLargePurchase.
  ///
  /// In en, this message translates to:
  /// **'Big purchase'**
  String get goalTypeLargePurchase;

  /// No description provided for @goalTypeCustom.
  ///
  /// In en, this message translates to:
  /// **'Something else'**
  String get goalTypeCustom;

  /// No description provided for @goalDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Goal'**
  String get goalDetailTitle;

  /// No description provided for @goalPercentSaved.
  ///
  /// In en, this message translates to:
  /// **'{percent} saved'**
  String goalPercentSaved(String percent);

  /// No description provided for @goalSavedOfTarget.
  ///
  /// In en, this message translates to:
  /// **'{saved} of {target}'**
  String goalSavedOfTarget(String saved, String target);

  /// No description provided for @goalSavedLabel.
  ///
  /// In en, this message translates to:
  /// **'Saved so far'**
  String get goalSavedLabel;

  /// No description provided for @goalTargetLabel.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get goalTargetLabel;

  /// No description provided for @goalRemainingLabel.
  ///
  /// In en, this message translates to:
  /// **'Still to go'**
  String get goalRemainingLabel;

  /// No description provided for @goalVerifiedLabel.
  ///
  /// In en, this message translates to:
  /// **'Backed by transactions'**
  String get goalVerifiedLabel;

  /// No description provided for @goalPlannedLabel.
  ///
  /// In en, this message translates to:
  /// **'Planned, not counted yet'**
  String get goalPlannedLabel;

  /// No description provided for @goalStartingLabel.
  ///
  /// In en, this message translates to:
  /// **'Saved before tracking'**
  String get goalStartingLabel;

  /// No description provided for @goalContributionCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No contributions yet} =1{1 contribution} other{{count} contributions}}'**
  String goalContributionCount(int count);

  /// No description provided for @goalPausedNotice.
  ///
  /// In en, this message translates to:
  /// **'This goal is paused. Resume it to add contributions.'**
  String get goalPausedNotice;

  /// No description provided for @goalAchievedNotice.
  ///
  /// In en, this message translates to:
  /// **'You reached this goal on {date}.'**
  String goalAchievedNotice(String date);

  /// No description provided for @goalAchievedNoticeNoDate.
  ///
  /// In en, this message translates to:
  /// **'You reached this goal.'**
  String get goalAchievedNoticeNoDate;

  /// No description provided for @goalCancelledNotice.
  ///
  /// In en, this message translates to:
  /// **'This goal has ended. Its history is kept.'**
  String get goalCancelledNotice;

  /// No description provided for @goalArchivedNotice.
  ///
  /// In en, this message translates to:
  /// **'This goal is archived. Its history is kept.'**
  String get goalArchivedNotice;

  /// No description provided for @goalViewerNotice.
  ///
  /// In en, this message translates to:
  /// **'You can see this goal but not add to it.'**
  String get goalViewerNotice;

  /// No description provided for @goalAddContribution.
  ///
  /// In en, this message translates to:
  /// **'Add contribution'**
  String get goalAddContribution;

  /// No description provided for @goalExport.
  ///
  /// In en, this message translates to:
  /// **'Export as CSV'**
  String get goalExport;

  /// No description provided for @goalPause.
  ///
  /// In en, this message translates to:
  /// **'Pause goal'**
  String get goalPause;

  /// No description provided for @goalResume.
  ///
  /// In en, this message translates to:
  /// **'Resume goal'**
  String get goalResume;

  /// No description provided for @goalMarkAchieved.
  ///
  /// In en, this message translates to:
  /// **'Mark as achieved'**
  String get goalMarkAchieved;

  /// No description provided for @goalCancel.
  ///
  /// In en, this message translates to:
  /// **'End goal'**
  String get goalCancel;

  /// No description provided for @goalArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive goal'**
  String get goalArchive;

  /// No description provided for @goalLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave goal'**
  String get goalLeave;

  /// No description provided for @goalPausedDone.
  ///
  /// In en, this message translates to:
  /// **'Goal paused.'**
  String get goalPausedDone;

  /// No description provided for @goalResumedDone.
  ///
  /// In en, this message translates to:
  /// **'Goal resumed.'**
  String get goalResumedDone;

  /// No description provided for @goalAchievedDone.
  ///
  /// In en, this message translates to:
  /// **'Goal marked as achieved.'**
  String get goalAchievedDone;

  /// No description provided for @goalCancelledDone.
  ///
  /// In en, this message translates to:
  /// **'Goal ended.'**
  String get goalCancelledDone;

  /// No description provided for @goalArchivedDone.
  ///
  /// In en, this message translates to:
  /// **'Goal archived.'**
  String get goalArchivedDone;

  /// No description provided for @goalLeftDone.
  ///
  /// In en, this message translates to:
  /// **'You left the goal.'**
  String get goalLeftDone;

  /// No description provided for @goalAchieveConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Mark this goal as achieved?'**
  String get goalAchieveConfirmTitle;

  /// No description provided for @goalAchieveConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'{name} will be marked as achieved. You can\'t add contributions to it after that.'**
  String goalAchieveConfirmBody(String name);

  /// No description provided for @goalCancelConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'End this goal?'**
  String get goalCancelConfirmTitle;

  /// No description provided for @goalCancelConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'{name} will be closed and its contributions kept in the history. You can start a new goal any time.'**
  String goalCancelConfirmBody(String name);

  /// No description provided for @goalArchiveConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Archive this goal?'**
  String get goalArchiveConfirmTitle;

  /// No description provided for @goalArchiveConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'{name} moves to the archive with its history. Archived goals can\'t be changed.'**
  String goalArchiveConfirmBody(String name);

  /// No description provided for @goalLeaveConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave this goal?'**
  String get goalLeaveConfirmTitle;

  /// No description provided for @goalLeaveConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'You won\'t see {name} anymore. Your past contributions stay in its history.'**
  String goalLeaveConfirmBody(String name);

  /// No description provided for @goalForecastTitle.
  ///
  /// In en, this message translates to:
  /// **'Outlook'**
  String get goalForecastTitle;

  /// No description provided for @goalForecastAchieved.
  ///
  /// In en, this message translates to:
  /// **'You\'ve reached the target'**
  String get goalForecastAchieved;

  /// No description provided for @goalForecastOnTrack.
  ///
  /// In en, this message translates to:
  /// **'On track'**
  String get goalForecastOnTrack;

  /// No description provided for @goalForecastNeedsMore.
  ///
  /// In en, this message translates to:
  /// **'Needs a little more to finish on time'**
  String get goalForecastNeedsMore;

  /// No description provided for @goalForecastDaysLeft.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =0{due today} =1{1 day left} other{{days} days left}}'**
  String goalForecastDaysLeft(int days);

  /// No description provided for @goalForecastRequired.
  ///
  /// In en, this message translates to:
  /// **'To finish by the target date, set aside about {perMonth} a month ({perWeek} a week).'**
  String goalForecastRequired(String perMonth, String perWeek);

  /// No description provided for @goalForecastRequiredMonthOnly.
  ///
  /// In en, this message translates to:
  /// **'To finish by the target date, set aside about {perMonth} a month.'**
  String goalForecastRequiredMonthOnly(String perMonth);

  /// No description provided for @goalForecastPace.
  ///
  /// In en, this message translates to:
  /// **'Recent pace: {pace} a month (last 90 days).'**
  String goalForecastPace(String pace);

  /// No description provided for @goalForecastProjected.
  ///
  /// In en, this message translates to:
  /// **'At this pace, you\'d reach it around {date}.'**
  String goalForecastProjected(String date);

  /// No description provided for @goalForecastNoPace.
  ///
  /// In en, this message translates to:
  /// **'There\'s no recent progress to estimate a finish date yet.'**
  String get goalForecastNoPace;

  /// No description provided for @goalForecastPlanned.
  ///
  /// In en, this message translates to:
  /// **'With your planned contributions, around {date}.'**
  String goalForecastPlanned(String date);

  /// No description provided for @goalForecastAssumptions.
  ///
  /// In en, this message translates to:
  /// **'How this is worked out'**
  String get goalForecastAssumptions;

  /// No description provided for @milestonesTitle.
  ///
  /// In en, this message translates to:
  /// **'Milestones'**
  String get milestonesTitle;

  /// No description provided for @milestonesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No milestones.'**
  String get milestonesEmpty;

  /// No description provided for @milestonePercent.
  ///
  /// In en, this message translates to:
  /// **'{percent}% of the target'**
  String milestonePercent(int percent);

  /// No description provided for @milestoneReachedOn.
  ///
  /// In en, this message translates to:
  /// **'Reached on {date}'**
  String milestoneReachedOn(String date);

  /// No description provided for @milestoneNotReached.
  ///
  /// In en, this message translates to:
  /// **'Not reached yet'**
  String get milestoneNotReached;

  /// No description provided for @milestonesHelp.
  ///
  /// In en, this message translates to:
  /// **'Up to 10. Each one is marked when you reach it.'**
  String get milestonesHelp;

  /// No description provided for @milestoneAdd.
  ///
  /// In en, this message translates to:
  /// **'Add milestone'**
  String get milestoneAdd;

  /// No description provided for @milestoneRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove milestone'**
  String get milestoneRemove;

  /// No description provided for @milestonePercentLabel.
  ///
  /// In en, this message translates to:
  /// **'Percent of the target'**
  String get milestonePercentLabel;

  /// No description provided for @milestoneNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get milestoneNameLabel;

  /// No description provided for @milestonePercentInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a whole number from 1 to 100.'**
  String get milestonePercentInvalid;

  /// No description provided for @milestoneDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Each milestone needs a different percent.'**
  String get milestoneDuplicate;

  /// No description provided for @contributionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Contributions'**
  String get contributionsTitle;

  /// No description provided for @contributionsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No contributions yet. Add one when you set money aside.'**
  String get contributionsEmpty;

  /// No description provided for @contributionKindContribution.
  ///
  /// In en, this message translates to:
  /// **'Contribution'**
  String get contributionKindContribution;

  /// No description provided for @contributionKindWithdrawal.
  ///
  /// In en, this message translates to:
  /// **'Withdrawal'**
  String get contributionKindWithdrawal;

  /// No description provided for @contributionStatusPlanned.
  ///
  /// In en, this message translates to:
  /// **'Planned'**
  String get contributionStatusPlanned;

  /// No description provided for @contributionStatusRecorded.
  ///
  /// In en, this message translates to:
  /// **'Recorded'**
  String get contributionStatusRecorded;

  /// No description provided for @contributionStatusVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get contributionStatusVerified;

  /// No description provided for @contributionStatusUnknown.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get contributionStatusUnknown;

  /// No description provided for @contributionVoided.
  ///
  /// In en, this message translates to:
  /// **'Voided'**
  String get contributionVoided;

  /// No description provided for @contributionYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get contributionYou;

  /// No description provided for @contributionAmountHidden.
  ///
  /// In en, this message translates to:
  /// **'Amount hidden'**
  String get contributionAmountHidden;

  /// No description provided for @contributionShareOfTarget.
  ///
  /// In en, this message translates to:
  /// **'{percent} of the target'**
  String contributionShareOfTarget(String percent);

  /// No description provided for @contributionLinkedTransaction.
  ///
  /// In en, this message translates to:
  /// **'Linked to a transaction'**
  String get contributionLinkedTransaction;

  /// No description provided for @contributionOpenTransaction.
  ///
  /// In en, this message translates to:
  /// **'Open the linked transaction'**
  String get contributionOpenTransaction;

  /// No description provided for @contributionVoid.
  ///
  /// In en, this message translates to:
  /// **'Void'**
  String get contributionVoid;

  /// No description provided for @contributionVoidTooltip.
  ///
  /// In en, this message translates to:
  /// **'Void your contribution of {date}'**
  String contributionVoidTooltip(String date);

  /// No description provided for @contributionVoidConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Void this contribution?'**
  String get contributionVoidConfirmTitle;

  /// No description provided for @contributionVoidConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'It stops counting towards the goal but stays in the history.'**
  String get contributionVoidConfirmBody;

  /// No description provided for @contributionVoidedDone.
  ///
  /// In en, this message translates to:
  /// **'Contribution voided.'**
  String get contributionVoidedDone;

  /// No description provided for @contributionNewTitle.
  ///
  /// In en, this message translates to:
  /// **'Add to {name}'**
  String contributionNewTitle(String name);

  /// No description provided for @contributionAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount added'**
  String get contributionAmountLabel;

  /// No description provided for @contributionWithdrawalAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount taken out'**
  String get contributionWithdrawalAmountLabel;

  /// No description provided for @contributionPlannedHelp.
  ///
  /// In en, this message translates to:
  /// **'Planned: money you intend to set aside. It isn\'t counted as saved yet.'**
  String get contributionPlannedHelp;

  /// No description provided for @contributionRecordedHelp.
  ///
  /// In en, this message translates to:
  /// **'Recorded: you\'ve already set the money aside. It counts as saved.'**
  String get contributionRecordedHelp;

  /// No description provided for @contributionTransactionLabel.
  ///
  /// In en, this message translates to:
  /// **'Linked transaction'**
  String get contributionTransactionLabel;

  /// No description provided for @contributionTransactionPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Choose the transaction that moved the money'**
  String get contributionTransactionPlaceholder;

  /// No description provided for @contributionTransactionPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Which transaction moved the money?'**
  String get contributionTransactionPickerTitle;

  /// No description provided for @contributionTransactionHelp.
  ///
  /// In en, this message translates to:
  /// **'Linking it marks this as verified. Each transaction counts once.'**
  String get contributionTransactionHelp;

  /// No description provided for @contributionNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get contributionNoteLabel;

  /// No description provided for @contributionSave.
  ///
  /// In en, this message translates to:
  /// **'Save contribution'**
  String get contributionSave;

  /// No description provided for @contributionWithdrawalSave.
  ///
  /// In en, this message translates to:
  /// **'Save withdrawal'**
  String get contributionWithdrawalSave;

  /// No description provided for @contributionSavedDone.
  ///
  /// In en, this message translates to:
  /// **'Contribution added.'**
  String get contributionSavedDone;

  /// No description provided for @contributionWithdrawalSavedDone.
  ///
  /// In en, this message translates to:
  /// **'Withdrawal recorded.'**
  String get contributionWithdrawalSavedDone;

  /// No description provided for @contributionGoalInactive.
  ///
  /// In en, this message translates to:
  /// **'Contributions can be added to active goals only.'**
  String get contributionGoalInactive;

  /// No description provided for @goalMembersTitle.
  ///
  /// In en, this message translates to:
  /// **'Shared with'**
  String get goalMembersTitle;

  /// No description provided for @goalMembersEmpty.
  ///
  /// In en, this message translates to:
  /// **'Not shared with anyone yet.'**
  String get goalMembersEmpty;

  /// No description provided for @goalAddMember.
  ///
  /// In en, this message translates to:
  /// **'Add a person'**
  String get goalAddMember;

  /// No description provided for @goalAddFromConnections.
  ///
  /// In en, this message translates to:
  /// **'From your connections'**
  String get goalAddFromConnections;

  /// No description provided for @goalAddFromGroup.
  ///
  /// In en, this message translates to:
  /// **'From this goal\'s group'**
  String get goalAddFromGroup;

  /// No description provided for @goalMemberYou.
  ///
  /// In en, this message translates to:
  /// **'{name} (you)'**
  String goalMemberYou(String name);

  /// No description provided for @goalMemberRoleTitle.
  ///
  /// In en, this message translates to:
  /// **'What can {name} do?'**
  String goalMemberRoleTitle(String name);

  /// No description provided for @goalMemberRoleContributor.
  ///
  /// In en, this message translates to:
  /// **'Can add contributions'**
  String get goalMemberRoleContributor;

  /// No description provided for @goalMemberRoleViewer.
  ///
  /// In en, this message translates to:
  /// **'Can only view'**
  String get goalMemberRoleViewer;

  /// No description provided for @goalMemberVisibilityAmounts.
  ///
  /// In en, this message translates to:
  /// **'Shows amounts'**
  String get goalMemberVisibilityAmounts;

  /// No description provided for @goalMemberVisibilityPercent.
  ///
  /// In en, this message translates to:
  /// **'Shows percentages only'**
  String get goalMemberVisibilityPercent;

  /// No description provided for @goalMemberVisibilityHidden.
  ///
  /// In en, this message translates to:
  /// **'Keeps contributions private'**
  String get goalMemberVisibilityHidden;

  /// No description provided for @goalMyVisibilityTitle.
  ///
  /// In en, this message translates to:
  /// **'What others see of your contributions'**
  String get goalMyVisibilityTitle;

  /// No description provided for @goalMemberAddedDone.
  ///
  /// In en, this message translates to:
  /// **'{name} added.'**
  String goalMemberAddedDone(String name);

  /// No description provided for @goalMemberUpdatedDone.
  ///
  /// In en, this message translates to:
  /// **'Sharing updated.'**
  String get goalMemberUpdatedDone;

  /// No description provided for @goalMemberRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove from goal'**
  String get goalMemberRemove;

  /// No description provided for @goalMemberRemoveConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}?'**
  String goalMemberRemoveConfirmTitle(String name);

  /// No description provided for @goalMemberRemoveConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'{name} won\'t see this goal anymore. Their past contributions stay in the history.'**
  String goalMemberRemoveConfirmBody(String name);

  /// No description provided for @goalMemberRemovedDone.
  ///
  /// In en, this message translates to:
  /// **'{name} removed.'**
  String goalMemberRemovedDone(String name);

  /// No description provided for @goalDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get goalDetailsTitle;

  /// No description provided for @goalVisibilityLabel.
  ///
  /// In en, this message translates to:
  /// **'Who can see it'**
  String get goalVisibilityLabel;

  /// No description provided for @goalRemindersDetail.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get goalRemindersDetail;

  /// No description provided for @goalEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit goal'**
  String get goalEditTitle;

  /// No description provided for @goalNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Goal name'**
  String get goalNameLabel;

  /// No description provided for @goalNameHelp.
  ///
  /// In en, this message translates to:
  /// **'For example \"Emergency fund\" or \"Goa trip\".'**
  String get goalNameHelp;

  /// No description provided for @goalTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Kind of goal'**
  String get goalTypeLabel;

  /// No description provided for @goalTypeRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose what kind of goal this is.'**
  String get goalTypeRequired;

  /// No description provided for @goalTargetAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Target amount'**
  String get goalTargetAmountLabel;

  /// No description provided for @goalStartingAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Already saved'**
  String get goalStartingAmountLabel;

  /// No description provided for @goalStartingAmountHelp.
  ///
  /// In en, this message translates to:
  /// **'Money you had saved before you started tracking this goal.'**
  String get goalStartingAmountHelp;

  /// No description provided for @goalDatesSection.
  ///
  /// In en, this message translates to:
  /// **'Dates'**
  String get goalDatesSection;

  /// No description provided for @goalStartDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Start date'**
  String get goalStartDateLabel;

  /// No description provided for @goalTargetDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Target date'**
  String get goalTargetDateLabel;

  /// No description provided for @goalTargetDateHelp.
  ///
  /// In en, this message translates to:
  /// **'Helps work out how much to set aside.'**
  String get goalTargetDateHelp;

  /// No description provided for @goalPlanSection.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get goalPlanSection;

  /// No description provided for @goalScheduleLabel.
  ///
  /// In en, this message translates to:
  /// **'How often you plan to add'**
  String get goalScheduleLabel;

  /// No description provided for @goalScheduleNone.
  ///
  /// In en, this message translates to:
  /// **'No regular plan'**
  String get goalScheduleNone;

  /// No description provided for @goalPlannedContributionLabel.
  ///
  /// In en, this message translates to:
  /// **'Planned amount each time'**
  String get goalPlannedContributionLabel;

  /// No description provided for @goalRemindersLabel.
  ///
  /// In en, this message translates to:
  /// **'Remind me about this goal'**
  String get goalRemindersLabel;

  /// No description provided for @goalPriorityLabel.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get goalPriorityLabel;

  /// No description provided for @goalPriorityHelp.
  ///
  /// In en, this message translates to:
  /// **'1 is the most important.'**
  String get goalPriorityHelp;

  /// No description provided for @goalPriorityHighest.
  ///
  /// In en, this message translates to:
  /// **'Highest'**
  String get goalPriorityHighest;

  /// No description provided for @goalPriorityHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get goalPriorityHigh;

  /// No description provided for @goalPriorityMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get goalPriorityMedium;

  /// No description provided for @goalPriorityLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get goalPriorityLow;

  /// No description provided for @goalPriorityLowest.
  ///
  /// In en, this message translates to:
  /// **'Lowest'**
  String get goalPriorityLowest;

  /// No description provided for @goalLinkedAccountLabel.
  ///
  /// In en, this message translates to:
  /// **'Linked account'**
  String get goalLinkedAccountLabel;

  /// No description provided for @goalLinkedAccountNone.
  ///
  /// In en, this message translates to:
  /// **'No account'**
  String get goalLinkedAccountNone;

  /// No description provided for @goalLinkedAccountHelp.
  ///
  /// In en, this message translates to:
  /// **'For your reference only. Its balance isn\'t counted automatically.'**
  String get goalLinkedAccountHelp;

  /// No description provided for @goalSharingSection.
  ///
  /// In en, this message translates to:
  /// **'Sharing'**
  String get goalSharingSection;

  /// No description provided for @goalVisibilityPrivate.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get goalVisibilityPrivate;

  /// No description provided for @goalVisibilityMembers.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get goalVisibilityMembers;

  /// No description provided for @goalVisibilityHelp.
  ///
  /// In en, this message translates to:
  /// **'Private: only you see it. Members: people you add can see it and, if allowed, contribute.'**
  String get goalVisibilityHelp;

  /// No description provided for @goalGroupLabel.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get goalGroupLabel;

  /// No description provided for @goalGroupHelp.
  ///
  /// In en, this message translates to:
  /// **'Share with a group so its members can join in.'**
  String get goalGroupHelp;

  /// No description provided for @goalMoreSection.
  ///
  /// In en, this message translates to:
  /// **'More details'**
  String get goalMoreSection;

  /// No description provided for @goalCreate.
  ///
  /// In en, this message translates to:
  /// **'Create goal'**
  String get goalCreate;

  /// No description provided for @goalCreatedDone.
  ///
  /// In en, this message translates to:
  /// **'Goal created.'**
  String get goalCreatedDone;

  /// No description provided for @goalSavedDone.
  ///
  /// In en, this message translates to:
  /// **'Goal saved.'**
  String get goalSavedDone;

  /// No description provided for @goalExportTitle.
  ///
  /// In en, this message translates to:
  /// **'Export contributions'**
  String get goalExportTitle;

  /// No description provided for @goalExportIntro.
  ///
  /// In en, this message translates to:
  /// **'This CSV lists every contribution, including voided ones. Copy it to paste into a spreadsheet or a note.'**
  String get goalExportIntro;

  /// No description provided for @goalExportFileLabel.
  ///
  /// In en, this message translates to:
  /// **'File name'**
  String get goalExportFileLabel;

  /// No description provided for @goalExportRowsLabel.
  ///
  /// In en, this message translates to:
  /// **'Rows'**
  String get goalExportRowsLabel;

  /// No description provided for @goalExportRows.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No rows yet} =1{1 row} other{{count} rows}}'**
  String goalExportRows(int count);

  /// No description provided for @goalExportEmpty.
  ///
  /// In en, this message translates to:
  /// **'There are no contributions yet, so only the column names are included.'**
  String get goalExportEmpty;

  /// No description provided for @goalExportCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy CSV'**
  String get goalExportCopy;

  /// No description provided for @goalExportCopied.
  ///
  /// In en, this message translates to:
  /// **'CSV copied. It includes your amounts and notes, so paste it only where you trust.'**
  String get goalExportCopied;

  /// No description provided for @goalExportPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get goalExportPreviewTitle;

  /// No description provided for @budgetsTitle.
  ///
  /// In en, this message translates to:
  /// **'Budgets'**
  String get budgetsTitle;

  /// No description provided for @budgetAdd.
  ///
  /// In en, this message translates to:
  /// **'New budget'**
  String get budgetAdd;

  /// No description provided for @budgetAddFirst.
  ///
  /// In en, this message translates to:
  /// **'Create a budget'**
  String get budgetAddFirst;

  /// No description provided for @budgetsShowArchived.
  ///
  /// In en, this message translates to:
  /// **'Show archived budgets'**
  String get budgetsShowArchived;

  /// No description provided for @budgetsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No budgets yet'**
  String get budgetsEmptyTitle;

  /// No description provided for @budgetsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'A budget sets a spending limit for a week, a month or a year. Montra shows what\'s left and whether your spending is on pace.'**
  String get budgetsEmptyBody;

  /// No description provided for @budgetAlertsTitle.
  ///
  /// In en, this message translates to:
  /// **'Budget alerts'**
  String get budgetAlertsTitle;

  /// No description provided for @budgetTypeTotal.
  ///
  /// In en, this message translates to:
  /// **'Total spending'**
  String get budgetTypeTotal;

  /// No description provided for @budgetTypeCategory.
  ///
  /// In en, this message translates to:
  /// **'By category'**
  String get budgetTypeCategory;

  /// No description provided for @budgetTypeMerchant.
  ///
  /// In en, this message translates to:
  /// **'By merchant'**
  String get budgetTypeMerchant;

  /// No description provided for @budgetTypeAccount.
  ///
  /// In en, this message translates to:
  /// **'By account'**
  String get budgetTypeAccount;

  /// No description provided for @budgetTypeEnvelope.
  ///
  /// In en, this message translates to:
  /// **'Envelopes'**
  String get budgetTypeEnvelope;

  /// No description provided for @budgetTypeZeroBased.
  ///
  /// In en, this message translates to:
  /// **'Zero-based'**
  String get budgetTypeZeroBased;

  /// No description provided for @budgetTypeUnknown.
  ///
  /// In en, this message translates to:
  /// **'Other budget'**
  String get budgetTypeUnknown;

  /// No description provided for @budgetTypeTotalHelp.
  ///
  /// In en, this message translates to:
  /// **'One limit for all your spending.'**
  String get budgetTypeTotalHelp;

  /// No description provided for @budgetTypeCategoryHelp.
  ///
  /// In en, this message translates to:
  /// **'Limits for the categories you choose.'**
  String get budgetTypeCategoryHelp;

  /// No description provided for @budgetTypeMerchantHelp.
  ///
  /// In en, this message translates to:
  /// **'Spending at the merchants you choose.'**
  String get budgetTypeMerchantHelp;

  /// No description provided for @budgetTypeAccountHelp.
  ///
  /// In en, this message translates to:
  /// **'Spending from the accounts you choose.'**
  String get budgetTypeAccountHelp;

  /// No description provided for @budgetTypeEnvelopeHelp.
  ///
  /// In en, this message translates to:
  /// **'Split the limit into envelopes, one per category.'**
  String get budgetTypeEnvelopeHelp;

  /// No description provided for @budgetTypeZeroBasedHelp.
  ///
  /// In en, this message translates to:
  /// **'Give every part of the limit a job: the envelopes must add up exactly to the limit.'**
  String get budgetTypeZeroBasedHelp;

  /// No description provided for @budgetTypeGroupHelp.
  ///
  /// In en, this message translates to:
  /// **'Group budgets count all of the group\'s shared expenses.'**
  String get budgetTypeGroupHelp;

  /// No description provided for @budgetPeriodWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get budgetPeriodWeekly;

  /// No description provided for @budgetPeriodMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get budgetPeriodMonthly;

  /// No description provided for @budgetPeriodAnnual.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get budgetPeriodAnnual;

  /// No description provided for @budgetPeriodCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom dates'**
  String get budgetPeriodCustom;

  /// No description provided for @budgetPeriodUnknown.
  ///
  /// In en, this message translates to:
  /// **'Other period'**
  String get budgetPeriodUnknown;

  /// No description provided for @budgetStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get budgetStatusActive;

  /// No description provided for @budgetStatusPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get budgetStatusPaused;

  /// No description provided for @budgetStatusArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get budgetStatusArchived;

  /// No description provided for @budgetStatusUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get budgetStatusUnknown;

  /// No description provided for @budgetAccessEditor.
  ///
  /// In en, this message translates to:
  /// **'Shared with you · can edit'**
  String get budgetAccessEditor;

  /// No description provided for @budgetAccessViewer.
  ///
  /// In en, this message translates to:
  /// **'Shared with you · can view'**
  String get budgetAccessViewer;

  /// No description provided for @budgetSharedWith.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Shared with 1 person} other{Shared with {count} people}}'**
  String budgetSharedWith(int count);

  /// No description provided for @budgetGroupLabel.
  ///
  /// In en, this message translates to:
  /// **'Group: {name}'**
  String budgetGroupLabel(String name);

  /// No description provided for @budgetGroupUnknown.
  ///
  /// In en, this message translates to:
  /// **'a group'**
  String get budgetGroupUnknown;

  /// No description provided for @budgetPaceUnder.
  ///
  /// In en, this message translates to:
  /// **'Spending slower than planned'**
  String get budgetPaceUnder;

  /// No description provided for @budgetPaceOnTrack.
  ///
  /// In en, this message translates to:
  /// **'On track'**
  String get budgetPaceOnTrack;

  /// No description provided for @budgetPaceAhead.
  ///
  /// In en, this message translates to:
  /// **'Spending faster than planned'**
  String get budgetPaceAhead;

  /// No description provided for @budgetPaceOver.
  ///
  /// In en, this message translates to:
  /// **'Over the limit'**
  String get budgetPaceOver;

  /// No description provided for @budgetPaceUnknown.
  ///
  /// In en, this message translates to:
  /// **'Pace not available'**
  String get budgetPaceUnknown;

  /// No description provided for @budgetSpentOf.
  ///
  /// In en, this message translates to:
  /// **'{spent} spent of {limit}'**
  String budgetSpentOf(String spent, String limit);

  /// No description provided for @budgetLeft.
  ///
  /// In en, this message translates to:
  /// **'{amount} left'**
  String budgetLeft(String amount);

  /// No description provided for @budgetOverBy.
  ///
  /// In en, this message translates to:
  /// **'{amount} over the limit'**
  String budgetOverBy(String amount);

  /// No description provided for @budgetPercentUsed.
  ///
  /// In en, this message translates to:
  /// **'{percent} used'**
  String budgetPercentUsed(String percent);

  /// No description provided for @budgetNoProgressPaused.
  ///
  /// In en, this message translates to:
  /// **'Progress isn\'t tracked while it\'s paused.'**
  String get budgetNoProgressPaused;

  /// No description provided for @budgetNoProgressArchived.
  ///
  /// In en, this message translates to:
  /// **'Its history is kept.'**
  String get budgetNoProgressArchived;

  /// No description provided for @budgetDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get budgetDetailTitle;

  /// No description provided for @budgetThisPeriod.
  ///
  /// In en, this message translates to:
  /// **'This period'**
  String get budgetThisPeriod;

  /// No description provided for @budgetDayOf.
  ///
  /// In en, this message translates to:
  /// **'Day {day} of {total}'**
  String budgetDayOf(int day, int total);

  /// No description provided for @budgetRemainingLabel.
  ///
  /// In en, this message translates to:
  /// **'Left to spend'**
  String get budgetRemainingLabel;

  /// No description provided for @budgetOverspentLabel.
  ///
  /// In en, this message translates to:
  /// **'Over the limit by'**
  String get budgetOverspentLabel;

  /// No description provided for @budgetDailyAllowanceLabel.
  ///
  /// In en, this message translates to:
  /// **'Per day for the rest of the period'**
  String get budgetDailyAllowanceLabel;

  /// No description provided for @budgetExpectedByNowLabel.
  ///
  /// In en, this message translates to:
  /// **'Expected by now at an even pace'**
  String get budgetExpectedByNowLabel;

  /// No description provided for @budgetProjectedLabel.
  ///
  /// In en, this message translates to:
  /// **'Estimate for the whole period'**
  String get budgetProjectedLabel;

  /// No description provided for @budgetProjectedOverLabel.
  ///
  /// In en, this message translates to:
  /// **'May go over by'**
  String get budgetProjectedOverLabel;

  /// No description provided for @budgetRolloverInLabel.
  ///
  /// In en, this message translates to:
  /// **'Carried over'**
  String get budgetRolloverInLabel;

  /// No description provided for @budgetBaseLimitLabel.
  ///
  /// In en, this message translates to:
  /// **'Base limit'**
  String get budgetBaseLimitLabel;

  /// No description provided for @budgetLimitLabel.
  ///
  /// In en, this message translates to:
  /// **'Limit'**
  String get budgetLimitLabel;

  /// No description provided for @budgetCountedLabel.
  ///
  /// In en, this message translates to:
  /// **'Transactions counted'**
  String get budgetCountedLabel;

  /// No description provided for @budgetAsOf.
  ///
  /// In en, this message translates to:
  /// **'Totals as of {time}'**
  String budgetAsOf(String time);

  /// No description provided for @budgetHowCalculated.
  ///
  /// In en, this message translates to:
  /// **'How this is calculated'**
  String get budgetHowCalculated;

  /// No description provided for @budgetExplainSpent.
  ///
  /// In en, this message translates to:
  /// **'Spent {spent} of {limit} between {from} and {to}.'**
  String budgetExplainSpent(String spent, String limit, String from, String to);

  /// No description provided for @budgetExplainRefundsRestore.
  ///
  /// In en, this message translates to:
  /// **'Transfers and balance adjustments never count. Refunds give money back to this budget.'**
  String get budgetExplainRefundsRestore;

  /// No description provided for @budgetExplainRefundsIgnored.
  ///
  /// In en, this message translates to:
  /// **'Transfers and balance adjustments never count. Refunds don\'t change this budget.'**
  String get budgetExplainRefundsIgnored;

  /// No description provided for @budgetExplainPending.
  ///
  /// In en, this message translates to:
  /// **'Pending transactions count too.'**
  String get budgetExplainPending;

  /// No description provided for @budgetExplainPostedOnly.
  ///
  /// In en, this message translates to:
  /// **'Only posted transactions count.'**
  String get budgetExplainPostedOnly;

  /// No description provided for @budgetExplainCarry.
  ///
  /// In en, this message translates to:
  /// **'Includes {amount} carried over from the previous period.'**
  String budgetExplainCarry(String amount);

  /// No description provided for @budgetExplainProjected.
  ///
  /// In en, this message translates to:
  /// **'At the current pace you would spend about {amount} by the end of the period. This is an estimate, not a promise.'**
  String budgetExplainProjected(String amount);

  /// No description provided for @budgetExplainOtherCurrency.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 matching transaction in another currency isn\'t included.} other{{count} matching transactions in other currencies aren\'t included.}}'**
  String budgetExplainOtherCurrency(int count);

  /// No description provided for @budgetExplainCollaborator.
  ///
  /// In en, this message translates to:
  /// **'You see the owner\'s totals only; their transactions stay private.'**
  String get budgetExplainCollaborator;

  /// No description provided for @budgetExplainGroup.
  ///
  /// In en, this message translates to:
  /// **'This budget counts the group\'s shared expenses.'**
  String get budgetExplainGroup;

  /// No description provided for @budgetHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Compare periods'**
  String get budgetHistoryTitle;

  /// No description provided for @budgetHistoryEarlier.
  ///
  /// In en, this message translates to:
  /// **'Earlier period'**
  String get budgetHistoryEarlier;

  /// No description provided for @budgetHistoryLater.
  ///
  /// In en, this message translates to:
  /// **'Later period'**
  String get budgetHistoryLater;

  /// No description provided for @budgetHistoryRow.
  ///
  /// In en, this message translates to:
  /// **'{period}: spent {spent} of {limit}.'**
  String budgetHistoryRow(String period, String spent, String limit);

  /// No description provided for @budgetTransactionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Counted transactions'**
  String get budgetTransactionsTitle;

  /// No description provided for @budgetTransactionsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing counts toward this budget in this period yet.'**
  String get budgetTransactionsEmpty;

  /// No description provided for @budgetTransactionsOwnerOnly.
  ///
  /// In en, this message translates to:
  /// **'Only the owner can see the individual transactions. You see the totals.'**
  String get budgetTransactionsOwnerOnly;

  /// No description provided for @budgetTransactionsGroup.
  ///
  /// In en, this message translates to:
  /// **'Group budgets count the group\'s expenses. Open the group to see them.'**
  String get budgetTransactionsGroup;

  /// No description provided for @budgetTransactionsShowAll.
  ///
  /// In en, this message translates to:
  /// **'Show all {count}'**
  String budgetTransactionsShowAll(int count);

  /// No description provided for @budgetTransactionsCapped.
  ///
  /// In en, this message translates to:
  /// **'Showing the first {count} transactions.'**
  String budgetTransactionsCapped(int count);

  /// No description provided for @budgetAllocationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Limits within this budget'**
  String get budgetAllocationsTitle;

  /// No description provided for @budgetEnvelopesTitle.
  ///
  /// In en, this message translates to:
  /// **'Envelopes'**
  String get budgetEnvelopesTitle;

  /// No description provided for @budgetAllocationMember.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s share'**
  String budgetAllocationMember(String name);

  /// No description provided for @budgetAllocationYou.
  ///
  /// In en, this message translates to:
  /// **'Your share'**
  String get budgetAllocationYou;

  /// No description provided for @budgetAllocationUnnamed.
  ///
  /// In en, this message translates to:
  /// **'Unnamed limit'**
  String get budgetAllocationUnnamed;

  /// No description provided for @budgetAllocationRemoved.
  ///
  /// In en, this message translates to:
  /// **'Removed item'**
  String get budgetAllocationRemoved;

  /// No description provided for @budgetAllocationAdd.
  ///
  /// In en, this message translates to:
  /// **'Add a limit'**
  String get budgetAllocationAdd;

  /// No description provided for @budgetAllocationEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit limit'**
  String get budgetAllocationEdit;

  /// No description provided for @budgetAllocationTargetLabel.
  ///
  /// In en, this message translates to:
  /// **'Applies to'**
  String get budgetAllocationTargetLabel;

  /// No description provided for @budgetAllocationTargetCategory.
  ///
  /// In en, this message translates to:
  /// **'A category'**
  String get budgetAllocationTargetCategory;

  /// No description provided for @budgetAllocationTargetMerchant.
  ///
  /// In en, this message translates to:
  /// **'A merchant'**
  String get budgetAllocationTargetMerchant;

  /// No description provided for @budgetAllocationTargetAccount.
  ///
  /// In en, this message translates to:
  /// **'An account'**
  String get budgetAllocationTargetAccount;

  /// No description provided for @budgetAllocationTargetMember.
  ///
  /// In en, this message translates to:
  /// **'A group member\'s share'**
  String get budgetAllocationTargetMember;

  /// No description provided for @budgetAllocationTargetName.
  ///
  /// In en, this message translates to:
  /// **'Just a name'**
  String get budgetAllocationTargetName;

  /// No description provided for @budgetAllocationNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name for this limit'**
  String get budgetAllocationNameLabel;

  /// No description provided for @budgetAllocationChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose'**
  String get budgetAllocationChoose;

  /// No description provided for @budgetAllocationTargetRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose what this limit applies to.'**
  String get budgetAllocationTargetRequired;

  /// No description provided for @budgetAllocationsNeeded.
  ///
  /// In en, this message translates to:
  /// **'Add at least one limit.'**
  String get budgetAllocationsNeeded;

  /// No description provided for @budgetAllocationsHelp.
  ///
  /// In en, this message translates to:
  /// **'Optional limits for parts of this budget.'**
  String get budgetAllocationsHelp;

  /// No description provided for @budgetZeroBasedHelp.
  ///
  /// In en, this message translates to:
  /// **'Envelopes must add up exactly to the limit.'**
  String get budgetZeroBasedHelp;

  /// No description provided for @budgetZeroBasedUnallocated.
  ///
  /// In en, this message translates to:
  /// **'The envelopes don\'t add up to the limit yet. Change an envelope or the limit so they match exactly.'**
  String get budgetZeroBasedUnallocated;

  /// No description provided for @budgetRemoveItem.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}'**
  String budgetRemoveItem(String name);

  /// No description provided for @budgetEditItem.
  ///
  /// In en, this message translates to:
  /// **'Edit {name}'**
  String budgetEditItem(String name);

  /// No description provided for @budgetAllocationValue.
  ///
  /// In en, this message translates to:
  /// **'{spent} of {limit}'**
  String budgetAllocationValue(String spent, String limit);

  /// No description provided for @budgetNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New budget'**
  String get budgetNewTitle;

  /// No description provided for @budgetEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit budget'**
  String get budgetEditTitle;

  /// No description provided for @budgetNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Budget name'**
  String get budgetNameLabel;

  /// No description provided for @budgetNameHelp.
  ///
  /// In en, this message translates to:
  /// **'For example \"Monthly spending\" or \"Groceries\".'**
  String get budgetNameHelp;

  /// No description provided for @budgetTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get budgetTypeLabel;

  /// No description provided for @budgetPeriodLabel.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get budgetPeriodLabel;

  /// No description provided for @budgetStartsOnLabel.
  ///
  /// In en, this message translates to:
  /// **'Starts on'**
  String get budgetStartsOnLabel;

  /// No description provided for @budgetEndsOnLabel.
  ///
  /// In en, this message translates to:
  /// **'Ends on'**
  String get budgetEndsOnLabel;

  /// No description provided for @budgetEndsOnRequired.
  ///
  /// In en, this message translates to:
  /// **'Custom-date budgets need an end date.'**
  String get budgetEndsOnRequired;

  /// No description provided for @budgetLimitHelp.
  ///
  /// In en, this message translates to:
  /// **'The most you want to spend in each period.'**
  String get budgetLimitHelp;

  /// No description provided for @budgetGroupField.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get budgetGroupField;

  /// No description provided for @budgetGroupHelp.
  ///
  /// In en, this message translates to:
  /// **'Track a household, trip or other group\'s shared expenses.'**
  String get budgetGroupHelp;

  /// No description provided for @budgetGroupFixed.
  ///
  /// In en, this message translates to:
  /// **'The group can\'t change after the budget is created.'**
  String get budgetGroupFixed;

  /// No description provided for @budgetCurrencyFromGroup.
  ///
  /// In en, this message translates to:
  /// **'Group budgets use the group\'s currency.'**
  String get budgetCurrencyFromGroup;

  /// No description provided for @budgetScopeSection.
  ///
  /// In en, this message translates to:
  /// **'What counts'**
  String get budgetScopeSection;

  /// No description provided for @budgetMerchantsLabel.
  ///
  /// In en, this message translates to:
  /// **'Merchants'**
  String get budgetMerchantsLabel;

  /// No description provided for @budgetMerchantsNeeded.
  ///
  /// In en, this message translates to:
  /// **'Choose at least one merchant.'**
  String get budgetMerchantsNeeded;

  /// No description provided for @budgetAddMerchant.
  ///
  /// In en, this message translates to:
  /// **'Add merchant'**
  String get budgetAddMerchant;

  /// No description provided for @budgetAccountsLabel.
  ///
  /// In en, this message translates to:
  /// **'Only these accounts'**
  String get budgetAccountsLabel;

  /// No description provided for @budgetAccountsAll.
  ///
  /// In en, this message translates to:
  /// **'All accounts'**
  String get budgetAccountsAll;

  /// No description provided for @budgetAccountsNeeded.
  ///
  /// In en, this message translates to:
  /// **'Choose at least one account.'**
  String get budgetAccountsNeeded;

  /// No description provided for @budgetExcludedLabel.
  ///
  /// In en, this message translates to:
  /// **'Leave out these categories'**
  String get budgetExcludedLabel;

  /// No description provided for @budgetNothingExcluded.
  ///
  /// In en, this message translates to:
  /// **'Nothing left out'**
  String get budgetNothingExcluded;

  /// No description provided for @budgetIncludePending.
  ///
  /// In en, this message translates to:
  /// **'Count pending transactions'**
  String get budgetIncludePending;

  /// No description provided for @budgetRefundsRestore.
  ///
  /// In en, this message translates to:
  /// **'Refunds give money back to the budget'**
  String get budgetRefundsRestore;

  /// No description provided for @budgetCountGroupShares.
  ///
  /// In en, this message translates to:
  /// **'Count my share of group expenses'**
  String get budgetCountGroupShares;

  /// No description provided for @budgetRolloverSection.
  ///
  /// In en, this message translates to:
  /// **'Carry over'**
  String get budgetRolloverSection;

  /// No description provided for @budgetRolloverLabel.
  ///
  /// In en, this message translates to:
  /// **'At the end of a period'**
  String get budgetRolloverLabel;

  /// No description provided for @budgetRolloverNone.
  ///
  /// In en, this message translates to:
  /// **'Start fresh each period'**
  String get budgetRolloverNone;

  /// No description provided for @budgetRolloverUnused.
  ///
  /// In en, this message translates to:
  /// **'Carry unused money forward'**
  String get budgetRolloverUnused;

  /// No description provided for @budgetRolloverOverspend.
  ///
  /// In en, this message translates to:
  /// **'Carry overspending forward'**
  String get budgetRolloverOverspend;

  /// No description provided for @budgetRolloverBoth.
  ///
  /// In en, this message translates to:
  /// **'Carry both forward'**
  String get budgetRolloverBoth;

  /// No description provided for @budgetRolloverUnknown.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get budgetRolloverUnknown;

  /// No description provided for @budgetRolloverCapLabel.
  ///
  /// In en, this message translates to:
  /// **'Most that can carry over'**
  String get budgetRolloverCapLabel;

  /// No description provided for @budgetRolloverCapHelp.
  ///
  /// In en, this message translates to:
  /// **'Leave empty for no cap.'**
  String get budgetRolloverCapHelp;

  /// No description provided for @budgetRolloverCustomNote.
  ///
  /// In en, this message translates to:
  /// **'Custom-date budgets don\'t carry anything over.'**
  String get budgetRolloverCustomNote;

  /// No description provided for @budgetAlertsSection.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get budgetAlertsSection;

  /// No description provided for @budgetThresholdsLabel.
  ///
  /// In en, this message translates to:
  /// **'Tell me when I\'ve used'**
  String get budgetThresholdsLabel;

  /// No description provided for @budgetThresholdsHelp.
  ///
  /// In en, this message translates to:
  /// **'Choose 1 to {max}.'**
  String budgetThresholdsHelp(int max);

  /// No description provided for @budgetThresholdValue.
  ///
  /// In en, this message translates to:
  /// **'{value}%'**
  String budgetThresholdValue(int value);

  /// No description provided for @budgetForecastAlert.
  ///
  /// In en, this message translates to:
  /// **'Warn me if I\'m likely to go over'**
  String get budgetForecastAlert;

  /// No description provided for @budgetForecastHelp.
  ///
  /// In en, this message translates to:
  /// **'Based on your spending pace. It\'s an estimate.'**
  String get budgetForecastHelp;

  /// No description provided for @budgetVisibilityLabel.
  ///
  /// In en, this message translates to:
  /// **'Who can see it'**
  String get budgetVisibilityLabel;

  /// No description provided for @budgetVisibilityMembers.
  ///
  /// In en, this message translates to:
  /// **'Everyone in the group'**
  String get budgetVisibilityMembers;

  /// No description provided for @budgetVisibilityPrivate.
  ///
  /// In en, this message translates to:
  /// **'Only me and people I add'**
  String get budgetVisibilityPrivate;

  /// No description provided for @budgetCreateButton.
  ///
  /// In en, this message translates to:
  /// **'Create budget'**
  String get budgetCreateButton;

  /// No description provided for @budgetCreated.
  ///
  /// In en, this message translates to:
  /// **'Budget created.'**
  String get budgetCreated;

  /// No description provided for @budgetSaved.
  ///
  /// In en, this message translates to:
  /// **'Budget saved.'**
  String get budgetSaved;

  /// No description provided for @budgetEditAppliesNote.
  ///
  /// In en, this message translates to:
  /// **'Changes apply from the current period onward. Earlier periods keep their numbers.'**
  String get budgetEditAppliesNote;

  /// No description provided for @budgetTypeUnknownNote.
  ///
  /// In en, this message translates to:
  /// **'This budget type isn\'t supported in this version of the app. Choose a type to save changes.'**
  String get budgetTypeUnknownNote;

  /// No description provided for @budgetSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get budgetSettingsTitle;

  /// No description provided for @budgetThresholdsShort.
  ///
  /// In en, this message translates to:
  /// **'Alert levels'**
  String get budgetThresholdsShort;

  /// No description provided for @budgetForecastShort.
  ///
  /// In en, this message translates to:
  /// **'Overspending forecast'**
  String get budgetForecastShort;

  /// No description provided for @budgetTimezoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Time zone'**
  String get budgetTimezoneLabel;

  /// No description provided for @budgetMembersTitle.
  ///
  /// In en, this message translates to:
  /// **'Shared with'**
  String get budgetMembersTitle;

  /// No description provided for @budgetYouOwn.
  ///
  /// In en, this message translates to:
  /// **'You own this budget.'**
  String get budgetYouOwn;

  /// No description provided for @budgetMembersEmpty.
  ///
  /// In en, this message translates to:
  /// **'Only you can see this budget.'**
  String get budgetMembersEmpty;

  /// No description provided for @budgetMembersGroupNote.
  ///
  /// In en, this message translates to:
  /// **'Group members can see it if you choose \"Everyone in the group\".'**
  String get budgetMembersGroupNote;

  /// No description provided for @budgetMemberAdd.
  ///
  /// In en, this message translates to:
  /// **'Add a person'**
  String get budgetMemberAdd;

  /// No description provided for @budgetRoleEditor.
  ///
  /// In en, this message translates to:
  /// **'Can edit'**
  String get budgetRoleEditor;

  /// No description provided for @budgetRoleViewer.
  ///
  /// In en, this message translates to:
  /// **'Can view'**
  String get budgetRoleViewer;

  /// No description provided for @budgetRoleLabel.
  ///
  /// In en, this message translates to:
  /// **'Access'**
  String get budgetRoleLabel;

  /// No description provided for @budgetMemberAllocationLabel.
  ///
  /// In en, this message translates to:
  /// **'Their share of the limit'**
  String get budgetMemberAllocationLabel;

  /// No description provided for @budgetMemberAllocationHelp.
  ///
  /// In en, this message translates to:
  /// **'Optional. Shown to them as their part of the limit.'**
  String get budgetMemberAllocationHelp;

  /// No description provided for @budgetMemberShareTitle.
  ///
  /// In en, this message translates to:
  /// **'Share with {name}'**
  String budgetMemberShareTitle(String name);

  /// No description provided for @budgetMemberEditTitle.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s access'**
  String budgetMemberEditTitle(String name);

  /// No description provided for @budgetMemberShareButton.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get budgetMemberShareButton;

  /// No description provided for @budgetMemberRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove from budget'**
  String get budgetMemberRemove;

  /// No description provided for @budgetMemberRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}?'**
  String budgetMemberRemoveTitle(String name);

  /// No description provided for @budgetMemberRemoveBody.
  ///
  /// In en, this message translates to:
  /// **'They won\'t see this budget anymore. You can add them again later.'**
  String get budgetMemberRemoveBody;

  /// No description provided for @budgetMemberAdded.
  ///
  /// In en, this message translates to:
  /// **'{name} can now see this budget.'**
  String budgetMemberAdded(String name);

  /// No description provided for @budgetMemberUpdated.
  ///
  /// In en, this message translates to:
  /// **'Access updated.'**
  String get budgetMemberUpdated;

  /// No description provided for @budgetMemberRemoved.
  ///
  /// In en, this message translates to:
  /// **'{name} was removed.'**
  String budgetMemberRemoved(String name);

  /// No description provided for @budgetMemberShare.
  ///
  /// In en, this message translates to:
  /// **'Share: {amount}'**
  String budgetMemberShare(String amount);

  /// No description provided for @budgetLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave this budget'**
  String get budgetLeave;

  /// No description provided for @budgetLeaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave this budget?'**
  String get budgetLeaveTitle;

  /// No description provided for @budgetLeaveBody.
  ///
  /// In en, this message translates to:
  /// **'You\'ll stop seeing it. The owner can add you again.'**
  String get budgetLeaveBody;

  /// No description provided for @budgetLeaveDone.
  ///
  /// In en, this message translates to:
  /// **'You left the budget.'**
  String get budgetLeaveDone;

  /// No description provided for @budgetPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get budgetPause;

  /// No description provided for @budgetResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get budgetResume;

  /// No description provided for @budgetArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get budgetArchive;

  /// No description provided for @budgetPaused.
  ///
  /// In en, this message translates to:
  /// **'Budget paused.'**
  String get budgetPaused;

  /// No description provided for @budgetResumed.
  ///
  /// In en, this message translates to:
  /// **'Budget resumed.'**
  String get budgetResumed;

  /// No description provided for @budgetArchived.
  ///
  /// In en, this message translates to:
  /// **'Budget archived. Its history is kept.'**
  String get budgetArchived;

  /// No description provided for @budgetRestored.
  ///
  /// In en, this message translates to:
  /// **'Budget restored.'**
  String get budgetRestored;

  /// No description provided for @budgetArchiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Archive this budget?'**
  String get budgetArchiveTitle;

  /// No description provided for @budgetArchiveBody.
  ///
  /// In en, this message translates to:
  /// **'{name} stops tracking spending, and its history is kept. You can restore it later.'**
  String budgetArchiveBody(String name);

  /// No description provided for @budgetPausedNotice.
  ///
  /// In en, this message translates to:
  /// **'This budget is paused. Spending isn\'t tracked against it until you resume it.'**
  String get budgetPausedNotice;

  /// No description provided for @budgetArchivedNotice.
  ///
  /// In en, this message translates to:
  /// **'This budget is archived. Its history is kept; restore it to track spending again.'**
  String get budgetArchivedNotice;

  /// No description provided for @budgetAlertStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get budgetAlertStatusActive;

  /// No description provided for @budgetAlertStatusSnoozed.
  ///
  /// In en, this message translates to:
  /// **'Snoozed'**
  String get budgetAlertStatusSnoozed;

  /// No description provided for @budgetAlertStatusDismissed.
  ///
  /// In en, this message translates to:
  /// **'Dismissed'**
  String get budgetAlertStatusDismissed;

  /// No description provided for @budgetAlertStatusAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get budgetAlertStatusAll;

  /// No description provided for @budgetAlertFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Show alerts'**
  String get budgetAlertFilterLabel;

  /// No description provided for @budgetAlertThreshold.
  ///
  /// In en, this message translates to:
  /// **'{name}: {percent}% of the limit used'**
  String budgetAlertThreshold(String name, int percent);

  /// No description provided for @budgetAlertFullyUsed.
  ///
  /// In en, this message translates to:
  /// **'{name}: the whole limit is used'**
  String budgetAlertFullyUsed(String name);

  /// No description provided for @budgetAlertForecast.
  ///
  /// In en, this message translates to:
  /// **'{name} may go over its limit'**
  String budgetAlertForecast(String name);

  /// No description provided for @budgetAlertForecastBody.
  ///
  /// In en, this message translates to:
  /// **'At the current pace this budget may be exceeded before the period ends. This is an estimate.'**
  String get budgetAlertForecastBody;

  /// No description provided for @budgetAlertUnusual.
  ///
  /// In en, this message translates to:
  /// **'Unusual spending in {name}'**
  String budgetAlertUnusual(String name);

  /// No description provided for @budgetAlertOther.
  ///
  /// In en, this message translates to:
  /// **'An update about {name}'**
  String budgetAlertOther(String name);

  /// No description provided for @budgetAlertPeriod.
  ///
  /// In en, this message translates to:
  /// **'Period from {date}'**
  String budgetAlertPeriod(String date);

  /// No description provided for @budgetAlertTriggered.
  ///
  /// In en, this message translates to:
  /// **'Noticed {time}'**
  String budgetAlertTriggered(String time);

  /// No description provided for @budgetAlertSnoozedUntil.
  ///
  /// In en, this message translates to:
  /// **'Snoozed until {time}'**
  String budgetAlertSnoozedUntil(String time);

  /// No description provided for @budgetAlertDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get budgetAlertDismiss;

  /// No description provided for @budgetAlertSnooze.
  ///
  /// In en, this message translates to:
  /// **'Snooze'**
  String get budgetAlertSnooze;

  /// No description provided for @budgetAlertReactivate.
  ///
  /// In en, this message translates to:
  /// **'Show again'**
  String get budgetAlertReactivate;

  /// No description provided for @budgetAlertDismissed.
  ///
  /// In en, this message translates to:
  /// **'Alert dismissed.'**
  String get budgetAlertDismissed;

  /// No description provided for @budgetAlertSnoozedDone.
  ///
  /// In en, this message translates to:
  /// **'Alert snoozed until {time}.'**
  String budgetAlertSnoozedDone(String time);

  /// No description provided for @budgetAlertReactivated.
  ///
  /// In en, this message translates to:
  /// **'The alert is active again.'**
  String get budgetAlertReactivated;

  /// No description provided for @budgetSnoozeTitle.
  ///
  /// In en, this message translates to:
  /// **'Snooze until'**
  String get budgetSnoozeTitle;

  /// No description provided for @budgetSnoozeDay.
  ///
  /// In en, this message translates to:
  /// **'For 1 day'**
  String get budgetSnoozeDay;

  /// No description provided for @budgetSnooze3Days.
  ///
  /// In en, this message translates to:
  /// **'For 3 days'**
  String get budgetSnooze3Days;

  /// No description provided for @budgetSnoozeWeek.
  ///
  /// In en, this message translates to:
  /// **'For a week'**
  String get budgetSnoozeWeek;

  /// No description provided for @budgetSnoozePickDate.
  ///
  /// In en, this message translates to:
  /// **'Until a date…'**
  String get budgetSnoozePickDate;

  /// No description provided for @budgetAlertsEmptyActive.
  ///
  /// In en, this message translates to:
  /// **'No active alerts. You\'ll see one here when a budget reaches a level you chose.'**
  String get budgetAlertsEmptyActive;

  /// No description provided for @budgetAlertsEmptyOther.
  ///
  /// In en, this message translates to:
  /// **'Nothing here.'**
  String get budgetAlertsEmptyOther;

  /// No description provided for @budgetAlertsBannerTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 budget alert} other{{count} budget alerts}}'**
  String budgetAlertsBannerTitle(int count);

  /// No description provided for @budgetAlertsBannerReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get budgetAlertsBannerReview;

  /// No description provided for @budgetHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No figures for this period yet.'**
  String get budgetHistoryEmpty;

  /// No description provided for @categoriesTitle.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categoriesTitle;

  /// No description provided for @categoriesIntro.
  ///
  /// In en, this message translates to:
  /// **'Categories group your spending and income. Subcategories sit under a main category.'**
  String get categoriesIntro;

  /// No description provided for @categoriesShowArchived.
  ///
  /// In en, this message translates to:
  /// **'Show archived and merged'**
  String get categoriesShowArchived;

  /// No description provided for @categoriesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No categories yet'**
  String get categoriesEmptyTitle;

  /// No description provided for @categoriesEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add one to start sorting your transactions.'**
  String get categoriesEmptyBody;

  /// No description provided for @categoryNew.
  ///
  /// In en, this message translates to:
  /// **'New category'**
  String get categoryNew;

  /// No description provided for @categoryNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New category'**
  String get categoryNewTitle;

  /// No description provided for @categoryEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit category'**
  String get categoryEditTitle;

  /// No description provided for @categoryEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get categoryEdit;

  /// No description provided for @categoryActionsFor.
  ///
  /// In en, this message translates to:
  /// **'More actions for {name}'**
  String categoryActionsFor(String name);

  /// No description provided for @categoryAddSubcategory.
  ///
  /// In en, this message translates to:
  /// **'Add a subcategory'**
  String get categoryAddSubcategory;

  /// No description provided for @categoryMergeInto.
  ///
  /// In en, this message translates to:
  /// **'Merge into another category'**
  String get categoryMergeInto;

  /// No description provided for @categoryMergeIntoHelp.
  ///
  /// In en, this message translates to:
  /// **'Moves its transactions and settings, then retires it.'**
  String get categoryMergeIntoHelp;

  /// No description provided for @categoryArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get categoryArchive;

  /// No description provided for @categoryArchiveHelp.
  ///
  /// In en, this message translates to:
  /// **'Hidden from pickers; past transactions keep it.'**
  String get categoryArchiveHelp;

  /// No description provided for @categoryRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get categoryRestore;

  /// No description provided for @categoryDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get categoryDelete;

  /// No description provided for @categoryDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete “{name}”?'**
  String categoryDeleteTitle(String name);

  /// No description provided for @categoryDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Nothing uses this category. Deleting it can\'t be undone.'**
  String get categoryDeleteBody;

  /// No description provided for @categoryDeleted.
  ///
  /// In en, this message translates to:
  /// **'“{name}” deleted.'**
  String categoryDeleted(String name);

  /// No description provided for @categoryArchived.
  ///
  /// In en, this message translates to:
  /// **'“{name}” archived. Past transactions keep it.'**
  String categoryArchived(String name);

  /// No description provided for @categoryRestored.
  ///
  /// In en, this message translates to:
  /// **'“{name}” restored.'**
  String categoryRestored(String name);

  /// No description provided for @categoryInUse.
  ///
  /// In en, this message translates to:
  /// **'Some records still use this category. Merge it into another category or archive it instead.'**
  String get categoryInUse;

  /// No description provided for @categoryMerge.
  ///
  /// In en, this message translates to:
  /// **'Merge'**
  String get categoryMerge;

  /// No description provided for @categoryMergeTargetTitle.
  ///
  /// In en, this message translates to:
  /// **'Merge “{name}” into…'**
  String categoryMergeTargetTitle(String name);

  /// No description provided for @categoryMergeTitle.
  ///
  /// In en, this message translates to:
  /// **'Merge “{source}” into “{target}”?'**
  String categoryMergeTitle(String source, String target);

  /// No description provided for @categoryMergeBody.
  ///
  /// In en, this message translates to:
  /// **'These move to the new category:\n{moves}\n\n“{name}” will then be marked as merged. This can\'t be undone.'**
  String categoryMergeBody(String moves, String name);

  /// No description provided for @categoryMergeNothing.
  ///
  /// In en, this message translates to:
  /// **'Nothing uses “{name}” yet. It will be marked as merged. This can\'t be undone.'**
  String categoryMergeNothing(String name);

  /// No description provided for @categoryMerged.
  ///
  /// In en, this message translates to:
  /// **'“{source}” merged into “{target}”.'**
  String categoryMerged(String source, String target);

  /// No description provided for @categoryCreated.
  ///
  /// In en, this message translates to:
  /// **'Category “{name}” added.'**
  String categoryCreated(String name);

  /// No description provided for @categorySaved.
  ///
  /// In en, this message translates to:
  /// **'Category saved.'**
  String get categorySaved;

  /// No description provided for @categoryNotFound.
  ///
  /// In en, this message translates to:
  /// **'This category isn\'t available any more.'**
  String get categoryNotFound;

  /// No description provided for @categoryStarterNote.
  ///
  /// In en, this message translates to:
  /// **'This is one of Montra\'s starter categories. You can rename it; until you do, it shows in your language.'**
  String get categoryStarterNote;

  /// No description provided for @categoryNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get categoryNameLabel;

  /// No description provided for @categoryNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a name.'**
  String get categoryNameRequired;

  /// No description provided for @categoryKindLabel.
  ///
  /// In en, this message translates to:
  /// **'Used for'**
  String get categoryKindLabel;

  /// No description provided for @categoryKindExpense.
  ///
  /// In en, this message translates to:
  /// **'Spending'**
  String get categoryKindExpense;

  /// No description provided for @categoryKindIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get categoryKindIncome;

  /// No description provided for @categoryKindBoth.
  ///
  /// In en, this message translates to:
  /// **'Both'**
  String get categoryKindBoth;

  /// No description provided for @categoryKindOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get categoryKindOther;

  /// No description provided for @categoryParentLabel.
  ///
  /// In en, this message translates to:
  /// **'Main category'**
  String get categoryParentLabel;

  /// No description provided for @categoryParentNone.
  ///
  /// In en, this message translates to:
  /// **'None (this is a main category)'**
  String get categoryParentNone;

  /// No description provided for @categoryParentHelp.
  ///
  /// In en, this message translates to:
  /// **'Choose one to make this a subcategory.'**
  String get categoryParentHelp;

  /// No description provided for @categoryParentHasChildren.
  ///
  /// In en, this message translates to:
  /// **'This category has subcategories, so it stays a main category.'**
  String get categoryParentHasChildren;

  /// No description provided for @categoryIconLabel.
  ///
  /// In en, this message translates to:
  /// **'Icon'**
  String get categoryIconLabel;

  /// No description provided for @categoryIncludeInBudgets.
  ///
  /// In en, this message translates to:
  /// **'Count in budgets'**
  String get categoryIncludeInBudgets;

  /// No description provided for @categoryIncludeInBudgetsHelp.
  ///
  /// In en, this message translates to:
  /// **'Turn off for things you don\'t want budgets to track.'**
  String get categoryIncludeInBudgetsHelp;

  /// No description provided for @categoryNotInBudgets.
  ///
  /// In en, this message translates to:
  /// **'Not in budgets'**
  String get categoryNotInBudgets;

  /// No description provided for @categorySortLabel.
  ///
  /// In en, this message translates to:
  /// **'Position in lists (optional)'**
  String get categorySortLabel;

  /// No description provided for @categorySortHelp.
  ///
  /// In en, this message translates to:
  /// **'Lower numbers come first.'**
  String get categorySortHelp;

  /// No description provided for @categoryStatusArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get categoryStatusArchived;

  /// No description provided for @categoryStatusMerged.
  ///
  /// In en, this message translates to:
  /// **'Merged'**
  String get categoryStatusMerged;

  /// No description provided for @categoryTransactionCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No transactions} =1{1 transaction} other{{count} transactions}}'**
  String categoryTransactionCount(int count);

  /// No description provided for @categoryIconCart.
  ///
  /// In en, this message translates to:
  /// **'Groceries'**
  String get categoryIconCart;

  /// No description provided for @categoryIconFood.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get categoryIconFood;

  /// No description provided for @categoryIconTransport.
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get categoryIconTransport;

  /// No description provided for @categoryIconFuel.
  ///
  /// In en, this message translates to:
  /// **'Fuel'**
  String get categoryIconFuel;

  /// No description provided for @categoryIconHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get categoryIconHome;

  /// No description provided for @categoryIconUtilities.
  ///
  /// In en, this message translates to:
  /// **'Utilities'**
  String get categoryIconUtilities;

  /// No description provided for @categoryIconShopping.
  ///
  /// In en, this message translates to:
  /// **'Shopping'**
  String get categoryIconShopping;

  /// No description provided for @categoryIconHealth.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get categoryIconHealth;

  /// No description provided for @categoryIconEducation.
  ///
  /// In en, this message translates to:
  /// **'Education'**
  String get categoryIconEducation;

  /// No description provided for @categoryIconEntertainment.
  ///
  /// In en, this message translates to:
  /// **'Entertainment'**
  String get categoryIconEntertainment;

  /// No description provided for @categoryIconTravel.
  ///
  /// In en, this message translates to:
  /// **'Travel'**
  String get categoryIconTravel;

  /// No description provided for @categoryIconPersonalCare.
  ///
  /// In en, this message translates to:
  /// **'Personal care'**
  String get categoryIconPersonalCare;

  /// No description provided for @categoryIconInsurance.
  ///
  /// In en, this message translates to:
  /// **'Insurance'**
  String get categoryIconInsurance;

  /// No description provided for @categoryIconBills.
  ///
  /// In en, this message translates to:
  /// **'Bills'**
  String get categoryIconBills;

  /// No description provided for @categoryIconGifts.
  ///
  /// In en, this message translates to:
  /// **'Gifts'**
  String get categoryIconGifts;

  /// No description provided for @categoryIconFamily.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get categoryIconFamily;

  /// No description provided for @categoryIconWork.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get categoryIconWork;

  /// No description provided for @categoryIconMoney.
  ///
  /// In en, this message translates to:
  /// **'Money'**
  String get categoryIconMoney;

  /// No description provided for @categoryIconTech.
  ///
  /// In en, this message translates to:
  /// **'Gadgets'**
  String get categoryIconTech;

  /// No description provided for @categoryIconSavings.
  ///
  /// In en, this message translates to:
  /// **'Savings'**
  String get categoryIconSavings;

  /// No description provided for @categoryIconOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get categoryIconOther;

  /// No description provided for @labelColorLabel.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get labelColorLabel;

  /// No description provided for @labelColorNone.
  ///
  /// In en, this message translates to:
  /// **'No color'**
  String get labelColorNone;

  /// No description provided for @labelColorCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom color'**
  String get labelColorCustom;

  /// No description provided for @labelColorRed.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get labelColorRed;

  /// No description provided for @labelColorOrange.
  ///
  /// In en, this message translates to:
  /// **'Orange'**
  String get labelColorOrange;

  /// No description provided for @labelColorYellow.
  ///
  /// In en, this message translates to:
  /// **'Yellow'**
  String get labelColorYellow;

  /// No description provided for @labelColorGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get labelColorGreen;

  /// No description provided for @labelColorTeal.
  ///
  /// In en, this message translates to:
  /// **'Teal'**
  String get labelColorTeal;

  /// No description provided for @labelColorBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get labelColorBlue;

  /// No description provided for @labelColorPurple.
  ///
  /// In en, this message translates to:
  /// **'Purple'**
  String get labelColorPurple;

  /// No description provided for @labelColorPink.
  ///
  /// In en, this message translates to:
  /// **'Pink'**
  String get labelColorPink;

  /// No description provided for @labelColorBrown.
  ///
  /// In en, this message translates to:
  /// **'Brown'**
  String get labelColorBrown;

  /// No description provided for @labelColorGrey.
  ///
  /// In en, this message translates to:
  /// **'Grey'**
  String get labelColorGrey;

  /// No description provided for @mergeAffectedTransactions.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 transaction} other{{count} transactions}}'**
  String mergeAffectedTransactions(int count);

  /// No description provided for @mergeAffectedSubcategories.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 subcategory} other{{count} subcategories}}'**
  String mergeAffectedSubcategories(int count);

  /// No description provided for @mergeAffectedRules.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 category rule} other{{count} category rules}}'**
  String mergeAffectedRules(int count);

  /// No description provided for @mergeAffectedBudgets.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 budget limit} other{{count} budget limits}}'**
  String mergeAffectedBudgets(int count);

  /// No description provided for @mergeAffectedMerchants.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 merchant default} other{{count} merchant defaults}}'**
  String mergeAffectedMerchants(int count);

  /// No description provided for @mergeAffectedRecurring.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 recurring rule} other{{count} recurring rules}}'**
  String mergeAffectedRecurring(int count);

  /// No description provided for @mergeAffectedBills.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 bill} other{{count} bills}}'**
  String mergeAffectedBills(int count);

  /// No description provided for @mergeAffectedSubscriptions.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 subscription} other{{count} subscriptions}}'**
  String mergeAffectedSubscriptions(int count);

  /// No description provided for @mergeAffectedOther.
  ///
  /// In en, this message translates to:
  /// **'{kind}: {count}'**
  String mergeAffectedOther(String kind, int count);

  /// No description provided for @categoryRulesTitle.
  ///
  /// In en, this message translates to:
  /// **'Category rules'**
  String get categoryRulesTitle;

  /// No description provided for @categoryRulesIntro.
  ///
  /// In en, this message translates to:
  /// **'Rules set the category for you when a transaction\'s merchant or description matches. They run in order; the first match wins.'**
  String get categoryRulesIntro;

  /// No description provided for @categoryRulesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No rules yet'**
  String get categoryRulesEmptyTitle;

  /// No description provided for @categoryRulesEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add a rule, for example: merchant contains “swiggy” → Food.'**
  String get categoryRulesEmptyBody;

  /// No description provided for @ruleNew.
  ///
  /// In en, this message translates to:
  /// **'New rule'**
  String get ruleNew;

  /// No description provided for @ruleNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New rule'**
  String get ruleNewTitle;

  /// No description provided for @ruleEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit rule'**
  String get ruleEditTitle;

  /// No description provided for @ruleNotFound.
  ///
  /// In en, this message translates to:
  /// **'This rule isn\'t available any more.'**
  String get ruleNotFound;

  /// No description provided for @ruleSummary.
  ///
  /// In en, this message translates to:
  /// **'{field} {match} “{pattern}” → {category}'**
  String ruleSummary(
    String field,
    String match,
    String pattern,
    String category,
  );

  /// No description provided for @rulePriorityValue.
  ///
  /// In en, this message translates to:
  /// **'Order {priority}'**
  String rulePriorityValue(int priority);

  /// No description provided for @ruleStatusOff.
  ///
  /// In en, this message translates to:
  /// **'Turned off'**
  String get ruleStatusOff;

  /// No description provided for @ruleCategoryMissing.
  ///
  /// In en, this message translates to:
  /// **'Unavailable category'**
  String get ruleCategoryMissing;

  /// No description provided for @ruleNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Rule name'**
  String get ruleNameLabel;

  /// No description provided for @ruleNameHelp.
  ///
  /// In en, this message translates to:
  /// **'Just for you, e.g. “Food delivery”.'**
  String get ruleNameHelp;

  /// No description provided for @ruleNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a name.'**
  String get ruleNameRequired;

  /// No description provided for @ruleWhenSection.
  ///
  /// In en, this message translates to:
  /// **'When'**
  String get ruleWhenSection;

  /// No description provided for @ruleThenSection.
  ///
  /// In en, this message translates to:
  /// **'Then set the category to'**
  String get ruleThenSection;

  /// No description provided for @ruleLimitsSection.
  ///
  /// In en, this message translates to:
  /// **'Only for (optional)'**
  String get ruleLimitsSection;

  /// No description provided for @ruleFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Look at'**
  String get ruleFieldLabel;

  /// No description provided for @ruleFieldMerchant.
  ///
  /// In en, this message translates to:
  /// **'Merchant'**
  String get ruleFieldMerchant;

  /// No description provided for @ruleFieldDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get ruleFieldDescription;

  /// No description provided for @ruleFieldAny.
  ///
  /// In en, this message translates to:
  /// **'Merchant or description'**
  String get ruleFieldAny;

  /// No description provided for @ruleMatchTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Match'**
  String get ruleMatchTypeLabel;

  /// No description provided for @ruleMatchContains.
  ///
  /// In en, this message translates to:
  /// **'contains'**
  String get ruleMatchContains;

  /// No description provided for @ruleMatchEquals.
  ///
  /// In en, this message translates to:
  /// **'is exactly'**
  String get ruleMatchEquals;

  /// No description provided for @ruleMatchStartsWith.
  ///
  /// In en, this message translates to:
  /// **'starts with'**
  String get ruleMatchStartsWith;

  /// No description provided for @ruleMatchRegex.
  ///
  /// In en, this message translates to:
  /// **'matches the pattern'**
  String get ruleMatchRegex;

  /// No description provided for @rulePatternLabel.
  ///
  /// In en, this message translates to:
  /// **'Text to match'**
  String get rulePatternLabel;

  /// No description provided for @rulePatternHelp.
  ///
  /// In en, this message translates to:
  /// **'Capital letters don\'t matter.'**
  String get rulePatternHelp;

  /// No description provided for @rulePatternRegexHelp.
  ///
  /// In en, this message translates to:
  /// **'Advanced: a regular expression.'**
  String get rulePatternRegexHelp;

  /// No description provided for @rulePatternRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the text to match.'**
  String get rulePatternRequired;

  /// No description provided for @ruleCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get ruleCategoryLabel;

  /// No description provided for @ruleCategoryPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Choose a category'**
  String get ruleCategoryPlaceholder;

  /// No description provided for @ruleCategoryRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose the category to set.'**
  String get ruleCategoryRequired;

  /// No description provided for @ruleTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Transaction type'**
  String get ruleTypeLabel;

  /// No description provided for @ruleTypeAny.
  ///
  /// In en, this message translates to:
  /// **'Any type'**
  String get ruleTypeAny;

  /// No description provided for @ruleTypeExpense.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get ruleTypeExpense;

  /// No description provided for @ruleTypeIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get ruleTypeIncome;

  /// No description provided for @ruleAccountLabel.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get ruleAccountLabel;

  /// No description provided for @ruleAccountAny.
  ///
  /// In en, this message translates to:
  /// **'Any account'**
  String get ruleAccountAny;

  /// No description provided for @ruleAmountMin.
  ///
  /// In en, this message translates to:
  /// **'Smallest amount (optional)'**
  String get ruleAmountMin;

  /// No description provided for @ruleAmountMax.
  ///
  /// In en, this message translates to:
  /// **'Largest amount (optional)'**
  String get ruleAmountMax;

  /// No description provided for @ruleAmountHelp.
  ///
  /// In en, this message translates to:
  /// **'Amounts are in {currency}. Leave empty for any amount.'**
  String ruleAmountHelp(String currency);

  /// No description provided for @ruleApplyToLabel.
  ///
  /// In en, this message translates to:
  /// **'Use for new transactions'**
  String get ruleApplyToLabel;

  /// No description provided for @ruleApplyAll.
  ///
  /// In en, this message translates to:
  /// **'Added by me and imported'**
  String get ruleApplyAll;

  /// No description provided for @ruleApplyManual.
  ///
  /// In en, this message translates to:
  /// **'Only ones I add'**
  String get ruleApplyManual;

  /// No description provided for @ruleApplyImports.
  ///
  /// In en, this message translates to:
  /// **'Only imported ones'**
  String get ruleApplyImports;

  /// No description provided for @rulePriorityLabel.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get rulePriorityLabel;

  /// No description provided for @rulePriorityHelp.
  ///
  /// In en, this message translates to:
  /// **'0 to 10000. Lower numbers run first; the first matching rule wins.'**
  String get rulePriorityHelp;

  /// No description provided for @rulePriorityInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a number from 0 to 10000.'**
  String get rulePriorityInvalid;

  /// No description provided for @ruleEnabledLabel.
  ///
  /// In en, this message translates to:
  /// **'Rule is on'**
  String get ruleEnabledLabel;

  /// No description provided for @ruleEnabledHelp.
  ///
  /// In en, this message translates to:
  /// **'Turned-off rules are kept but don\'t run.'**
  String get ruleEnabledHelp;

  /// No description provided for @rulePreviewSection.
  ///
  /// In en, this message translates to:
  /// **'Try it on past transactions'**
  String get rulePreviewSection;

  /// No description provided for @ruleOnlyUncategorized.
  ///
  /// In en, this message translates to:
  /// **'Only transactions without a category'**
  String get ruleOnlyUncategorized;

  /// No description provided for @rulePreviewAction.
  ///
  /// In en, this message translates to:
  /// **'Preview matches'**
  String get rulePreviewAction;

  /// No description provided for @rulePreviewNone.
  ///
  /// In en, this message translates to:
  /// **'No past transactions match.'**
  String get rulePreviewNone;

  /// No description provided for @rulePreviewCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Matches 1 transaction} other{Matches {count} transactions}} (showing {shown}).'**
  String rulePreviewCount(int count, int shown);

  /// No description provided for @ruleApplyAction.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Apply to this transaction} other{Apply to these {count} transactions}}'**
  String ruleApplyAction(int count);

  /// No description provided for @ruleApplyTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Change 1 transaction?} other{Change {count} transactions?}}'**
  String ruleApplyTitle(int count);

  /// No description provided for @ruleApplyBody.
  ///
  /// In en, this message translates to:
  /// **'Their category will change to {category}. You can still change any of them later.'**
  String ruleApplyBody(String category);

  /// No description provided for @ruleApplyConfirm.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get ruleApplyConfirm;

  /// No description provided for @ruleApplied.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No transactions needed a change.} =1{Updated 1 transaction.} other{Updated {count} transactions.}}'**
  String ruleApplied(int count);

  /// No description provided for @ruleSaved.
  ///
  /// In en, this message translates to:
  /// **'Rule saved.'**
  String get ruleSaved;

  /// No description provided for @ruleDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete rule'**
  String get ruleDelete;

  /// No description provided for @ruleDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete the rule “{name}”?'**
  String ruleDeleteTitle(String name);

  /// No description provided for @ruleDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Transactions it already changed keep their category.'**
  String get ruleDeleteBody;

  /// No description provided for @ruleDeleted.
  ///
  /// In en, this message translates to:
  /// **'Rule deleted.'**
  String get ruleDeleted;

  /// No description provided for @tagsTitle.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get tagsTitle;

  /// No description provided for @tagsIntro.
  ///
  /// In en, this message translates to:
  /// **'Tags are your own labels, like “trip” or “work”, and a transaction can have several.'**
  String get tagsIntro;

  /// No description provided for @tagsShowArchived.
  ///
  /// In en, this message translates to:
  /// **'Show archived tags'**
  String get tagsShowArchived;

  /// No description provided for @tagsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No tags yet'**
  String get tagsEmptyTitle;

  /// No description provided for @tagsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add one here or while saving a transaction.'**
  String get tagsEmptyBody;

  /// No description provided for @tagNew.
  ///
  /// In en, this message translates to:
  /// **'New tag'**
  String get tagNew;

  /// No description provided for @tagEdit.
  ///
  /// In en, this message translates to:
  /// **'Rename or recolor'**
  String get tagEdit;

  /// No description provided for @tagNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Tag name'**
  String get tagNameLabel;

  /// No description provided for @tagNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a name.'**
  String get tagNameRequired;

  /// No description provided for @tagNameTaken.
  ///
  /// In en, this message translates to:
  /// **'You already have a tag with this name.'**
  String get tagNameTaken;

  /// No description provided for @tagCreated.
  ///
  /// In en, this message translates to:
  /// **'Tag “{name}” added.'**
  String tagCreated(String name);

  /// No description provided for @tagSaved.
  ///
  /// In en, this message translates to:
  /// **'Tag saved.'**
  String get tagSaved;

  /// No description provided for @tagSeeTransactions.
  ///
  /// In en, this message translates to:
  /// **'See transactions'**
  String get tagSeeTransactions;

  /// No description provided for @tagArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get tagArchive;

  /// No description provided for @tagArchiveHelp.
  ///
  /// In en, this message translates to:
  /// **'Hidden from pickers; transactions keep it.'**
  String get tagArchiveHelp;

  /// No description provided for @tagUnarchive.
  ///
  /// In en, this message translates to:
  /// **'Unarchive'**
  String get tagUnarchive;

  /// No description provided for @tagArchived.
  ///
  /// In en, this message translates to:
  /// **'“{name}” archived.'**
  String tagArchived(String name);

  /// No description provided for @tagUnarchived.
  ///
  /// In en, this message translates to:
  /// **'“{name}” is back in your tag lists.'**
  String tagUnarchived(String name);

  /// No description provided for @tagDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get tagDelete;

  /// No description provided for @tagDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete the tag “{name}”?'**
  String tagDeleteTitle(String name);

  /// No description provided for @tagDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{It isn\'t on any transactions.} =1{It will be removed from 1 transaction. The transaction stays.} other{It will be removed from {count} transactions. The transactions stay.}}'**
  String tagDeleteBody(int count);

  /// No description provided for @tagDeleted.
  ///
  /// In en, this message translates to:
  /// **'“{name}” deleted.'**
  String tagDeleted(String name);

  /// No description provided for @tagStatusArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get tagStatusArchived;

  /// No description provided for @merchantsTitle.
  ///
  /// In en, this message translates to:
  /// **'Merchants'**
  String get merchantsTitle;

  /// No description provided for @merchantsSearch.
  ///
  /// In en, this message translates to:
  /// **'Search by name or other name'**
  String get merchantsSearch;

  /// No description provided for @merchantsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No merchants yet'**
  String get merchantsEmptyTitle;

  /// No description provided for @merchantsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Merchants are added when you save transactions with a merchant.'**
  String get merchantsEmptyBody;

  /// No description provided for @merchantsNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No merchants match.'**
  String get merchantsNoMatch;

  /// No description provided for @merchantDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Merchant'**
  String get merchantDetailTitle;

  /// No description provided for @merchantLastUsed.
  ///
  /// In en, this message translates to:
  /// **'Last used {date}'**
  String merchantLastUsed(String date);

  /// No description provided for @merchantAlsoKnownAs.
  ///
  /// In en, this message translates to:
  /// **'Also: {names}'**
  String merchantAlsoKnownAs(String names);

  /// No description provided for @merchantStatusArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get merchantStatusArchived;

  /// No description provided for @merchantEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit merchant'**
  String get merchantEdit;

  /// No description provided for @merchantMoreActions.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get merchantMoreActions;

  /// No description provided for @merchantDetailsSection.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get merchantDetailsSection;

  /// No description provided for @merchantDefaultCategory.
  ///
  /// In en, this message translates to:
  /// **'Default category'**
  String get merchantDefaultCategory;

  /// No description provided for @merchantDefaultCategoryHelp.
  ///
  /// In en, this message translates to:
  /// **'Suggested when you add a transaction here.'**
  String get merchantDefaultCategoryHelp;

  /// No description provided for @merchantNoDefaultCategory.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get merchantNoDefaultCategory;

  /// No description provided for @merchantTransactionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get merchantTransactionsLabel;

  /// No description provided for @merchantLastUsedLabel.
  ///
  /// In en, this message translates to:
  /// **'Last used'**
  String get merchantLastUsedLabel;

  /// No description provided for @merchantWebsiteLabel.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get merchantWebsiteLabel;

  /// No description provided for @merchantWebsiteFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open this website.'**
  String get merchantWebsiteFailed;

  /// No description provided for @merchantNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get merchantNotesLabel;

  /// No description provided for @merchantSpendingSection.
  ///
  /// In en, this message translates to:
  /// **'Spending, last 12 months'**
  String get merchantSpendingSection;

  /// No description provided for @merchantNoSpending.
  ///
  /// In en, this message translates to:
  /// **'No spending here in the last 12 months.'**
  String get merchantNoSpending;

  /// No description provided for @merchantSpendingSummary.
  ///
  /// In en, this message translates to:
  /// **'In {currency}, {months, plural, =1{1 month} other{{months} months}} with spending; the highest was {month} at {amount}. Refunds are subtracted.'**
  String merchantSpendingSummary(
    String currency,
    int months,
    String month,
    String amount,
  );

  /// No description provided for @merchantSpendingSummaryNone.
  ///
  /// In en, this message translates to:
  /// **'In {currency}, refunds cancelled out the spending in these months.'**
  String merchantSpendingSummaryNone(String currency);

  /// No description provided for @merchantAliasesSection.
  ///
  /// In en, this message translates to:
  /// **'Other names'**
  String get merchantAliasesSection;

  /// No description provided for @merchantAliasesHelp.
  ///
  /// In en, this message translates to:
  /// **'Names this merchant appears under, for example on bank statements.'**
  String get merchantAliasesHelp;

  /// No description provided for @merchantNoAliases.
  ///
  /// In en, this message translates to:
  /// **'No other names yet.'**
  String get merchantNoAliases;

  /// No description provided for @merchantAddAlias.
  ///
  /// In en, this message translates to:
  /// **'Add another name'**
  String get merchantAddAlias;

  /// No description provided for @merchantAliasDialogBody.
  ///
  /// In en, this message translates to:
  /// **'Transactions with this name will be matched to {name}.'**
  String merchantAliasDialogBody(String name);

  /// No description provided for @merchantAliasLabel.
  ///
  /// In en, this message translates to:
  /// **'Other name'**
  String get merchantAliasLabel;

  /// No description provided for @merchantAliasRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a name.'**
  String get merchantAliasRequired;

  /// No description provided for @merchantAliasAdded.
  ///
  /// In en, this message translates to:
  /// **'“{alias}” added as another name.'**
  String merchantAliasAdded(String alias);

  /// No description provided for @merchantSeeTransactions.
  ///
  /// In en, this message translates to:
  /// **'See transactions'**
  String get merchantSeeTransactions;

  /// No description provided for @merchantMergeAction.
  ///
  /// In en, this message translates to:
  /// **'Merge another merchant into this one'**
  String get merchantMergeAction;

  /// No description provided for @merchantMergeHelp.
  ///
  /// In en, this message translates to:
  /// **'For duplicates of the same place.'**
  String get merchantMergeHelp;

  /// No description provided for @merchantMergePickTitle.
  ///
  /// In en, this message translates to:
  /// **'Merge into “{name}”'**
  String merchantMergePickTitle(String name);

  /// No description provided for @merchantMergeTitle.
  ///
  /// In en, this message translates to:
  /// **'Merge “{source}” into “{target}”?'**
  String merchantMergeTitle(String source, String target);

  /// No description provided for @merchantMergeBody.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{“{source}” has no transactions.} =1{Its 1 transaction moves to “{target}”.} other{Its {count} transactions move to “{target}”.}} Its names are kept as other names of “{target}”. This can\'t be undone.'**
  String merchantMergeBody(int count, String source, String target);

  /// No description provided for @merchantMergeConfirm.
  ///
  /// In en, this message translates to:
  /// **'Merge'**
  String get merchantMergeConfirm;

  /// No description provided for @merchantMerged.
  ///
  /// In en, this message translates to:
  /// **'“{source}” merged into “{target}”.'**
  String merchantMerged(String source, String target);

  /// No description provided for @merchantMergedNote.
  ///
  /// In en, this message translates to:
  /// **'This merchant was merged into another one.'**
  String get merchantMergedNote;

  /// No description provided for @merchantArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get merchantArchive;

  /// No description provided for @merchantArchiveHelp.
  ///
  /// In en, this message translates to:
  /// **'Hidden from suggestions; past transactions keep it.'**
  String get merchantArchiveHelp;

  /// No description provided for @merchantUnarchive.
  ///
  /// In en, this message translates to:
  /// **'Unarchive'**
  String get merchantUnarchive;

  /// No description provided for @merchantArchived.
  ///
  /// In en, this message translates to:
  /// **'“{name}” archived.'**
  String merchantArchived(String name);

  /// No description provided for @merchantUnarchived.
  ///
  /// In en, this message translates to:
  /// **'“{name}” is back in suggestions.'**
  String merchantUnarchived(String name);

  /// No description provided for @merchantArchivedNote.
  ///
  /// In en, this message translates to:
  /// **'Archived: it isn\'t suggested for new transactions.'**
  String get merchantArchivedNote;

  /// No description provided for @merchantNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get merchantNameLabel;

  /// No description provided for @merchantNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a name.'**
  String get merchantNameRequired;

  /// No description provided for @merchantNameTaken.
  ///
  /// In en, this message translates to:
  /// **'Another merchant already has this name. Merge them instead.'**
  String get merchantNameTaken;

  /// No description provided for @merchantSaved.
  ///
  /// In en, this message translates to:
  /// **'Merchant saved.'**
  String get merchantSaved;

  /// No description provided for @recurringOpenTooltip.
  ///
  /// In en, this message translates to:
  /// **'Recurring payments'**
  String get recurringOpenTooltip;

  /// No description provided for @profileOrganizeTitle.
  ///
  /// In en, this message translates to:
  /// **'Organize'**
  String get profileOrganizeTitle;

  /// No description provided for @profileCategoriesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Main categories and subcategories'**
  String get profileCategoriesSubtitle;

  /// No description provided for @profileRulesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Set categories automatically'**
  String get profileRulesSubtitle;

  /// No description provided for @profileTagsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your own labels for transactions'**
  String get profileTagsSubtitle;

  /// No description provided for @profileMerchantsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Names, other names and spending'**
  String get profileMerchantsSubtitle;

  /// No description provided for @homePlanTitle.
  ///
  /// In en, this message translates to:
  /// **'Plan ahead'**
  String get homePlanTitle;

  /// No description provided for @homePlanBudgets.
  ///
  /// In en, this message translates to:
  /// **'Budgets'**
  String get homePlanBudgets;

  /// No description provided for @homePlanGoals.
  ///
  /// In en, this message translates to:
  /// **'Goals'**
  String get homePlanGoals;

  /// No description provided for @homePlanBills.
  ///
  /// In en, this message translates to:
  /// **'Bills'**
  String get homePlanBills;

  /// No description provided for @homePlanSubscriptions.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions'**
  String get homePlanSubscriptions;

  /// No description provided for @homePlanRecurring.
  ///
  /// In en, this message translates to:
  /// **'Recurring'**
  String get homePlanRecurring;

  /// No description provided for @homePlanCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get homePlanCalendar;

  /// No description provided for @errorStorageUnavailable.
  ///
  /// In en, this message translates to:
  /// **'File storage isn\'t available right now. Try again in a few minutes.'**
  String get errorStorageUnavailable;

  /// No description provided for @errorFeatureNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'This feature isn\'t set up on this server yet.'**
  String get errorFeatureNotConfigured;

  /// No description provided for @errorPayloadTooLarge.
  ///
  /// In en, this message translates to:
  /// **'This file is too large. Choose a smaller file.'**
  String get errorPayloadTooLarge;

  /// No description provided for @errorUnsupportedFile.
  ///
  /// In en, this message translates to:
  /// **'This file type isn\'t accepted, or its content doesn\'t match its type. Try another file.'**
  String get errorUnsupportedFile;

  /// No description provided for @errorRuleTransactionVoided.
  ///
  /// In en, this message translates to:
  /// **'Restore this transaction first.'**
  String get errorRuleTransactionVoided;

  /// No description provided for @errorRuleFileNotReady.
  ///
  /// In en, this message translates to:
  /// **'Finish uploading the file first.'**
  String get errorRuleFileNotReady;

  /// No description provided for @errorRuleFileNotAttachable.
  ///
  /// In en, this message translates to:
  /// **'This file can\'t be attached to a transaction.'**
  String get errorRuleFileNotAttachable;

  /// No description provided for @errorRuleStatusTransition.
  ///
  /// In en, this message translates to:
  /// **'This can\'t change from {from} to {to}. Reload to see where it stands now.'**
  String errorRuleStatusTransition(String from, String to);

  /// No description provided for @errorRuleRecordLimit.
  ///
  /// In en, this message translates to:
  /// **'{resource, select, bills{You can keep up to {limit} open bills.} recurring_rules{You can keep up to {limit} recurring payments.} subscriptions{You can keep up to {limit} subscriptions.} goals{You can keep up to {limit} goals.} other{You can keep up to {limit} of these.}} End, archive or delete ones you no longer need.'**
  String errorRuleRecordLimit(String resource, String limit);

  /// No description provided for @errorMerchantNameTaken.
  ///
  /// In en, this message translates to:
  /// **'Another merchant is already called “{name}”. Merge them instead.'**
  String errorMerchantNameTaken(String name);

  /// No description provided for @errorNameTaken.
  ///
  /// In en, this message translates to:
  /// **'“{name}” is already used. Choose another name.'**
  String errorNameTaken(String name);

  /// No description provided for @errorCategoryInUse.
  ///
  /// In en, this message translates to:
  /// **'This category is used by existing records. Merge it into another category or archive it instead.'**
  String get errorCategoryInUse;

  /// No description provided for @errorRuleCategoryUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This rule\'s category is archived or no longer fits the rule. Restore the category or choose another one.'**
  String get errorRuleCategoryUnavailable;

  /// No description provided for @errorRuleCategoryMerged.
  ///
  /// In en, this message translates to:
  /// **'This category was merged and can\'t be changed any more.'**
  String get errorRuleCategoryMerged;

  /// No description provided for @errorRuleCategoryAlreadyMerged.
  ///
  /// In en, this message translates to:
  /// **'One of these categories was already merged.'**
  String get errorRuleCategoryAlreadyMerged;

  /// No description provided for @errorRuleCategoryDepth.
  ///
  /// In en, this message translates to:
  /// **'Categories can have only one level of subcategories.'**
  String get errorRuleCategoryDepth;

  /// No description provided for @errorRuleParentArchived.
  ///
  /// In en, this message translates to:
  /// **'The main category is archived. Restore it first.'**
  String get errorRuleParentArchived;

  /// No description provided for @errorRuleMergeTargetInactive.
  ///
  /// In en, this message translates to:
  /// **'Merge into an active category.'**
  String get errorRuleMergeTargetInactive;

  /// No description provided for @errorRuleMergeTargetTopLevel.
  ///
  /// In en, this message translates to:
  /// **'A category with subcategories can only be merged into a main category.'**
  String get errorRuleMergeTargetTopLevel;

  /// No description provided for @errorRuleGroupBudgetType.
  ///
  /// In en, this message translates to:
  /// **'Group budgets track all of the group\'s expenses. Use a total budget, or split it between members.'**
  String get errorRuleGroupBudgetType;

  /// No description provided for @errorRuleGroupBudgetFilter.
  ///
  /// In en, this message translates to:
  /// **'Group budgets count all of the group\'s expenses, so account, category and merchant filters don\'t apply.'**
  String get errorRuleGroupBudgetFilter;

  /// No description provided for @errorRuleGroupBudgetAllocation.
  ///
  /// In en, this message translates to:
  /// **'Group budgets are split between members, not categories, merchants or accounts.'**
  String get errorRuleGroupBudgetAllocation;

  /// No description provided for @errorRuleGroupBudget.
  ///
  /// In en, this message translates to:
  /// **'Group budgets track group expenses. Open the group to see them.'**
  String get errorRuleGroupBudget;

  /// No description provided for @errorRuleZeroBasedUnallocated.
  ///
  /// In en, this message translates to:
  /// **'A zero-based budget must give out exactly the full limit.'**
  String get errorRuleZeroBasedUnallocated;

  /// No description provided for @errorRuleScheduleEnded.
  ///
  /// In en, this message translates to:
  /// **'This schedule has ended. Edit it to set new dates.'**
  String get errorRuleScheduleEnded;

  /// No description provided for @errorRuleRecurringInUse.
  ///
  /// In en, this message translates to:
  /// **'This can\'t be deleted because it has history. Stop it instead.'**
  String get errorRuleRecurringInUse;

  /// No description provided for @errorRuleNoOpenOccurrence.
  ///
  /// In en, this message translates to:
  /// **'Nothing is unpaid right now.'**
  String get errorRuleNoOpenOccurrence;

  /// No description provided for @errorRuleOccurrenceNotOpen.
  ///
  /// In en, this message translates to:
  /// **'That payment is already paid, skipped or no longer part of this bill.'**
  String get errorRuleOccurrenceNotOpen;

  /// No description provided for @errorRuleOccurrenceNotSkipped.
  ///
  /// In en, this message translates to:
  /// **'Only skipped payments can be reopened.'**
  String get errorRuleOccurrenceNotSkipped;

  /// No description provided for @errorRuleOccurrenceHandled.
  ///
  /// In en, this message translates to:
  /// **'This payment was already handled.'**
  String get errorRuleOccurrenceHandled;

  /// No description provided for @errorRulePostponeLater.
  ///
  /// In en, this message translates to:
  /// **'Move an open payment to a later date.'**
  String get errorRulePostponeLater;

  /// No description provided for @errorRuleUseBillScreen.
  ///
  /// In en, this message translates to:
  /// **'Change bills from the bill\'s own screen.'**
  String get errorRuleUseBillScreen;

  /// No description provided for @errorRuleAutoPostNeeds.
  ///
  /// In en, this message translates to:
  /// **'Recording automatically needs a fixed amount and an account.'**
  String get errorRuleAutoPostNeeds;

  /// No description provided for @errorRuleBillInactive.
  ///
  /// In en, this message translates to:
  /// **'Restore the bill before recording payments.'**
  String get errorRuleBillInactive;

  /// No description provided for @errorRuleBillsNotAutoPosted.
  ///
  /// In en, this message translates to:
  /// **'Bills are confirmed by linking or recording the actual payment.'**
  String get errorRuleBillsNotAutoPosted;

  /// No description provided for @errorRuleTransferTwoAccounts.
  ///
  /// In en, this message translates to:
  /// **'Recurring transfers need two different accounts.'**
  String get errorRuleTransferTwoAccounts;

  /// No description provided for @errorRuleTransferDestination.
  ///
  /// In en, this message translates to:
  /// **'This transfer has no destination account.'**
  String get errorRuleTransferDestination;

  /// No description provided for @errorRuleCrossCurrencyAutoPost.
  ///
  /// In en, this message translates to:
  /// **'Transfers between currencies need the received amount each time, so they can\'t be recorded automatically.'**
  String get errorRuleCrossCurrencyAutoPost;

  /// No description provided for @errorRuleSubscriptionInactive.
  ///
  /// In en, this message translates to:
  /// **'Reactivate the subscription before recording new payments.'**
  String get errorRuleSubscriptionInactive;

  /// No description provided for @errorRuleSubscriptionNotCancelled.
  ///
  /// In en, this message translates to:
  /// **'Only a cancelled subscription has a cancellation date.'**
  String get errorRuleSubscriptionNotCancelled;

  /// No description provided for @errorRuleDetectionDecided.
  ///
  /// In en, this message translates to:
  /// **'This possible subscription was already reviewed.'**
  String get errorRuleDetectionDecided;

  /// No description provided for @errorRuleDetectionEvidenceMissing.
  ///
  /// In en, this message translates to:
  /// **'The transactions behind this match no longer exist. Dismiss it.'**
  String get errorRuleDetectionEvidenceMissing;

  /// No description provided for @errorPaymentAlreadyLinked.
  ///
  /// In en, this message translates to:
  /// **'This payment is already recorded for this subscription.'**
  String get errorPaymentAlreadyLinked;

  /// No description provided for @errorPaymentLinkedElsewhere.
  ///
  /// In en, this message translates to:
  /// **'This payment is already recorded for another subscription.'**
  String get errorPaymentLinkedElsewhere;

  /// No description provided for @errorCancellationConfirmationRequired.
  ///
  /// In en, this message translates to:
  /// **'Confirm that you cancelled with the provider.'**
  String get errorCancellationConfirmationRequired;

  /// No description provided for @errorRuleGoalInactive.
  ///
  /// In en, this message translates to:
  /// **'Contributions can be added to active goals only.'**
  String get errorRuleGoalInactive;

  /// No description provided for @errorRuleOwnerRoleFixed.
  ///
  /// In en, this message translates to:
  /// **'The owner\'s role can\'t change.'**
  String get errorRuleOwnerRoleFixed;

  /// No description provided for @errorRuleOwnerCannotLeave.
  ///
  /// In en, this message translates to:
  /// **'The owner can\'t leave or be removed. Archive the goal instead.'**
  String get errorRuleOwnerCannotLeave;

  /// No description provided for @errorRuleMemberVisibility.
  ///
  /// In en, this message translates to:
  /// **'Members choose who sees their own contributions.'**
  String get errorRuleMemberVisibility;

  /// No description provided for @errorRuleContributionNotPlanned.
  ///
  /// In en, this message translates to:
  /// **'This contribution is already recorded.'**
  String get errorRuleContributionNotPlanned;

  /// No description provided for @errorRuleContributionVoided.
  ///
  /// In en, this message translates to:
  /// **'This contribution was voided.'**
  String get errorRuleContributionVoided;

  /// No description provided for @errorTransactionAlreadyCounted.
  ///
  /// In en, this message translates to:
  /// **'This transaction already counts toward a goal.'**
  String get errorTransactionAlreadyCounted;

  /// No description provided for @errorRuleWithdrawalExceedsSaved.
  ///
  /// In en, this message translates to:
  /// **'A withdrawal can\'t be more than what\'s saved ({saved} {currency}).'**
  String errorRuleWithdrawalExceedsSaved(String saved, String currency);

  /// No description provided for @errorRuleStorageQuota.
  ///
  /// In en, this message translates to:
  /// **'This upload would go over your {quota} storage allowance. Delete files you no longer need first.'**
  String errorRuleStorageQuota(String quota);

  /// No description provided for @errorRuleReceiptIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Add the receipt\'s date and total first.'**
  String get errorRuleReceiptIncomplete;

  /// No description provided for @errorRuleReceiptNotReviewed.
  ///
  /// In en, this message translates to:
  /// **'Save the receipt details before recording the purchase.'**
  String get errorRuleReceiptNotReviewed;

  /// No description provided for @errorRuleNoRows.
  ///
  /// In en, this message translates to:
  /// **'There are no rows to import.'**
  String get errorRuleNoRows;

  /// No description provided for @errorRuleRowInvalid.
  ///
  /// In en, this message translates to:
  /// **'Fix this row\'s date, amount or direction before importing it.'**
  String get errorRuleRowInvalid;

  /// No description provided for @errorRuleDirectionMismatch.
  ///
  /// In en, this message translates to:
  /// **'Statement rows and transactions must both be money in, or both money out.'**
  String get errorRuleDirectionMismatch;

  /// No description provided for @errorRuleInvalidMatchShape.
  ///
  /// In en, this message translates to:
  /// **'Match one statement row to several transactions, or several rows to one transaction.'**
  String get errorRuleInvalidMatchShape;

  /// No description provided for @errorRuleInvalidPair.
  ///
  /// In en, this message translates to:
  /// **'Choose one pending and one posted transaction going the same way.'**
  String get errorRuleInvalidPair;

  /// No description provided for @errorRuleSumsDiffer.
  ///
  /// In en, this message translates to:
  /// **'The statement side ({statement} {currency}) and the transactions ({ledger} {currency}) don\'t add up to the same amount.'**
  String errorRuleSumsDiffer(String statement, String ledger, String currency);

  /// No description provided for @errorRuleReportTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The report has too many transactions. Choose a shorter period or fewer filters.'**
  String get errorRuleReportTooLarge;

  /// No description provided for @errorRuleBalanceAlreadyMatches.
  ///
  /// In en, this message translates to:
  /// **'The balance already matches, so nothing needs adjusting.'**
  String get errorRuleBalanceAlreadyMatches;

  /// No description provided for @statusWordActive.
  ///
  /// In en, this message translates to:
  /// **'active'**
  String get statusWordActive;

  /// No description provided for @statusWordPaused.
  ///
  /// In en, this message translates to:
  /// **'paused'**
  String get statusWordPaused;

  /// No description provided for @statusWordArchived.
  ///
  /// In en, this message translates to:
  /// **'archived'**
  String get statusWordArchived;

  /// No description provided for @statusWordEnded.
  ///
  /// In en, this message translates to:
  /// **'ended'**
  String get statusWordEnded;

  /// No description provided for @statusWordAchieved.
  ///
  /// In en, this message translates to:
  /// **'achieved'**
  String get statusWordAchieved;

  /// No description provided for @statusWordCancelled.
  ///
  /// In en, this message translates to:
  /// **'cancelled'**
  String get statusWordCancelled;

  /// No description provided for @statusWordCancelling.
  ///
  /// In en, this message translates to:
  /// **'being cancelled'**
  String get statusWordCancelling;

  /// No description provided for @statusWordTrial.
  ///
  /// In en, this message translates to:
  /// **'on trial'**
  String get statusWordTrial;

  /// No description provided for @statusWordVoided.
  ///
  /// In en, this message translates to:
  /// **'deleted'**
  String get statusWordVoided;

  /// No description provided for @statusWordPending.
  ///
  /// In en, this message translates to:
  /// **'pending'**
  String get statusWordPending;

  /// No description provided for @statusWordPosted.
  ///
  /// In en, this message translates to:
  /// **'posted'**
  String get statusWordPosted;

  /// No description provided for @statusWordUnknown.
  ///
  /// In en, this message translates to:
  /// **'its current state'**
  String get statusWordUnknown;

  /// No description provided for @fileEmpty.
  ///
  /// In en, this message translates to:
  /// **'This file is empty. Choose another file.'**
  String get fileEmpty;

  /// No description provided for @fileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'This file is larger than {size}. Choose a smaller file.'**
  String fileTooLarge(String size);

  /// No description provided for @fileTypeNotAccepted.
  ///
  /// In en, this message translates to:
  /// **'This file type isn\'t accepted here. Use {types}.'**
  String fileTypeNotAccepted(String types);

  /// No description provided for @fileCameraUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The camera isn\'t available. Choose a photo or a file instead.'**
  String get fileCameraUnavailable;

  /// No description provided for @fileSourceTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a file'**
  String get fileSourceTitle;

  /// No description provided for @fileSourceCamera.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get fileSourceCamera;

  /// No description provided for @fileSourcePhotos.
  ///
  /// In en, this message translates to:
  /// **'Choose a photo'**
  String get fileSourcePhotos;

  /// No description provided for @fileSourceFiles.
  ///
  /// In en, this message translates to:
  /// **'Choose a file'**
  String get fileSourceFiles;

  /// No description provided for @fileAcceptedTypes.
  ///
  /// In en, this message translates to:
  /// **'{types}, up to {size}'**
  String fileAcceptedTypes(String types, String size);

  /// No description provided for @uploadStageChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking the file…'**
  String get uploadStageChecking;

  /// No description provided for @uploadStageAuthorizing.
  ///
  /// In en, this message translates to:
  /// **'Preparing the upload…'**
  String get uploadStageAuthorizing;

  /// No description provided for @uploadStageSending.
  ///
  /// In en, this message translates to:
  /// **'Uploading…'**
  String get uploadStageSending;

  /// No description provided for @uploadStageSendingPercent.
  ///
  /// In en, this message translates to:
  /// **'Uploading… {percent}%'**
  String uploadStageSendingPercent(int percent);

  /// No description provided for @uploadStageFinishing.
  ///
  /// In en, this message translates to:
  /// **'Finishing…'**
  String get uploadStageFinishing;

  /// No description provided for @uploadCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel upload'**
  String get uploadCancel;

  /// No description provided for @uploadCancelled.
  ///
  /// In en, this message translates to:
  /// **'Upload cancelled.'**
  String get uploadCancelled;

  /// No description provided for @fileShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get fileShare;

  /// No description provided for @fileSave.
  ///
  /// In en, this message translates to:
  /// **'Save to device'**
  String get fileSave;

  /// No description provided for @fileSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved.'**
  String get fileSaved;

  /// No description provided for @fileOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get fileOpen;

  /// No description provided for @fileDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading…'**
  String get fileDownloading;

  /// No description provided for @filePreviewLabel.
  ///
  /// In en, this message translates to:
  /// **'Preview of {name}'**
  String filePreviewLabel(String name);

  /// No description provided for @homeToolsTitle.
  ///
  /// In en, this message translates to:
  /// **'Review your money'**
  String get homeToolsTitle;

  /// No description provided for @entryReceipts.
  ///
  /// In en, this message translates to:
  /// **'Receipts'**
  String get entryReceipts;

  /// No description provided for @entryReceiptsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Photos and PDFs of receipts, checked by you'**
  String get entryReceiptsSubtitle;

  /// No description provided for @entryImports.
  ///
  /// In en, this message translates to:
  /// **'Statement imports'**
  String get entryImports;

  /// No description provided for @entryImportsShort.
  ///
  /// In en, this message translates to:
  /// **'Import a statement'**
  String get entryImportsShort;

  /// No description provided for @entryImportsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Bring in transactions from your bank\'s CSV, XLSX or OFX file'**
  String get entryImportsSubtitle;

  /// No description provided for @entryAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get entryAnalytics;

  /// No description provided for @entryAnalyticsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Cash flow, spending and trends, one currency at a time'**
  String get entryAnalyticsSubtitle;

  /// No description provided for @entryReports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get entryReports;

  /// No description provided for @entryReportsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Summaries and exports to download or schedule'**
  String get entryReportsSubtitle;

  /// No description provided for @entryExchangeRates.
  ///
  /// In en, this message translates to:
  /// **'Exchange rates'**
  String get entryExchangeRates;

  /// No description provided for @entryExchangeRatesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Rates between currencies, including your own'**
  String get entryExchangeRatesSubtitle;

  /// No description provided for @profileDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Records and insights'**
  String get profileDataTitle;

  /// No description provided for @entryReconcile.
  ///
  /// In en, this message translates to:
  /// **'Reconcile'**
  String get entryReconcile;

  /// No description provided for @entryReconcileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Check this account against a statement'**
  String get entryReconcileSubtitle;

  /// No description provided for @entryImportStatement.
  ///
  /// In en, this message translates to:
  /// **'Import a statement'**
  String get entryImportStatement;

  /// No description provided for @billNoChanges.
  ///
  /// In en, this message translates to:
  /// **'Nothing changed.'**
  String get billNoChanges;

  /// No description provided for @billScheduleUnknown.
  ///
  /// In en, this message translates to:
  /// **'This bill repeats in a way this version of Montra can\'t show. Update the app to change when it\'s due; you can still edit the other details.'**
  String get billScheduleUnknown;

  /// No description provided for @billReasonSameProvider.
  ///
  /// In en, this message translates to:
  /// **'Same provider'**
  String get billReasonSameProvider;

  /// No description provided for @billReasonSameAmount.
  ///
  /// In en, this message translates to:
  /// **'Same amount'**
  String get billReasonSameAmount;

  /// No description provided for @billReasonAmountClose.
  ///
  /// In en, this message translates to:
  /// **'Close to the expected amount'**
  String get billReasonAmountClose;

  /// No description provided for @billReasonOnDueDate.
  ///
  /// In en, this message translates to:
  /// **'Paid on the due date'**
  String get billReasonOnDueDate;

  /// No description provided for @billReasonDaysBefore.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day before the due date} other{{count} days before the due date}}'**
  String billReasonDaysBefore(int count);

  /// No description provided for @billReasonDaysAfter.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day after the due date} other{{count} days after the due date}}'**
  String billReasonDaysAfter(int count);

  /// No description provided for @billReasonOther.
  ///
  /// In en, this message translates to:
  /// **'Looks similar'**
  String get billReasonOther;

  /// No description provided for @recurringNoChanges.
  ///
  /// In en, this message translates to:
  /// **'Nothing changed.'**
  String get recurringNoChanges;

  /// No description provided for @recurringScheduleUnknown.
  ///
  /// In en, this message translates to:
  /// **'This repeats in a way this version of Montra can\'t show. Update the app to change its schedule; you can still edit the other details.'**
  String get recurringScheduleUnknown;

  /// No description provided for @occurrenceMovedTo.
  ///
  /// In en, this message translates to:
  /// **'Moved to {date}'**
  String occurrenceMovedTo(String date);

  /// No description provided for @calendarStatusTarget.
  ///
  /// In en, this message translates to:
  /// **'Target date'**
  String get calendarStatusTarget;

  /// No description provided for @subscriptionNoChanges.
  ///
  /// In en, this message translates to:
  /// **'Nothing changed.'**
  String get subscriptionNoChanges;

  /// No description provided for @subscriptionCancelledOnHelp.
  ///
  /// In en, this message translates to:
  /// **'Correct the date the cancellation took effect, if needed.'**
  String get subscriptionCancelledOnHelp;

  /// No description provided for @subscriptionCancelledOnPickHelp.
  ///
  /// In en, this message translates to:
  /// **'When the provider confirmed it. Today unless you change it.'**
  String get subscriptionCancelledOnPickHelp;

  /// No description provided for @subscriptionEventPaymentUnlinked.
  ///
  /// In en, this message translates to:
  /// **'Payment unlinked'**
  String get subscriptionEventPaymentUnlinked;

  /// No description provided for @subscriptionEventRenewed.
  ///
  /// In en, this message translates to:
  /// **'Renewed'**
  String get subscriptionEventRenewed;

  /// No description provided for @subscriptionNoteMatchedByDetection.
  ///
  /// In en, this message translates to:
  /// **'Linked when you added this subscription from your transactions'**
  String get subscriptionNoteMatchedByDetection;

  /// No description provided for @subscriptionLinkedPaymentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Linked payments'**
  String get subscriptionLinkedPaymentsTitle;

  /// No description provided for @subscriptionUnlinkPayment.
  ///
  /// In en, this message translates to:
  /// **'Unlink'**
  String get subscriptionUnlinkPayment;

  /// No description provided for @subscriptionUnlinkPaymentLabel.
  ///
  /// In en, this message translates to:
  /// **'Unlink the payment of {date}'**
  String subscriptionUnlinkPaymentLabel(String date);

  /// No description provided for @subscriptionUnlinkConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlink this payment?'**
  String get subscriptionUnlinkConfirmTitle;

  /// No description provided for @subscriptionUnlinkConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'The transaction stays as it is. It just won\'t count as a payment for {name} any more, and you can link it again later.'**
  String subscriptionUnlinkConfirmBody(String name);

  /// No description provided for @subscriptionPaymentUnlinked.
  ///
  /// In en, this message translates to:
  /// **'Payment unlinked.'**
  String get subscriptionPaymentUnlinked;

  /// No description provided for @subscriptionCandidatesIntro.
  ///
  /// In en, this message translates to:
  /// **'Charges that look like this subscription\'s payment. Choose one, or pick another transaction.'**
  String get subscriptionCandidatesIntro;

  /// No description provided for @subscriptionCandidatesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No matching charges found. Choose another transaction.'**
  String get subscriptionCandidatesEmpty;

  /// No description provided for @subscriptionCandidatesError.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t load suggested charges.'**
  String get subscriptionCandidatesError;

  /// No description provided for @subscriptionChooseOtherCharge.
  ///
  /// In en, this message translates to:
  /// **'Choose another transaction'**
  String get subscriptionChooseOtherCharge;

  /// No description provided for @subscriptionCandidateExpected.
  ///
  /// In en, this message translates to:
  /// **'Expected around {date}'**
  String subscriptionCandidateExpected(String date);

  /// No description provided for @subscriptionReasonSameMerchant.
  ///
  /// In en, this message translates to:
  /// **'Same merchant'**
  String get subscriptionReasonSameMerchant;

  /// No description provided for @subscriptionReasonMatchesName.
  ///
  /// In en, this message translates to:
  /// **'Matches the name'**
  String get subscriptionReasonMatchesName;

  /// No description provided for @subscriptionReasonSameAmount.
  ///
  /// In en, this message translates to:
  /// **'Same amount'**
  String get subscriptionReasonSameAmount;

  /// No description provided for @subscriptionReasonAmountClose.
  ///
  /// In en, this message translates to:
  /// **'Close to the price'**
  String get subscriptionReasonAmountClose;

  /// No description provided for @subscriptionReasonOnRenewalDate.
  ///
  /// In en, this message translates to:
  /// **'On the renewal date'**
  String get subscriptionReasonOnRenewalDate;

  /// No description provided for @subscriptionReasonDaysBefore.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day before the renewal date} other{{count} days before the renewal date}}'**
  String subscriptionReasonDaysBefore(int count);

  /// No description provided for @subscriptionReasonDaysAfter.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day after the renewal date} other{{count} days after the renewal date}}'**
  String subscriptionReasonDaysAfter(int count);

  /// No description provided for @subscriptionReasonOther.
  ///
  /// In en, this message translates to:
  /// **'Looks similar'**
  String get subscriptionReasonOther;

  /// No description provided for @subscriptionListCapped.
  ///
  /// In en, this message translates to:
  /// **'Showing the first {count} subscriptions.'**
  String subscriptionListCapped(int count);

  /// No description provided for @subscriptionChecklistUpdated.
  ///
  /// In en, this message translates to:
  /// **'Checklist updated.'**
  String get subscriptionChecklistUpdated;

  /// No description provided for @detectionReasonIntervals.
  ///
  /// In en, this message translates to:
  /// **'{fit} of {total} gaps between charges fit this pattern'**
  String detectionReasonIntervals(int fit, int total);

  /// No description provided for @detectionReasonAmounts.
  ///
  /// In en, this message translates to:
  /// **'{within} of {count} amounts are within {percent}% of the usual amount'**
  String detectionReasonAmounts(int within, int count, String percent);

  /// No description provided for @budgetSharedByEditor.
  ///
  /// In en, this message translates to:
  /// **'Shared by {name} · can edit'**
  String budgetSharedByEditor(String name);

  /// No description provided for @budgetSharedByViewer.
  ///
  /// In en, this message translates to:
  /// **'Shared by {name} · can view'**
  String budgetSharedByViewer(String name);

  /// No description provided for @budgetThresholdsNone.
  ///
  /// In en, this message translates to:
  /// **'No threshold alerts'**
  String get budgetThresholdsNone;

  /// No description provided for @budgetThresholdsChooseHelp.
  ///
  /// In en, this message translates to:
  /// **'Choose up to {max} levels. With none chosen, you won\'t get alerts for reaching a share of the limit.'**
  String budgetThresholdsChooseHelp(int max);

  /// No description provided for @budgetThresholdsClear.
  ///
  /// In en, this message translates to:
  /// **'Turn off threshold alerts'**
  String get budgetThresholdsClear;

  /// No description provided for @budgetTransactionsShowing.
  ///
  /// In en, this message translates to:
  /// **'Showing {shown} of {total}'**
  String budgetTransactionsShowing(int shown, int total);

  /// No description provided for @budgetMemberCannotAdd.
  ///
  /// In en, this message translates to:
  /// **'This person can\'t be added. You can share budgets with friends and members of your groups.'**
  String get budgetMemberCannotAdd;

  /// No description provided for @budgetMemberShareInvalid.
  ///
  /// In en, this message translates to:
  /// **'Check their share of the limit.'**
  String get budgetMemberShareInvalid;

  /// No description provided for @budgetNothingChanged.
  ///
  /// In en, this message translates to:
  /// **'Nothing changed, so there was nothing to save.'**
  String get budgetNothingChanged;

  /// No description provided for @budgetTypeGroupChoiceHelp.
  ///
  /// In en, this message translates to:
  /// **'Group budgets count all of the group\'s expenses: as one total, or split between members as envelopes or zero-based.'**
  String get budgetTypeGroupChoiceHelp;

  /// No description provided for @budgetAllocationsGroupHelp.
  ///
  /// In en, this message translates to:
  /// **'Optionally split the limit between current members of the group.'**
  String get budgetAllocationsGroupHelp;

  /// No description provided for @budgetAllocationsMerchantHelp.
  ///
  /// In en, this message translates to:
  /// **'Optional limits by category, by merchant or with a name of your own.'**
  String get budgetAllocationsMerchantHelp;

  /// No description provided for @budgetAllocationsAccountHelp.
  ///
  /// In en, this message translates to:
  /// **'Optional limits by category, by account or with a name of your own.'**
  String get budgetAllocationsAccountHelp;

  /// No description provided for @budgetAllocationOver.
  ///
  /// In en, this message translates to:
  /// **'{spent} spent of {limit} · {over} over'**
  String budgetAllocationOver(String spent, String limit, String over);

  /// No description provided for @budgetTransactionsOwnerOnlyError.
  ///
  /// In en, this message translates to:
  /// **'Only the owner can see the individual transactions. You see the owner\'s totals.'**
  String get budgetTransactionsOwnerOnlyError;

  /// No description provided for @goalMemberRoleOwner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get goalMemberRoleOwner;

  /// No description provided for @goalSharedBy.
  ///
  /// In en, this message translates to:
  /// **'Shared by {name}'**
  String goalSharedBy(String name);

  /// No description provided for @goalAssumptionExact.
  ///
  /// In en, this message translates to:
  /// **'Amounts are exact in {currency}; no interest, returns or inflation are assumed.'**
  String goalAssumptionExact(String currency);

  /// No description provided for @goalAssumptionPace.
  ///
  /// In en, this message translates to:
  /// **'Recent pace is the net of recorded and verified contributions in the last {days} days, divided by {months}.'**
  String goalAssumptionPace(String days, String months);

  /// No description provided for @goalAssumptionPlanned.
  ///
  /// In en, this message translates to:
  /// **'Planned contributions are intentions, not money set aside, so they aren\'t counted as saved.'**
  String get goalAssumptionPlanned;

  /// No description provided for @goalCurrencyFixed.
  ///
  /// In en, this message translates to:
  /// **'The currency can\'t change after the goal is created.'**
  String get goalCurrencyFixed;

  /// No description provided for @goalNothingChanged.
  ///
  /// In en, this message translates to:
  /// **'Nothing changed, so there was nothing to save.'**
  String get goalNothingChanged;

  /// No description provided for @goalOwnerNote.
  ///
  /// In en, this message translates to:
  /// **'You own this goal. You can\'t leave it, but you can choose what others see of your contributions.'**
  String get goalOwnerNote;

  /// No description provided for @goalExportIntroShare.
  ///
  /// In en, this message translates to:
  /// **'This CSV lists every contribution, including voided ones. Share it, save it to your device or copy it.'**
  String get goalExportIntroShare;

  /// No description provided for @contributionRecord.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get contributionRecord;

  /// No description provided for @contributionRecordTooltip.
  ///
  /// In en, this message translates to:
  /// **'Record your planned contribution of {date}'**
  String contributionRecordTooltip(String date);

  /// No description provided for @contributionRecordTitle.
  ///
  /// In en, this message translates to:
  /// **'Record this planned contribution'**
  String get contributionRecordTitle;

  /// No description provided for @contributionRecordIntro.
  ///
  /// In en, this message translates to:
  /// **'It will count as saved. Change the amount if you set aside a different amount, and link the transaction that moved the money to verify it.'**
  String get contributionRecordIntro;

  /// No description provided for @contributionRecordAmountHelp.
  ///
  /// In en, this message translates to:
  /// **'Leave as it is if you set aside the planned amount.'**
  String get contributionRecordAmountHelp;

  /// No description provided for @contributionRecordSave.
  ///
  /// In en, this message translates to:
  /// **'Record contribution'**
  String get contributionRecordSave;

  /// No description provided for @contributionRecordedDone.
  ///
  /// In en, this message translates to:
  /// **'Contribution recorded.'**
  String get contributionRecordedDone;

  /// No description provided for @mergeAffectedBudgetFilters.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 budget will follow the merge} other{{count} budgets will follow the merge}}'**
  String mergeAffectedBudgetFilters(int count);

  /// No description provided for @mergeAffectedAliases.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 other name} other{{count} other names}}'**
  String mergeAffectedAliases(int count);

  /// No description provided for @merchantMergePreviewBody.
  ///
  /// In en, this message translates to:
  /// **'These move to “{target}”:\n{moves}\n\n“{source}” will then be marked as merged and its names kept as other names of “{target}”. This can\'t be undone.'**
  String merchantMergePreviewBody(String target, String moves, String source);

  /// No description provided for @merchantMergePreviewNothing.
  ///
  /// In en, this message translates to:
  /// **'Nothing uses “{source}” yet. It will be marked as merged into “{target}”. This can\'t be undone.'**
  String merchantMergePreviewNothing(String source, String target);

  /// No description provided for @merchantAliasRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get merchantAliasRemove;

  /// No description provided for @merchantAliasRemoveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove the other name “{alias}”'**
  String merchantAliasRemoveTooltip(String alias);

  /// No description provided for @merchantAliasRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove “{alias}”?'**
  String merchantAliasRemoveTitle(String alias);

  /// No description provided for @merchantAliasRemoveBody.
  ///
  /// In en, this message translates to:
  /// **'New transactions with this name won\'t be matched to {name}. Transactions already matched stay as they are.'**
  String merchantAliasRemoveBody(String name);

  /// No description provided for @merchantAliasRemoved.
  ///
  /// In en, this message translates to:
  /// **'“{alias}” removed.'**
  String merchantAliasRemoved(String alias);

  /// No description provided for @merchantOpenMergedInto.
  ///
  /// In en, this message translates to:
  /// **'Open the merchant it was merged into'**
  String get merchantOpenMergedInto;

  /// No description provided for @merchantStatusMerged.
  ///
  /// In en, this message translates to:
  /// **'Merged'**
  String get merchantStatusMerged;

  /// No description provided for @merchantsFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Show merchants'**
  String get merchantsFilterLabel;

  /// No description provided for @merchantsFilterActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get merchantsFilterActive;

  /// No description provided for @merchantsFilterArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get merchantsFilterArchived;

  /// No description provided for @merchantsFilterMerged.
  ///
  /// In en, this message translates to:
  /// **'Merged'**
  String get merchantsFilterMerged;

  /// No description provided for @merchantsFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get merchantsFilterAll;

  /// No description provided for @merchantsEmptyFiltered.
  ///
  /// In en, this message translates to:
  /// **'No merchants here.'**
  String get merchantsEmptyFiltered;

  /// No description provided for @ruleCurrencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Currency of the amounts'**
  String get ruleCurrencyLabel;

  /// No description provided for @ruleAmountCurrencyNote.
  ///
  /// In en, this message translates to:
  /// **'Amount limits match only transactions in {currency}.'**
  String ruleAmountCurrencyNote(String currency);

  /// No description provided for @ruleAmountsBetween.
  ///
  /// In en, this message translates to:
  /// **'Amounts from {min} to {max}'**
  String ruleAmountsBetween(String min, String max);

  /// No description provided for @ruleAmountsAtLeast.
  ///
  /// In en, this message translates to:
  /// **'Amounts of {min} or more'**
  String ruleAmountsAtLeast(String min);

  /// No description provided for @ruleAmountsAtMost.
  ///
  /// In en, this message translates to:
  /// **'Amounts up to {max}'**
  String ruleAmountsAtMost(String max);

  /// No description provided for @rulePriorityOptionalHelp.
  ///
  /// In en, this message translates to:
  /// **'Optional: 0 to 10000. Lower numbers run first and the first matching rule wins. Empty means 100.'**
  String get rulePriorityOptionalHelp;

  /// No description provided for @attachmentAdd.
  ///
  /// In en, this message translates to:
  /// **'Add file'**
  String get attachmentAdd;

  /// No description provided for @attachmentAdded.
  ///
  /// In en, this message translates to:
  /// **'File attached.'**
  String get attachmentAdded;

  /// No description provided for @attachmentsEmptyAdd.
  ///
  /// In en, this message translates to:
  /// **'No files are attached. Add a photo or a PDF, such as a bill or a warranty.'**
  String get attachmentsEmptyAdd;

  /// No description provided for @attachmentReceiptLink.
  ///
  /// In en, this message translates to:
  /// **'Receipt'**
  String get attachmentReceiptLink;

  /// No description provided for @attachmentReceiptLinkHelp.
  ///
  /// In en, this message translates to:
  /// **'This transaction was recorded from a receipt.'**
  String get attachmentReceiptLinkHelp;

  /// No description provided for @receiptsTitle.
  ///
  /// In en, this message translates to:
  /// **'Receipts'**
  String get receiptsTitle;

  /// No description provided for @receiptAdd.
  ///
  /// In en, this message translates to:
  /// **'Add receipt'**
  String get receiptAdd;

  /// No description provided for @receiptAdded.
  ///
  /// In en, this message translates to:
  /// **'Receipt added. Enter its details next.'**
  String get receiptAdded;

  /// No description provided for @receiptUploadTitle.
  ///
  /// In en, this message translates to:
  /// **'Uploading'**
  String get receiptUploadTitle;

  /// No description provided for @receiptsManualNote.
  ///
  /// In en, this message translates to:
  /// **'Montra never reads receipts automatically: you type the details, then link the receipt to an expense or record a new one.'**
  String get receiptsManualNote;

  /// No description provided for @receiptsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No receipts yet'**
  String get receiptsEmptyTitle;

  /// No description provided for @receiptsEmptyFiltered.
  ///
  /// In en, this message translates to:
  /// **'No receipts here'**
  String get receiptsEmptyFiltered;

  /// No description provided for @receiptsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Take a photo of a receipt or choose a photo or PDF. You enter the details yourself.'**
  String get receiptsEmptyBody;

  /// No description provided for @receiptFilterOpen.
  ///
  /// In en, this message translates to:
  /// **'In inbox'**
  String get receiptFilterOpen;

  /// No description provided for @receiptFilterToReview.
  ///
  /// In en, this message translates to:
  /// **'To fill in'**
  String get receiptFilterToReview;

  /// No description provided for @receiptFilterReviewed.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get receiptFilterReviewed;

  /// No description provided for @receiptFilterLinked.
  ///
  /// In en, this message translates to:
  /// **'Linked'**
  String get receiptFilterLinked;

  /// No description provided for @receiptFilterDiscarded.
  ///
  /// In en, this message translates to:
  /// **'Discarded'**
  String get receiptFilterDiscarded;

  /// No description provided for @receiptUntitled.
  ///
  /// In en, this message translates to:
  /// **'Receipt'**
  String get receiptUntitled;

  /// No description provided for @receiptNoDetails.
  ///
  /// In en, this message translates to:
  /// **'Details not entered yet'**
  String get receiptNoDetails;

  /// No description provided for @receiptPages.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 page} other{{count} pages}}'**
  String receiptPages(int count);

  /// No description provided for @receiptPossibleDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Possible duplicate'**
  String get receiptPossibleDuplicate;

  /// No description provided for @receiptStatusUploaded.
  ///
  /// In en, this message translates to:
  /// **'Uploaded'**
  String get receiptStatusUploaded;

  /// No description provided for @receiptStatusProcessing.
  ///
  /// In en, this message translates to:
  /// **'Being processed'**
  String get receiptStatusProcessing;

  /// No description provided for @receiptStatusNeedsReview.
  ///
  /// In en, this message translates to:
  /// **'Details needed'**
  String get receiptStatusNeedsReview;

  /// No description provided for @receiptStatusReviewed.
  ///
  /// In en, this message translates to:
  /// **'Ready to record'**
  String get receiptStatusReviewed;

  /// No description provided for @receiptStatusMatched.
  ///
  /// In en, this message translates to:
  /// **'Linked to a transaction'**
  String get receiptStatusMatched;

  /// No description provided for @receiptStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t be read'**
  String get receiptStatusFailed;

  /// No description provided for @receiptStatusDiscarded.
  ///
  /// In en, this message translates to:
  /// **'Discarded'**
  String get receiptStatusDiscarded;

  /// No description provided for @receiptStatusOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get receiptStatusOther;

  /// No description provided for @receiptHelpNeedsReview.
  ///
  /// In en, this message translates to:
  /// **'Enter the details from the receipt so you can link it to an expense or record it.'**
  String get receiptHelpNeedsReview;

  /// No description provided for @receiptHelpReviewed.
  ///
  /// In en, this message translates to:
  /// **'Link it to an expense you already recorded, or record it as a new expense.'**
  String get receiptHelpReviewed;

  /// No description provided for @receiptHelpMatched.
  ///
  /// In en, this message translates to:
  /// **'This receipt is linked to a transaction. Its pages are attached to that transaction.'**
  String get receiptHelpMatched;

  /// No description provided for @receiptHelpDiscarded.
  ///
  /// In en, this message translates to:
  /// **'This receipt was removed from your inbox. Its files are kept until you delete them.'**
  String get receiptHelpDiscarded;

  /// No description provided for @receiptHelpProcessing.
  ///
  /// In en, this message translates to:
  /// **'This receipt is being processed. Pull down to refresh.'**
  String get receiptHelpProcessing;

  /// No description provided for @receiptTitle.
  ///
  /// In en, this message translates to:
  /// **'Receipt'**
  String get receiptTitle;

  /// No description provided for @receiptEnterDetails.
  ///
  /// In en, this message translates to:
  /// **'Enter details'**
  String get receiptEnterDetails;

  /// No description provided for @receiptEditDetails.
  ///
  /// In en, this message translates to:
  /// **'Edit details'**
  String get receiptEditDetails;

  /// No description provided for @receiptMatchAction.
  ///
  /// In en, this message translates to:
  /// **'Find the expense'**
  String get receiptMatchAction;

  /// No description provided for @receiptRecordAction.
  ///
  /// In en, this message translates to:
  /// **'Record as a new expense'**
  String get receiptRecordAction;

  /// No description provided for @receiptOpenTransaction.
  ///
  /// In en, this message translates to:
  /// **'Open the transaction'**
  String get receiptOpenTransaction;

  /// No description provided for @receiptUnlink.
  ///
  /// In en, this message translates to:
  /// **'Unlink'**
  String get receiptUnlink;

  /// No description provided for @receiptUnlinkConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlink this receipt?'**
  String get receiptUnlinkConfirmTitle;

  /// No description provided for @receiptUnlinkConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'The transaction stays as it is; only the receipt pages are removed from it. You can link the receipt again later.'**
  String get receiptUnlinkConfirmBody;

  /// No description provided for @receiptUnlinked.
  ///
  /// In en, this message translates to:
  /// **'Receipt unlinked.'**
  String get receiptUnlinked;

  /// No description provided for @receiptDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get receiptDiscard;

  /// No description provided for @receiptDiscardConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard this receipt?'**
  String get receiptDiscardConfirmTitle;

  /// No description provided for @receiptDiscarded.
  ///
  /// In en, this message translates to:
  /// **'Receipt discarded.'**
  String get receiptDiscarded;

  /// No description provided for @receiptDuplicateNotice.
  ///
  /// In en, this message translates to:
  /// **'This looks like a receipt you already added.'**
  String get receiptDuplicateNotice;

  /// No description provided for @receiptOpenOther.
  ///
  /// In en, this message translates to:
  /// **'Open the other receipt'**
  String get receiptOpenOther;

  /// No description provided for @receiptWarningArithmetic.
  ///
  /// In en, this message translates to:
  /// **'The subtotal, tax, tip and discount don\'t add up to the total. Check the numbers.'**
  String get receiptWarningArithmetic;

  /// No description provided for @receiptWarningLineItems.
  ///
  /// In en, this message translates to:
  /// **'The items don\'t add up to the subtotal. Check the numbers.'**
  String get receiptWarningLineItems;

  /// No description provided for @receiptPagesTitle.
  ///
  /// In en, this message translates to:
  /// **'Pages'**
  String get receiptPagesTitle;

  /// No description provided for @receiptNoPages.
  ///
  /// In en, this message translates to:
  /// **'This receipt has no pages.'**
  String get receiptNoPages;

  /// No description provided for @receiptPageLabel.
  ///
  /// In en, this message translates to:
  /// **'Receipt page {index} of {count}'**
  String receiptPageLabel(int index, int count);

  /// No description provided for @receiptOpenPage.
  ///
  /// In en, this message translates to:
  /// **'Open page {index}'**
  String receiptOpenPage(int index);

  /// No description provided for @receiptPdfPage.
  ///
  /// In en, this message translates to:
  /// **'PDF – opens with Share or Save'**
  String get receiptPdfPage;

  /// No description provided for @receiptFilePage.
  ///
  /// In en, this message translates to:
  /// **'File – opens with Share or Save'**
  String get receiptFilePage;

  /// No description provided for @receiptPreviewUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This picture can\'t be shown.'**
  String get receiptPreviewUnavailable;

  /// No description provided for @receiptPdfHelp.
  ///
  /// In en, this message translates to:
  /// **'PDF files open in another app. Use Share or Save.'**
  String get receiptPdfHelp;

  /// No description provided for @receiptFileHelp.
  ///
  /// In en, this message translates to:
  /// **'This file can\'t be shown in Montra. Use Share or Save.'**
  String get receiptFileHelp;

  /// No description provided for @receiptDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get receiptDetailsTitle;

  /// No description provided for @receiptMerchant.
  ///
  /// In en, this message translates to:
  /// **'Shop or merchant'**
  String get receiptMerchant;

  /// No description provided for @receiptMerchantHelp.
  ///
  /// In en, this message translates to:
  /// **'As printed on the receipt.'**
  String get receiptMerchantHelp;

  /// No description provided for @receiptDate.
  ///
  /// In en, this message translates to:
  /// **'Date on the receipt'**
  String get receiptDate;

  /// No description provided for @receiptDateChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose a date'**
  String get receiptDateChoose;

  /// No description provided for @receiptDateRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose the date on the receipt.'**
  String get receiptDateRequired;

  /// No description provided for @receiptTime.
  ///
  /// In en, this message translates to:
  /// **'Time (optional)'**
  String get receiptTime;

  /// No description provided for @receiptTimeNone.
  ///
  /// In en, this message translates to:
  /// **'No time'**
  String get receiptTimeNone;

  /// No description provided for @receiptCurrency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get receiptCurrency;

  /// No description provided for @receiptCurrencyHelp.
  ///
  /// In en, this message translates to:
  /// **'The currency printed on the receipt.'**
  String get receiptCurrencyHelp;

  /// No description provided for @receiptTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get receiptTotal;

  /// No description provided for @receiptSubtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get receiptSubtotal;

  /// No description provided for @receiptTax.
  ///
  /// In en, this message translates to:
  /// **'Tax'**
  String get receiptTax;

  /// No description provided for @receiptTip.
  ///
  /// In en, this message translates to:
  /// **'Tip'**
  String get receiptTip;

  /// No description provided for @receiptDiscount.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get receiptDiscount;

  /// No description provided for @receiptNumber.
  ///
  /// In en, this message translates to:
  /// **'Receipt number'**
  String get receiptNumber;

  /// No description provided for @receiptPaymentHint.
  ///
  /// In en, this message translates to:
  /// **'How you paid'**
  String get receiptPaymentHint;

  /// No description provided for @receiptLinkedTransaction.
  ///
  /// In en, this message translates to:
  /// **'Linked transaction'**
  String get receiptLinkedTransaction;

  /// No description provided for @receiptLineItemsTitle.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get receiptLineItemsTitle;

  /// No description provided for @receiptLineItemUnnamed.
  ///
  /// In en, this message translates to:
  /// **'Item {position}'**
  String receiptLineItemUnnamed(int position);

  /// No description provided for @receiptQuantityValue.
  ///
  /// In en, this message translates to:
  /// **'Quantity {quantity}'**
  String receiptQuantityValue(String quantity);

  /// No description provided for @receiptUnitPriceValue.
  ///
  /// In en, this message translates to:
  /// **'{price} each'**
  String receiptUnitPriceValue(String price);

  /// No description provided for @receiptTaxValue.
  ///
  /// In en, this message translates to:
  /// **'Tax {tax}'**
  String receiptTaxValue(String tax);

  /// No description provided for @receiptNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get receiptNotes;

  /// No description provided for @receiptHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Versions'**
  String get receiptHistoryTitle;

  /// No description provided for @receiptVersionTitle.
  ///
  /// In en, this message translates to:
  /// **'Version {version} · {method}'**
  String receiptVersionTitle(int version, String method);

  /// No description provided for @receiptMethodManual.
  ///
  /// In en, this message translates to:
  /// **'entered by you'**
  String get receiptMethodManual;

  /// No description provided for @receiptMethodAutomatic.
  ///
  /// In en, this message translates to:
  /// **'read from the file'**
  String get receiptMethodAutomatic;

  /// No description provided for @receiptReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Receipt details'**
  String get receiptReviewTitle;

  /// No description provided for @receiptReviewIntro.
  ///
  /// In en, this message translates to:
  /// **'Type the details as they appear on the receipt. Only the date and the total are required.'**
  String get receiptReviewIntro;

  /// No description provided for @receiptReviewUnavailable.
  ///
  /// In en, this message translates to:
  /// **'These details can\'t be changed now'**
  String get receiptReviewUnavailable;

  /// No description provided for @receiptBreakdownTitle.
  ///
  /// In en, this message translates to:
  /// **'Breakdown (optional)'**
  String get receiptBreakdownTitle;

  /// No description provided for @receiptBreakdownHelp.
  ///
  /// In en, this message translates to:
  /// **'Add these if the receipt shows them. Montra tells you if they don\'t add up.'**
  String get receiptBreakdownHelp;

  /// No description provided for @receiptAddLineItem.
  ///
  /// In en, this message translates to:
  /// **'Add an item'**
  String get receiptAddLineItem;

  /// No description provided for @receiptLineItemTitle.
  ///
  /// In en, this message translates to:
  /// **'Item {index}'**
  String receiptLineItemTitle(int index);

  /// No description provided for @receiptRemoveLineItem.
  ///
  /// In en, this message translates to:
  /// **'Remove item {index}'**
  String receiptRemoveLineItem(int index);

  /// No description provided for @receiptLineDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get receiptLineDescription;

  /// No description provided for @receiptQuantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get receiptQuantity;

  /// No description provided for @receiptQuantityInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a number, with up to 3 decimals.'**
  String get receiptQuantityInvalid;

  /// No description provided for @receiptUnitPrice.
  ///
  /// In en, this message translates to:
  /// **'Price each'**
  String get receiptUnitPrice;

  /// No description provided for @receiptLineAmount.
  ///
  /// In en, this message translates to:
  /// **'Item amount'**
  String get receiptLineAmount;

  /// No description provided for @receiptLineTax.
  ///
  /// In en, this message translates to:
  /// **'Item tax'**
  String get receiptLineTax;

  /// No description provided for @receiptReviewSave.
  ///
  /// In en, this message translates to:
  /// **'Save details'**
  String get receiptReviewSave;

  /// No description provided for @receiptReviewSaved.
  ///
  /// In en, this message translates to:
  /// **'Receipt details saved.'**
  String get receiptReviewSaved;

  /// No description provided for @receiptMatchTitle.
  ///
  /// In en, this message translates to:
  /// **'Find the expense'**
  String get receiptMatchTitle;

  /// No description provided for @receiptMatchIntro.
  ///
  /// In en, this message translates to:
  /// **'These recorded expenses are close in amount and date. Linking records no new money.'**
  String get receiptMatchIntro;

  /// No description provided for @receiptMatchNone.
  ///
  /// In en, this message translates to:
  /// **'No recorded expense looks like this receipt. Choose one yourself, or record a new expense.'**
  String get receiptMatchNone;

  /// No description provided for @receiptChooseTransaction.
  ///
  /// In en, this message translates to:
  /// **'Choose another expense'**
  String get receiptChooseTransaction;

  /// No description provided for @receiptLinkThis.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get receiptLinkThis;

  /// No description provided for @receiptLinked.
  ///
  /// In en, this message translates to:
  /// **'Receipt linked to the expense.'**
  String get receiptLinked;

  /// No description provided for @receiptUnnamedTransaction.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get receiptUnnamedTransaction;

  /// No description provided for @receiptCandidateAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get receiptCandidateAmount;

  /// No description provided for @receiptReasonSameAmount.
  ///
  /// In en, this message translates to:
  /// **'same amount as the total'**
  String get receiptReasonSameAmount;

  /// No description provided for @receiptReasonCloseAmount.
  ///
  /// In en, this message translates to:
  /// **'amount within 20% of the total (tip or fees)'**
  String get receiptReasonCloseAmount;

  /// No description provided for @receiptReasonSameDate.
  ///
  /// In en, this message translates to:
  /// **'same date'**
  String get receiptReasonSameDate;

  /// No description provided for @receiptReasonNearDate.
  ///
  /// In en, this message translates to:
  /// **'within 3 days'**
  String get receiptReasonNearDate;

  /// No description provided for @receiptReasonSameMerchant.
  ///
  /// In en, this message translates to:
  /// **'same merchant'**
  String get receiptReasonSameMerchant;

  /// No description provided for @receiptRecordTitle.
  ///
  /// In en, this message translates to:
  /// **'Record the expense'**
  String get receiptRecordTitle;

  /// No description provided for @receiptRecordIntro.
  ///
  /// In en, this message translates to:
  /// **'The amount, date and merchant come from the receipt details. Choose the account you paid from.'**
  String get receiptRecordIntro;

  /// No description provided for @receiptRecordUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This receipt can\'t be recorded yet'**
  String get receiptRecordUnavailable;

  /// No description provided for @receiptRecordAccount.
  ///
  /// In en, this message translates to:
  /// **'Paid from'**
  String get receiptRecordAccount;

  /// No description provided for @receiptRecordAccountHelp.
  ///
  /// In en, this message translates to:
  /// **'Accounts in {currency}, the receipt currency.'**
  String receiptRecordAccountHelp(String currency);

  /// No description provided for @receiptChooseAccount.
  ///
  /// In en, this message translates to:
  /// **'Choose an account'**
  String get receiptChooseAccount;

  /// No description provided for @receiptAccountRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose the account you paid from.'**
  String get receiptAccountRequired;

  /// No description provided for @receiptRecordCategory.
  ///
  /// In en, this message translates to:
  /// **'Category (optional)'**
  String get receiptRecordCategory;

  /// No description provided for @receiptRecordDescription.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get receiptRecordDescription;

  /// No description provided for @receiptRecordDescriptionHelp.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to use the merchant name.'**
  String get receiptRecordDescriptionHelp;

  /// No description provided for @receiptRecordSave.
  ///
  /// In en, this message translates to:
  /// **'Record expense'**
  String get receiptRecordSave;

  /// No description provided for @receiptRecorded.
  ///
  /// In en, this message translates to:
  /// **'Expense recorded from the receipt.'**
  String get receiptRecorded;

  /// No description provided for @importsTitle.
  ///
  /// In en, this message translates to:
  /// **'Statement imports'**
  String get importsTitle;

  /// No description provided for @importNew.
  ///
  /// In en, this message translates to:
  /// **'Import a statement'**
  String get importNew;

  /// No description provided for @importsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No imports yet'**
  String get importsEmptyTitle;

  /// No description provided for @importsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Import your bank\'s CSV, XLSX or OFX statement. You check every row before anything is added.'**
  String get importsEmptyBody;

  /// No description provided for @importsForAccount.
  ///
  /// In en, this message translates to:
  /// **'Imports into {account}'**
  String importsForAccount(String account);

  /// No description provided for @importsShowAll.
  ///
  /// In en, this message translates to:
  /// **'Show all accounts'**
  String get importsShowAll;

  /// No description provided for @importUnknownAccount.
  ///
  /// In en, this message translates to:
  /// **'Account not available'**
  String get importUnknownAccount;

  /// No description provided for @importStartedOn.
  ///
  /// In en, this message translates to:
  /// **'Started {time}'**
  String importStartedOn(String time);

  /// No description provided for @importCountsSummary.
  ///
  /// In en, this message translates to:
  /// **'{imported} imported · {skipped} skipped · {failed} failed'**
  String importCountsSummary(int imported, int skipped, int failed);

  /// No description provided for @importWizardTitle.
  ///
  /// In en, this message translates to:
  /// **'Import a statement'**
  String get importWizardTitle;

  /// No description provided for @importWizardIntro.
  ///
  /// In en, this message translates to:
  /// **'Choose the account and your bank\'s statement file. You will see every row before anything is added.'**
  String get importWizardIntro;

  /// No description provided for @importFormatsNote.
  ///
  /// In en, this message translates to:
  /// **'CSV, XLSX and OFX files work. PDF statements aren\'t supported: reading them needs AI, which Montra doesn\'t use. Most banks let you download CSV or XLSX.'**
  String get importFormatsNote;

  /// No description provided for @importStepAccount.
  ///
  /// In en, this message translates to:
  /// **'1. Account'**
  String get importStepAccount;

  /// No description provided for @importStepFile.
  ///
  /// In en, this message translates to:
  /// **'2. Statement file'**
  String get importStepFile;

  /// No description provided for @importAccountLabel.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get importAccountLabel;

  /// No description provided for @importChooseAccount.
  ///
  /// In en, this message translates to:
  /// **'Choose an account'**
  String get importChooseAccount;

  /// No description provided for @importAccountHelp.
  ///
  /// In en, this message translates to:
  /// **'Rows are added in the account\'s currency.'**
  String get importAccountHelp;

  /// No description provided for @importAccountRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose the account the statement belongs to.'**
  String get importAccountRequired;

  /// No description provided for @importFileLabel.
  ///
  /// In en, this message translates to:
  /// **'Statement file'**
  String get importFileLabel;

  /// No description provided for @importChooseFile.
  ///
  /// In en, this message translates to:
  /// **'Choose a file'**
  String get importChooseFile;

  /// No description provided for @importFileRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose the statement file.'**
  String get importFileRequired;

  /// No description provided for @importStart.
  ///
  /// In en, this message translates to:
  /// **'Upload and read'**
  String get importStart;

  /// No description provided for @importStatusReading.
  ///
  /// In en, this message translates to:
  /// **'Reading the file'**
  String get importStatusReading;

  /// No description provided for @importStatusNeedsMapping.
  ///
  /// In en, this message translates to:
  /// **'Columns needed'**
  String get importStatusNeedsMapping;

  /// No description provided for @importStatusPreviewReady.
  ///
  /// In en, this message translates to:
  /// **'Ready to review'**
  String get importStatusPreviewReady;

  /// No description provided for @importStatusImporting.
  ///
  /// In en, this message translates to:
  /// **'Importing'**
  String get importStatusImporting;

  /// No description provided for @importStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Imported'**
  String get importStatusCompleted;

  /// No description provided for @importStatusCompletedWithErrors.
  ///
  /// In en, this message translates to:
  /// **'Imported with problems'**
  String get importStatusCompletedWithErrors;

  /// No description provided for @importStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t import'**
  String get importStatusFailed;

  /// No description provided for @importStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get importStatusCancelled;

  /// No description provided for @importStatusOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get importStatusOther;

  /// No description provided for @importHelpReading.
  ///
  /// In en, this message translates to:
  /// **'Montra is reading your file. This usually takes a few seconds.'**
  String get importHelpReading;

  /// No description provided for @importHelpNeedsMapping.
  ///
  /// In en, this message translates to:
  /// **'Montra couldn\'t tell which column holds what. Choose the columns to continue.'**
  String get importHelpNeedsMapping;

  /// No description provided for @importHelpPreviewReady.
  ///
  /// In en, this message translates to:
  /// **'Check the rows, then import. Possible duplicates and rows you skip are left out.'**
  String get importHelpPreviewReady;

  /// No description provided for @importHelpImporting.
  ///
  /// In en, this message translates to:
  /// **'Your rows are being added. You can leave this screen.'**
  String get importHelpImporting;

  /// No description provided for @importHelpCompleted.
  ///
  /// In en, this message translates to:
  /// **'The rows were added to the account.'**
  String get importHelpCompleted;

  /// No description provided for @importHelpCompletedWithErrors.
  ///
  /// In en, this message translates to:
  /// **'Some rows couldn\'t be added. Fix them and try again, or leave them out.'**
  String get importHelpCompletedWithErrors;

  /// No description provided for @importHelpFailed.
  ///
  /// In en, this message translates to:
  /// **'Nothing was added to the account.'**
  String get importHelpFailed;

  /// No description provided for @importHelpCancelled.
  ///
  /// In en, this message translates to:
  /// **'This import was stopped. Rows imported before it stopped stay unless you roll them back.'**
  String get importHelpCancelled;

  /// No description provided for @importStillWorking.
  ///
  /// In en, this message translates to:
  /// **'Still working. Pull down to check again.'**
  String get importStillWorking;

  /// No description provided for @importCancelRequested.
  ///
  /// In en, this message translates to:
  /// **'Stopping after the current row.'**
  String get importCancelRequested;

  /// No description provided for @importErrorEmpty.
  ///
  /// In en, this message translates to:
  /// **'The file has no rows.'**
  String get importErrorEmpty;

  /// No description provided for @importErrorUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This file type can\'t be imported. Use CSV, XLSX or OFX from your bank.'**
  String get importErrorUnsupported;

  /// No description provided for @importErrorMalformed.
  ///
  /// In en, this message translates to:
  /// **'The file couldn\'t be read. Download it again from your bank.'**
  String get importErrorMalformed;

  /// No description provided for @importErrorTooManyRows.
  ///
  /// In en, this message translates to:
  /// **'The file has too many rows. Download a shorter period.'**
  String get importErrorTooManyRows;

  /// No description provided for @importErrorTooManyColumns.
  ///
  /// In en, this message translates to:
  /// **'The file has too many columns.'**
  String get importErrorTooManyColumns;

  /// No description provided for @importErrorCurrency.
  ///
  /// In en, this message translates to:
  /// **'The statement\'s currency doesn\'t match the account. Import it into an account in that currency.'**
  String get importErrorCurrency;

  /// No description provided for @importErrorFileUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The uploaded file is no longer available. Upload it again.'**
  String get importErrorFileUnavailable;

  /// No description provided for @importErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'The import couldn\'t finish.'**
  String get importErrorGeneric;

  /// No description provided for @importRolledBack.
  ///
  /// In en, this message translates to:
  /// **'This import was rolled back. Transactions changed after the import were kept.'**
  String get importRolledBack;

  /// No description provided for @importRolledBackCounts.
  ///
  /// In en, this message translates to:
  /// **'Rolled back: {removed} transactions removed, {kept} kept because they were changed or linked after the import.'**
  String importRolledBackCounts(int removed, int kept);

  /// No description provided for @importDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Statement import'**
  String get importDetailTitle;

  /// No description provided for @importChooseColumns.
  ///
  /// In en, this message translates to:
  /// **'Choose columns'**
  String get importChooseColumns;

  /// No description provided for @importChangeColumns.
  ///
  /// In en, this message translates to:
  /// **'Change columns'**
  String get importChangeColumns;

  /// No description provided for @importReviewRows.
  ///
  /// In en, this message translates to:
  /// **'Review rows'**
  String get importReviewRows;

  /// No description provided for @importSeeRows.
  ///
  /// In en, this message translates to:
  /// **'See rows'**
  String get importSeeRows;

  /// No description provided for @importReviewFailed.
  ///
  /// In en, this message translates to:
  /// **'Fix failed rows'**
  String get importReviewFailed;

  /// No description provided for @importRetryFailed.
  ///
  /// In en, this message translates to:
  /// **'Try failed rows again'**
  String get importRetryFailed;

  /// No description provided for @importRetrying.
  ///
  /// In en, this message translates to:
  /// **'Trying the failed rows again.'**
  String get importRetrying;

  /// No description provided for @importConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Import rows'**
  String get importConfirmAction;

  /// No description provided for @importConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Import these rows?'**
  String get importConfirmTitle;

  /// No description provided for @importConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Rows marked to import are added to {account}. Possible duplicates and rows you skipped are left out. You can roll the import back later.'**
  String importConfirmBody(String account);

  /// No description provided for @importConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Import started.'**
  String get importConfirmed;

  /// No description provided for @importCancelAction.
  ///
  /// In en, this message translates to:
  /// **'Cancel import'**
  String get importCancelAction;

  /// No description provided for @importCancelTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel this import?'**
  String get importCancelTitle;

  /// No description provided for @importCancelBody.
  ///
  /// In en, this message translates to:
  /// **'Nothing has been added yet, and nothing will be.'**
  String get importCancelBody;

  /// No description provided for @importCancelProcessingBody.
  ///
  /// In en, this message translates to:
  /// **'Montra stops after the current row. Rows already added stay unless you roll them back.'**
  String get importCancelProcessingBody;

  /// No description provided for @importCancelled.
  ///
  /// In en, this message translates to:
  /// **'Import cancelled.'**
  String get importCancelled;

  /// No description provided for @importRollbackAction.
  ///
  /// In en, this message translates to:
  /// **'Roll back'**
  String get importRollbackAction;

  /// No description provided for @importRollbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Roll back this import?'**
  String get importRollbackTitle;

  /// No description provided for @importRollbackBody.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{The imported transaction is deleted, unless it was changed or linked since.} other{The {count} imported transactions are deleted, except ones changed or linked since.}}'**
  String importRollbackBody(int count);

  /// No description provided for @importRollingBack.
  ///
  /// In en, this message translates to:
  /// **'Rolling back the import.'**
  String get importRollingBack;

  /// No description provided for @importTryAnotherFile.
  ///
  /// In en, this message translates to:
  /// **'Try another file'**
  String get importTryAnotherFile;

  /// No description provided for @importCheckStatement.
  ///
  /// In en, this message translates to:
  /// **'Check against the statement'**
  String get importCheckStatement;

  /// No description provided for @importPreviousFile.
  ///
  /// In en, this message translates to:
  /// **'You imported this file into this account before. Rows already imported are flagged and left out.'**
  String get importPreviousFile;

  /// No description provided for @importOpenPrevious.
  ///
  /// In en, this message translates to:
  /// **'Open the earlier import'**
  String get importOpenPrevious;

  /// No description provided for @importSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get importSummaryTitle;

  /// No description provided for @importFormatLabel.
  ///
  /// In en, this message translates to:
  /// **'File type'**
  String get importFormatLabel;

  /// No description provided for @importStartedLabel.
  ///
  /// In en, this message translates to:
  /// **'Started'**
  String get importStartedLabel;

  /// No description provided for @importPeriodLabel.
  ///
  /// In en, this message translates to:
  /// **'Statement period'**
  String get importPeriodLabel;

  /// No description provided for @importRowsInFile.
  ///
  /// In en, this message translates to:
  /// **'Rows in the file'**
  String get importRowsInFile;

  /// No description provided for @importRowsValid.
  ///
  /// In en, this message translates to:
  /// **'Readable rows'**
  String get importRowsValid;

  /// No description provided for @importRowsNeedFixing.
  ///
  /// In en, this message translates to:
  /// **'Rows to fix'**
  String get importRowsNeedFixing;

  /// No description provided for @importRowsPossibleDuplicates.
  ///
  /// In en, this message translates to:
  /// **'Possible duplicates'**
  String get importRowsPossibleDuplicates;

  /// No description provided for @importRowsImportedLabel.
  ///
  /// In en, this message translates to:
  /// **'Imported'**
  String get importRowsImportedLabel;

  /// No description provided for @importRowsSkippedLabel.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get importRowsSkippedLabel;

  /// No description provided for @importRowsFailedLabel.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get importRowsFailedLabel;

  /// No description provided for @importTotalsTitle.
  ///
  /// In en, this message translates to:
  /// **'Totals from the file'**
  String get importTotalsTitle;

  /// No description provided for @importBalanceOk.
  ///
  /// In en, this message translates to:
  /// **'Running balances add up'**
  String get importBalanceOk;

  /// No description provided for @importBalanceMismatch.
  ///
  /// In en, this message translates to:
  /// **'Running balances don\'t add up'**
  String get importBalanceMismatch;

  /// No description provided for @importBalanceNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'No balances in the file to check'**
  String get importBalanceNotAvailable;

  /// No description provided for @importMismatchedRows.
  ///
  /// In en, this message translates to:
  /// **'Check rows {rows}.'**
  String importMismatchedRows(String rows);

  /// No description provided for @importTotalIn.
  ///
  /// In en, this message translates to:
  /// **'Money in'**
  String get importTotalIn;

  /// No description provided for @importTotalOut.
  ///
  /// In en, this message translates to:
  /// **'Money out'**
  String get importTotalOut;

  /// No description provided for @importTotalNet.
  ///
  /// In en, this message translates to:
  /// **'Net'**
  String get importTotalNet;

  /// No description provided for @importOpeningBalance.
  ///
  /// In en, this message translates to:
  /// **'Opening balance'**
  String get importOpeningBalance;

  /// No description provided for @importClosingBalance.
  ///
  /// In en, this message translates to:
  /// **'Closing balance'**
  String get importClosingBalance;

  /// No description provided for @importMappingTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose columns'**
  String get importMappingTitle;

  /// No description provided for @importMappingIntro.
  ///
  /// In en, this message translates to:
  /// **'Tell Montra which column holds each value. The first rows of your file are shown so you can check.'**
  String get importMappingIntro;

  /// No description provided for @importMappingUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The columns can\'t be changed now'**
  String get importMappingUnavailable;

  /// No description provided for @importSampleTitle.
  ///
  /// In en, this message translates to:
  /// **'First rows of the file'**
  String get importSampleTitle;

  /// No description provided for @importSampleRow.
  ///
  /// In en, this message translates to:
  /// **'Row {number}: {cells}'**
  String importSampleRow(int number, String cells);

  /// No description provided for @importHeaderSection.
  ///
  /// In en, this message translates to:
  /// **'Header row'**
  String get importHeaderSection;

  /// No description provided for @importHeaderRowLabel.
  ///
  /// In en, this message translates to:
  /// **'Row with the column names'**
  String get importHeaderRowLabel;

  /// No description provided for @importHeaderRowHelp.
  ///
  /// In en, this message translates to:
  /// **'Rows above it are ignored.'**
  String get importHeaderRowHelp;

  /// No description provided for @importNoHeaderRow.
  ///
  /// In en, this message translates to:
  /// **'No header row'**
  String get importNoHeaderRow;

  /// No description provided for @importColumnNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get importColumnNone;

  /// No description provided for @importColumnNumber.
  ///
  /// In en, this message translates to:
  /// **'Column {number}'**
  String importColumnNumber(int number);

  /// No description provided for @importColumnExample.
  ///
  /// In en, this message translates to:
  /// **'{name} (e.g. {example})'**
  String importColumnExample(String name, String example);

  /// No description provided for @importDateSection.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get importDateSection;

  /// No description provided for @importDateColumn.
  ///
  /// In en, this message translates to:
  /// **'Date column'**
  String get importDateColumn;

  /// No description provided for @importDateFormat.
  ///
  /// In en, this message translates to:
  /// **'Date format'**
  String get importDateFormat;

  /// No description provided for @importDateFormatExample.
  ///
  /// In en, this message translates to:
  /// **'The file shows dates like {example}.'**
  String importDateFormatExample(String example);

  /// No description provided for @importAmountSection.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get importAmountSection;

  /// No description provided for @importAmountSingle.
  ///
  /// In en, this message translates to:
  /// **'One amount column'**
  String get importAmountSingle;

  /// No description provided for @importAmountSplit.
  ///
  /// In en, this message translates to:
  /// **'Money out and in columns'**
  String get importAmountSplit;

  /// No description provided for @importAmountColumn.
  ///
  /// In en, this message translates to:
  /// **'Amount column'**
  String get importAmountColumn;

  /// No description provided for @importSignNegativeOut.
  ///
  /// In en, this message translates to:
  /// **'Negative amounts are money out'**
  String get importSignNegativeOut;

  /// No description provided for @importSignPositiveOut.
  ///
  /// In en, this message translates to:
  /// **'Positive amounts are money out'**
  String get importSignPositiveOut;

  /// No description provided for @importDebitColumn.
  ///
  /// In en, this message translates to:
  /// **'Money out column (withdrawals)'**
  String get importDebitColumn;

  /// No description provided for @importCreditColumn.
  ///
  /// In en, this message translates to:
  /// **'Money in column (deposits)'**
  String get importCreditColumn;

  /// No description provided for @importIndicatorColumn.
  ///
  /// In en, this message translates to:
  /// **'Dr/Cr column (optional)'**
  String get importIndicatorColumn;

  /// No description provided for @importIndicatorHelp.
  ///
  /// In en, this message translates to:
  /// **'A column that says Dr or Cr decides the direction.'**
  String get importIndicatorHelp;

  /// No description provided for @importDecimalLabel.
  ///
  /// In en, this message translates to:
  /// **'Decimal separator'**
  String get importDecimalLabel;

  /// No description provided for @importDecimalPoint.
  ///
  /// In en, this message translates to:
  /// **'Point (1,234.50)'**
  String get importDecimalPoint;

  /// No description provided for @importDecimalComma.
  ///
  /// In en, this message translates to:
  /// **'Comma (1.234,50)'**
  String get importDecimalComma;

  /// No description provided for @importDescriptionSection.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get importDescriptionSection;

  /// No description provided for @importDescriptionHelp.
  ///
  /// In en, this message translates to:
  /// **'Choose one or more columns; they are joined.'**
  String get importDescriptionHelp;

  /// No description provided for @importOptionalSection.
  ///
  /// In en, this message translates to:
  /// **'More columns (optional)'**
  String get importOptionalSection;

  /// No description provided for @importReferenceColumn.
  ///
  /// In en, this message translates to:
  /// **'Reference column'**
  String get importReferenceColumn;

  /// No description provided for @importBalanceColumn.
  ///
  /// In en, this message translates to:
  /// **'Balance column'**
  String get importBalanceColumn;

  /// No description provided for @importBalanceColumnHelp.
  ///
  /// In en, this message translates to:
  /// **'Lets Montra check that the rows add up.'**
  String get importBalanceColumnHelp;

  /// No description provided for @importCurrencyColumn.
  ///
  /// In en, this message translates to:
  /// **'Currency column'**
  String get importCurrencyColumn;

  /// No description provided for @importExternalIdColumn.
  ///
  /// In en, this message translates to:
  /// **'Bank transaction ID column'**
  String get importExternalIdColumn;

  /// No description provided for @importExternalIdHelp.
  ///
  /// In en, this message translates to:
  /// **'Helps Montra spot rows already imported.'**
  String get importExternalIdHelp;

  /// No description provided for @importMappingNeedsDate.
  ///
  /// In en, this message translates to:
  /// **'Choose the date column.'**
  String get importMappingNeedsDate;

  /// No description provided for @importMappingNeedsDateFormat.
  ///
  /// In en, this message translates to:
  /// **'Choose the date format.'**
  String get importMappingNeedsDateFormat;

  /// No description provided for @importMappingNeedsAmount.
  ///
  /// In en, this message translates to:
  /// **'Choose the amount column.'**
  String get importMappingNeedsAmount;

  /// No description provided for @importMappingNeedsDebitCredit.
  ///
  /// In en, this message translates to:
  /// **'Choose both the money out and money in columns.'**
  String get importMappingNeedsDebitCredit;

  /// No description provided for @importMappingSave.
  ///
  /// In en, this message translates to:
  /// **'Save and read again'**
  String get importMappingSave;

  /// No description provided for @importMappingSaved.
  ///
  /// In en, this message translates to:
  /// **'Columns saved. Montra is reading the rows again.'**
  String get importMappingSaved;

  /// No description provided for @importRowsTitle.
  ///
  /// In en, this message translates to:
  /// **'Statement rows'**
  String get importRowsTitle;

  /// No description provided for @importRowsHelp.
  ///
  /// In en, this message translates to:
  /// **'Tap a row to skip it, import it, set its category or correct it.'**
  String get importRowsHelp;

  /// No description provided for @importRowsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No rows here.'**
  String get importRowsEmpty;

  /// No description provided for @importRowsAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get importRowsAll;

  /// No description provided for @importRowsReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get importRowsReady;

  /// No description provided for @importRowsDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Possible duplicates'**
  String get importRowsDuplicate;

  /// No description provided for @importRowsInvalid.
  ///
  /// In en, this message translates to:
  /// **'To fix'**
  String get importRowsInvalid;

  /// No description provided for @importRowsSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get importRowsSkipped;

  /// No description provided for @importRowsImported.
  ///
  /// In en, this message translates to:
  /// **'Imported'**
  String get importRowsImported;

  /// No description provided for @importRowsFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get importRowsFailed;

  /// No description provided for @importRowStatusParsed.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get importRowStatusParsed;

  /// No description provided for @importRowStatusReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get importRowStatusReady;

  /// No description provided for @importRowStatusDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Possible duplicate'**
  String get importRowStatusDuplicate;

  /// No description provided for @importRowStatusInvalid.
  ///
  /// In en, this message translates to:
  /// **'Needs fixing'**
  String get importRowStatusInvalid;

  /// No description provided for @importRowStatusSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get importRowStatusSkipped;

  /// No description provided for @importRowStatusImported.
  ///
  /// In en, this message translates to:
  /// **'Imported'**
  String get importRowStatusImported;

  /// No description provided for @importRowStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get importRowStatusFailed;

  /// No description provided for @importRowWillImport.
  ///
  /// In en, this message translates to:
  /// **'Will be imported'**
  String get importRowWillImport;

  /// No description provided for @importRowWillSkip.
  ///
  /// In en, this message translates to:
  /// **'Left out'**
  String get importRowWillSkip;

  /// No description provided for @importRowNumber.
  ///
  /// In en, this message translates to:
  /// **'Row {number}'**
  String importRowNumber(int number);

  /// No description provided for @importReasonHeader.
  ///
  /// In en, this message translates to:
  /// **'Header row'**
  String get importReasonHeader;

  /// No description provided for @importReasonPreamble.
  ///
  /// In en, this message translates to:
  /// **'Text before the header row'**
  String get importReasonPreamble;

  /// No description provided for @importReasonMissingDate.
  ///
  /// In en, this message translates to:
  /// **'The date is empty.'**
  String get importReasonMissingDate;

  /// No description provided for @importReasonBadDate.
  ///
  /// In en, this message translates to:
  /// **'The date doesn\'t match the chosen format.'**
  String get importReasonBadDate;

  /// No description provided for @importReasonCurrency.
  ///
  /// In en, this message translates to:
  /// **'This row is in another currency.'**
  String get importReasonCurrency;

  /// No description provided for @importReasonBadAmount.
  ///
  /// In en, this message translates to:
  /// **'The amount isn\'t a number in this currency.'**
  String get importReasonBadAmount;

  /// No description provided for @importReasonZeroAmount.
  ///
  /// In en, this message translates to:
  /// **'The amount is empty or zero.'**
  String get importReasonZeroAmount;

  /// No description provided for @importReasonBothColumns.
  ///
  /// In en, this message translates to:
  /// **'Both money out and money in have values.'**
  String get importReasonBothColumns;

  /// No description provided for @importReasonPossibleDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Looks like a transaction already in the account.'**
  String get importReasonPossibleDuplicate;

  /// No description provided for @importReasonAlreadyImported.
  ///
  /// In en, this message translates to:
  /// **'Already imported into this account.'**
  String get importReasonAlreadyImported;

  /// No description provided for @importReasonRolledBack.
  ///
  /// In en, this message translates to:
  /// **'Removed by rolling back this import.'**
  String get importReasonRolledBack;

  /// No description provided for @importRowInclude.
  ///
  /// In en, this message translates to:
  /// **'Import this row'**
  String get importRowInclude;

  /// No description provided for @importRowSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip this row'**
  String get importRowSkip;

  /// No description provided for @importRowCategory.
  ///
  /// In en, this message translates to:
  /// **'Set a category'**
  String get importRowCategory;

  /// No description provided for @importRowCorrect.
  ///
  /// In en, this message translates to:
  /// **'Correct this row'**
  String get importRowCorrect;

  /// No description provided for @importRowOpenTransaction.
  ///
  /// In en, this message translates to:
  /// **'Open the transaction'**
  String get importRowOpenTransaction;

  /// No description provided for @importRowOpenExisting.
  ///
  /// In en, this message translates to:
  /// **'Open the existing transaction'**
  String get importRowOpenExisting;

  /// No description provided for @importRowSaved.
  ///
  /// In en, this message translates to:
  /// **'Row updated.'**
  String get importRowSaved;

  /// No description provided for @importRowCorrectTitle.
  ///
  /// In en, this message translates to:
  /// **'Correct row {number}'**
  String importRowCorrectTitle(int number);

  /// No description provided for @importRowAsRead.
  ///
  /// In en, this message translates to:
  /// **'As read from the file: {cells}'**
  String importRowAsRead(String cells);

  /// No description provided for @importRowDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get importRowDate;

  /// No description provided for @importRowDateRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose the date.'**
  String get importRowDateRequired;

  /// No description provided for @importRowAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get importRowAmount;

  /// No description provided for @importRowMoneyOut.
  ///
  /// In en, this message translates to:
  /// **'Money out'**
  String get importRowMoneyOut;

  /// No description provided for @importRowMoneyIn.
  ///
  /// In en, this message translates to:
  /// **'Money in'**
  String get importRowMoneyIn;

  /// No description provided for @importRowDirectionRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose money out or money in.'**
  String get importRowDirectionRequired;

  /// No description provided for @importRowDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get importRowDescription;

  /// No description provided for @importRowSaveCorrection.
  ///
  /// In en, this message translates to:
  /// **'Save correction'**
  String get importRowSaveCorrection;

  /// No description provided for @analyticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get analyticsTitle;

  /// No description provided for @analyticsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading your figures'**
  String get analyticsLoading;

  /// No description provided for @analyticsSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'This period'**
  String get analyticsSummaryTitle;

  /// No description provided for @analyticsNoActivityBody.
  ///
  /// In en, this message translates to:
  /// **'Add transactions or import a statement to see your figures here.'**
  String get analyticsNoActivityBody;

  /// No description provided for @analyticsPeriodReportsTitle.
  ///
  /// In en, this message translates to:
  /// **'Look closer at this period'**
  String get analyticsPeriodReportsTitle;

  /// No description provided for @analyticsNowTitle.
  ///
  /// In en, this message translates to:
  /// **'Where things stand now'**
  String get analyticsNowTitle;

  /// No description provided for @analyticsUnknownReport.
  ///
  /// In en, this message translates to:
  /// **'This report isn\'t available.'**
  String get analyticsUnknownReport;

  /// No description provided for @analyticsCashFlowTitle.
  ///
  /// In en, this message translates to:
  /// **'Cash flow'**
  String get analyticsCashFlowTitle;

  /// No description provided for @analyticsCashFlowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Money in and out over time'**
  String get analyticsCashFlowSubtitle;

  /// No description provided for @analyticsCategoriesTitle.
  ///
  /// In en, this message translates to:
  /// **'Spending by category'**
  String get analyticsCategoriesTitle;

  /// No description provided for @analyticsCategoriesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Where your money went'**
  String get analyticsCategoriesSubtitle;

  /// No description provided for @analyticsExpensesTitle.
  ///
  /// In en, this message translates to:
  /// **'Spending over time'**
  String get analyticsExpensesTitle;

  /// No description provided for @analyticsExpensesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Spending, refunds and reimbursements'**
  String get analyticsExpensesSubtitle;

  /// No description provided for @analyticsIncomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Income over time'**
  String get analyticsIncomeTitle;

  /// No description provided for @analyticsIncomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Money received in each period'**
  String get analyticsIncomeSubtitle;

  /// No description provided for @analyticsMerchantsTitle.
  ///
  /// In en, this message translates to:
  /// **'Top merchants'**
  String get analyticsMerchantsTitle;

  /// No description provided for @analyticsMerchantsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Where you spent the most'**
  String get analyticsMerchantsSubtitle;

  /// No description provided for @analyticsAccountsTitle.
  ///
  /// In en, this message translates to:
  /// **'Net worth'**
  String get analyticsAccountsTitle;

  /// No description provided for @analyticsAccountsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'What you have and what you owe, per currency'**
  String get analyticsAccountsSubtitle;

  /// No description provided for @analyticsBudgetsTitle.
  ///
  /// In en, this message translates to:
  /// **'Budget performance'**
  String get analyticsBudgetsTitle;

  /// No description provided for @analyticsBudgetsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'How your budgets are doing in their current period'**
  String get analyticsBudgetsSubtitle;

  /// No description provided for @analyticsGoalsTitle.
  ///
  /// In en, this message translates to:
  /// **'Goal progress'**
  String get analyticsGoalsTitle;

  /// No description provided for @analyticsGoalsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Saved so far towards your goals'**
  String get analyticsGoalsSubtitle;

  /// No description provided for @analyticsSubscriptionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Subscription costs'**
  String get analyticsSubscriptionsTitle;

  /// No description provided for @analyticsSubscriptionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'What your subscriptions cost each month and year'**
  String get analyticsSubscriptionsSubtitle;

  /// No description provided for @analyticsRecurringTitle.
  ///
  /// In en, this message translates to:
  /// **'Recurring commitments'**
  String get analyticsRecurringTitle;

  /// No description provided for @analyticsRecurringSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Regular payments and income, per month'**
  String get analyticsRecurringSubtitle;

  /// No description provided for @analyticsCompareTitle.
  ///
  /// In en, this message translates to:
  /// **'Compare periods'**
  String get analyticsCompareTitle;

  /// No description provided for @analyticsCompareSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This period side by side with another'**
  String get analyticsCompareSubtitle;

  /// No description provided for @analyticsGranularityLabel.
  ///
  /// In en, this message translates to:
  /// **'Group by'**
  String get analyticsGranularityLabel;

  /// No description provided for @analyticsGranularityAuto.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get analyticsGranularityAuto;

  /// No description provided for @analyticsGranularityDay.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get analyticsGranularityDay;

  /// No description provided for @analyticsGranularityWeek.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get analyticsGranularityWeek;

  /// No description provided for @analyticsGranularityMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get analyticsGranularityMonth;

  /// No description provided for @analyticsGranularityYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get analyticsGranularityYear;

  /// No description provided for @analyticsOverTimeTitle.
  ///
  /// In en, this message translates to:
  /// **'Over time'**
  String get analyticsOverTimeTitle;

  /// No description provided for @analyticsGrossSpendingLabel.
  ///
  /// In en, this message translates to:
  /// **'Spent before refunds'**
  String get analyticsGrossSpendingLabel;

  /// No description provided for @analyticsRefundsLabel.
  ///
  /// In en, this message translates to:
  /// **'Refunds and reimbursements'**
  String get analyticsRefundsLabel;

  /// No description provided for @analyticsExpensesSummary.
  ///
  /// In en, this message translates to:
  /// **'Spending per {unit} for {period}. Highest: {amount} ({bucket}).'**
  String analyticsExpensesSummary(
    String unit,
    String period,
    String amount,
    String bucket,
  );

  /// No description provided for @analyticsIncomeSummary.
  ///
  /// In en, this message translates to:
  /// **'Income per {unit} for {period}. Highest: {amount} ({bucket}).'**
  String analyticsIncomeSummary(
    String unit,
    String period,
    String amount,
    String bucket,
  );

  /// No description provided for @analyticsShowSubcategories.
  ///
  /// In en, this message translates to:
  /// **'Show subcategories separately'**
  String get analyticsShowSubcategories;

  /// No description provided for @analyticsShowSubcategoriesHelp.
  ///
  /// In en, this message translates to:
  /// **'Otherwise they are added to their main category.'**
  String get analyticsShowSubcategoriesHelp;

  /// No description provided for @analyticsMerchantsSummary.
  ///
  /// In en, this message translates to:
  /// **'{name} had the most spending: {amount}. {count, plural, =1{1 merchant shown.} other{{count} merchants shown.}}'**
  String analyticsMerchantsSummary(String name, String amount, int count);

  /// No description provided for @analyticsMerchantRow.
  ///
  /// In en, this message translates to:
  /// **'{amount} · {count, plural, =1{1 transaction} other{{count} transactions}}'**
  String analyticsMerchantRow(String amount, int count);

  /// No description provided for @analyticsOverviewOnly.
  ///
  /// In en, this message translates to:
  /// **'Only accounts in my overview'**
  String get analyticsOverviewOnly;

  /// No description provided for @analyticsOverviewOnlyHelp.
  ///
  /// In en, this message translates to:
  /// **'Leave out accounts you keep out of the Home totals.'**
  String get analyticsOverviewOnlyHelp;

  /// No description provided for @analyticsBudgetsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No active budgets yet.'**
  String get analyticsBudgetsEmpty;

  /// No description provided for @analyticsBudgetsCreate.
  ///
  /// In en, this message translates to:
  /// **'Create a budget'**
  String get analyticsBudgetsCreate;

  /// No description provided for @analyticsBudgetsPaceTitle.
  ///
  /// In en, this message translates to:
  /// **'How they are going'**
  String get analyticsBudgetsPaceTitle;

  /// No description provided for @analyticsBudgetsOverCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No budget is over its limit.} =1{1 budget is over its limit.} other{{count} budgets are over their limit.}}'**
  String analyticsBudgetsOverCount(int count);

  /// No description provided for @analyticsBudgetsUseTitle.
  ///
  /// In en, this message translates to:
  /// **'How much of each limit is used'**
  String get analyticsBudgetsUseTitle;

  /// No description provided for @analyticsBudgetsSummary.
  ///
  /// In en, this message translates to:
  /// **'Use of the limit for {count, plural, =1{1 budget} other{{count} budgets}}. Over the limit: {over}.'**
  String analyticsBudgetsSummary(int count, int over);

  /// No description provided for @analyticsWithinLimit.
  ///
  /// In en, this message translates to:
  /// **'Within the limit'**
  String get analyticsWithinLimit;

  /// No description provided for @analyticsBudgetRow.
  ///
  /// In en, this message translates to:
  /// **'{spent} of {limit} ({percent}) · {pace}'**
  String analyticsBudgetRow(
    String spent,
    String limit,
    String percent,
    String pace,
  );

  /// No description provided for @analyticsBudgetNoProgress.
  ///
  /// In en, this message translates to:
  /// **'No figures for this period yet.'**
  String get analyticsBudgetNoProgress;

  /// No description provided for @analyticsGoalsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No goals yet.'**
  String get analyticsGoalsEmpty;

  /// No description provided for @analyticsGoalsCreate.
  ///
  /// In en, this message translates to:
  /// **'Create a goal'**
  String get analyticsGoalsCreate;

  /// No description provided for @analyticsGoalsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 goal} other{{count} goals}}; achieved: {achieved}'**
  String analyticsGoalsCount(int count, int achieved);

  /// No description provided for @analyticsGoalsProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Progress per goal'**
  String get analyticsGoalsProgressTitle;

  /// No description provided for @analyticsGoalsSummary.
  ///
  /// In en, this message translates to:
  /// **'Share of the target saved for {count, plural, =1{1 goal} other{{count} goals}}.'**
  String analyticsGoalsSummary(int count);

  /// No description provided for @analyticsGoalRow.
  ///
  /// In en, this message translates to:
  /// **'{saved} of {target} ({percent}) · {status}'**
  String analyticsGoalRow(
    String saved,
    String target,
    String percent,
    String status,
  );

  /// No description provided for @analyticsSubscriptionsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No subscriptions yet.'**
  String get analyticsSubscriptionsEmpty;

  /// No description provided for @analyticsSubscriptionsCreate.
  ///
  /// In en, this message translates to:
  /// **'Add a subscription'**
  String get analyticsSubscriptionsCreate;

  /// No description provided for @analyticsNoRenewals.
  ///
  /// In en, this message translates to:
  /// **'Nothing renews in the next 30 days.'**
  String get analyticsNoRenewals;

  /// No description provided for @analyticsRecurringNote.
  ///
  /// In en, this message translates to:
  /// **'Monthly amounts use fixed amounts only. Bills and income are what you expect, not money already recorded.'**
  String get analyticsRecurringNote;

  /// No description provided for @analyticsRecurringEmpty.
  ///
  /// In en, this message translates to:
  /// **'No active recurring payments or income.'**
  String get analyticsRecurringEmpty;

  /// No description provided for @analyticsRecurringCreate.
  ///
  /// In en, this message translates to:
  /// **'Add a recurring payment'**
  String get analyticsRecurringCreate;

  /// No description provided for @analyticsRecurringSummary.
  ///
  /// In en, this message translates to:
  /// **'Monthly amount per type. The largest is {kind}: {amount} a month.'**
  String analyticsRecurringSummary(String kind, String amount);

  /// No description provided for @analyticsPerMonth.
  ///
  /// In en, this message translates to:
  /// **'{amount} a month'**
  String analyticsPerMonth(String amount);

  /// No description provided for @analyticsRecurringRules.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 active} other{{count} active}}'**
  String analyticsRecurringRules(int count);

  /// No description provided for @analyticsNext30Days.
  ///
  /// In en, this message translates to:
  /// **'{kind}: due in the next 30 days'**
  String analyticsNext30Days(String kind);

  /// No description provided for @analyticsVariableRules.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 with a varying amount isn\'t included.} other{{count} with varying amounts aren\'t included.}}'**
  String analyticsVariableRules(int count);

  /// No description provided for @analyticsCompareNoteSameRules.
  ///
  /// In en, this message translates to:
  /// **'Both periods use the same filters and rules: transfers are left out and refunds reduce spending.'**
  String get analyticsCompareNoteSameRules;

  /// No description provided for @analyticsCompareNoteTotals.
  ///
  /// In en, this message translates to:
  /// **'Periods of different lengths are compared as totals, not per day.'**
  String get analyticsCompareNoteTotals;

  /// No description provided for @analyticsCompareThisPeriod.
  ///
  /// In en, this message translates to:
  /// **'This period'**
  String get analyticsCompareThisPeriod;

  /// No description provided for @analyticsCompareWith.
  ///
  /// In en, this message translates to:
  /// **'Compared with'**
  String get analyticsCompareWith;

  /// No description provided for @analyticsComparePreviousHelp.
  ///
  /// In en, this message translates to:
  /// **'The same number of days just before.'**
  String get analyticsComparePreviousHelp;

  /// No description provided for @analyticsCompareEmpty.
  ///
  /// In en, this message translates to:
  /// **'No income or spending in {now} or {then}.'**
  String analyticsCompareEmpty(String now, String then);

  /// No description provided for @analyticsCompareWindows.
  ///
  /// In en, this message translates to:
  /// **'{now} compared with {then}'**
  String analyticsCompareWindows(String now, String then);

  /// No description provided for @analyticsCompareSummary.
  ///
  /// In en, this message translates to:
  /// **'Spending was {spendingNow}, against {spendingThen} before. Income was {incomeNow}, against {incomeThen}.'**
  String analyticsCompareSummary(
    String spendingNow,
    String spendingThen,
    String incomeNow,
    String incomeThen,
  );

  /// No description provided for @analyticsCompareRow.
  ///
  /// In en, this message translates to:
  /// **'{now} now · {then} before'**
  String analyticsCompareRow(String now, String then);

  /// No description provided for @analyticsCompareThen.
  ///
  /// In en, this message translates to:
  /// **'Before: {amount}'**
  String analyticsCompareThen(String amount);

  /// No description provided for @analyticsCategoryChangesTitle.
  ///
  /// In en, this message translates to:
  /// **'Changes by category'**
  String get analyticsCategoryChangesTitle;

  /// No description provided for @analyticsCategoryChangesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No category spending in either period.'**
  String get analyticsCategoryChangesEmpty;

  /// No description provided for @analyticsCategoryChangeSpoken.
  ///
  /// In en, this message translates to:
  /// **'{now} now, {then} before, change {change}'**
  String analyticsCategoryChangeSpoken(String now, String then, String change);

  /// No description provided for @analyticsChangeNew.
  ///
  /// In en, this message translates to:
  /// **'new'**
  String get analyticsChangeNew;

  /// No description provided for @analyticsCategoryChange.
  ///
  /// In en, this message translates to:
  /// **'Change: {amount} ({percent})'**
  String analyticsCategoryChange(String amount, String percent);

  /// No description provided for @reportsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading your reports'**
  String get reportsLoading;

  /// No description provided for @reportsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No reports yet'**
  String get reportsEmptyTitle;

  /// No description provided for @reportsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Make a summary or an export of your transactions to download, share or keep.'**
  String get reportsEmptyBody;

  /// No description provided for @reportsWorkingNote.
  ///
  /// In en, this message translates to:
  /// **'Reports being made update here by themselves.'**
  String get reportsWorkingNote;

  /// No description provided for @reportsStillWorking.
  ///
  /// In en, this message translates to:
  /// **'Still being made. Pull down to check again.'**
  String get reportsStillWorking;

  /// No description provided for @reportNew.
  ///
  /// In en, this message translates to:
  /// **'New report'**
  String get reportNew;

  /// No description provided for @reportNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New report'**
  String get reportNewTitle;

  /// No description provided for @reportNewIntro.
  ///
  /// In en, this message translates to:
  /// **'Reports are made in the background and can be downloaded for a few days.'**
  String get reportNewIntro;

  /// No description provided for @reportCreate.
  ///
  /// In en, this message translates to:
  /// **'Create report'**
  String get reportCreate;

  /// No description provided for @reportQueued.
  ///
  /// In en, this message translates to:
  /// **'Your report is being made. It will show here when it\'s ready.'**
  String get reportQueued;

  /// No description provided for @reportMaking.
  ///
  /// In en, this message translates to:
  /// **'Your report is being made. This page updates by itself.'**
  String get reportMaking;

  /// No description provided for @reportReadyBody.
  ///
  /// In en, this message translates to:
  /// **'Share it with another app or save it to your device.'**
  String get reportReadyBody;

  /// No description provided for @reportExpiredBody.
  ///
  /// In en, this message translates to:
  /// **'This report has expired. Make it again to download it.'**
  String get reportExpiredBody;

  /// No description provided for @reportGenerateAgain.
  ///
  /// In en, this message translates to:
  /// **'Make it again'**
  String get reportGenerateAgain;

  /// No description provided for @reportNoDeleteNote.
  ///
  /// In en, this message translates to:
  /// **'Report files are deleted automatically when they expire.'**
  String get reportNoDeleteNote;

  /// No description provided for @reportDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get reportDetailsTitle;

  /// No description provided for @reportTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get reportTypeLabel;

  /// No description provided for @reportFormatLabel.
  ///
  /// In en, this message translates to:
  /// **'File format'**
  String get reportFormatLabel;

  /// No description provided for @reportPeriodLabel.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get reportPeriodLabel;

  /// No description provided for @reportPeriodDefault.
  ///
  /// In en, this message translates to:
  /// **'The usual period for this report'**
  String get reportPeriodDefault;

  /// No description provided for @reportIncludePending.
  ///
  /// In en, this message translates to:
  /// **'Include pending transactions'**
  String get reportIncludePending;

  /// No description provided for @reportIncludePendingHelp.
  ///
  /// In en, this message translates to:
  /// **'Otherwise only posted transactions are counted.'**
  String get reportIncludePendingHelp;

  /// No description provided for @reportTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get reportTitleLabel;

  /// No description provided for @reportTitleHelp.
  ///
  /// In en, this message translates to:
  /// **'Optional. For example \"Tax papers 2026\".'**
  String get reportTitleHelp;

  /// No description provided for @reportRequestedLabel.
  ///
  /// In en, this message translates to:
  /// **'Requested'**
  String get reportRequestedLabel;

  /// No description provided for @reportRequestedAt.
  ///
  /// In en, this message translates to:
  /// **'Requested {time}'**
  String reportRequestedAt(String time);

  /// No description provided for @reportCompletedLabel.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get reportCompletedLabel;

  /// No description provided for @reportExpiresLabel.
  ///
  /// In en, this message translates to:
  /// **'Available until'**
  String get reportExpiresLabel;

  /// No description provided for @reportAvailableUntil.
  ///
  /// In en, this message translates to:
  /// **'Available until {date}'**
  String reportAvailableUntil(String date);

  /// No description provided for @reportRowsLabel.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get reportRowsLabel;

  /// No description provided for @reportRows.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 row} other{{count} rows}}'**
  String reportRows(int count);

  /// No description provided for @reportTimezoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Time zone'**
  String get reportTimezoneLabel;

  /// No description provided for @reportTypeAndFormat.
  ///
  /// In en, this message translates to:
  /// **'{type} · {format}'**
  String reportTypeAndFormat(String type, String format);

  /// No description provided for @reportStatusQueued.
  ///
  /// In en, this message translates to:
  /// **'Waiting to start'**
  String get reportStatusQueued;

  /// No description provided for @reportStatusRunning.
  ///
  /// In en, this message translates to:
  /// **'Being made'**
  String get reportStatusRunning;

  /// No description provided for @reportStatusReady.
  ///
  /// In en, this message translates to:
  /// **'Ready to download'**
  String get reportStatusReady;

  /// No description provided for @reportStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t be made'**
  String get reportStatusFailed;

  /// No description provided for @reportStatusExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get reportStatusExpired;

  /// No description provided for @reportStatusOther.
  ///
  /// In en, this message translates to:
  /// **'Other status'**
  String get reportStatusOther;

  /// No description provided for @reportStatusSemantics.
  ///
  /// In en, this message translates to:
  /// **'Status: {status}'**
  String reportStatusSemantics(String status);

  /// No description provided for @reportFailedTooManyRows.
  ///
  /// In en, this message translates to:
  /// **'The report has too many transactions. Choose a shorter period.'**
  String get reportFailedTooManyRows;

  /// No description provided for @reportFailedPdfTooLarge.
  ///
  /// In en, this message translates to:
  /// **'This report is too long for a PDF. Choose CSV or Excel, or a shorter period.'**
  String get reportFailedPdfTooLarge;

  /// No description provided for @reportFailedInvalid.
  ///
  /// In en, this message translates to:
  /// **'The report couldn\'t be made with these choices. Try a different period or report.'**
  String get reportFailedInvalid;

  /// No description provided for @reportFailedUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Reports can\'t be made on this server right now.'**
  String get reportFailedUnavailable;

  /// No description provided for @reportFailedOther.
  ///
  /// In en, this message translates to:
  /// **'The report couldn\'t be made. Try again.'**
  String get reportFailedOther;

  /// No description provided for @reportFormatCsv.
  ///
  /// In en, this message translates to:
  /// **'CSV'**
  String get reportFormatCsv;

  /// No description provided for @reportFormatXlsx.
  ///
  /// In en, this message translates to:
  /// **'Excel (XLSX)'**
  String get reportFormatXlsx;

  /// No description provided for @reportFormatPdf.
  ///
  /// In en, this message translates to:
  /// **'PDF'**
  String get reportFormatPdf;

  /// No description provided for @reportFormatJson.
  ///
  /// In en, this message translates to:
  /// **'JSON'**
  String get reportFormatJson;

  /// No description provided for @reportFormatCsvHelp.
  ///
  /// In en, this message translates to:
  /// **'Opens in any spreadsheet app.'**
  String get reportFormatCsvHelp;

  /// No description provided for @reportFormatXlsxHelp.
  ///
  /// In en, this message translates to:
  /// **'For Excel and similar apps.'**
  String get reportFormatXlsxHelp;

  /// No description provided for @reportFormatPdfHelp.
  ///
  /// In en, this message translates to:
  /// **'Ready to read or print.'**
  String get reportFormatPdfHelp;

  /// No description provided for @reportFormatJsonHelp.
  ///
  /// In en, this message translates to:
  /// **'For other apps and tools.'**
  String get reportFormatJsonHelp;

  /// No description provided for @reportTypeMonthlySummary.
  ///
  /// In en, this message translates to:
  /// **'Monthly summary'**
  String get reportTypeMonthlySummary;

  /// No description provided for @reportTypeMonthlySummaryHelp.
  ///
  /// In en, this message translates to:
  /// **'Income, spending and top categories for a month.'**
  String get reportTypeMonthlySummaryHelp;

  /// No description provided for @reportTypeYearlySummary.
  ///
  /// In en, this message translates to:
  /// **'Yearly summary'**
  String get reportTypeYearlySummary;

  /// No description provided for @reportTypeYearlySummaryHelp.
  ///
  /// In en, this message translates to:
  /// **'The year at a glance, month by month.'**
  String get reportTypeYearlySummaryHelp;

  /// No description provided for @reportTypeCashFlow.
  ///
  /// In en, this message translates to:
  /// **'Cash flow'**
  String get reportTypeCashFlow;

  /// No description provided for @reportTypeCashFlowHelp.
  ///
  /// In en, this message translates to:
  /// **'Money in and out over the period.'**
  String get reportTypeCashFlowHelp;

  /// No description provided for @reportTypeIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get reportTypeIncome;

  /// No description provided for @reportTypeIncomeHelp.
  ///
  /// In en, this message translates to:
  /// **'Money received over the period, by category. Spending is not included.'**
  String get reportTypeIncomeHelp;

  /// No description provided for @reportTypeExpense.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get reportTypeExpense;

  /// No description provided for @reportTypeExpenseHelp.
  ///
  /// In en, this message translates to:
  /// **'Spending, refunds and reimbursements over the period. Income is not included.'**
  String get reportTypeExpenseHelp;

  /// No description provided for @reportTypeCategory.
  ///
  /// In en, this message translates to:
  /// **'Spending by category'**
  String get reportTypeCategory;

  /// No description provided for @reportTypeCategoryHelp.
  ///
  /// In en, this message translates to:
  /// **'Totals for each category.'**
  String get reportTypeCategoryHelp;

  /// No description provided for @reportTypeMerchant.
  ///
  /// In en, this message translates to:
  /// **'Spending by merchant'**
  String get reportTypeMerchant;

  /// No description provided for @reportTypeMerchantHelp.
  ///
  /// In en, this message translates to:
  /// **'Where you spent the most.'**
  String get reportTypeMerchantHelp;

  /// No description provided for @reportTypeAccount.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get reportTypeAccount;

  /// No description provided for @reportTypeAccountHelp.
  ///
  /// In en, this message translates to:
  /// **'Balances, assets and what you owe.'**
  String get reportTypeAccountHelp;

  /// No description provided for @reportTypeBudget.
  ///
  /// In en, this message translates to:
  /// **'Budgets'**
  String get reportTypeBudget;

  /// No description provided for @reportTypeBudgetHelp.
  ///
  /// In en, this message translates to:
  /// **'How each budget is doing.'**
  String get reportTypeBudgetHelp;

  /// No description provided for @reportTypeSubscription.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions'**
  String get reportTypeSubscription;

  /// No description provided for @reportTypeSubscriptionHelp.
  ///
  /// In en, this message translates to:
  /// **'What your subscriptions cost.'**
  String get reportTypeSubscriptionHelp;

  /// No description provided for @reportTypeRecurring.
  ///
  /// In en, this message translates to:
  /// **'Recurring commitments'**
  String get reportTypeRecurring;

  /// No description provided for @reportTypeRecurringHelp.
  ///
  /// In en, this message translates to:
  /// **'Regular payments and income per month.'**
  String get reportTypeRecurringHelp;

  /// No description provided for @reportTypeGoal.
  ///
  /// In en, this message translates to:
  /// **'Goals'**
  String get reportTypeGoal;

  /// No description provided for @reportTypeGoalHelp.
  ///
  /// In en, this message translates to:
  /// **'Progress towards each goal.'**
  String get reportTypeGoalHelp;

  /// No description provided for @reportTypeTransactions.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get reportTypeTransactions;

  /// No description provided for @reportTypeTransactionsHelp.
  ///
  /// In en, this message translates to:
  /// **'Every transaction in the period, one per row.'**
  String get reportTypeTransactionsHelp;

  /// No description provided for @reportTypeOther.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get reportTypeOther;

  /// No description provided for @reportSchedulesTitle.
  ///
  /// In en, this message translates to:
  /// **'Scheduled reports'**
  String get reportSchedulesTitle;

  /// No description provided for @schedulesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No scheduled reports'**
  String get schedulesEmptyTitle;

  /// No description provided for @schedulesEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Get a summary every week or month without asking each time.'**
  String get schedulesEmptyBody;

  /// No description provided for @schedulesNote.
  ///
  /// In en, this message translates to:
  /// **'Scheduled reports appear in your reports list when they\'re ready.'**
  String get schedulesNote;

  /// No description provided for @scheduleNew.
  ///
  /// In en, this message translates to:
  /// **'Schedule a report'**
  String get scheduleNew;

  /// No description provided for @scheduleNewTitle.
  ///
  /// In en, this message translates to:
  /// **'Schedule a report'**
  String get scheduleNewTitle;

  /// No description provided for @scheduleCreate.
  ///
  /// In en, this message translates to:
  /// **'Schedule report'**
  String get scheduleCreate;

  /// No description provided for @scheduleCreated.
  ///
  /// In en, this message translates to:
  /// **'Report scheduled.'**
  String get scheduleCreated;

  /// No description provided for @scheduleCadenceLabel.
  ///
  /// In en, this message translates to:
  /// **'How often'**
  String get scheduleCadenceLabel;

  /// No description provided for @scheduleCadenceWeekly.
  ///
  /// In en, this message translates to:
  /// **'Every week'**
  String get scheduleCadenceWeekly;

  /// No description provided for @scheduleCadenceMonthly.
  ///
  /// In en, this message translates to:
  /// **'Every month'**
  String get scheduleCadenceMonthly;

  /// No description provided for @scheduleWeeklyHelp.
  ///
  /// In en, this message translates to:
  /// **'Each report covers the previous full week.'**
  String get scheduleWeeklyHelp;

  /// No description provided for @scheduleMonthlyHelp.
  ///
  /// In en, this message translates to:
  /// **'Each report covers the previous full month.'**
  String get scheduleMonthlyHelp;

  /// No description provided for @scheduleCadenceAndFormat.
  ///
  /// In en, this message translates to:
  /// **'{cadence} · {format}'**
  String scheduleCadenceAndFormat(String cadence, String format);

  /// No description provided for @scheduleNextRun.
  ///
  /// In en, this message translates to:
  /// **'Next: {time}'**
  String scheduleNextRun(String time);

  /// No description provided for @scheduleOff.
  ///
  /// In en, this message translates to:
  /// **'Turned off'**
  String get scheduleOff;

  /// No description provided for @scheduleTitleWeekly.
  ///
  /// In en, this message translates to:
  /// **'{type} (weekly)'**
  String scheduleTitleWeekly(String type);

  /// No description provided for @scheduleTitleMonthly.
  ///
  /// In en, this message translates to:
  /// **'{type} (monthly)'**
  String scheduleTitleMonthly(String type);

  /// No description provided for @scheduleDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this schedule?'**
  String get scheduleDeleteTitle;

  /// No description provided for @scheduleDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'“{title}” will no longer be made. Reports already made stay in your list until they expire.'**
  String scheduleDeleteBody(String title);

  /// No description provided for @scheduleDeleteLabel.
  ///
  /// In en, this message translates to:
  /// **'Delete the schedule {title}'**
  String scheduleDeleteLabel(String title);

  /// No description provided for @scheduleDeleted.
  ///
  /// In en, this message translates to:
  /// **'Schedule deleted.'**
  String get scheduleDeleted;

  /// No description provided for @fxIntro.
  ///
  /// In en, this message translates to:
  /// **'Rates say how much one unit of a currency is worth in another. Your own rates are used before published ones.'**
  String get fxIntro;

  /// No description provided for @fxEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No exchange rates yet'**
  String get fxEmptyTitle;

  /// No description provided for @fxNoMatchTitle.
  ///
  /// In en, this message translates to:
  /// **'No rates for these currencies'**
  String get fxNoMatchTitle;

  /// No description provided for @fxEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add your own rate to convert between currencies.'**
  String get fxEmptyBody;

  /// No description provided for @fxFilterFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get fxFilterFrom;

  /// No description provided for @fxFilterTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get fxFilterTo;

  /// No description provided for @fxFilterAny.
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get fxFilterAny;

  /// No description provided for @fxAddRate.
  ///
  /// In en, this message translates to:
  /// **'Add a rate'**
  String get fxAddRate;

  /// No description provided for @fxRatePair.
  ///
  /// In en, this message translates to:
  /// **'1 {base} = {rate} {quote}'**
  String fxRatePair(String base, String rate, String quote);

  /// No description provided for @fxAsOf.
  ///
  /// In en, this message translates to:
  /// **'{source} · as of {date}'**
  String fxAsOf(String source, String date);

  /// No description provided for @fxYourRate.
  ///
  /// In en, this message translates to:
  /// **'Your rate'**
  String get fxYourRate;

  /// No description provided for @fxSourceManual.
  ///
  /// In en, this message translates to:
  /// **'Your rate'**
  String get fxSourceManual;

  /// No description provided for @fxSourceEcb.
  ///
  /// In en, this message translates to:
  /// **'European Central Bank'**
  String get fxSourceEcb;

  /// No description provided for @fxSourceProvider.
  ///
  /// In en, this message translates to:
  /// **'Rate provider'**
  String get fxSourceProvider;

  /// No description provided for @fxSourceOther.
  ///
  /// In en, this message translates to:
  /// **'Other source'**
  String get fxSourceOther;

  /// No description provided for @fxSourceLabel.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get fxSourceLabel;

  /// No description provided for @fxDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this rate?'**
  String get fxDeleteTitle;

  /// No description provided for @fxDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Your {base} to {quote} rate will be deleted. Published rates, if there are any, are used instead.'**
  String fxDeleteBody(String base, String quote);

  /// No description provided for @fxDeleteLabel.
  ///
  /// In en, this message translates to:
  /// **'Delete your {base} to {quote} rate'**
  String fxDeleteLabel(String base, String quote);

  /// No description provided for @fxDeleted.
  ///
  /// In en, this message translates to:
  /// **'Rate deleted.'**
  String get fxDeleted;

  /// No description provided for @fxManualIntro.
  ///
  /// In en, this message translates to:
  /// **'Add the rate you got, for example from your bank. Your earlier rates are kept.'**
  String get fxManualIntro;

  /// No description provided for @fxBaseLabel.
  ///
  /// In en, this message translates to:
  /// **'From currency'**
  String get fxBaseLabel;

  /// No description provided for @fxQuoteLabel.
  ///
  /// In en, this message translates to:
  /// **'To currency'**
  String get fxQuoteLabel;

  /// No description provided for @fxRateHelp.
  ///
  /// In en, this message translates to:
  /// **'How many units of the second currency one unit of the first is worth.'**
  String get fxRateHelp;

  /// No description provided for @fxRateHelpPair.
  ///
  /// In en, this message translates to:
  /// **'How many {quote} one {base} is worth, for example 83.12'**
  String fxRateHelpPair(String base, String quote);

  /// No description provided for @fxRateInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a number above zero with at most 12 decimal places, for example 83.12.'**
  String get fxRateInvalid;

  /// No description provided for @fxAsOfLabel.
  ///
  /// In en, this message translates to:
  /// **'Rate date'**
  String get fxAsOfLabel;

  /// No description provided for @fxAsOfNow.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get fxAsOfNow;

  /// No description provided for @fxAsOfHelp.
  ///
  /// In en, this message translates to:
  /// **'Leave it empty for now. A date means that whole day in your time zone (today is fine); it can\'t be in the future.'**
  String get fxAsOfHelp;

  /// No description provided for @fxPairRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose both currencies.'**
  String get fxPairRequired;

  /// No description provided for @fxPairDifferent.
  ///
  /// In en, this message translates to:
  /// **'Choose two different currencies.'**
  String get fxPairDifferent;

  /// No description provided for @fxSaveRate.
  ///
  /// In en, this message translates to:
  /// **'Save rate'**
  String get fxSaveRate;

  /// No description provided for @fxSaved.
  ///
  /// In en, this message translates to:
  /// **'Rate saved.'**
  String get fxSaved;

  /// No description provided for @fxConvertTitle.
  ///
  /// In en, this message translates to:
  /// **'Convert currency'**
  String get fxConvertTitle;

  /// No description provided for @fxConvertIntro.
  ///
  /// In en, this message translates to:
  /// **'Montra shows the rate it uses, where it comes from and its date. Your own rates are used first.'**
  String get fxConvertIntro;

  /// No description provided for @fxFromLabel.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get fxFromLabel;

  /// No description provided for @fxToLabel.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get fxToLabel;

  /// No description provided for @fxUseDate.
  ///
  /// In en, this message translates to:
  /// **'Use the rate on a date'**
  String get fxUseDate;

  /// No description provided for @fxUseDateHelp.
  ///
  /// In en, this message translates to:
  /// **'Otherwise the latest rate is used.'**
  String get fxUseDateHelp;

  /// No description provided for @fxDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Date of the rate'**
  String get fxDateLabel;

  /// No description provided for @fxDateRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose the date.'**
  String get fxDateRequired;

  /// No description provided for @fxConvertAction.
  ///
  /// In en, this message translates to:
  /// **'Convert'**
  String get fxConvertAction;

  /// No description provided for @fxResultTitle.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get fxResultTitle;

  /// No description provided for @fxResultLine.
  ///
  /// In en, this message translates to:
  /// **'{from} = {to}'**
  String fxResultLine(String from, String to);

  /// No description provided for @fxRateDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Rate as of'**
  String get fxRateDateLabel;

  /// No description provided for @fxPolicyLabel.
  ///
  /// In en, this message translates to:
  /// **'Rate used'**
  String get fxPolicyLabel;

  /// No description provided for @fxPolicyCurrent.
  ///
  /// In en, this message translates to:
  /// **'Latest rate'**
  String get fxPolicyCurrent;

  /// No description provided for @fxPolicyHistorical.
  ///
  /// In en, this message translates to:
  /// **'Rate on a date'**
  String get fxPolicyHistorical;

  /// No description provided for @fxInvertedNote.
  ///
  /// In en, this message translates to:
  /// **'Worked out from the {quote} to {base} rate.'**
  String fxInvertedNote(String quote, String base);

  /// No description provided for @fxRoundingNote.
  ///
  /// In en, this message translates to:
  /// **'Rounded to the smallest unit of the currency (difference: {delta} of that unit).'**
  String fxRoundingNote(String delta);

  /// No description provided for @fxNoRate.
  ///
  /// In en, this message translates to:
  /// **'No exchange rate is available for {from} to {to}. Add your own rate.'**
  String fxNoRate(String from, String to);

  /// No description provided for @reconTitle.
  ///
  /// In en, this message translates to:
  /// **'Reconcile'**
  String get reconTitle;

  /// No description provided for @reconTitleOf.
  ///
  /// In en, this message translates to:
  /// **'Reconcile {account}'**
  String reconTitleOf(String account);

  /// No description provided for @reconLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading reconciliation'**
  String get reconLoading;

  /// No description provided for @reconTabBalances.
  ///
  /// In en, this message translates to:
  /// **'Balances'**
  String get reconTabBalances;

  /// No description provided for @reconTabSuggestions.
  ///
  /// In en, this message translates to:
  /// **'Suggestions'**
  String get reconTabSuggestions;

  /// No description provided for @reconTabMatched.
  ///
  /// In en, this message translates to:
  /// **'Matched'**
  String get reconTabMatched;

  /// No description provided for @reconBalancesIntro.
  ///
  /// In en, this message translates to:
  /// **'Compare your statement\'s closing balance with Montra\'s balance on the same date. When they match, transactions up to that date are marked as reconciled.'**
  String get reconBalancesIntro;

  /// No description provided for @reconCheckBalance.
  ///
  /// In en, this message translates to:
  /// **'Check a statement balance'**
  String get reconCheckBalance;

  /// No description provided for @reconBalancesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No statement balance checks yet.'**
  String get reconBalancesEmpty;

  /// No description provided for @reconStatementOf.
  ///
  /// In en, this message translates to:
  /// **'Statement of {date}'**
  String reconStatementOf(String date);

  /// No description provided for @reconBalanced.
  ///
  /// In en, this message translates to:
  /// **'Matches'**
  String get reconBalanced;

  /// No description provided for @reconOffBy.
  ///
  /// In en, this message translates to:
  /// **'Off by {amount}'**
  String reconOffBy(String amount);

  /// No description provided for @reconOffByHelp.
  ///
  /// In en, this message translates to:
  /// **'Look for missing, duplicate or pending transactions up to this date, then check again.'**
  String get reconOffByHelp;

  /// No description provided for @reconStatementBalance.
  ///
  /// In en, this message translates to:
  /// **'Statement balance'**
  String get reconStatementBalance;

  /// No description provided for @reconLedgerBalance.
  ///
  /// In en, this message translates to:
  /// **'Montra\'s balance'**
  String get reconLedgerBalance;

  /// No description provided for @reconDifference.
  ///
  /// In en, this message translates to:
  /// **'Difference'**
  String get reconDifference;

  /// No description provided for @reconReconciledCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 transaction marked as reconciled.} other{{count} transactions marked as reconciled.}}'**
  String reconReconciledCount(int count);

  /// No description provided for @reconUnreconciledCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 transaction up to this date isn\'t reconciled yet.} other{{count} transactions up to this date aren\'t reconciled yet.}}'**
  String reconUnreconciledCount(int count);

  /// No description provided for @reconUnmatchedRows.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 statement row is still unmatched.} other{{count} statement rows are still unmatched.}}'**
  String reconUnmatchedRows(int count);

  /// No description provided for @reconSuggestionsIntro.
  ///
  /// In en, this message translates to:
  /// **'Possible matches found by Montra. Nothing changes until you confirm one, and you can undo it later.'**
  String get reconSuggestionsIntro;

  /// No description provided for @reconSuggestionsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No suggested matches right now.'**
  String get reconSuggestionsEmpty;

  /// No description provided for @reconSuggestionsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Suggestions appear for imported statement rows, pending transactions that posted, and transactions entered twice.'**
  String get reconSuggestionsEmptyBody;

  /// No description provided for @reconConfidence.
  ///
  /// In en, this message translates to:
  /// **'Match likelihood: {percent}%'**
  String reconConfidence(int percent);

  /// No description provided for @reconConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm match'**
  String get reconConfirm;

  /// No description provided for @reconConfirmPendingTitle.
  ///
  /// In en, this message translates to:
  /// **'Replace the pending transaction?'**
  String get reconConfirmPendingTitle;

  /// No description provided for @reconConfirmPendingBody.
  ///
  /// In en, this message translates to:
  /// **'The pending transaction will be removed because the posted one replaces it. You can undo this later.'**
  String get reconConfirmPendingBody;

  /// No description provided for @reconKeepTitle.
  ///
  /// In en, this message translates to:
  /// **'Which one should stay?'**
  String get reconKeepTitle;

  /// No description provided for @reconKeepImported.
  ///
  /// In en, this message translates to:
  /// **'Keep the imported one'**
  String get reconKeepImported;

  /// No description provided for @reconKeepManual.
  ///
  /// In en, this message translates to:
  /// **'Keep the one you entered'**
  String get reconKeepManual;

  /// No description provided for @reconWhy.
  ///
  /// In en, this message translates to:
  /// **'Why: {reasons}'**
  String reconWhy(String reasons);

  /// No description provided for @reconKindStatement.
  ///
  /// In en, this message translates to:
  /// **'Statement row'**
  String get reconKindStatement;

  /// No description provided for @reconKindStatementHelp.
  ///
  /// In en, this message translates to:
  /// **'A statement row matches transactions already in Montra. Confirming marks them as matched; the row isn\'t imported again.'**
  String get reconKindStatementHelp;

  /// No description provided for @reconKindPending.
  ///
  /// In en, this message translates to:
  /// **'Pending now posted'**
  String get reconKindPending;

  /// No description provided for @reconKindPendingHelp.
  ///
  /// In en, this message translates to:
  /// **'A pending transaction has posted. Confirming removes the pending one.'**
  String get reconKindPendingHelp;

  /// No description provided for @reconKindDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Entered twice'**
  String get reconKindDuplicate;

  /// No description provided for @reconKindDuplicateHelp.
  ///
  /// In en, this message translates to:
  /// **'The same transaction was entered by you and imported. Confirming keeps one and removes the other.'**
  String get reconKindDuplicateHelp;

  /// No description provided for @reconKindOther.
  ///
  /// In en, this message translates to:
  /// **'Match'**
  String get reconKindOther;

  /// No description provided for @reconSideStatement.
  ///
  /// In en, this message translates to:
  /// **'On the statement'**
  String get reconSideStatement;

  /// No description provided for @reconSideLedger.
  ///
  /// In en, this message translates to:
  /// **'In Montra'**
  String get reconSideLedger;

  /// No description provided for @reconSidePending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get reconSidePending;

  /// No description provided for @reconSideImported.
  ///
  /// In en, this message translates to:
  /// **'Imported'**
  String get reconSideImported;

  /// No description provided for @reconMatchesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No matches yet.'**
  String get reconMatchesEmpty;

  /// No description provided for @reconMatchedOn.
  ///
  /// In en, this message translates to:
  /// **'Matched {date}'**
  String reconMatchedOn(String date);

  /// No description provided for @reconMatchConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Matched'**
  String get reconMatchConfirmed;

  /// No description provided for @reconMatchUndone.
  ///
  /// In en, this message translates to:
  /// **'Undone'**
  String get reconMatchUndone;

  /// No description provided for @reconMatchSuggested.
  ///
  /// In en, this message translates to:
  /// **'Suggested'**
  String get reconMatchSuggested;

  /// No description provided for @reconMatchRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get reconMatchRejected;

  /// No description provided for @reconMatchOther.
  ///
  /// In en, this message translates to:
  /// **'Other status'**
  String get reconMatchOther;

  /// No description provided for @reconEffectVoided.
  ///
  /// In en, this message translates to:
  /// **'Removed (comes back if you undo)'**
  String get reconEffectVoided;

  /// No description provided for @reconEffectRowSkipped.
  ///
  /// In en, this message translates to:
  /// **'Statement row not imported'**
  String get reconEffectRowSkipped;

  /// No description provided for @reconUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo match'**
  String get reconUndo;

  /// No description provided for @reconUndoTitle.
  ///
  /// In en, this message translates to:
  /// **'Undo this match?'**
  String get reconUndoTitle;

  /// No description provided for @reconUndoBody.
  ///
  /// In en, this message translates to:
  /// **'Removed transactions come back and statement rows return to their import.'**
  String get reconUndoBody;

  /// No description provided for @reconUndone.
  ///
  /// In en, this message translates to:
  /// **'Match undone.'**
  String get reconUndone;

  /// No description provided for @reconReasonSameAmount.
  ///
  /// In en, this message translates to:
  /// **'Same amount and direction'**
  String get reconReasonSameAmount;

  /// No description provided for @reconReasonSameDate.
  ///
  /// In en, this message translates to:
  /// **'Same date'**
  String get reconReasonSameDate;

  /// No description provided for @reconReasonOneDay.
  ///
  /// In en, this message translates to:
  /// **'One day apart'**
  String get reconReasonOneDay;

  /// No description provided for @reconReasonThreeDays.
  ///
  /// In en, this message translates to:
  /// **'Within 3 days'**
  String get reconReasonThreeDays;

  /// No description provided for @reconReasonWeek.
  ///
  /// In en, this message translates to:
  /// **'Within a week'**
  String get reconReasonWeek;

  /// No description provided for @reconReasonReference.
  ///
  /// In en, this message translates to:
  /// **'Same reference'**
  String get reconReasonReference;

  /// No description provided for @reconReasonDescription.
  ///
  /// In en, this message translates to:
  /// **'Similar description'**
  String get reconReasonDescription;

  /// No description provided for @reconReasonAddsUp.
  ///
  /// In en, this message translates to:
  /// **'Amounts add up exactly'**
  String get reconReasonAddsUp;

  /// No description provided for @reconReasonAllWeek.
  ///
  /// In en, this message translates to:
  /// **'All within a week'**
  String get reconReasonAllWeek;

  /// No description provided for @reconReasonPendingReplaced.
  ///
  /// In en, this message translates to:
  /// **'The posted transaction replaces the pending one'**
  String get reconReasonPendingReplaced;

  /// No description provided for @reconReasonEnteredTwice.
  ///
  /// In en, this message translates to:
  /// **'The same transaction was entered by you and imported'**
  String get reconReasonEnteredTwice;

  /// No description provided for @reconReasonAmountsDiffer.
  ///
  /// In en, this message translates to:
  /// **'Amounts differ ({pending} pending, {posted} posted)'**
  String reconReasonAmountsDiffer(String pending, String posted);

  /// No description provided for @reconFormIntro.
  ///
  /// In en, this message translates to:
  /// **'Enter the closing balance shown on a statement for {account}.'**
  String reconFormIntro(String account);

  /// No description provided for @reconFromImport.
  ///
  /// In en, this message translates to:
  /// **'This check is linked to the imported statement.'**
  String get reconFromImport;

  /// No description provided for @reconStatementDate.
  ///
  /// In en, this message translates to:
  /// **'Statement date'**
  String get reconStatementDate;

  /// No description provided for @reconChooseDate.
  ///
  /// In en, this message translates to:
  /// **'Choose the date'**
  String get reconChooseDate;

  /// No description provided for @reconDateRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose the statement date.'**
  String get reconDateRequired;

  /// No description provided for @reconBalanceKindLabel.
  ///
  /// In en, this message translates to:
  /// **'The statement shows'**
  String get reconBalanceKindLabel;

  /// No description provided for @reconKindOwed.
  ///
  /// In en, this message translates to:
  /// **'Amount you owe'**
  String get reconKindOwed;

  /// No description provided for @reconKindBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get reconKindBalance;

  /// No description provided for @reconAmountOwedLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount owed on the statement'**
  String get reconAmountOwedLabel;

  /// No description provided for @reconAmountOwedHelp.
  ///
  /// In en, this message translates to:
  /// **'The amount you owe on the statement, as a positive number.'**
  String get reconAmountOwedHelp;

  /// No description provided for @reconStatementBalanceHelp.
  ///
  /// In en, this message translates to:
  /// **'As shown on the statement. Use a minus sign for an overdrawn balance.'**
  String get reconStatementBalanceHelp;

  /// No description provided for @reconWhatHappens.
  ///
  /// In en, this message translates to:
  /// **'Montra compares this with its own balance on that date. If they match, posted transactions up to the date are marked as reconciled. Nothing else changes.'**
  String get reconWhatHappens;

  /// No description provided for @reconCompare.
  ///
  /// In en, this message translates to:
  /// **'Compare'**
  String get reconCompare;

  /// No description provided for @reconResultBalanced.
  ///
  /// In en, this message translates to:
  /// **'The balances match.'**
  String get reconResultBalanced;

  /// No description provided for @reconResultOff.
  ///
  /// In en, this message translates to:
  /// **'The balances don\'t match yet.'**
  String get reconResultOff;

  /// No description provided for @reconCheckAgain.
  ///
  /// In en, this message translates to:
  /// **'Check another balance'**
  String get reconCheckAgain;

  /// No description provided for @limitsStorageTitle.
  ///
  /// In en, this message translates to:
  /// **'File storage'**
  String get limitsStorageTitle;

  /// No description provided for @limitsStorageUsed.
  ///
  /// In en, this message translates to:
  /// **'{used} of {quota} used'**
  String limitsStorageUsed(String used, String quota);

  /// No description provided for @limitsTitle.
  ///
  /// In en, this message translates to:
  /// **'Fair-use limits'**
  String get limitsTitle;

  /// No description provided for @limitsFreeNote.
  ///
  /// In en, this message translates to:
  /// **'Every Montra feature is free. These limits are the same for everyone and keep Montra fast.'**
  String get limitsFreeNote;

  /// No description provided for @limitsOpenBills.
  ///
  /// In en, this message translates to:
  /// **'Open bills: up to {count}'**
  String limitsOpenBills(String count);

  /// No description provided for @limitsRecurring.
  ///
  /// In en, this message translates to:
  /// **'Recurring payments: up to {count}'**
  String limitsRecurring(String count);

  /// No description provided for @limitsSubscriptions.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions: up to {count}'**
  String limitsSubscriptions(String count);

  /// No description provided for @limitsGoals.
  ///
  /// In en, this message translates to:
  /// **'Goals: up to {count}'**
  String limitsGoals(String count);

  /// No description provided for @limitsImportRows.
  ///
  /// In en, this message translates to:
  /// **'Rows in one statement import: up to {count}'**
  String limitsImportRows(String count);

  /// No description provided for @limitsExportDays.
  ///
  /// In en, this message translates to:
  /// **'Report downloads are kept for {days} days'**
  String limitsExportDays(String days);

  /// No description provided for @errorFileInUse.
  ///
  /// In en, this message translates to:
  /// **'This page is already part of another receipt.'**
  String get errorFileInUse;

  /// No description provided for @errorPageNotReady.
  ///
  /// In en, this message translates to:
  /// **'A page is still uploading. Wait a moment and try again.'**
  String get errorPageNotReady;

  /// No description provided for @errorReceiptLinked.
  ///
  /// In en, this message translates to:
  /// **'This receipt is already linked to a transaction. Unlink it first.'**
  String get errorReceiptLinked;

  /// No description provided for @errorReceiptDiscarded.
  ///
  /// In en, this message translates to:
  /// **'This receipt was discarded. Restore it first.'**
  String get errorReceiptDiscarded;

  /// No description provided for @errorReceiptProcessing.
  ///
  /// In en, this message translates to:
  /// **'This receipt is still being prepared. Try again in a moment.'**
  String get errorReceiptProcessing;

  /// No description provided for @errorReceiptNotLinked.
  ///
  /// In en, this message translates to:
  /// **'This receipt isn\'t linked to a transaction.'**
  String get errorReceiptNotLinked;

  /// No description provided for @errorReceiptNotDiscarded.
  ///
  /// In en, this message translates to:
  /// **'Only discarded receipts can be restored.'**
  String get errorReceiptNotDiscarded;

  /// No description provided for @errorTransactionHasReceipt.
  ///
  /// In en, this message translates to:
  /// **'That transaction already has a receipt.'**
  String get errorTransactionHasReceipt;

  /// No description provided for @receiptWarningLineItemsAmounts.
  ///
  /// In en, this message translates to:
  /// **'The items add up to {total}, not the subtotal of {subtotal}. Check the numbers.'**
  String receiptWarningLineItemsAmounts(String total, String subtotal);

  /// No description provided for @receiptWarningAmountUnreadable.
  ///
  /// In en, this message translates to:
  /// **'An amount couldn\'t be read (“{value}”). Check it.'**
  String receiptWarningAmountUnreadable(String value);

  /// No description provided for @receiptWarningAmountUnreadableGeneric.
  ///
  /// In en, this message translates to:
  /// **'An amount couldn\'t be read. Check the amounts.'**
  String get receiptWarningAmountUnreadableGeneric;

  /// No description provided for @receiptWarningDateUnreadable.
  ///
  /// In en, this message translates to:
  /// **'The date couldn\'t be read. Check it.'**
  String get receiptWarningDateUnreadable;

  /// No description provided for @receiptWarningCurrencyUnrecognized.
  ///
  /// In en, this message translates to:
  /// **'The currency wasn\'t recognized. Check it.'**
  String get receiptWarningCurrencyUnrecognized;

  /// No description provided for @receiptWarningReadingFailed.
  ///
  /// In en, this message translates to:
  /// **'This receipt couldn\'t be read automatically. Enter the details yourself.'**
  String get receiptWarningReadingFailed;

  /// No description provided for @receiptDiscardBodyRestorable.
  ///
  /// In en, this message translates to:
  /// **'It leaves your inbox. You can restore it later; its files are kept.'**
  String get receiptDiscardBodyRestorable;

  /// No description provided for @receiptDiscardLinkedBodyRestorable.
  ///
  /// In en, this message translates to:
  /// **'It leaves your inbox and is unlinked from its transaction, which stays as it is. If you restore the receipt later, it stays unlinked.'**
  String get receiptDiscardLinkedBodyRestorable;

  /// No description provided for @receiptRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get receiptRestore;

  /// No description provided for @receiptRestored.
  ///
  /// In en, this message translates to:
  /// **'Receipt restored.'**
  String get receiptRestored;

  /// No description provided for @receiptCheckDetails.
  ///
  /// In en, this message translates to:
  /// **'Check the details'**
  String get receiptCheckDetails;

  /// No description provided for @receiptHelpCheckManual.
  ///
  /// In en, this message translates to:
  /// **'These values weren\'t entered by you. Check them and save them before recording the purchase.'**
  String get receiptHelpCheckManual;

  /// No description provided for @receiptAddFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'The receipt wasn\'t added'**
  String get receiptAddFailedTitle;

  /// No description provided for @receiptAddForget.
  ///
  /// In en, this message translates to:
  /// **'Don\'t add'**
  String get receiptAddForget;

  /// No description provided for @receiptPaymentMethodHelp.
  ///
  /// In en, this message translates to:
  /// **'For example cash, UPI or card. Don\'t enter card or account numbers.'**
  String get receiptPaymentMethodHelp;

  /// No description provided for @navInsights.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get navInsights;

  /// No description provided for @navTogether.
  ///
  /// In en, this message translates to:
  /// **'Together'**
  String get navTogether;

  /// No description provided for @searchTitle.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchTitle;

  /// No description provided for @notificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// No description provided for @notificationsUnreadBadge.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 unread notification} other{{count} unread notifications}}'**
  String notificationsUnreadBadge(int count);

  /// No description provided for @fieldRequired.
  ///
  /// In en, this message translates to:
  /// **'This is required.'**
  String get fieldRequired;

  /// No description provided for @fieldTooShort.
  ///
  /// In en, this message translates to:
  /// **'Use at least {min} characters.'**
  String fieldTooShort(String min);

  /// No description provided for @fieldTooLong.
  ///
  /// In en, this message translates to:
  /// **'Use at most {max} characters.'**
  String fieldTooLong(String max);

  /// No description provided for @fieldTooFew.
  ///
  /// In en, this message translates to:
  /// **'Choose at least {min}.'**
  String fieldTooFew(String min);

  /// No description provided for @fieldTooMany.
  ///
  /// In en, this message translates to:
  /// **'Choose at most {max}.'**
  String fieldTooMany(String max);

  /// No description provided for @fieldTooSmall.
  ///
  /// In en, this message translates to:
  /// **'This value is too small.'**
  String get fieldTooSmall;

  /// No description provided for @fieldTooLarge.
  ///
  /// In en, this message translates to:
  /// **'This value is too large.'**
  String get fieldTooLarge;

  /// No description provided for @fieldInvalidChoice.
  ///
  /// In en, this message translates to:
  /// **'Choose one of the offered options.'**
  String get fieldInvalidChoice;

  /// No description provided for @fieldInvalidFormat.
  ///
  /// In en, this message translates to:
  /// **'Check the format of this value.'**
  String get fieldInvalidFormat;

  /// No description provided for @fieldInvalidType.
  ///
  /// In en, this message translates to:
  /// **'This value has the wrong type.'**
  String get fieldInvalidType;

  /// No description provided for @fieldUnexpected.
  ///
  /// In en, this message translates to:
  /// **'This field isn\'t accepted here.'**
  String get fieldUnexpected;

  /// No description provided for @fieldInvalidCharacters.
  ///
  /// In en, this message translates to:
  /// **'Remove the unsupported characters.'**
  String get fieldInvalidCharacters;

  /// No description provided for @fieldContainsSecret.
  ///
  /// In en, this message translates to:
  /// **'Remove card numbers, PINs, one-time codes and passwords before sending.'**
  String get fieldContainsSecret;

  /// No description provided for @fieldTooManyLinks.
  ///
  /// In en, this message translates to:
  /// **'Include at most {max} links.'**
  String fieldTooManyLinks(String max);

  /// No description provided for @fieldInsecureLink.
  ///
  /// In en, this message translates to:
  /// **'Links must start with https://.'**
  String get fieldInsecureLink;

  /// No description provided for @fieldLinkRequired.
  ///
  /// In en, this message translates to:
  /// **'Add a link.'**
  String get fieldLinkRequired;

  /// No description provided for @fieldModeratorsOnly.
  ///
  /// In en, this message translates to:
  /// **'Only moderators can post this.'**
  String get fieldModeratorsOnly;

  /// No description provided for @fieldPollMismatch.
  ///
  /// In en, this message translates to:
  /// **'Polls need poll options; other kinds of posts can\'t have them.'**
  String get fieldPollMismatch;

  /// No description provided for @fieldDuplicateOption.
  ///
  /// In en, this message translates to:
  /// **'Each poll option must be different.'**
  String get fieldDuplicateOption;

  /// No description provided for @fieldMustBeFuture.
  ///
  /// In en, this message translates to:
  /// **'Choose a date in the future.'**
  String get fieldMustBeFuture;

  /// No description provided for @fieldInvalidParent.
  ///
  /// In en, this message translates to:
  /// **'That comment can\'t be replied to.'**
  String get fieldInvalidParent;

  /// No description provided for @fieldInvalidOption.
  ///
  /// In en, this message translates to:
  /// **'That option isn\'t part of this poll.'**
  String get fieldInvalidOption;

  /// No description provided for @fieldInvalidTopic.
  ///
  /// In en, this message translates to:
  /// **'One of the topics isn\'t valid.'**
  String get fieldInvalidTopic;

  /// No description provided for @fieldSelfNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'You can\'t do this to yourself.'**
  String get fieldSelfNotAllowed;

  /// No description provided for @fieldReasonRequired.
  ///
  /// In en, this message translates to:
  /// **'Give a reason.'**
  String get fieldReasonRequired;

  /// No description provided for @fieldShareRequired.
  ///
  /// In en, this message translates to:
  /// **'Share your progress to appear on the leaderboard.'**
  String get fieldShareRequired;

  /// No description provided for @fieldSlugTaken.
  ///
  /// In en, this message translates to:
  /// **'That URL name is taken. Choose another.'**
  String get fieldSlugTaken;

  /// No description provided for @errorDailyCapRetry.
  ///
  /// In en, this message translates to:
  /// **'You\'ve reached today\'s limit ({limit} a day). Try again in {wait}.'**
  String errorDailyCapRetry(String limit, String wait);

  /// No description provided for @errorDailyCap.
  ///
  /// In en, this message translates to:
  /// **'You\'ve reached today\'s limit ({limit} a day). Try again tomorrow.'**
  String errorDailyCap(String limit);

  /// No description provided for @profileYouTitle.
  ///
  /// In en, this message translates to:
  /// **'You and your data'**
  String get profileYouTitle;

  /// No description provided for @profileNotificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'What Montra tells you, and how'**
  String get profileNotificationsSubtitle;

  /// No description provided for @profileFriendsTitle.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get profileFriendsTitle;

  /// No description provided for @profileFriendsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Requests, blocked people and who can find you'**
  String get profileFriendsSubtitle;

  /// No description provided for @profileIntegrationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Connected services'**
  String get profileIntegrationsTitle;

  /// No description provided for @profileIntegrationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Bank and other connections, and their status'**
  String get profileIntegrationsSubtitle;

  /// No description provided for @profilePrivacySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Consents, a copy of your data, closing your account'**
  String get profilePrivacySubtitle;

  /// No description provided for @profileModerationTitle.
  ///
  /// In en, this message translates to:
  /// **'Moderation decisions'**
  String get profileModerationTitle;

  /// No description provided for @profileModerationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Decisions about you, your appeals and reports'**
  String get profileModerationSubtitle;

  /// No description provided for @profileHelpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Common questions and your support requests'**
  String get profileHelpSubtitle;

  /// No description provided for @contactEntry.
  ///
  /// In en, this message translates to:
  /// **'Need help? Contact support'**
  String get contactEntry;

  /// No description provided for @helpTitle.
  ///
  /// In en, this message translates to:
  /// **'Help & support'**
  String get helpTitle;

  /// No description provided for @helpIntro.
  ///
  /// In en, this message translates to:
  /// **'Find quick answers below, or ask Montra support. Everything in Montra is free, including support.'**
  String get helpIntro;

  /// No description provided for @helpNewRequest.
  ///
  /// In en, this message translates to:
  /// **'Ask for help'**
  String get helpNewRequest;

  /// No description provided for @helpYourRequests.
  ///
  /// In en, this message translates to:
  /// **'Your requests'**
  String get helpYourRequests;

  /// No description provided for @helpNoRequests.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t asked for help yet.'**
  String get helpNoRequests;

  /// No description provided for @helpRequestMeta.
  ///
  /// In en, this message translates to:
  /// **'{kind} · {reference} · {date}'**
  String helpRequestMeta(String kind, String reference, String date);

  /// No description provided for @helpMessageCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 message} other{{count} messages}}'**
  String helpMessageCount(int count);

  /// No description provided for @helpTopicsTitle.
  ///
  /// In en, this message translates to:
  /// **'Common questions'**
  String get helpTopicsTitle;

  /// No description provided for @helpTopicMoneyTitle.
  ///
  /// In en, this message translates to:
  /// **'How Montra counts your money'**
  String get helpTopicMoneyTitle;

  /// No description provided for @helpTopicMoneyBody.
  ///
  /// In en, this message translates to:
  /// **'Transfers between your own accounts are not spending or income. Refunds reduce spending. Amounts in different currencies are never added together. Pending transactions count only when you choose to include them.'**
  String get helpTopicMoneyBody;

  /// No description provided for @helpTopicMoneyLink.
  ///
  /// In en, this message translates to:
  /// **'See your analytics'**
  String get helpTopicMoneyLink;

  /// No description provided for @helpTopicPrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your privacy'**
  String get helpTopicPrivacyTitle;

  /// No description provided for @helpTopicPrivacyBody.
  ///
  /// In en, this message translates to:
  /// **'Your records are visible only to you, unless you share them in a group. Montra never asks for bank passwords, UPI PINs, OTPs or card numbers. You can download your data or delete your account at any time.'**
  String get helpTopicPrivacyBody;

  /// No description provided for @helpTopicPrivacyLink.
  ///
  /// In en, this message translates to:
  /// **'Privacy & data'**
  String get helpTopicPrivacyLink;

  /// No description provided for @helpTopicImportsTitle.
  ///
  /// In en, this message translates to:
  /// **'Importing statements'**
  String get helpTopicImportsTitle;

  /// No description provided for @helpTopicImportsBody.
  ///
  /// In en, this message translates to:
  /// **'Import CSV, XLSX or OFX statements from your bank. You check every row before anything is added, and you can roll an import back.'**
  String get helpTopicImportsBody;

  /// No description provided for @helpTopicImportsLink.
  ///
  /// In en, this message translates to:
  /// **'Go to imports'**
  String get helpTopicImportsLink;

  /// No description provided for @helpTopicGroupsTitle.
  ///
  /// In en, this message translates to:
  /// **'Groups and shared costs'**
  String get helpTopicGroupsTitle;

  /// No description provided for @helpTopicGroupsBody.
  ///
  /// In en, this message translates to:
  /// **'Split costs with housemates, trips or friends. Montra keeps the balances; it never moves money. Settlements are recorded by you and confirmed by the other person.'**
  String get helpTopicGroupsBody;

  /// No description provided for @helpTopicGroupsLink.
  ///
  /// In en, this message translates to:
  /// **'Go to groups'**
  String get helpTopicGroupsLink;

  /// No description provided for @helpTopicLimitsTitle.
  ///
  /// In en, this message translates to:
  /// **'Is anything paid?'**
  String get helpTopicLimitsTitle;

  /// No description provided for @helpTopicLimitsBody.
  ///
  /// In en, this message translates to:
  /// **'No. Everything in Montra is free. A few fair-use limits, the same for everyone, keep it fast.'**
  String get helpTopicLimitsBody;

  /// No description provided for @helpTopicLimitsLink.
  ///
  /// In en, this message translates to:
  /// **'See the limits'**
  String get helpTopicLimitsLink;

  /// No description provided for @helpTopicModerationTitle.
  ///
  /// In en, this message translates to:
  /// **'A post removed or a limit placed?'**
  String get helpTopicModerationTitle;

  /// No description provided for @helpTopicModerationBody.
  ///
  /// In en, this message translates to:
  /// **'See the decisions about you and ask for a review within 30 days.'**
  String get helpTopicModerationBody;

  /// No description provided for @helpTopicModerationLink.
  ///
  /// In en, this message translates to:
  /// **'Moderation decisions'**
  String get helpTopicModerationLink;

  /// No description provided for @helpKindLabel.
  ///
  /// In en, this message translates to:
  /// **'What is it about?'**
  String get helpKindLabel;

  /// No description provided for @helpKindSupport.
  ///
  /// In en, this message translates to:
  /// **'Help using Montra'**
  String get helpKindSupport;

  /// No description provided for @helpKindBug.
  ///
  /// In en, this message translates to:
  /// **'Something isn\'t working'**
  String get helpKindBug;

  /// No description provided for @helpKindSecurity.
  ///
  /// In en, this message translates to:
  /// **'Security concern'**
  String get helpKindSecurity;

  /// No description provided for @helpKindPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy or my data'**
  String get helpKindPrivacy;

  /// No description provided for @helpKindFeedback.
  ///
  /// In en, this message translates to:
  /// **'Feedback or an idea'**
  String get helpKindFeedback;

  /// No description provided for @helpStatusOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get helpStatusOpen;

  /// No description provided for @helpStatusInProgress.
  ///
  /// In en, this message translates to:
  /// **'Being looked at'**
  String get helpStatusInProgress;

  /// No description provided for @helpStatusResolved.
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get helpStatusResolved;

  /// No description provided for @helpStatusClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get helpStatusClosed;

  /// No description provided for @helpNoSecretsNote.
  ///
  /// In en, this message translates to:
  /// **'Never include card numbers, PINs, one-time codes or passwords. Montra support never needs them.'**
  String get helpNoSecretsNote;

  /// No description provided for @helpNoSecretsShort.
  ///
  /// In en, this message translates to:
  /// **'No card numbers, PINs, codes or passwords.'**
  String get helpNoSecretsShort;

  /// No description provided for @helpSubjectLabel.
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get helpSubjectLabel;

  /// No description provided for @helpBodyLabel.
  ///
  /// In en, this message translates to:
  /// **'Your message'**
  String get helpBodyLabel;

  /// No description provided for @helpBodyHelp.
  ///
  /// In en, this message translates to:
  /// **'Say what you tried and what happened. Don\'t include amounts or account details unless they matter.'**
  String get helpBodyHelp;

  /// No description provided for @helpSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get helpSend;

  /// No description provided for @helpRequestSent.
  ///
  /// In en, this message translates to:
  /// **'Sent. Your reference is {reference}.'**
  String helpRequestSent(String reference);

  /// No description provided for @helpRequestTitle.
  ///
  /// In en, this message translates to:
  /// **'Support request'**
  String get helpRequestTitle;

  /// No description provided for @helpReferenceLabel.
  ///
  /// In en, this message translates to:
  /// **'Reference'**
  String get helpReferenceLabel;

  /// No description provided for @helpSentOn.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get helpSentOn;

  /// No description provided for @helpConversation.
  ///
  /// In en, this message translates to:
  /// **'Conversation'**
  String get helpConversation;

  /// No description provided for @helpNoMessages.
  ///
  /// In en, this message translates to:
  /// **'No replies yet. Montra support will answer here, and you\'ll get a notification.'**
  String get helpNoMessages;

  /// No description provided for @helpFromSupport.
  ///
  /// In en, this message translates to:
  /// **'Montra support'**
  String get helpFromSupport;

  /// No description provided for @helpFromYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get helpFromYou;

  /// No description provided for @helpFromRequester.
  ///
  /// In en, this message translates to:
  /// **'Requester'**
  String get helpFromRequester;

  /// No description provided for @helpReplyLabel.
  ///
  /// In en, this message translates to:
  /// **'Add a reply'**
  String get helpReplyLabel;

  /// No description provided for @helpSendReply.
  ///
  /// In en, this message translates to:
  /// **'Send reply'**
  String get helpSendReply;

  /// No description provided for @helpReplySent.
  ///
  /// In en, this message translates to:
  /// **'Reply sent.'**
  String get helpReplySent;

  /// No description provided for @helpRequestClosedNote.
  ///
  /// In en, this message translates to:
  /// **'This request is closed. If you still need help, ask again from Help & support.'**
  String get helpRequestClosedNote;

  /// No description provided for @helpRequestClosedError.
  ///
  /// In en, this message translates to:
  /// **'This request is closed, so it can\'t take more replies. Ask again from Help & support.'**
  String get helpRequestClosedError;

  /// No description provided for @contactTitle.
  ///
  /// In en, this message translates to:
  /// **'Contact support'**
  String get contactTitle;

  /// No description provided for @contactIntro.
  ///
  /// In en, this message translates to:
  /// **'Can\'t sign in, or not a Montra user yet? Send us a message and we\'ll reply by email.'**
  String get contactIntro;

  /// No description provided for @contactEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Your email'**
  String get contactEmailLabel;

  /// No description provided for @contactEmailHelp.
  ///
  /// In en, this message translates to:
  /// **'We use it only to reply to this message.'**
  String get contactEmailHelp;

  /// No description provided for @contactEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter an email address like name@example.com.'**
  String get contactEmailInvalid;

  /// No description provided for @contactSentTitle.
  ///
  /// In en, this message translates to:
  /// **'Message sent'**
  String get contactSentTitle;

  /// No description provided for @contactSentBody.
  ///
  /// In en, this message translates to:
  /// **'Your reference is {reference}. We\'ll reply to your email.'**
  String contactSentBody(String reference);

  /// No description provided for @privacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy & data'**
  String get privacyTitle;

  /// No description provided for @privacyIntro.
  ///
  /// In en, this message translates to:
  /// **'Choose what Montra may do with your data, get a copy of everything, or close your account.'**
  String get privacyIntro;

  /// No description provided for @privacyConsentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Consents'**
  String get privacyConsentsTitle;

  /// No description provided for @privacyConsentAccepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted (version {version})'**
  String privacyConsentAccepted(String version);

  /// No description provided for @privacyConsentTerms.
  ///
  /// In en, this message translates to:
  /// **'Terms of use'**
  String get privacyConsentTerms;

  /// No description provided for @privacyConsentPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy notice'**
  String get privacyConsentPrivacyPolicy;

  /// No description provided for @privacyConsentRequiredBody.
  ///
  /// In en, this message translates to:
  /// **'Needed to use Montra. To withdraw it, delete your account.'**
  String get privacyConsentRequiredBody;

  /// No description provided for @privacyConsentLocation.
  ///
  /// In en, this message translates to:
  /// **'Location on transactions'**
  String get privacyConsentLocation;

  /// No description provided for @privacyConsentLocationBody.
  ///
  /// In en, this message translates to:
  /// **'Lets you save a place name with a transaction, like the shop where you paid. When it\'s off, you can\'t add a location.'**
  String get privacyConsentLocationBody;

  /// No description provided for @privacyConsentPush.
  ///
  /// In en, this message translates to:
  /// **'Push notifications'**
  String get privacyConsentPush;

  /// No description provided for @privacyConsentPushBody.
  ///
  /// In en, this message translates to:
  /// **'Records whether Montra may send alerts to your devices. Push alerts are not set up in this version of the app; you see everything in the notification center.'**
  String get privacyConsentPushBody;

  /// No description provided for @privacyConsentMarketing.
  ///
  /// In en, this message translates to:
  /// **'Product news by email'**
  String get privacyConsentMarketing;

  /// No description provided for @privacyConsentMarketingBody.
  ///
  /// In en, this message translates to:
  /// **'Occasional emails about new features. Montra doesn\'t send these today; this records your choice. Account and security emails are always sent.'**
  String get privacyConsentMarketingBody;

  /// No description provided for @privacyConsentAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Product analytics'**
  String get privacyConsentAnalytics;

  /// No description provided for @privacyConsentAnalyticsBody.
  ///
  /// In en, this message translates to:
  /// **'Allows aggregate statistics about how features are used. Montra collects none today and this app has no analytics tools; this records your choice.'**
  String get privacyConsentAnalyticsBody;

  /// No description provided for @privacyConsentContacts.
  ///
  /// In en, this message translates to:
  /// **'Be found by your contacts'**
  String get privacyConsentContacts;

  /// No description provided for @privacyConsentContactsBody.
  ///
  /// In en, this message translates to:
  /// **'Lets people who already have your contact details find you. Montra has no contact matching today; being found by username is a separate setting under Friends.'**
  String get privacyConsentContactsBody;

  /// No description provided for @privacyConsentAi.
  ///
  /// In en, this message translates to:
  /// **'AI features'**
  String get privacyConsentAi;

  /// No description provided for @privacyConsentAiBody.
  ///
  /// In en, this message translates to:
  /// **'This app has no AI features. You gave this consent in another Montra app; withdrawing it turns AI off everywhere.'**
  String get privacyConsentAiBody;

  /// No description provided for @privacyConsentAiReceipts.
  ///
  /// In en, this message translates to:
  /// **'AI reading of receipts'**
  String get privacyConsentAiReceipts;

  /// No description provided for @privacyConsentAiReceiptsBody.
  ///
  /// In en, this message translates to:
  /// **'This app never reads receipts automatically. Withdrawing means receipts stay manual everywhere.'**
  String get privacyConsentAiReceiptsBody;

  /// No description provided for @privacyConsentOther.
  ///
  /// In en, this message translates to:
  /// **'Other consent'**
  String get privacyConsentOther;

  /// No description provided for @privacyConsentGiven.
  ///
  /// In en, this message translates to:
  /// **'Consent given.'**
  String get privacyConsentGiven;

  /// No description provided for @privacyConsentWithdrawn.
  ///
  /// In en, this message translates to:
  /// **'Consent withdrawn.'**
  String get privacyConsentWithdrawn;

  /// No description provided for @privacyConsentVersionMissing.
  ///
  /// In en, this message translates to:
  /// **'The current wording couldn\'t be loaded. Pull down to refresh, then try again.'**
  String get privacyConsentVersionMissing;

  /// No description provided for @privacyRequiredConsentError.
  ///
  /// In en, this message translates to:
  /// **'Terms and privacy consent are needed to use Montra. To withdraw them, delete your account.'**
  String get privacyRequiredConsentError;

  /// No description provided for @privacyExportTitle.
  ///
  /// In en, this message translates to:
  /// **'A copy of your data'**
  String get privacyExportTitle;

  /// No description provided for @privacyExportIntro.
  ///
  /// In en, this message translates to:
  /// **'Get everything Montra keeps about you as one ZIP file. It\'s made in the background; download it here when it\'s ready, then share it or save it to your device.'**
  String get privacyExportIntro;

  /// No description provided for @privacyExportRequest.
  ///
  /// In en, this message translates to:
  /// **'Request a copy'**
  String get privacyExportRequest;

  /// No description provided for @privacyExportRequested.
  ///
  /// In en, this message translates to:
  /// **'Your copy is being made. This page updates by itself.'**
  String get privacyExportRequested;

  /// No description provided for @privacyExportNone.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t requested a copy yet.'**
  String get privacyExportNone;

  /// No description provided for @privacyExportStillWorking.
  ///
  /// In en, this message translates to:
  /// **'Still being made. Pull down to check again.'**
  String get privacyExportStillWorking;

  /// No description provided for @privacyExportRequestedOn.
  ///
  /// In en, this message translates to:
  /// **'Requested {date}'**
  String privacyExportRequestedOn(String date);

  /// No description provided for @privacyExportQueued.
  ///
  /// In en, this message translates to:
  /// **'Waiting to start'**
  String get privacyExportQueued;

  /// No description provided for @privacyExportRunning.
  ///
  /// In en, this message translates to:
  /// **'Being made'**
  String get privacyExportRunning;

  /// No description provided for @privacyExportReady.
  ///
  /// In en, this message translates to:
  /// **'Ready to download'**
  String get privacyExportReady;

  /// No description provided for @privacyExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t be made'**
  String get privacyExportFailed;

  /// No description provided for @privacyExportExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get privacyExportExpired;

  /// No description provided for @privacyExportExpires.
  ///
  /// In en, this message translates to:
  /// **'Available until {date}'**
  String privacyExportExpires(String date);

  /// No description provided for @privacyExportFailedHelp.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong while making it. Request a new copy.'**
  String get privacyExportFailedHelp;

  /// No description provided for @privacyExportExpiredHelp.
  ///
  /// In en, this message translates to:
  /// **'Its download period ended and the file was removed. Request a new copy.'**
  String get privacyExportExpiredHelp;

  /// No description provided for @privacyExportDownload.
  ///
  /// In en, this message translates to:
  /// **'Download your data'**
  String get privacyExportDownload;

  /// No description provided for @privacyExportReadyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your data is ready'**
  String get privacyExportReadyTitle;

  /// No description provided for @privacyAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Your account'**
  String get privacyAccountTitle;

  /// No description provided for @privacyLimitsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Fair-use limits and your storage'**
  String get privacyLimitsSubtitle;

  /// No description provided for @privacyDeactivateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Take a break; sign in again to come back'**
  String get privacyDeactivateSubtitle;

  /// No description provided for @privacyDeletionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete your account and data'**
  String get privacyDeletionSubtitle;

  /// No description provided for @privacyDeletionScheduledSubtitle.
  ///
  /// In en, this message translates to:
  /// **'See the date or cancel it'**
  String get privacyDeletionScheduledSubtitle;

  /// No description provided for @deactivateTitle.
  ///
  /// In en, this message translates to:
  /// **'Close your account for now'**
  String get deactivateTitle;

  /// No description provided for @deactivateIntro.
  ///
  /// In en, this message translates to:
  /// **'Closing your account is a break, not a deletion.'**
  String get deactivateIntro;

  /// No description provided for @deactivatePointSignedOut.
  ///
  /// In en, this message translates to:
  /// **'You\'ll be signed out on every device.'**
  String get deactivatePointSignedOut;

  /// No description provided for @deactivatePointKept.
  ///
  /// In en, this message translates to:
  /// **'Your records stay as they are; nothing is deleted.'**
  String get deactivatePointKept;

  /// No description provided for @deactivatePointHidden.
  ///
  /// In en, this message translates to:
  /// **'Others can\'t find you or send you requests while it\'s closed.'**
  String get deactivatePointHidden;

  /// No description provided for @deactivatePointReturn.
  ///
  /// In en, this message translates to:
  /// **'To come back, just sign in again.'**
  String get deactivatePointReturn;

  /// No description provided for @deactivateAction.
  ///
  /// In en, this message translates to:
  /// **'Close my account'**
  String get deactivateAction;

  /// No description provided for @deactivateConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Close your account?'**
  String get deactivateConfirmTitle;

  /// No description provided for @deactivateConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'You\'ll be signed out everywhere. Sign in again whenever you want to come back.'**
  String get deactivateConfirmBody;

  /// No description provided for @deletionTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete your account'**
  String get deletionTitle;

  /// No description provided for @deletionIntro.
  ///
  /// In en, this message translates to:
  /// **'Deleting your account is permanent after a short waiting period. You can cancel until then.'**
  String get deletionIntro;

  /// No description provided for @deletionWhatHappens.
  ///
  /// In en, this message translates to:
  /// **'What happens'**
  String get deletionWhatHappens;

  /// No description provided for @deletionWhatIsKept.
  ///
  /// In en, this message translates to:
  /// **'What is kept, and why'**
  String get deletionWhatIsKept;

  /// No description provided for @deletionGroupsTitle.
  ///
  /// In en, this message translates to:
  /// **'Your groups'**
  String get deletionGroupsTitle;

  /// No description provided for @deletionConsequenceSignedOut.
  ///
  /// In en, this message translates to:
  /// **'You\'ll be signed out of every device and connected services will be disconnected.'**
  String get deletionConsequenceSignedOut;

  /// No description provided for @deletionConsequenceRecords.
  ///
  /// In en, this message translates to:
  /// **'Your accounts, transactions, budgets, goals, subscriptions, receipts, imports and reports will be permanently deleted.'**
  String get deletionConsequenceRecords;

  /// No description provided for @deletionConsequenceDocuments.
  ///
  /// In en, this message translates to:
  /// **'Files you uploaded will be removed from storage.'**
  String get deletionConsequenceDocuments;

  /// No description provided for @deletionConsequenceProfile.
  ///
  /// In en, this message translates to:
  /// **'Your profile will be removed; your community posts and comments will no longer show your name.'**
  String get deletionConsequenceProfile;

  /// No description provided for @deletionConsequenceIrreversible.
  ///
  /// In en, this message translates to:
  /// **'After the scheduled date this can\'t be undone.'**
  String get deletionConsequenceIrreversible;

  /// No description provided for @deletionRetainedGroupRecords.
  ///
  /// In en, this message translates to:
  /// **'Shared group expenses and settlements stay, without your name, so other members\' balances remain correct.'**
  String get deletionRetainedGroupRecords;

  /// No description provided for @deletionRetainedAudit.
  ///
  /// In en, this message translates to:
  /// **'Security records are kept for a limited time, as the law requires.'**
  String get deletionRetainedAudit;

  /// No description provided for @deletionGroupTransfer.
  ///
  /// In en, this message translates to:
  /// **'{group}: ownership will pass to its longest-standing admin or member.'**
  String deletionGroupTransfer(String group);

  /// No description provided for @deletionGroupDeleted.
  ///
  /// In en, this message translates to:
  /// **'{group}: it has no other members and will be deleted.'**
  String deletionGroupDeleted(String group);

  /// No description provided for @deletionExportFirst.
  ///
  /// In en, this message translates to:
  /// **'You may want a copy of your data first: request it on the Privacy & data screen.'**
  String get deletionExportFirst;

  /// No description provided for @deletionReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Why are you leaving? (optional)'**
  String get deletionReasonLabel;

  /// No description provided for @deletionReasonHelp.
  ///
  /// In en, this message translates to:
  /// **'This helps us improve. Don\'t include personal details.'**
  String get deletionReasonHelp;

  /// No description provided for @deletionConfirmLabel.
  ///
  /// In en, this message translates to:
  /// **'Type {word} to confirm'**
  String deletionConfirmLabel(String word);

  /// No description provided for @deletionConfirmMismatch.
  ///
  /// In en, this message translates to:
  /// **'Type {word} exactly to confirm.'**
  String deletionConfirmMismatch(String word);

  /// No description provided for @deletionAction.
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get deletionAction;

  /// No description provided for @deletionScheduledDone.
  ///
  /// In en, this message translates to:
  /// **'Deletion scheduled. You can cancel it until the date shown.'**
  String get deletionScheduledDone;

  /// No description provided for @deletionScheduledTitle.
  ///
  /// In en, this message translates to:
  /// **'Account deletion scheduled'**
  String get deletionScheduledTitle;

  /// No description provided for @deletionScheduledFor.
  ///
  /// In en, this message translates to:
  /// **'Your account will be deleted on {date}. You can cancel until then.'**
  String deletionScheduledFor(String date);

  /// No description provided for @deletionScheduledNoDate.
  ///
  /// In en, this message translates to:
  /// **'Your account is scheduled to be deleted. You can still cancel.'**
  String get deletionScheduledNoDate;

  /// No description provided for @deletionCancelAction.
  ///
  /// In en, this message translates to:
  /// **'Keep my account'**
  String get deletionCancelAction;

  /// No description provided for @deletionCancelledDone.
  ///
  /// In en, this message translates to:
  /// **'Deletion cancelled. Your account stays.'**
  String get deletionCancelledDone;

  /// No description provided for @limitsFairUseNote.
  ///
  /// In en, this message translates to:
  /// **'Every feature is free for everyone. These limits are the same for everyone and keep Montra fast and affordable to run.'**
  String get limitsFairUseNote;

  /// No description provided for @limitsStoragePercent.
  ///
  /// In en, this message translates to:
  /// **'{percent} percent used'**
  String limitsStoragePercent(int percent);

  /// No description provided for @limitsUploadSize.
  ///
  /// In en, this message translates to:
  /// **'Largest single upload: {size}'**
  String limitsUploadSize(String size);

  /// No description provided for @limitsOpenRecordsTitle.
  ///
  /// In en, this message translates to:
  /// **'Open records you can keep'**
  String get limitsOpenRecordsTitle;

  /// No description provided for @limitsOpenBillsLabel.
  ///
  /// In en, this message translates to:
  /// **'Open bills'**
  String get limitsOpenBillsLabel;

  /// No description provided for @limitsOpenRecurringLabel.
  ///
  /// In en, this message translates to:
  /// **'Recurring payments'**
  String get limitsOpenRecurringLabel;

  /// No description provided for @limitsOpenSubscriptionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions'**
  String get limitsOpenSubscriptionsLabel;

  /// No description provided for @limitsOpenGoalsLabel.
  ///
  /// In en, this message translates to:
  /// **'Goals'**
  String get limitsOpenGoalsLabel;

  /// No description provided for @limitsOpenRecordsHelp.
  ///
  /// In en, this message translates to:
  /// **'Ended, archived and deleted ones don\'t count.'**
  String get limitsOpenRecordsHelp;

  /// No description provided for @limitsOtherTitle.
  ///
  /// In en, this message translates to:
  /// **'Imports, support and downloads'**
  String get limitsOtherTitle;

  /// No description provided for @limitsImportRowsLabel.
  ///
  /// In en, this message translates to:
  /// **'Rows per statement import'**
  String get limitsImportRowsLabel;

  /// No description provided for @limitsSupportPerDayLabel.
  ///
  /// In en, this message translates to:
  /// **'Support requests per day'**
  String get limitsSupportPerDayLabel;

  /// No description provided for @limitsExportDaysLabel.
  ///
  /// In en, this message translates to:
  /// **'Reports and data copies stay downloadable'**
  String get limitsExportDaysLabel;

  /// No description provided for @limitsDeletionGraceLabel.
  ///
  /// In en, this message translates to:
  /// **'Waiting period before deletion'**
  String get limitsDeletionGraceLabel;

  /// No description provided for @limitsDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String limitsDays(int count);

  /// No description provided for @limitsRatesTitle.
  ///
  /// In en, this message translates to:
  /// **'Requests per minute'**
  String get limitsRatesTitle;

  /// No description provided for @limitsRatesHelp.
  ///
  /// In en, this message translates to:
  /// **'Short bursts above these are fine. If you go past a limit, the app tells you when to try again.'**
  String get limitsRatesHelp;

  /// No description provided for @limitsPerMinute.
  ///
  /// In en, this message translates to:
  /// **'{count} a minute'**
  String limitsPerMinute(String count);

  /// No description provided for @limitsPolicyDefault.
  ///
  /// In en, this message translates to:
  /// **'Reading'**
  String get limitsPolicyDefault;

  /// No description provided for @limitsPolicyAuth.
  ///
  /// In en, this message translates to:
  /// **'Signing in'**
  String get limitsPolicyAuth;

  /// No description provided for @limitsPolicyWrite.
  ///
  /// In en, this message translates to:
  /// **'Saving changes'**
  String get limitsPolicyWrite;

  /// No description provided for @limitsPolicyUpload.
  ///
  /// In en, this message translates to:
  /// **'Uploads'**
  String get limitsPolicyUpload;

  /// No description provided for @limitsPolicyAi.
  ///
  /// In en, this message translates to:
  /// **'AI'**
  String get limitsPolicyAi;

  /// No description provided for @limitsPolicyExport.
  ///
  /// In en, this message translates to:
  /// **'Exports'**
  String get limitsPolicyExport;

  /// No description provided for @limitsPolicySocial.
  ///
  /// In en, this message translates to:
  /// **'Friends and community'**
  String get limitsPolicySocial;

  /// No description provided for @limitsPolicyOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get limitsPolicyOther;

  /// No description provided for @notifViewInbox.
  ///
  /// In en, this message translates to:
  /// **'Inbox'**
  String get notifViewInbox;

  /// No description provided for @notifViewUnread.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get notifViewUnread;

  /// No description provided for @notifViewArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get notifViewArchive;

  /// No description provided for @notifCategoryFilter.
  ///
  /// In en, this message translates to:
  /// **'Show notifications about'**
  String get notifCategoryFilter;

  /// No description provided for @notifCategoryAll.
  ///
  /// In en, this message translates to:
  /// **'All topics'**
  String get notifCategoryAll;

  /// No description provided for @notifReadAll.
  ///
  /// In en, this message translates to:
  /// **'Mark all as read'**
  String get notifReadAll;

  /// No description provided for @notifReadAllDone.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nothing was unread.} =1{1 notification marked as read.} other{{count} notifications marked as read.}}'**
  String notifReadAllDone(int count);

  /// No description provided for @notifSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification settings'**
  String get notifSettingsTitle;

  /// No description provided for @notifActions.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get notifActions;

  /// No description provided for @notifMarkRead.
  ///
  /// In en, this message translates to:
  /// **'Mark as read'**
  String get notifMarkRead;

  /// No description provided for @notifMarkUnread.
  ///
  /// In en, this message translates to:
  /// **'Mark as unread'**
  String get notifMarkUnread;

  /// No description provided for @notifArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get notifArchive;

  /// No description provided for @notifMoveToInbox.
  ///
  /// In en, this message translates to:
  /// **'Move back to inbox'**
  String get notifMoveToInbox;

  /// No description provided for @notifMarkedRead.
  ///
  /// In en, this message translates to:
  /// **'Marked as read.'**
  String get notifMarkedRead;

  /// No description provided for @notifMarkedUnread.
  ///
  /// In en, this message translates to:
  /// **'Marked as unread.'**
  String get notifMarkedUnread;

  /// No description provided for @notifArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived.'**
  String get notifArchived;

  /// No description provided for @notifMovedToInbox.
  ///
  /// In en, this message translates to:
  /// **'Moved back to the inbox.'**
  String get notifMovedToInbox;

  /// No description provided for @notifNothingToOpen.
  ///
  /// In en, this message translates to:
  /// **'This notification has nothing more to open.'**
  String get notifNothingToOpen;

  /// No description provided for @notifUnreadLabel.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get notifUnreadLabel;

  /// No description provided for @notifEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No notifications'**
  String get notifEmptyTitle;

  /// No description provided for @notifEmptyUnreadTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re all caught up'**
  String get notifEmptyUnreadTitle;

  /// No description provided for @notifEmptyArchiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing archived'**
  String get notifEmptyArchiveTitle;

  /// No description provided for @notifEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Reminders and updates about your money, groups and account appear here.'**
  String get notifEmptyBody;

  /// No description provided for @notifPriorityHigh.
  ///
  /// In en, this message translates to:
  /// **'Important'**
  String get notifPriorityHigh;

  /// No description provided for @notifPriorityCritical.
  ///
  /// In en, this message translates to:
  /// **'Urgent'**
  String get notifPriorityCritical;

  /// No description provided for @notifCategoryBudget.
  ///
  /// In en, this message translates to:
  /// **'Budgets'**
  String get notifCategoryBudget;

  /// No description provided for @notifCategoryBill.
  ///
  /// In en, this message translates to:
  /// **'Bills'**
  String get notifCategoryBill;

  /// No description provided for @notifCategorySubscription.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions'**
  String get notifCategorySubscription;

  /// No description provided for @notifCategoryRecurring.
  ///
  /// In en, this message translates to:
  /// **'Recurring payments'**
  String get notifCategoryRecurring;

  /// No description provided for @notifCategoryGoal.
  ///
  /// In en, this message translates to:
  /// **'Goals'**
  String get notifCategoryGoal;

  /// No description provided for @notifCategoryGroup.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get notifCategoryGroup;

  /// No description provided for @notifCategorySettlement.
  ///
  /// In en, this message translates to:
  /// **'Settlements'**
  String get notifCategorySettlement;

  /// No description provided for @notifCategoryTrip.
  ///
  /// In en, this message translates to:
  /// **'Trips'**
  String get notifCategoryTrip;

  /// No description provided for @notifCategoryCommunity.
  ///
  /// In en, this message translates to:
  /// **'Communities'**
  String get notifCategoryCommunity;

  /// No description provided for @notifCategoryChallenge.
  ///
  /// In en, this message translates to:
  /// **'Challenges'**
  String get notifCategoryChallenge;

  /// No description provided for @notifCategorySecurity.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get notifCategorySecurity;

  /// No description provided for @notifCategoryImport.
  ///
  /// In en, this message translates to:
  /// **'Statement imports'**
  String get notifCategoryImport;

  /// No description provided for @notifCategoryReceipt.
  ///
  /// In en, this message translates to:
  /// **'Receipts'**
  String get notifCategoryReceipt;

  /// No description provided for @notifCategoryExport.
  ///
  /// In en, this message translates to:
  /// **'Data exports'**
  String get notifCategoryExport;

  /// No description provided for @notifCategoryAccount.
  ///
  /// In en, this message translates to:
  /// **'Your account'**
  String get notifCategoryAccount;

  /// No description provided for @notifCategoryInsight.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get notifCategoryInsight;

  /// No description provided for @notifCategorySystem.
  ///
  /// In en, this message translates to:
  /// **'Montra updates'**
  String get notifCategorySystem;

  /// No description provided for @notifCategorySocial.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get notifCategorySocial;

  /// No description provided for @notifChannelInApp.
  ///
  /// In en, this message translates to:
  /// **'In the app'**
  String get notifChannelInApp;

  /// No description provided for @notifChannelEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get notifChannelEmail;

  /// No description provided for @notifChannelPush.
  ///
  /// In en, this message translates to:
  /// **'Phone notifications'**
  String get notifChannelPush;

  /// No description provided for @notifChannelWebPush.
  ///
  /// In en, this message translates to:
  /// **'Browser notifications'**
  String get notifChannelWebPush;

  /// No description provided for @notifDigestFollowAccount.
  ///
  /// In en, this message translates to:
  /// **'Same as your email digest setting'**
  String get notifDigestFollowAccount;

  /// No description provided for @notifDigestDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily digest'**
  String get notifDigestDaily;

  /// No description provided for @notifDigestWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly digest (Mondays)'**
  String get notifDigestWeekly;

  /// No description provided for @notifDigestOff.
  ///
  /// In en, this message translates to:
  /// **'Off: send each email right away'**
  String get notifDigestOff;

  /// No description provided for @notifPushTitle.
  ///
  /// In en, this message translates to:
  /// **'Phone notifications are not set up'**
  String get notifPushTitle;

  /// No description provided for @notifPushNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'This version of the app doesn\'t receive push notifications. Everything you turn on below appears in the notification center in the app, and by email where you choose email.'**
  String get notifPushNotConfigured;

  /// No description provided for @notifPushChannelNote.
  ///
  /// In en, this message translates to:
  /// **'Not set up in this version of the app'**
  String get notifPushChannelNote;

  /// No description provided for @notifWebPushChannelNote.
  ///
  /// In en, this message translates to:
  /// **'For the Montra website in a browser'**
  String get notifWebPushChannelNote;

  /// No description provided for @notifAlwaysOn.
  ///
  /// In en, this message translates to:
  /// **'Always on'**
  String get notifAlwaysOn;

  /// No description provided for @notifAlwaysOnNote.
  ///
  /// In en, this message translates to:
  /// **'Security and account notifications always reach you in the app and by email, so you never miss a sign-in or account change.'**
  String get notifAlwaysOnNote;

  /// No description provided for @notifAlwaysOnError.
  ///
  /// In en, this message translates to:
  /// **'Security and account notifications can\'t be turned off.'**
  String get notifAlwaysOnError;

  /// No description provided for @notifEmailTiming.
  ///
  /// In en, this message translates to:
  /// **'When emails arrive'**
  String get notifEmailTiming;

  /// No description provided for @notifEmailTimingFor.
  ///
  /// In en, this message translates to:
  /// **'Emails about {category}'**
  String notifEmailTimingFor(String category);

  /// No description provided for @notifSettingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved.'**
  String get notifSettingsSaved;

  /// No description provided for @notifEmailAndQuietTitle.
  ///
  /// In en, this message translates to:
  /// **'Email digest and quiet hours'**
  String get notifEmailAndQuietTitle;

  /// No description provided for @notifAccountDigestTitle.
  ///
  /// In en, this message translates to:
  /// **'Email digest'**
  String get notifAccountDigestTitle;

  /// No description provided for @notifAccountDigestHelp.
  ///
  /// In en, this message translates to:
  /// **'Optional emails can be collected into one email at 08:00 your time (weekly on Mondays). Security, account and urgent emails always arrive right away.'**
  String get notifAccountDigestHelp;

  /// No description provided for @notifQuietHoursTitle.
  ///
  /// In en, this message translates to:
  /// **'Quiet hours'**
  String get notifQuietHoursTitle;

  /// No description provided for @notifQuietHoursHelp.
  ///
  /// In en, this message translates to:
  /// **'During quiet hours, emails and other alerts wait until the quiet hours end. Security and urgent ones still arrive. The notification center in the app is updated as usual.'**
  String get notifQuietHoursHelp;

  /// No description provided for @notifQuietHoursFrom.
  ///
  /// In en, this message translates to:
  /// **'Starts at'**
  String get notifQuietHoursFrom;

  /// No description provided for @notifQuietHoursTo.
  ///
  /// In en, this message translates to:
  /// **'Ends at'**
  String get notifQuietHoursTo;

  /// No description provided for @notifQuietHoursZone.
  ///
  /// In en, this message translates to:
  /// **'Times are in your time zone ({zone}).'**
  String notifQuietHoursZone(String zone);

  /// No description provided for @notifGroupOverridesTitle.
  ///
  /// In en, this message translates to:
  /// **'Group settings'**
  String get notifGroupOverridesTitle;

  /// No description provided for @notifGroupOverridesHelp.
  ///
  /// In en, this message translates to:
  /// **'These groups have their own setting for some topics.'**
  String get notifGroupOverridesHelp;

  /// No description provided for @notifGroupUnknown.
  ///
  /// In en, this message translates to:
  /// **'A group'**
  String get notifGroupUnknown;

  /// No description provided for @integrationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Bank connections'**
  String get integrationsTitle;

  /// No description provided for @integrationIntro.
  ///
  /// In en, this message translates to:
  /// **'Montra works fully without connections: add transactions yourself or import statements. A connection would bring in transactions from your bank after you approve it at the bank or provider; Montra never asks for your bank password.'**
  String get integrationIntro;

  /// No description provided for @integrationConnectionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Your connections'**
  String get integrationConnectionsTitle;

  /// No description provided for @integrationNoConnections.
  ///
  /// In en, this message translates to:
  /// **'You have no connections.'**
  String get integrationNoConnections;

  /// No description provided for @integrationProvidersTitle.
  ///
  /// In en, this message translates to:
  /// **'Providers'**
  String get integrationProvidersTitle;

  /// No description provided for @integrationNoProviders.
  ///
  /// In en, this message translates to:
  /// **'No providers are listed.'**
  String get integrationNoProviders;

  /// No description provided for @integrationCallbackNote.
  ///
  /// In en, this message translates to:
  /// **'After you approve access at the provider, it sends you back to the Montra website, which finishes connecting. Then come back here and pull down to refresh.'**
  String get integrationCallbackNote;

  /// No description provided for @integrationStatusAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get integrationStatusAvailable;

  /// No description provided for @integrationStatusNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Not configured'**
  String get integrationStatusNotConfigured;

  /// No description provided for @integrationStatusUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Not available yet'**
  String get integrationStatusUnavailable;

  /// No description provided for @integrationNotConfiguredHelp.
  ///
  /// In en, this message translates to:
  /// **'This provider isn\'t configured on this Montra server, so it can\'t be connected.'**
  String get integrationNotConfiguredHelp;

  /// No description provided for @integrationUnavailableHelp.
  ///
  /// In en, this message translates to:
  /// **'This provider can\'t be connected yet.'**
  String get integrationUnavailableHelp;

  /// No description provided for @integrationReason.
  ///
  /// In en, this message translates to:
  /// **'Details from Montra: {reason}'**
  String integrationReason(String reason);

  /// No description provided for @integrationKindBankData.
  ///
  /// In en, this message translates to:
  /// **'Bank data'**
  String get integrationKindBankData;

  /// No description provided for @integrationKindAccountAggregator.
  ///
  /// In en, this message translates to:
  /// **'Account Aggregator'**
  String get integrationKindAccountAggregator;

  /// No description provided for @integrationKindCard.
  ///
  /// In en, this message translates to:
  /// **'Cards'**
  String get integrationKindCard;

  /// No description provided for @integrationKindPayments.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get integrationKindPayments;

  /// No description provided for @integrationKindOther.
  ///
  /// In en, this message translates to:
  /// **'Other provider'**
  String get integrationKindOther;

  /// No description provided for @integrationCountries.
  ///
  /// In en, this message translates to:
  /// **'Countries: {countries}'**
  String integrationCountries(String countries);

  /// No description provided for @integrationCapabilities.
  ///
  /// In en, this message translates to:
  /// **'Brings in: {items}'**
  String integrationCapabilities(String items);

  /// No description provided for @integrationScopeTransactions.
  ///
  /// In en, this message translates to:
  /// **'transactions'**
  String get integrationScopeTransactions;

  /// No description provided for @integrationScopeBalances.
  ///
  /// In en, this message translates to:
  /// **'balances'**
  String get integrationScopeBalances;

  /// No description provided for @integrationScopeAccounts.
  ///
  /// In en, this message translates to:
  /// **'accounts'**
  String get integrationScopeAccounts;

  /// No description provided for @integrationScopeStatements.
  ///
  /// In en, this message translates to:
  /// **'statements'**
  String get integrationScopeStatements;

  /// No description provided for @integrationConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get integrationConnect;

  /// No description provided for @integrationChooseAccount.
  ///
  /// In en, this message translates to:
  /// **'Account to connect'**
  String get integrationChooseAccount;

  /// No description provided for @integrationConsentTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect {provider}?'**
  String integrationConsentTitle(String provider);

  /// No description provided for @integrationConsentPurpose.
  ///
  /// In en, this message translates to:
  /// **'Why Montra asks:'**
  String get integrationConsentPurpose;

  /// No description provided for @integrationConsentScope.
  ///
  /// In en, this message translates to:
  /// **'What Montra can read: {items}'**
  String integrationConsentScope(String items);

  /// No description provided for @integrationConsentDays.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{Access lasts 1 day; you can disconnect at any time.} other{Access lasts {days} days; you can disconnect at any time.}}'**
  String integrationConsentDays(int days);

  /// No description provided for @integrationNoCredentials.
  ///
  /// In en, this message translates to:
  /// **'You approve access at the provider. Montra never asks for your bank password or PIN.'**
  String get integrationNoCredentials;

  /// No description provided for @integrationConsentCheck.
  ///
  /// In en, this message translates to:
  /// **'I agree to share this data with Montra'**
  String get integrationConsentCheck;

  /// No description provided for @integrationContinueTitle.
  ///
  /// In en, this message translates to:
  /// **'Continue at the provider'**
  String get integrationContinueTitle;

  /// No description provided for @integrationContinueBody.
  ///
  /// In en, this message translates to:
  /// **'{provider} opened in your browser. Approve access there. You\'ll be sent back to the Montra website, which finishes connecting; then pull down here to see the connection.'**
  String integrationContinueBody(String provider);

  /// No description provided for @integrationOpenFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the provider'**
  String get integrationOpenFailedTitle;

  /// No description provided for @integrationOpenFailedBody.
  ///
  /// In en, this message translates to:
  /// **'Your browser couldn\'t be opened. Try again, or connect from the Montra website.'**
  String get integrationOpenFailedBody;

  /// No description provided for @integrationNeverSynced.
  ///
  /// In en, this message translates to:
  /// **'Not synced yet'**
  String get integrationNeverSynced;

  /// No description provided for @integrationLastSync.
  ///
  /// In en, this message translates to:
  /// **'Last synced {when}'**
  String integrationLastSync(String when);

  /// No description provided for @integrationLastSyncLabel.
  ///
  /// In en, this message translates to:
  /// **'Last synced'**
  String get integrationLastSyncLabel;

  /// No description provided for @integrationConnectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get integrationConnectionTitle;

  /// No description provided for @integrationConnPending.
  ///
  /// In en, this message translates to:
  /// **'Waiting for approval'**
  String get integrationConnPending;

  /// No description provided for @integrationConnConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get integrationConnConnected;

  /// No description provided for @integrationConnSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing'**
  String get integrationConnSyncing;

  /// No description provided for @integrationConnPartial.
  ///
  /// In en, this message translates to:
  /// **'Partly synced'**
  String get integrationConnPartial;

  /// No description provided for @integrationConnFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync failed'**
  String get integrationConnFailed;

  /// No description provided for @integrationConnConsentExpired.
  ///
  /// In en, this message translates to:
  /// **'Consent expired'**
  String get integrationConnConsentExpired;

  /// No description provided for @integrationConnDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get integrationConnDisconnected;

  /// No description provided for @integrationConnRevoked.
  ///
  /// In en, this message translates to:
  /// **'Access removed'**
  String get integrationConnRevoked;

  /// No description provided for @integrationScopeLabel.
  ///
  /// In en, this message translates to:
  /// **'Data shared'**
  String get integrationScopeLabel;

  /// No description provided for @integrationConsentGranted.
  ///
  /// In en, this message translates to:
  /// **'Consent given'**
  String get integrationConsentGranted;

  /// No description provided for @integrationConsentExpires.
  ///
  /// In en, this message translates to:
  /// **'Consent ends'**
  String get integrationConsentExpires;

  /// No description provided for @integrationLinkedAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get integrationLinkedAccount;

  /// No description provided for @integrationOpenAccount.
  ///
  /// In en, this message translates to:
  /// **'Open the account'**
  String get integrationOpenAccount;

  /// No description provided for @integrationLastProblem.
  ///
  /// In en, this message translates to:
  /// **'Last problem'**
  String get integrationLastProblem;

  /// No description provided for @integrationSyncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get integrationSyncNow;

  /// No description provided for @integrationSyncStarted.
  ///
  /// In en, this message translates to:
  /// **'Sync started. Pull down to see its progress.'**
  String get integrationSyncStarted;

  /// No description provided for @integrationSyncRunning.
  ///
  /// In en, this message translates to:
  /// **'A sync is already running. Try again when it finishes.'**
  String get integrationSyncRunning;

  /// No description provided for @integrationDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get integrationDisconnect;

  /// No description provided for @integrationDisconnectTitle.
  ///
  /// In en, this message translates to:
  /// **'Disconnect?'**
  String get integrationDisconnectTitle;

  /// No description provided for @integrationDisconnectBody.
  ///
  /// In en, this message translates to:
  /// **'Montra stops reading from this provider and deletes what it stored to connect. Transactions it brought in stay unless you choose below.'**
  String get integrationDisconnectBody;

  /// No description provided for @integrationDeleteData.
  ///
  /// In en, this message translates to:
  /// **'Also remove the transactions it brought in'**
  String get integrationDeleteData;

  /// No description provided for @integrationDeleteDataHelp.
  ///
  /// In en, this message translates to:
  /// **'They\'re voided, so balances and reports no longer count them.'**
  String get integrationDeleteDataHelp;

  /// No description provided for @integrationDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected.'**
  String get integrationDisconnected;

  /// No description provided for @integrationDisconnectedVoided.
  ///
  /// In en, this message translates to:
  /// **'{voided, plural, =0{Disconnected. No transactions needed removing.} =1{Disconnected. 1 transaction was removed.} other{Disconnected. {voided} transactions were removed.}}'**
  String integrationDisconnectedVoided(int voided);

  /// No description provided for @integrationRunsTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent syncs'**
  String get integrationRunsTitle;

  /// No description provided for @integrationNoRuns.
  ///
  /// In en, this message translates to:
  /// **'No syncs yet.'**
  String get integrationNoRuns;

  /// No description provided for @integrationRunQueued.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get integrationRunQueued;

  /// No description provided for @integrationRunRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get integrationRunRunning;

  /// No description provided for @integrationRunSucceeded.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get integrationRunSucceeded;

  /// No description provided for @integrationRunPartial.
  ///
  /// In en, this message translates to:
  /// **'Partly done'**
  String get integrationRunPartial;

  /// No description provided for @integrationRunFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get integrationRunFailed;

  /// No description provided for @integrationTriggerManual.
  ///
  /// In en, this message translates to:
  /// **'started by you'**
  String get integrationTriggerManual;

  /// No description provided for @integrationTriggerScheduled.
  ///
  /// In en, this message translates to:
  /// **'scheduled'**
  String get integrationTriggerScheduled;

  /// No description provided for @integrationTriggerWebhook.
  ///
  /// In en, this message translates to:
  /// **'sent by the provider'**
  String get integrationTriggerWebhook;

  /// No description provided for @integrationTriggerBackfill.
  ///
  /// In en, this message translates to:
  /// **'first import'**
  String get integrationTriggerBackfill;

  /// No description provided for @integrationRunCounts.
  ///
  /// In en, this message translates to:
  /// **'Fetched {fetched} · added {created} · updated {updated} · skipped {skipped}'**
  String integrationRunCounts(
    int fetched,
    int created,
    int updated,
    int skipped,
  );

  /// No description provided for @integrationConsentExpired.
  ///
  /// In en, this message translates to:
  /// **'Your consent for this connection expired. Connect again to renew it.'**
  String get integrationConsentExpired;

  /// No description provided for @integrationReconnectRequired.
  ///
  /// In en, this message translates to:
  /// **'Connect again before syncing.'**
  String get integrationReconnectRequired;

  /// No description provided for @integrationLinkedNotReversible.
  ///
  /// In en, this message translates to:
  /// **'Linked transactions aren\'t changed by the provider.'**
  String get integrationLinkedNotReversible;

  /// No description provided for @integrationErrorProviderUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The provider didn\'t respond. Try again later.'**
  String get integrationErrorProviderUnavailable;

  /// No description provided for @integrationErrorCode.
  ///
  /// In en, this message translates to:
  /// **'Problem code: {code}'**
  String integrationErrorCode(String code);

  /// No description provided for @searchFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Search your money, groups and posts'**
  String get searchFieldLabel;

  /// No description provided for @searchFieldHelp.
  ///
  /// In en, this message translates to:
  /// **'Type at least 2 characters. Press search to keep it in your recent searches.'**
  String get searchFieldHelp;

  /// No description provided for @searchSubmit.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchSubmit;

  /// No description provided for @searchScopeAll.
  ///
  /// In en, this message translates to:
  /// **'Everything'**
  String get searchScopeAll;

  /// No description provided for @searchSortTitle.
  ///
  /// In en, this message translates to:
  /// **'Sort results'**
  String get searchSortTitle;

  /// No description provided for @searchSortRelevance.
  ///
  /// In en, this message translates to:
  /// **'Best match'**
  String get searchSortRelevance;

  /// No description provided for @searchSortName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get searchSortName;

  /// No description provided for @searchSortRecent.
  ///
  /// In en, this message translates to:
  /// **'Newest first'**
  String get searchSortRecent;

  /// No description provided for @searchSortedBy.
  ///
  /// In en, this message translates to:
  /// **'Sorted by: {sort}'**
  String searchSortedBy(String sort);

  /// No description provided for @searchSectionTransactions.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get searchSectionTransactions;

  /// No description provided for @searchSectionMerchants.
  ///
  /// In en, this message translates to:
  /// **'Merchants'**
  String get searchSectionMerchants;

  /// No description provided for @searchSectionAccounts.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get searchSectionAccounts;

  /// No description provided for @searchSectionCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get searchSectionCategories;

  /// No description provided for @searchSectionBudgets.
  ///
  /// In en, this message translates to:
  /// **'Budgets'**
  String get searchSectionBudgets;

  /// No description provided for @searchSectionGoals.
  ///
  /// In en, this message translates to:
  /// **'Goals'**
  String get searchSectionGoals;

  /// No description provided for @searchSectionBills.
  ///
  /// In en, this message translates to:
  /// **'Bills'**
  String get searchSectionBills;

  /// No description provided for @searchSectionSubscriptions.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions'**
  String get searchSectionSubscriptions;

  /// No description provided for @searchSectionRecurring.
  ///
  /// In en, this message translates to:
  /// **'Recurring payments'**
  String get searchSectionRecurring;

  /// No description provided for @searchSectionGroups.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get searchSectionGroups;

  /// No description provided for @searchSectionPosts.
  ///
  /// In en, this message translates to:
  /// **'Community posts'**
  String get searchSectionPosts;

  /// No description provided for @searchSectionPeople.
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get searchSectionPeople;

  /// No description provided for @searchPeopleNote.
  ///
  /// In en, this message translates to:
  /// **'People are found only by their exact username, and only if they allow it.'**
  String get searchPeopleNote;

  /// No description provided for @searchKindExpense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get searchKindExpense;

  /// No description provided for @searchKindIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get searchKindIncome;

  /// No description provided for @searchKindTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get searchKindTransfer;

  /// No description provided for @searchGroupHousehold.
  ///
  /// In en, this message translates to:
  /// **'Household'**
  String get searchGroupHousehold;

  /// No description provided for @searchGroupRoommates.
  ///
  /// In en, this message translates to:
  /// **'Roommates'**
  String get searchGroupRoommates;

  /// No description provided for @searchGroupTrip.
  ///
  /// In en, this message translates to:
  /// **'Trip'**
  String get searchGroupTrip;

  /// No description provided for @searchGroupEvent.
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get searchGroupEvent;

  /// No description provided for @searchGroupFriends.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get searchGroupFriends;

  /// No description provided for @searchGroupCustom.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get searchGroupCustom;

  /// No description provided for @searchShared.
  ///
  /// In en, this message translates to:
  /// **'Shared'**
  String get searchShared;

  /// No description provided for @searchUntitled.
  ///
  /// In en, this message translates to:
  /// **'Transaction'**
  String get searchUntitled;

  /// No description provided for @searchNoResults.
  ///
  /// In en, this message translates to:
  /// **'Nothing found'**
  String get searchNoResults;

  /// No description provided for @searchNoResultsBody.
  ///
  /// In en, this message translates to:
  /// **'Try other words or another section.'**
  String get searchNoResultsBody;

  /// No description provided for @searchStartTitle.
  ///
  /// In en, this message translates to:
  /// **'Search Montra'**
  String get searchStartTitle;

  /// No description provided for @searchStartBody.
  ///
  /// In en, this message translates to:
  /// **'Find transactions, merchants, accounts, budgets, goals, bills, subscriptions, groups and community posts.'**
  String get searchStartBody;

  /// No description provided for @searchRecentTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent searches'**
  String get searchRecentTitle;

  /// No description provided for @searchClearRecent.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get searchClearRecent;

  /// No description provided for @searchClearRecentTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear recent searches?'**
  String get searchClearRecentTitle;

  /// No description provided for @searchClearRecentBody.
  ///
  /// In en, this message translates to:
  /// **'Your search history is removed from Montra.'**
  String get searchClearRecentBody;

  /// No description provided for @searchRecentCleared.
  ///
  /// In en, this message translates to:
  /// **'Recent searches cleared.'**
  String get searchRecentCleared;

  /// No description provided for @insightViewActive.
  ///
  /// In en, this message translates to:
  /// **'Needs a look'**
  String get insightViewActive;

  /// No description provided for @insightViewAll.
  ///
  /// In en, this message translates to:
  /// **'All, including handled'**
  String get insightViewAll;

  /// No description provided for @insightKindFilter.
  ///
  /// In en, this message translates to:
  /// **'Kind of insight'**
  String get insightKindFilter;

  /// No description provided for @insightKindAll.
  ///
  /// In en, this message translates to:
  /// **'All kinds'**
  String get insightKindAll;

  /// No description provided for @insightKindLabel.
  ///
  /// In en, this message translates to:
  /// **'Kind'**
  String get insightKindLabel;

  /// No description provided for @insightKindAnomaly.
  ///
  /// In en, this message translates to:
  /// **'Unusual activity'**
  String get insightKindAnomaly;

  /// No description provided for @insightKindSavings.
  ///
  /// In en, this message translates to:
  /// **'Saving opportunities'**
  String get insightKindSavings;

  /// No description provided for @insightKindSummary.
  ///
  /// In en, this message translates to:
  /// **'Summaries'**
  String get insightKindSummary;

  /// No description provided for @insightKindForecast.
  ///
  /// In en, this message translates to:
  /// **'Outlook'**
  String get insightKindForecast;

  /// No description provided for @insightKindBudget.
  ///
  /// In en, this message translates to:
  /// **'Budgets'**
  String get insightKindBudget;

  /// No description provided for @insightKindSubscription.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions'**
  String get insightKindSubscription;

  /// No description provided for @insightKindRecurring.
  ///
  /// In en, this message translates to:
  /// **'Recurring payments'**
  String get insightKindRecurring;

  /// No description provided for @insightKindOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get insightKindOther;

  /// No description provided for @insightMutesTitle.
  ///
  /// In en, this message translates to:
  /// **'Muted insights'**
  String get insightMutesTitle;

  /// No description provided for @insightRulesNote.
  ///
  /// In en, this message translates to:
  /// **'Insights come from fixed rules over your own records; no AI is used. They never change your records.'**
  String get insightRulesNote;

  /// No description provided for @insightEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing needs a look'**
  String get insightEmptyTitle;

  /// No description provided for @insightEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Montra checks your records for unusual activity and ways to save. New findings appear here.'**
  String get insightEmptyBody;

  /// No description provided for @insightSeverityWarning.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get insightSeverityWarning;

  /// No description provided for @insightSeverityNotice.
  ///
  /// In en, this message translates to:
  /// **'Worth a look'**
  String get insightSeverityNotice;

  /// No description provided for @insightSeverityInfo.
  ///
  /// In en, this message translates to:
  /// **'For your information'**
  String get insightSeverityInfo;

  /// No description provided for @insightStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get insightStatusActive;

  /// No description provided for @insightStatusDismissed.
  ///
  /// In en, this message translates to:
  /// **'Dismissed'**
  String get insightStatusDismissed;

  /// No description provided for @insightStatusSnoozed.
  ///
  /// In en, this message translates to:
  /// **'Snoozed'**
  String get insightStatusSnoozed;

  /// No description provided for @insightStatusExpected.
  ///
  /// In en, this message translates to:
  /// **'Expected'**
  String get insightStatusExpected;

  /// No description provided for @insightStatusResolved.
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get insightStatusResolved;

  /// No description provided for @insightStatusMuted.
  ///
  /// In en, this message translates to:
  /// **'Muted'**
  String get insightStatusMuted;

  /// No description provided for @insightDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Insight'**
  String get insightDetailTitle;

  /// No description provided for @insightNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'This insight isn\'t available'**
  String get insightNotFoundTitle;

  /// No description provided for @insightNotFoundBody.
  ///
  /// In en, this message translates to:
  /// **'It may be too old to show here.'**
  String get insightNotFoundBody;

  /// No description provided for @insightSnoozedUntil.
  ///
  /// In en, this message translates to:
  /// **'Snoozed until {when}'**
  String insightSnoozedUntil(String when);

  /// No description provided for @insightWhyTitle.
  ///
  /// In en, this message translates to:
  /// **'Why you see this'**
  String get insightWhyTitle;

  /// No description provided for @insightRuleUnknown.
  ///
  /// In en, this message translates to:
  /// **'A rule over your own records found this.'**
  String get insightRuleUnknown;

  /// No description provided for @insightPeriod.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get insightPeriod;

  /// No description provided for @insightOpenTransaction.
  ///
  /// In en, this message translates to:
  /// **'Open the transaction'**
  String get insightOpenTransaction;

  /// No description provided for @insightOpenBudget.
  ///
  /// In en, this message translates to:
  /// **'Open the budget'**
  String get insightOpenBudget;

  /// No description provided for @insightOpenSubscription.
  ///
  /// In en, this message translates to:
  /// **'Open the subscription'**
  String get insightOpenSubscription;

  /// No description provided for @insightOpenRecurring.
  ///
  /// In en, this message translates to:
  /// **'Open the recurring payment'**
  String get insightOpenRecurring;

  /// No description provided for @insightOpenMerchant.
  ///
  /// In en, this message translates to:
  /// **'Open the merchant'**
  String get insightOpenMerchant;

  /// No description provided for @insightOpenCategory.
  ///
  /// In en, this message translates to:
  /// **'See this category\'s transactions'**
  String get insightOpenCategory;

  /// No description provided for @insightOpenAccount.
  ///
  /// In en, this message translates to:
  /// **'Open the account'**
  String get insightOpenAccount;

  /// No description provided for @insightActionsTitle.
  ///
  /// In en, this message translates to:
  /// **'What do you want to do?'**
  String get insightActionsTitle;

  /// No description provided for @insightActionsHelp.
  ///
  /// In en, this message translates to:
  /// **'These only change this insight, never your records.'**
  String get insightActionsHelp;

  /// No description provided for @insightActionExpected.
  ///
  /// In en, this message translates to:
  /// **'This was expected'**
  String get insightActionExpected;

  /// No description provided for @insightActionResolved.
  ///
  /// In en, this message translates to:
  /// **'I\'ve dealt with it'**
  String get insightActionResolved;

  /// No description provided for @insightActionSnooze.
  ///
  /// In en, this message translates to:
  /// **'Remind me later'**
  String get insightActionSnooze;

  /// No description provided for @insightActionDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get insightActionDismiss;

  /// No description provided for @insightActionMute.
  ///
  /// In en, this message translates to:
  /// **'Stop showing this kind'**
  String get insightActionMute;

  /// No description provided for @insightActionReopen.
  ///
  /// In en, this message translates to:
  /// **'Open it again'**
  String get insightActionReopen;

  /// No description provided for @insightSnoozeTitle.
  ///
  /// In en, this message translates to:
  /// **'Remind me in'**
  String get insightSnoozeTitle;

  /// No description provided for @insightSnoozeDays.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{1 day} other{{days} days}}'**
  String insightSnoozeDays(int days);

  /// No description provided for @insightSnoozed.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{Snoozed for 1 day.} other{Snoozed for {days} days.}}'**
  String insightSnoozed(int days);

  /// No description provided for @insightDismissed.
  ///
  /// In en, this message translates to:
  /// **'Dismissed.'**
  String get insightDismissed;

  /// No description provided for @insightMarkedExpected.
  ///
  /// In en, this message translates to:
  /// **'Marked as expected.'**
  String get insightMarkedExpected;

  /// No description provided for @insightMarkedResolved.
  ///
  /// In en, this message translates to:
  /// **'Marked as resolved.'**
  String get insightMarkedResolved;

  /// No description provided for @insightMuted.
  ///
  /// In en, this message translates to:
  /// **'Muted. You can unmute it in Muted insights.'**
  String get insightMuted;

  /// No description provided for @insightReopened.
  ///
  /// In en, this message translates to:
  /// **'Opened again.'**
  String get insightReopened;

  /// No description provided for @insightSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved.'**
  String get insightSaved;

  /// No description provided for @insightMute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get insightMute;

  /// No description provided for @insightMuteTitle.
  ///
  /// In en, this message translates to:
  /// **'Stop showing this kind?'**
  String get insightMuteTitle;

  /// No description provided for @insightMuteBody.
  ///
  /// In en, this message translates to:
  /// **'Montra stops showing \"{kind}\" insights about this. You can unmute them at any time in Muted insights.'**
  String insightMuteBody(String kind);

  /// No description provided for @insightFeedbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Was this helpful?'**
  String get insightFeedbackTitle;

  /// No description provided for @insightFeedbackYours.
  ///
  /// In en, this message translates to:
  /// **'Your answer: {answer}'**
  String insightFeedbackYours(String answer);

  /// No description provided for @insightFeedbackNote.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get insightFeedbackNote;

  /// No description provided for @insightFeedbackNoteHelp.
  ///
  /// In en, this message translates to:
  /// **'Sent with your answer. Leave it empty to remove a note you sent before. Don\'t include card numbers or passwords.'**
  String get insightFeedbackNoteHelp;

  /// No description provided for @insightFeedbackHelpful.
  ///
  /// In en, this message translates to:
  /// **'Helpful'**
  String get insightFeedbackHelpful;

  /// No description provided for @insightFeedbackNotHelpful.
  ///
  /// In en, this message translates to:
  /// **'Not helpful'**
  String get insightFeedbackNotHelpful;

  /// No description provided for @insightFeedbackIncorrect.
  ///
  /// In en, this message translates to:
  /// **'Not correct'**
  String get insightFeedbackIncorrect;

  /// No description provided for @insightFeedbackExpected.
  ///
  /// In en, this message translates to:
  /// **'Expected'**
  String get insightFeedbackExpected;

  /// No description provided for @insightFeedbackSaved.
  ///
  /// In en, this message translates to:
  /// **'Thanks, your answer was saved.'**
  String get insightFeedbackSaved;

  /// No description provided for @insightMutesHelp.
  ///
  /// In en, this message translates to:
  /// **'Muted kinds of insight are not shown. Unmuting brings back the insights they were hiding.'**
  String get insightMutesHelp;

  /// No description provided for @insightMutesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing is muted'**
  String get insightMutesEmptyTitle;

  /// No description provided for @insightMutesEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Kinds of insight you mute appear here.'**
  String get insightMutesEmptyBody;

  /// No description provided for @insightMuteEverywhere.
  ///
  /// In en, this message translates to:
  /// **'Everywhere'**
  String get insightMuteEverywhere;

  /// No description provided for @insightMuteOneRecord.
  ///
  /// In en, this message translates to:
  /// **'For one record'**
  String get insightMuteOneRecord;

  /// No description provided for @insightMutedOn.
  ///
  /// In en, this message translates to:
  /// **'muted on {date}'**
  String insightMutedOn(String date);

  /// No description provided for @insightUnmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get insightUnmute;

  /// No description provided for @insightUnmuted.
  ///
  /// In en, this message translates to:
  /// **'{reopened, plural, =0{Unmuted.} =1{Unmuted. 1 insight is back.} other{Unmuted. {reopened} insights are back.}}'**
  String insightUnmuted(int reopened);

  /// No description provided for @insightSubtypeUnusualAmount.
  ///
  /// In en, this message translates to:
  /// **'Unusually large expense'**
  String get insightSubtypeUnusualAmount;

  /// No description provided for @insightSubtypeCategorySpike.
  ///
  /// In en, this message translates to:
  /// **'Category above your usual month'**
  String get insightSubtypeCategorySpike;

  /// No description provided for @insightSubtypeNewMerchant.
  ///
  /// In en, this message translates to:
  /// **'Large first purchase at a merchant'**
  String get insightSubtypeNewMerchant;

  /// No description provided for @insightSubtypeDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Possible duplicate'**
  String get insightSubtypeDuplicate;

  /// No description provided for @insightSubtypePriceIncrease.
  ///
  /// In en, this message translates to:
  /// **'Subscription price increase'**
  String get insightSubtypePriceIncrease;

  /// No description provided for @insightSubtypeMissingRecurring.
  ///
  /// In en, this message translates to:
  /// **'Recurring payment not recorded'**
  String get insightSubtypeMissingRecurring;

  /// No description provided for @insightSubtypeCashFlow.
  ///
  /// In en, this message translates to:
  /// **'Change in monthly cash flow'**
  String get insightSubtypeCashFlow;

  /// No description provided for @insightSubtypeSubscriptionCosts.
  ///
  /// In en, this message translates to:
  /// **'Subscription costs'**
  String get insightSubtypeSubscriptionCosts;

  /// No description provided for @insightSubtypeFrequency.
  ///
  /// In en, this message translates to:
  /// **'More purchases than usual'**
  String get insightSubtypeFrequency;

  /// No description provided for @insightSubtypeRecurringChange.
  ///
  /// In en, this message translates to:
  /// **'Recurring amount changed'**
  String get insightSubtypeRecurringChange;

  /// No description provided for @insightSubtypeOverspend.
  ///
  /// In en, this message translates to:
  /// **'Budget often exceeded'**
  String get insightSubtypeOverspend;

  /// No description provided for @insightRuleUnusualAmount.
  ///
  /// In en, this message translates to:
  /// **'The amount is at least 3 times your usual (median) amount in this category over the last 6 months, and above 95% of those transactions.'**
  String get insightRuleUnusualAmount;

  /// No description provided for @insightRuleCategorySpike.
  ///
  /// In en, this message translates to:
  /// **'What you spent in this category so far this month is more than your average month over the previous 3 months.'**
  String get insightRuleCategorySpike;

  /// No description provided for @insightRuleNewMerchant.
  ///
  /// In en, this message translates to:
  /// **'It\'s your first transaction at this merchant and at least twice your usual (median) expense.'**
  String get insightRuleNewMerchant;

  /// No description provided for @insightRuleDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Two transactions in the same account have the same amount within 2 days, with the same merchant or description.'**
  String get insightRuleDuplicate;

  /// No description provided for @insightRulePriceChange.
  ///
  /// In en, this message translates to:
  /// **'A payment you recorded changed the price of this subscription.'**
  String get insightRulePriceChange;

  /// No description provided for @insightRuleMissingRecurring.
  ///
  /// In en, this message translates to:
  /// **'A recurring payment is overdue and no payment is linked to it.'**
  String get insightRuleMissingRecurring;

  /// No description provided for @insightRuleCashFlow.
  ///
  /// In en, this message translates to:
  /// **'Last month your spending was at least 25% higher, or your income at least 20% lower, than your average over the 3 months before.'**
  String get insightRuleCashFlow;

  /// No description provided for @insightRuleSubscriptionCosts.
  ///
  /// In en, this message translates to:
  /// **'Your active subscriptions, each converted to a monthly cost from how often it bills.'**
  String get insightRuleSubscriptionCosts;

  /// No description provided for @insightRuleFrequency.
  ///
  /// In en, this message translates to:
  /// **'At least 4 purchases at this merchant in 7 days, and at least 3 times your weekly average of the previous 12 weeks.'**
  String get insightRuleFrequency;

  /// No description provided for @insightRuleRecurringChange.
  ///
  /// In en, this message translates to:
  /// **'The latest payment differs by at least 10% from the median of up to 6 earlier payments.'**
  String get insightRuleRecurringChange;

  /// No description provided for @insightRuleOverspend.
  ///
  /// In en, this message translates to:
  /// **'You spent above the limit in at least 2 of the last 3 finished periods.'**
  String get insightRuleOverspend;

  /// No description provided for @insightAmountAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get insightAmountAmount;

  /// No description provided for @insightAmountUsual.
  ///
  /// In en, this message translates to:
  /// **'Usual amount'**
  String get insightAmountUsual;

  /// No description provided for @insightAmountP95.
  ///
  /// In en, this message translates to:
  /// **'Most of your transactions stay below'**
  String get insightAmountP95;

  /// No description provided for @insightAmountTypical.
  ///
  /// In en, this message translates to:
  /// **'Your typical expense'**
  String get insightAmountTypical;

  /// No description provided for @insightAmountSoFar.
  ///
  /// In en, this message translates to:
  /// **'So far this month'**
  String get insightAmountSoFar;

  /// No description provided for @insightAmountMonthlyAverage.
  ///
  /// In en, this message translates to:
  /// **'Average month'**
  String get insightAmountMonthlyAverage;

  /// No description provided for @insightAmountOld.
  ///
  /// In en, this message translates to:
  /// **'Previous price'**
  String get insightAmountOld;

  /// No description provided for @insightAmountNew.
  ///
  /// In en, this message translates to:
  /// **'New price'**
  String get insightAmountNew;

  /// No description provided for @insightAmountSpending.
  ///
  /// In en, this message translates to:
  /// **'Spending'**
  String get insightAmountSpending;

  /// No description provided for @insightAmountUsualSpending.
  ///
  /// In en, this message translates to:
  /// **'Usual spending'**
  String get insightAmountUsualSpending;

  /// No description provided for @insightAmountIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get insightAmountIncome;

  /// No description provided for @insightAmountUsualIncome.
  ///
  /// In en, this message translates to:
  /// **'Usual income'**
  String get insightAmountUsualIncome;

  /// No description provided for @insightAmountMonthly.
  ///
  /// In en, this message translates to:
  /// **'Per month'**
  String get insightAmountMonthly;

  /// No description provided for @insightAmountYearly.
  ///
  /// In en, this message translates to:
  /// **'Per year'**
  String get insightAmountYearly;

  /// No description provided for @insightAmountAverageSpent.
  ///
  /// In en, this message translates to:
  /// **'Average spent'**
  String get insightAmountAverageSpent;

  /// No description provided for @insightAmountAverageOverspend.
  ///
  /// In en, this message translates to:
  /// **'Average amount over'**
  String get insightAmountAverageOverspend;

  /// No description provided for @insightAmountLimit.
  ///
  /// In en, this message translates to:
  /// **'Limit'**
  String get insightAmountLimit;

  /// No description provided for @insightMsgUnusualAmountTitle.
  ///
  /// In en, this message translates to:
  /// **'Unusually large {category} expense'**
  String insightMsgUnusualAmountTitle(String category);

  /// No description provided for @insightMsgUnusualAmountBody.
  ///
  /// In en, this message translates to:
  /// **'{amount} for {label} on {date} is about {ratio}× your usual {category} transaction (median {median} over {count} transactions in the previous {months} months). If it\'s expected, mark it so.'**
  String insightMsgUnusualAmountBody(
    String amount,
    String label,
    String date,
    String ratio,
    String category,
    String median,
    int count,
    int months,
  );

  /// No description provided for @insightMsgCategorySpikeTitle.
  ///
  /// In en, this message translates to:
  /// **'{category} spending is above your usual month'**
  String insightMsgCategorySpikeTitle(String category);

  /// No description provided for @insightMsgCategorySpikeBody.
  ///
  /// In en, this message translates to:
  /// **'You\'ve spent {soFar} on {category} so far this month, more than your usual {average} a month (average of the previous {months} months).'**
  String insightMsgCategorySpikeBody(
    String soFar,
    String category,
    String average,
    int months,
  );

  /// No description provided for @insightMsgNewMerchantTitle.
  ///
  /// In en, this message translates to:
  /// **'First purchase at {merchant}'**
  String insightMsgNewMerchantTitle(String merchant);

  /// No description provided for @insightMsgNewMerchantBody.
  ///
  /// In en, this message translates to:
  /// **'{amount} at {merchant} on {date} is your first transaction there and larger than your typical expense ({typical}). If you recognise it, mark it expected.'**
  String insightMsgNewMerchantBody(
    String amount,
    String merchant,
    String date,
    String typical,
  );

  /// No description provided for @insightMsgDuplicateTitle.
  ///
  /// In en, this message translates to:
  /// **'Possible duplicate: {label}'**
  String insightMsgDuplicateTitle(String label);

  /// No description provided for @insightMsgDuplicateBody.
  ///
  /// In en, this message translates to:
  /// **'Two transactions of {amount} for {label} on {first} and {second} in the same account look alike. If one was recorded twice, void it; Montra never deletes it for you.'**
  String insightMsgDuplicateBody(
    String amount,
    String label,
    String first,
    String second,
  );

  /// No description provided for @insightMsgPriceIncreaseTitle.
  ///
  /// In en, this message translates to:
  /// **'{name} costs more'**
  String insightMsgPriceIncreaseTitle(String name);

  /// No description provided for @insightMsgPriceIncreaseBody.
  ///
  /// In en, this message translates to:
  /// **'{name} went from {before} to {after} per billing ({percent} more) on {date}.'**
  String insightMsgPriceIncreaseBody(
    String name,
    String before,
    String after,
    String percent,
    String date,
  );

  /// No description provided for @insightMsgMissingRecurringTitle.
  ///
  /// In en, this message translates to:
  /// **'{name} was not recorded'**
  String insightMsgMissingRecurringTitle(String name);

  /// No description provided for @insightMsgMissingRecurringBody.
  ///
  /// In en, this message translates to:
  /// **'{name} was due on {date}, but no payment is linked yet. Record or link it, or skip this occurrence.'**
  String insightMsgMissingRecurringBody(String name, String date);

  /// No description provided for @insightMsgMissingRecurringAmountBody.
  ///
  /// In en, this message translates to:
  /// **'{name} ({amount}) was due on {date}, but no payment is linked yet. Record or link it, or skip this occurrence.'**
  String insightMsgMissingRecurringAmountBody(
    String name,
    String amount,
    String date,
  );

  /// No description provided for @insightMsgCashFlowTitle.
  ///
  /// In en, this message translates to:
  /// **'Last month\'s cash flow changed'**
  String get insightMsgCashFlowTitle;

  /// No description provided for @insightMsgCashFlowSpendingBody.
  ///
  /// In en, this message translates to:
  /// **'In {month}, spending was {spending} against your usual {usual} (average of the {months} months before).'**
  String insightMsgCashFlowSpendingBody(
    String month,
    String spending,
    String usual,
    int months,
  );

  /// No description provided for @insightMsgCashFlowIncomeBody.
  ///
  /// In en, this message translates to:
  /// **'In {month}, income was {income} against your usual {usual} (average of the {months} months before).'**
  String insightMsgCashFlowIncomeBody(
    String month,
    String income,
    String usual,
    int months,
  );

  /// No description provided for @insightMsgCashFlowBothBody.
  ///
  /// In en, this message translates to:
  /// **'In {month}, spending was {spending} against your usual {usualSpending}, and income was {income} against your usual {usualIncome} (average of the {months} months before).'**
  String insightMsgCashFlowBothBody(
    String month,
    String spending,
    String usualSpending,
    String income,
    String usualIncome,
    int months,
  );

  /// No description provided for @insightMsgSubscriptionCostsTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 subscription costs about {monthly} a month} other{{count} subscriptions cost about {monthly} a month}}'**
  String insightMsgSubscriptionCostsTitle(int count, String monthly);

  /// No description provided for @insightMsgSubscriptionCostsBody.
  ///
  /// In en, this message translates to:
  /// **'That\'s about {yearly} a year. Cancelling one you no longer use stops its future renewals only; Montra doesn\'t cancel anything for you.'**
  String insightMsgSubscriptionCostsBody(String yearly);

  /// No description provided for @insightMsgFrequencyTitle.
  ///
  /// In en, this message translates to:
  /// **'More purchases than usual at {merchant}'**
  String insightMsgFrequencyTitle(String merchant);

  /// No description provided for @insightMsgFrequencyBody.
  ///
  /// In en, this message translates to:
  /// **'You made {count} purchases at {merchant} in the last {days} days, compared with about {average} a week over the previous {weeks} weeks. This is unusual for you, not necessarily wrong; if it\'s expected, mark it so.'**
  String insightMsgFrequencyBody(
    int count,
    String merchant,
    int days,
    String average,
    int weeks,
  );

  /// No description provided for @insightMsgRecurringHigherTitle.
  ///
  /// In en, this message translates to:
  /// **'{name} was higher than usual'**
  String insightMsgRecurringHigherTitle(String name);

  /// No description provided for @insightMsgRecurringLowerTitle.
  ///
  /// In en, this message translates to:
  /// **'{name} was lower than usual'**
  String insightMsgRecurringLowerTitle(String name);

  /// No description provided for @insightMsgRecurringChangeBody.
  ///
  /// In en, this message translates to:
  /// **'The latest {name} payment ({amount} on {date}) differs from the usual {usual} (median of the previous {count} payments), a change of {percent}%. If the amount changed for good, update the recurring payment so your plans stay accurate.'**
  String insightMsgRecurringChangeBody(
    String name,
    String amount,
    String date,
    String usual,
    int count,
    String percent,
  );

  /// No description provided for @insightMsgOverspendTitle.
  ///
  /// In en, this message translates to:
  /// **'{budget} budget went over in {over} of the last {periods} periods'**
  String insightMsgOverspendTitle(String budget, int over, int periods);

  /// No description provided for @insightMsgOverspendBody.
  ///
  /// In en, this message translates to:
  /// **'Across the last {periods} periods you spent {average} on average against a limit of {limit}, going over by {overspend} on average when it was exceeded. You could raise the limit to about {average} so the budget matches how you actually spend, or keep it and look at what drives the spending. Based on past periods only.'**
  String insightMsgOverspendBody(
    int periods,
    String average,
    String limit,
    String overspend,
  );

  /// No description provided for @importErrorTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The file is too large to import. Split the statement into smaller periods.'**
  String get importErrorTooLarge;

  /// No description provided for @importErrorCurrencyNamed.
  ///
  /// In en, this message translates to:
  /// **'The statement is in {statement}, but the account is in {account}. Import it into an account in {statement}.'**
  String importErrorCurrencyNamed(String statement, String account);

  /// No description provided for @importNotesTitle.
  ///
  /// In en, this message translates to:
  /// **'Check the columns'**
  String get importNotesTitle;

  /// No description provided for @importNoteNoHeader.
  ///
  /// In en, this message translates to:
  /// **'No header row was found, so the columns are numbered. Check which column holds what.'**
  String get importNoteNoHeader;

  /// No description provided for @importNoteAmbiguousDate.
  ///
  /// In en, this message translates to:
  /// **'Dates could be day-first or month-first; {assumed} was assumed. Choose {alternative} if that\'s wrong.'**
  String importNoteAmbiguousDate(String assumed, String alternative);

  /// No description provided for @importNoteAmbiguousDateGeneric.
  ///
  /// In en, this message translates to:
  /// **'Dates could be day-first or month-first. Check the date format.'**
  String get importNoteAmbiguousDateGeneric;

  /// No description provided for @importNoteUnknownDateFormat.
  ///
  /// In en, this message translates to:
  /// **'The date format wasn\'t recognized. Choose it in the columns.'**
  String get importNoteUnknownDateFormat;

  /// No description provided for @importNoteDecimalComma.
  ///
  /// In en, this message translates to:
  /// **'Amounts use a comma for decimals. Check that they were read correctly.'**
  String get importNoteDecimalComma;

  /// No description provided for @importNoteMappingIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Some needed columns couldn\'t be found. Choose them in the columns.'**
  String get importNoteMappingIncomplete;

  /// No description provided for @importNoteCheckSign.
  ///
  /// In en, this message translates to:
  /// **'Check whether negative amounts are money out or money in.'**
  String get importNoteCheckSign;

  /// No description provided for @importNotePdfRead.
  ///
  /// In en, this message translates to:
  /// **'This statement was read automatically. Check every row before importing.'**
  String get importNotePdfRead;

  /// No description provided for @importReasonBadDateFormat.
  ///
  /// In en, this message translates to:
  /// **'The date doesn\'t match {format}.'**
  String importReasonBadDateFormat(String format);

  /// No description provided for @importReasonCurrencyNamed.
  ///
  /// In en, this message translates to:
  /// **'This row is in {currency}, but the account is in {account}.'**
  String importReasonCurrencyNamed(String currency, String account);

  /// No description provided for @importReasonBadAmountIn.
  ///
  /// In en, this message translates to:
  /// **'The amount isn\'t a number in {currency}.'**
  String importReasonBadAmountIn(String currency);

  /// No description provided for @importReasonAlreadyImportedReference.
  ///
  /// In en, this message translates to:
  /// **'Already imported into this account (same bank reference).'**
  String get importReasonAlreadyImportedReference;

  /// No description provided for @importReasonInvalidDate.
  ///
  /// In en, this message translates to:
  /// **'The date can\'t be used (for example, it\'s too far in the future). Correct it.'**
  String get importReasonInvalidDate;

  /// No description provided for @importReasonInvalidAmount.
  ///
  /// In en, this message translates to:
  /// **'The amount can\'t be used. Correct it.'**
  String get importReasonInvalidAmount;

  /// No description provided for @importReasonInvalidCategory.
  ///
  /// In en, this message translates to:
  /// **'The category can\'t be used. Choose another one.'**
  String get importReasonInvalidCategory;

  /// No description provided for @importReasonInvalidDescription.
  ///
  /// In en, this message translates to:
  /// **'The description can\'t be used. Correct it.'**
  String get importReasonInvalidDescription;

  /// No description provided for @importReasonInvalidReference.
  ///
  /// In en, this message translates to:
  /// **'The reference can\'t be used.'**
  String get importReasonInvalidReference;

  /// No description provided for @importReasonInvalidRow.
  ///
  /// In en, this message translates to:
  /// **'This row can\'t be imported as it is. Correct it or skip it.'**
  String get importReasonInvalidRow;

  /// No description provided for @importReasonRejected.
  ///
  /// In en, this message translates to:
  /// **'Montra couldn\'t import this row.'**
  String get importReasonRejected;

  /// No description provided for @importReasonReconciled.
  ///
  /// In en, this message translates to:
  /// **'Matched with a transaction in the account.'**
  String get importReasonReconciled;

  /// No description provided for @importReasonPossibleDuplicateWhy.
  ///
  /// In en, this message translates to:
  /// **'Looks like a transaction already in the account: {reasons}.'**
  String importReasonPossibleDuplicateWhy(String reasons);

  /// No description provided for @importConfirmBodyCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 row will be added to {account}.} other{{count} rows will be added to {account}.}} Possible duplicates and rows you skipped are left out. You can roll the import back later.'**
  String importConfirmBodyCount(int count, String account);

  /// No description provided for @importConfirmCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Import 1 row} other{Import {count} rows}}'**
  String importConfirmCount(int count);

  /// No description provided for @importNothingToImport.
  ///
  /// In en, this message translates to:
  /// **'No rows are marked to import. Mark the rows you want, or cancel the import.'**
  String get importNothingToImport;

  /// No description provided for @importRowsToImportLabel.
  ///
  /// In en, this message translates to:
  /// **'Will be imported'**
  String get importRowsToImportLabel;

  /// No description provided for @importFixDate.
  ///
  /// In en, this message translates to:
  /// **'Correct the date'**
  String get importFixDate;

  /// No description provided for @importFixAmount.
  ///
  /// In en, this message translates to:
  /// **'Correct the amount'**
  String get importFixAmount;

  /// No description provided for @importFixDescription.
  ///
  /// In en, this message translates to:
  /// **'Correct the description'**
  String get importFixDescription;

  /// No description provided for @reconReasonFarApart.
  ///
  /// In en, this message translates to:
  /// **'Dates are more than a week apart (matched by hand)'**
  String get reconReasonFarApart;

  /// No description provided for @reconReasonFarApartDays.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{Dates are 1 day apart (matched by hand)} other{Dates are {days} days apart (matched by hand)}}'**
  String reconReasonFarApartDays(int days);

  /// No description provided for @budgetOwnAlertsTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 alert for this budget} other{{count} alerts for this budget}}'**
  String budgetOwnAlertsTitle(int count);

  /// No description provided for @lastReconciledBalanceLabel.
  ///
  /// In en, this message translates to:
  /// **'Balance when last reconciled'**
  String get lastReconciledBalanceLabel;

  /// No description provided for @calendarMovedFrom.
  ///
  /// In en, this message translates to:
  /// **'Moved from {date}'**
  String calendarMovedFrom(String date);

  /// No description provided for @analyticsCategoriesSpending.
  ///
  /// In en, this message translates to:
  /// **'Spending'**
  String get analyticsCategoriesSpending;

  /// No description provided for @analyticsCategoriesIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get analyticsCategoriesIncome;

  /// No description provided for @analyticsNoIncome.
  ///
  /// In en, this message translates to:
  /// **'No income for {period}.'**
  String analyticsNoIncome(String period);

  /// No description provided for @categoryIncomeSummary.
  ///
  /// In en, this message translates to:
  /// **'Most income came from {name}: {amount}, {share} of the total. {count, plural, =1{1 category shown.} other{{count} categories shown.}}'**
  String categoryIncomeSummary(
    String name,
    String amount,
    String share,
    int count,
  );

  /// No description provided for @analyticsCompareNoteCurrencies.
  ///
  /// In en, this message translates to:
  /// **'Each currency is compared on its own; amounts in different currencies are never added together.'**
  String get analyticsCompareNoteCurrencies;

  /// No description provided for @analyticsCompareRowChange.
  ///
  /// In en, this message translates to:
  /// **'{now} now · {then} before · {change}'**
  String analyticsCompareRowChange(String now, String then, String change);

  /// No description provided for @analyticsCompareCountLabel.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get analyticsCompareCountLabel;

  /// No description provided for @analyticsCompareCount.
  ///
  /// In en, this message translates to:
  /// **'{now} now · {then} before'**
  String analyticsCompareCount(int now, int then);

  /// No description provided for @analyticsPreviousWindow.
  ///
  /// In en, this message translates to:
  /// **'Compared with {dates}, the period of the same length just before.'**
  String analyticsPreviousWindow(String dates);

  /// No description provided for @reconMatchByHand.
  ///
  /// In en, this message translates to:
  /// **'Match by hand'**
  String get reconMatchByHand;

  /// No description provided for @reconMatchTotal.
  ///
  /// In en, this message translates to:
  /// **'Amount kept'**
  String get reconMatchTotal;

  /// No description provided for @reconLineDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Looked like a duplicate, not imported'**
  String get reconLineDuplicate;

  /// No description provided for @reconLineSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped on import'**
  String get reconLineSkipped;

  /// No description provided for @reconLineNotImported.
  ///
  /// In en, this message translates to:
  /// **'Not imported'**
  String get reconLineNotImported;

  /// No description provided for @reconLineFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t be imported'**
  String get reconLineFailed;

  /// No description provided for @reconLineMatched.
  ///
  /// In en, this message translates to:
  /// **'Matched by hand'**
  String get reconLineMatched;

  /// No description provided for @reconLineNoDescription.
  ///
  /// In en, this message translates to:
  /// **'No description'**
  String get reconLineNoDescription;

  /// No description provided for @reconLinesUnmatched.
  ///
  /// In en, this message translates to:
  /// **'Not matched'**
  String get reconLinesUnmatched;

  /// No description provided for @reconLinesMatched.
  ///
  /// In en, this message translates to:
  /// **'Matched by hand'**
  String get reconLinesMatched;

  /// No description provided for @reconLinesIntro.
  ///
  /// In en, this message translates to:
  /// **'These statement lines weren\'t imported or matched. Choose a line, then the transactions in Montra it stands for. Their amounts must add up to the line.'**
  String get reconLinesIntro;

  /// No description provided for @reconLinesMatchedIntro.
  ///
  /// In en, this message translates to:
  /// **'Lines you matched by hand. Tap one to undo its match.'**
  String get reconLinesMatchedIntro;

  /// No description provided for @reconLinesEmpty.
  ///
  /// In en, this message translates to:
  /// **'Every statement line is imported or matched.'**
  String get reconLinesEmpty;

  /// No description provided for @reconLinesMatchedEmpty.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t matched any lines by hand.'**
  String get reconLinesMatchedEmpty;

  /// No description provided for @reconChooseTransactionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose the transactions'**
  String get reconChooseTransactionsTitle;

  /// No description provided for @reconChooseTransactionsIntro.
  ///
  /// In en, this message translates to:
  /// **'Unreconciled transactions in {account} going the same way as the statement line of {date}. Choose one, or several that add up to it.'**
  String reconChooseTransactionsIntro(String date, String account);

  /// No description provided for @reconStatementLineAmount.
  ///
  /// In en, this message translates to:
  /// **'Statement line'**
  String get reconStatementLineAmount;

  /// No description provided for @reconNoUnreconciled.
  ///
  /// In en, this message translates to:
  /// **'No unreconciled transactions go this way in this account.'**
  String get reconNoUnreconciled;

  /// No description provided for @reconMatchChosen.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Choose transactions} =1{Match 1 transaction} other{Match {count} transactions}}'**
  String reconMatchChosen(int count);

  /// No description provided for @reportFailedStorageUnavailable.
  ///
  /// In en, this message translates to:
  /// **'File storage wasn\'t available, so the file couldn\'t be saved. Make it again in a while.'**
  String get reportFailedStorageUnavailable;

  /// No description provided for @reportFailedGeneration.
  ///
  /// In en, this message translates to:
  /// **'Making the report failed every time it was tried. Make it again, or narrow the period.'**
  String get reportFailedGeneration;

  /// No description provided for @reportWindowDays.
  ///
  /// In en, this message translates to:
  /// **'{dates} ({days, plural, =1{1 day} other{{days} days}})'**
  String reportWindowDays(String dates, int days);

  /// No description provided for @reportCurrentState.
  ///
  /// In en, this message translates to:
  /// **'As things were when you asked for it'**
  String get reportCurrentState;

  /// No description provided for @reportDeleteAction.
  ///
  /// In en, this message translates to:
  /// **'Delete report'**
  String get reportDeleteAction;

  /// No description provided for @reportDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this report?'**
  String get reportDeleteTitle;

  /// No description provided for @reportDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" and its file are deleted. Links you already shared stop working.'**
  String reportDeleteBody(String title);

  /// No description provided for @reportDeleteBodyRunning.
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" is still being made. Making it stops and the report is deleted.'**
  String reportDeleteBodyRunning(String title);

  /// No description provided for @reportDeleted.
  ///
  /// In en, this message translates to:
  /// **'Report deleted.'**
  String get reportDeleted;

  /// No description provided for @scheduleEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit schedule'**
  String get scheduleEditTitle;

  /// No description provided for @scheduleNotFound.
  ///
  /// In en, this message translates to:
  /// **'This schedule doesn\'t exist any more.'**
  String get scheduleNotFound;

  /// No description provided for @scheduleNothingChanged.
  ///
  /// In en, this message translates to:
  /// **'Nothing changed, so there was nothing to save.'**
  String get scheduleNothingChanged;

  /// No description provided for @scheduleSaved.
  ///
  /// In en, this message translates to:
  /// **'Schedule saved.'**
  String get scheduleSaved;

  /// No description provided for @scheduleTypeFixed.
  ///
  /// In en, this message translates to:
  /// **'The kind of report can\'t change. Make a new schedule for another kind.'**
  String get scheduleTypeFixed;

  /// No description provided for @scheduleEditNote.
  ///
  /// In en, this message translates to:
  /// **'A new cadence starts from the next week or month. Leave the title empty to use the usual name.'**
  String get scheduleEditNote;

  /// No description provided for @schedulePause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get schedulePause;

  /// No description provided for @schedulePauseHelp.
  ///
  /// In en, this message translates to:
  /// **'No reports are made until you resume it.'**
  String get schedulePauseHelp;

  /// No description provided for @scheduleResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get scheduleResume;

  /// No description provided for @scheduleResumeHelp.
  ///
  /// In en, this message translates to:
  /// **'Starts again from the next week or month; missed periods aren\'t made.'**
  String get scheduleResumeHelp;

  /// No description provided for @schedulePaused.
  ///
  /// In en, this message translates to:
  /// **'Schedule paused.'**
  String get schedulePaused;

  /// No description provided for @scheduleResumed.
  ///
  /// In en, this message translates to:
  /// **'Schedule resumed.'**
  String get scheduleResumed;

  /// No description provided for @scheduleActionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Options for {title}'**
  String scheduleActionsLabel(String title);

  /// No description provided for @friendsTitle.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get friendsTitle;

  /// No description provided for @friendsTabFriends.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get friendsTabFriends;

  /// No description provided for @friendsTabRequests.
  ///
  /// In en, this message translates to:
  /// **'Requests'**
  String get friendsTabRequests;

  /// No description provided for @friendsTabRequestsCount.
  ///
  /// In en, this message translates to:
  /// **'Requests ({count})'**
  String friendsTabRequestsCount(int count);

  /// No description provided for @friendsTabFind.
  ///
  /// In en, this message translates to:
  /// **'Find someone'**
  String get friendsTabFind;

  /// No description provided for @friendsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No friends yet'**
  String get friendsEmptyTitle;

  /// No description provided for @friendsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Find people by their exact username and send them a friend request.'**
  String get friendsEmptyBody;

  /// No description provided for @friendsBlockedAndMutedTitle.
  ///
  /// In en, this message translates to:
  /// **'Blocked and muted'**
  String get friendsBlockedAndMutedTitle;

  /// No description provided for @friendsBlockedTab.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get friendsBlockedTab;

  /// No description provided for @friendsMutedTab.
  ///
  /// In en, this message translates to:
  /// **'Muted'**
  String get friendsMutedTab;

  /// No description provided for @friendsBlockedEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t blocked anyone'**
  String get friendsBlockedEmptyTitle;

  /// No description provided for @friendsBlockedHelp.
  ///
  /// In en, this message translates to:
  /// **'People you block can\'t find you, add you or see you in Montra, and you won\'t see them. They aren\'t told.'**
  String get friendsBlockedHelp;

  /// No description provided for @friendsMutedEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t muted anyone'**
  String get friendsMutedEmptyTitle;

  /// No description provided for @friendBlockedLabel.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get friendBlockedLabel;

  /// No description provided for @friendMutedLabel.
  ///
  /// In en, this message translates to:
  /// **'Muted'**
  String get friendMutedLabel;

  /// No description provided for @friendConnectionSelf.
  ///
  /// In en, this message translates to:
  /// **'This is you'**
  String get friendConnectionSelf;

  /// No description provided for @friendConnectionFriend.
  ///
  /// In en, this message translates to:
  /// **'Friend'**
  String get friendConnectionFriend;

  /// No description provided for @friendConnectionRequestSent.
  ///
  /// In en, this message translates to:
  /// **'Request sent'**
  String get friendConnectionRequestSent;

  /// No description provided for @friendConnectionRequestReceived.
  ///
  /// In en, this message translates to:
  /// **'Wants to be your friend'**
  String get friendConnectionRequestReceived;

  /// No description provided for @friendRequestsIncoming.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get friendRequestsIncoming;

  /// No description provided for @friendRequestsOutgoing.
  ///
  /// In en, this message translates to:
  /// **'Sent by you'**
  String get friendRequestsOutgoing;

  /// No description provided for @friendRequestsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No requests waiting'**
  String get friendRequestsEmptyTitle;

  /// No description provided for @friendRequestsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Friend requests you receive or send show up here until they are answered.'**
  String get friendRequestsEmptyBody;

  /// No description provided for @friendRequestMessage.
  ///
  /// In en, this message translates to:
  /// **'“{message}”'**
  String friendRequestMessage(String message);

  /// No description provided for @friendRequestAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get friendRequestAccept;

  /// No description provided for @friendRequestDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get friendRequestDecline;

  /// No description provided for @friendRequestCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel request'**
  String get friendRequestCancel;

  /// No description provided for @friendRequestSend.
  ///
  /// In en, this message translates to:
  /// **'Send friend request'**
  String get friendRequestSend;

  /// No description provided for @friendRequestAcceptTheirs.
  ///
  /// In en, this message translates to:
  /// **'Accept their request'**
  String get friendRequestAcceptTheirs;

  /// No description provided for @friendRequestSentDone.
  ///
  /// In en, this message translates to:
  /// **'Friend request sent to {name}.'**
  String friendRequestSentDone(String name);

  /// No description provided for @friendNowFriends.
  ///
  /// In en, this message translates to:
  /// **'You and {name} are now friends.'**
  String friendNowFriends(String name);

  /// No description provided for @friendRequestDeclinedDone.
  ///
  /// In en, this message translates to:
  /// **'Request declined.'**
  String get friendRequestDeclinedDone;

  /// No description provided for @friendRequestCancelledDone.
  ///
  /// In en, this message translates to:
  /// **'Request cancelled.'**
  String get friendRequestCancelledDone;

  /// No description provided for @friendFindIntro.
  ///
  /// In en, this message translates to:
  /// **'Type the whole username of the person you are looking for. Partial names find nobody, and only people who turned on “Let people find me by username” can be found.'**
  String get friendFindIntro;

  /// No description provided for @friendFindLabel.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get friendFindLabel;

  /// No description provided for @friendFindHelp.
  ///
  /// In en, this message translates to:
  /// **'For example: asha_r'**
  String get friendFindHelp;

  /// No description provided for @friendFindTooShort.
  ///
  /// In en, this message translates to:
  /// **'Enter the full username (at least 3 characters).'**
  String get friendFindTooShort;

  /// No description provided for @friendFindButton.
  ///
  /// In en, this message translates to:
  /// **'Find'**
  String get friendFindButton;

  /// No description provided for @friendFindNobody.
  ///
  /// In en, this message translates to:
  /// **'No one found with the username @{username}. Check the spelling, or ask them whether they let people find them by username.'**
  String friendFindNobody(String username);

  /// No description provided for @friendFindDiscoveryNote.
  ///
  /// In en, this message translates to:
  /// **'Want others to find you? Set a username and turn on “Let people find me by username” in your privacy settings.'**
  String get friendFindDiscoveryNote;

  /// No description provided for @friendMute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get friendMute;

  /// No description provided for @friendMuteHelp.
  ///
  /// In en, this message translates to:
  /// **'Muted people stay connected, but you won\'t get notifications about what they do.'**
  String get friendMuteHelp;

  /// No description provided for @friendUnmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get friendUnmute;

  /// No description provided for @friendBlock.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get friendBlock;

  /// No description provided for @friendBlockHelp.
  ///
  /// In en, this message translates to:
  /// **'They can\'t find you, add you or see you, and you won\'t see them.'**
  String get friendBlockHelp;

  /// No description provided for @friendUnblock.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get friendUnblock;

  /// No description provided for @friendRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove friend'**
  String get friendRemove;

  /// No description provided for @friendBlockConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Block {name}?'**
  String friendBlockConfirmTitle(String name);

  /// No description provided for @friendBlockConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'You\'ll no longer be friends and won\'t see each other in Montra. They aren\'t told. You can unblock them later from Blocked and muted.'**
  String get friendBlockConfirmBody;

  /// No description provided for @friendRemoveConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove {name} as a friend?'**
  String friendRemoveConfirmTitle(String name);

  /// No description provided for @friendRemoveConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'You can send a new friend request later. Groups and shared budgets or goals you are both in don\'t change.'**
  String get friendRemoveConfirmBody;

  /// No description provided for @friendMutedDone.
  ///
  /// In en, this message translates to:
  /// **'{name} is muted.'**
  String friendMutedDone(String name);

  /// No description provided for @friendUnmutedDone.
  ///
  /// In en, this message translates to:
  /// **'{name} is no longer muted.'**
  String friendUnmutedDone(String name);

  /// No description provided for @friendBlockedDone.
  ///
  /// In en, this message translates to:
  /// **'{name} is blocked.'**
  String friendBlockedDone(String name);

  /// No description provided for @friendUnblockedDone.
  ///
  /// In en, this message translates to:
  /// **'{name} is unblocked.'**
  String friendUnblockedDone(String name);

  /// No description provided for @friendRemovedDone.
  ///
  /// In en, this message translates to:
  /// **'{name} was removed from your friends.'**
  String friendRemovedDone(String name);

  /// No description provided for @friendCodeAlreadyFriends.
  ///
  /// In en, this message translates to:
  /// **'You are already friends.'**
  String get friendCodeAlreadyFriends;

  /// No description provided for @friendCodeRequestPending.
  ///
  /// In en, this message translates to:
  /// **'You already sent this person a friend request.'**
  String get friendCodeRequestPending;

  /// No description provided for @friendCodeRequestsClosed.
  ///
  /// In en, this message translates to:
  /// **'This person is not accepting friend requests.'**
  String get friendCodeRequestsClosed;

  /// No description provided for @socialSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy for friends'**
  String get socialSettingsTitle;

  /// No description provided for @socialSettingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Privacy settings saved.'**
  String get socialSettingsSaved;

  /// No description provided for @socialNothingChanged.
  ///
  /// In en, this message translates to:
  /// **'Nothing changed, so there was nothing to save.'**
  String get socialNothingChanged;

  /// No description provided for @usernameSection.
  ///
  /// In en, this message translates to:
  /// **'Your username'**
  String get usernameSection;

  /// No description provided for @usernameLabel.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get usernameLabel;

  /// No description provided for @usernameRules.
  ///
  /// In en, this message translates to:
  /// **'3 to 30 letters, digits, “_” or “.”. It is saved in lowercase. Leave it empty to remove your username.'**
  String get usernameRules;

  /// No description provided for @usernameLengthRule.
  ///
  /// In en, this message translates to:
  /// **'Use 3 to 30 characters.'**
  String get usernameLengthRule;

  /// No description provided for @usernameCharactersRule.
  ///
  /// In en, this message translates to:
  /// **'Use only letters, digits, “_” and “.”.'**
  String get usernameCharactersRule;

  /// No description provided for @usernameTaken.
  ///
  /// In en, this message translates to:
  /// **'That username is taken. Try another one.'**
  String get usernameTaken;

  /// No description provided for @socialDiscoverySection.
  ///
  /// In en, this message translates to:
  /// **'Who can find you'**
  String get socialDiscoverySection;

  /// No description provided for @socialDiscoverableLabel.
  ///
  /// In en, this message translates to:
  /// **'Let people find me by username'**
  String get socialDiscoverableLabel;

  /// No description provided for @socialDiscoverableHelp.
  ///
  /// In en, this message translates to:
  /// **'When this is on, someone who types your exact username can find you and send a friend request. Your friends can always add you to groups.'**
  String get socialDiscoverableHelp;

  /// No description provided for @socialDiscoverableOffNote.
  ///
  /// In en, this message translates to:
  /// **'This is off until you turn it on: nobody can find you by your username, even if they know it. You can still send requests and join groups with a link.'**
  String get socialDiscoverableOffNote;

  /// No description provided for @socialRequestsLabel.
  ///
  /// In en, this message translates to:
  /// **'Who can send you friend requests'**
  String get socialRequestsLabel;

  /// No description provided for @socialRequestsHelp.
  ///
  /// In en, this message translates to:
  /// **'Others who find you can only ask; you decide whether to accept.'**
  String get socialRequestsHelp;

  /// No description provided for @socialRequestsEveryone.
  ///
  /// In en, this message translates to:
  /// **'Anyone'**
  String get socialRequestsEveryone;

  /// No description provided for @socialRequestsFriendsOfFriends.
  ///
  /// In en, this message translates to:
  /// **'Friends of my friends'**
  String get socialRequestsFriendsOfFriends;

  /// No description provided for @socialRequestsNobody.
  ///
  /// In en, this message translates to:
  /// **'Nobody'**
  String get socialRequestsNobody;

  /// No description provided for @groupsTitle.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get groupsTitle;

  /// No description provided for @groupNew.
  ///
  /// In en, this message translates to:
  /// **'New group'**
  String get groupNew;

  /// No description provided for @groupsShowArchived.
  ///
  /// In en, this message translates to:
  /// **'Show archived groups'**
  String get groupsShowArchived;

  /// No description provided for @groupsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No groups yet'**
  String get groupsEmptyTitle;

  /// No description provided for @groupsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Create a group to share expenses with your household, roommates, a trip or friends, or join one with a link someone sent you.'**
  String get groupsEmptyBody;

  /// No description provided for @groupTypeAndMembers.
  ///
  /// In en, this message translates to:
  /// **'{type} · {count, plural, =1{1 member} other{{count} members}}'**
  String groupTypeAndMembers(String type, int count);

  /// No description provided for @groupArchivedLabel.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get groupArchivedLabel;

  /// No description provided for @groupTypeHousehold.
  ///
  /// In en, this message translates to:
  /// **'Household'**
  String get groupTypeHousehold;

  /// No description provided for @groupTypeRoommates.
  ///
  /// In en, this message translates to:
  /// **'Roommates'**
  String get groupTypeRoommates;

  /// No description provided for @groupTypeTrip.
  ///
  /// In en, this message translates to:
  /// **'Trip'**
  String get groupTypeTrip;

  /// No description provided for @groupTypeEvent.
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get groupTypeEvent;

  /// No description provided for @groupTypeFriends.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get groupTypeFriends;

  /// No description provided for @groupTypeCustom.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get groupTypeCustom;

  /// No description provided for @groupSplitEqual.
  ///
  /// In en, this message translates to:
  /// **'Equally'**
  String get groupSplitEqual;

  /// No description provided for @groupSplitExact.
  ///
  /// In en, this message translates to:
  /// **'Exact amounts'**
  String get groupSplitExact;

  /// No description provided for @groupSplitPercentage.
  ///
  /// In en, this message translates to:
  /// **'Percentages'**
  String get groupSplitPercentage;

  /// No description provided for @groupSplitShares.
  ///
  /// In en, this message translates to:
  /// **'Shares'**
  String get groupSplitShares;

  /// No description provided for @groupSplitItemized.
  ///
  /// In en, this message translates to:
  /// **'By item'**
  String get groupSplitItemized;

  /// No description provided for @groupRoleOwner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get groupRoleOwner;

  /// No description provided for @groupRoleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get groupRoleAdmin;

  /// No description provided for @groupRoleMember.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get groupRoleMember;

  /// No description provided for @groupNotifyAll.
  ///
  /// In en, this message translates to:
  /// **'Everything'**
  String get groupNotifyAll;

  /// No description provided for @groupNotifyImportant.
  ///
  /// In en, this message translates to:
  /// **'Only important things'**
  String get groupNotifyImportant;

  /// No description provided for @groupNotifyNone.
  ///
  /// In en, this message translates to:
  /// **'Nothing'**
  String get groupNotifyNone;

  /// No description provided for @groupNetOwedToYou.
  ///
  /// In en, this message translates to:
  /// **'You are owed {amount}'**
  String groupNetOwedToYou(String amount);

  /// No description provided for @groupNetYouOwe.
  ///
  /// In en, this message translates to:
  /// **'You owe {amount}'**
  String groupNetYouOwe(String amount);

  /// No description provided for @groupNetSettled.
  ///
  /// In en, this message translates to:
  /// **'Settled up'**
  String get groupNetSettled;

  /// No description provided for @groupMemberIsOwed.
  ///
  /// In en, this message translates to:
  /// **'is owed {amount}'**
  String groupMemberIsOwed(String amount);

  /// No description provided for @groupMemberOwes.
  ///
  /// In en, this message translates to:
  /// **'owes {amount}'**
  String groupMemberOwes(String amount);

  /// No description provided for @groupInvitationsForYou.
  ///
  /// In en, this message translates to:
  /// **'Invitations for you'**
  String get groupInvitationsForYou;

  /// No description provided for @groupInvitationReceived.
  ///
  /// In en, this message translates to:
  /// **'You were invited to join'**
  String get groupInvitationReceived;

  /// No description provided for @groupInvitationFrom.
  ///
  /// In en, this message translates to:
  /// **'Invited by {name}'**
  String groupInvitationFrom(String name);

  /// No description provided for @groupInvitationAccept.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get groupInvitationAccept;

  /// No description provided for @groupInvitationDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get groupInvitationDecline;

  /// No description provided for @groupInvitationDeclinedDone.
  ///
  /// In en, this message translates to:
  /// **'Invitation declined.'**
  String get groupInvitationDeclinedDone;

  /// No description provided for @groupJoinedDone.
  ///
  /// In en, this message translates to:
  /// **'You joined {name}.'**
  String groupJoinedDone(String name);

  /// No description provided for @groupEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit group'**
  String get groupEditTitle;

  /// No description provided for @groupNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get groupNameLabel;

  /// No description provided for @groupNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a name for the group.'**
  String get groupNameRequired;

  /// No description provided for @groupTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Kind of group'**
  String get groupTypeLabel;

  /// No description provided for @groupCurrencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Group currency'**
  String get groupCurrencyLabel;

  /// No description provided for @groupCurrencyDefault.
  ///
  /// In en, this message translates to:
  /// **'Your main currency'**
  String get groupCurrencyDefault;

  /// No description provided for @groupCurrencyHelp.
  ///
  /// In en, this message translates to:
  /// **'Balances are kept in this currency. It can’t change once the group has expenses or settlements.'**
  String get groupCurrencyHelp;

  /// No description provided for @groupSplitLabel.
  ///
  /// In en, this message translates to:
  /// **'Usual way to split'**
  String get groupSplitLabel;

  /// No description provided for @groupSplitHelp.
  ///
  /// In en, this message translates to:
  /// **'New expenses start with this; you can change it for each expense.'**
  String get groupSplitHelp;

  /// No description provided for @groupTripSection.
  ///
  /// In en, this message translates to:
  /// **'Trip details'**
  String get groupTripSection;

  /// No description provided for @groupDestinationLabel.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get groupDestinationLabel;

  /// No description provided for @groupStartDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Starts'**
  String get groupStartDateLabel;

  /// No description provided for @groupEndDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Ends'**
  String get groupEndDateLabel;

  /// No description provided for @groupAboutSection.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get groupAboutSection;

  /// No description provided for @groupDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get groupDescriptionLabel;

  /// No description provided for @groupRulesLabel.
  ///
  /// In en, this message translates to:
  /// **'House rules (optional)'**
  String get groupRulesLabel;

  /// No description provided for @groupRulesHelp.
  ///
  /// In en, this message translates to:
  /// **'For example, how you split groceries or when you settle up.'**
  String get groupRulesHelp;

  /// No description provided for @groupTimezoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Time zone (optional)'**
  String get groupTimezoneLabel;

  /// No description provided for @groupTimezoneHelp.
  ///
  /// In en, this message translates to:
  /// **'For example Asia/Kolkata. Left empty, your own time zone is used.'**
  String get groupTimezoneHelp;

  /// No description provided for @groupOptionsSection.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get groupOptionsSection;

  /// No description provided for @groupSimplifyLabel.
  ///
  /// In en, this message translates to:
  /// **'Simplify debts'**
  String get groupSimplifyLabel;

  /// No description provided for @groupSimplifyHelp.
  ///
  /// In en, this message translates to:
  /// **'Suggests fewer payments to settle up. Everyone ends up with the same balance.'**
  String get groupSimplifyHelp;

  /// No description provided for @groupAllowInvitesLabel.
  ///
  /// In en, this message translates to:
  /// **'Members can invite people'**
  String get groupAllowInvitesLabel;

  /// No description provided for @groupAllowInvitesHelp.
  ///
  /// In en, this message translates to:
  /// **'When off, only the owner and admins can invite.'**
  String get groupAllowInvitesHelp;

  /// No description provided for @groupRequireApprovalLabel.
  ///
  /// In en, this message translates to:
  /// **'Admins approve people who join with a link'**
  String get groupRequireApprovalLabel;

  /// No description provided for @groupRequireApprovalHelp.
  ///
  /// In en, this message translates to:
  /// **'Off by default. When on, opening an invitation link sends a request that an admin approves; people invited by username always join directly.'**
  String get groupRequireApprovalHelp;

  /// No description provided for @groupCreateButton.
  ///
  /// In en, this message translates to:
  /// **'Create group'**
  String get groupCreateButton;

  /// No description provided for @groupCreatedDone.
  ///
  /// In en, this message translates to:
  /// **'Group {name} created.'**
  String groupCreatedDone(String name);

  /// No description provided for @groupSavedDone.
  ///
  /// In en, this message translates to:
  /// **'Group saved.'**
  String get groupSavedDone;

  /// No description provided for @groupNothingChanged.
  ///
  /// In en, this message translates to:
  /// **'Nothing changed, so there was nothing to save.'**
  String get groupNothingChanged;

  /// No description provided for @groupJoinTitle.
  ///
  /// In en, this message translates to:
  /// **'Join a group with a link'**
  String get groupJoinTitle;

  /// No description provided for @groupJoinIntro.
  ///
  /// In en, this message translates to:
  /// **'Paste the invitation link someone sent you. You’ll see the group before you join.'**
  String get groupJoinIntro;

  /// No description provided for @groupJoinLinkLabel.
  ///
  /// In en, this message translates to:
  /// **'Invitation link'**
  String get groupJoinLinkLabel;

  /// No description provided for @groupJoinLinkInvalid.
  ///
  /// In en, this message translates to:
  /// **'This doesn’t look like a Montra invitation link.'**
  String get groupJoinLinkInvalid;

  /// No description provided for @groupJoinCheckLink.
  ///
  /// In en, this message translates to:
  /// **'Check the link'**
  String get groupJoinCheckLink;

  /// No description provided for @groupJoinLinkGone.
  ///
  /// In en, this message translates to:
  /// **'This link can’t be used: it may have expired, been used up or been turned off. Ask for a new one.'**
  String get groupJoinLinkGone;

  /// No description provided for @groupMembersLabel.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get groupMembersLabel;

  /// No description provided for @groupInvitedByLabel.
  ///
  /// In en, this message translates to:
  /// **'Invited by'**
  String get groupInvitedByLabel;

  /// No description provided for @groupInvitationExpiresLabel.
  ///
  /// In en, this message translates to:
  /// **'Link valid until'**
  String get groupInvitationExpiresLabel;

  /// No description provided for @groupJoinAlreadyMember.
  ///
  /// In en, this message translates to:
  /// **'You are already a member of this group.'**
  String get groupJoinAlreadyMember;

  /// No description provided for @groupJoinLinkNotActive.
  ///
  /// In en, this message translates to:
  /// **'This link can’t be used any more ({status}). Ask for a new one.'**
  String groupJoinLinkNotActive(String status);

  /// No description provided for @groupJoinNeedsApproval.
  ///
  /// In en, this message translates to:
  /// **'An admin approves new members of this group. When you ask to join, they’ll be told, and you join once one of them approves.'**
  String get groupJoinNeedsApproval;

  /// No description provided for @groupJoinDirect.
  ///
  /// In en, this message translates to:
  /// **'You’ll join right away. Members see your name and username in the group.'**
  String get groupJoinDirect;

  /// No description provided for @groupJoinButton.
  ///
  /// In en, this message translates to:
  /// **'Join group'**
  String get groupJoinButton;

  /// No description provided for @groupJoinAskToJoin.
  ///
  /// In en, this message translates to:
  /// **'Ask to join'**
  String get groupJoinAskToJoin;

  /// No description provided for @groupOpen.
  ///
  /// In en, this message translates to:
  /// **'Open the group'**
  String get groupOpen;

  /// No description provided for @groupJoinPendingTitle.
  ///
  /// In en, this message translates to:
  /// **'Request sent'**
  String get groupJoinPendingTitle;

  /// No description provided for @groupJoinPendingBody.
  ///
  /// In en, this message translates to:
  /// **'The admins of {group} will review your request. You’ll be notified when you join.'**
  String groupJoinPendingBody(String group);

  /// No description provided for @groupJoinBackToGroups.
  ///
  /// In en, this message translates to:
  /// **'Back to groups'**
  String get groupJoinBackToGroups;

  /// No description provided for @groupSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Group settings'**
  String get groupSettingsTitle;

  /// No description provided for @groupArchivedBanner.
  ///
  /// In en, this message translates to:
  /// **'This group is archived. Its records stay, but nothing can change until the owner restores it.'**
  String get groupArchivedBanner;

  /// No description provided for @groupBalanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Balances'**
  String get groupBalanceTitle;

  /// No description provided for @groupFormerMember.
  ///
  /// In en, this message translates to:
  /// **'{name} (former member)'**
  String groupFormerMember(String name);

  /// No description provided for @groupDisputedExpenses.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 expense is disputed and may change.} other{{count} expenses are disputed and may change.}}'**
  String groupDisputedExpenses(int count);

  /// No description provided for @groupBalancesUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Balances couldn’t be loaded. Pull down to try again.'**
  String get groupBalancesUnavailable;

  /// No description provided for @groupSettleUp.
  ///
  /// In en, this message translates to:
  /// **'Settle up'**
  String get groupSettleUp;

  /// No description provided for @groupMoneySection.
  ///
  /// In en, this message translates to:
  /// **'Money'**
  String get groupMoneySection;

  /// No description provided for @groupLinkExpenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get groupLinkExpenses;

  /// No description provided for @groupLinkBalances.
  ///
  /// In en, this message translates to:
  /// **'Balances and suggested payments'**
  String get groupLinkBalances;

  /// No description provided for @groupLinkSettlements.
  ///
  /// In en, this message translates to:
  /// **'Payments between members'**
  String get groupLinkSettlements;

  /// No description provided for @groupLinkRecurring.
  ///
  /// In en, this message translates to:
  /// **'Recurring shared expenses'**
  String get groupLinkRecurring;

  /// No description provided for @groupLinkReports.
  ///
  /// In en, this message translates to:
  /// **'Reports and export'**
  String get groupLinkReports;

  /// No description provided for @groupMemberYou.
  ///
  /// In en, this message translates to:
  /// **'{name} (you)'**
  String groupMemberYou(String name);

  /// No description provided for @groupMemberLeft.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get groupMemberLeft;

  /// No description provided for @groupMemberRemoved.
  ///
  /// In en, this message translates to:
  /// **'Removed'**
  String get groupMemberRemoved;

  /// No description provided for @groupActivityTitle.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get groupActivityTitle;

  /// No description provided for @groupActivityEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing has happened in this group yet.'**
  String get groupActivityEmpty;

  /// No description provided for @groupActivityUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Activity couldn’t be loaded.'**
  String get groupActivityUnavailable;

  /// No description provided for @groupActivitySomeone.
  ///
  /// In en, this message translates to:
  /// **'Someone'**
  String get groupActivitySomeone;

  /// No description provided for @groupActivityCreated.
  ///
  /// In en, this message translates to:
  /// **'{actor} created this {type} group.'**
  String groupActivityCreated(String actor, String type);

  /// No description provided for @groupActivityUpdated.
  ///
  /// In en, this message translates to:
  /// **'{actor} changed the group details.'**
  String groupActivityUpdated(String actor);

  /// No description provided for @groupActivityArchived.
  ///
  /// In en, this message translates to:
  /// **'{actor} archived the group.'**
  String groupActivityArchived(String actor);

  /// No description provided for @groupActivityRestored.
  ///
  /// In en, this message translates to:
  /// **'{actor} restored the group.'**
  String groupActivityRestored(String actor);

  /// No description provided for @groupActivityDeleted.
  ///
  /// In en, this message translates to:
  /// **'{actor} deleted the group.'**
  String groupActivityDeleted(String actor);

  /// No description provided for @groupActivityInvited.
  ///
  /// In en, this message translates to:
  /// **'{actor} invited someone by username.'**
  String groupActivityInvited(String actor);

  /// No description provided for @groupActivityLinkCreated.
  ///
  /// In en, this message translates to:
  /// **'{actor} created an invitation link.'**
  String groupActivityLinkCreated(String actor);

  /// No description provided for @groupActivityInvitationRevoked.
  ///
  /// In en, this message translates to:
  /// **'{actor} turned off an invitation.'**
  String groupActivityInvitationRevoked(String actor);

  /// No description provided for @groupActivityJoinRequested.
  ///
  /// In en, this message translates to:
  /// **'{actor} asked to join.'**
  String groupActivityJoinRequested(String actor);

  /// No description provided for @groupActivityJoined.
  ///
  /// In en, this message translates to:
  /// **'{name} joined the group.'**
  String groupActivityJoined(String name);

  /// No description provided for @groupActivityJoinedApproved.
  ///
  /// In en, this message translates to:
  /// **'{name} joined after an admin approved.'**
  String groupActivityJoinedApproved(String name);

  /// No description provided for @groupActivityLeft.
  ///
  /// In en, this message translates to:
  /// **'{name} left the group.'**
  String groupActivityLeft(String name);

  /// No description provided for @groupActivityRemoved.
  ///
  /// In en, this message translates to:
  /// **'{actor} removed {name}.'**
  String groupActivityRemoved(String actor, String name);

  /// No description provided for @groupActivityRoleChanged.
  ///
  /// In en, this message translates to:
  /// **'{actor} made {name} {role}.'**
  String groupActivityRoleChanged(String actor, String name, String role);

  /// No description provided for @groupActivityOwnershipTransferred.
  ///
  /// In en, this message translates to:
  /// **'{actor} made {name} the owner.'**
  String groupActivityOwnershipTransferred(String actor, String name);

  /// No description provided for @groupActivityExpenseAdded.
  ///
  /// In en, this message translates to:
  /// **'{actor} added the expense “{name}”.'**
  String groupActivityExpenseAdded(String actor, String name);

  /// No description provided for @groupActivityExpenseUpdated.
  ///
  /// In en, this message translates to:
  /// **'{actor} changed the expense “{name}”.'**
  String groupActivityExpenseUpdated(String actor, String name);

  /// No description provided for @groupActivityExpenseDeleted.
  ///
  /// In en, this message translates to:
  /// **'{actor} deleted the expense “{name}”.'**
  String groupActivityExpenseDeleted(String actor, String name);

  /// No description provided for @groupActivityExpenseCommented.
  ///
  /// In en, this message translates to:
  /// **'{actor} commented on “{name}”.'**
  String groupActivityExpenseCommented(String actor, String name);

  /// No description provided for @groupActivityExpenseDisputed.
  ///
  /// In en, this message translates to:
  /// **'{actor} raised a question about “{name}”.'**
  String groupActivityExpenseDisputed(String actor, String name);

  /// No description provided for @groupActivityDisputeResolved.
  ///
  /// In en, this message translates to:
  /// **'{actor} resolved the question about “{name}”.'**
  String groupActivityDisputeResolved(String actor, String name);

  /// No description provided for @groupActivityDisputeWithdrawn.
  ///
  /// In en, this message translates to:
  /// **'{actor} withdrew the question about “{name}”.'**
  String groupActivityDisputeWithdrawn(String actor, String name);

  /// No description provided for @groupActivitySettlementDisputeResolved.
  ///
  /// In en, this message translates to:
  /// **'{actor} resolved the question about a payment.'**
  String groupActivitySettlementDisputeResolved(String actor);

  /// No description provided for @groupActivitySettlementDisputeWithdrawn.
  ///
  /// In en, this message translates to:
  /// **'{actor} withdrew the question about a payment.'**
  String groupActivitySettlementDisputeWithdrawn(String actor);

  /// No description provided for @groupActivitySettlementProposed.
  ///
  /// In en, this message translates to:
  /// **'{actor} proposed a payment.'**
  String groupActivitySettlementProposed(String actor);

  /// No description provided for @groupActivitySettlementReported.
  ///
  /// In en, this message translates to:
  /// **'{actor} recorded a payment.'**
  String groupActivitySettlementReported(String actor);

  /// No description provided for @groupActivitySettlementConfirmed.
  ///
  /// In en, this message translates to:
  /// **'{actor} confirmed a payment.'**
  String groupActivitySettlementConfirmed(String actor);

  /// No description provided for @groupActivitySettlementDisputed.
  ///
  /// In en, this message translates to:
  /// **'{actor} questioned a payment.'**
  String groupActivitySettlementDisputed(String actor);

  /// No description provided for @groupActivitySettlementVoided.
  ///
  /// In en, this message translates to:
  /// **'{actor} cancelled a payment record.'**
  String groupActivitySettlementVoided(String actor);

  /// No description provided for @groupActivitySettlementCorrected.
  ///
  /// In en, this message translates to:
  /// **'{actor} corrected a payment.'**
  String groupActivitySettlementCorrected(String actor);

  /// No description provided for @groupActivityRecurringCreated.
  ///
  /// In en, this message translates to:
  /// **'{actor} set up the recurring expense “{name}”.'**
  String groupActivityRecurringCreated(String actor, String name);

  /// No description provided for @groupActivityRecurringUpdated.
  ///
  /// In en, this message translates to:
  /// **'{actor} changed the recurring expense “{name}”.'**
  String groupActivityRecurringUpdated(String actor, String name);

  /// No description provided for @groupActivityRecurringPaused.
  ///
  /// In en, this message translates to:
  /// **'{actor} paused the recurring expense “{name}”.'**
  String groupActivityRecurringPaused(String actor, String name);

  /// No description provided for @groupActivityRecurringResumed.
  ///
  /// In en, this message translates to:
  /// **'{actor} resumed the recurring expense “{name}”.'**
  String groupActivityRecurringResumed(String actor, String name);

  /// No description provided for @groupActivityRecurringStopped.
  ///
  /// In en, this message translates to:
  /// **'{actor} stopped the recurring expense “{name}”.'**
  String groupActivityRecurringStopped(String actor, String name);

  /// No description provided for @groupActivityRecurringSkipped.
  ///
  /// In en, this message translates to:
  /// **'{actor} skipped one “{name}”.'**
  String groupActivityRecurringSkipped(String actor, String name);

  /// No description provided for @groupActivityOther.
  ///
  /// In en, this message translates to:
  /// **'{actor} made a change.'**
  String groupActivityOther(String actor);

  /// No description provided for @groupDetailsSection.
  ///
  /// In en, this message translates to:
  /// **'Group details'**
  String get groupDetailsSection;

  /// No description provided for @groupAddMember.
  ///
  /// In en, this message translates to:
  /// **'Add a member'**
  String get groupAddMember;

  /// No description provided for @groupAddFromFriends.
  ///
  /// In en, this message translates to:
  /// **'From your friends'**
  String get groupAddFromFriends;

  /// No description provided for @groupAddFromFriendsHelp.
  ///
  /// In en, this message translates to:
  /// **'Friends can be added even if they can’t be found by username.'**
  String get groupAddFromFriendsHelp;

  /// No description provided for @groupAddByUsername.
  ///
  /// In en, this message translates to:
  /// **'By username'**
  String get groupAddByUsername;

  /// No description provided for @groupAddByUsernameHelp.
  ///
  /// In en, this message translates to:
  /// **'Only people who let others find them by username can be invited this way.'**
  String get groupAddByUsernameHelp;

  /// No description provided for @groupInvite.
  ///
  /// In en, this message translates to:
  /// **'Invite'**
  String get groupInvite;

  /// No description provided for @groupInvitedDone.
  ///
  /// In en, this message translates to:
  /// **'Invitation sent to {name}. They join when they accept.'**
  String groupInvitedDone(String name);

  /// No description provided for @groupMakeAdmin.
  ///
  /// In en, this message translates to:
  /// **'Make admin'**
  String get groupMakeAdmin;

  /// No description provided for @groupAdminHelp.
  ///
  /// In en, this message translates to:
  /// **'Admins can change the group, manage members and approve requests.'**
  String get groupAdminHelp;

  /// No description provided for @groupMakeMember.
  ///
  /// In en, this message translates to:
  /// **'Make member'**
  String get groupMakeMember;

  /// No description provided for @groupRoleChangedDone.
  ///
  /// In en, this message translates to:
  /// **'{name} is now {role}.'**
  String groupRoleChangedDone(String name, String role);

  /// No description provided for @groupTransferOwnership.
  ///
  /// In en, this message translates to:
  /// **'Make owner'**
  String get groupTransferOwnership;

  /// No description provided for @groupTransferConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Make {name} the owner?'**
  String groupTransferConfirmTitle(String name);

  /// No description provided for @groupTransferConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'{name} will own the group and can archive or delete it. You stay in the group as an admin.'**
  String groupTransferConfirmBody(String name);

  /// No description provided for @groupTransferredDone.
  ///
  /// In en, this message translates to:
  /// **'{name} is now the owner.'**
  String groupTransferredDone(String name);

  /// No description provided for @groupRemoveMember.
  ///
  /// In en, this message translates to:
  /// **'Remove from group'**
  String get groupRemoveMember;

  /// No description provided for @groupRemoveConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove {name} from the group?'**
  String groupRemoveConfirmTitle(String name);

  /// No description provided for @groupRemoveConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'{name} loses access at once. Their expenses, shares and payments stay in the records. If they still owe or are owed money, that balance keeps counting in balances, suggested payments and reports, anyone can record a payment with them, and an admin can confirm a payment to them.'**
  String groupRemoveConfirmBody(String name);

  /// No description provided for @groupRemovedDone.
  ///
  /// In en, this message translates to:
  /// **'{name} was removed from the group.'**
  String groupRemovedDone(String name);

  /// No description provided for @groupRemovalPolicy.
  ///
  /// In en, this message translates to:
  /// **'Removing a member keeps their records. An open balance stays in the group until it is settled.'**
  String get groupRemovalPolicy;

  /// No description provided for @groupInvitationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Invitations'**
  String get groupInvitationsTitle;

  /// No description provided for @groupCreateLink.
  ///
  /// In en, this message translates to:
  /// **'Create an invitation link'**
  String get groupCreateLink;

  /// No description provided for @groupCreateLinkHelp.
  ///
  /// In en, this message translates to:
  /// **'Anyone with the link can see the group’s name and ask to join.'**
  String get groupCreateLinkHelp;

  /// No description provided for @groupInvitationsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Invitations couldn’t be loaded.'**
  String get groupInvitationsUnavailable;

  /// No description provided for @groupInvitationsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No invitations yet.'**
  String get groupInvitationsEmpty;

  /// No description provided for @groupInvitationLinkTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Invitation link · not used yet} =1{Invitation link · used once} other{Invitation link · used {count} times}}'**
  String groupInvitationLinkTitle(int count);

  /// No description provided for @groupInvitationForPerson.
  ///
  /// In en, this message translates to:
  /// **'Invitation for {name}'**
  String groupInvitationForPerson(String name);

  /// No description provided for @groupInvitationCreated.
  ///
  /// In en, this message translates to:
  /// **'By {name} on {date}'**
  String groupInvitationCreated(String name, String date);

  /// No description provided for @groupInvitationStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get groupInvitationStatusActive;

  /// No description provided for @groupInvitationStatusAccepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get groupInvitationStatusAccepted;

  /// No description provided for @groupInvitationStatusDeclined.
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get groupInvitationStatusDeclined;

  /// No description provided for @groupInvitationStatusRevoked.
  ///
  /// In en, this message translates to:
  /// **'Turned off'**
  String get groupInvitationStatusRevoked;

  /// No description provided for @groupInvitationStatusExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get groupInvitationStatusExpired;

  /// No description provided for @groupInvitationRevoke.
  ///
  /// In en, this message translates to:
  /// **'Turn off'**
  String get groupInvitationRevoke;

  /// No description provided for @groupInvitationRevokeTitle.
  ///
  /// In en, this message translates to:
  /// **'Turn off this invitation?'**
  String get groupInvitationRevokeTitle;

  /// No description provided for @groupInvitationRevokeBody.
  ///
  /// In en, this message translates to:
  /// **'It can’t be used to join any more. People who already joined stay in the group.'**
  String get groupInvitationRevokeBody;

  /// No description provided for @groupInvitationRevokedDone.
  ///
  /// In en, this message translates to:
  /// **'Invitation turned off.'**
  String get groupInvitationRevokedDone;

  /// No description provided for @groupLinkCreatedDone.
  ///
  /// In en, this message translates to:
  /// **'Invitation link created.'**
  String get groupLinkCreatedDone;

  /// No description provided for @groupLinkExpiresLabel.
  ///
  /// In en, this message translates to:
  /// **'Valid for'**
  String get groupLinkExpiresLabel;

  /// No description provided for @groupLinkDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String groupLinkDays(int count);

  /// No description provided for @groupLinkUsesLabel.
  ///
  /// In en, this message translates to:
  /// **'Can be used'**
  String get groupLinkUsesLabel;

  /// No description provided for @groupLinkUses.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Once} other{{count} times}}'**
  String groupLinkUses(int count);

  /// No description provided for @groupLinkUsesAny.
  ///
  /// In en, this message translates to:
  /// **'Any number of times'**
  String get groupLinkUsesAny;

  /// No description provided for @groupLinkReadyTitle.
  ///
  /// In en, this message translates to:
  /// **'Share your invitation link'**
  String get groupLinkReadyTitle;

  /// No description provided for @groupLinkShownOnce.
  ///
  /// In en, this message translates to:
  /// **'This link is shown only now. Copy or share it before you close this window. You can turn it off any time.'**
  String get groupLinkShownOnce;

  /// No description provided for @groupLinkShareText.
  ///
  /// In en, this message translates to:
  /// **'Join {group} on Montra: {link}'**
  String groupLinkShareText(String group, String link);

  /// No description provided for @groupJoinRequestsTitle.
  ///
  /// In en, this message translates to:
  /// **'Requests to join'**
  String get groupJoinRequestsTitle;

  /// No description provided for @groupJoinRequestsOnHelp.
  ///
  /// In en, this message translates to:
  /// **'People who open an invitation link wait here until an admin approves them.'**
  String get groupJoinRequestsOnHelp;

  /// No description provided for @groupJoinRequestsOffHelp.
  ///
  /// In en, this message translates to:
  /// **'Approval is off: people with an invitation link join directly. Turn it on in the group details.'**
  String get groupJoinRequestsOffHelp;

  /// No description provided for @groupJoinRequestsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Requests couldn’t be loaded.'**
  String get groupJoinRequestsUnavailable;

  /// No description provided for @groupJoinRequestsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No one is waiting.'**
  String get groupJoinRequestsEmpty;

  /// No description provided for @groupJoinRequestApprove.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get groupJoinRequestApprove;

  /// No description provided for @groupJoinRequestDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get groupJoinRequestDecline;

  /// No description provided for @groupJoinRequestApprovedDone.
  ///
  /// In en, this message translates to:
  /// **'{name} joined the group.'**
  String groupJoinRequestApprovedDone(String name);

  /// No description provided for @groupJoinRequestDeclinedDone.
  ///
  /// In en, this message translates to:
  /// **'Request from {name} declined.'**
  String groupJoinRequestDeclinedDone(String name);

  /// No description provided for @groupJoinRequestStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get groupJoinRequestStatusPending;

  /// No description provided for @groupJoinRequestStatusApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get groupJoinRequestStatusApproved;

  /// No description provided for @groupJoinRequestStatusDeclined.
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get groupJoinRequestStatusDeclined;

  /// No description provided for @groupJoinRequestStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get groupJoinRequestStatusCancelled;

  /// No description provided for @groupYourNotifications.
  ///
  /// In en, this message translates to:
  /// **'Your notifications from this group'**
  String get groupYourNotifications;

  /// No description provided for @groupNotificationsSaved.
  ///
  /// In en, this message translates to:
  /// **'Notification choice saved.'**
  String get groupNotificationsSaved;

  /// No description provided for @groupActionsSection.
  ///
  /// In en, this message translates to:
  /// **'Group actions'**
  String get groupActionsSection;

  /// No description provided for @groupArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive group'**
  String get groupArchive;

  /// No description provided for @groupArchiveHelp.
  ///
  /// In en, this message translates to:
  /// **'Archiving keeps every record and pauses recurring expenses. Nothing can change until you restore it.'**
  String get groupArchiveHelp;

  /// No description provided for @groupArchiveConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Archive {name}?'**
  String groupArchiveConfirmTitle(String name);

  /// No description provided for @groupArchivedDone.
  ///
  /// In en, this message translates to:
  /// **'Group archived.'**
  String get groupArchivedDone;

  /// No description provided for @groupRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore group'**
  String get groupRestore;

  /// No description provided for @groupRestoredDone.
  ///
  /// In en, this message translates to:
  /// **'Group restored.'**
  String get groupRestoredDone;

  /// No description provided for @groupLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave group'**
  String get groupLeave;

  /// No description provided for @groupLeaveHelp.
  ///
  /// In en, this message translates to:
  /// **'You can leave once your balance in the group is settled. Your past expenses and payments stay in the group’s records.'**
  String get groupLeaveHelp;

  /// No description provided for @groupLeaveConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave {name}?'**
  String groupLeaveConfirmTitle(String name);

  /// No description provided for @groupLeftDone.
  ///
  /// In en, this message translates to:
  /// **'You left {name}.'**
  String groupLeftDone(String name);

  /// No description provided for @groupOwnerLeaveNote.
  ///
  /// In en, this message translates to:
  /// **'As the owner, make someone else the owner (under Members) before you leave.'**
  String get groupOwnerLeaveNote;

  /// No description provided for @groupDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete group'**
  String get groupDelete;

  /// No description provided for @groupDeleteHelp.
  ///
  /// In en, this message translates to:
  /// **'Everyone’s balances must be settled first. Deleting removes the group for every member and turns off its invitations. This can’t be undone.'**
  String get groupDeleteHelp;

  /// No description provided for @groupDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String groupDeleteConfirmTitle(String name);

  /// No description provided for @groupDeletedDone.
  ///
  /// In en, this message translates to:
  /// **'{name} was deleted.'**
  String groupDeletedDone(String name);

  /// No description provided for @groupCodeAlreadyMember.
  ///
  /// In en, this message translates to:
  /// **'This person is already a member of the group.'**
  String get groupCodeAlreadyMember;

  /// No description provided for @groupCodeJoinRequestPending.
  ///
  /// In en, this message translates to:
  /// **'Your request to join is already waiting for the admins.'**
  String get groupCodeJoinRequestPending;

  /// No description provided for @groupCodeInvitationUsed.
  ///
  /// In en, this message translates to:
  /// **'This invitation was already {status}.'**
  String groupCodeInvitationUsed(String status);

  /// No description provided for @groupCodeInvitationInactive.
  ///
  /// In en, this message translates to:
  /// **'This invitation is no longer active.'**
  String get groupCodeInvitationInactive;

  /// No description provided for @groupCodeArchived.
  ///
  /// In en, this message translates to:
  /// **'This group is archived. The owner can restore it to make changes.'**
  String get groupCodeArchived;

  /// No description provided for @groupCodeNotArchived.
  ///
  /// In en, this message translates to:
  /// **'The group is not archived.'**
  String get groupCodeNotArchived;

  /// No description provided for @groupCodeBalanceOpen.
  ///
  /// In en, this message translates to:
  /// **'Settle your balance in the group before you leave.'**
  String get groupCodeBalanceOpen;

  /// No description provided for @groupCodeBalancesOpen.
  ///
  /// In en, this message translates to:
  /// **'Everyone’s balances must be settled before the group can be deleted.'**
  String get groupCodeBalancesOpen;

  /// No description provided for @groupCodeTransferFirst.
  ///
  /// In en, this message translates to:
  /// **'Make someone else the owner before you leave.'**
  String get groupCodeTransferFirst;

  /// No description provided for @groupCodeCurrencyLocked.
  ///
  /// In en, this message translates to:
  /// **'The group currency can’t change once the group has expenses, payments or recurring expenses.'**
  String get groupCodeCurrencyLocked;

  /// No description provided for @togetherIntro.
  ///
  /// In en, this message translates to:
  /// **'Share expenses with the people around you, learn from communities and take on challenges. Everything here is free.'**
  String get togetherIntro;

  /// No description provided for @togetherFriendsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Find people by username and manage requests'**
  String get togetherFriendsSubtitle;

  /// No description provided for @togetherFriendRequests.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 friend request is waiting} other{{count} friend requests are waiting}}'**
  String togetherFriendRequests(int count);

  /// No description provided for @togetherGroupsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Split expenses with a household, trip or friends'**
  String get togetherGroupsSubtitle;

  /// No description provided for @togetherGroupsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 group} other{{count} groups}}'**
  String togetherGroupsCount(int count);

  /// No description provided for @togetherGroupInvitations.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 group invitation for you} other{{count} group invitations for you}}'**
  String togetherGroupInvitations(int count);

  /// No description provided for @togetherCommunities.
  ///
  /// In en, this message translates to:
  /// **'Communities'**
  String get togetherCommunities;

  /// No description provided for @togetherCommunitiesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Discuss money topics with others'**
  String get togetherCommunitiesSubtitle;

  /// No description provided for @togetherChallenges.
  ///
  /// In en, this message translates to:
  /// **'Challenges'**
  String get togetherChallenges;

  /// No description provided for @togetherChallengesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Build habits, alone or together'**
  String get togetherChallengesSubtitle;

  /// No description provided for @togetherJoinSection.
  ///
  /// In en, this message translates to:
  /// **'Got an invitation link?'**
  String get togetherJoinSection;

  /// No description provided for @togetherJoinGroupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Paste a group invitation link'**
  String get togetherJoinGroupSubtitle;

  /// No description provided for @togetherJoinCommunity.
  ///
  /// In en, this message translates to:
  /// **'Join a community with a link'**
  String get togetherJoinCommunity;

  /// No description provided for @togetherJoinCommunitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Paste a community invitation link'**
  String get togetherJoinCommunitySubtitle;

  /// No description provided for @communityVisibilityPublic.
  ///
  /// In en, this message translates to:
  /// **'Public'**
  String get communityVisibilityPublic;

  /// No description provided for @communityVisibilityPrivate.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get communityVisibilityPrivate;

  /// No description provided for @communityVisibilityInviteOnly.
  ///
  /// In en, this message translates to:
  /// **'Invitation only'**
  String get communityVisibilityInviteOnly;

  /// No description provided for @communityVisibilityPublicHelp.
  ///
  /// In en, this message translates to:
  /// **'Anyone can find it and join.'**
  String get communityVisibilityPublicHelp;

  /// No description provided for @communityVisibilityPrivateHelp.
  ///
  /// In en, this message translates to:
  /// **'Anyone can find it; moderators approve who joins.'**
  String get communityVisibilityPrivateHelp;

  /// No description provided for @communityVisibilityInviteOnlyHelp.
  ///
  /// In en, this message translates to:
  /// **'Not listed; people join with an invitation.'**
  String get communityVisibilityInviteOnlyHelp;

  /// No description provided for @communityRoleOwner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get communityRoleOwner;

  /// No description provided for @communityRoleModerator.
  ///
  /// In en, this message translates to:
  /// **'Moderator'**
  String get communityRoleModerator;

  /// No description provided for @communityRoleMember.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get communityRoleMember;

  /// No description provided for @communityMemberStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get communityMemberStatusActive;

  /// No description provided for @communityMemberStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Waiting for approval'**
  String get communityMemberStatusPending;

  /// No description provided for @communityMemberStatusBanned.
  ///
  /// In en, this message translates to:
  /// **'Banned'**
  String get communityMemberStatusBanned;

  /// No description provided for @communityMemberStatusLeft.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get communityMemberStatusLeft;

  /// No description provided for @postKindDiscussion.
  ///
  /// In en, this message translates to:
  /// **'Discussion'**
  String get postKindDiscussion;

  /// No description provided for @postKindQuestion.
  ///
  /// In en, this message translates to:
  /// **'Question'**
  String get postKindQuestion;

  /// No description provided for @postKindResource.
  ///
  /// In en, this message translates to:
  /// **'Resource link'**
  String get postKindResource;

  /// No description provided for @postKindPoll.
  ///
  /// In en, this message translates to:
  /// **'Poll'**
  String get postKindPoll;

  /// No description provided for @postKindChallengeUpdate.
  ///
  /// In en, this message translates to:
  /// **'Challenge update'**
  String get postKindChallengeUpdate;

  /// No description provided for @postLabelPersonalExperience.
  ///
  /// In en, this message translates to:
  /// **'Personal experience'**
  String get postLabelPersonalExperience;

  /// No description provided for @postLabelVerifiedGuidance.
  ///
  /// In en, this message translates to:
  /// **'Verified guidance'**
  String get postLabelVerifiedGuidance;

  /// No description provided for @postLabelQuestion.
  ///
  /// In en, this message translates to:
  /// **'Question'**
  String get postLabelQuestion;

  /// No description provided for @postLabelResource.
  ///
  /// In en, this message translates to:
  /// **'Resource'**
  String get postLabelResource;

  /// No description provided for @reactionLike.
  ///
  /// In en, this message translates to:
  /// **'Like'**
  String get reactionLike;

  /// No description provided for @reactionHelpful.
  ///
  /// In en, this message translates to:
  /// **'Helpful'**
  String get reactionHelpful;

  /// No description provided for @reactionInsightful.
  ///
  /// In en, this message translates to:
  /// **'Insightful'**
  String get reactionInsightful;

  /// No description provided for @reactionSupport.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get reactionSupport;

  /// No description provided for @contentReportReasonSpam.
  ///
  /// In en, this message translates to:
  /// **'Spam'**
  String get contentReportReasonSpam;

  /// No description provided for @contentReportReasonAbuse.
  ///
  /// In en, this message translates to:
  /// **'Abuse'**
  String get contentReportReasonAbuse;

  /// No description provided for @contentReportReasonHarassment.
  ///
  /// In en, this message translates to:
  /// **'Harassment'**
  String get contentReportReasonHarassment;

  /// No description provided for @contentReportReasonScam.
  ///
  /// In en, this message translates to:
  /// **'Scam or fraud'**
  String get contentReportReasonScam;

  /// No description provided for @contentReportReasonImpersonation.
  ///
  /// In en, this message translates to:
  /// **'Pretending to be someone else'**
  String get contentReportReasonImpersonation;

  /// No description provided for @contentReportReasonMisinformation.
  ///
  /// In en, this message translates to:
  /// **'False or misleading'**
  String get contentReportReasonMisinformation;

  /// No description provided for @contentReportReasonPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Shares private information'**
  String get contentReportReasonPrivacy;

  /// No description provided for @contentReportReasonOther.
  ///
  /// In en, this message translates to:
  /// **'Something else'**
  String get contentReportReasonOther;

  /// No description provided for @communityErrorAccountRestricted.
  ///
  /// In en, this message translates to:
  /// **'Your account can\'t take part in communities right now.'**
  String get communityErrorAccountRestricted;

  /// No description provided for @communityErrorAlreadyDeleted.
  ///
  /// In en, this message translates to:
  /// **'This was already deleted.'**
  String get communityErrorAlreadyDeleted;

  /// No description provided for @communityErrorCommentLocked.
  ///
  /// In en, this message translates to:
  /// **'This comment can\'t be changed any more.'**
  String get communityErrorCommentLocked;

  /// No description provided for @communityErrorCommentsClosed.
  ///
  /// In en, this message translates to:
  /// **'Comments are closed on this post.'**
  String get communityErrorCommentsClosed;

  /// No description provided for @communityErrorSuspended.
  ///
  /// In en, this message translates to:
  /// **'This community is suspended. Only Montra staff can restore it.'**
  String get communityErrorSuspended;

  /// No description provided for @communityErrorContentUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This isn\'t available any more.'**
  String get communityErrorContentUnavailable;

  /// No description provided for @communityErrorInvitationOnly.
  ///
  /// In en, this message translates to:
  /// **'This community is invitation only. Ask a moderator for an invitation.'**
  String get communityErrorInvitationOnly;

  /// No description provided for @communityErrorJoinFirst.
  ///
  /// In en, this message translates to:
  /// **'Join the community to take part.'**
  String get communityErrorJoinFirst;

  /// No description provided for @communityErrorNewAccountLinks.
  ///
  /// In en, this message translates to:
  /// **'New accounts can share links after their first day.'**
  String get communityErrorNewAccountLinks;

  /// No description provided for @communityErrorNotAcceptingMembers.
  ///
  /// In en, this message translates to:
  /// **'This community isn\'t accepting new members.'**
  String get communityErrorNotAcceptingMembers;

  /// No description provided for @communityErrorNotAcceptingPosts.
  ///
  /// In en, this message translates to:
  /// **'This community isn\'t accepting new posts.'**
  String get communityErrorNotAcceptingPosts;

  /// No description provided for @communityErrorOwnContent.
  ///
  /// In en, this message translates to:
  /// **'Ask another moderator to act on your own content or account.'**
  String get communityErrorOwnContent;

  /// No description provided for @communityErrorOwnerProtected.
  ///
  /// In en, this message translates to:
  /// **'The owner can\'t be banned from their own community.'**
  String get communityErrorOwnerProtected;

  /// No description provided for @communityErrorPollClosed.
  ///
  /// In en, this message translates to:
  /// **'This poll is closed.'**
  String get communityErrorPollClosed;

  /// No description provided for @communityErrorPostLocked.
  ///
  /// In en, this message translates to:
  /// **'This post can\'t be changed any more.'**
  String get communityErrorPostLocked;

  /// No description provided for @communityErrorPostingRestrictedUntil.
  ///
  /// In en, this message translates to:
  /// **'A moderator paused your posting here until {until}.'**
  String communityErrorPostingRestrictedUntil(String until);

  /// No description provided for @communityErrorPostingRestricted.
  ///
  /// In en, this message translates to:
  /// **'A moderator paused your posting here for now.'**
  String get communityErrorPostingRestricted;

  /// No description provided for @communityErrorTransferOwnershipFirst.
  ///
  /// In en, this message translates to:
  /// **'Transfer ownership before leaving.'**
  String get communityErrorTransferOwnershipFirst;

  /// No description provided for @communityErrorAlreadyMember.
  ///
  /// In en, this message translates to:
  /// **'You\'re already a member.'**
  String get communityErrorAlreadyMember;

  /// No description provided for @communityErrorInvitationUsed.
  ///
  /// In en, this message translates to:
  /// **'This invitation was already answered.'**
  String get communityErrorInvitationUsed;

  /// No description provided for @communityErrorInvitationInactive.
  ///
  /// In en, this message translates to:
  /// **'This invitation is no longer active.'**
  String get communityErrorInvitationInactive;

  /// No description provided for @challengeErrorCancelled.
  ///
  /// In en, this message translates to:
  /// **'This challenge was cancelled.'**
  String get challengeErrorCancelled;

  /// No description provided for @challengeErrorInactive.
  ///
  /// In en, this message translates to:
  /// **'This challenge is no longer active.'**
  String get challengeErrorInactive;

  /// No description provided for @challengeErrorNotOpen.
  ///
  /// In en, this message translates to:
  /// **'This challenge isn\'t open.'**
  String get challengeErrorNotOpen;

  /// No description provided for @challengeErrorJoinFirst.
  ///
  /// In en, this message translates to:
  /// **'Join the challenge first.'**
  String get challengeErrorJoinFirst;

  /// No description provided for @challengeErrorLeaderboardOptIn.
  ///
  /// In en, this message translates to:
  /// **'The leaderboard is shared both ways: share your progress and choose to appear on it to see it.'**
  String get challengeErrorLeaderboardOptIn;

  /// No description provided for @challengeErrorNoLeaderboard.
  ///
  /// In en, this message translates to:
  /// **'This challenge has no leaderboard.'**
  String get challengeErrorNoLeaderboard;

  /// No description provided for @challengeTypeNoSpend.
  ///
  /// In en, this message translates to:
  /// **'No-spend'**
  String get challengeTypeNoSpend;

  /// No description provided for @challengeTypeSavingsStreak.
  ///
  /// In en, this message translates to:
  /// **'Savings streak'**
  String get challengeTypeSavingsStreak;

  /// No description provided for @challengeTypeGroceryBudget.
  ///
  /// In en, this message translates to:
  /// **'Grocery budget'**
  String get challengeTypeGroceryBudget;

  /// No description provided for @challengeTypeMealPlanning.
  ///
  /// In en, this message translates to:
  /// **'Meal planning'**
  String get challengeTypeMealPlanning;

  /// No description provided for @challengeTypeTravelSavings.
  ///
  /// In en, this message translates to:
  /// **'Travel savings'**
  String get challengeTypeTravelSavings;

  /// No description provided for @challengeTypeCustom.
  ///
  /// In en, this message translates to:
  /// **'Your own'**
  String get challengeTypeCustom;

  /// No description provided for @challengeMetricDays.
  ///
  /// In en, this message translates to:
  /// **'Days checked in'**
  String get challengeMetricDays;

  /// No description provided for @challengeMetricStreak.
  ///
  /// In en, this message translates to:
  /// **'Longest streak'**
  String get challengeMetricStreak;

  /// No description provided for @challengeMetricMilestones.
  ///
  /// In en, this message translates to:
  /// **'Total check-ins'**
  String get challengeMetricMilestones;

  /// No description provided for @challengeMetricPercent.
  ///
  /// In en, this message translates to:
  /// **'Your own percentage'**
  String get challengeMetricPercent;

  /// No description provided for @challengeMetricDaysHelp.
  ///
  /// In en, this message translates to:
  /// **'Each day you check in as done counts.'**
  String get challengeMetricDaysHelp;

  /// No description provided for @challengeMetricStreakHelp.
  ///
  /// In en, this message translates to:
  /// **'Your longest run of days in a row counts.'**
  String get challengeMetricStreakHelp;

  /// No description provided for @challengeMetricMilestonesHelp.
  ///
  /// In en, this message translates to:
  /// **'Every check-in adds up, with the count you enter.'**
  String get challengeMetricMilestonesHelp;

  /// No description provided for @challengeMetricPercentHelp.
  ///
  /// In en, this message translates to:
  /// **'You report how far you are, from 0 to 100 %.'**
  String get challengeMetricPercentHelp;

  /// No description provided for @challengeTargetDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String challengeTargetDays(int count);

  /// No description provided for @challengeTargetStreak.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day in a row} other{{count} days in a row}}'**
  String challengeTargetStreak(int count);

  /// No description provided for @challengeTargetCheckIns.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 check-in} other{{count} check-ins}}'**
  String challengeTargetCheckIns(int count);

  /// No description provided for @challengeTargetPercent.
  ///
  /// In en, this message translates to:
  /// **'{count} %'**
  String challengeTargetPercent(int count);

  /// No description provided for @challengeStatusDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get challengeStatusDraft;

  /// No description provided for @challengeStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get challengeStatusActive;

  /// No description provided for @challengeStatusEnded.
  ///
  /// In en, this message translates to:
  /// **'Ended'**
  String get challengeStatusEnded;

  /// No description provided for @challengeStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get challengeStatusCompleted;

  /// No description provided for @challengeStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get challengeStatusCancelled;

  /// No description provided for @challengeScopePrivate.
  ///
  /// In en, this message translates to:
  /// **'Just you'**
  String get challengeScopePrivate;

  /// No description provided for @challengeScopeGroup.
  ///
  /// In en, this message translates to:
  /// **'A group'**
  String get challengeScopeGroup;

  /// No description provided for @challengeScopeCommunity.
  ///
  /// In en, this message translates to:
  /// **'A community'**
  String get challengeScopeCommunity;

  /// No description provided for @challengeScopePublic.
  ///
  /// In en, this message translates to:
  /// **'Everyone'**
  String get challengeScopePublic;

  /// No description provided for @challengeMilestoneHalfway.
  ///
  /// In en, this message translates to:
  /// **'Halfway there'**
  String get challengeMilestoneHalfway;

  /// No description provided for @challengeMilestoneDone.
  ///
  /// In en, this message translates to:
  /// **'Target reached'**
  String get challengeMilestoneDone;

  /// No description provided for @challengeMilestonePercent.
  ///
  /// In en, this message translates to:
  /// **'{percent} % of the target'**
  String challengeMilestonePercent(int percent);

  /// No description provided for @moderationErrorOtherModerator.
  ///
  /// In en, this message translates to:
  /// **'Another moderator must review an appeal against your own action.'**
  String get moderationErrorOtherModerator;

  /// No description provided for @moderationErrorAppealWindowPassed.
  ///
  /// In en, this message translates to:
  /// **'Appeals can be made within 30 days of the decision.'**
  String get moderationErrorAppealWindowPassed;

  /// No description provided for @moderationErrorNotAppealable.
  ///
  /// In en, this message translates to:
  /// **'This decision can\'t be appealed.'**
  String get moderationErrorNotAppealable;

  /// No description provided for @moderationActionHide.
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get moderationActionHide;

  /// No description provided for @moderationActionRemove.
  ///
  /// In en, this message translates to:
  /// **'Removed'**
  String get moderationActionRemove;

  /// No description provided for @moderationActionRestore.
  ///
  /// In en, this message translates to:
  /// **'Restored'**
  String get moderationActionRestore;

  /// No description provided for @moderationActionPin.
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get moderationActionPin;

  /// No description provided for @moderationActionUnpin.
  ///
  /// In en, this message translates to:
  /// **'Unpinned'**
  String get moderationActionUnpin;

  /// No description provided for @moderationActionLock.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get moderationActionLock;

  /// No description provided for @moderationActionUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlocked'**
  String get moderationActionUnlock;

  /// No description provided for @moderationActionWarn.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get moderationActionWarn;

  /// No description provided for @moderationActionRestrict.
  ///
  /// In en, this message translates to:
  /// **'Posting paused'**
  String get moderationActionRestrict;

  /// No description provided for @moderationActionBan.
  ///
  /// In en, this message translates to:
  /// **'Banned'**
  String get moderationActionBan;

  /// No description provided for @moderationActionUnban.
  ///
  /// In en, this message translates to:
  /// **'Ban lifted'**
  String get moderationActionUnban;

  /// No description provided for @moderationActionDismissReport.
  ///
  /// In en, this message translates to:
  /// **'Report dismissed'**
  String get moderationActionDismissReport;

  /// No description provided for @moderationActionEscalate.
  ///
  /// In en, this message translates to:
  /// **'Sent to Montra staff'**
  String get moderationActionEscalate;

  /// No description provided for @moderationActionSuspend.
  ///
  /// In en, this message translates to:
  /// **'Suspended'**
  String get moderationActionSuspend;

  /// No description provided for @moderationActionUnsuspend.
  ///
  /// In en, this message translates to:
  /// **'Suspension lifted'**
  String get moderationActionUnsuspend;

  /// No description provided for @moderationTargetPost.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get moderationTargetPost;

  /// No description provided for @moderationTargetComment.
  ///
  /// In en, this message translates to:
  /// **'Comment'**
  String get moderationTargetComment;

  /// No description provided for @moderationTargetMember.
  ///
  /// In en, this message translates to:
  /// **'Membership'**
  String get moderationTargetMember;

  /// No description provided for @moderationTargetProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get moderationTargetProfile;

  /// No description provided for @moderationTargetGroup.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get moderationTargetGroup;

  /// No description provided for @moderationTargetCommunity.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get moderationTargetCommunity;

  /// No description provided for @appealStatusOpen.
  ///
  /// In en, this message translates to:
  /// **'Appeal under review'**
  String get appealStatusOpen;

  /// No description provided for @appealStatusUpheld.
  ///
  /// In en, this message translates to:
  /// **'Decision stands'**
  String get appealStatusUpheld;

  /// No description provided for @appealStatusOverturned.
  ///
  /// In en, this message translates to:
  /// **'Decision reversed'**
  String get appealStatusOverturned;

  /// No description provided for @appealStatusOpenHelp.
  ///
  /// In en, this message translates to:
  /// **'A moderator who didn\'t make the decision will review your appeal.'**
  String get appealStatusOpenHelp;

  /// No description provided for @appealStatusUpheldHelp.
  ///
  /// In en, this message translates to:
  /// **'Your appeal was reviewed and the decision stands.'**
  String get appealStatusUpheldHelp;

  /// No description provided for @appealStatusOverturnedHelp.
  ///
  /// In en, this message translates to:
  /// **'Your appeal was accepted and the decision was reversed.'**
  String get appealStatusOverturnedHelp;

  /// No description provided for @contentReportStatusOpen.
  ///
  /// In en, this message translates to:
  /// **'Waiting for review'**
  String get contentReportStatusOpen;

  /// No description provided for @contentReportStatusUnderReview.
  ///
  /// In en, this message translates to:
  /// **'Being reviewed'**
  String get contentReportStatusUnderReview;

  /// No description provided for @contentReportStatusActioned.
  ///
  /// In en, this message translates to:
  /// **'Action taken'**
  String get contentReportStatusActioned;

  /// No description provided for @contentReportStatusDismissed.
  ///
  /// In en, this message translates to:
  /// **'No action needed'**
  String get contentReportStatusDismissed;

  /// No description provided for @contentReportStatusEscalated.
  ///
  /// In en, this message translates to:
  /// **'Sent to Montra staff'**
  String get contentReportStatusEscalated;

  /// No description provided for @contentReportStatusOpenHelp.
  ///
  /// In en, this message translates to:
  /// **'Moderators will look at it. Thank you for helping keep things kind.'**
  String get contentReportStatusOpenHelp;

  /// No description provided for @contentReportStatusActionedHelp.
  ///
  /// In en, this message translates to:
  /// **'Moderators acted on what you reported.'**
  String get contentReportStatusActionedHelp;

  /// No description provided for @contentReportStatusDismissedHelp.
  ///
  /// In en, this message translates to:
  /// **'Moderators looked at it and found it within the rules.'**
  String get contentReportStatusDismissedHelp;

  /// No description provided for @contentReportStatusEscalatedHelp.
  ///
  /// In en, this message translates to:
  /// **'Moderators passed it to Montra staff to review.'**
  String get contentReportStatusEscalatedHelp;

  /// No description provided for @communityEdited.
  ///
  /// In en, this message translates to:
  /// **'edited'**
  String get communityEdited;

  /// No description provided for @reactionSemantics.
  ///
  /// In en, this message translates to:
  /// **'{reaction}, {count}'**
  String reactionSemantics(String reaction, int count);

  /// No description provided for @pollVoted.
  ///
  /// In en, this message translates to:
  /// **'Your vote is saved.'**
  String get pollVoted;

  /// No description provided for @pollTotalVotes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No votes yet} =1{1 vote} other{{count} votes}}'**
  String pollTotalVotes(int count);

  /// No description provided for @pollChooseSeveral.
  ///
  /// In en, this message translates to:
  /// **'Choose one or more'**
  String get pollChooseSeveral;

  /// No description provided for @pollClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get pollClosed;

  /// No description provided for @pollClosesAt.
  ///
  /// In en, this message translates to:
  /// **'Closes {date}'**
  String pollClosesAt(String date);

  /// No description provided for @pollVote.
  ///
  /// In en, this message translates to:
  /// **'Vote'**
  String get pollVote;

  /// No description provided for @pollChangeVote.
  ///
  /// In en, this message translates to:
  /// **'Change my vote'**
  String get pollChangeVote;

  /// No description provided for @pollPrivacyNote.
  ///
  /// In en, this message translates to:
  /// **'Only the totals are shown; nobody sees who voted for what.'**
  String get pollPrivacyNote;

  /// No description provided for @pollOptionResult.
  ///
  /// In en, this message translates to:
  /// **'{votes, plural, =1{1 vote} other{{votes} votes}} · {percent} %'**
  String pollOptionResult(int votes, int percent);

  /// No description provided for @pollYourChoice.
  ///
  /// In en, this message translates to:
  /// **'{option} (your vote)'**
  String pollYourChoice(String option);

  /// No description provided for @communityLinkNotOpened.
  ///
  /// In en, this message translates to:
  /// **'This link can\'t be opened. Only web links (https) are opened.'**
  String get communityLinkNotOpened;

  /// No description provided for @contentReportSent.
  ///
  /// In en, this message translates to:
  /// **'Thank you. Moderators will review your report.'**
  String get contentReportSent;

  /// No description provided for @contentReportAlreadySent.
  ///
  /// In en, this message translates to:
  /// **'You already reported this. Moderators will review it.'**
  String get contentReportAlreadySent;

  /// No description provided for @contentReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get contentReportTitle;

  /// No description provided for @contentReportIntro.
  ///
  /// In en, this message translates to:
  /// **'Tell moderators what\'s wrong. The person you report isn\'t told who reported them.'**
  String get contentReportIntro;

  /// No description provided for @contentReportDetailsLabel.
  ///
  /// In en, this message translates to:
  /// **'More details (optional)'**
  String get contentReportDetailsLabel;

  /// No description provided for @contentReportDetailsHelp.
  ///
  /// In en, this message translates to:
  /// **'Don\'t include card numbers, PINs or passwords.'**
  String get contentReportDetailsHelp;

  /// No description provided for @contentReportSend.
  ///
  /// In en, this message translates to:
  /// **'Send report'**
  String get contentReportSend;

  /// No description provided for @moderationDoHide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get moderationDoHide;

  /// No description provided for @moderationDoRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get moderationDoRemove;

  /// No description provided for @moderationDoRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get moderationDoRestore;

  /// No description provided for @moderationDoPin.
  ///
  /// In en, this message translates to:
  /// **'Pin to the top'**
  String get moderationDoPin;

  /// No description provided for @moderationDoUnpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get moderationDoUnpin;

  /// No description provided for @moderationDoLock.
  ///
  /// In en, this message translates to:
  /// **'Lock comments'**
  String get moderationDoLock;

  /// No description provided for @moderationDoUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock comments'**
  String get moderationDoUnlock;

  /// No description provided for @moderationDoWarn.
  ///
  /// In en, this message translates to:
  /// **'Send a warning'**
  String get moderationDoWarn;

  /// No description provided for @moderationDoRestrict.
  ///
  /// In en, this message translates to:
  /// **'Pause posting'**
  String get moderationDoRestrict;

  /// No description provided for @moderationDoBan.
  ///
  /// In en, this message translates to:
  /// **'Ban from the community'**
  String get moderationDoBan;

  /// No description provided for @moderationDoUnban.
  ///
  /// In en, this message translates to:
  /// **'Lift the ban'**
  String get moderationDoUnban;

  /// No description provided for @moderationDoDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss the report'**
  String get moderationDoDismiss;

  /// No description provided for @moderationDoEscalate.
  ///
  /// In en, this message translates to:
  /// **'Send to Montra staff'**
  String get moderationDoEscalate;

  /// No description provided for @moderationChooseAction.
  ///
  /// In en, this message translates to:
  /// **'Choose an action'**
  String get moderationChooseAction;

  /// No description provided for @moderationDone.
  ///
  /// In en, this message translates to:
  /// **'Done. The action is recorded in the moderation log.'**
  String get moderationDone;

  /// No description provided for @moderationReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get moderationReasonLabel;

  /// No description provided for @moderationNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get moderationNoteLabel;

  /// No description provided for @moderationReasonHelp.
  ///
  /// In en, this message translates to:
  /// **'The person affected sees this reason and can appeal within 30 days.'**
  String get moderationReasonHelp;

  /// No description provided for @moderationDurationLabel.
  ///
  /// In en, this message translates to:
  /// **'For how long'**
  String get moderationDurationLabel;

  /// No description provided for @moderationDuration.
  ///
  /// In en, this message translates to:
  /// **'{span, select, h1{1 hour} d1{1 day} d3{3 days} w1{1 week} d30{30 days} other{{span}}}'**
  String moderationDuration(String span);

  /// No description provided for @communitiesTitle.
  ///
  /// In en, this message translates to:
  /// **'Communities'**
  String get communitiesTitle;

  /// No description provided for @communityJoinWithLink.
  ///
  /// In en, this message translates to:
  /// **'Join with a link'**
  String get communityJoinWithLink;

  /// No description provided for @communitiesTabDiscover.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get communitiesTabDiscover;

  /// No description provided for @communitiesTabYours.
  ///
  /// In en, this message translates to:
  /// **'Yours'**
  String get communitiesTabYours;

  /// No description provided for @communitiesTabInvitations.
  ///
  /// In en, this message translates to:
  /// **'Invitations'**
  String get communitiesTabInvitations;

  /// No description provided for @communityCreate.
  ///
  /// In en, this message translates to:
  /// **'Start a community'**
  String get communityCreate;

  /// No description provided for @communitiesSearchLabel.
  ///
  /// In en, this message translates to:
  /// **'Search communities'**
  String get communitiesSearchLabel;

  /// No description provided for @communitiesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No communities to show yet'**
  String get communitiesEmptyTitle;

  /// No description provided for @communitiesNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No communities match “{query}”.'**
  String communitiesNoMatches(String query);

  /// No description provided for @communitiesEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Communities are places to share money tips and ask questions. You can start one yourself.'**
  String get communitiesEmptyBody;

  /// No description provided for @communitiesYoursEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t joined a community yet'**
  String get communitiesYoursEmptyTitle;

  /// No description provided for @communitiesYoursEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Find one under Discover, or join with an invitation link.'**
  String get communitiesYoursEmptyBody;

  /// No description provided for @communityJoinedDone.
  ///
  /// In en, this message translates to:
  /// **'You joined {name}.'**
  String communityJoinedDone(String name);

  /// No description provided for @communityInvitationDeclineTitle.
  ///
  /// In en, this message translates to:
  /// **'Decline this invitation?'**
  String get communityInvitationDeclineTitle;

  /// No description provided for @communityInvitationDeclineBody.
  ///
  /// In en, this message translates to:
  /// **'You won\'t join {name}. Someone can invite you again later.'**
  String communityInvitationDeclineBody(String name);

  /// No description provided for @communityInvitationDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get communityInvitationDecline;

  /// No description provided for @communityInvitationDeclined.
  ///
  /// In en, this message translates to:
  /// **'Invitation declined.'**
  String get communityInvitationDeclined;

  /// No description provided for @communityUnnamed.
  ///
  /// In en, this message translates to:
  /// **'A community'**
  String get communityUnnamed;

  /// No description provided for @communityInvitationsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No invitations'**
  String get communityInvitationsEmptyTitle;

  /// No description provided for @communityInvitationsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'When someone invites you to a community by your username, it shows up here.'**
  String get communityInvitationsEmptyBody;

  /// No description provided for @communityInvitedBy.
  ///
  /// In en, this message translates to:
  /// **'Invited by {name}'**
  String communityInvitedBy(String name);

  /// No description provided for @communityInvitationExpires.
  ///
  /// In en, this message translates to:
  /// **'Valid until {date}'**
  String communityInvitationExpires(String date);

  /// No description provided for @communityInvitationAccept.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get communityInvitationAccept;

  /// No description provided for @communityMemberCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 member} other{{count} members}}'**
  String communityMemberCount(int count);

  /// No description provided for @communityStatusArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get communityStatusArchived;

  /// No description provided for @communityStatusSuspended.
  ///
  /// In en, this message translates to:
  /// **'Suspended'**
  String get communityStatusSuspended;

  /// No description provided for @communityInvitationStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get communityInvitationStatusActive;

  /// No description provided for @communityInvitationStatusUsed.
  ///
  /// In en, this message translates to:
  /// **'Used'**
  String get communityInvitationStatusUsed;

  /// No description provided for @communityInvitationStatusDeclined.
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get communityInvitationStatusDeclined;

  /// No description provided for @communityInvitationStatusRevoked.
  ///
  /// In en, this message translates to:
  /// **'Revoked'**
  String get communityInvitationStatusRevoked;

  /// No description provided for @communityInvitationStatusExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get communityInvitationStatusExpired;

  /// No description provided for @communityCreated.
  ///
  /// In en, this message translates to:
  /// **'Community created. You are its owner.'**
  String get communityCreated;

  /// No description provided for @communityCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'New community'**
  String get communityCreateTitle;

  /// No description provided for @communityCreateIntro.
  ///
  /// In en, this message translates to:
  /// **'Communities are free. Keep them kind: posts are plain text, and members can report anything unkind.'**
  String get communityCreateIntro;

  /// No description provided for @communityNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get communityNameLabel;

  /// No description provided for @communitySlugLabel.
  ///
  /// In en, this message translates to:
  /// **'URL name (optional)'**
  String get communitySlugLabel;

  /// No description provided for @communitySlugHelp.
  ///
  /// In en, this message translates to:
  /// **'3–60 lowercase letters, digits or dashes. It can\'t change later; without one, it comes from the name.'**
  String get communitySlugHelp;

  /// No description provided for @communitySlugInvalid.
  ///
  /// In en, this message translates to:
  /// **'Use 3–60 lowercase letters, digits or dashes.'**
  String get communitySlugInvalid;

  /// No description provided for @communityDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'What it is about (optional)'**
  String get communityDescriptionLabel;

  /// No description provided for @communityRulesLabel.
  ///
  /// In en, this message translates to:
  /// **'Community rules (optional)'**
  String get communityRulesLabel;

  /// No description provided for @communityRulesHelp.
  ///
  /// In en, this message translates to:
  /// **'Members see these rules before they post.'**
  String get communityRulesHelp;

  /// No description provided for @communityTopicsLabel.
  ///
  /// In en, this message translates to:
  /// **'Topics (optional)'**
  String get communityTopicsLabel;

  /// No description provided for @communityTopicsHelp.
  ///
  /// In en, this message translates to:
  /// **'Separate topics with commas, for example: saving, budgeting'**
  String get communityTopicsHelp;

  /// No description provided for @communityVisibilityLabel.
  ///
  /// In en, this message translates to:
  /// **'Who can join'**
  String get communityVisibilityLabel;

  /// No description provided for @communityJoinLinkInvalid.
  ///
  /// In en, this message translates to:
  /// **'This isn\'t a community invitation link or code.'**
  String get communityJoinLinkInvalid;

  /// No description provided for @communityJoinTitle.
  ///
  /// In en, this message translates to:
  /// **'Join a community'**
  String get communityJoinTitle;

  /// No description provided for @communityJoinIntro.
  ///
  /// In en, this message translates to:
  /// **'Paste the invitation link or code you received. You\'ll see which community it is before joining.'**
  String get communityJoinIntro;

  /// No description provided for @communityJoinLinkLabel.
  ///
  /// In en, this message translates to:
  /// **'Invitation link or code'**
  String get communityJoinLinkLabel;

  /// No description provided for @communityJoinCheck.
  ///
  /// In en, this message translates to:
  /// **'Check the invitation'**
  String get communityJoinCheck;

  /// No description provided for @communityJoinFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t use this invitation'**
  String get communityJoinFailedTitle;

  /// No description provided for @communityJoinLinkGone.
  ///
  /// In en, this message translates to:
  /// **'This invitation no longer works: it was used, revoked or has expired. Ask for a new one.'**
  String get communityJoinLinkGone;

  /// No description provided for @communityOpen.
  ///
  /// In en, this message translates to:
  /// **'Open the community'**
  String get communityOpen;

  /// No description provided for @communityJoinLinkNotActive.
  ///
  /// In en, this message translates to:
  /// **'This invitation can\'t be used: {status}.'**
  String communityJoinLinkNotActive(String status);

  /// No description provided for @communityJoinDirectly.
  ///
  /// In en, this message translates to:
  /// **'This invitation lets you join directly.'**
  String get communityJoinDirectly;

  /// No description provided for @communityJoin.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get communityJoin;

  /// No description provided for @postNew.
  ///
  /// In en, this message translates to:
  /// **'New post'**
  String get postNew;

  /// No description provided for @communityLeaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave {name}?'**
  String communityLeaveTitle(String name);

  /// No description provided for @communityLeaveBody.
  ///
  /// In en, this message translates to:
  /// **'Your posts and comments stay. You can join again later if the community allows it.'**
  String get communityLeaveBody;

  /// No description provided for @communityLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave community'**
  String get communityLeave;

  /// No description provided for @communityLeftDone.
  ///
  /// In en, this message translates to:
  /// **'You left the community.'**
  String get communityLeftDone;

  /// No description provided for @communityMembersTitle.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get communityMembersTitle;

  /// No description provided for @communitySettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Community settings'**
  String get communitySettingsTitle;

  /// No description provided for @communityModerationTitle.
  ///
  /// In en, this message translates to:
  /// **'Moderation'**
  String get communityModerationTitle;

  /// No description provided for @communityStartChallenge.
  ///
  /// In en, this message translates to:
  /// **'Start a challenge here'**
  String get communityStartChallenge;

  /// No description provided for @communityReport.
  ///
  /// In en, this message translates to:
  /// **'Report community'**
  String get communityReport;

  /// No description provided for @communityJoinRequested.
  ///
  /// In en, this message translates to:
  /// **'Request sent. Moderators will review it.'**
  String get communityJoinRequested;

  /// No description provided for @communityFeedMembersOnly.
  ///
  /// In en, this message translates to:
  /// **'Only members see the posts in this community.'**
  String get communityFeedMembersOnly;

  /// No description provided for @communityFeedEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No posts yet'**
  String get communityFeedEmptyTitle;

  /// No description provided for @communityFeedNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No posts match “{query}”.'**
  String communityFeedNoMatches(String query);

  /// No description provided for @communityFeedEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Start the conversation with a question or a tip.'**
  String get communityFeedEmptyBody;

  /// No description provided for @communityStaffModerates.
  ///
  /// In en, this message translates to:
  /// **'Montra staff'**
  String get communityStaffModerates;

  /// No description provided for @communityTopicsLine.
  ///
  /// In en, this message translates to:
  /// **'Topics: {topics}'**
  String communityTopicsLine(String topics);

  /// No description provided for @communityRulesTitle.
  ///
  /// In en, this message translates to:
  /// **'Community rules'**
  String get communityRulesTitle;

  /// No description provided for @communityArchivedNote.
  ///
  /// In en, this message translates to:
  /// **'This community is archived. You can read it, but nothing new can be posted.'**
  String get communityArchivedNote;

  /// No description provided for @communityPendingNote.
  ///
  /// In en, this message translates to:
  /// **'Your request to join is waiting for a moderator.'**
  String get communityPendingNote;

  /// No description provided for @communityBannedNote.
  ///
  /// In en, this message translates to:
  /// **'You can\'t take part in this community.'**
  String get communityBannedNote;

  /// No description provided for @communityAskToJoinHelp.
  ///
  /// In en, this message translates to:
  /// **'Moderators approve who joins this community.'**
  String get communityAskToJoinHelp;

  /// No description provided for @communityAskToJoin.
  ///
  /// In en, this message translates to:
  /// **'Ask to join'**
  String get communityAskToJoin;

  /// No description provided for @communityFeedTitle.
  ///
  /// In en, this message translates to:
  /// **'Posts'**
  String get communityFeedTitle;

  /// No description provided for @communityFeedSortNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get communityFeedSortNew;

  /// No description provided for @communityFeedSortTop.
  ///
  /// In en, this message translates to:
  /// **'Top'**
  String get communityFeedSortTop;

  /// No description provided for @communityFeedSortActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get communityFeedSortActive;

  /// No description provided for @communityFeedSearchLabel.
  ///
  /// In en, this message translates to:
  /// **'Search posts'**
  String get communityFeedSearchLabel;

  /// No description provided for @postCommentCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No comments} =1{1 comment} other{{count} comments}}'**
  String postCommentCount(int count);

  /// No description provided for @postPinned.
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get postPinned;

  /// No description provided for @postLocked.
  ///
  /// In en, this message translates to:
  /// **'Comments closed'**
  String get postLocked;

  /// No description provided for @postHidden.
  ///
  /// In en, this message translates to:
  /// **'Hidden by a moderator'**
  String get postHidden;

  /// No description provided for @postRemoved.
  ///
  /// In en, this message translates to:
  /// **'Removed by a moderator'**
  String get postRemoved;

  /// No description provided for @postDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get postDeleted;

  /// No description provided for @postEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit post'**
  String get postEditTitle;

  /// No description provided for @postSaved.
  ///
  /// In en, this message translates to:
  /// **'Post saved.'**
  String get postSaved;

  /// No description provided for @postPublished.
  ///
  /// In en, this message translates to:
  /// **'Post published.'**
  String get postPublished;

  /// No description provided for @postComposerIntro.
  ///
  /// In en, this message translates to:
  /// **'Posts are plain text. Never share card numbers, PINs, one-time codes or passwords.'**
  String get postComposerIntro;

  /// No description provided for @postKindHeading.
  ///
  /// In en, this message translates to:
  /// **'Kind of post'**
  String get postKindHeading;

  /// No description provided for @postLabelHeading.
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get postLabelHeading;

  /// No description provided for @postTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get postTitleLabel;

  /// No description provided for @postBodyLabel.
  ///
  /// In en, this message translates to:
  /// **'Text (optional)'**
  String get postBodyLabel;

  /// No description provided for @postBodyHelp.
  ///
  /// In en, this message translates to:
  /// **'Shown exactly as you type it.'**
  String get postBodyHelp;

  /// No description provided for @postLinkLabel.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get postLinkLabel;

  /// No description provided for @postLinkHelp.
  ///
  /// In en, this message translates to:
  /// **'A public web link starting with https://'**
  String get postLinkHelp;

  /// No description provided for @postPollFixed.
  ///
  /// In en, this message translates to:
  /// **'A poll\'s question and options can\'t change after posting.'**
  String get postPollFixed;

  /// No description provided for @postPublish.
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get postPublish;

  /// No description provided for @postPollTitle.
  ///
  /// In en, this message translates to:
  /// **'Poll'**
  String get postPollTitle;

  /// No description provided for @postPollQuestionLabel.
  ///
  /// In en, this message translates to:
  /// **'Question'**
  String get postPollQuestionLabel;

  /// No description provided for @postPollOptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Option {number}'**
  String postPollOptionLabel(int number);

  /// No description provided for @postPollRemoveOption.
  ///
  /// In en, this message translates to:
  /// **'Remove option {number}'**
  String postPollRemoveOption(int number);

  /// No description provided for @postPollAddOption.
  ///
  /// In en, this message translates to:
  /// **'Add an option'**
  String get postPollAddOption;

  /// No description provided for @postPollAllowMultiple.
  ///
  /// In en, this message translates to:
  /// **'People can choose more than one'**
  String get postPollAllowMultiple;

  /// No description provided for @postPollClosesLabel.
  ///
  /// In en, this message translates to:
  /// **'Closes on'**
  String get postPollClosesLabel;

  /// No description provided for @postPollNoEnd.
  ///
  /// In en, this message translates to:
  /// **'Stays open'**
  String get postPollNoEnd;

  /// No description provided for @postTitle.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get postTitle;

  /// No description provided for @postDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this post?'**
  String get postDeleteTitle;

  /// No description provided for @postDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'It disappears for everyone, with its comments. This can\'t be undone.'**
  String get postDeleteBody;

  /// No description provided for @postDeletedDone.
  ///
  /// In en, this message translates to:
  /// **'Post deleted.'**
  String get postDeletedDone;

  /// No description provided for @postOpenCommunity.
  ///
  /// In en, this message translates to:
  /// **'Open the community'**
  String get postOpenCommunity;

  /// No description provided for @moderationModerate.
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get moderationModerate;

  /// No description provided for @commentPosted.
  ///
  /// In en, this message translates to:
  /// **'Comment posted.'**
  String get commentPosted;

  /// No description provided for @postRemovedReason.
  ///
  /// In en, this message translates to:
  /// **'Reason given by the moderator: {reason}'**
  String postRemovedReason(String reason);

  /// No description provided for @postOpenLink.
  ///
  /// In en, this message translates to:
  /// **'Open link ({host})'**
  String postOpenLink(String host);

  /// No description provided for @commentsTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Comments} =1{1 comment} other{{count} comments}}'**
  String commentsTitle(int count);

  /// No description provided for @commentJoinToComment.
  ///
  /// In en, this message translates to:
  /// **'Join the community to comment.'**
  String get commentJoinToComment;

  /// No description provided for @commentsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No comments yet.'**
  String get commentsEmpty;

  /// No description provided for @commentReplyingTo.
  ///
  /// In en, this message translates to:
  /// **'Replying to {name}'**
  String commentReplyingTo(String name);

  /// No description provided for @commentCancelReply.
  ///
  /// In en, this message translates to:
  /// **'Cancel reply'**
  String get commentCancelReply;

  /// No description provided for @commentAddLabel.
  ///
  /// In en, this message translates to:
  /// **'Your comment'**
  String get commentAddLabel;

  /// No description provided for @commentReplyLabel.
  ///
  /// In en, this message translates to:
  /// **'Your reply'**
  String get commentReplyLabel;

  /// No description provided for @commentPlainTextHelp.
  ///
  /// In en, this message translates to:
  /// **'Plain text. Be kind.'**
  String get commentPlainTextHelp;

  /// No description provided for @commentSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get commentSend;

  /// No description provided for @commentSaved.
  ///
  /// In en, this message translates to:
  /// **'Comment saved.'**
  String get commentSaved;

  /// No description provided for @commentDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this comment?'**
  String get commentDeleteTitle;

  /// No description provided for @commentDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Replies to it stay. This can\'t be undone.'**
  String get commentDeleteBody;

  /// No description provided for @commentDeletedDone.
  ///
  /// In en, this message translates to:
  /// **'Comment deleted.'**
  String get commentDeletedDone;

  /// No description provided for @commentActions.
  ///
  /// In en, this message translates to:
  /// **'Comment options'**
  String get commentActions;

  /// No description provided for @commentHiddenLabel.
  ///
  /// In en, this message translates to:
  /// **'Hidden by a moderator; only you and moderators see it'**
  String get commentHiddenLabel;

  /// No description provided for @commentDeletedText.
  ///
  /// In en, this message translates to:
  /// **'This comment was deleted.'**
  String get commentDeletedText;

  /// No description provided for @commentRemovedText.
  ///
  /// In en, this message translates to:
  /// **'This comment was removed by a moderator.'**
  String get commentRemovedText;

  /// No description provided for @commentReply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get commentReply;

  /// No description provided for @commentEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit comment'**
  String get commentEditTitle;

  /// No description provided for @communitySettingsModeratorsOnly.
  ///
  /// In en, this message translates to:
  /// **'Only the owner and moderators can manage this community.'**
  String get communitySettingsModeratorsOnly;

  /// No description provided for @communityMembersSettingsHelp.
  ///
  /// In en, this message translates to:
  /// **'Approve requests, change roles, warn or ban.'**
  String get communityMembersSettingsHelp;

  /// No description provided for @communityModerationSettingsHelp.
  ///
  /// In en, this message translates to:
  /// **'Reports, appeals and the moderation log.'**
  String get communityModerationSettingsHelp;

  /// No description provided for @communityNothingChanged.
  ///
  /// In en, this message translates to:
  /// **'Nothing changed, so there was nothing to save.'**
  String get communityNothingChanged;

  /// No description provided for @communitySaved.
  ///
  /// In en, this message translates to:
  /// **'Community saved.'**
  String get communitySaved;

  /// No description provided for @communityDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get communityDetailsTitle;

  /// No description provided for @communityVisibilityOwnerOnly.
  ///
  /// In en, this message translates to:
  /// **'Only the owner can change who can join.'**
  String get communityVisibilityOwnerOnly;

  /// No description provided for @communityInviteLinkExpiresTitle.
  ///
  /// In en, this message translates to:
  /// **'How long should the link work?'**
  String get communityInviteLinkExpiresTitle;

  /// No description provided for @communityInviteLinkDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String communityInviteLinkDays(int count);

  /// No description provided for @communityInviteSent.
  ///
  /// In en, this message translates to:
  /// **'Invitation sent to @{username}.'**
  String communityInviteSent(String username);

  /// No description provided for @communityInviteUserNotFound.
  ///
  /// In en, this message translates to:
  /// **'No one with this username can be invited. People are found by their exact username once they allow it.'**
  String get communityInviteUserNotFound;

  /// No description provided for @communityInviteRevokeTitle.
  ///
  /// In en, this message translates to:
  /// **'Revoke this invitation?'**
  String get communityInviteRevokeTitle;

  /// No description provided for @communityInviteRevokeBody.
  ///
  /// In en, this message translates to:
  /// **'It stops working right away. People who already joined stay members.'**
  String get communityInviteRevokeBody;

  /// No description provided for @communityInviteRevoke.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get communityInviteRevoke;

  /// No description provided for @communityInviteRevoked.
  ///
  /// In en, this message translates to:
  /// **'Invitation revoked.'**
  String get communityInviteRevoked;

  /// No description provided for @communityInvitationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Invitations'**
  String get communityInvitationsTitle;

  /// No description provided for @communityInvitationsHelp.
  ///
  /// In en, this message translates to:
  /// **'Invited people join directly, even when moderators approve members.'**
  String get communityInvitationsHelp;

  /// No description provided for @communityInviteCreateLink.
  ///
  /// In en, this message translates to:
  /// **'Create an invitation link'**
  String get communityInviteCreateLink;

  /// No description provided for @communityInviteUsernameLabel.
  ///
  /// In en, this message translates to:
  /// **'Invite by username'**
  String get communityInviteUsernameLabel;

  /// No description provided for @communityInviteUsernameHelp.
  ///
  /// In en, this message translates to:
  /// **'Their exact username. They accept or decline in the app.'**
  String get communityInviteUsernameHelp;

  /// No description provided for @communityInviteSend.
  ///
  /// In en, this message translates to:
  /// **'Send invitation'**
  String get communityInviteSend;

  /// No description provided for @communityInvitationsShowInactive.
  ///
  /// In en, this message translates to:
  /// **'Show used, declined, revoked and expired'**
  String get communityInvitationsShowInactive;

  /// No description provided for @communityInvitationsNone.
  ///
  /// In en, this message translates to:
  /// **'No invitations here.'**
  String get communityInvitationsNone;

  /// No description provided for @communityInviteKindLink.
  ///
  /// In en, this message translates to:
  /// **'Invitation link'**
  String get communityInviteKindLink;

  /// No description provided for @communityInviteKindPerson.
  ///
  /// In en, this message translates to:
  /// **'Invitation for {name}'**
  String communityInviteKindPerson(String name);

  /// No description provided for @communityInviteLinkTitle.
  ///
  /// In en, this message translates to:
  /// **'Your invitation'**
  String get communityInviteLinkTitle;

  /// No description provided for @communityInviteCodeIntro.
  ///
  /// In en, this message translates to:
  /// **'Share this code. People open Communities, choose “Join with a link” and paste it. It\'s shown only once.'**
  String get communityInviteCodeIntro;

  /// No description provided for @communityInviteLinkIntro.
  ///
  /// In en, this message translates to:
  /// **'Share this link with the people you want to invite. It\'s shown only once.'**
  String get communityInviteLinkIntro;

  /// No description provided for @communityInviteShareCode.
  ///
  /// In en, this message translates to:
  /// **'Join my community on Montra: open Communities, choose “Join with a link” and paste this code: {code}'**
  String communityInviteShareCode(String code);

  /// No description provided for @communityInviteShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get communityInviteShare;

  /// No description provided for @communityTransferNobody.
  ///
  /// In en, this message translates to:
  /// **'There is no other member to hand the community to yet.'**
  String get communityTransferNobody;

  /// No description provided for @communityTransferChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose the new owner'**
  String get communityTransferChoose;

  /// No description provided for @communityTransferTitle.
  ///
  /// In en, this message translates to:
  /// **'Make {name} the owner?'**
  String communityTransferTitle(String name);

  /// No description provided for @communityTransferBody.
  ///
  /// In en, this message translates to:
  /// **'{name} will own the community and you become a moderator. Only the new owner can give it back.'**
  String communityTransferBody(String name);

  /// No description provided for @communityTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer ownership'**
  String get communityTransfer;

  /// No description provided for @communityTransferredDone.
  ///
  /// In en, this message translates to:
  /// **'{name} now owns the community.'**
  String communityTransferredDone(String name);

  /// No description provided for @communityRestoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore this community?'**
  String get communityRestoreTitle;

  /// No description provided for @communityArchiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Archive this community?'**
  String get communityArchiveTitle;

  /// No description provided for @communityRestoreBody.
  ///
  /// In en, this message translates to:
  /// **'Members can post and comment again.'**
  String get communityRestoreBody;

  /// No description provided for @communityArchiveBody.
  ///
  /// In en, this message translates to:
  /// **'It becomes read-only: nothing new can be posted, and no one new can join. You can restore it later.'**
  String get communityArchiveBody;

  /// No description provided for @communityArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get communityArchive;

  /// No description provided for @communityRestoredDone.
  ///
  /// In en, this message translates to:
  /// **'Community restored.'**
  String get communityRestoredDone;

  /// No description provided for @communityArchivedDone.
  ///
  /// In en, this message translates to:
  /// **'Community archived.'**
  String get communityArchivedDone;

  /// No description provided for @communityOwnerSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Ownership'**
  String get communityOwnerSectionTitle;

  /// No description provided for @communityRestoreHelp.
  ///
  /// In en, this message translates to:
  /// **'Restoring lets members post again.'**
  String get communityRestoreHelp;

  /// No description provided for @communityArchiveHelp.
  ///
  /// In en, this message translates to:
  /// **'Archiving keeps everything readable but stops new posts.'**
  String get communityArchiveHelp;

  /// No description provided for @communityMembersFilterActive.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get communityMembersFilterActive;

  /// No description provided for @communityMembersFilterPending.
  ///
  /// In en, this message translates to:
  /// **'Waiting for approval'**
  String get communityMembersFilterPending;

  /// No description provided for @communityMembersFilterBanned.
  ///
  /// In en, this message translates to:
  /// **'Banned'**
  String get communityMembersFilterBanned;

  /// No description provided for @communityMembersModeratorsOnlyNote.
  ///
  /// In en, this message translates to:
  /// **'These people moderate this community.'**
  String get communityMembersModeratorsOnlyNote;

  /// No description provided for @communityMembersNoRequests.
  ///
  /// In en, this message translates to:
  /// **'No one is waiting to join.'**
  String get communityMembersNoRequests;

  /// No description provided for @communityMembersEmpty.
  ///
  /// In en, this message translates to:
  /// **'No one here.'**
  String get communityMembersEmpty;

  /// No description provided for @communityMemberYou.
  ///
  /// In en, this message translates to:
  /// **'{name} (you)'**
  String communityMemberYou(String name);

  /// No description provided for @communityMemberRestrictedUntil.
  ///
  /// In en, this message translates to:
  /// **'Posting paused until {date}'**
  String communityMemberRestrictedUntil(String date);

  /// No description provided for @communityMemberApproved.
  ///
  /// In en, this message translates to:
  /// **'{name} is now a member.'**
  String communityMemberApproved(String name);

  /// No description provided for @communityMemberApprove.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get communityMemberApprove;

  /// No description provided for @communityMemberRejected.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s request was declined.'**
  String communityMemberRejected(String name);

  /// No description provided for @communityMemberReject.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get communityMemberReject;

  /// No description provided for @communityMemberActions.
  ///
  /// In en, this message translates to:
  /// **'Options for {name}'**
  String communityMemberActions(String name);

  /// No description provided for @communityMemberNowModerator.
  ///
  /// In en, this message translates to:
  /// **'{name} is now a moderator.'**
  String communityMemberNowModerator(String name);

  /// No description provided for @communityMemberNowMember.
  ///
  /// In en, this message translates to:
  /// **'{name} is now a member.'**
  String communityMemberNowMember(String name);

  /// No description provided for @communityMemberMakeModerator.
  ///
  /// In en, this message translates to:
  /// **'Make moderator'**
  String get communityMemberMakeModerator;

  /// No description provided for @communityMemberMakeMember.
  ///
  /// In en, this message translates to:
  /// **'Make a regular member'**
  String get communityMemberMakeMember;

  /// No description provided for @moderationTabReports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get moderationTabReports;

  /// No description provided for @moderationTabAppeals.
  ///
  /// In en, this message translates to:
  /// **'Appeals'**
  String get moderationTabAppeals;

  /// No description provided for @moderationTabLog.
  ///
  /// In en, this message translates to:
  /// **'Log'**
  String get moderationTabLog;

  /// No description provided for @moderationReportsEmptyOpen.
  ///
  /// In en, this message translates to:
  /// **'No reports waiting. Thank you for keeping things kind.'**
  String get moderationReportsEmptyOpen;

  /// No description provided for @moderationReportsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No reports here.'**
  String get moderationReportsEmpty;

  /// No description provided for @moderationReportHeadline.
  ///
  /// In en, this message translates to:
  /// **'{target} · {reason}'**
  String moderationReportHeadline(String target, String reason);

  /// No description provided for @moderationReportPreview.
  ///
  /// In en, this message translates to:
  /// **'Reported text: {text}'**
  String moderationReportPreview(String text);

  /// No description provided for @moderationReportDetails.
  ///
  /// In en, this message translates to:
  /// **'Reporter wrote: {text}'**
  String moderationReportDetails(String text);

  /// No description provided for @moderationOpenReports.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No other open reports} =1{1 open report on this} other{{count} open reports on this}}'**
  String moderationOpenReports(int count);

  /// No description provided for @moderationOpenPost.
  ///
  /// In en, this message translates to:
  /// **'Open the post'**
  String get moderationOpenPost;

  /// No description provided for @moderationActOnContent.
  ///
  /// In en, this message translates to:
  /// **'Act on the content'**
  String get moderationActOnContent;

  /// No description provided for @moderationActOnAuthor.
  ///
  /// In en, this message translates to:
  /// **'Act on the author'**
  String get moderationActOnAuthor;

  /// No description provided for @moderationUpholdTitle.
  ///
  /// In en, this message translates to:
  /// **'Keep the decision?'**
  String get moderationUpholdTitle;

  /// No description provided for @moderationOverturnTitle.
  ///
  /// In en, this message translates to:
  /// **'Reverse the decision?'**
  String get moderationOverturnTitle;

  /// No description provided for @moderationUpholdBody.
  ///
  /// In en, this message translates to:
  /// **'The decision stands. The person is told, with your note if you add one.'**
  String get moderationUpholdBody;

  /// No description provided for @moderationOverturnBody.
  ///
  /// In en, this message translates to:
  /// **'The action is reversed. The person is told, with your note if you add one.'**
  String get moderationOverturnBody;

  /// No description provided for @moderationUphold.
  ///
  /// In en, this message translates to:
  /// **'Keep decision'**
  String get moderationUphold;

  /// No description provided for @moderationOverturn.
  ///
  /// In en, this message translates to:
  /// **'Reverse decision'**
  String get moderationOverturn;

  /// No description provided for @moderationAppealDecided.
  ///
  /// In en, this message translates to:
  /// **'Appeal decided. The person has been told.'**
  String get moderationAppealDecided;

  /// No description provided for @moderationAppealsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No open appeals.'**
  String get moderationAppealsEmpty;

  /// No description provided for @moderationAppealAgainst.
  ///
  /// In en, this message translates to:
  /// **'Appeal against: {action} ({target})'**
  String moderationAppealAgainst(String action, String target);

  /// No description provided for @moderationDecisionReason.
  ///
  /// In en, this message translates to:
  /// **'Reason: {reason}'**
  String moderationDecisionReason(String reason);

  /// No description provided for @moderationAppealStatement.
  ///
  /// In en, this message translates to:
  /// **'Appeal: {text}'**
  String moderationAppealStatement(String text);

  /// No description provided for @moderationReverseTitle.
  ///
  /// In en, this message translates to:
  /// **'Reverse this action?'**
  String get moderationReverseTitle;

  /// No description provided for @moderationReverseBody.
  ///
  /// In en, this message translates to:
  /// **'The action is undone. It stays in the log as reversed.'**
  String get moderationReverseBody;

  /// No description provided for @moderationReverse.
  ///
  /// In en, this message translates to:
  /// **'Reverse'**
  String get moderationReverse;

  /// No description provided for @moderationReversed.
  ///
  /// In en, this message translates to:
  /// **'Action reversed.'**
  String get moderationReversed;

  /// No description provided for @moderationLogEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing in the log yet.'**
  String get moderationLogEmpty;

  /// No description provided for @moderationLogLine.
  ///
  /// In en, this message translates to:
  /// **'{action} · {target}'**
  String moderationLogLine(String action, String target);

  /// No description provided for @moderationUntil.
  ///
  /// In en, this message translates to:
  /// **'Until {date}'**
  String moderationUntil(String date);

  /// No description provided for @moderationReversedAt.
  ///
  /// In en, this message translates to:
  /// **'Reversed on {date}'**
  String moderationReversedAt(String date);

  /// No description provided for @myModerationTitle.
  ///
  /// In en, this message translates to:
  /// **'Moderation and reports'**
  String get myModerationTitle;

  /// No description provided for @myModerationTabDecisions.
  ///
  /// In en, this message translates to:
  /// **'About you'**
  String get myModerationTabDecisions;

  /// No description provided for @myModerationTabAppeals.
  ///
  /// In en, this message translates to:
  /// **'Your appeals'**
  String get myModerationTabAppeals;

  /// No description provided for @myModerationTabReports.
  ///
  /// In en, this message translates to:
  /// **'Your reports'**
  String get myModerationTabReports;

  /// No description provided for @myModerationDecisionsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing here'**
  String get myModerationDecisionsEmptyTitle;

  /// No description provided for @myModerationDecisionsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'No moderator has acted on your posts, comments or membership.'**
  String get myModerationDecisionsEmptyBody;

  /// No description provided for @myModerationIntro.
  ///
  /// In en, this message translates to:
  /// **'Decisions moderators made about your content or membership. You can appeal within 30 days; another moderator reviews it.'**
  String get myModerationIntro;

  /// No description provided for @appealSent.
  ///
  /// In en, this message translates to:
  /// **'Appeal sent. You will be told the outcome.'**
  String get appealSent;

  /// No description provided for @appealAlreadySent.
  ///
  /// In en, this message translates to:
  /// **'You already appealed this decision.'**
  String get appealAlreadySent;

  /// No description provided for @myModerationByStaff.
  ///
  /// In en, this message translates to:
  /// **'Decided by Montra staff'**
  String get myModerationByStaff;

  /// No description provided for @myModerationEnded.
  ///
  /// In en, this message translates to:
  /// **'Ended on {date}'**
  String myModerationEnded(String date);

  /// No description provided for @appealDecisionNote.
  ///
  /// In en, this message translates to:
  /// **'Note from the reviewer: {note}'**
  String appealDecisionNote(String note);

  /// No description provided for @appealDecidedOn.
  ///
  /// In en, this message translates to:
  /// **'Decided on {date}'**
  String appealDecidedOn(String date);

  /// No description provided for @appealWindow.
  ///
  /// In en, this message translates to:
  /// **'You can appeal until {date}.'**
  String appealWindow(String date);

  /// No description provided for @appealAction.
  ///
  /// In en, this message translates to:
  /// **'Appeal'**
  String get appealAction;

  /// No description provided for @appealTitle.
  ///
  /// In en, this message translates to:
  /// **'Appeal this decision'**
  String get appealTitle;

  /// No description provided for @appealIntro.
  ///
  /// In en, this message translates to:
  /// **'Explain why you think the decision should change. A moderator who did not make it will review your appeal.'**
  String get appealIntro;

  /// No description provided for @appealStatementLabel.
  ///
  /// In en, this message translates to:
  /// **'Your appeal'**
  String get appealStatementLabel;

  /// No description provided for @appealSend.
  ///
  /// In en, this message translates to:
  /// **'Send appeal'**
  String get appealSend;

  /// No description provided for @myModerationAppealsEmpty.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t made any appeals.'**
  String get myModerationAppealsEmpty;

  /// No description provided for @appealSentOn.
  ///
  /// In en, this message translates to:
  /// **'Sent on {date}'**
  String appealSentOn(String date);

  /// No description provided for @myModerationReportsEmpty.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t reported anything.'**
  String get myModerationReportsEmpty;

  /// No description provided for @challengesTitle.
  ///
  /// In en, this message translates to:
  /// **'Challenges'**
  String get challengesTitle;

  /// No description provided for @challengesTabMine.
  ///
  /// In en, this message translates to:
  /// **'Yours'**
  String get challengesTabMine;

  /// No description provided for @challengesTabDiscover.
  ///
  /// In en, this message translates to:
  /// **'Join one'**
  String get challengesTabDiscover;

  /// No description provided for @challengeCreate.
  ///
  /// In en, this message translates to:
  /// **'Start a challenge'**
  String get challengeCreate;

  /// No description provided for @challengesMineEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No challenges yet'**
  String get challengesMineEmptyTitle;

  /// No description provided for @challengesMineEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Start one for yourself, a group or a community, or join one.'**
  String get challengesMineEmptyBody;

  /// No description provided for @challengesDiscoverEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing to join right now'**
  String get challengesDiscoverEmptyTitle;

  /// No description provided for @challengesDiscoverEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Challenges from your groups and communities show up here.'**
  String get challengesDiscoverEmptyBody;

  /// No description provided for @challengeParticipants.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No one has joined yet} =1{1 taking part} other{{count} taking part}}'**
  String challengeParticipants(int count);

  /// No description provided for @challengeYourProgress.
  ///
  /// In en, this message translates to:
  /// **'{percent} % done'**
  String challengeYourProgress(int percent);

  /// No description provided for @challengeCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'New challenge'**
  String get challengeCreateTitle;

  /// No description provided for @challengeEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit challenge'**
  String get challengeEditTitle;

  /// No description provided for @challengePickCommunity.
  ///
  /// In en, this message translates to:
  /// **'Choose a community'**
  String get challengePickCommunity;

  /// No description provided for @challengePickCommunityEmpty.
  ///
  /// In en, this message translates to:
  /// **'You aren\'t a member of a community yet.'**
  String get challengePickCommunityEmpty;

  /// No description provided for @challengeScopeRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose where the challenge runs.'**
  String get challengeScopeRequired;

  /// No description provided for @challengeCreated.
  ///
  /// In en, this message translates to:
  /// **'Challenge started.'**
  String get challengeCreated;

  /// No description provided for @challengeCreateIntro.
  ///
  /// In en, this message translates to:
  /// **'A friendly goal with daily check-ins. Progress stays private unless each person chooses to share it.'**
  String get challengeCreateIntro;

  /// No description provided for @challengeTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get challengeTitleLabel;

  /// No description provided for @challengeTypeHeading.
  ///
  /// In en, this message translates to:
  /// **'Kind'**
  String get challengeTypeHeading;

  /// No description provided for @challengeMetricHeading.
  ///
  /// In en, this message translates to:
  /// **'How progress counts'**
  String get challengeMetricHeading;

  /// No description provided for @challengeTargetLabel.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get challengeTargetLabel;

  /// No description provided for @challengeTargetPercentHelp.
  ///
  /// In en, this message translates to:
  /// **'Use a whole number from 1 to 100.'**
  String get challengeTargetPercentHelp;

  /// No description provided for @challengeTargetInvalid.
  ///
  /// In en, this message translates to:
  /// **'Use a whole number of at least 1.'**
  String get challengeTargetInvalid;

  /// No description provided for @challengeStartsLabel.
  ///
  /// In en, this message translates to:
  /// **'Starts on'**
  String get challengeStartsLabel;

  /// No description provided for @challengeEndsLabel.
  ///
  /// In en, this message translates to:
  /// **'Ends on'**
  String get challengeEndsLabel;

  /// No description provided for @challengeEndsHelp.
  ///
  /// In en, this message translates to:
  /// **'At most a year after the start.'**
  String get challengeEndsHelp;

  /// No description provided for @challengeScopeHeading.
  ///
  /// In en, this message translates to:
  /// **'Who it is for'**
  String get challengeScopeHeading;

  /// No description provided for @challengeGroupLabel.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get challengeGroupLabel;

  /// No description provided for @challengeGroupChosen.
  ///
  /// In en, this message translates to:
  /// **'Chosen group'**
  String get challengeGroupChosen;

  /// No description provided for @challengeCommunityLabel.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get challengeCommunityLabel;

  /// No description provided for @challengeCommunityChosen.
  ///
  /// In en, this message translates to:
  /// **'Chosen community'**
  String get challengeCommunityChosen;

  /// No description provided for @challengeLeaderboardLabel.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard'**
  String get challengeLeaderboardLabel;

  /// No description provided for @challengeLeaderboardHelp.
  ///
  /// In en, this message translates to:
  /// **'Only people who choose to appear are on it, as percentages, never amounts.'**
  String get challengeLeaderboardHelp;

  /// No description provided for @challengePrivateNoLeaderboard.
  ///
  /// In en, this message translates to:
  /// **'A challenge just for you has no leaderboard.'**
  String get challengePrivateNoLeaderboard;

  /// No description provided for @challengeDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get challengeDescriptionLabel;

  /// No description provided for @challengeRulesLabel.
  ///
  /// In en, this message translates to:
  /// **'Rules (optional)'**
  String get challengeRulesLabel;

  /// No description provided for @challengeNothingChanged.
  ///
  /// In en, this message translates to:
  /// **'Nothing changed, so there was nothing to save.'**
  String get challengeNothingChanged;

  /// No description provided for @challengeSaved.
  ///
  /// In en, this message translates to:
  /// **'Challenge saved.'**
  String get challengeSaved;

  /// No description provided for @challengeEditIntro.
  ///
  /// In en, this message translates to:
  /// **'You can change the title, description, rules and leaderboard, and move the end date later.'**
  String get challengeEditIntro;

  /// No description provided for @challengeEndsLaterHelp.
  ///
  /// In en, this message translates to:
  /// **'The end date can only move later, within a year of the start.'**
  String get challengeEndsLaterHelp;

  /// No description provided for @challengeCancelTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel this challenge?'**
  String get challengeCancelTitle;

  /// No description provided for @challengeCancelBody.
  ///
  /// In en, this message translates to:
  /// **'No one can check in any more. This can\'t be undone.'**
  String get challengeCancelBody;

  /// No description provided for @challengeCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel challenge'**
  String get challengeCancel;

  /// No description provided for @challengeCancelledDone.
  ///
  /// In en, this message translates to:
  /// **'Challenge cancelled.'**
  String get challengeCancelledDone;

  /// No description provided for @challengeNotOpenNote.
  ///
  /// In en, this message translates to:
  /// **'This challenge isn\'t taking new participants.'**
  String get challengeNotOpenNote;

  /// No description provided for @challengeGoalLabel.
  ///
  /// In en, this message translates to:
  /// **'Goal'**
  String get challengeGoalLabel;

  /// No description provided for @challengeDatesLabel.
  ///
  /// In en, this message translates to:
  /// **'Dates'**
  String get challengeDatesLabel;

  /// No description provided for @challengeParticipantsLabel.
  ///
  /// In en, this message translates to:
  /// **'Taking part'**
  String get challengeParticipantsLabel;

  /// No description provided for @challengeJoinedDone.
  ///
  /// In en, this message translates to:
  /// **'You joined the challenge. Good luck!'**
  String get challengeJoinedDone;

  /// No description provided for @challengeJoinTitle.
  ///
  /// In en, this message translates to:
  /// **'Join this challenge'**
  String get challengeJoinTitle;

  /// No description provided for @challengePrivacyNote.
  ///
  /// In en, this message translates to:
  /// **'Your check-ins and notes are private. Others see your progress only if you share it.'**
  String get challengePrivacyNote;

  /// No description provided for @challengeShareProgress.
  ///
  /// In en, this message translates to:
  /// **'Share my progress'**
  String get challengeShareProgress;

  /// No description provided for @challengeShareProgressHelp.
  ///
  /// In en, this message translates to:
  /// **'People in the challenge see how far you are, as a percentage.'**
  String get challengeShareProgressHelp;

  /// No description provided for @challengeShowOnLeaderboard.
  ///
  /// In en, this message translates to:
  /// **'Appear on the leaderboard'**
  String get challengeShowOnLeaderboard;

  /// No description provided for @challengeShowOnLeaderboardHelp.
  ///
  /// In en, this message translates to:
  /// **'Needs sharing. Only people who appear can see the leaderboard.'**
  String get challengeShowOnLeaderboardHelp;

  /// No description provided for @challengeJoin.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get challengeJoin;

  /// No description provided for @challengeCheckInSaved.
  ///
  /// In en, this message translates to:
  /// **'Check-in saved.'**
  String get challengeCheckInSaved;

  /// No description provided for @challengeSharingSaved.
  ///
  /// In en, this message translates to:
  /// **'Your sharing choice is saved.'**
  String get challengeSharingSaved;

  /// No description provided for @challengeLeaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave this challenge?'**
  String get challengeLeaveTitle;

  /// No description provided for @challengeLeaveBody.
  ///
  /// In en, this message translates to:
  /// **'Your progress stops counting and you leave the leaderboard.'**
  String get challengeLeaveBody;

  /// No description provided for @challengeLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave challenge'**
  String get challengeLeave;

  /// No description provided for @challengeLeftDone.
  ///
  /// In en, this message translates to:
  /// **'You left the challenge.'**
  String get challengeLeftDone;

  /// No description provided for @challengeYourProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Your progress'**
  String get challengeYourProgressTitle;

  /// No description provided for @challengeProgressLine.
  ///
  /// In en, this message translates to:
  /// **'{value} of {target}'**
  String challengeProgressLine(int value, String target);

  /// No description provided for @challengeStreaks.
  ///
  /// In en, this message translates to:
  /// **'Current streak: {current} · Best: {best}'**
  String challengeStreaks(int current, int best);

  /// No description provided for @challengeCompletedOn.
  ///
  /// In en, this message translates to:
  /// **'Completed on {date}'**
  String challengeCompletedOn(String date);

  /// No description provided for @challengeMilestoneReached.
  ///
  /// In en, this message translates to:
  /// **'Reached'**
  String get challengeMilestoneReached;

  /// No description provided for @challengeMilestoneAhead.
  ///
  /// In en, this message translates to:
  /// **'Not yet'**
  String get challengeMilestoneAhead;

  /// No description provided for @challengeCheckInTitle.
  ///
  /// In en, this message translates to:
  /// **'Check in'**
  String get challengeCheckInTitle;

  /// No description provided for @challengeCheckInHelp.
  ///
  /// In en, this message translates to:
  /// **'Checking in again for the same day corrects it.'**
  String get challengeCheckInHelp;

  /// No description provided for @challengeCheckInDate.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get challengeCheckInDate;

  /// No description provided for @challengeCheckInDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get challengeCheckInDone;

  /// No description provided for @challengeCheckInMissed.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get challengeCheckInMissed;

  /// No description provided for @challengeCheckInPercent.
  ///
  /// In en, this message translates to:
  /// **'How far you are (0–100 %)'**
  String get challengeCheckInPercent;

  /// No description provided for @challengeCheckInCount.
  ///
  /// In en, this message translates to:
  /// **'How many'**
  String get challengeCheckInCount;

  /// No description provided for @challengeCheckInNote.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get challengeCheckInNote;

  /// No description provided for @challengeCheckInNoteHelp.
  ///
  /// In en, this message translates to:
  /// **'Only you see this note.'**
  String get challengeCheckInNoteHelp;

  /// No description provided for @challengeCheckIn.
  ///
  /// In en, this message translates to:
  /// **'Save check-in'**
  String get challengeCheckIn;

  /// No description provided for @challengeSharingTitle.
  ///
  /// In en, this message translates to:
  /// **'What you share'**
  String get challengeSharingTitle;

  /// No description provided for @challengeLeaderboardEmpty.
  ///
  /// In en, this message translates to:
  /// **'No one appears on the leaderboard yet.'**
  String get challengeLeaderboardEmpty;

  /// No description provided for @challengeLeaderboardYou.
  ///
  /// In en, this message translates to:
  /// **'{name} (you)'**
  String challengeLeaderboardYou(String name);

  /// No description provided for @challengeStreakNow.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1-day streak} other{{count}-day streak}}'**
  String challengeStreakNow(int count);

  /// No description provided for @challengeLeaderboardNote.
  ///
  /// In en, this message translates to:
  /// **'Percentages of the target only; amounts and notes are never shown.'**
  String get challengeLeaderboardNote;

  /// No description provided for @challengeLeaderboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard'**
  String get challengeLeaderboardTitle;

  /// No description provided for @entryConnectAccount.
  ///
  /// In en, this message translates to:
  /// **'Connect to the bank'**
  String get entryConnectAccount;

  /// No description provided for @gxExpensesTitle.
  ///
  /// In en, this message translates to:
  /// **'Shared expenses'**
  String get gxExpensesTitle;

  /// No description provided for @gxExpensesTitleOf.
  ///
  /// In en, this message translates to:
  /// **'Expenses · {group}'**
  String gxExpensesTitleOf(String group);

  /// No description provided for @gxExpenseTitle.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get gxExpenseTitle;

  /// No description provided for @gxBalancesTitle.
  ///
  /// In en, this message translates to:
  /// **'Balances'**
  String get gxBalancesTitle;

  /// No description provided for @gxSettlementsTitle.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get gxSettlementsTitle;

  /// No description provided for @gxSettlementTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get gxSettlementTitle;

  /// No description provided for @gxRecurringTitle.
  ///
  /// In en, this message translates to:
  /// **'Recurring expenses'**
  String get gxRecurringTitle;

  /// No description provided for @gxReportsTitle.
  ///
  /// In en, this message translates to:
  /// **'Group report'**
  String get gxReportsTitle;

  /// No description provided for @gxMoreScreens.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get gxMoreScreens;

  /// No description provided for @gxArchivedReadOnly.
  ///
  /// In en, this message translates to:
  /// **'This group is archived, so nothing can be added or changed.'**
  String get gxArchivedReadOnly;

  /// No description provided for @gxYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get gxYou;

  /// No description provided for @gxFormerMember.
  ///
  /// In en, this message translates to:
  /// **'Former member'**
  String get gxFormerMember;

  /// No description provided for @gxMemberLeft.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get gxMemberLeft;

  /// No description provided for @gxMemberRemoved.
  ///
  /// In en, this message translates to:
  /// **'Removed'**
  String get gxMemberRemoved;

  /// No description provided for @gxNoOneToPick.
  ///
  /// In en, this message translates to:
  /// **'There is no one else to choose.'**
  String get gxNoOneToPick;

  /// No description provided for @gxStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get gxStatusActive;

  /// No description provided for @gxStatusDisputed.
  ///
  /// In en, this message translates to:
  /// **'Disputed'**
  String get gxStatusDisputed;

  /// No description provided for @gxStatusDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get gxStatusDeleted;

  /// No description provided for @gxStatusOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get gxStatusOther;

  /// No description provided for @gxSplitEqual.
  ///
  /// In en, this message translates to:
  /// **'Equally'**
  String get gxSplitEqual;

  /// No description provided for @gxSplitExact.
  ///
  /// In en, this message translates to:
  /// **'Exact amounts'**
  String get gxSplitExact;

  /// No description provided for @gxSplitPercentage.
  ///
  /// In en, this message translates to:
  /// **'Percentages'**
  String get gxSplitPercentage;

  /// No description provided for @gxSplitShares.
  ///
  /// In en, this message translates to:
  /// **'Shares'**
  String get gxSplitShares;

  /// No description provided for @gxSplitItemized.
  ///
  /// In en, this message translates to:
  /// **'By item'**
  String get gxSplitItemized;

  /// No description provided for @gxSplitOther.
  ///
  /// In en, this message translates to:
  /// **'Other split'**
  String get gxSplitOther;

  /// No description provided for @gxSplitEqualHelp.
  ///
  /// In en, this message translates to:
  /// **'Everyone chosen pays the same share.'**
  String get gxSplitEqualHelp;

  /// No description provided for @gxSplitExactHelp.
  ///
  /// In en, this message translates to:
  /// **'Enter each person\'s amount. The amounts must add up to the total.'**
  String get gxSplitExactHelp;

  /// No description provided for @gxSplitPercentageHelp.
  ///
  /// In en, this message translates to:
  /// **'Enter each person’s percentage (up to 2 decimals). They must add up to 100%.'**
  String get gxSplitPercentageHelp;

  /// No description provided for @gxSplitSharesHelp.
  ///
  /// In en, this message translates to:
  /// **'Give each person a whole number of shares, for example 2 for a couple.'**
  String get gxSplitSharesHelp;

  /// No description provided for @gxSplitItemizedHelp.
  ///
  /// In en, this message translates to:
  /// **'List the items and who shared each. Tax, tip or rounding (the total minus the items) is shared in proportion.'**
  String get gxSplitItemizedHelp;

  /// No description provided for @gxSplitSection.
  ///
  /// In en, this message translates to:
  /// **'Split'**
  String get gxSplitSection;

  /// No description provided for @gxSplitMethodLabel.
  ///
  /// In en, this message translates to:
  /// **'How it is split'**
  String get gxSplitMethodLabel;

  /// No description provided for @gxSplitNeedsPeople.
  ///
  /// In en, this message translates to:
  /// **'Choose at least one person to share it.'**
  String get gxSplitNeedsPeople;

  /// No description provided for @gxPercentValue.
  ///
  /// In en, this message translates to:
  /// **'{value} %'**
  String gxPercentValue(String value);

  /// No description provided for @gxSharesValue.
  ///
  /// In en, this message translates to:
  /// **'{value} shares'**
  String gxSharesValue(String value);

  /// No description provided for @gxSharesEqually.
  ///
  /// In en, this message translates to:
  /// **'Equal share'**
  String get gxSharesEqually;

  /// No description provided for @gxValueAmountFor.
  ///
  /// In en, this message translates to:
  /// **'Amount for {name}'**
  String gxValueAmountFor(String name);

  /// No description provided for @gxValuePercentFor.
  ///
  /// In en, this message translates to:
  /// **'Percentage for {name}'**
  String gxValuePercentFor(String name);

  /// No description provided for @gxValueSharesFor.
  ///
  /// In en, this message translates to:
  /// **'Shares for {name}'**
  String gxValueSharesFor(String name);

  /// No description provided for @gxPercentInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a percentage up to 100 with up to 2 decimals.'**
  String get gxPercentInvalid;

  /// No description provided for @gxSharesInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a whole number above 0.'**
  String get gxSharesInvalid;

  /// No description provided for @gxPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview (the server works out the final split): {text}'**
  String gxPreview(String text);

  /// No description provided for @gxPreviewPeople.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{shared by 1 person} other{shared equally by {count} people}}'**
  String gxPreviewPeople(int count);

  /// No description provided for @gxPreviewPercentOk.
  ///
  /// In en, this message translates to:
  /// **'the percentages add up to 100%.'**
  String get gxPreviewPercentOk;

  /// No description provided for @gxPreviewPercentTotal.
  ///
  /// In en, this message translates to:
  /// **'the percentages add up to {total}%, not 100%.'**
  String gxPreviewPercentTotal(String total);

  /// No description provided for @gxPreviewShares.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 share in total.} other{{count} shares in total.}}'**
  String gxPreviewShares(int count);

  /// No description provided for @gxPreviewAssigned.
  ///
  /// In en, this message translates to:
  /// **'{assigned} assigned.'**
  String gxPreviewAssigned(String assigned);

  /// No description provided for @gxPreviewExactOk.
  ///
  /// In en, this message translates to:
  /// **'the amounts add up to the total.'**
  String get gxPreviewExactOk;

  /// No description provided for @gxPreviewPayersOk.
  ///
  /// In en, this message translates to:
  /// **'the payments add up to the total.'**
  String get gxPreviewPayersOk;

  /// No description provided for @gxPreviewLeft.
  ///
  /// In en, this message translates to:
  /// **'{assigned} so far, {left} still to assign.'**
  String gxPreviewLeft(String assigned, String left);

  /// No description provided for @gxPreviewTooMuch.
  ///
  /// In en, this message translates to:
  /// **'{assigned} so far, {over} more than the total.'**
  String gxPreviewTooMuch(String assigned, String over);

  /// No description provided for @gxAddExpense.
  ///
  /// In en, this message translates to:
  /// **'Add expense'**
  String get gxAddExpense;

  /// No description provided for @gxEditExpense.
  ///
  /// In en, this message translates to:
  /// **'Edit expense'**
  String get gxEditExpense;

  /// No description provided for @gxFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get gxFilterAll;

  /// No description provided for @gxFilterPayer.
  ///
  /// In en, this message translates to:
  /// **'Paid by'**
  String get gxFilterPayer;

  /// No description provided for @gxFilterPaidBy.
  ///
  /// In en, this message translates to:
  /// **'Paid by {name}'**
  String gxFilterPaidBy(String name);

  /// No description provided for @gxFilterCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get gxFilterCategory;

  /// No description provided for @gxFilterDates.
  ///
  /// In en, this message translates to:
  /// **'Dates'**
  String get gxFilterDates;

  /// No description provided for @gxExpensesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No shared expenses yet'**
  String get gxExpensesEmptyTitle;

  /// No description provided for @gxExpensesEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add what someone paid for the group, and Montra works out who owes whom.'**
  String get gxExpensesEmptyBody;

  /// No description provided for @gxExpensesEmptyFiltered.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches these filters'**
  String get gxExpensesEmptyFiltered;

  /// No description provided for @gxExpenseLine.
  ///
  /// In en, this message translates to:
  /// **'{date} · {category}'**
  String gxExpenseLine(String date, String category);

  /// No description provided for @gxYouPaidShare.
  ///
  /// In en, this message translates to:
  /// **'You paid {paid} · your share {share}'**
  String gxYouPaidShare(String paid, String share);

  /// No description provided for @gxPaidInOriginal.
  ///
  /// In en, this message translates to:
  /// **'Paid in {amount}'**
  String gxPaidInOriginal(String amount);

  /// No description provided for @gxDescriptionHelp.
  ///
  /// In en, this message translates to:
  /// **'What was it for? For example: Dinner, Groceries, Taxi.'**
  String get gxDescriptionHelp;

  /// No description provided for @gxAmountSection.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get gxAmountSection;

  /// No description provided for @gxForeignLabel.
  ///
  /// In en, this message translates to:
  /// **'Paid in another currency'**
  String get gxForeignLabel;

  /// No description provided for @gxForeignHelp.
  ///
  /// In en, this message translates to:
  /// **'Enter what you paid; Montra converts it to {currency}.'**
  String gxForeignHelp(String currency);

  /// No description provided for @gxOriginalCurrency.
  ///
  /// In en, this message translates to:
  /// **'Currency paid in'**
  String get gxOriginalCurrency;

  /// No description provided for @gxOriginalAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount paid'**
  String get gxOriginalAmount;

  /// No description provided for @gxRateLookup.
  ///
  /// In en, this message translates to:
  /// **'Use Montra\'s rate for the date'**
  String get gxRateLookup;

  /// No description provided for @gxRateLookupHelp.
  ///
  /// In en, this message translates to:
  /// **'Your own saved rate for that day is used first, then a published rate.'**
  String get gxRateLookupHelp;

  /// No description provided for @gxRateManual.
  ///
  /// In en, this message translates to:
  /// **'Enter the rate I used'**
  String get gxRateManual;

  /// No description provided for @gxRateManualHelp.
  ///
  /// In en, this message translates to:
  /// **'How many {currency} one unit cost, for example from your card statement.'**
  String gxRateManualHelp(String currency);

  /// No description provided for @gxRateLabel.
  ///
  /// In en, this message translates to:
  /// **'{currency} 1 = ? {group}'**
  String gxRateLabel(String currency, String group);

  /// No description provided for @gxRateInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a positive rate, for example 83.25.'**
  String get gxRateInvalid;

  /// No description provided for @gxForeignServerAmount.
  ///
  /// In en, this message translates to:
  /// **'Montra works out the amount in {currency} from the rate and shows it after you save.'**
  String gxForeignServerAmount(String currency);

  /// No description provided for @gxChooseCurrency.
  ///
  /// In en, this message translates to:
  /// **'Choose the currency you paid in.'**
  String get gxChooseCurrency;

  /// No description provided for @gxDateToday.
  ///
  /// In en, this message translates to:
  /// **'Today (in the group’s time zone)'**
  String get gxDateToday;

  /// No description provided for @gxItemsSection.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get gxItemsSection;

  /// No description provided for @gxItemsHelp.
  ///
  /// In en, this message translates to:
  /// **'Item amounts are in the group currency. Choose who shared each item.'**
  String get gxItemsHelp;

  /// No description provided for @gxItemName.
  ///
  /// In en, this message translates to:
  /// **'Item {number}'**
  String gxItemName(int number);

  /// No description provided for @gxItemAmount.
  ///
  /// In en, this message translates to:
  /// **'Item amount'**
  String get gxItemAmount;

  /// No description provided for @gxItemSharedBy.
  ///
  /// In en, this message translates to:
  /// **'Shared by'**
  String get gxItemSharedBy;

  /// No description provided for @gxItemRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove item'**
  String get gxItemRemove;

  /// No description provided for @gxItemAdd.
  ///
  /// In en, this message translates to:
  /// **'Add item'**
  String get gxItemAdd;

  /// No description provided for @gxItemNeedsPeople.
  ///
  /// In en, this message translates to:
  /// **'Choose who shared each item.'**
  String get gxItemNeedsPeople;

  /// No description provided for @gxWhoPaid.
  ///
  /// In en, this message translates to:
  /// **'Who paid'**
  String get gxWhoPaid;

  /// No description provided for @gxPayerYou.
  ///
  /// In en, this message translates to:
  /// **'I paid'**
  String get gxPayerYou;

  /// No description provided for @gxPayerOne.
  ///
  /// In en, this message translates to:
  /// **'Someone else paid'**
  String get gxPayerOne;

  /// No description provided for @gxPayerSeveral.
  ///
  /// In en, this message translates to:
  /// **'Several people paid'**
  String get gxPayerSeveral;

  /// No description provided for @gxPaidBy.
  ///
  /// In en, this message translates to:
  /// **'Paid by {name}'**
  String gxPaidBy(String name);

  /// No description provided for @gxChoosePayer.
  ///
  /// In en, this message translates to:
  /// **'Choose who paid.'**
  String get gxChoosePayer;

  /// No description provided for @gxForeignPayerNote.
  ///
  /// In en, this message translates to:
  /// **'Several payers need the amount in {currency}: to split the payment, enter the amount in {currency} instead.'**
  String gxForeignPayerNote(String currency);

  /// No description provided for @gxRecordInAccount.
  ///
  /// In en, this message translates to:
  /// **'Record my payment in an account'**
  String get gxRecordInAccount;

  /// No description provided for @gxRecordInAccountHelp.
  ///
  /// In en, this message translates to:
  /// **'Only your share counts as your spending.'**
  String get gxRecordInAccountHelp;

  /// No description provided for @gxMoreSection.
  ///
  /// In en, this message translates to:
  /// **'More details'**
  String get gxMoreSection;

  /// No description provided for @gxAttachReceipt.
  ///
  /// In en, this message translates to:
  /// **'Attach a receipt'**
  String get gxAttachReceipt;

  /// No description provided for @gxReceiptAttached.
  ///
  /// In en, this message translates to:
  /// **'Receipt attached'**
  String get gxReceiptAttached;

  /// No description provided for @gxReceiptHelp.
  ///
  /// In en, this message translates to:
  /// **'Group members can see it.'**
  String get gxReceiptHelp;

  /// No description provided for @gxReceiptRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove the file'**
  String get gxReceiptRemove;

  /// No description provided for @gxFormerParticipants.
  ///
  /// In en, this message translates to:
  /// **'{names} no longer belong to the group. Saving leaves them out of the split.'**
  String gxFormerParticipants(String names);

  /// No description provided for @gxExpenseAdded.
  ///
  /// In en, this message translates to:
  /// **'Expense added.'**
  String get gxExpenseAdded;

  /// No description provided for @gxExpenseSaved.
  ///
  /// In en, this message translates to:
  /// **'Expense saved.'**
  String get gxExpenseSaved;

  /// No description provided for @gxDeletedNotice.
  ///
  /// In en, this message translates to:
  /// **'This expense was deleted. It no longer counts in balances.'**
  String get gxDeletedNotice;

  /// No description provided for @gxDisputedNotice.
  ///
  /// In en, this message translates to:
  /// **'Someone disputed this expense. It still counts until the dispute is resolved or the expense is edited or deleted.'**
  String get gxDisputedNotice;

  /// No description provided for @gxYourShare.
  ///
  /// In en, this message translates to:
  /// **'Your share'**
  String get gxYourShare;

  /// No description provided for @gxYouPaid.
  ///
  /// In en, this message translates to:
  /// **'You paid'**
  String get gxYouPaid;

  /// No description provided for @gxHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get gxHistory;

  /// No description provided for @gxEditedTimes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Edited once} other{Edited {count} times}}'**
  String gxEditedTimes(int count);

  /// No description provided for @gxForeignTitle.
  ///
  /// In en, this message translates to:
  /// **'Other currency'**
  String get gxForeignTitle;

  /// No description provided for @gxRateUsed.
  ///
  /// In en, this message translates to:
  /// **'Rate used'**
  String get gxRateUsed;

  /// No description provided for @gxRateValue.
  ///
  /// In en, this message translates to:
  /// **'1 {from} = {rate} {to}'**
  String gxRateValue(String from, String rate, String to);

  /// No description provided for @gxRateSource.
  ///
  /// In en, this message translates to:
  /// **'Rate from'**
  String get gxRateSource;

  /// No description provided for @gxRateTime.
  ///
  /// In en, this message translates to:
  /// **'Rate as of'**
  String get gxRateTime;

  /// No description provided for @gxConverted.
  ///
  /// In en, this message translates to:
  /// **'In the group currency'**
  String get gxConverted;

  /// No description provided for @gxFxSourceManual.
  ///
  /// In en, this message translates to:
  /// **'Entered by a member'**
  String get gxFxSourceManual;

  /// No description provided for @gxFxSourceEcb.
  ///
  /// In en, this message translates to:
  /// **'European Central Bank'**
  String get gxFxSourceEcb;

  /// No description provided for @gxFxSourceProvider.
  ///
  /// In en, this message translates to:
  /// **'Rate provider'**
  String get gxFxSourceProvider;

  /// No description provided for @gxFxSourceOther.
  ///
  /// In en, this message translates to:
  /// **'Other source'**
  String get gxFxSourceOther;

  /// No description provided for @gxPaidBySection.
  ///
  /// In en, this message translates to:
  /// **'Paid by'**
  String get gxPaidBySection;

  /// No description provided for @gxSharesSection.
  ///
  /// In en, this message translates to:
  /// **'Shares'**
  String get gxSharesSection;

  /// No description provided for @gxSharesByServer.
  ///
  /// In en, this message translates to:
  /// **'Shares are worked out exactly by Montra, down to the last paisa or cent.'**
  String get gxSharesByServer;

  /// No description provided for @gxReceipt.
  ///
  /// In en, this message translates to:
  /// **'Receipt'**
  String get gxReceipt;

  /// No description provided for @gxRecordedInAccount.
  ///
  /// In en, this message translates to:
  /// **'Recorded in your account'**
  String get gxRecordedInAccount;

  /// No description provided for @gxRecordedInAccountHelp.
  ///
  /// In en, this message translates to:
  /// **'Your payment is in your transactions; it follows changes to this expense.'**
  String get gxRecordedInAccountHelp;

  /// No description provided for @gxRecorded.
  ///
  /// In en, this message translates to:
  /// **'Recorded in your account.'**
  String get gxRecorded;

  /// No description provided for @gxUnlink.
  ///
  /// In en, this message translates to:
  /// **'Remove from my account'**
  String get gxUnlink;

  /// No description provided for @gxUnlinkTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove your account record?'**
  String get gxUnlinkTitle;

  /// No description provided for @gxUnlinkBody.
  ///
  /// In en, this message translates to:
  /// **'The transaction in your account is removed. The group expense stays as it is.'**
  String get gxUnlinkBody;

  /// No description provided for @gxUnlinkSettlementBody.
  ///
  /// In en, this message translates to:
  /// **'The transaction in your account is removed. The payment stays recorded in the group.'**
  String get gxUnlinkSettlementBody;

  /// No description provided for @gxUnlinked.
  ///
  /// In en, this message translates to:
  /// **'Removed from your account.'**
  String get gxUnlinked;

  /// No description provided for @gxDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this expense?'**
  String get gxDeleteTitle;

  /// No description provided for @gxDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" will no longer count in balances. Members still see it as deleted.'**
  String gxDeleteBody(String name);

  /// No description provided for @gxExpenseDeleted.
  ///
  /// In en, this message translates to:
  /// **'Expense deleted.'**
  String get gxExpenseDeleted;

  /// No description provided for @gxDisputesSection.
  ///
  /// In en, this message translates to:
  /// **'Disputes'**
  String get gxDisputesSection;

  /// No description provided for @gxNoDisputes.
  ///
  /// In en, this message translates to:
  /// **'No one has disputed this expense.'**
  String get gxNoDisputes;

  /// No description provided for @gxDispute.
  ///
  /// In en, this message translates to:
  /// **'Something is wrong'**
  String get gxDispute;

  /// No description provided for @gxDisputeTitle.
  ///
  /// In en, this message translates to:
  /// **'What is wrong?'**
  String get gxDisputeTitle;

  /// No description provided for @gxDisputeBody.
  ///
  /// In en, this message translates to:
  /// **'Members see your note. The expense still counts until it is fixed.'**
  String get gxDisputeBody;

  /// No description provided for @gxDisputeReason.
  ///
  /// In en, this message translates to:
  /// **'What is wrong'**
  String get gxDisputeReason;

  /// No description provided for @gxDisputeSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get gxDisputeSend;

  /// No description provided for @gxDisputeSent.
  ///
  /// In en, this message translates to:
  /// **'Your note was sent to the group.'**
  String get gxDisputeSent;

  /// No description provided for @gxDisputeOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get gxDisputeOpen;

  /// No description provided for @gxDisputeResolved.
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get gxDisputeResolved;

  /// No description provided for @gxDisputeWithdrawn.
  ///
  /// In en, this message translates to:
  /// **'Withdrawn'**
  String get gxDisputeWithdrawn;

  /// No description provided for @gxRaisedBy.
  ///
  /// In en, this message translates to:
  /// **'Raised by {name}'**
  String gxRaisedBy(String name);

  /// No description provided for @gxResolutionText.
  ///
  /// In en, this message translates to:
  /// **'Resolution: {text}'**
  String gxResolutionText(String text);

  /// No description provided for @gxWithdraw.
  ///
  /// In en, this message translates to:
  /// **'Withdraw'**
  String get gxWithdraw;

  /// No description provided for @gxWithdrawTitle.
  ///
  /// In en, this message translates to:
  /// **'Withdraw your dispute?'**
  String get gxWithdrawTitle;

  /// No description provided for @gxWithdrawBody.
  ///
  /// In en, this message translates to:
  /// **'The expense stays as it is.'**
  String get gxWithdrawBody;

  /// No description provided for @gxWithdrawn.
  ///
  /// In en, this message translates to:
  /// **'Dispute withdrawn.'**
  String get gxWithdrawn;

  /// No description provided for @gxResolve.
  ///
  /// In en, this message translates to:
  /// **'Resolve'**
  String get gxResolve;

  /// No description provided for @gxResolveTitle.
  ///
  /// In en, this message translates to:
  /// **'Resolve this dispute'**
  String get gxResolveTitle;

  /// No description provided for @gxResolveBody.
  ///
  /// In en, this message translates to:
  /// **'Say what was decided. Edit the expense first if something needs to change.'**
  String get gxResolveBody;

  /// No description provided for @gxResolution.
  ///
  /// In en, this message translates to:
  /// **'What was decided'**
  String get gxResolution;

  /// No description provided for @gxResolved.
  ///
  /// In en, this message translates to:
  /// **'Dispute resolved.'**
  String get gxResolved;

  /// No description provided for @gxCommentsSection.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get gxCommentsSection;

  /// No description provided for @gxNoComments.
  ///
  /// In en, this message translates to:
  /// **'No comments yet.'**
  String get gxNoComments;

  /// No description provided for @gxCommentLabel.
  ///
  /// In en, this message translates to:
  /// **'Add a comment'**
  String get gxCommentLabel;

  /// No description provided for @gxCommentSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get gxCommentSend;

  /// No description provided for @gxCommentSent.
  ///
  /// In en, this message translates to:
  /// **'Comment added.'**
  String get gxCommentSent;

  /// No description provided for @gxYourBalance.
  ///
  /// In en, this message translates to:
  /// **'Your balance'**
  String get gxYourBalance;

  /// No description provided for @gxYouAreOwed.
  ///
  /// In en, this message translates to:
  /// **'You are owed {amount}'**
  String gxYouAreOwed(String amount);

  /// No description provided for @gxYouOwe.
  ///
  /// In en, this message translates to:
  /// **'You owe {amount}'**
  String gxYouOwe(String amount);

  /// No description provided for @gxYouSettled.
  ///
  /// In en, this message translates to:
  /// **'You are all settled'**
  String get gxYouSettled;

  /// No description provided for @gxIsOwed.
  ///
  /// In en, this message translates to:
  /// **'{name} is owed {amount}'**
  String gxIsOwed(String name, String amount);

  /// No description provided for @gxOwes.
  ///
  /// In en, this message translates to:
  /// **'{name} owes {amount}'**
  String gxOwes(String name, String amount);

  /// No description provided for @gxSettled.
  ///
  /// In en, this message translates to:
  /// **'{name} is settled'**
  String gxSettled(String name);

  /// No description provided for @gxComputedAt.
  ///
  /// In en, this message translates to:
  /// **'Worked out {time}'**
  String gxComputedAt(String time);

  /// No description provided for @gxDisputedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 disputed expense still counts until it is resolved, edited or deleted.} other{{count} disputed expenses still count until they are resolved, edited or deleted.}}'**
  String gxDisputedCount(int count);

  /// No description provided for @gxSuggestionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Suggested payments'**
  String get gxSuggestionsTitle;

  /// No description provided for @gxSuggestionsHelp.
  ///
  /// In en, this message translates to:
  /// **'Suggestions only. Montra does not move money; record a payment after you pay outside Montra.'**
  String get gxSuggestionsHelp;

  /// No description provided for @gxOnlyMine.
  ///
  /// In en, this message translates to:
  /// **'Only mine'**
  String get gxOnlyMine;

  /// No description provided for @gxNoSuggestionsMine.
  ///
  /// In en, this message translates to:
  /// **'You have nothing to pay or receive.'**
  String get gxNoSuggestionsMine;

  /// No description provided for @gxNothingOwed.
  ///
  /// In en, this message translates to:
  /// **'Everyone is settled.'**
  String get gxNothingOwed;

  /// No description provided for @gxWhoOwesWhom.
  ///
  /// In en, this message translates to:
  /// **'Who owes whom'**
  String get gxWhoOwesWhom;

  /// No description provided for @gxDebtsSimplified.
  ///
  /// In en, this message translates to:
  /// **'Fewest payments'**
  String get gxDebtsSimplified;

  /// No description provided for @gxDebtsOriginal.
  ///
  /// In en, this message translates to:
  /// **'As recorded'**
  String get gxDebtsOriginal;

  /// No description provided for @gxDebtsSimplifiedHelp.
  ///
  /// In en, this message translates to:
  /// **'The fewest payments that settle everyone. Both views add up to the same balances.'**
  String get gxDebtsSimplifiedHelp;

  /// No description provided for @gxDebtsOriginalHelp.
  ///
  /// In en, this message translates to:
  /// **'What each person owes each other person from the expenses, netted per pair.'**
  String get gxDebtsOriginalHelp;

  /// No description provided for @gxPays.
  ///
  /// In en, this message translates to:
  /// **'{from} pays {to}'**
  String gxPays(String from, String to);

  /// No description provided for @gxInvolvesYou.
  ///
  /// In en, this message translates to:
  /// **'Involves you'**
  String get gxInvolvesYou;

  /// No description provided for @gxRecordThisPayment.
  ///
  /// In en, this message translates to:
  /// **'Record a payment from {from} to {to} of {amount}'**
  String gxRecordThisPayment(String from, String to, String amount);

  /// No description provided for @gxMembersSection.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get gxMembersSection;

  /// No description provided for @gxBalancePaid.
  ///
  /// In en, this message translates to:
  /// **'Paid for the group'**
  String get gxBalancePaid;

  /// No description provided for @gxBalanceShare.
  ///
  /// In en, this message translates to:
  /// **'Share of expenses'**
  String get gxBalanceShare;

  /// No description provided for @gxBalanceSent.
  ///
  /// In en, this message translates to:
  /// **'Payments made (confirmed)'**
  String get gxBalanceSent;

  /// No description provided for @gxBalanceReceived.
  ///
  /// In en, this message translates to:
  /// **'Payments received (confirmed)'**
  String get gxBalanceReceived;

  /// No description provided for @gxBalancePendingOut.
  ///
  /// In en, this message translates to:
  /// **'Reported, waiting for confirmation'**
  String get gxBalancePendingOut;

  /// No description provided for @gxBalancePendingIn.
  ///
  /// In en, this message translates to:
  /// **'To confirm'**
  String get gxBalancePendingIn;

  /// No description provided for @gxFormerBalanceNote.
  ///
  /// In en, this message translates to:
  /// **'Their balance stays in the group. Anyone can record a payment with them, and an admin confirms payments to them.'**
  String get gxFormerBalanceNote;

  /// No description provided for @gxNoMoneyMoves.
  ///
  /// In en, this message translates to:
  /// **'Montra never moves money. Payments here are records of money paid outside Montra.'**
  String get gxNoMoneyMoves;

  /// No description provided for @gxRecordPayment.
  ///
  /// In en, this message translates to:
  /// **'Record a payment'**
  String get gxRecordPayment;

  /// No description provided for @gxShowVoided.
  ///
  /// In en, this message translates to:
  /// **'Show voided'**
  String get gxShowVoided;

  /// No description provided for @gxSettlementsHelp.
  ///
  /// In en, this message translates to:
  /// **'Only confirmed payments count in balances.'**
  String get gxSettlementsHelp;

  /// No description provided for @gxSettlementsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No payments yet'**
  String get gxSettlementsEmptyTitle;

  /// No description provided for @gxSettlementsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'When someone pays back, record it here so balances stay right.'**
  String get gxSettlementsEmptyBody;

  /// No description provided for @gxPaid.
  ///
  /// In en, this message translates to:
  /// **'{from} paid {to}'**
  String gxPaid(String from, String to);

  /// No description provided for @gxSettlementProposed.
  ///
  /// In en, this message translates to:
  /// **'Planned'**
  String get gxSettlementProposed;

  /// No description provided for @gxSettlementReported.
  ///
  /// In en, this message translates to:
  /// **'Waiting for confirmation'**
  String get gxSettlementReported;

  /// No description provided for @gxSettlementConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get gxSettlementConfirmed;

  /// No description provided for @gxSettlementDisputed.
  ///
  /// In en, this message translates to:
  /// **'Disputed'**
  String get gxSettlementDisputed;

  /// No description provided for @gxSettlementVoided.
  ///
  /// In en, this message translates to:
  /// **'Voided'**
  String get gxSettlementVoided;

  /// No description provided for @gxMethodCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get gxMethodCash;

  /// No description provided for @gxMethodBank.
  ///
  /// In en, this message translates to:
  /// **'Bank transfer'**
  String get gxMethodBank;

  /// No description provided for @gxMethodUpi.
  ///
  /// In en, this message translates to:
  /// **'UPI'**
  String get gxMethodUpi;

  /// No description provided for @gxMethodOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get gxMethodOther;

  /// No description provided for @gxMethodLabel.
  ///
  /// In en, this message translates to:
  /// **'How it was paid'**
  String get gxMethodLabel;

  /// No description provided for @gxWhoReceived.
  ///
  /// In en, this message translates to:
  /// **'Who received it'**
  String get gxWhoReceived;

  /// No description provided for @gxWhoPays.
  ///
  /// In en, this message translates to:
  /// **'Who pays'**
  String get gxWhoPays;

  /// No description provided for @gxRecordIntro.
  ///
  /// In en, this message translates to:
  /// **'Montra never moves money. Record a payment made in cash, by bank transfer or UPI; the other person confirms it, and then it counts in balances.'**
  String get gxRecordIntro;

  /// No description provided for @gxCorrectIntro.
  ///
  /// In en, this message translates to:
  /// **'Correcting records the right payment and voids the original. Both stay in the history.'**
  String get gxCorrectIntro;

  /// No description provided for @gxCorrectTitle.
  ///
  /// In en, this message translates to:
  /// **'Correct this payment'**
  String get gxCorrectTitle;

  /// No description provided for @gxCorrectButton.
  ///
  /// In en, this message translates to:
  /// **'Save the correction'**
  String get gxCorrectButton;

  /// No description provided for @gxCorrect.
  ///
  /// In en, this message translates to:
  /// **'Correct'**
  String get gxCorrect;

  /// No description provided for @gxPartialAllowed.
  ///
  /// In en, this message translates to:
  /// **'A part payment is fine.'**
  String get gxPartialAllowed;

  /// No description provided for @gxProposedLabel.
  ///
  /// In en, this message translates to:
  /// **'Not paid yet'**
  String get gxProposedLabel;

  /// No description provided for @gxProposedHelp.
  ///
  /// In en, this message translates to:
  /// **'Record it as a plan or a request; the payer marks it paid later.'**
  String get gxProposedHelp;

  /// No description provided for @gxFormerPayeeNote.
  ///
  /// In en, this message translates to:
  /// **'They are no longer a member, so a group admin confirms this payment for them.'**
  String get gxFormerPayeeNote;

  /// No description provided for @gxSettlementAccountHelp.
  ///
  /// In en, this message translates to:
  /// **'Adds the payment to your account as money out (not spending).'**
  String get gxSettlementAccountHelp;

  /// No description provided for @gxAttachProof.
  ///
  /// In en, this message translates to:
  /// **'Attach proof (optional)'**
  String get gxAttachProof;

  /// No description provided for @gxPaymentRecorded.
  ///
  /// In en, this message translates to:
  /// **'Payment recorded.'**
  String get gxPaymentRecorded;

  /// No description provided for @gxCorrected.
  ///
  /// In en, this message translates to:
  /// **'Payment corrected.'**
  String get gxCorrected;

  /// No description provided for @gxVerification.
  ///
  /// In en, this message translates to:
  /// **'Checked by'**
  String get gxVerification;

  /// No description provided for @gxReportedByMembers.
  ///
  /// In en, this message translates to:
  /// **'Reported by members'**
  String get gxReportedByMembers;

  /// No description provided for @gxVerifiedByProvider.
  ///
  /// In en, this message translates to:
  /// **'Verified by a payment provider'**
  String get gxVerifiedByProvider;

  /// No description provided for @gxCounts.
  ///
  /// In en, this message translates to:
  /// **'Counts in balances'**
  String get gxCounts;

  /// No description provided for @gxCountsYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get gxCountsYes;

  /// No description provided for @gxCountsNo.
  ///
  /// In en, this message translates to:
  /// **'Not yet'**
  String get gxCountsNo;

  /// No description provided for @gxRecordedBy.
  ///
  /// In en, this message translates to:
  /// **'Recorded by'**
  String get gxRecordedBy;

  /// No description provided for @gxConfirmedBy.
  ///
  /// In en, this message translates to:
  /// **'Confirmed by'**
  String get gxConfirmedBy;

  /// No description provided for @gxDisputeReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Dispute'**
  String get gxDisputeReasonLabel;

  /// No description provided for @gxVoidReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Voided because'**
  String get gxVoidReasonLabel;

  /// No description provided for @gxCorrectsOriginal.
  ///
  /// In en, this message translates to:
  /// **'This corrects an earlier payment'**
  String get gxCorrectsOriginal;

  /// No description provided for @gxCorrectedBy.
  ///
  /// In en, this message translates to:
  /// **'See the corrected payment'**
  String get gxCorrectedBy;

  /// No description provided for @gxProof.
  ///
  /// In en, this message translates to:
  /// **'Proof of payment'**
  String get gxProof;

  /// No description provided for @gxSettlementRecordedHelp.
  ///
  /// In en, this message translates to:
  /// **'This payment is in your transactions.'**
  String get gxSettlementRecordedHelp;

  /// No description provided for @gxProposedStatusHelp.
  ///
  /// In en, this message translates to:
  /// **'Planned. The payer marks it paid once the money is sent.'**
  String get gxProposedStatusHelp;

  /// No description provided for @gxReportedStatusHelp.
  ///
  /// In en, this message translates to:
  /// **'Reported as paid. It counts once the person who received it confirms.'**
  String get gxReportedStatusHelp;

  /// No description provided for @gxConfirmedStatusHelp.
  ///
  /// In en, this message translates to:
  /// **'Confirmed by the person who received it. It counts in balances.'**
  String get gxConfirmedStatusHelp;

  /// No description provided for @gxDisputedStatusHelp.
  ///
  /// In en, this message translates to:
  /// **'Someone said this is not right. It ends when the payee confirms it or someone voids it.'**
  String get gxDisputedStatusHelp;

  /// No description provided for @gxVoidedStatusHelp.
  ///
  /// In en, this message translates to:
  /// **'Voided. It no longer counts.'**
  String get gxVoidedStatusHelp;

  /// No description provided for @gxSettlementMarkPaid.
  ///
  /// In en, this message translates to:
  /// **'Mark as paid'**
  String get gxSettlementMarkPaid;

  /// No description provided for @gxSettlementConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm I received it'**
  String get gxSettlementConfirm;

  /// No description provided for @gxSettlementDispute.
  ///
  /// In en, this message translates to:
  /// **'Dispute'**
  String get gxSettlementDispute;

  /// No description provided for @gxSettlementVoid.
  ///
  /// In en, this message translates to:
  /// **'Void'**
  String get gxSettlementVoid;

  /// No description provided for @gxSettlementDisputeTitle.
  ///
  /// In en, this message translates to:
  /// **'Dispute this payment?'**
  String get gxSettlementDisputeTitle;

  /// No description provided for @gxSettlementDisputeBody.
  ///
  /// In en, this message translates to:
  /// **'Say what is wrong. It stops counting until the payee confirms it again.'**
  String get gxSettlementDisputeBody;

  /// No description provided for @gxSettlementVoidTitle.
  ///
  /// In en, this message translates to:
  /// **'Void this payment?'**
  String get gxSettlementVoidTitle;

  /// No description provided for @gxSettlementVoidBody.
  ///
  /// In en, this message translates to:
  /// **'It stays in the history but no longer counts. Give a reason.'**
  String get gxSettlementVoidBody;

  /// No description provided for @gxReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get gxReasonLabel;

  /// No description provided for @gxConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm this payment?'**
  String get gxConfirmTitle;

  /// No description provided for @gxConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Confirm only if you received {amount}. It then counts in balances.'**
  String gxConfirmBody(String amount);

  /// No description provided for @gxConfirmOnBehalfBody.
  ///
  /// In en, this message translates to:
  /// **'The person who received it is no longer a member, so you confirm it as an admin. Confirm only if you know the money arrived.'**
  String get gxConfirmOnBehalfBody;

  /// No description provided for @gxMarkPaidTitle.
  ///
  /// In en, this message translates to:
  /// **'Mark as paid?'**
  String get gxMarkPaidTitle;

  /// No description provided for @gxMarkPaidBody.
  ///
  /// In en, this message translates to:
  /// **'Do this once you have sent the money. The other person then confirms it.'**
  String get gxMarkPaidBody;

  /// No description provided for @gxMarkedPaid.
  ///
  /// In en, this message translates to:
  /// **'Marked as paid.'**
  String get gxMarkedPaid;

  /// No description provided for @gxConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Payment confirmed.'**
  String get gxConfirmed;

  /// No description provided for @gxDisputed.
  ///
  /// In en, this message translates to:
  /// **'Payment disputed.'**
  String get gxDisputed;

  /// No description provided for @gxVoided.
  ///
  /// In en, this message translates to:
  /// **'Payment voided.'**
  String get gxVoided;

  /// No description provided for @gxRecurringAdd.
  ///
  /// In en, this message translates to:
  /// **'Add recurring expense'**
  String get gxRecurringAdd;

  /// No description provided for @gxRecurringEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit recurring expense'**
  String get gxRecurringEdit;

  /// No description provided for @gxRecurringEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No recurring expenses'**
  String get gxRecurringEmptyTitle;

  /// No description provided for @gxRecurringEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Set up rent, cleaning or a shared subscription once, and add it each time it is due.'**
  String get gxRecurringEmptyBody;

  /// No description provided for @gxRecurringName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get gxRecurringName;

  /// No description provided for @gxRecurringNameHelp.
  ///
  /// In en, this message translates to:
  /// **'For example: Rent, Cleaning, Internet.'**
  String get gxRecurringNameHelp;

  /// No description provided for @gxRecurringAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount each time'**
  String get gxRecurringAmount;

  /// No description provided for @gxRecurringDescriptionHelp.
  ///
  /// In en, this message translates to:
  /// **'The description of each expense (the name by default).'**
  String get gxRecurringDescriptionHelp;

  /// No description provided for @gxScheduleSection.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get gxScheduleSection;

  /// No description provided for @gxScheduleDates.
  ///
  /// In en, this message translates to:
  /// **'Dates'**
  String get gxScheduleDates;

  /// No description provided for @gxScheduleFixed.
  ///
  /// In en, this message translates to:
  /// **'The schedule cannot change. To change it, stop this one and add a new one.'**
  String get gxScheduleFixed;

  /// No description provided for @gxAutoAddLabel.
  ///
  /// In en, this message translates to:
  /// **'Add automatically when due'**
  String get gxAutoAddLabel;

  /// No description provided for @gxAutoAddHelp.
  ///
  /// In en, this message translates to:
  /// **'Otherwise any member adds it when it is due.'**
  String get gxAutoAddHelp;

  /// No description provided for @gxAutoAddOn.
  ///
  /// In en, this message translates to:
  /// **'Added automatically'**
  String get gxAutoAddOn;

  /// No description provided for @gxAutoAddOff.
  ///
  /// In en, this message translates to:
  /// **'A member adds it when due'**
  String get gxAutoAddOff;

  /// No description provided for @gxPayerAdder.
  ///
  /// In en, this message translates to:
  /// **'Whoever adds it'**
  String get gxPayerAdder;

  /// No description provided for @gxPayerAdderHelp.
  ///
  /// In en, this message translates to:
  /// **'Whoever adds the expense pays it (the creator when it is added automatically).'**
  String get gxPayerAdderHelp;

  /// No description provided for @gxRecurringAdded.
  ///
  /// In en, this message translates to:
  /// **'Recurring expense added.'**
  String get gxRecurringAdded;

  /// No description provided for @gxRecurringSaved.
  ///
  /// In en, this message translates to:
  /// **'Recurring expense saved.'**
  String get gxRecurringSaved;

  /// No description provided for @gxNextOn.
  ///
  /// In en, this message translates to:
  /// **'Next: {date}'**
  String gxNextOn(String date);

  /// No description provided for @gxNextLabel.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get gxNextLabel;

  /// No description provided for @gxCreatedBy.
  ///
  /// In en, this message translates to:
  /// **'Set up by'**
  String get gxCreatedBy;

  /// No description provided for @gxOccurrencesTitle.
  ///
  /// In en, this message translates to:
  /// **'Occurrences'**
  String get gxOccurrencesTitle;

  /// No description provided for @gxOccurrencesEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing is scheduled.'**
  String get gxOccurrencesEmpty;

  /// No description provided for @gxOccurrenceAdd.
  ///
  /// In en, this message translates to:
  /// **'Add the expense now'**
  String get gxOccurrenceAdd;

  /// No description provided for @gxOccurrenceAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add this expense?'**
  String get gxOccurrenceAddTitle;

  /// No description provided for @gxOccurrenceAddBody.
  ///
  /// In en, this message translates to:
  /// **'{name}, due {date}. You are recorded as the payer unless the split names payers.'**
  String gxOccurrenceAddBody(String name, String date);

  /// No description provided for @gxOccurrenceAdded.
  ///
  /// In en, this message translates to:
  /// **'Expense added.'**
  String get gxOccurrenceAdded;

  /// No description provided for @gxOccurrenceSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped.'**
  String get gxOccurrenceSkipped;

  /// No description provided for @gxOpenExpense.
  ///
  /// In en, this message translates to:
  /// **'Open the expense'**
  String get gxOpenExpense;

  /// No description provided for @gxRecurringStopTitle.
  ///
  /// In en, this message translates to:
  /// **'Stop this recurring expense?'**
  String get gxRecurringStopTitle;

  /// No description provided for @gxRecurringStopBody.
  ///
  /// In en, this message translates to:
  /// **'No more {name} expenses will be scheduled. Expenses already added stay.'**
  String gxRecurringStopBody(String name);

  /// No description provided for @gxAllTime.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get gxAllTime;

  /// No description provided for @gxReportPeriod.
  ///
  /// In en, this message translates to:
  /// **'Report period'**
  String get gxReportPeriod;

  /// No description provided for @gxReportEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing to report yet'**
  String get gxReportEmptyTitle;

  /// No description provided for @gxReportEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'There are no expenses in this period.'**
  String get gxReportEmptyBody;

  /// No description provided for @gxReportSummary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get gxReportSummary;

  /// No description provided for @gxTotalSpent.
  ///
  /// In en, this message translates to:
  /// **'Total spent'**
  String get gxTotalSpent;

  /// No description provided for @gxExpenseCount.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get gxExpenseCount;

  /// No description provided for @gxExpensesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 expense} other{{count} expenses}}'**
  String gxExpensesCount(int count);

  /// No description provided for @gxDisputedLabel.
  ///
  /// In en, this message translates to:
  /// **'Disputed'**
  String get gxDisputedLabel;

  /// No description provided for @gxParticipants.
  ///
  /// In en, this message translates to:
  /// **'People who shared'**
  String get gxParticipants;

  /// No description provided for @gxPeopleCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 person} other{{count} people}}'**
  String gxPeopleCount(int count);

  /// No description provided for @gxPerPerson.
  ///
  /// In en, this message translates to:
  /// **'Average per person'**
  String get gxPerPerson;

  /// No description provided for @gxTripTitle.
  ///
  /// In en, this message translates to:
  /// **'Trip'**
  String get gxTripTitle;

  /// No description provided for @gxDestination.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get gxDestination;

  /// No description provided for @gxTripDates.
  ///
  /// In en, this message translates to:
  /// **'Dates'**
  String get gxTripDates;

  /// No description provided for @gxTripDays.
  ///
  /// In en, this message translates to:
  /// **'Length'**
  String get gxTripDays;

  /// No description provided for @gxDaysCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String gxDaysCount(int count);

  /// No description provided for @gxDailyAverage.
  ///
  /// In en, this message translates to:
  /// **'Average per day'**
  String get gxDailyAverage;

  /// No description provided for @gxByCategory.
  ///
  /// In en, this message translates to:
  /// **'By category'**
  String get gxByCategory;

  /// No description provided for @gxByMember.
  ///
  /// In en, this message translates to:
  /// **'By person'**
  String get gxByMember;

  /// No description provided for @gxByMonth.
  ///
  /// In en, this message translates to:
  /// **'By month'**
  String get gxByMonth;

  /// No description provided for @gxMemberPaidShare.
  ///
  /// In en, this message translates to:
  /// **'Paid {paid} · share {share}'**
  String gxMemberPaidShare(String paid, String share);

  /// No description provided for @gxChartSummary.
  ///
  /// In en, this message translates to:
  /// **'Largest: {label}, {amount}.'**
  String gxChartSummary(String label, String amount);

  /// No description provided for @gxOriginalCurrencies.
  ///
  /// In en, this message translates to:
  /// **'Paid in other currencies'**
  String get gxOriginalCurrencies;

  /// No description provided for @gxOriginalConverted.
  ///
  /// In en, this message translates to:
  /// **'{original} → {converted}'**
  String gxOriginalConverted(String original, String converted);

  /// No description provided for @gxOriginalCurrenciesHelp.
  ///
  /// In en, this message translates to:
  /// **'Converted with each expense’s own rate.'**
  String get gxOriginalCurrenciesHelp;

  /// No description provided for @gxSettlementsConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get gxSettlementsConfirmed;

  /// No description provided for @gxSettlementsPending.
  ///
  /// In en, this message translates to:
  /// **'Waiting for confirmation'**
  String get gxSettlementsPending;

  /// No description provided for @gxSettlementsDisputedCount.
  ///
  /// In en, this message translates to:
  /// **'Disputed'**
  String get gxSettlementsDisputedCount;

  /// No description provided for @gxSettlementsCount.
  ///
  /// In en, this message translates to:
  /// **'Payments recorded'**
  String get gxSettlementsCount;

  /// No description provided for @gxExport.
  ///
  /// In en, this message translates to:
  /// **'Export as CSV'**
  String get gxExport;

  /// No description provided for @gxExportTitle.
  ///
  /// In en, this message translates to:
  /// **'Group expenses (CSV)'**
  String get gxExportTitle;

  /// No description provided for @gxExportIntro.
  ///
  /// In en, this message translates to:
  /// **'Every expense (deleted ones too) and every payment of the group, to share or save. Members are named; no account details are included.'**
  String get gxExportIntro;

  /// No description provided for @gxExportFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get gxExportFile;

  /// No description provided for @gxExportRowsLabel.
  ///
  /// In en, this message translates to:
  /// **'Rows'**
  String get gxExportRowsLabel;

  /// No description provided for @gxExportRows.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 row} other{{count} rows}}'**
  String gxExportRows(int count);

  /// No description provided for @gxErrSplitMismatch.
  ///
  /// In en, this message translates to:
  /// **'The split doesn\'t add up. Check the amounts, percentages (100% in total) or shares.'**
  String get gxErrSplitMismatch;

  /// No description provided for @gxErrPayersMismatch.
  ///
  /// In en, this message translates to:
  /// **'What the payers paid must add up to the total.'**
  String get gxErrPayersMismatch;

  /// No description provided for @gxErrItemsExceedTotal.
  ///
  /// In en, this message translates to:
  /// **'The items add up to more than the total.'**
  String get gxErrItemsExceedTotal;

  /// No description provided for @gxErrItemsNeedAmount.
  ///
  /// In en, this message translates to:
  /// **'At least one item needs an amount.'**
  String get gxErrItemsNeedAmount;

  /// No description provided for @gxErrPayerOnly.
  ///
  /// In en, this message translates to:
  /// **'Only someone who paid can record this expense in an account.'**
  String get gxErrPayerOnly;

  /// No description provided for @gxErrFxUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Montra has no {from} to {to} rate for {date}. Enter the rate you used.'**
  String gxErrFxUnavailable(String from, String to, String date);

  /// No description provided for @gxErrExpenseDeleted.
  ///
  /// In en, this message translates to:
  /// **'This expense was deleted, so it can no longer be changed.'**
  String get gxErrExpenseDeleted;

  /// No description provided for @gxErrExpenseAlreadyRecorded.
  ///
  /// In en, this message translates to:
  /// **'This expense is already recorded in your account.'**
  String get gxErrExpenseAlreadyRecorded;

  /// No description provided for @gxErrSettlementVoided.
  ///
  /// In en, this message translates to:
  /// **'This payment was voided. Record a new one instead.'**
  String get gxErrSettlementVoided;

  /// No description provided for @gxErrSettlementNotProposed.
  ///
  /// In en, this message translates to:
  /// **'Only a planned payment can be marked paid. It is now: {status}.'**
  String gxErrSettlementNotProposed(String status);

  /// No description provided for @gxErrSettlementNotConfirmable.
  ///
  /// In en, this message translates to:
  /// **'This payment can no longer be confirmed. It is now: {status}.'**
  String gxErrSettlementNotConfirmable(String status);

  /// No description provided for @gxErrSettlementNotDisputable.
  ///
  /// In en, this message translates to:
  /// **'Only a reported or confirmed payment can be disputed. It is now: {status}.'**
  String gxErrSettlementNotDisputable(String status);

  /// No description provided for @gxErrSettlementAlreadyRecorded.
  ///
  /// In en, this message translates to:
  /// **'This payment is already recorded in your account.'**
  String get gxErrSettlementAlreadyRecorded;

  /// No description provided for @gxErrSettlementNotConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirm the payment before recording it in your account.'**
  String get gxErrSettlementNotConfirmed;

  /// No description provided for @gxErrSettlementNotPaid.
  ///
  /// In en, this message translates to:
  /// **'Mark it paid before recording it in your account.'**
  String get gxErrSettlementNotPaid;

  /// No description provided for @gxErrSettlementDispute.
  ///
  /// In en, this message translates to:
  /// **'A payment dispute ends when the payee confirms the payment or someone voids it.'**
  String get gxErrSettlementDispute;

  /// No description provided for @gxErrRecurringMemberInactive.
  ///
  /// In en, this message translates to:
  /// **'Someone who shares or pays this recurring expense is no longer a member. Edit who shares it, then add it.'**
  String get gxErrRecurringMemberInactive;

  /// No description provided for @gxErrRecurringMemberInactiveNamed.
  ///
  /// In en, this message translates to:
  /// **'{name} is no longer a member. Edit who shares or pays this recurring expense, then add it.'**
  String gxErrRecurringMemberInactiveNamed(String name);

  /// No description provided for @gxErrRecurringTemplateInvalid.
  ///
  /// In en, this message translates to:
  /// **'This recurring expense cannot be added as it is set up. Edit its split, then add it.'**
  String get gxErrRecurringTemplateInvalid;

  /// No description provided for @gxErrGroupArchived.
  ///
  /// In en, this message translates to:
  /// **'This group is archived; restore it to make changes.'**
  String get gxErrGroupArchived;

  /// No description provided for @errorAlreadyMember.
  ///
  /// In en, this message translates to:
  /// **'Already a member, so nothing changed.'**
  String get errorAlreadyMember;

  /// No description provided for @gxErrConvertedTooSmall.
  ///
  /// In en, this message translates to:
  /// **'At this rate the amount in {currency} rounds to zero. Check the original amount and the rate.'**
  String gxErrConvertedTooSmall(String currency);

  /// No description provided for @privacyConsentOutdated.
  ///
  /// In en, this message translates to:
  /// **'The wording of this consent was updated (version {version}). We loaded it; try again.'**
  String privacyConsentOutdated(String version);

  /// No description provided for @moderationErrorAppealDecided.
  ///
  /// In en, this message translates to:
  /// **'This appeal was already decided. Reload to see the outcome.'**
  String get moderationErrorAppealDecided;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

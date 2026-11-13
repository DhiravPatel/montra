// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Montra';

  @override
  String get actionRetry => 'Try again';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionContinue => 'Continue';

  @override
  String get actionDone => 'Done';

  @override
  String get actionCopy => 'Copy';

  @override
  String get actionClose => 'Close';

  @override
  String get copiedToClipboard => 'Copied';

  @override
  String get loadingLabel => 'Loading';

  @override
  String requestReference(String requestId) {
    return 'Reference: $requestId';
  }

  @override
  String get copyReference => 'Copy reference';

  @override
  String get offlineBanner =>
      'You\'re offline. Changes can\'t be saved until you reconnect.';

  @override
  String get errorOfflineTitle => 'You\'re offline';

  @override
  String get errorOfflineBody =>
      'Check your internet connection and try again.';

  @override
  String get errorTimeout =>
      'Montra is taking too long to respond. Try again in a moment.';

  @override
  String get errorGenericTitle => 'Something went wrong';

  @override
  String get errorGenericBody =>
      'We couldn\'t complete that request. Try again in a moment.';

  @override
  String get errorServiceUnavailable =>
      'Montra is temporarily unavailable. Try again in a few minutes.';

  @override
  String get errorInvalidResponse =>
      'We received an unexpected response. Try again, and update the app if this keeps happening.';

  @override
  String get errorPermissionTitle => 'You don\'t have access';

  @override
  String get errorPermissionBody =>
      'You don\'t have permission to view or change this.';

  @override
  String get errorNotFound =>
      'We couldn\'t find that. It may have been removed.';

  @override
  String get errorConflict =>
      'This was changed somewhere else. Refresh and try again.';

  @override
  String get errorRateLimited =>
      'Too many attempts. Wait a moment and try again.';

  @override
  String errorRateLimitedRetry(String wait) {
    return 'Too many attempts. Try again in $wait.';
  }

  @override
  String get errorSessionEnded => 'Your session ended. Sign in again.';

  @override
  String get errorValidation => 'Some details need your attention.';

  @override
  String durationSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seconds',
      one: '1 second',
    );
    return '$_temp0';
  }

  @override
  String durationMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes',
      one: '1 minute',
    );
    return '$_temp0';
  }

  @override
  String shortSeconds(int count) {
    return '${count}s';
  }

  @override
  String shortMinutes(int count) {
    return '$count min';
  }

  @override
  String retryIn(String wait) {
    return 'Try again in $wait';
  }

  @override
  String get welcomeTagline =>
      'Understand your money, manage money together, and make better financial decisions.';

  @override
  String get welcomeFreeTitle => 'Free for everyone';

  @override
  String get welcomeFreeBody =>
      'Every feature is free. There are no paid tiers or locked features.';

  @override
  String get welcomePrivateTitle => 'Private by default';

  @override
  String get welcomePrivateBody =>
      'Your financial data is never sold and never shown publicly.';

  @override
  String get welcomeManualTitle => 'No bank linking needed';

  @override
  String get welcomeManualBody =>
      'Track your money by entering it yourself. Connecting a bank is never required.';

  @override
  String get welcomeCreateAccount => 'Create account';

  @override
  String get welcomeSignIn => 'I already have an account';

  @override
  String get emailLabel => 'Email address';

  @override
  String get passwordLabel => 'Password';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get validationEmailRequired => 'Enter your email address.';

  @override
  String get validationEmailInvalid => 'Enter a valid email address.';

  @override
  String get validationPasswordRequired => 'Enter your password.';

  @override
  String get signInTitle => 'Sign in';

  @override
  String get signInButton => 'Sign in';

  @override
  String get forgotPasswordLink => 'Forgot password?';

  @override
  String get noAccountPrompt => 'New to Montra?';

  @override
  String get createAccountLink => 'Create an account';

  @override
  String get signInInvalidCredentials => 'Incorrect email or password.';

  @override
  String get signInAccountLocked =>
      'This account is locked. Contact support to restore access.';

  @override
  String get signInThrottled =>
      'Too many failed sign-in attempts. Try again later or reset your password.';

  @override
  String signInThrottledRetry(String wait) {
    return 'Too many failed sign-in attempts. Try again in $wait, or reset your password.';
  }

  @override
  String get signInEmailNotVerifiedTitle => 'Verify your email to sign in';

  @override
  String get signInEmailNotVerifiedBody =>
      'We\'ve sent you a new verification link. Open it on this device, or paste it here.';

  @override
  String get sessionExpiredNotice =>
      'Your session ended. Sign in again to continue.';

  @override
  String get signedOutEverywhereNotice =>
      'You\'ve been signed out of all devices.';

  @override
  String get passwordResetNotice =>
      'Your password was changed. Sign in with your new password.';

  @override
  String get mfaTitle => 'Two-step verification';

  @override
  String get mfaBody => 'Enter the 6-digit code from your authenticator app.';

  @override
  String get mfaRecoveryBody =>
      'Enter one of the recovery codes you saved when you turned on two-step verification. Each code works once.';

  @override
  String get mfaCodeLabel => 'Verification code';

  @override
  String get mfaRecoveryLabel => 'Recovery code';

  @override
  String get mfaUseRecovery => 'Use a recovery code instead';

  @override
  String get mfaUseCode => 'Use an authenticator code instead';

  @override
  String get mfaVerifyButton => 'Verify';

  @override
  String get mfaStartOver => 'Start over';

  @override
  String get validationCodeRequired => 'Enter the 6-digit code.';

  @override
  String get validationCodeFormat => 'The code is 6 digits.';

  @override
  String get validationRecoveryRequired => 'Enter a recovery code.';

  @override
  String get mfaCodeInvalid =>
      'That code didn\'t work. Check your authenticator app and try again.';

  @override
  String get mfaRecoveryCodeInvalid =>
      'That recovery code didn\'t work. Check it and try again; each code works only once.';

  @override
  String get mfaChallengeExpired =>
      'This sign-in attempt expired. Enter your password to start again.';

  @override
  String get signUpTitle => 'Create your account';

  @override
  String get displayNameLabel => 'Name';

  @override
  String get displayNameHelp => 'What should Montra call you?';

  @override
  String get validationDisplayNameRequired => 'Enter a name.';

  @override
  String validationDisplayNameLength(int max) {
    return 'Use $max characters or fewer.';
  }

  @override
  String get passwordRulesTitle => 'Your password must';

  @override
  String passwordRuleLength(int min) {
    return 'Be at least $min characters long';
  }

  @override
  String get passwordRuleNotEmail => 'Not contain your email address';

  @override
  String get passwordRuleVariety => 'Use at least 4 different characters';

  @override
  String get passwordRuleCommon =>
      'Not be a commonly used password (checked when you submit)';

  @override
  String get passwordRuleMet => 'Done';

  @override
  String get passwordRuleNotMet => 'Not yet';

  @override
  String get passwordRuleServerChecked => 'Checked by Montra';

  @override
  String validationPasswordTooShort(int min) {
    return 'Use at least $min characters.';
  }

  @override
  String validationPasswordTooLong(int max) {
    return 'Use $max characters or fewer.';
  }

  @override
  String get currencyLabel => 'Main currency';

  @override
  String get currencyHelp => 'The currency you use most often.';

  @override
  String get currencyPickerTitle => 'Choose a currency';

  @override
  String get currencySearchHint => 'Search by name or code';

  @override
  String currencyNoResults(String query) {
    return 'No currencies match \"$query\".';
  }

  @override
  String get currencyLoadError => 'We couldn\'t load the list of currencies.';

  @override
  String get currencyNotChosen => 'Not chosen';

  @override
  String get validationCurrencyRequired => 'Choose a currency.';

  @override
  String get deviceSettingsTitle => 'Taken from this device';

  @override
  String deviceTimezone(String timezone) {
    return 'Time zone: $timezone';
  }

  @override
  String get deviceTimezoneUnknown =>
      'Time zone: not detected (Montra\'s default will be used)';

  @override
  String deviceLocale(String locale) {
    return 'Language and region: $locale';
  }

  @override
  String termsCheckbox(String version) {
    return 'I agree to the Terms of Service and Privacy Policy (version $version).';
  }

  @override
  String get termsLink => 'Read the Terms of Service';

  @override
  String get privacyLink => 'Read the Privacy Policy';

  @override
  String get validationTermsRequired =>
      'Accept the terms to create an account.';

  @override
  String get adultCheckbox => 'I\'m at least 18 years old.';

  @override
  String get validationAdultRequired =>
      'You must be at least 18 to use Montra.';

  @override
  String get signUpButton => 'Create account';

  @override
  String get signUpClosed =>
      'New sign-ups are paused right now. Please try again later.';

  @override
  String get haveAccountPrompt => 'Already have an account?';

  @override
  String get signInLink => 'Sign in';

  @override
  String get checkEmailTitle => 'Check your email';

  @override
  String checkEmailBody(String email) {
    return 'We\'ve sent a verification link to $email. Open it on this device to finish setting up your account.';
  }

  @override
  String get checkEmailBodyNoAddress =>
      'We\'ve sent you a verification link. Open it on this device to finish setting up your account.';

  @override
  String get checkEmailSpamHint =>
      'Can\'t find it? Check your spam or junk folder.';

  @override
  String get haveLinkButton => 'I have the link';

  @override
  String get resendEmailButton => 'Resend email';

  @override
  String resendEmailCooldown(String wait) {
    return 'Resend in $wait';
  }

  @override
  String get resendEmailSent =>
      'If your account needs verification, a new link is on its way.';

  @override
  String get backToSignIn => 'Back to sign in';

  @override
  String get verifyEmailTitle => 'Verify your email';

  @override
  String get verifyingEmail => 'Verifying your email…';

  @override
  String get verifyEmailSuccessTitle => 'Email verified';

  @override
  String get verifyEmailSuccessBody =>
      'Thanks for confirming your email address. You can now sign in.';

  @override
  String get verifyEmailSuccessSignedInBody =>
      'Thanks for confirming your email address.';

  @override
  String get verifyEmailExpired =>
      'This verification link is invalid or has expired. Request a new one below.';

  @override
  String get verifyEmailPasteBody =>
      'Paste the verification link from your email.';

  @override
  String get verifyEmailButton => 'Verify email';

  @override
  String get resendSectionTitle => 'Need a new link?';

  @override
  String get resendSectionBody =>
      'Enter your email address and we\'ll send a new verification link.';

  @override
  String get pasteLinkLabel => 'Link from the email';

  @override
  String get pasteFromClipboard => 'Paste from clipboard';

  @override
  String get validationLinkRequired => 'Paste the link from the email.';

  @override
  String get validationLinkInvalid =>
      'That doesn\'t look like a Montra link. Copy the whole link from the email.';

  @override
  String get validationLinkIsReset =>
      'This is a password reset link. Use it on the reset password screen.';

  @override
  String get validationLinkIsVerify =>
      'This is an email verification link. Use it on the verify email screen.';

  @override
  String get forgotTitle => 'Reset your password';

  @override
  String get forgotBody =>
      'Enter the email address for your account and we\'ll send you a link to choose a new password.';

  @override
  String get forgotButton => 'Send reset link';

  @override
  String get forgotSentTitle => 'Check your email';

  @override
  String forgotSentBody(String email) {
    return 'If an account exists for $email, a reset link is on its way. Open it on this device.';
  }

  @override
  String get resetTitle => 'Choose a new password';

  @override
  String get resetPasteBody => 'Paste the link from your password reset email.';

  @override
  String get newPasswordLabel => 'New password';

  @override
  String get confirmPasswordLabel => 'Confirm new password';

  @override
  String get validationConfirmPasswordRequired =>
      'Enter the new password again.';

  @override
  String get validationPasswordsDontMatch => 'The passwords don\'t match.';

  @override
  String get resetButton => 'Update password';

  @override
  String get resetSuccessTitle => 'Password updated';

  @override
  String get resetSuccessBody =>
      'Your password has been changed and every device was signed out. Sign in with your new password.';

  @override
  String get resetExpired =>
      'This reset link is invalid or has expired. Request a new one.';

  @override
  String get requestNewLink => 'Request a new link';

  @override
  String get splashRestoring => 'Signing you in…';

  @override
  String get splashRestoreFailedTitle => 'We couldn\'t reach Montra';

  @override
  String get splashRestoreFailedBody =>
      'You\'re still signed in on this device. Check your connection and try again.';

  @override
  String get splashSignOut => 'Sign out instead';

  @override
  String get notFoundTitle => 'Page not found';

  @override
  String get notFoundBody => 'This link isn\'t available in the app.';

  @override
  String get goHome => 'Go to Montra';

  @override
  String get configErrorTitle => 'Montra can\'t start';

  @override
  String get configErrorBody =>
      'This build of the app is not configured correctly. Please install an official build.';

  @override
  String get navProfile => 'Profile';

  @override
  String get profileTitle => 'Profile';

  @override
  String profileSignedInAs(String name) {
    return 'Signed in as $name';
  }

  @override
  String get emailVerifiedStatus => 'Email verified';

  @override
  String get emailNotVerifiedStatus => 'Email not verified';

  @override
  String get securityTitle => 'Security';

  @override
  String get securitySubtitle => 'Password, two-step verification and devices';

  @override
  String get appearanceTitle => 'Appearance';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get signOutButton => 'Sign out';

  @override
  String get signedOutOffline =>
      'You\'re signed out on this device. We couldn\'t reach Montra, so that session will end on its own when it expires.';

  @override
  String get statusOn => 'On';

  @override
  String get statusOff => 'Off';

  @override
  String get twoStepTitle => 'Two-step verification';

  @override
  String twoStepStatus(String status) {
    return 'Two-step verification: $status';
  }

  @override
  String get twoStepSubtitle =>
      'A code from an authenticator app when you sign in';

  @override
  String get sessionsTitle => 'Devices and sessions';

  @override
  String get sessionsSubtitle =>
      'See where you\'re signed in and sign out remotely';

  @override
  String get changePasswordTitle => 'Change password';

  @override
  String get changePasswordSubtitle => 'Other devices will be signed out';

  @override
  String get signOutEverywhereButton => 'Sign out of all devices';

  @override
  String get signOutEverywhereConfirmTitle => 'Sign out of all devices?';

  @override
  String get signOutEverywhereConfirmBody =>
      'You\'ll be signed out everywhere, including this device, and will need to sign in again.';

  @override
  String get signOutEverywhereConfirm => 'Sign out everywhere';

  @override
  String get sessionsEmpty => 'There are no active sessions.';

  @override
  String get sessionCurrentDevice => 'This device';

  @override
  String sessionLastActive(String time) {
    return 'Last active $time';
  }

  @override
  String sessionSignedInOn(String date) {
    return 'Signed in $date';
  }

  @override
  String get sessionTwoStepVerified => 'Verified with two-step verification';

  @override
  String get sessionClientAndroid => 'Android app';

  @override
  String get sessionClientIos => 'iPhone or iPad app';

  @override
  String get sessionClientWeb => 'Web browser';

  @override
  String get sessionClientUnknown => 'Unknown device';

  @override
  String get sessionRevoke => 'Sign out';

  @override
  String sessionRevokeLabel(String device) {
    return 'Sign out $device';
  }

  @override
  String get sessionRevokeConfirmTitle => 'Sign out this device?';

  @override
  String sessionRevokeConfirmBody(String device) {
    return '$device will be signed out and will need to sign in again.';
  }

  @override
  String get sessionRevoked => 'Device signed out.';

  @override
  String get sessionAlreadyEnded => 'That session had already ended.';

  @override
  String get relativeJustNow => 'just now';

  @override
  String relativeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes ago',
      one: '1 minute ago',
    );
    return '$_temp0';
  }

  @override
  String relativeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours ago',
      one: '1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String relativeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: 'yesterday',
    );
    return '$_temp0';
  }

  @override
  String get currentPasswordLabel => 'Current password';

  @override
  String get changePasswordButton => 'Change password';

  @override
  String get changePasswordSuccess =>
      'Password changed. Your other devices have been signed out.';

  @override
  String get twoStepIntro =>
      'Each time you sign in, you\'ll also enter a code from an authenticator app. This keeps your account safe even if someone learns your password.';

  @override
  String get twoStepSetupButton => 'Set up two-step verification';

  @override
  String get twoStepScanTitle => '1. Add Montra to your authenticator app';

  @override
  String get twoStepScanBody =>
      'Scan this QR code with an authenticator app on another device, or open the setup link with an authenticator app on this device.';

  @override
  String get twoStepQrSemantics =>
      'QR code for adding Montra to an authenticator app';

  @override
  String get twoStepOpenApp => 'Open in authenticator app';

  @override
  String get twoStepNoApp =>
      'No app on this device could open the setup link. Enter the setup key instead.';

  @override
  String get twoStepManualTitle => 'Or enter this setup key';

  @override
  String get twoStepCopyKey => 'Copy setup key';

  @override
  String get twoStepVerifyTitle => '2. Enter the 6-digit code it shows';

  @override
  String get twoStepActivateButton => 'Turn on two-step verification';

  @override
  String get twoStepCancelSetup => 'Cancel setup';

  @override
  String get twoStepEnabledBody =>
      'Two-step verification is on. You\'ll enter a code from your authenticator app when you sign in.';

  @override
  String get twoStepEnabledNotice => 'Two-step verification is on.';

  @override
  String get twoStepRegenerate => 'Generate new recovery codes';

  @override
  String get twoStepRegenerateConfirmTitle => 'Generate new recovery codes?';

  @override
  String get twoStepRegenerateConfirmBody =>
      'Your current recovery codes will stop working immediately.';

  @override
  String get twoStepRegenerateConfirm => 'Generate new codes';

  @override
  String get twoStepDisable => 'Turn off two-step verification';

  @override
  String get twoStepDisableBody =>
      'To turn off two-step verification, enter a code from your authenticator app or one of your recovery codes.';

  @override
  String get twoStepDisableConfirm => 'Turn off';

  @override
  String get twoStepDisabledNotice => 'Two-step verification is off.';

  @override
  String get twoStepDisableCodeRejected =>
      'That code didn\'t work. Each code works only once: if you just used it to confirm it\'s you, wait for the next code and try again, or use a recovery code.';

  @override
  String get recoveryCodesTitle => 'Save your recovery codes';

  @override
  String get recoveryCodesBody =>
      'If you lose access to your authenticator app, you can sign in with one of these codes. Each code works once. This is the only time they\'ll be shown.';

  @override
  String get recoveryCodesListLabel => 'Recovery codes';

  @override
  String get recoveryCodesCopy => 'Copy codes';

  @override
  String get recoveryCodesCopied =>
      'Recovery codes copied. Store them somewhere safe, such as a password manager.';

  @override
  String get recoveryCodesConfirm => 'I\'ve saved my recovery codes';

  @override
  String get recoveryCodesLeaveTitle => 'Leave without saving?';

  @override
  String get recoveryCodesLeaveBody =>
      'These codes won\'t be shown again. You can generate new ones later, which replaces them.';

  @override
  String get recoveryCodesLeave => 'Leave';

  @override
  String get recoveryCodesStay => 'Stay';

  @override
  String get reauthTitle => 'Confirm it\'s you';

  @override
  String get reauthBody =>
      'For your security, enter your password to continue.';

  @override
  String get reauthBodyWithCode =>
      'For your security, enter your password and a code from your authenticator app to continue.';

  @override
  String get reauthBodyWithRecovery =>
      'For your security, enter your password and one of your unused recovery codes to continue.';

  @override
  String get reauthButton => 'Confirm';

  @override
  String get reauthWrongPassword => 'The password is incorrect.';

  @override
  String get reauthCodeInvalid =>
      'Enter a valid code from your authenticator app.';

  @override
  String get reauthRecoveryInvalid => 'Enter an unused recovery code.';

  @override
  String get confirmDestructiveDefault => 'Confirm';

  @override
  String get errorStillSaving =>
      'Your last request is still being saved. Wait a moment, then check before trying again.';

  @override
  String get errorRequestChanged =>
      'This request changed while it was being sent. Review the details and save again.';

  @override
  String get versionConflictReloaded =>
      'This was changed somewhere else, so we loaded the latest version. Review it and make your change again.';

  @override
  String get moneyMinusWord => 'minus';

  @override
  String moneyInflowSemantics(String amount) {
    return 'received $amount';
  }

  @override
  String moneyOutflowSemantics(String amount) {
    return 'spent $amount';
  }

  @override
  String get amountRequired => 'Enter an amount.';

  @override
  String get amountInvalid => 'Enter a number, for example 1250.50.';

  @override
  String amountTooPrecise(int decimals) {
    String _temp0 = intl.Intl.pluralLogic(
      decimals,
      locale: localeName,
      other: '$decimals decimal places',
      one: '1 decimal place',
    );
    return 'Use at most $_temp0.';
  }

  @override
  String get amountNoDecimals => 'This currency has no decimal places.';

  @override
  String get amountNotPositive => 'Enter an amount greater than zero.';

  @override
  String get amountNegative => 'The amount can\'t be negative.';

  @override
  String get amountTooLarge => 'That amount is too large.';

  @override
  String get selectorNotChosen => 'Not chosen';

  @override
  String get selectorChangeHint => 'Double-tap to change';

  @override
  String selectorClear(String field) {
    return 'Clear $field';
  }

  @override
  String get selectedLabel => 'Selected';

  @override
  String get chartShowTable => 'Show as a list';

  @override
  String get chartShowChart => 'Show as a chart';

  @override
  String get actionSave => 'Save';

  @override
  String get actionEdit => 'Edit';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionRestore => 'Restore';

  @override
  String get actionAdd => 'Add';

  @override
  String get actionApply => 'Apply';

  @override
  String get actionReset => 'Reset';

  @override
  String get actionSeeAll => 'See all';

  @override
  String get actionSkip => 'Skip';

  @override
  String get actionBack => 'Back';

  @override
  String get actionNext => 'Next';

  @override
  String get actionMore => 'More options';

  @override
  String get actionClear => 'Clear';

  @override
  String get actionLoadMore => 'Load more';

  @override
  String optionalLabel(String field) {
    return '$field (optional)';
  }

  @override
  String get dateToday => 'Today';

  @override
  String refreshFailedStale(String time) {
    return 'We couldn\'t refresh. Showing figures from $time.';
  }

  @override
  String updatedAt(String time) {
    return 'Updated $time';
  }

  @override
  String get noneOption => 'None';

  @override
  String get searchHint => 'Search';

  @override
  String get validationRequired => 'This field is required.';

  @override
  String validationTooLong(int max) {
    return 'Use $max characters or fewer.';
  }

  @override
  String get offlineSaveHint =>
      'You\'re offline. We\'ll keep what you entered; save again when you\'re back online.';

  @override
  String possibleDuplicateNotice(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count other transactions',
      one: 'another transaction',
    );
    return 'This looks similar to $_temp0. Nothing was merged.';
  }

  @override
  String get possibleDuplicateReview => 'Review';

  @override
  String get starterFoodDining => 'Food & dining';

  @override
  String get starterGroceries => 'Groceries';

  @override
  String get starterTransport => 'Transport';

  @override
  String get starterFuel => 'Fuel';

  @override
  String get starterHousingRent => 'Housing & rent';

  @override
  String get starterUtilities => 'Utilities';

  @override
  String get starterShopping => 'Shopping';

  @override
  String get starterHealthcare => 'Healthcare';

  @override
  String get starterEducation => 'Education';

  @override
  String get starterEntertainment => 'Entertainment';

  @override
  String get starterTravel => 'Travel';

  @override
  String get starterPersonalCare => 'Personal care';

  @override
  String get starterInsurance => 'Insurance';

  @override
  String get starterTaxesFees => 'Taxes & fees';

  @override
  String get starterGiftsDonations => 'Gifts & donations';

  @override
  String get starterFamily => 'Family';

  @override
  String get starterWorkExpenses => 'Work expenses';

  @override
  String get starterSalary => 'Salary';

  @override
  String get starterFreelanceIncome => 'Freelance income';

  @override
  String get starterInterest => 'Interest';

  @override
  String get starterRefunds => 'Refunds';

  @override
  String get starterOther => 'Other';

  @override
  String subcategoryOf(String name, String parent) {
    return '$name, subcategory of $parent';
  }

  @override
  String get categoryPickerTitle => 'Choose a category';

  @override
  String get categoryPickerEmpty => 'There are no categories to choose from.';

  @override
  String get categoryNone => 'No category';

  @override
  String get categoryUncategorized => 'Uncategorized';

  @override
  String get selectionEmpty => 'There\'s nothing to choose yet.';

  @override
  String selectionNoMatches(String query) {
    return 'Nothing matches \"$query\".';
  }

  @override
  String get tagPickerTitle => 'Choose a tag';

  @override
  String get tagPickerEmpty =>
      'You don\'t have any tags yet. Type a name to create one.';

  @override
  String tagCreate(String name) {
    return 'Create tag \"$name\"';
  }

  @override
  String tagUsage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Used $count times',
      one: 'Used once',
      zero: 'Not used yet',
    );
    return '$_temp0';
  }

  @override
  String get merchantPickerTitle => 'Choose a merchant';

  @override
  String get merchantSearchLabel => 'Search or type a new name';

  @override
  String get merchantSearchPrompt =>
      'Type a few letters to find a merchant you\'ve used before.';

  @override
  String merchantUseName(String name) {
    return 'Use \"$name\"';
  }

  @override
  String get merchantUseNameHelp =>
      'Matched to an existing merchant or added as a new one';

  @override
  String get merchantNone => 'No merchant';

  @override
  String merchantNoMatches(String query) {
    return 'No saved merchants match \"$query\".';
  }

  @override
  String merchantTransactionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions',
      one: '1 transaction',
      zero: 'No transactions',
    );
    return '$_temp0';
  }

  @override
  String get accountTypeCash => 'Cash wallet';

  @override
  String get accountTypeBank => 'Bank account';

  @override
  String get accountTypeSavings => 'Savings account';

  @override
  String get accountTypeCreditCard => 'Credit card';

  @override
  String get accountTypeDebitCard => 'Debit card';

  @override
  String get accountTypePrepaidCard => 'Prepaid card';

  @override
  String get accountTypeDigitalWallet => 'Digital wallet';

  @override
  String get accountTypeUpi => 'UPI / payment wallet';

  @override
  String get accountTypeLoan => 'Loan';

  @override
  String get accountTypeInvestment => 'Investment';

  @override
  String get accountTypeHouseholdLedger => 'Household ledger';

  @override
  String get accountTypeCustom => 'Other account';

  @override
  String get balanceSourceManual => 'Entered by you';

  @override
  String get balanceSourceCalculated => 'Calculated from your entries';

  @override
  String get balanceSourceImported => 'From imported statements';

  @override
  String get balanceSourceProvider => 'Synced from a provider';

  @override
  String get accountStatusActive => 'Active';

  @override
  String get accountStatusArchived => 'Archived';

  @override
  String get accountStatusClosed => 'Closed';

  @override
  String get accountPickerTitle => 'Choose an account';

  @override
  String get accountPickerEmpty =>
      'You don\'t have an active account yet. Add one from Profile → Accounts.';

  @override
  String get balanceOwed => 'Owed';

  @override
  String get balanceInCredit => 'In credit';

  @override
  String get balanceOverdrawn => 'Overdrawn';

  @override
  String get accountBalanceLabel => 'Balance';

  @override
  String get accountSharedReadOnly => 'Shared with you · read-only';

  @override
  String get accountNotInOverview => 'Not in overview';

  @override
  String get accountsTitle => 'Accounts';

  @override
  String get accountAdd => 'Add account';

  @override
  String get accountAddFirst => 'Add your first account';

  @override
  String get accountsShowArchived => 'Show archived and closed accounts';

  @override
  String get accountsEmptyTitle => 'No accounts yet';

  @override
  String get accountsEmptyBody =>
      'Add a cash wallet, bank account or card to start tracking. You never need to connect a bank.';

  @override
  String accountGroupHeading(String type, int count) {
    return '$type ($count)';
  }

  @override
  String get accountsTotalsTitle => 'Totals (tracked)';

  @override
  String currencyHeading(String currency) {
    return 'In $currency';
  }

  @override
  String get netWorthLabel => 'Net worth';

  @override
  String get assetsLabel => 'Assets';

  @override
  String get liabilitiesLabel => 'Owed on cards and loans';

  @override
  String get trackedBalanceNote =>
      'Balances are tracked from your entries and imports. They are not verified by a bank.';

  @override
  String get providerBalanceNote =>
      'This balance is synced from a connected provider.';

  @override
  String get accountDetailTitle => 'Account';

  @override
  String get accountAdjustBalance => 'Adjust balance';

  @override
  String get accountArchive => 'Archive';

  @override
  String get accountClose => 'Close account';

  @override
  String get accountArchiveConfirmTitle => 'Archive this account?';

  @override
  String accountArchiveConfirmBody(String name) {
    return '$name and its history stay in your reports, but you can\'t add new transactions to it until you restore it.';
  }

  @override
  String get accountCloseConfirmTitle => 'Close this account?';

  @override
  String accountCloseConfirmBody(String name) {
    return '$name will be marked closed and kept in your history. Only an account with a zero balance can be closed. You can restore it later.';
  }

  @override
  String get accountArchived => 'Account archived.';

  @override
  String get accountRestored => 'Account restored.';

  @override
  String get accountClosed => 'Account closed.';

  @override
  String get accountArchivedNotice =>
      'This account is archived. Its history is kept; restore it to add transactions.';

  @override
  String get accountClosedNotice =>
      'This account is closed. Its history is kept; restore it to use it again.';

  @override
  String get creditLimitLabel => 'Credit limit';

  @override
  String get availableCreditLabel => 'Available credit';

  @override
  String get statementDayLabel => 'Statement day';

  @override
  String get paymentDueDayLabel => 'Payment due day';

  @override
  String dayOfMonth(int day) {
    return 'Day $day of the month';
  }

  @override
  String get notSetLabel => 'Not set';

  @override
  String get transactionAddExpense => 'Add expense';

  @override
  String get transactionAddIncome => 'Add income';

  @override
  String get transferAdd => 'Transfer';

  @override
  String get balanceHistoryTitle => 'Balance over the last 30 days';

  @override
  String get balanceHistoryEmpty => 'There\'s no balance history yet.';

  @override
  String balanceHistorySummary(
    String fromDate,
    String fromAmount,
    String toDate,
    String toAmount,
    String low,
    String high,
  ) {
    return 'The balance went from $fromAmount on $fromDate to $toAmount on $toDate. Lowest $low, highest $high.';
  }

  @override
  String get recentTransactionsTitle => 'Recent transactions';

  @override
  String accountSeeAllTransactions(String name) {
    return 'See all transactions in $name';
  }

  @override
  String get accountNoTransactions => 'No transactions in this account yet.';

  @override
  String get accountDetailsTitle => 'Details';

  @override
  String get currencyFieldLabel => 'Currency';

  @override
  String get openingDateLabel => 'Opening date';

  @override
  String get includeInOverviewLabel => 'Include in overview';

  @override
  String get includeInOverviewHelp => 'Counts towards the balances on Home.';

  @override
  String get lastReconciledLabel => 'Last reconciled';

  @override
  String get lastImportLabel => 'Last import';

  @override
  String get notesLabel => 'Notes';

  @override
  String get colorTeal => 'Teal';

  @override
  String get colorBlue => 'Blue';

  @override
  String get colorPurple => 'Purple';

  @override
  String get colorRose => 'Rose';

  @override
  String get colorOrange => 'Orange';

  @override
  String get colorSand => 'Sand';

  @override
  String get colorGreen => 'Green';

  @override
  String get colorGrey => 'Grey';

  @override
  String get colorNone => 'No color';

  @override
  String get accountNewTitle => 'New account';

  @override
  String get accountEditTitle => 'Edit account';

  @override
  String get accountCreated => 'Account added.';

  @override
  String get accountSaved => 'Account saved.';

  @override
  String get accountNameLabel => 'Account name';

  @override
  String get accountNameHelp => 'For example \"HDFC savings\" or \"Wallet\".';

  @override
  String get accountTypeLabel => 'Type';

  @override
  String get accountTypeFixed =>
      'The type can\'t change after the account is created.';

  @override
  String get accountCurrencyChangeHelp =>
      'You can change the currency only until the first transaction is recorded.';

  @override
  String get openingBalanceSection => 'Opening balance';

  @override
  String get openingOwed => 'I owe this';

  @override
  String get openingInCredit => 'It\'s in credit';

  @override
  String get openingOwedLabel => 'Amount owed now';

  @override
  String get openingCreditLabel => 'Credit balance now';

  @override
  String get openingBalanceLabel => 'Balance now';

  @override
  String get openingBalanceHelp =>
      'Leave empty to start at zero. Use a minus sign if the account is overdrawn.';

  @override
  String get openingLiabilityHelp => 'Leave empty if nothing is owed.';

  @override
  String get accountMoreDetails => 'More details';

  @override
  String get institutionLabel => 'Bank or provider name';

  @override
  String get maskedNumberLabel => 'Last digits';

  @override
  String get maskedNumberHelp =>
      'Only the last 2–4 digits. Never enter a full card or account number, CVV or PIN.';

  @override
  String get maskedNumberInvalid => 'Enter 2 to 4 digits.';

  @override
  String get accountColorLabel => 'Color';

  @override
  String get accountCreateButton => 'Add account';

  @override
  String get adjustTitle => 'Adjust balance';

  @override
  String adjustIntro(String name) {
    return 'If $name doesn\'t match your bank or wallet, record a correction. It\'s saved as an adjustment with your reason, so your history stays complete.';
  }

  @override
  String get adjustCurrentBalance => 'Current tracked balance';

  @override
  String get adjustModeTarget => 'Set the balance';

  @override
  String get adjustModeDelta => 'Change by';

  @override
  String get adjustTargetLabel => 'Correct balance';

  @override
  String get adjustDeltaLabel => 'Change';

  @override
  String get adjustTargetHelp =>
      'The balance the account should show. Use a minus sign for an overdraft.';

  @override
  String get adjustTargetLiabilityHelp =>
      'For a card or loan, enter what you owe as a negative number, for example -2500.';

  @override
  String get adjustDeltaHelp => 'Positive adds money, negative removes it.';

  @override
  String get adjustReasonLabel => 'Reason';

  @override
  String get adjustReasonHelp =>
      'Kept in the account\'s history, for example \"Matched bank app\".';

  @override
  String get adjustReasonTooShort => 'Enter a reason of at least 3 characters.';

  @override
  String get adjustDateLabel => 'Effective date';

  @override
  String get adjustButton => 'Save adjustment';

  @override
  String get adjustDone => 'Balance adjusted.';

  @override
  String get paymentKindCash => 'Cash';

  @override
  String get paymentKindUpi => 'UPI';

  @override
  String get paymentKindDebitCard => 'Debit card';

  @override
  String get paymentKindCreditCard => 'Credit card';

  @override
  String get paymentKindBankTransfer => 'Bank transfer';

  @override
  String get paymentKindWallet => 'Wallet';

  @override
  String get paymentKindCheque => 'Cheque';

  @override
  String get paymentKindOther => 'Other';

  @override
  String get paymentNetworkOther => 'Other network';

  @override
  String get paymentDefault => 'Default';

  @override
  String get paymentPickerTitle => 'Choose a payment method';

  @override
  String get paymentPickerEmpty =>
      'You haven\'t added any payment methods yet.';

  @override
  String get paymentNone => 'No payment method';

  @override
  String get paymentMethodsTitle => 'Payment methods';

  @override
  String get paymentMethodsIntro =>
      'Record how you paid, such as UPI, cash or a card. Store only a label and the last digits — never full card numbers, CVVs or PINs.';

  @override
  String get paymentShowArchived => 'Show archived methods';

  @override
  String get paymentEmptyTitle => 'No payment methods yet';

  @override
  String get paymentEmptyBody =>
      'Add the ways you pay to filter and review spending by method.';

  @override
  String get paymentAdd => 'Add payment method';

  @override
  String paymentLinkedTo(String account) {
    return 'Linked to $account';
  }

  @override
  String get paymentRemove => 'Remove';

  @override
  String paymentRemoveLabel(String label) {
    return 'Remove $label';
  }

  @override
  String get paymentRemoveConfirmTitle => 'Remove this payment method?';

  @override
  String paymentRemoveConfirmBody(String label) {
    return '$label will no longer be offered. If transactions already use it, it\'s archived so their history stays intact.';
  }

  @override
  String get paymentRemoved => 'Payment method removed.';

  @override
  String get paymentNewTitle => 'New payment method';

  @override
  String get paymentEditTitle => 'Edit payment method';

  @override
  String get paymentCreated => 'Payment method added.';

  @override
  String get paymentSaved => 'Payment method saved.';

  @override
  String get paymentKindLabel => 'Kind';

  @override
  String get paymentLabelLabel => 'Name';

  @override
  String get paymentLabelHelp =>
      'For example \"GPay\" or \"HDFC credit card\".';

  @override
  String get paymentHintLabel => 'Masked hint';

  @override
  String get paymentHintHelp =>
      'Last digits or a masked UPI handle only, for example •••• 4821.';

  @override
  String get paymentHintTooManyDigits =>
      'Use at most 4 digits. Never enter full card or account numbers, CVVs or PINs.';

  @override
  String get paymentNetworkLabel => 'Network';

  @override
  String get paymentAccountLabel => 'Paid from account';

  @override
  String get paymentAccountHelp =>
      'Optional link to the account this method draws from.';

  @override
  String get paymentAccountUnknown => 'Account not available';

  @override
  String get paymentMakeDefault => 'Use as default';

  @override
  String get navHome => 'Home';

  @override
  String get navTransactions => 'Transactions';

  @override
  String get txTypeExpense => 'Expense';

  @override
  String get txTypeIncome => 'Income';

  @override
  String get txTypeTransfer => 'Transfer';

  @override
  String get txTypeRefund => 'Refund';

  @override
  String get txTypeReimbursement => 'Reimbursement';

  @override
  String get txTypeAdjustment => 'Balance adjustment';

  @override
  String get txTypeOpeningBalance => 'Opening balance';

  @override
  String get txTypeGroupExpense => 'Group expense';

  @override
  String get txTypeSettlement => 'Settlement';

  @override
  String get txTypeOther => 'Transaction';

  @override
  String get txStatusDraft => 'Draft';

  @override
  String get txStatusPending => 'Pending';

  @override
  String get txStatusPosted => 'Posted';

  @override
  String get txStatusDeleted => 'Deleted';

  @override
  String get txStatusReversed => 'Reversed';

  @override
  String get txSourceManual => 'Entered by you';

  @override
  String get txSourceImport => 'Statement import';

  @override
  String get txSourceReceipt => 'Receipt';

  @override
  String get txSourceRecurring => 'Recurring rule';

  @override
  String get txSourceIntegration => 'Connected provider';

  @override
  String get txSourceCorrection => 'Correction';

  @override
  String get txSourceGroup => 'Group';

  @override
  String get txSourceSystem => 'Montra';

  @override
  String get reconUnreconciled => 'Not reconciled';

  @override
  String get reconMatched => 'Matched';

  @override
  String get reconReconciled => 'Reconciled';

  @override
  String get reconExcluded => 'Excluded from reconciliation';

  @override
  String txRefundedAmount(String amount) {
    return 'Refunded $amount';
  }

  @override
  String get quickAddTitle => 'Add a transaction';

  @override
  String get quickAddExpenseHelp => 'Money you spent';

  @override
  String get quickAddIncomeHelp => 'Money you received';

  @override
  String get quickAddTransferHelp => 'Move money between your own accounts';

  @override
  String get transactionsSearchHint => 'Search description, notes or merchant';

  @override
  String get searchOpen => 'Search transactions';

  @override
  String get searchClose => 'Close search';

  @override
  String get filtersTitle => 'Filters';

  @override
  String filtersActiveTooltip(int count) {
    return 'Filters, $count active';
  }

  @override
  String get filtersApply => 'Show results';

  @override
  String get filtersClearAll => 'Clear filters';

  @override
  String filterRemove(String label) {
    return 'Remove filter $label';
  }

  @override
  String get filterDates => 'Dates';

  @override
  String get filterType => 'Type';

  @override
  String get filterDirection => 'Money in or out';

  @override
  String get directionIn => 'Money in';

  @override
  String get directionOut => 'Money out';

  @override
  String get filterAny => 'Any';

  @override
  String get filterOneSelected => '1 selected';

  @override
  String get filterAccounts => 'Accounts';

  @override
  String filterAccountsCount(int count) {
    return '$count accounts';
  }

  @override
  String get filterCategories => 'Categories';

  @override
  String filterCategoriesCount(int count) {
    return '$count categories';
  }

  @override
  String get filterTags => 'Tags';

  @override
  String filterTagsCount(int count) {
    return '$count tags';
  }

  @override
  String get filterMerchant => 'Merchant';

  @override
  String get filterPaymentMethod => 'Payment method';

  @override
  String get filterAmount => 'Amount';

  @override
  String get filterAmountCurrency => 'Currency for the amount range';

  @override
  String get filterMinAmount => 'At least';

  @override
  String get filterMaxAmount => 'At most';

  @override
  String filterAmountChip(String min, String max, String currency) {
    return 'Amount $min to $max $currency';
  }

  @override
  String get filterMore => 'More filters';

  @override
  String get filterStatus => 'Status';

  @override
  String get filterStatusActive => 'Active (not deleted)';

  @override
  String get filterStatusDeleted => 'Deleted only';

  @override
  String get filterStatusAll => 'All, including deleted';

  @override
  String get filterSource => 'Source';

  @override
  String get filterReconciliation => 'Reconciliation';

  @override
  String get filterHasAttachment => 'Has attachments';

  @override
  String get filterWithAttachments => 'With attachments';

  @override
  String get filterWithoutAttachments => 'Without attachments';

  @override
  String get filterRecurring => 'From a recurring rule';

  @override
  String get filterRecurringOnly => 'Recurring only';

  @override
  String get filterNotRecurring => 'Not recurring';

  @override
  String get filterYes => 'Yes';

  @override
  String get filterNo => 'No';

  @override
  String get filterSort => 'Sort by';

  @override
  String get sortDateDesc => 'Newest first';

  @override
  String get sortDateAsc => 'Oldest first';

  @override
  String get sortAmountDesc => 'Largest amount first';

  @override
  String get sortAmountAsc => 'Smallest amount first';

  @override
  String get rangePickerTitle => 'Choose dates';

  @override
  String get rangeToday => 'Today';

  @override
  String get rangeYesterday => 'Yesterday';

  @override
  String get rangeThisWeek => 'This week';

  @override
  String get rangeLastWeek => 'Last week';

  @override
  String get rangeThisMonth => 'This month';

  @override
  String get rangeLastMonth => 'Last month';

  @override
  String get rangeThisYear => 'This year';

  @override
  String get rangeLastYear => 'Last year';

  @override
  String get rangeLast7Days => 'Last 7 days';

  @override
  String get rangeLast30Days => 'Last 30 days';

  @override
  String get rangeLast90Days => 'Last 90 days';

  @override
  String get rangeCustom => 'Custom dates';

  @override
  String get rangeAnyTime => 'Any time';

  @override
  String rangeFrom(String date) {
    return 'From $date';
  }

  @override
  String rangeUntil(String date) {
    return 'Until $date';
  }

  @override
  String get transactionsEmptyTitle => 'No transactions yet';

  @override
  String get transactionsEmptyBody =>
      'Add what you spend and receive to see where your money goes. No bank connection needed.';

  @override
  String get transactionAddFirst => 'Add an expense';

  @override
  String get transactionsNoMatchTitle => 'No transactions match';

  @override
  String get transactionsNoMatchBody =>
      'Try other dates or remove some filters.';

  @override
  String transactionsEnd(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'That\'s all $count transactions.',
      one: 'That\'s 1 transaction.',
    );
    return '$_temp0';
  }

  @override
  String get loadingMore => 'Loading more transactions';

  @override
  String selectionCount(int count) {
    return '$count selected';
  }

  @override
  String get selectionCancel => 'Cancel selection';

  @override
  String get bulkEditTitle => 'Change selected';

  @override
  String bulkEditTitleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Change $count transactions',
      one: 'Change 1 transaction',
    );
    return '$_temp0';
  }

  @override
  String get bulkSetCategory => 'Set category';

  @override
  String get bulkClearCategory => 'Remove category';

  @override
  String get bulkAddTags => 'Add tags';

  @override
  String get bulkRemoveTags => 'Remove tags';

  @override
  String get bulkMoveAccount => 'Move to another account';

  @override
  String get bulkMoveAccountHelp =>
      'Only to an account with the same currency. Transfers can\'t be moved.';

  @override
  String bulkSetCategoryConfirm(int count, String category) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions',
      one: '1 transaction',
    );
    return 'Set the category of $_temp0 to $category?';
  }

  @override
  String bulkClearCategoryConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions',
      one: '1 transaction',
    );
    return 'Remove the category from $_temp0?';
  }

  @override
  String bulkAddTagsConfirm(int count, int tags) {
    String _temp0 = intl.Intl.pluralLogic(
      tags,
      locale: localeName,
      other: '$tags tags',
      one: '1 tag',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions',
      one: '1 transaction',
    );
    return 'Add $_temp0 to $_temp1?';
  }

  @override
  String bulkRemoveTagsConfirm(int count, int tags) {
    String _temp0 = intl.Intl.pluralLogic(
      tags,
      locale: localeName,
      other: '$tags tags',
      one: '1 tag',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions',
      one: '1 transaction',
    );
    return 'Remove $_temp0 from $_temp1?';
  }

  @override
  String bulkMoveConfirm(int count, String account) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions',
      one: '1 transaction',
    );
    return 'Move $_temp0 to $account?';
  }

  @override
  String bulkUpdated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions updated.',
      one: '1 transaction updated.',
    );
    return '$_temp0';
  }

  @override
  String get bulkDeleteTooltip => 'Delete selected';

  @override
  String bulkDeleteConfirmTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete $count transactions?',
      one: 'Delete 1 transaction?',
    );
    return '$_temp0';
  }

  @override
  String get bulkDeleteConfirmBody =>
      'They\'re removed from balances and reports. Nothing is erased: you can find them with the Deleted filter and restore them.';

  @override
  String bulkDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions deleted.',
      one: '1 transaction deleted.',
    );
    return '$_temp0';
  }

  @override
  String get amountLabel => 'Amount';

  @override
  String get amountChooseAccountFirst =>
      'Choose the account first to set the currency.';

  @override
  String get accountFieldLabel => 'Account';

  @override
  String get accountFieldPlaceholder => 'Choose an account';

  @override
  String get validationAccountRequired => 'Choose an account.';

  @override
  String get moveAccountHelp =>
      'You can move it to another account with the same currency.';

  @override
  String get dateLabel => 'Date';

  @override
  String get categoryFieldLabel => 'Category';

  @override
  String get merchantFieldLabel => 'Merchant';

  @override
  String get merchantNewHelp =>
      'New merchant: matched to an existing one with the same name, or added.';

  @override
  String get paymentMethodFieldLabel => 'Payment method';

  @override
  String get tagsLabel => 'Tags';

  @override
  String get tagAdd => 'Add tag';

  @override
  String tagRemove(String name) {
    return 'Remove tag $name';
  }

  @override
  String get descriptionLabel => 'Description';

  @override
  String get notesPrivacyHelp =>
      'Never write card numbers, CVVs, PINs or OTPs here.';

  @override
  String get moreOptions => 'More options';

  @override
  String get statusLabel => 'Status';

  @override
  String get foreignCurrencyToggle => 'Paid in another currency';

  @override
  String get foreignCurrencyHelp =>
      'Enter the amount your account was charged above, and the original amount here.';

  @override
  String get originalCurrencyLabel => 'Original currency';

  @override
  String get originalAmountLabel => 'Original amount';

  @override
  String get originalAmountHelp =>
      'The amount in the currency you actually paid.';

  @override
  String get fxFeeLabel => 'Currency conversion fee';

  @override
  String get fxFeeHelp => 'Part of the amount above, for your records.';

  @override
  String get fxRateLabel => 'Exchange rate';

  @override
  String rateWithSource(String rate, String source) {
    return '$rate ($source)';
  }

  @override
  String get expenseNewTitle => 'New expense';

  @override
  String get incomeNewTitle => 'New income';

  @override
  String get transactionEditTitle => 'Edit transaction';

  @override
  String transactionLimitedEdit(String type) {
    return 'This is a $type. Only the description, notes, merchant and tags can be changed here.';
  }

  @override
  String get expenseSaved => 'Expense saved.';

  @override
  String get incomeSaved => 'Income saved.';

  @override
  String get transactionSaved => 'Transaction saved.';

  @override
  String get transactionDetailTitle => 'Transaction';

  @override
  String get transactionDeletedNotice =>
      'This transaction is deleted. It doesn\'t count in balances or reports until you restore it.';

  @override
  String get transactionSharedReadOnly =>
      'This transaction belongs to an account shared with you. You can view it but not change it.';

  @override
  String get transactionDeleteConfirmTitle => 'Delete this transaction?';

  @override
  String get transactionDeleteConfirmBody =>
      'It\'s removed from balances and reports. Nothing is erased; you can restore it later.';

  @override
  String get transactionDeleteTransferBody =>
      'This is part of a transfer. Deleting it deletes the whole transfer: both accounts and any fee. You can restore it later.';

  @override
  String get transactionDeleted => 'Transaction deleted.';

  @override
  String get transactionRestored => 'Transaction restored.';

  @override
  String get duplicateAction => 'Duplicate';

  @override
  String get duplicateDateTitle => 'Date for the copy';

  @override
  String get duplicateConfirm => 'Create copy';

  @override
  String get duplicateCreated => 'Copy created.';

  @override
  String get refundAction => 'Record a refund';

  @override
  String get reimbursementAction => 'Record a reimbursement';

  @override
  String personalShareLabel(String amount) {
    return 'Your share: $amount';
  }

  @override
  String get correctionLabel => 'Correction';

  @override
  String get partOfTransfer => 'Part of a transfer';

  @override
  String get partOfTransferHelp => 'See both accounts and any fee';

  @override
  String get refundOf => 'Refund of an expense';

  @override
  String get reimbursementOf => 'Reimbursement of an expense';

  @override
  String get groupLinkedRecord => 'Linked to a group';

  @override
  String get groupLinkedRecordHelp =>
      'Changes come from the group and follow it automatically.';

  @override
  String get locationLabel => 'Location';

  @override
  String get sourceLabel => 'Added by';

  @override
  String get reconciliationLabel => 'Reconciliation';

  @override
  String get createdLabel => 'Created';

  @override
  String get updatedLabel => 'Last changed';

  @override
  String get attachmentsTitle => 'Attachments';

  @override
  String get attachmentsEmpty => 'No files are attached.';

  @override
  String get attachmentUnnamed => 'Unnamed file';

  @override
  String attachedOn(String time) {
    return 'Attached $time';
  }

  @override
  String get attachmentRemove => 'Remove';

  @override
  String attachmentRemoveLabel(String name) {
    return 'Remove $name from this transaction';
  }

  @override
  String get attachmentRemoveConfirmTitle => 'Remove this attachment?';

  @override
  String attachmentRemoveConfirmBody(String name) {
    return '$name will no longer be attached to this transaction.';
  }

  @override
  String get attachmentRemoved => 'Attachment removed.';

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
  String get historyTitle => 'History';

  @override
  String get historyEmpty => 'No changes recorded.';

  @override
  String auditWhenWho(String time, String who) {
    return '$time · $who';
  }

  @override
  String get auditActorYou => 'by you';

  @override
  String get auditActorMontra => 'by Montra';

  @override
  String get auditCreated => 'Created';

  @override
  String get auditUpdated => 'Changed';

  @override
  String get auditVoided => 'Deleted';

  @override
  String get auditRestored => 'Restored';

  @override
  String get auditDuplicated => 'Created as a copy';

  @override
  String get auditBulkUpdated => 'Changed with others';

  @override
  String get auditAttachmentAdded => 'File attached';

  @override
  String get auditAttachmentRemoved => 'File removed';

  @override
  String get auditRuleCategorized => 'Categorized by a rule';

  @override
  String get auditRefundAdded => 'Refund recorded';

  @override
  String get auditReimbursementAdded => 'Reimbursement recorded';

  @override
  String get auditTagsAdded => 'Tags added';

  @override
  String get auditTagsRemoved => 'Tags removed';

  @override
  String auditChanged(String field) {
    return '$field changed';
  }

  @override
  String auditChangedFromTo(String field, String from, String to) {
    return '$field: $from → $to';
  }

  @override
  String auditLinkedAmount(String amount) {
    return 'Amount: $amount';
  }

  @override
  String get refundTitle => 'Record a refund';

  @override
  String get reimbursementTitle => 'Record a reimbursement';

  @override
  String get refundOriginalTitle => 'Original expense';

  @override
  String get refundOriginalLabel => 'Expense';

  @override
  String get refundAlreadyLabel => 'Already refunded or reimbursed';

  @override
  String get refundCapNote =>
      'Refunds and reimbursements together can\'t be more than the original amount. Montra checks this when you save.';

  @override
  String get refundHelp =>
      'Money the seller gave back. It reduces your spending.';

  @override
  String get reimbursementHelp =>
      'Money someone paid you back, such as an employer. It reduces your spending.';

  @override
  String get refundAmountLabel => 'Amount returned';

  @override
  String get refundAccountLabel => 'Received in';

  @override
  String get refundAccountHelp =>
      'Defaults to the account of the original expense.';

  @override
  String get refundCorrectionLabel => 'This is a correction';

  @override
  String get refundCorrectionHelp =>
      'Allows more than the original amount, for example to fix a wrong original. Use only on purpose.';

  @override
  String get refundNotAllowedTitle => 'This can\'t be refunded';

  @override
  String get refundNotAllowedBody =>
      'Only your own expenses that aren\'t deleted can get a refund or reimbursement.';

  @override
  String get refundSave => 'Save refund';

  @override
  String get reimbursementSave => 'Save reimbursement';

  @override
  String get refundSaved => 'Refund saved.';

  @override
  String get reimbursementSaved => 'Reimbursement saved.';

  @override
  String get transferNewTitle => 'New transfer';

  @override
  String get transferIntro =>
      'Move money between your own accounts. Transfers aren\'t counted as income or spending.';

  @override
  String get transferFromLabel => 'From';

  @override
  String get transferToLabel => 'To';

  @override
  String get transferAmountLabel => 'Amount sent';

  @override
  String get transferAmountHelp => 'In the currency of the account it leaves.';

  @override
  String get transferFxSection => 'Different currencies';

  @override
  String transferFxHelp(String from, String to) {
    return 'Money leaves in $from and arrives in $to. Enter what arrived, or the exchange rate.';
  }

  @override
  String get transferFxReceived => 'Amount received';

  @override
  String get transferFxRate => 'Exchange rate';

  @override
  String get transferToAmountLabel => 'Amount received';

  @override
  String transferRateLabel(String from, String to) {
    return '$to per 1 $from';
  }

  @override
  String get transferRateHelp => 'An exact rate such as 0.0119.';

  @override
  String get transferRateInvalid => 'Enter a positive rate, for example 83.12.';

  @override
  String get transferFeeLabel => 'Fee';

  @override
  String get transferFeeHelp =>
      'Charged to the account the money leaves. Saved as a separate expense.';

  @override
  String get transferSave => 'Save transfer';

  @override
  String get transferSaved => 'Transfer saved.';

  @override
  String get transferDetailTitle => 'Transfer';

  @override
  String transferBetween(String from, String to) {
    return '$from → $to';
  }

  @override
  String get transferNotIncomeNote =>
      'Transfers move your own money, so they aren\'t counted as income or spending.';

  @override
  String transferSentFrom(String account) {
    return 'Sent from $account';
  }

  @override
  String transferReceivedIn(String account) {
    return 'Received in $account';
  }

  @override
  String transferRateShown(String from, String to) {
    return 'Exchange rate ($to per $from)';
  }

  @override
  String get transferLegsTitle => 'Recorded as';

  @override
  String get transferLegOut => 'Money out of the first account';

  @override
  String get transferLegIn => 'Money into the second account';

  @override
  String get transferVoidedNotice =>
      'This transfer is deleted. Neither account counts it until you restore it.';

  @override
  String get transferDelete => 'Delete transfer';

  @override
  String get transferDeleteConfirmTitle => 'Delete this transfer?';

  @override
  String get transferDeleteConfirmBody =>
      'Both sides are removed together. Nothing is erased; you can restore it later.';

  @override
  String get transferDeleteConfirmBodyFee =>
      'Both sides and the fee are removed together. Nothing is erased; you can restore it later.';

  @override
  String get transferDeleted => 'Transfer deleted.';

  @override
  String get transferRestore => 'Restore transfer';

  @override
  String get transferRestored => 'Transfer restored.';

  @override
  String get widgetBalances => 'Balances';

  @override
  String get widgetBalancesHelp =>
      'Tracked net worth, assets and what you owe, per currency';

  @override
  String get widgetCashFlow => 'Cash flow';

  @override
  String get widgetCashFlowHelp =>
      'Income, spending and net cash flow for the period';

  @override
  String get widgetIncomeVsExpense => 'Income vs spending';

  @override
  String get widgetIncomeVsExpenseHelp => 'A chart comparing money in and out';

  @override
  String get widgetCashFlowTrend => 'Cash-flow trend';

  @override
  String get widgetCashFlowTrendHelp => 'Income and spending over time';

  @override
  String get widgetCategoryBreakdown => 'Spending by category';

  @override
  String get widgetCategoryBreakdownHelp => 'Where your money went';

  @override
  String get widgetTopMerchants => 'Top merchants';

  @override
  String get widgetTopMerchantsHelp => 'Who you spent the most with';

  @override
  String get widgetRecentTransactions => 'Recent transactions';

  @override
  String get widgetRecentTransactionsHelp => 'Your latest entries';

  @override
  String get widgetDataCoverage => 'About these figures';

  @override
  String get widgetDataCoverageHelp =>
      'What the figures are based on and how they\'re calculated';

  @override
  String get widgetUnknownHelp => 'Available in a newer version of the app';

  @override
  String get widgetSettingsTitle => 'Customize Home';

  @override
  String get widgetSettingsIntro =>
      'Choose what Home shows and in which order. This only changes the layout, never your records.';

  @override
  String widgetPosition(int position, int total) {
    return 'Position $position of $total';
  }

  @override
  String widgetMoveUp(String name) {
    return 'Move $name up';
  }

  @override
  String widgetMoveDown(String name) {
    return 'Move $name down';
  }

  @override
  String get widgetSettingsSaved => 'Home layout saved.';

  @override
  String get widgetSettingsResetTitle => 'Reset Home layout?';

  @override
  String get widgetSettingsResetBody =>
      'All widgets will be shown again in the default order.';

  @override
  String get widgetSettingsResetDone => 'Home layout reset.';

  @override
  String get dashboardCustomize => 'Customize Home';

  @override
  String get dashboardChangePeriod => 'Change the period';

  @override
  String get dashboardLoading => 'Loading your overview';

  @override
  String get dashboardLayoutFallback =>
      'We couldn\'t load your Home layout, so the default is shown.';

  @override
  String get dashboardCurrencyTitle => 'Currency';

  @override
  String dashboardCurrencyChip(String currency) {
    return 'Show figures in $currency';
  }

  @override
  String get dashboardCurrencyNote =>
      'Amounts in different currencies are shown separately and never added together.';

  @override
  String get dashboardGetStartedTitle => 'Let\'s start tracking';

  @override
  String get dashboardGetStartedBody =>
      'Add an account such as your wallet or bank account, then record what you spend and receive. You never need to connect a bank.';

  @override
  String get dashboardViewAccounts => 'Accounts';

  @override
  String get dashboardSeeAllTransactions => 'See all transactions';

  @override
  String get dashboardNoAccounts =>
      'No accounts are included in your overview yet.';

  @override
  String dashboardAccountCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Across $count accounts',
      one: 'Across 1 account',
    );
    return '$_temp0';
  }

  @override
  String dashboardNoActivity(String period) {
    return 'No income or spending for $period.';
  }

  @override
  String dashboardNoSpending(String period) {
    return 'No spending for $period.';
  }

  @override
  String dashboardNoMerchants(String period) {
    return 'No spending with merchants for $period.';
  }

  @override
  String get dashboardNoRecent => 'No transactions yet.';

  @override
  String dashboardPreviousValue(String amount) {
    return 'Previous period: $amount';
  }

  @override
  String dashboardWithPrevious(String now, String before) {
    return '$now; previous period $before';
  }

  @override
  String get dashboardPreviousExplained =>
      'The previous period has the same length, just before this one.';

  @override
  String dashboardSpendingDetail(String gross, String refunds) {
    return 'Spent $gross, minus $refunds in refunds and reimbursements.';
  }

  @override
  String dashboardTransactionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Based on $count transactions',
      one: 'Based on 1 transaction',
    );
    return '$_temp0';
  }

  @override
  String get dashboardHowCalculated => 'How these figures are calculated';

  @override
  String get incomeLabel => 'Income';

  @override
  String get spendingLabel => 'Spending';

  @override
  String get netCashFlowLabel => 'Net cash flow';

  @override
  String get netCashFlowPositive => 'More came in than went out.';

  @override
  String get netCashFlowNegative => 'More went out than came in.';

  @override
  String get savingsRateLabel => 'Savings rate';

  @override
  String incomeVsExpenseSummary(String period, String income, String spending) {
    return 'For $period, income was $income and spending was $spending.';
  }

  @override
  String get trendUnitDay => 'day';

  @override
  String get trendUnitWeek => 'week';

  @override
  String get trendUnitMonth => 'month';

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
      other: '$count periods with activity',
      one: '1 period with activity',
    );
    return 'Income and spending per $unit for $period, $_temp0. Highest spending: $amount ($bucket).';
  }

  @override
  String trendBucketStarting(String date) {
    return 'Starting $date';
  }

  @override
  String trendRow(String income, String spending, String net) {
    return 'In $income · out $spending · net $net';
  }

  @override
  String categorySummary(String name, String amount, String share, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count categories shown.',
      one: '1 category shown.',
    );
    return 'Most spending went to $name: $amount, $share of the total. $_temp0';
  }

  @override
  String categoryShareDetail(String share, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions',
      one: '1 transaction',
    );
    return '$share · $_temp0';
  }

  @override
  String categoryTableValue(String amount, String share) {
    return '$amount ($share)';
  }

  @override
  String get coverageTransactions => 'Transactions';

  @override
  String coverageTransactionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count in this period',
      one: '1 in this period',
      zero: 'None',
    );
    return '$_temp0';
  }

  @override
  String get coverageSpan => 'From – to';

  @override
  String get coverageUncategorized => 'Without a category';

  @override
  String get coveragePending => 'Pending (not counted)';

  @override
  String get coverageLastImport => 'Last statement import';

  @override
  String get coverageNoImports => 'No imports yet';

  @override
  String get onboardingTitle => 'Set up Montra';

  @override
  String onboardingProgress(int step, int total) {
    return 'Step $step of $total';
  }

  @override
  String get onboardingSkipAll => 'Skip setup';

  @override
  String get onboardingSkipStep => 'Skip this step';

  @override
  String onboardingWelcomeTitle(String name) {
    return 'Welcome, $name';
  }

  @override
  String get onboardingWelcomeBody =>
      'A few quick, optional steps get Montra ready. You can skip any of them and change everything later.';

  @override
  String get onboardingPrivacyTitle => 'Your data stays yours';

  @override
  String get onboardingPrivacyNotSold =>
      'Montra never sells your financial data and never shows it publicly.';

  @override
  String get onboardingPrivacyNoBank =>
      'You don\'t need to connect a bank. Add accounts and transactions yourself.';

  @override
  String get onboardingPrivacyNoSms =>
      'Montra doesn\'t read your SMS or notifications. If a feature ever needs a permission, we\'ll explain why first.';

  @override
  String get onboardingPrivacyControl =>
      'You can export or delete your data at any time from your profile.';

  @override
  String get onboardingRegionTitle => 'Currency and time zone';

  @override
  String get onboardingRegionBody =>
      'Montra uses these for totals and dates. Changing them later never rewrites past amounts or dates.';

  @override
  String get onboardingCurrencyLabel => 'Main currency';

  @override
  String get onboardingCurrencyHelp =>
      'Accounts can still use other currencies.';

  @override
  String get onboardingTimezoneLabel => 'Time zone';

  @override
  String get onboardingTimezoneHelp =>
      'Decides which day a transaction belongs to.';

  @override
  String onboardingUseDeviceTimezone(String timezone) {
    return 'Use this device\'s time zone ($timezone)';
  }

  @override
  String get onboardingCountryLabel => 'Country or region code';

  @override
  String get onboardingCountryHelp => 'Two letters, for example IN.';

  @override
  String get onboardingCountryInvalid => 'Use two letters, for example IN.';

  @override
  String get onboardingIncomeTitle => 'Monthly income (optional)';

  @override
  String get onboardingIncomeBody =>
      'A rough monthly range in rupees only helps Montra tailor tips. It\'s never shown to anyone, and you can skip it.';

  @override
  String get incomeUnder25k => 'Under ₹25,000';

  @override
  String get income25k50k => '₹25,000 – ₹50,000';

  @override
  String get income50k1l => '₹50,000 – ₹1 lakh';

  @override
  String get income1l2l => '₹1 lakh – ₹2 lakh';

  @override
  String get income2l5l => '₹2 lakh – ₹5 lakh';

  @override
  String get incomeAbove5l => 'Above ₹5 lakh';

  @override
  String get incomePreferNot => 'Prefer not to say';

  @override
  String get onboardingAccountsTitle => 'Add an account (optional)';

  @override
  String get onboardingAccountsBody =>
      'Start with the wallet or account you use most. You can add more anytime.';

  @override
  String get onboardingAddAnother => 'Add another account';

  @override
  String get onboardingCategoriesTitle => 'Your starter categories';

  @override
  String get onboardingCategoriesBody =>
      'We\'ve added these categories so you can start right away. You can rename, add or archive categories later.';

  @override
  String get onboardingCategoriesSpending => 'For spending';

  @override
  String get onboardingCategoriesIncome => 'For income';

  @override
  String get onboardingFinish => 'Finish setup';

  @override
  String get onboardingFinishNote => 'You can change all of this later.';

  @override
  String get profileAccountsTitle => 'Accounts';

  @override
  String get profileAccountsSubtitle =>
      'Wallets, bank accounts, cards and loans';

  @override
  String get profilePaymentMethodsTitle => 'Payment methods';

  @override
  String get profilePaymentMethodsSubtitle => 'UPI, cash, cards and more';

  @override
  String get profileHomeLayout => 'Home layout';

  @override
  String get profileHomeLayoutSubtitle => 'Show, hide and reorder Home widgets';

  @override
  String get widgetUnknownTitle => 'Widget from a newer version';

  @override
  String get paymentArchivedResult =>
      'Archived because transactions use it. You can restore it from the archived list.';

  @override
  String get paymentRestored => 'Payment method restored.';

  @override
  String paymentRestoreLabel(String label) {
    return 'Restore $label';
  }

  @override
  String get auditReconciled => 'Reconciled';

  @override
  String get auditUnreconciled => 'Reconciliation undone';

  @override
  String get auditImported => 'Imported';

  @override
  String get auditReceiptLinked => 'Receipt linked';

  @override
  String get auditTagsChanged => 'Tags changed';

  @override
  String get auditOther => 'Changed';

  @override
  String get auditActorImport => 'from an import';

  @override
  String get auditActorRecurring => 'by a recurring rule';

  @override
  String get auditActorIntegration => 'from a connected provider';

  @override
  String get trendUnitYear => 'year';

  @override
  String get noteExcludesTransfers =>
      'Transfers between your accounts, balance adjustments and opening balances are not counted as income or spending.';

  @override
  String get noteRefundsReduceSpending =>
      'Refunds and reimbursements reduce spending; for group expenses only your share counts.';

  @override
  String get noteCurrenciesSeparate =>
      'Amounts in different currencies are shown separately and never added together.';

  @override
  String get noteBalancesTracked =>
      'Balances are tracked from your entries and imports; they are not verified by a bank.';

  @override
  String possibleDuplicateNoticeReasons(int count, String reasons) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count other transactions',
      one: 'another transaction',
    );
    return 'Saved. It looks like $_temp0 ($reasons). Nothing was merged.';
  }

  @override
  String get duplicateSameAccountAmount => 'same account and amount';

  @override
  String get duplicateSameDate => 'same date';

  @override
  String duplicateDaysApart(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days apart',
      one: '1 day apart',
      zero: 'same day',
    );
    return '$_temp0';
  }

  @override
  String get duplicateSameDescription => 'same description';

  @override
  String get filterUncategorized => 'Without a category';

  @override
  String get filterUncategorizedHelp =>
      'Only transactions that have no category yet.';

  @override
  String ruleRefundExceedsRemaining(String remaining, String currency) {
    return 'Refunds and reimbursements can\'t be more than the original. $remaining $currency can still be refunded. Mark it as a correction if this is intentional.';
  }

  @override
  String get ruleOriginalNotRefundable =>
      'Only your own expenses that aren\'t deleted can get a refund or reimbursement.';

  @override
  String ruleCurrencyMismatch(String currency) {
    return 'Use the same currency as the original ($currency).';
  }

  @override
  String get ruleAccountInactive =>
      'This account is archived or closed. Restore it to add or change transactions.';

  @override
  String get ruleGroupLinked =>
      'This is linked to a group record, so change it from the group.';

  @override
  String get ruleHasLinkedRefunds =>
      'Delete the linked refunds or reimbursements first.';

  @override
  String get frequencyDaily => 'Daily';

  @override
  String get frequencyWeekly => 'Weekly';

  @override
  String get frequencyBiweekly => 'Every 2 weeks';

  @override
  String get frequencyMonthly => 'Monthly';

  @override
  String get frequencyBimonthly => 'Every 2 months';

  @override
  String get frequencyQuarterly => 'Every 3 months';

  @override
  String get frequencySemiannual => 'Every 6 months';

  @override
  String get frequencyYearly => 'Yearly';

  @override
  String get frequencyCustom => 'Custom';

  @override
  String frequencyEveryDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $count days',
      one: 'Every day',
    );
    return '$_temp0';
  }

  @override
  String frequencyEveryWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $count weeks',
      one: 'Every week',
    );
    return '$_temp0';
  }

  @override
  String frequencyEveryMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $count months',
      one: 'Every month',
    );
    return '$_temp0';
  }

  @override
  String frequencyEveryYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $count years',
      one: 'Every year',
    );
    return '$_temp0';
  }

  @override
  String get intervalUnitDays => 'Days';

  @override
  String get intervalUnitWeeks => 'Weeks';

  @override
  String get intervalUnitMonths => 'Months';

  @override
  String get intervalUnitYears => 'Years';

  @override
  String get reminderDaysLabel => 'Remind me';

  @override
  String get reminderOnTheDay => 'On the day';

  @override
  String reminderDaysBefore(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days before',
      one: '1 day before',
    );
    return '$_temp0';
  }

  @override
  String reminderDaysHelp(int max) {
    return 'Choose up to $max.';
  }

  @override
  String get reminderNone => 'No reminders.';

  @override
  String get personPickerTitle => 'Choose a person';

  @override
  String get personPickerEmpty =>
      'No connections yet. People you connect with in Montra show up here.';

  @override
  String get groupMemberPickerTitle => 'Choose a group member';

  @override
  String get groupMemberPickerEmpty =>
      'There\'s no one else in this group yet.';

  @override
  String get groupPickerTitle => 'Choose a group';

  @override
  String get groupPickerEmpty => 'You\'re not in any groups yet.';

  @override
  String get groupNone => 'No group';

  @override
  String groupMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '1 member',
    );
    return '$_temp0';
  }

  @override
  String get transactionPickerTitle => 'Choose a transaction';

  @override
  String get transactionPickerSearch => 'Search transactions';

  @override
  String get transactionPickerEmpty => 'No matching transactions.';

  @override
  String get recurringTitle => 'Recurring';

  @override
  String get recurringAdd => 'Add recurring';

  @override
  String get recurringAddFirst => 'Add your first recurring item';

  @override
  String get recurringEmptyTitle => 'No recurring items yet';

  @override
  String get recurringEmptyBody =>
      'Add rent, salary or a monthly transfer once. Montra shows each one when it\'s due, and you decide what to record.';

  @override
  String get recurringNoMatchTitle => 'Nothing matches these filters';

  @override
  String get recurringNoMatchBody => 'Try another type or status.';

  @override
  String get recurringFilterAllKinds => 'All types';

  @override
  String get recurringFilterExpenses => 'Expenses';

  @override
  String get recurringFilterIncome => 'Income';

  @override
  String get recurringFilterTransfers => 'Transfers';

  @override
  String get recurringFilterBills => 'Bills';

  @override
  String get recurringFilterAllStatuses => 'Any status';

  @override
  String get recurringStatusActive => 'Active';

  @override
  String get recurringStatusPaused => 'Paused';

  @override
  String get recurringStatusEnded => 'Ended';

  @override
  String recurringStatusSemantics(String status) {
    return 'Status: $status';
  }

  @override
  String get recurringKindExpense => 'Expense';

  @override
  String get recurringKindIncome => 'Income';

  @override
  String get recurringKindTransfer => 'Transfer';

  @override
  String get recurringKindBill => 'Bill';

  @override
  String get recurringKindSubscription => 'Subscription';

  @override
  String get recurringKindGroupExpense => 'Group expense';

  @override
  String get recurringKindOther => 'Recurring';

  @override
  String get recurringKindLabel => 'Type';

  @override
  String get recurringKindFixed =>
      'The type stays the same when you edit. To change it, add a new recurring item.';

  @override
  String recurringNextOn(String date) {
    return 'Next: $date';
  }

  @override
  String get recurringVaries => 'Varies';

  @override
  String get recurringAmountVaries => 'Amount varies';

  @override
  String get recurringNewTitle => 'New recurring item';

  @override
  String get recurringEditTitle => 'Edit recurring item';

  @override
  String get recurringEditFutureNote =>
      'Changes apply to this and future occurrences. Past ones stay as they are.';

  @override
  String get recurringNameLabel => 'Name';

  @override
  String get recurringNameHelp => 'For example \"Rent\" or \"Salary\".';

  @override
  String get recurringAmountSection => 'Amount and account';

  @override
  String get recurringVariableLabel => 'The amount changes each time';

  @override
  String get recurringVariableHelp =>
      'You\'ll enter the amount when you record it.';

  @override
  String get recurringAmountLabel => 'Expected amount';

  @override
  String get recurringFromAccountLabel => 'From account';

  @override
  String get recurringToAccountLabel => 'To account';

  @override
  String get recurringAccountRequired => 'Choose an account.';

  @override
  String get recurringAutoPostLabel => 'Record automatically';

  @override
  String get recurringAutoPostHelp =>
      'When it\'s due, Montra adds the transaction for you.';

  @override
  String get recurringAutoPostNeedsAmount =>
      'Needs a fixed amount and an account.';

  @override
  String get recurringAutoPostOn => 'Recorded automatically';

  @override
  String get recurringAutoPostOff => 'You confirm each one';

  @override
  String get recurringMoreSection => 'More details';

  @override
  String get recurringCreateButton => 'Add recurring item';

  @override
  String get recurringCreated => 'Recurring item added.';

  @override
  String get recurringSaved => 'Saved for this and future occurrences.';

  @override
  String get recurringDetailTitle => 'Recurring item';

  @override
  String get recurringUpcomingTitle => 'Coming up';

  @override
  String get recurringHistoryTitle => 'History';

  @override
  String get recurringDetailsTitle => 'Details';

  @override
  String get recurringNextLabel => 'Next';

  @override
  String get recurringNothingUpcoming => 'Nothing coming up.';

  @override
  String get recurringNoHistory => 'Nothing recorded yet.';

  @override
  String get recurringCompletedLabel => 'Recorded or paid so far';

  @override
  String get recurringManagedByBill =>
      'This schedule belongs to a bill. Change or pause it from the bill.';

  @override
  String get recurringManagedBySubscription =>
      'This schedule belongs to a subscription. Manage it from the subscription.';

  @override
  String get recurringManagedByGroup =>
      'This is a shared expense of a group. Manage it from the group.';

  @override
  String get recurringOpenBill => 'Open bill';

  @override
  String get recurringSharedReadOnly => 'Shared with you · read-only';

  @override
  String get recurringPausedNotice =>
      'Paused. Nothing new is added until you resume it.';

  @override
  String get recurringEndedNotice => 'Ended. Its history is kept.';

  @override
  String get recurringPause => 'Pause';

  @override
  String get recurringResume => 'Resume';

  @override
  String get recurringSkipNext => 'Skip the next one';

  @override
  String get recurringStop => 'Stop';

  @override
  String get recurringPaused => 'Paused.';

  @override
  String get recurringResumed => 'Resumed.';

  @override
  String get recurringSkippedNext => 'The next one is skipped.';

  @override
  String get recurringStopped => 'Stopped. Its history is kept.';

  @override
  String get recurringSkipNextConfirmTitle => 'Skip the next one?';

  @override
  String recurringSkipNextConfirmBody(String name) {
    return 'The next occurrence of $name will be skipped. Later ones stay as planned.';
  }

  @override
  String get recurringStopConfirmTitle => 'Stop this recurring item?';

  @override
  String recurringStopConfirmBody(String name) {
    return 'No more occurrences of $name will be added. What\'s already recorded stays.';
  }

  @override
  String get recurringDeleteConfirmTitle => 'Delete this recurring item?';

  @override
  String recurringDeleteConfirmBody(String name) {
    return 'If $name was never used, it\'s removed. If it has history, it ends instead and the history is kept.';
  }

  @override
  String get recurringDeleted => 'Recurring item deleted.';

  @override
  String get recurringEndedKept =>
      'It has history, so it was ended instead. Past occurrences are kept.';

  @override
  String get occurrenceStatusScheduled => 'Scheduled';

  @override
  String get occurrenceStatusPosted => 'Recorded';

  @override
  String get occurrenceStatusPaid => 'Paid';

  @override
  String get occurrenceStatusSkipped => 'Skipped';

  @override
  String get occurrenceStatusOverdue => 'Overdue';

  @override
  String get occurrenceStatusOther => 'Planned';

  @override
  String occurrenceMovedFrom(String date) {
    return 'Moved from $date';
  }

  @override
  String get occurrenceHasTransaction => 'Linked to a transaction';

  @override
  String occurrenceSheetTitle(String date) {
    return 'Due $date';
  }

  @override
  String get occurrenceConfirm => 'Record it now';

  @override
  String get occurrenceConfirmHelp => 'Adds the transaction to your account.';

  @override
  String get occurrenceLink => 'Link a transaction I already added';

  @override
  String get occurrenceLinkHelp =>
      'Nothing new is added, so there\'s no duplicate.';

  @override
  String get occurrenceLinkTitle => 'Choose the transaction';

  @override
  String get occurrenceSetAmount => 'Change the amount';

  @override
  String get occurrencePostpone => 'Move to another date';

  @override
  String get occurrencePostponeTitle => 'Move to';

  @override
  String get occurrenceSkip => 'Skip this one';

  @override
  String get occurrenceReopen => 'Undo skip';

  @override
  String get occurrenceOpenTransaction => 'Open transaction';

  @override
  String get occurrenceSkipConfirmTitle => 'Skip this one?';

  @override
  String occurrenceSkipConfirmBody(String date) {
    return 'Nothing will be recorded for $date. You can undo this later.';
  }

  @override
  String get occurrenceConfirmTitle => 'Record this one';

  @override
  String occurrenceConfirmBody(String name, String date) {
    return '$name, due $date.';
  }

  @override
  String get occurrenceAmountLabel => 'Amount';

  @override
  String get occurrenceAmountHelp =>
      'Change it if the actual amount was different.';

  @override
  String get occurrenceDateDefault => 'Due date (or today if early)';

  @override
  String get occurrenceConfirmButton => 'Record';

  @override
  String get occurrenceSetAmountTitle => 'Change the amount';

  @override
  String get occurrenceSetAmountBody => 'Only this occurrence changes.';

  @override
  String get occurrenceRecorded => 'Recorded.';

  @override
  String get occurrenceLinked => 'Linked to the transaction.';

  @override
  String get occurrenceSkipped => 'Skipped.';

  @override
  String get occurrencePostponed => 'Moved to the new date.';

  @override
  String get occurrenceAmountSet => 'Amount changed.';

  @override
  String get occurrenceReopened => 'It\'s back on the list.';

  @override
  String get occurrenceUpdated => 'Updated.';

  @override
  String get scheduleTitle => 'Schedule';

  @override
  String get scheduleFrequencyLabel => 'Repeats';

  @override
  String get scheduleEveryLabel => 'Every';

  @override
  String get scheduleUnitLabel => 'Period';

  @override
  String get scheduleIntervalInvalid => 'Enter a number from 1 to 366.';

  @override
  String get scheduleWeekdayLabel => 'Day of the week';

  @override
  String get scheduleSameWeekday => 'Same day as the start date';

  @override
  String get scheduleDayLabel => 'Which day';

  @override
  String get scheduleAnchorStart => 'Same date as the start date';

  @override
  String get scheduleAnchorMonthDay => 'A date of the month';

  @override
  String get scheduleAnchorNthWeekday => 'A weekday of the month';

  @override
  String get scheduleMonthDayLabel => 'Date';

  @override
  String get scheduleLastDay => 'Last day of the month';

  @override
  String get scheduleMonthDayHelp =>
      'In shorter months it falls on the last day.';

  @override
  String get scheduleWeekOfMonthLabel => 'Week';

  @override
  String scheduleOrdinal(String n) {
    String _temp0 = intl.Intl.selectLogic(n, {
      '1': 'First',
      '2': 'Second',
      '3': 'Third',
      '4': 'Fourth',
      '5': 'Fifth',
      'other': 'Last',
    });
    return '$_temp0';
  }

  @override
  String scheduleOnWeekday(String weekday) {
    return 'on $weekday';
  }

  @override
  String scheduleOnNthWeekday(String week, String weekday) {
    String _temp0 = intl.Intl.selectLogic(week, {
      '1': 'first',
      '2': 'second',
      '3': 'third',
      '4': 'fourth',
      '5': 'fifth',
      'other': 'last',
    });
    return 'on the $_temp0 $weekday';
  }

  @override
  String scheduleOnMonthDay(int day) {
    return 'on day $day';
  }

  @override
  String get scheduleOnLastDay => 'on the last day';

  @override
  String get scheduleStartLabel => 'Starts on';

  @override
  String get scheduleEndsLabel => 'Ends';

  @override
  String get scheduleEndsNever => 'Never';

  @override
  String get scheduleEndsOnDate => 'On a date';

  @override
  String get scheduleEndsAfter => 'After a number of times';

  @override
  String get scheduleEndDateLabel => 'Ends on';

  @override
  String get scheduleEndDateChoose => 'Choose a date';

  @override
  String get scheduleEndBeforeStart => 'Choose a date after the start date.';

  @override
  String get scheduleTimesLabel => 'Number of times';

  @override
  String get scheduleTimesInvalid => 'Enter a number from 1 to 10,000.';

  @override
  String get scheduleTimeLabel => 'Time';

  @override
  String get scheduleTimeHelp =>
      'Reminders and automatic entries use this time.';

  @override
  String scheduleFrom(String start) {
    return 'From $start';
  }

  @override
  String scheduleFromUntil(String start, String end) {
    return 'From $start until $end';
  }

  @override
  String scheduleFromTimes(String start, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count times',
      one: 'once',
    );
    return 'From $start, $_temp0';
  }

  @override
  String get billsTitle => 'Bills';

  @override
  String get billAdd => 'Add bill';

  @override
  String get billAddFirst => 'Add your first bill';

  @override
  String get billsEmptyTitle => 'No bills yet';

  @override
  String get billsEmptyBody =>
      'Add rent, electricity or phone bills to see what\'s due and mark them paid.';

  @override
  String get billsNoMatchTitle => 'No bills here';

  @override
  String get billFilterActive => 'Active';

  @override
  String get billFilterPaused => 'Paused';

  @override
  String get billFilterArchived => 'Archived';

  @override
  String get billFilterAll => 'All';

  @override
  String get billStateOverdue => 'Overdue';

  @override
  String get billStateDueToday => 'Due today';

  @override
  String get billStateDueSoon => 'Due soon';

  @override
  String get billStatePaid => 'Paid';

  @override
  String get billStateUpcoming => 'Upcoming';

  @override
  String get billStatePaused => 'Paused';

  @override
  String get billStateArchived => 'Archived';

  @override
  String get billStateEnded => 'Ended';

  @override
  String get billStateOther => 'Status unavailable';

  @override
  String billStateSemantics(String state) {
    return 'Payment state: $state';
  }

  @override
  String billDueOn(String date) {
    return 'Due $date';
  }

  @override
  String billPaidOn(String date) {
    return 'Paid $date';
  }

  @override
  String billLastPaidOn(String date) {
    return 'Last paid $date';
  }

  @override
  String get billVaries => 'Varies';

  @override
  String get billNewTitle => 'New bill';

  @override
  String get billEditTitle => 'Edit bill';

  @override
  String get billNameLabel => 'Bill name';

  @override
  String get billNameHelp => 'For example \"Electricity\" or \"Phone\".';

  @override
  String get billProviderLabel => 'Provider';

  @override
  String get billProviderHelp => 'Who you pay, for example your power company.';

  @override
  String get billAmountSection => 'Amount and payment';

  @override
  String get billVariableLabel => 'The amount changes each time';

  @override
  String get billVariableHelp => 'You\'ll enter the amount when you pay.';

  @override
  String get billExpectedAmountLabel => 'Expected amount';

  @override
  String get billPaymentAccountLabel => 'Paid from';

  @override
  String get billPaymentAccountHelp => 'Used when you record a payment.';

  @override
  String get billNoPaymentAccount => 'Not set';

  @override
  String get billScheduleSection => 'When it\'s due';

  @override
  String get billCreateButton => 'Add bill';

  @override
  String get billCreated => 'Bill added.';

  @override
  String get billSaved => 'Bill saved.';

  @override
  String get billDetailTitle => 'Bill';

  @override
  String get billDetailsTitle => 'Details';

  @override
  String get billHistoryTitle => 'Payments';

  @override
  String get billNoHistory => 'No payments yet.';

  @override
  String get billMarkPaid => 'Mark as paid';

  @override
  String get billSkip => 'Skip this one';

  @override
  String get billSkipThis => 'Skip this payment';

  @override
  String get billSkipConfirmTitle => 'Skip this payment?';

  @override
  String billSkipConfirmBody(String date) {
    return 'The bill due $date will be marked as skipped. Nothing is recorded.';
  }

  @override
  String get billSkippedDone => 'Skipped.';

  @override
  String get billPause => 'Pause';

  @override
  String get billResume => 'Resume';

  @override
  String get billArchive => 'Archive';

  @override
  String get billPausedDone => 'Bill paused.';

  @override
  String get billResumedDone => 'Bill resumed.';

  @override
  String get billRestoredDone => 'Bill restored.';

  @override
  String get billArchivedDone => 'Bill archived.';

  @override
  String get billArchiveConfirmTitle => 'Archive this bill?';

  @override
  String billArchiveConfirmBody(String name) {
    return '$name stops showing as due. Its payment history is kept, and you can restore it.';
  }

  @override
  String get billPausedNotice =>
      'Paused. It won\'t show as due until you resume it.';

  @override
  String get billArchivedNotice => 'Archived. Its payment history is kept.';

  @override
  String get billSharedReadOnly => 'Shared with you · read-only';

  @override
  String get billPayTitle => 'Mark as paid';

  @override
  String get billNothingToPay => 'Nothing is due on this bill right now.';

  @override
  String billPayIntro(String name, String date) {
    return '$name, due $date';
  }

  @override
  String get billPayLinkMode => 'Link a payment';

  @override
  String get billPayRecordMode => 'Record new';

  @override
  String get billPayLinkHelp =>
      'Choose the payment you already recorded. Nothing new is added.';

  @override
  String get billPayRecordHelp => 'Adds a new expense for this payment.';

  @override
  String get billCandidatesError => 'We couldn\'t load suggested payments.';

  @override
  String get billNoCandidates =>
      'No matching payments found. Choose a transaction or record a new payment.';

  @override
  String get billChooseOtherPayment => 'Choose another transaction';

  @override
  String get billChosenPayment => 'Chosen payment';

  @override
  String get billChoosePayment => 'Choose the payment to link.';

  @override
  String get billPaidAmountLabel => 'Amount paid';

  @override
  String get billPaidAmountHelp => 'Change it if you paid a different amount.';

  @override
  String get billPaidFromLabel => 'Paid from';

  @override
  String get billPaidOnLabel => 'Paid on';

  @override
  String get billAccountRequired => 'Choose the account you paid from.';

  @override
  String get billMarkedPaid => 'Marked as paid.';

  @override
  String get calendarTitle => 'Calendar';

  @override
  String get calendarPreviousMonth => 'Previous month';

  @override
  String get calendarNextMonth => 'Next month';

  @override
  String get calendarThisMonth => 'Go to this month';

  @override
  String calendarEmptyTitle(String month) {
    return 'Nothing planned in $month';
  }

  @override
  String get calendarEmptyBody =>
      'Bills, recurring items, subscription renewals and goal dates show up here.';

  @override
  String calendarMonthCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items this month',
      one: '1 item this month',
    );
    return '$_temp0';
  }

  @override
  String calendarTodayHeading(String date) {
    return 'Today · $date';
  }

  @override
  String get calendarKindRecurring => 'Recurring';

  @override
  String get calendarKindBill => 'Bill';

  @override
  String get calendarKindGroupExpense => 'Group expense';

  @override
  String get calendarKindRenewal => 'Subscription renewal';

  @override
  String get calendarKindTrialEnd => 'Trial ends';

  @override
  String get calendarKindGoal => 'Goal target date';

  @override
  String get calendarKindOther => 'Planned';

  @override
  String get calendarStatusProjected => 'Planned';

  @override
  String get calendarStatusExpected => 'Expected';

  @override
  String get subscriptionsTitle => 'Subscriptions';

  @override
  String get subscriptionListTitle => 'Your subscriptions';

  @override
  String get subscriptionAdd => 'Add subscription';

  @override
  String get subscriptionNewTitle => 'Add subscription';

  @override
  String get subscriptionEditTitle => 'Edit subscription';

  @override
  String get subscriptionDetailTitle => 'Subscription';

  @override
  String get subscriptionEmptyTitle => 'No subscriptions yet';

  @override
  String get subscriptionEmptyBody =>
      'Add the services you pay for regularly to see what they cost each month.';

  @override
  String get subscriptionEmptyFiltered => 'No subscriptions with this status.';

  @override
  String get subscriptionSummaryError => 'We couldn\'t load the overview.';

  @override
  String get subscriptionStatusTrial => 'Free trial';

  @override
  String get subscriptionStatusActive => 'Active';

  @override
  String get subscriptionStatusPaused => 'Paused';

  @override
  String get subscriptionStatusCancelling => 'Being cancelled';

  @override
  String get subscriptionStatusCancelled => 'Cancelled';

  @override
  String get subscriptionStatusUnknown => 'Other status';

  @override
  String get subscriptionFilterCurrent => 'Current';

  @override
  String get subscriptionFilterAll => 'All';

  @override
  String get subscriptionTotalsTitle => 'What they cost';

  @override
  String subscriptionTotalCount(int count, String currency) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count subscriptions',
      one: '1 subscription',
    );
    return '$_temp0 in $currency';
  }

  @override
  String get subscriptionMonthlyCost => 'Per month';

  @override
  String get subscriptionAnnualCost => 'Per year';

  @override
  String get subscriptionTotalsNote =>
      'Includes free trials, active subscriptions and ones being cancelled. Each currency is added up separately.';

  @override
  String get subscriptionTrialsTitle => 'Free trials ending soon';

  @override
  String get subscriptionRenewalsTitle => 'Renewing in the next 30 days';

  @override
  String subscriptionDetectionsPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count possible subscriptions to review',
      one: '1 possible subscription to review',
    );
    return '$_temp0';
  }

  @override
  String get subscriptionDetectionsReview =>
      'Found in your transactions. Nothing is added until you confirm.';

  @override
  String subscriptionTrialEnds(String date) {
    return 'Trial ends $date';
  }

  @override
  String subscriptionRenews(String date) {
    return 'Renews $date';
  }

  @override
  String subscriptionNextCharge(String date) {
    return 'Next charge $date';
  }

  @override
  String get subscriptionSharedLabel => 'Shared with you';

  @override
  String get subscriptionNameLabel => 'Name';

  @override
  String get subscriptionNameHelp => 'For example, the service you pay for.';

  @override
  String get subscriptionPlanLabel => 'Plan';

  @override
  String get subscriptionPriceSection => 'Price and billing';

  @override
  String get subscriptionAmountLabel => 'Price per billing cycle';

  @override
  String get subscriptionFrequencyLabel => 'Billing cycle';

  @override
  String get subscriptionFrequencyRequired => 'Choose a billing cycle.';

  @override
  String get subscriptionIntervalCountLabel => 'Repeats every';

  @override
  String get subscriptionIntervalUnitLabel => 'Unit';

  @override
  String get subscriptionIntervalInvalid =>
      'Enter a whole number from 1 to 366.';

  @override
  String get subscriptionDatesSection => 'Dates';

  @override
  String get subscriptionStartLabel => 'Started on';

  @override
  String get subscriptionTrialLabel => 'Free trial ends';

  @override
  String get subscriptionNoTrial => 'No free trial';

  @override
  String get subscriptionNextRenewalLabel => 'Next renewal';

  @override
  String get subscriptionNextRenewalAuto => 'Work it out for me';

  @override
  String get subscriptionNextRenewalHelp =>
      'Leave it empty and Montra works it out from the start date.';

  @override
  String get subscriptionPaymentSection => 'Payment and sharing';

  @override
  String get subscriptionPaymentAccountLabel => 'Paid from';

  @override
  String get subscriptionPaymentAccountNone => 'Not set';

  @override
  String get subscriptionCategoryUnavailable => 'Category not available';

  @override
  String get subscriptionGroupLabel => 'Shared with a group';

  @override
  String get subscriptionGroupHelp =>
      'Track it as shared with a group you belong to.';

  @override
  String get subscriptionGroupUnavailable => 'Group not available';

  @override
  String get subscriptionRemindersSection => 'Reminders';

  @override
  String get subscriptionRemindersLabel => 'Remind me before it renews';

  @override
  String get subscriptionRemindersHelp =>
      'During a free trial, Montra also reminds you before the trial ends.';

  @override
  String get subscriptionCancellationSection => 'Cancelling';

  @override
  String get subscriptionCancellationUrlLabel => 'Cancellation page';

  @override
  String get subscriptionCancellationUrlHelp =>
      'The provider\'s official page, starting with https://';

  @override
  String get subscriptionCancellationUrlInvalid =>
      'Use the provider\'s official https:// page.';

  @override
  String get subscriptionCancellationHowLabel => 'How to cancel';

  @override
  String get subscriptionChecklistTitle => 'Cancellation checklist';

  @override
  String get subscriptionChecklistHelp =>
      'Steps to finish before or while you cancel, such as downloading your data.';

  @override
  String get subscriptionChecklistAdd => 'Add a step';

  @override
  String get subscriptionChecklistAddButton => 'Add this step';

  @override
  String subscriptionChecklistRemove(String item) {
    return 'Remove step: $item';
  }

  @override
  String subscriptionChecklistFull(int max) {
    return 'You can add up to $max steps.';
  }

  @override
  String get subscriptionChecklistEmpty =>
      'Add steps to the checklist by editing this subscription.';

  @override
  String get subscriptionCreated => 'Subscription added.';

  @override
  String get subscriptionSaved => 'Subscription saved.';

  @override
  String get subscriptionPriceLabel => 'Price';

  @override
  String get subscriptionSourceLabel => 'Added';

  @override
  String get subscriptionSourceDetected => 'Found in your transactions';

  @override
  String get subscriptionSourceManual => 'Added by you';

  @override
  String get subscriptionDuplicateTitle => 'This may be a duplicate';

  @override
  String subscriptionDuplicateBody(String name, String reason) {
    return 'It looks like $name: $reason.';
  }

  @override
  String get subscriptionDuplicateSameMerchant => 'same merchant';

  @override
  String get subscriptionDuplicateSameName => 'same name';

  @override
  String get subscriptionDuplicateSamePrice => 'same price and billing cycle';

  @override
  String get subscriptionDuplicateOpen => 'Open';

  @override
  String subscriptionDuplicateOpenLabel(String name) {
    return 'Open $name';
  }

  @override
  String get subscriptionSharedNotice =>
      'This subscription is shared with you through a group. Only its owner can change it.';

  @override
  String get subscriptionCostTitle => 'What it costs';

  @override
  String get subscriptionCostNote =>
      'Worked out by Montra from the price and billing cycle.';

  @override
  String get subscriptionPaymentsTitle => 'Payments';

  @override
  String get subscriptionNoPayments => 'No payments linked yet.';

  @override
  String get subscriptionLastPayment => 'Last payment';

  @override
  String get subscriptionPaidAmount => 'Amount paid';

  @override
  String get subscriptionViewTransaction => 'View transaction';

  @override
  String get subscriptionRecordPayment => 'Record a payment';

  @override
  String get subscriptionPaymentPickerTitle => 'Which charge was this payment?';

  @override
  String subscriptionPaymentCurrencyMismatch(String currency) {
    return 'Choose a charge in $currency, the subscription\'s currency.';
  }

  @override
  String get subscriptionRecordPaymentTitle => 'Record this payment?';

  @override
  String subscriptionRecordPaymentBody(
    String title,
    String date,
    String amount,
  ) {
    return '$title on $date for $amount will be linked to this subscription. The transaction itself won\'t change.';
  }

  @override
  String subscriptionPriceDiffers(String price) {
    return 'This is different from the current price of $price.';
  }

  @override
  String subscriptionUpdatePrice(String amount) {
    return 'Change the price to $amount';
  }

  @override
  String get subscriptionRecordPaymentConfirm => 'Record payment';

  @override
  String get subscriptionPaymentRecorded => 'Payment recorded.';

  @override
  String get subscriptionPaymentDuplicate =>
      'This payment is already linked to a subscription.';

  @override
  String get subscriptionActionUnavailable =>
      'That isn\'t possible in the subscription\'s current status. We\'ve loaded the latest details.';

  @override
  String get subscriptionCancellingNotice =>
      'You\'ve started cancelling. Once the provider confirms, mark it as cancelled.';

  @override
  String get subscriptionOpenPage => 'Open page';

  @override
  String get subscriptionCopyLink => 'Copy link';

  @override
  String get subscriptionOpenPageFailed =>
      'We couldn\'t open the page. You can copy the link instead.';

  @override
  String get subscriptionLinkCopied => 'Link copied.';

  @override
  String get subscriptionCancelledOn => 'Cancelled on';

  @override
  String get subscriptionLastChecked => 'Last checked';

  @override
  String get subscriptionNeverChecked => 'Not yet';

  @override
  String get subscriptionDetailsSection => 'Details';

  @override
  String get subscriptionHistoryTitle => 'History';

  @override
  String get subscriptionHistoryEmpty => 'No history yet.';

  @override
  String subscriptionHistoryShowAll(int count) {
    return 'Show all $count entries';
  }

  @override
  String subscriptionPriceHistorySummary(
    String firstPrice,
    String firstDate,
    String lastPrice,
    String lastDate,
  ) {
    return 'The price went from $firstPrice on $firstDate to $lastPrice on $lastDate.';
  }

  @override
  String subscriptionPriceChange(String from, String to) {
    return '$from to $to';
  }

  @override
  String get subscriptionEventCreated => 'Added';

  @override
  String get subscriptionEventEdited => 'Details changed';

  @override
  String get subscriptionEventPriceChanged => 'Price changed';

  @override
  String get subscriptionEventPayment => 'Payment recorded';

  @override
  String get subscriptionEventTrialStarted => 'Free trial started';

  @override
  String get subscriptionEventTrialEnding => 'Free trial ending soon';

  @override
  String get subscriptionEventPaused => 'Paused';

  @override
  String get subscriptionEventResumed => 'Resumed';

  @override
  String get subscriptionEventCancellationStarted => 'Cancellation started';

  @override
  String get subscriptionEventCancelled => 'Cancelled';

  @override
  String get subscriptionEventReactivated => 'Reactivated';

  @override
  String get subscriptionEventVerified => 'Checked';

  @override
  String get subscriptionEventOther => 'Updated';

  @override
  String get subscriptionActionVerify => 'Mark as checked';

  @override
  String get subscriptionActionPause => 'Pause';

  @override
  String get subscriptionActionResume => 'Resume';

  @override
  String get subscriptionActionCancellationStarted =>
      'I\'ve started cancelling';

  @override
  String get subscriptionActionCancelled => 'Mark as cancelled';

  @override
  String get subscriptionActionReactivate => 'Reactivate';

  @override
  String get subscriptionVerifiedDone => 'Marked as checked today.';

  @override
  String get subscriptionPausedDone => 'Subscription paused.';

  @override
  String get subscriptionResumedDone => 'Subscription resumed.';

  @override
  String get subscriptionCancellationStartedDone =>
      'Noted. Use the checklist while you cancel.';

  @override
  String get subscriptionCancelledDone => 'Marked as cancelled.';

  @override
  String get subscriptionReactivatedDone => 'Subscription reactivated.';

  @override
  String get subscriptionCancelledConfirmTitle => 'Has it been cancelled?';

  @override
  String subscriptionCancelledConfirmBody(String name) {
    return 'Mark $name as cancelled only after the provider has confirmed it. Montra doesn\'t cancel subscriptions for you.';
  }

  @override
  String get subscriptionCancelledConfirm => 'Yes, it\'s cancelled';

  @override
  String get detectionsTitle => 'Possible subscriptions';

  @override
  String get detectionsHint => 'Look for regular charges in your transactions.';

  @override
  String get detectionsIntro =>
      'Montra looks for charges that repeat at a regular interval with a similar amount. Nothing is added until you confirm it.';

  @override
  String get detectionsRefresh => 'Look again';

  @override
  String get detectionsRefreshStarted =>
      'Looking for regular charges. This runs in the background, so check back in a few minutes.';

  @override
  String get detectionsEmptyTitle => 'Nothing to review';

  @override
  String get detectionsEmptyBody =>
      'When charges repeat regularly, they show up here for you to review.';

  @override
  String get detectionTypicalAmount => 'Usual amount';

  @override
  String detectionTolerance(String amount) {
    return 'Amounts vary by up to $amount.';
  }

  @override
  String detectionStrong(int percent) {
    return 'Strong match ($percent%)';
  }

  @override
  String detectionLikely(int percent) {
    return 'Likely match ($percent%)';
  }

  @override
  String detectionPossible(int percent) {
    return 'Possible match ($percent%)';
  }

  @override
  String get detectionConfidenceHelp =>
      'Based on how regular the dates are, how similar the amounts are and how many charges there are.';

  @override
  String detectionEvidenceCharges(int count, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count charges',
      one: '1 charge',
    );
    String _temp1 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return '$_temp0, usually $_temp1 apart';
  }

  @override
  String detectionEvidenceLast(String date) {
    return 'Last charge on $date';
  }

  @override
  String detectionEvidenceNext(String date) {
    return 'Next charge expected around $date';
  }

  @override
  String get detectionConfirm => 'Add as subscription';

  @override
  String detectionConfirmLabel(String name) {
    return 'Add $name as a subscription';
  }

  @override
  String get detectionDismiss => 'Not a subscription';

  @override
  String detectionDismissLabel(String name) {
    return '$name is not a subscription';
  }

  @override
  String get detectionDismissTitle => 'Not a subscription?';

  @override
  String detectionDismissBody(String name) {
    return '$name will be removed from this list. Your transactions stay as they are.';
  }

  @override
  String get detectionDismissed => 'Removed from the list.';

  @override
  String get detectionSeeCharges => 'See charges';

  @override
  String detectionSeeChargesLabel(String name) {
    return 'See charges from $name';
  }

  @override
  String get detectionConfirmTitle => 'Add as a subscription';

  @override
  String get detectionConfirmBody =>
      'Check the details. Anything you leave as it is uses what we found.';

  @override
  String get detectionAccountDefault => 'Account of the latest charge';

  @override
  String get detectionConfirmed => 'Subscription added.';

  @override
  String get subscriptionListError => 'We couldn\'t load your subscriptions.';

  @override
  String get goalsTitle => 'Goals';

  @override
  String get goalNew => 'New goal';

  @override
  String get goalAddFirst => 'Add a goal';

  @override
  String get goalsEmptyTitle => 'No goals yet';

  @override
  String get goalsEmptyBody =>
      'Save towards something that matters to you, like an emergency fund, a trip or a new phone. Add a goal and go at your own pace.';

  @override
  String get goalsNoMatchTitle => 'No goals here';

  @override
  String get goalsNoMatchBody => 'Try another filter.';

  @override
  String get goalFilterLabel => 'Show goals';

  @override
  String get goalFilterCurrent => 'Current';

  @override
  String get goalFilterAll => 'All, including archived';

  @override
  String get goalStatusActive => 'Active';

  @override
  String get goalStatusPaused => 'Paused';

  @override
  String get goalStatusAchieved => 'Achieved';

  @override
  String get goalStatusCancelled => 'Ended';

  @override
  String get goalStatusArchived => 'Archived';

  @override
  String get goalStatusUnknown => 'Other status';

  @override
  String goalProgressSummary(String percent, String saved, String target) {
    return '$percent saved · $saved of $target';
  }

  @override
  String goalTargetDateShort(String date) {
    return 'By $date';
  }

  @override
  String get goalSharedWithYou => 'Shared with you';

  @override
  String goalSharedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Shared with $count people',
      one: 'Shared with 1 person',
    );
    return '$_temp0';
  }

  @override
  String get goalTypeEmergencyFund => 'Emergency fund';

  @override
  String get goalTypeTravel => 'Travel';

  @override
  String get goalTypeEducation => 'Education';

  @override
  String get goalTypeDevice => 'Phone or gadget';

  @override
  String get goalTypeVehicle => 'Vehicle';

  @override
  String get goalTypeHome => 'Home';

  @override
  String get goalTypeEvent => 'Event or celebration';

  @override
  String get goalTypeDebtPayoff => 'Paying off a loan';

  @override
  String get goalTypeLargePurchase => 'Big purchase';

  @override
  String get goalTypeCustom => 'Something else';

  @override
  String get goalDetailTitle => 'Goal';

  @override
  String goalPercentSaved(String percent) {
    return '$percent saved';
  }

  @override
  String goalSavedOfTarget(String saved, String target) {
    return '$saved of $target';
  }

  @override
  String get goalSavedLabel => 'Saved so far';

  @override
  String get goalTargetLabel => 'Target';

  @override
  String get goalRemainingLabel => 'Still to go';

  @override
  String get goalVerifiedLabel => 'Backed by transactions';

  @override
  String get goalPlannedLabel => 'Planned, not counted yet';

  @override
  String get goalStartingLabel => 'Saved before tracking';

  @override
  String goalContributionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count contributions',
      one: '1 contribution',
      zero: 'No contributions yet',
    );
    return '$_temp0';
  }

  @override
  String get goalPausedNotice =>
      'This goal is paused. Resume it to add contributions.';

  @override
  String goalAchievedNotice(String date) {
    return 'You reached this goal on $date.';
  }

  @override
  String get goalAchievedNoticeNoDate => 'You reached this goal.';

  @override
  String get goalCancelledNotice => 'This goal has ended. Its history is kept.';

  @override
  String get goalArchivedNotice =>
      'This goal is archived. Its history is kept.';

  @override
  String get goalViewerNotice => 'You can see this goal but not add to it.';

  @override
  String get goalAddContribution => 'Add contribution';

  @override
  String get goalExport => 'Export as CSV';

  @override
  String get goalPause => 'Pause goal';

  @override
  String get goalResume => 'Resume goal';

  @override
  String get goalMarkAchieved => 'Mark as achieved';

  @override
  String get goalCancel => 'End goal';

  @override
  String get goalArchive => 'Archive goal';

  @override
  String get goalLeave => 'Leave goal';

  @override
  String get goalPausedDone => 'Goal paused.';

  @override
  String get goalResumedDone => 'Goal resumed.';

  @override
  String get goalAchievedDone => 'Goal marked as achieved.';

  @override
  String get goalCancelledDone => 'Goal ended.';

  @override
  String get goalArchivedDone => 'Goal archived.';

  @override
  String get goalLeftDone => 'You left the goal.';

  @override
  String get goalAchieveConfirmTitle => 'Mark this goal as achieved?';

  @override
  String goalAchieveConfirmBody(String name) {
    return '$name will be marked as achieved. You can\'t add contributions to it after that.';
  }

  @override
  String get goalCancelConfirmTitle => 'End this goal?';

  @override
  String goalCancelConfirmBody(String name) {
    return '$name will be closed and its contributions kept in the history. You can start a new goal any time.';
  }

  @override
  String get goalArchiveConfirmTitle => 'Archive this goal?';

  @override
  String goalArchiveConfirmBody(String name) {
    return '$name moves to the archive with its history. Archived goals can\'t be changed.';
  }

  @override
  String get goalLeaveConfirmTitle => 'Leave this goal?';

  @override
  String goalLeaveConfirmBody(String name) {
    return 'You won\'t see $name anymore. Your past contributions stay in its history.';
  }

  @override
  String get goalForecastTitle => 'Outlook';

  @override
  String get goalForecastAchieved => 'You\'ve reached the target';

  @override
  String get goalForecastOnTrack => 'On track';

  @override
  String get goalForecastNeedsMore => 'Needs a little more to finish on time';

  @override
  String goalForecastDaysLeft(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days left',
      one: '1 day left',
      zero: 'due today',
    );
    return '$_temp0';
  }

  @override
  String goalForecastRequired(String perMonth, String perWeek) {
    return 'To finish by the target date, set aside about $perMonth a month ($perWeek a week).';
  }

  @override
  String goalForecastRequiredMonthOnly(String perMonth) {
    return 'To finish by the target date, set aside about $perMonth a month.';
  }

  @override
  String goalForecastPace(String pace) {
    return 'Recent pace: $pace a month (last 90 days).';
  }

  @override
  String goalForecastProjected(String date) {
    return 'At this pace, you\'d reach it around $date.';
  }

  @override
  String get goalForecastNoPace =>
      'There\'s no recent progress to estimate a finish date yet.';

  @override
  String goalForecastPlanned(String date) {
    return 'With your planned contributions, around $date.';
  }

  @override
  String get goalForecastAssumptions => 'How this is worked out';

  @override
  String get milestonesTitle => 'Milestones';

  @override
  String get milestonesEmpty => 'No milestones.';

  @override
  String milestonePercent(int percent) {
    return '$percent% of the target';
  }

  @override
  String milestoneReachedOn(String date) {
    return 'Reached on $date';
  }

  @override
  String get milestoneNotReached => 'Not reached yet';

  @override
  String get milestonesHelp =>
      'Up to 10. Each one is marked when you reach it.';

  @override
  String get milestoneAdd => 'Add milestone';

  @override
  String get milestoneRemove => 'Remove milestone';

  @override
  String get milestonePercentLabel => 'Percent of the target';

  @override
  String get milestoneNameLabel => 'Label';

  @override
  String get milestonePercentInvalid => 'Enter a whole number from 1 to 100.';

  @override
  String get milestoneDuplicate => 'Each milestone needs a different percent.';

  @override
  String get contributionsTitle => 'Contributions';

  @override
  String get contributionsEmpty =>
      'No contributions yet. Add one when you set money aside.';

  @override
  String get contributionKindContribution => 'Contribution';

  @override
  String get contributionKindWithdrawal => 'Withdrawal';

  @override
  String get contributionStatusPlanned => 'Planned';

  @override
  String get contributionStatusRecorded => 'Recorded';

  @override
  String get contributionStatusVerified => 'Verified';

  @override
  String get contributionStatusUnknown => 'Other';

  @override
  String get contributionVoided => 'Voided';

  @override
  String get contributionYou => 'You';

  @override
  String get contributionAmountHidden => 'Amount hidden';

  @override
  String contributionShareOfTarget(String percent) {
    return '$percent of the target';
  }

  @override
  String get contributionLinkedTransaction => 'Linked to a transaction';

  @override
  String get contributionOpenTransaction => 'Open the linked transaction';

  @override
  String get contributionVoid => 'Void';

  @override
  String contributionVoidTooltip(String date) {
    return 'Void your contribution of $date';
  }

  @override
  String get contributionVoidConfirmTitle => 'Void this contribution?';

  @override
  String get contributionVoidConfirmBody =>
      'It stops counting towards the goal but stays in the history.';

  @override
  String get contributionVoidedDone => 'Contribution voided.';

  @override
  String contributionNewTitle(String name) {
    return 'Add to $name';
  }

  @override
  String get contributionAmountLabel => 'Amount added';

  @override
  String get contributionWithdrawalAmountLabel => 'Amount taken out';

  @override
  String get contributionPlannedHelp =>
      'Planned: money you intend to set aside. It isn\'t counted as saved yet.';

  @override
  String get contributionRecordedHelp =>
      'Recorded: you\'ve already set the money aside. It counts as saved.';

  @override
  String get contributionTransactionLabel => 'Linked transaction';

  @override
  String get contributionTransactionPlaceholder =>
      'Choose the transaction that moved the money';

  @override
  String get contributionTransactionPickerTitle =>
      'Which transaction moved the money?';

  @override
  String get contributionTransactionHelp =>
      'Linking it marks this as verified. Each transaction counts once.';

  @override
  String get contributionNoteLabel => 'Note';

  @override
  String get contributionSave => 'Save contribution';

  @override
  String get contributionWithdrawalSave => 'Save withdrawal';

  @override
  String get contributionSavedDone => 'Contribution added.';

  @override
  String get contributionWithdrawalSavedDone => 'Withdrawal recorded.';

  @override
  String get contributionGoalInactive =>
      'Contributions can be added to active goals only.';

  @override
  String get goalMembersTitle => 'Shared with';

  @override
  String get goalMembersEmpty => 'Not shared with anyone yet.';

  @override
  String get goalAddMember => 'Add a person';

  @override
  String get goalAddFromConnections => 'From your connections';

  @override
  String get goalAddFromGroup => 'From this goal\'s group';

  @override
  String goalMemberYou(String name) {
    return '$name (you)';
  }

  @override
  String goalMemberRoleTitle(String name) {
    return 'What can $name do?';
  }

  @override
  String get goalMemberRoleContributor => 'Can add contributions';

  @override
  String get goalMemberRoleViewer => 'Can only view';

  @override
  String get goalMemberVisibilityAmounts => 'Shows amounts';

  @override
  String get goalMemberVisibilityPercent => 'Shows percentages only';

  @override
  String get goalMemberVisibilityHidden => 'Keeps contributions private';

  @override
  String get goalMyVisibilityTitle => 'What others see of your contributions';

  @override
  String goalMemberAddedDone(String name) {
    return '$name added.';
  }

  @override
  String get goalMemberUpdatedDone => 'Sharing updated.';

  @override
  String get goalMemberRemove => 'Remove from goal';

  @override
  String goalMemberRemoveConfirmTitle(String name) {
    return 'Remove $name?';
  }

  @override
  String goalMemberRemoveConfirmBody(String name) {
    return '$name won\'t see this goal anymore. Their past contributions stay in the history.';
  }

  @override
  String goalMemberRemovedDone(String name) {
    return '$name removed.';
  }

  @override
  String get goalDetailsTitle => 'Details';

  @override
  String get goalVisibilityLabel => 'Who can see it';

  @override
  String get goalRemindersDetail => 'Reminders';

  @override
  String get goalEditTitle => 'Edit goal';

  @override
  String get goalNameLabel => 'Goal name';

  @override
  String get goalNameHelp => 'For example \"Emergency fund\" or \"Goa trip\".';

  @override
  String get goalTypeLabel => 'Kind of goal';

  @override
  String get goalTypeRequired => 'Choose what kind of goal this is.';

  @override
  String get goalTargetAmountLabel => 'Target amount';

  @override
  String get goalStartingAmountLabel => 'Already saved';

  @override
  String get goalStartingAmountHelp =>
      'Money you had saved before you started tracking this goal.';

  @override
  String get goalDatesSection => 'Dates';

  @override
  String get goalStartDateLabel => 'Start date';

  @override
  String get goalTargetDateLabel => 'Target date';

  @override
  String get goalTargetDateHelp => 'Helps work out how much to set aside.';

  @override
  String get goalPlanSection => 'Plan';

  @override
  String get goalScheduleLabel => 'How often you plan to add';

  @override
  String get goalScheduleNone => 'No regular plan';

  @override
  String get goalPlannedContributionLabel => 'Planned amount each time';

  @override
  String get goalRemindersLabel => 'Remind me about this goal';

  @override
  String get goalPriorityLabel => 'Priority';

  @override
  String get goalPriorityHelp => '1 is the most important.';

  @override
  String get goalPriorityHighest => 'Highest';

  @override
  String get goalPriorityHigh => 'High';

  @override
  String get goalPriorityMedium => 'Medium';

  @override
  String get goalPriorityLow => 'Low';

  @override
  String get goalPriorityLowest => 'Lowest';

  @override
  String get goalLinkedAccountLabel => 'Linked account';

  @override
  String get goalLinkedAccountNone => 'No account';

  @override
  String get goalLinkedAccountHelp =>
      'For your reference only. Its balance isn\'t counted automatically.';

  @override
  String get goalSharingSection => 'Sharing';

  @override
  String get goalVisibilityPrivate => 'Private';

  @override
  String get goalVisibilityMembers => 'Members';

  @override
  String get goalVisibilityHelp =>
      'Private: only you see it. Members: people you add can see it and, if allowed, contribute.';

  @override
  String get goalGroupLabel => 'Group';

  @override
  String get goalGroupHelp => 'Share with a group so its members can join in.';

  @override
  String get goalMoreSection => 'More details';

  @override
  String get goalCreate => 'Create goal';

  @override
  String get goalCreatedDone => 'Goal created.';

  @override
  String get goalSavedDone => 'Goal saved.';

  @override
  String get goalExportTitle => 'Export contributions';

  @override
  String get goalExportIntro =>
      'This CSV lists every contribution, including voided ones. Copy it to paste into a spreadsheet or a note.';

  @override
  String get goalExportFileLabel => 'File name';

  @override
  String get goalExportRowsLabel => 'Rows';

  @override
  String goalExportRows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rows',
      one: '1 row',
      zero: 'No rows yet',
    );
    return '$_temp0';
  }

  @override
  String get goalExportEmpty =>
      'There are no contributions yet, so only the column names are included.';

  @override
  String get goalExportCopy => 'Copy CSV';

  @override
  String get goalExportCopied =>
      'CSV copied. It includes your amounts and notes, so paste it only where you trust.';

  @override
  String get goalExportPreviewTitle => 'Preview';

  @override
  String get budgetsTitle => 'Budgets';

  @override
  String get budgetAdd => 'New budget';

  @override
  String get budgetAddFirst => 'Create a budget';

  @override
  String get budgetsShowArchived => 'Show archived budgets';

  @override
  String get budgetsEmptyTitle => 'No budgets yet';

  @override
  String get budgetsEmptyBody =>
      'A budget sets a spending limit for a week, a month or a year. Montra shows what\'s left and whether your spending is on pace.';

  @override
  String get budgetAlertsTitle => 'Budget alerts';

  @override
  String get budgetTypeTotal => 'Total spending';

  @override
  String get budgetTypeCategory => 'By category';

  @override
  String get budgetTypeMerchant => 'By merchant';

  @override
  String get budgetTypeAccount => 'By account';

  @override
  String get budgetTypeEnvelope => 'Envelopes';

  @override
  String get budgetTypeZeroBased => 'Zero-based';

  @override
  String get budgetTypeUnknown => 'Other budget';

  @override
  String get budgetTypeTotalHelp => 'One limit for all your spending.';

  @override
  String get budgetTypeCategoryHelp => 'Limits for the categories you choose.';

  @override
  String get budgetTypeMerchantHelp => 'Spending at the merchants you choose.';

  @override
  String get budgetTypeAccountHelp => 'Spending from the accounts you choose.';

  @override
  String get budgetTypeEnvelopeHelp =>
      'Split the limit into envelopes, one per category.';

  @override
  String get budgetTypeZeroBasedHelp =>
      'Give every part of the limit a job: the envelopes must add up exactly to the limit.';

  @override
  String get budgetTypeGroupHelp =>
      'Group budgets count all of the group\'s shared expenses.';

  @override
  String get budgetPeriodWeekly => 'Weekly';

  @override
  String get budgetPeriodMonthly => 'Monthly';

  @override
  String get budgetPeriodAnnual => 'Yearly';

  @override
  String get budgetPeriodCustom => 'Custom dates';

  @override
  String get budgetPeriodUnknown => 'Other period';

  @override
  String get budgetStatusActive => 'Active';

  @override
  String get budgetStatusPaused => 'Paused';

  @override
  String get budgetStatusArchived => 'Archived';

  @override
  String get budgetStatusUnknown => 'Unavailable';

  @override
  String get budgetAccessEditor => 'Shared with you · can edit';

  @override
  String get budgetAccessViewer => 'Shared with you · can view';

  @override
  String budgetSharedWith(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Shared with $count people',
      one: 'Shared with 1 person',
    );
    return '$_temp0';
  }

  @override
  String budgetGroupLabel(String name) {
    return 'Group: $name';
  }

  @override
  String get budgetGroupUnknown => 'a group';

  @override
  String get budgetPaceUnder => 'Spending slower than planned';

  @override
  String get budgetPaceOnTrack => 'On track';

  @override
  String get budgetPaceAhead => 'Spending faster than planned';

  @override
  String get budgetPaceOver => 'Over the limit';

  @override
  String get budgetPaceUnknown => 'Pace not available';

  @override
  String budgetSpentOf(String spent, String limit) {
    return '$spent spent of $limit';
  }

  @override
  String budgetLeft(String amount) {
    return '$amount left';
  }

  @override
  String budgetOverBy(String amount) {
    return '$amount over the limit';
  }

  @override
  String budgetPercentUsed(String percent) {
    return '$percent used';
  }

  @override
  String get budgetNoProgressPaused =>
      'Progress isn\'t tracked while it\'s paused.';

  @override
  String get budgetNoProgressArchived => 'Its history is kept.';

  @override
  String get budgetDetailTitle => 'Budget';

  @override
  String get budgetThisPeriod => 'This period';

  @override
  String budgetDayOf(int day, int total) {
    return 'Day $day of $total';
  }

  @override
  String get budgetRemainingLabel => 'Left to spend';

  @override
  String get budgetOverspentLabel => 'Over the limit by';

  @override
  String get budgetDailyAllowanceLabel => 'Per day for the rest of the period';

  @override
  String get budgetExpectedByNowLabel => 'Expected by now at an even pace';

  @override
  String get budgetProjectedLabel => 'Estimate for the whole period';

  @override
  String get budgetProjectedOverLabel => 'May go over by';

  @override
  String get budgetRolloverInLabel => 'Carried over';

  @override
  String get budgetBaseLimitLabel => 'Base limit';

  @override
  String get budgetLimitLabel => 'Limit';

  @override
  String get budgetCountedLabel => 'Transactions counted';

  @override
  String budgetAsOf(String time) {
    return 'Totals as of $time';
  }

  @override
  String get budgetHowCalculated => 'How this is calculated';

  @override
  String budgetExplainSpent(
    String spent,
    String limit,
    String from,
    String to,
  ) {
    return 'Spent $spent of $limit between $from and $to.';
  }

  @override
  String get budgetExplainRefundsRestore =>
      'Transfers and balance adjustments never count. Refunds give money back to this budget.';

  @override
  String get budgetExplainRefundsIgnored =>
      'Transfers and balance adjustments never count. Refunds don\'t change this budget.';

  @override
  String get budgetExplainPending => 'Pending transactions count too.';

  @override
  String get budgetExplainPostedOnly => 'Only posted transactions count.';

  @override
  String budgetExplainCarry(String amount) {
    return 'Includes $amount carried over from the previous period.';
  }

  @override
  String budgetExplainProjected(String amount) {
    return 'At the current pace you would spend about $amount by the end of the period. This is an estimate, not a promise.';
  }

  @override
  String budgetExplainOtherCurrency(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count matching transactions in other currencies aren\'t included.',
      one: '1 matching transaction in another currency isn\'t included.',
    );
    return '$_temp0';
  }

  @override
  String get budgetExplainCollaborator =>
      'You see the owner\'s totals only; their transactions stay private.';

  @override
  String get budgetExplainGroup =>
      'This budget counts the group\'s shared expenses.';

  @override
  String get budgetHistoryTitle => 'Compare periods';

  @override
  String get budgetHistoryEarlier => 'Earlier period';

  @override
  String get budgetHistoryLater => 'Later period';

  @override
  String budgetHistoryRow(String period, String spent, String limit) {
    return '$period: spent $spent of $limit.';
  }

  @override
  String get budgetTransactionsTitle => 'Counted transactions';

  @override
  String get budgetTransactionsEmpty =>
      'Nothing counts toward this budget in this period yet.';

  @override
  String get budgetTransactionsOwnerOnly =>
      'Only the owner can see the individual transactions. You see the totals.';

  @override
  String get budgetTransactionsGroup =>
      'Group budgets count the group\'s expenses. Open the group to see them.';

  @override
  String budgetTransactionsShowAll(int count) {
    return 'Show all $count';
  }

  @override
  String budgetTransactionsCapped(int count) {
    return 'Showing the first $count transactions.';
  }

  @override
  String get budgetAllocationsTitle => 'Limits within this budget';

  @override
  String get budgetEnvelopesTitle => 'Envelopes';

  @override
  String budgetAllocationMember(String name) {
    return '$name\'s share';
  }

  @override
  String get budgetAllocationYou => 'Your share';

  @override
  String get budgetAllocationUnnamed => 'Unnamed limit';

  @override
  String get budgetAllocationRemoved => 'Removed item';

  @override
  String get budgetAllocationAdd => 'Add a limit';

  @override
  String get budgetAllocationEdit => 'Edit limit';

  @override
  String get budgetAllocationTargetLabel => 'Applies to';

  @override
  String get budgetAllocationTargetCategory => 'A category';

  @override
  String get budgetAllocationTargetMerchant => 'A merchant';

  @override
  String get budgetAllocationTargetAccount => 'An account';

  @override
  String get budgetAllocationTargetMember => 'A group member\'s share';

  @override
  String get budgetAllocationTargetName => 'Just a name';

  @override
  String get budgetAllocationNameLabel => 'Name for this limit';

  @override
  String get budgetAllocationChoose => 'Choose';

  @override
  String get budgetAllocationTargetRequired =>
      'Choose what this limit applies to.';

  @override
  String get budgetAllocationsNeeded => 'Add at least one limit.';

  @override
  String get budgetAllocationsHelp =>
      'Optional limits for parts of this budget.';

  @override
  String get budgetZeroBasedHelp =>
      'Envelopes must add up exactly to the limit.';

  @override
  String get budgetZeroBasedUnallocated =>
      'The envelopes don\'t add up to the limit yet. Change an envelope or the limit so they match exactly.';

  @override
  String budgetRemoveItem(String name) {
    return 'Remove $name';
  }

  @override
  String budgetEditItem(String name) {
    return 'Edit $name';
  }

  @override
  String budgetAllocationValue(String spent, String limit) {
    return '$spent of $limit';
  }

  @override
  String get budgetNewTitle => 'New budget';

  @override
  String get budgetEditTitle => 'Edit budget';

  @override
  String get budgetNameLabel => 'Budget name';

  @override
  String get budgetNameHelp =>
      'For example \"Monthly spending\" or \"Groceries\".';

  @override
  String get budgetTypeLabel => 'Type';

  @override
  String get budgetPeriodLabel => 'Period';

  @override
  String get budgetStartsOnLabel => 'Starts on';

  @override
  String get budgetEndsOnLabel => 'Ends on';

  @override
  String get budgetEndsOnRequired => 'Custom-date budgets need an end date.';

  @override
  String get budgetLimitHelp => 'The most you want to spend in each period.';

  @override
  String get budgetGroupField => 'Group';

  @override
  String get budgetGroupHelp =>
      'Track a household, trip or other group\'s shared expenses.';

  @override
  String get budgetGroupFixed =>
      'The group can\'t change after the budget is created.';

  @override
  String get budgetCurrencyFromGroup =>
      'Group budgets use the group\'s currency.';

  @override
  String get budgetScopeSection => 'What counts';

  @override
  String get budgetMerchantsLabel => 'Merchants';

  @override
  String get budgetMerchantsNeeded => 'Choose at least one merchant.';

  @override
  String get budgetAddMerchant => 'Add merchant';

  @override
  String get budgetAccountsLabel => 'Only these accounts';

  @override
  String get budgetAccountsAll => 'All accounts';

  @override
  String get budgetAccountsNeeded => 'Choose at least one account.';

  @override
  String get budgetExcludedLabel => 'Leave out these categories';

  @override
  String get budgetNothingExcluded => 'Nothing left out';

  @override
  String get budgetIncludePending => 'Count pending transactions';

  @override
  String get budgetRefundsRestore => 'Refunds give money back to the budget';

  @override
  String get budgetCountGroupShares => 'Count my share of group expenses';

  @override
  String get budgetRolloverSection => 'Carry over';

  @override
  String get budgetRolloverLabel => 'At the end of a period';

  @override
  String get budgetRolloverNone => 'Start fresh each period';

  @override
  String get budgetRolloverUnused => 'Carry unused money forward';

  @override
  String get budgetRolloverOverspend => 'Carry overspending forward';

  @override
  String get budgetRolloverBoth => 'Carry both forward';

  @override
  String get budgetRolloverUnknown => 'Other';

  @override
  String get budgetRolloverCapLabel => 'Most that can carry over';

  @override
  String get budgetRolloverCapHelp => 'Leave empty for no cap.';

  @override
  String get budgetRolloverCustomNote =>
      'Custom-date budgets don\'t carry anything over.';

  @override
  String get budgetAlertsSection => 'Alerts';

  @override
  String get budgetThresholdsLabel => 'Tell me when I\'ve used';

  @override
  String budgetThresholdsHelp(int max) {
    return 'Choose 1 to $max.';
  }

  @override
  String budgetThresholdValue(int value) {
    return '$value%';
  }

  @override
  String get budgetForecastAlert => 'Warn me if I\'m likely to go over';

  @override
  String get budgetForecastHelp =>
      'Based on your spending pace. It\'s an estimate.';

  @override
  String get budgetVisibilityLabel => 'Who can see it';

  @override
  String get budgetVisibilityMembers => 'Everyone in the group';

  @override
  String get budgetVisibilityPrivate => 'Only me and people I add';

  @override
  String get budgetCreateButton => 'Create budget';

  @override
  String get budgetCreated => 'Budget created.';

  @override
  String get budgetSaved => 'Budget saved.';

  @override
  String get budgetEditAppliesNote =>
      'Changes apply from the current period onward. Earlier periods keep their numbers.';

  @override
  String get budgetTypeUnknownNote =>
      'This budget type isn\'t supported in this version of the app. Choose a type to save changes.';

  @override
  String get budgetSettingsTitle => 'Settings';

  @override
  String get budgetThresholdsShort => 'Alert levels';

  @override
  String get budgetForecastShort => 'Overspending forecast';

  @override
  String get budgetTimezoneLabel => 'Time zone';

  @override
  String get budgetMembersTitle => 'Shared with';

  @override
  String get budgetYouOwn => 'You own this budget.';

  @override
  String get budgetMembersEmpty => 'Only you can see this budget.';

  @override
  String get budgetMembersGroupNote =>
      'Group members can see it if you choose \"Everyone in the group\".';

  @override
  String get budgetMemberAdd => 'Add a person';

  @override
  String get budgetRoleEditor => 'Can edit';

  @override
  String get budgetRoleViewer => 'Can view';

  @override
  String get budgetRoleLabel => 'Access';

  @override
  String get budgetMemberAllocationLabel => 'Their share of the limit';

  @override
  String get budgetMemberAllocationHelp =>
      'Optional. Shown to them as their part of the limit.';

  @override
  String budgetMemberShareTitle(String name) {
    return 'Share with $name';
  }

  @override
  String budgetMemberEditTitle(String name) {
    return '$name\'s access';
  }

  @override
  String get budgetMemberShareButton => 'Share';

  @override
  String get budgetMemberRemove => 'Remove from budget';

  @override
  String budgetMemberRemoveTitle(String name) {
    return 'Remove $name?';
  }

  @override
  String get budgetMemberRemoveBody =>
      'They won\'t see this budget anymore. You can add them again later.';

  @override
  String budgetMemberAdded(String name) {
    return '$name can now see this budget.';
  }

  @override
  String get budgetMemberUpdated => 'Access updated.';

  @override
  String budgetMemberRemoved(String name) {
    return '$name was removed.';
  }

  @override
  String budgetMemberShare(String amount) {
    return 'Share: $amount';
  }

  @override
  String get budgetLeave => 'Leave this budget';

  @override
  String get budgetLeaveTitle => 'Leave this budget?';

  @override
  String get budgetLeaveBody =>
      'You\'ll stop seeing it. The owner can add you again.';

  @override
  String get budgetLeaveDone => 'You left the budget.';

  @override
  String get budgetPause => 'Pause';

  @override
  String get budgetResume => 'Resume';

  @override
  String get budgetArchive => 'Archive';

  @override
  String get budgetPaused => 'Budget paused.';

  @override
  String get budgetResumed => 'Budget resumed.';

  @override
  String get budgetArchived => 'Budget archived. Its history is kept.';

  @override
  String get budgetRestored => 'Budget restored.';

  @override
  String get budgetArchiveTitle => 'Archive this budget?';

  @override
  String budgetArchiveBody(String name) {
    return '$name stops tracking spending, and its history is kept. You can restore it later.';
  }

  @override
  String get budgetPausedNotice =>
      'This budget is paused. Spending isn\'t tracked against it until you resume it.';

  @override
  String get budgetArchivedNotice =>
      'This budget is archived. Its history is kept; restore it to track spending again.';

  @override
  String get budgetAlertStatusActive => 'Active';

  @override
  String get budgetAlertStatusSnoozed => 'Snoozed';

  @override
  String get budgetAlertStatusDismissed => 'Dismissed';

  @override
  String get budgetAlertStatusAll => 'All';

  @override
  String get budgetAlertFilterLabel => 'Show alerts';

  @override
  String budgetAlertThreshold(String name, int percent) {
    return '$name: $percent% of the limit used';
  }

  @override
  String budgetAlertFullyUsed(String name) {
    return '$name: the whole limit is used';
  }

  @override
  String budgetAlertForecast(String name) {
    return '$name may go over its limit';
  }

  @override
  String get budgetAlertForecastBody =>
      'At the current pace this budget may be exceeded before the period ends. This is an estimate.';

  @override
  String budgetAlertUnusual(String name) {
    return 'Unusual spending in $name';
  }

  @override
  String budgetAlertOther(String name) {
    return 'An update about $name';
  }

  @override
  String budgetAlertPeriod(String date) {
    return 'Period from $date';
  }

  @override
  String budgetAlertTriggered(String time) {
    return 'Noticed $time';
  }

  @override
  String budgetAlertSnoozedUntil(String time) {
    return 'Snoozed until $time';
  }

  @override
  String get budgetAlertDismiss => 'Dismiss';

  @override
  String get budgetAlertSnooze => 'Snooze';

  @override
  String get budgetAlertReactivate => 'Show again';

  @override
  String get budgetAlertDismissed => 'Alert dismissed.';

  @override
  String budgetAlertSnoozedDone(String time) {
    return 'Alert snoozed until $time.';
  }

  @override
  String get budgetAlertReactivated => 'The alert is active again.';

  @override
  String get budgetSnoozeTitle => 'Snooze until';

  @override
  String get budgetSnoozeDay => 'For 1 day';

  @override
  String get budgetSnooze3Days => 'For 3 days';

  @override
  String get budgetSnoozeWeek => 'For a week';

  @override
  String get budgetSnoozePickDate => 'Until a date…';

  @override
  String get budgetAlertsEmptyActive =>
      'No active alerts. You\'ll see one here when a budget reaches a level you chose.';

  @override
  String get budgetAlertsEmptyOther => 'Nothing here.';

  @override
  String budgetAlertsBannerTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count budget alerts',
      one: '1 budget alert',
    );
    return '$_temp0';
  }

  @override
  String get budgetAlertsBannerReview => 'Review';

  @override
  String get budgetHistoryEmpty => 'No figures for this period yet.';

  @override
  String get categoriesTitle => 'Categories';

  @override
  String get categoriesIntro =>
      'Categories group your spending and income. Subcategories sit under a main category.';

  @override
  String get categoriesShowArchived => 'Show archived and merged';

  @override
  String get categoriesEmptyTitle => 'No categories yet';

  @override
  String get categoriesEmptyBody =>
      'Add one to start sorting your transactions.';

  @override
  String get categoryNew => 'New category';

  @override
  String get categoryNewTitle => 'New category';

  @override
  String get categoryEditTitle => 'Edit category';

  @override
  String get categoryEdit => 'Edit';

  @override
  String categoryActionsFor(String name) {
    return 'More actions for $name';
  }

  @override
  String get categoryAddSubcategory => 'Add a subcategory';

  @override
  String get categoryMergeInto => 'Merge into another category';

  @override
  String get categoryMergeIntoHelp =>
      'Moves its transactions and settings, then retires it.';

  @override
  String get categoryArchive => 'Archive';

  @override
  String get categoryArchiveHelp =>
      'Hidden from pickers; past transactions keep it.';

  @override
  String get categoryRestore => 'Restore';

  @override
  String get categoryDelete => 'Delete';

  @override
  String categoryDeleteTitle(String name) {
    return 'Delete “$name”?';
  }

  @override
  String get categoryDeleteBody =>
      'Nothing uses this category. Deleting it can\'t be undone.';

  @override
  String categoryDeleted(String name) {
    return '“$name” deleted.';
  }

  @override
  String categoryArchived(String name) {
    return '“$name” archived. Past transactions keep it.';
  }

  @override
  String categoryRestored(String name) {
    return '“$name” restored.';
  }

  @override
  String get categoryInUse =>
      'Some records still use this category. Merge it into another category or archive it instead.';

  @override
  String get categoryMerge => 'Merge';

  @override
  String categoryMergeTargetTitle(String name) {
    return 'Merge “$name” into…';
  }

  @override
  String categoryMergeTitle(String source, String target) {
    return 'Merge “$source” into “$target”?';
  }

  @override
  String categoryMergeBody(String moves, String name) {
    return 'These move to the new category:\n$moves\n\n“$name” will then be marked as merged. This can\'t be undone.';
  }

  @override
  String categoryMergeNothing(String name) {
    return 'Nothing uses “$name” yet. It will be marked as merged. This can\'t be undone.';
  }

  @override
  String categoryMerged(String source, String target) {
    return '“$source” merged into “$target”.';
  }

  @override
  String categoryCreated(String name) {
    return 'Category “$name” added.';
  }

  @override
  String get categorySaved => 'Category saved.';

  @override
  String get categoryNotFound => 'This category isn\'t available any more.';

  @override
  String get categoryStarterNote =>
      'This is one of Montra\'s starter categories. You can rename it; until you do, it shows in your language.';

  @override
  String get categoryNameLabel => 'Name';

  @override
  String get categoryNameRequired => 'Enter a name.';

  @override
  String get categoryKindLabel => 'Used for';

  @override
  String get categoryKindExpense => 'Spending';

  @override
  String get categoryKindIncome => 'Income';

  @override
  String get categoryKindBoth => 'Both';

  @override
  String get categoryKindOther => 'Other';

  @override
  String get categoryParentLabel => 'Main category';

  @override
  String get categoryParentNone => 'None (this is a main category)';

  @override
  String get categoryParentHelp => 'Choose one to make this a subcategory.';

  @override
  String get categoryParentHasChildren =>
      'This category has subcategories, so it stays a main category.';

  @override
  String get categoryIconLabel => 'Icon';

  @override
  String get categoryIncludeInBudgets => 'Count in budgets';

  @override
  String get categoryIncludeInBudgetsHelp =>
      'Turn off for things you don\'t want budgets to track.';

  @override
  String get categoryNotInBudgets => 'Not in budgets';

  @override
  String get categorySortLabel => 'Position in lists (optional)';

  @override
  String get categorySortHelp => 'Lower numbers come first.';

  @override
  String get categoryStatusArchived => 'Archived';

  @override
  String get categoryStatusMerged => 'Merged';

  @override
  String categoryTransactionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions',
      one: '1 transaction',
      zero: 'No transactions',
    );
    return '$_temp0';
  }

  @override
  String get categoryIconCart => 'Groceries';

  @override
  String get categoryIconFood => 'Food';

  @override
  String get categoryIconTransport => 'Transport';

  @override
  String get categoryIconFuel => 'Fuel';

  @override
  String get categoryIconHome => 'Home';

  @override
  String get categoryIconUtilities => 'Utilities';

  @override
  String get categoryIconShopping => 'Shopping';

  @override
  String get categoryIconHealth => 'Health';

  @override
  String get categoryIconEducation => 'Education';

  @override
  String get categoryIconEntertainment => 'Entertainment';

  @override
  String get categoryIconTravel => 'Travel';

  @override
  String get categoryIconPersonalCare => 'Personal care';

  @override
  String get categoryIconInsurance => 'Insurance';

  @override
  String get categoryIconBills => 'Bills';

  @override
  String get categoryIconGifts => 'Gifts';

  @override
  String get categoryIconFamily => 'Family';

  @override
  String get categoryIconWork => 'Work';

  @override
  String get categoryIconMoney => 'Money';

  @override
  String get categoryIconTech => 'Gadgets';

  @override
  String get categoryIconSavings => 'Savings';

  @override
  String get categoryIconOther => 'Other';

  @override
  String get labelColorLabel => 'Color';

  @override
  String get labelColorNone => 'No color';

  @override
  String get labelColorCustom => 'Custom color';

  @override
  String get labelColorRed => 'Red';

  @override
  String get labelColorOrange => 'Orange';

  @override
  String get labelColorYellow => 'Yellow';

  @override
  String get labelColorGreen => 'Green';

  @override
  String get labelColorTeal => 'Teal';

  @override
  String get labelColorBlue => 'Blue';

  @override
  String get labelColorPurple => 'Purple';

  @override
  String get labelColorPink => 'Pink';

  @override
  String get labelColorBrown => 'Brown';

  @override
  String get labelColorGrey => 'Grey';

  @override
  String mergeAffectedTransactions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions',
      one: '1 transaction',
    );
    return '$_temp0';
  }

  @override
  String mergeAffectedSubcategories(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count subcategories',
      one: '1 subcategory',
    );
    return '$_temp0';
  }

  @override
  String mergeAffectedRules(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count category rules',
      one: '1 category rule',
    );
    return '$_temp0';
  }

  @override
  String mergeAffectedBudgets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count budget limits',
      one: '1 budget limit',
    );
    return '$_temp0';
  }

  @override
  String mergeAffectedMerchants(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count merchant defaults',
      one: '1 merchant default',
    );
    return '$_temp0';
  }

  @override
  String mergeAffectedRecurring(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recurring rules',
      one: '1 recurring rule',
    );
    return '$_temp0';
  }

  @override
  String mergeAffectedBills(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bills',
      one: '1 bill',
    );
    return '$_temp0';
  }

  @override
  String mergeAffectedSubscriptions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count subscriptions',
      one: '1 subscription',
    );
    return '$_temp0';
  }

  @override
  String mergeAffectedOther(String kind, int count) {
    return '$kind: $count';
  }

  @override
  String get categoryRulesTitle => 'Category rules';

  @override
  String get categoryRulesIntro =>
      'Rules set the category for you when a transaction\'s merchant or description matches. They run in order; the first match wins.';

  @override
  String get categoryRulesEmptyTitle => 'No rules yet';

  @override
  String get categoryRulesEmptyBody =>
      'Add a rule, for example: merchant contains “swiggy” → Food.';

  @override
  String get ruleNew => 'New rule';

  @override
  String get ruleNewTitle => 'New rule';

  @override
  String get ruleEditTitle => 'Edit rule';

  @override
  String get ruleNotFound => 'This rule isn\'t available any more.';

  @override
  String ruleSummary(
    String field,
    String match,
    String pattern,
    String category,
  ) {
    return '$field $match “$pattern” → $category';
  }

  @override
  String rulePriorityValue(int priority) {
    return 'Order $priority';
  }

  @override
  String get ruleStatusOff => 'Turned off';

  @override
  String get ruleCategoryMissing => 'Unavailable category';

  @override
  String get ruleNameLabel => 'Rule name';

  @override
  String get ruleNameHelp => 'Just for you, e.g. “Food delivery”.';

  @override
  String get ruleNameRequired => 'Enter a name.';

  @override
  String get ruleWhenSection => 'When';

  @override
  String get ruleThenSection => 'Then set the category to';

  @override
  String get ruleLimitsSection => 'Only for (optional)';

  @override
  String get ruleFieldLabel => 'Look at';

  @override
  String get ruleFieldMerchant => 'Merchant';

  @override
  String get ruleFieldDescription => 'Description';

  @override
  String get ruleFieldAny => 'Merchant or description';

  @override
  String get ruleMatchTypeLabel => 'Match';

  @override
  String get ruleMatchContains => 'contains';

  @override
  String get ruleMatchEquals => 'is exactly';

  @override
  String get ruleMatchStartsWith => 'starts with';

  @override
  String get ruleMatchRegex => 'matches the pattern';

  @override
  String get rulePatternLabel => 'Text to match';

  @override
  String get rulePatternHelp => 'Capital letters don\'t matter.';

  @override
  String get rulePatternRegexHelp => 'Advanced: a regular expression.';

  @override
  String get rulePatternRequired => 'Enter the text to match.';

  @override
  String get ruleCategoryLabel => 'Category';

  @override
  String get ruleCategoryPlaceholder => 'Choose a category';

  @override
  String get ruleCategoryRequired => 'Choose the category to set.';

  @override
  String get ruleTypeLabel => 'Transaction type';

  @override
  String get ruleTypeAny => 'Any type';

  @override
  String get ruleTypeExpense => 'Expenses';

  @override
  String get ruleTypeIncome => 'Income';

  @override
  String get ruleAccountLabel => 'Account';

  @override
  String get ruleAccountAny => 'Any account';

  @override
  String get ruleAmountMin => 'Smallest amount (optional)';

  @override
  String get ruleAmountMax => 'Largest amount (optional)';

  @override
  String ruleAmountHelp(String currency) {
    return 'Amounts are in $currency. Leave empty for any amount.';
  }

  @override
  String get ruleApplyToLabel => 'Use for new transactions';

  @override
  String get ruleApplyAll => 'Added by me and imported';

  @override
  String get ruleApplyManual => 'Only ones I add';

  @override
  String get ruleApplyImports => 'Only imported ones';

  @override
  String get rulePriorityLabel => 'Order';

  @override
  String get rulePriorityHelp =>
      '0 to 10000. Lower numbers run first; the first matching rule wins.';

  @override
  String get rulePriorityInvalid => 'Enter a number from 0 to 10000.';

  @override
  String get ruleEnabledLabel => 'Rule is on';

  @override
  String get ruleEnabledHelp => 'Turned-off rules are kept but don\'t run.';

  @override
  String get rulePreviewSection => 'Try it on past transactions';

  @override
  String get ruleOnlyUncategorized => 'Only transactions without a category';

  @override
  String get rulePreviewAction => 'Preview matches';

  @override
  String get rulePreviewNone => 'No past transactions match.';

  @override
  String rulePreviewCount(int count, int shown) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Matches $count transactions',
      one: 'Matches 1 transaction',
    );
    return '$_temp0 (showing $shown).';
  }

  @override
  String ruleApplyAction(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Apply to these $count transactions',
      one: 'Apply to this transaction',
    );
    return '$_temp0';
  }

  @override
  String ruleApplyTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Change $count transactions?',
      one: 'Change 1 transaction?',
    );
    return '$_temp0';
  }

  @override
  String ruleApplyBody(String category) {
    return 'Their category will change to $category. You can still change any of them later.';
  }

  @override
  String get ruleApplyConfirm => 'Change';

  @override
  String ruleApplied(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Updated $count transactions.',
      one: 'Updated 1 transaction.',
      zero: 'No transactions needed a change.',
    );
    return '$_temp0';
  }

  @override
  String get ruleSaved => 'Rule saved.';

  @override
  String get ruleDelete => 'Delete rule';

  @override
  String ruleDeleteTitle(String name) {
    return 'Delete the rule “$name”?';
  }

  @override
  String get ruleDeleteBody =>
      'Transactions it already changed keep their category.';

  @override
  String get ruleDeleted => 'Rule deleted.';

  @override
  String get tagsTitle => 'Tags';

  @override
  String get tagsIntro =>
      'Tags are your own labels, like “trip” or “work”, and a transaction can have several.';

  @override
  String get tagsShowArchived => 'Show archived tags';

  @override
  String get tagsEmptyTitle => 'No tags yet';

  @override
  String get tagsEmptyBody => 'Add one here or while saving a transaction.';

  @override
  String get tagNew => 'New tag';

  @override
  String get tagEdit => 'Rename or recolor';

  @override
  String get tagNameLabel => 'Tag name';

  @override
  String get tagNameRequired => 'Enter a name.';

  @override
  String get tagNameTaken => 'You already have a tag with this name.';

  @override
  String tagCreated(String name) {
    return 'Tag “$name” added.';
  }

  @override
  String get tagSaved => 'Tag saved.';

  @override
  String get tagSeeTransactions => 'See transactions';

  @override
  String get tagArchive => 'Archive';

  @override
  String get tagArchiveHelp => 'Hidden from pickers; transactions keep it.';

  @override
  String get tagUnarchive => 'Unarchive';

  @override
  String tagArchived(String name) {
    return '“$name” archived.';
  }

  @override
  String tagUnarchived(String name) {
    return '“$name” is back in your tag lists.';
  }

  @override
  String get tagDelete => 'Delete';

  @override
  String tagDeleteTitle(String name) {
    return 'Delete the tag “$name”?';
  }

  @override
  String tagDeleteBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'It will be removed from $count transactions. The transactions stay.',
      one: 'It will be removed from 1 transaction. The transaction stays.',
      zero: 'It isn\'t on any transactions.',
    );
    return '$_temp0';
  }

  @override
  String tagDeleted(String name) {
    return '“$name” deleted.';
  }

  @override
  String get tagStatusArchived => 'Archived';

  @override
  String get merchantsTitle => 'Merchants';

  @override
  String get merchantsSearch => 'Search by name or other name';

  @override
  String get merchantsEmptyTitle => 'No merchants yet';

  @override
  String get merchantsEmptyBody =>
      'Merchants are added when you save transactions with a merchant.';

  @override
  String get merchantsNoMatch => 'No merchants match.';

  @override
  String get merchantDetailTitle => 'Merchant';

  @override
  String merchantLastUsed(String date) {
    return 'Last used $date';
  }

  @override
  String merchantAlsoKnownAs(String names) {
    return 'Also: $names';
  }

  @override
  String get merchantStatusArchived => 'Archived';

  @override
  String get merchantEdit => 'Edit merchant';

  @override
  String get merchantMoreActions => 'More actions';

  @override
  String get merchantDetailsSection => 'Details';

  @override
  String get merchantDefaultCategory => 'Default category';

  @override
  String get merchantDefaultCategoryHelp =>
      'Suggested when you add a transaction here.';

  @override
  String get merchantNoDefaultCategory => 'None';

  @override
  String get merchantTransactionsLabel => 'Transactions';

  @override
  String get merchantLastUsedLabel => 'Last used';

  @override
  String get merchantWebsiteLabel => 'Website';

  @override
  String get merchantWebsiteFailed => 'Couldn\'t open this website.';

  @override
  String get merchantNotesLabel => 'Notes';

  @override
  String get merchantSpendingSection => 'Spending, last 12 months';

  @override
  String get merchantNoSpending => 'No spending here in the last 12 months.';

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
      other: '$months months',
      one: '1 month',
    );
    return 'In $currency, $_temp0 with spending; the highest was $month at $amount. Refunds are subtracted.';
  }

  @override
  String merchantSpendingSummaryNone(String currency) {
    return 'In $currency, refunds cancelled out the spending in these months.';
  }

  @override
  String get merchantAliasesSection => 'Other names';

  @override
  String get merchantAliasesHelp =>
      'Names this merchant appears under, for example on bank statements.';

  @override
  String get merchantNoAliases => 'No other names yet.';

  @override
  String get merchantAddAlias => 'Add another name';

  @override
  String merchantAliasDialogBody(String name) {
    return 'Transactions with this name will be matched to $name.';
  }

  @override
  String get merchantAliasLabel => 'Other name';

  @override
  String get merchantAliasRequired => 'Enter a name.';

  @override
  String merchantAliasAdded(String alias) {
    return '“$alias” added as another name.';
  }

  @override
  String get merchantSeeTransactions => 'See transactions';

  @override
  String get merchantMergeAction => 'Merge another merchant into this one';

  @override
  String get merchantMergeHelp => 'For duplicates of the same place.';

  @override
  String merchantMergePickTitle(String name) {
    return 'Merge into “$name”';
  }

  @override
  String merchantMergeTitle(String source, String target) {
    return 'Merge “$source” into “$target”?';
  }

  @override
  String merchantMergeBody(int count, String source, String target) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Its $count transactions move to “$target”.',
      one: 'Its 1 transaction moves to “$target”.',
      zero: '“$source” has no transactions.',
    );
    return '$_temp0 Its names are kept as other names of “$target”. This can\'t be undone.';
  }

  @override
  String get merchantMergeConfirm => 'Merge';

  @override
  String merchantMerged(String source, String target) {
    return '“$source” merged into “$target”.';
  }

  @override
  String get merchantMergedNote => 'This merchant was merged into another one.';

  @override
  String get merchantArchive => 'Archive';

  @override
  String get merchantArchiveHelp =>
      'Hidden from suggestions; past transactions keep it.';

  @override
  String get merchantUnarchive => 'Unarchive';

  @override
  String merchantArchived(String name) {
    return '“$name” archived.';
  }

  @override
  String merchantUnarchived(String name) {
    return '“$name” is back in suggestions.';
  }

  @override
  String get merchantArchivedNote =>
      'Archived: it isn\'t suggested for new transactions.';

  @override
  String get merchantNameLabel => 'Name';

  @override
  String get merchantNameRequired => 'Enter a name.';

  @override
  String get merchantNameTaken =>
      'Another merchant already has this name. Merge them instead.';

  @override
  String get merchantSaved => 'Merchant saved.';

  @override
  String get recurringOpenTooltip => 'Recurring payments';

  @override
  String get profileOrganizeTitle => 'Organize';

  @override
  String get profileCategoriesSubtitle => 'Main categories and subcategories';

  @override
  String get profileRulesSubtitle => 'Set categories automatically';

  @override
  String get profileTagsSubtitle => 'Your own labels for transactions';

  @override
  String get profileMerchantsSubtitle => 'Names, other names and spending';

  @override
  String get homePlanTitle => 'Plan ahead';

  @override
  String get homePlanBudgets => 'Budgets';

  @override
  String get homePlanGoals => 'Goals';

  @override
  String get homePlanBills => 'Bills';

  @override
  String get homePlanSubscriptions => 'Subscriptions';

  @override
  String get homePlanRecurring => 'Recurring';

  @override
  String get homePlanCalendar => 'Calendar';

  @override
  String get errorStorageUnavailable =>
      'File storage isn\'t available right now. Try again in a few minutes.';

  @override
  String get errorFeatureNotConfigured =>
      'This feature isn\'t set up on this server yet.';

  @override
  String get errorPayloadTooLarge =>
      'This file is too large. Choose a smaller file.';

  @override
  String get errorUnsupportedFile =>
      'This file type isn\'t accepted, or its content doesn\'t match its type. Try another file.';

  @override
  String get errorRuleTransactionVoided => 'Restore this transaction first.';

  @override
  String get errorRuleFileNotReady => 'Finish uploading the file first.';

  @override
  String get errorRuleFileNotAttachable =>
      'This file can\'t be attached to a transaction.';

  @override
  String errorRuleStatusTransition(String from, String to) {
    return 'This can\'t change from $from to $to. Reload to see where it stands now.';
  }

  @override
  String errorRuleRecordLimit(String resource, String limit) {
    String _temp0 = intl.Intl.selectLogic(resource, {
      'bills': 'You can keep up to $limit open bills.',
      'recurring_rules': 'You can keep up to $limit recurring payments.',
      'subscriptions': 'You can keep up to $limit subscriptions.',
      'goals': 'You can keep up to $limit goals.',
      'other': 'You can keep up to $limit of these.',
    });
    return '$_temp0 End, archive or delete ones you no longer need.';
  }

  @override
  String errorMerchantNameTaken(String name) {
    return 'Another merchant is already called “$name”. Merge them instead.';
  }

  @override
  String errorNameTaken(String name) {
    return '“$name” is already used. Choose another name.';
  }

  @override
  String get errorCategoryInUse =>
      'This category is used by existing records. Merge it into another category or archive it instead.';

  @override
  String get errorRuleCategoryUnavailable =>
      'This rule\'s category is archived or no longer fits the rule. Restore the category or choose another one.';

  @override
  String get errorRuleCategoryMerged =>
      'This category was merged and can\'t be changed any more.';

  @override
  String get errorRuleCategoryAlreadyMerged =>
      'One of these categories was already merged.';

  @override
  String get errorRuleCategoryDepth =>
      'Categories can have only one level of subcategories.';

  @override
  String get errorRuleParentArchived =>
      'The main category is archived. Restore it first.';

  @override
  String get errorRuleMergeTargetInactive => 'Merge into an active category.';

  @override
  String get errorRuleMergeTargetTopLevel =>
      'A category with subcategories can only be merged into a main category.';

  @override
  String get errorRuleGroupBudgetType =>
      'Group budgets track all of the group\'s expenses. Use a total budget, or split it between members.';

  @override
  String get errorRuleGroupBudgetFilter =>
      'Group budgets count all of the group\'s expenses, so account, category and merchant filters don\'t apply.';

  @override
  String get errorRuleGroupBudgetAllocation =>
      'Group budgets are split between members, not categories, merchants or accounts.';

  @override
  String get errorRuleGroupBudget =>
      'Group budgets track group expenses. Open the group to see them.';

  @override
  String get errorRuleZeroBasedUnallocated =>
      'A zero-based budget must give out exactly the full limit.';

  @override
  String get errorRuleScheduleEnded =>
      'This schedule has ended. Edit it to set new dates.';

  @override
  String get errorRuleRecurringInUse =>
      'This can\'t be deleted because it has history. Stop it instead.';

  @override
  String get errorRuleNoOpenOccurrence => 'Nothing is unpaid right now.';

  @override
  String get errorRuleOccurrenceNotOpen =>
      'That payment is already paid, skipped or no longer part of this bill.';

  @override
  String get errorRuleOccurrenceNotSkipped =>
      'Only skipped payments can be reopened.';

  @override
  String get errorRuleOccurrenceHandled => 'This payment was already handled.';

  @override
  String get errorRulePostponeLater => 'Move an open payment to a later date.';

  @override
  String get errorRuleUseBillScreen =>
      'Change bills from the bill\'s own screen.';

  @override
  String get errorRuleAutoPostNeeds =>
      'Recording automatically needs a fixed amount and an account.';

  @override
  String get errorRuleBillInactive =>
      'Restore the bill before recording payments.';

  @override
  String get errorRuleBillsNotAutoPosted =>
      'Bills are confirmed by linking or recording the actual payment.';

  @override
  String get errorRuleTransferTwoAccounts =>
      'Recurring transfers need two different accounts.';

  @override
  String get errorRuleTransferDestination =>
      'This transfer has no destination account.';

  @override
  String get errorRuleCrossCurrencyAutoPost =>
      'Transfers between currencies need the received amount each time, so they can\'t be recorded automatically.';

  @override
  String get errorRuleSubscriptionInactive =>
      'Reactivate the subscription before recording new payments.';

  @override
  String get errorRuleSubscriptionNotCancelled =>
      'Only a cancelled subscription has a cancellation date.';

  @override
  String get errorRuleDetectionDecided =>
      'This possible subscription was already reviewed.';

  @override
  String get errorRuleDetectionEvidenceMissing =>
      'The transactions behind this match no longer exist. Dismiss it.';

  @override
  String get errorPaymentAlreadyLinked =>
      'This payment is already recorded for this subscription.';

  @override
  String get errorPaymentLinkedElsewhere =>
      'This payment is already recorded for another subscription.';

  @override
  String get errorCancellationConfirmationRequired =>
      'Confirm that you cancelled with the provider.';

  @override
  String get errorRuleGoalInactive =>
      'Contributions can be added to active goals only.';

  @override
  String get errorRuleOwnerRoleFixed => 'The owner\'s role can\'t change.';

  @override
  String get errorRuleOwnerCannotLeave =>
      'The owner can\'t leave or be removed. Archive the goal instead.';

  @override
  String get errorRuleMemberVisibility =>
      'Members choose who sees their own contributions.';

  @override
  String get errorRuleContributionNotPlanned =>
      'This contribution is already recorded.';

  @override
  String get errorRuleContributionVoided => 'This contribution was voided.';

  @override
  String get errorTransactionAlreadyCounted =>
      'This transaction already counts toward a goal.';

  @override
  String errorRuleWithdrawalExceedsSaved(String saved, String currency) {
    return 'A withdrawal can\'t be more than what\'s saved ($saved $currency).';
  }

  @override
  String errorRuleStorageQuota(String quota) {
    return 'This upload would go over your $quota storage allowance. Delete files you no longer need first.';
  }

  @override
  String get errorRuleReceiptIncomplete =>
      'Add the receipt\'s date and total first.';

  @override
  String get errorRuleReceiptNotReviewed =>
      'Save the receipt details before recording the purchase.';

  @override
  String get errorRuleNoRows => 'There are no rows to import.';

  @override
  String get errorRuleRowInvalid =>
      'Fix this row\'s date, amount or direction before importing it.';

  @override
  String get errorRuleDirectionMismatch =>
      'Statement rows and transactions must both be money in, or both money out.';

  @override
  String get errorRuleInvalidMatchShape =>
      'Match one statement row to several transactions, or several rows to one transaction.';

  @override
  String get errorRuleInvalidPair =>
      'Choose one pending and one posted transaction going the same way.';

  @override
  String errorRuleSumsDiffer(String statement, String ledger, String currency) {
    return 'The statement side ($statement $currency) and the transactions ($ledger $currency) don\'t add up to the same amount.';
  }

  @override
  String get errorRuleReportTooLarge =>
      'The report has too many transactions. Choose a shorter period or fewer filters.';

  @override
  String get errorRuleBalanceAlreadyMatches =>
      'The balance already matches, so nothing needs adjusting.';

  @override
  String get statusWordActive => 'active';

  @override
  String get statusWordPaused => 'paused';

  @override
  String get statusWordArchived => 'archived';

  @override
  String get statusWordEnded => 'ended';

  @override
  String get statusWordAchieved => 'achieved';

  @override
  String get statusWordCancelled => 'cancelled';

  @override
  String get statusWordCancelling => 'being cancelled';

  @override
  String get statusWordTrial => 'on trial';

  @override
  String get statusWordVoided => 'deleted';

  @override
  String get statusWordPending => 'pending';

  @override
  String get statusWordPosted => 'posted';

  @override
  String get statusWordUnknown => 'its current state';

  @override
  String get fileEmpty => 'This file is empty. Choose another file.';

  @override
  String fileTooLarge(String size) {
    return 'This file is larger than $size. Choose a smaller file.';
  }

  @override
  String fileTypeNotAccepted(String types) {
    return 'This file type isn\'t accepted here. Use $types.';
  }

  @override
  String get fileCameraUnavailable =>
      'The camera isn\'t available. Choose a photo or a file instead.';

  @override
  String get fileSourceTitle => 'Add a file';

  @override
  String get fileSourceCamera => 'Take a photo';

  @override
  String get fileSourcePhotos => 'Choose a photo';

  @override
  String get fileSourceFiles => 'Choose a file';

  @override
  String fileAcceptedTypes(String types, String size) {
    return '$types, up to $size';
  }

  @override
  String get uploadStageChecking => 'Checking the file…';

  @override
  String get uploadStageAuthorizing => 'Preparing the upload…';

  @override
  String get uploadStageSending => 'Uploading…';

  @override
  String uploadStageSendingPercent(int percent) {
    return 'Uploading… $percent%';
  }

  @override
  String get uploadStageFinishing => 'Finishing…';

  @override
  String get uploadCancel => 'Cancel upload';

  @override
  String get uploadCancelled => 'Upload cancelled.';

  @override
  String get fileShare => 'Share';

  @override
  String get fileSave => 'Save to device';

  @override
  String get fileSaved => 'Saved.';

  @override
  String get fileOpen => 'Open';

  @override
  String get fileDownloading => 'Downloading…';

  @override
  String filePreviewLabel(String name) {
    return 'Preview of $name';
  }

  @override
  String get homeToolsTitle => 'Review your money';

  @override
  String get entryReceipts => 'Receipts';

  @override
  String get entryReceiptsSubtitle =>
      'Photos and PDFs of receipts, checked by you';

  @override
  String get entryImports => 'Statement imports';

  @override
  String get entryImportsShort => 'Import a statement';

  @override
  String get entryImportsSubtitle =>
      'Bring in transactions from your bank\'s CSV, XLSX or OFX file';

  @override
  String get entryAnalytics => 'Analytics';

  @override
  String get entryAnalyticsSubtitle =>
      'Cash flow, spending and trends, one currency at a time';

  @override
  String get entryReports => 'Reports';

  @override
  String get entryReportsSubtitle =>
      'Summaries and exports to download or schedule';

  @override
  String get entryExchangeRates => 'Exchange rates';

  @override
  String get entryExchangeRatesSubtitle =>
      'Rates between currencies, including your own';

  @override
  String get profileDataTitle => 'Records and insights';

  @override
  String get entryReconcile => 'Reconcile';

  @override
  String get entryReconcileSubtitle => 'Check this account against a statement';

  @override
  String get entryImportStatement => 'Import a statement';

  @override
  String get billNoChanges => 'Nothing changed.';

  @override
  String get billScheduleUnknown =>
      'This bill repeats in a way this version of Montra can\'t show. Update the app to change when it\'s due; you can still edit the other details.';

  @override
  String get billReasonSameProvider => 'Same provider';

  @override
  String get billReasonSameAmount => 'Same amount';

  @override
  String get billReasonAmountClose => 'Close to the expected amount';

  @override
  String get billReasonOnDueDate => 'Paid on the due date';

  @override
  String billReasonDaysBefore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days before the due date',
      one: '1 day before the due date',
    );
    return '$_temp0';
  }

  @override
  String billReasonDaysAfter(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days after the due date',
      one: '1 day after the due date',
    );
    return '$_temp0';
  }

  @override
  String get billReasonOther => 'Looks similar';

  @override
  String get recurringNoChanges => 'Nothing changed.';

  @override
  String get recurringScheduleUnknown =>
      'This repeats in a way this version of Montra can\'t show. Update the app to change its schedule; you can still edit the other details.';

  @override
  String occurrenceMovedTo(String date) {
    return 'Moved to $date';
  }

  @override
  String get calendarStatusTarget => 'Target date';

  @override
  String get subscriptionNoChanges => 'Nothing changed.';

  @override
  String get subscriptionCancelledOnHelp =>
      'Correct the date the cancellation took effect, if needed.';

  @override
  String get subscriptionCancelledOnPickHelp =>
      'When the provider confirmed it. Today unless you change it.';

  @override
  String get subscriptionEventPaymentUnlinked => 'Payment unlinked';

  @override
  String get subscriptionEventRenewed => 'Renewed';

  @override
  String get subscriptionNoteMatchedByDetection =>
      'Linked when you added this subscription from your transactions';

  @override
  String get subscriptionLinkedPaymentsTitle => 'Linked payments';

  @override
  String get subscriptionUnlinkPayment => 'Unlink';

  @override
  String subscriptionUnlinkPaymentLabel(String date) {
    return 'Unlink the payment of $date';
  }

  @override
  String get subscriptionUnlinkConfirmTitle => 'Unlink this payment?';

  @override
  String subscriptionUnlinkConfirmBody(String name) {
    return 'The transaction stays as it is. It just won\'t count as a payment for $name any more, and you can link it again later.';
  }

  @override
  String get subscriptionPaymentUnlinked => 'Payment unlinked.';

  @override
  String get subscriptionCandidatesIntro =>
      'Charges that look like this subscription\'s payment. Choose one, or pick another transaction.';

  @override
  String get subscriptionCandidatesEmpty =>
      'No matching charges found. Choose another transaction.';

  @override
  String get subscriptionCandidatesError =>
      'We couldn\'t load suggested charges.';

  @override
  String get subscriptionChooseOtherCharge => 'Choose another transaction';

  @override
  String subscriptionCandidateExpected(String date) {
    return 'Expected around $date';
  }

  @override
  String get subscriptionReasonSameMerchant => 'Same merchant';

  @override
  String get subscriptionReasonMatchesName => 'Matches the name';

  @override
  String get subscriptionReasonSameAmount => 'Same amount';

  @override
  String get subscriptionReasonAmountClose => 'Close to the price';

  @override
  String get subscriptionReasonOnRenewalDate => 'On the renewal date';

  @override
  String subscriptionReasonDaysBefore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days before the renewal date',
      one: '1 day before the renewal date',
    );
    return '$_temp0';
  }

  @override
  String subscriptionReasonDaysAfter(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days after the renewal date',
      one: '1 day after the renewal date',
    );
    return '$_temp0';
  }

  @override
  String get subscriptionReasonOther => 'Looks similar';

  @override
  String subscriptionListCapped(int count) {
    return 'Showing the first $count subscriptions.';
  }

  @override
  String get subscriptionChecklistUpdated => 'Checklist updated.';

  @override
  String detectionReasonIntervals(int fit, int total) {
    return '$fit of $total gaps between charges fit this pattern';
  }

  @override
  String detectionReasonAmounts(int within, int count, String percent) {
    return '$within of $count amounts are within $percent% of the usual amount';
  }

  @override
  String budgetSharedByEditor(String name) {
    return 'Shared by $name · can edit';
  }

  @override
  String budgetSharedByViewer(String name) {
    return 'Shared by $name · can view';
  }

  @override
  String get budgetThresholdsNone => 'No threshold alerts';

  @override
  String budgetThresholdsChooseHelp(int max) {
    return 'Choose up to $max levels. With none chosen, you won\'t get alerts for reaching a share of the limit.';
  }

  @override
  String get budgetThresholdsClear => 'Turn off threshold alerts';

  @override
  String budgetTransactionsShowing(int shown, int total) {
    return 'Showing $shown of $total';
  }

  @override
  String get budgetMemberCannotAdd =>
      'This person can\'t be added. You can share budgets with friends and members of your groups.';

  @override
  String get budgetMemberShareInvalid => 'Check their share of the limit.';

  @override
  String get budgetNothingChanged =>
      'Nothing changed, so there was nothing to save.';

  @override
  String get budgetTypeGroupChoiceHelp =>
      'Group budgets count all of the group\'s expenses: as one total, or split between members as envelopes or zero-based.';

  @override
  String get budgetAllocationsGroupHelp =>
      'Optionally split the limit between current members of the group.';

  @override
  String get budgetAllocationsMerchantHelp =>
      'Optional limits by category, by merchant or with a name of your own.';

  @override
  String get budgetAllocationsAccountHelp =>
      'Optional limits by category, by account or with a name of your own.';

  @override
  String budgetAllocationOver(String spent, String limit, String over) {
    return '$spent spent of $limit · $over over';
  }

  @override
  String get budgetTransactionsOwnerOnlyError =>
      'Only the owner can see the individual transactions. You see the owner\'s totals.';

  @override
  String get goalMemberRoleOwner => 'Owner';

  @override
  String goalSharedBy(String name) {
    return 'Shared by $name';
  }

  @override
  String goalAssumptionExact(String currency) {
    return 'Amounts are exact in $currency; no interest, returns or inflation are assumed.';
  }

  @override
  String goalAssumptionPace(String days, String months) {
    return 'Recent pace is the net of recorded and verified contributions in the last $days days, divided by $months.';
  }

  @override
  String get goalAssumptionPlanned =>
      'Planned contributions are intentions, not money set aside, so they aren\'t counted as saved.';

  @override
  String get goalCurrencyFixed =>
      'The currency can\'t change after the goal is created.';

  @override
  String get goalNothingChanged =>
      'Nothing changed, so there was nothing to save.';

  @override
  String get goalOwnerNote =>
      'You own this goal. You can\'t leave it, but you can choose what others see of your contributions.';

  @override
  String get goalExportIntroShare =>
      'This CSV lists every contribution, including voided ones. Share it, save it to your device or copy it.';

  @override
  String get contributionRecord => 'Record';

  @override
  String contributionRecordTooltip(String date) {
    return 'Record your planned contribution of $date';
  }

  @override
  String get contributionRecordTitle => 'Record this planned contribution';

  @override
  String get contributionRecordIntro =>
      'It will count as saved. Change the amount if you set aside a different amount, and link the transaction that moved the money to verify it.';

  @override
  String get contributionRecordAmountHelp =>
      'Leave as it is if you set aside the planned amount.';

  @override
  String get contributionRecordSave => 'Record contribution';

  @override
  String get contributionRecordedDone => 'Contribution recorded.';

  @override
  String mergeAffectedBudgetFilters(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count budgets will follow the merge',
      one: '1 budget will follow the merge',
    );
    return '$_temp0';
  }

  @override
  String mergeAffectedAliases(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count other names',
      one: '1 other name',
    );
    return '$_temp0';
  }

  @override
  String merchantMergePreviewBody(String target, String moves, String source) {
    return 'These move to “$target”:\n$moves\n\n“$source” will then be marked as merged and its names kept as other names of “$target”. This can\'t be undone.';
  }

  @override
  String merchantMergePreviewNothing(String source, String target) {
    return 'Nothing uses “$source” yet. It will be marked as merged into “$target”. This can\'t be undone.';
  }

  @override
  String get merchantAliasRemove => 'Remove';

  @override
  String merchantAliasRemoveTooltip(String alias) {
    return 'Remove the other name “$alias”';
  }

  @override
  String merchantAliasRemoveTitle(String alias) {
    return 'Remove “$alias”?';
  }

  @override
  String merchantAliasRemoveBody(String name) {
    return 'New transactions with this name won\'t be matched to $name. Transactions already matched stay as they are.';
  }

  @override
  String merchantAliasRemoved(String alias) {
    return '“$alias” removed.';
  }

  @override
  String get merchantOpenMergedInto => 'Open the merchant it was merged into';

  @override
  String get merchantStatusMerged => 'Merged';

  @override
  String get merchantsFilterLabel => 'Show merchants';

  @override
  String get merchantsFilterActive => 'Active';

  @override
  String get merchantsFilterArchived => 'Archived';

  @override
  String get merchantsFilterMerged => 'Merged';

  @override
  String get merchantsFilterAll => 'All';

  @override
  String get merchantsEmptyFiltered => 'No merchants here.';

  @override
  String get ruleCurrencyLabel => 'Currency of the amounts';

  @override
  String ruleAmountCurrencyNote(String currency) {
    return 'Amount limits match only transactions in $currency.';
  }

  @override
  String ruleAmountsBetween(String min, String max) {
    return 'Amounts from $min to $max';
  }

  @override
  String ruleAmountsAtLeast(String min) {
    return 'Amounts of $min or more';
  }

  @override
  String ruleAmountsAtMost(String max) {
    return 'Amounts up to $max';
  }

  @override
  String get rulePriorityOptionalHelp =>
      'Optional: 0 to 10000. Lower numbers run first and the first matching rule wins. Empty means 100.';

  @override
  String get attachmentAdd => 'Add file';

  @override
  String get attachmentAdded => 'File attached.';

  @override
  String get attachmentsEmptyAdd =>
      'No files are attached. Add a photo or a PDF, such as a bill or a warranty.';

  @override
  String get attachmentReceiptLink => 'Receipt';

  @override
  String get attachmentReceiptLinkHelp =>
      'This transaction was recorded from a receipt.';

  @override
  String get receiptsTitle => 'Receipts';

  @override
  String get receiptAdd => 'Add receipt';

  @override
  String get receiptAdded => 'Receipt added. Enter its details next.';

  @override
  String get receiptUploadTitle => 'Uploading';

  @override
  String get receiptsManualNote =>
      'Montra never reads receipts automatically: you type the details, then link the receipt to an expense or record a new one.';

  @override
  String get receiptsEmptyTitle => 'No receipts yet';

  @override
  String get receiptsEmptyFiltered => 'No receipts here';

  @override
  String get receiptsEmptyBody =>
      'Take a photo of a receipt or choose a photo or PDF. You enter the details yourself.';

  @override
  String get receiptFilterOpen => 'In inbox';

  @override
  String get receiptFilterToReview => 'To fill in';

  @override
  String get receiptFilterReviewed => 'Ready';

  @override
  String get receiptFilterLinked => 'Linked';

  @override
  String get receiptFilterDiscarded => 'Discarded';

  @override
  String get receiptUntitled => 'Receipt';

  @override
  String get receiptNoDetails => 'Details not entered yet';

  @override
  String receiptPages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pages',
      one: '1 page',
    );
    return '$_temp0';
  }

  @override
  String get receiptPossibleDuplicate => 'Possible duplicate';

  @override
  String get receiptStatusUploaded => 'Uploaded';

  @override
  String get receiptStatusProcessing => 'Being processed';

  @override
  String get receiptStatusNeedsReview => 'Details needed';

  @override
  String get receiptStatusReviewed => 'Ready to record';

  @override
  String get receiptStatusMatched => 'Linked to a transaction';

  @override
  String get receiptStatusFailed => 'Couldn\'t be read';

  @override
  String get receiptStatusDiscarded => 'Discarded';

  @override
  String get receiptStatusOther => 'Other';

  @override
  String get receiptHelpNeedsReview =>
      'Enter the details from the receipt so you can link it to an expense or record it.';

  @override
  String get receiptHelpReviewed =>
      'Link it to an expense you already recorded, or record it as a new expense.';

  @override
  String get receiptHelpMatched =>
      'This receipt is linked to a transaction. Its pages are attached to that transaction.';

  @override
  String get receiptHelpDiscarded =>
      'This receipt was removed from your inbox. Its files are kept until you delete them.';

  @override
  String get receiptHelpProcessing =>
      'This receipt is being processed. Pull down to refresh.';

  @override
  String get receiptTitle => 'Receipt';

  @override
  String get receiptEnterDetails => 'Enter details';

  @override
  String get receiptEditDetails => 'Edit details';

  @override
  String get receiptMatchAction => 'Find the expense';

  @override
  String get receiptRecordAction => 'Record as a new expense';

  @override
  String get receiptOpenTransaction => 'Open the transaction';

  @override
  String get receiptUnlink => 'Unlink';

  @override
  String get receiptUnlinkConfirmTitle => 'Unlink this receipt?';

  @override
  String get receiptUnlinkConfirmBody =>
      'The transaction stays as it is; only the receipt pages are removed from it. You can link the receipt again later.';

  @override
  String get receiptUnlinked => 'Receipt unlinked.';

  @override
  String get receiptDiscard => 'Discard';

  @override
  String get receiptDiscardConfirmTitle => 'Discard this receipt?';

  @override
  String get receiptDiscarded => 'Receipt discarded.';

  @override
  String get receiptDuplicateNotice =>
      'This looks like a receipt you already added.';

  @override
  String get receiptOpenOther => 'Open the other receipt';

  @override
  String get receiptWarningArithmetic =>
      'The subtotal, tax, tip and discount don\'t add up to the total. Check the numbers.';

  @override
  String get receiptWarningLineItems =>
      'The items don\'t add up to the subtotal. Check the numbers.';

  @override
  String get receiptPagesTitle => 'Pages';

  @override
  String get receiptNoPages => 'This receipt has no pages.';

  @override
  String receiptPageLabel(int index, int count) {
    return 'Receipt page $index of $count';
  }

  @override
  String receiptOpenPage(int index) {
    return 'Open page $index';
  }

  @override
  String get receiptPdfPage => 'PDF – opens with Share or Save';

  @override
  String get receiptFilePage => 'File – opens with Share or Save';

  @override
  String get receiptPreviewUnavailable => 'This picture can\'t be shown.';

  @override
  String get receiptPdfHelp =>
      'PDF files open in another app. Use Share or Save.';

  @override
  String get receiptFileHelp =>
      'This file can\'t be shown in Montra. Use Share or Save.';

  @override
  String get receiptDetailsTitle => 'Details';

  @override
  String get receiptMerchant => 'Shop or merchant';

  @override
  String get receiptMerchantHelp => 'As printed on the receipt.';

  @override
  String get receiptDate => 'Date on the receipt';

  @override
  String get receiptDateChoose => 'Choose a date';

  @override
  String get receiptDateRequired => 'Choose the date on the receipt.';

  @override
  String get receiptTime => 'Time (optional)';

  @override
  String get receiptTimeNone => 'No time';

  @override
  String get receiptCurrency => 'Currency';

  @override
  String get receiptCurrencyHelp => 'The currency printed on the receipt.';

  @override
  String get receiptTotal => 'Total';

  @override
  String get receiptSubtotal => 'Subtotal';

  @override
  String get receiptTax => 'Tax';

  @override
  String get receiptTip => 'Tip';

  @override
  String get receiptDiscount => 'Discount';

  @override
  String get receiptNumber => 'Receipt number';

  @override
  String get receiptPaymentHint => 'How you paid';

  @override
  String get receiptLinkedTransaction => 'Linked transaction';

  @override
  String get receiptLineItemsTitle => 'Items';

  @override
  String receiptLineItemUnnamed(int position) {
    return 'Item $position';
  }

  @override
  String receiptQuantityValue(String quantity) {
    return 'Quantity $quantity';
  }

  @override
  String receiptUnitPriceValue(String price) {
    return '$price each';
  }

  @override
  String receiptTaxValue(String tax) {
    return 'Tax $tax';
  }

  @override
  String get receiptNotes => 'Notes';

  @override
  String get receiptHistoryTitle => 'Versions';

  @override
  String receiptVersionTitle(int version, String method) {
    return 'Version $version · $method';
  }

  @override
  String get receiptMethodManual => 'entered by you';

  @override
  String get receiptMethodAutomatic => 'read from the file';

  @override
  String get receiptReviewTitle => 'Receipt details';

  @override
  String get receiptReviewIntro =>
      'Type the details as they appear on the receipt. Only the date and the total are required.';

  @override
  String get receiptReviewUnavailable => 'These details can\'t be changed now';

  @override
  String get receiptBreakdownTitle => 'Breakdown (optional)';

  @override
  String get receiptBreakdownHelp =>
      'Add these if the receipt shows them. Montra tells you if they don\'t add up.';

  @override
  String get receiptAddLineItem => 'Add an item';

  @override
  String receiptLineItemTitle(int index) {
    return 'Item $index';
  }

  @override
  String receiptRemoveLineItem(int index) {
    return 'Remove item $index';
  }

  @override
  String get receiptLineDescription => 'Description';

  @override
  String get receiptQuantity => 'Quantity';

  @override
  String get receiptQuantityInvalid => 'Enter a number, with up to 3 decimals.';

  @override
  String get receiptUnitPrice => 'Price each';

  @override
  String get receiptLineAmount => 'Item amount';

  @override
  String get receiptLineTax => 'Item tax';

  @override
  String get receiptReviewSave => 'Save details';

  @override
  String get receiptReviewSaved => 'Receipt details saved.';

  @override
  String get receiptMatchTitle => 'Find the expense';

  @override
  String get receiptMatchIntro =>
      'These recorded expenses are close in amount and date. Linking records no new money.';

  @override
  String get receiptMatchNone =>
      'No recorded expense looks like this receipt. Choose one yourself, or record a new expense.';

  @override
  String get receiptChooseTransaction => 'Choose another expense';

  @override
  String get receiptLinkThis => 'Link';

  @override
  String get receiptLinked => 'Receipt linked to the expense.';

  @override
  String get receiptUnnamedTransaction => 'Expense';

  @override
  String get receiptCandidateAmount => 'Amount';

  @override
  String get receiptReasonSameAmount => 'same amount as the total';

  @override
  String get receiptReasonCloseAmount =>
      'amount within 20% of the total (tip or fees)';

  @override
  String get receiptReasonSameDate => 'same date';

  @override
  String get receiptReasonNearDate => 'within 3 days';

  @override
  String get receiptReasonSameMerchant => 'same merchant';

  @override
  String get receiptRecordTitle => 'Record the expense';

  @override
  String get receiptRecordIntro =>
      'The amount, date and merchant come from the receipt details. Choose the account you paid from.';

  @override
  String get receiptRecordUnavailable => 'This receipt can\'t be recorded yet';

  @override
  String get receiptRecordAccount => 'Paid from';

  @override
  String receiptRecordAccountHelp(String currency) {
    return 'Accounts in $currency, the receipt currency.';
  }

  @override
  String get receiptChooseAccount => 'Choose an account';

  @override
  String get receiptAccountRequired => 'Choose the account you paid from.';

  @override
  String get receiptRecordCategory => 'Category (optional)';

  @override
  String get receiptRecordDescription => 'Description (optional)';

  @override
  String get receiptRecordDescriptionHelp =>
      'Leave empty to use the merchant name.';

  @override
  String get receiptRecordSave => 'Record expense';

  @override
  String get receiptRecorded => 'Expense recorded from the receipt.';

  @override
  String get importsTitle => 'Statement imports';

  @override
  String get importNew => 'Import a statement';

  @override
  String get importsEmptyTitle => 'No imports yet';

  @override
  String get importsEmptyBody =>
      'Import your bank\'s CSV, XLSX or OFX statement. You check every row before anything is added.';

  @override
  String importsForAccount(String account) {
    return 'Imports into $account';
  }

  @override
  String get importsShowAll => 'Show all accounts';

  @override
  String get importUnknownAccount => 'Account not available';

  @override
  String importStartedOn(String time) {
    return 'Started $time';
  }

  @override
  String importCountsSummary(int imported, int skipped, int failed) {
    return '$imported imported · $skipped skipped · $failed failed';
  }

  @override
  String get importWizardTitle => 'Import a statement';

  @override
  String get importWizardIntro =>
      'Choose the account and your bank\'s statement file. You will see every row before anything is added.';

  @override
  String get importFormatsNote =>
      'CSV, XLSX and OFX files work. PDF statements aren\'t supported: reading them needs AI, which Montra doesn\'t use. Most banks let you download CSV or XLSX.';

  @override
  String get importStepAccount => '1. Account';

  @override
  String get importStepFile => '2. Statement file';

  @override
  String get importAccountLabel => 'Account';

  @override
  String get importChooseAccount => 'Choose an account';

  @override
  String get importAccountHelp => 'Rows are added in the account\'s currency.';

  @override
  String get importAccountRequired =>
      'Choose the account the statement belongs to.';

  @override
  String get importFileLabel => 'Statement file';

  @override
  String get importChooseFile => 'Choose a file';

  @override
  String get importFileRequired => 'Choose the statement file.';

  @override
  String get importStart => 'Upload and read';

  @override
  String get importStatusReading => 'Reading the file';

  @override
  String get importStatusNeedsMapping => 'Columns needed';

  @override
  String get importStatusPreviewReady => 'Ready to review';

  @override
  String get importStatusImporting => 'Importing';

  @override
  String get importStatusCompleted => 'Imported';

  @override
  String get importStatusCompletedWithErrors => 'Imported with problems';

  @override
  String get importStatusFailed => 'Couldn\'t import';

  @override
  String get importStatusCancelled => 'Cancelled';

  @override
  String get importStatusOther => 'Other';

  @override
  String get importHelpReading =>
      'Montra is reading your file. This usually takes a few seconds.';

  @override
  String get importHelpNeedsMapping =>
      'Montra couldn\'t tell which column holds what. Choose the columns to continue.';

  @override
  String get importHelpPreviewReady =>
      'Check the rows, then import. Possible duplicates and rows you skip are left out.';

  @override
  String get importHelpImporting =>
      'Your rows are being added. You can leave this screen.';

  @override
  String get importHelpCompleted => 'The rows were added to the account.';

  @override
  String get importHelpCompletedWithErrors =>
      'Some rows couldn\'t be added. Fix them and try again, or leave them out.';

  @override
  String get importHelpFailed => 'Nothing was added to the account.';

  @override
  String get importHelpCancelled =>
      'This import was stopped. Rows imported before it stopped stay unless you roll them back.';

  @override
  String get importStillWorking => 'Still working. Pull down to check again.';

  @override
  String get importCancelRequested => 'Stopping after the current row.';

  @override
  String get importErrorEmpty => 'The file has no rows.';

  @override
  String get importErrorUnsupported =>
      'This file type can\'t be imported. Use CSV, XLSX or OFX from your bank.';

  @override
  String get importErrorMalformed =>
      'The file couldn\'t be read. Download it again from your bank.';

  @override
  String get importErrorTooManyRows =>
      'The file has too many rows. Download a shorter period.';

  @override
  String get importErrorTooManyColumns => 'The file has too many columns.';

  @override
  String get importErrorCurrency =>
      'The statement\'s currency doesn\'t match the account. Import it into an account in that currency.';

  @override
  String get importErrorFileUnavailable =>
      'The uploaded file is no longer available. Upload it again.';

  @override
  String get importErrorGeneric => 'The import couldn\'t finish.';

  @override
  String get importRolledBack =>
      'This import was rolled back. Transactions changed after the import were kept.';

  @override
  String importRolledBackCounts(int removed, int kept) {
    return 'Rolled back: $removed transactions removed, $kept kept because they were changed or linked after the import.';
  }

  @override
  String get importDetailTitle => 'Statement import';

  @override
  String get importChooseColumns => 'Choose columns';

  @override
  String get importChangeColumns => 'Change columns';

  @override
  String get importReviewRows => 'Review rows';

  @override
  String get importSeeRows => 'See rows';

  @override
  String get importReviewFailed => 'Fix failed rows';

  @override
  String get importRetryFailed => 'Try failed rows again';

  @override
  String get importRetrying => 'Trying the failed rows again.';

  @override
  String get importConfirmAction => 'Import rows';

  @override
  String get importConfirmTitle => 'Import these rows?';

  @override
  String importConfirmBody(String account) {
    return 'Rows marked to import are added to $account. Possible duplicates and rows you skipped are left out. You can roll the import back later.';
  }

  @override
  String get importConfirmed => 'Import started.';

  @override
  String get importCancelAction => 'Cancel import';

  @override
  String get importCancelTitle => 'Cancel this import?';

  @override
  String get importCancelBody =>
      'Nothing has been added yet, and nothing will be.';

  @override
  String get importCancelProcessingBody =>
      'Montra stops after the current row. Rows already added stay unless you roll them back.';

  @override
  String get importCancelled => 'Import cancelled.';

  @override
  String get importRollbackAction => 'Roll back';

  @override
  String get importRollbackTitle => 'Roll back this import?';

  @override
  String importRollbackBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'The $count imported transactions are deleted, except ones changed or linked since.',
      one: 'The imported transaction is deleted, unless it was changed or linked since.',
    );
    return '$_temp0';
  }

  @override
  String get importRollingBack => 'Rolling back the import.';

  @override
  String get importTryAnotherFile => 'Try another file';

  @override
  String get importCheckStatement => 'Check against the statement';

  @override
  String get importPreviousFile =>
      'You imported this file into this account before. Rows already imported are flagged and left out.';

  @override
  String get importOpenPrevious => 'Open the earlier import';

  @override
  String get importSummaryTitle => 'Summary';

  @override
  String get importFormatLabel => 'File type';

  @override
  String get importStartedLabel => 'Started';

  @override
  String get importPeriodLabel => 'Statement period';

  @override
  String get importRowsInFile => 'Rows in the file';

  @override
  String get importRowsValid => 'Readable rows';

  @override
  String get importRowsNeedFixing => 'Rows to fix';

  @override
  String get importRowsPossibleDuplicates => 'Possible duplicates';

  @override
  String get importRowsImportedLabel => 'Imported';

  @override
  String get importRowsSkippedLabel => 'Skipped';

  @override
  String get importRowsFailedLabel => 'Failed';

  @override
  String get importTotalsTitle => 'Totals from the file';

  @override
  String get importBalanceOk => 'Running balances add up';

  @override
  String get importBalanceMismatch => 'Running balances don\'t add up';

  @override
  String get importBalanceNotAvailable => 'No balances in the file to check';

  @override
  String importMismatchedRows(String rows) {
    return 'Check rows $rows.';
  }

  @override
  String get importTotalIn => 'Money in';

  @override
  String get importTotalOut => 'Money out';

  @override
  String get importTotalNet => 'Net';

  @override
  String get importOpeningBalance => 'Opening balance';

  @override
  String get importClosingBalance => 'Closing balance';

  @override
  String get importMappingTitle => 'Choose columns';

  @override
  String get importMappingIntro =>
      'Tell Montra which column holds each value. The first rows of your file are shown so you can check.';

  @override
  String get importMappingUnavailable => 'The columns can\'t be changed now';

  @override
  String get importSampleTitle => 'First rows of the file';

  @override
  String importSampleRow(int number, String cells) {
    return 'Row $number: $cells';
  }

  @override
  String get importHeaderSection => 'Header row';

  @override
  String get importHeaderRowLabel => 'Row with the column names';

  @override
  String get importHeaderRowHelp => 'Rows above it are ignored.';

  @override
  String get importNoHeaderRow => 'No header row';

  @override
  String get importColumnNone => 'None';

  @override
  String importColumnNumber(int number) {
    return 'Column $number';
  }

  @override
  String importColumnExample(String name, String example) {
    return '$name (e.g. $example)';
  }

  @override
  String get importDateSection => 'Date';

  @override
  String get importDateColumn => 'Date column';

  @override
  String get importDateFormat => 'Date format';

  @override
  String importDateFormatExample(String example) {
    return 'The file shows dates like $example.';
  }

  @override
  String get importAmountSection => 'Amount';

  @override
  String get importAmountSingle => 'One amount column';

  @override
  String get importAmountSplit => 'Money out and in columns';

  @override
  String get importAmountColumn => 'Amount column';

  @override
  String get importSignNegativeOut => 'Negative amounts are money out';

  @override
  String get importSignPositiveOut => 'Positive amounts are money out';

  @override
  String get importDebitColumn => 'Money out column (withdrawals)';

  @override
  String get importCreditColumn => 'Money in column (deposits)';

  @override
  String get importIndicatorColumn => 'Dr/Cr column (optional)';

  @override
  String get importIndicatorHelp =>
      'A column that says Dr or Cr decides the direction.';

  @override
  String get importDecimalLabel => 'Decimal separator';

  @override
  String get importDecimalPoint => 'Point (1,234.50)';

  @override
  String get importDecimalComma => 'Comma (1.234,50)';

  @override
  String get importDescriptionSection => 'Description';

  @override
  String get importDescriptionHelp =>
      'Choose one or more columns; they are joined.';

  @override
  String get importOptionalSection => 'More columns (optional)';

  @override
  String get importReferenceColumn => 'Reference column';

  @override
  String get importBalanceColumn => 'Balance column';

  @override
  String get importBalanceColumnHelp =>
      'Lets Montra check that the rows add up.';

  @override
  String get importCurrencyColumn => 'Currency column';

  @override
  String get importExternalIdColumn => 'Bank transaction ID column';

  @override
  String get importExternalIdHelp => 'Helps Montra spot rows already imported.';

  @override
  String get importMappingNeedsDate => 'Choose the date column.';

  @override
  String get importMappingNeedsDateFormat => 'Choose the date format.';

  @override
  String get importMappingNeedsAmount => 'Choose the amount column.';

  @override
  String get importMappingNeedsDebitCredit =>
      'Choose both the money out and money in columns.';

  @override
  String get importMappingSave => 'Save and read again';

  @override
  String get importMappingSaved =>
      'Columns saved. Montra is reading the rows again.';

  @override
  String get importRowsTitle => 'Statement rows';

  @override
  String get importRowsHelp =>
      'Tap a row to skip it, import it, set its category or correct it.';

  @override
  String get importRowsEmpty => 'No rows here.';

  @override
  String get importRowsAll => 'All';

  @override
  String get importRowsReady => 'Ready';

  @override
  String get importRowsDuplicate => 'Possible duplicates';

  @override
  String get importRowsInvalid => 'To fix';

  @override
  String get importRowsSkipped => 'Skipped';

  @override
  String get importRowsImported => 'Imported';

  @override
  String get importRowsFailed => 'Failed';

  @override
  String get importRowStatusParsed => 'Read';

  @override
  String get importRowStatusReady => 'Ready';

  @override
  String get importRowStatusDuplicate => 'Possible duplicate';

  @override
  String get importRowStatusInvalid => 'Needs fixing';

  @override
  String get importRowStatusSkipped => 'Skipped';

  @override
  String get importRowStatusImported => 'Imported';

  @override
  String get importRowStatusFailed => 'Failed';

  @override
  String get importRowWillImport => 'Will be imported';

  @override
  String get importRowWillSkip => 'Left out';

  @override
  String importRowNumber(int number) {
    return 'Row $number';
  }

  @override
  String get importReasonHeader => 'Header row';

  @override
  String get importReasonPreamble => 'Text before the header row';

  @override
  String get importReasonMissingDate => 'The date is empty.';

  @override
  String get importReasonBadDate =>
      'The date doesn\'t match the chosen format.';

  @override
  String get importReasonCurrency => 'This row is in another currency.';

  @override
  String get importReasonBadAmount =>
      'The amount isn\'t a number in this currency.';

  @override
  String get importReasonZeroAmount => 'The amount is empty or zero.';

  @override
  String get importReasonBothColumns =>
      'Both money out and money in have values.';

  @override
  String get importReasonPossibleDuplicate =>
      'Looks like a transaction already in the account.';

  @override
  String get importReasonAlreadyImported =>
      'Already imported into this account.';

  @override
  String get importReasonRolledBack => 'Removed by rolling back this import.';

  @override
  String get importRowInclude => 'Import this row';

  @override
  String get importRowSkip => 'Skip this row';

  @override
  String get importRowCategory => 'Set a category';

  @override
  String get importRowCorrect => 'Correct this row';

  @override
  String get importRowOpenTransaction => 'Open the transaction';

  @override
  String get importRowOpenExisting => 'Open the existing transaction';

  @override
  String get importRowSaved => 'Row updated.';

  @override
  String importRowCorrectTitle(int number) {
    return 'Correct row $number';
  }

  @override
  String importRowAsRead(String cells) {
    return 'As read from the file: $cells';
  }

  @override
  String get importRowDate => 'Date';

  @override
  String get importRowDateRequired => 'Choose the date.';

  @override
  String get importRowAmount => 'Amount';

  @override
  String get importRowMoneyOut => 'Money out';

  @override
  String get importRowMoneyIn => 'Money in';

  @override
  String get importRowDirectionRequired => 'Choose money out or money in.';

  @override
  String get importRowDescription => 'Description';

  @override
  String get importRowSaveCorrection => 'Save correction';

  @override
  String get analyticsTitle => 'Analytics';

  @override
  String get analyticsLoading => 'Loading your figures';

  @override
  String get analyticsSummaryTitle => 'This period';

  @override
  String get analyticsNoActivityBody =>
      'Add transactions or import a statement to see your figures here.';

  @override
  String get analyticsPeriodReportsTitle => 'Look closer at this period';

  @override
  String get analyticsNowTitle => 'Where things stand now';

  @override
  String get analyticsUnknownReport => 'This report isn\'t available.';

  @override
  String get analyticsCashFlowTitle => 'Cash flow';

  @override
  String get analyticsCashFlowSubtitle => 'Money in and out over time';

  @override
  String get analyticsCategoriesTitle => 'Spending by category';

  @override
  String get analyticsCategoriesSubtitle => 'Where your money went';

  @override
  String get analyticsExpensesTitle => 'Spending over time';

  @override
  String get analyticsExpensesSubtitle =>
      'Spending, refunds and reimbursements';

  @override
  String get analyticsIncomeTitle => 'Income over time';

  @override
  String get analyticsIncomeSubtitle => 'Money received in each period';

  @override
  String get analyticsMerchantsTitle => 'Top merchants';

  @override
  String get analyticsMerchantsSubtitle => 'Where you spent the most';

  @override
  String get analyticsAccountsTitle => 'Net worth';

  @override
  String get analyticsAccountsSubtitle =>
      'What you have and what you owe, per currency';

  @override
  String get analyticsBudgetsTitle => 'Budget performance';

  @override
  String get analyticsBudgetsSubtitle =>
      'How your budgets are doing in their current period';

  @override
  String get analyticsGoalsTitle => 'Goal progress';

  @override
  String get analyticsGoalsSubtitle => 'Saved so far towards your goals';

  @override
  String get analyticsSubscriptionsTitle => 'Subscription costs';

  @override
  String get analyticsSubscriptionsSubtitle =>
      'What your subscriptions cost each month and year';

  @override
  String get analyticsRecurringTitle => 'Recurring commitments';

  @override
  String get analyticsRecurringSubtitle =>
      'Regular payments and income, per month';

  @override
  String get analyticsCompareTitle => 'Compare periods';

  @override
  String get analyticsCompareSubtitle =>
      'This period side by side with another';

  @override
  String get analyticsGranularityLabel => 'Group by';

  @override
  String get analyticsGranularityAuto => 'Automatic';

  @override
  String get analyticsGranularityDay => 'Day';

  @override
  String get analyticsGranularityWeek => 'Week';

  @override
  String get analyticsGranularityMonth => 'Month';

  @override
  String get analyticsGranularityYear => 'Year';

  @override
  String get analyticsOverTimeTitle => 'Over time';

  @override
  String get analyticsGrossSpendingLabel => 'Spent before refunds';

  @override
  String get analyticsRefundsLabel => 'Refunds and reimbursements';

  @override
  String analyticsExpensesSummary(
    String unit,
    String period,
    String amount,
    String bucket,
  ) {
    return 'Spending per $unit for $period. Highest: $amount ($bucket).';
  }

  @override
  String analyticsIncomeSummary(
    String unit,
    String period,
    String amount,
    String bucket,
  ) {
    return 'Income per $unit for $period. Highest: $amount ($bucket).';
  }

  @override
  String get analyticsShowSubcategories => 'Show subcategories separately';

  @override
  String get analyticsShowSubcategoriesHelp =>
      'Otherwise they are added to their main category.';

  @override
  String analyticsMerchantsSummary(String name, String amount, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count merchants shown.',
      one: '1 merchant shown.',
    );
    return '$name had the most spending: $amount. $_temp0';
  }

  @override
  String analyticsMerchantRow(String amount, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions',
      one: '1 transaction',
    );
    return '$amount · $_temp0';
  }

  @override
  String get analyticsOverviewOnly => 'Only accounts in my overview';

  @override
  String get analyticsOverviewOnlyHelp =>
      'Leave out accounts you keep out of the Home totals.';

  @override
  String get analyticsBudgetsEmpty => 'No active budgets yet.';

  @override
  String get analyticsBudgetsCreate => 'Create a budget';

  @override
  String get analyticsBudgetsPaceTitle => 'How they are going';

  @override
  String analyticsBudgetsOverCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count budgets are over their limit.',
      one: '1 budget is over its limit.',
      zero: 'No budget is over its limit.',
    );
    return '$_temp0';
  }

  @override
  String get analyticsBudgetsUseTitle => 'How much of each limit is used';

  @override
  String analyticsBudgetsSummary(int count, int over) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count budgets',
      one: '1 budget',
    );
    return 'Use of the limit for $_temp0. Over the limit: $over.';
  }

  @override
  String get analyticsWithinLimit => 'Within the limit';

  @override
  String analyticsBudgetRow(
    String spent,
    String limit,
    String percent,
    String pace,
  ) {
    return '$spent of $limit ($percent) · $pace';
  }

  @override
  String get analyticsBudgetNoProgress => 'No figures for this period yet.';

  @override
  String get analyticsGoalsEmpty => 'No goals yet.';

  @override
  String get analyticsGoalsCreate => 'Create a goal';

  @override
  String analyticsGoalsCount(int count, int achieved) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count goals',
      one: '1 goal',
    );
    return '$_temp0; achieved: $achieved';
  }

  @override
  String get analyticsGoalsProgressTitle => 'Progress per goal';

  @override
  String analyticsGoalsSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count goals',
      one: '1 goal',
    );
    return 'Share of the target saved for $_temp0.';
  }

  @override
  String analyticsGoalRow(
    String saved,
    String target,
    String percent,
    String status,
  ) {
    return '$saved of $target ($percent) · $status';
  }

  @override
  String get analyticsSubscriptionsEmpty => 'No subscriptions yet.';

  @override
  String get analyticsSubscriptionsCreate => 'Add a subscription';

  @override
  String get analyticsNoRenewals => 'Nothing renews in the next 30 days.';

  @override
  String get analyticsRecurringNote =>
      'Monthly amounts use fixed amounts only. Bills and income are what you expect, not money already recorded.';

  @override
  String get analyticsRecurringEmpty =>
      'No active recurring payments or income.';

  @override
  String get analyticsRecurringCreate => 'Add a recurring payment';

  @override
  String analyticsRecurringSummary(String kind, String amount) {
    return 'Monthly amount per type. The largest is $kind: $amount a month.';
  }

  @override
  String analyticsPerMonth(String amount) {
    return '$amount a month';
  }

  @override
  String analyticsRecurringRules(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count active',
      one: '1 active',
    );
    return '$_temp0';
  }

  @override
  String analyticsNext30Days(String kind) {
    return '$kind: due in the next 30 days';
  }

  @override
  String analyticsVariableRules(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count with varying amounts aren\'t included.',
      one: '1 with a varying amount isn\'t included.',
    );
    return '$_temp0';
  }

  @override
  String get analyticsCompareNoteSameRules =>
      'Both periods use the same filters and rules: transfers are left out and refunds reduce spending.';

  @override
  String get analyticsCompareNoteTotals =>
      'Periods of different lengths are compared as totals, not per day.';

  @override
  String get analyticsCompareThisPeriod => 'This period';

  @override
  String get analyticsCompareWith => 'Compared with';

  @override
  String get analyticsComparePreviousHelp =>
      'The same number of days just before.';

  @override
  String analyticsCompareEmpty(String now, String then) {
    return 'No income or spending in $now or $then.';
  }

  @override
  String analyticsCompareWindows(String now, String then) {
    return '$now compared with $then';
  }

  @override
  String analyticsCompareSummary(
    String spendingNow,
    String spendingThen,
    String incomeNow,
    String incomeThen,
  ) {
    return 'Spending was $spendingNow, against $spendingThen before. Income was $incomeNow, against $incomeThen.';
  }

  @override
  String analyticsCompareRow(String now, String then) {
    return '$now now · $then before';
  }

  @override
  String analyticsCompareThen(String amount) {
    return 'Before: $amount';
  }

  @override
  String get analyticsCategoryChangesTitle => 'Changes by category';

  @override
  String get analyticsCategoryChangesEmpty =>
      'No category spending in either period.';

  @override
  String analyticsCategoryChangeSpoken(String now, String then, String change) {
    return '$now now, $then before, change $change';
  }

  @override
  String get analyticsChangeNew => 'new';

  @override
  String analyticsCategoryChange(String amount, String percent) {
    return 'Change: $amount ($percent)';
  }

  @override
  String get reportsLoading => 'Loading your reports';

  @override
  String get reportsEmptyTitle => 'No reports yet';

  @override
  String get reportsEmptyBody =>
      'Make a summary or an export of your transactions to download, share or keep.';

  @override
  String get reportsWorkingNote =>
      'Reports being made update here by themselves.';

  @override
  String get reportsStillWorking =>
      'Still being made. Pull down to check again.';

  @override
  String get reportNew => 'New report';

  @override
  String get reportNewTitle => 'New report';

  @override
  String get reportNewIntro =>
      'Reports are made in the background and can be downloaded for a few days.';

  @override
  String get reportCreate => 'Create report';

  @override
  String get reportQueued =>
      'Your report is being made. It will show here when it\'s ready.';

  @override
  String get reportMaking =>
      'Your report is being made. This page updates by itself.';

  @override
  String get reportReadyBody =>
      'Share it with another app or save it to your device.';

  @override
  String get reportExpiredBody =>
      'This report has expired. Make it again to download it.';

  @override
  String get reportGenerateAgain => 'Make it again';

  @override
  String get reportNoDeleteNote =>
      'Report files are deleted automatically when they expire.';

  @override
  String get reportDetailsTitle => 'Details';

  @override
  String get reportTypeLabel => 'Report';

  @override
  String get reportFormatLabel => 'File format';

  @override
  String get reportPeriodLabel => 'Period';

  @override
  String get reportPeriodDefault => 'The usual period for this report';

  @override
  String get reportIncludePending => 'Include pending transactions';

  @override
  String get reportIncludePendingHelp =>
      'Otherwise only posted transactions are counted.';

  @override
  String get reportTitleLabel => 'Title';

  @override
  String get reportTitleHelp => 'Optional. For example \"Tax papers 2026\".';

  @override
  String get reportRequestedLabel => 'Requested';

  @override
  String reportRequestedAt(String time) {
    return 'Requested $time';
  }

  @override
  String get reportCompletedLabel => 'Ready';

  @override
  String get reportExpiresLabel => 'Available until';

  @override
  String reportAvailableUntil(String date) {
    return 'Available until $date';
  }

  @override
  String get reportRowsLabel => 'Size';

  @override
  String reportRows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rows',
      one: '1 row',
    );
    return '$_temp0';
  }

  @override
  String get reportTimezoneLabel => 'Time zone';

  @override
  String reportTypeAndFormat(String type, String format) {
    return '$type · $format';
  }

  @override
  String get reportStatusQueued => 'Waiting to start';

  @override
  String get reportStatusRunning => 'Being made';

  @override
  String get reportStatusReady => 'Ready to download';

  @override
  String get reportStatusFailed => 'Couldn\'t be made';

  @override
  String get reportStatusExpired => 'Expired';

  @override
  String get reportStatusOther => 'Other status';

  @override
  String reportStatusSemantics(String status) {
    return 'Status: $status';
  }

  @override
  String get reportFailedTooManyRows =>
      'The report has too many transactions. Choose a shorter period.';

  @override
  String get reportFailedPdfTooLarge =>
      'This report is too long for a PDF. Choose CSV or Excel, or a shorter period.';

  @override
  String get reportFailedInvalid =>
      'The report couldn\'t be made with these choices. Try a different period or report.';

  @override
  String get reportFailedUnavailable =>
      'Reports can\'t be made on this server right now.';

  @override
  String get reportFailedOther => 'The report couldn\'t be made. Try again.';

  @override
  String get reportFormatCsv => 'CSV';

  @override
  String get reportFormatXlsx => 'Excel (XLSX)';

  @override
  String get reportFormatPdf => 'PDF';

  @override
  String get reportFormatJson => 'JSON';

  @override
  String get reportFormatCsvHelp => 'Opens in any spreadsheet app.';

  @override
  String get reportFormatXlsxHelp => 'For Excel and similar apps.';

  @override
  String get reportFormatPdfHelp => 'Ready to read or print.';

  @override
  String get reportFormatJsonHelp => 'For other apps and tools.';

  @override
  String get reportTypeMonthlySummary => 'Monthly summary';

  @override
  String get reportTypeMonthlySummaryHelp =>
      'Income, spending and top categories for a month.';

  @override
  String get reportTypeYearlySummary => 'Yearly summary';

  @override
  String get reportTypeYearlySummaryHelp =>
      'The year at a glance, month by month.';

  @override
  String get reportTypeCashFlow => 'Cash flow';

  @override
  String get reportTypeCashFlowHelp => 'Money in and out over the period.';

  @override
  String get reportTypeIncome => 'Income';

  @override
  String get reportTypeIncomeHelp =>
      'Money received over the period, by category. Spending is not included.';

  @override
  String get reportTypeExpense => 'Expenses';

  @override
  String get reportTypeExpenseHelp =>
      'Spending, refunds and reimbursements over the period. Income is not included.';

  @override
  String get reportTypeCategory => 'Spending by category';

  @override
  String get reportTypeCategoryHelp => 'Totals for each category.';

  @override
  String get reportTypeMerchant => 'Spending by merchant';

  @override
  String get reportTypeMerchantHelp => 'Where you spent the most.';

  @override
  String get reportTypeAccount => 'Accounts';

  @override
  String get reportTypeAccountHelp => 'Balances, assets and what you owe.';

  @override
  String get reportTypeBudget => 'Budgets';

  @override
  String get reportTypeBudgetHelp => 'How each budget is doing.';

  @override
  String get reportTypeSubscription => 'Subscriptions';

  @override
  String get reportTypeSubscriptionHelp => 'What your subscriptions cost.';

  @override
  String get reportTypeRecurring => 'Recurring commitments';

  @override
  String get reportTypeRecurringHelp =>
      'Regular payments and income per month.';

  @override
  String get reportTypeGoal => 'Goals';

  @override
  String get reportTypeGoalHelp => 'Progress towards each goal.';

  @override
  String get reportTypeTransactions => 'Transactions';

  @override
  String get reportTypeTransactionsHelp =>
      'Every transaction in the period, one per row.';

  @override
  String get reportTypeOther => 'Report';

  @override
  String get reportSchedulesTitle => 'Scheduled reports';

  @override
  String get schedulesEmptyTitle => 'No scheduled reports';

  @override
  String get schedulesEmptyBody =>
      'Get a summary every week or month without asking each time.';

  @override
  String get schedulesNote =>
      'Scheduled reports appear in your reports list when they\'re ready.';

  @override
  String get scheduleNew => 'Schedule a report';

  @override
  String get scheduleNewTitle => 'Schedule a report';

  @override
  String get scheduleCreate => 'Schedule report';

  @override
  String get scheduleCreated => 'Report scheduled.';

  @override
  String get scheduleCadenceLabel => 'How often';

  @override
  String get scheduleCadenceWeekly => 'Every week';

  @override
  String get scheduleCadenceMonthly => 'Every month';

  @override
  String get scheduleWeeklyHelp => 'Each report covers the previous full week.';

  @override
  String get scheduleMonthlyHelp =>
      'Each report covers the previous full month.';

  @override
  String scheduleCadenceAndFormat(String cadence, String format) {
    return '$cadence · $format';
  }

  @override
  String scheduleNextRun(String time) {
    return 'Next: $time';
  }

  @override
  String get scheduleOff => 'Turned off';

  @override
  String scheduleTitleWeekly(String type) {
    return '$type (weekly)';
  }

  @override
  String scheduleTitleMonthly(String type) {
    return '$type (monthly)';
  }

  @override
  String get scheduleDeleteTitle => 'Delete this schedule?';

  @override
  String scheduleDeleteBody(String title) {
    return '“$title” will no longer be made. Reports already made stay in your list until they expire.';
  }

  @override
  String scheduleDeleteLabel(String title) {
    return 'Delete the schedule $title';
  }

  @override
  String get scheduleDeleted => 'Schedule deleted.';

  @override
  String get fxIntro =>
      'Rates say how much one unit of a currency is worth in another. Your own rates are used before published ones.';

  @override
  String get fxEmptyTitle => 'No exchange rates yet';

  @override
  String get fxNoMatchTitle => 'No rates for these currencies';

  @override
  String get fxEmptyBody => 'Add your own rate to convert between currencies.';

  @override
  String get fxFilterFrom => 'From';

  @override
  String get fxFilterTo => 'To';

  @override
  String get fxFilterAny => 'Any';

  @override
  String get fxAddRate => 'Add a rate';

  @override
  String fxRatePair(String base, String rate, String quote) {
    return '1 $base = $rate $quote';
  }

  @override
  String fxAsOf(String source, String date) {
    return '$source · as of $date';
  }

  @override
  String get fxYourRate => 'Your rate';

  @override
  String get fxSourceManual => 'Your rate';

  @override
  String get fxSourceEcb => 'European Central Bank';

  @override
  String get fxSourceProvider => 'Rate provider';

  @override
  String get fxSourceOther => 'Other source';

  @override
  String get fxSourceLabel => 'Source';

  @override
  String get fxDeleteTitle => 'Delete this rate?';

  @override
  String fxDeleteBody(String base, String quote) {
    return 'Your $base to $quote rate will be deleted. Published rates, if there are any, are used instead.';
  }

  @override
  String fxDeleteLabel(String base, String quote) {
    return 'Delete your $base to $quote rate';
  }

  @override
  String get fxDeleted => 'Rate deleted.';

  @override
  String get fxManualIntro =>
      'Add the rate you got, for example from your bank. Your earlier rates are kept.';

  @override
  String get fxBaseLabel => 'From currency';

  @override
  String get fxQuoteLabel => 'To currency';

  @override
  String get fxRateHelp =>
      'How many units of the second currency one unit of the first is worth.';

  @override
  String fxRateHelpPair(String base, String quote) {
    return 'How many $quote one $base is worth, for example 83.12';
  }

  @override
  String get fxRateInvalid =>
      'Enter a number above zero with at most 12 decimal places, for example 83.12.';

  @override
  String get fxAsOfLabel => 'Rate date';

  @override
  String get fxAsOfNow => 'Now';

  @override
  String get fxAsOfHelp =>
      'Leave it empty for now. A date means that whole day in your time zone (today is fine); it can\'t be in the future.';

  @override
  String get fxPairRequired => 'Choose both currencies.';

  @override
  String get fxPairDifferent => 'Choose two different currencies.';

  @override
  String get fxSaveRate => 'Save rate';

  @override
  String get fxSaved => 'Rate saved.';

  @override
  String get fxConvertTitle => 'Convert currency';

  @override
  String get fxConvertIntro =>
      'Montra shows the rate it uses, where it comes from and its date. Your own rates are used first.';

  @override
  String get fxFromLabel => 'From';

  @override
  String get fxToLabel => 'To';

  @override
  String get fxUseDate => 'Use the rate on a date';

  @override
  String get fxUseDateHelp => 'Otherwise the latest rate is used.';

  @override
  String get fxDateLabel => 'Date of the rate';

  @override
  String get fxDateRequired => 'Choose the date.';

  @override
  String get fxConvertAction => 'Convert';

  @override
  String get fxResultTitle => 'Result';

  @override
  String fxResultLine(String from, String to) {
    return '$from = $to';
  }

  @override
  String get fxRateDateLabel => 'Rate as of';

  @override
  String get fxPolicyLabel => 'Rate used';

  @override
  String get fxPolicyCurrent => 'Latest rate';

  @override
  String get fxPolicyHistorical => 'Rate on a date';

  @override
  String fxInvertedNote(String quote, String base) {
    return 'Worked out from the $quote to $base rate.';
  }

  @override
  String fxRoundingNote(String delta) {
    return 'Rounded to the smallest unit of the currency (difference: $delta of that unit).';
  }

  @override
  String fxNoRate(String from, String to) {
    return 'No exchange rate is available for $from to $to. Add your own rate.';
  }

  @override
  String get reconTitle => 'Reconcile';

  @override
  String reconTitleOf(String account) {
    return 'Reconcile $account';
  }

  @override
  String get reconLoading => 'Loading reconciliation';

  @override
  String get reconTabBalances => 'Balances';

  @override
  String get reconTabSuggestions => 'Suggestions';

  @override
  String get reconTabMatched => 'Matched';

  @override
  String get reconBalancesIntro =>
      'Compare your statement\'s closing balance with Montra\'s balance on the same date. When they match, transactions up to that date are marked as reconciled.';

  @override
  String get reconCheckBalance => 'Check a statement balance';

  @override
  String get reconBalancesEmpty => 'No statement balance checks yet.';

  @override
  String reconStatementOf(String date) {
    return 'Statement of $date';
  }

  @override
  String get reconBalanced => 'Matches';

  @override
  String reconOffBy(String amount) {
    return 'Off by $amount';
  }

  @override
  String get reconOffByHelp =>
      'Look for missing, duplicate or pending transactions up to this date, then check again.';

  @override
  String get reconStatementBalance => 'Statement balance';

  @override
  String get reconLedgerBalance => 'Montra\'s balance';

  @override
  String get reconDifference => 'Difference';

  @override
  String reconReconciledCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions marked as reconciled.',
      one: '1 transaction marked as reconciled.',
    );
    return '$_temp0';
  }

  @override
  String reconUnreconciledCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions up to this date aren\'t reconciled yet.',
      one: '1 transaction up to this date isn\'t reconciled yet.',
    );
    return '$_temp0';
  }

  @override
  String reconUnmatchedRows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count statement rows are still unmatched.',
      one: '1 statement row is still unmatched.',
    );
    return '$_temp0';
  }

  @override
  String get reconSuggestionsIntro =>
      'Possible matches found by Montra. Nothing changes until you confirm one, and you can undo it later.';

  @override
  String get reconSuggestionsEmpty => 'No suggested matches right now.';

  @override
  String get reconSuggestionsEmptyBody =>
      'Suggestions appear for imported statement rows, pending transactions that posted, and transactions entered twice.';

  @override
  String reconConfidence(int percent) {
    return 'Match likelihood: $percent%';
  }

  @override
  String get reconConfirm => 'Confirm match';

  @override
  String get reconConfirmPendingTitle => 'Replace the pending transaction?';

  @override
  String get reconConfirmPendingBody =>
      'The pending transaction will be removed because the posted one replaces it. You can undo this later.';

  @override
  String get reconKeepTitle => 'Which one should stay?';

  @override
  String get reconKeepImported => 'Keep the imported one';

  @override
  String get reconKeepManual => 'Keep the one you entered';

  @override
  String reconWhy(String reasons) {
    return 'Why: $reasons';
  }

  @override
  String get reconKindStatement => 'Statement row';

  @override
  String get reconKindStatementHelp =>
      'A statement row matches transactions already in Montra. Confirming marks them as matched; the row isn\'t imported again.';

  @override
  String get reconKindPending => 'Pending now posted';

  @override
  String get reconKindPendingHelp =>
      'A pending transaction has posted. Confirming removes the pending one.';

  @override
  String get reconKindDuplicate => 'Entered twice';

  @override
  String get reconKindDuplicateHelp =>
      'The same transaction was entered by you and imported. Confirming keeps one and removes the other.';

  @override
  String get reconKindOther => 'Match';

  @override
  String get reconSideStatement => 'On the statement';

  @override
  String get reconSideLedger => 'In Montra';

  @override
  String get reconSidePending => 'Pending';

  @override
  String get reconSideImported => 'Imported';

  @override
  String get reconMatchesEmpty => 'No matches yet.';

  @override
  String reconMatchedOn(String date) {
    return 'Matched $date';
  }

  @override
  String get reconMatchConfirmed => 'Matched';

  @override
  String get reconMatchUndone => 'Undone';

  @override
  String get reconMatchSuggested => 'Suggested';

  @override
  String get reconMatchRejected => 'Rejected';

  @override
  String get reconMatchOther => 'Other status';

  @override
  String get reconEffectVoided => 'Removed (comes back if you undo)';

  @override
  String get reconEffectRowSkipped => 'Statement row not imported';

  @override
  String get reconUndo => 'Undo match';

  @override
  String get reconUndoTitle => 'Undo this match?';

  @override
  String get reconUndoBody =>
      'Removed transactions come back and statement rows return to their import.';

  @override
  String get reconUndone => 'Match undone.';

  @override
  String get reconReasonSameAmount => 'Same amount and direction';

  @override
  String get reconReasonSameDate => 'Same date';

  @override
  String get reconReasonOneDay => 'One day apart';

  @override
  String get reconReasonThreeDays => 'Within 3 days';

  @override
  String get reconReasonWeek => 'Within a week';

  @override
  String get reconReasonReference => 'Same reference';

  @override
  String get reconReasonDescription => 'Similar description';

  @override
  String get reconReasonAddsUp => 'Amounts add up exactly';

  @override
  String get reconReasonAllWeek => 'All within a week';

  @override
  String get reconReasonPendingReplaced =>
      'The posted transaction replaces the pending one';

  @override
  String get reconReasonEnteredTwice =>
      'The same transaction was entered by you and imported';

  @override
  String reconReasonAmountsDiffer(String pending, String posted) {
    return 'Amounts differ ($pending pending, $posted posted)';
  }

  @override
  String reconFormIntro(String account) {
    return 'Enter the closing balance shown on a statement for $account.';
  }

  @override
  String get reconFromImport =>
      'This check is linked to the imported statement.';

  @override
  String get reconStatementDate => 'Statement date';

  @override
  String get reconChooseDate => 'Choose the date';

  @override
  String get reconDateRequired => 'Choose the statement date.';

  @override
  String get reconBalanceKindLabel => 'The statement shows';

  @override
  String get reconKindOwed => 'Amount you owe';

  @override
  String get reconKindBalance => 'Balance';

  @override
  String get reconAmountOwedLabel => 'Amount owed on the statement';

  @override
  String get reconAmountOwedHelp =>
      'The amount you owe on the statement, as a positive number.';

  @override
  String get reconStatementBalanceHelp =>
      'As shown on the statement. Use a minus sign for an overdrawn balance.';

  @override
  String get reconWhatHappens =>
      'Montra compares this with its own balance on that date. If they match, posted transactions up to the date are marked as reconciled. Nothing else changes.';

  @override
  String get reconCompare => 'Compare';

  @override
  String get reconResultBalanced => 'The balances match.';

  @override
  String get reconResultOff => 'The balances don\'t match yet.';

  @override
  String get reconCheckAgain => 'Check another balance';

  @override
  String get limitsStorageTitle => 'File storage';

  @override
  String limitsStorageUsed(String used, String quota) {
    return '$used of $quota used';
  }

  @override
  String get limitsTitle => 'Fair-use limits';

  @override
  String get limitsFreeNote =>
      'Every Montra feature is free. These limits are the same for everyone and keep Montra fast.';

  @override
  String limitsOpenBills(String count) {
    return 'Open bills: up to $count';
  }

  @override
  String limitsRecurring(String count) {
    return 'Recurring payments: up to $count';
  }

  @override
  String limitsSubscriptions(String count) {
    return 'Subscriptions: up to $count';
  }

  @override
  String limitsGoals(String count) {
    return 'Goals: up to $count';
  }

  @override
  String limitsImportRows(String count) {
    return 'Rows in one statement import: up to $count';
  }

  @override
  String limitsExportDays(String days) {
    return 'Report downloads are kept for $days days';
  }

  @override
  String get errorFileInUse => 'This page is already part of another receipt.';

  @override
  String get errorPageNotReady =>
      'A page is still uploading. Wait a moment and try again.';

  @override
  String get errorReceiptLinked =>
      'This receipt is already linked to a transaction. Unlink it first.';

  @override
  String get errorReceiptDiscarded =>
      'This receipt was discarded. Restore it first.';

  @override
  String get errorReceiptProcessing =>
      'This receipt is still being prepared. Try again in a moment.';

  @override
  String get errorReceiptNotLinked =>
      'This receipt isn\'t linked to a transaction.';

  @override
  String get errorReceiptNotDiscarded =>
      'Only discarded receipts can be restored.';

  @override
  String get errorTransactionHasReceipt =>
      'That transaction already has a receipt.';

  @override
  String receiptWarningLineItemsAmounts(String total, String subtotal) {
    return 'The items add up to $total, not the subtotal of $subtotal. Check the numbers.';
  }

  @override
  String receiptWarningAmountUnreadable(String value) {
    return 'An amount couldn\'t be read (“$value”). Check it.';
  }

  @override
  String get receiptWarningAmountUnreadableGeneric =>
      'An amount couldn\'t be read. Check the amounts.';

  @override
  String get receiptWarningDateUnreadable =>
      'The date couldn\'t be read. Check it.';

  @override
  String get receiptWarningCurrencyUnrecognized =>
      'The currency wasn\'t recognized. Check it.';

  @override
  String get receiptWarningReadingFailed =>
      'This receipt couldn\'t be read automatically. Enter the details yourself.';

  @override
  String get receiptDiscardBodyRestorable =>
      'It leaves your inbox. You can restore it later; its files are kept.';

  @override
  String get receiptDiscardLinkedBodyRestorable =>
      'It leaves your inbox and is unlinked from its transaction, which stays as it is. If you restore the receipt later, it stays unlinked.';

  @override
  String get receiptRestore => 'Restore';

  @override
  String get receiptRestored => 'Receipt restored.';

  @override
  String get receiptCheckDetails => 'Check the details';

  @override
  String get receiptHelpCheckManual =>
      'These values weren\'t entered by you. Check them and save them before recording the purchase.';

  @override
  String get receiptAddFailedTitle => 'The receipt wasn\'t added';

  @override
  String get receiptAddForget => 'Don\'t add';

  @override
  String get receiptPaymentMethodHelp =>
      'For example cash, UPI or card. Don\'t enter card or account numbers.';

  @override
  String get navInsights => 'Insights';

  @override
  String get navTogether => 'Together';

  @override
  String get searchTitle => 'Search';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String notificationsUnreadBadge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unread notifications',
      one: '1 unread notification',
    );
    return '$_temp0';
  }

  @override
  String get fieldRequired => 'This is required.';

  @override
  String fieldTooShort(String min) {
    return 'Use at least $min characters.';
  }

  @override
  String fieldTooLong(String max) {
    return 'Use at most $max characters.';
  }

  @override
  String fieldTooFew(String min) {
    return 'Choose at least $min.';
  }

  @override
  String fieldTooMany(String max) {
    return 'Choose at most $max.';
  }

  @override
  String get fieldTooSmall => 'This value is too small.';

  @override
  String get fieldTooLarge => 'This value is too large.';

  @override
  String get fieldInvalidChoice => 'Choose one of the offered options.';

  @override
  String get fieldInvalidFormat => 'Check the format of this value.';

  @override
  String get fieldInvalidType => 'This value has the wrong type.';

  @override
  String get fieldUnexpected => 'This field isn\'t accepted here.';

  @override
  String get fieldInvalidCharacters => 'Remove the unsupported characters.';

  @override
  String get fieldContainsSecret =>
      'Remove card numbers, PINs, one-time codes and passwords before sending.';

  @override
  String fieldTooManyLinks(String max) {
    return 'Include at most $max links.';
  }

  @override
  String get fieldInsecureLink => 'Links must start with https://.';

  @override
  String get fieldLinkRequired => 'Add a link.';

  @override
  String get fieldModeratorsOnly => 'Only moderators can post this.';

  @override
  String get fieldPollMismatch =>
      'Polls need poll options; other kinds of posts can\'t have them.';

  @override
  String get fieldDuplicateOption => 'Each poll option must be different.';

  @override
  String get fieldMustBeFuture => 'Choose a date in the future.';

  @override
  String get fieldInvalidParent => 'That comment can\'t be replied to.';

  @override
  String get fieldInvalidOption => 'That option isn\'t part of this poll.';

  @override
  String get fieldInvalidTopic => 'One of the topics isn\'t valid.';

  @override
  String get fieldSelfNotAllowed => 'You can\'t do this to yourself.';

  @override
  String get fieldReasonRequired => 'Give a reason.';

  @override
  String get fieldShareRequired =>
      'Share your progress to appear on the leaderboard.';

  @override
  String get fieldSlugTaken => 'That URL name is taken. Choose another.';

  @override
  String errorDailyCapRetry(String limit, String wait) {
    return 'You\'ve reached today\'s limit ($limit a day). Try again in $wait.';
  }

  @override
  String errorDailyCap(String limit) {
    return 'You\'ve reached today\'s limit ($limit a day). Try again tomorrow.';
  }

  @override
  String get profileYouTitle => 'You and your data';

  @override
  String get profileNotificationsSubtitle => 'What Montra tells you, and how';

  @override
  String get profileFriendsTitle => 'Friends';

  @override
  String get profileFriendsSubtitle =>
      'Requests, blocked people and who can find you';

  @override
  String get profileIntegrationsTitle => 'Connected services';

  @override
  String get profileIntegrationsSubtitle =>
      'Bank and other connections, and their status';

  @override
  String get profilePrivacySubtitle =>
      'Consents, a copy of your data, closing your account';

  @override
  String get profileModerationTitle => 'Moderation decisions';

  @override
  String get profileModerationSubtitle =>
      'Decisions about you, your appeals and reports';

  @override
  String get profileHelpSubtitle =>
      'Common questions and your support requests';

  @override
  String get contactEntry => 'Need help? Contact support';

  @override
  String get helpTitle => 'Help & support';

  @override
  String get helpIntro =>
      'Find quick answers below, or ask Montra support. Everything in Montra is free, including support.';

  @override
  String get helpNewRequest => 'Ask for help';

  @override
  String get helpYourRequests => 'Your requests';

  @override
  String get helpNoRequests => 'You haven\'t asked for help yet.';

  @override
  String helpRequestMeta(String kind, String reference, String date) {
    return '$kind · $reference · $date';
  }

  @override
  String helpMessageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages',
      one: '1 message',
    );
    return '$_temp0';
  }

  @override
  String get helpTopicsTitle => 'Common questions';

  @override
  String get helpTopicMoneyTitle => 'How Montra counts your money';

  @override
  String get helpTopicMoneyBody =>
      'Transfers between your own accounts are not spending or income. Refunds reduce spending. Amounts in different currencies are never added together. Pending transactions count only when you choose to include them.';

  @override
  String get helpTopicMoneyLink => 'See your analytics';

  @override
  String get helpTopicPrivacyTitle => 'Your privacy';

  @override
  String get helpTopicPrivacyBody =>
      'Your records are visible only to you, unless you share them in a group. Montra never asks for bank passwords, UPI PINs, OTPs or card numbers. You can download your data or delete your account at any time.';

  @override
  String get helpTopicPrivacyLink => 'Privacy & data';

  @override
  String get helpTopicImportsTitle => 'Importing statements';

  @override
  String get helpTopicImportsBody =>
      'Import CSV, XLSX or OFX statements from your bank. You check every row before anything is added, and you can roll an import back.';

  @override
  String get helpTopicImportsLink => 'Go to imports';

  @override
  String get helpTopicGroupsTitle => 'Groups and shared costs';

  @override
  String get helpTopicGroupsBody =>
      'Split costs with housemates, trips or friends. Montra keeps the balances; it never moves money. Settlements are recorded by you and confirmed by the other person.';

  @override
  String get helpTopicGroupsLink => 'Go to groups';

  @override
  String get helpTopicLimitsTitle => 'Is anything paid?';

  @override
  String get helpTopicLimitsBody =>
      'No. Everything in Montra is free. A few fair-use limits, the same for everyone, keep it fast.';

  @override
  String get helpTopicLimitsLink => 'See the limits';

  @override
  String get helpTopicModerationTitle => 'A post removed or a limit placed?';

  @override
  String get helpTopicModerationBody =>
      'See the decisions about you and ask for a review within 30 days.';

  @override
  String get helpTopicModerationLink => 'Moderation decisions';

  @override
  String get helpKindLabel => 'What is it about?';

  @override
  String get helpKindSupport => 'Help using Montra';

  @override
  String get helpKindBug => 'Something isn\'t working';

  @override
  String get helpKindSecurity => 'Security concern';

  @override
  String get helpKindPrivacy => 'Privacy or my data';

  @override
  String get helpKindFeedback => 'Feedback or an idea';

  @override
  String get helpStatusOpen => 'Open';

  @override
  String get helpStatusInProgress => 'Being looked at';

  @override
  String get helpStatusResolved => 'Resolved';

  @override
  String get helpStatusClosed => 'Closed';

  @override
  String get helpNoSecretsNote =>
      'Never include card numbers, PINs, one-time codes or passwords. Montra support never needs them.';

  @override
  String get helpNoSecretsShort => 'No card numbers, PINs, codes or passwords.';

  @override
  String get helpSubjectLabel => 'Subject';

  @override
  String get helpBodyLabel => 'Your message';

  @override
  String get helpBodyHelp =>
      'Say what you tried and what happened. Don\'t include amounts or account details unless they matter.';

  @override
  String get helpSend => 'Send';

  @override
  String helpRequestSent(String reference) {
    return 'Sent. Your reference is $reference.';
  }

  @override
  String get helpRequestTitle => 'Support request';

  @override
  String get helpReferenceLabel => 'Reference';

  @override
  String get helpSentOn => 'Sent';

  @override
  String get helpConversation => 'Conversation';

  @override
  String get helpNoMessages =>
      'No replies yet. Montra support will answer here, and you\'ll get a notification.';

  @override
  String get helpFromSupport => 'Montra support';

  @override
  String get helpFromYou => 'You';

  @override
  String get helpFromRequester => 'Requester';

  @override
  String get helpReplyLabel => 'Add a reply';

  @override
  String get helpSendReply => 'Send reply';

  @override
  String get helpReplySent => 'Reply sent.';

  @override
  String get helpRequestClosedNote =>
      'This request is closed. If you still need help, ask again from Help & support.';

  @override
  String get helpRequestClosedError =>
      'This request is closed, so it can\'t take more replies. Ask again from Help & support.';

  @override
  String get contactTitle => 'Contact support';

  @override
  String get contactIntro =>
      'Can\'t sign in, or not a Montra user yet? Send us a message and we\'ll reply by email.';

  @override
  String get contactEmailLabel => 'Your email';

  @override
  String get contactEmailHelp => 'We use it only to reply to this message.';

  @override
  String get contactEmailInvalid =>
      'Enter an email address like name@example.com.';

  @override
  String get contactSentTitle => 'Message sent';

  @override
  String contactSentBody(String reference) {
    return 'Your reference is $reference. We\'ll reply to your email.';
  }

  @override
  String get privacyTitle => 'Privacy & data';

  @override
  String get privacyIntro =>
      'Choose what Montra may do with your data, get a copy of everything, or close your account.';

  @override
  String get privacyConsentsTitle => 'Consents';

  @override
  String privacyConsentAccepted(String version) {
    return 'Accepted (version $version)';
  }

  @override
  String get privacyConsentTerms => 'Terms of use';

  @override
  String get privacyConsentPrivacyPolicy => 'Privacy notice';

  @override
  String get privacyConsentRequiredBody =>
      'Needed to use Montra. To withdraw it, delete your account.';

  @override
  String get privacyConsentLocation => 'Location on transactions';

  @override
  String get privacyConsentLocationBody =>
      'Lets you save a place name with a transaction, like the shop where you paid. When it\'s off, you can\'t add a location.';

  @override
  String get privacyConsentPush => 'Push notifications';

  @override
  String get privacyConsentPushBody =>
      'Records whether Montra may send alerts to your devices. Push alerts are not set up in this version of the app; you see everything in the notification center.';

  @override
  String get privacyConsentMarketing => 'Product news by email';

  @override
  String get privacyConsentMarketingBody =>
      'Occasional emails about new features. Montra doesn\'t send these today; this records your choice. Account and security emails are always sent.';

  @override
  String get privacyConsentAnalytics => 'Product analytics';

  @override
  String get privacyConsentAnalyticsBody =>
      'Allows aggregate statistics about how features are used. Montra collects none today and this app has no analytics tools; this records your choice.';

  @override
  String get privacyConsentContacts => 'Be found by your contacts';

  @override
  String get privacyConsentContactsBody =>
      'Lets people who already have your contact details find you. Montra has no contact matching today; being found by username is a separate setting under Friends.';

  @override
  String get privacyConsentAi => 'AI features';

  @override
  String get privacyConsentAiBody =>
      'This app has no AI features. You gave this consent in another Montra app; withdrawing it turns AI off everywhere.';

  @override
  String get privacyConsentAiReceipts => 'AI reading of receipts';

  @override
  String get privacyConsentAiReceiptsBody =>
      'This app never reads receipts automatically. Withdrawing means receipts stay manual everywhere.';

  @override
  String get privacyConsentOther => 'Other consent';

  @override
  String get privacyConsentGiven => 'Consent given.';

  @override
  String get privacyConsentWithdrawn => 'Consent withdrawn.';

  @override
  String get privacyConsentVersionMissing =>
      'The current wording couldn\'t be loaded. Pull down to refresh, then try again.';

  @override
  String get privacyRequiredConsentError =>
      'Terms and privacy consent are needed to use Montra. To withdraw them, delete your account.';

  @override
  String get privacyExportTitle => 'A copy of your data';

  @override
  String get privacyExportIntro =>
      'Get everything Montra keeps about you as one ZIP file. It\'s made in the background; download it here when it\'s ready, then share it or save it to your device.';

  @override
  String get privacyExportRequest => 'Request a copy';

  @override
  String get privacyExportRequested =>
      'Your copy is being made. This page updates by itself.';

  @override
  String get privacyExportNone => 'You haven\'t requested a copy yet.';

  @override
  String get privacyExportStillWorking =>
      'Still being made. Pull down to check again.';

  @override
  String privacyExportRequestedOn(String date) {
    return 'Requested $date';
  }

  @override
  String get privacyExportQueued => 'Waiting to start';

  @override
  String get privacyExportRunning => 'Being made';

  @override
  String get privacyExportReady => 'Ready to download';

  @override
  String get privacyExportFailed => 'Couldn\'t be made';

  @override
  String get privacyExportExpired => 'Expired';

  @override
  String privacyExportExpires(String date) {
    return 'Available until $date';
  }

  @override
  String get privacyExportFailedHelp =>
      'Something went wrong while making it. Request a new copy.';

  @override
  String get privacyExportExpiredHelp =>
      'Its download period ended and the file was removed. Request a new copy.';

  @override
  String get privacyExportDownload => 'Download your data';

  @override
  String get privacyExportReadyTitle => 'Your data is ready';

  @override
  String get privacyAccountTitle => 'Your account';

  @override
  String get privacyLimitsSubtitle => 'Fair-use limits and your storage';

  @override
  String get privacyDeactivateSubtitle =>
      'Take a break; sign in again to come back';

  @override
  String get privacyDeletionSubtitle =>
      'Permanently delete your account and data';

  @override
  String get privacyDeletionScheduledSubtitle => 'See the date or cancel it';

  @override
  String get deactivateTitle => 'Close your account for now';

  @override
  String get deactivateIntro =>
      'Closing your account is a break, not a deletion.';

  @override
  String get deactivatePointSignedOut =>
      'You\'ll be signed out on every device.';

  @override
  String get deactivatePointKept =>
      'Your records stay as they are; nothing is deleted.';

  @override
  String get deactivatePointHidden =>
      'Others can\'t find you or send you requests while it\'s closed.';

  @override
  String get deactivatePointReturn => 'To come back, just sign in again.';

  @override
  String get deactivateAction => 'Close my account';

  @override
  String get deactivateConfirmTitle => 'Close your account?';

  @override
  String get deactivateConfirmBody =>
      'You\'ll be signed out everywhere. Sign in again whenever you want to come back.';

  @override
  String get deletionTitle => 'Delete your account';

  @override
  String get deletionIntro =>
      'Deleting your account is permanent after a short waiting period. You can cancel until then.';

  @override
  String get deletionWhatHappens => 'What happens';

  @override
  String get deletionWhatIsKept => 'What is kept, and why';

  @override
  String get deletionGroupsTitle => 'Your groups';

  @override
  String get deletionConsequenceSignedOut =>
      'You\'ll be signed out of every device and connected services will be disconnected.';

  @override
  String get deletionConsequenceRecords =>
      'Your accounts, transactions, budgets, goals, subscriptions, receipts, imports and reports will be permanently deleted.';

  @override
  String get deletionConsequenceDocuments =>
      'Files you uploaded will be removed from storage.';

  @override
  String get deletionConsequenceProfile =>
      'Your profile will be removed; your community posts and comments will no longer show your name.';

  @override
  String get deletionConsequenceIrreversible =>
      'After the scheduled date this can\'t be undone.';

  @override
  String get deletionRetainedGroupRecords =>
      'Shared group expenses and settlements stay, without your name, so other members\' balances remain correct.';

  @override
  String get deletionRetainedAudit =>
      'Security records are kept for a limited time, as the law requires.';

  @override
  String deletionGroupTransfer(String group) {
    return '$group: ownership will pass to its longest-standing admin or member.';
  }

  @override
  String deletionGroupDeleted(String group) {
    return '$group: it has no other members and will be deleted.';
  }

  @override
  String get deletionExportFirst =>
      'You may want a copy of your data first: request it on the Privacy & data screen.';

  @override
  String get deletionReasonLabel => 'Why are you leaving? (optional)';

  @override
  String get deletionReasonHelp =>
      'This helps us improve. Don\'t include personal details.';

  @override
  String deletionConfirmLabel(String word) {
    return 'Type $word to confirm';
  }

  @override
  String deletionConfirmMismatch(String word) {
    return 'Type $word exactly to confirm.';
  }

  @override
  String get deletionAction => 'Delete my account';

  @override
  String get deletionScheduledDone =>
      'Deletion scheduled. You can cancel it until the date shown.';

  @override
  String get deletionScheduledTitle => 'Account deletion scheduled';

  @override
  String deletionScheduledFor(String date) {
    return 'Your account will be deleted on $date. You can cancel until then.';
  }

  @override
  String get deletionScheduledNoDate =>
      'Your account is scheduled to be deleted. You can still cancel.';

  @override
  String get deletionCancelAction => 'Keep my account';

  @override
  String get deletionCancelledDone => 'Deletion cancelled. Your account stays.';

  @override
  String get limitsFairUseNote =>
      'Every feature is free for everyone. These limits are the same for everyone and keep Montra fast and affordable to run.';

  @override
  String limitsStoragePercent(int percent) {
    return '$percent percent used';
  }

  @override
  String limitsUploadSize(String size) {
    return 'Largest single upload: $size';
  }

  @override
  String get limitsOpenRecordsTitle => 'Open records you can keep';

  @override
  String get limitsOpenBillsLabel => 'Open bills';

  @override
  String get limitsOpenRecurringLabel => 'Recurring payments';

  @override
  String get limitsOpenSubscriptionsLabel => 'Subscriptions';

  @override
  String get limitsOpenGoalsLabel => 'Goals';

  @override
  String get limitsOpenRecordsHelp =>
      'Ended, archived and deleted ones don\'t count.';

  @override
  String get limitsOtherTitle => 'Imports, support and downloads';

  @override
  String get limitsImportRowsLabel => 'Rows per statement import';

  @override
  String get limitsSupportPerDayLabel => 'Support requests per day';

  @override
  String get limitsExportDaysLabel =>
      'Reports and data copies stay downloadable';

  @override
  String get limitsDeletionGraceLabel => 'Waiting period before deletion';

  @override
  String limitsDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get limitsRatesTitle => 'Requests per minute';

  @override
  String get limitsRatesHelp =>
      'Short bursts above these are fine. If you go past a limit, the app tells you when to try again.';

  @override
  String limitsPerMinute(String count) {
    return '$count a minute';
  }

  @override
  String get limitsPolicyDefault => 'Reading';

  @override
  String get limitsPolicyAuth => 'Signing in';

  @override
  String get limitsPolicyWrite => 'Saving changes';

  @override
  String get limitsPolicyUpload => 'Uploads';

  @override
  String get limitsPolicyAi => 'AI';

  @override
  String get limitsPolicyExport => 'Exports';

  @override
  String get limitsPolicySocial => 'Friends and community';

  @override
  String get limitsPolicyOther => 'Other';

  @override
  String get notifViewInbox => 'Inbox';

  @override
  String get notifViewUnread => 'Unread';

  @override
  String get notifViewArchive => 'Archive';

  @override
  String get notifCategoryFilter => 'Show notifications about';

  @override
  String get notifCategoryAll => 'All topics';

  @override
  String get notifReadAll => 'Mark all as read';

  @override
  String notifReadAllDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notifications marked as read.',
      one: '1 notification marked as read.',
      zero: 'Nothing was unread.',
    );
    return '$_temp0';
  }

  @override
  String get notifSettingsTitle => 'Notification settings';

  @override
  String get notifActions => 'More actions';

  @override
  String get notifMarkRead => 'Mark as read';

  @override
  String get notifMarkUnread => 'Mark as unread';

  @override
  String get notifArchive => 'Archive';

  @override
  String get notifMoveToInbox => 'Move back to inbox';

  @override
  String get notifMarkedRead => 'Marked as read.';

  @override
  String get notifMarkedUnread => 'Marked as unread.';

  @override
  String get notifArchived => 'Archived.';

  @override
  String get notifMovedToInbox => 'Moved back to the inbox.';

  @override
  String get notifNothingToOpen =>
      'This notification has nothing more to open.';

  @override
  String get notifUnreadLabel => 'Unread';

  @override
  String get notifEmptyTitle => 'No notifications';

  @override
  String get notifEmptyUnreadTitle => 'You\'re all caught up';

  @override
  String get notifEmptyArchiveTitle => 'Nothing archived';

  @override
  String get notifEmptyBody =>
      'Reminders and updates about your money, groups and account appear here.';

  @override
  String get notifPriorityHigh => 'Important';

  @override
  String get notifPriorityCritical => 'Urgent';

  @override
  String get notifCategoryBudget => 'Budgets';

  @override
  String get notifCategoryBill => 'Bills';

  @override
  String get notifCategorySubscription => 'Subscriptions';

  @override
  String get notifCategoryRecurring => 'Recurring payments';

  @override
  String get notifCategoryGoal => 'Goals';

  @override
  String get notifCategoryGroup => 'Groups';

  @override
  String get notifCategorySettlement => 'Settlements';

  @override
  String get notifCategoryTrip => 'Trips';

  @override
  String get notifCategoryCommunity => 'Communities';

  @override
  String get notifCategoryChallenge => 'Challenges';

  @override
  String get notifCategorySecurity => 'Security';

  @override
  String get notifCategoryImport => 'Statement imports';

  @override
  String get notifCategoryReceipt => 'Receipts';

  @override
  String get notifCategoryExport => 'Data exports';

  @override
  String get notifCategoryAccount => 'Your account';

  @override
  String get notifCategoryInsight => 'Insights';

  @override
  String get notifCategorySystem => 'Montra updates';

  @override
  String get notifCategorySocial => 'Friends';

  @override
  String get notifChannelInApp => 'In the app';

  @override
  String get notifChannelEmail => 'Email';

  @override
  String get notifChannelPush => 'Phone notifications';

  @override
  String get notifChannelWebPush => 'Browser notifications';

  @override
  String get notifDigestFollowAccount => 'Same as your email digest setting';

  @override
  String get notifDigestDaily => 'Daily digest';

  @override
  String get notifDigestWeekly => 'Weekly digest (Mondays)';

  @override
  String get notifDigestOff => 'Off: send each email right away';

  @override
  String get notifPushTitle => 'Phone notifications are not set up';

  @override
  String get notifPushNotConfigured =>
      'This version of the app doesn\'t receive push notifications. Everything you turn on below appears in the notification center in the app, and by email where you choose email.';

  @override
  String get notifPushChannelNote => 'Not set up in this version of the app';

  @override
  String get notifWebPushChannelNote => 'For the Montra website in a browser';

  @override
  String get notifAlwaysOn => 'Always on';

  @override
  String get notifAlwaysOnNote =>
      'Security and account notifications always reach you in the app and by email, so you never miss a sign-in or account change.';

  @override
  String get notifAlwaysOnError =>
      'Security and account notifications can\'t be turned off.';

  @override
  String get notifEmailTiming => 'When emails arrive';

  @override
  String notifEmailTimingFor(String category) {
    return 'Emails about $category';
  }

  @override
  String get notifSettingsSaved => 'Saved.';

  @override
  String get notifEmailAndQuietTitle => 'Email digest and quiet hours';

  @override
  String get notifAccountDigestTitle => 'Email digest';

  @override
  String get notifAccountDigestHelp =>
      'Optional emails can be collected into one email at 08:00 your time (weekly on Mondays). Security, account and urgent emails always arrive right away.';

  @override
  String get notifQuietHoursTitle => 'Quiet hours';

  @override
  String get notifQuietHoursHelp =>
      'During quiet hours, emails and other alerts wait until the quiet hours end. Security and urgent ones still arrive. The notification center in the app is updated as usual.';

  @override
  String get notifQuietHoursFrom => 'Starts at';

  @override
  String get notifQuietHoursTo => 'Ends at';

  @override
  String notifQuietHoursZone(String zone) {
    return 'Times are in your time zone ($zone).';
  }

  @override
  String get notifGroupOverridesTitle => 'Group settings';

  @override
  String get notifGroupOverridesHelp =>
      'These groups have their own setting for some topics.';

  @override
  String get notifGroupUnknown => 'A group';

  @override
  String get integrationsTitle => 'Bank connections';

  @override
  String get integrationIntro =>
      'Montra works fully without connections: add transactions yourself or import statements. A connection would bring in transactions from your bank after you approve it at the bank or provider; Montra never asks for your bank password.';

  @override
  String get integrationConnectionsTitle => 'Your connections';

  @override
  String get integrationNoConnections => 'You have no connections.';

  @override
  String get integrationProvidersTitle => 'Providers';

  @override
  String get integrationNoProviders => 'No providers are listed.';

  @override
  String get integrationCallbackNote =>
      'After you approve access at the provider, it sends you back to the Montra website, which finishes connecting. Then come back here and pull down to refresh.';

  @override
  String get integrationStatusAvailable => 'Available';

  @override
  String get integrationStatusNotConfigured => 'Not configured';

  @override
  String get integrationStatusUnavailable => 'Not available yet';

  @override
  String get integrationNotConfiguredHelp =>
      'This provider isn\'t configured on this Montra server, so it can\'t be connected.';

  @override
  String get integrationUnavailableHelp =>
      'This provider can\'t be connected yet.';

  @override
  String integrationReason(String reason) {
    return 'Details from Montra: $reason';
  }

  @override
  String get integrationKindBankData => 'Bank data';

  @override
  String get integrationKindAccountAggregator => 'Account Aggregator';

  @override
  String get integrationKindCard => 'Cards';

  @override
  String get integrationKindPayments => 'Payments';

  @override
  String get integrationKindOther => 'Other provider';

  @override
  String integrationCountries(String countries) {
    return 'Countries: $countries';
  }

  @override
  String integrationCapabilities(String items) {
    return 'Brings in: $items';
  }

  @override
  String get integrationScopeTransactions => 'transactions';

  @override
  String get integrationScopeBalances => 'balances';

  @override
  String get integrationScopeAccounts => 'accounts';

  @override
  String get integrationScopeStatements => 'statements';

  @override
  String get integrationConnect => 'Connect';

  @override
  String get integrationChooseAccount => 'Account to connect';

  @override
  String integrationConsentTitle(String provider) {
    return 'Connect $provider?';
  }

  @override
  String get integrationConsentPurpose => 'Why Montra asks:';

  @override
  String integrationConsentScope(String items) {
    return 'What Montra can read: $items';
  }

  @override
  String integrationConsentDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Access lasts $days days; you can disconnect at any time.',
      one: 'Access lasts 1 day; you can disconnect at any time.',
    );
    return '$_temp0';
  }

  @override
  String get integrationNoCredentials =>
      'You approve access at the provider. Montra never asks for your bank password or PIN.';

  @override
  String get integrationConsentCheck =>
      'I agree to share this data with Montra';

  @override
  String get integrationContinueTitle => 'Continue at the provider';

  @override
  String integrationContinueBody(String provider) {
    return '$provider opened in your browser. Approve access there. You\'ll be sent back to the Montra website, which finishes connecting; then pull down here to see the connection.';
  }

  @override
  String get integrationOpenFailedTitle => 'Couldn\'t open the provider';

  @override
  String get integrationOpenFailedBody =>
      'Your browser couldn\'t be opened. Try again, or connect from the Montra website.';

  @override
  String get integrationNeverSynced => 'Not synced yet';

  @override
  String integrationLastSync(String when) {
    return 'Last synced $when';
  }

  @override
  String get integrationLastSyncLabel => 'Last synced';

  @override
  String get integrationConnectionTitle => 'Connection';

  @override
  String get integrationConnPending => 'Waiting for approval';

  @override
  String get integrationConnConnected => 'Connected';

  @override
  String get integrationConnSyncing => 'Syncing';

  @override
  String get integrationConnPartial => 'Partly synced';

  @override
  String get integrationConnFailed => 'Sync failed';

  @override
  String get integrationConnConsentExpired => 'Consent expired';

  @override
  String get integrationConnDisconnected => 'Disconnected';

  @override
  String get integrationConnRevoked => 'Access removed';

  @override
  String get integrationScopeLabel => 'Data shared';

  @override
  String get integrationConsentGranted => 'Consent given';

  @override
  String get integrationConsentExpires => 'Consent ends';

  @override
  String get integrationLinkedAccount => 'Account';

  @override
  String get integrationOpenAccount => 'Open the account';

  @override
  String get integrationLastProblem => 'Last problem';

  @override
  String get integrationSyncNow => 'Sync now';

  @override
  String get integrationSyncStarted =>
      'Sync started. Pull down to see its progress.';

  @override
  String get integrationSyncRunning =>
      'A sync is already running. Try again when it finishes.';

  @override
  String get integrationDisconnect => 'Disconnect';

  @override
  String get integrationDisconnectTitle => 'Disconnect?';

  @override
  String get integrationDisconnectBody =>
      'Montra stops reading from this provider and deletes what it stored to connect. Transactions it brought in stay unless you choose below.';

  @override
  String get integrationDeleteData =>
      'Also remove the transactions it brought in';

  @override
  String get integrationDeleteDataHelp =>
      'They\'re voided, so balances and reports no longer count them.';

  @override
  String get integrationDisconnected => 'Disconnected.';

  @override
  String integrationDisconnectedVoided(int voided) {
    String _temp0 = intl.Intl.pluralLogic(
      voided,
      locale: localeName,
      other: 'Disconnected. $voided transactions were removed.',
      one: 'Disconnected. 1 transaction was removed.',
      zero: 'Disconnected. No transactions needed removing.',
    );
    return '$_temp0';
  }

  @override
  String get integrationRunsTitle => 'Recent syncs';

  @override
  String get integrationNoRuns => 'No syncs yet.';

  @override
  String get integrationRunQueued => 'Waiting';

  @override
  String get integrationRunRunning => 'Running';

  @override
  String get integrationRunSucceeded => 'Done';

  @override
  String get integrationRunPartial => 'Partly done';

  @override
  String get integrationRunFailed => 'Failed';

  @override
  String get integrationTriggerManual => 'started by you';

  @override
  String get integrationTriggerScheduled => 'scheduled';

  @override
  String get integrationTriggerWebhook => 'sent by the provider';

  @override
  String get integrationTriggerBackfill => 'first import';

  @override
  String integrationRunCounts(
    int fetched,
    int created,
    int updated,
    int skipped,
  ) {
    return 'Fetched $fetched · added $created · updated $updated · skipped $skipped';
  }

  @override
  String get integrationConsentExpired =>
      'Your consent for this connection expired. Connect again to renew it.';

  @override
  String get integrationReconnectRequired => 'Connect again before syncing.';

  @override
  String get integrationLinkedNotReversible =>
      'Linked transactions aren\'t changed by the provider.';

  @override
  String get integrationErrorProviderUnavailable =>
      'The provider didn\'t respond. Try again later.';

  @override
  String integrationErrorCode(String code) {
    return 'Problem code: $code';
  }

  @override
  String get searchFieldLabel => 'Search your money, groups and posts';

  @override
  String get searchFieldHelp =>
      'Type at least 2 characters. Press search to keep it in your recent searches.';

  @override
  String get searchSubmit => 'Search';

  @override
  String get searchScopeAll => 'Everything';

  @override
  String get searchSortTitle => 'Sort results';

  @override
  String get searchSortRelevance => 'Best match';

  @override
  String get searchSortName => 'Name';

  @override
  String get searchSortRecent => 'Newest first';

  @override
  String searchSortedBy(String sort) {
    return 'Sorted by: $sort';
  }

  @override
  String get searchSectionTransactions => 'Transactions';

  @override
  String get searchSectionMerchants => 'Merchants';

  @override
  String get searchSectionAccounts => 'Accounts';

  @override
  String get searchSectionCategories => 'Categories';

  @override
  String get searchSectionBudgets => 'Budgets';

  @override
  String get searchSectionGoals => 'Goals';

  @override
  String get searchSectionBills => 'Bills';

  @override
  String get searchSectionSubscriptions => 'Subscriptions';

  @override
  String get searchSectionRecurring => 'Recurring payments';

  @override
  String get searchSectionGroups => 'Groups';

  @override
  String get searchSectionPosts => 'Community posts';

  @override
  String get searchSectionPeople => 'People';

  @override
  String get searchPeopleNote =>
      'People are found only by their exact username, and only if they allow it.';

  @override
  String get searchKindExpense => 'Expense';

  @override
  String get searchKindIncome => 'Income';

  @override
  String get searchKindTransfer => 'Transfer';

  @override
  String get searchGroupHousehold => 'Household';

  @override
  String get searchGroupRoommates => 'Roommates';

  @override
  String get searchGroupTrip => 'Trip';

  @override
  String get searchGroupEvent => 'Event';

  @override
  String get searchGroupFriends => 'Friends';

  @override
  String get searchGroupCustom => 'Group';

  @override
  String get searchShared => 'Shared';

  @override
  String get searchUntitled => 'Transaction';

  @override
  String get searchNoResults => 'Nothing found';

  @override
  String get searchNoResultsBody => 'Try other words or another section.';

  @override
  String get searchStartTitle => 'Search Montra';

  @override
  String get searchStartBody =>
      'Find transactions, merchants, accounts, budgets, goals, bills, subscriptions, groups and community posts.';

  @override
  String get searchRecentTitle => 'Recent searches';

  @override
  String get searchClearRecent => 'Clear';

  @override
  String get searchClearRecentTitle => 'Clear recent searches?';

  @override
  String get searchClearRecentBody =>
      'Your search history is removed from Montra.';

  @override
  String get searchRecentCleared => 'Recent searches cleared.';

  @override
  String get insightViewActive => 'Needs a look';

  @override
  String get insightViewAll => 'All, including handled';

  @override
  String get insightKindFilter => 'Kind of insight';

  @override
  String get insightKindAll => 'All kinds';

  @override
  String get insightKindLabel => 'Kind';

  @override
  String get insightKindAnomaly => 'Unusual activity';

  @override
  String get insightKindSavings => 'Saving opportunities';

  @override
  String get insightKindSummary => 'Summaries';

  @override
  String get insightKindForecast => 'Outlook';

  @override
  String get insightKindBudget => 'Budgets';

  @override
  String get insightKindSubscription => 'Subscriptions';

  @override
  String get insightKindRecurring => 'Recurring payments';

  @override
  String get insightKindOther => 'Other';

  @override
  String get insightMutesTitle => 'Muted insights';

  @override
  String get insightRulesNote =>
      'Insights come from fixed rules over your own records; no AI is used. They never change your records.';

  @override
  String get insightEmptyTitle => 'Nothing needs a look';

  @override
  String get insightEmptyBody =>
      'Montra checks your records for unusual activity and ways to save. New findings appear here.';

  @override
  String get insightSeverityWarning => 'Needs attention';

  @override
  String get insightSeverityNotice => 'Worth a look';

  @override
  String get insightSeverityInfo => 'For your information';

  @override
  String get insightStatusActive => 'Open';

  @override
  String get insightStatusDismissed => 'Dismissed';

  @override
  String get insightStatusSnoozed => 'Snoozed';

  @override
  String get insightStatusExpected => 'Expected';

  @override
  String get insightStatusResolved => 'Resolved';

  @override
  String get insightStatusMuted => 'Muted';

  @override
  String get insightDetailTitle => 'Insight';

  @override
  String get insightNotFoundTitle => 'This insight isn\'t available';

  @override
  String get insightNotFoundBody => 'It may be too old to show here.';

  @override
  String insightSnoozedUntil(String when) {
    return 'Snoozed until $when';
  }

  @override
  String get insightWhyTitle => 'Why you see this';

  @override
  String get insightRuleUnknown => 'A rule over your own records found this.';

  @override
  String get insightPeriod => 'Period';

  @override
  String get insightOpenTransaction => 'Open the transaction';

  @override
  String get insightOpenBudget => 'Open the budget';

  @override
  String get insightOpenSubscription => 'Open the subscription';

  @override
  String get insightOpenRecurring => 'Open the recurring payment';

  @override
  String get insightOpenMerchant => 'Open the merchant';

  @override
  String get insightOpenCategory => 'See this category\'s transactions';

  @override
  String get insightOpenAccount => 'Open the account';

  @override
  String get insightActionsTitle => 'What do you want to do?';

  @override
  String get insightActionsHelp =>
      'These only change this insight, never your records.';

  @override
  String get insightActionExpected => 'This was expected';

  @override
  String get insightActionResolved => 'I\'ve dealt with it';

  @override
  String get insightActionSnooze => 'Remind me later';

  @override
  String get insightActionDismiss => 'Dismiss';

  @override
  String get insightActionMute => 'Stop showing this kind';

  @override
  String get insightActionReopen => 'Open it again';

  @override
  String get insightSnoozeTitle => 'Remind me in';

  @override
  String insightSnoozeDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String insightSnoozed(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Snoozed for $days days.',
      one: 'Snoozed for 1 day.',
    );
    return '$_temp0';
  }

  @override
  String get insightDismissed => 'Dismissed.';

  @override
  String get insightMarkedExpected => 'Marked as expected.';

  @override
  String get insightMarkedResolved => 'Marked as resolved.';

  @override
  String get insightMuted => 'Muted. You can unmute it in Muted insights.';

  @override
  String get insightReopened => 'Opened again.';

  @override
  String get insightSaved => 'Saved.';

  @override
  String get insightMute => 'Mute';

  @override
  String get insightMuteTitle => 'Stop showing this kind?';

  @override
  String insightMuteBody(String kind) {
    return 'Montra stops showing \"$kind\" insights about this. You can unmute them at any time in Muted insights.';
  }

  @override
  String get insightFeedbackTitle => 'Was this helpful?';

  @override
  String insightFeedbackYours(String answer) {
    return 'Your answer: $answer';
  }

  @override
  String get insightFeedbackNote => 'Note (optional)';

  @override
  String get insightFeedbackNoteHelp =>
      'Sent with your answer. Leave it empty to remove a note you sent before. Don\'t include card numbers or passwords.';

  @override
  String get insightFeedbackHelpful => 'Helpful';

  @override
  String get insightFeedbackNotHelpful => 'Not helpful';

  @override
  String get insightFeedbackIncorrect => 'Not correct';

  @override
  String get insightFeedbackExpected => 'Expected';

  @override
  String get insightFeedbackSaved => 'Thanks, your answer was saved.';

  @override
  String get insightMutesHelp =>
      'Muted kinds of insight are not shown. Unmuting brings back the insights they were hiding.';

  @override
  String get insightMutesEmptyTitle => 'Nothing is muted';

  @override
  String get insightMutesEmptyBody => 'Kinds of insight you mute appear here.';

  @override
  String get insightMuteEverywhere => 'Everywhere';

  @override
  String get insightMuteOneRecord => 'For one record';

  @override
  String insightMutedOn(String date) {
    return 'muted on $date';
  }

  @override
  String get insightUnmute => 'Unmute';

  @override
  String insightUnmuted(int reopened) {
    String _temp0 = intl.Intl.pluralLogic(
      reopened,
      locale: localeName,
      other: 'Unmuted. $reopened insights are back.',
      one: 'Unmuted. 1 insight is back.',
      zero: 'Unmuted.',
    );
    return '$_temp0';
  }

  @override
  String get insightSubtypeUnusualAmount => 'Unusually large expense';

  @override
  String get insightSubtypeCategorySpike => 'Category above your usual month';

  @override
  String get insightSubtypeNewMerchant => 'Large first purchase at a merchant';

  @override
  String get insightSubtypeDuplicate => 'Possible duplicate';

  @override
  String get insightSubtypePriceIncrease => 'Subscription price increase';

  @override
  String get insightSubtypeMissingRecurring => 'Recurring payment not recorded';

  @override
  String get insightSubtypeCashFlow => 'Change in monthly cash flow';

  @override
  String get insightSubtypeSubscriptionCosts => 'Subscription costs';

  @override
  String get insightSubtypeFrequency => 'More purchases than usual';

  @override
  String get insightSubtypeRecurringChange => 'Recurring amount changed';

  @override
  String get insightSubtypeOverspend => 'Budget often exceeded';

  @override
  String get insightRuleUnusualAmount =>
      'The amount is at least 3 times your usual (median) amount in this category over the last 6 months, and above 95% of those transactions.';

  @override
  String get insightRuleCategorySpike =>
      'What you spent in this category so far this month is more than your average month over the previous 3 months.';

  @override
  String get insightRuleNewMerchant =>
      'It\'s your first transaction at this merchant and at least twice your usual (median) expense.';

  @override
  String get insightRuleDuplicate =>
      'Two transactions in the same account have the same amount within 2 days, with the same merchant or description.';

  @override
  String get insightRulePriceChange =>
      'A payment you recorded changed the price of this subscription.';

  @override
  String get insightRuleMissingRecurring =>
      'A recurring payment is overdue and no payment is linked to it.';

  @override
  String get insightRuleCashFlow =>
      'Last month your spending was at least 25% higher, or your income at least 20% lower, than your average over the 3 months before.';

  @override
  String get insightRuleSubscriptionCosts =>
      'Your active subscriptions, each converted to a monthly cost from how often it bills.';

  @override
  String get insightRuleFrequency =>
      'At least 4 purchases at this merchant in 7 days, and at least 3 times your weekly average of the previous 12 weeks.';

  @override
  String get insightRuleRecurringChange =>
      'The latest payment differs by at least 10% from the median of up to 6 earlier payments.';

  @override
  String get insightRuleOverspend =>
      'You spent above the limit in at least 2 of the last 3 finished periods.';

  @override
  String get insightAmountAmount => 'Amount';

  @override
  String get insightAmountUsual => 'Usual amount';

  @override
  String get insightAmountP95 => 'Most of your transactions stay below';

  @override
  String get insightAmountTypical => 'Your typical expense';

  @override
  String get insightAmountSoFar => 'So far this month';

  @override
  String get insightAmountMonthlyAverage => 'Average month';

  @override
  String get insightAmountOld => 'Previous price';

  @override
  String get insightAmountNew => 'New price';

  @override
  String get insightAmountSpending => 'Spending';

  @override
  String get insightAmountUsualSpending => 'Usual spending';

  @override
  String get insightAmountIncome => 'Income';

  @override
  String get insightAmountUsualIncome => 'Usual income';

  @override
  String get insightAmountMonthly => 'Per month';

  @override
  String get insightAmountYearly => 'Per year';

  @override
  String get insightAmountAverageSpent => 'Average spent';

  @override
  String get insightAmountAverageOverspend => 'Average amount over';

  @override
  String get insightAmountLimit => 'Limit';

  @override
  String insightMsgUnusualAmountTitle(String category) {
    return 'Unusually large $category expense';
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
    return '$amount for $label on $date is about $ratio× your usual $category transaction (median $median over $count transactions in the previous $months months). If it\'s expected, mark it so.';
  }

  @override
  String insightMsgCategorySpikeTitle(String category) {
    return '$category spending is above your usual month';
  }

  @override
  String insightMsgCategorySpikeBody(
    String soFar,
    String category,
    String average,
    int months,
  ) {
    return 'You\'ve spent $soFar on $category so far this month, more than your usual $average a month (average of the previous $months months).';
  }

  @override
  String insightMsgNewMerchantTitle(String merchant) {
    return 'First purchase at $merchant';
  }

  @override
  String insightMsgNewMerchantBody(
    String amount,
    String merchant,
    String date,
    String typical,
  ) {
    return '$amount at $merchant on $date is your first transaction there and larger than your typical expense ($typical). If you recognise it, mark it expected.';
  }

  @override
  String insightMsgDuplicateTitle(String label) {
    return 'Possible duplicate: $label';
  }

  @override
  String insightMsgDuplicateBody(
    String amount,
    String label,
    String first,
    String second,
  ) {
    return 'Two transactions of $amount for $label on $first and $second in the same account look alike. If one was recorded twice, void it; Montra never deletes it for you.';
  }

  @override
  String insightMsgPriceIncreaseTitle(String name) {
    return '$name costs more';
  }

  @override
  String insightMsgPriceIncreaseBody(
    String name,
    String before,
    String after,
    String percent,
    String date,
  ) {
    return '$name went from $before to $after per billing ($percent more) on $date.';
  }

  @override
  String insightMsgMissingRecurringTitle(String name) {
    return '$name was not recorded';
  }

  @override
  String insightMsgMissingRecurringBody(String name, String date) {
    return '$name was due on $date, but no payment is linked yet. Record or link it, or skip this occurrence.';
  }

  @override
  String insightMsgMissingRecurringAmountBody(
    String name,
    String amount,
    String date,
  ) {
    return '$name ($amount) was due on $date, but no payment is linked yet. Record or link it, or skip this occurrence.';
  }

  @override
  String get insightMsgCashFlowTitle => 'Last month\'s cash flow changed';

  @override
  String insightMsgCashFlowSpendingBody(
    String month,
    String spending,
    String usual,
    int months,
  ) {
    return 'In $month, spending was $spending against your usual $usual (average of the $months months before).';
  }

  @override
  String insightMsgCashFlowIncomeBody(
    String month,
    String income,
    String usual,
    int months,
  ) {
    return 'In $month, income was $income against your usual $usual (average of the $months months before).';
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
    return 'In $month, spending was $spending against your usual $usualSpending, and income was $income against your usual $usualIncome (average of the $months months before).';
  }

  @override
  String insightMsgSubscriptionCostsTitle(int count, String monthly) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count subscriptions cost about $monthly a month',
      one: '1 subscription costs about $monthly a month',
    );
    return '$_temp0';
  }

  @override
  String insightMsgSubscriptionCostsBody(String yearly) {
    return 'That\'s about $yearly a year. Cancelling one you no longer use stops its future renewals only; Montra doesn\'t cancel anything for you.';
  }

  @override
  String insightMsgFrequencyTitle(String merchant) {
    return 'More purchases than usual at $merchant';
  }

  @override
  String insightMsgFrequencyBody(
    int count,
    String merchant,
    int days,
    String average,
    int weeks,
  ) {
    return 'You made $count purchases at $merchant in the last $days days, compared with about $average a week over the previous $weeks weeks. This is unusual for you, not necessarily wrong; if it\'s expected, mark it so.';
  }

  @override
  String insightMsgRecurringHigherTitle(String name) {
    return '$name was higher than usual';
  }

  @override
  String insightMsgRecurringLowerTitle(String name) {
    return '$name was lower than usual';
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
    return 'The latest $name payment ($amount on $date) differs from the usual $usual (median of the previous $count payments), a change of $percent%. If the amount changed for good, update the recurring payment so your plans stay accurate.';
  }

  @override
  String insightMsgOverspendTitle(String budget, int over, int periods) {
    return '$budget budget went over in $over of the last $periods periods';
  }

  @override
  String insightMsgOverspendBody(
    int periods,
    String average,
    String limit,
    String overspend,
  ) {
    return 'Across the last $periods periods you spent $average on average against a limit of $limit, going over by $overspend on average when it was exceeded. You could raise the limit to about $average so the budget matches how you actually spend, or keep it and look at what drives the spending. Based on past periods only.';
  }

  @override
  String get importErrorTooLarge =>
      'The file is too large to import. Split the statement into smaller periods.';

  @override
  String importErrorCurrencyNamed(String statement, String account) {
    return 'The statement is in $statement, but the account is in $account. Import it into an account in $statement.';
  }

  @override
  String get importNotesTitle => 'Check the columns';

  @override
  String get importNoteNoHeader =>
      'No header row was found, so the columns are numbered. Check which column holds what.';

  @override
  String importNoteAmbiguousDate(String assumed, String alternative) {
    return 'Dates could be day-first or month-first; $assumed was assumed. Choose $alternative if that\'s wrong.';
  }

  @override
  String get importNoteAmbiguousDateGeneric =>
      'Dates could be day-first or month-first. Check the date format.';

  @override
  String get importNoteUnknownDateFormat =>
      'The date format wasn\'t recognized. Choose it in the columns.';

  @override
  String get importNoteDecimalComma =>
      'Amounts use a comma for decimals. Check that they were read correctly.';

  @override
  String get importNoteMappingIncomplete =>
      'Some needed columns couldn\'t be found. Choose them in the columns.';

  @override
  String get importNoteCheckSign =>
      'Check whether negative amounts are money out or money in.';

  @override
  String get importNotePdfRead =>
      'This statement was read automatically. Check every row before importing.';

  @override
  String importReasonBadDateFormat(String format) {
    return 'The date doesn\'t match $format.';
  }

  @override
  String importReasonCurrencyNamed(String currency, String account) {
    return 'This row is in $currency, but the account is in $account.';
  }

  @override
  String importReasonBadAmountIn(String currency) {
    return 'The amount isn\'t a number in $currency.';
  }

  @override
  String get importReasonAlreadyImportedReference =>
      'Already imported into this account (same bank reference).';

  @override
  String get importReasonInvalidDate =>
      'The date can\'t be used (for example, it\'s too far in the future). Correct it.';

  @override
  String get importReasonInvalidAmount =>
      'The amount can\'t be used. Correct it.';

  @override
  String get importReasonInvalidCategory =>
      'The category can\'t be used. Choose another one.';

  @override
  String get importReasonInvalidDescription =>
      'The description can\'t be used. Correct it.';

  @override
  String get importReasonInvalidReference => 'The reference can\'t be used.';

  @override
  String get importReasonInvalidRow =>
      'This row can\'t be imported as it is. Correct it or skip it.';

  @override
  String get importReasonRejected => 'Montra couldn\'t import this row.';

  @override
  String get importReasonReconciled =>
      'Matched with a transaction in the account.';

  @override
  String importReasonPossibleDuplicateWhy(String reasons) {
    return 'Looks like a transaction already in the account: $reasons.';
  }

  @override
  String importConfirmBodyCount(int count, String account) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rows will be added to $account.',
      one: '1 row will be added to $account.',
    );
    return '$_temp0 Possible duplicates and rows you skipped are left out. You can roll the import back later.';
  }

  @override
  String importConfirmCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Import $count rows',
      one: 'Import 1 row',
    );
    return '$_temp0';
  }

  @override
  String get importNothingToImport =>
      'No rows are marked to import. Mark the rows you want, or cancel the import.';

  @override
  String get importRowsToImportLabel => 'Will be imported';

  @override
  String get importFixDate => 'Correct the date';

  @override
  String get importFixAmount => 'Correct the amount';

  @override
  String get importFixDescription => 'Correct the description';

  @override
  String get reconReasonFarApart =>
      'Dates are more than a week apart (matched by hand)';

  @override
  String reconReasonFarApartDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Dates are $days days apart (matched by hand)',
      one: 'Dates are 1 day apart (matched by hand)',
    );
    return '$_temp0';
  }

  @override
  String budgetOwnAlertsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count alerts for this budget',
      one: '1 alert for this budget',
    );
    return '$_temp0';
  }

  @override
  String get lastReconciledBalanceLabel => 'Balance when last reconciled';

  @override
  String calendarMovedFrom(String date) {
    return 'Moved from $date';
  }

  @override
  String get analyticsCategoriesSpending => 'Spending';

  @override
  String get analyticsCategoriesIncome => 'Income';

  @override
  String analyticsNoIncome(String period) {
    return 'No income for $period.';
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
      other: '$count categories shown.',
      one: '1 category shown.',
    );
    return 'Most income came from $name: $amount, $share of the total. $_temp0';
  }

  @override
  String get analyticsCompareNoteCurrencies =>
      'Each currency is compared on its own; amounts in different currencies are never added together.';

  @override
  String analyticsCompareRowChange(String now, String then, String change) {
    return '$now now · $then before · $change';
  }

  @override
  String get analyticsCompareCountLabel => 'Transactions';

  @override
  String analyticsCompareCount(int now, int then) {
    return '$now now · $then before';
  }

  @override
  String analyticsPreviousWindow(String dates) {
    return 'Compared with $dates, the period of the same length just before.';
  }

  @override
  String get reconMatchByHand => 'Match by hand';

  @override
  String get reconMatchTotal => 'Amount kept';

  @override
  String get reconLineDuplicate => 'Looked like a duplicate, not imported';

  @override
  String get reconLineSkipped => 'Skipped on import';

  @override
  String get reconLineNotImported => 'Not imported';

  @override
  String get reconLineFailed => 'Couldn\'t be imported';

  @override
  String get reconLineMatched => 'Matched by hand';

  @override
  String get reconLineNoDescription => 'No description';

  @override
  String get reconLinesUnmatched => 'Not matched';

  @override
  String get reconLinesMatched => 'Matched by hand';

  @override
  String get reconLinesIntro =>
      'These statement lines weren\'t imported or matched. Choose a line, then the transactions in Montra it stands for. Their amounts must add up to the line.';

  @override
  String get reconLinesMatchedIntro =>
      'Lines you matched by hand. Tap one to undo its match.';

  @override
  String get reconLinesEmpty => 'Every statement line is imported or matched.';

  @override
  String get reconLinesMatchedEmpty =>
      'You haven\'t matched any lines by hand.';

  @override
  String get reconChooseTransactionsTitle => 'Choose the transactions';

  @override
  String reconChooseTransactionsIntro(String date, String account) {
    return 'Unreconciled transactions in $account going the same way as the statement line of $date. Choose one, or several that add up to it.';
  }

  @override
  String get reconStatementLineAmount => 'Statement line';

  @override
  String get reconNoUnreconciled =>
      'No unreconciled transactions go this way in this account.';

  @override
  String reconMatchChosen(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Match $count transactions',
      one: 'Match 1 transaction',
      zero: 'Choose transactions',
    );
    return '$_temp0';
  }

  @override
  String get reportFailedStorageUnavailable =>
      'File storage wasn\'t available, so the file couldn\'t be saved. Make it again in a while.';

  @override
  String get reportFailedGeneration =>
      'Making the report failed every time it was tried. Make it again, or narrow the period.';

  @override
  String reportWindowDays(String dates, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return '$dates ($_temp0)';
  }

  @override
  String get reportCurrentState => 'As things were when you asked for it';

  @override
  String get reportDeleteAction => 'Delete report';

  @override
  String get reportDeleteTitle => 'Delete this report?';

  @override
  String reportDeleteBody(String title) {
    return '\"$title\" and its file are deleted. Links you already shared stop working.';
  }

  @override
  String reportDeleteBodyRunning(String title) {
    return '\"$title\" is still being made. Making it stops and the report is deleted.';
  }

  @override
  String get reportDeleted => 'Report deleted.';

  @override
  String get scheduleEditTitle => 'Edit schedule';

  @override
  String get scheduleNotFound => 'This schedule doesn\'t exist any more.';

  @override
  String get scheduleNothingChanged =>
      'Nothing changed, so there was nothing to save.';

  @override
  String get scheduleSaved => 'Schedule saved.';

  @override
  String get scheduleTypeFixed =>
      'The kind of report can\'t change. Make a new schedule for another kind.';

  @override
  String get scheduleEditNote =>
      'A new cadence starts from the next week or month. Leave the title empty to use the usual name.';

  @override
  String get schedulePause => 'Pause';

  @override
  String get schedulePauseHelp => 'No reports are made until you resume it.';

  @override
  String get scheduleResume => 'Resume';

  @override
  String get scheduleResumeHelp =>
      'Starts again from the next week or month; missed periods aren\'t made.';

  @override
  String get schedulePaused => 'Schedule paused.';

  @override
  String get scheduleResumed => 'Schedule resumed.';

  @override
  String scheduleActionsLabel(String title) {
    return 'Options for $title';
  }

  @override
  String get friendsTitle => 'Friends';

  @override
  String get friendsTabFriends => 'Friends';

  @override
  String get friendsTabRequests => 'Requests';

  @override
  String friendsTabRequestsCount(int count) {
    return 'Requests ($count)';
  }

  @override
  String get friendsTabFind => 'Find someone';

  @override
  String get friendsEmptyTitle => 'No friends yet';

  @override
  String get friendsEmptyBody =>
      'Find people by their exact username and send them a friend request.';

  @override
  String get friendsBlockedAndMutedTitle => 'Blocked and muted';

  @override
  String get friendsBlockedTab => 'Blocked';

  @override
  String get friendsMutedTab => 'Muted';

  @override
  String get friendsBlockedEmptyTitle => 'You haven\'t blocked anyone';

  @override
  String get friendsBlockedHelp =>
      'People you block can\'t find you, add you or see you in Montra, and you won\'t see them. They aren\'t told.';

  @override
  String get friendsMutedEmptyTitle => 'You haven\'t muted anyone';

  @override
  String get friendBlockedLabel => 'Blocked';

  @override
  String get friendMutedLabel => 'Muted';

  @override
  String get friendConnectionSelf => 'This is you';

  @override
  String get friendConnectionFriend => 'Friend';

  @override
  String get friendConnectionRequestSent => 'Request sent';

  @override
  String get friendConnectionRequestReceived => 'Wants to be your friend';

  @override
  String get friendRequestsIncoming => 'Received';

  @override
  String get friendRequestsOutgoing => 'Sent by you';

  @override
  String get friendRequestsEmptyTitle => 'No requests waiting';

  @override
  String get friendRequestsEmptyBody =>
      'Friend requests you receive or send show up here until they are answered.';

  @override
  String friendRequestMessage(String message) {
    return '“$message”';
  }

  @override
  String get friendRequestAccept => 'Accept';

  @override
  String get friendRequestDecline => 'Decline';

  @override
  String get friendRequestCancel => 'Cancel request';

  @override
  String get friendRequestSend => 'Send friend request';

  @override
  String get friendRequestAcceptTheirs => 'Accept their request';

  @override
  String friendRequestSentDone(String name) {
    return 'Friend request sent to $name.';
  }

  @override
  String friendNowFriends(String name) {
    return 'You and $name are now friends.';
  }

  @override
  String get friendRequestDeclinedDone => 'Request declined.';

  @override
  String get friendRequestCancelledDone => 'Request cancelled.';

  @override
  String get friendFindIntro =>
      'Type the whole username of the person you are looking for. Partial names find nobody, and only people who turned on “Let people find me by username” can be found.';

  @override
  String get friendFindLabel => 'Username';

  @override
  String get friendFindHelp => 'For example: asha_r';

  @override
  String get friendFindTooShort =>
      'Enter the full username (at least 3 characters).';

  @override
  String get friendFindButton => 'Find';

  @override
  String friendFindNobody(String username) {
    return 'No one found with the username @$username. Check the spelling, or ask them whether they let people find them by username.';
  }

  @override
  String get friendFindDiscoveryNote =>
      'Want others to find you? Set a username and turn on “Let people find me by username” in your privacy settings.';

  @override
  String get friendMute => 'Mute';

  @override
  String get friendMuteHelp =>
      'Muted people stay connected, but you won\'t get notifications about what they do.';

  @override
  String get friendUnmute => 'Unmute';

  @override
  String get friendBlock => 'Block';

  @override
  String get friendBlockHelp =>
      'They can\'t find you, add you or see you, and you won\'t see them.';

  @override
  String get friendUnblock => 'Unblock';

  @override
  String get friendRemove => 'Remove friend';

  @override
  String friendBlockConfirmTitle(String name) {
    return 'Block $name?';
  }

  @override
  String get friendBlockConfirmBody =>
      'You\'ll no longer be friends and won\'t see each other in Montra. They aren\'t told. You can unblock them later from Blocked and muted.';

  @override
  String friendRemoveConfirmTitle(String name) {
    return 'Remove $name as a friend?';
  }

  @override
  String get friendRemoveConfirmBody =>
      'You can send a new friend request later. Groups and shared budgets or goals you are both in don\'t change.';

  @override
  String friendMutedDone(String name) {
    return '$name is muted.';
  }

  @override
  String friendUnmutedDone(String name) {
    return '$name is no longer muted.';
  }

  @override
  String friendBlockedDone(String name) {
    return '$name is blocked.';
  }

  @override
  String friendUnblockedDone(String name) {
    return '$name is unblocked.';
  }

  @override
  String friendRemovedDone(String name) {
    return '$name was removed from your friends.';
  }

  @override
  String get friendCodeAlreadyFriends => 'You are already friends.';

  @override
  String get friendCodeRequestPending =>
      'You already sent this person a friend request.';

  @override
  String get friendCodeRequestsClosed =>
      'This person is not accepting friend requests.';

  @override
  String get socialSettingsTitle => 'Privacy for friends';

  @override
  String get socialSettingsSaved => 'Privacy settings saved.';

  @override
  String get socialNothingChanged =>
      'Nothing changed, so there was nothing to save.';

  @override
  String get usernameSection => 'Your username';

  @override
  String get usernameLabel => 'Username';

  @override
  String get usernameRules =>
      '3 to 30 letters, digits, “_” or “.”. It is saved in lowercase. Leave it empty to remove your username.';

  @override
  String get usernameLengthRule => 'Use 3 to 30 characters.';

  @override
  String get usernameCharactersRule => 'Use only letters, digits, “_” and “.”.';

  @override
  String get usernameTaken => 'That username is taken. Try another one.';

  @override
  String get socialDiscoverySection => 'Who can find you';

  @override
  String get socialDiscoverableLabel => 'Let people find me by username';

  @override
  String get socialDiscoverableHelp =>
      'When this is on, someone who types your exact username can find you and send a friend request. Your friends can always add you to groups.';

  @override
  String get socialDiscoverableOffNote =>
      'This is off until you turn it on: nobody can find you by your username, even if they know it. You can still send requests and join groups with a link.';

  @override
  String get socialRequestsLabel => 'Who can send you friend requests';

  @override
  String get socialRequestsHelp =>
      'Others who find you can only ask; you decide whether to accept.';

  @override
  String get socialRequestsEveryone => 'Anyone';

  @override
  String get socialRequestsFriendsOfFriends => 'Friends of my friends';

  @override
  String get socialRequestsNobody => 'Nobody';

  @override
  String get groupsTitle => 'Groups';

  @override
  String get groupNew => 'New group';

  @override
  String get groupsShowArchived => 'Show archived groups';

  @override
  String get groupsEmptyTitle => 'No groups yet';

  @override
  String get groupsEmptyBody =>
      'Create a group to share expenses with your household, roommates, a trip or friends, or join one with a link someone sent you.';

  @override
  String groupTypeAndMembers(String type, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '1 member',
    );
    return '$type · $_temp0';
  }

  @override
  String get groupArchivedLabel => 'Archived';

  @override
  String get groupTypeHousehold => 'Household';

  @override
  String get groupTypeRoommates => 'Roommates';

  @override
  String get groupTypeTrip => 'Trip';

  @override
  String get groupTypeEvent => 'Event';

  @override
  String get groupTypeFriends => 'Friends';

  @override
  String get groupTypeCustom => 'Other';

  @override
  String get groupSplitEqual => 'Equally';

  @override
  String get groupSplitExact => 'Exact amounts';

  @override
  String get groupSplitPercentage => 'Percentages';

  @override
  String get groupSplitShares => 'Shares';

  @override
  String get groupSplitItemized => 'By item';

  @override
  String get groupRoleOwner => 'Owner';

  @override
  String get groupRoleAdmin => 'Admin';

  @override
  String get groupRoleMember => 'Member';

  @override
  String get groupNotifyAll => 'Everything';

  @override
  String get groupNotifyImportant => 'Only important things';

  @override
  String get groupNotifyNone => 'Nothing';

  @override
  String groupNetOwedToYou(String amount) {
    return 'You are owed $amount';
  }

  @override
  String groupNetYouOwe(String amount) {
    return 'You owe $amount';
  }

  @override
  String get groupNetSettled => 'Settled up';

  @override
  String groupMemberIsOwed(String amount) {
    return 'is owed $amount';
  }

  @override
  String groupMemberOwes(String amount) {
    return 'owes $amount';
  }

  @override
  String get groupInvitationsForYou => 'Invitations for you';

  @override
  String get groupInvitationReceived => 'You were invited to join';

  @override
  String groupInvitationFrom(String name) {
    return 'Invited by $name';
  }

  @override
  String get groupInvitationAccept => 'Join';

  @override
  String get groupInvitationDecline => 'Decline';

  @override
  String get groupInvitationDeclinedDone => 'Invitation declined.';

  @override
  String groupJoinedDone(String name) {
    return 'You joined $name.';
  }

  @override
  String get groupEditTitle => 'Edit group';

  @override
  String get groupNameLabel => 'Group name';

  @override
  String get groupNameRequired => 'Enter a name for the group.';

  @override
  String get groupTypeLabel => 'Kind of group';

  @override
  String get groupCurrencyLabel => 'Group currency';

  @override
  String get groupCurrencyDefault => 'Your main currency';

  @override
  String get groupCurrencyHelp =>
      'Balances are kept in this currency. It can’t change once the group has expenses or settlements.';

  @override
  String get groupSplitLabel => 'Usual way to split';

  @override
  String get groupSplitHelp =>
      'New expenses start with this; you can change it for each expense.';

  @override
  String get groupTripSection => 'Trip details';

  @override
  String get groupDestinationLabel => 'Destination';

  @override
  String get groupStartDateLabel => 'Starts';

  @override
  String get groupEndDateLabel => 'Ends';

  @override
  String get groupAboutSection => 'About';

  @override
  String get groupDescriptionLabel => 'Description (optional)';

  @override
  String get groupRulesLabel => 'House rules (optional)';

  @override
  String get groupRulesHelp =>
      'For example, how you split groceries or when you settle up.';

  @override
  String get groupTimezoneLabel => 'Time zone (optional)';

  @override
  String get groupTimezoneHelp =>
      'For example Asia/Kolkata. Left empty, your own time zone is used.';

  @override
  String get groupOptionsSection => 'Options';

  @override
  String get groupSimplifyLabel => 'Simplify debts';

  @override
  String get groupSimplifyHelp =>
      'Suggests fewer payments to settle up. Everyone ends up with the same balance.';

  @override
  String get groupAllowInvitesLabel => 'Members can invite people';

  @override
  String get groupAllowInvitesHelp =>
      'When off, only the owner and admins can invite.';

  @override
  String get groupRequireApprovalLabel =>
      'Admins approve people who join with a link';

  @override
  String get groupRequireApprovalHelp =>
      'Off by default. When on, opening an invitation link sends a request that an admin approves; people invited by username always join directly.';

  @override
  String get groupCreateButton => 'Create group';

  @override
  String groupCreatedDone(String name) {
    return 'Group $name created.';
  }

  @override
  String get groupSavedDone => 'Group saved.';

  @override
  String get groupNothingChanged =>
      'Nothing changed, so there was nothing to save.';

  @override
  String get groupJoinTitle => 'Join a group with a link';

  @override
  String get groupJoinIntro =>
      'Paste the invitation link someone sent you. You’ll see the group before you join.';

  @override
  String get groupJoinLinkLabel => 'Invitation link';

  @override
  String get groupJoinLinkInvalid =>
      'This doesn’t look like a Montra invitation link.';

  @override
  String get groupJoinCheckLink => 'Check the link';

  @override
  String get groupJoinLinkGone =>
      'This link can’t be used: it may have expired, been used up or been turned off. Ask for a new one.';

  @override
  String get groupMembersLabel => 'Members';

  @override
  String get groupInvitedByLabel => 'Invited by';

  @override
  String get groupInvitationExpiresLabel => 'Link valid until';

  @override
  String get groupJoinAlreadyMember =>
      'You are already a member of this group.';

  @override
  String groupJoinLinkNotActive(String status) {
    return 'This link can’t be used any more ($status). Ask for a new one.';
  }

  @override
  String get groupJoinNeedsApproval =>
      'An admin approves new members of this group. When you ask to join, they’ll be told, and you join once one of them approves.';

  @override
  String get groupJoinDirect =>
      'You’ll join right away. Members see your name and username in the group.';

  @override
  String get groupJoinButton => 'Join group';

  @override
  String get groupJoinAskToJoin => 'Ask to join';

  @override
  String get groupOpen => 'Open the group';

  @override
  String get groupJoinPendingTitle => 'Request sent';

  @override
  String groupJoinPendingBody(String group) {
    return 'The admins of $group will review your request. You’ll be notified when you join.';
  }

  @override
  String get groupJoinBackToGroups => 'Back to groups';

  @override
  String get groupSettingsTitle => 'Group settings';

  @override
  String get groupArchivedBanner =>
      'This group is archived. Its records stay, but nothing can change until the owner restores it.';

  @override
  String get groupBalanceTitle => 'Balances';

  @override
  String groupFormerMember(String name) {
    return '$name (former member)';
  }

  @override
  String groupDisputedExpenses(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count expenses are disputed and may change.',
      one: '1 expense is disputed and may change.',
    );
    return '$_temp0';
  }

  @override
  String get groupBalancesUnavailable =>
      'Balances couldn’t be loaded. Pull down to try again.';

  @override
  String get groupSettleUp => 'Settle up';

  @override
  String get groupMoneySection => 'Money';

  @override
  String get groupLinkExpenses => 'Expenses';

  @override
  String get groupLinkBalances => 'Balances and suggested payments';

  @override
  String get groupLinkSettlements => 'Payments between members';

  @override
  String get groupLinkRecurring => 'Recurring shared expenses';

  @override
  String get groupLinkReports => 'Reports and export';

  @override
  String groupMemberYou(String name) {
    return '$name (you)';
  }

  @override
  String get groupMemberLeft => 'Left';

  @override
  String get groupMemberRemoved => 'Removed';

  @override
  String get groupActivityTitle => 'Activity';

  @override
  String get groupActivityEmpty => 'Nothing has happened in this group yet.';

  @override
  String get groupActivityUnavailable => 'Activity couldn’t be loaded.';

  @override
  String get groupActivitySomeone => 'Someone';

  @override
  String groupActivityCreated(String actor, String type) {
    return '$actor created this $type group.';
  }

  @override
  String groupActivityUpdated(String actor) {
    return '$actor changed the group details.';
  }

  @override
  String groupActivityArchived(String actor) {
    return '$actor archived the group.';
  }

  @override
  String groupActivityRestored(String actor) {
    return '$actor restored the group.';
  }

  @override
  String groupActivityDeleted(String actor) {
    return '$actor deleted the group.';
  }

  @override
  String groupActivityInvited(String actor) {
    return '$actor invited someone by username.';
  }

  @override
  String groupActivityLinkCreated(String actor) {
    return '$actor created an invitation link.';
  }

  @override
  String groupActivityInvitationRevoked(String actor) {
    return '$actor turned off an invitation.';
  }

  @override
  String groupActivityJoinRequested(String actor) {
    return '$actor asked to join.';
  }

  @override
  String groupActivityJoined(String name) {
    return '$name joined the group.';
  }

  @override
  String groupActivityJoinedApproved(String name) {
    return '$name joined after an admin approved.';
  }

  @override
  String groupActivityLeft(String name) {
    return '$name left the group.';
  }

  @override
  String groupActivityRemoved(String actor, String name) {
    return '$actor removed $name.';
  }

  @override
  String groupActivityRoleChanged(String actor, String name, String role) {
    return '$actor made $name $role.';
  }

  @override
  String groupActivityOwnershipTransferred(String actor, String name) {
    return '$actor made $name the owner.';
  }

  @override
  String groupActivityExpenseAdded(String actor, String name) {
    return '$actor added the expense “$name”.';
  }

  @override
  String groupActivityExpenseUpdated(String actor, String name) {
    return '$actor changed the expense “$name”.';
  }

  @override
  String groupActivityExpenseDeleted(String actor, String name) {
    return '$actor deleted the expense “$name”.';
  }

  @override
  String groupActivityExpenseCommented(String actor, String name) {
    return '$actor commented on “$name”.';
  }

  @override
  String groupActivityExpenseDisputed(String actor, String name) {
    return '$actor raised a question about “$name”.';
  }

  @override
  String groupActivityDisputeResolved(String actor, String name) {
    return '$actor resolved the question about “$name”.';
  }

  @override
  String groupActivityDisputeWithdrawn(String actor, String name) {
    return '$actor withdrew the question about “$name”.';
  }

  @override
  String groupActivitySettlementDisputeResolved(String actor) {
    return '$actor resolved the question about a payment.';
  }

  @override
  String groupActivitySettlementDisputeWithdrawn(String actor) {
    return '$actor withdrew the question about a payment.';
  }

  @override
  String groupActivitySettlementProposed(String actor) {
    return '$actor proposed a payment.';
  }

  @override
  String groupActivitySettlementReported(String actor) {
    return '$actor recorded a payment.';
  }

  @override
  String groupActivitySettlementConfirmed(String actor) {
    return '$actor confirmed a payment.';
  }

  @override
  String groupActivitySettlementDisputed(String actor) {
    return '$actor questioned a payment.';
  }

  @override
  String groupActivitySettlementVoided(String actor) {
    return '$actor cancelled a payment record.';
  }

  @override
  String groupActivitySettlementCorrected(String actor) {
    return '$actor corrected a payment.';
  }

  @override
  String groupActivityRecurringCreated(String actor, String name) {
    return '$actor set up the recurring expense “$name”.';
  }

  @override
  String groupActivityRecurringUpdated(String actor, String name) {
    return '$actor changed the recurring expense “$name”.';
  }

  @override
  String groupActivityRecurringPaused(String actor, String name) {
    return '$actor paused the recurring expense “$name”.';
  }

  @override
  String groupActivityRecurringResumed(String actor, String name) {
    return '$actor resumed the recurring expense “$name”.';
  }

  @override
  String groupActivityRecurringStopped(String actor, String name) {
    return '$actor stopped the recurring expense “$name”.';
  }

  @override
  String groupActivityRecurringSkipped(String actor, String name) {
    return '$actor skipped one “$name”.';
  }

  @override
  String groupActivityOther(String actor) {
    return '$actor made a change.';
  }

  @override
  String get groupDetailsSection => 'Group details';

  @override
  String get groupAddMember => 'Add a member';

  @override
  String get groupAddFromFriends => 'From your friends';

  @override
  String get groupAddFromFriendsHelp =>
      'Friends can be added even if they can’t be found by username.';

  @override
  String get groupAddByUsername => 'By username';

  @override
  String get groupAddByUsernameHelp =>
      'Only people who let others find them by username can be invited this way.';

  @override
  String get groupInvite => 'Invite';

  @override
  String groupInvitedDone(String name) {
    return 'Invitation sent to $name. They join when they accept.';
  }

  @override
  String get groupMakeAdmin => 'Make admin';

  @override
  String get groupAdminHelp =>
      'Admins can change the group, manage members and approve requests.';

  @override
  String get groupMakeMember => 'Make member';

  @override
  String groupRoleChangedDone(String name, String role) {
    return '$name is now $role.';
  }

  @override
  String get groupTransferOwnership => 'Make owner';

  @override
  String groupTransferConfirmTitle(String name) {
    return 'Make $name the owner?';
  }

  @override
  String groupTransferConfirmBody(String name) {
    return '$name will own the group and can archive or delete it. You stay in the group as an admin.';
  }

  @override
  String groupTransferredDone(String name) {
    return '$name is now the owner.';
  }

  @override
  String get groupRemoveMember => 'Remove from group';

  @override
  String groupRemoveConfirmTitle(String name) {
    return 'Remove $name from the group?';
  }

  @override
  String groupRemoveConfirmBody(String name) {
    return '$name loses access at once. Their expenses, shares and payments stay in the records. If they still owe or are owed money, that balance keeps counting in balances, suggested payments and reports, anyone can record a payment with them, and an admin can confirm a payment to them.';
  }

  @override
  String groupRemovedDone(String name) {
    return '$name was removed from the group.';
  }

  @override
  String get groupRemovalPolicy =>
      'Removing a member keeps their records. An open balance stays in the group until it is settled.';

  @override
  String get groupInvitationsTitle => 'Invitations';

  @override
  String get groupCreateLink => 'Create an invitation link';

  @override
  String get groupCreateLinkHelp =>
      'Anyone with the link can see the group’s name and ask to join.';

  @override
  String get groupInvitationsUnavailable => 'Invitations couldn’t be loaded.';

  @override
  String get groupInvitationsEmpty => 'No invitations yet.';

  @override
  String groupInvitationLinkTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Invitation link · used $count times',
      one: 'Invitation link · used once',
      zero: 'Invitation link · not used yet',
    );
    return '$_temp0';
  }

  @override
  String groupInvitationForPerson(String name) {
    return 'Invitation for $name';
  }

  @override
  String groupInvitationCreated(String name, String date) {
    return 'By $name on $date';
  }

  @override
  String get groupInvitationStatusActive => 'Active';

  @override
  String get groupInvitationStatusAccepted => 'Accepted';

  @override
  String get groupInvitationStatusDeclined => 'Declined';

  @override
  String get groupInvitationStatusRevoked => 'Turned off';

  @override
  String get groupInvitationStatusExpired => 'Expired';

  @override
  String get groupInvitationRevoke => 'Turn off';

  @override
  String get groupInvitationRevokeTitle => 'Turn off this invitation?';

  @override
  String get groupInvitationRevokeBody =>
      'It can’t be used to join any more. People who already joined stay in the group.';

  @override
  String get groupInvitationRevokedDone => 'Invitation turned off.';

  @override
  String get groupLinkCreatedDone => 'Invitation link created.';

  @override
  String get groupLinkExpiresLabel => 'Valid for';

  @override
  String groupLinkDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get groupLinkUsesLabel => 'Can be used';

  @override
  String groupLinkUses(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count times',
      one: 'Once',
    );
    return '$_temp0';
  }

  @override
  String get groupLinkUsesAny => 'Any number of times';

  @override
  String get groupLinkReadyTitle => 'Share your invitation link';

  @override
  String get groupLinkShownOnce =>
      'This link is shown only now. Copy or share it before you close this window. You can turn it off any time.';

  @override
  String groupLinkShareText(String group, String link) {
    return 'Join $group on Montra: $link';
  }

  @override
  String get groupJoinRequestsTitle => 'Requests to join';

  @override
  String get groupJoinRequestsOnHelp =>
      'People who open an invitation link wait here until an admin approves them.';

  @override
  String get groupJoinRequestsOffHelp =>
      'Approval is off: people with an invitation link join directly. Turn it on in the group details.';

  @override
  String get groupJoinRequestsUnavailable => 'Requests couldn’t be loaded.';

  @override
  String get groupJoinRequestsEmpty => 'No one is waiting.';

  @override
  String get groupJoinRequestApprove => 'Approve';

  @override
  String get groupJoinRequestDecline => 'Decline';

  @override
  String groupJoinRequestApprovedDone(String name) {
    return '$name joined the group.';
  }

  @override
  String groupJoinRequestDeclinedDone(String name) {
    return 'Request from $name declined.';
  }

  @override
  String get groupJoinRequestStatusPending => 'Waiting';

  @override
  String get groupJoinRequestStatusApproved => 'Approved';

  @override
  String get groupJoinRequestStatusDeclined => 'Declined';

  @override
  String get groupJoinRequestStatusCancelled => 'Cancelled';

  @override
  String get groupYourNotifications => 'Your notifications from this group';

  @override
  String get groupNotificationsSaved => 'Notification choice saved.';

  @override
  String get groupActionsSection => 'Group actions';

  @override
  String get groupArchive => 'Archive group';

  @override
  String get groupArchiveHelp =>
      'Archiving keeps every record and pauses recurring expenses. Nothing can change until you restore it.';

  @override
  String groupArchiveConfirmTitle(String name) {
    return 'Archive $name?';
  }

  @override
  String get groupArchivedDone => 'Group archived.';

  @override
  String get groupRestore => 'Restore group';

  @override
  String get groupRestoredDone => 'Group restored.';

  @override
  String get groupLeave => 'Leave group';

  @override
  String get groupLeaveHelp =>
      'You can leave once your balance in the group is settled. Your past expenses and payments stay in the group’s records.';

  @override
  String groupLeaveConfirmTitle(String name) {
    return 'Leave $name?';
  }

  @override
  String groupLeftDone(String name) {
    return 'You left $name.';
  }

  @override
  String get groupOwnerLeaveNote =>
      'As the owner, make someone else the owner (under Members) before you leave.';

  @override
  String get groupDelete => 'Delete group';

  @override
  String get groupDeleteHelp =>
      'Everyone’s balances must be settled first. Deleting removes the group for every member and turns off its invitations. This can’t be undone.';

  @override
  String groupDeleteConfirmTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String groupDeletedDone(String name) {
    return '$name was deleted.';
  }

  @override
  String get groupCodeAlreadyMember =>
      'This person is already a member of the group.';

  @override
  String get groupCodeJoinRequestPending =>
      'Your request to join is already waiting for the admins.';

  @override
  String groupCodeInvitationUsed(String status) {
    return 'This invitation was already $status.';
  }

  @override
  String get groupCodeInvitationInactive =>
      'This invitation is no longer active.';

  @override
  String get groupCodeArchived =>
      'This group is archived. The owner can restore it to make changes.';

  @override
  String get groupCodeNotArchived => 'The group is not archived.';

  @override
  String get groupCodeBalanceOpen =>
      'Settle your balance in the group before you leave.';

  @override
  String get groupCodeBalancesOpen =>
      'Everyone’s balances must be settled before the group can be deleted.';

  @override
  String get groupCodeTransferFirst =>
      'Make someone else the owner before you leave.';

  @override
  String get groupCodeCurrencyLocked =>
      'The group currency can’t change once the group has expenses, payments or recurring expenses.';

  @override
  String get togetherIntro =>
      'Share expenses with the people around you, learn from communities and take on challenges. Everything here is free.';

  @override
  String get togetherFriendsSubtitle =>
      'Find people by username and manage requests';

  @override
  String togetherFriendRequests(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count friend requests are waiting',
      one: '1 friend request is waiting',
    );
    return '$_temp0';
  }

  @override
  String get togetherGroupsSubtitle =>
      'Split expenses with a household, trip or friends';

  @override
  String togetherGroupsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count groups',
      one: '1 group',
    );
    return '$_temp0';
  }

  @override
  String togetherGroupInvitations(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count group invitations for you',
      one: '1 group invitation for you',
    );
    return '$_temp0';
  }

  @override
  String get togetherCommunities => 'Communities';

  @override
  String get togetherCommunitiesSubtitle => 'Discuss money topics with others';

  @override
  String get togetherChallenges => 'Challenges';

  @override
  String get togetherChallengesSubtitle => 'Build habits, alone or together';

  @override
  String get togetherJoinSection => 'Got an invitation link?';

  @override
  String get togetherJoinGroupSubtitle => 'Paste a group invitation link';

  @override
  String get togetherJoinCommunity => 'Join a community with a link';

  @override
  String get togetherJoinCommunitySubtitle =>
      'Paste a community invitation link';

  @override
  String get communityVisibilityPublic => 'Public';

  @override
  String get communityVisibilityPrivate => 'Private';

  @override
  String get communityVisibilityInviteOnly => 'Invitation only';

  @override
  String get communityVisibilityPublicHelp => 'Anyone can find it and join.';

  @override
  String get communityVisibilityPrivateHelp =>
      'Anyone can find it; moderators approve who joins.';

  @override
  String get communityVisibilityInviteOnlyHelp =>
      'Not listed; people join with an invitation.';

  @override
  String get communityRoleOwner => 'Owner';

  @override
  String get communityRoleModerator => 'Moderator';

  @override
  String get communityRoleMember => 'Member';

  @override
  String get communityMemberStatusActive => 'Member';

  @override
  String get communityMemberStatusPending => 'Waiting for approval';

  @override
  String get communityMemberStatusBanned => 'Banned';

  @override
  String get communityMemberStatusLeft => 'Left';

  @override
  String get postKindDiscussion => 'Discussion';

  @override
  String get postKindQuestion => 'Question';

  @override
  String get postKindResource => 'Resource link';

  @override
  String get postKindPoll => 'Poll';

  @override
  String get postKindChallengeUpdate => 'Challenge update';

  @override
  String get postLabelPersonalExperience => 'Personal experience';

  @override
  String get postLabelVerifiedGuidance => 'Verified guidance';

  @override
  String get postLabelQuestion => 'Question';

  @override
  String get postLabelResource => 'Resource';

  @override
  String get reactionLike => 'Like';

  @override
  String get reactionHelpful => 'Helpful';

  @override
  String get reactionInsightful => 'Insightful';

  @override
  String get reactionSupport => 'Support';

  @override
  String get contentReportReasonSpam => 'Spam';

  @override
  String get contentReportReasonAbuse => 'Abuse';

  @override
  String get contentReportReasonHarassment => 'Harassment';

  @override
  String get contentReportReasonScam => 'Scam or fraud';

  @override
  String get contentReportReasonImpersonation =>
      'Pretending to be someone else';

  @override
  String get contentReportReasonMisinformation => 'False or misleading';

  @override
  String get contentReportReasonPrivacy => 'Shares private information';

  @override
  String get contentReportReasonOther => 'Something else';

  @override
  String get communityErrorAccountRestricted =>
      'Your account can\'t take part in communities right now.';

  @override
  String get communityErrorAlreadyDeleted => 'This was already deleted.';

  @override
  String get communityErrorCommentLocked =>
      'This comment can\'t be changed any more.';

  @override
  String get communityErrorCommentsClosed =>
      'Comments are closed on this post.';

  @override
  String get communityErrorSuspended =>
      'This community is suspended. Only Montra staff can restore it.';

  @override
  String get communityErrorContentUnavailable =>
      'This isn\'t available any more.';

  @override
  String get communityErrorInvitationOnly =>
      'This community is invitation only. Ask a moderator for an invitation.';

  @override
  String get communityErrorJoinFirst => 'Join the community to take part.';

  @override
  String get communityErrorNewAccountLinks =>
      'New accounts can share links after their first day.';

  @override
  String get communityErrorNotAcceptingMembers =>
      'This community isn\'t accepting new members.';

  @override
  String get communityErrorNotAcceptingPosts =>
      'This community isn\'t accepting new posts.';

  @override
  String get communityErrorOwnContent =>
      'Ask another moderator to act on your own content or account.';

  @override
  String get communityErrorOwnerProtected =>
      'The owner can\'t be banned from their own community.';

  @override
  String get communityErrorPollClosed => 'This poll is closed.';

  @override
  String get communityErrorPostLocked =>
      'This post can\'t be changed any more.';

  @override
  String communityErrorPostingRestrictedUntil(String until) {
    return 'A moderator paused your posting here until $until.';
  }

  @override
  String get communityErrorPostingRestricted =>
      'A moderator paused your posting here for now.';

  @override
  String get communityErrorTransferOwnershipFirst =>
      'Transfer ownership before leaving.';

  @override
  String get communityErrorAlreadyMember => 'You\'re already a member.';

  @override
  String get communityErrorInvitationUsed =>
      'This invitation was already answered.';

  @override
  String get communityErrorInvitationInactive =>
      'This invitation is no longer active.';

  @override
  String get challengeErrorCancelled => 'This challenge was cancelled.';

  @override
  String get challengeErrorInactive => 'This challenge is no longer active.';

  @override
  String get challengeErrorNotOpen => 'This challenge isn\'t open.';

  @override
  String get challengeErrorJoinFirst => 'Join the challenge first.';

  @override
  String get challengeErrorLeaderboardOptIn =>
      'The leaderboard is shared both ways: share your progress and choose to appear on it to see it.';

  @override
  String get challengeErrorNoLeaderboard =>
      'This challenge has no leaderboard.';

  @override
  String get challengeTypeNoSpend => 'No-spend';

  @override
  String get challengeTypeSavingsStreak => 'Savings streak';

  @override
  String get challengeTypeGroceryBudget => 'Grocery budget';

  @override
  String get challengeTypeMealPlanning => 'Meal planning';

  @override
  String get challengeTypeTravelSavings => 'Travel savings';

  @override
  String get challengeTypeCustom => 'Your own';

  @override
  String get challengeMetricDays => 'Days checked in';

  @override
  String get challengeMetricStreak => 'Longest streak';

  @override
  String get challengeMetricMilestones => 'Total check-ins';

  @override
  String get challengeMetricPercent => 'Your own percentage';

  @override
  String get challengeMetricDaysHelp => 'Each day you check in as done counts.';

  @override
  String get challengeMetricStreakHelp =>
      'Your longest run of days in a row counts.';

  @override
  String get challengeMetricMilestonesHelp =>
      'Every check-in adds up, with the count you enter.';

  @override
  String get challengeMetricPercentHelp =>
      'You report how far you are, from 0 to 100 %.';

  @override
  String challengeTargetDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String challengeTargetStreak(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days in a row',
      one: '1 day in a row',
    );
    return '$_temp0';
  }

  @override
  String challengeTargetCheckIns(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count check-ins',
      one: '1 check-in',
    );
    return '$_temp0';
  }

  @override
  String challengeTargetPercent(int count) {
    return '$count %';
  }

  @override
  String get challengeStatusDraft => 'Draft';

  @override
  String get challengeStatusActive => 'Active';

  @override
  String get challengeStatusEnded => 'Ended';

  @override
  String get challengeStatusCompleted => 'Completed';

  @override
  String get challengeStatusCancelled => 'Cancelled';

  @override
  String get challengeScopePrivate => 'Just you';

  @override
  String get challengeScopeGroup => 'A group';

  @override
  String get challengeScopeCommunity => 'A community';

  @override
  String get challengeScopePublic => 'Everyone';

  @override
  String get challengeMilestoneHalfway => 'Halfway there';

  @override
  String get challengeMilestoneDone => 'Target reached';

  @override
  String challengeMilestonePercent(int percent) {
    return '$percent % of the target';
  }

  @override
  String get moderationErrorOtherModerator =>
      'Another moderator must review an appeal against your own action.';

  @override
  String get moderationErrorAppealWindowPassed =>
      'Appeals can be made within 30 days of the decision.';

  @override
  String get moderationErrorNotAppealable =>
      'This decision can\'t be appealed.';

  @override
  String get moderationActionHide => 'Hidden';

  @override
  String get moderationActionRemove => 'Removed';

  @override
  String get moderationActionRestore => 'Restored';

  @override
  String get moderationActionPin => 'Pinned';

  @override
  String get moderationActionUnpin => 'Unpinned';

  @override
  String get moderationActionLock => 'Locked';

  @override
  String get moderationActionUnlock => 'Unlocked';

  @override
  String get moderationActionWarn => 'Warning';

  @override
  String get moderationActionRestrict => 'Posting paused';

  @override
  String get moderationActionBan => 'Banned';

  @override
  String get moderationActionUnban => 'Ban lifted';

  @override
  String get moderationActionDismissReport => 'Report dismissed';

  @override
  String get moderationActionEscalate => 'Sent to Montra staff';

  @override
  String get moderationActionSuspend => 'Suspended';

  @override
  String get moderationActionUnsuspend => 'Suspension lifted';

  @override
  String get moderationTargetPost => 'Post';

  @override
  String get moderationTargetComment => 'Comment';

  @override
  String get moderationTargetMember => 'Membership';

  @override
  String get moderationTargetProfile => 'Profile';

  @override
  String get moderationTargetGroup => 'Group';

  @override
  String get moderationTargetCommunity => 'Community';

  @override
  String get appealStatusOpen => 'Appeal under review';

  @override
  String get appealStatusUpheld => 'Decision stands';

  @override
  String get appealStatusOverturned => 'Decision reversed';

  @override
  String get appealStatusOpenHelp =>
      'A moderator who didn\'t make the decision will review your appeal.';

  @override
  String get appealStatusUpheldHelp =>
      'Your appeal was reviewed and the decision stands.';

  @override
  String get appealStatusOverturnedHelp =>
      'Your appeal was accepted and the decision was reversed.';

  @override
  String get contentReportStatusOpen => 'Waiting for review';

  @override
  String get contentReportStatusUnderReview => 'Being reviewed';

  @override
  String get contentReportStatusActioned => 'Action taken';

  @override
  String get contentReportStatusDismissed => 'No action needed';

  @override
  String get contentReportStatusEscalated => 'Sent to Montra staff';

  @override
  String get contentReportStatusOpenHelp =>
      'Moderators will look at it. Thank you for helping keep things kind.';

  @override
  String get contentReportStatusActionedHelp =>
      'Moderators acted on what you reported.';

  @override
  String get contentReportStatusDismissedHelp =>
      'Moderators looked at it and found it within the rules.';

  @override
  String get contentReportStatusEscalatedHelp =>
      'Moderators passed it to Montra staff to review.';

  @override
  String get communityEdited => 'edited';

  @override
  String reactionSemantics(String reaction, int count) {
    return '$reaction, $count';
  }

  @override
  String get pollVoted => 'Your vote is saved.';

  @override
  String pollTotalVotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count votes',
      one: '1 vote',
      zero: 'No votes yet',
    );
    return '$_temp0';
  }

  @override
  String get pollChooseSeveral => 'Choose one or more';

  @override
  String get pollClosed => 'Closed';

  @override
  String pollClosesAt(String date) {
    return 'Closes $date';
  }

  @override
  String get pollVote => 'Vote';

  @override
  String get pollChangeVote => 'Change my vote';

  @override
  String get pollPrivacyNote =>
      'Only the totals are shown; nobody sees who voted for what.';

  @override
  String pollOptionResult(int votes, int percent) {
    String _temp0 = intl.Intl.pluralLogic(
      votes,
      locale: localeName,
      other: '$votes votes',
      one: '1 vote',
    );
    return '$_temp0 · $percent %';
  }

  @override
  String pollYourChoice(String option) {
    return '$option (your vote)';
  }

  @override
  String get communityLinkNotOpened =>
      'This link can\'t be opened. Only web links (https) are opened.';

  @override
  String get contentReportSent =>
      'Thank you. Moderators will review your report.';

  @override
  String get contentReportAlreadySent =>
      'You already reported this. Moderators will review it.';

  @override
  String get contentReportTitle => 'Report';

  @override
  String get contentReportIntro =>
      'Tell moderators what\'s wrong. The person you report isn\'t told who reported them.';

  @override
  String get contentReportDetailsLabel => 'More details (optional)';

  @override
  String get contentReportDetailsHelp =>
      'Don\'t include card numbers, PINs or passwords.';

  @override
  String get contentReportSend => 'Send report';

  @override
  String get moderationDoHide => 'Hide';

  @override
  String get moderationDoRemove => 'Remove';

  @override
  String get moderationDoRestore => 'Restore';

  @override
  String get moderationDoPin => 'Pin to the top';

  @override
  String get moderationDoUnpin => 'Unpin';

  @override
  String get moderationDoLock => 'Lock comments';

  @override
  String get moderationDoUnlock => 'Unlock comments';

  @override
  String get moderationDoWarn => 'Send a warning';

  @override
  String get moderationDoRestrict => 'Pause posting';

  @override
  String get moderationDoBan => 'Ban from the community';

  @override
  String get moderationDoUnban => 'Lift the ban';

  @override
  String get moderationDoDismiss => 'Dismiss the report';

  @override
  String get moderationDoEscalate => 'Send to Montra staff';

  @override
  String get moderationChooseAction => 'Choose an action';

  @override
  String get moderationDone =>
      'Done. The action is recorded in the moderation log.';

  @override
  String get moderationReasonLabel => 'Reason';

  @override
  String get moderationNoteLabel => 'Note (optional)';

  @override
  String get moderationReasonHelp =>
      'The person affected sees this reason and can appeal within 30 days.';

  @override
  String get moderationDurationLabel => 'For how long';

  @override
  String moderationDuration(String span) {
    String _temp0 = intl.Intl.selectLogic(span, {
      'h1': '1 hour',
      'd1': '1 day',
      'd3': '3 days',
      'w1': '1 week',
      'd30': '30 days',
      'other': '$span',
    });
    return '$_temp0';
  }

  @override
  String get communitiesTitle => 'Communities';

  @override
  String get communityJoinWithLink => 'Join with a link';

  @override
  String get communitiesTabDiscover => 'Discover';

  @override
  String get communitiesTabYours => 'Yours';

  @override
  String get communitiesTabInvitations => 'Invitations';

  @override
  String get communityCreate => 'Start a community';

  @override
  String get communitiesSearchLabel => 'Search communities';

  @override
  String get communitiesEmptyTitle => 'No communities to show yet';

  @override
  String communitiesNoMatches(String query) {
    return 'No communities match “$query”.';
  }

  @override
  String get communitiesEmptyBody =>
      'Communities are places to share money tips and ask questions. You can start one yourself.';

  @override
  String get communitiesYoursEmptyTitle =>
      'You haven\'t joined a community yet';

  @override
  String get communitiesYoursEmptyBody =>
      'Find one under Discover, or join with an invitation link.';

  @override
  String communityJoinedDone(String name) {
    return 'You joined $name.';
  }

  @override
  String get communityInvitationDeclineTitle => 'Decline this invitation?';

  @override
  String communityInvitationDeclineBody(String name) {
    return 'You won\'t join $name. Someone can invite you again later.';
  }

  @override
  String get communityInvitationDecline => 'Decline';

  @override
  String get communityInvitationDeclined => 'Invitation declined.';

  @override
  String get communityUnnamed => 'A community';

  @override
  String get communityInvitationsEmptyTitle => 'No invitations';

  @override
  String get communityInvitationsEmptyBody =>
      'When someone invites you to a community by your username, it shows up here.';

  @override
  String communityInvitedBy(String name) {
    return 'Invited by $name';
  }

  @override
  String communityInvitationExpires(String date) {
    return 'Valid until $date';
  }

  @override
  String get communityInvitationAccept => 'Join';

  @override
  String communityMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '1 member',
    );
    return '$_temp0';
  }

  @override
  String get communityStatusArchived => 'Archived';

  @override
  String get communityStatusSuspended => 'Suspended';

  @override
  String get communityInvitationStatusActive => 'Active';

  @override
  String get communityInvitationStatusUsed => 'Used';

  @override
  String get communityInvitationStatusDeclined => 'Declined';

  @override
  String get communityInvitationStatusRevoked => 'Revoked';

  @override
  String get communityInvitationStatusExpired => 'Expired';

  @override
  String get communityCreated => 'Community created. You are its owner.';

  @override
  String get communityCreateTitle => 'New community';

  @override
  String get communityCreateIntro =>
      'Communities are free. Keep them kind: posts are plain text, and members can report anything unkind.';

  @override
  String get communityNameLabel => 'Name';

  @override
  String get communitySlugLabel => 'URL name (optional)';

  @override
  String get communitySlugHelp =>
      '3–60 lowercase letters, digits or dashes. It can\'t change later; without one, it comes from the name.';

  @override
  String get communitySlugInvalid =>
      'Use 3–60 lowercase letters, digits or dashes.';

  @override
  String get communityDescriptionLabel => 'What it is about (optional)';

  @override
  String get communityRulesLabel => 'Community rules (optional)';

  @override
  String get communityRulesHelp => 'Members see these rules before they post.';

  @override
  String get communityTopicsLabel => 'Topics (optional)';

  @override
  String get communityTopicsHelp =>
      'Separate topics with commas, for example: saving, budgeting';

  @override
  String get communityVisibilityLabel => 'Who can join';

  @override
  String get communityJoinLinkInvalid =>
      'This isn\'t a community invitation link or code.';

  @override
  String get communityJoinTitle => 'Join a community';

  @override
  String get communityJoinIntro =>
      'Paste the invitation link or code you received. You\'ll see which community it is before joining.';

  @override
  String get communityJoinLinkLabel => 'Invitation link or code';

  @override
  String get communityJoinCheck => 'Check the invitation';

  @override
  String get communityJoinFailedTitle => 'Couldn\'t use this invitation';

  @override
  String get communityJoinLinkGone =>
      'This invitation no longer works: it was used, revoked or has expired. Ask for a new one.';

  @override
  String get communityOpen => 'Open the community';

  @override
  String communityJoinLinkNotActive(String status) {
    return 'This invitation can\'t be used: $status.';
  }

  @override
  String get communityJoinDirectly => 'This invitation lets you join directly.';

  @override
  String get communityJoin => 'Join';

  @override
  String get postNew => 'New post';

  @override
  String communityLeaveTitle(String name) {
    return 'Leave $name?';
  }

  @override
  String get communityLeaveBody =>
      'Your posts and comments stay. You can join again later if the community allows it.';

  @override
  String get communityLeave => 'Leave community';

  @override
  String get communityLeftDone => 'You left the community.';

  @override
  String get communityMembersTitle => 'Members';

  @override
  String get communitySettingsTitle => 'Community settings';

  @override
  String get communityModerationTitle => 'Moderation';

  @override
  String get communityStartChallenge => 'Start a challenge here';

  @override
  String get communityReport => 'Report community';

  @override
  String get communityJoinRequested =>
      'Request sent. Moderators will review it.';

  @override
  String get communityFeedMembersOnly =>
      'Only members see the posts in this community.';

  @override
  String get communityFeedEmptyTitle => 'No posts yet';

  @override
  String communityFeedNoMatches(String query) {
    return 'No posts match “$query”.';
  }

  @override
  String get communityFeedEmptyBody =>
      'Start the conversation with a question or a tip.';

  @override
  String get communityStaffModerates => 'Montra staff';

  @override
  String communityTopicsLine(String topics) {
    return 'Topics: $topics';
  }

  @override
  String get communityRulesTitle => 'Community rules';

  @override
  String get communityArchivedNote =>
      'This community is archived. You can read it, but nothing new can be posted.';

  @override
  String get communityPendingNote =>
      'Your request to join is waiting for a moderator.';

  @override
  String get communityBannedNote => 'You can\'t take part in this community.';

  @override
  String get communityAskToJoinHelp =>
      'Moderators approve who joins this community.';

  @override
  String get communityAskToJoin => 'Ask to join';

  @override
  String get communityFeedTitle => 'Posts';

  @override
  String get communityFeedSortNew => 'New';

  @override
  String get communityFeedSortTop => 'Top';

  @override
  String get communityFeedSortActive => 'Active';

  @override
  String get communityFeedSearchLabel => 'Search posts';

  @override
  String postCommentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count comments',
      one: '1 comment',
      zero: 'No comments',
    );
    return '$_temp0';
  }

  @override
  String get postPinned => 'Pinned';

  @override
  String get postLocked => 'Comments closed';

  @override
  String get postHidden => 'Hidden by a moderator';

  @override
  String get postRemoved => 'Removed by a moderator';

  @override
  String get postDeleted => 'Deleted';

  @override
  String get postEditTitle => 'Edit post';

  @override
  String get postSaved => 'Post saved.';

  @override
  String get postPublished => 'Post published.';

  @override
  String get postComposerIntro =>
      'Posts are plain text. Never share card numbers, PINs, one-time codes or passwords.';

  @override
  String get postKindHeading => 'Kind of post';

  @override
  String get postLabelHeading => 'Label';

  @override
  String get postTitleLabel => 'Title';

  @override
  String get postBodyLabel => 'Text (optional)';

  @override
  String get postBodyHelp => 'Shown exactly as you type it.';

  @override
  String get postLinkLabel => 'Link';

  @override
  String get postLinkHelp => 'A public web link starting with https://';

  @override
  String get postPollFixed =>
      'A poll\'s question and options can\'t change after posting.';

  @override
  String get postPublish => 'Publish';

  @override
  String get postPollTitle => 'Poll';

  @override
  String get postPollQuestionLabel => 'Question';

  @override
  String postPollOptionLabel(int number) {
    return 'Option $number';
  }

  @override
  String postPollRemoveOption(int number) {
    return 'Remove option $number';
  }

  @override
  String get postPollAddOption => 'Add an option';

  @override
  String get postPollAllowMultiple => 'People can choose more than one';

  @override
  String get postPollClosesLabel => 'Closes on';

  @override
  String get postPollNoEnd => 'Stays open';

  @override
  String get postTitle => 'Post';

  @override
  String get postDeleteTitle => 'Delete this post?';

  @override
  String get postDeleteBody =>
      'It disappears for everyone, with its comments. This can\'t be undone.';

  @override
  String get postDeletedDone => 'Post deleted.';

  @override
  String get postOpenCommunity => 'Open the community';

  @override
  String get moderationModerate => 'Moderate';

  @override
  String get commentPosted => 'Comment posted.';

  @override
  String postRemovedReason(String reason) {
    return 'Reason given by the moderator: $reason';
  }

  @override
  String postOpenLink(String host) {
    return 'Open link ($host)';
  }

  @override
  String commentsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count comments',
      one: '1 comment',
      zero: 'Comments',
    );
    return '$_temp0';
  }

  @override
  String get commentJoinToComment => 'Join the community to comment.';

  @override
  String get commentsEmpty => 'No comments yet.';

  @override
  String commentReplyingTo(String name) {
    return 'Replying to $name';
  }

  @override
  String get commentCancelReply => 'Cancel reply';

  @override
  String get commentAddLabel => 'Your comment';

  @override
  String get commentReplyLabel => 'Your reply';

  @override
  String get commentPlainTextHelp => 'Plain text. Be kind.';

  @override
  String get commentSend => 'Send';

  @override
  String get commentSaved => 'Comment saved.';

  @override
  String get commentDeleteTitle => 'Delete this comment?';

  @override
  String get commentDeleteBody => 'Replies to it stay. This can\'t be undone.';

  @override
  String get commentDeletedDone => 'Comment deleted.';

  @override
  String get commentActions => 'Comment options';

  @override
  String get commentHiddenLabel =>
      'Hidden by a moderator; only you and moderators see it';

  @override
  String get commentDeletedText => 'This comment was deleted.';

  @override
  String get commentRemovedText => 'This comment was removed by a moderator.';

  @override
  String get commentReply => 'Reply';

  @override
  String get commentEditTitle => 'Edit comment';

  @override
  String get communitySettingsModeratorsOnly =>
      'Only the owner and moderators can manage this community.';

  @override
  String get communityMembersSettingsHelp =>
      'Approve requests, change roles, warn or ban.';

  @override
  String get communityModerationSettingsHelp =>
      'Reports, appeals and the moderation log.';

  @override
  String get communityNothingChanged =>
      'Nothing changed, so there was nothing to save.';

  @override
  String get communitySaved => 'Community saved.';

  @override
  String get communityDetailsTitle => 'Details';

  @override
  String get communityVisibilityOwnerOnly =>
      'Only the owner can change who can join.';

  @override
  String get communityInviteLinkExpiresTitle =>
      'How long should the link work?';

  @override
  String communityInviteLinkDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String communityInviteSent(String username) {
    return 'Invitation sent to @$username.';
  }

  @override
  String get communityInviteUserNotFound =>
      'No one with this username can be invited. People are found by their exact username once they allow it.';

  @override
  String get communityInviteRevokeTitle => 'Revoke this invitation?';

  @override
  String get communityInviteRevokeBody =>
      'It stops working right away. People who already joined stay members.';

  @override
  String get communityInviteRevoke => 'Revoke';

  @override
  String get communityInviteRevoked => 'Invitation revoked.';

  @override
  String get communityInvitationsTitle => 'Invitations';

  @override
  String get communityInvitationsHelp =>
      'Invited people join directly, even when moderators approve members.';

  @override
  String get communityInviteCreateLink => 'Create an invitation link';

  @override
  String get communityInviteUsernameLabel => 'Invite by username';

  @override
  String get communityInviteUsernameHelp =>
      'Their exact username. They accept or decline in the app.';

  @override
  String get communityInviteSend => 'Send invitation';

  @override
  String get communityInvitationsShowInactive =>
      'Show used, declined, revoked and expired';

  @override
  String get communityInvitationsNone => 'No invitations here.';

  @override
  String get communityInviteKindLink => 'Invitation link';

  @override
  String communityInviteKindPerson(String name) {
    return 'Invitation for $name';
  }

  @override
  String get communityInviteLinkTitle => 'Your invitation';

  @override
  String get communityInviteCodeIntro =>
      'Share this code. People open Communities, choose “Join with a link” and paste it. It\'s shown only once.';

  @override
  String get communityInviteLinkIntro =>
      'Share this link with the people you want to invite. It\'s shown only once.';

  @override
  String communityInviteShareCode(String code) {
    return 'Join my community on Montra: open Communities, choose “Join with a link” and paste this code: $code';
  }

  @override
  String get communityInviteShare => 'Share';

  @override
  String get communityTransferNobody =>
      'There is no other member to hand the community to yet.';

  @override
  String get communityTransferChoose => 'Choose the new owner';

  @override
  String communityTransferTitle(String name) {
    return 'Make $name the owner?';
  }

  @override
  String communityTransferBody(String name) {
    return '$name will own the community and you become a moderator. Only the new owner can give it back.';
  }

  @override
  String get communityTransfer => 'Transfer ownership';

  @override
  String communityTransferredDone(String name) {
    return '$name now owns the community.';
  }

  @override
  String get communityRestoreTitle => 'Restore this community?';

  @override
  String get communityArchiveTitle => 'Archive this community?';

  @override
  String get communityRestoreBody => 'Members can post and comment again.';

  @override
  String get communityArchiveBody =>
      'It becomes read-only: nothing new can be posted, and no one new can join. You can restore it later.';

  @override
  String get communityArchive => 'Archive';

  @override
  String get communityRestoredDone => 'Community restored.';

  @override
  String get communityArchivedDone => 'Community archived.';

  @override
  String get communityOwnerSectionTitle => 'Ownership';

  @override
  String get communityRestoreHelp => 'Restoring lets members post again.';

  @override
  String get communityArchiveHelp =>
      'Archiving keeps everything readable but stops new posts.';

  @override
  String get communityMembersFilterActive => 'Members';

  @override
  String get communityMembersFilterPending => 'Waiting for approval';

  @override
  String get communityMembersFilterBanned => 'Banned';

  @override
  String get communityMembersModeratorsOnlyNote =>
      'These people moderate this community.';

  @override
  String get communityMembersNoRequests => 'No one is waiting to join.';

  @override
  String get communityMembersEmpty => 'No one here.';

  @override
  String communityMemberYou(String name) {
    return '$name (you)';
  }

  @override
  String communityMemberRestrictedUntil(String date) {
    return 'Posting paused until $date';
  }

  @override
  String communityMemberApproved(String name) {
    return '$name is now a member.';
  }

  @override
  String get communityMemberApprove => 'Approve';

  @override
  String communityMemberRejected(String name) {
    return '$name\'s request was declined.';
  }

  @override
  String get communityMemberReject => 'Decline';

  @override
  String communityMemberActions(String name) {
    return 'Options for $name';
  }

  @override
  String communityMemberNowModerator(String name) {
    return '$name is now a moderator.';
  }

  @override
  String communityMemberNowMember(String name) {
    return '$name is now a member.';
  }

  @override
  String get communityMemberMakeModerator => 'Make moderator';

  @override
  String get communityMemberMakeMember => 'Make a regular member';

  @override
  String get moderationTabReports => 'Reports';

  @override
  String get moderationTabAppeals => 'Appeals';

  @override
  String get moderationTabLog => 'Log';

  @override
  String get moderationReportsEmptyOpen =>
      'No reports waiting. Thank you for keeping things kind.';

  @override
  String get moderationReportsEmpty => 'No reports here.';

  @override
  String moderationReportHeadline(String target, String reason) {
    return '$target · $reason';
  }

  @override
  String moderationReportPreview(String text) {
    return 'Reported text: $text';
  }

  @override
  String moderationReportDetails(String text) {
    return 'Reporter wrote: $text';
  }

  @override
  String moderationOpenReports(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count open reports on this',
      one: '1 open report on this',
      zero: 'No other open reports',
    );
    return '$_temp0';
  }

  @override
  String get moderationOpenPost => 'Open the post';

  @override
  String get moderationActOnContent => 'Act on the content';

  @override
  String get moderationActOnAuthor => 'Act on the author';

  @override
  String get moderationUpholdTitle => 'Keep the decision?';

  @override
  String get moderationOverturnTitle => 'Reverse the decision?';

  @override
  String get moderationUpholdBody =>
      'The decision stands. The person is told, with your note if you add one.';

  @override
  String get moderationOverturnBody =>
      'The action is reversed. The person is told, with your note if you add one.';

  @override
  String get moderationUphold => 'Keep decision';

  @override
  String get moderationOverturn => 'Reverse decision';

  @override
  String get moderationAppealDecided =>
      'Appeal decided. The person has been told.';

  @override
  String get moderationAppealsEmpty => 'No open appeals.';

  @override
  String moderationAppealAgainst(String action, String target) {
    return 'Appeal against: $action ($target)';
  }

  @override
  String moderationDecisionReason(String reason) {
    return 'Reason: $reason';
  }

  @override
  String moderationAppealStatement(String text) {
    return 'Appeal: $text';
  }

  @override
  String get moderationReverseTitle => 'Reverse this action?';

  @override
  String get moderationReverseBody =>
      'The action is undone. It stays in the log as reversed.';

  @override
  String get moderationReverse => 'Reverse';

  @override
  String get moderationReversed => 'Action reversed.';

  @override
  String get moderationLogEmpty => 'Nothing in the log yet.';

  @override
  String moderationLogLine(String action, String target) {
    return '$action · $target';
  }

  @override
  String moderationUntil(String date) {
    return 'Until $date';
  }

  @override
  String moderationReversedAt(String date) {
    return 'Reversed on $date';
  }

  @override
  String get myModerationTitle => 'Moderation and reports';

  @override
  String get myModerationTabDecisions => 'About you';

  @override
  String get myModerationTabAppeals => 'Your appeals';

  @override
  String get myModerationTabReports => 'Your reports';

  @override
  String get myModerationDecisionsEmptyTitle => 'Nothing here';

  @override
  String get myModerationDecisionsEmptyBody =>
      'No moderator has acted on your posts, comments or membership.';

  @override
  String get myModerationIntro =>
      'Decisions moderators made about your content or membership. You can appeal within 30 days; another moderator reviews it.';

  @override
  String get appealSent => 'Appeal sent. You will be told the outcome.';

  @override
  String get appealAlreadySent => 'You already appealed this decision.';

  @override
  String get myModerationByStaff => 'Decided by Montra staff';

  @override
  String myModerationEnded(String date) {
    return 'Ended on $date';
  }

  @override
  String appealDecisionNote(String note) {
    return 'Note from the reviewer: $note';
  }

  @override
  String appealDecidedOn(String date) {
    return 'Decided on $date';
  }

  @override
  String appealWindow(String date) {
    return 'You can appeal until $date.';
  }

  @override
  String get appealAction => 'Appeal';

  @override
  String get appealTitle => 'Appeal this decision';

  @override
  String get appealIntro =>
      'Explain why you think the decision should change. A moderator who did not make it will review your appeal.';

  @override
  String get appealStatementLabel => 'Your appeal';

  @override
  String get appealSend => 'Send appeal';

  @override
  String get myModerationAppealsEmpty => 'You haven\'t made any appeals.';

  @override
  String appealSentOn(String date) {
    return 'Sent on $date';
  }

  @override
  String get myModerationReportsEmpty => 'You haven\'t reported anything.';

  @override
  String get challengesTitle => 'Challenges';

  @override
  String get challengesTabMine => 'Yours';

  @override
  String get challengesTabDiscover => 'Join one';

  @override
  String get challengeCreate => 'Start a challenge';

  @override
  String get challengesMineEmptyTitle => 'No challenges yet';

  @override
  String get challengesMineEmptyBody =>
      'Start one for yourself, a group or a community, or join one.';

  @override
  String get challengesDiscoverEmptyTitle => 'Nothing to join right now';

  @override
  String get challengesDiscoverEmptyBody =>
      'Challenges from your groups and communities show up here.';

  @override
  String challengeParticipants(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count taking part',
      one: '1 taking part',
      zero: 'No one has joined yet',
    );
    return '$_temp0';
  }

  @override
  String challengeYourProgress(int percent) {
    return '$percent % done';
  }

  @override
  String get challengeCreateTitle => 'New challenge';

  @override
  String get challengeEditTitle => 'Edit challenge';

  @override
  String get challengePickCommunity => 'Choose a community';

  @override
  String get challengePickCommunityEmpty =>
      'You aren\'t a member of a community yet.';

  @override
  String get challengeScopeRequired => 'Choose where the challenge runs.';

  @override
  String get challengeCreated => 'Challenge started.';

  @override
  String get challengeCreateIntro =>
      'A friendly goal with daily check-ins. Progress stays private unless each person chooses to share it.';

  @override
  String get challengeTitleLabel => 'Title';

  @override
  String get challengeTypeHeading => 'Kind';

  @override
  String get challengeMetricHeading => 'How progress counts';

  @override
  String get challengeTargetLabel => 'Target';

  @override
  String get challengeTargetPercentHelp => 'Use a whole number from 1 to 100.';

  @override
  String get challengeTargetInvalid => 'Use a whole number of at least 1.';

  @override
  String get challengeStartsLabel => 'Starts on';

  @override
  String get challengeEndsLabel => 'Ends on';

  @override
  String get challengeEndsHelp => 'At most a year after the start.';

  @override
  String get challengeScopeHeading => 'Who it is for';

  @override
  String get challengeGroupLabel => 'Group';

  @override
  String get challengeGroupChosen => 'Chosen group';

  @override
  String get challengeCommunityLabel => 'Community';

  @override
  String get challengeCommunityChosen => 'Chosen community';

  @override
  String get challengeLeaderboardLabel => 'Leaderboard';

  @override
  String get challengeLeaderboardHelp =>
      'Only people who choose to appear are on it, as percentages, never amounts.';

  @override
  String get challengePrivateNoLeaderboard =>
      'A challenge just for you has no leaderboard.';

  @override
  String get challengeDescriptionLabel => 'Description (optional)';

  @override
  String get challengeRulesLabel => 'Rules (optional)';

  @override
  String get challengeNothingChanged =>
      'Nothing changed, so there was nothing to save.';

  @override
  String get challengeSaved => 'Challenge saved.';

  @override
  String get challengeEditIntro =>
      'You can change the title, description, rules and leaderboard, and move the end date later.';

  @override
  String get challengeEndsLaterHelp =>
      'The end date can only move later, within a year of the start.';

  @override
  String get challengeCancelTitle => 'Cancel this challenge?';

  @override
  String get challengeCancelBody =>
      'No one can check in any more. This can\'t be undone.';

  @override
  String get challengeCancel => 'Cancel challenge';

  @override
  String get challengeCancelledDone => 'Challenge cancelled.';

  @override
  String get challengeNotOpenNote =>
      'This challenge isn\'t taking new participants.';

  @override
  String get challengeGoalLabel => 'Goal';

  @override
  String get challengeDatesLabel => 'Dates';

  @override
  String get challengeParticipantsLabel => 'Taking part';

  @override
  String get challengeJoinedDone => 'You joined the challenge. Good luck!';

  @override
  String get challengeJoinTitle => 'Join this challenge';

  @override
  String get challengePrivacyNote =>
      'Your check-ins and notes are private. Others see your progress only if you share it.';

  @override
  String get challengeShareProgress => 'Share my progress';

  @override
  String get challengeShareProgressHelp =>
      'People in the challenge see how far you are, as a percentage.';

  @override
  String get challengeShowOnLeaderboard => 'Appear on the leaderboard';

  @override
  String get challengeShowOnLeaderboardHelp =>
      'Needs sharing. Only people who appear can see the leaderboard.';

  @override
  String get challengeJoin => 'Join';

  @override
  String get challengeCheckInSaved => 'Check-in saved.';

  @override
  String get challengeSharingSaved => 'Your sharing choice is saved.';

  @override
  String get challengeLeaveTitle => 'Leave this challenge?';

  @override
  String get challengeLeaveBody =>
      'Your progress stops counting and you leave the leaderboard.';

  @override
  String get challengeLeave => 'Leave challenge';

  @override
  String get challengeLeftDone => 'You left the challenge.';

  @override
  String get challengeYourProgressTitle => 'Your progress';

  @override
  String challengeProgressLine(int value, String target) {
    return '$value of $target';
  }

  @override
  String challengeStreaks(int current, int best) {
    return 'Current streak: $current · Best: $best';
  }

  @override
  String challengeCompletedOn(String date) {
    return 'Completed on $date';
  }

  @override
  String get challengeMilestoneReached => 'Reached';

  @override
  String get challengeMilestoneAhead => 'Not yet';

  @override
  String get challengeCheckInTitle => 'Check in';

  @override
  String get challengeCheckInHelp =>
      'Checking in again for the same day corrects it.';

  @override
  String get challengeCheckInDate => 'Day';

  @override
  String get challengeCheckInDone => 'Done';

  @override
  String get challengeCheckInMissed => 'Missed';

  @override
  String get challengeCheckInPercent => 'How far you are (0–100 %)';

  @override
  String get challengeCheckInCount => 'How many';

  @override
  String get challengeCheckInNote => 'Note (optional)';

  @override
  String get challengeCheckInNoteHelp => 'Only you see this note.';

  @override
  String get challengeCheckIn => 'Save check-in';

  @override
  String get challengeSharingTitle => 'What you share';

  @override
  String get challengeLeaderboardEmpty =>
      'No one appears on the leaderboard yet.';

  @override
  String challengeLeaderboardYou(String name) {
    return '$name (you)';
  }

  @override
  String challengeStreakNow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count-day streak',
      one: '1-day streak',
    );
    return '$_temp0';
  }

  @override
  String get challengeLeaderboardNote =>
      'Percentages of the target only; amounts and notes are never shown.';

  @override
  String get challengeLeaderboardTitle => 'Leaderboard';

  @override
  String get entryConnectAccount => 'Connect to the bank';

  @override
  String get gxExpensesTitle => 'Shared expenses';

  @override
  String gxExpensesTitleOf(String group) {
    return 'Expenses · $group';
  }

  @override
  String get gxExpenseTitle => 'Expense';

  @override
  String get gxBalancesTitle => 'Balances';

  @override
  String get gxSettlementsTitle => 'Payments';

  @override
  String get gxSettlementTitle => 'Payment';

  @override
  String get gxRecurringTitle => 'Recurring expenses';

  @override
  String get gxReportsTitle => 'Group report';

  @override
  String get gxMoreScreens => 'More';

  @override
  String get gxArchivedReadOnly =>
      'This group is archived, so nothing can be added or changed.';

  @override
  String get gxYou => 'You';

  @override
  String get gxFormerMember => 'Former member';

  @override
  String get gxMemberLeft => 'Left';

  @override
  String get gxMemberRemoved => 'Removed';

  @override
  String get gxNoOneToPick => 'There is no one else to choose.';

  @override
  String get gxStatusActive => 'Active';

  @override
  String get gxStatusDisputed => 'Disputed';

  @override
  String get gxStatusDeleted => 'Deleted';

  @override
  String get gxStatusOther => 'Other';

  @override
  String get gxSplitEqual => 'Equally';

  @override
  String get gxSplitExact => 'Exact amounts';

  @override
  String get gxSplitPercentage => 'Percentages';

  @override
  String get gxSplitShares => 'Shares';

  @override
  String get gxSplitItemized => 'By item';

  @override
  String get gxSplitOther => 'Other split';

  @override
  String get gxSplitEqualHelp => 'Everyone chosen pays the same share.';

  @override
  String get gxSplitExactHelp =>
      'Enter each person\'s amount. The amounts must add up to the total.';

  @override
  String get gxSplitPercentageHelp =>
      'Enter each person’s percentage (up to 2 decimals). They must add up to 100%.';

  @override
  String get gxSplitSharesHelp =>
      'Give each person a whole number of shares, for example 2 for a couple.';

  @override
  String get gxSplitItemizedHelp =>
      'List the items and who shared each. Tax, tip or rounding (the total minus the items) is shared in proportion.';

  @override
  String get gxSplitSection => 'Split';

  @override
  String get gxSplitMethodLabel => 'How it is split';

  @override
  String get gxSplitNeedsPeople => 'Choose at least one person to share it.';

  @override
  String gxPercentValue(String value) {
    return '$value %';
  }

  @override
  String gxSharesValue(String value) {
    return '$value shares';
  }

  @override
  String get gxSharesEqually => 'Equal share';

  @override
  String gxValueAmountFor(String name) {
    return 'Amount for $name';
  }

  @override
  String gxValuePercentFor(String name) {
    return 'Percentage for $name';
  }

  @override
  String gxValueSharesFor(String name) {
    return 'Shares for $name';
  }

  @override
  String get gxPercentInvalid =>
      'Enter a percentage up to 100 with up to 2 decimals.';

  @override
  String get gxSharesInvalid => 'Enter a whole number above 0.';

  @override
  String gxPreview(String text) {
    return 'Preview (the server works out the final split): $text';
  }

  @override
  String gxPreviewPeople(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'shared equally by $count people',
      one: 'shared by 1 person',
    );
    return '$_temp0';
  }

  @override
  String get gxPreviewPercentOk => 'the percentages add up to 100%.';

  @override
  String gxPreviewPercentTotal(String total) {
    return 'the percentages add up to $total%, not 100%.';
  }

  @override
  String gxPreviewShares(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count shares in total.',
      one: '1 share in total.',
    );
    return '$_temp0';
  }

  @override
  String gxPreviewAssigned(String assigned) {
    return '$assigned assigned.';
  }

  @override
  String get gxPreviewExactOk => 'the amounts add up to the total.';

  @override
  String get gxPreviewPayersOk => 'the payments add up to the total.';

  @override
  String gxPreviewLeft(String assigned, String left) {
    return '$assigned so far, $left still to assign.';
  }

  @override
  String gxPreviewTooMuch(String assigned, String over) {
    return '$assigned so far, $over more than the total.';
  }

  @override
  String get gxAddExpense => 'Add expense';

  @override
  String get gxEditExpense => 'Edit expense';

  @override
  String get gxFilterAll => 'All';

  @override
  String get gxFilterPayer => 'Paid by';

  @override
  String gxFilterPaidBy(String name) {
    return 'Paid by $name';
  }

  @override
  String get gxFilterCategory => 'Category';

  @override
  String get gxFilterDates => 'Dates';

  @override
  String get gxExpensesEmptyTitle => 'No shared expenses yet';

  @override
  String get gxExpensesEmptyBody =>
      'Add what someone paid for the group, and Montra works out who owes whom.';

  @override
  String get gxExpensesEmptyFiltered => 'Nothing matches these filters';

  @override
  String gxExpenseLine(String date, String category) {
    return '$date · $category';
  }

  @override
  String gxYouPaidShare(String paid, String share) {
    return 'You paid $paid · your share $share';
  }

  @override
  String gxPaidInOriginal(String amount) {
    return 'Paid in $amount';
  }

  @override
  String get gxDescriptionHelp =>
      'What was it for? For example: Dinner, Groceries, Taxi.';

  @override
  String get gxAmountSection => 'Amount';

  @override
  String get gxForeignLabel => 'Paid in another currency';

  @override
  String gxForeignHelp(String currency) {
    return 'Enter what you paid; Montra converts it to $currency.';
  }

  @override
  String get gxOriginalCurrency => 'Currency paid in';

  @override
  String get gxOriginalAmount => 'Amount paid';

  @override
  String get gxRateLookup => 'Use Montra\'s rate for the date';

  @override
  String get gxRateLookupHelp =>
      'Your own saved rate for that day is used first, then a published rate.';

  @override
  String get gxRateManual => 'Enter the rate I used';

  @override
  String gxRateManualHelp(String currency) {
    return 'How many $currency one unit cost, for example from your card statement.';
  }

  @override
  String gxRateLabel(String currency, String group) {
    return '$currency 1 = ? $group';
  }

  @override
  String get gxRateInvalid => 'Enter a positive rate, for example 83.25.';

  @override
  String gxForeignServerAmount(String currency) {
    return 'Montra works out the amount in $currency from the rate and shows it after you save.';
  }

  @override
  String get gxChooseCurrency => 'Choose the currency you paid in.';

  @override
  String get gxDateToday => 'Today (in the group’s time zone)';

  @override
  String get gxItemsSection => 'Items';

  @override
  String get gxItemsHelp =>
      'Item amounts are in the group currency. Choose who shared each item.';

  @override
  String gxItemName(int number) {
    return 'Item $number';
  }

  @override
  String get gxItemAmount => 'Item amount';

  @override
  String get gxItemSharedBy => 'Shared by';

  @override
  String get gxItemRemove => 'Remove item';

  @override
  String get gxItemAdd => 'Add item';

  @override
  String get gxItemNeedsPeople => 'Choose who shared each item.';

  @override
  String get gxWhoPaid => 'Who paid';

  @override
  String get gxPayerYou => 'I paid';

  @override
  String get gxPayerOne => 'Someone else paid';

  @override
  String get gxPayerSeveral => 'Several people paid';

  @override
  String gxPaidBy(String name) {
    return 'Paid by $name';
  }

  @override
  String get gxChoosePayer => 'Choose who paid.';

  @override
  String gxForeignPayerNote(String currency) {
    return 'Several payers need the amount in $currency: to split the payment, enter the amount in $currency instead.';
  }

  @override
  String get gxRecordInAccount => 'Record my payment in an account';

  @override
  String get gxRecordInAccountHelp =>
      'Only your share counts as your spending.';

  @override
  String get gxMoreSection => 'More details';

  @override
  String get gxAttachReceipt => 'Attach a receipt';

  @override
  String get gxReceiptAttached => 'Receipt attached';

  @override
  String get gxReceiptHelp => 'Group members can see it.';

  @override
  String get gxReceiptRemove => 'Remove the file';

  @override
  String gxFormerParticipants(String names) {
    return '$names no longer belong to the group. Saving leaves them out of the split.';
  }

  @override
  String get gxExpenseAdded => 'Expense added.';

  @override
  String get gxExpenseSaved => 'Expense saved.';

  @override
  String get gxDeletedNotice =>
      'This expense was deleted. It no longer counts in balances.';

  @override
  String get gxDisputedNotice =>
      'Someone disputed this expense. It still counts until the dispute is resolved or the expense is edited or deleted.';

  @override
  String get gxYourShare => 'Your share';

  @override
  String get gxYouPaid => 'You paid';

  @override
  String get gxHistory => 'History';

  @override
  String gxEditedTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Edited $count times',
      one: 'Edited once',
    );
    return '$_temp0';
  }

  @override
  String get gxForeignTitle => 'Other currency';

  @override
  String get gxRateUsed => 'Rate used';

  @override
  String gxRateValue(String from, String rate, String to) {
    return '1 $from = $rate $to';
  }

  @override
  String get gxRateSource => 'Rate from';

  @override
  String get gxRateTime => 'Rate as of';

  @override
  String get gxConverted => 'In the group currency';

  @override
  String get gxFxSourceManual => 'Entered by a member';

  @override
  String get gxFxSourceEcb => 'European Central Bank';

  @override
  String get gxFxSourceProvider => 'Rate provider';

  @override
  String get gxFxSourceOther => 'Other source';

  @override
  String get gxPaidBySection => 'Paid by';

  @override
  String get gxSharesSection => 'Shares';

  @override
  String get gxSharesByServer =>
      'Shares are worked out exactly by Montra, down to the last paisa or cent.';

  @override
  String get gxReceipt => 'Receipt';

  @override
  String get gxRecordedInAccount => 'Recorded in your account';

  @override
  String get gxRecordedInAccountHelp =>
      'Your payment is in your transactions; it follows changes to this expense.';

  @override
  String get gxRecorded => 'Recorded in your account.';

  @override
  String get gxUnlink => 'Remove from my account';

  @override
  String get gxUnlinkTitle => 'Remove your account record?';

  @override
  String get gxUnlinkBody =>
      'The transaction in your account is removed. The group expense stays as it is.';

  @override
  String get gxUnlinkSettlementBody =>
      'The transaction in your account is removed. The payment stays recorded in the group.';

  @override
  String get gxUnlinked => 'Removed from your account.';

  @override
  String get gxDeleteTitle => 'Delete this expense?';

  @override
  String gxDeleteBody(String name) {
    return '\"$name\" will no longer count in balances. Members still see it as deleted.';
  }

  @override
  String get gxExpenseDeleted => 'Expense deleted.';

  @override
  String get gxDisputesSection => 'Disputes';

  @override
  String get gxNoDisputes => 'No one has disputed this expense.';

  @override
  String get gxDispute => 'Something is wrong';

  @override
  String get gxDisputeTitle => 'What is wrong?';

  @override
  String get gxDisputeBody =>
      'Members see your note. The expense still counts until it is fixed.';

  @override
  String get gxDisputeReason => 'What is wrong';

  @override
  String get gxDisputeSend => 'Send';

  @override
  String get gxDisputeSent => 'Your note was sent to the group.';

  @override
  String get gxDisputeOpen => 'Open';

  @override
  String get gxDisputeResolved => 'Resolved';

  @override
  String get gxDisputeWithdrawn => 'Withdrawn';

  @override
  String gxRaisedBy(String name) {
    return 'Raised by $name';
  }

  @override
  String gxResolutionText(String text) {
    return 'Resolution: $text';
  }

  @override
  String get gxWithdraw => 'Withdraw';

  @override
  String get gxWithdrawTitle => 'Withdraw your dispute?';

  @override
  String get gxWithdrawBody => 'The expense stays as it is.';

  @override
  String get gxWithdrawn => 'Dispute withdrawn.';

  @override
  String get gxResolve => 'Resolve';

  @override
  String get gxResolveTitle => 'Resolve this dispute';

  @override
  String get gxResolveBody =>
      'Say what was decided. Edit the expense first if something needs to change.';

  @override
  String get gxResolution => 'What was decided';

  @override
  String get gxResolved => 'Dispute resolved.';

  @override
  String get gxCommentsSection => 'Comments';

  @override
  String get gxNoComments => 'No comments yet.';

  @override
  String get gxCommentLabel => 'Add a comment';

  @override
  String get gxCommentSend => 'Send';

  @override
  String get gxCommentSent => 'Comment added.';

  @override
  String get gxYourBalance => 'Your balance';

  @override
  String gxYouAreOwed(String amount) {
    return 'You are owed $amount';
  }

  @override
  String gxYouOwe(String amount) {
    return 'You owe $amount';
  }

  @override
  String get gxYouSettled => 'You are all settled';

  @override
  String gxIsOwed(String name, String amount) {
    return '$name is owed $amount';
  }

  @override
  String gxOwes(String name, String amount) {
    return '$name owes $amount';
  }

  @override
  String gxSettled(String name) {
    return '$name is settled';
  }

  @override
  String gxComputedAt(String time) {
    return 'Worked out $time';
  }

  @override
  String gxDisputedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count disputed expenses still count until they are resolved, edited or deleted.',
      one: '1 disputed expense still counts until it is resolved, edited or deleted.',
    );
    return '$_temp0';
  }

  @override
  String get gxSuggestionsTitle => 'Suggested payments';

  @override
  String get gxSuggestionsHelp =>
      'Suggestions only. Montra does not move money; record a payment after you pay outside Montra.';

  @override
  String get gxOnlyMine => 'Only mine';

  @override
  String get gxNoSuggestionsMine => 'You have nothing to pay or receive.';

  @override
  String get gxNothingOwed => 'Everyone is settled.';

  @override
  String get gxWhoOwesWhom => 'Who owes whom';

  @override
  String get gxDebtsSimplified => 'Fewest payments';

  @override
  String get gxDebtsOriginal => 'As recorded';

  @override
  String get gxDebtsSimplifiedHelp =>
      'The fewest payments that settle everyone. Both views add up to the same balances.';

  @override
  String get gxDebtsOriginalHelp =>
      'What each person owes each other person from the expenses, netted per pair.';

  @override
  String gxPays(String from, String to) {
    return '$from pays $to';
  }

  @override
  String get gxInvolvesYou => 'Involves you';

  @override
  String gxRecordThisPayment(String from, String to, String amount) {
    return 'Record a payment from $from to $to of $amount';
  }

  @override
  String get gxMembersSection => 'Members';

  @override
  String get gxBalancePaid => 'Paid for the group';

  @override
  String get gxBalanceShare => 'Share of expenses';

  @override
  String get gxBalanceSent => 'Payments made (confirmed)';

  @override
  String get gxBalanceReceived => 'Payments received (confirmed)';

  @override
  String get gxBalancePendingOut => 'Reported, waiting for confirmation';

  @override
  String get gxBalancePendingIn => 'To confirm';

  @override
  String get gxFormerBalanceNote =>
      'Their balance stays in the group. Anyone can record a payment with them, and an admin confirms payments to them.';

  @override
  String get gxNoMoneyMoves =>
      'Montra never moves money. Payments here are records of money paid outside Montra.';

  @override
  String get gxRecordPayment => 'Record a payment';

  @override
  String get gxShowVoided => 'Show voided';

  @override
  String get gxSettlementsHelp => 'Only confirmed payments count in balances.';

  @override
  String get gxSettlementsEmptyTitle => 'No payments yet';

  @override
  String get gxSettlementsEmptyBody =>
      'When someone pays back, record it here so balances stay right.';

  @override
  String gxPaid(String from, String to) {
    return '$from paid $to';
  }

  @override
  String get gxSettlementProposed => 'Planned';

  @override
  String get gxSettlementReported => 'Waiting for confirmation';

  @override
  String get gxSettlementConfirmed => 'Confirmed';

  @override
  String get gxSettlementDisputed => 'Disputed';

  @override
  String get gxSettlementVoided => 'Voided';

  @override
  String get gxMethodCash => 'Cash';

  @override
  String get gxMethodBank => 'Bank transfer';

  @override
  String get gxMethodUpi => 'UPI';

  @override
  String get gxMethodOther => 'Other';

  @override
  String get gxMethodLabel => 'How it was paid';

  @override
  String get gxWhoReceived => 'Who received it';

  @override
  String get gxWhoPays => 'Who pays';

  @override
  String get gxRecordIntro =>
      'Montra never moves money. Record a payment made in cash, by bank transfer or UPI; the other person confirms it, and then it counts in balances.';

  @override
  String get gxCorrectIntro =>
      'Correcting records the right payment and voids the original. Both stay in the history.';

  @override
  String get gxCorrectTitle => 'Correct this payment';

  @override
  String get gxCorrectButton => 'Save the correction';

  @override
  String get gxCorrect => 'Correct';

  @override
  String get gxPartialAllowed => 'A part payment is fine.';

  @override
  String get gxProposedLabel => 'Not paid yet';

  @override
  String get gxProposedHelp =>
      'Record it as a plan or a request; the payer marks it paid later.';

  @override
  String get gxFormerPayeeNote =>
      'They are no longer a member, so a group admin confirms this payment for them.';

  @override
  String get gxSettlementAccountHelp =>
      'Adds the payment to your account as money out (not spending).';

  @override
  String get gxAttachProof => 'Attach proof (optional)';

  @override
  String get gxPaymentRecorded => 'Payment recorded.';

  @override
  String get gxCorrected => 'Payment corrected.';

  @override
  String get gxVerification => 'Checked by';

  @override
  String get gxReportedByMembers => 'Reported by members';

  @override
  String get gxVerifiedByProvider => 'Verified by a payment provider';

  @override
  String get gxCounts => 'Counts in balances';

  @override
  String get gxCountsYes => 'Yes';

  @override
  String get gxCountsNo => 'Not yet';

  @override
  String get gxRecordedBy => 'Recorded by';

  @override
  String get gxConfirmedBy => 'Confirmed by';

  @override
  String get gxDisputeReasonLabel => 'Dispute';

  @override
  String get gxVoidReasonLabel => 'Voided because';

  @override
  String get gxCorrectsOriginal => 'This corrects an earlier payment';

  @override
  String get gxCorrectedBy => 'See the corrected payment';

  @override
  String get gxProof => 'Proof of payment';

  @override
  String get gxSettlementRecordedHelp =>
      'This payment is in your transactions.';

  @override
  String get gxProposedStatusHelp =>
      'Planned. The payer marks it paid once the money is sent.';

  @override
  String get gxReportedStatusHelp =>
      'Reported as paid. It counts once the person who received it confirms.';

  @override
  String get gxConfirmedStatusHelp =>
      'Confirmed by the person who received it. It counts in balances.';

  @override
  String get gxDisputedStatusHelp =>
      'Someone said this is not right. It ends when the payee confirms it or someone voids it.';

  @override
  String get gxVoidedStatusHelp => 'Voided. It no longer counts.';

  @override
  String get gxSettlementMarkPaid => 'Mark as paid';

  @override
  String get gxSettlementConfirm => 'Confirm I received it';

  @override
  String get gxSettlementDispute => 'Dispute';

  @override
  String get gxSettlementVoid => 'Void';

  @override
  String get gxSettlementDisputeTitle => 'Dispute this payment?';

  @override
  String get gxSettlementDisputeBody =>
      'Say what is wrong. It stops counting until the payee confirms it again.';

  @override
  String get gxSettlementVoidTitle => 'Void this payment?';

  @override
  String get gxSettlementVoidBody =>
      'It stays in the history but no longer counts. Give a reason.';

  @override
  String get gxReasonLabel => 'Reason';

  @override
  String get gxConfirmTitle => 'Confirm this payment?';

  @override
  String gxConfirmBody(String amount) {
    return 'Confirm only if you received $amount. It then counts in balances.';
  }

  @override
  String get gxConfirmOnBehalfBody =>
      'The person who received it is no longer a member, so you confirm it as an admin. Confirm only if you know the money arrived.';

  @override
  String get gxMarkPaidTitle => 'Mark as paid?';

  @override
  String get gxMarkPaidBody =>
      'Do this once you have sent the money. The other person then confirms it.';

  @override
  String get gxMarkedPaid => 'Marked as paid.';

  @override
  String get gxConfirmed => 'Payment confirmed.';

  @override
  String get gxDisputed => 'Payment disputed.';

  @override
  String get gxVoided => 'Payment voided.';

  @override
  String get gxRecurringAdd => 'Add recurring expense';

  @override
  String get gxRecurringEdit => 'Edit recurring expense';

  @override
  String get gxRecurringEmptyTitle => 'No recurring expenses';

  @override
  String get gxRecurringEmptyBody =>
      'Set up rent, cleaning or a shared subscription once, and add it each time it is due.';

  @override
  String get gxRecurringName => 'Name';

  @override
  String get gxRecurringNameHelp => 'For example: Rent, Cleaning, Internet.';

  @override
  String get gxRecurringAmount => 'Amount each time';

  @override
  String get gxRecurringDescriptionHelp =>
      'The description of each expense (the name by default).';

  @override
  String get gxScheduleSection => 'Schedule';

  @override
  String get gxScheduleDates => 'Dates';

  @override
  String get gxScheduleFixed =>
      'The schedule cannot change. To change it, stop this one and add a new one.';

  @override
  String get gxAutoAddLabel => 'Add automatically when due';

  @override
  String get gxAutoAddHelp => 'Otherwise any member adds it when it is due.';

  @override
  String get gxAutoAddOn => 'Added automatically';

  @override
  String get gxAutoAddOff => 'A member adds it when due';

  @override
  String get gxPayerAdder => 'Whoever adds it';

  @override
  String get gxPayerAdderHelp =>
      'Whoever adds the expense pays it (the creator when it is added automatically).';

  @override
  String get gxRecurringAdded => 'Recurring expense added.';

  @override
  String get gxRecurringSaved => 'Recurring expense saved.';

  @override
  String gxNextOn(String date) {
    return 'Next: $date';
  }

  @override
  String get gxNextLabel => 'Next';

  @override
  String get gxCreatedBy => 'Set up by';

  @override
  String get gxOccurrencesTitle => 'Occurrences';

  @override
  String get gxOccurrencesEmpty => 'Nothing is scheduled.';

  @override
  String get gxOccurrenceAdd => 'Add the expense now';

  @override
  String get gxOccurrenceAddTitle => 'Add this expense?';

  @override
  String gxOccurrenceAddBody(String name, String date) {
    return '$name, due $date. You are recorded as the payer unless the split names payers.';
  }

  @override
  String get gxOccurrenceAdded => 'Expense added.';

  @override
  String get gxOccurrenceSkipped => 'Skipped.';

  @override
  String get gxOpenExpense => 'Open the expense';

  @override
  String get gxRecurringStopTitle => 'Stop this recurring expense?';

  @override
  String gxRecurringStopBody(String name) {
    return 'No more $name expenses will be scheduled. Expenses already added stay.';
  }

  @override
  String get gxAllTime => 'All time';

  @override
  String get gxReportPeriod => 'Report period';

  @override
  String get gxReportEmptyTitle => 'Nothing to report yet';

  @override
  String get gxReportEmptyBody => 'There are no expenses in this period.';

  @override
  String get gxReportSummary => 'Summary';

  @override
  String get gxTotalSpent => 'Total spent';

  @override
  String get gxExpenseCount => 'Expenses';

  @override
  String gxExpensesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count expenses',
      one: '1 expense',
    );
    return '$_temp0';
  }

  @override
  String get gxDisputedLabel => 'Disputed';

  @override
  String get gxParticipants => 'People who shared';

  @override
  String gxPeopleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people',
      one: '1 person',
    );
    return '$_temp0';
  }

  @override
  String get gxPerPerson => 'Average per person';

  @override
  String get gxTripTitle => 'Trip';

  @override
  String get gxDestination => 'Destination';

  @override
  String get gxTripDates => 'Dates';

  @override
  String get gxTripDays => 'Length';

  @override
  String gxDaysCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get gxDailyAverage => 'Average per day';

  @override
  String get gxByCategory => 'By category';

  @override
  String get gxByMember => 'By person';

  @override
  String get gxByMonth => 'By month';

  @override
  String gxMemberPaidShare(String paid, String share) {
    return 'Paid $paid · share $share';
  }

  @override
  String gxChartSummary(String label, String amount) {
    return 'Largest: $label, $amount.';
  }

  @override
  String get gxOriginalCurrencies => 'Paid in other currencies';

  @override
  String gxOriginalConverted(String original, String converted) {
    return '$original → $converted';
  }

  @override
  String get gxOriginalCurrenciesHelp =>
      'Converted with each expense’s own rate.';

  @override
  String get gxSettlementsConfirmed => 'Confirmed';

  @override
  String get gxSettlementsPending => 'Waiting for confirmation';

  @override
  String get gxSettlementsDisputedCount => 'Disputed';

  @override
  String get gxSettlementsCount => 'Payments recorded';

  @override
  String get gxExport => 'Export as CSV';

  @override
  String get gxExportTitle => 'Group expenses (CSV)';

  @override
  String get gxExportIntro =>
      'Every expense (deleted ones too) and every payment of the group, to share or save. Members are named; no account details are included.';

  @override
  String get gxExportFile => 'File';

  @override
  String get gxExportRowsLabel => 'Rows';

  @override
  String gxExportRows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rows',
      one: '1 row',
    );
    return '$_temp0';
  }

  @override
  String get gxErrSplitMismatch =>
      'The split doesn\'t add up. Check the amounts, percentages (100% in total) or shares.';

  @override
  String get gxErrPayersMismatch =>
      'What the payers paid must add up to the total.';

  @override
  String get gxErrItemsExceedTotal =>
      'The items add up to more than the total.';

  @override
  String get gxErrItemsNeedAmount => 'At least one item needs an amount.';

  @override
  String get gxErrPayerOnly =>
      'Only someone who paid can record this expense in an account.';

  @override
  String gxErrFxUnavailable(String from, String to, String date) {
    return 'Montra has no $from to $to rate for $date. Enter the rate you used.';
  }

  @override
  String get gxErrExpenseDeleted =>
      'This expense was deleted, so it can no longer be changed.';

  @override
  String get gxErrExpenseAlreadyRecorded =>
      'This expense is already recorded in your account.';

  @override
  String get gxErrSettlementVoided =>
      'This payment was voided. Record a new one instead.';

  @override
  String gxErrSettlementNotProposed(String status) {
    return 'Only a planned payment can be marked paid. It is now: $status.';
  }

  @override
  String gxErrSettlementNotConfirmable(String status) {
    return 'This payment can no longer be confirmed. It is now: $status.';
  }

  @override
  String gxErrSettlementNotDisputable(String status) {
    return 'Only a reported or confirmed payment can be disputed. It is now: $status.';
  }

  @override
  String get gxErrSettlementAlreadyRecorded =>
      'This payment is already recorded in your account.';

  @override
  String get gxErrSettlementNotConfirmed =>
      'Confirm the payment before recording it in your account.';

  @override
  String get gxErrSettlementNotPaid =>
      'Mark it paid before recording it in your account.';

  @override
  String get gxErrSettlementDispute =>
      'A payment dispute ends when the payee confirms the payment or someone voids it.';

  @override
  String get gxErrRecurringMemberInactive =>
      'Someone who shares or pays this recurring expense is no longer a member. Edit who shares it, then add it.';

  @override
  String gxErrRecurringMemberInactiveNamed(String name) {
    return '$name is no longer a member. Edit who shares or pays this recurring expense, then add it.';
  }

  @override
  String get gxErrRecurringTemplateInvalid =>
      'This recurring expense cannot be added as it is set up. Edit its split, then add it.';

  @override
  String get gxErrGroupArchived =>
      'This group is archived; restore it to make changes.';

  @override
  String get errorAlreadyMember => 'Already a member, so nothing changed.';

  @override
  String gxErrConvertedTooSmall(String currency) {
    return 'At this rate the amount in $currency rounds to zero. Check the original amount and the rate.';
  }

  @override
  String privacyConsentOutdated(String version) {
    return 'The wording of this consent was updated (version $version). We loaded it; try again.';
  }

  @override
  String get moderationErrorAppealDecided =>
      'This appeal was already decided. Reload to see the outcome.';

  @override
  String codeQueryTooShort(String min) {
    return 'Type at least $min characters of the username.';
  }

  @override
  String get codeUsernameInvalid =>
      'Use 3 to 30 lowercase letters, digits, “_” or “.”.';

  @override
  String get codeUsernameReserved =>
      'This username is reserved. Choose another one.';

  @override
  String get codeAvatarFileInvalid =>
      'This photo can\'t be used yet. Upload it again as your profile photo and wait until the upload finishes.';

  @override
  String get codeUsernameOrUserId =>
      'Choose who to invite: type a username or pick a friend, not both.';

  @override
  String codeConfirmWordMismatch(String word) {
    return 'Type $word exactly to confirm.';
  }

  @override
  String get codeDeletionAlreadyScheduled =>
      'Your account is already scheduled for deletion. You can cancel it on the Privacy & data screen.';

  @override
  String get codeNoDeletionScheduled =>
      'There is no scheduled deletion to cancel.';

  @override
  String get codeDuplicateItem =>
      'Each transaction or statement line can be chosen only once.';

  @override
  String get codeTransactionAlreadyMatched =>
      'One of these transactions is already matched or reconciled. Reload to see where things stand.';

  @override
  String get codeSyncRunning =>
      'A sync is already running. Wait for it to finish, then try again.';

  @override
  String get codeAlreadyReported =>
      'You already reported this; moderators will review it.';

  @override
  String get widgetBudgets => 'Budgets';

  @override
  String get widgetBudgetsHelp =>
      'Your fullest budgets and how they\'re pacing';

  @override
  String get widgetUpcoming => 'Coming up';

  @override
  String get widgetUpcomingHelp =>
      'Overdue and upcoming bills, recurring payments, renewals and goal dates';

  @override
  String get widgetGoals => 'Goals';

  @override
  String get widgetGoalsHelp => 'Progress on your nearest goals';

  @override
  String get widgetGroupBalances => 'Group balances';

  @override
  String get widgetGroupBalancesHelp =>
      'Groups where you\'re owed money or owe money';

  @override
  String get dashPlanLoading => 'Loading…';

  @override
  String dashPlanError(String reason) {
    return 'This card couldn\'t be loaded. $reason';
  }

  @override
  String dashPlanBudgetsSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count active budgets',
      one: '1 active budget',
    );
    return '$_temp0';
  }

  @override
  String dashPlanBudgetsOver(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count are over budget',
      one: '1 is over budget',
    );
    return '$_temp0';
  }

  @override
  String get dashPlanBudgetsNoneOver => 'None are over budget';

  @override
  String get dashPlanBudgetsEmpty =>
      'No active budgets. A budget shows how much of a limit you\'ve spent.';

  @override
  String get dashPlanBudgetsCreate => 'Create a budget';

  @override
  String get dashPlanBudgetsSeeAll => 'See all budgets';

  @override
  String get dashPlanBudgetPaused => 'No figures for this period yet';

  @override
  String dashPlanUpcomingSummary(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items through $date',
      one: '1 item through $date',
    );
    return '$_temp0';
  }

  @override
  String dashPlanUpcomingOverdue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count are overdue',
      one: '1 is overdue',
    );
    return '$_temp0';
  }

  @override
  String get dashPlanUpcomingNoneOverdue => 'Nothing is overdue';

  @override
  String get dashPlanUpcomingEmpty =>
      'Nothing is due in the next 14 days, and nothing is overdue.';

  @override
  String get dashPlanUpcomingAddBill => 'Add a bill';

  @override
  String get dashPlanUpcomingSeeAll => 'Open the calendar';

  @override
  String dashPlanUpcomingMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count more in the calendar',
      one: '1 more in the calendar',
    );
    return '$_temp0';
  }

  @override
  String dashPlanDueOn(String date) {
    return 'Due $date';
  }

  @override
  String get dashPlanDueToday => 'Due today';

  @override
  String dashPlanWasDue(String date) {
    return 'Was due $date';
  }

  @override
  String dashPlanGoalsSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count active goals',
      one: '1 active goal',
    );
    return '$_temp0';
  }

  @override
  String get dashPlanGoalsEmpty =>
      'No active goals. Set one to save toward something.';

  @override
  String get dashPlanGoalsCreate => 'Create a goal';

  @override
  String get dashPlanGoalsSeeAll => 'See all goals';

  @override
  String get dashPlanGoalNoDate => 'No target date';

  @override
  String dashPlanGroupsSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Open balances in $count groups',
      one: 'Open balance in 1 group',
    );
    return '$_temp0';
  }

  @override
  String get dashPlanGroupsEmpty => 'You\'re settled up in every group.';

  @override
  String get dashPlanGroupsSeeAll => 'See all groups';

  @override
  String get dashPlanGroupSettled => 'Settled up';

  @override
  String dashPlanShowingFirst(int shown, int total) {
    return 'Showing $shown of $total';
  }

  @override
  String get profileEditTitle => 'Edit profile';

  @override
  String get profileEditEntry => 'Edit profile';

  @override
  String get profileEditEntrySubtitle =>
      'Name, photo, username, bio and who can see your profile';

  @override
  String get profileEditPhotoSection => 'Profile photo';

  @override
  String get profileEditPhotoNone =>
      'No photo yet. People see your initials instead.';

  @override
  String get profileEditPhotoLabel => 'Your profile photo';

  @override
  String profileEditPhotoInitials(String name) {
    return 'Initials for $name';
  }

  @override
  String get profileEditPhotoChoose => 'Choose a photo';

  @override
  String get profileEditPhotoChange => 'Change photo';

  @override
  String get profileEditPhotoRemove => 'Remove photo';

  @override
  String get profileEditPhotoRemoveTitle => 'Remove your profile photo?';

  @override
  String get profileEditPhotoRemoveBody =>
      'People will see your initials instead. You can add a photo again at any time.';

  @override
  String get profileEditPhotoSaved => 'Profile photo updated.';

  @override
  String get profileEditPhotoRemoved => 'Profile photo removed.';

  @override
  String get profileEditPhotoUnavailable =>
      'The photo couldn\'t be shown right now.';

  @override
  String profileEditPhotoHelp(String size) {
    return 'JPG, PNG or WEBP, up to $size. Your photo is shown where your profile is visible.';
  }

  @override
  String get profileEditDetailsSection => 'About you';

  @override
  String get profileEditDisplayName => 'Display name';

  @override
  String get profileEditDisplayNameHelp =>
      'Shown to friends, groups and communities.';

  @override
  String get profileEditBio => 'Bio';

  @override
  String get profileEditBioHelp =>
      'A short line about you. Leave it empty to remove it.';

  @override
  String get profileEditLocation => 'Location';

  @override
  String get profileEditLocationHelp =>
      'A city or region, never your address. Leave it empty to remove it.';

  @override
  String get profileEditInterests => 'Interests';

  @override
  String profileEditInterestsHelp(int max) {
    return 'Up to $max short topics, for example cooking or cricket.';
  }

  @override
  String get profileEditInterestAdd => 'Add interest';

  @override
  String get profileEditInterestNew => 'New interest';

  @override
  String profileEditInterestRemove(String name) {
    return 'Remove interest $name';
  }

  @override
  String get profileEditInterestTooLong =>
      'Keep each interest short (up to 40 letters in English, fewer in Hindi).';

  @override
  String get profileEditInterestDuplicate => 'You already added this interest.';

  @override
  String profileEditInterestsFull(int max) {
    return 'You can add up to $max interests.';
  }

  @override
  String get profileEditInterestsNone => 'No interests added.';

  @override
  String get profileEditVisibility => 'Who can see your profile';

  @override
  String get profileEditVisibilityPrivate => 'Private';

  @override
  String get profileEditVisibilityPrivateHelp =>
      'Only you, people in an active group with you, and people with a pending friend request between you can see your profile and photo.';

  @override
  String get profileEditVisibilityConnections => 'Friends';

  @override
  String get profileEditVisibilityConnectionsHelp =>
      'Your friends can see your profile and photo, as well as you, people in an active group with you, and people with a pending friend request between you.';

  @override
  String get profileEditVisibilityPublic => 'Everyone on Montra';

  @override
  String get profileEditVisibilityPublicHelp =>
      'Anyone signed in to Montra can see your profile and photo.';

  @override
  String get profileEditUsernameHelp =>
      '3 to 30 lowercase letters, digits, “_” or “.”. Leave it empty to remove it. Who can find you by it is set in Friends.';

  @override
  String get profileEditSaved => 'Profile saved.';

  @override
  String get profileEditFinanceNote =>
      'Your profile never shows your accounts, amounts or transactions.';

  @override
  String get prefsTitle => 'Preferences';

  @override
  String get prefsEntrySubtitle =>
      'Currency, region, formats, defaults, theme and accessibility';

  @override
  String get prefsSaved => 'Preferences saved.';

  @override
  String get prefsMoneySection => 'Money';

  @override
  String get prefsBaseCurrency => 'Base currency';

  @override
  String get prefsBaseCurrencyExplain =>
      'Your base currency is the default for new accounts, budgets, goals, bills and receipts, and comes first on Home. Changing it converts nothing: existing accounts, transactions, budgets and goals keep their own currency, and amounts in different currencies are never added together.';

  @override
  String prefsBaseCurrencyChanged(String currency) {
    return 'From now on new records default to $currency. Nothing you already recorded changes.';
  }

  @override
  String get prefsDisplayCurrency => 'Second currency to show';

  @override
  String get prefsDisplayCurrencyHelp =>
      'Optional. Where exchange rates are used, amounts can also be shown in this currency; your records keep their own currency.';

  @override
  String get prefsNone => 'None';

  @override
  String get prefsDefaultAccount => 'Default account';

  @override
  String get prefsDefaultAccountHelp =>
      'Chosen first when you add an expense or income.';

  @override
  String get prefsDefaultAccountMissing =>
      'An account that is no longer active';

  @override
  String get prefsDefaultRange => 'Default period';

  @override
  String get prefsDefaultRangeHelp => 'The period Home opens with.';

  @override
  String get prefsRegionSection => 'Region and language';

  @override
  String get prefsCountryHelp =>
      'Two letters, for example IN. Leave it empty to remove it.';

  @override
  String get prefsTimezoneHelp =>
      '\"Today\", budget periods and reminders follow this time zone. Changing it doesn\'t move anything you already recorded.';

  @override
  String get prefsTimezoneSearch => 'Search time zones';

  @override
  String prefsTimezoneUseTyped(String zone) {
    return 'Use “$zone”';
  }

  @override
  String prefsTimezoneDevice(String zone) {
    return 'This device: $zone';
  }

  @override
  String get prefsLocale => 'Language and region';

  @override
  String get prefsLocaleHelp => 'The app\'s language follows this setting.';

  @override
  String get prefsLocaleEnIn => 'English (India)';

  @override
  String get prefsLocaleEnUs => 'English (United States)';

  @override
  String get prefsLocaleEnGb => 'English (United Kingdom)';

  @override
  String get prefsLocaleHiIn => 'हिन्दी (भारत)';

  @override
  String get prefsFormatsSection => 'Formats';

  @override
  String get prefsDateFormat => 'Date format';

  @override
  String get prefsDateFormatLocale => 'Follow the language';

  @override
  String get prefsDateFormatDmy => 'Day, month, year (31/12/2026)';

  @override
  String get prefsDateFormatMdy => 'Month, day, year (12/31/2026)';

  @override
  String get prefsDateFormatYmd => 'Year, month, day (2026-12-31)';

  @override
  String get prefsDateFormatHelp =>
      'How dates are written in the app, exports, reports and emails.';

  @override
  String get prefsNumberFormat => 'Number format';

  @override
  String get prefsNumberFormatLocale => 'Follow the language and region';

  @override
  String prefsNumberFormatIndian(String example) {
    return 'Lakh and crore ($example)';
  }

  @override
  String prefsNumberFormatInternational(String example) {
    return 'Thousands and millions ($example)';
  }

  @override
  String prefsNumberFormatHelp(String example) {
    return 'How amounts are grouped in the app, for example $example.';
  }

  @override
  String get prefsWeekStart => 'Week starts on';

  @override
  String get prefsWeekStartHelp =>
      'Used for weekly budgets, reports, weekly totals and the calendars where you pick dates.';

  @override
  String get prefsMonthStart => 'Month starts on day';

  @override
  String get prefsMonthStartHelp =>
      'For example 25 if your salary arrives on the 25th. Days 1 to 28.';

  @override
  String prefsMonthStartDay(int day) {
    return 'Day $day';
  }

  @override
  String get prefsAppearanceSection => 'Theme';

  @override
  String get prefsThemeHelp => 'Saved to your account and used on this device.';

  @override
  String get a11yTitle => 'Accessibility';

  @override
  String get a11yIntro =>
      'These settings apply in the app as soon as you save, on top of your phone\'s own accessibility settings.';

  @override
  String get a11yReducedMotion => 'Reduce motion';

  @override
  String get a11yReducedMotionHelp =>
      'Turns off screen transitions and other animations.';

  @override
  String get a11yHighContrast => 'High contrast';

  @override
  String get a11yHighContrastHelp =>
      'Stronger colors and borders that are easier to tell apart.';

  @override
  String get a11yTextSize => 'Text size';

  @override
  String a11yTextSizeValue(int percent) {
    return '$percent%';
  }

  @override
  String get a11yTextSizeHelp =>
      'Multiplies your phone\'s text size, from 80% to 200%.';

  @override
  String get a11yTextSizeSmaller => 'Smaller text';

  @override
  String get a11yTextSizeLarger => 'Larger text';

  @override
  String get a11yTextSizePreview =>
      'Preview: ₹1,250.50 spent on groceries this week.';

  @override
  String get prefsUnsavedTitle => 'Discard your changes?';

  @override
  String get prefsUnsavedBody =>
      'You changed some settings but didn\'t save them.';

  @override
  String get prefsDiscard => 'Discard';

  @override
  String get receiptPagesAddTitle => 'Add receipt';

  @override
  String receiptPagesIntro(int max) {
    return 'Add each photo or PDF of the receipt, in order. A long receipt can have up to $max pages. Nothing is read automatically: you enter the details next.';
  }

  @override
  String get receiptPagesNoneTitle => 'No pages yet';

  @override
  String get receiptPagesNoneBody =>
      'Take a photo, or choose photos or files. Each one becomes a page.';

  @override
  String get receiptPagesTakePhoto => 'Take a photo';

  @override
  String get receiptPagesChoosePhotos => 'Choose photos';

  @override
  String get receiptPagesChooseFiles => 'Choose files';

  @override
  String receiptPagesPage(int position, int total) {
    return 'Page $position of $total';
  }

  @override
  String receiptPagesFile(int position, int total) {
    return 'File $position of $total';
  }

  @override
  String receiptPagesMoveUp(String name) {
    return 'Move $name up';
  }

  @override
  String receiptPagesMoveDown(String name) {
    return 'Move $name down';
  }

  @override
  String receiptPagesRemove(String name) {
    return 'Remove $name';
  }

  @override
  String get receiptPagesStateWaiting => 'Ready to upload';

  @override
  String get receiptPagesStateUploaded => 'Uploaded';

  @override
  String get receiptPagesStateCreating => 'Adding the receipt…';

  @override
  String receiptPagesStateFailed(String reason) {
    return 'Not added: $reason';
  }

  @override
  String get receiptPagesStateDone => 'Added';

  @override
  String get receiptPagesModeTitle => 'These files are';

  @override
  String get receiptPagesModePages => 'Pages of one receipt';

  @override
  String get receiptPagesModePagesHelp => 'In the order shown above.';

  @override
  String get receiptPagesModeSeparate => 'Separate receipts';

  @override
  String get receiptPagesModeSeparateHelp =>
      'Each file becomes its own receipt.';

  @override
  String get receiptPagesNotes => 'Note';

  @override
  String get receiptPagesNotesHelp =>
      'For example who it was for. Kept with the receipt.';

  @override
  String receiptPagesSave(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Add receipt with $count pages',
      one: 'Add receipt',
    );
    return '$_temp0';
  }

  @override
  String receiptPagesSaveSeparate(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Add $count receipts',
      one: 'Add 1 receipt',
    );
    return '$_temp0';
  }

  @override
  String get receiptPagesStop => 'Stop uploading';

  @override
  String get receiptPagesStopped =>
      'Stopped. Nothing was added; uploaded pages are kept until you leave this screen.';

  @override
  String receiptPagesTooMany(int max) {
    return 'A receipt can have up to $max pages.';
  }

  @override
  String receiptPagesAlreadyAdded(String name) {
    return '$name is already in the list.';
  }

  @override
  String receiptPagesRefused(String name, String reason) {
    return '$name wasn\'t added: $reason';
  }

  @override
  String get receiptPagesUploadFailed =>
      'Some pages couldn\'t be uploaded. Try again to upload the rest; uploaded pages aren\'t sent twice.';

  @override
  String receiptPagesSomeFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count receipts weren\'t added. Try again to add them.',
      one: '1 receipt wasn\'t added. Try again to add it.',
    );
    return '$_temp0';
  }

  @override
  String receiptPagesAddedMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count receipts added. Enter their details next.',
      one: '1 receipt added. Enter its details next.',
    );
    return '$_temp0';
  }

  @override
  String get receiptPagesLeaveTitle => 'Leave without adding?';

  @override
  String get receiptPagesLeaveBody =>
      'The pages you chose won\'t be added, and uploaded ones are deleted.';

  @override
  String get receiptPagesLeave => 'Leave';

  @override
  String get widgetAlerts => 'Budget alerts';

  @override
  String get widgetAlertsHelp =>
      'Budgets that reached a limit you set, to snooze or dismiss';

  @override
  String get widgetRenewals => 'Renewals';

  @override
  String get widgetRenewalsHelp =>
      'Subscription renewals and trial ends in the next 30 days';

  @override
  String get widgetRecurring => 'Recurring commitments';

  @override
  String get widgetRecurringHelp =>
      'Regular payments and income as monthly amounts';

  @override
  String dashPlanAlertsSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count active alerts',
      one: '1 active alert',
    );
    return '$_temp0';
  }

  @override
  String get dashPlanAlertsEmpty =>
      'No active budget alerts. One appears here when a budget reaches a limit you set.';

  @override
  String get dashPlanAlertsSeeAll => 'See all budget alerts';

  @override
  String dashPlanAlertSnoozeFor(String budget) {
    return 'Snooze the alert for $budget';
  }

  @override
  String dashPlanAlertDismissFor(String budget) {
    return 'Dismiss the alert for $budget';
  }

  @override
  String dashPlanRenewalsSummary(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count renewals and trial ends through $date',
      one: '1 renewal or trial end through $date',
    );
    return '$_temp0';
  }

  @override
  String get dashPlanRenewalsEmpty =>
      'No subscription renewals or trial ends in the next 30 days.';

  @override
  String get dashPlanRenewalsAdd => 'Add a subscription';

  @override
  String get dashPlanRenewalsSeeAll => 'See all subscriptions';

  @override
  String get dashPlanRenewalToday => 'Today';

  @override
  String dashPlanRenewalOn(String date) {
    return 'On $date';
  }

  @override
  String get dashPlanRecurringSeeAll => 'Open recurring commitments';

  @override
  String get onboardingCalendarSection => 'Weeks and months';

  @override
  String get onboardingGoalsTitle => 'Save toward something (optional)';

  @override
  String get onboardingGoalsBody =>
      'Add one goal now, such as an emergency fund or a trip. You can add plans, milestones and more goals later, or skip this.';

  @override
  String get onboardingGoalCreate => 'Create goal';

  @override
  String get onboardingGoalCreated => 'Goal created';

  @override
  String onboardingGoalTarget(String amount) {
    return 'Target $amount';
  }

  @override
  String get onboardingGoalLater =>
      'You can add money to it, change it or add more goals in Goals.';

  @override
  String get onboardingNotificationsTitle => 'Email summaries';

  @override
  String get onboardingNotificationsBody =>
      'Choose how Montra sends optional emails, such as bill reminders and budget alerts.';

  @override
  String get onboardingDigestOff => 'Send each email right away';

  @override
  String get onboardingDigestOffHelp =>
      'Optional emails arrive as things happen.';

  @override
  String get onboardingDigestDaily => 'Daily summary';

  @override
  String get onboardingDigestDailyHelp =>
      'Optional emails are held and sent together at 8:00 each morning.';

  @override
  String get onboardingDigestWeekly => 'Weekly summary';

  @override
  String get onboardingDigestWeeklyHelp =>
      'Optional emails are held and sent together at 8:00 on Mondays.';

  @override
  String get onboardingDigestSecurity =>
      'Security and account emails, such as sign-in alerts, are always sent right away. You can choose for each kind of email later in notification settings.';

  @override
  String get profileEditVisibilityBlocked =>
      'People you block never see your profile, whatever you choose here, and you don\'t see theirs.';

  @override
  String get savedFiltersOpen => 'Saved filters';

  @override
  String get savedSearchesOpen => 'Saved searches';

  @override
  String get savedFiltersTitle => 'Saved filters';

  @override
  String get savedSearchesTitle => 'Saved searches';

  @override
  String get savedFiltersSaveCurrent => 'Save current filters';

  @override
  String get savedSearchesSaveCurrent => 'Save this search';

  @override
  String get savedFiltersNothingToSave =>
      'Search or choose filters first, then save them here.';

  @override
  String get savedSearchesNothingToSave =>
      'Type at least 2 characters to save a search.';

  @override
  String get savedFiltersEmpty =>
      'Nothing saved yet. What you save is kept with your account, so it’s on the web too.';

  @override
  String get savedFiltersSaveTitle => 'Save filters';

  @override
  String get savedSearchesSaveTitle => 'Save search';

  @override
  String get savedFiltersNameLabel => 'Name';

  @override
  String get savedFiltersNameHelp =>
      'For example “Groceries this month”. Up to 80 characters.';

  @override
  String get savedFiltersNameRequired => 'Enter a name.';

  @override
  String get savedFiltersNameTooLong => 'Use 80 characters or fewer.';

  @override
  String get savedFiltersNameTaken =>
      'You already saved one with this name. Choose another name.';

  @override
  String get savedFiltersFilterInvalid =>
      'These filters can’t be saved. Change them and try again.';

  @override
  String get savedFiltersSaveAction => 'Save';

  @override
  String savedFiltersSaved(String name) {
    return 'Saved “$name”.';
  }

  @override
  String savedFiltersApplied(String name) {
    return 'Showing “$name”.';
  }

  @override
  String savedFiltersDeleteTooltip(String name) {
    return 'Delete “$name”';
  }

  @override
  String savedFiltersDeleteTitle(String name) {
    return 'Delete “$name”?';
  }

  @override
  String get savedFiltersDeleteBody =>
      'It’s removed from your account on every device. Your records don’t change.';

  @override
  String savedFiltersDeleted(String name) {
    return 'Deleted “$name”.';
  }

  @override
  String savedFiltersAlreadyGone(String name) {
    return '“$name” was already deleted.';
  }

  @override
  String get savedFiltersUnusable =>
      'Can’t be used in this version of the app.';

  @override
  String savedFiltersSearchFor(String query) {
    return 'Search: “$query”';
  }

  @override
  String savedFiltersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count filters',
      one: '1 filter',
      zero: 'No filters',
    );
    return '$_temp0';
  }

  @override
  String get helpGuideTopicStart => 'Getting started';

  @override
  String get helpGuideTopicCalculations => 'How Montra calculates';

  @override
  String get helpGuideTopicStatements => 'Statements and reconciliation';

  @override
  String get helpGuideTopicAccount => 'Privacy, security and limits';

  @override
  String get helpGuideTopicTroubleshooting => 'Troubleshooting';

  @override
  String get helpGuidesTitle => 'Guides';

  @override
  String get helpGuidesDescription =>
      'Step-by-step guides and how Montra works out your numbers.';

  @override
  String get helpGuidesSearch => 'Search the guides';

  @override
  String get helpGuidesSearchHelp =>
      'Searches titles and text in the current language.';

  @override
  String helpGuidesNoResults(String query) {
    return 'No guide matches “$query”. Try another word, or send us a request below.';
  }

  @override
  String helpGuidesResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count guides found',
      one: '1 guide found',
    );
    return '$_temp0';
  }

  @override
  String get helpGuidesOpen => 'Read the guide';

  @override
  String get helpGuidesBack => 'All guides';

  @override
  String get helpGuidesOnThisPage => 'On this page';

  @override
  String get helpGuidesRelated => 'Where to do this';

  @override
  String get helpGuidesNotFound =>
      'This guide doesn’t exist. It may have moved.';

  @override
  String get helpGuidesContact =>
      'Didn’t find an answer? Send a support request.';

  @override
  String get helpGuidesStatus => 'Service status';

  @override
  String get helpGuidesStatusHelp =>
      'Check whether Montra is having problems right now.';

  @override
  String get helpGuidesAffordance => 'How this works';

  @override
  String helpGuidesAffordanceFor(String guide) {
    return 'How this works: $guide';
  }

  @override
  String get helpGuideGettingStartedTitle =>
      'Getting started without a bank link';

  @override
  String get helpGuideGettingStartedSummary =>
      'Set up accounts, record or import what happens, and plan ahead. Montra never needs your bank login.';

  @override
  String get helpGuideGettingStartedLink => 'Add an account';

  @override
  String get helpGuideGettingStartedHowTitle => 'How Montra works';

  @override
  String get helpGuideGettingStartedHowB1 =>
      'Montra doesn’t connect to your bank. You tell it what happens: you add your accounts, then record transactions as they happen or import a statement your bank gives you. Your numbers are “tracked”, not verified by a bank.';

  @override
  String get helpGuideGettingStartedHowB2 =>
      'The first-time setup is optional and you can skip any step after the welcome. Nothing in it asks for bank details.';

  @override
  String get helpGuideGettingStartedStepsTitle => 'First steps';

  @override
  String get helpGuideGettingStartedStepsB1 =>
      'Add your accounts: cash, bank, savings, card, wallet, UPI, loan and more. Enter today’s balance as the opening balance (for a card or loan, what you owe).';

  @override
  String get helpGuideGettingStartedStepsB2 =>
      'Record expenses and income as they happen, and use a transfer when money moves between your own accounts.';

  @override
  String get helpGuideGettingStartedStepsB3 =>
      'To bring in many transactions at once, import a statement file (CSV, XLSX, OFX or QFX). To keep a bill, add a photo of the receipt.';

  @override
  String get helpGuideGettingStartedStepsB4 =>
      'Add salary, rent and other repeating money as recurring transactions or bills, so they show on the calendar before they’re due.';

  @override
  String get helpGuideGettingStartedStepsB5 =>
      'Then set a budget or a savings goal when you’re ready.';

  @override
  String get helpGuideGettingStartedAccurateTitle => 'Keeping it accurate';

  @override
  String get helpGuideGettingStartedAccurateB1 =>
      'Now and then, compare a balance with your bank app or statement. If it’s different, reconcile the account or record a balance adjustment with a reason; the adjustment keeps a history and never counts as income or spending.';

  @override
  String get helpGuideNoBankTitle => 'Why don’t I see my bank?';

  @override
  String get helpGuideNoBankSummary =>
      'Montra can’t connect to any bank yet. Here’s why, and what to use instead.';

  @override
  String get helpGuideNoBankLink => 'See connected services';

  @override
  String get helpGuideNoBankTodayTitle => 'No bank linking yet';

  @override
  String get helpGuideNoBankTodayB1 =>
      'Montra doesn’t link to any bank today, so no bank appears in the list. The connected services page shows the one option being considered, Account Aggregator (India), as unavailable: it needs an approved partner, registration and a legal review first.';

  @override
  String get helpGuideNoBankTodayB2 =>
      'It isn’t a setting you’ve missed, and it isn’t a paid feature. When a connection becomes available, it will appear on that page.';

  @override
  String get helpGuideNoBankNeverTitle => 'What Montra will never do';

  @override
  String get helpGuideNoBankNeverB1 =>
      'Ask for your bank password, PIN, card number or OTP.';

  @override
  String get helpGuideNoBankNeverB2 =>
      'Read your SMS or notifications, or scrape your bank’s website.';

  @override
  String get helpGuideNoBankNeverB3 => 'Move money or make payments for you.';

  @override
  String get helpGuideNoBankInsteadTitle => 'What to use instead';

  @override
  String get helpGuideNoBankInsteadB1 =>
      'Import the statement file your bank lets you download.';

  @override
  String get helpGuideNoBankInsteadB2 =>
      'Add receipts from photos, and turn them into transactions.';

  @override
  String get helpGuideNoBankInsteadB3 =>
      'Set up recurring transactions so regular income and bills record themselves.';

  @override
  String get helpGuideBalancesTitle => 'How balances are calculated';

  @override
  String get helpGuideBalancesSummary =>
      'Opening balance plus every counted transaction, with transfers and adjustments kept apart from spending.';

  @override
  String get helpGuideBalancesLink => 'Go to accounts';

  @override
  String get helpGuideBalancesFormulaTitle => 'The balance';

  @override
  String get helpGuideBalancesFormulaB1 =>
      'An account’s balance is its opening balance plus every posted and pending transaction in it. Drafts and deleted (voided) transactions don’t change it. Restoring a deleted transaction counts it again.';

  @override
  String get helpGuideBalancesFormulaB2 =>
      'Credit cards and loans are money you owe, so spending on them increases what you owe.';

  @override
  String get helpGuideBalancesNotSpendingTitle =>
      'What isn’t income or spending';

  @override
  String get helpGuideBalancesNotSpendingB1 =>
      'Transfers between your own accounts change both balances but are never income or spending. A transfer fee is recorded as its own expense.';

  @override
  String get helpGuideBalancesNotSpendingB2 =>
      'Balance adjustments correct a balance to match reality. They keep a history with your reason and never count as income or spending.';

  @override
  String get helpGuideBalancesNotSpendingB3 =>
      'Refunds reduce spending instead of counting as income.';

  @override
  String get helpGuideBalancesCurrenciesTitle => 'Several currencies';

  @override
  String get helpGuideBalancesCurrenciesB1 =>
      'Amounts in different currencies are never simply added together. Totals are shown per currency, unless you choose a display currency; then Montra converts them and tells you which rate it used.';

  @override
  String get helpGuideBalancesCurrenciesB2 =>
      'An account shared with you by your household is read-only for you, and its balance is the owner’s record.';

  @override
  String get helpGuideBudgetsTitle => 'How budgets are calculated';

  @override
  String get helpGuideBudgetsSummary =>
      'What counts as spent, how pace and projections work, and how refunds and rollover change a budget.';

  @override
  String get helpGuideBudgetsLink => 'Go to budgets';

  @override
  String get helpGuideBudgetsSpentTitle => 'What counts as spent';

  @override
  String get helpGuideBudgetsSpentB1 =>
      'A budget adds up the expenses in its period that match it: its accounts, categories and merchants, and only in the budget’s currency. Transactions in other currencies aren’t counted; the budget tells you how many were left out.';

  @override
  String get helpGuideBudgetsSpentB2 =>
      'Transfers and balance adjustments never count.';

  @override
  String get helpGuideBudgetsSpentB3 =>
      'Pending transactions count only if the budget includes pending.';

  @override
  String get helpGuideBudgetsSpentB4 =>
      'Your share of group expenses counts when the budget includes group shares (the default).';

  @override
  String get helpGuideBudgetsRefundsTitle => 'Refunds';

  @override
  String get helpGuideBudgetsRefundsB1 =>
      'When “refunds restore the budget” is on (the default), refunds and reimbursements are subtracted from what you spent. Spent never goes below zero. When it’s off, refunds don’t change the budget.';

  @override
  String get helpGuideBudgetsPaceTitle => 'Pace and projection';

  @override
  String get helpGuideBudgetsPaceB1 =>
      'Pace compares what you’ve spent with an even pace through the period: the limit × days passed ÷ days in the period.';

  @override
  String get helpGuideBudgetsPaceB2 => 'On track: within 10% of the even pace.';

  @override
  String get helpGuideBudgetsPaceB3 =>
      'Spending faster than expected: more than 10% above it.';

  @override
  String get helpGuideBudgetsPaceB4 =>
      'Spending slower than expected: more than 10% below it.';

  @override
  String get helpGuideBudgetsPaceB5 =>
      'Over the limit: you’ve spent more than the limit.';

  @override
  String get helpGuideBudgetsPaceB6 =>
      'The projection is what you’d spend by the end of the period at your current pace. It’s an estimate, not a promise. The daily amount left is what remains ÷ days left.';

  @override
  String get helpGuideBudgetsRolloverTitle => 'Rollover';

  @override
  String get helpGuideBudgetsRolloverB1 =>
      'Rollover carries money from one period into the next. The carried amount is added to (or taken from) the next period’s limit.';

  @override
  String get helpGuideBudgetsRolloverB2 =>
      'Carry unused: what you didn’t spend is added.';

  @override
  String get helpGuideBudgetsRolloverB3 =>
      'Carry overspend: what you overspent is taken off.';

  @override
  String get helpGuideBudgetsRolloverB4 =>
      'Both: either one, whichever happened.';

  @override
  String get helpGuideBudgetsRolloverB5 =>
      'An optional cap limits how much is carried either way. Budgets with a custom period don’t roll over. Editing a budget applies from the current period onward.';

  @override
  String get helpGuideBudgetsAlertsTitle => 'Alerts';

  @override
  String get helpGuideBudgetsAlertsB1 =>
      'Each threshold you choose (for example 50%, 80% and 100%) alerts you once per period. A forecast alert warns when your pace would take you over the limit. You can dismiss or snooze alerts, and an empty threshold list turns threshold alerts off.';

  @override
  String get helpGuideRecurringTitle => 'Recurring, bills and subscriptions';

  @override
  String get helpGuideRecurringSummary =>
      'How repeating transactions are scheduled and posted, how bill status works, and how subscription totals and detection are worked out.';

  @override
  String get helpGuideRecurringLink => 'Go to bills and recurring';

  @override
  String get helpGuideRecurringScheduleTitle => 'Schedules';

  @override
  String get helpGuideRecurringScheduleB1 =>
      'Every date is worked out from the start date, so a rule on the 31st lands on 31 January, 28 or 29 February and 31 March. Montra checks schedules about every 15 minutes and catches up after any downtime.';

  @override
  String get helpGuideRecurringScheduleB2 =>
      'Automatic posting needs a fixed amount and an account, and records exactly one transaction per occurrence. Otherwise you confirm each occurrence, or skip, postpone, change its amount or link a transaction you already recorded.';

  @override
  String get helpGuideRecurringBillsTitle => 'Bills';

  @override
  String get helpGuideRecurringBillsB1 =>
      'A bill’s status comes from its due date and payments: overdue, due today, due soon, upcoming or paid. Mark it paid by linking the real payment (Montra suggests matching transactions) or by recording a new one. Reminders arrive the number of days before that you chose.';

  @override
  String get helpGuideRecurringSubscriptionsTitle => 'Subscriptions';

  @override
  String get helpGuideRecurringSubscriptionsB1 =>
      'Monthly and yearly totals convert each price to a common cycle: a yearly plan counts as one twelfth of its price per month, and a weekly one as 52 payments a year. Totals are kept separate per currency.';

  @override
  String get helpGuideRecurringSubscriptionsB2 =>
      'Once a day, Montra looks for charges at the same merchant at a regular interval (weekly to yearly) with similar amounts, and shows them for review. You confirm or dismiss each one. Montra never cancels anything for you; it gives you a checklist and records the cancellation once the provider confirms it.';

  @override
  String get helpGuideGoalsTitle => 'How goals are calculated';

  @override
  String get helpGuideGoalsSummary =>
      'What counts as saved, how milestones are reached and what the forecast assumes.';

  @override
  String get helpGuideGoalsLink => 'Go to goals';

  @override
  String get helpGuideGoalsSavedTitle => 'Saved so far';

  @override
  String get helpGuideGoalsSavedB1 =>
      'Saved is the starting amount plus recorded contributions minus recorded withdrawals. Planned contributions don’t count until you record them. A withdrawal can’t be more than what’s saved.';

  @override
  String get helpGuideGoalsSavedB2 =>
      'Linking a contribution to a real transaction marks it verified; one transaction can back only one contribution. In a shared goal, contributions a member hides still count towards progress.';

  @override
  String get helpGuideGoalsMilestonesTitle => 'Milestones';

  @override
  String get helpGuideGoalsMilestonesB1 =>
      'Milestones are reached at 25%, 50%, 75% and 100% of the target unless you set your own. Each one notifies the goal’s members once. Reaching the target marks the goal achieved.';

  @override
  String get helpGuideGoalsForecastTitle => 'Forecast';

  @override
  String get helpGuideGoalsForecastB1 =>
      'The forecast shows how much you’d need to add each month (or week) to reach the target by its date, and when you’d reach it at your recent pace: what you saved in the last 90 days. If you planned contributions, it also shows when that plan would finish. It uses exact amounts with no interest or growth.';

  @override
  String get helpGuideGroupBalancesTitle => 'How group balances are calculated';

  @override
  String get helpGuideGroupBalancesSummary =>
      'Who owes whom: what each person paid, their share, and settlements that were confirmed.';

  @override
  String get helpGuideGroupBalancesLink => 'Go to groups';

  @override
  String get helpGuideGroupBalancesNetTitle => 'Your net balance';

  @override
  String get helpGuideGroupBalancesNetB1 =>
      'For each person: what they paid, minus their share of the expenses, plus settlements they paid, minus settlements they received. A positive number means others owe them; a negative number means they owe.';

  @override
  String get helpGuideGroupBalancesNetB2 =>
      'Splits (equal, exact amounts, percentages, shares or items) are worked out exactly in the smallest unit of the currency, and any leftover paisa or cent goes to members in a fixed order, so totals always add up.';

  @override
  String get helpGuideGroupBalancesSettlementsTitle => 'Settlements';

  @override
  String get helpGuideGroupBalancesSettlementsB1 =>
      'Montra never moves money. When you record that you paid someone, it counts in balances only after they confirm it; until then it shows as pending. Settlement suggestions propose fewer payments that clear the same debts, but they don’t change any record.';

  @override
  String get helpGuideGroupBalancesPersonalTitle => 'Your own spending';

  @override
  String get helpGuideGroupBalancesPersonalB1 =>
      'When you record a group payment in your own account, only your share counts as your spending. Expenses in another currency are converted with the rate typed in or Montra’s rate for the expense date.';

  @override
  String get helpGuideGroupBalancesPersonalB2 =>
      'The home screen shows only your own net balance in each group. Group members never see your personal accounts or transactions.';

  @override
  String get helpGuideImportsTitle =>
      'Importing statements and fixing a failed import';

  @override
  String get helpGuideImportsSummary =>
      'Upload a statement file, check the columns, review rows and duplicates, and recover when something goes wrong.';

  @override
  String get helpGuideImportsLink => 'Go to imports';

  @override
  String get helpGuideImportsStepsTitle => 'How an import works';

  @override
  String get helpGuideImportsStepsB1 =>
      'Download a statement from your bank as CSV, XLSX, OFX or QFX, and choose the account it belongs to. The statement must be in the account’s currency.';

  @override
  String get helpGuideImportsStepsB2 =>
      'Check the column mapping: which column is the date, amount or description, the date format and whether spending is shown as negative.';

  @override
  String get helpGuideImportsStepsB3 =>
      'Review the rows. Rows already imported, and possible duplicates of transactions you entered, are flagged. Correct a value or skip a row.';

  @override
  String get helpGuideImportsStepsB4 =>
      'Confirm. Montra creates the transactions in the background and notifies you when it’s done.';

  @override
  String get helpGuideImportsFailedTitle => 'If the file can’t be read';

  @override
  String get helpGuideImportsFailedB1 =>
      'The import page says why. Common reasons and fixes:';

  @override
  String get helpGuideImportsFailedB2 =>
      'Unsupported or damaged file: download the statement again as CSV or XLSX and upload that.';

  @override
  String get helpGuideImportsFailedB3 =>
      'Empty, too many rows or too many columns: split the period into smaller statements. One file can have up to 20,000 rows and 64 columns.';

  @override
  String get helpGuideImportsFailedB4 =>
      'Currency doesn’t match: choose the account in the statement’s currency, or create one.';

  @override
  String get helpGuideImportsFailedB5 =>
      'PDF statements: PDFs can’t be read today. Download CSV, XLSX, OFX or QFX instead.';

  @override
  String get helpGuideImportsRowsTitle => 'If some rows fail';

  @override
  String get helpGuideImportsRowsB1 =>
      'Each refused row names the value to fix, such as a date or amount that can’t be read. Correct it in the row and confirm again. If the import finished with errors, retry the failed rows once you’ve fixed them.';

  @override
  String get helpGuideImportsRowsB2 =>
      'Imported the wrong file or into the wrong account? Undo the import: it deletes the transactions it created, except ones you edited since.';

  @override
  String get helpGuideReconciliationTitle => 'Reconciling an account';

  @override
  String get helpGuideReconciliationSummary =>
      'Match statement lines with your transactions and check a balance against your statement.';

  @override
  String get helpGuideReconciliationLink => 'Go to accounts';

  @override
  String get helpGuideReconciliationMatchesTitle => 'Matching';

  @override
  String get helpGuideReconciliationMatchesB1 =>
      'After an import, Montra suggests matches: a statement line and the transaction you already entered for it, a pending transaction and its posted version, or a manual entry and an imported one. Each suggestion shows how sure it is and why.';

  @override
  String get helpGuideReconciliationMatchesB2 =>
      'Confirming a match keeps one record, so nothing is counted twice. You can also match a line by hand with one or more transactions whose amounts add up, and undo a match later.';

  @override
  String get helpGuideReconciliationMatchesB3 =>
      'Both sides must be money in or both money out, and the amounts must add up exactly.';

  @override
  String get helpGuideReconciliationMatchesB4 =>
      'A transaction can be in only one match.';

  @override
  String get helpGuideReconciliationMatchesB5 =>
      'A pair more than a week apart is shown without confidence: check it yourself.';

  @override
  String get helpGuideReconciliationBalanceTitle => 'Balance check';

  @override
  String get helpGuideReconciliationBalanceB1 =>
      'Enter the balance on your statement (for a card, the amount owed) and its date. Montra compares it with the account on that date and records whether it balanced. A balanced check is remembered as the last reconciled date.';

  @override
  String get helpGuideReconciliationBalanceB2 =>
      'If it doesn’t balance, look for missing or duplicate transactions around that date, unconfirmed matches and pending items. If the difference is real, record a balance adjustment with a reason.';

  @override
  String get helpGuidePrivacyTitle => 'Privacy, export and deletion';

  @override
  String get helpGuidePrivacySummary =>
      'Choose optional consents, download a copy of your data, pause your account or delete it.';

  @override
  String get helpGuidePrivacyLink => 'Go to privacy and data';

  @override
  String get helpGuidePrivacyConsentsTitle => 'Consents';

  @override
  String get helpGuidePrivacyConsentsB1 =>
      'The terms and privacy policy are accepted at sign-up. Everything else (location, notifications, and others) is optional, and you can turn it off at any time. Some choices are only recorded today because the feature they’d enable doesn’t exist yet.';

  @override
  String get helpGuidePrivacyConsentsB2 =>
      'Montra’s staff have no default access to your financial data, and logs never contain your amounts, merchants or descriptions.';

  @override
  String get helpGuidePrivacyExportTitle => 'Download your data';

  @override
  String get helpGuidePrivacyExportB1 =>
      'Ask for an export and confirm it’s you. Montra prepares a ZIP file with your data in the background and notifies you when it’s ready. The download link stays valid for 7 days.';

  @override
  String get helpGuidePrivacyDeactivateTitle => 'Deactivate';

  @override
  String get helpGuidePrivacyDeactivateB1 =>
      'Deactivating signs you out everywhere and keeps your data. Signing in again reactivates the account.';

  @override
  String get helpGuidePrivacyDeleteTitle => 'Delete your account';

  @override
  String get helpGuidePrivacyDeleteB1 =>
      'Deletion starts after a 7-day grace period, and you can cancel it until then. Montra shows what will happen to each group first. When it runs, your personal records and files are deleted, groups you own are handed over or archived, and what you shared in groups and communities stays as “Deleted member”. A confirmation is emailed to you.';

  @override
  String get helpGuidePrivacyDeleteB2 =>
      'Download an export first if you want to keep a copy.';

  @override
  String get helpGuideTwoStepTitle => 'Two-step verification and recovery';

  @override
  String get helpGuideTwoStepSummary =>
      'Protect sign-in with an authenticator app, and keep recovery codes for when your phone isn’t available.';

  @override
  String get helpGuideTwoStepLink => 'Go to security settings';

  @override
  String get helpGuideTwoStepSetupTitle => 'Turning it on';

  @override
  String get helpGuideTwoStepSetupB1 =>
      'In security settings, choose to turn on two-step verification and confirm your password.';

  @override
  String get helpGuideTwoStepSetupB2 =>
      'Scan the QR code (or type the key) into an authenticator app, then enter the 6-digit code it shows.';

  @override
  String get helpGuideTwoStepSetupB3 =>
      'Save the 10 recovery codes somewhere safe and offline. Each code works once.';

  @override
  String get helpGuideTwoStepSignInTitle => 'Signing in';

  @override
  String get helpGuideTwoStepSignInB1 =>
      'After your password, enter the current code from the app, or one of your recovery codes. Codes change every 30 seconds and each code can be used only once, so if one is refused, wait for the next.';

  @override
  String get helpGuideTwoStepSignInB2 =>
      'Sensitive actions (changing two-step verification, new recovery codes, exporting data, deactivating or deleting the account) ask you to confirm it’s you again if you haven’t in the last few minutes.';

  @override
  String get helpGuideTwoStepRecoveryTitle => 'Lost your phone?';

  @override
  String get helpGuideTwoStepRecoveryB1 =>
      'Sign in with a recovery code. Then, in security settings, turn two-step verification off and on again to set up your new phone, or create new recovery codes. New codes replace all the old ones.';

  @override
  String get helpGuideTwoStepRecoveryB2 =>
      'Montra staff can’t see your codes or skip the second step for you, so without your app or a recovery code you can’t sign in. Keep the recovery codes safe.';

  @override
  String get helpGuideTwoStepRecoveryB3 =>
      'Montra emails you whenever two-step verification is turned on or off.';

  @override
  String get helpGuideFairUseTitle => 'Fair-use limits';

  @override
  String get helpGuideFairUseSummary =>
      'The same limits apply to everyone. They keep Montra fast; they are never paid tiers.';

  @override
  String get helpGuideFairUseLink => 'See the limits and your usage';

  @override
  String get helpGuideFairUseWhatTitle => 'What’s limited';

  @override
  String get helpGuideFairUseWhatB1 =>
      'Every feature is free, and the limits are the same for every person. The limits page shows the exact values and how much storage you use. The usual defaults are:';

  @override
  String get helpGuideFairUseWhatB2 =>
      'Storage: 2 GB of files in total, and up to 20 MB per file (some kinds of file have a lower limit).';

  @override
  String get helpGuideFairUseWhatB3 =>
      'Imports: up to 20,000 rows per statement.';

  @override
  String get helpGuideFairUseWhatB4 =>
      'Open records: 500 recurring rules, 200 bills, 500 subscriptions and 200 goals.';

  @override
  String get helpGuideFairUseWhatB5 =>
      'Support: 10 new requests and 10 messages a day.';

  @override
  String get helpGuideFairUseReachedTitle => 'When you reach a limit';

  @override
  String get helpGuideFairUseReachedB1 =>
      'Montra tells you which limit you reached. For open records, archive, end or delete ones you no longer need. For storage, delete files you don’t need. If you’re asked to wait, Montra shows how long; daily caps reset the next day.';

  @override
  String get helpGuideFairUseReachedB2 =>
      'Before uploading, Montra makes large photos smaller, so receipts and pictures use less of your storage. PDFs are uploaded as they are.';

  @override
  String get helpGuideTroubleshootingTitle =>
      'Troubleshooting sign-in, sync and notifications';

  @override
  String get helpGuideTroubleshootingSummary =>
      'What to check when you can’t sign in, your data looks out of date, or notifications don’t arrive.';

  @override
  String get helpGuideTroubleshootingLink => 'Go to notification settings';

  @override
  String get helpGuideTroubleshootingSignInTitle => 'Can’t sign in';

  @override
  String get helpGuideTroubleshootingSignInB1 =>
      'New account? Open the link in the verification email first. You can ask for a new link; links expire after 24 hours.';

  @override
  String get helpGuideTroubleshootingSignInB2 =>
      'The error doesn’t say whether the email or the password is wrong, to protect accounts. If you’re unsure, reset your password; the reset link works for 1 hour, and only the newest one counts.';

  @override
  String get helpGuideTroubleshootingSignInB3 =>
      'After several failed attempts you’ll be asked to wait; the screen shows how long. Resetting your password also works.';

  @override
  String get helpGuideTroubleshootingSignInB4 =>
      'Two-step code refused? Make sure your phone sets its time automatically, and wait for a new code. Or use a recovery code.';

  @override
  String get helpGuideTroubleshootingSignInB5 =>
      'On the web, Montra needs cookies for this site. Changing or resetting your password signs you out on your other devices.';

  @override
  String get helpGuideTroubleshootingSyncTitle => 'Data looks out of date';

  @override
  String get helpGuideTroubleshootingSyncB1 =>
      'There is no bank sync: Montra shows what you’ve recorded or imported. The web and the app read the same account, so a change on one appears on the other when the screen refreshes. Reload the page, or pull down to refresh in the app.';

  @override
  String get helpGuideTroubleshootingSyncB2 =>
      'Some figures update in the background a moment after a change: budget progress, imports, recurring occurrences (about every 15 minutes) and subscription suggestions (daily).';

  @override
  String get helpGuideTroubleshootingSyncB3 =>
      'When your phone is offline, the app shows a banner and changes can’t be saved. Try again when you’re back online: the same save is never recorded twice.';

  @override
  String get helpGuideTroubleshootingNotificationsTitle =>
      'Notifications don’t arrive';

  @override
  String get helpGuideTroubleshootingNotificationsB1 =>
      'Check notification settings: each kind of notification can be on or off for in-app, email and browser notifications. Security and account messages are always on.';

  @override
  String get helpGuideTroubleshootingNotificationsB2 =>
      'Quiet hours delay email and push until they end, and a daily or weekly digest collects non-urgent email (sent at 08:00 your time; weekly on Mondays).';

  @override
  String get helpGuideTroubleshootingNotificationsB3 =>
      'Browser notifications need your browser’s permission, and the server must support them; if the option isn’t offered, they aren’t available yet. The phone app doesn’t receive push notifications yet: open the notification centre instead.';

  @override
  String get helpGuideTroubleshootingNotificationsB4 =>
      'No email? Check your spam folder. Using an unsubscribe link turns off only that kind of email.';

  @override
  String get helpGuideTroubleshootingStillStuckTitle => 'Still stuck?';

  @override
  String get helpGuideTroubleshootingStillStuckB1 =>
      'Send a support request and include the reference shown with the error, if there was one. Never include card numbers, PINs, OTPs or passwords.';

  @override
  String get analyticsPaymentMethodsTitle => 'Payment methods';

  @override
  String get analyticsPaymentMethodsSubtitle =>
      'How you paid for your spending';

  @override
  String get analyticsPaymentMethodUnspecified => 'No payment method';

  @override
  String analyticsPaymentMethodArchived(String name) {
    return '$name (archived)';
  }

  @override
  String analyticsNoPaymentMethodSpending(String period) {
    return 'No spending for $period.';
  }

  @override
  String analyticsPaymentMethodsSummary(String name, String amount, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count payment methods shown.',
      one: '1 payment method shown.',
    );
    return '$name had the most spending: $amount. $_temp0';
  }

  @override
  String analyticsPaymentMethodRow(String amount, int count, String share) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions',
      one: '1 transaction',
    );
    return '$amount · $share · $_temp0';
  }
}

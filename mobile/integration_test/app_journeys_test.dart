import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:montra_mobile/core/config/app_config.dart';

import 'support/journey.dart';

/// Real journeys on a device or emulator against a live Montra API.
///
///   flutter test integration_test -d emulator-5554 \
///     --dart-define=API_BASE_URL=http://10.0.2.2:8080
///
/// The API must run with APP_ENV=development and
/// AUTH_DEV_AUTO_VERIFY_EMAIL=true. Each run signs up a new throwaway user
/// (`e2e.<timestamp>.ci@example.com`) and only touches that user's data.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AppConfig config;

  setUpAll(() async {
    config = journeyConfig();
    step('API: ${config.apiRoot}');
    await expectApiReady(config);
  });

  testWidgets('a new user signs up, skips setup, records money, shares a group '
      'expense and signs out', (WidgetTester tester) async {
    final String email = throwawayEmail();
    final String stamp = email.split('.')[1];
    final String accountName = 'E2E Wallet $stamp';
    final String expenseNote = 'E2E groceries $stamp';
    final String incomeNote = 'E2E salary $stamp';
    final String groupName = 'E2E Trip $stamp';
    final String sharedNote = 'E2E dinner $stamp';

    await launchApp(tester, config);

    step('sign up $email');
    await tapOn(tester, button(l10n.welcomeCreateAccount));
    await waitFor(tester, field(l10n.displayNameLabel));
    await enter(tester, l10n.displayNameLabel, 'E2E Mobile');
    await enter(tester, l10n.emailLabel, email);
    await enter(tester, l10n.passwordLabel, journeyPassword);
    await tapOn(tester, find.text(l10n.termsCheckbox(AppConfig.termsVersion)));
    await tapOn(tester, find.text(l10n.adultCheckbox));
    await tapOn(tester, button(l10n.signUpButton));
    await waitFor(tester, find.text(l10n.checkEmailTitle));

    step('sign in (dev API verifies email automatically)');
    await tapOn(tester, button(l10n.backToSignIn));
    await waitFor(tester, find.byKey(const Key('signIn.email')));
    await tester.enterText(find.byKey(const Key('signIn.email')), email);
    await tester.enterText(
      find.byKey(const Key('signIn.password')),
      journeyPassword,
    );
    await tapOn(tester, find.byKey(const Key('signIn.submit')));

    step('skip onboarding');
    await tapOn(tester, button(l10n.onboardingSkipAll));
    await waitFor(tester, find.text(l10n.dashboardGetStartedTitle));

    step('add an account');
    await tapOn(tester, button(l10n.accountAddFirst));
    await enter(tester, l10n.accountNameLabel, accountName);
    await enter(tester, l10n.openingBalanceLabel, '5000');
    await tapOn(tester, button(l10n.accountCreateButton));
    await waitForGone(tester, button(l10n.accountCreateButton));

    step('add an expense');
    await tapFab(tester);
    await tapOn(tester, find.text(l10n.txTypeExpense), last: true);
    await enter(tester, l10n.amountLabel, '250');
    await enter(tester, l10n.optionalLabel(l10n.descriptionLabel), expenseNote);
    await tapOn(tester, button(l10n.actionSave));
    await waitForGone(tester, field(l10n.amountLabel));

    step('add an income');
    await tapFab(tester);
    await tapOn(tester, find.text(l10n.txTypeIncome), last: true);
    await enter(tester, l10n.amountLabel, '1200');
    await enter(tester, l10n.optionalLabel(l10n.descriptionLabel), incomeNote);
    await tapOn(tester, button(l10n.actionSave));
    await waitForGone(tester, field(l10n.amountLabel));

    step('both show on Home');
    await scrollTo(tester, find.text(expenseNote));
    await scrollTo(tester, find.text(incomeNote));
    expect(find.text(expenseNote), findsWidgets);
    expect(find.text(incomeNote), findsWidgets);

    step('create a group and add a shared expense');
    await openTab(tester, l10n.navTogether);
    await tapOn(tester, find.text(l10n.groupsTitle));
    await tapFab(tester);
    await enter(tester, l10n.groupNameLabel, groupName);
    await tapOn(tester, button(l10n.groupCreateButton));
    await scrollTo(tester, find.text(l10n.groupLinkExpenses));
    await tapOn(tester, find.text(l10n.groupLinkExpenses));
    await tapFab(tester);
    await enter(tester, l10n.descriptionLabel, sharedNote);
    await enter(tester, l10n.amountLabel, '900');
    await tapOn(tester, button(l10n.gxAddExpense));
    await waitForGone(tester, field(l10n.descriptionLabel));
    await waitFor(tester, find.text(sharedNote));

    step('sign out');
    await backToTabs(tester);
    await openTab(tester, l10n.navProfile);
    await scrollTo(tester, button(l10n.signOutButton));
    await tapOn(tester, button(l10n.signOutButton));
    await waitFor(tester, button(l10n.welcomeCreateAccount));
    step('done');
  }, timeout: const Timeout(Duration(minutes: 6)));
}

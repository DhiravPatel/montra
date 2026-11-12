import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/auth/auth_controller.dart';
import 'package:montra_mobile/core/auth/auth_state.dart';
import 'package:montra_mobile/core/files/file_export.dart';
import 'package:montra_mobile/core/files/file_policy.dart';
import 'package:montra_mobile/core/files/file_source.dart';
import 'package:montra_mobile/core/files/file_uploader.dart';
import 'package:montra_mobile/core/formatting/currency_catalog.dart';
import 'package:montra_mobile/core/settings/app_preferences.dart';
import 'package:montra_mobile/features/accounts/data/accounts_api.dart';
import 'package:montra_mobile/features/settings/data/preferences_api.dart';
import 'package:montra_mobile/features/social/data/social_api.dart';

import '../../helpers/fakes.dart';
import '../../helpers/files_fakes.dart';
import '../../helpers/finance_fakes.dart';
import '../../helpers/router_app.dart';
import '../../helpers/social_fakes.dart';

const List<CurrencyDto> _currencies = <CurrencyDto>[
  CurrencyDto(code: 'INR', name: 'Indian Rupee', exponent: 2, selectable: true),
  CurrencyDto(code: 'USD', name: 'US Dollar', exponent: 2, selectable: true),
];

/// `GET /me` with a fuller profile.
MeDto fullMe({
  String? avatar,
  String? bio = 'Saving for a bike',
  String? location = 'Pune',
  List<String> interests = const <String>['cricket'],
  String? username = 'asha',
}) => MeDto.fromJson(<String, Object?>{
  'account': userJson(),
  'profile': <String, Object?>{
    ...profileDtoJson(username: username),
    'bio': ?bio,
    'coarse_location': ?location,
    'interests': interests,
    'avatar_file_id': ?avatar,
  },
  'preferences': preferences().toJson(),
});

/// Preferences with some members replaced.
PreferencesDto prefsWith(Map<String, Object?> changes) =>
    PreferencesDto.fromJson(<String, Object?>{
      ...preferences().toJson(),
      ...changes,
    });

ApiException fieldError(
  String field,
  String code, {
  ErrorObjectCode error = ErrorObjectCode.validationError,
  int status = 422,
}) => serverError(
  error,
  status: status,
  details: <Detail>[
    Detail(field: 'body.$field', code: code, message: 'English text'),
  ],
);

void main() {
  late MockSocialApi social;
  late MockPreferencesApi prefs;
  late MockAccountsApi accounts;
  late MockFileUploader uploader;
  late MockFileDownloader downloader;
  late FakeFileSource source;

  setUpAll(() {
    registerFinanceFallbacks();
    registerSocialFallbacks();
    registerFileFallbacks();
  });

  setUp(() {
    social = MockSocialApi();
    prefs = MockPreferencesApi();
    accounts = MockAccountsApi();
    uploader = MockFileUploader();
    downloader = MockFileDownloader();
    source = FakeFileSource();
    when(() => social.me()).thenAnswer((_) async => fullMe());
    when(() => prefs.preferences()).thenAnswer((_) async => preferences());
    when(() => accounts.list(includeArchived: any(named: 'includeArchived')))
        .thenAnswer((_) async => <AccountDto>[account()]);
    when(() => downloader.download(any())).thenAnswer(
      (_) async => downloadedFile(name: 'me.png', mimeType: 'image/png'),
    );
  });

  List<Override> overrides() => <Override>[
    socialApiProvider.overrideWithValue(social),
    preferencesApiProvider.overrideWithValue(prefs),
    accountsApiProvider.overrideWithValue(accounts),
    fileUploaderProvider.overrideWithValue(uploader),
    fileDownloaderProvider.overrideWithValue(downloader),
    fileSourceProvider.overrideWithValue(source),
    currencyCatalogProvider.overrideWith(
      (_) async => CurrencyCatalog(_currencies),
    ),
  ];

  Future<GoRouter> pump(
    WidgetTester tester,
    String location, {
    Locale locale = const Locale('en'),
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final ({Widget app, GoRouter router}) r = routedApp(
      location,
      overrides: overrides(),
      locale: locale,
    );
    await tester.pumpWidget(r.app);
    await tester.pumpAndSettle();
    return r.router;
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(Scaffold).last));

  group('edit profile', () {
    testWidgets('Profile opens it; only changed fields are sent and emptied '
        'ones are cleared', (WidgetTester tester) async {
      Map<String, Object?>? sent;
      when(() => social.updateProfile(any())).thenAnswer((Invocation i) async {
        sent = (i.positionalArguments.single as ProfilePatch).toJson();
        return ProfileDto.fromJson(<String, Object?>{
          ...profileDtoJson(),
          'display_name': 'Asha Rao',
          'interests': <String>['cooking'],
          'updated_at': '2026-11-12T10:00:00Z',
        });
      });
      final GoRouter router = await pump(tester, '/profile');
      await tapVisible(tester, find.text('Edit profile'));
      expect(locationOf(router), '/profile/edit');

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Display name'),
        'Asha Rao',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Bio (optional)'),
        '',
      );
      await tapVisible(tester, find.byTooltip('Remove interest cricket'));
      await tester.enterText(
        find.widgetWithText(TextField, 'New interest'),
        'cooking',
      );
      await tapVisible(tester, find.byTooltip('Add interest'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(InputChip, 'cooking'), findsOneWidget);

      await tapVisible(tester, find.text('Save'));
      expect(sent, <String, Object?>{
        'display_name': 'Asha Rao',
        'bio': '',
        'interests': <String>['cooking'],
      });
      expect(find.text('Profile saved.'), findsOneWidget);
      final AuthState auth = containerOf(tester).read(authControllerProvider);
      expect((auth as SignedIn).user.displayName, 'Asha Rao');
    });

    testWidgets('nothing changed sends nothing; a long interest is refused', (
      WidgetTester tester,
    ) async {
      await pump(tester, '/profile/edit');
      await tester.enterText(
        find.widgetWithText(TextField, 'New interest'),
        'a' * 41,
      );
      await tapVisible(tester, find.byTooltip('Add interest'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Keep each interest short'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'New interest'),
        'Cricket',
      );
      await tapVisible(tester, find.byTooltip('Add interest'));
      await tester.pumpAndSettle();
      expect(find.text('You already added this interest.'), findsOneWidget);
      await tapVisible(tester, find.text('Save'));
      expect(
        find.text('Nothing changed, so there was nothing to save.'),
        findsOneWidget,
      );
      verifyNever(() => social.updateProfile(any()));
    });

    testWidgets('coded username answers are shown on the field', (
      WidgetTester tester,
    ) async {
      final List<ApiException> answers = <ApiException>[
        fieldError('username', 'username_reserved'),
        fieldError(
          'username',
          'username_taken',
          error: ErrorObjectCode.conflict,
          status: 409,
        ),
      ];
      when(() => social.updateProfile(any())).thenAnswer((_) async {
        throw answers.removeAt(0);
      });
      await pump(tester, '/profile/edit');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Username (optional)'),
        'montra_team',
      );
      await tapVisible(tester, find.text('Save'));
      expect(
        find.text('This username is reserved. Choose another one.'),
        findsOneWidget,
      );
      await tapVisible(tester, find.text('Save'));
      expect(
        find.text('That username is taken. Try another one.'),
        findsOneWidget,
      );
      final ProfilePatch last =
          verify(() => social.updateProfile(captureAny())).captured.last
              as ProfilePatch;
      expect(last.toJson(), <String, Object?>{'username': 'montra_team'});
    });

    testWidgets('a photo is uploaded as an avatar, set, and can be removed '
        'after confirming', (WidgetTester tester) async {
      source.enqueue(pickedFile(name: 'me.png', mimeType: 'image/png'));
      when(
        () => uploader.upload(
          any(),
          any(),
          onStage: any(named: 'onStage'),
          onProgress: any(named: 'onProgress'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) async => fileDto(id: 'f-avatar'));
      final List<ProfilePatch> patches = <ProfilePatch>[];
      when(() => social.updateProfile(any())).thenAnswer((Invocation i) async {
        final ProfilePatch patch = i.positionalArguments.single as ProfilePatch;
        patches.add(patch);
        return ProfileDto.fromJson(<String, Object?>{
          ...profileDtoJson(),
          if (patch.avatarFileId!.isNotEmpty)
            'avatar_file_id': patch.avatarFileId,
        });
      });
      await pump(tester, '/profile/edit');
      expect(find.textContaining('No photo yet.'), findsOneWidget);

      await tester.tap(find.text('Choose a photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose a photo').last);
      await tester.pumpAndSettle();

      expect(source.requests.single.$2, UploadPurpose.avatar);
      expect(
        verify(
          () => uploader.upload(
            any(),
            captureAny(),
            onStage: any(named: 'onStage'),
            onProgress: any(named: 'onProgress'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).captured.single,
        UploadPurpose.avatar,
      );
      expect(patches.single.toJson(), <String, Object?>{
        'avatar_file_id': 'f-avatar',
      });
      expect(find.text('Profile photo updated.'), findsOneWidget);
      verify(() => downloader.download('f-avatar')).called(1);

      await tester.tap(find.text('Remove photo'));
      await tester.pumpAndSettle();
      expect(find.text('Remove your profile photo?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Remove photo'));
      await tester.pumpAndSettle();
      expect(patches.last.toJson(), <String, Object?>{'avatar_file_id': ''});
      expect(find.text('Profile photo removed.'), findsOneWidget);
      expect(find.text('Choose a photo'), findsOneWidget);
    });

    testWidgets('a photo the server refuses is explained', (
      WidgetTester tester,
    ) async {
      source.enqueue(pickedFile(name: 'me.png', mimeType: 'image/png'));
      when(
        () => uploader.upload(
          any(),
          any(),
          onStage: any(named: 'onStage'),
          onProgress: any(named: 'onProgress'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) async => fileDto(id: 'f-avatar'));
      when(() => social.updateProfile(any()))
          .thenThrow(fieldError('avatar_file_id', 'avatar_file_invalid'));
      await pump(tester, '/profile/edit');
      await tester.tap(find.text('Choose a photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose a photo').last);
      await tester.pumpAndSettle();
      expect(
        find.textContaining("This photo can't be used yet."),
        findsOneWidget,
      );
    });

    testWidgets('a profile with nothing optional shows what can be added', (
      WidgetTester tester,
    ) async {
      when(() => social.me()).thenAnswer(
        (_) async => fullMe(
          bio: null,
          location: null,
          interests: const <String>[],
          username: null,
        ),
      );
      await pump(tester, '/profile/edit');
      expect(find.textContaining('No photo yet.'), findsOneWidget);
      expect(find.bySemanticsLabel('Initials for Asha'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('No interests added.'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('No interests added.'), findsOneWidget);
    });

    testWidgets('a profile that fails to load offers a retry', (
      WidgetTester tester,
    ) async {
      int calls = 0;
      when(() => social.me()).thenAnswer((_) async {
        if (++calls == 1) {
          throw offline;
        }
        return fullMe();
      });
      await pump(tester, '/profile/edit');
      expect(find.text("You're offline"), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(TextFormField, 'Display name'),
        findsOneWidget,
      );
    });
  });

  group('preferences', () {
    testWidgets('Profile opens it; the base currency is explained and only '
        'changed preferences are sent, then applied', (
      WidgetTester tester,
    ) async {
      Map<String, Object?>? sent;
      when(() => prefs.updatePreferences(any()))
          .thenAnswer((Invocation i) async {
            sent = (i.positionalArguments.single as PreferencesPatch).toJson();
            final PreferencesDto saved = prefsWith(<String, Object?>{
              'number_format': 'indian',
              'reduced_motion': true,
              'text_scale_percent': 130,
              'country': null,
              'updated_at': '2026-11-12T10:00:00Z',
            });
            // The screen reloads the preferences after saving.
            when(() => prefs.preferences()).thenAnswer((_) async => saved);
            return saved;
          });
      final GoRouter router = await pump(tester, '/profile');
      await tapVisible(tester, find.text('Preferences'));
      expect(locationOf(router), '/profile/preferences');

      expect(
        find.textContaining('Changing it converts nothing'),
        findsOneWidget,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Country or region code (optional)'),
        '',
      );
      await tapVisible(tester, find.text('Follow the language and region'));
      await tester.tap(find.textContaining('Lakh and crore').last);
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Reduce motion'));
      await tapVisible(tester, find.byTooltip('Larger text'));
      await tester.tap(find.byTooltip('Larger text'));
      await tester.pump();
      await tester.tap(find.byTooltip('Larger text'));
      await tester.pumpAndSettle();
      expect(find.text('130%'), findsOneWidget);

      await tapVisible(tester, find.widgetWithText(FilledButton, 'Save'));
      expect(sent, <String, Object?>{
        'country': '',
        'number_format': 'indian',
        'reduced_motion': true,
        'text_scale_percent': 130,
      });
      expect(find.text('Preferences saved.'), findsOneWidget);
      // Applied app wide at once.
      expect(
        containerOf(tester).read(accessibilitySettingsProvider),
        const AccessibilitySettings(reducedMotion: true, textScalePercent: 130),
      );
    });

    testWidgets('a new base currency says nothing already recorded changes', (
      WidgetTester tester,
    ) async {
      Map<String, Object?>? sent;
      when(() => prefs.updatePreferences(any()))
          .thenAnswer((Invocation i) async {
            sent = (i.positionalArguments.single as PreferencesPatch).toJson();
            return prefsWith(<String, Object?>{
              'base_currency': 'USD',
              'updated_at': '2026-11-12T10:00:00Z',
            });
          });
      await pump(tester, '/profile/preferences');
      await tester.tap(find.text('INR'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('US Dollar'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('From now on new records default to USD.'),
        findsOneWidget,
      );
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Save'));
      expect(sent, <String, Object?>{'base_currency': 'USD'});
      final AuthState auth = containerOf(tester).read(authControllerProvider);
      expect((auth as SignedIn).user.baseCurrency, 'USD');
    });

    testWidgets('the default account can be cleared', (
      WidgetTester tester,
    ) async {
      when(() => prefs.preferences()).thenAnswer(
        (_) async =>
            prefsWith(<String, Object?>{'default_account_id': 'acc-1'}),
      );
      Map<String, Object?>? sent;
      when(() => prefs.updatePreferences(any()))
          .thenAnswer((Invocation i) async {
            sent = (i.positionalArguments.single as PreferencesPatch).toJson();
            return prefsWith(<String, Object?>{
              'updated_at': '2026-11-12T10:00:00Z',
            });
          });
      await pump(tester, '/profile/preferences');
      expect(find.text('HDFC Savings'), findsOneWidget);
      await tester.tap(find.byTooltip('Clear Default account (optional)'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Save'));
      expect(sent, <String, Object?>{'clear_default_account': true});
    });

    testWidgets('server errors are shown on their fields', (
      WidgetTester tester,
    ) async {
      when(() => prefs.updatePreferences(any()))
          .thenThrow(fieldError('timezone', 'invalid_format'));
      await pump(tester, '/profile/preferences');
      await tapVisible(tester, find.text('Asia/Kolkata'));
      await tester.enterText(
        find.widgetWithText(TextField, 'Search time zones'),
        'Mars/Base',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use “Mars/Base”'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Save'));
      await tester.scrollUntilVisible(
        find.text('Mars/Base'),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Check the format of this value.'), findsOneWidget);
    });

    testWidgets('leaving with unsaved changes asks first', (
      WidgetTester tester,
    ) async {
      final GoRouter router = await pump(tester, '/profile');
      await tapVisible(tester, find.text('Preferences'));
      await tapVisible(tester, find.text('High contrast'));
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Discard your changes?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Discard'));
      await tester.pumpAndSettle();
      expect(locationOf(router), '/profile');
    });

    testWidgets('optional preferences that are not set read "None"', (
      WidgetTester tester,
    ) async {
      when(
        () => prefs.preferences(),
      ).thenAnswer((_) async => prefsWith(<String, Object?>{'country': null}));
      await pump(tester, '/profile/preferences');
      expect(find.text('None'), findsNWidgets(2));
      expect(
        find.widgetWithText(TextFormField, 'Country or region code (optional)'),
        findsOneWidget,
      );
    });

    testWidgets('preferences that fail to load offer a retry', (
      WidgetTester tester,
    ) async {
      int calls = 0;
      when(() => prefs.preferences()).thenAnswer((_) async {
        if (++calls == 1) {
          throw offline;
        }
        return preferences();
      });
      await pump(tester, '/profile/preferences');
      expect(find.text("You're offline"), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Base currency'), findsOneWidget);
    });
  });

  for (final Locale locale in <Locale>[
    const Locale('en'),
    const Locale('hi'),
  ]) {
    testWidgets('profile and preferences fit at 200% text ($locale)', (
      WidgetTester tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      when(() => prefs.preferences()).thenAnswer(
        (_) async => prefsWith(<String, Object?>{
          'default_account_id': 'acc-1',
          'display_currency': 'USD',
        }),
      );
      for (final String location in <String>[
        '/profile/edit',
        '/profile/preferences',
        '/profile',
      ]) {
        final GoRouter router = await pump(tester, location, locale: locale);
        final Finder list = find.byType(Scrollable).first;
        for (int i = 0; i < 14; i++) {
          await tester.drag(list, const Offset(0, -400));
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull, reason: location);
        expect(locationOf(router), location);
      }
    });
  }
}

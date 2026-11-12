import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/features/labels/data/labels_api.dart';

import '../../helpers/finance_fakes.dart';
import '../../helpers/organize_fakes.dart';
import '../../helpers/router_app.dart';

void main() {
  late MockLabelsApi labels;

  setUpAll(registerOrganizeFallbacks);

  setUp(() {
    labels = MockLabelsApi();
    stubLabels(labels, categories: <CategoryDto>[managedCategory()]);
  });

  List<Override> overrides() => <Override>[
    labelsApiProvider.overrideWithValue(labels),
  ];

  Future<GoRouter> pump(WidgetTester tester, String location) async {
    final ({Widget app, GoRouter router}) r = routedApp(
      location,
      overrides: overrides(),
    );
    await tester.pumpWidget(r.app);
    await tester.pumpAndSettle();
    return r.router;
  }

  Future<void> unfocus(WidgetTester tester) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
  }

  Future<void> waitForSnackBar(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }

  Finder inSheet(String text) =>
      find.descendant(of: find.byType(BottomSheet), matching: find.text(text));

  group('tags', () {
    testWidgets('lists tags with usage and adds one; taken names explained', (
      WidgetTester tester,
    ) async {
      when(() => labels.listTags()).thenAnswer(
        (_) async => <TagDto>[
          managedTag(),
          managedTag(id: 'tag-old', name: 'old', usage: 0, archived: true),
        ],
      );
      final List<TagBody> created = <TagBody>[];
      when(() => labels.createTag(any())).thenAnswer((Invocation i) async {
        final TagBody body = i.positionalArguments.first as TagBody;
        created.add(body);
        if (created.length == 2) {
          throw serverError(ErrorObjectCode.conflict, status: 409);
        }
        return managedTag(id: 'tag-work', name: body.name ?? '');
      });
      await pump(tester, '/tags');

      expect(find.text('trip'), findsOneWidget);
      expect(find.text('Used 3 times'), findsOneWidget);
      expect(find.text('old'), findsNothing);
      await tester.tap(find.text('Show archived tags'));
      await tester.pumpAndSettle();
      expect(find.text('old'), findsOneWidget);
      expect(find.text('Archived'), findsOneWidget);

      Future<void> add(String name) async {
        await tester.tap(find.text('New tag'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Tag name'),
          name,
        );
        await unfocus(tester);
        await tester.tap(find.widgetWithText(ChoiceChip, 'Green'));
        await tester.pump();
        await tester.tap(find.widgetWithText(FilledButton, 'Save'));
        await tester.pumpAndSettle();
      }

      await add('work');
      expect(created.first.name, 'work');
      expect(created.first.color, '#43A047');
      expect(find.text('Tag “work” added.'), findsOneWidget);
      await waitForSnackBar(tester);

      await add('trip');
      expect(
        find.text('You already have a tag with this name.'),
        findsOneWidget,
      );
    });

    testWidgets('renames, archives and deletes after confirming', (
      WidgetTester tester,
    ) async {
      when(() => labels.listTags())
          .thenAnswer((_) async => <TagDto>[managedTag()]);
      final List<TagPatch> updates = <TagPatch>[];
      when(() => labels.updateTag('tag-trip', any()))
          .thenAnswer((Invocation i) async {
            updates.add(i.positionalArguments[1] as TagPatch);
            return managedTag();
          });
      when(() => labels.deleteTag('tag-trip')).thenAnswer((_) async {});
      await pump(tester, '/tags');

      await tester.tap(find.text('trip'));
      await tester.pumpAndSettle();
      await tester.tap(inSheet('Rename or recolor'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Tag name'),
        'travel',
      );
      await unfocus(tester);
      // The color can be removed now (`clear_color`).
      await tester.tap(find.widgetWithText(ChoiceChip, 'No color'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(updates.single.toJson(), <String, Object?>{
        'clear_color': true,
        'name': 'travel',
        'version': 1,
      });
      await waitForSnackBar(tester);

      await tester.tap(find.text('trip'));
      await tester.pumpAndSettle();
      await tester.tap(inSheet('Archive'));
      await tester.pumpAndSettle();
      expect(updates.last.archived, isTrue);
      expect(updates.last.version, 1);
      expect(find.text('“trip” archived.'), findsOneWidget);
      await waitForSnackBar(tester);

      await tester.tap(find.text('trip'));
      await tester.pumpAndSettle();
      await tester.tap(inSheet('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete the tag “trip”?'), findsOneWidget);
      expect(
        find.text(
          'It will be removed from 3 transactions. The transactions stay.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      verify(() => labels.deleteTag('tag-trip')).called(1);
      expect(find.text('“trip” deleted.'), findsOneWidget);
    });

    testWidgets('a stale tag is reloaded by itself (GET /tags/{id}) and '
        'offered again', (WidgetTester tester) async {
      when(() => labels.listTags())
          .thenAnswer((_) async => <TagDto>[managedTag()]);
      when(() => labels.updateTag('tag-trip', any()))
          .thenThrow(serverError(ErrorObjectCode.versionConflict, status: 409));
      when(
        () => labels.getTag('tag-trip'),
      ).thenAnswer((_) async => managedTag(name: 'trips abroad', version: 2));
      await pump(tester, '/tags');
      await tester.tap(find.text('trip'));
      await tester.pumpAndSettle();
      await tester.tap(inSheet('Archive'));
      await tester.pumpAndSettle();
      verify(() => labels.getTag('tag-trip')).called(1);
      // The actions open again on the latest version.
      expect(find.text('trips abroad'), findsWidgets);
      expect(inSheet('Archive'), findsOneWidget);
    });

    testWidgets('shows error and empty states', (WidgetTester tester) async {
      int calls = 0;
      when(() => labels.listTags()).thenAnswer((_) async {
        calls++;
        if (calls == 1) {
          throw offline;
        }
        return <TagDto>[];
      });
      await pump(tester, '/tags');
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('No tags yet'), findsOneWidget);
    });
  });

  group('merchants', () {
    void stubDirectory() {
      when(
        () => labels.merchantsPage(
          query: any(named: 'query'),
          status: any(named: 'status'),
          cursor: any(named: 'cursor'),
        ),
      ).thenAnswer((Invocation i) async {
        final String q = (i.namedArguments[#query] as String?) ?? '';
        return merchantsPage(<MerchantDto>[
          if (q.isEmpty) merchantDto(),
          merchantDto(
            id: 'mer-zomato',
            name: 'Zomato',
            aliases: const <String>[],
            status: 'archived',
            transactions: 1,
          ),
        ]);
      });
    }

    testWidgets('searches and opens a merchant with its spending history', (
      WidgetTester tester,
    ) async {
      stubDirectory();
      when(() => labels.getMerchant('mer-swiggy'))
          .thenAnswer((_) async => merchantDetail());
      final GoRouter router = await pump(tester, '/merchants');

      expect(find.text('Swiggy'), findsOneWidget);
      expect(find.text('Also: SWIGGY BLR'), findsOneWidget);
      // The status filter chip and Zomato's status label.
      expect(find.text('Archived'), findsNWidgets(2));
      await tester.enterText(find.byType(TextField), 'zom');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('Swiggy'), findsNothing);
      expect(find.text('Zomato'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Swiggy'));
      await tester.pumpAndSettle();
      expect(locationOf(router), '/merchants/mer-swiggy');

      expect(find.text('Default category'), findsOneWidget);
      expect(find.text('Food'), findsOneWidget);
      expect(find.text('https://www.swiggy.com'), findsOneWidget);
      expect(
        find.textContaining('the highest was Oct 2026 at ₹1,200.50'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Show as a list'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show as a list'));
      await tester.pumpAndSettle();
      expect(find.text('₹1,200.50 · 3 transactions'), findsOneWidget);
    });

    testWidgets('adds another name, merges a duplicate and archives', (
      WidgetTester tester,
    ) async {
      stubDirectory();
      when(() => labels.getMerchant('mer-swiggy'))
          .thenAnswer((_) async => merchantDetail());
      when(() => labels.addMerchantAlias('mer-swiggy', 'Swiggy Instamart'))
          .thenAnswer((_) async => merchantDetail());
      when(
        () => labels.previewMerchantMerge(
          targetId: 'mer-swiggy',
          sourceIds: <String>['mer-zomato'],
        ),
      ).thenAnswer(
        (_) async =>
            merchantMergePreview(transactions: 1, aliases: 2, budgetFilters: 1),
      );
      when(
        () => labels.mergeMerchants(
          targetId: 'mer-swiggy',
          sourceIds: <String>['mer-zomato'],
        ),
      ).thenAnswer((_) async => merchantDetail());
      when(() => labels.updateMerchant('mer-swiggy', any()))
          .thenAnswer((_) async => merchantDetail(status: 'archived'));
      await pump(tester, '/merchants/mer-swiggy');

      await tester.ensureVisible(find.text('Add another name'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add another name'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Other name'),
        'Swiggy Instamart',
      );
      await unfocus(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Add another name'));
      await tester.pumpAndSettle();
      verify(() => labels.addMerchantAlias('mer-swiggy', 'Swiggy Instamart'))
          .called(1);
      expect(
        find.text('“Swiggy Instamart” added as another name.'),
        findsOneWidget,
      );
      await waitForSnackBar(tester);

      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      await tester.tap(inSheet('Merge another merchant into this one'));
      await tester.pumpAndSettle();
      // The merchant itself is not offered.
      expect(inSheet('Swiggy'), findsNothing);
      await tester.tap(inSheet('Zomato'));
      await tester.pumpAndSettle();
      expect(find.text('Merge “Zomato” into “Swiggy”?'), findsOneWidget);
      Finder inDialog(String text) => find.descendant(
        of: find.byType(AlertDialog),
        matching: find.textContaining(text),
      );
      expect(inDialog('These move to “Swiggy”'), findsOneWidget);
      expect(inDialog('1 transaction\n'), findsOneWidget);
      expect(inDialog('2 other names'), findsOneWidget);
      expect(inDialog('1 budget will follow the merge'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Merge'));
      await tester.pumpAndSettle();
      verify(
        () => labels.mergeMerchants(
          targetId: 'mer-swiggy',
          sourceIds: <String>['mer-zomato'],
        ),
      ).called(1);
      expect(find.text('“Zomato” merged into “Swiggy”.'), findsOneWidget);
      await waitForSnackBar(tester);

      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      await tester.tap(inSheet('Archive'));
      await tester.pumpAndSettle();
      final MerchantPatch patch =
          verify(() => labels.updateMerchant('mer-swiggy', captureAny()))
                  .captured
                  .single
              as MerchantPatch;
      expect(patch.archived, isTrue);
      expect(patch.name, isNull);
      expect(patch.version, 1);
    });

    testWidgets('removes another name after confirming', (
      WidgetTester tester,
    ) async {
      when(() => labels.getMerchant('mer-swiggy'))
          .thenAnswer((_) async => merchantDetail());
      when(() => labels.removeMerchantAlias('mer-swiggy', 'SWIGGY BLR'))
          .thenAnswer((_) async => merchantDetail(aliases: const <String>[]));
      await pump(tester, '/merchants/mer-swiggy');

      final Finder remove = find.byTooltip(
        'Remove the other name “SWIGGY BLR”',
      );
      await tester.ensureVisible(remove);
      await tester.pumpAndSettle();
      await tester.tap(remove);
      await tester.pumpAndSettle();
      expect(find.text('Remove “SWIGGY BLR”?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await tester.pumpAndSettle();
      verify(() => labels.removeMerchantAlias('mer-swiggy', 'SWIGGY BLR'))
          .called(1);
      expect(find.text('“SWIGGY BLR” removed.'), findsOneWidget);
    });

    testWidgets('a merged merchant links to the one it was merged into', (
      WidgetTester tester,
    ) async {
      when(() => labels.getMerchant('mer-old')).thenAnswer(
        (_) async => merchantDetail(
          id: 'mer-old',
          name: 'Swigy',
          status: 'merged',
          mergedIntoId: 'mer-swiggy',
        ),
      );
      when(() => labels.getMerchant('mer-swiggy'))
          .thenAnswer((_) async => merchantDetail());
      final GoRouter router = await pump(tester, '/merchants/mer-old');
      expect(
        find.byTooltip('Remove the other name “SWIGGY BLR”'),
        findsNothing,
      );
      await tester.tap(find.text('Open the merchant it was merged into'));
      await tester.pumpAndSettle();
      expect(locationOf(router), '/merchants/mer-swiggy');
    });

    testWidgets('the directory filters by status and loads more pages', (
      WidgetTester tester,
    ) async {
      when(
        () => labels.merchantsPage(
          query: any(named: 'query'),
          status: any(named: 'status'),
          cursor: any(named: 'cursor'),
        ),
      ).thenAnswer((Invocation i) async {
        final String status = i.namedArguments[#status]! as String;
        final String? cursor = i.namedArguments[#cursor] as String?;
        if (status == 'archived') {
          return merchantsPage(<MerchantDto>[
            merchantDto(id: 'mer-old', name: 'Old shop', status: 'archived'),
          ]);
        }
        return cursor == null
            ? merchantsPage(<MerchantDto>[merchantDto()], next: 'c2')
            : merchantsPage(<MerchantDto>[
                merchantDto(id: 'mer-zomato', name: 'Zomato'),
              ]);
      });
      await pump(tester, '/merchants');
      expect(find.text('Swiggy'), findsOneWidget);
      verify(
        () => labels.merchantsPage(query: '', status: 'active', cursor: null),
      ).called(1);
      await tester.tap(find.text('Load more'));
      await tester.pumpAndSettle();
      expect(find.text('Zomato'), findsOneWidget);
      expect(find.text('Load more'), findsNothing);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Archived'));
      await tester.pumpAndSettle();
      expect(find.text('Old shop'), findsOneWidget);
      expect(find.text('Swiggy'), findsNothing);
    });

    testWidgets('edits send only changes; a taken name is explained', (
      WidgetTester tester,
    ) async {
      stubDirectory();
      when(() => labels.getMerchant('mer-swiggy'))
          .thenAnswer((_) async => merchantDetail());
      final List<MerchantPatch> sent = <MerchantPatch>[];
      when(() => labels.updateMerchant('mer-swiggy', any()))
          .thenAnswer((Invocation i) async {
            sent.add(i.positionalArguments[1] as MerchantPatch);
            if (sent.length == 1) {
              throw serverError(
                ErrorObjectCode.conflict,
                status: 409,
                details: const <Detail>[
                  Detail(
                    code: 'name_taken',
                    message: 'Another merchant already has this name.',
                    params: <String, String>{
                      'name': 'Zomato',
                      'merchant_id': 'mer-zomato',
                    },
                  ),
                ],
              );
            }
            return merchantDetail(name: 'Swiggy Foods');
          });
      final GoRouter router = await pump(tester, '/merchants');
      unawaited(router.push<Object?>('/merchants/mer-swiggy/edit'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Clear Default category'));
      await tester.pumpAndSettle();
      final Finder name = find.widgetWithText(TextFormField, 'Name');
      await tester.enterText(name, 'Zomato');
      await unfocus(tester);
      await tester.ensureVisible(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Another merchant already has this name. Merge them instead.',
        ),
        findsOneWidget,
      );

      await tester.enterText(name, 'Swiggy Foods');
      await unfocus(tester);
      await tester.ensureVisible(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(sent.last.name, 'Swiggy Foods');
      expect(sent.last.clearDefaultCategory, isTrue);
      expect(sent.last.defaultCategoryId, isNull);
      expect(sent.last.website, isNull);
      expect(sent.last.notes, isNull);
      expect(sent.last.version, 1);
      expect(find.text('Merchant saved.'), findsOneWidget);
      expect(locationOf(router), '/merchants');
    });

    testWidgets('a stale merchant edit reloads the latest version', (
      WidgetTester tester,
    ) async {
      int loads = 0;
      when(() => labels.getMerchant('mer-swiggy')).thenAnswer((_) async {
        loads++;
        return loads == 1
            ? merchantDetail()
            : merchantDetail(name: 'Swiggy (renamed)', version: 2);
      });
      final List<MerchantPatch> sent = <MerchantPatch>[];
      when(() => labels.updateMerchant('mer-swiggy', any()))
          .thenAnswer((Invocation i) async {
            sent.add(i.positionalArguments[1] as MerchantPatch);
            if (sent.length == 1) {
              throw serverError(ErrorObjectCode.versionConflict, status: 409);
            }
            return merchantDetail(name: 'Swiggy Foods', version: 3);
          });
      final GoRouter router = await pump(tester, '/merchants/mer-swiggy');
      unawaited(router.push<Object?>('/merchants/mer-swiggy/edit'));
      await tester.pumpAndSettle();
      final Finder name = find.widgetWithText(TextFormField, 'Name');
      await tester.enterText(name, 'Swiggy Foods');
      await unfocus(tester);
      await tester.ensureVisible(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(sent.single.version, 1);
      expect(find.textContaining('changed somewhere else'), findsOneWidget);
      expect(find.text('Swiggy (renamed)'), findsWidgets);
      await tester.enterText(name, 'Swiggy Foods');
      await unfocus(tester);
      await tester.ensureVisible(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(sent.last.version, 2);
    });

    testWidgets('shows empty and error states', (WidgetTester tester) async {
      int calls = 0;
      when(
        () => labels.merchantsPage(
          query: any(named: 'query'),
          status: any(named: 'status'),
          cursor: any(named: 'cursor'),
        ),
      ).thenAnswer((_) async {
        calls++;
        if (calls == 1) {
          throw offline;
        }
        return merchantsPage(<MerchantDto>[]);
      });
      when(() => labels.getMerchant('gone'))
          .thenThrow(serverError(ErrorObjectCode.notFound, status: 404));
      final GoRouter router = await pump(tester, '/merchants');
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('No merchants yet'), findsOneWidget);

      unawaited(router.push<Object?>('/merchants/gone'));
      await tester.pumpAndSettle();
      expect(find.text('Try again'), findsOneWidget);
    });
  });
}

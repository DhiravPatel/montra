import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/core/api/api_client.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/api/idempotency.dart';
import 'package:montra_mobile/core/api/interceptors/auth_interceptor.dart';
import 'package:montra_mobile/core/files/file_export.dart';
import 'package:montra_mobile/features/goals/data/goals_api.dart';
import 'package:montra_mobile/features/goals/domain/goal_display.dart';
import 'package:montra_mobile/features/goals/domain/goal_export.dart';

import '../../helpers/fakes.dart';
import '../../helpers/goals_fakes.dart';

const String _csv =
    'date,contributor,kind,status,amount,currency,'
    'share_of_target_percent,voided,note\n'
    '2026-11-05,Asha,contribution,recorded,2500.00,INR,,no,"first, of ""many"""\n'
    '2026-11-06,Ravi,withdrawal,verified,,INR,2.5,no,"two\nlines"\n';

/// The JSON of [g] as the server sends it.
Map<String, Object?> goalJsonOf(GoalDto g) => g.toJson();

void main() {
  late AppLocalizations en;
  late AppLocalizations hi;

  setUpAll(() {
    en = lookupAppLocalizations(const Locale('en'));
    hi = lookupAppLocalizations(const Locale('hi'));
  });

  group('export body', () {
    test('becomes a CSV file to share or save', () {
      final DownloadedFile file = const GoalExport(
        csv: 'a,b\n',
        fileName: 'goal-contributions-2026-11-05.csv',
      ).toFile();
      expect(file.name, 'goal-contributions-2026-11-05.csv');
      expect(file.mimeType, 'text/csv');
      expect(utf8.decode(file.bytes), 'a,b\n');
      expect(const GoalExport(csv: '').toFile().name, 'goal-contributions.csv');
    });

    test('takes the file name from Content-Disposition', () {
      expect(
        exportFileName('attachment; filename="emergency-fund.csv"'),
        'emergency-fund.csv',
      );
      expect(
        exportFileName("attachment; filename*=UTF-8''goa%20trip.csv"),
        'goa trip.csv',
      );
      expect(exportFileName('attachment'), isNull);
      expect(exportFileName(null), isNull);
    });

    test('parses quoted fields, escaped quotes and line breaks', () {
      final List<List<String>> records = parseCsv(_csv);
      expect(records, hasLength(3));
      expect(records[1].last, 'first, of "many"');
      expect(records[2].last, 'two\nlines');
      expect(records[2][4], '');
      expect(parseCsv('a,b\r\nc,d'), <List<String>>[
        <String>['a', 'b'],
        <String>['c', 'd'],
      ]);
      expect(parseCsv(''), isEmpty);
      const GoalExport export = GoalExport(csv: _csv);
      expect(export.rowCount, 2);
      expect(const GoalExport(csv: 'date,amount\n').rowCount, 0);
    });
  });

  group('display', () {
    test('types, statuses and schedules have names in both languages', () {
      for (final GoalInputGoalType t in goalTypeOrder) {
        expect(goalTypeLabel(hi, t), isNotEmpty);
      }
      expect(
        goalTypeLabel(en, GoalInputGoalType.debtPayoff),
        'Paying off a loan',
      );
      // A type this app version doesn't know reads as "Something else".
      expect(goalTypeOf(goal(type: 'pilgrimage')), isNull);
      expect(
        goalTypeLabel(en, goalTypeOf(goal(type: 'pilgrimage'))),
        'Something else',
      );
      expect(goalStatusLabel(en, GoalDtoStatus.cancelled), 'Ended');
      expect(goalStatusChip(en, GoalDtoStatus.active), isNull);
      expect(goalStatusChip(en, GoalDtoStatus.achieved)?.text, 'Achieved');
      expect(goalFilterLabel(en, null), 'Current');
      expect(goalFilterLabel(en, 'all'), 'All, including archived');
      expect(goalFilterLabel(hi, 'paused'), hi.goalStatusPaused);
      expect(
        goalScheduleLabel(en, GoalInputContributionSchedule.biweekly),
        'Every 2 weeks',
      );
      expect(
        goalScheduleOf(goal(schedule: 'none')),
        GoalInputContributionSchedule.none,
      );
      expect(goalPriorityLabel(en, 1), '1 · Highest');
      expect(goalPriorityLabel(hi, 5), '5 · ${hi.goalPriorityLowest}');
      expect(
        goalContributionVisibilityLabel(
          en,
          GoalMemberContributionVisibility.percentOnly,
        ),
        'Shows percentages only',
      );
      expect(goalRoleLabel(en, GoalMemberRole.owner), 'Owner');
      expect(goalRoleLabel(hi, GoalMemberRole.owner), hi.goalMemberRoleOwner);
    });

    test('the owner is listed but not counted as someone it is shared '
        'with', () {
      final GoalDto shared = goal(
        members: <Map<String, Object?>>[
          goalMemberJson(id: 'u-ravi', name: 'Ravi'),
        ],
      );
      expect(shared.members.first.role, GoalMemberRole.owner);
      expect(goalSharedMembers(shared).single.userId, 'u-ravi');
      expect(goalSharedMembers(goal()), isEmpty);
    });

    test('forecast assumptions are localized by code, with the English line '
        'for unknown codes', () {
      final GoalForecast f = forecast(
        assumptions: const <String>[
          'Exact amounts.',
          'Recent pace.',
          'Planned.',
          'Something new.',
        ],
        assumptionCodes: const <String>[
          'exact_amounts_no_growth',
          'recent_pace_window',
          'planned_not_counted',
          'brand_new',
        ],
      );
      expect(goalAssumptions(en, f), <String>[
        en.goalAssumptionExact('INR'),
        en.goalAssumptionPace('90', '3'),
        en.goalAssumptionPlanned,
        'Something new.',
      ]);
      expect(
        en.goalAssumptionPace('90', '3'),
        'Recent pace is the net of recorded and verified contributions in '
        'the last 90 days, divided by 3.',
      );
      expect(goalAssumptions(hi, f).first, hi.goalAssumptionExact('INR'));
    });

    test('the stored goal becomes the same input the form builds', () {
      final GoalInput input = goalInputOf(
        goal(
          starting: '0.00',
          description: '  Rainy days ',
          linkedAccountId: 'acc-1',
        ),
      );
      expect(input.startingAmount, isNull);
      expect(input.description, 'Rainy days');
      expect(input.linkedAccountId, 'acc-1');
      expect(input.plannedContribution, '8000.00');
      expect(input.milestones!.map((GoalMilestoneInput m) => m.percent), <int>[
        25,
        50,
      ]);
      expect(input.version, 1);
      expect(goalInputOf(goal(schedule: 'none')).plannedContribution, isNull);
    });

    test('progress text uses the server basis points as given', () {
      expect(formatGoalPercent(2500, 'en_IN'), '25%');
      expect(formatGoalPercent(250, 'en'), '2.5%');
      expect(formatGoalPercent(12050, 'en'), '120.5%');
      expect(goalProgressFraction(12050), 1.0);
      expect(goalProgressFraction(-5), 0.0);
      expect(goalProgressFraction(2500), 0.25);
    });

    test('contributions are offered on active goals the user may add to', () {
      expect(canContribute(goal()), isTrue);
      expect(canContribute(goal(status: 'paused')), isFalse);
      expect(canContribute(goal(access: 'viewer')), isFalse);
      expect(canContribute(goal(access: 'contributor')), isTrue);
      expect(canManageGoal(goal(access: 'contributor')), isFalse);
    });
  });

  group('GoalsApi', () {
    late FakeHttpAdapter adapter;
    late GoalsApi api;

    setUp(() {
      adapter = FakeHttpAdapter(
        (RequestOptions o) async => jsonResponse(500, null),
      );
      final Dio dio = createApiDio(
        testConfig,
        adapter: adapter,
        enableLogging: false,
      );
      api = GoalsApi(ApiClient(dio), dio);
    });

    test('creating a goal sends the Idempotency-Key; edits send the patch; '
        'actions send the version', () async {
      adapter.handler = (RequestOptions o) async => jsonResponse(
        o.method == 'POST' && o.path.endsWith('/goals') ? 201 : 200,
        envelope(
          o.method == 'DELETE' && o.path.contains('/members/')
              ? <String, Object?>{'ok': true}
              : goalJsonOf(goal()),
        ),
      );
      await api.create(
        const GoalInput(
          name: 'Trip',
          goalType: GoalInputGoalType.travel,
          targetAmount: '100.00',
        ),
        key: 'goal-key-1234',
      );
      expect(
        adapter.requests.last.headers[Idempotency.header],
        'goal-key-1234',
      );
      await api.update(
        'goal-1',
        GoalPatch.fromJson(<String, Object?>{
          'clear': <String>['linked_account_id'],
          'notes': '',
          'version': 2,
        }),
      );
      expect(adapter.requests.last.method, 'PATCH');
      expect(adapter.requests.last.data, <String, Object?>{
        'clear': <String>['linked_account_id'],
        'notes': '',
        'version': 2,
      });
      await api.pause('goal-1', version: 2);
      await api.archive('goal-1', version: 3);
      await api.removeMember('goal-1', 'u-ravi', version: 4);
      await api.updateMember(
        'goal-1',
        goalsTestUserId,
        const GoalMemberUpdate(
          contributionVisibility: GoalMemberUpdateContributionVisibility.hidden,
        ),
        version: 5,
      );
      expect(
        adapter.requests
            .skip(2)
            .map(
              (RequestOptions r) => '${r.method} ${r.uri.path}?${r.uri.query}',
            ),
        <String>[
          'POST /api/v1/goals/goal-1/pause?version=2',
          'DELETE /api/v1/goals/goal-1?version=3',
          'DELETE /api/v1/goals/goal-1/members/u-ravi?version=4',
          'PATCH /api/v1/goals/goal-1/members/$goalsTestUserId?version=5',
        ],
      );
    });

    test('recording a planned contribution sends its own Idempotency-Key; '
        'contributions page with a cursor', () async {
      adapter.handler = (RequestOptions o) async => o.method == 'POST'
          ? jsonResponse(200, envelope(contribution().toJson()))
          : jsonResponse(200, <String, Object?>{
              'data': <Object?>[contribution().toJson()],
              'meta': <String, Object?>{
                'request_id': 'r',
                'timestamp': '2026-11-05T10:00:00Z',
                'next_cursor': 'c2',
                'has_more': true,
              },
            });
      await api.recordContribution(
        'goal-1',
        'gc-9',
        const GoalContributionRecordInput(transactionId: 'tx-1'),
        key: 'record-key-123',
      );
      final RequestOptions record = adapter.requests.last;
      expect(record.uri.path, '/api/v1/goals/goal-1/contributions/gc-9/record');
      expect(record.headers[Idempotency.header], 'record-key-123');
      expect(record.data, <String, Object?>{'transaction_id': 'tx-1'});

      final page = await api.contributions('goal-1', cursor: 'c1');
      expect(page.nextCursor, 'c2');
      expect(adapter.requests.last.uri.queryParameters, <String, String>{
        'cursor': 'c1',
        'limit': '500',
      });
    });

    test('export reads text/csv with auth and the endpoint template', () async {
      adapter.handler = (RequestOptions o) async => ResponseBody.fromString(
        _csv,
        200,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>['text/csv; charset=utf-8'],
          'content-disposition': <String>[
            'attachment; filename="emergency-fund-contributions.csv"',
          ],
        },
      );
      final GoalExport export = await api.export('goal 1');
      expect(export.csv, _csv);
      expect(export.fileName, 'emergency-fund-contributions.csv');
      final RequestOptions sent = adapter.requests.single;
      expect(sent.uri.path, endsWith('/goals/goal%201/export'));
      expect(sent.method, 'GET');
      expect(sent.extra[AuthExtras.requiresAuth], isTrue);
      expect(sent.extra[AuthExtras.endpoint], '/goals/{id}/export');
      expect(sent.headers[Headers.acceptHeader], contains('text/csv'));
    });

    test('export errors are the standard API errors', () async {
      adapter.handler = (RequestOptions o) async =>
          jsonResponse(404, errorBody(ErrorObjectCode.notFound));
      await expectLater(
        api.export('goal-1'),
        throwsA(
          isA<ApiException>().having(
            (ApiException e) => e.code,
            'code',
            ErrorObjectCode.notFound,
          ),
        ),
      );
    });

    test(
      'contributions send the Idempotency-Key; lists send the status',
      () async {
        adapter.handler = (RequestOptions o) async => o.method == 'POST'
            ? jsonResponse(201, envelope(contribution().toJson()))
            : jsonResponse(200, envelope(<Object?>[goal().toJson()]));
        await api.addContribution(
          'goal-1',
          const GoalContributionInput(
            amount: '10.00',
            status: GoalContributionInputStatus.planned,
          ),
          key: 'key-12345678',
        );
        final RequestOptions post = adapter.requests.last;
        expect(post.headers[Idempotency.header], 'key-12345678');
        expect(post.data, <String, Object?>{
          'amount': '10.00',
          'status': 'planned',
        });
        final List<GoalDto> goals = await api.list(status: 'archived');
        expect(goals.single.id, 'goal-1');
        expect(adapter.requests.last.uri.queryParameters, <String, String>{
          'status': 'archived',
        });
        await api.list();
        expect(adapter.requests.last.uri.queryParameters, isEmpty);
      },
    );
  });
}

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart'
    show AsyncNotifierProviderFamily, FutureProviderFamily;
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/features/reports/data/reports_api.dart';

/// Whether [report] is still being generated.
bool isGenerating(ReportDto report) =>
    report.status == ReportDtoStatus.queued ||
    report.status == ReportDtoStatus.running;

/// Re-reads a list while something in it is still being generated: every
/// [interval] (3 s), at most [maxPolls] times (about 3 minutes); after that
/// the screen asks the user to pull to refresh. Polling stops when nothing
/// is generating and when the screen is left (the provider is disposed).
mixin _Polling<T> on AsyncNotifier<T> {
  /// Time between two reads.
  static const Duration interval = Duration(seconds: 3);

  /// Reads before polling gives up.
  static const int maxPolls = 60;

  Timer? _timer;
  int _polls = 0;

  /// Whether polling stopped while something was still generating.
  bool gaveUp = false;

  /// Reads the value from the server.
  Future<T> fetch();

  /// Whether [value] still has something being generated.
  bool working(T value);

  void _startPolling() {
    ref.onDispose(() => _timer?.cancel());
  }

  void _schedule(T value) {
    _timer?.cancel();
    if (!working(value)) {
      gaveUp = false;
      return;
    }
    if (_polls >= maxPolls) {
      gaveUp = true;
      // Nothing else changes, so make the screen show the hint.
      ref.notifyListeners();
      return;
    }
    _timer = Timer(interval, _poll);
  }

  Future<void> _poll() async {
    _polls++;
    try {
      final T next = await fetch();
      if (!ref.mounted) {
        return;
      }
      state = AsyncData<T>(next);
      _schedule(next);
    } on Object {
      // A failed poll keeps the last value; the next poll tries again.
      if (ref.mounted && state.hasValue) {
        _schedule(state.requireValue);
      }
    }
  }

  /// Reads again now and restarts polling (pull to refresh).
  Future<void> refresh() async {
    _polls = 0;
    gaveUp = false;
    final T next = await fetch();
    if (!ref.mounted) {
      return;
    }
    state = AsyncData<T>(next);
    _schedule(next);
  }
}

/// The user's recent reports, polled while any is queued or running.
final AsyncNotifierProvider<ReportsController, List<ReportDto>>
reportsProvider =
    AsyncNotifierProvider.autoDispose<ReportsController, List<ReportDto>>(
      ReportsController.new,
    );

/// See [reportsProvider].
class ReportsController extends AsyncNotifier<List<ReportDto>>
    with _Polling<List<ReportDto>> {
  @override
  Future<List<ReportDto>> build() async {
    ref.watch(currentUserIdProvider);
    _startPolling();
    final List<ReportDto> list = await fetch();
    _schedule(list);
    return list;
  }

  @override
  Future<List<ReportDto>> fetch() => ref.read(reportsApiProvider).list();

  @override
  bool working(List<ReportDto> value) => value.any(isGenerating);

  /// Queues a report and shows it at the top right away.
  Future<ReportDto> create(ReportInput input) async {
    final ReportDto created = await ref.read(reportsApiProvider).create(input);
    if (ref.mounted) {
      final List<ReportDto> now = <ReportDto>[
        created,
        for (final ReportDto r in state.value ?? const <ReportDto>[])
          if (r.id != created.id) r,
      ];
      state = AsyncData<List<ReportDto>>(now);
      _polls = 0;
      _schedule(now);
    }
    return created;
  }
}

/// One report, polled while it is queued or running.
final AsyncNotifierProviderFamily<ReportController, ReportDto, String>
reportProvider = AsyncNotifierProvider.autoDispose
    .family<ReportController, ReportDto, String>(ReportController.new);

/// See [reportProvider].
class ReportController extends AsyncNotifier<ReportDto>
    with _Polling<ReportDto> {
  /// Creates the controller for report [reportId].
  ReportController(this.reportId);

  /// The report.
  final String reportId;

  @override
  Future<ReportDto> build() async {
    ref.watch(currentUserIdProvider);
    _startPolling();
    final ReportDto report = await fetch();
    _schedule(report);
    return report;
  }

  @override
  Future<ReportDto> fetch() => ref.read(reportsApiProvider).get(reportId);

  @override
  bool working(ReportDto value) => isGenerating(value);
}

/// Scheduled reports.
final FutureProvider<List<ScheduleDto>> reportSchedulesProvider =
    FutureProvider.autoDispose<List<ScheduleDto>>((Ref ref) {
      ref.watch(currentUserIdProvider);
      return ref.read(reportsApiProvider).schedules();
    });

/// One schedule (`GET /reports/schedules/{id}`) for its edit screen; a
/// deleted (or unknown) schedule reads as `null`.
final FutureProviderFamily<ScheduleDto?, String> reportScheduleProvider =
    FutureProvider.autoDispose.family<ScheduleDto?, String>((
      Ref ref,
      String id,
    ) async {
      ref.watch(currentUserIdProvider);
      try {
        return await ref.read(reportsApiProvider).schedule(id);
      } on ApiException catch (error) {
        // Unknown, someone else's, or not an ID at all (a mistyped link
        // answers 422 on `path.id`).
        if (error.code == ErrorObjectCode.notFound ||
            error.details.any((Detail d) => d.field == 'path.id')) {
          return null;
        }
        rethrow;
      }
    });

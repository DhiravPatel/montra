import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/features/privacy/data/privacy_api.dart';
import 'package:montra_mobile/features/privacy/domain/privacy_display.dart';

/// Current consent wording versions (`GET /legal`).
final FutureProvider<LegalDto> legalProvider =
    FutureProvider.autoDispose<LegalDto>(
      (Ref ref) => ref.read(privacyApiProvider).legal(),
    );

/// Consents in force.
final FutureProvider<List<ConsentDto>> consentsProvider =
    FutureProvider.autoDispose<List<ConsentDto>>((Ref ref) {
      ref.watch(currentUserIdProvider);
      return ref.read(privacyApiProvider).consents();
    });

/// Deletion status, consequences and what is kept.
final FutureProvider<DeletionDto> deletionProvider =
    FutureProvider.autoDispose<DeletionDto>((Ref ref) {
      ref.watch(currentUserIdProvider);
      return ref.read(privacyApiProvider).deletion();
    });

/// The user's data exports, newest first; re-read every [interval] while
/// one is queued or running (at most [maxPolls] times, then the screen asks
/// to pull to refresh). Polling stops when the screen closes.
final AsyncNotifierProvider<ExportsController, List<ExportDto>>
exportsProvider =
    AsyncNotifierProvider.autoDispose<ExportsController, List<ExportDto>>(
      ExportsController.new,
    );

/// See [exportsProvider].
class ExportsController extends AsyncNotifier<List<ExportDto>> {
  /// Time between two reads while an export is being made.
  static const Duration interval = Duration(seconds: 3);

  /// Reads before polling gives up (about two minutes).
  static const int maxPolls = 40;

  Timer? _timer;
  int _polls = 0;

  /// Whether polling stopped while an export was still being made.
  bool gaveUp = false;

  @override
  Future<List<ExportDto>> build() async {
    ref
      ..watch(currentUserIdProvider)
      ..onDispose(() => _timer?.cancel());
    final List<ExportDto> list = await ref.read(privacyApiProvider).exports();
    _schedule(list);
    return list;
  }

  void _schedule(List<ExportDto> list) {
    _timer?.cancel();
    if (!list.any(exportWorking)) {
      gaveUp = false;
      return;
    }
    if (_polls >= maxPolls) {
      gaveUp = true;
      ref.notifyListeners();
      return;
    }
    _timer = Timer(interval, _poll);
  }

  Future<void> _poll() async {
    _polls++;
    try {
      final List<ExportDto> next = await ref.read(privacyApiProvider).exports();
      if (!ref.mounted) {
        return;
      }
      state = AsyncData<List<ExportDto>>(next);
      _schedule(next);
    } on Object {
      if (ref.mounted && state.hasValue) {
        _schedule(state.requireValue);
      }
    }
  }

  /// Reads again now and restarts polling (pull to refresh).
  Future<void> refresh() async {
    _polls = 0;
    gaveUp = false;
    final List<ExportDto> next = await ref.read(privacyApiProvider).exports();
    if (!ref.mounted) {
      return;
    }
    state = AsyncData<List<ExportDto>>(next);
    _schedule(next);
  }

  /// Shows a newly requested export at the top and starts polling.
  void added(ExportDto export) {
    final List<ExportDto> now = <ExportDto>[
      export,
      for (final ExportDto e in state.value ?? const <ExportDto>[])
        if (e.id != export.id) e,
    ];
    state = AsyncData<List<ExportDto>>(now);
    _polls = 0;
    _schedule(now);
  }
}

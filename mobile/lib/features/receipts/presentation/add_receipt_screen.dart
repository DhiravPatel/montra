import 'dart:async';

import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/api/idempotency.dart';
import 'package:montra_mobile/core/files/file_policy.dart';
import 'package:montra_mobile/core/files/file_source.dart';
import 'package:montra_mobile/core/files/file_uploader.dart';
import 'package:montra_mobile/core/files/file_widgets.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/core/formatting/file_size.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/core/widgets/status_label.dart';
import 'package:montra_mobile/core/widgets/submit_button.dart';
import 'package:montra_mobile/features/receipts/data/receipts_api.dart';

/// Most pages a receipt can have (`ReceiptCreateInput.file_ids` maxItems);
/// one batch of separate receipts uses the same limit.
const int maxReceiptPages = 20;

/// Longest note (`ReceiptCreateInput.notes` maxLength).
const int maxReceiptNoteLength = 1000;

/// How the chosen files become receipts.
enum ReceiptAddMode {
  /// All files are pages of one receipt, in the order shown.
  pages,

  /// Each file becomes its own receipt.
  separate,
}

/// Where a chosen file is in the add flow.
enum ReceiptPageState {
  /// Chosen, not uploaded yet.
  waiting,

  /// Being uploaded.
  uploading,

  /// Uploaded (a ready `receipt` file), not part of a receipt yet.
  uploaded,

  /// The receipt with this page is being created.
  creating,

  /// Uploading it or creating its receipt failed.
  failed,

  /// Part of a receipt.
  done,
}

class _Page {
  _Page(this.id, this.file);

  final int id;
  final PickedFile file;
  ReceiptPageState state = ReceiptPageState.waiting;
  UploadStage? stage;
  double? sent;
  String? error;

  /// The uploaded file, kept so a retry never uploads it again.
  FileDto? uploaded;

  /// Whether a receipt was requested with this page (then it is not deleted
  /// when the screen closes, since the receipt may exist).
  bool claimed = false;
}

/// Adds receipts from photos and files (mirrors the web's add-receipt
/// dialog): each chosen file is a page, shown in order and movable;
/// several files are pages of one receipt (`POST /receipts` with the
/// `file_ids` in order) or separate receipts. Pages are uploaded one by one
/// with their progress in words (purpose `receipt`); creating a receipt
/// uses an Idempotency-Key kept for the same request, so trying again
/// after a lost answer never adds it twice, and uploaded pages are not sent
/// twice. Uploads can be stopped; pages that never became part of a
/// receipt are deleted when the screen closes. Nothing is read
/// automatically.
class AddReceiptScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const AddReceiptScreen({super.key});

  @override
  ConsumerState<AddReceiptScreen> createState() => _AddReceiptScreenState();
}

class _AddReceiptScreenState extends ConsumerState<AddReceiptScreen> {
  final List<_Page> _pages = <_Page>[];
  final TextEditingController _notes = TextEditingController();

  /// One key per request body (see [IdempotentSubmission]), dropped once
  /// it succeeds.
  final Map<String, IdempotentSubmission> _keys =
      <String, IdempotentSubmission>{};
  ReceiptAddMode _mode = ReceiptAddMode.pages;
  int _nextId = 0;
  bool _running = false;
  CancelToken? _cancel;
  String? _error;
  String? _notice;
  ReceiptsApi? _api;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _api = ref.read(receiptsApiProvider);
  }

  @override
  void dispose() {
    _cancel?.cancel();
    _notes.dispose();
    // Pages that never became part of a receipt would only use storage.
    final ReceiptsApi? api = _api;
    if (api != null) {
      for (final _Page page in _pages) {
        final FileDto? file = page.uploaded;
        if (file != null && !page.claimed) {
          unawaited(api.deleteUpload(file.id).catchError((Object _) {}));
        }
      }
    }
    super.dispose();
  }

  List<_Page> get _remaining => <_Page>[
    for (final _Page p in _pages)
      if (p.state != ReceiptPageState.done) p,
  ];

  bool get _hasUnfinished => _remaining.isNotEmpty;

  Future<void> _addFrom(FileOrigin origin) async {
    final AppLocalizations l10n = context.l10n;
    final int room = maxReceiptPages - _pages.length;
    if (room <= 0) {
      showSnack(context, l10n.receiptPagesTooMany(maxReceiptPages));
      return;
    }
    final List<PickedFile> picked;
    try {
      picked = await ref
          .read(fileSourceProvider)
          .pickMany(origin, UploadPurpose.receipt, limit: room);
    } on CameraUnavailable {
      if (mounted) {
        showSnack(context, l10n.fileCameraUnavailable);
      }
      return;
    } on Exception {
      if (mounted) {
        showSnack(context, l10n.errorGenericBody);
      }
      return;
    }
    if (!mounted || picked.isEmpty) {
      return;
    }
    final List<String> problems = <String>[];
    setState(() {
      for (final PickedFile file in picked) {
        final FileProblem? problem = UploadPurpose.receipt.check(
          file.name,
          file.sizeBytes,
        );
        if (problem != null) {
          problems.add(
            l10n.receiptPagesRefused(
              file.name,
              fileProblemMessage(l10n, problem, UploadPurpose.receipt),
            ),
          );
        } else if (_pages.any((_Page p) => _sameFile(p.file, file))) {
          problems.add(l10n.receiptPagesAlreadyAdded(file.name));
        } else if (_pages.length >= maxReceiptPages) {
          problems.add(l10n.receiptPagesTooMany(maxReceiptPages));
          break;
        } else {
          _pages.add(_Page(_nextId++, file));
        }
      }
      _error = null;
      _notice = problems.isEmpty ? null : problems.join('\n');
    });
  }

  static bool _sameFile(PickedFile a, PickedFile b) =>
      a.name == b.name && a.sizeBytes == b.sizeBytes;

  void _move(int from, int to) => setState(() {
    final _Page page = _pages.removeAt(from);
    _pages.insert(to, page);
  });

  void _remove(_Page page) {
    final FileDto? file = page.uploaded;
    if (file != null && !page.claimed) {
      unawaited(
        ref
            .read(receiptsApiProvider)
            .deleteUpload(file.id)
            .catchError((Object _) {}),
      );
    }
    setState(() => _pages.remove(page));
  }

  /// Uploads [page] unless it was uploaded already. Returns its file, or
  /// null when it failed (the error is on the page). Rethrows a stop.
  Future<FileDto?> _upload(_Page page, CancelToken cancel) async {
    final FileDto? done = page.uploaded;
    if (done != null) {
      return done;
    }
    setState(() {
      page
        ..state = ReceiptPageState.uploading
        ..stage = UploadStage.checking
        ..sent = null
        ..error = null;
    });
    try {
      final FileDto file = await ref
          .read(fileUploaderProvider)
          .upload(
            page.file,
            UploadPurpose.receipt,
            cancelToken: cancel,
            onStage: (UploadStage stage) {
              if (mounted) {
                setState(() => page.stage = stage);
              }
            },
            onProgress: (double sent) {
              if (mounted) {
                setState(() => page.sent = sent);
              }
            },
          );
      if (cancel.isCancelled) {
        // Finished just as it was stopped: keep it for next time.
        page
          ..uploaded = file
          ..state = ReceiptPageState.uploaded;
        throw const _Stopped();
      }
      setState(() {
        page
          ..uploaded = file
          ..state = ReceiptPageState.uploaded;
      });
      return file;
    } on _Stopped {
      rethrow;
    } on Object catch (error) {
      if (cancel.isCancelled ||
          (error is ApiException && error.kind == ApiErrorKind.cancelled)) {
        setState(() => page.state = ReceiptPageState.waiting);
        throw const _Stopped();
      }
      if (mounted) {
        setState(() {
          page
            ..state = ReceiptPageState.failed
            ..error = describeError(context.l10n, error);
        });
      }
      return null;
    }
  }

  /// Creates one receipt from [pages] (in order). Returns it, or null when
  /// it failed (the error is on the pages and in [_error]).
  Future<ReceiptDto?> _create(List<_Page> pages, String? note) async {
    final AppLocalizations l10n = context.l10n;
    final List<String> fileIds = <String>[
      for (final _Page p in pages) p.uploaded!.id,
    ];
    final Map<String, Object?> body = ReceiptCreateInput(
      fileIds: fileIds,
      notes: note,
    ).toJson();
    final String draft = fileIds.join(',');
    final IdempotentSubmission key = _keys.putIfAbsent(
      draft,
      IdempotentSubmission.new,
    );
    setState(() {
      for (final _Page p in pages) {
        p
          ..claimed = true
          ..state = ReceiptPageState.creating
          ..error = null;
      }
    });
    try {
      final ReceiptDto receipt = await ref
          .read(receiptsApiProvider)
          .create(fileIds, notes: note, key: key.keyFor(body));
      _keys.remove(draft);
      setState(() {
        for (final _Page p in pages) {
          p.state = ReceiptPageState.done;
        }
      });
      return receipt;
    } on ApiException catch (error) {
      if (error.code == ErrorObjectCode.idempotencyConflict) {
        key.reset();
      }
      // Only a definite refusal frees the pages; after a lost answer the
      // receipt may exist, so they are not deleted.
      final bool refused = error.kind == ApiErrorKind.server;
      final String message = describeError(l10n, error);
      if (mounted) {
        setState(() {
          for (final _Page p in pages) {
            p
              ..claimed = !refused
              ..state = ReceiptPageState.failed
              ..error = message;
          }
          _error = message;
        });
      }
      return null;
    }
  }

  Future<void> _run() async {
    final AppLocalizations l10n = context.l10n;
    if (_running) {
      return;
    }
    final List<_Page> pending = _remaining;
    if (pending.isEmpty) {
      return;
    }
    final GoRouter router = GoRouter.of(context);
    final CancelToken cancel = CancelToken();
    final String note = _notes.text.trim();
    final String? notes = note.isEmpty ? null : note;
    final List<ReceiptDto> created = <ReceiptDto>[];
    int failures = 0;
    setState(() {
      _running = true;
      _cancel = cancel;
      _error = null;
      _notice = null;
    });
    try {
      if (_mode == ReceiptAddMode.pages || _pages.length == 1) {
        final List<_Page> pages = List<_Page>.of(_pages);
        for (final _Page page in pages) {
          if (await _upload(page, cancel) == null) {
            failures++;
          }
        }
        if (failures > 0) {
          _error = l10n.receiptPagesUploadFailed;
        } else {
          final ReceiptDto? receipt = await _create(pages, notes);
          if (receipt != null) {
            created.add(receipt);
          } else {
            failures++;
          }
        }
      } else {
        for (final _Page page in pending) {
          if (await _upload(page, cancel) == null) {
            failures++;
            continue;
          }
          final ReceiptDto? receipt = await _create(<_Page>[page], notes);
          if (receipt != null) {
            created.add(receipt);
          } else {
            failures++;
          }
        }
        if (failures > 0) {
          _error = l10n.receiptPagesSomeFailed(failures);
        }
      }
    } on _Stopped {
      _notice = l10n.receiptPagesStopped;
    } finally {
      if (mounted) {
        setState(() {
          _running = false;
          _cancel = null;
        });
      }
    }
    if (created.isNotEmpty) {
      ref.financeChanged();
    }
    if (!mounted || created.isEmpty || failures > 0 || cancel.isCancelled) {
      return;
    }
    // Everything was added.
    if (created.length == 1) {
      showSnack(context, l10n.receiptAdded);
      unawaited(
        router.pushReplacement(AppRoutes.receiptDetail(created.single.id)),
      );
    } else {
      showSnack(context, l10n.receiptPagesAddedMany(created.length));
      router.pop();
    }
  }

  void _stop() => _cancel?.cancel();

  Future<void> _confirmLeave() async {
    final AppLocalizations l10n = context.l10n;
    final NavigatorState navigator = Navigator.of(context);
    final bool leave = await showConfirmDialog(
      context,
      title: l10n.receiptPagesLeaveTitle,
      body: l10n.receiptPagesLeaveBody,
      confirmLabel: l10n.receiptPagesLeave,
    );
    if (leave && mounted) {
      // Uploaded pages are deleted in dispose().
      _stop();
      navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final bool full = _pages.length >= maxReceiptPages;
    final bool several = _pages.length > 1;
    final int count = _remaining.length;
    final String? error = _error;
    final String? notice = _notice;
    return PopScope(
      canPop: !_hasUnfinished && !_running,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (!didPop) {
          _confirmLeave();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.receiptPagesAddTitle),
          bottom: _running
              ? const PreferredSize(
                  preferredSize: Size.fromHeight(4),
                  child: LinearProgressIndicator(),
                )
              : null,
        ),
        bottomNavigationBar: _pages.isEmpty
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(Insets.md),
                  child: _running
                      ? OutlinedButton.icon(
                          onPressed: _cancel == null ? null : _stop,
                          icon: const Icon(Icons.stop_circle_outlined),
                          label: Text(l10n.receiptPagesStop),
                        )
                      : SubmitButton(
                          label: _mode == ReceiptAddMode.separate && several
                              ? l10n.receiptPagesSaveSeparate(count)
                              : l10n.receiptPagesSave(_pages.length),
                          onPressed: count == 0 ? null : _run,
                        ),
                ),
              ),
        body: ListView(
          padding: const EdgeInsets.all(Insets.md),
          children: <Widget>[
            Text(l10n.receiptPagesIntro(maxReceiptPages)),
            const SizedBox(height: Insets.sm),
            Text(
              acceptedFilesText(l10n, UploadPurpose.receipt),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: Insets.md),
            Wrap(
              spacing: Insets.sm,
              runSpacing: Insets.sm,
              children: <Widget>[
                FilledButton.tonalIcon(
                  onPressed: _running || full
                      ? null
                      : () => _addFrom(FileOrigin.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text(l10n.receiptPagesTakePhoto),
                ),
                OutlinedButton.icon(
                  onPressed: _running || full
                      ? null
                      : () => _addFrom(FileOrigin.photos),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(l10n.receiptPagesChoosePhotos),
                ),
                OutlinedButton.icon(
                  onPressed: _running || full
                      ? null
                      : () => _addFrom(FileOrigin.files),
                  icon: const Icon(Icons.upload_file_outlined),
                  label: Text(l10n.receiptPagesChooseFiles),
                ),
              ],
            ),
            if (full) ...<Widget>[
              const SizedBox(height: Insets.sm),
              Text(l10n.receiptPagesTooMany(maxReceiptPages)),
            ],
            if (error != null) ...<Widget>[
              const SizedBox(height: Insets.md),
              NoticeBanner(
                tone: NoticeTone.error,
                title: l10n.receiptAddFailedTitle,
                message: error,
              ),
            ],
            if (notice != null) ...<Widget>[
              const SizedBox(height: Insets.md),
              NoticeBanner(tone: NoticeTone.warning, message: notice),
            ],
            const SizedBox(height: Insets.md),
            if (_pages.isEmpty)
              MessageStateView(
                icon: Icons.receipt_long_outlined,
                title: l10n.receiptPagesNoneTitle,
                body: l10n.receiptPagesNoneBody,
              )
            else ...<Widget>[
              for (int i = 0; i < _pages.length; i++)
                _PageTile(
                  page: _pages[i],
                  label: _mode == ReceiptAddMode.separate && several
                      ? l10n.receiptPagesFile(i + 1, _pages.length)
                      : l10n.receiptPagesPage(i + 1, _pages.length),
                  onUp: _running || i == 0 ? null : () => _move(i, i - 1),
                  onDown: _running || i == _pages.length - 1
                      ? null
                      : () => _move(i, i + 1),
                  onRemove: _running ? null : () => _remove(_pages[i]),
                ),
              if (several) ...<Widget>[
                const SizedBox(height: Insets.md),
                Semantics(
                  header: true,
                  child: Text(
                    l10n.receiptPagesModeTitle,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                RadioGroup<ReceiptAddMode>(
                  groupValue: _mode,
                  onChanged: (ReceiptAddMode? m) {
                    if (m != null && !_running) {
                      setState(() => _mode = m);
                    }
                  },
                  child: Column(
                    children: <Widget>[
                      RadioListTile<ReceiptAddMode>(
                        contentPadding: EdgeInsets.zero,
                        value: ReceiptAddMode.pages,
                        title: Text(l10n.receiptPagesModePages),
                        subtitle: Text(l10n.receiptPagesModePagesHelp),
                      ),
                      RadioListTile<ReceiptAddMode>(
                        contentPadding: EdgeInsets.zero,
                        value: ReceiptAddMode.separate,
                        title: Text(l10n.receiptPagesModeSeparate),
                        subtitle: Text(l10n.receiptPagesModeSeparateHelp),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: Insets.md),
              TextField(
                controller: _notes,
                enabled: !_running,
                maxLength: maxReceiptNoteLength,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: l10n.optionalLabel(l10n.receiptPagesNotes),
                  helperText: l10n.receiptPagesNotesHelp,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Stopped implements Exception {
  const _Stopped();
}

/// One chosen file: its position, name, size, state in words and the
/// order and remove buttons.
class _PageTile extends StatelessWidget {
  const _PageTile({
    required this.page,
    required this.label,
    required this.onUp,
    required this.onDown,
    required this.onRemove,
  });

  final _Page page;
  final String label;
  final VoidCallback? onUp;
  final VoidCallback? onDown;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final String name = page.file.name;
    final (String text, StatusTone tone, IconData icon) = switch (page.state) {
      ReceiptPageState.waiting => (
        l10n.receiptPagesStateWaiting,
        StatusTone.neutral,
        Icons.schedule,
      ),
      ReceiptPageState.uploading => (
        uploadStageText(
          l10n,
          page.stage ?? UploadStage.checking,
          sent: page.stage == UploadStage.sending ? page.sent : null,
        ),
        StatusTone.neutral,
        Icons.cloud_upload_outlined,
      ),
      ReceiptPageState.uploaded => (
        l10n.receiptPagesStateUploaded,
        StatusTone.positive,
        Icons.cloud_done_outlined,
      ),
      ReceiptPageState.creating => (
        l10n.receiptPagesStateCreating,
        StatusTone.neutral,
        Icons.hourglass_top,
      ),
      ReceiptPageState.failed => (
        l10n.receiptPagesStateFailed(page.error ?? l10n.errorGenericBody),
        StatusTone.caution,
        Icons.error_outline,
      ),
      ReceiptPageState.done => (
        l10n.receiptPagesStateDone,
        StatusTone.positive,
        Icons.check_circle_outline,
      ),
    };
    // Camera photos often have no MIME type; the extension decides.
    final bool image =
        UploadPurpose.receipt.kindOf(name)?.mimeType.startsWith('image/') ??
        false;
    return Card(
      margin: const EdgeInsets.only(bottom: Insets.sm),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Insets.md,
          Insets.sm,
          Insets.xs,
          Insets.xs,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ExcludeSemantics(
                  child: Icon(
                    image
                        ? Icons.image_outlined
                        : Icons.picture_as_pdf_outlined,
                  ),
                ),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(label, style: theme.textTheme.labelLarge),
                      Text(name, style: theme.textTheme.bodyMedium),
                      Text(
                        formatFileSize(l10n, page.file.sizeBytes),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.xs),
            Semantics(
              liveRegion: page.state == ReceiptPageState.failed,
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: StatusLabel(text: text, tone: tone, icon: icon),
              ),
            ),
            if (page.state == ReceiptPageState.uploading) ...<Widget>[
              const SizedBox(height: Insets.xs),
              ExcludeSemantics(
                child: LinearProgressIndicator(
                  value: page.stage == UploadStage.sending ? page.sent : null,
                ),
              ),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                IconButton(
                  tooltip: l10n.receiptPagesMoveUp(name),
                  icon: const Icon(Icons.arrow_upward),
                  onPressed: onUp,
                ),
                IconButton(
                  tooltip: l10n.receiptPagesMoveDown(name),
                  icon: const Icon(Icons.arrow_downward),
                  onPressed: onDown,
                ),
                IconButton(
                  tooltip: l10n.receiptPagesRemove(name),
                  icon: const Icon(Icons.delete_outline),
                  onPressed: onRemove,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

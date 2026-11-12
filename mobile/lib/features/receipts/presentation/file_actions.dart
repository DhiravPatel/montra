import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/router/app_routes.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/api/api_exception.dart';
import 'package:montra_mobile/core/api/generated/models.dart';
import 'package:montra_mobile/core/files/file_export.dart';
import 'package:montra_mobile/core/files/file_policy.dart';
import 'package:montra_mobile/core/files/file_source.dart';
import 'package:montra_mobile/core/files/file_uploader.dart';
import 'package:montra_mobile/core/files/file_widgets.dart';
import 'package:montra_mobile/core/formatting/file_size.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/core/widgets/state_views.dart';
import 'package:montra_mobile/features/receipts/application/receipts_providers.dart';

/// Uploads [file] for [purpose] while a dialog shows the step, the share
/// sent and a cancel button. Returns the ready file, or null when the user
/// cancelled or the upload failed (the reason is shown as a snack bar).
Future<FileDto?> uploadWithProgress(
  BuildContext context, {
  required PickedFile file,
  required UploadPurpose purpose,
  String? groupId,
}) async {
  final AppLocalizations l10n = context.l10n;
  final _UploadOutcome? outcome = await showDialog<_UploadOutcome>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) =>
        _UploadDialog(file: file, purpose: purpose, groupId: groupId),
  );
  if (!context.mounted || outcome == null) {
    return null;
  }
  if (outcome.cancelled) {
    showSnack(context, l10n.uploadCancelled);
    return null;
  }
  final Object? error = outcome.error;
  if (error != null) {
    showSnack(context, describeError(l10n, error));
    return null;
  }
  return outcome.file;
}

class _UploadOutcome {
  const _UploadOutcome({this.file, this.error, this.cancelled = false});

  final FileDto? file;
  final Object? error;
  final bool cancelled;
}

class _UploadDialog extends ConsumerStatefulWidget {
  const _UploadDialog({
    required this.file,
    required this.purpose,
    this.groupId,
  });

  final PickedFile file;
  final UploadPurpose purpose;
  final String? groupId;

  @override
  ConsumerState<_UploadDialog> createState() => _UploadDialogState();
}

class _UploadDialogState extends ConsumerState<_UploadDialog> {
  final CancelToken _cancel = CancelToken();
  UploadStage _stage = UploadStage.checking;
  double? _sent;
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final NavigatorState navigator = Navigator.of(context);
    _UploadOutcome outcome;
    try {
      final FileDto file = await ref
          .read(fileUploaderProvider)
          .upload(
            widget.file,
            widget.purpose,
            groupId: widget.groupId,
            cancelToken: _cancel,
            onStage: (UploadStage stage) {
              if (mounted) {
                setState(() => _stage = stage);
              }
            },
            onProgress: (double sent) {
              if (mounted) {
                setState(() => _sent = sent);
              }
            },
          );
      outcome = _cancelling
          ? const _UploadOutcome(cancelled: true)
          : _UploadOutcome(file: file);
    } on ApiException catch (error) {
      outcome = error.kind == ApiErrorKind.cancelled || _cancelling
          ? const _UploadOutcome(cancelled: true)
          : _UploadOutcome(error: error);
    } on Object catch (error) {
      outcome = _cancelling
          ? const _UploadOutcome(cancelled: true)
          : _UploadOutcome(error: error);
    }
    if (mounted) {
      navigator.pop(outcome);
    }
  }

  void _onCancel() {
    setState(() => _cancelling = true);
    _cancel.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(l10n.receiptUploadTitle),
        content: SingleChildScrollView(
          child: UploadProgress(
            stage: _stage,
            sent: _sent,
            onCancel: _cancelling ? null : _onCancel,
          ),
        ),
      ),
    );
  }
}

/// Shows a private file (a receipt page or an attachment) full screen:
/// images in the app (zoomable), other files with Share and Save.
Future<void> openPrivateFile(
  BuildContext context, {
  required String fileId,
  required String name,
}) => showDialog<void>(
  context: context,
  builder: (BuildContext dialogContext) => Dialog.fullscreen(
    child: PrivateFileViewer(fileId: fileId, name: name),
  ),
);

/// The full-screen viewer behind [openPrivateFile].
class PrivateFileViewer extends ConsumerWidget {
  /// Creates the viewer.
  const PrivateFileViewer({
    required this.fileId,
    required this.name,
    super.key,
  });

  /// The file.
  final String fileId;

  /// Name shown in the title.
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<DownloadedFile> file = ref.watch(
      privateFileProvider(fileId),
    );
    final DownloadedFile? loaded = file.value;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l10n.actionClose,
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(name, overflow: TextOverflow.ellipsis),
      ),
      body: SafeArea(
        child: file.hasError && !file.isLoading
            ? ErrorStateView(
                error: file.error!,
                onRetry: () => ref.invalidate(privateFileProvider(fileId)),
              )
            : loaded == null
            ? LoadingStateView(label: l10n.fileDownloading)
            : _FileBody(file: loaded),
      ),
      bottomNavigationBar: loaded == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(Insets.md),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: Insets.sm,
                  runSpacing: Insets.sm,
                  children: <Widget>[
                    OutlinedButton.icon(
                      onPressed: () => saveDownloadedFile(context, ref, loaded),
                      icon: const Icon(Icons.download_outlined),
                      label: Text(l10n.fileSave),
                    ),
                    FilledButton.icon(
                      onPressed: () =>
                          shareDownloadedFile(context, ref, loaded),
                      icon: const Icon(Icons.share_outlined),
                      label: Text(l10n.fileShare),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _FileBody extends StatelessWidget {
  const _FileBody({required this.file});

  final DownloadedFile file;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    if (file.isImage) {
      return InteractiveViewer(
        maxScale: 5,
        child: Center(
          child: Image.memory(
            file.bytes,
            semanticLabel: l10n.filePreviewLabel(file.name),
            errorBuilder: (BuildContext context, Object error, StackTrace? _) =>
                _OtherFile(file: file),
          ),
        ),
      );
    }
    return _OtherFile(file: file);
  }
}

class _OtherFile extends StatelessWidget {
  const _OtherFile({required this.file});

  final DownloadedFile file;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return MessageStateView(
      icon: file.isPdf
          ? Icons.picture_as_pdf_outlined
          : Icons.insert_drive_file_outlined,
      title: file.name,
      body: <String>[
        if (file.isPdf) l10n.receiptPdfHelp else l10n.receiptFileHelp,
        formatFileSize(l10n, file.bytes.length),
      ].join('\n'),
    );
  }
}

/// Leaves a receipt sub-screen (review, match, record) for the receipt's
/// page: back when it was opened from there, otherwise straight to it (a
/// deep link).
void leaveToReceipt(BuildContext context, String receiptId) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(AppRoutes.receiptDetail(receiptId));
  }
}

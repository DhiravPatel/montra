import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:montra_mobile/app/l10n/l10n.dart';
import 'package:montra_mobile/app/theme/app_theme.dart';
import 'package:montra_mobile/core/files/file_export.dart';
import 'package:montra_mobile/core/files/file_policy.dart';
import 'package:montra_mobile/core/files/file_source.dart';
import 'package:montra_mobile/core/files/file_uploader.dart';
import 'package:montra_mobile/core/formatting/file_size.dart';
import 'package:montra_mobile/core/widgets/dialogs.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';

/// "JPG, PNG, WEBP, HEIC, PDF, up to 15 MB" for [purpose].
String acceptedFilesText(AppLocalizations l10n, UploadPurpose purpose) =>
    l10n.fileAcceptedTypes(
      acceptedTypesText(purpose),
      formatFileSize(l10n, purpose.maxBytes),
    );

/// Asks where to take a file for [purpose] from: the camera and the photo
/// library are offered when the purpose takes images ([camera] can turn the
/// camera off), files always. Returns null when dismissed.
Future<FileOrigin?> showFileOriginSheet(
  BuildContext context, {
  required UploadPurpose purpose,
  bool camera = true,
  String? title,
}) => showModalBottomSheet<FileOrigin>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (BuildContext sheetContext) {
    final AppLocalizations l10n = sheetContext.l10n;
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.md,
                0,
                Insets.md,
                Insets.sm,
              ),
              child: Semantics(
                header: true,
                child: Text(
                  title ?? l10n.fileSourceTitle,
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
              ),
            ),
            if (purpose.acceptsImages && camera)
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: Text(l10n.fileSourceCamera),
                onTap: () => Navigator.of(sheetContext).pop(FileOrigin.camera),
              ),
            if (purpose.acceptsImages)
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(l10n.fileSourcePhotos),
                onTap: () => Navigator.of(sheetContext).pop(FileOrigin.photos),
              ),
            ListTile(
              leading: const Icon(Icons.upload_file_outlined),
              title: Text(l10n.fileSourceFiles),
              subtitle: Text(acceptedFilesText(l10n, purpose)),
              onTap: () => Navigator.of(sheetContext).pop(FileOrigin.files),
            ),
            const SizedBox(height: Insets.sm),
          ],
        ),
      ),
    );
  },
);

/// Lets the user choose a file for [purpose] ([origin], or asked with
/// [showFileOriginSheet]) and checks it against the purpose's limits.
/// Problems (camera unavailable, too large, wrong type, empty) are shown as
/// a snack bar and give null, as does cancelling.
Future<PickedFile?> pickFileFor(
  BuildContext context,
  WidgetRef ref, {
  required UploadPurpose purpose,
  FileOrigin? origin,
  bool camera = true,
}) async {
  final FileSource source = ref.read(fileSourceProvider);
  final AppLocalizations l10n = context.l10n;
  final FileOrigin? chosen =
      origin ??
      await showFileOriginSheet(context, purpose: purpose, camera: camera);
  if (chosen == null || !context.mounted) {
    return null;
  }
  final PickedFile? file;
  try {
    file = await source.pick(chosen, purpose);
  } on CameraUnavailable {
    if (context.mounted) {
      showSnack(context, l10n.fileCameraUnavailable);
    }
    return null;
  } on Exception {
    if (context.mounted) {
      showSnack(context, l10n.errorGenericBody);
    }
    return null;
  }
  if (file == null || !context.mounted) {
    return null;
  }
  final FileProblem? problem = purpose.check(file.name, file.sizeBytes);
  if (problem != null) {
    showSnack(context, fileProblemMessage(l10n, problem, purpose));
    return null;
  }
  return file;
}

/// What an upload is doing, as text: "Uploading… 40%".
String uploadStageText(
  AppLocalizations l10n,
  UploadStage stage, {
  double? sent,
}) => switch (stage) {
  UploadStage.checking => l10n.uploadStageChecking,
  UploadStage.authorizing => l10n.uploadStageAuthorizing,
  UploadStage.sending when sent != null => l10n.uploadStageSendingPercent(
    (sent.clamp(0, 1) * 100).round(),
  ),
  UploadStage.sending => l10n.uploadStageSending,
  UploadStage.finishing => l10n.uploadStageFinishing,
};

/// Progress of an upload: the step in words (announced to screen readers),
/// a progress bar (determinate while bytes are sent) and an optional
/// cancel button.
class UploadProgress extends StatelessWidget {
  /// Creates the view.
  const UploadProgress({
    required this.stage,
    this.sent,
    this.onCancel,
    super.key,
  });

  /// Current step.
  final UploadStage stage;

  /// Share of bytes sent (0–1) while [UploadStage.sending].
  final double? sent;

  /// Cancels the upload; no button when null.
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final double? value = stage == UploadStage.sending ? sent : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          liveRegion: true,
          child: Text(uploadStageText(l10n, stage, sent: value)),
        ),
        const SizedBox(height: Insets.sm),
        ExcludeSemantics(child: LinearProgressIndicator(value: value)),
        if (onCancel != null) ...<Widget>[
          const SizedBox(height: Insets.sm),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: onCancel,
              icon: const Icon(Icons.close),
              label: Text(l10n.uploadCancel),
            ),
          ),
        ],
      ],
    );
  }
}

/// Opens the share sheet for [file]; failures are shown as a snack bar.
Future<void> shareDownloadedFile(
  BuildContext context,
  WidgetRef ref,
  DownloadedFile file,
) async {
  final AppLocalizations l10n = context.l10n;
  final RenderBox? box = context.findRenderObject() as RenderBox?;
  final Rect? origin = box == null || !box.hasSize
      ? null
      : box.localToGlobal(Offset.zero) & box.size;
  try {
    await ref.read(fileExporterProvider).share(file, origin: origin);
  } on Exception {
    if (context.mounted) {
      showSnack(context, l10n.errorGenericBody);
    }
  }
}

/// Saves [file] where the user chooses; says "Saved." when done.
Future<void> saveDownloadedFile(
  BuildContext context,
  WidgetRef ref,
  DownloadedFile file,
) async {
  final AppLocalizations l10n = context.l10n;
  try {
    final bool saved = await ref.read(fileExporterProvider).save(file);
    if (saved && context.mounted) {
      showSnack(context, l10n.fileSaved);
    }
  } on Exception {
    if (context.mounted) {
      showSnack(context, l10n.errorGenericBody);
    }
  }
}

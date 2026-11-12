import 'dart:async';

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
import 'package:montra_mobile/core/files/file_widgets.dart';
import 'package:montra_mobile/core/finance/finance_refresh.dart';
import 'package:montra_mobile/core/widgets/banners.dart';
import 'package:montra_mobile/core/widgets/error_messages.dart';
import 'package:montra_mobile/core/widgets/layout.dart';
import 'package:montra_mobile/core/widgets/selector_field.dart';
import 'package:montra_mobile/core/widgets/submit_button.dart';
import 'package:montra_mobile/features/accounts/application/accounts_providers.dart';
import 'package:montra_mobile/features/accounts/presentation/account_picker.dart';
import 'package:montra_mobile/features/imports/data/imports_api.dart';
import 'package:montra_mobile/features/receipts/presentation/file_actions.dart';

/// Starts a statement import: choose the account, then the bank's CSV,
/// XLSX or OFX file (uploaded with the `statement_import` purpose), and
/// `POST /imports`. The import then opens: the server reads the file in the
/// background and asks for the columns when it cannot tell them itself.
class ImportWizardScreen extends ConsumerStatefulWidget {
  /// Creates the wizard, optionally starting with [accountId] chosen.
  const ImportWizardScreen({this.accountId, super.key});

  /// Preselected account.
  final String? accountId;

  @override
  ConsumerState<ImportWizardScreen> createState() => _ImportWizardScreenState();
}

class _ImportWizardScreenState extends ConsumerState<ImportWizardScreen> {
  late String? _accountId = widget.accountId;
  PickedFile? _file;

  /// The upload of [_file], kept so a retry after a refused import does not
  /// upload the same file again.
  FileDto? _uploaded;

  /// One key per account and file: a retry after a lost answer returns the
  /// import created the first time instead of a second one.
  final IdempotentSubmission _createKey = IdempotentSubmission();
  String? _accountError;
  String? _fileError;
  String? _error;
  String? _requestId;

  static const UploadPurpose _purpose = UploadPurpose.statementImport;

  Future<void> _pickAccount() async {
    final AccountDto? picked = await showAccountPicker(
      context,
      selectedId: _accountId,
      title: context.l10n.importAccountLabel,
    );
    if (picked != null && mounted) {
      setState(() {
        _accountId = picked.id;
        _accountError = null;
      });
    }
  }

  Future<void> _pickFile() async {
    final PickedFile? picked = await pickFileFor(
      context,
      ref,
      purpose: _purpose,
      origin: FileOrigin.files,
    );
    if (picked != null && mounted) {
      setState(() {
        _file = picked;
        _uploaded = null;
        _fileError = null;
      });
    }
  }

  Future<void> _start() async {
    final AppLocalizations l10n = context.l10n;
    final GoRouter router = GoRouter.of(context);
    setState(() {
      _error = null;
      _requestId = null;
      _accountError = _accountId == null ? l10n.importAccountRequired : null;
      _fileError = _file == null ? l10n.importFileRequired : null;
    });
    final String? accountId = _accountId;
    final PickedFile? picked = _file;
    if (accountId == null || picked == null) {
      return;
    }
    final FileDto? file =
        _uploaded ??
        await uploadWithProgress(context, file: picked, purpose: _purpose);
    if (file == null || !mounted) {
      return;
    }
    _uploaded = file;
    try {
      final ImportBatchDto batch = await ref
          .read(importsApiProvider)
          .create(
            accountId: accountId,
            fileId: file.id,
            key: _createKey.keyFor(<String, Object?>{
              'account_id': accountId,
              'file_id': file.id,
            }),
          );
      _createKey.reset();
      ref.financeChanged();
      unawaited(router.pushReplacement(AppRoutes.importDetail(batch.id)));
    } on ApiException catch (error) {
      if (error.code == ErrorObjectCode.idempotencyConflict) {
        _createKey.reset();
      }
      if (mounted) {
        setState(() {
          _error = describeError(l10n, error);
          _requestId = requestIdOf(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final Map<String, AccountDto> accounts = ref.watch(accountIndexProvider);
    final AccountDto? account = _accountId == null
        ? null
        : accounts[_accountId];
    final PickedFile? file = _file;
    final String? error = _error;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.importWizardTitle)),
      body: ScrollableContent(
        children: <Widget>[
          Text(l10n.importWizardIntro),
          const SizedBox(height: Insets.md),
          NoticeBanner(message: l10n.importFormatsNote),
          const SizedBox(height: Insets.md),
          if (error != null) ...<Widget>[
            NoticeBanner(
              tone: NoticeTone.error,
              message: error,
              requestId: _requestId,
            ),
            const SizedBox(height: Insets.md),
          ],
          FormSectionHeader(l10n.importStepAccount),
          SelectorField(
            label: l10n.importAccountLabel,
            icon: Icons.account_balance_outlined,
            value: account == null
                ? null
                : '${account.name} · ${account.currency}',
            placeholder: l10n.importChooseAccount,
            helperText: l10n.importAccountHelp,
            errorText: _accountError,
            onTap: _pickAccount,
          ),
          const SizedBox(height: Insets.md),
          FormSectionHeader(l10n.importStepFile),
          SelectorField(
            label: l10n.importFileLabel,
            icon: Icons.upload_file_outlined,
            value: file?.name,
            placeholder: l10n.importChooseFile,
            helperText: acceptedFilesText(l10n, _purpose),
            errorText: _fileError,
            onTap: _pickFile,
          ),
          const SizedBox(height: Insets.lg),
          SubmitButton(
            label: l10n.importStart,
            icon: Icons.upload,
            onPressed: _start,
          ),
          const SizedBox(height: Insets.lg),
        ],
      ),
    );
  }
}

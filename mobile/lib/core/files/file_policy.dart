import 'package:flutter/foundation.dart';

/// A file type the server accepts, detected from the content
/// (`backend/internal/files/sniff.go`).
@immutable
class FileKind {
  /// Creates the kind.
  const FileKind(this.mimeType, this.extension);

  /// Canonical MIME type.
  final String mimeType;

  /// Canonical extension, without the dot.
  final String extension;

  static const FileKind jpeg = FileKind('image/jpeg', 'jpg');
  static const FileKind png = FileKind('image/png', 'png');
  static const FileKind webp = FileKind('image/webp', 'webp');
  static const FileKind heic = FileKind('image/heic', 'heic');
  static const FileKind pdf = FileKind('application/pdf', 'pdf');
  static const FileKind csv = FileKind('text/csv', 'csv');
  static const FileKind xlsx = FileKind(
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'xlsx',
  );
  static const FileKind ofx = FileKind('application/x-ofx', 'ofx');

  /// Every kind the app can upload.
  static const List<FileKind> all = <FileKind>[
    jpeg,
    png,
    webp,
    heic,
    pdf,
    csv,
    xlsx,
    ofx,
  ];

  /// Other spellings the server maps to a canonical extension
  /// (`allowedExt` in `files.go`).
  static const Map<String, String> aliases = <String, String>{
    'jpeg': 'jpg',
    'heif': 'heic',
    'qfx': 'ofx',
    'txt': 'csv',
  };

  /// The kind of a file name's extension, or null when unknown.
  static FileKind? ofName(String filename) {
    final String ext = extensionOf(filename);
    final String canonical = aliases[ext] ?? ext;
    for (final FileKind kind in all) {
      if (kind.extension == canonical) {
        return kind;
      }
    }
    return null;
  }

  /// The lower-case extension of [filename] without the dot ('' if none).
  static String extensionOf(String filename) {
    final int dot = filename.lastIndexOf('.');
    if (dot < 0 || dot == filename.length - 1) {
      return '';
    }
    return filename.substring(dot + 1).toLowerCase();
  }

  @override
  bool operator ==(Object other) =>
      other is FileKind &&
      other.mimeType == mimeType &&
      other.extension == extension;

  @override
  int get hashCode => Object.hash(mimeType, extension);

  @override
  String toString() => 'FileKind($extension)';
}

/// Why a picked file cannot be uploaded for a purpose (checked before any
/// request, so nothing is sent).
enum FileProblem {
  /// The file has no content.
  empty,

  /// The file is larger than the purpose allows.
  tooLarge,

  /// The file type is not accepted for the purpose.
  unsupportedType,
}

/// What an upload is for: `UploadIntentInput.purpose`. The limits mirror
/// `Policies` in `backend/internal/files/files.go`; the server checks them
/// again from the content.
enum UploadPurpose {
  /// A receipt photo or PDF.
  receipt('receipt', 15 * _mb, _imagesAndPdf),

  /// A bill's document.
  billDocument('bill_document', 15 * _mb, _imagesAndPdf),

  /// A file attached to a transaction.
  transactionAttachment('transaction_attachment', 15 * _mb, _imagesAndPdf),

  /// A file attached to a goal.
  goalAttachment('goal_attachment', 15 * _mb, _imagesAndPdf),

  /// A subscription invoice.
  subscriptionInvoice('subscription_invoice', 15 * _mb, <FileKind>[
    FileKind.pdf,
    FileKind.jpeg,
    FileKind.png,
  ]),

  /// A bank statement to import. The server also takes PDF statements, but
  /// reading them needs AI extraction, which Montra does not use, so the
  /// app offers CSV, XLSX and OFX only.
  statementImport('statement_import', 10 * _mb, <FileKind>[
    FileKind.csv,
    FileKind.xlsx,
    FileKind.ofx,
  ]),

  /// A file attached to a group expense or settlement (needs the group).
  groupAttachment('group_attachment', 15 * _mb, _imagesAndPdf),

  /// A profile photo.
  avatar('avatar', 5 * _mb, <FileKind>[
    FileKind.jpeg,
    FileKind.png,
    FileKind.webp,
  ]);

  const UploadPurpose(this.wire, this.maxBytes, this.kinds);

  /// The contract value.
  final String wire;

  /// Largest accepted file, in bytes.
  final int maxBytes;

  /// Accepted kinds.
  final List<FileKind> kinds;

  /// Extensions to offer in a file picker (canonical ones plus aliases).
  List<String> get pickerExtensions => <String>[
    for (final FileKind kind in kinds) kind.extension,
    for (final MapEntry<String, String> alias in FileKind.aliases.entries)
      if (kinds.any((FileKind k) => k.extension == alias.value)) alias.key,
  ];

  /// Whether photos (camera or library) fit this purpose.
  bool get acceptsImages => kinds.contains(FileKind.jpeg);

  /// The accepted kind for [filename], or null.
  FileKind? kindOf(String filename) {
    final FileKind? kind = FileKind.ofName(filename);
    return kind != null && kinds.contains(kind) ? kind : null;
  }

  /// The first problem with a file named [filename] of [sizeBytes], or
  /// null when it can be uploaded.
  FileProblem? check(String filename, int sizeBytes) {
    if (sizeBytes <= 0) {
      return FileProblem.empty;
    }
    if (kindOf(filename) == null) {
      return FileProblem.unsupportedType;
    }
    if (sizeBytes > maxBytes) {
      return FileProblem.tooLarge;
    }
    return null;
  }
}

const int _mb = 1024 * 1024;

const List<FileKind> _imagesAndPdf = <FileKind>[
  FileKind.jpeg,
  FileKind.png,
  FileKind.webp,
  FileKind.heic,
  FileKind.pdf,
];

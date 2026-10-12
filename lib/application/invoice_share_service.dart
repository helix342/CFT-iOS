/// Thin share/copy coordinator for a finalized invoice (task 12.3).
///
/// `InvoiceShareService` wires together the two pure value→payload generators —
/// [DocxExportService] (the editable Word document bytes + filename) and
/// [WhatsAppExportService] (the WhatsApp-ready bill text) — and exposes the
/// three user actions Requirement 15.4 names:
///
///   * **Share invoice file** — the `.docx` bytes under the human-readable
///     filename, offered through the iOS share sheet (`shareInvoiceFile`);
///   * **Share bill text** — the WhatsApp text, offered through the share sheet
///     with the generic iOS share sheet as the fallback when WhatsApp is absent
///     (Requirement 15.5) (`shareBillText`); and
///   * **Copy bill text** — the same WhatsApp text copied to the clipboard
///     (`copyBillText`).
///
/// A **PDF** export is an **optional extra only**: it must never replace the
/// DOCX or WhatsApp-text exports (Requirement 15.7). This coordinator therefore
/// does *not* generate a PDF — it exposes an opt-in seam (`sharePdfFile`) that
/// is only usable when the caller injects a [PdfExporter]. Leaving the exporter
/// unset is the normal case and keeps PDF strictly additive.
///
/// ## Immutability: sharing never mutates stock or the invoice (Req 15.6)
///
/// Every action here reads the already-finalized, immutable [InvoiceSnapshot]
/// and nothing else. The coordinator performs **no** allocation, finalize,
/// billing, or database work; it never calls back into the services that
/// deduct stock. Sharing or copying the same snapshot any number of times
/// produces identical payloads and leaves the snapshot untouched (Requirement
/// 15.6; snapshot immutability). This is a hard invariant and the unit tests
/// pin it directly.
///
/// ## Headless-testable device seam
///
/// The real iOS share sheet and the system clipboard are device plugins that
/// cannot run under `flutter test` on Windows. They are abstracted behind the
/// injectable [ShareBackend] interface so the coordinator stays a pure
/// orchestrator: tests inject a fake backend and assert on the payloads handed
/// to it, while production injects the platform adapter in
/// `invoice_share_backend_platform.dart`. The real plugin wiring
/// (share-sheet file/text share) is **device-verified-later** (task 17;
/// Requirements 14.7, 15.5, 21.24) and is explicitly *not* asserted here.
///
/// Architecture note: this service lives in the application layer. It depends
/// only on the pure snapshot/export types and the [ShareBackend] abstraction;
/// it does **not** import `package:flutter/*`, so it compiles and runs headless.
/// The concrete plugin adapter is the only Flutter-coupled piece and lives in
/// its own file.
library;

import 'package:meta/meta.dart';

import 'package:wood_cft/application/docx_export_service.dart';
import 'package:wood_cft/application/whatsapp_export_service.dart';

/// A file payload to hand to the share sheet: the raw [bytes], the
/// human-readable [fileName], and its [mimeType].
///
/// Immutable; carries only the already-generated export bytes, so passing it to
/// a [ShareBackend] can never mutate the source snapshot.
@immutable
class ShareFilePayload {
  /// Creates a share-file payload.
  const ShareFilePayload({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
  });

  /// The exported document bytes (e.g. the OOXML `.docx` package).
  final List<int> bytes;

  /// The human-readable filename to attach the bytes under (Requirement 14.6).
  final String fileName;

  /// The MIME type of [bytes] (e.g. the WordprocessingML document type).
  final String mimeType;
}

/// The device seam the coordinator drives: the iOS share sheet and the system
/// clipboard.
///
/// Production supplies a plugin-backed adapter
/// (`invoice_share_backend_platform.dart`); tests supply [FakeShareBackend].
/// Every method is a one-way, side-effecting hand-off of an already-built
/// payload — none of them read or return invoice/stock state, so no
/// implementation can re-deduct stock (Requirement 15.6).
abstract interface class ShareBackend {
  /// Offers [payload] through the iOS share sheet (file share).
  Future<void> shareFile(ShareFilePayload payload);

  /// Offers [text] through the iOS share sheet (text share), falling back to
  /// the generic share sheet when WhatsApp is absent (Requirement 15.5).
  Future<void> shareText(String text);

  /// Copies [text] to the system clipboard.
  Future<void> copyText(String text);
}

/// Optional, opt-in PDF generator seam.
///
/// PDF is an **optional extra** that must never replace DOCX/WhatsApp text
/// (Requirement 15.7). The coordinator only offers [InvoiceShareService.sharePdfFile]
/// when such an exporter is injected; the default is `null` (no PDF).
abstract interface class PdfExporter {
  /// Builds the PDF bytes for [snapshot].
  List<int> buildPdf(InvoiceSnapshot snapshot);

  /// Builds the human-readable PDF filename for [snapshot].
  String buildFileName(InvoiceSnapshot snapshot);
}

/// Coordinates the Share-file / Share-text / Copy-text actions over a finalized
/// invoice snapshot (task 12.3).
///
/// Holds no mutable state; a single instance can be reused. All work is driven
/// off the immutable [InvoiceSnapshot] passed to each method.
class InvoiceShareService {
  /// Creates the coordinator.
  ///
  /// [backend] is the device seam (share sheet + clipboard). [docx] and
  /// [whatsApp] default to the shared pure generators. [pdfExporter] is the
  /// optional PDF seam and is left `null` unless a caller opts in
  /// (Requirement 15.7).
  const InvoiceShareService({
    required this.backend,
    this.docx = const DocxExportService(),
    this.whatsApp = const WhatsAppExportService(),
    this.pdfExporter,
  });

  /// The WordprocessingML `.docx` MIME type.
  static const String docxMimeType =
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document';

  /// The PDF MIME type (only used when a [PdfExporter] is injected).
  static const String pdfMimeType = 'application/pdf';

  /// The device seam (iOS share sheet + system clipboard).
  final ShareBackend backend;

  /// The pure OOXML `.docx` generator.
  final DocxExportService docx;

  /// The pure WhatsApp-text generator.
  final WhatsAppExportService whatsApp;

  /// The optional PDF generator seam; `null` means no PDF (Requirement 15.7).
  final PdfExporter? pdfExporter;

  /// Whether a PDF export action is available (an exporter was injected).
  ///
  /// PDF is optional-extra only (Requirement 15.7); this is `false` by default.
  bool get isPdfAvailable => pdfExporter != null;

  /// Share invoice file — offers the `.docx` bytes under their human-readable
  /// filename through the share sheet (Requirements 15.4, 14.7).
  ///
  /// Builds the bytes/filename from [snapshot] only; never re-deducts stock or
  /// mutates the invoice (Requirement 15.6).
  Future<void> shareInvoiceFile(InvoiceSnapshot snapshot) {
    final payload = ShareFilePayload(
      bytes: docx.buildDocx(snapshot),
      fileName: docx.buildFileName(snapshot),
      mimeType: docxMimeType,
    );
    return backend.shareFile(payload);
  }

  /// Share bill text — offers the WhatsApp text through the share sheet, with
  /// the generic iOS share sheet as the fallback when WhatsApp is absent
  /// (Requirements 15.4, 15.5).
  ///
  /// Reads [snapshot] only; never re-deducts stock (Requirement 15.6).
  Future<void> shareBillText(InvoiceSnapshot snapshot) {
    return backend.shareText(whatsApp.buildMessage(snapshot));
  }

  /// Copy bill text — copies the WhatsApp text to the clipboard (Requirement
  /// 15.4).
  ///
  /// Reads [snapshot] only; never re-deducts stock (Requirement 15.6).
  Future<void> copyBillText(InvoiceSnapshot snapshot) {
    return backend.copyText(whatsApp.buildMessage(snapshot));
  }

  /// Share a PDF — **optional extra only** (Requirement 15.7).
  ///
  /// Available only when a [PdfExporter] was injected ([isPdfAvailable]);
  /// otherwise throws [StateError] so a PDF can never silently stand in for the
  /// DOCX/WhatsApp exports. Reads [snapshot] only; never re-deducts stock
  /// (Requirement 15.6).
  Future<void> sharePdfFile(InvoiceSnapshot snapshot) {
    final exporter = pdfExporter;
    if (exporter == null) {
      throw StateError(
        'PDF export is an optional extra and is not configured; '
        'use shareInvoiceFile (DOCX) or shareBillText (WhatsApp) instead.',
      );
    }
    final payload = ShareFilePayload(
      bytes: exporter.buildPdf(snapshot),
      fileName: exporter.buildFileName(snapshot),
      mimeType: pdfMimeType,
    );
    return backend.shareFile(payload);
  }
}

/// In-memory [ShareBackend] for headless tests.
///
/// Records what the coordinator hands to the share sheet / clipboard instead of
/// touching a device, so unit tests can assert the DOCX bytes + filename, the
/// WhatsApp text, and the copied text without an iPhone (and confirm no action
/// mutates the snapshot). Not used in production.
class FakeShareBackend implements ShareBackend {
  /// The file payloads passed to [shareFile], in call order.
  final List<ShareFilePayload> sharedFiles = <ShareFilePayload>[];

  /// The texts passed to [shareText], in call order.
  final List<String> sharedTexts = <String>[];

  /// The texts passed to [copyText], in call order.
  final List<String> copiedTexts = <String>[];

  @override
  Future<void> shareFile(ShareFilePayload payload) async {
    sharedFiles.add(payload);
  }

  @override
  Future<void> shareText(String text) async {
    sharedTexts.add(text);
  }

  @override
  Future<void> copyText(String text) async {
    copiedTexts.add(text);
  }
}

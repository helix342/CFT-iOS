/// Production [ShareBackend] adapter — the only Flutter/device-coupled piece of
/// the share wiring (task 12.3; FIX 3).
///
/// This thin adapter maps the coordinator's three one-way actions onto the
/// device:
///
///   * **Copy bill text** uses Flutter's built-in [Clipboard.setData] (part of
///     `package:flutter/services.dart`, no plugin dependency).
///   * **Share invoice file** writes the already-built `payload.bytes` to a
///     temporary file named `payload.fileName` (under the OS temp directory
///     from `path_provider`) and hands that file to the OS share sheet via
///     `share_plus` ([Share.shareXFiles]).
///   * **Share bill text** hands the WhatsApp-ready text straight to the share
///     sheet via `share_plus` ([Share.share]); the OS presents WhatsApp when
///     installed and the generic share sheet otherwise (Requirement 15.5).
///
/// Nothing here reads or mutates invoice/stock state — it only forwards an
/// already-built payload to the OS — so this adapter cannot re-deduct stock
/// (Requirement 15.6).
///
/// Because this file imports `package:flutter/*` and the platform plugins, it
/// is intentionally separated from the pure `invoice_share_service.dart`
/// coordinator, which stays Flutter-free and fully unit-testable with
/// [FakeShareBackend]. On the Android emulator / Windows the share sheet may be
/// limited, but the code is correct; the coordinator is unit-tested against the
/// fake backend.
library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:wood_cft/application/invoice_share_service.dart';

/// Device-backed [ShareBackend] used in production.
///
/// All three actions are live: clipboard copy via the Flutter SDK, and file /
/// text sharing via `share_plus` + `path_provider`.
class PlatformShareBackend implements ShareBackend {
  /// Creates the platform share backend.
  const PlatformShareBackend();

  @override
  Future<void> shareFile(ShareFilePayload payload) async {
    // Write the export bytes to a temp file under the human-readable filename,
    // then present the OS share sheet with that file + its MIME type.
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}${payload.fileName}')
      ..createSync(recursive: true);
    await file.writeAsBytes(Uint8List.fromList(payload.bytes), flush: true);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: payload.mimeType, name: payload.fileName)],
    );
  }

  @override
  Future<void> shareText(String text) async {
    // Hand the text to the OS share sheet; WhatsApp appears when installed,
    // otherwise the generic share sheet is the fallback (Requirement 15.5).
    await Share.share(text);
  }

  @override
  Future<void> copyText(String text) {
    // Clipboard is part of the Flutter SDK (no plugin), so copy works directly.
    return Clipboard.setData(ClipboardData(text: text));
  }
}

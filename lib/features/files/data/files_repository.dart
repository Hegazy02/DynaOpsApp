/// `FilesRepository`: decodes base64 payloads off the UI isolate and saves
/// them to Downloads, shares them (`share_plus`), prints PDFs (`printing`) or
/// opens them in another app (`open_filex`) (D14, §5.4). File names are
/// sanitised so they can never escape the target folder.
///
/// Why it exists: the WebView cannot hand `blob:` downloads to Android;
/// Angular sends the bytes over the bridge and this does the platform work.
/// Status: used — registered in `service_locator.dart`; called by
/// `FilesHandler`; `shareText` by the diagnostics screen.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/network/failure.dart';

/// Save / share / print / open base64 payloads sent by Angular (D14, §5.4).
class FilesRepository {
  /// Shares plain text as a `.txt` file (diagnostics log export, §15).
  Future<void> shareText({required String name, required String text}) async {
    try {
      final file = File(p.join((await getTemporaryDirectory()).path, _safeName(name)));
      await file.writeAsString(text, flush: true);
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: 'text/plain')]));
    } catch (e) {
      throw PlatformFailure('Share failed: $e');
    }
  }

  /// Writes the file under the app's downloads folder and returns its path.
  Future<String> save({required String name, required String base64}) async {
    final dir = await _downloadsDir();
    return (await _write(dir, name, base64)).path;
  }

  Future<void> share({required String name, required String mimeType, required String base64}) async {
    final file = await _write(await getTemporaryDirectory(), name, base64);
    try {
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path, mimeType: mimeType)], fileNameOverrides: [_safeName(name)]),
      );
    } catch (e) {
      throw PlatformFailure('Share failed: $e');
    }
  }

  Future<void> print({required String name, required String base64Pdf}) async {
    final bytes = await _decode(base64Pdf);
    try {
      await Printing.layoutPdf(name: _safeName(name), onLayout: (_) async => bytes);
    } catch (e) {
      throw PlatformFailure('Print failed: $e');
    }
  }

  Future<void> open({required String name, required String mimeType, required String base64}) async {
    final file = await _write(await getTemporaryDirectory(), name, base64);
    final result = await OpenFilex.open(file.path, type: mimeType);
    switch (result.type) {
      case ResultType.done:
        return;
      case ResultType.noAppToOpen:
        throw UnsupportedFailure('No app can open $mimeType files.');
      case ResultType.fileNotFound:
      case ResultType.permissionDenied:
      case ResultType.error:
        throw PlatformFailure('Could not open the file: ${result.message}');
    }
  }

  Future<File> _write(Directory dir, String name, String base64) async {
    final bytes = await _decode(base64);
    try {
      await dir.create(recursive: true);
      final file = File(p.join(dir.path, _safeName(name)));
      return await file.writeAsBytes(bytes, flush: true);
    } catch (e) {
      throw PlatformFailure('Could not write the file: $e');
    }
  }

  /// Decoded off the UI isolate: payloads can be several MB.
  Future<Uint8List> _decode(String base64) async {
    try {
      return await compute(base64Decode, base64);
    } on FormatException {
      throw const InvalidInputFailure('File content is not valid base64.');
    }
  }

  Future<Directory> _downloadsDir() async {
    try {
      return await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
    } catch (_) {
      return getApplicationDocumentsDirectory();
    }
  }

  /// Keeps only the last path segment so a name can never escape the folder.
  static String _safeName(String name) {
    final base = p.basename(name.replaceAll('\\', '/')).trim();
    return base.isEmpty || base == '.' || base == '..' ? 'file' : base;
  }
}

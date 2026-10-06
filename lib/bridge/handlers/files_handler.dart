/// `FilesHandler`: `files.save | share | print | open` for base64 payloads
/// sent by Angular (D14). Gets a longer timeout because share/print dialogs
/// stay open.
///
/// Why it exists: `blob:` downloads never reach the native side, so PDFs and
/// exports travel over the bridge and `FilesRepository` does the platform
/// work.
/// Status: used — registered in `service_locator.dart`.
library;

import '../../features/files/data/files_repository.dart';
import '../bridge_handler.dart';
import '../bridge_message_model.dart';

/// `files.save | share | print | open` (D14).
class FilesHandler extends BridgeHandler {
  FilesHandler(this._files);
  final FilesRepository _files;

  @override
  String get prefix => 'files';

  @override
  Future<Object?> handle(BridgeRequest request) async {
    final payload = request.payload;
    switch (request.action) {
      case 'files.save':
        final path = await _files.save(
          name: payload.requireString('name'),
          base64: payload.requireString('base64'),
        );
        return {'uri': Uri.file(path).toString()};
      case 'files.share':
        await _files.share(
          name: payload.requireString('name'),
          mimeType: payload.requireString('mimeType'),
          base64: payload.requireString('base64'),
        );
        return const <String, dynamic>{};
      case 'files.print':
        await _files.print(
          name: payload.requireString('name'),
          base64Pdf: payload.requireString('base64Pdf'),
        );
        return const <String, dynamic>{};
      case 'files.open':
        await _files.open(
          name: payload.requireString('name'),
          mimeType: payload.requireString('mimeType'),
          base64: payload.requireString('base64'),
        );
        return const <String, dynamic>{};
      default:
        unknownAction(request);
    }
  }
}

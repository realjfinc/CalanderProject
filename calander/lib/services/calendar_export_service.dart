import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Hands a generated `.ics` file to the platform's save/share UI so the
/// user ends up with a real file they can hand to another calendar app --
/// kept behind an interface (like [UploadStorage]/[EventExtractionService])
/// so tests can fake "the user saved it" without a real file picker.
abstract class CalendarExportService {
  /// Returns true if the file was saved, false if the user canceled.
  Future<bool> exportToFile(String icsContent, {String fileName = 'calander-export.ics'});
}

class FilePickerCalendarExportService implements CalendarExportService {
  @override
  Future<bool> exportToFile(String icsContent, {String fileName = 'calander-export.ics'}) async {
    final bytes = Uint8List.fromList(utf8.encode(icsContent));
    final uri = await FilePicker.saveFile(fileName: fileName, bytes: bytes, mimeType: 'text/calendar');
    return uri != null;
  }
}

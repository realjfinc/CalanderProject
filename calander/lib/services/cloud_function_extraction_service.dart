import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:mime/mime.dart';

import '../models/extracted_event_draft.dart';
import '../models/extraction_input.dart';
import 'event_extraction_service.dart';
import 'timezone_offset.dart';

/// Production [EventExtractionService] calling the `extractEvent` Cloud
/// Function (see functions/src/index.ts).
class CloudFunctionExtractionService implements EventExtractionService {
  CloudFunctionExtractionService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  @override
  Future<ExtractedEventDraft> extract(ExtractionInput input) async {
    final timezone = currentTimezoneOffsetLabel();
    final callable = _functions.httpsCallable('extractEvent');

    final Map<String, dynamic> payload = switch (input) {
      ImageExtractionInput(:final bytes, :final mimeType, :final fileName) => {
        'type': 'image',
        'data': base64Encode(bytes),
        'mimeType': mimeType.isNotEmpty ? mimeType : (lookupMimeType(fileName) ?? 'image/jpeg'),
        'timezone': timezone,
      },
      PdfExtractionInput(:final bytes) => {
        'type': 'pdf',
        'data': base64Encode(bytes),
        'timezone': timezone,
      },
      LinkExtractionInput(:final url) => {'type': 'link', 'url': url, 'timezone': timezone},
    };

    final result = await callable.call<Map<Object?, Object?>>(payload);
    return ExtractedEventDraft.fromCallableResult(result.data);
  }
}

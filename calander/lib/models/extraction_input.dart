import 'dart:typed_data';

/// What the user handed us to extract an event from — a file (image/PDF)
/// picked from storage, a photo, or a pasted link. Exactly one of these is
/// sent to the extraction pipeline per request.
sealed class ExtractionInput {
  const ExtractionInput();
}

class ImageExtractionInput extends ExtractionInput {
  const ImageExtractionInput({required this.bytes, required this.mimeType, required this.fileName});
  final Uint8List bytes;
  final String mimeType;
  final String fileName;
}

class PdfExtractionInput extends ExtractionInput {
  const PdfExtractionInput({required this.bytes, required this.fileName});
  final Uint8List bytes;
  final String fileName;
}

class LinkExtractionInput extends ExtractionInput {
  const LinkExtractionInput({required this.url});
  final String url;
}

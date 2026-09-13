import '../models/extracted_event_draft.dart';
import '../models/extraction_input.dart';

/// Runs the extraction pipeline (Cloud Function + LLM) on a file or link and
/// returns a proposed, editable event — never saves anything itself.
abstract class EventExtractionService {
  Future<ExtractedEventDraft> extract(ExtractionInput input);
}

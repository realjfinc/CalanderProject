import pdfParse from "pdf-parse";

const MAX_TEXT_LENGTH = 20_000;

export class PdfExtractionError extends Error {}

/** Extracts plain text from a text-based PDF. Scanned/image-only PDFs will
 * yield little or no text — that's a known limitation (no OCR step here). */
export async function extractPdfText(buffer: Buffer): Promise<string> {
  try {
    const result = await pdfParse(buffer);
    return result.text.slice(0, MAX_TEXT_LENGTH);
  } catch (error) {
    throw new PdfExtractionError(`Could not read PDF: ${(error as Error).message}`);
  }
}

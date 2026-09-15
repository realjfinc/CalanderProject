import assert from "node:assert/strict";
import { test } from "node:test";

import { extractEvent, InvalidExtractRequestError } from "../src/extraction/extractEvent";
import type { LlmClient, LlmExtractionInput } from "../src/extraction/llmClient";
import { ExtractionNormalizationError } from "../src/extraction/normalizeEvent";
import type { ExtractRequest, RawLlmEventOutput } from "../src/extraction/types";

class FakeLlmClient implements LlmClient {
  public receivedInputs: LlmExtractionInput[] = [];
  constructor(private readonly response: RawLlmEventOutput) {}
  async extractEvent(input: LlmExtractionInput): Promise<RawLlmEventOutput> {
    this.receivedInputs.push(input);
    return this.response;
  }
}

const okResponse: RawLlmEventOutput = {
  title: "Book Club",
  location: "Library",
  start: "2026-05-01T18:00:00Z",
  end: "2026-05-01T19:00:00Z",
  notes: null,
};

test("image extraction sends base64 image data to the LLM client and normalizes the result", async () => {
  const llm = new FakeLlmClient(okResponse);
  const request: ExtractRequest = {
    type: "image",
    data: "ZmFrZS1pbWFnZS1ieXRlcw==",
    mimeType: "image/png",
    timezone: "UTC",
  };

  const result = await extractEvent(request, llm);

  assert.equal(result.title, "Book Club");
  assert.equal(llm.receivedInputs.length, 1);
  assert.equal(llm.receivedInputs[0].kind, "image");
});

test("image extraction rejects a request missing data/mimeType", async () => {
  const llm = new FakeLlmClient(okResponse);
  await assert.rejects(
    () => extractEvent({ type: "image", timezone: "UTC" } as ExtractRequest, llm),
    InvalidExtractRequestError,
  );
});

test("link extraction fetches the URL's text and sends it to the LLM client", async () => {
  const llm = new FakeLlmClient(okResponse);
  const fakeFetchLinkText = async (url: string) => {
    assert.equal(url, "https://example.com/party");
    return "You're invited! May 1st at 6pm at the Library.";
  };

  const result = await extractEvent(
    { type: "link", url: "https://example.com/party", timezone: "UTC" },
    llm,
    fakeFetchLinkText,
  );

  assert.equal(result.location, "Library");
  assert.equal(llm.receivedInputs[0].kind, "text");
});

test("link extraction rejects a request missing a url", async () => {
  const llm = new FakeLlmClient(okResponse);
  await assert.rejects(
    () => extractEvent({ type: "link", timezone: "UTC" } as ExtractRequest, llm),
    InvalidExtractRequestError,
  );
});

test("pdf extraction rejects a request missing data", async () => {
  const llm = new FakeLlmClient(okResponse);
  await assert.rejects(
    () => extractEvent({ type: "pdf", timezone: "UTC" } as ExtractRequest, llm),
    InvalidExtractRequestError,
  );
});

test("propagates a normalization failure when the LLM can't find a start time", async () => {
  const llm = new FakeLlmClient({ title: "No date here" });
  await assert.rejects(
    () => extractEvent({ type: "image", data: "abc", mimeType: "image/png", timezone: "UTC" }, llm),
    ExtractionNormalizationError,
  );
});

test("image extraction rejects a disallowed mime type", async () => {
  const llm = new FakeLlmClient(okResponse);
  await assert.rejects(
    () =>
      extractEvent(
        { type: "image", data: "ZmFrZQ==", mimeType: "application/x-msdownload", timezone: "UTC" },
        llm,
      ),
    InvalidExtractRequestError,
  );
  assert.equal(llm.receivedInputs.length, 0);
});

test("image extraction rejects an oversized payload before it reaches the LLM client", async () => {
  const llm = new FakeLlmClient(okResponse);
  const oversized = "A".repeat(10_000_001);
  await assert.rejects(
    () => extractEvent({ type: "image", data: oversized, mimeType: "image/png", timezone: "UTC" }, llm),
    InvalidExtractRequestError,
  );
  assert.equal(llm.receivedInputs.length, 0);
});

test("pdf extraction rejects an oversized payload", async () => {
  const llm = new FakeLlmClient(okResponse);
  const oversized = "A".repeat(20_000_001);
  await assert.rejects(
    () => extractEvent({ type: "pdf", data: oversized, timezone: "UTC" }, llm),
    InvalidExtractRequestError,
  );
});

test("link extraction rejects an implausibly long url before fetching it", async () => {
  const llm = new FakeLlmClient(okResponse);
  let fetchCalled = false;
  const fakeFetchLinkText = async () => {
    fetchCalled = true;
    return "unreachable";
  };
  const longUrl = "https://example.com/" + "a".repeat(2048);
  await assert.rejects(
    () => extractEvent({ type: "link", url: longUrl, timezone: "UTC" }, llm, fakeFetchLinkText),
    InvalidExtractRequestError,
  );
  assert.equal(fetchCalled, false);
});

import assert from "node:assert/strict";
import { test } from "node:test";

import { AnthropicLlmClient, LlmResponseError } from "../src/extraction/llmClient";

function fakeAnthropicResponse(text: string): typeof fetch {
  return (async () =>
    new Response(JSON.stringify({ content: [{ type: "text", text }] }), {
      status: 200,
      headers: { "content-type": "application/json" },
    })) as typeof fetch;
}

test("parses a clean JSON response", async () => {
  const client = new AnthropicLlmClient(
    "fake-key",
    fakeAnthropicResponse('{"title":"Gala","start":"2026-06-01T20:00:00Z"}'),
  );
  const result = await client.extractEvent({ kind: "text", text: "some flyer text" });
  assert.equal(result.title, "Gala");
});

test("strips a markdown fence the model added despite instructions", async () => {
  const client = new AnthropicLlmClient(
    "fake-key",
    fakeAnthropicResponse('```json\n{"title":"Gala","start":"2026-06-01T20:00:00Z"}\n```'),
  );
  const result = await client.extractEvent({ kind: "text", text: "some flyer text" });
  assert.equal(result.title, "Gala");
});

test("throws LlmResponseError on invalid JSON", async () => {
  const client = new AnthropicLlmClient("fake-key", fakeAnthropicResponse("not json at all"));
  await assert.rejects(
    () => client.extractEvent({ kind: "text", text: "x" }),
    LlmResponseError,
  );
});

test("throws LlmResponseError on a non-OK HTTP status", async () => {
  const failingFetch = (async () => new Response("error", { status: 500 })) as typeof fetch;
  const client = new AnthropicLlmClient("fake-key", failingFetch);
  await assert.rejects(
    () => client.extractEvent({ kind: "text", text: "x" }),
    LlmResponseError,
  );
});

test("sends image content in the expected shape", async () => {
  let capturedBody: any;
  const capturingFetch = (async (_url: string, init: RequestInit) => {
    capturedBody = JSON.parse(init.body as string);
    return new Response(JSON.stringify({ content: [{ type: "text", text: '{"title":"x","start":"2026-01-01T00:00:00Z"}' }] }));
  }) as typeof fetch;

  const client = new AnthropicLlmClient("fake-key", capturingFetch);
  await client.extractEvent({ kind: "image", base64: "abc123", mimeType: "image/jpeg" });

  const imageBlock = capturedBody.messages[0].content.find((b: any) => b.type === "image");
  assert.equal(imageBlock.source.media_type, "image/jpeg");
  assert.equal(imageBlock.source.data, "abc123");
});

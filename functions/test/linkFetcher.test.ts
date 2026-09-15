import assert from "node:assert/strict";
import { test } from "node:test";

import { fetchLinkText, htmlToText, LinkFetchError } from "../src/extraction/linkFetcher";

// A fake resolver standing in for a real DNS lookup, so these tests never
// touch the network -- returns a public-looking address unless overridden.
const publicLookup = async (_hostname: string) => [{ address: "93.184.216.34" }];

test("htmlToText strips tags, scripts, and styles, and collapses whitespace", () => {
  const html = `
    <html><head><style>.a{color:red}</style></head>
    <body>
      <script>trackStuff();</script>
      <h1>Block   Party</h1>
      <p>May 1st &amp; 2nd at&nbsp;the park</p>
    </body></html>
  `;
  assert.equal(htmlToText(html), "Block Party May 1st & 2nd at the park");
});

test("fetchLinkText surfaces a LinkFetchError on a non-OK response", async () => {
  const fakeFetch = (async () => new Response("nope", { status: 404 })) as typeof fetch;
  await assert.rejects(
    () => fetchLinkText("https://example.com/missing", fakeFetch, publicLookup),
    LinkFetchError,
  );
});

test("fetchLinkText surfaces a LinkFetchError when the network call throws", async () => {
  const fakeFetch = (async () => {
    throw new Error("dns failure");
  }) as typeof fetch;
  await assert.rejects(() => fetchLinkText("https://example.com", fakeFetch, publicLookup), LinkFetchError);
});

test("fetchLinkText reads a normal page's text through a public-resolving host", async () => {
  const fakeFetch = (async () =>
    new Response("<html><body><p>Hello there</p></body></html>", {
      status: 200,
      headers: { "content-type": "text/html" },
    })) as typeof fetch;
  const text = await fetchLinkText("https://example.com", fakeFetch, publicLookup);
  assert.equal(text, "Hello there");
});

test("fetchLinkText rejects a non-http(s) scheme", async () => {
  const fakeFetch = (async () => new Response("", { status: 200 })) as typeof fetch;
  await assert.rejects(
    () => fetchLinkText("file:///etc/passwd", fakeFetch, publicLookup),
    LinkFetchError,
  );
});

test("fetchLinkText rejects localhost", async () => {
  const fakeFetch = (async () => new Response("", { status: 200 })) as typeof fetch;
  await assert.rejects(
    () => fetchLinkText("http://localhost:8080/admin", fakeFetch, publicLookup),
    LinkFetchError,
  );
});

test("fetchLinkText rejects a literal private-range IP", async () => {
  const fakeFetch = (async () => new Response("", { status: 200 })) as typeof fetch;
  await assert.rejects(
    () => fetchLinkText("http://10.0.0.5/", fakeFetch, publicLookup),
    LinkFetchError,
  );
});

test("fetchLinkText rejects the cloud metadata address", async () => {
  const fakeFetch = (async () => new Response("", { status: 200 })) as typeof fetch;
  await assert.rejects(
    () => fetchLinkText("http://169.254.169.254/computeMetadata/v1/", fakeFetch, publicLookup),
    LinkFetchError,
  );
});

test("fetchLinkText rejects a public-looking hostname that resolves to a private address (DNS rebinding)", async () => {
  const fakeFetch = (async () => new Response("", { status: 200 })) as typeof fetch;
  const rebindingLookup = async (_hostname: string) => [{ address: "127.0.0.1" }];
  await assert.rejects(
    () => fetchLinkText("http://evil.example.com/", fakeFetch, rebindingLookup),
    LinkFetchError,
  );
});

test("fetchLinkText rejects a response over the size cap even without a trustworthy Content-Length", async () => {
  const hugeBody = "x".repeat(6 * 1024 * 1024); // over the 5 MB cap
  const fakeFetch = (async () => new Response(hugeBody, { status: 200 })) as typeof fetch;
  await assert.rejects(() => fetchLinkText("https://example.com", fakeFetch, publicLookup), LinkFetchError);
});

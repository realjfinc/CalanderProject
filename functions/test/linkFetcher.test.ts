import assert from "node:assert/strict";
import { test } from "node:test";

import { fetchLinkText, htmlToText, LinkFetchError } from "../src/extraction/linkFetcher";

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
  await assert.rejects(() => fetchLinkText("https://example.com/missing", fakeFetch), LinkFetchError);
});

test("fetchLinkText surfaces a LinkFetchError when the network call throws", async () => {
  const fakeFetch = (async () => {
    throw new Error("dns failure");
  }) as typeof fetch;
  await assert.rejects(() => fetchLinkText("https://example.com", fakeFetch), LinkFetchError);
});

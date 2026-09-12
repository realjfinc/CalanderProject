const MAX_TEXT_LENGTH = 20_000;

export class LinkFetchError extends Error {}

/** Fetches a URL and returns its visible text content, truncated to a sane size for an LLM prompt. */
export async function fetchLinkText(url: string, fetchFn: typeof fetch = fetch): Promise<string> {
  let response: Response;
  try {
    response = await fetchFn(url, { redirect: "follow" });
  } catch (error) {
    throw new LinkFetchError(`Could not reach ${url}: ${(error as Error).message}`);
  }
  if (!response.ok) {
    throw new LinkFetchError(`Fetching ${url} returned status ${response.status}`);
  }
  const html = await response.text();
  return htmlToText(html).slice(0, MAX_TEXT_LENGTH);
}

export function htmlToText(html: string): string {
  return html
    .replace(/<script[\s\S]*?<\/script>/gi, " ")
    .replace(/<style[\s\S]*?<\/style>/gi, " ")
    .replace(/<[^>]+>/g, " ")
    .replace(/&nbsp;/gi, " ")
    .replace(/&amp;/gi, "&")
    .replace(/&lt;/gi, "<")
    .replace(/&gt;/gi, ">")
    .replace(/\s+/g, " ")
    .trim();
}

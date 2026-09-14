import dns from "node:dns/promises";
import net from "node:net";

const MAX_TEXT_LENGTH = 20_000;
// Caps how much of a response body we'll buffer before giving up, regardless
// of what Content-Length claims (which can't be trusted, or may be absent
// for a chunked response) -- keeps a malicious/huge page from exhausting
// function memory or running up cost.
const MAX_RESPONSE_BYTES = 5 * 1024 * 1024;
const FETCH_TIMEOUT_MS = 10_000;

export class LinkFetchError extends Error {}

type LookupFn = (hostname: string) => Promise<{ address: string }[]>;

const defaultLookup: LookupFn = (hostname) => dns.lookup(hostname, { all: true });

/**
 * True for any IP in a private, loopback, link-local, or otherwise
 * non-public-routable range -- including 169.254.169.254, the cloud
 * metadata address AWS/GCP/Azure all use to serve instance credentials to
 * whatever's running on the machine. Fetching a user-supplied URL from a
 * server without this check is a classic SSRF: a client could ask this
 * function to fetch a link that actually targets the function's own cloud
 * metadata service or another internal-only host, unreachable to the
 * client directly. Fails closed for anything it doesn't recognize.
 */
function isPrivateOrReservedIp(ip: string): boolean {
  const type = net.isIP(ip);
  if (type === 4) {
    const parts = ip.split(".").map(Number);
    if (parts.length !== 4 || parts.some((n) => Number.isNaN(n))) return true;
    const [a, b] = parts;
    if (a === 0 || a === 10 || a === 127) return true;
    if (a === 169 && b === 254) return true;
    if (a === 172 && b >= 16 && b <= 31) return true;
    if (a === 192 && b === 168) return true;
    if (a === 100 && b >= 64 && b <= 127) return true; // carrier-grade NAT
    return false;
  }
  if (type === 6) {
    const lower = ip.toLowerCase();
    if (lower === "::1" || lower === "::") return true;
    if (lower.startsWith("fe80:") || lower.startsWith("fc") || lower.startsWith("fd")) return true;
    if (lower.startsWith("::ffff:")) {
      const mapped = lower.slice("::ffff:".length);
      if (net.isIP(mapped) === 4) return isPrivateOrReservedIp(mapped);
    }
    return false;
  }
  return true;
}

/**
 * Validates a user-supplied URL is a public http(s) address before it's
 * ever fetched -- scheme allowlist, then DNS-resolves the hostname (a
 * literal IP is checked directly) and rejects any address that resolves to
 * a private/reserved range. Resolving here (rather than trusting the
 * hostname string alone) closes the obvious bypass of naming a public-
 * looking domain that actually resolves to an internal address.
 */
async function assertSafeUrl(rawUrl: string, lookupFn: LookupFn): Promise<URL> {
  let url: URL;
  try {
    url = new URL(rawUrl);
  } catch {
    throw new LinkFetchError(`"${rawUrl}" is not a valid URL.`);
  }
  if (url.protocol !== "http:" && url.protocol !== "https:") {
    throw new LinkFetchError("Only http and https links are supported.");
  }
  const hostname = url.hostname;
  if (hostname.toLowerCase() === "localhost" || hostname.toLowerCase().endsWith(".localhost")) {
    throw new LinkFetchError("That link isn't reachable.");
  }

  const literalIpType = net.isIP(hostname);
  let addresses: string[];
  if (literalIpType) {
    addresses = [hostname];
  } else {
    try {
      addresses = (await lookupFn(hostname)).map((entry) => entry.address);
    } catch {
      throw new LinkFetchError("That link isn't reachable.");
    }
  }
  if (addresses.length === 0 || addresses.some(isPrivateOrReservedIp)) {
    throw new LinkFetchError("That link isn't reachable.");
  }
  return url;
}

async function readBoundedText(response: Response, maxBytes: number): Promise<string> {
  const body = response.body;
  if (!body) return response.text();
  const reader = body.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      if (!value) continue;
      total += value.byteLength;
      if (total > maxBytes) {
        throw new LinkFetchError("That page is too large to read.");
      }
      chunks.push(value);
    }
  } finally {
    await reader.cancel().catch(() => {});
  }
  return Buffer.concat(chunks.map((chunk) => Buffer.from(chunk))).toString("utf-8");
}

/** Fetches a URL and returns its visible text content, truncated to a sane size for an LLM prompt. */
export async function fetchLinkText(
  url: string,
  fetchFn: typeof fetch = fetch,
  lookupFn: LookupFn = defaultLookup,
): Promise<string> {
  const safeUrl = await assertSafeUrl(url, lookupFn);

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS);
  let response: Response;
  try {
    response = await fetchFn(safeUrl.toString(), { redirect: "follow", signal: controller.signal });
  } catch (error) {
    throw new LinkFetchError(`Could not reach ${url}: ${(error as Error).message}`);
  } finally {
    clearTimeout(timeout);
  }
  if (!response.ok) {
    throw new LinkFetchError(`Fetching ${url} returned status ${response.status}`);
  }
  const contentLength = response.headers.get("content-length");
  if (contentLength && Number(contentLength) > MAX_RESPONSE_BYTES) {
    throw new LinkFetchError("That page is too large to read.");
  }
  const html = await readBoundedText(response, MAX_RESPONSE_BYTES);
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

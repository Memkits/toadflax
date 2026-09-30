import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { pathToFileURL } from "node:url";

export function checkCdnPath(html, base) {
  assert.ok(base?.startsWith("https://") && base.endsWith("/"));
  const active = html.replace(/<!--[\s\S]*?-->/g, "");
  const scripts = [...active.matchAll(/<script\b[^>]*\bsrc=["']([^"']+)["']/gi)].map((m) => m[1]);
  const styles = [...active.matchAll(/<link\b[^>]*\bhref=["']([^"']+)["']/gi)].map((m) => m[1]).filter((url) => /\.css(?:[?#]|$)/.test(url));
  assert.ok(scripts.some((url) => url.startsWith(`${base}assets/`) && /\.js(?:[?#]|$)/.test(url)), "Missing generated JavaScript entry");
  // Respo creates this app's CSS at runtime; Vite emits no standalone CSS.
  assert.ok(styles.includes("https://cdn.tiye.me/favored-fonts/main-fonts.css"), "Missing existing shared font stylesheet");
  for (const asset of [...scripts, ...styles]) {
    if (asset === "https://cdn.tiye.me/favored-fonts/main-fonts.css") continue;
    assert.ok(asset.startsWith(`${base}assets/`), `Wrong generated asset prefix: ${asset}`);
    assert.equal(new URL(asset).pathname, new URL(asset).pathname.replace(/\/\//g, "/"));
  }
  const manifest = [...active.matchAll(/<link\b[^>]*>/gi)].filter(([tag]) => /\brel=["']manifest["']/.test(tag));
  assert.equal(manifest.length, 1, "Missing app manifest");
  const manifestUrl = manifest[0][0].match(/\bhref=["']([^"']+)["']/)?.[1];
  assert.ok(manifestUrl?.startsWith(`${base}assets/`), "Manifest uses wrong CDN prefix");
}
// Generated HTML only; remote upload verification belongs to the COS action.
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  checkCdnPath(readFileSync("dist/index.html", "utf8"), process.env.VITE_BASE_URL);
  console.log("Generated frontend assets use the selected CDN prefix");
}

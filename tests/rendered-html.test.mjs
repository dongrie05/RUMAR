import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

async function render() {
  const workerUrl = new URL("../dist/server/index.js", import.meta.url);
  workerUrl.searchParams.set("test", `${process.pid}-${Date.now()}`);
  const { default: worker } = await import(workerUrl.href);

  return worker.fetch(
    new Request("http://localhost/", { headers: { accept: "text/html" } }),
    {
      ASSETS: {
        fetch: async () => new Response("Not found", { status: 404 }),
      },
    },
    { waitUntil() {}, passThroughOnException() {} },
  );
}

test("renders the RUMAR product dashboard", async () => {
  const response = await render();
  assert.equal(response.status, 200);
  assert.match(response.headers.get("content-type") ?? "", /^text\/html\b/i);

  const html = await response.text();
  assert.match(
    html,
    /<title>RUMAR — O teu dia técnico, sob controlo<\/title>/i,
  );
  assert.match(html, /Bom dia,\s*<!-- -->Gonçalo/i);
  assert.match(html, /Agenda|Hoje/);
  assert.match(html, /Novo trabalho/);
  assert.match(html, /A RUMAR JÁ ADIANTOU TRABALHO/);
  assert.match(html, /aria-label="Navegação principal"/);
  assert.doesNotMatch(html, /Tino|Miguel|codex-preview/i);
});

test("keeps source branding and metadata aligned", async () => {
  const [page, layout] = await Promise.all([
    readFile(new URL("../app/page.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/layout.tsx", import.meta.url), "utf8"),
  ]);

  assert.match(page, /RUMAR/);
  assert.match(page, /Gonçalo/);
  assert.match(layout, /metadataBase/);
  assert.match(layout, /RUMAR — O teu dia técnico, sob controlo/);
  assert.doesNotMatch(`${page}\n${layout}`, /Tino|Miguel|tino\.pt/i);
});

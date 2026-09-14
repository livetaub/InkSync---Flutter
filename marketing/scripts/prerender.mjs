/**
 * Prerender the marketing site's SEO routes to static HTML.
 *
 * Why this exists: the site is a client-rendered React SPA. Crawlers and
 * link-unfurlers that don't execute JavaScript would otherwise see an empty
 * shell with none of the per-page titles, meta tags, canonicals or JSON-LD.
 * This script renders each route in jsdom after `vite build` and writes the
 * resulting DOM to dist/<route>/index.html, so Cloudflare Pages serves real
 * content to bots while humans still get the SPA.
 *
 * Routes come from public/sitemap.xml (single source of truth).
 * Run: node scripts/prerender.mjs   (wired into `npm run build`)
 *
 * Implementation notes:
 * - The built JS bundle is served to jsdom from disk via a custom
 *   ResourceLoader, so the render needs zero network access (works in
 *   sandboxes, CI, and offline). Images/fonts are blocked; they don't
 *   affect the DOM or head tags we care about.
 * - The bundle runs as a classic script because jsdom doesn't execute
 *   <script type="module">. Verified: the vite bundle has no top-level
 *   import/export, so classic execution is equivalent.
 * - No headless browser is required; jsdom is enough because the app uses
 *   no layout-dependent or exotic browser APIs (verified 2026-09-14).
 */
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import pkg from 'jsdom';
const { JSDOM, VirtualConsole, requestInterceptor } = pkg;

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const DIST = path.join(__dirname, '..', 'dist');
const SITEMAP = path.join(__dirname, '..', 'public', 'sitemap.xml');
const PROD_ORIGIN = 'https://inksyncnote.com';

function routesFromSitemap() {
  const xml = fs.readFileSync(SITEMAP, 'utf8');
  const locs = [...xml.matchAll(/<loc>([^<]+)<\/loc>/g)].map((m) => m[1].trim());
  return locs.map((u) => new URL(u).pathname);
}

// Serve dist/ files to jsdom from disk via an undici request interceptor;
// block everything else (images, fonts…) so the render needs zero network.
function makeResources() {
  return {
    interceptors: [
      requestInterceptor(async (request) => {
        try {
          const u = new URL(request.url);
          if (u.origin === PROD_ORIGIN && u.pathname.startsWith('/assets/')) {
            const file = path.join(DIST, decodeURIComponent(u.pathname));
            if (fs.existsSync(file) && fs.statSync(file).isFile()) {
              return new Response(fs.readFileSync(file, 'utf8'), {
                headers: { 'Content-Type': 'application/javascript' },
              });
            }
          }
        } catch {
          // fall through to block
        }
        return new Response('', { status: 404 });
      }),
    ],
  };
}

// The bundle tag must not be type="module" (jsdom won't execute it), but it
// MUST stay deferred: a synchronous classic script in <head> would run before
// <div id="root"> is parsed, so createRoot(null) throws React error #299 and
// the entire app silently never mounts (page looks fine from the prerendered
// HTML, but every interactive element is dead). `defer` runs it after parsing
// in real browsers and is honored by jsdom too.
function buildShell() {
  return fs
    .readFileSync(path.join(DIST, 'index.html'), 'utf8')
    .replace('<script type="module"', '<script defer data-prerender-classic');
}

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

async function renderRoute(shell, route, resources) {
  const virtualConsole = new VirtualConsole();
  virtualConsole.on('jsdomError', () => {});
  virtualConsole.on('error', () => {});

  const dom = new JSDOM(shell, {
    url: PROD_ORIGIN + route,
    runScripts: 'dangerously',
    pretendToBeVisual: true,
    resources,
    virtualConsole,
  });

  const { document } = dom.window;

  // Wait for React to mount…
  const deadline = Date.now() + 15000;
  while (Date.now() < deadline) {
    if (document.querySelector('#root > *')) break;
    await sleep(100);
  }
  if (!document.querySelector('#root > *')) {
    throw new Error(`React did not mount for route ${route}`);
  }
  // …then let passive effects (document.title / meta / canonical updates)
  // flush before serializing.
  await sleep(1200);

  const html = dom.serialize();
  dom.window.close();
  return html;
}

async function main() {
  const routes = routesFromSitemap();
  console.log(`Prerendering ${routes.length} routes…`);
  const shell = buildShell();
  const resources = makeResources();

  for (const route of routes) {
    const html = await renderRoute(shell, route, resources);
    const outDir = path.join(DIST, route);
    fs.mkdirSync(outDir, { recursive: true });
    fs.writeFileSync(path.join(outDir, 'index.html'), html);
    console.log(`  ✓ ${route}`);
  }
  console.log('Prerender complete.');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});

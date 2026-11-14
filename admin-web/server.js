// Static server for the Savarun admin website (admin.savarun.com).
//
// public/ holds the Flutter web build of app/lib/main_admin.dart, built with
// --base-href / (see README.md). It has no dependencies, so Railway only runs
// `npm start`. All data comes from the backend's /api/admin routes, which
// require an admin Firebase token; these files are public.
import http from 'node:http';
import { createReadStream } from 'node:fs';
import { stat } from 'node:fs/promises';
import { extname, join, normalize, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const PUBLIC_DIR = join(fileURLToPath(new URL('.', import.meta.url)), 'public');
const PORT = Number(process.env.PORT) || 5700;

const TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.wasm': 'application/wasm',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.webp': 'image/webp',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.otf': 'font/otf',
  '.ttf': 'font/ttf',
  '.woff2': 'font/woff2',
  '.frag': 'application/octet-stream',
  '.bin': 'application/octet-stream',
};

const SECURITY_HEADERS = {
  'X-Frame-Options': 'DENY',
  'X-Content-Type-Options': 'nosniff',
  'Referrer-Policy': 'strict-origin-when-cross-origin',
  'Strict-Transport-Security': 'max-age=31536000',
  // Keep the admin site out of search results.
  'X-Robots-Tag': 'noindex, nofollow',
};

async function resolveFile(urlPath) {
  let rel;
  try {
    rel = decodeURIComponent(urlPath.split('?')[0]);
  } catch {
    return null;
  }
  const full = normalize(join(PUBLIC_DIR, rel));
  if (full !== PUBLIC_DIR && !full.startsWith(PUBLIC_DIR + sep)) return null;
  try {
    const s = await stat(full);
    if (s.isFile()) return full;
    if (s.isDirectory()) {
      const index = join(full, 'index.html');
      if ((await stat(index)).isFile()) return index;
    }
  } catch {
    // fall through
  }
  return null;
}

http
  .createServer(async (req, res) => {
    if (req.method !== 'GET' && req.method !== 'HEAD') {
      res.writeHead(405, { Allow: 'GET, HEAD' }).end();
      return;
    }
    if (req.url === '/health') {
      res.writeHead(200, { 'Content-Type': 'application/json' }).end('{"ok":true}');
      return;
    }
    if (req.url === '/robots.txt') {
      res.writeHead(200, { 'Content-Type': 'text/plain' }).end('User-agent: *\nDisallow: /\n');
      return;
    }

    // The app uses #/ routes, so unknown paths fall back to index.html.
    const file = (await resolveFile(req.url)) || join(PUBLIC_DIR, 'index.html');
    const ext = extname(file);
    const isEntry = ext === '.html' || file.endsWith('flutter_bootstrap.js') || file.endsWith('flutter_service_worker.js') || file.endsWith('version.json');
    res.writeHead(200, {
      ...SECURITY_HEADERS,
      'Content-Type': TYPES[ext] || 'application/octet-stream',
      // Entry files must update on every deploy; the rest can be cached briefly.
      'Cache-Control': isEntry ? 'no-cache' : 'public, max-age=3600',
    });
    if (req.method === 'HEAD') {
      res.end();
      return;
    }
    createReadStream(file).on('error', () => res.end()).pipe(res);
  })
  .listen(PORT, '0.0.0.0', () => console.log(`Savarun admin website on port ${PORT}`));

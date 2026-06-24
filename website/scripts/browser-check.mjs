// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (c) 2026 GibblyGobbly
//
// Opens every page of the built site in Chrome, at phone and desktop width, in both themes, and fails on:
// console errors, sideways scrolling, a Run button that gives no result, text that is hard to read while the
// pointer is over a link or button (contrast under 4.5), a reference search that finds nothing, and a header
// link to Inside that does not open the first page. Needs `npm run build` first and playwright-core and Chrome.
import { spawn } from 'node:child_process';
import { readdirSync, statSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { chromium } from 'playwright-core';

const site = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const PORT = 4179;
const URL = `http://localhost:${PORT}`;

function routes(dir, pre = '') {
  const out = [];
  for (const f of readdirSync(dir).sort()) {
    const p = join(dir, f);
    if (statSync(p).isDirectory() && !f.startsWith('_')) out.push(...routes(p, `${pre}/${f}`));
  }
  if (readdirSync(dir).includes('index.html')) out.push(`${pre}/`);
  return out;
}

const server = spawn('npx', ['vite', 'preview', '--port', String(PORT), '--strictPort'], { cwd: site, stdio: 'ignore' });
const stop = () => server.kill();
process.on('exit', stop);
for (let i = 0; i < 50; i++) {
  try { if ((await fetch(URL)).ok) break; } catch {}
  await new Promise((r) => setTimeout(r, 200));
}

const lum = (c) => {
  const [r, g, b] = c.map((v) => { v /= 255; return v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4; });
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
};
const nums = (s) => s.match(/[\d.]+/g).map(Number);

const list = routes(join(site, 'build'));
const browser = await chromium.launch({ executablePath: process.env.CHROME ?? '/usr/bin/google-chrome', args: ['--no-sandbox'] });
let bad = 0;
const fail = (m) => { bad++; console.log('FAIL', m); };

for (const theme of ['light', 'dark']) {
  for (const [w, h] of [[390, 844], [1280, 900]]) {
    const page = await browser.newPage({ viewport: { width: w, height: h } });
    await page.addInitScript((t) => localStorage.setItem('zue-theme', t), theme);
    const errs = [];
    page.on('console', (m) => { if (m.type() === 'error') errs.push(m.text()); });
    page.on('pageerror', (e) => errs.push(String(e)));
    for (const r of list) {
      errs.length = 0;
      await page.goto(URL + r, { waitUntil: 'networkidle' });
      const over = await page.evaluate(() => document.documentElement.scrollWidth - innerWidth);
      if (over > 0) fail(`${theme} ${w}px ${r}: scrolls sideways by ${over}px`);
      if (errs.length) fail(`${theme} ${w}px ${r}: console ${errs.join(' ; ').slice(0, 200)}`);
      if (w === 1280) {
        for (const b of await page.$$('button.go')) { await b.click(); await page.waitForTimeout(40); }
        for (const [i, t] of (await page.$$eval('.screen', (e) => e.map((x) => x.innerText))).entries()) {
          if (!/exit status/.test(t)) fail(`${theme} ${r}: terminal ${i} has no result`);
        }
        // Hover every link and button and measure the contrast of the text inside.
        const els = await page.$$('a, button.btn, .tabs button, .toggle button, .mini, summary');
        const seen = new Set();
        for (const el of els.slice(0, 70)) {
          try { await el.scrollIntoViewIfNeeded({ timeout: 400 }); await el.hover({ timeout: 600 }); } catch { continue; }
          const items = await el.evaluate((e) => {
            const bgOf = (n) => { while (n) { const c = getComputedStyle(n).backgroundColor; if (!/rgba?\(0, 0, 0, 0\)|transparent/.test(c)) return c; n = n.parentElement; } return 'rgb(255,255,255)'; };
            const out = [];
            const walker = document.createTreeWalker(e, NodeFilter.SHOW_TEXT);
            let t;
            while ((t = walker.nextNode())) {
              if (!t.textContent.trim()) continue;
              const n = t.parentElement;
              out.push({ text: t.textContent.trim().slice(0, 28), fg: getComputedStyle(n).color, bg: bgOf(n) });
            }
            return out;
          });
          for (const x of items) {
            const a = lum(nums(x.fg)), b = lum(nums(x.bg));
            const ratio = (Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05);
            const key = r + x.text;
            if (ratio < 4.5 && !seen.has(key)) { seen.add(key); fail(`${theme} ${r}: "${x.text}" is hard to read when hovered (contrast ${ratio.toFixed(2)})`); }
          }
        }
      }
    }
    await page.close();
  }
}

const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
await page.goto(URL + '/', { waitUntil: 'networkidle' });
await page.click('header nav a:has-text("Inside")');
await page.waitForLoadState('networkidle');
if (!/\/internals\/memory\/$/.test(page.url())) fail(`Inside opens ${page.url()}, not the first page`);
await page.goto(URL + '/reference/', { waitUntil: 'networkidle' });
await page.fill('#rq', 'shuffle');
if ((await page.$$eval('.hits li a', (e) => e.length)) < 1) fail('reference search found nothing for shuffle');
await page.fill('#rq', 'E0201');
if ((await page.$$eval('.hits li a', (e) => e.length)) < 1) fail('reference search found nothing for E0201');
await page.goto(URL + '/learn/modules/', { waitUntil: 'networkidle' });
await page.click('.tabs button:nth-child(2)');
if (!/export const PI_ISH/.test(await page.inputValue('.ed textarea'))) fail('module tab did not switch');
await page.click('.toggle button:nth-child(3)');
await page.reload({ waitUntil: 'networkidle' });
if ((await page.evaluate(() => document.documentElement.dataset.theme)) !== 'dark') fail('theme did not persist');

console.log(bad ? `${bad} problem(s) in ${list.length} pages` : `ALL CHECKS PASSED (${list.length} pages, 2 widths, 2 themes)`);
await browser.close();
stop();
process.exit(bad ? 1 : 0);

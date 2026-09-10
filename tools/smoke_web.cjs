/* Browser regression for the exported prototype. Uses only normal player input.
 * Usage: node tools/smoke_web.cjs [http://127.0.0.1:8765/?smoke=1]
 * Requires: npm ci && npm run browser:install (optional development tools)
 */
'use strict';

const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require('playwright');
const browserChannel = process.env.SCRAPSTORM_BROWSER_CHANNEL || undefined;

const root = path.resolve(__dirname, '..');
const url = process.argv[2] || 'http://127.0.0.1:8765/?smoke=1';
const captureRoot = path.join(root, 'captures');
const artifactRoot = path.join(root, 'artifacts');
fs.mkdirSync(captureRoot, { recursive: true });
fs.mkdirSync(artifactRoot, { recursive: true });
const report = {
  started_at: new Date().toISOString(), url,
  browser: browserChannel || 'Playwright Chromium', viewport: { width: 1280, height: 720 },
  checks: [], transitions: [], snapshots: [],
  focus_events: [],
  page_errors: [], console_errors: [], network_failures: [], http_errors: [],
  screenshots: [], passed: false,
};
const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
let browser;
let page;
let sampleTimer;
let sampling = false;
let previousTransition = '';

async function state() {
  return page.evaluate(() => window.__scrapstorm ? JSON.parse(JSON.stringify(window.__scrapstorm)) : null);
}

async function sample(label) {
  const value = await state();
  if (!value) return value;
  const signature = `${value.mode}|${value.locale}`;
  if (signature !== previousTransition) {
    report.transitions.push({ at: new Date().toISOString(), mode: value.mode, locale: value.locale });
    previousTransition = signature;
  }
  if (label) report.snapshots.push({ label, at: new Date().toISOString(), state: value });
  return value;
}

function check(name, condition, details) {
  report.checks.push({ name, passed: Boolean(condition), details });
  if (!condition) throw new Error(`${name}: ${JSON.stringify(details)}`);
}

async function waitMode(mode) {
  await page.waitForFunction((expected) => window.__scrapstorm?.mode === expected, mode, { timeout: 15000 });
  return sample(mode);
}

async function clickLogical(x, y) {
  const bounds = await page.locator('canvas').first().boundingBox();
  if (!bounds || bounds.width < 100 || bounds.height < 100) throw new Error('Game canvas is unavailable or too small');
  await page.mouse.click(bounds.x + x * bounds.width / 1280, bounds.y + y * bounds.height / 720);
}

async function moveLogical(x, y) {
  const bounds = await page.locator('canvas').first().boundingBox();
  if (!bounds) throw new Error('Game canvas is unavailable');
  await page.mouse.move(bounds.x + x * bounds.width / 1280, bounds.y + y * bounds.height / 720);
}

async function screenshot(name) {
  await page.screenshot({ path: path.join(captureRoot, name), fullPage: false });
  report.screenshots.push(`captures/${name}`);
}

async function chooseLocale(locale) {
  const current = await sample();
  if (current.locale === locale) return;
  await clickLogical(770, 255);
  await delay(150);
  // Godot PopupMenu is rendered inside the canvas, below the OptionButton.
  // Pointer selection avoids browser key handling affecting popup navigation.
  await clickLogical(770, locale === 'zh_CN' ? 326 : 297);
  await page.waitForFunction((expected) => window.__scrapstorm?.locale === expected, locale, { timeout: 8000 });
  check(`language selectable: ${locale}`, (await sample(`locale-${locale}`)).locale === locale);
}

async function boot() {
  if (report.page_errors.length) throw new Error(`Game startup raised a JavaScript error: ${report.page_errors[0].message}`);
  let errorTimer;
  try {
    await Promise.race([
      page.waitForFunction(() => window.__scrapstorm?.ui_started === true, null, { timeout: 120000 }),
      new Promise((_, reject) => {
        errorTimer = setInterval(() => {
          if (report.page_errors.length) reject(new Error(`Game startup raised a JavaScript error: ${report.page_errors[0].message}`));
        }, 250);
      }),
    ]);
  } finally { clearInterval(errorTimer); }
  await waitMode('menu');
  await delay(350);
}

(async () => {
  try {
    browser = await chromium.launch({
      channel: browserChannel, headless: true,
      args: ['--enable-webgl', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'],
    });
    const context = await browser.newContext({ viewport: report.viewport, deviceScaleFactor: 1 });
    page = await context.newPage();
    page.on('pageerror', (error) => report.page_errors.push({ at: new Date().toISOString(), message: error.message, stack: error.stack }));
    page.on('console', (message) => {
      if (message.type() === 'error') report.console_errors.push({ at: new Date().toISOString(), text: message.text(), location: message.location() });
    });
    page.on('requestfailed', (request) => report.network_failures.push({
      at: new Date().toISOString(), url: request.url(), method: request.method(),
      resource_type: request.resourceType(), failure: request.failure(),
    }));
    page.on('response', (response) => {
      if (response.status() >= 400) report.http_errors.push({ url: response.url(), status: response.status() });
    });
    sampleTimer = setInterval(async () => {
      if (sampling || !page || page.isClosed()) return;
      sampling = true;
      try { await sample(); } catch (_) { /* Navigation replaces the execution context. */ }
      finally { sampling = false; }
    }, 250);

    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 120000 });
    await boot();
    check('fresh profile defaults to English', (await sample('fresh-menu')).locale === 'en');
    await screenshot('menu-en.png');

    await clickLogical(480, 455);
    await waitMode('settings');
    await chooseLocale('zh_CN');
    await screenshot('settings-zh.png');
    await clickLogical(640, 520);
    await waitMode('menu');
    await screenshot('menu-zh.png');
    // Allow the browser filesystem to sync settings to IndexedDB before reload.
    await delay(2500);
    await page.reload({ waitUntil: 'domcontentloaded', timeout: 120000 });
    await boot();
    check('Chinese choice survives refresh', (await sample('refreshed-menu')).locale === 'zh_CN');

    await clickLogical(480, 455);
    await waitMode('settings');
    await chooseLocale('en');
    await clickLogical(640, 520);
    await waitMode('menu');
    await clickLogical(230, 455);
    await waitMode('playing');
    const beforePlay = await sample('before-input');
    await moveLogical(960, 360);
    await page.keyboard.down('KeyD');
    await delay(1800);
    await page.keyboard.up('KeyD');
    const afterRightMovement = await sample('after-right-movement');
    check('D moves player right', Number(afterRightMovement.position?.x) > Number(beforePlay.position?.x) + 100, { before: beforePlay.position, after: afterRightMovement.position });
    await page.mouse.down({ button: 'right' });
    await page.keyboard.down('KeyS');
    await delay(600);
    const duringVacuum = await sample('vacuum-held');
    check('right mouse starts vacuum', duringVacuum.stats?.vacuum === true, duringVacuum.stats);
    // Release before dashing: dash intentionally cancels vacuum without firing.
    await page.mouse.up({ button: 'right' });
    await delay(250);
    const afterRelease = await sample('vacuum-released');
    check('right mouse release discharges', Number(afterRelease.stats?.shots) > Number(duringVacuum.stats?.shots), { before: duringVacuum.stats, after: afterRelease.stats });
    check('discharge preserves scrap currency', Number(afterRelease.stats?.currency) >= Number(duringVacuum.stats?.currency), { before: duringVacuum.stats, after: afterRelease.stats });
    await page.keyboard.press('Space');
    await delay(350);
    const duringDash = await sample('dash-cooldown');
    check('space consumes dash cooldown', Number(duringDash.stats?.dash_ratio) < 1, duringDash.stats);
    await delay(800);
    await page.keyboard.up('KeyS');
    await page.keyboard.down('KeyA');
    await delay(1800);
    await page.keyboard.up('KeyA');
    const beforeUpMovement = await sample('before-up-movement');
    await page.keyboard.down('KeyW');
    await delay(1800);
    await page.keyboard.up('KeyW');
    const afterUpMovement = await sample('after-up-movement');
    check('W moves player up', Number(afterUpMovement.position?.y) < Number(beforeUpMovement.position?.y) - 100, { before: beforeUpMovement.position, after: afterUpMovement.position });
    await delay(2600);
    const afterPlay = await sample('after-ten-seconds-input');
    check('game remains active after input', afterPlay.mode === 'playing', afterPlay);
    check('game time advances', Number(afterPlay.stats?.elapsed) > Number(beforePlay.stats?.elapsed) + 5, { before: beforePlay.stats, after: afterPlay.stats });
    check('right mouse release ends vacuum', afterPlay.stats?.vacuum === false, afterPlay.stats);
    check('discharge is counted once', Number(afterPlay.stats?.shots) === 1, afterPlay.stats);
    await screenshot('gameplay.png');

    await page.keyboard.press('Escape');
    await waitMode('pause');
    await delay(350);
    const pausedBefore = await sample('pause-before');
    await delay(1500);
    const pausedAfter = await sample('pause-after');
    check('Escape freezes gameplay time', Math.abs(Number(pausedAfter.stats?.elapsed) - Number(pausedBefore.stats?.elapsed)) < 0.025, { before: pausedBefore.stats, after: pausedAfter.stats });
    await page.keyboard.press('Escape');
    await waitMode('playing');
    await delay(750);
    check('Escape resumes gameplay time', Number((await sample('resumed')).stats?.elapsed) > Number(pausedAfter.stats?.elapsed) + 0.1);

    // Playwright forces pages to remain focused by default, even behind another
    // tab. Disable that browser emulation so this checks a genuine blur event.
    const focusSession = await context.newCDPSession(page);
    await focusSession.send('Emulation.setFocusEmulationEnabled', { enabled: false });
    await page.evaluate(() => {
      window.__smokeFocusEvents = [];
      for (const type of ['focus', 'blur', 'visibilitychange']) {
        window.addEventListener(type, () => window.__smokeFocusEvents.push({
          type, focused: document.hasFocus(), visibility: document.visibilityState,
        }));
      }
    });
    const otherTab = await context.newPage();
    await otherTab.goto('about:blank');
    await otherTab.bringToFront();
    await delay(800);
    await page.bringToFront();
    await delay(450);
    report.focus_events = await page.evaluate(() => window.__smokeFocusEvents);
    const blurred = await sample('after-tab-switch');
    check('tab switch pauses gameplay', blurred.mode === 'pause', blurred);
    await otherTab.close();
    await page.keyboard.press('Escape');
    await waitMode('playing');

    check('no JavaScript page errors', report.page_errors.length === 0, report.page_errors);
    check('no browser console errors', report.console_errors.length === 0, report.console_errors);
    check('no failed network requests', report.network_failures.length === 0, report.network_failures);
    check('no HTTP errors', report.http_errors.length === 0, report.http_errors);
    report.passed = true;
  } catch (error) {
    report.failure = { message: error.message, stack: error.stack };
    if (page && !page.isClosed()) {
      try { await sample('failure'); await screenshot('web-smoke-failure.png'); } catch (_) { /* Preserve the original failure. */ }
    }
    process.exitCode = 1;
  } finally {
    if (sampleTimer) clearInterval(sampleTimer);
    report.finished_at = new Date().toISOString();
    fs.writeFileSync(path.join(artifactRoot, 'web-smoke.json'), JSON.stringify(report, null, 2) + '\n');
    if (browser) await browser.close();
    console.log(JSON.stringify({ passed: report.passed, checks: report.checks.length, report: 'artifacts/web-smoke.json', failure: report.failure?.message || null }, null, 2));
  }
})();

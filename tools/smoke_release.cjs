/* Current release entry/persistence check using only ordinary player input.
 * No combat victory, shop checkpoint, boss-clear or hardware FPS claim.
 * npm ci; npm run browser:install; node tools/smoke_release.cjs [URL]
 */
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { chromium } = require('playwright');
const root = path.resolve(__dirname, '..');
const version = fs.readFileSync(path.join(root, 'project.godot'), 'utf8').match(/^config\/version="([0-9.]+)"$/m)[1];
const runId = new Date().toISOString().replace(/[:.]/g, '-');
const url = process.argv.find(a => /^https?:\/\//.test(a)) || 'http://127.0.0.1:8765/?smoke=1';
const channel = process.env.SCRAPSTORM_BROWSER_CHANNEL || undefined;
const captures = path.join(root, 'captures', 'release-' + runId);
const artifacts = path.join(root, 'artifacts');
fs.mkdirSync(captures, { recursive: true });
fs.mkdirSync(artifacts, { recursive: true });
const report = { version, started_at: new Date().toISOString(), browser: channel || 'Playwright Chromium',
  url, checks: [], errors: [], screenshots: [], passed: false,
  scope: 'Isolated fresh profile; menu, EN/ZH persistence, 960/1280 viewport, three mode entries, pause, voluntary retreat, local history reload. Ordinary input only; no combat victory/shop checkpoint/boss clear/long-run balance or human listening claim.' };
let browser, page;
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
const hash = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const state = () => page.evaluate(() => window.__scrapstorm ? JSON.parse(JSON.stringify(window.__scrapstorm)) : null);
function check(name, passed, details) {
  report.checks.push({ name, passed: Boolean(passed), details });
  console.log((passed ? 'PASS ' : 'FAIL ') + name);
  if (!passed) throw new Error(name);
}
async function mode(expected) {
  await page.waitForFunction(value => window.__scrapstorm?.mode === value, expected, { timeout: 15000 });
  await delay(200);
  return state();
}
async function click(x, y) {
  const bounds = await page.locator('canvas').first().boundingBox();
  if (!bounds || bounds.width < 100) throw new Error('Missing game canvas');
  await page.mouse.click(bounds.x + x * bounds.width / 1280, bounds.y + y * bounds.height / 720);
}
async function capture(label) {
  const name = label + '.png';
  await page.screenshot({ path: path.join(captures, name) });
  report.screenshots.push(path.relative(root, path.join(captures, name)).split(path.sep).join('/'));
}
async function boot() {
  await page.waitForFunction(() => window.__scrapstorm?.ui_started, null, { timeout: 120000 });
  return mode('menu');
}
async function locale(id) {
  await click(430, 587); await mode('settings');
  await click(477, 182); await delay(180);
  await click(477, id === 'zh_CN' ? 251 : 222);
  await page.waitForFunction(value => window.__scrapstorm?.locale === value, id);
  await click(640, 615); return mode('menu');
}
async function deploy(endless) {
  await click(250, endless ? 298 : 395); await mode('missions');
  await click(1045, 675);
  await page.waitForFunction(() => window.__scrapstorm?.mission_step === 1);
  await click(1045, 675); return mode('playing');
}
async function retreat() {
  if ((await state()).mode === 'playing') { await page.keyboard.press('Escape'); await mode('pause'); }
  await click(640, 480); await delay(250); await page.keyboard.press('Enter');
  const result = await mode('result');
  check('Voluntary retreat settles a local history entry', result.result.abandoned && result.result.reward.ok);
  await delay(600); await click(849, 634); return mode('menu');
}
(async () => {
  try {
    const response = await fetch(new URL('index.pck', url));
    const served = Buffer.from(await response.arrayBuffer());
    const local = fs.readFileSync(path.join(root, 'exports/web/index.pck'));
    report.pck_sha256 = hash(local);
    check('HTTP serves the exact local release PCK', response.ok && hash(served) === hash(local));
    browser = await chromium.launch({ channel, headless: true, args: ['--enable-webgl', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
    const context = await browser.newContext({ viewport: { width: 1280, height: 720 }, deviceScaleFactor: 1 });
    page = await context.newPage();
    page.on('pageerror', error => report.errors.push({ type: 'js', message: error.message }));
    page.on('console', message => { if (message.type() === 'error') report.errors.push({ type: 'console', message: message.text() }); });
    page.on('requestfailed', request => report.errors.push({ type: 'network', url: request.url(), failure: request.failure() }));
    page.on('response', response => { if (response.status() >= 400) report.errors.push({ type: 'http', status: response.status(), url: response.url() }); });
    await page.goto(url, { waitUntil: 'domcontentloaded' });
    let s = await boot();
    check('Fresh profile defaults to English with no history', s.locale === 'en' && s.profile.history_count === 0);
    await capture('menu-en');
    await locale('zh_CN'); await delay(2300);
    await page.reload({ waitUntil: 'domcontentloaded' }); s = await boot();
    check('Chinese preference persists after reload', s.locale === 'zh_CN');
    await page.setViewportSize({ width: 960, height: 540 }); await delay(200); await capture('menu-zh-960');
    await click(175, 587); s = await mode('archive');
    check('Achievements entry works at 960 x 540', s.archive_tab === 'achievements');
    await capture('achievements-zh'); await page.keyboard.press('Escape'); await mode('menu');
    await locale('en'); await page.setViewportSize({ width: 1280, height: 720 });
    s = await deploy(true);
    check('OVERTIME starts with four slots', s.stats.endless_mode && s.stats.weapon_slots === 4);
    await page.keyboard.press('KeyE'); await delay(180);
    check('Active skill accepts normal keyboard input', (await state()).stats.ability_uses === 1);
    await page.keyboard.press('Escape'); s = await mode('pause');
    const elapsed = s.stats.elapsed; await delay(800);
    check('Pause freezes combat time', (await state()).stats.elapsed === elapsed);
    await retreat();
    s = await deploy(false);
    check('NIGHT SHIFT remains a separate three-slot mode', s.stats.standard_mode && !s.stats.endless_mode && s.stats.weapon_slots === 3);
    await retreat();
    await click(250, 469); s = await mode('playing');
    check('QUICK SWEEP starts its 180-second mode', !s.stats.standard_mode && !s.stats.endless_mode && s.stats.duration === 180);
    await retreat();
    s = await state(); const coins = s.profile.coins;
    check('Three voluntary departures record exactly three battles', s.profile.history_count === 3);
    await delay(2300); await page.reload({ waitUntil: 'domcontentloaded' }); s = await boot();
    check('Reload retains history and coins without duplicate settlement', s.profile.history_count === 3 && s.profile.coins === coins);
    await click(430, 537); s = await mode('archive');
    check('Saved history is reachable through the menu', s.archive_tab === 'history' && s.profile.history_count === 3);
    await capture('history-en');
    check('No browser, JavaScript, network or HTTP errors', report.errors.length === 0, report.errors);
    report.passed = true;
  } catch (error) {
    report.failure = { message: error.message, stack: error.stack };
    process.exitCode = 1;
    if (page) { try { await capture('failure'); } catch (_) {} }
  } finally {
    report.finished_at = new Date().toISOString();
    const output = path.join(artifacts, 'release-web-' + runId + '.json');
    fs.writeFileSync(output, JSON.stringify(report, null, 2) + '\n');
    if (browser) await browser.close();
    console.log(JSON.stringify({ passed: report.passed, checks: report.checks.length, errors: report.errors.length, report: path.relative(root, output), failure: report.failure?.message }));
  }
})();

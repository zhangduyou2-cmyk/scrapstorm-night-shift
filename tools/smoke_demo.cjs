/* M2 demo regression through ordinary keyboard/mouse input only.
 * Usage: node tools/smoke_demo.cjs [http://127.0.0.1:8765/?smoke=1]
 * The diagnostic object is read only. This script never edits game state.
 */
'use strict';

const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require('playwright');
const browserChannel = process.env.SCRAPSTORM_BROWSER_CHANNEL || undefined;

const root = path.resolve(__dirname, '..');
const url = process.argv[2] || 'http://127.0.0.1:8765/?smoke=1';
const captures = path.join(root, 'captures');
const artifacts = path.join(root, 'artifacts');
fs.mkdirSync(captures, { recursive: true });
fs.mkdirSync(artifacts, { recursive: true });
const report = {
  started_at: new Date().toISOString(), url,
  browser: browserChannel || 'Playwright Chromium', viewport: { width: 1280, height: 720 },
  input_method: 'Ordinary keyboard/mouse input, read-only visible enemy/scrap observations and nine-direction collision prediction',
  checks: [], transitions: [], snapshots: [], focus_events: [],
  page_errors: [], console_errors: [], network_failures: [], http_errors: [],
  screenshots: [], survival_samples: [], passed: false,
  full_demo_completion_verified: false,
  boss_human_clear_verified: false,
  evidence_limits: [
    'This automated check covers the first normal 55-second wave, its shop, and entry to wave two.',
    'No evidence of a complete six-wave demo clear or a human boss victory is produced.',
    'Headless SwiftShader frame rates are not representative of target hardware performance.',
  ],
};
// Keep evidence from prior failed survival attempts when refining only the bot.
const previousReportPath = path.join(artifacts, 'demo-web-smoke.json');
if (fs.existsSync(previousReportPath)) {
  try {
    const previous = JSON.parse(fs.readFileSync(previousReportPath, 'utf8'));
    report.previous_attempts = [...(previous.previous_attempts || []), {
      started_at: previous.started_at, passed: previous.passed,
      failure: previous.failure?.message || null,
      survival_samples: previous.survival_samples || [],
    }];
  } catch (_) { /* A malformed old artifact must not prevent a fresh check. */ }
}
const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
let browser;
let context;
let page;
let sampleTimer;
let sampling = false;
let previousTransition = '';
let heldKeys = new Set();
let holdingVacuum = false;

async function state() {
  return page.evaluate(() => window.__scrapstorm ? JSON.parse(JSON.stringify(window.__scrapstorm)) : null);
}

async function sample(label) {
  const value = await state();
  if (!value) return value;
  const signature = `${value.mode}|${value.locale}|${value.stats?.wave}|${value.stats?.phase}`;
  if (signature !== previousTransition) {
    report.transitions.push({ at: new Date().toISOString(), mode: value.mode, locale: value.locale, wave: value.stats?.wave, phase: value.stats?.phase });
    previousTransition = signature;
  }
  if (label) report.snapshots.push({ label, at: new Date().toISOString(), state: value });
  return value;
}

function check(name, condition, details) {
  report.checks.push({ name, passed: Boolean(condition), details });
  console.log(`${condition ? 'PASS' : 'FAIL'} ${name}`);
  if (!condition) throw new Error(`${name}: ${JSON.stringify(details)}`);
}

async function waitMode(mode, timeout = 15000) {
  await page.waitForFunction((expected) => window.__scrapstorm?.mode === expected, mode, { timeout });
  return sample(mode);
}

async function point(x, y) {
  const bounds = await page.locator('canvas').first().boundingBox();
  if (!bounds || bounds.width < 100 || bounds.height < 100) throw new Error('Game canvas is unavailable');
  return { x: bounds.x + x * bounds.width / 1280, y: bounds.y + y * bounds.height / 720 };
}

async function click(x, y) {
  const position = await point(x, y);
  await page.mouse.click(position.x, position.y);
}

async function aim(x, y) {
  const position = await point(x, y);
  await page.mouse.move(position.x, position.y);
}

async function screenshot(name) {
  await page.screenshot({ path: path.join(captures, name), fullPage: false });
  report.screenshots.push(`captures/${name}`);
}

async function setKeys(nextKeys) {
  const next = new Set(nextKeys);
  for (const key of heldKeys) if (!next.has(key)) await page.keyboard.up(key);
  for (const key of next) if (!heldKeys.has(key)) await page.keyboard.down(key);
  heldKeys = next;
}

async function setVacuum(next) {
  if (next === holdingVacuum) return;
  if (next) await page.mouse.down({ button: 'right' });
  else await page.mouse.up({ button: 'right' });
  holdingVacuum = next;
}

async function releaseInputs() {
  await setKeys([]);
  await setVacuum(false);
}

async function chooseLocale(locale) {
  if ((await sample()).locale === locale) return;
  await click(770, 255);
  await delay(150);
  await click(770, locale === 'zh_CN' ? 326 : 297);
  await page.waitForFunction((expected) => window.__scrapstorm?.locale === expected, locale, { timeout: 8000 });
  check(`language selectable: ${locale}`, (await sample(`locale-${locale}`)).locale === locale);
}

async function boot() {
  if (report.page_errors.length) throw new Error(`Startup error: ${report.page_errors[0].message}`);
  let errorTimer;
  try {
    await Promise.race([
      page.waitForFunction(() => window.__scrapstorm?.ui_started === true, null, { timeout: 120000 }),
      new Promise((_, reject) => {
        errorTimer = setInterval(() => {
          if (report.page_errors.length) reject(new Error(`Startup error: ${report.page_errors[0].message}`));
        }, 250);
      }),
    ]);
  } finally { clearInterval(errorTimer); }
  await waitMode('menu');
  await delay(350);
}

async function testPreferences() {
  check('fresh profile defaults to English', (await sample('fresh-menu')).locale === 'en');
  await screenshot('menu-v02.png');
  await click(480, 455);
  await waitMode('settings');
  await chooseLocale('zh_CN');
  await click(640, 520);
  await waitMode('menu');
  await delay(2500);
  await page.reload({ waitUntil: 'domcontentloaded', timeout: 120000 });
  await boot();
  check('Chinese choice survives refresh', (await sample('refreshed-menu')).locale === 'zh_CN');
  await click(480, 455);
  await waitMode('settings');
  await chooseLocale('en');
  await click(640, 520);
  await waitMode('menu');
}

async function testPause() {
  await releaseInputs();
  await page.keyboard.press('Escape');
  await waitMode('pause');
  await delay(300);
  const before = await sample('pause-before');
  await delay(1250);
  const after = await sample('pause-after');
  check('pause freezes both run and wave time',
    Math.abs(Number(after.stats.elapsed) - Number(before.stats.elapsed)) < 0.025 &&
    Math.abs(Number(after.stats.wave_elapsed) - Number(before.stats.wave_elapsed)) < 0.025,
    { before: before.stats, after: after.stats });
  await page.keyboard.press('Escape');
  await waitMode('playing');
  await delay(350);
  check('Escape resumes wave time', Number((await sample('resumed')).stats.wave_elapsed) > Number(after.stats.wave_elapsed) + 0.1);

  const session = await context.newCDPSession(page);
  await session.send('Emulation.setFocusEmulationEnabled', { enabled: false });
  await page.evaluate(() => {
    window.__smokeFocusEvents = [];
    for (const type of ['focus', 'blur']) window.addEventListener(type, () => window.__smokeFocusEvents.push({ type, focused: document.hasFocus() }));
  });
  const otherTab = await context.newPage();
  await otherTab.goto('about:blank');
  await otherTab.bringToFront();
  await delay(500);
  await page.bringToFront();
  await waitMode('pause');
  report.focus_events = await page.evaluate(() => window.__smokeFocusEvents);
  check('actual browser blur pauses demo', report.focus_events.some((event) => event.type === 'blur' && event.focused === false), report.focus_events);
  await otherTab.close();
  await page.keyboard.press('Escape');
  await waitMode('playing');
}

async function testInitialInput() {
  const before = await sample('first-wave-start');
  check('default Start launches demo wave one', before.mode === 'playing' && before.stats.wave === 1 && before.stats.phase === 'combat', before);
  check('ordinary wave duration is 55 seconds', Number(before.stats.wave_duration) === 55, before.stats);
  await aim(710, 390);
  await setKeys(['KeyD']);
  await delay(750);
  await setKeys([]);
  const moved = await sample('right-movement');
  check('D moves the player', Number(moved.position.x) > Number(before.position.x) + 70, { before: before.position, after: moved.position });
  await setVacuum(true);
  await delay(650);
  const held = await sample('vacuum-held');
  check('right mouse starts vacuum', held.stats.vacuum === true, held.stats);
  await setVacuum(false);
  await delay(300);
  const released = await sample('vacuum-release');
  check('release ends vacuum', released.stats.vacuum === false, released.stats);
  check('release does not spend scrap currency', Number(released.stats.currency) >= Number(held.stats.currency), { before: held.stats, after: released.stats });
  await setKeys(['KeyW']);
  await page.keyboard.press('Space');
  await delay(350);
  const dashed = await sample('dash-cooldown');
  check('Space activates dash cooldown', Number(dashed.stats.dash_ratio) < 1, dashed.stats);
  check('W moves player up', Number(dashed.position.y) < Number(moved.position.y) - 50, { before: moved.position, after: dashed.position });
  await releaseInputs();
}

function chooseControls(current) {
  const position = current.position;
  const enemies = current.observations.enemies.filter((enemy) => Number(enemy.spawn) <= 0);
  const scraps = current.observations.scraps;
  const distance = (a, b) => Math.hypot(a.x - b.x, a.y - b.y);
  const nearest = enemies.reduce((best, enemy) => !best || distance(position, enemy) < distance(position, best) ? enemy : best, null);
  const nearestScrap = scraps.reduce((best, scrap) => !best || distance(position, scrap) < distance(position, best) ? scrap : best, null);
  const enemyDistance = nearest ? distance(position, nearest) : Infinity;
  let goal = { x: 640, y: 390 };
  let target = goal;
  if (nearest) {
    const denominator = Math.max(0.001, enemyDistance);
    goal = { x: nearest.x + (position.x - nearest.x) / denominator * 78, y: nearest.y + (position.y - nearest.y) / denominator * 78 };
    target = nearest;
  }
  if (nearestScrap && (enemyDistance > 105 && distance(position, nearestScrap) < 200 || !nearest)) {
    goal = nearestScrap;
    target = nearestScrap;
  }
  const diagonal = Math.SQRT1_2;
  const directions = [{ x: 0, y: 0 }, { x: 1, y: 0 }, { x: diagonal, y: diagonal }, { x: 0, y: 1 }, { x: -diagonal, y: diagonal }, { x: -1, y: 0 }, { x: -diagonal, y: -diagonal }, { x: 0, y: -1 }, { x: diagonal, y: -diagonal }];
  const crates = [{ x: 237, y: 236 }, { x: 973, y: 236 }, { x: 237, y: 500 }, { x: 973, y: 500 }];
  let best = directions[0];
  let bestScore = Infinity;
  for (const direction of directions) {
    const candidate = { x: position.x + direction.x * 53.75, y: position.y + direction.y * 53.75 };
    let score = distance(candidate, goal) * 0.03;
    if (candidate.x < 71 || candidate.x > 1209 || candidate.y < 145 || candidate.y > 635) score += 20;
    for (const crate of crates) if (candidate.x > crate.x - 28 && candidate.x < crate.x + 98 && candidate.y > crate.y - 28 && candidate.y < crate.y + 84) score += 22;
    for (const enemy of enemies) {
      const dangerRadius = Number(enemy.radius) + 19 + 15;
      score += Math.pow(Math.max(0, dangerRadius + 14 - distance(candidate, enemy)) * 0.16, 2);
      if (Number(enemy.windup) > 0 || Number(enemy.charge) > 0) {
        const endpoint = { x: enemy.x + Number(enemy.dx) * 160, y: enemy.y + Number(enemy.dy) * 160 };
        const vx = endpoint.x - enemy.x;
        const vy = endpoint.y - enemy.y;
        const fraction = Math.max(0, Math.min(1, ((candidate.x - enemy.x) * vx + (candidate.y - enemy.y) * vy) / Math.max(0.001, vx * vx + vy * vy)));
        const closest = { x: enemy.x + vx * fraction, y: enemy.y + vy * fraction };
        if (distance(candidate, closest) < dangerRadius + 10) score += 16;
      }
    }
    if (score < bestScore) { bestScore = score; best = direction; }
  }
  const keys = [];
  if (best.x > 0.2) keys.push('KeyD');
  if (best.x < -0.2) keys.push('KeyA');
  if (best.y > 0.2) keys.push('KeyS');
  if (best.y < -0.2) keys.push('KeyW');
  return {
    keys, target, enemyDistance,
    vacuum: !(current.stats.vacuum && Number(current.stats.energy) >= 45 && enemyDistance < 300),
    dash: enemyDistance < 52 && Number(current.stats.dash_ratio) >= 0.999 && keys.length > 0,
  };
}

async function surviveFirstWave() {
  check('visible observations are available for reactive input', Array.isArray((await sample()).observations?.enemies));
  let lastDashTime = -10;
  let lastSampleTime = -10;
  let gameplayCaptured = false;
  const started = Date.now();
  while (Date.now() - started < 180000) {
    const current = await sample();
    if (current.mode === 'shop') {
      await releaseInputs();
      check('normal input survives first wave into shop', current.stats.wave === 1 && current.stats.phase === 'shop', current);
      return sample('first-shop');
    }
    if (current.mode === 'result' || Number(current.stats.health) <= 0) {
      await releaseInputs();
      check('normal input survives first wave into shop', false, { reason: 'Player defeated during normal movement; no cheat or state override was used.', state: current });
    }
    if (current.mode !== 'playing') throw new Error(`Unexpected state during survival: ${current.mode}`);
    const waveTime = Number(current.stats.wave_elapsed);
    const player = current.position;
    const controls = chooseControls(current);
    await setKeys(controls.keys);
    await aim(controls.target.x, controls.target.y);
    await setVacuum(controls.vacuum && waveTime - lastDashTime > 0.25);
    if (controls.dash && waveTime - lastDashTime > 1.6) {
      await setVacuum(false);
      await page.keyboard.press('Space');
      lastDashTime = waveTime;
    }
    if (waveTime - lastSampleTime >= 5) {
      report.survival_samples.push({ wave_time: waveTime, health: current.stats.health, currency: current.stats.currency, shots: current.stats.shots, kills: current.stats.kills, position: player });
      console.log(`First wave: ${waveTime.toFixed(1)} / 55 s, hull ${current.stats.health}, scrap ${current.stats.currency}`);
      lastSampleTime = waveTime;
    }
    if (!gameplayCaptured && waveTime >= 14) {
      await screenshot('gameplay-v02.png');
      gameplayCaptured = true;
    }
    await delay(75);
  }
  await releaseInputs();
  check('normal input survives first wave into shop', false, { reason: '180-second browser time limit exceeded', state: await sample('survival-timeout') });
}

async function testShop() {
  await delay(350);
  const beforeWait = await sample('shop-before-wait');
  await screenshot('shop-en.png');
  await delay(1250);
  const shop = await sample('shop-after-wait');
  check('shop freezes run and wave clocks', Number(shop.stats.elapsed) === Number(beforeWait.stats.elapsed) && Number(shop.stats.wave_elapsed) === Number(beforeWait.stats.wave_elapsed), { before: beforeWait.stats, after: shop.stats });
  check('shop has three distinct offers', Array.isArray(shop.shop_offers) && shop.shop_offers.length === 3 && new Set(shop.shop_offers.map((offer) => offer.token)).size === 3, shop.shop_offers);
  check('shop summary describes completed first wave', Number(shop.shop_summary?.wave) === 1, shop.shop_summary);
  const offerIndex = shop.shop_offers.findIndex((offer) => !offer.sold && Number(offer.cost) <= Number(shop.stats.currency));
  check('earned currency can buy an offered upgrade', offerIndex >= 0, { currency: shop.stats.currency, offers: shop.shop_offers });
  const offer = shop.shop_offers[offerIndex];
  await click(266 + offerIndex * 374, 472);
  await page.waitForFunction((token) => window.__scrapstorm?.shop_offers?.some((candidate) => candidate.token === token && candidate.sold), offer.token, { timeout: 8000 });
  const purchased = await sample('after-purchase');
  check('purchase deducts the displayed cost exactly once', Number(purchased.stats.currency) === Number(shop.stats.currency) - Number(offer.cost), { offer, before: shop.stats.currency, after: purchased.stats.currency });
  check('purchase upgrades the loadout', JSON.stringify(purchased.stats.loadout) !== JSON.stringify(shop.stats.loadout), { offer, before: shop.stats.loadout, after: purchased.stats.loadout });
  await click(266 + offerIndex * 374, 472);
  await delay(450);
  const repeated = await sample('repeat-purchase-click');
  check('sold offer cannot charge or upgrade twice', Number(repeated.stats.currency) === Number(purchased.stats.currency) && JSON.stringify(repeated.stats.loadout) === JSON.stringify(purchased.stats.loadout), { before: purchased.stats, after: repeated.stats });

  await click(793, 632);
  await waitMode('settings');
  await chooseLocale('zh_CN');
  await click(640, 520);
  await waitMode('shop');
  const chineseShop = await sample('chinese-shop');
  check('Chinese settings returns to the same shop', chineseShop.locale === 'zh_CN' && chineseShop.stats.wave === 1 && Number(chineseShop.stats.currency) === Number(purchased.stats.currency) && JSON.stringify(chineseShop.shop_offers) === JSON.stringify(repeated.shop_offers), chineseShop);
  await screenshot('shop-zh.png');
  await click(793, 632);
  await waitMode('settings');
  await chooseLocale('en');
  await click(640, 520);
  await waitMode('shop');
  await click(1044, 632);
  await waitMode('playing');
  const next = await sample('second-wave-start');
  check('Continue starts exactly wave two', next.stats.wave === 2 && next.stats.phase === 'combat' && Number(next.stats.wave_elapsed) < 2, next.stats);
  await delay(1000);
  const later = await sample('second-wave-after-one-second');
  check('one Continue click cannot skip another wave', later.stats.wave === 2 && later.mode === 'playing', later.stats);
  check('purchased loadout persists into wave two', JSON.stringify(later.stats.loadout) === JSON.stringify(purchased.stats.loadout), { bought: purchased.stats.loadout, wave_two: later.stats.loadout });
}

(async () => {
  try {
    browser = await chromium.launch({ channel: browserChannel, headless: true, args: ['--enable-webgl', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
    context = await browser.newContext({ viewport: report.viewport, deviceScaleFactor: 1 });
    page = await context.newPage();
    page.on('pageerror', (error) => report.page_errors.push({ at: new Date().toISOString(), message: error.message, stack: error.stack }));
    page.on('console', (message) => { if (message.type() === 'error') report.console_errors.push({ text: message.text(), location: message.location() }); });
    page.on('requestfailed', (request) => report.network_failures.push({ url: request.url(), failure: request.failure() }));
    page.on('response', (response) => { if (response.status() >= 400) report.http_errors.push({ url: response.url(), status: response.status() }); });
    sampleTimer = setInterval(async () => {
      if (sampling || page.isClosed()) return;
      sampling = true;
      try { await sample(); } catch (_) { /* Reload replaces the execution context. */ }
      finally { sampling = false; }
    }, 250);
    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 120000 });
    await boot();
    await testPreferences();
    await click(220, 457);
    await waitMode('playing');
    await testInitialInput();
    await testPause();
    await surviveFirstWave();
    await testShop();
    check('no JavaScript page errors', report.page_errors.length === 0, report.page_errors);
    check('no browser console errors', report.console_errors.length === 0, report.console_errors);
    check('no failed network requests', report.network_failures.length === 0, report.network_failures);
    check('no HTTP errors', report.http_errors.length === 0, report.http_errors);
    report.passed = true;
  } catch (error) {
    report.failure = { message: error.message, stack: error.stack };
    if (page && !page.isClosed()) {
      try { await releaseInputs(); await sample('failure'); await screenshot('demo-web-smoke-failure.png'); } catch (_) { /* Preserve the original cause. */ }
    }
    process.exitCode = 1;
  } finally {
    if (sampleTimer) clearInterval(sampleTimer);
    report.finished_at = new Date().toISOString();
    fs.writeFileSync(path.join(artifacts, 'demo-web-smoke.json'), JSON.stringify(report, null, 2) + '\n');
    if (browser) await browser.close();
    console.log(JSON.stringify({ passed: report.passed, checks: report.checks.length, report: 'artifacts/demo-web-smoke.json', failure: report.failure?.message || null, full_demo_completion_verified: false, boss_human_clear_verified: false }, null, 2));
  }
})();

/* v0.4 Web regression through ordinary keyboard/mouse input only.
 * Reads window.__scrapstorm for observation; never mutates gameplay/profile state.
 * Fresh isolated browser context. No stage skipping, invulnerability or added money.
 */
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { chromium } = require('playwright');
const browserChannel = process.env.SCRAPSTORM_BROWSER_CHANNEL || undefined;
const root = path.resolve(__dirname, '..');
const captures = path.join(root, 'captures', 'v04', 'browser');
const artifacts = path.join(root, 'artifacts');
const retreatOnly = process.argv.includes('--retreat-only');
const quickOnly = process.argv.includes('--quick-only');
const url = process.argv.find((arg) => /^https?:\/\//.test(arg)) || 'http://127.0.0.1:8765/?smoke=1&v=0.4.0';
fs.mkdirSync(captures, { recursive: true });
fs.mkdirSync(artifacts, { recursive: true });
const reportName = quickOnly ? 'standard-web-v04-quick-smoke.json' : retreatOnly ? 'standard-web-v04-retreat-smoke.json' : 'standard-web-v04-smoke.json';
const reportPath = path.join(artifacts, reportName);
const report = { started_at: new Date().toISOString(), url, browser: browserChannel || 'Playwright Chromium',
  viewport: { width: 1280, height: 720 }, input_method: 'Ordinary mouse/keyboard; read-only diagnostic observations',
  checks: [], snapshots: [], transitions: [], survival_samples: [], screenshots: [], focus_events: [],
  page_errors: [], console_errors: [], network_failures: [], http_errors: [], passed: false,
  evidence_limits: ['A reactive input bot completes the first normal 120-second stage, not a human playtest.',
    'Three map entries, shop, save/reload, second-stage entry, abandonment and the preserved Quick Sweep entry are exercised; full 15–20 minute clears are not.',
    'Music routing and gesture state are observed; subjective listening is a separate check.',
    'Headless SwiftShader FPS is not hardware performance evidence.'] };
if (retreatOnly) {
  report.evidence_limits = ['Targeted final-build supplement: three short map entries and voluntary retreat, not another full-stage survival run.',
    'The read-only abandoned result flag is asserted. Localized result headings are additionally checked from actual screenshots.',
    'No money, kills or stage progress are injected; a fresh isolated browser profile is used.'];
}
if (quickOnly) {
  report.evidence_limits = ['Final-package supplement: normal menu/workshop input, Quick Sweep with the free alternate skill, naturally spawned enemies, and localized voluntary retreat.',
    'The browser profile uses the free Industrial/Mint appearance. Nondefault paid cosmetic propagation is checked by the native application test, not inferred from ability diagnostics here.',
    'Atlas presence and UI readability require screenshot inspection; the input bot and headless SwiftShader FPS are not human difficulty or hardware performance evidence.'];
}
const localPack = path.join(root, 'exports', 'web', 'index.pck');
if (fs.existsSync(localPack)) {
  const packStat = fs.statSync(localPack);
  report.local_served_package = { path: 'exports/web/index.pck', bytes: packStat.size,
    modified_at: packStat.mtime.toISOString(), sha256: crypto.createHash('sha256').update(fs.readFileSync(localPack)).digest('hex') };
}
if (fs.existsSync(reportPath)) {
  try { const old = JSON.parse(fs.readFileSync(reportPath, 'utf8'));
    report.previous_attempts = [...(old.previous_attempts || []), { started_at: old.started_at, passed: old.passed, failure: old.failure?.message, survival_samples: old.survival_samples || [] }];
  } catch (_) { /* A prior truncated report cannot block testing. */ }
}
const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
let browser, context, page, sampleTimer;
let sampling = false, lastTransition = '', heldKeys = new Set(), vacuum = false;
const state = () => page.evaluate(() => window.__scrapstorm ? JSON.parse(JSON.stringify(window.__scrapstorm)) : null);
async function sample(label) {
  const value = await state();
  if (!value) return value;
  const signature = `${value.mode}/${value.locale}/${value.stats?.map_id}/${value.stats?.wave}/${value.stats?.phase}`;
  if (signature !== lastTransition) { lastTransition = signature; report.transitions.push({ at: new Date().toISOString(), signature }); }
  if (label) report.snapshots.push({ label, at: new Date().toISOString(), state: value });
  return value;
}
function check(name, passed, details) {
  report.checks.push({ name, passed: Boolean(passed), details });
  console.log(`${passed ? 'PASS' : 'FAIL'} ${name}`);
  if (!passed) throw new Error(`${name}: ${JSON.stringify(details)}`);
}
async function waitMode(mode, timeout = 15000) {
  await page.waitForFunction((expected) => window.__scrapstorm?.mode === expected, mode, { timeout });
  await delay(150);
  return sample(mode);
}
async function point(x, y) {
  const box = await page.locator('canvas').first().boundingBox();
  if (!box || box.width < 100) throw new Error('Game canvas unavailable');
  return { x: box.x + x * box.width / 1280, y: box.y + y * box.height / 720 };
}
async function click(x, y) { const p = await point(x, y); await page.mouse.click(p.x, p.y); }
async function aim(x, y) { const p = await point(x, y); await page.mouse.move(p.x, p.y); }
async function shot(name) {
  if (quickOnly) name = 'quick-final-' + name;
  else if (retreatOnly) name = 'retreat-' + name;
  await page.screenshot({ path: path.join(captures, name), fullPage: false });
  report.screenshots.push(`captures/v04/browser/${name}`);
}
async function keys(next) {
  const wanted = new Set(next);
  for (const key of heldKeys) if (!wanted.has(key)) await page.keyboard.up(key);
  for (const key of wanted) if (!heldKeys.has(key)) await page.keyboard.down(key);
  heldKeys = wanted;
}
async function suction(next) {
  if (next === vacuum) return;
  if (next) await page.mouse.down({ button: 'right' }); else await page.mouse.up({ button: 'right' });
  vacuum = next;
}
async function release() { await keys([]); await suction(false); }
async function boot() {
  await page.waitForFunction(() => window.__scrapstorm?.ui_started === true, null, { timeout: 120000 });
  await waitMode('menu');
  await delay(350);
}
async function reload() {
  await release(); await delay(2200);
  await page.reload({ waitUntil: 'domcontentloaded', timeout: 120000 });
  await boot();
}
async function locale(value) {
  if ((await state()).locale === value) return;
  await click(477, 182); await delay(120);
  // Popup row positions were verified in the captured actual Godot canvas.
  await click(477, value === 'zh_CN' ? 251 : 222);
  await page.waitForFunction((wanted) => window.__scrapstorm?.locale === wanted, value, { timeout: 8000 });
  check(`language switch ${value}`, (await sample(`locale-${value}`)).locale === value);
}
async function openSettings() { await click(480, 447); await waitMode('settings'); }
async function closeSettings(expected = 'menu') { await click(640, 615); await waitMode(expected); }
async function preferences() {
  const fresh = await sample('fresh-menu');
  check('new browser profile starts in English with two free active blueprints', fresh.locale === 'en' && fresh.profile.coins === 0 && fresh.profile.owned.length === 4 && fresh.profile.owned.includes('skill_overdrive'), fresh.profile);
  check('menu has no resumable checkpoint initially', !fresh.profile.has_checkpoint);
  await shot('standard-menu-en.png');
  await openSettings(); await locale('zh_CN'); await shot('standard-settings-zh.png'); await closeSettings();
  await shot('standard-menu-zh.png'); await reload();
  check('language choice survives browser refresh', (await sample('locale-reload')).locale === 'zh_CN');
  await page.setViewportSize({ width: 960, height: 540 }); await delay(300); await shot('standard-menu-zh-960.png');
  await click(220, 447); await waitMode('missions'); await shot('standard-missions-zh-960.png');
  await click(150, 675); await waitMode('menu');
  await openSettings(); await shot('standard-settings-zh-960.png'); await locale('en'); await closeSettings();
  await page.setViewportSize(report.viewport); await delay(300);
  await openSettings(); await shot('standard-settings-en.png'); await closeSettings();
}
async function mission(mapId, skill = 'pulse') {
  await click(220, 447); await waitMode('missions');
  const index = ['yard', 'foundry', 'reactor'].indexOf(mapId);
  await click(216, 208 + index * 145); await delay(180);
  await shot(`standard-mission-${mapId}.png`);
  await click(1045, 675);
  await page.waitForFunction(() => window.__scrapstorm?.mode === 'missions' && window.__scrapstorm?.mission_step === 1, null, { timeout: 8000 });
  const prepared = await sample(`preparation-${mapId}`);
  check(`${mapId} dispatch requires explicit loadout preparation`, prepared.mode === 'missions' && prepared.mission_step === 1);
  await click(905, 394); await delay(200); const locked = await sample(`locked-preview-${mapId}`);
  check(`${mapId} locked skill preview cannot silently equip`, !locked.profile.owned.includes('skill_singularity') && locked.profile.selected.skill === prepared.profile.selected.skill, locked.profile);
  await click(905, skill === 'overdrive' ? 292 : 190);
  await page.waitForFunction((selected) => window.__scrapstorm?.profile.selected.skill === selected, skill, { timeout: 8000 });
  await shot(`standard-loadout-${mapId}-${skill}.png`);
  await click(1045, 675); await waitMode('playing'); await delay(300);
  const current = await sample(`started-${mapId}`);
  check(`mission selection launches ${mapId}`, current.stats.standard_mode && current.stats.map_id === mapId && current.stats.wave === 1 && current.stats.wave_duration === 120, current.stats);
  check(`${mapId} gameplay uses the prepared active blueprint`, current.stats.ability_id === skill && current.stats.ability_state === 'ready' && current.stats.ability_charge === 100, current.stats);
  check(`${mapId} music follows map and gameplay context`, current.music.map_id === mapId && current.music.phase === 'combat' && current.music.unlocked, current.music);
  await shot(`standard-game-${mapId}.png`);
}
async function abandon(label) {
  await release();
  if ((await state()).mode === 'playing') { await page.keyboard.press('Escape'); await waitMode('pause'); }
  await click(640, 480); await delay(250);
  await shot(`standard-abandon-${label}.png`);
  // ConfirmationDialog's focused accept button uses ordinary Enter input.
  // A visible screenshot records the confirmation before accepting it.
  await page.keyboard.press('Enter'); await waitMode('result');
  // The result reveal includes a 0.18 s delay and 0.42 s fade. Inspect the settled UI.
  await delay(650);
  return sample(`abandoned-${label}`);
}
async function returnMenu() { await click(849, 634); await waitMode('menu'); }
async function mapEntries() {
  await mission('foundry', 'overdrive'); await abilityInput('overdrive'); await abandon('foundry'); await returnMenu();
  await mission('reactor', 'pulse'); await abilityInput('pulse'); await abandon('reactor'); await returnMenu();
  await mission('yard');
}
async function abilityInput(skill) {
  const before = await sample(`ability-${skill}-ready`);
  await page.keyboard.press('KeyE');
  await page.waitForFunction((uses) => Number(window.__scrapstorm?.stats.ability_uses) === uses + 1, Number(before.stats.ability_uses), { timeout: 8000 });
  const cast = await sample(`ability-${skill}-cast`);
  check(`${skill} uses independent charge without spending discharge energy`, cast.stats.ability_charge < 100 && cast.stats.energy === before.stats.energy, { before: before.stats, cast: cast.stats });
  await shot(`standard-skill-${skill}-active.png`);
  await page.keyboard.press('KeyE'); await delay(180);
  check(`${skill} repeated input cannot cast while active or charging`, Number((await state()).stats.ability_uses) === Number(cast.stats.ability_uses));
  if (skill === 'overdrive') {
    await page.keyboard.press('Escape'); await waitMode('pause');
    const paused = await sample('active-skill-paused'); await page.keyboard.press('KeyE'); await delay(700);
    const still = await sample('active-skill-pause-held');
    check('pause freezes active skill duration and blocks its input', paused.stats.ability_remaining === still.stats.ability_remaining && paused.stats.ability_uses === still.stats.ability_uses && still.stats.ability_state === 'active', { before: paused.stats, after: still.stats });
    await page.keyboard.press('Escape'); await waitMode('playing');
  } else {
    await page.waitForFunction(() => window.__scrapstorm?.stats.ability_state === 'charging', null, { timeout: 8000 });
    await shot('standard-skill-charging.png');
    check('spent pulse clearly enters charging state with no parallel cooldown', (await state()).stats.ability_cooldown === 0);
  }
}
async function pauseAndFocus() {
  await release(); await page.keyboard.press('Escape'); await waitMode('pause'); await delay(250);
  const before = await sample('pause-before'); await delay(1050); const after = await sample('pause-after');
  check('pause freezes combat time and lowers music intensity', before.stats.elapsed === after.stats.elapsed && after.music.phase === 'pause', { before: before.stats.elapsed, after: after.stats.elapsed, music: after.music });
  await page.keyboard.press('Escape'); await waitMode('playing');
  const cdp = await context.newCDPSession(page); await cdp.send('Emulation.setFocusEmulationEnabled', { enabled: false });
  await page.evaluate(() => { window.__smokeFocusEvents = []; for (const type of ['focus', 'blur']) window.addEventListener(type, () => window.__smokeFocusEvents.push({ type, focused: document.hasFocus() })); });
  const other = await context.newPage(); await other.goto('about:blank'); await other.bringToFront(); await delay(500);
  await page.bringToFront(); await waitMode('pause');
  report.focus_events = await page.evaluate(() => window.__smokeFocusEvents);
  check('real browser tab blur pauses the game', report.focus_events.some((event) => event.type === 'blur' && event.focused === false), report.focus_events);
  await other.close(); await page.keyboard.press('Escape'); await waitMode('playing');
}
function controls(current) {
  const p = current.position, enemies = current.observations.enemies.filter((e) => Number(e.spawn) <= 0), scraps = current.observations.scraps;
  const dist = (a, b) => Math.hypot(a.x - b.x, a.y - b.y);
  const nearest = enemies.reduce((best, e) => !best || dist(p, e) < dist(p, best) ? e : best, null);
  const scrap = scraps.reduce((best, e) => !best || dist(p, e) < dist(p, best) ? e : best, null);
  const distance = nearest ? dist(p, nearest) : Infinity;
  let goal = { x: 640, y: 390 }, target = goal;
  if (nearest) { goal = { x: nearest.x + (p.x - nearest.x) / Math.max(.001, distance) * 78, y: nearest.y + (p.y - nearest.y) / Math.max(.001, distance) * 78 }; target = nearest; }
  if (scrap && ((!nearest) || distance > 110 && dist(p, scrap) < 200)) { goal = scrap; target = scrap; }
  const q = Math.SQRT1_2, dirs = [[0, 0], [1, 0], [q, q], [0, 1], [-q, q], [-1, 0], [-q, -q], [0, -1], [q, -q]];
  let best = dirs[0], scoreBest = Infinity;
  for (const [x, y] of dirs) {
    const candidate = { x: p.x + x * 53.75, y: p.y + y * 53.75 };
    let score = dist(candidate, goal) * .03;
    if (candidate.x < 71 || candidate.x > 1209 || candidate.y < 145 || candidate.y > 635) score += 25;
    for (const [cx, cy] of [[237, 236], [973, 236], [237, 500], [973, 500]]) if (candidate.x > cx - 28 && candidate.x < cx + 98 && candidate.y > cy - 28 && candidate.y < cy + 84) score += 25;
    for (const e of enemies) {
      const danger = Number(e.radius) + 35;
      score += Math.pow(Math.max(0, danger + 16 - dist(candidate, e)) * .16, 2);
      if (Number(e.windup) > 0 || Number(e.charge) > 0) {
        const vx = Number(e.dx) * 190, vy = Number(e.dy) * 190;
        const t = Math.max(0, Math.min(1, ((candidate.x - e.x) * vx + (candidate.y - e.y) * vy) / Math.max(.001, vx * vx + vy * vy)));
        if (dist(candidate, { x: e.x + vx * t, y: e.y + vy * t }) < danger + 14) score += 20;
      }
    }
    if (score < scoreBest) { scoreBest = score; best = [x, y]; }
  }
  const next = []; if (best[0] > .2) next.push('KeyD'); if (best[0] < -.2) next.push('KeyA'); if (best[1] > .2) next.push('KeyS'); if (best[1] < -.2) next.push('KeyW');
  return { keys: next, target, distance, vacuum: !(current.stats.vacuum && Number(current.stats.energy) >= 68 && distance < 270),
    dash: distance < 57 && Number(current.stats.dash_ratio) >= .999 && next.length > 0,
    pulse: distance < 140 && current.stats.ability_state === 'ready' && Number(current.stats.ability_charge) >= 100 };
}
async function survive() {
  check('visible observations available for reactive input', Array.isArray((await state()).observations?.enemies));
  let lastDash = -10, lastLog = -15, captured = false;
  const begun = Date.now();
  while (Date.now() - begun < 300000) {
    const current = await sample();
    if (current.mode === 'shop') { await release(); check('ordinary input finishes the full 120-second first stage', current.stats.wave === 1 && current.stats.wave_elapsed >= 120, current.stats); return; }
    if (current.mode === 'result' || current.stats.health <= 0) throw new Error(`Reactive input bot died without completing the first stage: ${JSON.stringify(current.stats)}`);
    if (current.mode !== 'playing') throw new Error(`Unexpected mode while surviving: ${current.mode}`);
    const t = Number(current.stats.wave_elapsed), control = controls(current);
    await keys(control.keys); await aim(control.target.x, control.target.y); await suction(control.vacuum && t - lastDash > .28);
    if (control.dash && t - lastDash > 1.6) { await suction(false); await page.keyboard.press('Space'); lastDash = t; }
    if (control.pulse) await page.keyboard.press('KeyE');
    if (t - lastLog >= 10) { const row = { wave_time: t, hull: current.stats.health, scrap: current.stats.currency, kills: current.stats.kills, shots: current.stats.shots, skill_charge: current.stats.ability_charge, skill_uses: current.stats.ability_uses, discharge_energy: current.stats.energy, position: current.position }; report.survival_samples.push(row); console.log(`SURVIVAL ${t.toFixed(1)}/120s hull=${row.hull} scrap=${row.scrap} kills=${row.kills} skill=${row.skill_charge}% uses=${row.skill_uses}`); lastLog = t; }
    if (!captured && t > 18) { await shot('standard-gameplay-yard-active.png'); captured = true; }
    await delay(65);
  }
  throw new Error('First-stage wall-clock limit exceeded without state overrides');
}
async function shopAndResume() {
  await delay(350); const before = await sample('first-shop'); await shot('standard-shop-en.png');
  await delay(1000); const initial = await sample('shop-still');
  check('shop freezes combat time without adding shopping duration', initial.stats.elapsed === before.stats.elapsed && initial.stats.wave_elapsed === before.stats.wave_elapsed);
  check('shop automatically creates resumable profile state', initial.profile.has_checkpoint && initial.music.phase === 'shop');
  check('three distinct shop offers are available', initial.shop_offers.length === 3 && new Set(initial.shop_offers.map((o) => o.token)).size === 3, initial.shop_offers);
  const index = initial.shop_offers.findIndex((o) => !o.sold && Number(o.cost) + Number(initial.stats.reroll_cost) <= Number(initial.stats.currency));
  check('normally earned scrap funds an upgrade and one refresh', index >= 0, { currency: initial.stats.currency, offers: initial.shop_offers });
  const offer = initial.shop_offers[index]; await click(478 + index * 307, 434);
  await page.waitForFunction((token) => window.__scrapstorm?.shop_offers?.some((o) => o.token === token && o.sold), offer.token, { timeout: 8000 });
  const bought = await sample('bought');
  check('purchase applies exact displayed debit and equipment change', bought.stats.currency === initial.stats.currency - offer.cost && JSON.stringify(bought.stats.loadout) !== JSON.stringify(initial.stats.loadout), { offer, initial: initial.stats.currency, bought: bought.stats.currency });
  await click(478 + index * 307, 434); await delay(250); const duplicate = await sample('purchase-again');
  check('sold purchase cannot charge twice', duplicate.stats.currency === bought.stats.currency && JSON.stringify(duplicate.stats.loadout) === JSON.stringify(bought.stats.loadout));
  await click(1063, 151); await page.waitForFunction(() => window.__scrapstorm?.stats.can_reroll === false, null, { timeout: 8000 });
  const refreshed = await sample('refreshed');
  check('one refresh debits exactly and replaces offer tokens', refreshed.stats.currency === duplicate.stats.currency - duplicate.stats.reroll_cost && JSON.stringify(refreshed.shop_offers) !== JSON.stringify(duplicate.shop_offers), { cost: duplicate.stats.reroll_cost, before: duplicate.stats.currency, after: refreshed.stats.currency });
  await click(1063, 151); await delay(250); const twice = await sample('refresh-again');
  check('used refresh cannot charge or reroll twice', twice.stats.currency === refreshed.stats.currency && JSON.stringify(twice.shop_offers) === JSON.stringify(refreshed.shop_offers));
  await click(318, 687); await waitMode('settings'); await locale('zh_CN'); await closeSettings('shop'); await shot('standard-shop-zh.png');
  await click(318, 687); await waitMode('settings'); await locale('en'); await closeSettings('shop');
  const saved = await sample('before-return');
  await click(134, 687); await waitMode('menu');
  check('return from shop keeps checkpoint without ending the run', (await state()).profile.has_checkpoint);
  await reload(); check('checkpoint survives full browser refresh', (await state()).profile.has_checkpoint);
  await click(315, 570); await waitMode('shop'); const restored = await sample('restored-shop');
  check('continue restores exact wallet and purchased loadout', restored.stats.currency === saved.stats.currency && JSON.stringify(restored.stats.loadout) === JSON.stringify(saved.stats.loadout));
  check('continue restores exact offers and spent refresh', JSON.stringify(restored.shop_offers) === JSON.stringify(saved.shop_offers) && !restored.stats.can_reroll);
  check('continue restores combat time without recording shop time', restored.stats.elapsed === saved.stats.elapsed && restored.stats.wave_elapsed === saved.stats.wave_elapsed);
  await shot('standard-restored-shop.png'); await click(1080, 687); await waitMode('playing'); const next = await sample('second-stage');
  check('continue starts stage two once with retained equipment', next.stats.wave === 2 && next.stats.wave_elapsed < 2 && JSON.stringify(next.stats.loadout) === JSON.stringify(saved.stats.loadout));
  const coinsBefore = Number(next.profile.coins); await delay(750); const ended = await abandon('second-stage');
  check('explicit abandonment rewards completed stages and clears checkpoint', ended.profile.coins >= coinsBefore + 12 && !ended.profile.has_checkpoint && ended.result.reward?.ok, ended);
  await shot('standard-result-en.png'); const expectedCoins = ended.profile.coins;
  await returnMenu(); await reload(); const persisted = await sample('reward-reload');
  check('earned gold persists and does not award again on reload', persisted.profile.coins === expectedCoins && !persisted.profile.has_checkpoint, persisted.profile);
  await reload(); check('second reload still cannot duplicate settlement', (await state()).profile.coins === expectedCoins);
}
async function garage() {
  await click(480, 512); await waitMode('garage'); const before = await sample('garage'); await shot('standard-garage-blueprints.png');
  check('garage presents free owned selections and locked paid cosmetics', before.profile.owned.includes('skin_industrial') && before.profile.owned.includes('skill_pulse') && !before.profile.owned.includes('skin_arctic'), before.profile);
  await click(930, 168); await click(920, 358); await delay(200); await shot('standard-garage-skins.png');
  await click(1086, 655); await delay(200); const after = await sample('unaffordable-skin');
  check('unaffordable skin cannot debit or equip', after.profile.coins === before.profile.coins && JSON.stringify(after.profile.selected) === JSON.stringify(before.profile.selected));
  await click(770, 655); await shot('standard-garage-tracked-target.png');
  await click(1136, 168); await shot('standard-garage-colors.png');
  await click(720, 168); await click(918, 459); await click(1086, 655);
  await page.waitForFunction(() => window.__scrapstorm?.profile.selected.skill === 'overdrive', null, { timeout: 8000 });
  check('workshop equips the free alternate skill without paying coins', (await state()).profile.coins === before.profile.coins);
  await click(146, 677); await waitMode('menu'); await reload();
  check('equipped alternate skill persists after browser refresh', (await state()).profile.selected.skill === 'overdrive');
}
async function quickEntry() {
  const before = await sample('quick-before');
  await click(220, 512); await waitMode('playing');
  const started = await sample('quick-started');
  check('Quick Sweep remains immediate and uses the workshop skill', !started.stats.standard_mode && !started.stats.demo_mode && started.stats.duration === 180 && started.stats.ability_id === before.profile.selected.skill, started.stats);
  await shot('standard-quick-entry.png');
  const ended = await abandon('quick-entry');
  check('short Quick Sweep retreat cannot duplicate prior shift rewards', ended.profile.coins === before.profile.coins && !ended.profile.has_checkpoint, ended.result);
  await returnMenu();
}
async function retreatSupplement() {
  const initial = await sample('retreat-fresh-menu');
  check('targeted supplement starts with a fresh English profile', initial.locale === 'en' && initial.profile.coins === 0 && !initial.profile.has_checkpoint, initial.profile);
  for (const [mapId, language] of [['yard', 'en'], ['foundry', 'zh_CN'], ['reactor', 'en']]) {
    if ((await state()).locale !== language) { await openSettings(); await locale(language); await closeSettings(); }
    const before = await sample(`before-${mapId}`);
    await mission(mapId);
    const ended = await abandon(`short-${mapId}`);
    check(`${mapId} records a voluntary live-player retreat`, ended.result.abandoned === true && ended.result.won === false && Number(ended.result.health) > 0, ended.result);
    check(`${mapId} zero completed stages cannot earn clear rewards`, ended.result.reward?.ok && Number(ended.result.reward.completed) === 0 && Number(ended.result.reward.coins) === 0 && Number(ended.profile.coins) === Number(before.profile.coins), ended.result.reward);
    check(`${mapId} retreat leaves no resumable checkpoint`, !ended.profile.has_checkpoint);
    await shot(`result-${mapId}-${language}.png`);
    report.snapshots.push({ label: `localized-retreat-visual-${mapId}`, expected_locale: language,
      manual_review_required: 'Result must use voluntary-withdrawal title/description and omit the last-impact/death-cause line.' });
    const expectedCoins = Number(ended.profile.coins);
    await returnMenu(); await reload();
    const restored = await sample(`retreat-reloaded-${mapId}`);
    check(`${mapId} retreat reload preserves coins and language without new reward`, Number(restored.profile.coins) === expectedCoins && restored.locale === language && !restored.profile.has_checkpoint, restored.profile);
  }
}
async function quickSupplement() {
  const initial = await sample('quick-final-fresh');
  check('final package opens the English hangar with two free skills', initial.locale === 'en' && initial.profile.coins === 0 && initial.profile.owned.includes('skill_pulse') && initial.profile.owned.includes('skill_overdrive'), initial.profile);
  await shot('menu-en.png');
  await click(480, 512); await waitMode('garage');
  await click(918, 459); await click(1086, 655);
  await page.waitForFunction(() => window.__scrapstorm?.profile.selected.skill === 'overdrive', null, { timeout: 8000 });
  await shot('workshop-overdrive.png');
  await click(146, 677); await waitMode('menu'); await reload();
  check('workshop alternate skill persists in final package', (await state()).profile.selected.skill === 'overdrive');
  await click(220, 512); await waitMode('playing');
  const started = await sample('quick-final-started');
  check('final Quick Sweep immediately uses the saved alternate skill', !started.stats.standard_mode && !started.stats.demo_mode && started.stats.duration === 180 && started.stats.ability_id === 'overdrive', started.stats);
  await abilityInput('overdrive');
  const began = Date.now(); let captured = false;
  while (Date.now() - began < 60000) {
    const current = await sample();
    if (current.mode !== 'playing' || current.stats.health <= 0) throw new Error('Quick atlas observation interrupted before ordinary enemies were captured');
    const control = controls(current);
    await keys(control.keys); await aim(control.target.x, control.target.y); await suction(control.vacuum);
    if (Number(current.stats.elapsed) >= 18 && current.observations.enemies.some((enemy) => Number(enemy.spawn) <= 0)) {
      await release();
      await shot('quick-natural-enemies.png');
      const observed = await sample('quick-final-natural-enemies');
      check('final Quick Sweep produces visible normal enemies through ordinary play', observed.observations.enemies.some((enemy) => Number(enemy.spawn) <= 0), observed.observations.enemies);
      captured = true; break;
    }
    await delay(80);
  }
  check('final atlas capture completes without synthetic progress', captured);
  const ended = await abandon('quick-final-en');
  const combatCoins = Math.min(6, Math.floor(Number(ended.result.kills) / 10));
  check('final Quick retreat settles earned kill coins without a stage-clear award', ended.result.abandoned && ended.result.health > 0 && ended.result.reward.completed === 0 && ended.profile.coins === combatCoins && !ended.profile.has_checkpoint, ended.result);
  const expectedCoins = ended.profile.coins;
  await shot('result-en.png'); await returnMenu();
  await openSettings(); await locale('zh_CN'); await closeSettings();
  await page.setViewportSize({ width: 960, height: 540 }); await delay(350); await shot('menu-zh-960.png');
  await click(220, 512); await waitMode('playing');
  check('Chinese Quick entry keeps the equipped alternate skill', (await state()).stats.ability_id === 'overdrive' && (await state()).locale === 'zh_CN');
  const zhEnded = await abandon('quick-final-zh');
  check('short Chinese retreat cannot grant or duplicate rewards', zhEnded.result.abandoned && zhEnded.profile.coins === expectedCoins && !zhEnded.profile.has_checkpoint, zhEnded.result);
  await shot('result-zh-960.png'); await returnMenu(); await reload();
  check('final refresh keeps language and configuration without settlement duplication', (await state()).locale === 'zh_CN' && (await state()).profile.selected.skill === 'overdrive' && (await state()).profile.coins === expectedCoins);
}
(async () => {
  try {
    browser = await chromium.launch({ channel: browserChannel, headless: true, args: ['--enable-webgl', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
    context = await browser.newContext({ viewport: report.viewport, deviceScaleFactor: 1 }); page = await context.newPage();
    page.on('pageerror', (e) => report.page_errors.push({ message: e.message, stack: e.stack }));
    page.on('console', (m) => { if (m.type() === 'error') report.console_errors.push({ text: m.text(), location: m.location() }); });
    page.on('requestfailed', (r) => report.network_failures.push({ url: r.url(), failure: r.failure() }));
    page.on('response', (r) => { if (r.status() >= 400) report.http_errors.push({ url: r.url(), status: r.status() }); });
    sampleTimer = setInterval(async () => { if (sampling || page.isClosed()) return; sampling = true; try { await sample(); } catch (_) {} finally { sampling = false; } }, 300);
    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 120000 }); await boot();
    if (quickOnly) await quickSupplement();
    else if (retreatOnly) await retreatSupplement();
    else { await preferences(); await mapEntries(); await pauseAndFocus(); await survive(); await shopAndResume(); await garage(); await quickEntry(); }
    check('no JavaScript page errors', report.page_errors.length === 0, report.page_errors);
    check('no browser console errors', report.console_errors.length === 0, report.console_errors);
    check('no failed requests', report.network_failures.length === 0, report.network_failures);
    check('no HTTP errors', report.http_errors.length === 0, report.http_errors);
    report.passed = true;
  } catch (error) {
    report.failure = { message: error.message, stack: error.stack }; process.exitCode = 1;
    if (page && !page.isClosed()) { try { await release(); await sample('failure'); await shot('standard-web-smoke-failure.png'); } catch (_) {} }
  } finally {
    clearInterval(sampleTimer); report.finished_at = new Date().toISOString();
    fs.writeFileSync(reportPath, JSON.stringify(report, null, 2) + '\n');
    if (browser) await browser.close();
    console.log(JSON.stringify({ passed: report.passed, checks: report.checks.length, failure: report.failure?.message || null, report: `artifacts/${reportName}` }, null, 2));
  }
})();

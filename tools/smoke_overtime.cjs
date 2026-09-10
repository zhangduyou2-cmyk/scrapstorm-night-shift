/* Exported Web integration: normal keyboard/mouse only, fresh isolated profile.
 * window.__scrapstorm is a read-only observation channel, never a state editor.
 */
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { chromium } = require('playwright');
const browserChannel = process.env.SCRAPSTORM_BROWSER_CHANNEL || undefined;
const root = path.resolve(__dirname, '..');
const version = fs.readFileSync(path.join(root, 'project.godot'), 'utf8').match(/^config\/version="([0-9.]+)"$/m)[1];
const releaseLabel = 'v' + version.replaceAll('.', '');
const runId = new Date().toISOString().replace(/[:.]/g, '-');
const captureRelative = `captures/${releaseLabel}/browser-${runId}`;
const captures = path.join(root, captureRelative);
const reportPath = path.join(root,`artifacts/${releaseLabel}-web-smoke.json`);
if(fs.existsSync(reportPath)) {
  const previous=JSON.parse(fs.readFileSync(reportPath,'utf8'));
  const previousId=String(previous.started_at||runId).replace(/[:.]/g,'-');
  const archived=path.join(root,`artifacts/${releaseLabel}-web-smoke-${previousId}.json`);
  if(!fs.existsSync(archived))fs.copyFileSync(reportPath,archived);
}
fs.mkdirSync(captures, {recursive:true});
const url = process.argv.find(a => /^https?:\/\//.test(a)) || `http://127.0.0.1:8765/?smoke=1&v=${version}`;
const report = {url, started_at:new Date().toISOString(), checks:[], snapshots:[], screenshots:[], samples:[], errors:[], passed:false,
  browser: browserChannel || 'Playwright Chromium',
  method:'Fresh isolated browser context; ordinary inputs, real combat time, no gameplay/profile injections. Read-only diagnostics supply visible positions; collection/early-escape policy v4 uses no hidden projectile state.',
  prior_failure:'artifacts/v05-web-smoke-initial-failed.json; original captures/v05/browser is preserved.',
  limits:'First endless room and checkpoint/route loop, short standard/quick entries. No full Web boss clear, long-run balance, or hardware FPS claim.'};
const pack = fs.readFileSync(path.join(root,'exports/web/index.pck'));
report.package={bytes:pack.length,sha256:crypto.createHash('sha256').update(pack).digest('hex')};
const delay = ms => new Promise(r => setTimeout(r,ms));
let browser,page,held=new Set(),vacuum=false;
const state = () => page.evaluate(() => window.__scrapstorm ? JSON.parse(JSON.stringify(window.__scrapstorm)) : null);
function check(name, passed, details) { report.checks.push({name,passed:!!passed,details}); console.log(`${passed?'PASS':'FAIL'} ${name}`); if(!passed)throw Error(name); }
async function waitMode(mode) {await page.waitForFunction(m=>window.__scrapstorm?.mode===m,mode,{timeout:15000}); await delay(180); return state();}
async function point(x,y) {const b=await page.locator('canvas').first().boundingBox();return {x:b.x+x*b.width/1280,y:b.y+y*b.height/720};}
async function click(x,y) {const p=await point(x,y);await page.mouse.click(p.x,p.y);}
async function aim(x,y) {const p=await point(x,y);await page.mouse.move(p.x,p.y);}
async function keys(next) {const n=new Set(next);for(const k of held)if(!n.has(k))await page.keyboard.up(k);for(const k of n)if(!held.has(k))await page.keyboard.down(k);held=n;}
async function suction(on) {if(on===vacuum)return; if(on)await page.mouse.down({button:'right'});else await page.mouse.up({button:'right'});vacuum=on;}
async function release(){await keys([]);await suction(false);}
async function snap(name){await delay(250);await page.screenshot({path:path.join(captures,name+'.png')});report.screenshots.push(`${captureRelative}/${name}.png`);report.snapshots.push({name,state:await state()});}
async function boot(){await page.waitForFunction(()=>window.__scrapstorm?.ui_started,null,{timeout:120000});await waitMode('menu');}
async function reload(){await release();await delay(2200);await page.reload({waitUntil:'domcontentloaded'});await boot();}
async function locale(id){await click(477,182);await delay(150);await click(477,id==='zh_CN'?251:222);await page.waitForFunction(v=>window.__scrapstorm?.locale===v,id);}
async function abandon(){await release();if((await state()).mode==='playing'){await page.keyboard.press('Escape');await waitMode('pause');}await click(640,480);await delay(250);await page.keyboard.press('Enter');await waitMode('result');await delay(700);return state();}
async function menu(){await click(849,634);await waitMode('menu');}
async function deploy(endless){await click(250,endless?298:395);await waitMode('missions');await click(1045,675);await page.waitForFunction(()=>window.__scrapstorm?.mission_step===1);if(endless){await click(850,289);await delay(250);check('Preparation equips free Overdrive through its visible button',(await state()).profile.selected.skill==='overdrive'&&(await state()).profile.coins===0);}await snap('deployment-'+(endless?'overtime':'standard'));await click(1045,675);return waitMode('playing');}

// Collection/combat loop via public read-only observations. Stay within brush
// reach, collect energy for deliberate releases, break suction early at danger,
// and use the freely selectable Overdrive blueprint through its visible button.
// These ordinary inputs are integration coverage, not a human win-rate claim.
function controls(current) {
  const p = current.position, enemies = current.observations.enemies.filter((e) => Number(e.spawn) <= 0), scraps = current.observations.scraps;
  const dist = (a, b) => Math.hypot(a.x - b.x, a.y - b.y);
  const nearest = enemies.reduce((best, e) => !best || dist(p, e) < dist(p, best) ? e : best, null);
  const scrap = scraps.reduce((best, e) => !best || dist(p, e) < dist(p, best) ? e : best, null);
  const distance = nearest ? dist(p, nearest) : Infinity;
  let goal = { x: 640, y: 390 }, target = goal;
  if (nearest) { goal = { x: nearest.x + (p.x - nearest.x) / Math.max(.001, distance) * 83, y: nearest.y + (p.y - nearest.y) / Math.max(.001, distance) * 83 }; target = nearest; }
  if (scrap && ((!nearest) || distance > 110 && dist(p, scrap) < 200)) { goal = scrap; target = scrap; }
  const q = Math.SQRT1_2, dirs = [[0, 0], [1, 0], [q, q], [0, 1], [-q, q], [-1, 0], [-q, -q], [0, -1], [q, -q]];
  let best = dirs[0], scoreBest = Infinity;
  for (const [x, y] of dirs) {
    const candidate = { x: p.x + x * 53.75, y: p.y + y * 53.75 };
    let score = dist(candidate, goal) * .03;
    if(!x&&!y&&Number(current.stats.projectiles)>0)score+=2;
    score += 0.02*(Math.max(0,85-candidate.x)**2+Math.max(0,candidate.x-1195)**2+Math.max(0,155-candidate.y)**2+Math.max(0,candidate.y-625)**2);
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
  const chargingThreat=enemies.some(e=>(Number(e.windup)>0||Number(e.charge)>0)&&dist(p,e)<160);
  const shotReady=current.stats.vacuum&&Number(current.stats.energy)>=68&&distance<270;
  return {keys:next,target,distance,
    vacuum:!shotReady&&distance>65&&!chargingThreat,
    dash:(distance<85||chargingThreat)&&Number(current.stats.dash_ratio)>=.999&&next.length>0,
    pulse:distance<(current.stats.ability_id==='overdrive'?260:140)&&current.stats.ability_state==='ready'};
}
async function survive(){const begun=Date.now();let lastLog=-15,lastDash=-10;
  while(Date.now()-begun<240000){const s=await state();if(s.mode==='shop'){await release();check('Full first endless room cleared through normal inputs',s.stats.rooms_completed===1&&s.stats.wave_elapsed>=65,s.stats);return;}
    if(s.mode!=='playing')throw Error(`Survival interrupted: mode=${s.mode}, time=${s.stats.wave_elapsed}, health=${s.stats.health}, damage_events=${s.stats.damage_events}, damage_taken=${s.stats.damage_taken}`);
    const c=controls(s),t=Number(s.stats.wave_elapsed);await keys(c.keys);await aim(c.target.x,c.target.y);await suction(c.vacuum&&t-lastDash>.28);
    if(c.dash&&t-lastDash>1.6){await suction(false);await page.keyboard.press('Space');lastDash=t;}if(c.pulse)await page.keyboard.press('KeyE');
    if(t-lastLog>=10){console.log(`OVERTIME ${t.toFixed(1)}/65 health=${s.stats.health} kills=${s.stats.kills} scrap=${s.stats.currency} hits=${s.stats.damage_events}`);report.samples.push({time:t,health:s.stats.health,kills:s.stats.kills,charge:s.stats.ability_charge,currency:s.stats.currency,damage_events:s.stats.damage_events,damage_taken:s.stats.damage_taken,position:s.position});lastLog=t;}
    await delay(65);
  }throw Error('First room timed out without state overrides');
}
(async()=>{try{
  const servedResponse=await fetch(new URL('index.pck',url));
  const servedPack=Buffer.from(await servedResponse.arrayBuffer());
  report.served_package={status:servedResponse.status,bytes:servedPack.length,sha256:crypto.createHash('sha256').update(servedPack).digest('hex')};
  check('HTTP serves the exact final local Web PCK',servedResponse.ok&&report.served_package.sha256===report.package.sha256);
  browser=await chromium.launch({channel:browserChannel,headless:true,args:['--enable-webgl','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
  const context=await browser.newContext({viewport:{width:1280,height:720},deviceScaleFactor:1});page=await context.newPage();
  page.on('pageerror',e=>report.errors.push({type:'js',message:e.message}));page.on('console',m=>{if(m.type()==='error')report.errors.push({type:'console',message:m.text()});});
  page.on('requestfailed',r=>report.errors.push({type:'network',url:r.url(),failure:r.failure()}));page.on('response',r=>{if(r.status()>=400)report.errors.push({type:'http',url:r.url(),status:r.status()});});
  await page.goto(url,{waitUntil:'domcontentloaded'});await boot();
  check('Fresh profile defaults to English', (await state()).locale==='en');await snap('menu-en');
  await click(430,587);await waitMode('settings');await locale('zh_CN');await snap('settings-zh');await click(640,615);await waitMode('menu');await reload();
  check('Chinese selection persists after reload',(await state()).locale==='zh_CN');await page.setViewportSize({width:960,height:540});await snap('menu-zh-960');
  await click(175,587);await waitMode('archive');check('Achievement entry opens its own tab',(await state()).archive_tab==='achievements');await snap('achievements-zh-960');await page.keyboard.press('Escape');await waitMode('menu');
  await click(430,537);await waitMode('archive');check('History starts empty and opens independently',(await state()).archive_tab==='history'&&(await state()).profile.history_count===0);await page.keyboard.press('Escape');await waitMode('menu');
  await click(430,587);await waitMode('settings');await locale('en');await click(640,615);await waitMode('menu');await page.setViewportSize({width:1280,height:720});
  let s=await deploy(true);check('Primary mode launches endless with four slots',s.stats.endless_mode&&s.stats.weapon_slots===4&&s.stats.wave_duration===65);await snap('overtime-combat');
  await page.keyboard.press('KeyE');await delay(180);check('Active skill accepts normal input',(await state()).stats.ability_uses===1);
  await page.keyboard.press('Escape');s=await waitMode('pause');const t=s.stats.elapsed;await delay(900);check('Pause freezes combat time',(await state()).stats.elapsed===t);await page.keyboard.press('Escape');await waitMode('playing');
  await survive();s=await state();const shopTime=s.stats.elapsed,charge=s.stats.ability_charge;await delay(1100);check('Shop never counts time or recharges',(await state()).stats.elapsed===shopTime&&(await state()).stats.ability_charge===charge);await snap('shop');
  const offerIndex=s.shop_offers.findIndex(o=>!o.sold&&o.cost<=s.stats.currency);check('Earned scrap can buy an offered item',offerIndex>=0);const offer=s.shop_offers[offerIndex];await click(478+offerIndex*307,434);await delay(220);check('Purchase debits exact actual scrap',(await state()).stats.currency===s.stats.currency-offer.cost);
  await click(1080,687);s=await waitMode('route');check('Three distinct route choices are offered',s.stats.route_choices.length===3&&s.stats.route_choice===-1);await snap('route-unselected');
  const selected=s.stats.route_choices.findIndex(c=>c.risk==='armored');const idx=selected>=0?selected:0;await click(238+400*idx,519);await delay(200);s=await state();check('Route is chosen once',s.stats.route_choice===idx);const boons=JSON.stringify(s.stats.boons),routes=JSON.stringify(s.stats.route_choices);await snap('route-selected');await click(238+400*((idx+1)%3),519);await delay(220);check('A second route click cannot replace or stack the chosen route',(await state()).stats.route_choice===idx&&JSON.stringify((await state()).stats.boons)===boons);
  const checkpointWallet=s.stats.currency,checkpointOffers=JSON.stringify(s.shop_offers),checkpointLoadout=JSON.stringify(s.stats.loadout);
  await page.keyboard.press('Escape');await waitMode('shop');await click(134,687);await waitMode('menu');check('Checkpoint visible in main menu',(await state()).profile.has_checkpoint);await reload();await click(302,650);s=await waitMode('shop');
  check('Reload preserves chosen route and run bonuses',s.stats.route_choice===idx&&JSON.stringify(s.stats.boons)===boons&&JSON.stringify(s.stats.route_choices)===routes);
  check('Reload preserves exact shop wallet offers and loadout',s.stats.currency===checkpointWallet&&JSON.stringify(s.shop_offers)===checkpointOffers&&JSON.stringify(s.stats.loadout)===checkpointLoadout);await snap('shop-restored');
  await click(1080,687);await waitMode('route');await click(1050,677);s=await waitMode('playing');check('Chosen route advances exactly to room two',s.stats.endless_room===2&&s.stats.rooms_completed===1);await delay(1500);s=await abandon();
  check('Abandon settles earned endless progress and clears checkpoint',s.result.reward.ok&&s.result.abandoned&&!s.profile.has_checkpoint&&s.profile.history_count===1);const settledCoins=s.profile.coins;check('Completed first room grants actual earned coins',settledCoins>0);await snap('endless-result');await menu();
  await click(430,537);s=await waitMode('archive');check('Saved history is reachable from main menu',s.profile.history_count===1&&s.archive_tab==='history');await snap('history');await page.keyboard.press('Escape');await waitMode('menu');await reload();check('History survives a fresh browser reload',(await state()).profile.history_count===1);check('Reload retains coins without settling again',(await state()).profile.coins===settledCoins&&!(await state()).profile.has_checkpoint);
  s=await deploy(false);check('Standard mode remains distinct',s.stats.standard_mode&&!s.stats.endless_mode&&s.stats.weapon_slots===3&&s.stats.wave_duration===120);await abandon();await menu();
  await click(250,469);s=await waitMode('playing');check('Quick Sweep remains available',!s.stats.standard_mode&&!s.stats.endless_mode&&s.stats.duration===180);await abandon();await menu();
  check('No browser, script, network or HTTP errors',report.errors.length===0,report.errors);report.passed=true;
}catch(e){report.failure={message:e.message,stack:e.stack};process.exitCode=1;if(page)try{await release();await snap('failure');}catch(_){} }
finally{report.finished_at=new Date().toISOString();fs.writeFileSync(reportPath,JSON.stringify(report,null,2));fs.writeFileSync(path.join(root,`artifacts/v05-web-smoke-${runId}.json`),JSON.stringify(report,null,2));if(browser)await browser.close();console.log(JSON.stringify({passed:report.passed,checks:report.checks.length,failure:report.failure?.message,errors:report.errors.length}));}})();

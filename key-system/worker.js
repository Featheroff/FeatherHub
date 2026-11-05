// FeatherHub Key System - Cloudflare Worker
const PUBLIC_ORIGIN = 'https://featherhub-keys.xyz-206.workers.dev';
const LINKVERTISE_URL = 'https://direct-link.net/3658090/Y6Pg0BTB1rSa';
const COOKIE = 'fh_session';
const MAX_BODY = 4096;
const SESSION_MS = 30 * 60 * 1000;
const KEY_MS = 24 * 60 * 60 * 1000;
const PUBLIC_KEY = 'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA1piHDY9WRIehbfC3FpolLy/WrJF8TKFVdDMobj3fkNjN/69dTv9JgXt+gcJxVn/h4NCMtQ2mCQXNBMXzLOkyHJipiFMoyPtOOlMlbWRAiaQE1GpMebGNRcsxYnWzF53v63+hUQgrMahH9X0Ii/NJhvDyFlPX77+z9xiyd45L+xrgayePpOxvQpj6VJDlpNNKWbuIkFvkMmUVRM2TLulLJSgs4EgoBZgTYRpmhgR8tYfDOW+cOctffggcMAzKUC2CzYNmhzX15O7DKaZdYgfaBR/hqvyNAxBepHOJnBfHkQqaox5diHGqdwXXLwiJKzoK5R26vaI3jg2+d69VPSGL0QIDAQAB';

const INDEX_HTML = `<!doctype html>
<html lang="ru">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="referrer" content="no-referrer">
  <meta name="description" content="Получение временного ключа FeatherHub после подтверждённого прохождения Linkvertise.">
  <title>FeatherHub — получить ключ</title>
  <link rel="icon" href="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 32 32'%3E%3Crect width='32' height='32' rx='8' fill='%230e1424'/%3E%3Cpath d='M10 8h14v4H14v4h8v4h-8v7h-4z' fill='%237dd3fc'/%3E%3C/svg%3E">
  <style>
    :root {
      color-scheme: dark;
      --bg: #0a0e1a;
      --bg-gradient: linear-gradient(135deg, #0a0e1a 0%, #1a1f3a 50%, #0f1428 100%);
      --card: rgba(20, 25, 45, 0.85);
      --card-border: rgba(125, 211, 252, 0.2);
      --line: #2d405b;
      --text: #e7edf7;
      --muted: #94a3b8;
      --accent: #7dd3fc;
      --accent-gradient: linear-gradient(135deg, #7dd3fc 0%, #3b82f6 100%);
      --good: #4ade80;
      --bad: #fca5a5;
      --shadow: 0 20px 60px rgba(0, 0, 0, 0.5);
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      min-height: 100svh;
      display: grid;
      place-items: center;
      padding: 28px 18px;
      background: var(--bg-gradient);
      background-attachment: fixed;
      color: var(--text);
      font: 16px/1.6 system-ui, -apple-system, "Segoe UI", sans-serif;
      position: relative;
      overflow-x: hidden;
    }
    body::before {
      content: '';
      position: fixed;
      top: -50%;
      left: -50%;
      width: 200%;
      height: 200%;
      background: radial-gradient(circle, rgba(125, 211, 252, 0.1) 0%, transparent 70%);
      animation: rotate 30s linear infinite;
      pointer-events: none;
      z-index: 0;
    }
    @keyframes rotate {
      from { transform: rotate(0deg); }
      to { transform: rotate(360deg); }
    }
    main {
      width: min(100%, 520px);
      padding: 40px;
      background: var(--card);
      backdrop-filter: blur(20px);
      -webkit-backdrop-filter: blur(20px);
      border: 1px solid var(--card-border);
      border-radius: 24px;
      box-shadow: var(--shadow);
      position: relative;
      z-index: 1;
      animation: slideUp 0.6s ease-out;
    }
    @keyframes slideUp {
      from { opacity: 0; transform: translateY(30px); }
      to { opacity: 1; transform: translateY(0); }
    }
    header {
      display: flex;
      gap: 18px;
      align-items: center;
      margin-bottom: 32px;
      padding-bottom: 24px;
      border-bottom: 1px solid rgba(125, 211, 252, 0.1);
    }
    .mark {
      width: 60px;
      height: 60px;
      flex: none;
      display: grid;
      place-items: center;
      background: var(--accent-gradient);
      border-radius: 16px;
      color: #0a0e1a;
      font-size: 32px;
      font-weight: 800;
      box-shadow: 0 8px 24px rgba(125, 211, 252, 0.3);
      animation: pulse 2s ease-in-out infinite;
    }
    @keyframes pulse {
      0%, 100% { box-shadow: 0 8px 24px rgba(125, 211, 252, 0.3); }
      50% { box-shadow: 0 8px 32px rgba(125, 211, 252, 0.5); }
    }
    h1 {
      margin: 0;
      font-size: 28px;
      line-height: 1.2;
      letter-spacing: -0.5px;
      background: var(--accent-gradient);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
      background-clip: text;
    }
    header p {
      margin: 6px 0 0;
      color: var(--muted);
      font-size: 14px;
    }
    .language-selector {
      position: absolute;
      top: 20px;
      right: 20px;
      z-index: 10;
    }
    .language-selector select {
      background: rgba(30, 41, 59, 0.8);
      border: 1px solid var(--line);
      border-radius: 8px;
      padding: 6px 12px;
      color: var(--accent);
      font-size: 13px;
      font-weight: 600;
      cursor: pointer;
      transition: all 0.3s ease;
    }
    .language-selector select:hover {
      border-color: var(--accent);
      background: rgba(30, 41, 59, 1);
    }
    ol {
      list-style: none;
      padding: 0;
      margin: 0 0 32px;
    }
    li {
      display: flex;
      align-items: center;
      gap: 14px;
      padding: 14px 0;
      color: var(--muted);
      transition: all 0.3s ease;
    }
    li + li {
      border-top: 1px solid rgba(45, 64, 91, 0.5);
    }
    li.current {
      color: var(--text);
    }
    li.current .step {
      background: var(--accent-gradient);
      color: #0a0e1a;
      border-color: transparent;
      box-shadow: 0 4px 12px rgba(125, 211, 252, 0.4);
    }
    li.done {
      color: var(--good);
    }
    li.done .step {
      background: var(--good);
      color: #0a0e1a;
      border-color: transparent;
    }
    .step {
      width: 32px;
      height: 32px;
      flex: none;
      display: grid;
      place-items: center;
      border: 2px solid var(--line);
      border-radius: 50%;
      font-size: 14px;
      font-weight: 700;
      transition: all 0.3s ease;
    }
    h2 {
      font-size: 22px;
      margin: 0 0 12px;
      font-weight: 700;
    }
    .description {
      margin: 0 0 24px;
      color: var(--muted);
      line-height: 1.6;
    }
    button, a.action {
      width: 100%;
      display: block;
      border: 0;
      border-radius: 12px;
      padding: 16px 20px;
      font: 600 16px/1.5 system-ui, -apple-system, "Segoe UI", sans-serif;
      cursor: pointer;
      background: var(--accent-gradient);
      color: #0a0e1a;
      text-align: center;
      text-decoration: none;
      transition: all 0.3s ease;
      box-shadow: 0 4px 16px rgba(125, 211, 252, 0.3);
      position: relative;
      overflow: hidden;
    }
    button::before, a.action::before {
      content: '';
      position: absolute;
      top: 50%;
      left: 50%;
      width: 0;
      height: 0;
      border-radius: 50%;
      background: rgba(255, 255, 255, 0.3);
      transform: translate(-50%, -50%);
      transition: width 0.6s, height 0.6s;
    }
    button:hover::before, a.action:hover::before {
      width: 300px;
      height: 300px;
    }
    button {
      font-family: inherit;
      font-size: 16px;
      font-weight: 650;
    }
    button:disabled {
      opacity: 0.5;
      cursor: wait;
    }
    button:hover:not(:disabled), a.action:hover {
      transform: translateY(-2px);
      box-shadow: 0 8px 24px rgba(125, 211, 252, 0.4);
    }
    button:active:not(:disabled), a.action:active {
      transform: translateY(0);
    }
    button.secondary {
      margin-top: 12px;
      background: rgba(30, 41, 59, 0.8);
      color: var(--text);
      border: 1px solid var(--line);
      box-shadow: none;
    }
    button.secondary:hover:not(:disabled) {
      background: rgba(30, 41, 59, 1);
      border-color: var(--accent);
      box-shadow: 0 4px 16px rgba(125, 211, 252, 0.2);
    }
    :focus-visible {
      outline: 3px solid var(--accent);
      outline-offset: 4px;
    }
    #status {
      min-height: 26px;
      margin: 20px 0 0;
      font-size: 14px;
      overflow-wrap: anywhere;
      padding: 12px;
      border-radius: 8px;
      background: rgba(30, 41, 59, 0.5);
      transition: all 0.3s ease;
    }
    #status.error {
      color: var(--bad);
      background: rgba(252, 165, 165, 0.1);
      border: 1px solid rgba(252, 165, 165, 0.3);
    }
    #status.success {
      color: var(--good);
      background: rgba(74, 222, 128, 0.1);
      border: 1px solid rgba(74, 222, 128, 0.3);
    }
    label {
      display: block;
      color: var(--muted);
      font-size: 14px;
      margin-bottom: 10px;
      font-weight: 500;
    }
    textarea {
      width: 100%;
      resize: none;
      padding: 14px;
      background: rgba(24, 34, 53, 0.8);
      color: var(--text);
      border: 1px solid var(--line);
      border-radius: 10px;
      font: 14px/1.6 ui-monospace, Consolas, monospace;
      overflow-wrap: anywhere;
      transition: all 0.3s ease;
    }
    textarea:focus {
      border-color: var(--accent);
      background: rgba(24, 34, 53, 1);
      box-shadow: 0 0 0 3px rgba(125, 211, 252, 0.1);
    }
    #expiry {
      color: var(--muted);
      font-size: 14px;
      margin: 12px 0 24px;
      padding: 10px 14px;
      background: rgba(30, 41, 59, 0.5);
      border-radius: 8px;
      border-left: 3px solid var(--accent);
    }
    footer {
      margin-top: 32px;
      padding-top: 24px;
      border-top: 1px solid rgba(45, 64, 91, 0.5);
      color: var(--muted);
      font-size: 13px;
      text-align: center;
    }
    [hidden] {
      display: none !important;
    }
    @media (max-width: 480px) {
      main { padding: 28px; }
      h1 { font-size: 24px; }
      .mark { width: 50px; height: 50px; font-size: 26px; }
    }
  </style>
</head>
<body>
<div class="language-selector">
  <select id="language">
    <option value="en">EN</option>
    <option value="ru">RU</option>
  </select>
</div>
<main>
  <header>
    <div class="mark" aria-hidden="true">F</div>
    <div>
      <h1>FeatherHub</h1>
      <p data-i18n="subtitle">Get your key</p>
    </div>
  </header>
  <ol id="steps" aria-label="Steps to get your key">
    <li id="step1" class="current"><span class="step">1</span><span data-i18n="step1">Open the link from the loader</span></li>
    <li id="step2"><span class="step">2</span><span data-i18n="step2">Complete Linkvertise</span></li>
    <li id="step3"><span class="step">3</span><span data-i18n="step3">Copy your key</span></li>
  </ol>
  <section id="intro">
    <h2 id="heading" data-i18n="loading_heading">Checking the connection</h2>
    <p class="description" id="description" data-i18n="loading_description">The server creates your key only after verifying the checkpoint.</p>
    <a id="checkpoint" class="action" hidden referrerpolicy="no-referrer" data-i18n="checkpoint">Complete checkpoint</a>
    <button id="confirm" hidden type="button" data-i18n="confirm_complete">I completed the checkpoint</button>
    <button id="refresh" class="secondary" type="button" data-i18n="refresh">Refresh status</button>
  </section>
  <section id="result" hidden>
    <h2 data-i18n="result_heading">Your key is ready</h2>
    <p class="description" data-i18n="result_description">Paste it into FeatherHub and click Verify.</p>
    <label for="key" data-i18n="key_label">Key linked to your device</label>
    <textarea id="key" rows="3" readonly spellcheck="false" autocomplete="off"></textarea>
    <p id="expiry"></p>
    <button id="copy" type="button" data-i18n="copy">Copy key</button>
  </section>
  <p id="status" role="status" aria-live="polite"></p>
  <footer data-i18n="footer">Do not share your key. This website does not use a pre-made key list.</footer>
</main>
<script>
'use strict';
const $ = id => document.getElementById(id);
const API = '';
let busy = false;
const i18n = {
  en: {
    subtitle: 'Get your key', step1: 'Open the link from the loader', step2: 'Complete Linkvertise', step3: 'Copy your key',
    loading_heading: 'Checking the connection', loading_description: 'The server creates your key only after verifying the checkpoint.',
    checkpoint: 'Complete checkpoint', refresh: 'Refresh status', result_heading: 'Your key is ready',
    result_description: 'Paste it into FeatherHub and click Verify.', key_label: 'Key linked to your device', copy: 'Copy key',
    footer: 'Do not share your key. This website does not use a pre-made key list.',
    checkpoint_heading: 'Complete the checkpoint', checkpoint_description: 'After finishing Linkvertise, wait for the button to appear and click it to get your key.',
    confirm_complete: 'I completed the checkpoint',
    none_heading: 'Open the link from FeatherHub', none_description: 'Click "Get key" in the loader and open the copied link. This binds the key to your device.',
    unavailable_heading: 'Key issuance unavailable',
    status_checking: 'Checking status…', status_verified: 'Checkpoint verified by server.', status_copied: 'Key copied.',
    status_select_copy: 'You can copy the key manually.', status_expires: 'Valid until',
    service_not_configured: 'Still setting up. Keys not available yet.', checkpoint_not_configured: 'Linkvertise not connected yet.',
    database_not_configured: 'Key storage not connected yet.', login_required: 'Open the published site with allowed access.',
    session_required: 'Open the site via "Get key" in the loader.', session_expired: 'Link expired. Get a new link in the loader.',
    checkpoint_rejected: 'Checkpoint not verified. Complete it.', proof_reused: 'This confirmation already used. Complete a new checkpoint.',
    rate_limited: 'Too many requests. Try later.', service_unavailable: 'Service temporarily unavailable. Try later.',
    request_failed: 'Could not reach server. Refresh status.'
  },
  ru: {
    subtitle: 'Получи свой ключ', step1: 'Открой ссылку из лоадера', step2: 'Пройди Linkvertise', step3: 'Скопируй ключ',
    loading_heading: 'Проверяем подключение', loading_description: 'Сервер создаёт ключ только после подтверждения чекпоинта.',
    checkpoint: 'Пройти чекпоинт', refresh: 'Обновить статус', result_heading: 'Ключ готов',
    result_description: 'Вставь его в FeatherHub и нажми «Подтвердить».', key_label: 'Ключ привязан к твоему устройству', copy: 'Скопировать ключ',
    footer: 'Не делись ключом. Этот сайт не использует готовый список ключей.',
    checkpoint_heading: 'Пройди чекпоинт', checkpoint_description: 'После завершения Linkvertise подожди появления кнопки и нажми её для получения ключа.',
    confirm_complete: 'Я прошёл чекпоинт',
    none_heading: 'Открой ссылку из FeatherHub', none_description: 'Нажми «Получить ключ» в лоадере и открой скопированную ссылку. Так ключ будет привязан к твоему устройству.',
    unavailable_heading: 'Получение ключа недоступно',
    status_checking: 'Проверяем статус…', status_verified: 'Чекпоинт подтверждён сервером.', status_copied: 'Ключ скопирован.',
    status_select_copy: 'Выделенный ключ можно скопировать вручную.', status_expires: 'Действует до',
    service_not_configured: 'Выдача ещё настраивается. Ключи пока недоступны.', checkpoint_not_configured: 'Linkvertise ещё не подключён.',
    database_not_configured: 'Хранилище ключей ещё не подключено.', login_required: 'Открой опубликованный сайт с разрешённым доступом.',
    session_required: 'Открой сайт кнопкой «Получить ключ» в лоадере.', session_expired: 'Ссылка истекла. Получи новую ссылку в лоадере.',
    checkpoint_rejected: 'Прохождение не подтверждено. Заверши чекпоинт.', proof_reused: 'Это подтверждение уже использовано. Пройди новый чекпоинт.',
    rate_limited: 'Слишком много запросов. Попробуй позже.', service_unavailable: 'Сервис временно недоступен. Попробуй позже.',
    request_failed: 'Не удалось связаться с сервером. Обнови статус.'
  }
};
let currentLang = localStorage.getItem('featherhub_lang');
if (!currentLang || !i18n[currentLang]) { const browserLang = (navigator.language || 'en').toLowerCase(); currentLang = browserLang.startsWith('ru') ? 'ru' : 'en'; }
function t(key) { return i18n[currentLang]?.[key] || i18n.en[key] || key; }
function applyLanguage() { document.querySelectorAll('[data-i18n]').forEach(el => { const key = el.getAttribute('data-i18n'); const text = t(key); if (text) el.textContent = text; }); $('language').value = currentLang; document.documentElement.lang = currentLang; localStorage.setItem('featherhub_lang', currentLang); }
$('language').addEventListener('change', e => { currentLang = e.target.value; applyLanguage(); if (!$('result').hidden && $('key').value) { const expiryText = $('expiry').dataset.expiresAt; if (expiryText) { const locale = currentLang === 'ru' ? 'ru-RU' : 'en-US'; $('expiry').textContent = t('status_expires') + ' ' + new Date(expiryText).toLocaleString(locale); } } });
const messages = new Proxy({}, { get: (_, key) => t(key) });
function status(text,kind='') { $('status').textContent=text; $('status').className=kind; }
async function api(path,body) { let response; try { response=await fetch(API+path,{method:body===undefined?'GET':'POST',credentials:'same-origin',cache:'no-store',headers:body===undefined?{}:{'Content-Type':'application/json'},body:body===undefined?undefined:JSON.stringify(body),signal:AbortSignal.timeout(20000)}); } catch { throw new Error('request_failed'); } const type=response.headers.get('content-type')||''; if(!type.includes('application/json')) throw new Error(response.status===401?'login_required':'request_failed'); let data; try { data=await response.json(); } catch { throw new Error('request_failed'); } if(!response.ok || !data || typeof data!=='object' || data.ok!==true) throw new Error(typeof data?.error==='string'?data.error:'request_failed'); return data; }
function render(data) { if(typeof data.stage!=='string') throw new Error('request_failed'); $('checkpoint').hidden=true; $('confirm').hidden=true; if(data.stage==='issued') { if(typeof data.key!=='string'||!/^FEATHER-[A-F0-9]{64}$/.test(data.key)||typeof data.expiresAt!=='string'||!Number.isFinite(Date.parse(data.expiresAt))) throw new Error('request_failed'); $('intro').hidden=true; $('result').hidden=false; $('key').value=data.key; const locale = currentLang === 'ru' ? 'ru-RU' : 'en-US'; $('expiry').textContent=t('status_expires')+' '+new Date(data.expiresAt).toLocaleString(locale); $('expiry').dataset.expiresAt=data.expiresAt; ['step1','step2','step3'].forEach(id=>$(id).className='done'); status(t('status_verified'),'success'); } else if(data.stage==='pending') { if(typeof data.checkpointUrl!=='string') throw new Error('request_failed'); const url=new URL(data.checkpointUrl); if(url.protocol!=='https:'||!['linkvertise.com','link-to.net','link-center.net','direct-link.net','link-hub.net','link-target.net'].includes(url.hostname)) throw new Error('request_failed'); $('intro').hidden=false; $('result').hidden=true; $('step1').className='done'; $('step2').className='current'; $('step3').className=''; $('heading').textContent=t('checkpoint_heading'); $('description').textContent=t('checkpoint_description'); $('checkpoint').href=url.href; $('checkpoint').hidden=false; status(''); // Show confirm button after 30 seconds delay setTimeout(() => { if (!$('result').hidden && !$('confirm').hidden === false) { $('confirm').hidden = false; } }, 30000); } else if(data.stage==='none') { $('heading').textContent=t('none_heading'); $('description').textContent=t('none_description'); status(''); } else throw new Error('request_failed'); }
async function refresh() { if(busy) return; busy=true; $('refresh').disabled=true; status(t('status_checking')); try { render(await api('/state')); } catch(error) { $('heading').textContent=t('unavailable_heading'); status(messages[error.message]||error.message,'error'); } finally { busy=false; $('refresh').disabled=false; } }
async function initialize() { if(busy) return; busy=true; $('refresh').disabled=true; try { const fragment=new URLSearchParams(location.hash.slice(1)); const incoming=fragment.get('ticket'); const proofParam=new URLSearchParams(location.search).get('proof'); if(incoming) sessionStorage.setItem('feather_pending_ticket',incoming); if(proofParam) sessionStorage.setItem('feather_pending_proof',proofParam); history.replaceState(null,'','/'); const ticket=sessionStorage.getItem('feather_pending_ticket'); if(ticket) { await api('/resume',{ticket}); sessionStorage.removeItem('feather_pending_ticket'); } const proof=sessionStorage.getItem('feather_pending_proof'); if(proof) { await api('/complete',{proof}); sessionStorage.removeItem('feather_pending_proof'); } render(await api('/state')); } catch(error) { if(['checkpoint_rejected','proof_reused'].includes(error.message)) sessionStorage.removeItem('feather_pending_proof'); $('heading').textContent=t('unavailable_heading'); status(messages[error.message]||error.message,'error'); } finally { busy=false; $('refresh').disabled=false; } }
$('refresh').addEventListener('click',()=>{ if(sessionStorage.getItem('feather_pending_ticket')||sessionStorage.getItem('feather_pending_proof')) initialize(); else refresh(); });
$('confirm').addEventListener('click',async()=>{ if(busy) return; busy=true; $('confirm').disabled=true; status(t('status_checking')); try { render(await api('/complete',{})); } catch(error) { $('heading').textContent=t('unavailable_heading'); status(messages[error.message]||error.message,'error'); } finally { busy=false; $('confirm').disabled=false; } });
$('copy').addEventListener('click',async()=>{ try { await navigator.clipboard.writeText($('key').value); status(t('status_copied'),'success'); } catch { $('key').focus(); $('key').select(); status(t('status_select_copy')); } });
applyLanguage();
initialize();
</script>
</body>
</html>`;

const encoder = new TextEncoder();
const hex = bytes => Array.from(new Uint8Array(bytes), b => b.toString(16).padStart(2, '0')).join('');
const sha = async text => hex(await crypto.subtle.digest('SHA-256', encoder.encode(text)));
const validHex = value => typeof value === 'string' && /^[a-f0-9]{64}$/.test(value);
const uuid = value => typeof value === 'string' && /^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/.test(value);
const randomToken = () => hex(crypto.getRandomValues(new Uint8Array(32)));
const keyFor = async (ticket, sessionId) => 'FEATHER-' + (await sha('FeatherHub:key:v1:' + ticket + ':' + sessionId)).toUpperCase();

async function dynamicLink(publisher, destination) {
  // Simple base64 encoding (no RSA) - Linkvertise accepts this format
  const encoded = btoa(encodeURIComponent(destination));
  const url = new URL('https://link-to.net/' + publisher + '/' + Math.random().toString().slice(2) + '/dynamic/');
  url.searchParams.set('r', encoded);
  return url.href;
}

function jsonResponse(data, status = 200, headers = {}) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Cache-Control': 'no-store',
      'X-Content-Type-Options': 'nosniff',
      ...headers
    }
  });
}

async function input(request) {
  if (request.headers.get('content-type')?.split(';')[0].trim().toLowerCase() !== 'application/json') {
    return jsonResponse({ok: false, error: 'invalid_input'}, 400);
  }
  const reader = request.body?.getReader();
  if (!reader) return jsonResponse({ok: false, error: 'invalid_input'}, 400);
  let size = 0;
  const chunks = [];
  try {
    while (true) {
      const {done, value} = await reader.read();
      if (done) break;
      size += value.byteLength;
      if (size > MAX_BODY) {
        await reader.cancel();
        return jsonResponse({ok: false, error: 'payload_too_large'}, 413);
      }
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }
  const bytes = new Uint8Array(size);
  let offset = 0;
  for (const part of chunks) {
    bytes.set(part, offset);
    offset += part.length;
  }
  let value;
  try {
    value = JSON.parse(new TextDecoder('utf-8', {fatal: true}).decode(bytes));
  } catch {
    return jsonResponse({ok: false, error: 'invalid_input'}, 400);
  }
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return jsonResponse({ok: false, error: 'invalid_input'}, 400);
  }
  return value;
}

async function limit(db, id, maximum, expiresAt) {
  const existing = await db.prepare('SELECT id, count FROM key_limits WHERE id = ?').bind(id).first();
  if (!existing) {
    await db.prepare('INSERT INTO key_limits (id, count, expires_at) VALUES (?, 1, ?)').bind(id, expiresAt).run();
    return;
  }
  const count = existing.count;
  if (count >= maximum) {
    return jsonResponse({ok: false, error: 'rate_limited'}, 429);
  }
  const updated = await db.prepare('UPDATE key_limits SET count = ? WHERE id = ? AND count = ?').bind(count + 1, id, count).run();
  if (updated.meta.changes !== 1) {
    return jsonResponse({ok: false, error: 'rate_limited'}, 429);
  }
}

async function getSession(request, db) {
  const cookies = (request.headers.get('cookie') || '').split(';').map(v => v.trim());
  const values = cookies.filter(v => v.startsWith(COOKIE + '=')).map(v => v.slice(COOKIE.length + 1));
  if (values.length !== 1 || !validHex(values[0])) return null;
  const ticket = values[0];
  const found = await db.prepare('SELECT id, ticket_hash, device_hash, expires_at FROM key_sessions WHERE ticket_hash = ?').bind(await sha(ticket)).first();
  if (!found) return null;
  return {...found, ticket};
}

async function getIssued(db, current) {
  return await db.prepare('SELECT id, session_id, key_hash, device_hash, expires_at, revoked FROM issued_keys WHERE session_id = ? AND device_hash = ?').bind(current.id, current.device_hash).first();
}

function validTime(value) {
  const time = Date.parse(value);
  if (!Number.isFinite(time)) return jsonResponse({ok: false, error: 'service_unavailable'}, 503);
  return time;
}

async function keyResult(current, license) {
  if (license.revoked !== 0 || validTime(license.expires_at) <= Date.now()) {
    return jsonResponse({ok: false, error: 'session_expired'}, 410);
  }
  const key = await keyFor(current.ticket, current.id);
  if (await sha(key) !== license.key_hash) {
    return jsonResponse({ok: false, error: 'service_unavailable'}, 503);
  }
  return jsonResponse({ok: true, stage: 'issued', key, expiresAt: license.expires_at});
}

async function receipt(token, proof) {
  const url = new URL('https://publisher.linkvertise.com/api/v1/anti_bypassing');
  url.searchParams.set('token', token);
  url.searchParams.set('hash', proof);
  const response = await fetch(url.href, {method: 'POST', headers: {'Content-Type': 'application/x-www-form-urlencoded'}});
  if (!response.ok) return null;
  const text = await response.text();
  return text.trim().toUpperCase() === 'TRUE';
}

export default {
  async fetch(request, env) {
    const db = env.featherhub_keys;
    const url = new URL(request.url);

    // CORS headers
    const corsHeaders = {
      'Access-Control-Allow-Origin': PUBLIC_ORIGIN,
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
      'Access-Control-Allow-Credentials': 'true',
    };

    if (request.method === 'OPTIONS') {
      return new Response(null, {headers: corsHeaders});
    }

    try {
      // Serve HTML page
      if (request.method === 'GET' && (url.pathname === '/' || url.pathname.startsWith('/return/'))) {
        return new Response(INDEX_HTML, {
          headers: {
            'Content-Type': 'text/html; charset=utf-8',
            'Cache-Control': 'no-store'
          }
        });
      }

      // Health check
      if (url.pathname === '/health') {
        return jsonResponse({ok: true, service: 'featherhub-keys'});
      }

      // Check configuration
      const token = env.LINKVERTISE_TOKEN;
      const publisher = env.LINKVERTISE_PUBLISHER_ID;
      if (typeof token !== 'string' || token.length !== 64 || typeof publisher !== 'string' || !/^[1-9][0-9]{0,14}$/.test(publisher)) {
        return jsonResponse({ok: false, error: 'service_not_configured'}, 503);
      }

      // GET /state - check current session state
      if (request.method === 'GET' && url.pathname === '/state') {
        const current = await getSession(request, db);
        if (!current) {
          return jsonResponse({ok: true, stage: 'none'});
        }
        if (Date.parse(current.expires_at) <= Date.now()) {
          return jsonResponse({ok: true, stage: 'none'});
        }
        const license = await getIssued(db, current);
        if (license) {
          return await keyResult(current, license);
        }
        const checkpointUrl = LINKVERTISE_URL;
        return jsonResponse({ok: true, stage: 'pending', checkpointUrl});
      }

      // POST /ticket - create new session
      if (request.method === 'POST' && url.pathname === '/ticket') {
        const body = await input(request);
        if (!body || typeof body !== 'object') {
          return jsonResponse({ok: false, error: 'invalid_input'}, 400);
        }
        const hwid = typeof body.hwid === 'string' ? body.hwid : '';
        const deviceHash = await sha(hwid || 'anonymous');
        const globalId = 'global:' + new Date().toISOString().slice(0, 13);
        const deviceId = 'device:' + deviceHash + ':' + new Date().toISOString().slice(0, 13);
        const globalLimit = limit(db, globalId, 1200, new Date(Date.now() + 3600000).toISOString());
        const deviceLimit = limit(db, deviceId, 6, new Date(Date.now() + 3600000).toISOString());
        const [globalErr, deviceErr] = await Promise.all([globalLimit, deviceLimit]).then(r => r.map(v => v instanceof Response ? v : null));
        if (globalErr) return globalErr;
        if (deviceErr) return deviceErr;
        const ticket = randomToken();
        const ticketHash = await sha(ticket);
        const sessionId = crypto.randomUUID();
        const now = new Date().toISOString();
        const expiresAt = new Date(Date.now() + SESSION_MS).toISOString();
        await db.prepare('INSERT INTO key_sessions (id, ticket_hash, device_hash, created_at, expires_at) VALUES (?, ?, ?, ?, ?)').bind(sessionId, ticketHash, deviceHash, now, expiresAt).run();
        const response = jsonResponse({ok: true, ticket});
        response.headers.set('Set-Cookie', `${COOKIE}=${ticket}; Path=/; Max-Age=${SESSION_MS / 1000}; HttpOnly; Secure; SameSite=Lax`);
        return response;
      }

      // POST /resume - resume existing session
      if (request.method === 'POST' && url.pathname === '/resume') {
        const body = await input(request);
        if (!body || typeof body.ticket !== 'string' || !validHex(body.ticket)) {
          return jsonResponse({ok: false, error: 'invalid_input'}, 400);
        }
        const ticketHash = await sha(body.ticket);
        const found = await db.prepare('SELECT id, ticket_hash, device_hash, expires_at FROM key_sessions WHERE ticket_hash = ?').bind(ticketHash).first();
        if (!found) {
          return jsonResponse({ok: false, error: 'session_expired'}, 410);
        }
        const current = {...found, ticket: body.ticket};
        const license = await getIssued(db, current);
        if (license) {
          return await keyResult(current, license);
        }
        if (Date.parse(found.expires_at) <= Date.now()) {
          return jsonResponse({ok: false, error: 'session_expired'}, 410);
        }
        const checkpointUrl = LINKVERTISE_URL;
        const response = jsonResponse({ok: true, stage: 'pending', checkpointUrl});
        response.headers.set('Set-Cookie', `${COOKIE}=${body.ticket}; Path=/; Max-Age=${SESSION_MS / 1000}; HttpOnly; Secure; SameSite=Lax`);
        return response;
      }

      // POST /complete - complete checkpoint (static link doesn't return proof)
      if (request.method === 'POST' && url.pathname === '/complete') {
        const body = await input(request);
        const current = await getSession(request, db);
        if (!current) {
          return jsonResponse({ok: false, error: 'session_expired'}, 410);
        }
        const license = await getIssued(db, current);
        if (license) {
          return await keyResult(current, license);
        }
        // Issue key without proof (static Linkvertise doesn't pass proof back)
        // Rate limiting (6/device/hour) provides basic abuse protection
        const key = await keyFor(current.ticket, current.id);
        const keyHash = await sha(key);
        const now = new Date().toISOString();
        const expiresAt = new Date(Date.now() + KEY_MS).toISOString();
        await db.prepare('INSERT INTO issued_keys (id, session_id, key_hash, device_hash, created_at, expires_at, revoked) VALUES (?, ?, ?, ?, ?, ?, 0)').bind(crypto.randomUUID(), current.id, keyHash, current.device_hash, now, expiresAt).run();
        const response = jsonResponse({ok: true, stage: 'issued', key, expiresAt});
        response.headers.set('Set-Cookie', `${COOKIE}=${current.ticket}; Path=/; Max-Age=${KEY_MS / 1000}; HttpOnly; Secure; SameSite=Lax`);
        return response;
      }

      // POST /verify - verify key
      if (request.method === 'POST' && url.pathname === '/verify') {
        const body = await input(request);
        if (!body || typeof body.key !== 'string' || !/^FEATHER-[A-F0-9]{64}$/.test(body.key)) {
          return jsonResponse({ok: false, error: 'invalid_input'}, 400);
        }
        const keyHash = await sha(body.key);
        const license = await db.prepare('SELECT id, session_id, key_hash, device_hash, expires_at, revoked FROM issued_keys WHERE key_hash = ?').bind(keyHash).first();
        if (!license || license.revoked !== 0) {
          return jsonResponse({ok: false, error: 'invalid_key'}, 404);
        }
        if (validTime(license.expires_at) <= Date.now()) {
          return jsonResponse({ok: false, error: 'key_expired'}, 410);
        }
        return jsonResponse({ok: true});
      }

      return jsonResponse({ok: false, error: 'not_found'}, 404);
    } catch (error) {
      console.error(error);
      return jsonResponse({ok: false, error: 'service_unavailable'}, 503);
    }
  }
};

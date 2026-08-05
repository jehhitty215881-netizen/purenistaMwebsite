/**
 * Purenista 全站功能熱門計數 — Cloudflare Worker（D1 版）
 *
 * 為什麼從 KV 換成 D1
 * ---------------------
 * 前一版把所有計數存在同一個 KV key，流程是「讀出整包 → +1 → 寫回」。這在單人測試時
 * 看起來完全正常，多人同時使用就會壞：
 *
 *   1. 遺失更新：KV 沒有原子加法。兩個人同時點，兩邊都讀到 100，兩邊都寫回 101 —
 *      少算一次。網站越熱門，少算越多。
 *   2. 同一個 key 每秒只能寫一次。22 個分頁全擠在同一個 key，尖峰時寫入會被丟掉。
 *   3. 免費方案 KV 每天只有 1,000 次寫入。用完之後當天就靜靜地停止計數，
 *      不會報錯，只是數字不再動。
 *
 * D1（Cloudflare 的免費 SQLite）用一行 SQL 就能原子遞增，免費額度是每天 10 萬次寫入。
 * 三個問題一次解決。
 *
 * 部署步驟（約 5 分鐘，全部免費）
 * --------------------------------
 * 1. 註冊 https://dash.cloudflare.com
 * 2. Storage & Databases → D1 → Create database（名稱隨意，例如 purenista）
 * 3. 進入該資料庫 → Console，貼上並執行：
 *
 *      CREATE TABLE IF NOT EXISTS hits (
 *        tab TEXT PRIMARY KEY,
 *        n   INTEGER NOT NULL DEFAULT 0
 *      );
 *
 * 4. Workers & Pages → Create Worker → 貼上本檔全部內容 → Deploy
 * 5. 該 Worker → Settings → Bindings → Add → D1 database
 *      Variable name 填：DB
 *      選剛才建立的資料庫
 * 6. 再按一次 Deploy
 * 7. 複製 Worker 網址（形如 https://purenista-rank.你的帳號.workers.dev）
 * 8. 打開 index.html 與 en.html，搜尋：
 *      var GLOBAL_RANK_ENDPOINT = '';
 *    改成：
 *      var GLOBAL_RANK_ENDPOINT = 'https://你的網址';
 * 9. 重新推送到 GitHub Pages
 *
 * 隱私
 * ----
 * - 只記「分頁名稱 → 累計次數」，沒有帳號、沒有 IP、沒有任何識別碼寫入資料庫
 * - GLOBAL_RANK_ENDPOINT 留空時，網站完全不會送出請求
 * - 同一瀏覽器同一分頁 60 秒內只會 +1
 *
 * API
 * ---
 *   GET  /   → { "calc": 12, "check": 5, ... }
 *   POST /   body: { "tab": "calc" } → 該分頁 +1 後回傳完整物件
 */

/* 想擋掉別人用 curl 灌票，就把你的網域填進來，例如：
     const ORIGINS = ['https://你的帳號.github.io'];
   留空陣列＝接受任何來源。註記：這只擋得住瀏覽器裡的呼叫，擋不住直接打 API 的人——
   真的要防刷需要驗證碼或登入，不在這個小工具的範圍。 */
const ORIGINS = [];

const ALLOW = new Set([
  'home','calc','ratio','market','pull','vip','brand','branddata','trade','sched',
  'check','workspace','colorinspire','naming','charcheck','flow','aes','lore','qa',
  'feedback','notes','changelog'
]);

function cors(request) {
  const origin = request.headers.get('Origin') || '';
  const allow = ORIGINS.length === 0 ? '*' : (ORIGINS.indexOf(origin) >= 0 ? origin : '');
  const h = {
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
  };
  if (allow) h['Access-Control-Allow-Origin'] = allow;
  if (ORIGINS.length) h['Vary'] = 'Origin';
  return h;
}

function json(data, request, status) {
  return new Response(JSON.stringify(data), { status: status || 200, headers: cors(request) });
}

async function readAll(env) {
  const { results } = await env.DB.prepare('SELECT tab, n FROM hits').all();
  const out = {};
  for (const row of results || []) {
    // never echo back a tab the site does not know about
    if (ALLOW.has(row.tab)) out[row.tab] = row.n | 0;
  }
  return out;
}

export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: cors(request) });
    }
    if (!env.DB) {
      return json({ error: 'D1 binding DB missing - bind a D1 database named DB (see header)' }, request, 500);
    }

    if (request.method === 'GET') {
      try {
        return json(await readAll(env), request);
      } catch (e) {
        // the usual cause is step 3 being skipped, so say so rather than returning a bare 500
        return json({ error: 'read failed - has the hits table been created?' }, request, 500);
      }
    }

    if (request.method === 'POST') {
      let body = {};
      try { body = await request.json(); } catch (e) { return json({ error: 'bad json' }, request, 400); }
      const tab = String(body.tab || '');
      if (!ALLOW.has(tab)) return json({ error: 'unknown tab' }, request, 400);
      try {
        // one atomic statement: no read-modify-write, so two visitors clicking at the same
        // moment can no longer overwrite each other's increment the way they did on KV
        await env.DB.prepare(
          'INSERT INTO hits (tab, n) VALUES (?1, 1) ON CONFLICT(tab) DO UPDATE SET n = n + 1'
        ).bind(tab).run();
        return json(await readAll(env), request);
      } catch (e) {
        return json({ error: 'write failed - has the hits table been created?' }, request, 500);
      }
    }

    return json({ error: 'method not allowed' }, request, 405);
  }
};

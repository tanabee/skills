// open スキル用: --remote-debugging-port=0 付きで起動した専用 Chrome のタブを CDP で操作する (依存なし。Node 22+ の WebSocket を使う)
//   node cdp.mjs <user-data-dir> list                 タブ一覧 (id<TAB>url)
//   node cdp.mjs <user-data-dir> open <url>           同 URL のタブがあれば前面化してリロード (ハッシュだけ違えばハッシュ遷移)。無ければ新規タブ
//   node cdp.mjs <user-data-dir> reload <urlSubstr>   URL に部分一致するタブをリロード
// ポートは <user-data-dir>/DevToolsActivePort (Chrome が起動時に書く) の 1 行目から読む。repo ごとに別プロファイルを使えば
// ポートの衝突も取り違えも起きない。第 1 引数に数字を渡した場合はそれをポートとして使う
// 終了コード: 0 成功 / 2 接続できない (Chrome 未起動、ファイルが前回起動時の残骸、または --remote-debugging-port 無しで起動中)
import { readFileSync } from 'node:fs';
const [target, cmd, arg] = process.argv.slice(2);
let port = target;
if (!/^\d+$/.test(target ?? '')) {
  try { port = readFileSync(`${target}/DevToolsActivePort`, 'utf8').split('\n')[0].trim(); }
  catch { console.error(`no DevToolsActivePort in ${target}`); process.exit(2); }
}
const base = `http://127.0.0.1:${port}`;
const stripHash = u => u.split('#')[0];

async function list() {
  try { return (await (await fetch(`${base}/json/list`)).json()).filter(t => t.type === 'page'); }
  catch { console.error(`cannot connect to ${base}`); process.exit(2); }
}
async function cdp(ws, method, params = {}) {
  const sock = new WebSocket(ws);
  await new Promise((ok, ng) => { sock.onopen = ok; sock.onerror = ng; });
  const res = await new Promise((ok, ng) => {
    sock.onmessage = e => { const m = JSON.parse(e.data); if (m.id === 1) m.error ? ng(m.error) : ok(m.result); };
    sock.send(JSON.stringify({ id: 1, method, params }));
  });
  sock.close();
  return res;
}
const activate = t => fetch(`${base}/json/activate/${t.id}`, { method: 'PUT' });

if (cmd === 'list') {
  console.log((await list()).map(t => `${t.id}\t${t.url}`).join('\n'));
} else if (cmd === 'open') {
  const tabs = await list();
  const t = tabs.find(x => x.url === arg) || tabs.find(x => stripHash(x.url) === stripHash(arg));
  if (!t) {
    const r = await (await fetch(`${base}/json/new?${arg}`, { method: 'PUT' })).json();
    console.log(`opened ${r.id}`);
  } else {
    await activate(t);
    if (t.url === arg) { await cdp(t.webSocketDebuggerUrl, 'Page.reload'); console.log(`reloaded ${t.id}`); }
    else { await cdp(t.webSocketDebuggerUrl, 'Page.navigate', { url: arg }); console.log(`navigated ${t.id}`); }
  }
} else if (cmd === 'reload') {
  const t = (await list()).find(x => x.url.includes(arg));
  if (!t) { console.error('no matching tab'); process.exit(1); }
  await activate(t); await cdp(t.webSocketDebuggerUrl, 'Page.reload'); console.log(`reloaded ${t.id}`);
} else {
  console.error('usage: node cdp.mjs <user-data-dir|port> list | open <url> | reload <urlSubstr>'); process.exit(1);
}

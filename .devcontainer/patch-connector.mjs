import fs from "node:fs";
const FILE = process.argv[2] || "connector.luau";
if (!fs.existsSync(FILE)) { console.error(`  ✗ 文件不存在: ${FILE}`); process.exit(1); }
let src = fs.readFileSync(FILE, "utf8");
if (src.includes("BridgeHttpBase")) { console.log("  已打过补丁，跳过"); process.exit(0); }
const anchor = `local BridgeURL = getgenv().BridgeURL or ... or "localhost:16384"`;
if (!src.includes(anchor)) { console.error("  ✗ 未找到 BridgeURL 锚点"); process.exit(1); }
const helper = `${anchor}

--// Protocol Auto-Detect (Codespaces / HTTPS 适配) \\--
local BridgeHttpBase, BridgeWsBase
do
    local raw = tostring(BridgeURL or "")
    raw = raw:gsub("^%s+", ""):gsub("%s+$", ""):gsub("/+$", "")
    if raw:match("^https://") then
        BridgeHttpBase = raw
        BridgeWsBase = raw:gsub("^https://", "wss://")
    elseif raw:match("^wss://") then
        BridgeWsBase = raw
        BridgeHttpBase = raw:gsub("^wss://", "https://")
    elseif raw:match("^http://") then
        BridgeHttpBase = raw
        BridgeWsBase = raw:gsub("^http://", "ws://")
    elseif raw:match("^ws://") then
        BridgeWsBase = raw
        BridgeHttpBase = raw:gsub("^ws://", "http://")
    else
        BridgeHttpBase = "http://" .. raw
        BridgeWsBase = "ws://" .. raw
    end
end`;
src = src.replace(anchor, helper);
const reps = [
  [`Url = "http://" .. BridgeURL,`, "Url = BridgeHttpBase,"],
  [`WebSocket.connect("ws://" .. BridgeURL)`, "WebSocket.connect(BridgeWsBase)"],
  [`Url = "http://" .. BridgeURL .. "/register",`, `Url = BridgeHttpBase .. "/register",`],
  [`local pollUrl = "http://" .. BridgeURL .. "/poll"`, `local pollUrl = BridgeHttpBase .. "/poll"`],
  [`Url = "http://" .. BridgeURL .. "/respond",`, `Url = BridgeHttpBase .. "/respond",`],
  [`Url = "http://" .. BridgeURL .. "/script-sources",`, `Url = BridgeHttpBase .. "/script-sources",`],
];
let n = 0;
for (const [from, to] of reps) {
  const c = src.split(from).length - 1;
  if (c === 0) { console.error(`  ✗ 未匹配到: ${from}`); process.exit(1); }
  src = src.split(from).join(to); n += c;
}
fs.writeFileSync(FILE, src);
console.log(`  ✓ 替换 ${n} 处硬编码协议`);

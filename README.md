# 作品健檢 · Purenista M 交換速查手冊

GitHub Pages 版。**這個資料夾裡的檔案就是全部**，直接上傳到 repo 根目錄即可。

```
index.html   ← 中文版（首頁）
en.html      ← 英文版
```

沒有任何絕對路徑，放在子目錄（例如 `/purenistaMwebsite/`）也不會壞。

---

## AI 視覺輔助

不需要部署任何後端。在網頁的 ④ 進階選項：

1. 勾選「使用 AI 視覺輔助」
2. 在「① 直接填你自己的 API key」貼上 console.anthropic.com 申請的 key
3. 選模型（`claude-haiku-4-5` 最便宜，`claude-sonnet-5` 較準）

key 存在這台裝置的瀏覽器，只送到 `api.anthropic.com`，不經過你的網站。

⚠️ 共用電腦不建議填。**絕對不要把 key 寫進 HTML 再上傳**——那會公開給所有人。

### 什麼時候才需要 Cloudflare Worker

只有當你想**開放給其他玩家使用**、由你付所有人的 API 費用時才需要。
那種情況 key 不能放在訪客的瀏覽器裡，必須放伺服器端。
需要的話跟我說，我再給你 worker 檔案。

---

## 前一版有但這裡刪掉的檔案

| 檔案 | 為什麼不需要 |
|---|---|
| `netlify.toml` | Netlify 專用設定，GitHub Pages 讀不到 |
| `_redirects` | Netlify 專用。只做 `/en` → `/en.html`，但站內連結都直接寫 `en.html` |
| `netlify/functions/analyze.js` | GitHub Pages 不能跑 serverless |
| `cloudflare/worker.js` | 是貼進 Cloudflare 後台的，不是放網站的檔案 |

---

## 功能

**分析模組**：構圖型態 18 種／美的形式原理 10 項／光影質地 6 項／
配色法則 7 種＋風格色系 8 組／人像構圖（含關節裁切）／文字層／動漫臉部偵測（純 JS，無 opencv）

**美學專欄**：構圖 26 條、形式原理 10 項、光影 13 項、色彩 7 法＋8 組色卡、
人像 17 項、排版 16 項，皆從攝影／繪畫／設計三個角度說明。另有「哪一項弱就找哪種老師」學習路線。

報告分四個分頁（總結／構圖／色彩・光影／細節），最上方有一句話結論。

# 作品健檢 · Purenista M 交換速查手冊

GitHub Pages 版。**這個資料夾裡的檔案就是全部**，直接上傳到 repo 根目錄即可。

```
index.html   ← 中文版（首頁）
en.html      ← 英文版
```

沒有任何絕對路徑，放在子目錄（例如 `/purenistaMwebsite/`）也不會壞。

---

## 已移除的功能

之前版本有一個「AI 視覺輔助」選項，需要使用者自己填 API key 或架設 Cloudflare Worker／
Netlify Function 才能用。因為大部分人不會、也不想處理部署，這個功能已經整個拿掉。
現在的人物／臉部辨識全部是本地端純 JavaScript（LBP cascade），不需要任何設定或網路連線。

---

## 前一版有但這裡刪掉的檔案

| 檔案 | 為什麼不需要 |
|---|---|
| `netlify.toml` | Netlify 專用設定，GitHub Pages 讀不到 |
| `_redirects` | Netlify 專用。只做 `/en` → `/en.html`，但站內連結都直接寫 `en.html` |
| `netlify/functions/analyze.js` | 原本是 AI 視覺輔助的後端，功能已移除 |
| `cloudflare/worker.js` | 同上，AI 視覺輔助的自架端點，功能已移除 |

---

## 功能

**分析模組**：構圖型態 18 種／美的形式原理 10 項／光影質地 6 項／
配色法則 7 種＋風格色系 8 組／人像構圖（含關節裁切）／文字層／動漫臉部偵測（純 JS，無 opencv）

**美學專欄**：構圖 26 條、形式原理 10 項、光影 13 項、色彩 7 法＋8 組色卡、
人像 17 項、排版 16 項，皆從攝影／繪畫／設計三個角度說明。另有「哪一項弱就找哪種老師」學習路線。

報告分四個分頁（總結／構圖／色彩・光影／細節），最上方有一句話結論。

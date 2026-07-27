# 作品健檢 v4.7（GitHub Pages 版）

這份是合併 v3.2「動漫／插畫臉部辨識」與 v4.7 最新分析引擎後、專為 GitHub Pages
整理過的版本：拿掉了 Cloudflare / Netlify 的伺服器端檔案（`cloudflare/`、
`netlify/`、`netlify.toml`、`_redirects`），純靜態，上傳到 repo 就能用，不用架任何後端。

結構：
- `index.html`（中文版）
- `en/index.html`（英文版）
- `README.md`

動漫／插畫臉部辨識（原 v3.2 用 OpenCV.js，約 10MB）已經改寫成不依賴 OpenCV 的
純 JavaScript 版本，模型只有約 1MB，在背景執行緒跑，不會卡頁面，勾選框預設開啟。

## 免部署了：填你自己的 API key 就能用

之前需要 Worker 的原因只有一個——**API key 不能寫在網頁裡**。網頁的 JavaScript
任何人按 F12 都看得到，key 一旦寫進去等於公開，別人拿去用而帳單記在你頭上。

但 Anthropic 的 API 支援瀏覽器直接呼叫（帶上 `anthropic-dangerous-direct-browser-access` header），
設計出來的正當用途就是「使用者自備 key」。差別在**誰的 key、存在哪裡**：

| | key 在哪 | 誰付費 | 適合 |
|---|---|---|---|
| **① 填在網頁欄位**（新增） | 只在**你這台裝置**的瀏覽器 | 填 key 的人自己 | 你自己用 ✔ |
| ② Cloudflare Worker | 伺服器端，訪客看不到 | **你**（所有訪客的用量） | 開放給別人用 |
| ✗ 寫進原始碼上傳 | **全世界都看得到** | 你，直到被盜刷 | 絕對不要 |

所以你的情況——自己用——**選①，什麼都不用部署**。

### 怎麼用

1. console.anthropic.com 申請 API key
2. 網頁 ④ 進階選項 → 勾「使用 AI 視覺輔助」
3. 把 key 貼進「① 直接填你自己的 API key」欄位
4. 選模型（`claude-haiku-4-5` 最便宜，`claude-sonnet-5` 較準）

key 會記在這台裝置的瀏覽器裡，只送到 `api.anthropic.com`，不會傳給本站或任何第三方。

⚠️ **共用電腦不建議填**（有權限的人可以從開發者工具讀出來）。
⚠️ **絕對不要把 key 寫進 HTML 再上傳**——那就變成上表的第三種了。

### 測試

自備 key 這條路有 10 項測試（用假的 fetch，沒有真的呼叫 API）：
打對網址、帶對 header、key 放對位置、用選到的模型、圖片正確編碼、
回應能解析、401 時正確回報「key 被拒絕」、沒填 key 時退回端點路徑、端點可自訂與預設。

---

## v4.6

- 標題加上 **Purenista M**，並補了 `<meta name="description">`（Lighthouse SEO 缺的就是這個）
- 美學專欄 → 實作分頁新增「**哪一項弱，就找哪種老師**」，
  把報告的每一段接到對應的手藝，以及「只能選兩三門」的優先順序
  （版面設計 → 色彩學 → 字體排印 → 分鏡／構圖 → 光影，理由寫在卡片裡）

## v4.5

- **判準跟著你在②選的視角走**。舊閘門用 `illustrationMode = !mainKp`，
  意思只是「BodyPix 沒抓到姿態」；一旦抓到，插畫閘門全部失效。
  現在只有選「攝影師」才把曝光／對焦／腳下留白列為缺點
- Cloudflare Worker 版本（`cloudflare/worker.js`），端點網址可自填

## 更早

- **v4.4** 純白／純黑設計改報「高調（純白 X%）」「低調（純黑 X%）」而非過曝／死黑
- **v4.2–4.3** 焦點集中度改用「一半視覺重量佔多少面積」；新增色彩評語
- **v4.0–4.1** AI 視覺輔助；文字層改為有依據才判讀
- **v3.5–3.8** 移除 opencv.js（10MB → 1MB）；DOM 6,895 → 2,341；修多個必現誤報

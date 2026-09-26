# Timer Cam — 定時拍攝 iOS 作業

原生 SwiftUI + AVFoundation，最低 iOS 17，第一版僅支援 iPhone 直向、後置相機。

第一次開啟會先顯示三頁介紹（可 Skip），之後直接進入全螢幕相機畫面。

流程：設定 40／60／自訂 1–600 秒 → 設定就位時間 → 按開始 → 就位倒數 → 開拍倒數「5、4、3、2、1」→ 錄影並收錄現場聲音 → 到時自動停止 → 回放／儲存至相簿。

5、4 各 1 秒；3、2、1 各 0.4／0.5／0.7 秒，預設整段開拍倒數 3.5 秒。倒數是大字搭配系統提示音，非語音喊數。就位與開拍倒數不計入錄影長度。

## 開發方式

1. Windows / WSL / Linux：編輯 `TimerCam/Sources`、文件，使用 Git / GitHub 交接。
2. Mac：clone 後直接開啟 `TimerCam.xcodeproj`，依 [Xcode 設定步驟](docs/XCODE_SETUP.md) 選擇簽署 Team 後執行。
3. 實體 iPhone：依 [驗收清單](docs/DEVICE_TESTS.md) 測試相機、權限、時間、聲音與中斷，再拍截圖與作業展示影片。

## 目前進度與版本

| 分支 | 版本內容 |
|---|---|
| `version/v1-dance-timer` | 初版 Dance Timer（無 Xcode 專案檔） |
| `version/v2-timer-cam-xcode` | 改名 Timer Cam、加入 `TimerCam.xcodeproj` |
| `version/v3-camera-ui` | 相機式介面（左下歷史、中間錄影鍵、右下設定）、App icon |
| `version/v4-english-font` | 介面全英文、Playwrite 字型 |
| `main`（最新） | 第一次開啟介紹頁（`AsyncImage` 網路照片＋`TimerCamLogo` 本機圖片）；字型改回 iOS 系統字型；可刪除影片 |

`git checkout <分支>` 即可切換到該版本展示。各版本的需求、AI 對話、遇到的問題與待補截圖清單整理在 [`conversation.txt`](conversation.txt)。

尚未完成：Xcode 編譯與 iPhone 實機驗收、各版本截圖與展示影片（清單見 `conversation.txt` 第四節）。

`TimerCam.xcodeproj` 是在沒有 Xcode 的環境手寫產生，尚未通過 Apple SDK 編譯或 iPhone 實測，不能視為可直接上架的已驗證版本。第一次開啟若有設定問題，以 Xcode 提示修正後再 commit。

## 檔案

- `TimerCamApp.swift`：App 入口。
- `ContentView.swift`：全螢幕相機介面（左下歷史錄影、中間錄影鍵、右下設定）、設定頁、回放與刪除影片；首次開啟時以 `fullScreenCover` 顯示介紹頁。
- `RecorderModel.swift`：權限、倒數、錄影狀態、相簿儲存、刪除影片檔。
- `CameraRecorder.swift`：背景序列佇列操作相機、影片時長限制與錄影回呼。
- `IntroView.swift`：第一次開啟時的三頁介紹（`@AppStorage("hasSeenIntro")`），以 `AsyncImage` 從網路載入舞者照片，含載入中、載入失敗（可重試）畫面。畫面上不標示作者；照片來源（Wikimedia Commons）記錄於此：
  - [Don Quijote de la Mancha en el Teatro Teresa Carreño 3](https://commons.wikimedia.org/wiki/File:Don_Quijote_de_la_Mancha_en_el_Teatro_Teresa_Carre%C3%B1o,_Caracas,_Venezuela_3.jpg)：Wilfredor（舞作 Laura Fiorucci），CC0。
  - [Marthe Weijers, hiphop dancer](https://commons.wikimedia.org/wiki/File:Marthe_Weijers,_hiphop_dancer.jpg)：Industrees，CC0。
  - [Illstyle & Peace Productions hip hop show in Donetsk](https://commons.wikimedia.org/wiki/File:Illstyle_%26_Peace_Productions_hip_hop_show_in_Donetsk,_April_4,_2013_(8639988872).jpg)：U.S. Embassy Kyiv Ukraine，Public domain。
- `Assets.xcassets/AppIcon.appiconset`：App icon（1024×1024，無透明度）。
- `Assets.xcassets/TimerCamLogo.imageset`：直接複製現有 `AppIcon.png` 而成的本機圖片資源，未重新製作。

## 圖片實作

- 本機圖片：`IntroView` 頂端的 App 標題「Timer Cam」旁以 `Image("TimerCamLogo")` 顯示，資源打包在 App 內，不需網路。`Assets.xcassets` 在 Xcode 專案中是整個資料夾引用，新增的 imageset 會自動編入，不需修改 `project.pbxproj`。
- 網路圖片：`IntroView` 三頁照片以 `AsyncImage` 載入，載入中顯示 `ProgressView`，失敗時顯示 `wifi.exclamationmark` 圖示與「Try again」按鈕（變更 `.id` 重新請求），成功後淡入並裁切為 4:3 圓角。照片來源見上方 `IntroView.swift` 說明。

## 字型與語言

使用 iOS 系統字型（倒數大字為 rounded、剩餘秒數為 monospaced），支援動態字級。v4 曾改用 Playwrite BE WAL Guides，現已移除字型檔，保留在 `version/v4-english-font` 分支。

App 介面僅提供英文。

## 權限與資料

- 使用者按中間相機鍵（Turn on camera and microphone）才請求相機／麥克風權限；被拒絕可前往系統設定。
- 使用者按「Save to Photos」才請求 `.addOnly` 權限，不讀取使用者的照片資料庫。
- 影片存在 App 的 Documents/Recordings，重開 App 可回放；移除 App 會失去尚未匯出影片。
- 不登入、不使用廣告、分析 SDK 或網路上傳。唯一的網路請求是介紹頁從 Wikimedia Commons（upload.wikimedia.org）下載照片，不傳送使用者資料，但對方伺服器會收到一般連線資訊（如 IP）。Documents 可能由 iOS 隨裝置備份。
- 刪除影片：在 History 列表向左滑動，或在回放頁按右上角垃圾桶並確認。只刪除 App 內的檔案，已存到相簿的影片不受影響；刪除後無法復原。
- 切到背景會取消倒數或停止錄影，不支援背景／鎖定畫面錄影。

## 上架準備

這是作業 MVP 的程式基礎。App Icon 已放入。正式提交前仍要完成實機驗收、截圖、支援與隱私政策網址、App Store Connect 隱私揭露、簽署及封存。權限字串已提供，但僅有權限流程不代表保證通過審查。依實際最終版本（包括後加的 SDK）填寫隱私資訊；不要把這份開發 README 當成公開隱私政策。

## Apple 參考資料

- [相機與麥克風授權](https://developer.apple.com/documentation/avfoundation/requesting-authorization-to-capture-and-save-media)
- [影片錄製輸出](https://developer.apple.com/documentation/avfoundation/avcapturemoviefileoutput)
- [新增至相簿的用途說明](https://developer.apple.com/documentation/bundleresources/information-property-list/nsphotolibraryaddusagedescription)

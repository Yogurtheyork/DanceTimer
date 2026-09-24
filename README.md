# Timer Cam — 定時拍攝 iOS 作業

原生 SwiftUI + AVFoundation，最低 iOS 17，第一版僅支援 iPhone 直向、後置相機。

流程：設定 40／60／自訂 1–600 秒 → 設定就位時間 → 按開始 → 就位倒數 → 開拍倒數「5、4、3、2、1」→ 錄影並收錄現場聲音 → 到時自動停止 → 回放／儲存至相簿。

5、4 各 1 秒；3、2、1 各 0.4／0.5／0.7 秒，預設整段開拍倒數 3.5 秒。倒數是大字搭配系統提示音，非語音喊數。就位與開拍倒數不計入錄影長度。

## 開發方式

1. Windows / WSL / Linux：編輯 `TimerCam/Sources`、文件，使用 Git / GitHub 交接。
2. Mac：clone 後直接開啟 `TimerCam.xcodeproj`，依 [Xcode 設定步驟](docs/XCODE_SETUP.md) 選擇簽署 Team 後執行。
3. 實體 iPhone：依 [驗收清單](docs/DEVICE_TESTS.md) 測試相機、權限、時間、聲音與中斷，再拍截圖與作業展示影片。

`TimerCam.xcodeproj` 是在沒有 Xcode 的環境手寫產生，尚未通過 Apple SDK 編譯或 iPhone 實測，不能視為可直接上架的已驗證版本。第一次開啟若有設定問題，以 Xcode 提示修正後再 commit。

## 檔案

- `TimerCamApp.swift`：App 入口。
- `ContentView.swift`：全螢幕相機介面（左下歷史錄影、中間錄影鍵、右下設定）、設定頁與回放。
- `RecorderModel.swift`：權限、倒數、錄影狀態、相簿儲存。
- `CameraRecorder.swift`：背景序列佇列操作相機、影片時長限制與錄影回呼。
- `TimerCam/Fonts`：App 字型 [Playwrite BE WAL Guides](https://fonts.google.com/specimen/Playwrite+BE+WAL+Guides)，SIL Open Font License（`OFL.txt`，一併打包進 App）。

App 介面僅提供英文。

## 權限與資料

- 使用者按中間相機鍵（Turn on camera and microphone）才請求相機／麥克風權限；被拒絕可前往系統設定。
- 使用者按「Save to Photos」才請求 `.addOnly` 權限，不讀取使用者的照片資料庫。
- 影片存在 App 的 Documents/Recordings，重開 App 可回放；移除 App 會失去尚未匯出影片。
- 不登入、不使用廣告、分析 SDK 或網路上傳。Documents 可能由 iOS 隨裝置備份。
- 第一版尚無 App 內刪除影片功能；長期使用前應補上儲存空間管理。
- 切到背景會取消倒數或停止錄影，不支援背景／鎖定畫面錄影。

## 上架準備

這是作業 MVP 的程式基礎。正式提交前仍要完成實機驗收、App Icon、截圖、支援與隱私政策網址、App Store Connect 隱私揭露、簽署及封存。權限字串已提供，但僅有權限流程不代表保證通過審查。依實際最終版本（包括後加的 SDK）填寫隱私資訊；不要把這份開發 README 當成公開隱私政策。

## Apple 參考資料

- [相機與麥克風授權](https://developer.apple.com/documentation/avfoundation/requesting-authorization-to-capture-and-save-media)
- [影片錄製輸出](https://developer.apple.com/documentation/avfoundation/avcapturemoviefileoutput)
- [新增至相簿的用途說明](https://developer.apple.com/documentation/bundleresources/information-property-list/nsphotolibraryaddusagedescription)

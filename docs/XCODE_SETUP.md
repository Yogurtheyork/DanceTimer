# 在 Mac 建立 Xcode 專案

## 1. 建立專案

1. 在 Mac 安裝可支援 iOS 17 或更新版的 Xcode，取得本資料夾（GitHub clone 或複製）。
2. Xcode → File → New → Project → iOS → App。
3. Product Name：`DanceTimer`；Interface：SwiftUI；Language：Swift；Storage：None。選擇自己的 Team 與 Organization Identifier。
4. 將專案放在 repository 的 `Xcode/` 子資料夾，避免覆蓋現有原始碼。
5. 移除新專案自動生成的 `ContentView.swift` 與 `DanceTimerApp.swift`，避免重複 App 入口。
6. File → Add Files to “DanceTimer”… → 選取此 repository 的 `DanceTimer/Sources` 中四個 Swift 檔。建議引用原檔、不勾 Copy items if needed；確認加入 DanceTimer target。若選擇複製，日後應以 Xcode 中那份為準，避免維護兩份。
7. 保留 Xcode 自動產生的 Assets.xcassets。

## 2. Target 與編譯設定

- Target → General → Minimum Deployments：iOS 17.0 或更新。
- Supported Destinations：iPhone；第一版取消 iPad 與 Mac 支援。
- iPhone Orientation：僅 Portrait（取消 Landscape 與 Upside Down）。預覽與影片目前固定直向。
- Signing & Capabilities：選擇 Team，啟用 Automatically manage signing，使用唯一 Bundle Identifier。
- Build Settings → Swift Language Version：**Swift 5**。
- 若 Xcode 有 Default Actor Isolation 設定，設為 **Nonisolated**；這份程式以主執行緒 UI 與序列相機佇列分工，未採 Swift 6 預設 MainActor 隔離。
- 不需要 Background Modes、網路權限、第三方套件或 API key。

## 3. 加入三個隱私用途字串（必要）

Target → Info → Custom iOS Target Properties，按 + 新增以下項目。Xcode 使用自動產生 Info.plist 即可，無須另外拖入一份 plist。

| Xcode 顯示名稱 / 原始 key | Type | Value |
| --- | --- | --- |
| Privacy - Camera Usage Description / `NSCameraUsageDescription` | String | 使用相機錄製你的街舞練習影片，並顯示取景畫面。 |
| Privacy - Microphone Usage Description / `NSMicrophoneUsageDescription` | String | 在練舞錄影時收錄現場音樂與聲音。 |
| Privacy - Photo Library Additions Usage Description / `NSPhotoLibraryAddUsageDescription` | String | 將你選擇的練舞影片儲存到相簿。 |

缺少相機或麥克風用途說明會在存取時造成 App 終止。只需新增相簿權限，不要額外要求讀取整個相簿。

## 4. 編譯與實機執行

1. Product → Build，先修正任何編譯錯誤；本 Linux 工作區無法執行此步。
2. 連接 iPhone，信任 Mac，依系統指示開啟 Developer Mode，選擇該裝置後 Run。
3. 按「啟用相機與麥克風」，允許權限；設定就位時間與錄影長度，再開始。
4. 完成 `DEVICE_TESTS.md`，特別確認倒數音是否可聽見及影片是否正常收音。
5. Simulator 只用來檢查基本排版；錄影及聲音需要實機。SwiftUI Preview 也不應當成相機功能驗證。

## 5. 作業展示與後續上架

- 截圖：時間設定、倒數、錄影中、回放、權限說明畫面。
- 展示影片：設定短片時長 → 進場 → 自動開始與停止 → 回放 → 儲存到相簿。
- App Icon：在 Assets 的 AppIcon 補上自己的圖示；本版尚未提供。
- 上架另需 Apple Developer Program、App Store Connect 資料與隱私政策等；以提交時的 Apple 要求為準。

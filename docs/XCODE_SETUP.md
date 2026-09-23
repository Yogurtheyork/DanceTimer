# 在 Mac 開啟 Xcode 專案

## 1. 開啟專案

1. 在 Mac 安裝可支援 iOS 17 或更新版的 Xcode。
2. Xcode → File → Clone Repository…，貼上 `https://github.com/Yogurtheyork/TimerCam.git`；或用終端機 `git clone`。
3. 開啟 repository 根目錄的 `TimerCam.xcodeproj`。

專案已包含：`TimerCam/Sources` 四個 Swift 檔、`TimerCam/Assets.xcassets`（空白 AppIcon），以及共用的 TimerCam scheme。

## 2. 簽署（第一次必做）

- 點左側藍色 TimerCam 專案 → Target TimerCam → Signing & Capabilities。
- Team：選擇自己的 Apple ID / Team。
- Bundle Identifier 預設為 `com.yogurtheyork.TimerCam`；若顯示已被使用，改成自己唯一的值。

## 3. 專案內已預設的設定

以下已寫在專案檔中，一般不需要改，僅供檢查：

- Minimum Deployments：iOS 17.0；Supported Destinations：僅 iPhone；Orientation：僅 Portrait。
- Swift Language Version：**Swift 5**。
- Default Actor Isolation：**nonisolated**（Xcode 26 才有此設定；舊版 Xcode 會忽略）。這份程式以主執行緒 UI 與序列相機佇列分工，未採 Swift 6 預設 MainActor 隔離。
- 自動產生 Info.plist，並包含三個隱私用途字串：

| Xcode 顯示名稱 / 原始 key | Value |
| --- | --- |
| Privacy - Camera Usage Description / `NSCameraUsageDescription` | 使用相機定時錄製影片，並顯示取景畫面。 |
| Privacy - Microphone Usage Description / `NSMicrophoneUsageDescription` | 在錄影時收錄現場聲音。 |
| Privacy - Photo Library Additions Usage Description / `NSPhotoLibraryAddUsageDescription` | 將你選擇的影片儲存到相簿。 |

缺少相機或麥克風用途說明會在存取時造成 App 終止；可在 Target → Info 確認。不需要 Background Modes、網路權限、第三方套件或 API key。

若 Xcode 開啟專案時提示「Update to recommended settings」，可以接受，再把變更 commit 回 repository。

## 4. 編譯與實機執行

1. Product → Build，先修正任何編譯錯誤；本 Linux 工作區無法執行此步。
2. 連接 iPhone，信任 Mac，依系統指示開啟 Developer Mode，選擇該裝置後 Run。
3. 按「啟用相機與麥克風」，允許權限；設定就位時間與錄影長度，再開始。
4. 完成 `DEVICE_TESTS.md`，特別確認倒數音是否可聽見及影片是否正常收音。
5. Simulator 只用來檢查基本排版；錄影及聲音需要實機。SwiftUI Preview 也不應當成相機功能驗證。

## 5. 作業展示與後續上架

- 截圖：時間設定、倒數、錄影中、回放、權限說明畫面。
- 展示影片：設定短片時長 → 倒數 → 自動開始與停止 → 回放 → 儲存到相簿。
- App Icon：在 Assets 的 AppIcon 補上自己的圖示；本版尚未提供。
- 上架另需 Apple Developer Program、App Store Connect 資料與隱私政策等；以提交時的 Apple 要求為準。

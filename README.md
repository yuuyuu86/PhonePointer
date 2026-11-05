# PhonePointer

iPhoneを画面に向けて、空中でMacを操作するエアマウス。

## 構成

| ディレクトリ | 内容 |
|---|---|
| `iOS/` | iPhoneアプリ(センサー取得・操作判定・送信) |
| `macOS/` | Macメニューバーアプリ(受信・カーソル/クリック/スクロールに変換) |
| `Shared/` | 通信プロトコル(改行区切りJSON over TCP) |
| `docs/SPEC.md` | 仕様書 |

接続: 同じWi-Fi内でBonjour(`_phonepointer._tcp`)によりMacを自動検出。初回のみMacに表示される4桁コードでペアリング。

## 操作

| 操作 | 動作 |
|---|---|
| iPhoneを上下左右に向ける | カーソル移動 |
| 手首を右にひねる | 左クリック(ひねり始めの位置でクリック) |
| 手首を左にひねる | 右クリック |
| 画面に親指を置いて手前/奥に傾ける | 下/上にスクロール(傾きが大きいほど速い) |
| 画面を短くタップ | 左クリック(設定でオフ可) |
| 「押してドラッグ」を押している間 | ドラッグ |
| 中心合わせ | カーソルを画面中央へ |
| 一時停止 | カーソル操作を止める |

持ち方: 画面を上に向け、iPhoneの上端をMacの画面に向ける。

## ビルド

```bash
brew install xcodegen
xcodegen generate
open PhonePointer.xcodeproj
```

- `PhonePointer` スキーム: iPhone実機で実行(Signing & CapabilitiesでTeamを選択)
- `PhonePointerMac` スキーム: Macで実行。初回起動時に **システム設定 > プライバシーとセキュリティ > アクセシビリティ** で許可する

## 実機で調整したいこと

ひねり判定のしきい値は `iOS/MotionController.swift` の `handleTwist`、感度の初期値は `iOS/Settings.swift`。

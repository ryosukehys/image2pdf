# image2pdf

写真から PDF を作る iPhone アプリ（SwiftUI ネイティブアプリ）。

1 枚でも複数枚でも、選んだ写真を連続したページを持つ 1 つの PDF として書き出します。
印刷のレイアウトのように、1 ページに複数の画像をまとめて配置することもできます。

## 主な機能

- **写真の選択**: フォトライブラリから 1 枚〜複数枚をまとめて選択（`PhotosPicker`）。
- **連続ページ PDF**: 選んだ画像を順番に並べ、複数ページの PDF として出力。
- **割り付け印刷レイアウト**: 1 / 2 / 4 / 6 / 8 枚を 1 ページにグリッド配置。
- **並べ替え・削除**: リストをドラッグして順番を変更、スワイプで削除。
- **ページ設定**: 用紙サイズ（A4 / Letter / 画像にフィット）、向き（縦 / 横）、余白、画像同士の間隔を調整。
- **プレビューと共有**: `PDFKit` でその場でプレビューし、`ShareLink` から保存・共有（ファイルアプリ、メール、AirDrop など）。

## 動作環境

- iOS 16.0 以上（iPhone / iPad）
- Xcode 16 以上（プロジェクトは File System Synchronized Group を使用）

## ビルド方法

1. macOS の Xcode で `image2pdf.xcodeproj` を開く。
2. 署名チーム（Signing & Capabilities → Team）を自分の Apple ID に設定する。
   必要に応じて Bundle Identifier（既定値 `com.example.image2pdf`）を一意な値に変更する。
3. 実機または iOS シミュレータを選んで Run（⌘R）。

## 使い方

1. 「写真を追加」から PDF にしたい画像を選ぶ。
2. レイアウト（1 ページあたりの枚数）、用紙サイズ、向き、余白などを調整する。
3. リストをドラッグして順番を整える。
4. 「プレビューと書き出し」で仕上がりを確認し、ファイル名を付けて共有・保存する。

## 構成

| ファイル | 役割 |
| --- | --- |
| `image2pdfApp.swift` | アプリのエントリーポイント |
| `ContentView.swift` | メイン画面（写真リスト・ページ設定） |
| `PreviewSheet.swift` | PDF プレビューと共有シート |
| `DocumentModel.swift` | 選択画像と設定を保持する ObservableObject |
| `PDFGenerator.swift` | 画像から PDF を生成する描画ロジック |
| `PageSettings.swift` | 用紙サイズ・向き・レイアウトの定義 |
| `PDFPreviewView.swift` | `PDFKit` の `PDFView` を SwiftUI でラップ |

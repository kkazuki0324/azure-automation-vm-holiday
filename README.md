# Azure Automation で祝日判定付き Microsoft Fabric 容量 自動一時停止/再開 ハンズオン

このハンズオンでは、Azure Automation を使用して日本の祝日を考慮した Microsoft Fabric 容量（Capacity）の自動一時停止/再開システムを構築します。内閣府の Web サイトから祝日データを取得し、平日のみ Fabric 容量を再開、祝日は再開せずコストを最適化するシステムを学習します。

## 🎯 学習目標

このハンズオンを完了すると以下のスキルが身に付きます：

- Azure Automation アカウントの作成と設定
- PowerShell Runbook の作成とスケジューリング
- Azure Automation 変数の活用方法
- Graphical Runbook による条件分岐処理
- 日本の祝日データの取得と活用
- Microsoft Fabric 容量リソース管理の自動化

## 🛠️ 前提条件

### 必要な権限

- Azure サブスクリプション（Contributor 以上の権限）
- Microsoft Fabric 容量の作成・管理権限
- Azure Automation リソースの作成権限

### 必要な知識

- Azure Portal の基本操作
- PowerShell の基礎知識
- Microsoft Fabric の基本概念

### 準備するもの

- 動作確認用の Microsoft Fabric 容量（一時停止可能なテスト環境）
- Web ブラウザと Azure Portal へのアクセス

## 📋 システム概要

### 処理フロー

1. **年次処理**：内閣府ホームページから祝日 CSV をダウンロード
2. **祝日データ処理**：年末年始休暇などの追加休日を設定
3. **変数格納**：今年と来年の祝日データを Azure 変数に保存
4. **平日再開処理**：祝日以外の平日に Fabric 容量を自動再開
5. **毎日一時停止処理**：業務終了時間に Fabric 容量を自動一時停止

### システム構成図

```
┌─────────────┐    ┌──────────────┐    ┌─────────────────┐
│内閣府Web    │───▶│Azure         │───▶│Microsoft Fabric │
│(祝日CSV)    │    │Automation    │    │Capacity         │
└─────────────┘    └──────────────┘    └─────────────────┘
                          │
                   ┌──────────────┐
                   │Automation    │
                   │Variables     │
                   └──────────────┘
```

## 📁 プロジェクト構成

```
azure-automation-fabric-holiday/
├── README.md                          # このファイル
├── docs/                             # ドキュメント
│   ├── setup-guide.md                # 詳細セットアップガイド
│   └── troubleshooting.md            # トラブルシューティング
├── scripts/                          # PowerShellスクリプト
│   ├── add_holidays.ps1              # 祝日データ取得・設定
│   ├── not_holidays.ps1              # 祝日判定
│   ├── resume_fabric.ps1             # Fabric容量再開
│   └── pause_fabric.ps1              # Fabric容量一時停止
├── config/                           # 設定ファイル
│   ├── automation-variables.json     # Automation変数設定
│   └── runbook-schedules.json        # Runbookスケジュール設定
└── images/                           # 説明用画像
    └── architecture-diagram.png      # システム構成図
```

## 🚀 クイックスタート

### ステップ 1: Azure Automation アカウントの作成

1. Azure Portal にログイン
2. 「Automation アカウント」を検索して選択
3. 新しい Automation アカウントを作成

### ステップ 2: 必要なモジュールのインポート

以下のモジュールをインポートします：

- `Az.Accounts`
- `Az.Automation`

### ステップ 3: Automation 変数の設定

| 変数名                  | 値の例                   | 説明                                   |
| ----------------------- | ------------------------ | -------------------------------------- |
| `target_capacity_name`  | "fabric-capacity-prod"   | 対象 Fabric 容量の名前                 |
| `target_resource_group` | "rg-fabric"              | 対象 Fabric 容量のリソースグループ     |
| `holidays_JP`           | "2024/1/1,2024/1/2"      | 祝日リスト（自動更新）                 |

### ステップ 4: Runbook の作成

1. `add_holidays` - 祝日データ取得（年 1 回実行）
2. `not_holidays` - 祝日判定処理
3. `resume_fabric` - Fabric 容量再開処理
4. `pause_fabric` - Fabric 容量一時停止処理（毎日実行）
5. `holiday_automation` - 条件分岐処理（平日実行）

### ステップ 5: スケジュール設定

- **祝日データ更新**: 年 1 回（1 月 1 日）
- **自動再開**: 平日朝（例：8:00）
- **自動一時停止**: 毎日夜（例：20:00）

## 📖 詳細ガイド

より詳細な実装手順については以下をご確認ください：

- [詳細セットアップガイド](docs/setup-guide.md)
- [トラブルシューティング](docs/troubleshooting.md)

## ⚠️ 注意事項

- **本番環境での使用前に必ずテスト環境で動作確認を行ってください**
- スクリプトの実行によって Fabric 容量が意図せず一時停止する可能性があります
- Azure 使用料金が発生します。不要なリソースは削除してください
- 祝日データは内閣府の Web サイトに依存しているため、サイト変更時は対応が必要です

## 🔧 カスタマイズ

### 年末年始休暇の調整

`add_holidays.ps1`内の以下の部分を変更することで、独自の休暇を追加できます：

```powershell
$additionalHolidays = @("/1/2", "/1/3", "/12/29", "/12/30", "/12/31")
```

### 対象 Fabric 容量の変更

`automation-variables.json`で対象の Fabric 容量を設定できます。

## 📊 コスト最適化効果

このシステムにより期待できるコスト削減：

- 祝日分の Fabric 容量稼働時間削減：年間約 20 日分
- 土日祝日での自動一時停止忘れ防止
- 手動操作ミスの防止

## 🤝 コントリビューション

改善提案やバグ報告は以下の方法でお願いします：

1. Issue の作成
2. Pull Request の提出
3. ドキュメントの改善提案

## 📄 ライセンス

このプロジェクトは MIT ライセンスの下で公開されています。

## 📞 サポート

質問や問題がある場合は、以下までお問い合わせください：

- プロジェクトの Issue
- Azure 公式ドキュメント
- Azure サポート

---

**次へ**: [詳細セットアップガイド](docs/setup-guide.md)を確認して実装を開始してください。

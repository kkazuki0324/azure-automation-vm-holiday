# Azure Automation 祝日判定付き VM 自動起動/停止 トラブルシューティングガイド

このドキュメントでは、システム運用中に発生する可能性のある問題と解決方法を説明します。

## 📋 目次

1. [よくある問題と解決方法](#よくある問題と解決方法)
2. [エラーコード別対処法](#エラーコード別対処法)
3. [ログの確認方法](#ログの確認方法)
4. [動作検証手順](#動作検証手順)
5. [緊急時の対応](#緊急時の対応)
6. [メンテナンス方法](#メンテナンス方法)

## よくある問題と解決方法

### 🔥 問題 1: VM が祝日でも起動してしまう

**症状**

- 祝日にも関わらず VM が自動起動される
- 祝日判定が正しく動作していない

**原因と解決方法**

#### 原因 1: 祝日データが更新されていない

```powershell
# 解決方法
1. Azure Portal → Automation アカウント → 変数 → holidays_JP の値を確認
2. 値が古い場合、add_holidays Runbook を手動実行
3. 実行後、holidays_JP の値が更新されることを確認
```

#### 原因 2: 日付フォーマットの問題

```powershell
# 確認方法
not_holidays Runbook を手動実行して出力を確認:
- 今日の日付: 2024/1/1（先頭ゼロなし）
- 祝日リスト: 2024/1/01（先頭ゼロあり）
→ フォーマット不一致でマッチしない
```

**修正方法**

```powershell
# scripts/not_holidays.ps1 の日付フォーマットを確認
$Today = Get-Date -Format "yyyy/M/d"  # 正しい（先頭ゼロなし）
# ↑ これが yyyy/MM/dd になっていないか確認
```

#### 原因 3: 条件分岐の設定ミス

```
# Graphical Runbook の条件式を確認
正しい: !$ActivityOutput["not_holidays"]
間違い: $ActivityOutput["not_holidays"]
```

### 🔥 問題 2: VM が平日でも起動しない

**症状**

- 平日に VM が自動起動されない
- holiday_automation が実行されているが、start_vm が動作しない

**解決方法**

#### 1. Runbook 実行履歴の確認

```
1. Azure Portal → Automation アカウント → Runbook → holiday_automation
2. 「ジョブ」タブで最新の実行結果を確認
3. エラーメッセージや警告を確認
```

#### 2. 変数設定の確認

```
target_resource_group: 実際のリソースグループ名が正しいか
exclude_VM: 対象VMが除外リストに含まれていないか
```

#### 3. 権限の確認

```
# Azure Run As Account の権限確認
1. Automation アカウント → アカウント設定 → 実行アカウント
2. Azure 実行アカウントが正常に作成されているか確認
3. 対象リソースグループに対する権限があるか確認
```

### 🔥 問題 3: Runbook の実行に失敗する

**症状**

- Runbook 実行時にエラーが発生
- スケジュール実行が失敗する

**解決方法**

#### モジュールの確認

```
1. 共有リソース → モジュール で以下を確認:
   - Az.Accounts: 使用可能
   - Az.Automation: 使用可能
   - Az.Compute: 使用可能

2. 「利用できません」状態の場合は再インポート
```

#### スクリプト構文の確認

```powershell
# 手動でスクリプトをテスト実行
1. 対象 Runbook → 編集
2. 「テスト ウィンドウ」をクリック
3. 「開始」でテスト実行
4. エラーメッセージを確認
```

### 🔥 問題 4: 内閣府サイトからの祝日データ取得に失敗

**症状**

- add_holidays 実行時にエラー
- 「Invoke-WebRequest」でエラーが発生

**解決方法**

#### 1. ネットワーク接続の確認

```powershell
# テスト用スクリプト（add_holidays内で実行）
try {
    $uri = "https://www8.cao.go.jp/chosei/shukujitsu/syukujitsu.csv"
    $response = Invoke-WebRequest -Uri $uri -UseBasicParsing
    Write-Output "接続成功: $($response.StatusCode)"
}
catch {
    Write-Error "接続失敗: $($_.Exception.Message)"
}
```

#### 2. 代替手段

```powershell
# 手動で祝日データを設定する場合
$holidays = "2024/1/1,2024/1/8,2024/2/11,2024/2/12,2024/3/20,2024/4/29,2024/5/3,2024/5/4,2024/5/5,2024/7/15,2024/8/11,2024/9/16,2024/9/23,2024/10/14,2024/11/3,2024/11/23,2024/12/29,2024/12/30,2024/12/31"
Set-AutomationVariable -Name 'holidays_JP' -Value $holidays
```

### 🔥 問題 5: スケジュールが実行されない

**症状**

- 設定した時刻になっても Runbook が実行されない
- スケジュール設定は正常に見える

**解決方法**

#### 1. スケジュール設定の確認

```
以下を確認:
- 開始時刻が未来の日時に設定されているか
- タイムゾーンが正しく設定されているか（JST）
- 曜日設定が正しいか（holiday_automation）
- Runbook が公開済みか
```

#### 2. 開始時刻の修正

```
1. 対象 Runbook → スケジュール
2. 既存スケジュールを削除
3. 新しいスケジュールを作成（開始時刻を未来に設定）
```

## エラーコード別対処法

### Authentication_Failed

```
原因: Azure実行アカウントの認証失敗
解決方法:
1. Automation アカウント → 実行アカウント → Azure実行アカウント
2. 証明書の有効期限を確認
3. 必要に応じて実行アカウントを再作成
```

### ResourceGroupNotFound

```
原因: 指定されたリソースグループが見つからない
解決方法:
1. target_resource_group 変数の値を確認
2. リソースグループ名のスペルチェック
3. 権限の確認
```

### VirtualMachineNotFound

```
原因: 指定されたVMが見つからない
解決方法:
1. VM名の確認
2. VMが削除されていないか確認
3. exclude_VM設定の確認
```

### ModuleNotFound

```
原因: 必要なPowerShellモジュールがインポートされていない
解決方法:
1. 共有リソース → モジュール で状態確認
2. 必要に応じて再インポート
3. インポート順序の確認（Az.Accounts → Az.Automation → Az.Compute）
```

## ログの確認方法

### Runbook 実行ログの確認

1. **基本的な確認方法**

   ```
   1. Azure Portal → Automation アカウント
   2. プロセス オートメーション → Runbook
   3. 対象Runbook → ジョブ
   4. 最新の実行結果をクリック
   5. 「出力」タブで詳細ログを確認
   ```

2. **エラー詳細の確認**
   ```
   1. 失敗したジョブをクリック
   2. 「例外」タブでエラー詳細を確認
   3. 「すべてのログ」でデバッグ情報を確認
   ```

### デバッグ情報の追加

Runbook に以下を追加してより詳細な情報を取得:

```powershell
# デバッグ情報の出力例
Write-Output "=== デバッグ情報 ==="
Write-Output "実行時刻: $(Get-Date)"
Write-Output "対象リソースグループ: $target_resource_group"
Write-Output "除外VM: $exclude_VM"
Write-Output "祝日リスト件数: $($holidays.Count)"
Write-Output "今日の日付: $Today"
Write-Output "祝日判定結果: $is_holiday"
```

## 動作検証手順

### 月次検証項目

1. **祝日データの確認**

   ```
   1. holidays_JP 変数の値を確認
   2. 今月・来月の祝日が含まれているか確認
   3. 年末年始データが含まれているか確認
   ```

2. **VM 起動/停止テスト**
   ```
   1. テスト用VMを準備
   2. 平日にholiday_automationを手動実行
   3. VMが起動することを確認
   4. stop_vmを手動実行
   5. VMが停止することを確認
   ```

### 年次検証項目

1. **祝日データの更新確認**
   ```
   1. 1月1日にadd_holidaysが自動実行されることを確認
   2. 新年度の祝日データが正しく取得されることを確認
   3. うるう年の対応確認
   ```

## 緊急時の対応

### VM が停止しない場合

1. **即座の対応**

   ```powershell
   # Azure CLI による緊急停止
   az vm stop --resource-group "リソースグループ名" --name "VM名"
   ```

2. **根本原因の調査**
   - stop_vm Runbook の実行履歴確認
   - VM の状態確認
   - 権限問題の調査

### VM が起動しない場合

1. **手動起動**

   ```powershell
   # Azure CLI による手動起動
   az vm start --resource-group "リソースグループ名" --name "VM名"
   ```

2. **自動化の修復**
   - holiday_automation の実行履歴確認
   - 祝日判定ロジックの確認
   - スケジュール設定の確認

## メンテナンス方法

### 定期メンテナンス項目

#### 月次メンテナンス

- [ ] Runbook 実行履歴の確認（エラーがないか）
- [ ] 祝日データの確認（最新か）
- [ ] VM 起動/停止テストの実行

#### 年次メンテナンス

- [ ] Azure 実行アカウント証明書の更新（必要に応じて）
- [ ] PowerShell モジュールの更新
- [ ] 祝日データの年次更新確認
- [ ] スケジュール設定の見直し

### 設定変更時の注意点

1. **VM 追加時**

   ```
   - 新しいVMのリソースグループを target_resource_group に追加
   - テスト環境での動作確認
   - 本番環境への適用
   ```

2. **業務時間変更時**

   ```
   - スケジュール設定の更新
   - タイムゾーンの確認
   - 変更前後での動作確認
   ```

3. **祝日ルール変更時**
   ```
   - add_holidays.ps1 の年末年始設定を更新
   - 独自休暇の追加/削除
   - テスト実行での確認
   ```

## サポート情報

### Microsoft サポートへの問い合わせ

深刻な問題が発生した場合:

1. **収集すべき情報**

   - Automation アカウント情報
   - エラーメッセージの詳細
   - 実行ログのスクリーンショット
   - 再現手順

2. **問い合わせ先**
   - Azure Portal → ヘルプとサポート
   - Azure サポートプラン（必要に応じて）

### コミュニティリソース

- [Azure Automation フォーラム](https://docs.microsoft.com/ja-jp/answers/topics/azure-automation.html)
- [Azure PowerShell ドキュメント](https://docs.microsoft.com/ja-jp/powershell/azure/)
- [Azure Automation ドキュメント](https://docs.microsoft.com/ja-jp/azure/automation/)

---

**よくある質問や新たな問題が発見された場合は、このドキュメントを更新してください。**

# =============================================
# 祝日データ取得・設定スクリプト
# =============================================
# 
# 内閣府のWebサイトから祝日CSVをダウンロードし、
# 年末年始休暇を追加してAutomation変数に格納する
#
# 実行頻度: 年1回（1月1日推奨）
# =============================================

# Azure Automation実行確認用のログ追加
Write-Output "=== Azure Automation Holiday Script Started ==="
Write-Output "Script execution time: $(Get-Date)"
Write-Output "PowerShell version: $($PSVersionTable.PSVersion)"

# 内閣府のHPから祝日一覧(csvファイル)を取得
$uri = "https://www8.cao.go.jp/chosei/shukujitsu/syukujitsu.csv"
$importLoc = ".\syukujitsu.csv"
Write-Output "Downloading holiday data from: $uri"

try {
    Invoke-WebRequest -Uri $uri -OutFile $importLoc 
    Write-Output "Download completed successfully"
    
    # ファイルサイズを確認
    $fileSize = (Get-Item $importLoc).Length
    Write-Output "Downloaded file size: $fileSize bytes"
}
catch {
    Write-Output "Error downloading file: $($_.Exception.Message)"
    throw
} 

# CSVの読み込み（1行目ヘッダーを除外）
Write-Output "Reading CSV data..."
$rawContent = Get-Content $importLoc -Encoding Default
$csvLines = $rawContent | Select-Object -Skip 1  # ヘッダー行をスキップ

# 手動でCSVデータを解析（日付パターンのみ抽出）
$HolidaysCsv = @()
foreach ($line in $csvLines) {
    if ($line -and $line.Trim() -ne "" -and $line -notmatch "国民の祝日") {
        $parts = $line -split ","
        if ($parts.Count -ge 2 -and $parts[0] -match "^\d{4}/\d{1,2}/\d{1,2}$") {
            $dateStr = $parts[0].Trim()
            try {
                # 日付の妥当性を確認
                $testDate = [datetime]$dateStr
                $HolidaysCsv += New-Object PSObject -Property @{
                    date = $dateStr
                    name = $parts[1].Trim()
                }
            }
            catch {
                Write-Output "Skipping invalid date: $dateStr"
            }
        }
    }
}

Write-Output "Loaded holiday records: $($HolidaysCsv.Count)"

# 対象年を設定（2025年と2026年）
$targetYears = @(2025, 2026)
Write-Output "Target years: $($targetYears -join ', ')"

# 対象年のみ抽出
$filteredHolidays = $HolidaysCsv | Where-Object {
    try {
        $dateParts = $_.date.Split("/")
        if ($dateParts.Count -ge 3) {
            $year = [int]$dateParts[0]
            $result = $targetYears -contains $year
            return $result
        }
        return $false
    }
    catch {
        Write-Output "Warning: Invalid date format: $($_.date)"
        return $false
    }
}

Write-Output "Filtered holidays for target years: $($filteredHolidays.Count)"

# 年末年始休暇を両年分追加
Write-Output "Adding year-end holidays..."
$aditionalHolidays = @("/1/2", "/1/3", "/12/29", "/12/30", "/12/31")
foreach ($year in $targetYears) {
    Write-Output "Adding holidays for year: $year"
    foreach ($addition in $aditionalHolidays) {
        $filteredHolidays += New-Object PsObject -Property @{
            date = "$year$addition"
            name = "年末年始休暇"
        }
    }
}

Write-Output "Total holidays after adding year-end holidays: $($filteredHolidays.Count)"

# ソート
Write-Output "Sorting holidays by date..."
$filteredHolidays = $filteredHolidays | Where-Object { 
    # 有効な日付のみソート対象にする
    try {
        [datetime]$_.date | Out-Null
        return $true
    }
    catch {
        Write-Output "Removing invalid date from sort: $($_.date)"
        return $false
    }
} | Sort-Object { [datetime]$_.date }

# CSVに上書き保存（オプション）
Write-Output "Exporting filtered holidays to CSV..."
$filteredHolidays | Export-Csv -Path $importLoc -Encoding Default -NoTypeInformation

# 祝日一覧を文字列で結合
Write-Output "Creating holiday string..."
$holidaysStr = ($filteredHolidays.date -join ",")
Write-Output "Generated holiday string length: $($holidaysStr.Length) characters"
Write-Output "Sample of holiday string: $($holidaysStr.Substring(0, [Math]::Min(100, $holidaysStr.Length)))..."

# Automation変数に格納（Azure Automation想定）
Write-Output "Setting Azure Automation variable 'holidays_JP'..."
try {
    Set-AutomationVariable -Name 'holidays_JP' -Value $holidaysStr
    Write-Output "Successfully set holidays_JP variable"
    
    # 確認のため変数を読み戻し
    $storedValue = Get-AutomationVariable -Name 'holidays_JP'
    Write-Output "Verification - stored value length: $($storedValue.Length) characters"
    Write-Output "First 100 characters of stored value: $($storedValue.Substring(0, [Math]::Min(100, $storedValue.Length)))..."
}
catch {
    Write-Output "Error setting Automation variable: $($_.Exception.Message)"
    # ローカル環境の場合はファイルに保存
    $holidaysStr | Out-File "holidays_JP_output.txt" -Encoding UTF8
    Write-Output "Saved holiday string to local file: holidays_JP_output.txt"
}

Write-Output "=== Script execution completed ==="
Write-Output "Final holiday count: $($filteredHolidays.Count)"
Write-Output "Script end time: $(Get-Date)"

# 最終出力
Write-Output $holidaysStr


# =============================================
# 祝日データ取得・設定スクリプト
# =============================================
# 
# 内閣府のWebサイトから祝日CSVをダウンロードし、
# 年末年始休暇を追加してAutomation変数に格納する
#
# 実行頻度: 年1回（1月1日推奨）
# =============================================

Write-Output "祝日データの取得を開始します..."

try {
    # 内閣府のホームページから祝日一覧(csvファイル)を取得
    $uri = "https://www8.cao.go.jp/chosei/shukujitsu/syukujitsu.csv"
    $importLoc = ".\syukujitsu.csv"
    
    Write-Output "内閣府から祝日データをダウンロード中..."
    Invoke-WebRequest -Uri $uri -OutFile $importLoc
    
    # CSVファイルをインポート（ヘッダー行を除外）
    $HolidaysCsv = Import-Csv $importLoc -Encoding Default -Header "date", "name" | Where-Object -FilterScript { $_.date -ne "国民の祝日・休日月日" }
    
    Write-Output "祝日データの取得が完了しました。件数: $($HolidaysCsv.Count)"
    
    # 祝日一覧には記載されていない年末年始休暇を追加
    $thisyear = (Get-Date).ToString("yyyy")
    $additionalHolidays = @("/1/2", "/1/3", "/12/29", "/12/30", "/12/31")
    
    Write-Output "年末年始休暇を追加中..."
    foreach ($addition in $additionalHolidays) {
        $addition = $thisyear + $addition
        $HolidaysCsv += New-Object PsObject -Property @{ 
            date = $addition 
            name = '年末年始休暇' 
        }
    }
    
    # 翌年の祝日もソートして取得（年をまたいだスケジュール対応）
    $nextyear = ([int]$thisyear + 1).ToString()
    foreach ($addition in $additionalHolidays) {
        $addition = $nextyear + $addition
        $HolidaysCsv += New-Object PsObject -Property @{ 
            date = $addition 
            name = '年末年始休暇' 
        }
    }
    
    # 今年以降の祝日をソートして取得
    $thisyearsHolidays = $HolidaysCsv | Where-Object -FilterScript { $_.date -ge $thisyear + "/1/1" } | Sort-Object { [datetime]$_.date }
    
    # デバッグ用：取得した祝日をCSVファイルに出力
    $thisyearsHolidays | Export-Csv -Path $importLoc -Encoding Default -NoTypeInformation
    
    # 祝日を文字列として結合（カンマ区切り）
    $content = ""
    $lastholiday = $thisyearsHolidays[-1]
    $thisyearsHolidays | ForEach-Object {
        $content += [string]$_.date
        if ($_.date -ne $lastholiday.date) {
            $content += ","
        }
    }
    
    Write-Output "祝日データを文字列に変換しました。文字数: $($content.Length)"
    Write-Output "祝日データサンプル: $($content.Substring(0, [Math]::Min(100, $content.Length)))..."
    
    # holidays_JP変数に格納
    Set-AutomationVariable -Name 'holidays_JP' -Value $content
    
    Write-Output "祝日データをAutomation変数 'holidays_JP' に正常に格納しました。"
    Write-Output "処理完了。今年と来年の祝日データが設定されました。"
    
}
catch {
    Write-Error "祝日データの取得・設定中にエラーが発生しました: $($_.Exception.Message)"
    throw
}
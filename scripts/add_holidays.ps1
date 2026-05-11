# =============================================
# 祝日データ取得・設定スクリプト
# =============================================
# 
# 内閣府のWebサイトから祝日CSVをダウンロードし、
# 年末年始休暇を追加してAutomation変数に格納する
#
# 実行頻度: 月1回（毎月1日推奨）
# =============================================
# Azure Automation実行確認用のログ追加
Write-Verbose "=== Azure Automation Holiday Script Started ==="
Write-Verbose "Script execution time: $(Get-Date)"
Write-Verbose "PowerShell version: $($PSVersionTable.PSVersion)"

#内閣府のHPから祝日一覧(csvファイル)を取得
$uri="https://www8.cao.go.jp/chosei/shukujitsu/syukujitsu.csv"
$importLoc=".\syukujitsu.csv"
Invoke-WebRequest -Uri $uri -OutFile $importLoc 
$HolidaysCsv= Import-Csv $importLoc -Encoding Default -Header "date","name" | Where-Object -FilterScript{$_.date -match '(\d{4}[-/]\d{1,2}[-/]\d{1,2})' }
Write-Verbose -Message "HolidaysCsv: $($HolidaysCsv -join "`n"))"
#祝日一覧には記載されていない年末年始休暇を追加
$thisyear =(get-date).Tostring("yyyy")
$aditionalHolidays =@("/1/2","/1/3","/12/29","/12/30","/12/31")
foreach($addition in $aditionalHolidays){
    $addition= $thisyear+$addition
    $HolidaysCsv += New-Object PsObject -Property @{ date = $addition ; name = '年末年始休暇' }
}

Write-Verbose -Message "thisyearsHolidays: $($thisyearsHolidays -join "`n"))"
$thisyearsHolidays= $HolidaysCsv |Where-Object -FilterScript{$_.date -ge "${thisyear}/1/1"}|sort {[datetime]$_.date} 

#祝日を文字列として結合
$content=""
$lastholiday=$thisyearsHolidays[-1]
$thisyearsHolidays|ForEach-Object{
    $content+=[string]$_.date
    if($_.date -ne $lastholiday.date){
    $content+=","
    }
}
Write-Verbose $content
Set-AutomationVariable -Name 'holidays_JP' -Value $content

Write-Verbose "=== Script execution completed ==="
Write-Verbose "Final holiday count: $($filteredHolidays.Count)"
Write-Verbose "Script end time: $(Get-Date)"

# 最終出力
Write-Output $content

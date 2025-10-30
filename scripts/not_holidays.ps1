# =============================================
# 祝日判定スクリプト
# =============================================
# 
# 実行日が祝日かどうかを判定する
# True: 祝日、False: 平日
#
# 実行頻度: holiday_automationから呼び出し
# =============================================

Write-Output "祝日判定を開始します..."

try {
    # holidays_JP変数に格納してある祝日を取得
    $Holidays = (Get-AutomationVariable -Name 'holidays_JP') -split ","
    
    Write-Output "取得した祝日数: $($Holidays.Count)"
    
    # 今日の日付を取得（一桁の月日は先頭に0を付けない形式）
    $Today = Get-Date -Format "yyyy/M/d"
    
    Write-Output "今日の日付: $Today"
    
    # 今日の日付とholidays_JP変数内の日付を突合
    $is_holiday = $Holidays.contains($Today)
    
    if ($is_holiday) {
        Write-Output "本日 ($Today) は祝日です。VMの自動起動はスキップされます。"
    }
    else {
        Write-Output "本日 ($Today) は平日です。VMの自動起動処理を継続します。"
    }
    
    # 今日の日付がholidays_JP変数内に存在すればTrue、存在してなければFalse
    Write-Output $is_holiday
    
    # デバッグ情報として祝日リストの最初の10件を出力
    $sampleHolidays = $Holidays | Select-Object -First 10
    Write-Output "祝日リスト（最初の10件）: $($sampleHolidays -join ', ')"
    
}
catch {
    Write-Error "祝日判定中にエラーが発生しました: $($_.Exception.Message)"
    # エラーが発生した場合は安全のため祝日扱いにする（VM起動しない）
    Write-Output $true
}
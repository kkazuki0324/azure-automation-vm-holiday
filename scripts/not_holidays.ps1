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

# holidays_JP変数から祝日一覧を取得
$Holidays = (Get-AutomationVariable -Name 'holidays_JP') -split ","


# 今日の日付を取得
$Today = Get-Date -Format "yyyy/M/d"

# 今日が祝日に含まれるか判定
$isHoliday = $Holidays.Contains($Today)

# 結果出力（True:祝日 / False:平日）
Write-Output $isHoliday
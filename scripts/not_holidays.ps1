# =============================================
# 平日判定スクリプト
# =============================================
# 
# 平日かどうかを判定する
# True: 平日、False: 祝日
#
# 実行頻度: holiday_automationから呼び出し
# =============================================
$Holidays = (Get-AutomationVariable -Name 'holidays_JP') -split ","
$Time = Get-Date
$UtcTime = Get-Date -Date $Time.ToUniversalTime()
$JSTTime = (Get-Date -Date $UtcTime).AddHours(9)
$Today =  Get-Date -Date $JSTTime -Format "yyyy/M/d"
 
Write-Verbose "UtcTime ${UtcTime}"
Write-Verbose "JSTTime ${JSTTime}"
Write-Verbose "Today ${Today}"
 
$holidays = $Holidays.Contains($Today)
Write-Verbose "not_holidays ${not_holidays}"
Write-Output !$holidays
 
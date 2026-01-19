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

$Holidays = (Get-AutomationVariable -Name 'holidays_JP') -split ","
$Today = Get-Date -Format "yyyy/M/d"

if ($Holidays.Contains($Today)) {
    Write-Output "今日は祝日です。処理を終了します。"
    return
}

Write-Output "平日のため VM 操作を実行します"
# Start-AzVM / Stop-AzVM

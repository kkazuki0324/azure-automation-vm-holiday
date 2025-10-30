# =============================================
# VM起動スクリプト
# =============================================
# 
# 指定したリソースグループ内のVMを自動起動する
# 除外リストに含まれるVMは起動対象外
#
# 実行頻度: holiday_automationから呼び出し（平日のみ）
# =============================================

Write-Output "VM自動起動処理を開始します..."

try {
    # Azure Run As Account を使用してAzureに接続
    $servicePrincipalConnection = Get-AutomationConnection -Name "AzureRunAsConnection"
    
    Write-Output "Azureに接続中..."
    Add-AzAccount `
        -ServicePrincipal `
        -TenantId $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint
    
    # target_resource_group変数からリソースグループ名を取得
    $Target_RG = (Get-AutomationVariable -Name 'target_resource_group') -split ","
    
    Write-Output "対象リソースグループ: $($Target_RG -join ', ')"
    
    # 上記で取得したリソースグループに所属する仮想マシンリストを取得
    $VMList = @()
    ForEach ($rg in $Target_RG) {
        $rgVMs = (Get-AzVM -ResourceGroupName $rg).Name
        if ($rgVMs) {
            $VMList += $rgVMs
            Write-Output "リソースグループ '$rg' 内のVM: $($rgVMs -join ', ')"
        }
        else {
            Write-Output "リソースグループ '$rg' にVMが見つかりませんでした"
        }
    }
    
    Write-Output "発見されたVM総数: $($VMList.Count)"
    
    # 除外VMリスト取得
    $excludeVM = (Get-AutomationVariable -Name 'exclude_VM') -split ","
    
    Write-Output "除外VM: $($excludeVM -join ', ')"
    
    # 対象VM取得（全VMリストから除外VMを引く）
    $targetVM = Compare-Object -ReferenceObject $VMList -DifferenceObject $excludeVM -PassThru
    
    if ($targetVM) {
        Write-Output "起動対象VM: $($targetVM -join ', ')"
        
        # 対象VM起動
        $startedVMs = @()
        $failedVMs = @()
        
        $targetVM | ForEach-Object {
            try {
                Write-Output "VM '$_' の起動を開始しています..."
                $result = Start-AzVM -ResourceGroupName (Get-AzVM -Name $_).ResourceGroupName -Name $_ -NoWait
                $startedVMs += $_
                Write-Output "VM '$_' の起動コマンドを正常に実行しました"
            }
            catch {
                Write-Error "VM '$_' の起動に失敗しました: $($_.Exception.Message)"
                $failedVMs += $_
            }
        }
        
        Write-Output "起動処理完了:"
        Write-Output "  正常起動: $($startedVMs.Count)台 ($($startedVMs -join ', '))"
        if ($failedVMs.Count -gt 0) {
            Write-Output "  起動失敗: $($failedVMs.Count)台 ($($failedVMs -join ', '))"
        }
    }
    else {
        Write-Output "起動対象のVMがありません（すべて除外リストに含まれているか、VMが存在しません）"
    }
    
    Write-Output "VM自動起動処理が完了しました"
    
}
catch {
    Write-Error "VM起動処理中にエラーが発生しました: $($_.Exception.Message)"
    throw
}
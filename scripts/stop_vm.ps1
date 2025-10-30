# =============================================
# VM停止スクリプト
# =============================================
# 
# 指定したリソースグループ内のVMを自動停止する
# 除外リストに含まれるVMは停止対象外
#
# 実行頻度: 毎日（業務終了時間）
# =============================================

Write-Output "VM自動停止処理を開始します..."

try {
    # Azure Run As Account を使用してAzureに接続
    $servicePrincipalConnection = Get-AutomationConnection -Name "AzureRunAsConnection"
    
    Write-Output "Azureに接続中..."
    Add-AzAccount `
        -ServicePrincipal `
        -TenantId $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint
    
    # 対象リソースグループ取得
    $TargetResourceGroup = (Get-AutomationVariable -Name 'target_resource_group') -split ","
    
    Write-Output "対象リソースグループ: $($TargetResourceGroup -join ', ')"
    
    # 対象リソースグループ所属VMリスト取得
    $VMList = @()
    ForEach ($rg in $TargetResourceGroup) {
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
        Write-Output "停止対象VM: $($targetVM -join ', ')"
        
        # 対象VM停止
        $stoppedVMs = @()
        $failedVMs = @()
        
        $targetVM | ForEach-Object {
            try {
                Write-Output "VM '$_' の停止を開始しています..."
                
                # VM の現在の状態を確認
                $vmStatus = Get-AzVM -ResourceGroupName (Get-AzVM -Name $_).ResourceGroupName -Name $_ -Status
                $powerState = ($vmStatus.Statuses | Where-Object { $_.Code -like "PowerState/*" }).Code
                
                if ($powerState -eq "PowerState/running") {
                    $result = Stop-AzVM -ResourceGroupName (Get-AzVM -Name $_).ResourceGroupName -Name $_ -Force -NoWait
                    $stoppedVMs += $_
                    Write-Output "VM '$_' の停止コマンドを正常に実行しました"
                }
                elseif ($powerState -eq "PowerState/stopped" -or $powerState -eq "PowerState/deallocated") {
                    Write-Output "VM '$_' は既に停止しています（状態: $powerState）"
                    $stoppedVMs += $_
                }
                else {
                    Write-Output "VM '$_' の状態が不明です（状態: $powerState）"
                }
            }
            catch {
                Write-Error "VM '$_' の停止に失敗しました: $($_.Exception.Message)"
                $failedVMs += $_
            }
        }
        
        Write-Output "停止処理完了:"
        Write-Output "  正常停止: $($stoppedVMs.Count)台 ($($stoppedVMs -join ', '))"
        if ($failedVMs.Count -gt 0) {
            Write-Output "  停止失敗: $($failedVMs.Count)台 ($($failedVMs -join ', '))"
        }
    }
    else {
        Write-Output "停止対象のVMがありません（すべて除外リストに含まれているか、VMが存在しません）"
    }
    
    Write-Output "VM自動停止処理が完了しました"
    
}
catch {
    Write-Error "VM停止処理中にエラーが発生しました: $($_.Exception.Message)"
    throw
}
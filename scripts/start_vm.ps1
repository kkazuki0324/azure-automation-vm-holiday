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

# システム割り当てマネージドIDを使用してAzureに接続
Write-Output "Connecting to Azure using System-assigned Managed Identity..."
try {
    $context = Connect-AzAccount -Identity
    Write-Output "Successfully connected to Azure with Managed Identity"
    
    # 現在のサブスクリプション情報を表示
    $currentContext = Get-AzContext
    Write-Output "Current subscription: $($currentContext.Subscription.Name) ($($currentContext.Subscription.Id))"
    
    # サブスクリプションIDが設定されていない場合の処理
    if (-not $currentContext.Subscription.Id) {
        Write-Output "Subscription ID is not set. Attempting to retrieve available subscriptions..."
        
        # 利用可能なサブスクリプション一覧を取得
        try {
            $subscriptions = Get-AzSubscription -ErrorAction Stop
            Write-Output "Available subscriptions: $($subscriptions.Count)"
            
            if ($subscriptions.Count -gt 0) {
                # 最初のサブスクリプションを使用
                $targetSubscription = $subscriptions[0]
                Write-Output "Setting subscription to: $($targetSubscription.Name) ($($targetSubscription.Id))"
                Set-AzContext -SubscriptionId $targetSubscription.Id
                
                # 再度コンテキストを確認
                $updatedContext = Get-AzContext
                Write-Output "Updated subscription: $($updatedContext.Subscription.Name) ($($updatedContext.Subscription.Id))"
            }
            else {
                Write-Output "ERROR: No subscriptions available for this Managed Identity"
                Write-Output "SOLUTION: Please assign appropriate permissions to the Managed Identity:"
                Write-Output "1. Go to Azure Portal → Subscriptions → Access control (IAM)"
                Write-Output "2. Add role assignment → Role: Reader or Virtual Machine Contributor"
                Write-Output "3. Principal: [Your Automation Account Name]"
                Write-Output "4. Or assign permissions at Resource Group level"
                throw "No accessible subscriptions found - Permission configuration required"
            }
        }
        catch {
            Write-Output "ERROR: Failed to retrieve subscriptions: $($_.Exception.Message)"
            Write-Output "This typically indicates insufficient permissions for the Managed Identity"
            Write-Output "Please check the Managed Identity permissions in Azure Portal"
            throw
        }
    }
}
catch {
    Write-Output "Failed to connect to Azure: $($_.Exception.Message)"
    throw
} 

#target_resource_group変数からリソースグループ名を取得
Write-Output "Getting target resource groups..."
try {
    $Target_RG = (Get-AutomationVariable -Name 'target_resource_group') -split ","
    $Target_RG = $Target_RG | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
    Write-Output "Target resource groups: $($Target_RG -join ', ')"
}
catch {
    Write-Output "Failed to get target_resource_group variable: $($_.Exception.Message)"
    throw
}

# サブスクリプションIDを明示的に設定（オプション）
Write-Output "Checking for explicit subscription ID setting..."
try {
    $explicitSubscriptionId = Get-AutomationVariable -Name 'target_subscription_id' -ErrorAction SilentlyContinue
    if ($explicitSubscriptionId) {
        Write-Output "Found explicit subscription ID: $explicitSubscriptionId"
        Set-AzContext -SubscriptionId $explicitSubscriptionId
        $finalContext = Get-AzContext
        Write-Output "Set subscription context: $($finalContext.Subscription.Name) ($($finalContext.Subscription.Id))"
    }
    else {
        Write-Output "No explicit subscription ID found, using current context"
    }
}
catch {
    Write-Output "Warning: Could not set explicit subscription: $($_.Exception.Message)"
}

#上記で取得したリソースグループに所属する仮想マシンリストを取得
Write-Output "Getting VM list from target resource groups..."
$VMList = @()
$totalVMsFound = 0

ForEach ($rg in $Target_RG) {
    try {
        if ($rg -ne "") {
            Write-Output "Processing resource group: $rg"
            
            # リソースグループの存在確認
            Write-Output "Checking if resource group '$rg' exists..."
            $resourceGroup = Get-AzResourceGroup -Name $rg -ErrorAction Stop
            Write-Output "Resource group '$rg' found in subscription"
            Write-Output "Resource group location: $($resourceGroup.Location)"
            Write-Output "Resource group provisioning state: $($resourceGroup.ProvisioningState)"
            
            # VM一覧を取得
            Write-Output "Calling Get-AzVM for resource group: $rg"
            $vmsInRG = Get-AzVM -ResourceGroupName $rg -ErrorAction Stop
            Write-Output "Get-AzVM returned $($vmsInRG.Count) VM objects"
            
            if ($vmsInRG -and $vmsInRG.Count -gt 0) {
                # VM名を正しく抽出（Write-Outputをパイプラインから除外）
                $vmNames = @()
                foreach ($vm in $vmsInRG) {
                    Write-Output "Processing VM object: $($vm.Name)"
                    $vmNames += $vm.Name
                }
                Write-Output "VM names extracted: $($vmNames -join ', ')"
                
                if ($vmNames.Count -gt 0) {
                    $VMList += $vmNames
                    $totalVMsFound += $vmNames.Count
                    Write-Output "Found $($vmNames.Count) VMs in resource group '$rg': $($vmNames -join ', ')"
                }
                else {
                    Write-Output "Warning: VM objects found but no names extracted"
                }
            }
            else {
                Write-Output "No VM objects returned from Get-AzVM"
            }
        }
    }
    catch {
        Write-Output "Error processing resource group '$rg': $($_.Exception.Message)"
        Write-Output "Error type: $($_.Exception.GetType().Name)"
        Write-Output "Error details: $($_.Exception.ToString())"
        
        # リソースグループが存在しない場合の詳細情報
        if ($_.Exception.Message -like "*ResourceGroupNotFound*") {
            Write-Output "Resource group '$rg' does not exist or no permission to access"
        }
        elseif ($_.Exception.Message -like "*Forbidden*" -or $_.Exception.Message -like "*Authorization*") {
            Write-Output "Permission denied: Managed Identity may not have sufficient permissions"
        }
        elseif ($_.Exception.Message -like "*SubscriptionId*") {
            Write-Output "Subscription context issue detected"
        }
    }
}
Write-Output "Total VMs found across all resource groups: $totalVMsFound"
Write-Output "VMList array contents: [$($VMList -join ', ')]"
Write-Output "VMList count: $($VMList.Count)"

#除外VMリスト取得
Write-Output "Getting exclude VM list..."
try {
    $excludeVM = (Get-AutomationVariable -Name 'exclude_VM') -split ","
    $excludeVM = $excludeVM | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
    Write-Output "Exclude VMs: $($excludeVM -join ', ')"
}
catch {
    Write-Output "Warning: Failed to get exclude_VM variable, proceeding without exclusions: $($_.Exception.Message)"
    $excludeVM = @()
}

#対象VM取得
Write-Output "Determining target VMs..."
if ($VMList.Count -eq 0) {
    $targetVM = @()
    Write-Output "No VMs available for processing"
}
elseif ($excludeVM.Count -gt 0) {
    $targetVM = $VMList | Where-Object { $_ -notin $excludeVM }
    Write-Output "Applied exclusion filter"
}
else {
    $targetVM = $VMList
    Write-Output "No exclusions applied"
}

Write-Output "Target VMs for startup: $($targetVM -join ', ')"
Write-Output "Number of VMs to start: $($targetVM.Count)"

#対象VM起動
Write-Output "Starting VMs..."
$successCount = 0
$failureCount = 0

if ($targetVM.Count -eq 0) {
    Write-Output "No VMs to start."
}
else {
    $targetVM | ForEach-Object {
        try {
            $vmName = $_
            Write-Output "Starting VM: $vmName"
            
            # VM情報を取得してリソースグループを特定
            $vmInfo = Get-AzVM -Name $vmName -ErrorAction Stop
            $resourceGroupName = $vmInfo.ResourceGroupName
            
            # VM起動（NoWaitオプションで並列実行）
            Start-AzVM -ResourceGroupName $resourceGroupName -Name $vmName -NoWait
            Write-Output "VM '$vmName' in resource group '$resourceGroupName' - start command sent successfully"
            $successCount++
        }
        catch {
            Write-Output "Failed to start VM '$vmName': $($_.Exception.Message)"
            $failureCount++
        }
    }
}

Write-Output "=== VM Startup Summary ==="
Write-Output "Total VMs discovered: $totalVMsFound"
Write-Output "VMs after exclusion: $($targetVM.Count)"
Write-Output "Successfully started: $successCount"
Write-Output "Failed to start: $failureCount"
Write-Output "VM startup process completed."
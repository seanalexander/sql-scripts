class StartEnd {
    [DateTime]$ScriptStart
    [DateTime]$ScriptEnd

    [TimeSpan]TotalDuration() {
        return (New-TimeSpan -Start $this.ScriptStart -End $this.ScriptEnd)
    }

}

class BlobDeletionResults {
    [string]$FileType
    [Int]$TotalFiles
    [Int]$TotalMb
    [Int]$TotalGb
    [Int]$TotalTb
}

Function Remove-SqlBlobBackups {
    [cmdletbinding()]
    Param (
        [string]$AccountName,
        [string]$AccountKey,
        [string]$Container,
        [DateTime]$StartDate = (Get-Date).AddYears(-1), #The farthest you want to go back in time.
        [DateTime]$EndDate = (Get-Date).AddDays(-30), #The date you want to stop at.
        [ValidateSet('*.trn', '*.bak', '*.dif')]
        [string[]]$BlobPatterns = @("*.trn", "*.bak", "*.dif"),
        [ValidateRange(1, 100000)]
        [int]$ProgressUpdates = 1000,
        [switch]$DeleteFiles
    )
    # End of Parameters
    Write-Host "StartDate:`t$($StartDate)";
    Write-Host "EndDate:`t$($EndDate)";

    $StartEnd = [StartEnd]::new();
    $StartEnd.ScriptStart = Get-Date;
    
    $ctx = New-AzStorageContext -StorageAccountName $AccountName -StorageAccountKey $accountkey
        
    $BlobPatternSizes = @(0.00, 0.00, 0.00);
    $BlobPatternTotalCount = @(0, 0, 0);
    
    $BlobPatternIndex = 0;

    Write-Host "";

    $BlobPatterns | ForEach-Object {
        $BlobsToDelete = Get-AzStorageBlob -Container $Container -Blob $_ -Context $ctx | Where-Object { $_.LastModified -le $EndDate -and $_.LastModified -ge $StartDate }
        Write-Host "Blob Pattern:`t`t$($_)";
        Write-Host "Blobs to Delete:`t$($BlobsToDelete.Count)";
    
        $HowManyRows = $BlobsToDelete.Count;

        $BlobPatternTotalCount[$BlobPatternIndex] = 0;
        $BlobPatternSizes[$BlobPatternIndex] = 0;

        $BlobsToDelete | Select-Object | ForEach-Object {
            if ($BlobPatternTotalCount[$BlobPatternIndex] -eq 0 -or (($BlobPatternTotalCount[$BlobPatternIndex] % $ProgressUpdates) -eq 0) -or (($BlobPatternTotalCount[$BlobPatternIndex] + 1) -eq $HowManyRows)) {
                $CurrentBlobNumber = $($BlobPatternTotalCount[$BlobPatternIndex] + 1);
                $EndBlobNumber = $HowManyRows;
                $CurrentPercentage = ($CurrentBlobNumber / $EndBlobNumber).ToString("P");
                Write-Host "$(($CurrentPercentage))`tProcessing Row`t$($CurrentBlobNumber) of $($EndBlobNumber) ($(Get-Date))";
                Write-Host "`tLastModified:`t$($_.LastModified.LocalDateTime)";
                Write-Host "`tBlob Name:`t$($_.Name)`n";
            }
            $BlobPatternSizes[$BlobPatternIndex] = $BlobPatternSizes[$BlobPatternIndex] + ($_.Length);
            if ($DeleteFiles) {
                $_ | Remove-AzStorageBlob #This fails if there is a lease.
            }
            else {
            }
            $BlobPatternTotalCount[$BlobPatternIndex] = $BlobPatternTotalCount[$BlobPatternIndex] + 1;
        }
        $BlobPatternIndex = $BlobPatternIndex + 1;
        Write-Host "`n";
    }

    $ResultSummary = [System.Collections.ArrayList]::new();
    For ($BlobPatternIndex = 0; $BlobPatternIndex -lt $BlobPatterns.Count; $BlobPatternIndex++) {
        $Results = [BlobDeletionResults]::new()
        $Results.FileType = $($BlobPatterns[$BlobPatternIndex]);
        $Results.TotalFiles = $($BlobPatternTotalCount[$BlobPatternIndex]);
        $Results.TotalMb = $([double]('{0:N2}' -f ($BlobPatternSizes[$BlobPatternIndex] / 1mb)));
        $Results.TotalGb = $([double]('{0:N2}' -f ($BlobPatternSizes[$BlobPatternIndex] / 1gb)));
        $Results.TotalTb = $([double]('{0:N2}' -f ($BlobPatternSizes[$BlobPatternIndex] / 1tb)));
        [void]$ResultSummary.Add($Results);
    }

    $ResultSummary | Select-Object | Format-Table;

    $StartEnd.ScriptEnd = Get-Date;
    
    $StartEnd | Select-Object @{Name = "Script Started"; Expression = { $_.ScriptStart } }, @{Name = "Script Ended"; Expression = { $_.ScriptEnd } }, @{Name = "Total Duration"; Expression = { $_.TotalDuration().ToString() } } | Format-List
}

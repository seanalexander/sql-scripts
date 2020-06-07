Function Remove-SqlBlobBackups {
    [cmdletbinding()]
    Param (
        [DateTime]$StartDate,
        [DateTime]$EndDate,
        [string]$AccountName,
        [string]$AccountKey,
        [string]$Container,
        [string[]]$BlobPatterns = @("*.trn", "*.bak", "*.dif"),
        [int]$ProgressUpdates   = 1000
    )
    # End of Parameters
    Process {
        Write-Host "StartDate:`t$($StartDate)";
        Write-Host "EndDate:`t$($EndDate)";

        $StartEnd = @{ };
        $StartEnd.ScriptStart = Get-Date;
    
        $ctx = New-AzStorageContext -StorageAccountName $AccountName -StorageAccountKey $accountkey
        
        $BlobPatternSizes = @(0.00, 0.00, 0.00);
        $BlobPatternTotalCount = @(0, 0, 0);
    
        $BlobPatternIndex = 0;
    
        $BlobPatterns | ForEach-Object {
            $BlobsToDelete = Get-AzStorageBlob -Container $Container -Blob $_ -Context $ctx | Where-Object { $_.LastModified -le $EndDate -and $_.LastModified -ge $StartDate }
            Write-Host "Blob Pattern: $($_)";
            Write-Host "Blobs to Delete: $($BlobsToDelete.Count)";
    
            $HowManyRows = $BlobsToDelete.Count;
    
            $BlobsToDelete | Select-Object | ForEach-Object {
                if ($BlobPatternTotalCount[$BlobPatternIndex] -eq 0 -or (($BlobPatternTotalCount[$BlobPatternIndex] % $ProgressUpdates) -eq 0) -or (($BlobPatternTotalCount[$BlobPatternIndex] + 1) -eq $HowManyRows)) {
                    Write-Host "Processing Row $($BlobPatternTotalCount[$BlobPatternIndex]+1) of $($HowManyRows) @ ($(Get-Date))";
                    Write-Host "`tLastModified:`t$($_.LastModified.LocalDateTime)`tName: $($_.Name)";
                }
                $BlobPatternSizes[$BlobPatternIndex] = $BlobPatternSizes[$BlobPatternIndex] + ($_.Length);
                $_ | Remove-AzStorageBlob #This fails if there is a lease.
                $BlobPatternTotalCount[$BlobPatternIndex] = $BlobPatternTotalCount[$BlobPatternIndex] + 1;
            }
            $BlobPatternIndex = $BlobPatternIndex + 1;
        }
    
        Write-Host "";
    
        For ($BlobPatternIndex = 0; $BlobPatternIndex -lt $BlobPatterns.Count; $BlobPatternIndex++) {
            $Results = @{ }
            $Results.FileType = $($BlobPatterns[$BlobPatternIndex]);
            $Results.TotalFiles = $($BlobPatternTotalCount[$BlobPatternIndex]);
            $Results.TotalMb = $([double]('{0:N2}' -f ($BlobPatternSizes[$BlobPatternIndex]/1mb)));
            $Results.TotalGb = $([double]('{0:N2}' -f ($BlobPatternSizes[$BlobPatternIndex]/1gb)));
            $Results.TotalTb = $([double]('{0:N2}' -f ($BlobPatternSizes[$BlobPatternIndex]/1tb)));
            $Results | Select-Object FileType, TotalFiles, TotalMb, TotalGb, TotalTb
        }
    
        $StartEnd.ScriptEnd = Get-Date;
    
        $StartEnd | Select-Object ScriptStart, ScriptEnd;
    } # End of Process
}

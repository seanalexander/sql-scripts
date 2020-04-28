<#
I should exist under: C:\SQLServerFiles\TEMPDBSetup\
My Windows Task Scheduler file can be imported from: C:\SQLServerFiles\TEMPDBSetup\TempDBInit.xml
It is triggered to run at Startup.
It can be triggered manually with no issue.
#>

<#
Begin Global Variables
#>

    # Log File Location
    $LogFileLocation = "C:\SQLServerFiles\TEMPDBSetup\SQLTempDBInit.log";
    
    # Specify the Drive Letter for TempDB
    $driveLetter_tempDB = "T";

<#
End Global Variables
#>

<#
Begin Helper Functions
#>

<#
Write-Log lifted from: https://stackoverflow.com/a/38738942
#>

Function Write-Log {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $False)]
        [ValidateSet("INFO", "WARN", "ERROR", "FATAL", "DEBUG")]
        [String]
        $Level = "INFO",

        [Parameter(Mandatory = $True)]
        [string]
        $Message,

        [Parameter(Mandatory = $False)]
        [string]
        $logfile
    )

    $Stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
    $Line = "$Stamp $Level $Message"
    If ($logfile) {
        Add-Content $logfile -Value $Line
    }
    Else {
        Write-Output $Line
    }
}

<#
End Helper Functions
#>

<#
Begin Main Functions
#>

<#
New-RAID_LS_v2:
This function should return if there is already a tempdb configured.
It will also return if there is an error configuring the tempdb disk pools: This is severe but no alert is sent out.
Proper error handling should be built in--and with that said, this set of routines should never fail on an LS*_v2 series.
#>
Function New-RAID_LS_v2 {
    # Get a list of the Drive Letters
    $driveLetters = (Get-Volume).DriveLetter;

    # Verify that the T Drive does not already exist
    if ($driveLetters -contains $driveLetter_tempDB) {
        Write-Log -Level "INFO" -logfile $LogFileLocation -Message  "$($driveLetter_tempDB) Drive Exists."
        return;
    }
    else {
        # Name of the Disk Pool
        $Pool_FriendlyName = "TempDBPOOL";
        # Name of the Disk
        $Disk_FriendlyName = "TempDB";

        Write-Log -Level "INFO" -logfile $LogFileLocation -Message "Creating T Drive";

        #Get Storage SubSystem

        Write-Log -Level "INFO" -logfile $LogFileLocation -Message "Get Storage SubSystem"
        $StorageSubSystem = Get-StorageSubSystem;

        if ($StorageSubSystem.UniqueId -eq $nil) {
            Write-Log -Level "ERROR" -logfile $LogFileLocation -Message  "No Storage SubSystem returned.";
            return;
        }

        # Get list of Disks that match Microsoft NVMe Direct Disk

        Write-Log -Level "INFO" -logfile $LogFileLocation -Message "Get list of Disks that match Microsoft NVMe Direct Disk"
        $PhysicalDisks = Get-PhysicalDisk -CanPool $true -Model "Microsoft NVMe Direct Disk";

        if ($PhysicalDisks.FriendlyName -eq $nil) {
            Write-Log -Level "ERROR" -logfile $LogFileLocation -Message  "No Disks are Candidates for a Pool.";
            return;
        }

        # Create pool

        Write-Log -Level "INFO" -logfile $LogFileLocation -Message "Create pool"
        $StoragePool = New-StoragePool -FriendlyName $Pool_FriendlyName -StorageSubSystemID $StorageSubSystem.UniqueId -PhysicalDisks $PhysicalDisks;

        if ($StoragePool.FriendlyName -eq $nil) {
            Write-Log -Level "ERROR" -logfile $LogFileLocation -Message  "No Storage Pool exists.";
            return;
        }

        # Create Virtual Disk

        Write-Log -Level "INFO" -logfile $LogFileLocation -Message "Create Virtual Disk"
        $VirtualDisk = New-VirtualDisk -FriendlyName $Disk_FriendlyName -StoragePoolFriendlyName $Pool_FriendlyName -AutoNumberOfColumns -ResiliencySettingName Simple -ProvisioningType Fixed -UseMaximumSize;

        if ($VirtualDisk.FriendlyName -eq $nil) {
            Write-Log -Level "ERROR" -logfile $LogFileLocation -Message  "No Virtual Disk exists.";
            return;
        }

        # Initialize Virtual Disk as GPT

        Write-Log -Level "INFO" -logfile $LogFileLocation -Message "Initialize Virtual Disk as GPT"
        $InitializedDisk = $VirtualDisk | Initialize-Disk -PartitionStyle GPT -PassThru;
    
        if ($InitializedDisk.Number -eq $nil) {
            Write-Log -Level "ERROR" -logfile $LogFileLocation -Message  "No Initialized Disk Exists.";
            return;
        }

        # Create new Partition and Map it to the T Drive
    
        Write-Log -Level "INFO" -logfile $LogFileLocation -Message "Create new Partition and Map it to the T Drive"
        $T_Drive = $InitializedDisk | New-Partition -DriveLetter $driveLetter_tempDB -UseMaximumSize;

        if ($T_Drive.PartitionNumber -eq $nil) {
            Write-Log -Level "ERROR" -logfile $LogFileLocation -Message  "No Partition Exists.";
            return;
        }

        # Format New Volume
    
        Write-Log -Level "INFO" -logfile $LogFileLocation -Message "Format New Volume";
        $Formatted_Volume = $T_Drive | Format-Volume -FileSystem NTFS -NewFileSystemLabel "tempdb" -AllocationUnitSize 65536 -Confirm:$false;

        if ($Formatted_Volume.DriveLetter -ne $driveLetter_tempDB) {
            Write-Log -Level "ERROR" -logfile $LogFileLocation -Message  "The Drive Letter Reported ($($Formatted_Volume.DriveLetter)) is not: $($driveLetter_tempDB).";
            return;
        }
    }
}

<#
New-LS_v2_TempDBFolder:
The next version of New-LS_v2_TempDBFolder should be generic such as: New-IaaS_SQLServer_TempDB
It should create both a D: and T: folder for tempdb, only if the drives exist.
#>
Function New-LS_v2_TempDBFolder {
    $tempFolder = "$($driveLetter_tempDB):\SQLTEMP"

    if (!(test-path -path $tempFolder)) {
        Write-Log -Level "INFO" -logfile $LogFileLocation -Message "TempDB Folder does not Exist, Creating Folder"
        New-Item -ItemType directory -Path $tempFolder;
    }
}

<#
Start-L2_v2_SQLServer:
Simply starts the SQL Server and SQL Server Agent.
#>
Function Start-L2_v2_SQLServer {
    $SQLService = "SQL Server (MSSQLSERVER)";
    $SQLAgentService = "SQL Server Agent (MSSQLSERVER)";

    Write-Log -Level "INFO" -logfile $LogFileLocation -Message "Starting SQL Server"
    Start-Service $SQLService;

    # SQL Server Agent cannot start without SQL Server
    Write-Log -Level "INFO" -logfile $LogFileLocation -Message "Starting SQL Server Agent"
    Start-Service $SQLAgentService;
}

<#
End Main Functions
#>

<#
Begin Program Code
#>



Write-Log -Level "INFO" -logfile $LogFileLocation -Message  "SQL Temp DB Initialization Script: Started"

<#
Each one of these calls is idempotent, which means they can be called multiple times without changing the desired outcome.
#>

New-RAID_LS_v2;

New-LS_v2_TempDBFolder;

Start-L2_v2_SQLServer;


Write-Log -Level "INFO" -logfile $LogFileLocation -Message  "SQL Temp DB Initialization Script: Ended"

Write-Log -Level "INFO" -logfile $LogFileLocation -Message  "--------------------------------------------------"
Write-Log -Level "INFO" -logfile $LogFileLocation -Message  " "

<#
End Program Code
#>

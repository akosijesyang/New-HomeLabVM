<#
.SYNOPSIS
A script that automates the creation of Hyper-V virtual machine.

.DESCRIPTION
A PowerShell script specifically created for creating Hyper-V virtual machine by either using a pre-created VHD (parent) or from an ISO file.

.EXAMPLE
Just run the script, it will prompt you what's required to proceed

.INPUTS
N/A

.OUTPUTS
N/A

Big thanks to @MotoX80 of microsoft.com/learn community for correcting my While loop implementation
https://docs.microsoft.com/en-us/answers/questions/528212/get-back-to-read-host-if-invalid.html
https://docs.microsoft.com/en-us/users/motox80/
#>

$host.ui.RawUI.WindowTitle = 'New-HomeLabVM - Create a virtual machine, FAST.' # Replaces default Powershell window title
##############################################################
##############################################################
#Global Variables | Modify the following variables as necessary
$VMFilesDirectory = "D:\Hyper-V Lab Files\virtual-machines\vm-files\Virtual Machines" # Folder where VM files will be stored
$ParentVHDDirectory = "D:\Hyper-V Lab Files\vhd templates" # Folder where parent VHD is stored
$VHDFileDirectory = "D:\Hyper-V Lab Files\virtual-machines\vhd-files" # Folder where new VHD files will be created
$ISOFileDirectory = "D:\Hyper-V Lab Files\iso-files" # Folder where ISO files are stored
$NATvSwitch = "vNAT"
##############################################################
##############################################################
Start-Sleep 2
# Prerequisite Checks
$vmms = Get-Service -Name "vmms"
$vmcompute = Get-Service -Name "vmcompute"
if (((Get-ChildItem -Path $ISOFileDirectory).Extension -notcontains ".iso") -and `
    ((Get-ChildItem -Path $ParentVHDDirectory).Extension -notcontains ".vhdx") -and `
    ($vmms.Status -ne "running") -and ($vmcompute.Status -ne "running")) {
    Write-Host "`n!--Prerequisite checks failed.`n" -ForegroundColor Red
    Write-Host "Make sure you modify the values decalred on the Global Variables section of the script and try again." -ForegroundColor Red
    Write-Host "`nWindow will close automatically." -ForegroundColor Yellow
    Exit
}
Write-Host "`n!--Prerequisite checks passed.`n" -ForegroundColor Green
##############################################################

# ...existing code...

Write-Host "Select VM creation method:" -ForegroundColor Yellow
Write-Host "1. From template (VHD / VHDX)"
Write-Host "2. From Image File (ISO)"
Write-Host "3. Windows 11 VM (with TPM, Secure Boot, etc.)"
$VMOption = Read-Host "Type 1, 2, or 3"

do {
    $VMOption = Read-Host "Type 1, 2, or 3"
    if ($VMOption -notin @('1','2','3')) {
        Write-Host "Invalid selection. Please enter 1, 2, or 3." -ForegroundColor Red
    }
} while ($VMOption -notin @('1','2','3'))

switch ($VMOption) {
    '1' {
        # Existing logic for template (VHD)
        Write-Host "`nNew VM will use a VHD template..." -ForegroundColor Yellow
$ArrayIndex = 0 # Equivalent to the index value to each line in the array
$ParentVHDFile = Get-ChildItem -Path $ParentVHDDirectory | Where-Object -Property Name -Like "*.vhdx" | `
    Select-Object -Property Name, @{ Name = "ID" ; Expression = { $script:ArrayIndex; $script:ArrayIndex++ } }
$ParentVHDFileIndex = $ParentVHDFile.Count - 1
Write-Host "`nParent VHD file selection:" -ForegroundColor Green
$ParentVHDFile | Format-Table
While ($true) {
    $SelectArrayIndex = Read-Host "`nSelect an ID between 0 and $ParentVHDFileIndex"
    if ($SelectArrayIndex -notmatch "^\d+$") {
        Write-Host "Invalid ID. Try Again" -ForegroundColor Red
        Start-Sleep 2
        Write-Host "`nParent VHD file selection:" -ForegroundColor Green
        $ParentVHDFile | Format-Table
        continue
    }
    $SelectArrayIndex = [int]$SelectArrayIndex  # Ensures only integer value is accepted
    if ($SelectArrayIndex -le $ParentVHDFileIndex) {
        Write-Host ""
        Write-Host You selected $ParentVHDFile.Name[$SelectArrayIndex]... -ForegroundColor Green
        break
    }
    Write-Host "Invalid ID. Try Again" -ForegroundColor Red
    Start-Sleep 2
    Write-Host "`nParent VHD file selection:" -ForegroundColor Green
    $ParentVHDFile | Format-Table
}
# Create VM from parent VHD
$HomeLabVMName = Read-Host "`nEnter VM name" -ErrorAction Ignore #Asks the user to type in the VM name
$HomeLabVMName = $HomeLabVMName.Trim() # Removes any space/s on the begining/end of VM name
if ($HomeLabVMName -ne "") {
    # Template-VHD 1: VM name defined by user | Creates VM | Creates VHD | Config VM settings
    $SelectedParentVHDFile = $ParentVHDFile.Name[$SelectArrayIndex] # Maps parent VHD file
    $ParentVDH = "$ParentVHDDirectory\$SelectedParentVHDFile" # Sets parent/reference VHD
    New-VHD -ParentPath $ParentVDH -Path "$VHDFileDirectory\$HomeLabVMName.vhdx" -Differencing # Maps new VHD to parent VHD
    New-VM -Name $HomeLabVMName -Path "$VMFilesDirectory\$HomeLabVMName" -Generation 2 -MemoryStartupBytes 1GB `
        -SwitchName "$NATvSwitch" -VHDPath "$VHDFileDirectory\$HomeLabVMName.vhdx"  -BootDevice "VHD" # Creates VM
    Set-VM -Name $HomeLabVMName -ProcessorCount "4" -AutomaticCheckpointsEnabled $false -DynamicMemory `
        -MemoryMaximumBytes 4GB # Sets up additional VM configurations
    Get-VMIntegrationService -Name "Guest Service Interface" -VMName $HomeLabVMName | `
        Enable-VMIntegrationService # Turns on VM integration service
    Set-VMFirmware -VMName "$($HomeLabVMName)" -EnableSecureBoot 1 # Turns off Secure Boot (allowing non-Windows ISO to be detected)
    Write-Host "`nWindow will close automatically." -ForegroundColor Yellow
    Start-Sleep -Seconds "5"
}
else {
    # Template-VHD Option 2: VM name prompt skipped by user | Creates VM | Creates VHD | Config VM settings
    $NewVMTimeStamp = Get-Date -Format yyyyMMddTHHmmss # Captures point-in-time
    $HomeLabVMNameAlt = "VM-$NewVMTimeStamp" # Sets VM name based on timestamp
    Write-Host "You skipped VM name input - Your new VM will named as $HomeLabVMNameAlt..." -ForegroundColor Yellow
    Start-Sleep 2
    $SelectedParentVHDFile = $ParentVHDFile.Name[$SelectArrayIndex] # Maps parent VHD file
    $ParentVDH = "$ParentVHDDirectory\$SelectedParentVHDFile" # Sets parent/reference VHD
    New-VHD -ParentPath $ParentVDH -Path "$VHDFileDirectory\$HomeLabVMNameAlt.vhdx" -Differencing # Maps new VHD to parent VHD
    New-VM -Name $HomeLabVMNameAlt -Path "$VMFilesDirectory\$HomeLabVMNameAlt" -Generation 2 -MemoryStartupBytes 1GB `
        -SwitchName "$NATvSwitch" -VHDPath "$VHDFileDirectory\$HomeLabVMNameAlt.vhdx" -BootDevice "VHD" # Creates VM
    Set-VM -Name $HomeLabVMNameAlt -ProcessorCount "4" -AutomaticCheckpointsEnabled $false -DynamicMemory `
        -MemoryMaximumBytes 4GB # Sets up additional VM configurations
    Get-VMIntegrationService -Name "Guest Service Interface" -VMName $HomeLabVMNameAlt | `
        Enable-VMIntegrationService # Turns on VM integration service
    Set-VMFirmware -VMName "$($HomeLabVMNameAlt)" -EnableSecureBoot 1 # Turns off Secure Boot (allowing non-Windows ISO to be detected)
    Write-Host "`nWindow will close automatically" -ForegroundColor Yellow
    Start-Sleep -Seconds "5"
}
Clear-History
# Nothing follows
        # ...existing code for template VHD...
    }
    '2' {
        # Existing logic for ISO
        # Creates VM from ISO
        ##############################################################
        Write-Host "`nNew VM will be built using an ISO..." -ForegroundColor Yellow
        Start-Sleep 2
        ##############################################################
        $ArrayIndex = 0 # Equivalent to the index value to each line in the array
        $ISOFile = Get-ChildItem -Path $ISOFileDirectory | Where-Object -Property Name -Like "*.iso" | `
            Select-Object -Property Name, @{ Name = "ID" ; Expression = { $script:ArrayIndex; $script:ArrayIndex++ } }
        $ISOFileIndex = $ISOFile.Count - 1
        Write-Host "`nISO file selection:" -ForegroundColor Green
        $ISOFile | Format-Table
        While ($true) {
            $SelectArrayIndex = Read-Host "`nSelect an ID between 0 and $ISOFileIndex"
            if ($SelectArrayIndex -notmatch "^\d+$") {
                Write-Host "Invalid ID. Try Again" -ForegroundColor Red
                Start-Sleep 2
                Write-Host "`nISO file selection:" -ForegroundColor Green
                $ISOFile | Format-Table
                continue
            }
            $SelectArrayIndex = [int]$SelectArrayIndex  # Ensures only integer value is accepted
            if ($SelectArrayIndex -le $ISOFileIndex) {
                Write-Host ""
                Write-Host You selected $ISOFile.Name[$SelectArrayIndex] -ForegroundColor Green
                break
            }
            Write-Host "Invalid ID. Try Again" -ForegroundColor Red
            Start-Sleep 2
            Write-Host "`nISO file selection:" -ForegroundColor Green
            $ISOFile | Format-Table
        }
        Start-Sleep 1
        $VMGenOption = Read-Host "`nType Gen1 if creating a Linux VM, else type any key to continue"
        if ($VMGenOption -eq "Gen1") {
            Write-Host "`nGen-1 Virtual Machine will be created (no dynamic memory)" -ForegroundColor Green
            Write-Host "!--INFORMATIONAL: Gen-1 VM is ideal for Linux for compatibility" -ForegroundColor Yellow
            #ISO Option 1a (Gen-1 VM): VM name defined by user | Creates VM | Creates VHD | Config VM settings
            $HomeLabVMName = Read-Host "`nEnter VM name" -ErrorAction Ignore #Asks the user to type in the VM name
            $HomeLabVMName = $HomeLabVMName.Trim() # Removes any space/s on the begining/end of VM name
            if ($HomeLabVMName -ne "") {
                New-VHD -Path "$VHDFileDirectory\$HomeLabVMName.vhd" -Dynamic -SizeBytes 100GB
                New-VM -Name $HomeLabVMName -Path "$VMFilesDirectory\$HomeLabVMName" -Generation 1 -MemoryStartupBytes 4GB `
                    -SwitchName "$NATvSwitch" -VHDPath "$VHDFileDirectory\$HomeLabVMName.vhd" # Creates VM
                Set-VM -Name $HomeLabVMName -ProcessorCount "4" -AutomaticCheckpointsEnabled $false # Sets up additional VM configurations
                $SelectedISOFile = $ISOFile.Name[$SelectArrayIndex] # Maps ISO file
                Add-VMDvdDrive -VMName $HomeLabVMName -Path $ISOFileDirectory\$SelectedISOFile #Adds DVD drive and then mounts ISO file
                Get-VMIntegrationService -Name "Guest Service Interface" -VMName $HomeLabVMName | `
                    Enable-VMIntegrationService # Turns on VM integration service
                Set-VMBios -VMName "$($HomeLabVMName)" -StartupOrder @("CD", "IDE", "LegacyNetworkAdapter", "Floppy") # Sets ISO as first boot device
                Write-Host "`nWindow will close automatically." -ForegroundColor Yellow
                Start-Sleep -Seconds "5"
            }
            else {
                Start-Sleep 2
                # ISO Option 2a (Gen-1 VM): VM name prompt skipped by user | Creates VM | Creates VHD | Config VM settings
                $NewVMTimeStamp = Get-Date -Format yyyyMMddTHHmmss # Captures point-in-time
                $HomeLabVMNameAlt = "VM-$NewVMTimeStamp" # ets VM name based on timestamp
                Write-Host "`nYou skipped VM name input - Your new VM will named as $HomeLabVMNameAlt..." -ForegroundColor Green
                Start-Sleep 2
                New-VHD -Path "$VHDFileDirectory\$HomeLabVMNameAlt.vhd" -Dynamic -SizeBytes 100GB # Creates VHD/boot drive
                New-VM -Name $HomeLabVMNameAlt -Path "$VMFilesDirectory\$HomeLabVMNameAlt" -BootDevice "VHD" -Generation 1 -MemoryStartupBytes 4GB `
                    -SwitchName "$NATvSwitch" -VHDPath "$VHDFileDirectory\$HomeLabVMNameAlt.vhd" # Creates VM
                Set-VM -Name $HomeLabVMNameAlt -ProcessorCount "4" -AutomaticCheckpointsEnabled $false # Sets up additional VM configurations
                $SelectedISOFile = $ISOFile.Name[$SelectArrayIndex] # Maps ISO file
                Add-VMDvdDrive -VMName $HomeLabVMNameAlt -Path $ISOFileDirectory\$SelectedISOFile # Adds DVD drive and then mounts ISO file
                Get-VMIntegrationService -Name "Guest Service Interface" -VMName $HomeLabVMNameAlt | `
                    Enable-VMIntegrationService # Turns on VM integration service
                Set-VMBios -VMName "$($HomeLabVMNameAlt)" -StartupOrder @("CD", "IDE", "LegacyNetworkAdapter", "Floppy") # Sets ISO as first boot device
                Write-Host "`nWindow will close automatically." -ForegroundColor Yellow
                Start-Sleep -Seconds "5"
            }
        }
        else {
            Write-Host "`nGen-2 Virtual Machine will be created (with dynamic memory)" -ForegroundColor Green
            # ISO Option 1b (Gen-2 VM): VM name defined by user | Creates VM | Creates VHD | Config VM settings
            $HomeLabVMName = Read-Host "`nEnter VM name" -ErrorAction Ignore #Asks the user to type in the VM name
            $HomeLabVMName = $HomeLabVMName.Trim() # Removes any space/s on the begining/end of VM name
            if ($HomeLabVMName -ne "") {
                New-VHD -Path "$VHDFileDirectory\$HomeLabVMName.vhdx" -Dynamic -SizeBytes 100GB
                New-VM -Name $HomeLabVMName -Path "$VMFilesDirectory\$HomeLabVMName" -Generation 2 -MemoryStartupBytes 1GB `
                    -SwitchName "$NATvSwitch" -VHDPath "$VHDFileDirectory\$HomeLabVMName.vhdx" # Creates VM
                Set-VM -Name $HomeLabVMName -ProcessorCount "4" -AutomaticCheckpointsEnabled $false -DynamicMemory `
                    -MemoryMaximumBytes 4GB # Sets up additional VM configurations
                $SelectedISOFile = $ISOFile.Name[$SelectArrayIndex] # Maps ISO file
                Add-VMDvdDrive -VMName $HomeLabVMName -Path $ISOFileDirectory\$SelectedISOFile #Adds DVD drive and then mounts ISO file
                Get-VMIntegrationService -Name "Guest Service Interface" -VMName $HomeLabVMName | `
                    Enable-VMIntegrationService # Turns on VM integration service
                Set-VMFirmware -VMName "$($HomeLabVMName)" -EnableSecureBoot 1 # Turns off Secure Boot (allowing non-Windows ISO to be detected)
                $InspectBootOrder = Get-VMFirmware -VMName "$($HomeLabVMName)"
                $InspectBootOrder.BootOrder
                $HddDrive = $InspectBootOrder.BootOrder[0]
                $NetAdapter = $InspectBootOrder.BootOrder[1]
                $DvdDrive = $InspectBootOrder.BootOrder[2]
                Set-VMFirmware -VMName "$($HomeLabVMName)"-BootOrder $DvdDrive,$HddDrive,$NetAdapter # Sets ISO/DVD as first boot device
                Write-Host "`nWindow will close automatically." -ForegroundColor Yellow
                Start-Sleep -Seconds "5"
            }
            else {
                Start-Sleep 2
                # ISO Option 2b (Gen-2 VM): VM name prompt skipped by user | Creates VM | Creates VHD | Config VM settings
                $NewVMTimeStamp = Get-Date -Format yyyyMMddTHHmmss # Captures point-in-time
                $HomeLabVMNameAlt = "VM-$NewVMTimeStamp" # ets VM name based on timestamp
                Write-Host "You skipped VM name input - Your new VM will named as $HomeLabVMNameAlt..." -ForegroundColor Green
                Start-Sleep 2
                New-VHD -Path "$VHDFileDirectory\$HomeLabVMNameAlt.vhdx" -Dynamic -SizeBytes 100GB # Creates VHD/boot drive
                New-VM -Name $HomeLabVMNameAlt -Path "$VMFilesDirectory\$HomeLabVMNameAlt" -BootDevice "VHD" -Generation 2 -MemoryStartupBytes 1GB `
                    -SwitchName "$NATvSwitch" -VHDPath "$VHDFileDirectory\$HomeLabVMNameAlt.vhdx" # Creates VM
                Set-VM -Name $HomeLabVMNameAlt -ProcessorCount "4" -AutomaticCheckpointsEnabled $false -DynamicMemory `
                    -MemoryMaximumBytes 4GB # Sets up additional VM configurations
                $SelectedISOFile = $ISOFile.Name[$SelectArrayIndex] # Maps ISO file
                Add-VMDvdDrive -VMName $HomeLabVMNameAlt -Path $ISOFileDirectory\$SelectedISOFile # Adds DVD drive and then mounts ISO file
                Get-VMIntegrationService -Name "Guest Service Interface" -VMName $HomeLabVMNameAlt | `
                    Enable-VMIntegrationService # Turns on VM integration service
                Set-VMFirmware -VMName "$($HomeLabVMNameAlt)" -EnableSecureBoot 1 # Turns off Secure Boot (allowing non-Windows ISO to be detected)
                $InspectBootOrder = Get-VMFirmware -VMName "$($HomeLabVMNameAlt)"
                $InspectBootOrder.BootOrder
                $HddDrive = $InspectBootOrder.BootOrder[0]
                $NetAdapter = $InspectBootOrder.BootOrder[1]
                $DvdDrive = $InspectBootOrder.BootOrder[2]
                Set-VMFirmware -VMName "$($HomeLabVMNameAlt)" -BootOrder $DvdDrive,$HddDrive,$NetAdapter # Sets ISO/DVD as first boot device
                Write-Host "`nWindow will close automatically." -ForegroundColor Yellow
                Start-Sleep -Seconds "5"
            }
        }
        exit 
        # ...existing code for ISO...
    }
    '3' {
        Write-Host "`nWindows 11 VM will be created (Gen2, Secure Boot, TPM, 4 CPUs, 4GB RAM min)" -ForegroundColor Green
        $Win11VMName = Read-Host "`nEnter Windows 11 VM name"
        $Win11VMName = $Win11VMName.Trim()
        $Win11VHDPath = "$VHDFileDirectory\$Win11VMName.vhdx"
        $Win11VMPath = "$VMFilesDirectory\$Win11VMName"
        $Win11ISO = Get-ChildItem -Path $ISOFileDirectory | Where-Object { $_.Name -like "*.iso" } | Select-Object -First 1
        if (-not $Win11ISO) {
            Write-Host "No ISO found in $ISOFileDirectory" -ForegroundColor Red
            exit
        }
        # Create VHD
        New-VHD -Path $Win11VHDPath -Dynamic -SizeBytes 100GB
        # Create VM
        New-VM -Name $Win11VMName -Path $Win11VMPath -Generation 2 -MemoryStartupBytes 4GB `
            -SwitchName "$NATvSwitch" -VHDPath $Win11VHDPath
        # Configure VM
        Set-VM -Name $Win11VMName -ProcessorCount 4 -AutomaticCheckpointsEnabled $false -DynamicMemory `
            -MemoryMinimumBytes 4GB -MemoryMaximumBytes 8GB
        Set-VMFirmware -VMName $Win11VMName -EnableSecureBoot On
        Set-VMKeyProtector -VMName $Win11VMName -NewLocalKeyProtector
        Enable-VMTPM -VMName $Win11VMName
        Add-VMDvdDrive -VMName $Win11VMName -Path $Win11ISO.FullName
        Get-VMIntegrationService -VMName $Win11VMName | Enable-VMIntegrationService
        Write-Host "`nWindows 11 VM created and ready for install!" -ForegroundColor Green
        Write-Host "`nWindow will close automatically." -ForegroundColor Yellow
        Start-Sleep -Seconds 5
        exit
    }
    default {
        Write-Host "Invalid selection. Exiting." -ForegroundColor Red
        exit
    }
}
# ...existing code...
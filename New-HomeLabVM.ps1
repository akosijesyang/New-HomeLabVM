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
$VMFilesDirectory = "D:\Hyper-V Lab Files\virtual-machines\vm-files" # Folder where VM files will be stored
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
    Write-Host "Prerequisite checks failed." -ForegroundColor Red
    Write-Host "Make sure you modify the values decalred on the Global Variables section of the script and try again." -ForegroundColor Red
    Write-Host "`nWindow will close automatically." -ForegroundColor Yellow
    Exit
}
Write-Host "Prerequisite checks passed." -ForegroundColor Yellow
##############################################################
Write-Host "Do you want to create VM from template (VHD)?" -ForegroundColor Yellow
$ConfirmTemplate = Read-Host "Please type [y/n]"
while ($ConfirmTemplate -ne "y") {
    if ($ConfirmTemplate -eq 'n') { 
        # Creates VM from ISO
        ##############################################################
        ##############################################################
        Write-Host "New VM will be built using an ISO..." -ForegroundColor Yellow
        Start-Sleep 2
        ##############################################################
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
                Write-Host You selected $ISOFile.Name[$SelectArrayIndex] -ForegroundColor Green
                break
            }
            Write-Host "Invalid ID. Try Again" -ForegroundColor Red
            Start-Sleep 2
            Write-Host "`nISO file selection:" -ForegroundColor Green
            $ISOFile | Format-Table
        }
        # ISO Option 1: VM name defined by user | Creates VM | Creates VHD | Config VM settings
        $HomeLabVMName = Read-Host "Enter VM name" -ErrorAction Ignore #Asks the user to type in the VM name
        $HomeLabVMName = $HomeLabVMName.Trim() # Removes any space/s on the begining/end of VM name
        if ($HomeLabVMName -ne "") {
            New-VHD -Path "$VHDFileDirectory\$HomeLabVMName.vhdx" -Dynamic -SizeBytes 100GB
            New-VM -Name $HomeLabVMName -Path "$VMFilesDirectory\$HomeLabVMName" -Generation 2 -MemoryStartupBytes 1GB `
                -SwitchName "$NATvSwitch" -VHDPath "$VHDFileDirectory\$HomeLabVMName.vhdx" # Creates VM
            Set-VM -Name $HomeLabVMName -ProcessorCount "4" -AutomaticCheckpointsEnabled $false -DynamicMemory `
                -MemoryMaximumBytes 4GB # Sets up additional VM configurations
            $SelectedISOFile = $ISOFile.Name[$SelectArrayIndex] # Maps ISO file
            Add-VMDvdDrive -VMName $HomeLabVMName -Path $ISOFileDirectory\$SelectedISOFile #Adds DVD drive and then mounts ISO file
            $BootLoader = Get-VMFirmware $HomeLabVMName
            $DVD = $BootLoader.BootOrder[2]
            $HDD = $BootLoader.BootOrder[0]
            $PXE = $BootLoader.BootOrder[1]
            Set-VMFirmware $HomeLabVMName -BootOrder $DVD, $HDD, $PXE # Sets DVD as first bootable device
            Set-VMFirmware -VMName $HomeLabVMName -EnableSecureBoot 1 # Turns of Secure Boot
            Get-VMIntegrationService -Name "Guest Service Interface" -VMName $HomeLabVMName | `
                Enable-VMIntegrationService # Turns on VM integration service
            Write-Host "`nWindow will close automatically." -ForegroundColor Yellow
            Start-Sleep -Seconds "5"
        }
        else {
            Start-Sleep 2
            # ISO Option 2: VM name prompt skipped by user | Creates VM | Creates VHD | Config VM settings
            $NewVMTimeStamp = Get-Date -Format yyyyMMddTHHmmss # Captures point-in-time
            $HomeLabVMNameAlt = "VM-$NewVMTimeStamp" # ets VM name based on timestamp
            Write-Host "You skipped VM name input - Your new VM will named as $HomeLabVMNameAlt..." -ForegroundColor Yellow
            Start-Sleep 2
            New-VHD -Path "$VHDFileDirectory\$HomeLabVMNameAlt.vhdx" -Dynamic -SizeBytes 100GB # Creates VHD/boot drive
            New-VM -Name $HomeLabVMNameAlt -Path "$VMFilesDirectory\$HomeLabVMNameAlt" -BootDevice "VHD" -Generation 2 -MemoryStartupBytes 1GB `
                -SwitchName "$NATvSwitch" -VHDPath "$VHDFileDirectory\$HomeLabVMNameAlt.vhdx" # Creates VM
            Set-VM -Name $HomeLabVMNameAlt -ProcessorCount "4" -AutomaticCheckpointsEnabled $false -DynamicMemory `
                -MemoryMaximumBytes 4GB # Sets up additional VM configurations
            $SelectedISOFile = $ISOFile.Name[$SelectArrayIndex] # Maps ISO file
            Add-VMDvdDrive -VMName $HomeLabVMNameAlt -Path $ISOFileDirectory\$SelectedISOFile # Adds DVD drive and then mounts ISO file
            $BootLoader = Get-VMFirmware $HomeLabVMNameAlt
            $DVD = $BootLoader.BootOrder[2]
            $HDD = $BootLoader.BootOrder[0]
            $PXE = $BootLoader.BootOrder[1]
            Set-VMFirmware $HomeLabVMNameAlt -BootOrder $DVD, $HDD, $PXE # Sets DVD as first bootable device
            Get-VMIntegrationService -Name "Guest Service Interface" -VMName $HomeLabVMNameAlt | `
                Enable-VMIntegrationService # Turns on VM integration service
            Set-VMFirmware -VMName $HomeLabVMNameAlt -EnableSecureBoot 1 # Turns of Secure Boot
            Write-Host "`nWindow will close automatically." -ForegroundColor Yellow
            Start-Sleep -Seconds "5"
        }
        exit 
    }
    $ConfirmTemplate = Read-Host "Please type [y/n]"
}

Write-Host "New VM will use a VHD template..." -ForegroundColor Yellow
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
        Write-Host You selected $ParentVHDFile.Name[$SelectArrayIndex]... -ForegroundColor Green
        break
    }
    Write-Host "Invalid ID. Try Again" -ForegroundColor Red
    Start-Sleep 2
    Write-Host "`nParent VHD file selection:" -ForegroundColor Green
    $ParentVHDFile | Format-Table
}
# Create VM from parent VHD
$HomeLabVMName = Read-Host "Enter VM name" -ErrorAction Ignore #Asks the user to type in the VM name
$HomeLabVMName = $HomeLabVMName.Trim() # Removes any space/s on the begining/end of VM name
if ($HomeLabVMName -ne "") {
    # Template-VHD 1: VM name defined by user | Creates VM | Creates VHD | Config VM settings
    # $ParentVDH = "$ParentVHDDirectory\WS2019_Template.vhdx" #Sets parent/reference VHD
    $SelectedParentVHDFile = $ParentVHDFile.Name[$SelectArrayIndex] # Maps parent VHD file
    $ParentVDH = "$ParentVHDDirectory\$SelectedParentVHDFile" # Sets parent/reference VHD
    New-VHD -ParentPath $ParentVDH -Path "$VHDFileDirectory\$HomeLabVMName.vhdx" -Differencing # Maps new VHD to parent VHD
    New-VM -Name $HomeLabVMName -Path "$VMFilesDirectory\$HomeLabVMName" -Generation 2 -MemoryStartupBytes 1GB `
        -SwitchName "$NATvSwitch" -VHDPath "$VHDFileDirectory\$HomeLabVMName.vhdx"  -BootDevice "VHD" # Creates VM
    Set-VM -Name $HomeLabVMName -ProcessorCount "4" -AutomaticCheckpointsEnabled $false -DynamicMemory `
        -MemoryMaximumBytes 4GB # Sets up additional VM configurations
    Get-VMIntegrationService -Name "Guest Service Interface" -VMName $HomeLabVMName | `
        Enable-VMIntegrationService # Turns on VM integration service
    Set-VMFirmware -VMName $HomeLabVMName -EnableSecureBoot 1 # Turns of Secure Boot
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
    Set-VMFirmware -VMName $HomeLabVMNameAlt -EnableSecureBoot 1 # Turns of Secure Boot
    Write-Host "`nWindow will close automatically" -ForegroundColor Yellow
    Start-Sleep -Seconds "5"
}
Clear-History
##############################################################
# Nothing follows.
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

$host.ui.RawUI.WindowTitle = 'New-HomeLabVM - Create a virtual machine, FAST.'
##############################################################
# Global Variables
$VMFilesDirectory = "D:\Hyper-V Lab Files\virtual-machines\vm-files\Virtual Machines"
$ParentVHDDirectory = "D:\Hyper-V Lab Files\vhd templates"
$VHDFileDirectory = "D:\Hyper-V Lab Files\virtual-machines\vhd-files"
$ISOFileDirectory = "D:\Hyper-V Lab Files\iso-files"
$NATvSwitch = "vNAT"
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

Write-Host "Select VM creation method:" -ForegroundColor Yellow
Write-Host "[1] From template (VHD / VHDX)"
Write-Host "[2] From Image File (ISO)"
Write-Host "[3] Windows 11 VM (with TPM, Secure Boot, etc.)"

do {
    $VMOption = Read-Host "`nType 1, 2, or 3"
    if ($VMOption -notin @('1', '2', '3')) {
        Write-Host "`nInvalid selection! Please enter 1, 2, or 3." -ForegroundColor Red
    }
} while ($VMOption -notin @('1', '2', '3'))

switch ($VMOption) {
    '1' {
        Write-Host "`nNew VM will use a VHD template..." -ForegroundColor Yellow
        $ArrayIndex = 0
        $ParentVHDFile = Get-ChildItem -Path $ParentVHDDirectory | Where-Object Name -Like "*.vhdx" | `
            Select-Object Name, @{ Name = "ID" ; Expression = { $script:ArrayIndex; $script:ArrayIndex++ } }
        $ParentVHDFileIndex = $ParentVHDFile.Count - 1
        Write-Host "`nParent VHD file selection:" -ForegroundColor Green
        $ParentVHDFile | Format-Table
        while ($true) {
            $SelectArrayIndex = Read-Host "`nSelect an ID between 0 and $ParentVHDFileIndex"
            if ($SelectArrayIndex -notmatch "^\d+$" -or [int]$SelectArrayIndex -gt $ParentVHDFileIndex) {
                Write-Host "Invalid ID. Try Again" -ForegroundColor Red
                Start-Sleep 2
                Write-Host "`nParent VHD file selection:" -ForegroundColor Green
                $ParentVHDFile | Format-Table
                continue
            }
            $SelectArrayIndex = [int]$SelectArrayIndex
            Write-Host ""
            Write-Host "You selected $($ParentVHDFile.Name[$SelectArrayIndex])..." -ForegroundColor Green
            break
        }
        $inputName = Read-Host "`nEnter VM name"
        $vmName = if ($inputName.Trim()) { $inputName.Trim() } else { "VM-$(Get-Date -Format yyyyMMddTHHmmss)" }
        if (-not $inputName.Trim()) {
            Write-Host "You skipped VM name input - Your new VM will be named as $vmName..." -ForegroundColor Yellow
            Start-Sleep 2
        }
        $SelectedParentVHDFile = $ParentVHDFile.Name[$SelectArrayIndex]
        $ParentVDH = "$ParentVHDDirectory\$SelectedParentVHDFile"
        New-VHD -ParentPath $ParentVDH -Path "$VHDFileDirectory\$vmName.vhdx" -Differencing
        New-VM -Name $vmName -Path "$VMFilesDirectory\$vmName" -Generation 2 -MemoryStartupBytes 1GB `
            -SwitchName "$NATvSwitch" -VHDPath "$VHDFileDirectory\$vmName.vhdx" -BootDevice "VHD"
        Set-VM -Name $vmName -ProcessorCount 4 -AutomaticCheckpointsEnabled $false -DynamicMemory -MemoryMaximumBytes 4GB
        Get-VMIntegrationService -Name "Guest Service Interface" -VMName $vmName | Enable-VMIntegrationService
        Set-VMFirmware -VMName $vmName -EnableSecureBoot 1
        Write-Host "`nWindow will close automatically." -ForegroundColor Yellow
        Start-Sleep 5
        Clear-History
    }
    '2' {
        Write-Host "`nNew VM will be built using an ISO..." -ForegroundColor Yellow
        Start-Sleep 2
        $ArrayIndex = 0
        $ISOFile = Get-ChildItem -Path $ISOFileDirectory | Where-Object Name -Like "*.iso" | `
            Select-Object Name, @{ Name = "ID" ; Expression = { $script:ArrayIndex; $script:ArrayIndex++ } }
        $ISOFileIndex = $ISOFile.Count - 1
        Write-Host "`nISO file selection:" -ForegroundColor Green
        $ISOFile | Format-Table
        while ($true) {
            $SelectArrayIndex = Read-Host "`nSelect an ID between 0 and $ISOFileIndex"
            if ($SelectArrayIndex -notmatch "^\d+$" -or [int]$SelectArrayIndex -gt $ISOFileIndex) {
                Write-Host "Invalid ID. Try Again" -ForegroundColor Red
                Start-Sleep 2
                Write-Host "`nISO file selection:" -ForegroundColor Green
                $ISOFile | Format-Table
                continue
            }
            $SelectArrayIndex = [int]$SelectArrayIndex
            Write-Host ""
            Write-Host "You selected $($ISOFile.Name[$SelectArrayIndex])" -ForegroundColor Green
            break
        }
        Start-Sleep 1
        $VMGenOption = Read-Host "`nType Gen1 if creating a Linux VM, else type any key to continue"
        $inputName = Read-Host "`nEnter VM name"
        $vmName = if ($inputName.Trim()) { $inputName.Trim() } else { "VM-$(Get-Date -Format yyyyMMddTHHmmss)" }
        if (-not $inputName.Trim()) {
            Write-Host "You skipped VM name input - Your new VM will be named as $vmName..." -ForegroundColor Green
            Start-Sleep 2
        }
        $SelectedISOFile = $ISOFile.Name[$SelectArrayIndex]
        if ($VMGenOption -eq "Gen1") {
            Write-Host "`nGen-1 Virtual Machine will be created (no dynamic memory)" -ForegroundColor Green
            Write-Host "!--INFORMATIONAL: Gen-1 VM is ideal for Linux for compatibility" -ForegroundColor Yellow
            New-VHD -Path "$VHDFileDirectory\$vmName.vhd" -Dynamic -SizeBytes 100GB
            New-VM -Name $vmName -Path "$VMFilesDirectory\$vmName" -Generation 1 -MemoryStartupBytes 4GB `
                -SwitchName "$NATvSwitch" -VHDPath "$VHDFileDirectory\$vmName.vhd"
            Set-VM -Name $vmName -ProcessorCount 4 -AutomaticCheckpointsEnabled $false
            Add-VMDvdDrive -VMName $vmName -Path "$ISOFileDirectory\$SelectedISOFile"
            Get-VMIntegrationService -Name "Guest Service Interface" -VMName $vmName | Enable-VMIntegrationService
            Set-VMBios -VMName $vmName -StartupOrder @("CD", "IDE", "LegacyNetworkAdapter", "Floppy")
        } else {
            Write-Host "`nGen-2 Virtual Machine will be created (with dynamic memory)" -ForegroundColor Green
            New-VHD -Path "$VHDFileDirectory\$vmName.vhdx" -Dynamic -SizeBytes 100GB
            New-VM -Name $vmName -Path "$VMFilesDirectory\$vmName" -Generation 2 -MemoryStartupBytes 1GB `
                -SwitchName "$NATvSwitch" -VHDPath "$VHDFileDirectory\$vmName.vhdx"
            Set-VM -Name $vmName -ProcessorCount 4 -AutomaticCheckpointsEnabled $false -DynamicMemory -MemoryMaximumBytes 4GB
            Add-VMDvdDrive -VMName $vmName -Path "$ISOFileDirectory\$SelectedISOFile"
            Get-VMIntegrationService -Name "Guest Service Interface" -VMName $vmName | Enable-VMIntegrationService
            Set-VMFirmware -VMName $vmName -EnableSecureBoot 1
            $InspectBootOrder = Get-VMFirmware -VMName $vmName
            $HddDrive = $InspectBootOrder.BootOrder[0]
            $NetAdapter = $InspectBootOrder.BootOrder[1]
            $DvdDrive = $InspectBootOrder.BootOrder[2]
            Set-VMFirmware -VMName $vmName -BootOrder $DvdDrive, $HddDrive, $NetAdapter
        }
        Write-Host "`nWindow will close automatically." -ForegroundColor Yellow
        Start-Sleep 5
        exit
    }
    '3' {
        Write-Host "`nWindows 11 VM will be created (Gen2, Secure Boot, TPM, 4 CPUs, 4GB RAM min)" -ForegroundColor Green
        $inputName = Read-Host "`nEnter Windows 11 VM name"
        $vmName = if ($inputName.Trim()) { $inputName.Trim() } else { "Win11VM-$(Get-Date -Format yyyyMMddTHHmmss)" }
        if (-not $inputName.Trim()) {
            Write-Host "`nYou skipped VM name input - Your new VM will be named as $vmName..." -ForegroundColor Green
            Start-Sleep 2
        }
        $Win11VHDPath = "$VHDFileDirectory\$vmName.vhdx"
        $Win11VMPath = "$VMFilesDirectory\$vmName"
        $Win11ISO = Get-ChildItem -Path $ISOFileDirectory | Where-Object { $_.Name -like "*.iso" } | Select-Object -First 1
        if (-not $Win11ISO) {
            Write-Host "No ISO found in $ISOFileDirectory" -ForegroundColor Red
            exit
        }
        New-VHD -Path $Win11VHDPath -Dynamic -SizeBytes 100GB
        New-VM -Name $vmName -Path $Win11VMPath -Generation 2 -MemoryStartupBytes 4GB `
            -SwitchName "$NATvSwitch" -VHDPath $Win11VHDPath
        Set-VM -Name $vmName -ProcessorCount 4 -AutomaticCheckpointsEnabled $false -DynamicMemory `
            -MemoryMinimumBytes 4GB -MemoryMaximumBytes 8GB
        Set-VMFirmware -VMName $vmName -EnableSecureBoot On
        Set-VMKeyProtector -VMName $vmName -NewLocalKeyProtector
        Enable-VMTPM -VMName $vmName
        Add-VMDvdDrive -VMName $vmName -Path $Win11ISO.FullName
        Get-VMIntegrationService -VMName $vmName | Enable-VMIntegrationService
        Write-Host "`nWindows 11 VM created and ready for install!" -ForegroundColor Green
        Write-Host "`nWindow will close automatically." -ForegroundColor Yellow
        Start-Sleep 5
        exit
    }
    default {
        Write-Host "Invalid selection. Exiting." -ForegroundColor Red
        exit
    }
}
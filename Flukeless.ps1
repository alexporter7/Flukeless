#===============================================================================
#===                            Flukeless                                    ===
#===============================================================================
#===                            Authors                                      ===
#===                         Canyon Shapiro                                  ===
#===                          Alex Porter                                    ===
#===============================================================================

$cwd = Get-Location
$Date_Info = Get-Date -UFormat "%m_%d_%Y %H_%M_%S"; #log the date
$Log_File_Name = "$($Date_Info)_Flukeless.txt" #name of the log file
$Version = "2.4.0"

$inputXML = @"
<Window x:Class="PortCheckCS.MainWindow"
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
        xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
        xmlns:local="clr-namespace:PortCheckCS"
        mc:Ignorable="d"
        Title="Flukeless" Height="433" Width="804" MinWidth="804" MinHeight="433" MaxWidth="804" MaxHeight="433">
    <Grid>
        <Button x:Name="startButton" Content="Start" HorizontalAlignment="Left" Margin="10,10,0,0" VerticalAlignment="Top" Width="772" Height="31"/>
        <TextBox x:Name="outputTextbox" HorizontalAlignment="Left" Height="258" Margin="10,86,0,0" TextWrapping="Wrap" VerticalAlignment="Top" Width="772" />
        <ProgressBar x:Name="progBar" HorizontalAlignment="Left" Height="35" Margin="10,46,0,0" VerticalAlignment="Top" Width="772"/>
        <Button x:Name="saveButton" Content="Save Results" HorizontalAlignment="Left" Margin="10,349,0,0" VerticalAlignment="Top" Width="527" Height="37"/>
        <Button x:Name="exitButton" Content="Exit" HorizontalAlignment="Left" Margin="542,349,0,0" VerticalAlignment="Top" Width="240" Height="37"/>

    </Grid>
</Window>
"@

$inputXML = $inputXML -replace 'mc:Ignorable="d"','' -replace "x:N",'N' -replace '^<Win.*', '<Window'
[void][System.Reflection.Assembly]::LoadWithPartialName('presentationframework')
[xml]$XAML = $inputXML
#Read XAML

$reader=(New-Object System.Xml.XmlNodeReader $xaml)
try{
    $Form=[Windows.Markup.XamlReader]::Load( $reader )
}
catch{
    Write-Warning "Unable to parse XML, with error: $($Error[0])`n Ensure that there are NO SelectionChanged or TextChanged properties in your textboxes (PowerShell cannot process them)"
    throw
}

#===========================================================================
# Load XAML Objects In PowerShell
#===========================================================================

$xaml.SelectNodes("//*[@Name]") | %{"trying item $($_.Name)" | Out-Null;
    try {Set-Variable -Name "WPF$($_.Name)" -Value $Form.FindName($_.Name) -ErrorAction Stop}
    catch{throw}
    }

Function Get-FormVariables{
#if ($global:ReadmeDisplay -ne $true){Write-host "If you need to reference this display again, run Get-FormVariables" -ForegroundColor Yellow;$global:ReadmeDisplay=$true}
#write-host "Found the following interactable elements from our form" -ForegroundColor Cyan
get-variable WPF*
}

#Get-FormVariables

#===============================================================================
# Use this space to add code to the various form elements in your GUI
#===============================================================================

############################################################################
# Script: PortCheck.ps1
#
# Description: Listens for CDP (Cisco Discovery Protocol) and LLDP (Link Layer Discovery Protocol) and if found will display switch and VLAN port information
# for the selected interface
#
# Author: Dan Parr / 2016
#
# Version: 2.3
#
# Dependencies: Wireshark and TShark
#
# Updated by: Canyon Shapiro / Sept 2019
# Updated by: Alex Porter / Sept 2019
############################################################################

Function Process-CDP {

# This function pulls some info from the CDP (Cisco Discovery Protocol) packet blob to display to the user
# and returns the display string. Could be expanded to include any other details contained in the packet.

$Device = $args[0] | Select-String -Pattern "Device ID: " -Encoding Unicode
$Platform = $args[0] | Select-String -Pattern "Platform: " -Encoding Unicode
$IP = $args[0] | Select-String -Pattern "IP Address: " -Encoding Unicode
$Interface = $args[0]| Select-String -Pattern "Port ID: " -Encoding Unicode
$VLanID = $args[0]| Select-String -Pattern "Native VLAN: " -Encoding Unicode

$D = $Device[0].tostring().trim().replace("Device ID: ","Switch Name: ")
$P = $Platform[0].tostring().trim().replace("Platform: ","Switch Description: ")

# Truncate platform information if necessary
 If ($P.lenght -gt 88) {
    $P = $P.substring(0,87).trim() + " (Truncated...)"
}

$I = $IP[0].tostring().trim().replace("IP Address: ","Switch IP Address: ")
$V = $VLanID[0].tostring().trim().replace("Native VLAN: ","Current VLAN Assignment: ")
$Int = $Interface[0].tostring().trim().replace("Port Id: ","Switch Port: ")

$Response = "
######################################################
CDP Information Collected
######################################################

$D
$Int
$I
$V

$P

######################################################"

$Response
}

Function Process-LLDP {

# This function pulls some info from the LLDP packet blob to display to the user
# and returns the display string. Could be expanded to include any other details contained in the packet.

$Device = $args[0] | Select-String -Pattern "System Name: " -Encoding Unicode
$IP = $args[0] | Select-String -Pattern "Management Address: " -Encoding Unicode
$Platform = $args[0] | Select-String -Pattern "^\s*System Description" -Encoding Unicode
$Interface = $args[0]| Select-String -Pattern "Port ID: " -Encoding Unicode
$VLanID = $args[0]| Select-String -Pattern "Port VLAN Identifier: " -Encoding Unicode

$D = $Device[0].tostring().trim().replace("System Name: ","Switch Name: ")
$P = $Platform[0].tostring().trim().replace("System Description =","Switch Description:")

#Truncate platform information if necessary
If ($P.length -gt 88){
    $P = $P.substring(0,87).trim() + " (Truncated...)"
}

$V = $VLanID[0].tostring().trim().replace("Port VLAN Identifier: ","Current VLAN Assignment: ")

$I = $IP[0].tostring().trim().replace("Management Address: ","Switch IP Address: ")
$Int = $Interface[0].tostring().trim().replace("Port Id: ","Switch Port: ")

$Response = "
######################################################
LLDP Information Collected
######################################################

$D
$Int
$I
$V

$P

######################################################"

$Response

}

Function Exit($ExitCode) {

  $Form.Close()
  exit

}

Function SetProgress($progress) {

  $WPFprogBar.Value = $progress
  $Form.Dispatcher.Invoke([action]{},"Render")

}

Function OutputText($text) {

  #Write-Host $text
  if ($text.length -ne 0) {
    $WPFoutputTextbox.Text = "$($WPFoutputTextbox.Text)[*] $text`n"
    $WPFoutputTextbox.ScrollToEnd()
    $Form.Dispatcher.Invoke([action]{},"Render")
}

}

Function CheckWiresharkInstall {

  $wiresharkString = "Wireshark"
  $WiresharkDefault = (Get-ItemProperty HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | Where {$_.DisplayName -like "$wiresharkString*"}) -ne $null
  $checkWiresharkPath = Test-Path -Path "C:\Program Files\Wireshark\tshark.exe"

  If ($WiresharkDefault -eq $true -and $checkWiresharkPath -eq $true) {
      $wiresharkFound = $true

      # Allow user to change path to TShark.exe
      OutputText("Wireshark components found")

      # $checkDir = Read-Host "`nThe default directory for Wireshark is: '$command' to change this directory type 'change'; otherwise, hit enter to continue"
      #
      # If ($checkDir -eq "change") {
      #     While ($confirm -ne "y" -or "Y") {
      #         $newDir = Read-Host "Where is TShark.exe located?"
      #         $confirm = Read-Host "You have entered: '$newDir' is this correct? (y/n)"
      #     }
      #     $Command = $newDir
      # } else {
      #     Write-Host "Directory set to: '$command'"
      # }

  } else {
      $wiresharkFound = $false
  }
   SetProgress(5)

  While ($true) {
      If ($wiresharkFound -eq $false) {

          OutputText("The necessary Wireshark components were not found.")
          OutputText("Attempting to unpack them now")
          $cwd = Get-Location
          & $cwd\resources\Wireshark-win64-3.0.5.exe /S /desktopicon=no /quicklaunchicon=no
          OutputText("Installing Wireshark")
          Start-Sleep -s 4
          While ($true) {
              If (Test-Path -Path "C:\Program Files\Wireshark\tshark.exe") {
                  $wiresharkFound = $true
                  break
              }
              Start-Sleep -s 3
          }
      } else {

          OutputText("Wireshark is installed")
          break

      }
  }

    SetProgress(10)

}

Function CheckNpcapInstall {

  $NpcapString = "npcap"
  $cwd = (Get-Location)

  While ($true) {
      $NpcapInstallLocation = (Get-ItemProperty HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | Where {$_.DisplayName -like "$NpcapString*"}) -ne $null

      If (-Not $NpcapInstallLocation) {
          OutputText("The necessary Npcap components were not found")
          OutputText("Please follow the installation prompt")

          & $cwd\resources\npcap-0.9983.exe /admin_only=enforced /loopback_support=disabled /dot11_support=disabled /winpcap_mode=disabled

          Start-Sleep -s 2
          While ($true) {

              If ((Get-Process | Where-Object {$_.Name -like "npcap*"}) -eq $null) {
                OutputText("Loading Npcap Service")
                for($i = 1; $i -ne 8; $i++) {
                    #OutputText("Installing TShark Dependencies $i/")
                    SetProgress($WPFprogBar.Value + 2)
                    Start-Sleep -s 1
                }
                  break
              }
              Start-Sleep -s 1
              #Write-Host -NoNewLine "."
          }
      } else {
          OutputText("Npcap components found")
          OutputText("Npcap is installed")

          # Grab Npcap service
          $NpcapService = Get-Service -Name "npcap"

          # Check if Npcap service is running
          While ($NpcapService.Status -ne "Running" -or $null) {
              OutputText("Npcap service is not running yet.")
              Start-Sleep -s 5
              $NpcapService.Refresh()
          }

          break
      }
  }

  SetProgress(30)

}

Function MainScript {

  $Command = "C:\Program Files\Wireshark\tshark.exe"
  $InterfaceOptions = @('-D')

  # Allow user to change path to TShark.exe

  #$checkDir = Read-Host "`nThe script will look for TShark.exe by default in: '$command' to change this directory type 'change'; otherwise, hit enter to continue"
  # $checkDir = ""
  # If ($checkDir -eq "change") {
  #     While ($confirm -ne "y" -or "Y") {
  #         $newDir = Read-Host "Where is TShark.exe located?"
  #         $confirm = Read-Host "You have entered: '$newDir' is this correct? (y/n)"
  #     } else {
  #         $Command = $newDir
  #         Write-Host "Directory set to: '$command'"
  #     }
  # }

  OutputText("List of Network Adapters:")
  # Execute TShark.exe and pass an array of arguments
  # $adapters = & $Command $InterfaceOptions
  # OutputText($adapters)
& $Command $InterfaceOptions | % {OutputText($_)}
#===============================================================================
# Automatically pick correct network adapter
#===============================================================================
$outputArray = @()
$sanatizedOutputArray = @()
$singleChoice = $false
& $Command $InterfaceOptions | % {$outputArray += $_} #get array of network adapters

$count = 0
foreach($item in $outputArray) {

  $count++
  if ($item -like "*ethern*") {
    $sanatizedOutputArray += $count
  }

}

if ($sanatizedOutputArray.count -eq 1) {
  $singleChoice = $true
}

#===============================================================================

  SetProgress(55)

  # Have user select the interface to be monitored
  OutputText("TShark has returned a list of network interfaces it can see")

  if ($singleChoice -eq $true) {
    OutputText("Only one choice contains an ethernet adapter")
    OutputText("Ethernet adapter has been automatically selected")
    $IntID = $sanatizedOutputArray[0]
  } else {
      $IntID = Read-Host -Prompt "To continue, enter the number of the interface you would like to monitor (1, 2, 3...)"
  }

  SetProgress(70)
  ##########################################################################
  # TShark Command Line Options
  ##########################################################################

  # Define a capture filter to capture only CDP or LLDP packets
  $CaptureFilter = "(ether proto 0x88cc) or ( ether host 01:00:0c:cc:cc:cc and ether[16:4] = 0x0300000C and ether[20:2] == 0x2000)"

  # Define how long TShark will wait in seconds for a CDP or LLDP packet
  $Duration = "30"
  OutputText("Duration is set to $Duration seconds")

  # Store arguments for TShark execution in options variable to be called below
  $Options= @('-i',"$IntID",'-f',$CaptureFilter,'-a',"duration:$Duration",'-c','1','-V','-Q')

  ###########################################################################
  SetProgress(80)
  Clear
  OutputText("Listening for CDP or LLDP advertisements on the wire, this may take up to $Duration seconds...")
  # Execute TShark Command and pass an array of arguments. Use STDOut to populate variable
  $CDP = & $Command $Options

  # Create directory if it doesn't exist and output text file for analysis
  If (!(Test-Path -Path "$cwd\PortCheckLogs")) {
      New-Item -ItemType directory -Path $cwd\PortCheckLogs | Out-Null
      OutputText("Creating PortCheckLogs Directory")
  } Else {
    OutputText("PortCheckLogs Directory FOUND")
  }

  If (!(Test-Path -Path "$cwd\results")) {
      New-Item -ItemType directory -Path $cwd\results | Out-Null
  } Else {
    OutputText("Results Directory FOUND")
  }

  If (!(Test-Path -Path "$cwd\resources")) {
      New-Item -ItemType directory -Path $cwd\results | Out-Null
  } Else {
        OutputText("Resources Directory FOUND")
  }

  # Define file location and naming convention
  $fileOut = "$cwd\PortCheckLogs\PortCheck_" + (Get-Date).ToString("yyyy-MM-ddTHH-mm-ss").Replace(":","-") + ".txt"

  # Output to timestamped file
  $CDP > $fileOut
  OutputText("The raw packet capture has been saved to the PortCheckLogs directory")


  # Determine the type of data received and act on it
  If ((Select-String -Pattern "Cisco Discovery Protocol" -InputObject $CDP).length -gt 0) {

      OutputText("Received CDP Annoucement:")

      # Store results and display
      $CollectedInfo = Process-CDP $CDP
      OutputText($CollectedInfo)

      # Copy output to clipboard
      Set-Clipboard $CollectedInfo
      OutputText("Results copied to clipboard")

  } ElseIf ((Select-string -Pattern "Link Layer Discovery Protocol" -InputObject $CDP).length -gt 0) {

      OutputText("Found LLDP Annoucement:")

      #Store results and display
      $CollectedInfo = Process-LLDP $CDP
      OutputText($CollectedInfo)

      # Copy output to clipboard
      Set-Clipboard $CollectedInfo
      OutputText("Results copied to clipboard")


  } Else {
      OutputText("No CDP or LLDP information found")
      OutputText("Port is either not connected or dead")
  }

  $uninstallResponse = Read-Host "Do you want to uninstall Wireshark and Npcap? (Y/n)"

  If ($uninstallResponse -eq "N" -or $uninstallResponse -eq "n") {
      OutputText("Skipping uninstall")
  } else {
      OutputText("Cleaning up...")

      # Uninstall Npcap
      # Write-Host "Removing Npcap"
      OutputText("Starting removal of Npcap")
      SetProgress(85)
      & "C:\Program Files\Npcap\Uninstall.exe" /S
      SetProgress(90)
      OutputText("Uninstall of Npcap finished")
      # Uninstall Wireshark
      # Write-Host "Removing Wireshark"
      OutputText("Starting removal of WireShark")
      & "C:\Program Files\Wireshark\uninstall.exe" /S
      OutputText("Uninstall of WireShark finished")
      SetProgress(95)

  }

}

Function SaveResults {

  if ($WPFprogBar.Value -ne 100) {
    OutputText("Port scan is either not complete or has not been started")
  } else {
    $Text = $WPFoutputTextbox.Text
    $Text = $Text.replace("[*] ", "")
    $Text | Out-File "results\$Log_File_Name"
  }

  OutputText("Results have been saved to $Log_File_Name")

}

Function StartScript {

  OutputText($Version)
  CheckWiresharkInstall
  CheckNpcapInstall
  MainScript

  SetProgress(100)

}

#===========================================================================
# Create those button event listeners
#===========================================================================

$WPFstartButton.Add_Click({ StartScript })
$WPFexitButton.Add_Click({ Exit(0) })
$WPFsaveButton.Add_Click({ SaveResults })

#===========================================================================
# Shows the form
#===========================================================================
#write-host "To show the form, run the following" -ForegroundColor Cyan
#'$Form.ShowDialog() | out-null'
$Form.ShowDialog() | Out-Null

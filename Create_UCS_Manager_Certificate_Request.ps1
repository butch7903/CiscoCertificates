<#
    .NOTES
	===========================================================================
	Created by:		Russell Hamker
	Date:			August 6, 2021
	Version:		1.0
	Twitter:		@butch7903
	GitHub:			https://github.com/butch7903
	===========================================================================

	.SYNOPSIS
		This script will automate the creation of the a Cisco UCS Manager
		CSR Request.

	.DESCRIPTION
		Use this script to connect to a freshly IPd UCS FI Cluster create 
		a Certificate Request.
		
	.NOTES
		This script requires a Cisco.UCSManager minimum version 3.0.1.2 or greater. 

	.TROUBLESHOOTING
		
#>

##Variables to Fill Out
$UCSMVIPFQDN = "ham-ucs-1.hamker.local" #FQDN name for your UCSM VIP #Example ham-ucs-1.hamker.local
$UCSMVIPIP = "192.168.1.100" 			#Example 192.168.1.100
$UCSMAIP = "192.168.1.101" 				#Example 10.27.1.12
$UCSMBIP = "192.168.1.102" 				#Example 10.27.1.12
$EMAIL = "stbu-platops@cisco.com"		#Example me@me.com
$COUNTRY = "US"							#Country
$LOCALITY = "San Jose"					#City
$ORGNAME = "Cisco Systems" 				#Company
$ORGUNIT = "CES Platops"				#Department
$STATE = "CA"							#State

##Check if Modules are installed, if so load them, else install them
if (Get-InstalledModule -Name Cisco.UCSManager -MinimumVersion 3.0.1.2) {
	Write-Host "-----------------------------------------------------------------------------------------------------------------------"
	Write-Host "PowerShell Module Cisco.UCSManager required minimum version was found previously installed"
	Write-Host "Importing PowerShell Module Cisco.UCSManager"
	Import-Module -Name Cisco.UCSManager
	Write-Host "Importing PowerShell Module VMware PowerCLI Completed"
	Write-Host "-----------------------------------------------------------------------------------------------------------------------"
	#CLEAR
} else {
	Write-Host "-----------------------------------------------------------------------------------------------------------------------"
	Write-Host "PowerShell Module Cisco.UCSManager does not exist"
	Write-Host "Setting TLS Security Protocol to TLS1.2, this is needed for Proxy Access"
	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 
	Write-Host "Setting Micrsoft PowerShell Gallery as a Trusted Repository"
	Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
	Write-Host "Verifying that NuGet is at minimum version 2.8.5.201 to proceed with update"
	Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false
	Write-Host "Uninstalling any older versions of the PowerShellGet Module"
	Get-Module PowerShellGet | Uninstall-Module -Force
	Write-Host "Installing PowerShellGet Module"
	Install-Module -Name PowerShellGet -Scope AllUsers -Force
	Write-Host "Setting Execution Policy to RemoteSigned"
	Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force
	Write-Host "Uninstalling any older versions of the Cisco.UCSManager Module"
	Get-Module Cisco.UCSManager | Uninstall-Module -Force
	Write-Host "Installing Newest version of Cisco.UCSManager PowerShell Module"
	Install-Module -Name Cisco.UCSManager -MinimumVersion 3.0.1.2 -Scope AllUsers -Force -AcceptLicense
	Write-Host "Importing PowerShell Module Cisco.UCSManager"
	Import-Module -Name Cisco.UCSManager
	Write-Host "PowerShell Module Cisco.UCSManager Loaded"
	Write-Host "-----------------------------------------------------------------------------------------------------------------------"
	#Clear
}

##Document Start Time
$STARTTIME = Get-Date -format "MMM-dd-yyyy HH-mm-ss"
$STARTTIMESW = [Diagnostics.Stopwatch]::StartNew()
$STARTDATE = Get-Date -format "MMM-dd-yyyy_HH-mm"

##Get Current Path
$pwd = pwd

##Setting CSV File Location 
$CSVFILELOCATION = $pwd.path

##Get Date Info for Logging
$LOGDATE = Get-Date -format "MMM-dd-yyyy_HH-mm"
##Specify Log File Info
$LOGFILENAME = "Log_" + $LOGDATE + ".txt"
#Create Log Folder
$LogFolder = $pwd.path+"\Log"
If (Test-Path $LogFolder){
	Write-Host "Log Directory Created. Continuing..."
}Else{
	New-Item $LogFolder -type directory
}
#Specify Log File
$LOGFILE = $pwd.path+"\Log\"+$LOGFILENAME

##Starting Logging
Start-Transcript -path $LOGFILE -Append
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Script Logging Started"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

#Specify UCS Creds
$MyCredential = Get-Credential -Message "Please Provide the admin password for $UCSMVIPFQDN"

CLS
##Disconnect from any open UCS Sessions
#This can cause problems if there are any
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Disconnecting from any Open UCS Sessions"
TRY
{Disconnect-Ucs}
CATCH
{Write-Host "No Open UCS Sessions found"}
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Connect to UCS Server VIP
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Setting TLS 1.2"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Write-Host "Connecting to UCS $UCSMVIPFQDN"
$UCSMANAGER = Connect-Ucs $UCSMVIPFQDN -Credential $MyCredential
Write-Output $UCSMANAGER
Write-Host "Connected to UCS VIP $UCSMVIPFQDN"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Create new UCS Key Ring and Generate CSR
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Creating new UCS Key Ring and Generate CSR"
Start-UcsTransaction
$mo = Add-UcsKeyRing -ModifyPresent  -Cert "" -Descr "" -Modulus "mod2048" -Name "internal_ca" -PolicyOwner "local" -Regen "no" -Tp ""
$mo_1 = $mo | Add-UcsCertRequest -ModifyPresent -Country $COUNTRY -Dns $UCSMVIPFQDN -Email $EMAIL -Ip $UCSMVIPIP -IpA $UCSMAIP -IpB $UCSMBIP -Ipv6 "::" -Ipv6A "::" -Ipv6B "::" -Locality $LOCALITY -OrgName $ORGNAME -OrgUnitName $ORGNAME -Pwd "" -State $STATE -SubjName $UCSMVIPFQDN
Complete-UcsTransaction
Write-Host "Completed creating new UCS Key Ring and Generate CSR"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Export New UCS CSR to file for use with a Certificate Authority
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Exporting CSR to File for use with a Certificate Authority"
$REQ = (Get-UcsKeyRing -Name "internal_ca"| Get-UcsCertRequest).Req
$REQ | Out-File -Path ./"$UCSMVIPFQDN.csr"
Write-Host "Completed exporting CSR to File for use with a Certificate Authority"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Disconnect from any open UCS Sessions
#This can cause problems if there are any
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Disconnecting from UCS $UCSVIP"
TRY
{Disconnect-Ucs}
CATCH
{Write-Host "No Open UCS Sessions found"}
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Document Script Total Run time
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
$STARTTIMESW.STOP()
Write-Host "Total Script Time:"$STARTTIMESW.Elapsed.TotalMinutes"Minutes"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Stopping Logging
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "All Processes Completed"
Write-Host "Stopping Transcript"
Stop-Transcript
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Script Completed
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Script Completed for $VCSA"
Write-Host "Press Enter to close this PowerShell Script"
PAUSE
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
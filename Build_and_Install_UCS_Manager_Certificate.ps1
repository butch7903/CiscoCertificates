<#
    .NOTES
	===========================================================================
	Created by:		Russell Hamker
	Date:			August 13, 2021
	Version:		1.5
	Twitter:		@butch7903
	GitHub:			https://github.com/butch7903
	===========================================================================

	.SYNOPSIS
		This script will automate the import of a UCS Certificate.

	.DESCRIPTION
		Use this script to connect to a freshly IPd UCS FI Cluster to import a
		UCS Certificate and then optionally flip the UCS Environment to use it.
		
	.NOTES
		This script requires a Cisco.UCSManager minimum version 3.0.1.2 or greater. 

	.TROUBLESHOOTING
		
#>

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

#Location Of Open SSL Application
$OpenSSLLocation = "C:\Program Files\OpenSSL-Win64\bin" #x64 Version

##Select UCS To Install Certificate to
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
CLS
Write-Host "Select UCS Manager to install certificate to"
$ExportFolder = $pwd.path+"\Export\"
$ARRAY = @()
$UCS_LIST = (Get-Childitem $ExportFolder -Directory).Name
$ARRAY += $UCS_LIST
$countCL = 0   
Write-Host " " 
Write-Host "UCS Manager List: " 
Write-Host " " 
foreach($oC in $ARRAY)
{   
	Write-Output "[$countCL] $oc" 
	$countCL = $countCL+1  
}
Write-Host " "   
$choice = Read-Host "Which UCS Manager do you wish to install a certificate?"
$UCSMVIPFQDN = $ARRAY[$choice]
$WORKINGDIR = $ExportFolder+$UCSMVIPFQDN
Write-Host "You have selected UCS Manager $UCSMVIPFQDN in Directory
$WORKINGDIR"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Get Date Info for Logging
$LOGDATE = Get-Date -format "MMM-dd-yyyy_HH-mm"
##Specify Log File Info
$LOGFILENAME = "Log_$UCSMVIPFQDN_" + $LOGDATE + ".txt"
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

###Test if OpenSSL is Installed
##Specify OpenSSL version. If you have a 64-bit OS, use the x64 version. If you have a 32-bit OS, use the x86 version
#$OPENSSL = get-item "C:\Program Files (x86)\OpenSSL-Win32\bin\OpenSSL.exe" -ErrorAction SilentlyContinue ##x86 version
$OpenSSLLocation = "C:\Program Files\OpenSSL-Win64\bin" #x64 Version
$OPENSSL = get-item "$OpenSSLLocation\OpenSSL.exe" -ErrorAction SilentlyContinue ##x64 version 
IF(!$OPENSSL)
{
	Write-Warning "OpenSSL is not installed"
	Write-Warning "Please download and install OpenSSL"
	Write-Warning "Download similar to version Win64 OpenSSL v1.1.1b Light"
	Write-Warning "https://slproweb.com/products/Win32OpenSSL.html"
	Write-Warning "Example downlod would be https://slproweb.com/download/Win64OpenSSL_Light-1_1_1b.msi"
	Pause
	EXIT
}else{
	Write-Host "Verified: OpenSSL has been properly installed" -ForegroundColor Green
}

##Verify if Certificate Zip Bundle Exists
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Verifying that Certificate Zip Bundle Exists and Expanding it"
$ZIP = (get-childitem -File *.zip -Path $WORKINGDIR)
$CERTZIPPATH = $ZIP.FullName
$CERTZIPPATHGET = Get-Item $CERTZIPPATH -ErrorAction SilentlyContinue
If(!$CERTZIPPATHGET)
{
	Write-Error "Certificate Zip file does not Exist!!!"
	Write-Host "Exiting"
	Pause
	Exit
}
If($CERTZIPPATHGET)
{
	Write-Host "Certificate Zip file found. Expanding..."
	Expand-Archive -LiteralPath $CERTZIPPATH -DestinationPath $WORKINGDIR -ErrorAction SilentlyContinue
}
Write-Host "Completed verifying that Certificate Zip Bundle Exists and Expanding it"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

##Convert Files to proper PEM Formatting
###Verify that OpenSSL is installed
IF($OPENSSL)
{
	$CERTCER = $WORKINGDIR+"\"+$UCSMVIPFQDN+".cer"
	$CERTPEM = $WORKINGDIR+"\"+$UCSMVIPFQDN+".pem"
	$CERTPEMCHAIN = $WORKINGDIR+"\"+$UCSMVIPFQDN+"-sslCertificateChain.pem"
	$CERTPEMCHAINGET = Get-Item $CERTPEMCHAIN -ErrorAction SilentlyContinue
	$CERTPATHGET = Get-Item $CERTCER -ErrorAction SilentlyContinue
	If(!$CERTPATHGET)
	{
		Write-Error "Certificate file does not Exist!!!"
		Write-Host "Exiting"
		Pause
		Exit
	}
	If(!$CERTPEMCHAINGET)
	{
		Write-Host "Certificate file not yet built, building..." -ForegroundColor Green
		If($CERTPATHGET)
		{
			
			#UCS Cert found, convert to PEM format
			Write-Host "-----------------------------------------------------------------------------------------------------------------------"
			Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
			Write-Host "Certificate file exist. Converting all CER files to PEM Format"
			$CERLIST = (get-childitem -File *.cer -Path $WORKINGDIR)
			ForEach($CER in $CERLIST)
			{
				$CERFILEPATH = $CER.FullName
				$PEMFILEPATH = $WORKINGDIR+"\"+$CER.BaseName+".pem"
				CD $OpenSSLLocation
				.\openssl x509 -in $CERFILEPATH -outform PEM -out $PEMFILEPATH
			}
			Write-Host "Completed converting all CER files to PEM Format"
			Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
			Write-Host "-----------------------------------------------------------------------------------------------------------------------"
			
			<#
			##Copy cert pem to start SSL Certificate Chain
			Write-Host "-----------------------------------------------------------------------------------------------------------------------"
			Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
			Write-Host "Copying $UCSMVIPFQDN.pem to $UCSMVIPFQDN-sslCertificateChain.pem"
			cd $WORKINGDIR
			#Copy-Item $CERTPEM -Destination $CERTPEMCHAIN
			Write-Host "Completed copying $UCSMVIPFQDN.pem to $UCSMVIPFQDN-sslCertificateChain.pem"
			Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
			Write-Host "-----------------------------------------------------------------------------------------------------------------------"
			#>
			
			##Get Cert info to build Certificate Chain
			Write-Host "-----------------------------------------------------------------------------------------------------------------------"
			Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
			Write-Host "Getting Certificate Chain Info"
			##Get Cert info to build cert chain
			cd $WORKINGDIR
			$CERTINFO = Get-PfxCertificate $CERTCER | select * ##not working yet
			$ISSUER = ([String]$CERTINFO.Issuer.split(",")[0]).TrimStart("CN=")
			$PEMFILELIST = (get-childitem -File *.pem -Path $WORKINGDIR) #| where {$_.FullName -ne $CERTPEM}
			$PEMLIST = @()
			ForEach($PEMFILE in $PEMFILELIST)
			{
				$TEMPARRAY = ""| Select Name,BaseName,FullName,Issuer,Subject,Contents
				$TEMPARRAY.Name = $PEMFILE.Name
				$TEMPARRAY.BaseName = $PEMFILE.BaseName
				$TEMPARRAY.FullName = $PEMFILE.FullName
				$TEMPINFO = Get-PfxCertificate ($PEMFILE.FullName) | select *
				$TEMPISSUER = ([String]$TEMPINFO.Issuer.split(",")[0]).TrimStart("CN=")
				$TEMPARRAY.Issuer = $TEMPISSUER
				$TEMPSUBJECT = ([String]$TEMPINFO.Subject.split(",")[0]).TrimStart("CN=")
				$TEMPARRAY.Subject = $TEMPSUBJECT
				$TEMPARRAY.Contents = Get-Content ($PEMFILE.FullName)
				$PEMLIST += $TEMPARRAY
			}
			Write-Host "Completed getting Certificate Chain Info"
			Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
			Write-Host "-----------------------------------------------------------------------------------------------------------------------"
			
			##Build Certificate Chain
			Write-Host "-----------------------------------------------------------------------------------------------------------------------"
			Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
			Write-Host "Building Certificate Chain in proper order"
			$PEMCHAIN = @()
			$PEMPOSTLIST = $PEMLIST
			$FIRSTPEM = $PEMPOSTLIST | Where {$_.BaseName -eq $UCSMVIPFQDN}
			$PEMCHAIN = $FIRSTPEM.Contents
			#Remove First PEM From List
			$PEMPOSTLIST = $PEMPOSTLIST | Where {$_.BaseName -ne $UCSMVIPFQDN}
			#nextpem
			$NEXTPEM = $FIRSTPEM
			Do{
				If($PEMPOSTLIST | Where {$_.BaseName -eq $NEXTPEM.Issuer})
				{
					$NEXTPEM = $PEMPOSTLIST | Where {$_.BaseName -eq $NEXTPEM.Issuer}
					$PEMCHAIN = $PEMCHAIN + ($NEXTPEM.Contents)
					$PEMPOSTLIST = $PEMPOSTLIST | Where {$_.BaseName -ne $NEXTPEM.BaseName}
				}Else{
					Write-Error "Next Certificate in Certificate Chain DOES NOT EXIST!"
					Write-Host "Copy CER files for Certificate Chain to the below directory and Re-Run script"
					Write-Host "Directory: $WORKINGDIR"
					PAUSE
					EXIT
				}
			}Until($PEMPOSTLIST.Count -eq 0)
			Write-Host "Chain Completed, outputting to file.."
			$PEMCHAIN | Set-Content $CERTPEMCHAIN
			Start-Sleep -Seconds 3
			$PEMCHAINIMPORT = Get-Content $CERTPEMCHAIN | Out-String
			$PEMCHAINIMPORT
			Write-Host "Completed building Certificate Chain in proper order"  -ForegroundColor Green
			Write-Host "Certificate Chain Name:
			$CERTPEMCHAIN" -ForegroundColor Green
			Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
			Write-Host "-----------------------------------------------------------------------------------------------------------------------"
		}
	}Else{
		Write-Host "Certificate Chain Already Exists/Built..."  -ForegroundColor Green
		Write-Host "Certificate Chain Name:
		$CERTPEMCHAIN" -ForegroundColor Green
		$PEMCHAINIMPORT = Get-Content $CERTPEMCHAIN | Out-String
		Write-Output $PEMCHAINIMPORT
	}
}


$REPLY = Read-Host -Prompt "Do you wish to install Certificate Chain on UCS $UCSVIPFQDN? (y/n)"
If($REPLY -match "[yY]")
{
##Specify UCS Creds
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

##Install Certficate to KeyRing
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Setting Certificate in KeyRing"
$KEYRINGNAME = "internal_ca"
$TRUSTPOINT = "intermediate"
#$STRPEMCHAIN = [STRING]$PEMCHAIN
$KEYRING = Get-UcsKeyRing $KEYRINGNAME | Set-UcsKeyRing -Tp $TrustPoint -Force -Cert $PEMCHAINIMPORT
Write-Host "Completed setting Certificate in KeyRing"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"

$REPLY = Read-Host -Prompt "Do you wish to Activate the $KEYRING Certificate on $UCSVIPFQDN? (y/n)"
If($REPLY -match "[yY]")
{
#Set HTTPS to use new Certificate
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "Activating KeyRing $KEYRING on $UCSVIPFQDN and setting TLS 1.2 only"
Get-UcsHttps | Set-UcsHttps -KeyRing $KEYRINGNAME -AdminState enabled -AllowedSSLProtocols "tlsv1_2" -Force
Write-Host "Completed Activating KeyRing $KEYRING on $UCSVIPFQDN"
Write-Host (Get-Date -format "MMM-dd-yyyy_HH-mm-ss")
Write-Host "-----------------------------------------------------------------------------------------------------------------------"
}
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
}

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
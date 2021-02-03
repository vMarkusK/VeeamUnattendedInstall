# Requires PowerShell 5.1

#region: Variables
$source = "E:"
$licensefile = "C:\_install\veeam.lic"
$username = "svc_veeam"
$fulluser = $env:COMPUTERNAME+ "\" + $username
$password = "Password!"
$SQLusername = "svc_sql"
$SQLfulluser = $env:COMPUTERNAME+ "\" + $username
$SQLpassword = "Password!"
$SQLsapassword = "Password!"
#$CatalogPath = "D:\VbrCatalog"
#$vPowerPath = "D:\vPowerNfs"
#endregion

#region: logdir
$logdir = "C:\logdir"
$trash = New-Item -ItemType Directory -path $logdir  -ErrorAction SilentlyContinue
#endregion

#region: Firewall Mangement
Set-NetFirewallProfile -Name Domain,Public,Private -Enabled True -Confirm:$false
New-NetFirewallRule -DisplayName "VeeamONE_ReporterConsole" -Direction Inbound -LocalPort 1239 -Protocol TCP -Action Allow -Confirm:$false
New-NetFirewallRule -DisplayName "VeeamONE_BusinessView" -Direction Inbound -LocalPort 1340 -Protocol TCP -Action Allow -Confirm:$false
New-NetFirewallRule -DisplayName "VeeamONE_Agent" -Direction Inbound -LocalPort 2805 -Protocol TCP -Action Allow -Confirm:$false
New-NetFirewallRule -DisplayName "VeeamONE_ServerSMB" -Direction Inbound -LocalPort 445 -Protocol TCP -Action Allow -Confirm:$false
#endregion

#region: create local admin for Veeam One Service
Write-Host "Creating local user '$fulluser' with password '$password' ..." -ForegroundColor Yellow
$trash = New-LocalUser -Name $username -Password ($password | ConvertTo-SecureString -AsPlainText -Force) -Description "Service Account for Veeam" -AccountNeverExpires -ErrorAction Stop
Add-LocalGroupMember -Group "Administrators" -Member $username -ErrorAction Stop
#endregion

#region: create local user for SQL Servcie
Write-Host "Creating local user '$SQLfulluser' with password '$SQLpassword' ..." -ForegroundColor Yellow
$trash = New-LocalUser -Name $SQLusername -Password ($SQLpassword | ConvertTo-SecureString -AsPlainText -Force) -Description "Service Account for SQL" -AccountNeverExpires -ErrorAction Stop
Add-LocalGroupMember -Group "Users" -Member $SQLusername -ErrorAction Stop
#endregion


#region: Installation
#  Info: https://helpcenter.veeam.com/docs/one/deployment/silent_mode_syntax.html?ver=100

## Global Prerequirements
Write-Host "Installing Global Prerequirements ..." -ForegroundColor Yellow
### 2012 System CLR Types
Write-Host "    Installing 2012 System CLR Types ..." -ForegroundColor Yellow
$MSIArguments = @(
    "/i"
    "$source\Redistr\x64\SQLSysClrTypes.msi"
    "/qn"
    "/norestart"
    "/L*v"
    "$logdir\01_CLR.txt"
)
Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

if (Select-String -path "$logdir\01_CLR.txt" -pattern "Installation success or error status: 0.") {
    Write-Host "    Setup OK" -ForegroundColor Green
    }
    else {
        throw "Setup Failed"
        }

### 2012 Shared management objects
Write-Host "    Installing 2012 Shared management objects ..." -ForegroundColor Yellow
$MSIArguments = @(
    "/i"
    "$source\Redistr\x64\SharedManagementObjects.msi"
    "/qn"
    "/norestart"
    "/L*v"
    "$logdir\02_Shared.txt"
)
Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

if (Select-String -path "$logdir\02_Shared.txt" -pattern "Installation success or error status: 0.") {
    Write-Host "    Setup OK" -ForegroundColor Green
    }
    else {
        throw "Setup Failed"
        }

### XML Parser
Write-Host "    Installing XML Parser..." -ForegroundColor Yellow
$MSIArguments = @(
    "/i"
    "$source\Redistr\x64\msxml6_x64.msi"
    "/qn"
    "/norestart"
    "/L*v"
    "$logdir\03_xml.txt"
)
Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

if (Select-String -path "$logdir\03_xml.txt" -pattern "Installation success or error status: 0.") {
    Write-Host "    Setup OK" -ForegroundColor Green
    }
    else {
        throw "Setup Failed"
        }

### SQL Native Client
Write-Host "    Installing SQL Native Client..." -ForegroundColor Yellow
$MSIArguments = @(
    "/i"
    "$source\Redistr\x64\sqlncli.msi"
    "/qn"
    "/norestart"
    "/L*v"
    "$logdir\04_sqlncli.txt"
    "IACCEPTSQLNCLILICENSETERMS=YES"
)
Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

if (Select-String -path "$logdir\04_sqlncli.txt" -pattern "Installation success or error status: 0.") {
    Write-Host "    Setup OK" -ForegroundColor Green
    }
    else {
        throw "Setup Failed"
        }

### ReportViewer
Write-Host "    Installing ReportViewer..." -ForegroundColor Yellow
$MSIArguments = @(
    "/i"
    "$source\Redistr\ReportViewer.msi"
    "/qn"
    "/norestart"
    "/L*v"
    "$logdir\05_ReportViewer.txt"
)
Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

if (Select-String -path "$logdir\05_ReportViewer.txt" -pattern "Installation success or error status: 0.") {
    Write-Host "    Setup OK" -ForegroundColor Green
    }
    else {
        throw "Setup Failed"
        }

### IIS
Install-WindowsFeature -Name Web-Server -IncludeAllSubFeature –IncludeManagementTools -Connfirm:$false -LogPath "$logdir\06_IIS.txt"

### SQL Express
### Info: https://msdn.microsoft.com/en-us/library/ms144259.aspx
Write-Host "    Installing SQL 2016 Express ..." -ForegroundColor Yellow
$Arguments = "/HIDECONSOLE /Q /IACCEPTSQLSERVERLICENSETERMS /ACTION=install /FEATURES=SQL /INSTANCENAME=VEEAMSQL2016 /SQLSVCACCOUNT=`"$SQLfulluser`" /SQLSVCPASSWORD=`"$SQLpassword`" /SECURITYMODE=SQL /SAPWD=`"$SQLsapassword`" /ADDCURRENTUSERASSQLADMIN /TCPENABLED=1 /NPENABLED=1 /UpdateEnabled=0"
Start-Process "$source\\Redistr\x64\SqlExpress\2016SP2\SQLEXPR_x64_ENU.exe" -ArgumentList $Arguments -Wait -NoNewWindow

## Install Veeam ONE without license file
Write-Host "Installing Veeam ONE without license file ..." -ForegroundColor Yellow
### Veeam ONE Monitor Server
Write-Host "    Installing Veeam ONE Monitor Server ..." -ForegroundColor Yellow
$MSIArguments = @(
    "/i"
    "$source\Monitor\\VeeamONE.Monitor.Server.x64.msi"
    "/qn"
    "/L*v"
    "$logdir\07_MonitorServer.txt"
    "ACCEPT_THIRDPARTY_LICENSES=1"
    "ACCEPT_EULA=1"
    "VM_MN_SERVICEACCOUNT=$username"
    "VM_MN_SERVICEPASSWORD=$password"
    "VM_MN_SQL_SERVER=$env:COMPUTERNAME\VEEAMSQL2016"
    "VM_MN_SQL_AUTHENTICATION=1"
    "VM_MN_SQL_USER=sa"
    "VM_MN_SQL_PASSWORD=$SQLsapassword"
    "VM_BACKUP_ADD_LATER=1"
    "VM_VC_SELECTED_TYPE=2"

)
Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

if (Select-String -path "$logdir\07_MonitorServer.txt" -pattern "Installation success or error status: 0.") {
    Write-Host "    Setup OK" -ForegroundColor Green
    }
    else {
        throw "Setup Failed"
        }


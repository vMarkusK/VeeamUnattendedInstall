<#
    .DESCRIPTION
    Installing Veeam ONE (VeeamONE_10.0.0.750_20200415) in Unattended Mode

    .NOTES
    File Name  : VeeamONEv10 Silent.ps1
    Author     : Markus Kraus (@vMarkusK)
    Version    : 0.3
    State      : Dev

    .LINK
    https://mycloudrevolution.com/

#>

#region: functions
function CheckLatestLog {

    if (Select-String -path "$logdir\$logfile" -pattern "Installation success or error status: 0.") {
        Write-Host "    Setup OK" -ForegroundColor Green
        }
        else {
            throw "Setup Failed"
            }
    
}
#endregion

#region: Variables
$source = "E:"
$licensefile = "C:\_install\veeam.lic"
$username = "svc_veeam"
$fulluser = $env:COMPUTERNAME+ "\" + $username
$password = "Password!"
$SQLinstance = "VEEAMSQL2016"
$SQLusername = "svc_sql"
$SQLfulluser = $env:COMPUTERNAME+ "\" + $username
$SQLpassword = "Password!"
$SQLsapassword = "Password!"
##endregion

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
$logfile = "01_CLR.txt"
$MSIArguments = @(
    "/i"
    "$source\Redistr\x64\SQLSysClrTypes.msi"
    "/qn"
    "/norestart"
    "/L*v"
    "$logdir\$logfile"
)
Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

CheckLatestLog

### 2012 Shared management objects
Write-Host "    Installing 2012 Shared management objects ..." -ForegroundColor Yellow
$logfile = "02_Shared.txt"
$MSIArguments = @(
    "/i"
    "$source\Redistr\x64\SharedManagementObjects.msi"
    "/qn"
    "/norestart"
    "/L*v"
    "$logdir\$logfile"
)
Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

CheckLatestLog

### XML Parser
Write-Host "    Installing XML Parser..." -ForegroundColor Yellow
$logfile = "03_xml.txt"
$MSIArguments = @(
    "/i"
    "$source\Redistr\x64\msxml6_x64.msi"
    "/qn"
    "/norestart"
    "/L*v"
    "$logdir\$logfile"
)
Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

CheckLatestLog

### SQL Native Client
Write-Host "    Installing SQL Native Client..." -ForegroundColor Yellow
$logfile = "04_sqlncli.txt"
$MSIArguments = @(
    "/i"
    "$source\Redistr\x64\sqlncli.msi"
    "/qn"
    "/norestart"
    "/L*v"
    "$logdir\$logfile"
    "IACCEPTSQLNCLILICENSETERMS=YES"
)
Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

CheckLatestLog

### ReportViewer
Write-Host "    Installing ReportViewer..." -ForegroundColor Yellow
$logfile = "05_ReportViewer.txt"
$MSIArguments = @(
    "/i"
    "$source\Redistr\ReportViewer.msi"
    "/qn"
    "/norestart"
    "/L*v"
    "$logdir\$logfile"
)
Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

CheckLatestLog

### IIS
$logfile = "06_IIS.txt"
Install-WindowsFeature -Name Web-Server -IncludeAllSubFeature –IncludeManagementTools -Confirm:$false -LogPath "$logdir\$logfile"

### SQL Express
### Info: https://msdn.microsoft.com/en-us/library/ms144259.aspx
Write-Host "    Installing SQL 2016 Express ..." -ForegroundColor Yellow
$Arguments = "/HIDECONSOLE /Q /IACCEPTSQLSERVERLICENSETERMS /ACTION=install /FEATURES=SQL /INSTANCENAME=`"$SQLinstance`" /SQLSVCACCOUNT=`"$SQLfulluser`" /SQLSVCPASSWORD=`"$SQLpassword`" /SECURITYMODE=SQL /SAPWD=`"$SQLsapassword`" /ADDCURRENTUSERASSQLADMIN /TCPENABLED=1 /NPENABLED=1 /UpdateEnabled=0"
Start-Process "$source\\Redistr\x64\SqlExpress\2016SP2\SQLEXPR_x64_ENU.exe" -ArgumentList $Arguments -Wait -NoNewWindow

## Install Veeam ONE without license file
Write-Host "Installing Veeam ONE without license file ..." -ForegroundColor Yellow
### Veeam ONE Monitor Server
$logfile = "07_MonitorServer.txt"
Write-Host "    Installing Veeam ONE Monitor Server ..." -ForegroundColor Yellow
$MSIArguments = @(
    "/i"
    "$source\Monitor\VeeamONE.Monitor.Server.x64.msi"
    "/qn"
    "/L*v"
    "$logdir\$logfile"
    "ACCEPT_THIRDPARTY_LICENSES=1"
    "ACCEPT_EULA=1"
    "VM_MN_SERVICEACCOUNT=$username"
    "VM_MN_SERVICEPASSWORD=$password"
    "VM_MN_SQL_SERVER=$env:COMPUTERNAME\$SQLinstance"
    "VM_MN_SQL_AUTHENTICATION=1"
    "VM_MN_SQL_USER=sa"
    "VM_MN_SQL_PASSWORD=$SQLsapassword"
    "VM_BACKUP_ADD_LATER=1"
    "VM_VC_SELECTED_TYPE=2"

)
Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

CheckLatestLog

### Veeam ONE Reporter Server
Write-Host "    Installing Veeam ONE Reporter Server ..." -ForegroundColor Yellow
$logfile = "08_ReporterServer.txt"
$MSIArguments = @(
    "/i"
    "$source\Monitor\VeeamONE.Reporter.Server.x64.msi"
    "/qn"
    "/L*v"
    "$logdir\$logfile"
    "ACCEPT_THIRDPARTY_LICENSES=1"
    "ACCEPT_EULA=1"
    "VM_RP_SERVICEACCOUNT=$username"
    "VM_RP_SERVICEPASSWORD=$password"
    "VM_RP_SQL_SERVER=l$env:COMPUTERNAME\$SQLinstance"
    "VM_RP_SQL_AUTHENTICATION=1"
    "VM_RP_SQL_USER=sa"
    "VM_RP_SQL_PASSWORD=$SQLsapassword"
    "VM_BACKUP_ADD_LATER=1"
    "VM_VC_SELECTED_TYPE=2"

)
Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

CheckLatestLog

### Veeam ONE Reporter Web UI
Write-Host "    Installing Veeam ONE Reporter Web UI ..." -ForegroundColor Yellow
$logfile = "08_ReporterWebUI.txt"
$MSIArguments = @(
    "/i"
    "$source\Monitor\VeeamONE.Reporter.WebUI.x64.msi"
    "/qn"
    "/L*v"
    "$logdir\$logfile"
    "ACCEPT_THIRDPARTY_LICENSES=1"
    "ACCEPT_EULA=1"
    "VM_RP_SERVICEACCOUNT=$username"
    "VM_RP_SERVICEPASSWORD=$password"
    "VM_RP_SQL_SERVER=l$env:COMPUTERNAME\$SQLinstance"
    "VM_RP_SQL_AUTHENTICATION=1"
    "VM_RP_SQL_USER=sa"
    "VM_RP_SQL_PASSWORD=$SQLsapassword"

)
Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

CheckLatestLog

### Veeam ONE Monitor Client
Write-Host "    Installing Veeam ONE Monitor Client ..." -ForegroundColor Yellow
$logfile = "09_MonitorClient.txt"
$MSIArguments = @(
    "/i"
    "$source\Monitor\VeeamONE.Monitor.Client.x64.msi"
    "/qn"
    "/L*v"
    "$logdir\$logfile"
    "ACCEPT_THIRDPARTY_LICENSES=1"
    "ACCEPT_EULA=1"

)
Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

CheckLatestLog

### Veeam ONE Agent
Write-Host "    Installing Veeam ONE Agent ..." -ForegroundColor Yellow
$logfile = "10_Agent.txt"
$MSIArguments = @(
    "/i"
    "$source\Monitor\VeeamONE.Agent.x64.msi"
    "/qn"
    "/L*v"
    "$logdir\$logfile"
    "ACCEPT_THIRDPARTY_LICENSES=1"
    "ACCEPT_EULA=1"
    "VO_AGENT_TYPE=1"
    "VO_BUNDLE_INSTALLATION=1"
    "VO_AGENT_SERVICE_ACCOUNT_NAME=$username"
    "VO_AGENT_SERVICE_ACCOUNT_PASSWORD=$password"

)
Start-Process "msiexec.exe" -ArgumentList $MSIArguments -Wait -NoNewWindow

CheckLatestLog


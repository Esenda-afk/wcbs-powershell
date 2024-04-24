param(
    [string]$albacs, 
    [string]$s3bucket, 
    [string]$awss3user, 
    [string]$loglocation, 
    [string]$sauser,
    [string]$sapass,
    [string]$TaskName,
    [string]$PASS_VMName
)

# $location = get-location

$ScriptPath = "C:\HubPay\s3-scripts\HUBpayFileUpload.ps1"
$Value1 = "$albacs"
$Value2 = "$s3bucket"
$Arguments = "-File `"$ScriptPath`" -albacs `"$Value1`" -s3bucket `"$Value2`" -awss3user `"$awss3user`" -logpath `"$loglocation`" -PASS_VMName `"$PASS_VMName`""

# Create a new scheduled task action
$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $Arguments

# Create a new scheduled task trigger to run every minute indefinitely
$Trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 1)

# Create a PSCredential object
Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -User $sauser -Password $sapass -RunLevel Highest -ErrorAction Stop
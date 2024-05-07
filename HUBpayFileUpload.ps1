param(
    [string]$albacs, 
    [string]$s3bucket, 
    [string]$awss3user, 
    [string]$logpath,
    [string]$PASS_VMName)

function Ensure-ModuleLoaded {
    Param (
        [string]$ModuleName
    )
    try {
        Import-Module $ModuleName -ErrorAction Stop
        return $true
    }
    catch {
        Write-Host "Failed to load $ModuleName. Error: $_"
        return $false
    }
}

try {
    if (!(Test-Path "$logpath")) {

        New-Item -ItemType file -Path "$logpath"
    }
    Start-Transcript -Path "$logpath" -Append

    # Initialise Sentry if the module can be loaded
    $sentryAvailable = Ensure-ModuleLoaded "Sentry"
    if ($sentryAvailable) {
        Import-Module Sentry
        Start-Sentry 'https://38b83915f24124ddae8196758e939802@o1174556.ingest.us.sentry.io/4507095445798912'
    }
    else {
        Write-Host "Skipping Sentry initialization because the Sentry module could not be loaded"
    }
    $limit = (Get-Date).AddMinutes(-15)
    $logpathlimit = (Get-Date).Addhours(-24)
    echo $limit
    $path = "$albacs"
    $Extension = "*"
    $uploaddate = Get-Date -Format "ddMMyyyy_HHmm"


    $uploadedpath = "$path\uploaded"
    $logstore = "C:\HubPay\s3-logs\"
    $logarchive = "$logstore\archive"

    if (!(Test-Path "$logstore")) {
    
        New-Item -ItemType Directory -Path "$logstore"
    }


    if (!(Test-Path "$logarchive")) {
    
        New-Item -ItemType Directory -Path "$logarchive"
    }

    if (!(Test-Path "$uploadedpath")) {
    
        New-Item -ItemType Directory -Path "$uploadedpath"
    }

    $files = Get-ChildItem -Path $path -Filter $Extension -File -Force | Where-Object { $_.CreationTime -lt $limit }

    foreach ($file in $files) {
        echo "aws-vault exec $awss3user -- aws s3 cp $path\$file $s3bucket"
        aws-vault exec $awss3user -- aws s3 cp $path\$file $s3bucket 

        $fileName = [System.IO.Path]::GetFileNameWithoutExtension($file)
        $fileExtension = [System.IO.Path]::GetExtension($file)

        # Construct the new file name with the $uploaddate before the extension
        $newFileName = "{0} {1}{2}" -f $fileName, $uploaddate, $fileExtension
        $destination = Join-Path $uploadedpath $newFileName
        echo "This is file variable: $file"
        echo "This is path variable: $path"
        echo "This is uploaddate variable: $uploaddate"
        echo "This is destination variable: $destination"
        echo "move-item -path $path\$file -Destination $destination"
        move-item -path "$path\$file" -Destination $destination
    }

    Stop-Transcript
    $logFile = Get-ChildItem -Path $logpath -File | Where-Object { $_.CreationTime -lt $logpathlimit }

    if ($logFile) {
        echo "This is the logfile variable: $logfile"
        $archivefileName = [System.IO.Path]::GetFileNameWithoutExtension($logFile.FullName)
        $archivefileExtension = [System.IO.Path]::GetExtension($logFile.FullName)
        $archivelogName = "{0} {1}{2}" -f $archivefileName, $uploaddate, $archivefileExtension
        copy-Item -Path $logFile.FullName -Destination "$logarchive\$archivelogName"
        Set-Content -Path $logfile -Value ""
    }
    else {
        Write-Host "No files found older than 24 hours in $logpath."
    }
}
catch {
    $errorMessage = "An error occurred: " + $_.Exception.Message
    if ($sentryAvailable) {
        $_ | Out-Sentry
    }
    else {
        Write-Host "Skipping sending error to sentry, as module cannot be imported"
    }
    Write-Error $errorMessage
}

param(
    [string]$albacs, 
    [string]$s3bucket, 
    [string]$awss3user, 
    [string]$logpath,
    [string]$PASS_VMName)

if (!(Test-Path "$logpath")) {
    
    New-Item -ItemType file -Path "$logpath"
}

Start-Transcript -Path "$logpath" -Append

function Ensure-ModuleInstalled {
    Param (
        [string]$ModuleName
    )

    Write-Host "Checking if $ModuleName is installed..."
    if (-not (Get-Module -ListAvailable -Name $ModuleName)) {
        Write-Host "$ModuleName is not installed. Attempting to install..."
        Install-Module -Name $ModuleName -Scope CurrentUser -Repository PSGallery -Force
        Write-Host "$ModuleName installed successfully."
    } else {
        Write-Host "$ModuleName is already installed."
    }
    Import-Module $ModuleName
}

Ensure-ModuleInstalled -ModuleName "Sentry"
Import-Module Sentry
Start-Sentry 'https://38b83915f24124ddae8196758e939802@o1174556.ingest.us.sentry.io/4507095445798912'

try
{
    $limit = (Get-Date).AddMinutes(-15)
    $logpathlimit = (Get-Date).Addhours(-24)
    echo $limit
    $path = "$albacs"
    $Extension = "*"
    $uploaddate = Get-Date -Format "ddMMyyyy_HHmm"


    $uploadedpath = "$path\uploaded"
    $archivedpath = "$path\archive"
    $logstore = "C:\HubPay\s3-logs\"
    $logarchive = "$logstore\archive"

    if (!(Test-Path "$logstore")) {
        
        New-Item -ItemType Directory -Path "$logstore"
    }


    if (!(Test-Path "$logarchive")) {
        
        New-Item -ItemType Directory -Path "$logarchive"
    }

    $files = Get-ChildItem -Path $path -Filter $Extension -File -Force | Where-Object {$_.CreationTime -lt $limit}

    foreach ($file in $files){
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
        echo "move-item -path $file -Destination $destination"
        move-item -path $file -Destination $destination
    }

    Stop-Transcript
    $logFile = Get-ChildItem -Path $logpath -File | Where-Object {$_.CreationTime -lt $logpathlimit}

    if ($logFile) {
        echo "This is the logfile variable: $logfile"
        $archivefileName = [System.IO.Path]::GetFileNameWithoutExtension($logFile.FullName)
        $archivefileExtension = [System.IO.Path]::GetExtension($logFile.FullName)
        $archivelogName = "{0} {1}{2}" -f $archivefileName, $uploaddate, $archivefileExtension
        copy-Item -Path $logFile.FullName -Destination "$logarchive\$archivelogName"
        Set-Content -Path $logfile -Value ""
    } else {
        Write-Host "No files found older than 24 hours in $logpath."
    }
}
catch
{
    $_ | Out-Sentry
}
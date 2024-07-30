param(
    [string]$albacs, 
    [string]$s3bucket, 
    [string]$awss3user, 
    [string]$logpath,
    [string]$PASS_VMName
)

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

function Run-Command {
    param (
        [string]$Command
    )
    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processInfo.FileName = "powershell.exe"
    $processInfo.Arguments = "-Command `"$Command`""
    $processInfo.RedirectStandardError = $true
    $processInfo.RedirectStandardOutput = $true
    $processInfo.UseShellExecute = $false
    $processInfo.CreateNoWindow = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $processInfo

    $process.Start() | Out-Null

    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()

    $process.WaitForExit()
    $exitCode = $process.ExitCode

    return @{ExitCode = $exitCode; StdOut = $stdout; StdErr = $stderr }
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
        Start-Sentry 'https://b32e1aec4eafd670e8bcc6201c655bb7@o4507299731210240.ingest.de.sentry.io/4507300788568144'
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
        $fullFilePath = Join-Path -Path $path -ChildPath $file.Name
        <# 
        Spaces and brackets in the path "\\wcsPASS\c$\Program Files (x86)\WCBS\Pass for Windows\Documents\Albacs" were causing issues,
        so we need to prefix them with the escape character in powershell (which is `). I tried more elegant approaches than a simple character replacement,
        I assumed there would be some built in library or way for Powershell to properly escape strings. I wasn't able to get any other solution working that
        could both properly handle the spaces and brackets in the file path, as well as actually execute the command with the proper file paths instead of just variable names.
        #>
        $escapedFullFilePath = $fullFilePath -replace ' ', '` ' -replace '\(', '`(' -replace '\)', '`)'
        $command = "aws-vault exec $awss3user -- aws s3 cp `"$escapedFullFilePath`" `"$s3bucket`""
        echo "Command is: $command"
        $result = Run-Command -Command $command

        if ($result.ExitCode -ne 0) {
            $errorMsg = "Failed to upload $file to S3. Error: $($result.StdErr)"
            Write-Host $errorMsg
            if ($sentryAvailable) {
                Edit-SentryScope {
                    $_.SetTag("s3-bucket-name", $s3bucket)
                    $_.SetTag("file-name", $file.Name)
                }
                $exception = New-Object System.Exception($errorMsg)
                $exception | Out-Sentry
            }
            continue
        }

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
        Edit-SentryScope {
            $_.SetTag("s3-bucket-name", $s3bucket)
        }
        $_ | Out-Sentry
    }
    else {
        Write-Host "Skipping sending error to sentry, as module cannot be imported"
    }
    Write-Error $errorMessage
}

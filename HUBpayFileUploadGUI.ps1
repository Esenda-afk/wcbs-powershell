Add-Type -AssemblyName System.Windows.Forms

try {
    Stop-Transcript
} catch {
    # Ignoring errors if no transcript is running
}

start-Transcript -path C:\HubPay\guilog.txt

<#
.SYNOPSIS
    Checks if a PowerShell module is installed, and installs it if not present.

.DESCRIPTION
    Installs the inputted PS module if it's not already present. Also imports the module.
    Returns a boolean to indicate whether the module was successfully loaded or not.

.PARAMETER ModuleName
    The name of the PowerShell module to check and install.

.EXAMPLE
    Ensure-ModuleInstalled -ModuleName "Sentry"
    Checks if the Sentry module is installed, installs it if it is not, and then loads the module.
#>
function Ensure-ModuleInstalled {
    Param (
        [string]$ModuleName
    )

    Write-Host "Checking if $ModuleName is installed..."
    if (-not (Get-Module -ListAvailable -Name $ModuleName)) {
        try {
            Write-Host "$ModuleName is not installed. Attempting to install..."
            Install-Module -Name $ModuleName -Scope CurrentUser -Repository PSGallery -Force -ErrorAction Stop
            Write-Host "$ModuleName installed successfully."
        } catch {
            Write-Host "Failed to install $ModuleName. Error: $_"
            return $false
        }
    } else {
        Write-Host "$ModuleName is already installed."
    }
    
    try {
        Import-Module $ModuleName -ErrorAction Stop
        return $true
    } catch {
        Write-Host "Failed to load $ModuleName. Error: $_"
        return $false
    }
}


# Initialise Sentry if the module can be installed
$sentryAvailable = Ensure-ModuleInstalled -ModuleName "Sentry"
if ($sentryAvailable) {
    Import-Module Sentry
    Start-Sentry 'https://38b83915f24124ddae8196758e939802@o1174556.ingest.us.sentry.io/4507095445798912'
} else {
    Write-Host "Skipping Sentry initialization because the Sentry module could not be installed."
}


# Create form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Upload to S3 GUI"
$form.Size = New-Object System.Drawing.Size(400, 400)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.MinimizeBox = $false

# Create labels and textboxes for each parameter
$labels = @("Albacs", "S3 Bucket", "AWS S3 User", "Log Location", "SA User", "SA Password", "Task Name", "PASS VM Name")
$textboxes = @{}
for ($i = 0; $i -lt $labels.Count; $i++) {
    $labelLocationX = 10
    $labelLocationY = 20 + $i * 30
    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point $labelLocationX, $labelLocationY
    $label.Size = New-Object System.Drawing.Size(100, 20)
    $label.Text = $labels[$i]
    $form.Controls.Add($label)

    $textboxLocationX = 120
    $textboxLocationY = 20 + $i * 30
    $textbox = New-Object System.Windows.Forms.TextBox
    $textbox.Location = New-Object System.Drawing.Point $textboxLocationX, $textboxLocationY
    $textbox.Size = New-Object System.Drawing.Size(250, 20)
    $form.Controls.Add($textbox)
    $textboxes[$labels[$i]] = $textbox
}

# Calculate button location
$buttonHeight = 30
$buttonLocationX = 150
$buttonLocationY = ($labels.Count * 30) + 50  # Adjusted to position the button below the textboxes

# Create button to execute the script
$button = New-Object System.Windows.Forms.Button
$button.Location = New-Object System.Drawing.Point $buttonLocationX, $buttonLocationY
$button.Size = New-Object System.Drawing.Size(100, 30)
$button.Text = "Execute Script"
$button.Add_Click({
    try {
        # Retrieve values from textboxes and execute the script
        $albacs, $s3bucket, $awss3user, $loglocation, $sauser, $sapass, $TaskName, $PASS_VMName = $labels.ForEach({ $textboxes[$_].Text })

        # Docs on this $PSScriptRoot var: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_automatic_variables?view=powershell-7.4#psscriptroot
        & "$PSScriptRoot\HUBpay-createschedtask.ps1" -albacs $albacs -s3bucket $s3bucket -awss3user $awss3user -loglocation $loglocation -sauser $sauser -sapass $sapass -TaskName $TaskName -PASS_VMName $PASS_VMName

        # Display success message box
        [System.Windows.Forms.MessageBox]::Show("Scheduled task created successfully", "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    } catch {
        # Capture the error message
        $errorMessage = "An error occurred: " + $_.Exception.Message

        # If Sentry is available, send the error to Sentry
        if ($sentryAvailable) {
            $_ | Out-Sentry
        } else {
            Write-Host "Skipping error reporting to Sentry because the Sentry module is not available."
        }

        Write-Error $errorMessage

        # Display the error message in a dialog box
        [System.Windows.Forms.MessageBox]::Show($errorMessage)
    }
})

$form.Controls.Add($button)

# Show the form
$form.ShowDialog() | Out-Null

stop-Transcript
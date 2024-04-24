Add-Type -AssemblyName System.Windows.Forms

try {
    Stop-Transcript
} catch {
    # Ignoring errors if no transcript is running
}

start-Transcript -path C:\HubPay\guilog.txt

# Initialise sentry
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

        # Assuming 'C:\HubPay\s3-scripts\HUBpay-createschedtask.ps1' is the correct path to the script
        & "C:\HubPay\s3-scripts\HUBpay-createschedtask.ps1" -albacs $albacs -s3bucket $s3bucket -awss3user $awss3user -loglocation $loglocation -sauser $sauser -sapass $sapass -TaskName $TaskName -PASS_VMName $PASS_VMName
    } catch {
        # Capture the error message
        $errorMessage = "An error occurred: " + $_.Exception.Message

        # Send the error to Sentry
        $_ | Out-Sentry

        Write-Error $errorMessage

        # Display the error message in a dialog box
        [System.Windows.Forms.MessageBox]::Show($errorMessage)
    }
})

$form.Controls.Add($button)

# Show the form
$form.ShowDialog() | Out-Null

stop-Transcript
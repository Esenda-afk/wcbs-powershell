Add-Type -AssemblyName System.Windows.Forms
start-Transcript -path C:\HubPay\guilog.txt
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
    $albacs = $textboxes["Albacs"].Text
    $s3bucket = $textboxes["S3 Bucket"].Text
    $awss3user = $textboxes["AWS S3 User"].Text
    $loglocation = $textboxes["Log Location"].Text
    $sauser = $textboxes["SA User"].Text
    $sapass = $textboxes["SA Password"].Text
    $TaskName = $textboxes["Task Name"].Text
    $PASS_VMName = $textboxes["PASS VM Name"].Text

    # Call the script with the provided parameters
    & "C:\HubPay\s3-scripts\HUBpay-createschedtask.ps1" -albacs $albacs -s3bucket $s3bucket -awss3user $awss3user -loglocation $loglocation -sauser $sauser -sapass $sapass -TaskName $TaskName -PASS_VMName $PASS_VMName

    # Run the create-task.ps1 script
    Start-Process powershell.exe -ArgumentList "-File '$location\HUBpay-createschedtask.ps1' -albacs '$albacs' -s3bucket '$s3bucket' -awss3user '$awss3user' -loglocation '$loglocation' -sauser '$sauser' -sapass '$sapass' -TaskName '$TaskName' -PASS_VMName '$PASS_VMName'"
})

$form.Controls.Add($button)

# Show the form
$form.ShowDialog() | Out-Null

stop-Transcript
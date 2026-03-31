Add-Type -AssemblyName System.Windows.Forms
# Create the form
$form = New-Object System.Windows.Forms.Form
$form.Text = "IT Self Service"
$form.StartPosition = "CenterScreen"
$form.Size = New-Object System.Drawing.Size(300, 150)
$form.TopMost = $true
# Create the label
$label = New-Object System.Windows.Forms.Label
$label.Text = "Self Service Action Complete"
$label.Dock = "Fill"
$label.TextAlign = "MiddleCenter"
$label.Font = New-Object System.Drawing.Font("Segoe UI", 12)
$form.Controls.Add($label)
# Create the OK button
$okButton = New-Object System.Windows.Forms.Button
$okButton.Text = "OK"
$okButton.Dock = "Bottom"
$okButton.Height = 40
$okButton.Add_Click({
        $form.Tag = "clicked"
        $form.Close()
    })
$form.Controls.Add($okButton)
# Set up a timer to auto-close after 60 seconds
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 60000  # 60 seconds
$timer.Add_Tick({
        $form.Tag = "timeout"
        $form.Close()
    })
$timer.Start()
# Show the form
$form.ShowDialog()
# Exit with code 0 regardless of how it closed
exit 0
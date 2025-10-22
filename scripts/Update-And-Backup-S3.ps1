# Update-And-Backup-S3.ps1
# Author: Ayoub Tadlawi
# Description: Updates Windows and uploads a daily backup to Scaleway S3.
param(
  [string] = "C:\Data",
  [string] = "s3://mk-backups-daily",
  [string] = "https://s3.fr-par.scw.cloud"
)
Write-Host "Installing system updates..."
Install-WindowsUpdate -AcceptAll -AutoReboot
Write-Host "Creating zip archive..."
Compress-Archive -Path  -DestinationPath "C:\backup.zip" -Force
Write-Host "Uploading to Scaleway..."
aws s3 cp "C:\backup.zip" "" --endpoint-url 
Write-Host "Backup completed successfully."

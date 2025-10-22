<# 
Update-And-Backup-S3.ps1
Author: Ayoub Rabihi

Purpose:
- Optionnel: installer les mises à jour Windows (best effort).
- Créer une archive ZIP d’un répertoire source.
- Téléverser l’archive vers Scaleway Object Storage (S3-compatible via AWS CLI).
- Nettoyer les archives locales anciennes.

Prerequisites:
- AWS CLI installé et configuré (aws --version ; aws configure).
- Droits sur le bucket Scaleway ; endpoint ex: https://s3.fr-par.scw.cloud
- PowerShell 5.1+ (ou pwsh 7+). 
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)]
  [string]$Source,                        # Dossier à sauvegarder, ex: C:\Data

  [Parameter(Mandatory=$true)]
  [string]$Bucket,                        # Nom S3, ex: s3://mk-backups-daily

  [Parameter(Mandatory=$true)]
  [string]$Endpoint,                      # Endpoint S3 Scaleway, ex: https://s3.fr-par.scw.cloud

  [int]$RetentionDays = 14,               # Rétention des archives locales
  [string]$ArchivePrefix = "backup",      # Préfixe de l’archive ZIP
  [string]$TempDir = "$env:TEMP",         # Répertoire temporaire
  [string]$LogDir = "C:\Logs\MediakeysBackup",  # Répertoire des logs
  [switch]$SkipWindowsUpdate              # Ne pas tenter d’installer les mises à jour
)

$ErrorActionPreference = "Stop"

function Log {
  param([string]$Message)
  $timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssK"
  $line = "[$timestamp] $Message"
  Write-Host $line
  $line | Out-File -FilePath $Script:LogFile -Append -Encoding utf8
}

try {
  if (-not (Test-Path -LiteralPath $Source)) {
    throw "Source folder not found: $Source"
  }

  if (-not (Test-Path -LiteralPath $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
  }

  $stamp   = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
  $zipName = "${ArchivePrefix}_${stamp}.zip"
  $zipPath = Join-Path $TempDir $zipName
  $Script:LogFile = Join-Path $LogDir "run_${stamp}.log"

  Log "Start run. Source='$Source' Bucket='$Bucket' Endpoint='$Endpoint'"

  # 1) Windows Updates (best effort, ignoré si -SkipWindowsUpdate ou module indisponible)
  if (-not $SkipWindowsUpdate) {
    try {
      Import-Module PSWindowsUpdate -ErrorAction Stop
      Log "Installing Windows Updates (best effort)..."
      Get-WindowsUpdate -AcceptAll -Install -IgnoreReboot | Out-Null
      Log "Windows Updates step completed."
    } catch {
      Log "PSWindowsUpdate not available or failed. Continuing without OS updates. Details: $($_.Exception.Message)"
    }
  } else {
    Log "Skipped Windows Updates (per -SkipWindowsUpdate)."
  }

  # 2) Création de l’archive
  if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
  Log "Creating archive '$zipPath' from '$Source'..."
  Compress-Archive -Path $Source -DestinationPath $zipPath -Force
  Log "Archive created. Size = $((Get-Item $zipPath).Length) bytes."

  # 3) Vérification AWS CLI
  try {
    $awsVersion = & aws --version 2>&1
    Log "AWS CLI detected: $awsVersion"
  } catch {
    throw "AWS CLI is not available in PATH. Install it or open a new shell after installation."
  }

  # 4) Upload vers Scaleway S3
  Log "Uploading archive to $Bucket ..."
  & aws configure set default.s3.signature_version s3v4 | Out-Null
  & aws s3 cp $zipPath "$Bucket/" --endpoint-url $Endpoint | Out-Null
  Log "Upload completed."

  # 5) Nettoyage local des anciennes archives
  Log "Cleaning local archives older than $RetentionDays day(s) in '$TempDir'..."
  Get-ChildItem $TempDir -Filter "${ArchivePrefix}_*.zip" -File -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$RetentionDays) } |
    Remove-Item -Force -ErrorAction SilentlyContinue
  Log "Cleanup completed."

  Log "Run completed successfully."
  exit 0
}
catch {
  Log "ERROR: $($_.Exception.Message)"
  exit 1
}

# Mediakeys – Technical Assessment for IT Engineer

**Author:** Ayoub Rabihi
**Date:** October 2025  
**Scope:** End-to-end procedures (PC onboarding, troubleshooting, Scaleway migration, Cloudflare DNS/Zero Trust, global IT support, inventory standardization) and one automation script in PowerShell.

---

##  1) PC Configuration & Maintenance

### Scenario 1 — New Employee Onboarding (bare laptop, no OS)
**Goal:** deliver an encrypted, hardened, standardized, remotely manageable workstation.

1) Hardware & security  
- Update BIOS/UEFI; enable Secure Boot + TPM 2.0; record serial/asset tag.

2) OS install  
- Windows via Autopilot/Intune (preferred) or MDT/PXE. GPT layout; enable BitLocker at setup, escrow recovery key in Azure AD/Intune.

3) Directory & compliance  
- Enroll in Intune / Azure AD. Apply profiles: Wi-Fi, VPN, firewall, disk encryption, updates.

4) Drivers & updates  
- OEM driver pack, Windows Update/WSUS; verify Device Guard/Credential Guard.

5) Baseline apps  
- Deployed by Intune/winget: Office, browser, EDR/AV, monitoring/MDM agents, VPN.

6) Remote access ready  
- Certificates, VPN profiles (split/full tunnel), enterprise Wi-Fi (EAP-TLS/PEAP).

7) Hardening  
- Host firewall, screen lock, WDAC/AppLocker, DNS filtering (Cloudflare Gateway), EDR active.

8) Handover & docs  
- Sign checklist, provide quick start guide & support contacts; close onboarding ticket.

### Scenario 2 — Troubleshooting: slow PC + unstable Wi-Fi
1) Triage: when, which apps, others affected, distance to AP.  
2) Local performance: Task Manager (CPU/RAM/Disk), disk SMART, AV scan, startup bloat, temps, drivers/OS updates, OneDrive I/O.  
3) Wi-Fi: RSSI/channels, 2.4 vs 5/6 GHz, NIC power saving off, forget/re-add SSID, renew 802.1X cert, DHCP/DNS leases, test Ethernet, reset stack.  
4) Fix & validate: apply changes, reboot, test ping/jitter/iperf; document root cause.

---

##  2) Cloud Migration & Management

### Scenario 3 — Migrate on-prem file server to **Scaleway Object Storage (S3)**
**Plan:** inventory (size, ACLs/shares), constraints (latency, file locking, RPO/RTO), target (buckets per team/env, versioning, SSE, lifecycle, IAM least-privilege).

**Execution:**  
- Create project, bucket(s), access keys; optional Object Lock; bucket policy + IP allowlist.  
- Seed → delta sync → cutover (on-prem SMB read-only during final sync).  
- Validate checksums, sample restores.  
- Access options: SMB gateway (Linux + `rclone mount` VFS) or native S3/web.  
- DR: cross-region replication, versioning, lifecycle to cold storage; restoration runbook & periodic tests.  
- Cost/monitoring: object metrics, access logs, budget alerts, quarterly IAM review.

**Example (Windows):**
```powershell
aws configure set default.s3.signature_version s3v4
aws s3 sync "C:\Data\Shares" s3://my-bucket/ --endpoint-url https://s3.fr-par.scw.cloud --delete

---

## 3) Sécurité et Réseau — Cloudflare DNS / Zero Trust

**Objectif :** centraliser la sécurité DNS et gérer les accès distants via Cloudflare Zero Trust.

- Enregistrer le domaine dans Cloudflare.  
- Configurer DNS public (A, CNAME, MX, TXT).  
- Activer DNSSEC et proxy “orange cloud” sur les services publics.  
- Mettre en place les politiques de Zero Trust (IP ranges, device posture, MFA).  
- Activer les tunnels Cloudflare pour accès RDP/SSH internes.  
- Journaliser le trafic et exporter vers SIEM.

---

## 4) Support global & standardisation

- Créer un catalogue matériel (poste, périphériques, licences).  
- Standardiser les modèles par rôle (Sales, Dev, Infra).  
- Documenter chaque procédure dans Confluence / Wiki interne.  
- Mettre en place des alertes de supervision basiques (Pingdom, UptimeRobot, Grafana).

---

## 5) Script PowerShell d’automatisation

Ce script réalise la sauvegarde et la synchronisation automatique d’un dossier local vers Scaleway S3.

```powershell
# Update-And-Backup-S3.ps1
# Author: Ayoub Tadlawi
# Date: October 2025

$source = "C:\Data\Shares"
$bucket = "s3://my-bucket/"
$endpoint = "https://s3.fr-par.scw.cloud"
$logFile = "C:\Logs\S3Backup_$(Get-Date -Format 'yyyyMMdd_HHmm').log"

Write-Host "Starting S3 sync..."
aws s3 sync $source $bucket --endpoint-url $endpoint --delete | Tee-Object -FilePath $logFile

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Backup completed successfully!"
} else {
    Write-Host "❌ Backup failed. Check log: $logFile"
}

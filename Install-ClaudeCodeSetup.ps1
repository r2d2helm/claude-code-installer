#Requires -Version 5.1
<#
.SYNOPSIS
    Installation complète de la configuration Claude Code avec tous les skills et MCP servers.

.DESCRIPTION
    Ce script installe:
    - 6 Skills: windows-skill, proxmox-skill, knowledge-skill, knowledge-watcher-skill, obsidian-skill, fileorg-skill
    - 1 MCP Server: knowledge-assistant
    - Templates Obsidian
    - Tâches planifiées Knowledge Watcher
    - Configuration settings.json

.PARAMETER VaultPath
    Chemin du vault Obsidian (défaut: $env:USERPROFILE\Documents\Knowledge)

.PARAMETER SkipScheduledTasks
    Ne pas créer les tâches planifiées Windows

.PARAMETER SkipMCP
    Ne pas installer le serveur MCP

.EXAMPLE
    .\Install-ClaudeCodeSetup.ps1
    .\Install-ClaudeCodeSetup.ps1 -VaultPath "D:\MonVault"
#>

[CmdletBinding()]
param(
    [string]$VaultPath = "$env:USERPROFILE\Documents\Knowledge",
    [switch]$SkipScheduledTasks,
    [switch]$SkipMCP
)

$ErrorActionPreference = "Stop"
$script:InstallerVersion = "1.0.0"
$script:InstallerDate = "2026-02-05"

# Couleurs
function Write-Step { param([string]$Message) Write-Host "`n[$script:Step] $Message" -ForegroundColor Cyan; $script:Step++ }
function Write-Success { param([string]$Message) Write-Host "  [OK] $Message" -ForegroundColor Green }
function Write-Warning { param([string]$Message) Write-Host "  [!] $Message" -ForegroundColor Yellow }
function Write-Error { param([string]$Message) Write-Host "  [X] $Message" -ForegroundColor Red }
$script:Step = 1

# Fonction pour écrire en UTF-8 avec BOM (compatible PS 5.1)
function Write-Utf8WithBom {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Content
    )
    $utf8Bom = New-Object System.Text.UTF8Encoding $true
    [System.IO.File]::WriteAllText($Path, $Content, $utf8Bom)
}

# ============================================================================
# CONFIGURATION
# ============================================================================

$Config = @{
    ClaudeDir       = "$env:USERPROFILE\.claude"
    SkillsDir       = "$env:USERPROFILE\.claude\skills"
    MCPDir          = "$env:USERPROFILE\.claude\mcp-servers"
    LocalBin        = "$env:USERPROFILE\.local\bin"
    VaultPath       = $VaultPath
    ProjetsPath     = "$env:USERPROFILE\Documents\Projets"
    GitHubUser      = "r2d2helm"
    MCPRepoUrl      = "https://github.com/r2d2helm/knowledge-assistant-mcp.git"
}

# ============================================================================
# FONCTIONS UTILITAIRES
# ============================================================================

function Test-Prerequisites {
    Write-Step "Vérification des prérequis"

    # Windows version
    $os = Get-CimInstance Win32_OperatingSystem
    if ($os.Version -lt "10.0.22000") {
        Write-Warning "Windows 11+ recommandé (actuel: $($os.Caption))"
    } else {
        Write-Success "Windows: $($os.Caption)"
    }

    # PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        Write-Warning "PowerShell 7+ recommandé (actuel: $($PSVersionTable.PSVersion))"
    } else {
        Write-Success "PowerShell: $($PSVersionTable.PSVersion)"
    }

    # Git
    if (Get-Command git -ErrorAction SilentlyContinue) {
        Write-Success "Git: $(git --version)"
    } else {
        throw "Git non installé. Installez avec: winget install Git.Git"
    }

    # Python
    $python = Get-Command python -ErrorAction SilentlyContinue
    if ($python) {
        $pyVer = python --version 2>&1
        Write-Success "Python: $pyVer"
    } else {
        Write-Warning "Python non trouvé (requis pour MCP server)"
    }

    # uv (Python package manager)
    if (Get-Command uv -ErrorAction SilentlyContinue) {
        Write-Success "uv: installé"
    } else {
        Write-Warning "uv non trouvé (sera installé si nécessaire)"
    }

    # Claude CLI
    $claudePath = Join-Path $Config.LocalBin "claude.exe"
    if (Test-Path $claudePath) {
        Write-Success "Claude CLI: $claudePath"
    } else {
        Write-Warning "Claude CLI non trouvé dans $($Config.LocalBin)"
    }
}

function Initialize-DirectoryStructure {
    Write-Step "Création de la structure de dossiers"

    $dirs = @(
        $Config.ClaudeDir,
        $Config.SkillsDir,
        $Config.MCPDir,
        $Config.LocalBin,
        $Config.VaultPath,
        $Config.ProjetsPath,
        (Join-Path $Config.ClaudeDir "projects"),
        (Join-Path $Config.ClaudeDir "plans"),
        (Join-Path $Config.ClaudeDir "todos"),
        (Join-Path $Config.ClaudeDir "cache"),
        (Join-Path $Config.VaultPath "_Attachments"),
        (Join-Path $Config.VaultPath "_Daily"),
        (Join-Path $Config.VaultPath "_Inbox"),
        (Join-Path $Config.VaultPath "_Index"),
        (Join-Path $Config.VaultPath "_Templates"),
        (Join-Path $Config.VaultPath "Code"),
        (Join-Path $Config.VaultPath "Concepts"),
        (Join-Path $Config.VaultPath "Conversations"),
        (Join-Path $Config.VaultPath "Formations"),
        (Join-Path $Config.VaultPath "Projets"),
        (Join-Path $Config.VaultPath "Références"),
        (Join-Path $Config.VaultPath "Références\Documentation"),
        (Join-Path $Config.VaultPath "Références\Troubleshooting")
    )

    foreach ($dir in $dirs) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Write-Success "Créé: $dir"
        } else {
            Write-Success "Existe: $dir"
        }
    }
}

function Install-UvPackageManager {
    if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
        Write-Step "Installation de uv (gestionnaire Python)"

        try {
            Invoke-RestMethod https://astral.sh/uv/install.ps1 | Invoke-Expression
            Write-Success "uv installé"
        } catch {
            Write-Warning "Installation uv échouée: $_"
            Write-Host "  Installez manuellement: pip install uv"
        }
    }
}

# ============================================================================
# INSTALLATION DES SKILLS
# ============================================================================

function Install-WindowsSkill {
    Write-Step "Installation: windows-skill"

    $skillPath = Join-Path $Config.SkillsDir "windows-skill"

    if (Test-Path $skillPath) {
        Write-Success "Déjà installé: $skillPath"
        return
    }

    New-Item -ItemType Directory -Path $skillPath -Force | Out-Null
    New-Item -ItemType Directory -Path "$skillPath\commands" -Force | Out-Null
    New-Item -ItemType Directory -Path "$skillPath\wizards" -Force | Out-Null

    # SKILL.md
    @"
# Windows Skill - Agent Windows 11/Server 2025

## Description
Agent spécialisé pour l'administration Windows 11 23H2+ et Windows Server 2022/2025.

## Prérequis
- Windows 11 23H2+ ou Server 2022/2025
- PowerShell 7.4+ (5.1 compatible)
- .NET 8.0+ (optionnel)

## Commandes
| Commande | Description |
|----------|-------------|
| /win-diagnostic | Diagnostic système complet |
| /win-security | Audit sécurité |
| /win-network | Configuration réseau |
| /win-services | Gestion services |
| /win-users | Gestion utilisateurs |
| /win-firewall | Règles pare-feu |
| /win-defender | Windows Defender |
| /win-update | Windows Update |
| /win-wizard | Assistants guidés |

## Tags
#windows #powershell #admin #system
"@ | Out-File -FilePath "$skillPath\SKILL.md" -Encoding UTF8

    # Commande diagnostic
    @"
# /win-diagnostic

## Description
Effectue un diagnostic complet du système Windows.

## Utilisation
``````
/win-diagnostic [quick|full]
``````

## Actions
1. Informations système (OS, RAM, CPU)
2. Espace disque
3. Services critiques
4. Événements récents
5. Performances

## Exemple PowerShell
``````powershell
# Infos système
Get-ComputerInfo | Select-Object WindowsProductName, OsVersion, TotalPhysicalMemory

# Espace disque
Get-PSDrive -PSProvider FileSystem | Select-Object Name, Used, Free

# Services
Get-Service | Where-Object Status -eq 'Stopped' | Where-Object StartType -eq 'Automatic'
``````
"@ | Out-File -FilePath "$skillPath\commands\diagnostic.md" -Encoding UTF8

    Write-Success "Installé: windows-skill"
}

function Install-ProxmoxSkill {
    Write-Step "Installation: proxmox-skill"

    $skillPath = Join-Path $Config.SkillsDir "proxmox-skill"

    if (Test-Path $skillPath) {
        Write-Success "Déjà installé: $skillPath"
        return
    }

    New-Item -ItemType Directory -Path $skillPath -Force | Out-Null
    New-Item -ItemType Directory -Path "$skillPath\commands" -Force | Out-Null
    New-Item -ItemType Directory -Path "$skillPath\wizards" -Force | Out-Null

    @"
# Proxmox Skill - Agent Proxmox VE 9+

## Description
Agent spécialisé pour l'administration Proxmox VE 9.0, 9.1+.

## Prérequis
- Proxmox VE 9.0+
- Accès SSH au serveur
- Token API (optionnel)

## Commandes
| Commande | Description |
|----------|-------------|
| /pve-status | Vue d'ensemble cluster |
| /pve-vm | Gestion VMs |
| /pve-ct | Gestion containers |
| /pve-storage | Gestion stockage |
| /pve-backup | Sauvegardes |
| /pve-network | Configuration réseau |
| /pve-wizard | Assistants guidés |

## Tags
#proxmox #virtualization #homelab #linux
"@ | Out-File -FilePath "$skillPath\SKILL.md" -Encoding UTF8

    Write-Success "Installé: proxmox-skill"
}

function Install-KnowledgeSkill {
    Write-Step "Installation: know-save skill"

    # Format correct: skills/<skill-name>/SKILL.md -> /skill-name
    $skillPath = Join-Path $Config.SkillsDir "know-save"

    if (Test-Path $skillPath) {
        Write-Success "Déjà installé: $skillPath"
        return
    }

    New-Item -ItemType Directory -Path $skillPath -Force | Out-Null

    $vaultPath = $Config.VaultPath

    @"
---
name: know-save
description: Sauvegarder et résumer la conversation actuelle dans le vault Knowledge
allowed-tools: Bash(powershell:*), Write(*), Read(*)
---

## Context

- Date actuelle: !``powershell -Command "Get-Date -Format 'yyyy-MM-dd'"``
- Heure actuelle: !``powershell -Command "Get-Date -Format 'HHmmss'"``
- Vault Knowledge: $vaultPath

## Your task

Analyse la conversation actuelle et sauvegarde-la dans le vault Obsidian.

### Étapes:

1. **Analyser** la conversation pour extraire:
   - Sujet principal (pour le titre)
   - Résumé en 2-3 phrases
   - Points clés (3-5 bullets)
   - Décisions prises
   - Code/commandes utilisés
   - Actions suivantes
   - Tags pertinents (#domaine/sous-domaine)

2. **Créer le fichier de conversation** dans ``Knowledge/Conversations/``:
   - Nom: ``{YYYY-MM-DD}_Conv_{Sujet-Sans-Espaces}.md``
   - Utiliser le template avec frontmatter YAML

3. **Mettre à jour la Daily Note** dans ``Knowledge/_Daily/``:
   - Créer si n'existe pas
   - Ajouter lien vers la conversation

### Template de sortie:

``````markdown
---
id: {YYYYMMDD}-{HHMMSS}
title: {Titre}
date: {YYYY-MM-DD}
type: conversation
tags: [{tags}]
source: Claude
status: captured
related: []
---

# {Titre}

## Résumé
{résumé}

## Points Clés
- {point1}
- {point2}
- {point3}

## Code/Commandes
```{langage}
{code extrait}
```

## Actions Suivantes
- [ ] {action1}

---
*Capturé le {date} depuis conversation Claude*
``````
"@ | Out-File -FilePath "$skillPath\SKILL.md" -Encoding UTF8

    Write-Success "Installé: know-save -> /know-save"
}

function Install-KnowledgeWatcherSkill {
    Write-Step "Installation: knowledge-watcher-skill"

    $skillPath = Join-Path $Config.SkillsDir "knowledge-watcher-skill"
    $vaultPath = $Config.VaultPath

    if (Test-Path $skillPath) {
        Write-Success "Déjà installé: $skillPath"
        return
    }

    # Structure
    $dirs = @(
        $skillPath,
        "$skillPath\commands",
        "$skillPath\wizards",
        "$skillPath\config",
        "$skillPath\scripts",
        "$skillPath\scripts\scheduled",
        "$skillPath\sources",
        "$skillPath\processors",
        "$skillPath\data",
        "$skillPath\data\logs"
    )
    foreach ($dir in $dirs) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    # SKILL.md
    @"
# Knowledge Watcher Skill - Surveillance Automatique

## Description
Agent de surveillance multi-sources pour capturer automatiquement les connaissances.

## Architecture Tiers
| Tier | Fréquence | Sources |
|------|-----------|---------|
| 1 | Real-time | Claude history, Projets, Vault |
| 2 | Horaire | Downloads, Formations |
| 3 | Quotidien (6h) | Bookmarks, Scripts |
| 4 | Hebdo (dim 3h) | Archives |

## Commandes
| Commande | Description |
|----------|-------------|
| /kwatch-start | Démarrer watchers temps réel |
| /kwatch-stop | Arrêter watchers |
| /kwatch-status | Dashboard |
| /kwatch-process | Traiter queue manuellement |

## Configuration
- ``config/config.json`` - Chemins et paramètres
- ``config/sources.json`` - Sources de données
- ``config/rules.json`` - Règles classification

## Tags
#automation #watcher #knowledge #powershell
"@ | Out-File -FilePath "$skillPath\SKILL.md" -Encoding UTF8

    # config.json
    $configJson = @{
        paths = @{
            obsidianVault = $vaultPath
            claudeCli = "$env:USERPROFILE\.local\bin\claude.exe"
            queueFile = "$skillPath\data\queue.json"
            stateFile = "$skillPath\data\state.json"
            logDir = "$skillPath\data\logs"
        }
        processing = @{
            claudeTimeout = 30000
            maxFileSize = 1048576
            deduplicationWindow = 86400000
            maxQueueSize = 100
            batchSize = 10
        }
        output = @{
            defaultFolder = "_Inbox"
            updateDailyNote = $true
            createBacklinks = $true
            language = "fr"
        }
        scheduler = @{
            tier2CronHourly = "0 * * * *"
            tier3CronDaily = "0 6 * * *"
            tier4CronWeekly = "0 3 * * 0"
        }
    }
    $configJson | ConvertTo-Json -Depth 5 | Out-File -FilePath "$skillPath\config\config.json" -Encoding UTF8

    # sources.json
    $sourcesJson = @{
        tier1 = @{
            name = "Real-time"
            enabled = $true
            sources = @(
                @{ name = "Claude History"; path = "$env:USERPROFILE\.claude"; pattern = "*.jsonl" }
                @{ name = "Projets"; path = "$env:USERPROFILE\Documents\Projets"; pattern = "*.md" }
                @{ name = "Knowledge Vault"; path = $vaultPath; pattern = "*.md" }
            )
        }
        tier2 = @{
            name = "Hourly"
            enabled = $true
            sources = @(
                @{ name = "Downloads"; path = "$env:USERPROFILE\Downloads"; pattern = "*.pdf,*.md" }
                @{ name = "Formations"; path = "$vaultPath\Formations"; pattern = "*.md" }
            )
        }
        tier3 = @{
            name = "Daily"
            enabled = $true
            sources = @(
                @{ name = "Scripts"; path = "$env:USERPROFILE\Documents\WindowsPowerShell"; pattern = "*.ps1" }
            )
        }
        tier4 = @{
            name = "Weekly"
            enabled = $true
            sources = @(
                @{ name = "Archives"; path = "$env:USERPROFILE\Documents"; pattern = "*.zip" }
            )
        }
    }
    $sourcesJson | ConvertTo-Json -Depth 5 | Out-File -FilePath "$skillPath\config\sources.json" -Encoding UTF8

    # rules.json
    $rulesJson = @{
        classification = @(
            @{ pattern = "^C_"; type = "concept"; folder = "Concepts" }
            @{ pattern = "_Conv_"; type = "conversation"; folder = "Conversations" }
            @{ pattern = "_Fix_"; type = "troubleshooting"; folder = "Références/Troubleshooting" }
            @{ pattern = "\.ps1$"; type = "code"; folder = "Code" }
        )
        tags = @{
            powershell = @("dev/powershell", "code")
            python = @("dev/python", "code")
            claude = @("ai/claude", "dev/claude-code")
        }
    }
    $rulesJson | ConvertTo-Json -Depth 5 | Out-File -FilePath "$skillPath\config\rules.json" -Encoding UTF8

    # Initialiser data files
    "[]" | Out-File -FilePath "$skillPath\data\queue.json" -Encoding UTF8
    @{ watchers = @{}; lastProcessed = $null } | ConvertTo-Json | Out-File -FilePath "$skillPath\data\state.json" -Encoding UTF8
    @{ notes = @(); terms = @{} } | ConvertTo-Json | Out-File -FilePath "$skillPath\data\notes-index.json" -Encoding UTF8

    # Module PowerShell principal
    $moduleContent = @'
# KnowledgeWatcher.psm1
# Module principal pour la surveillance de connaissances

$script:ConfigPath = Join-Path $PSScriptRoot "..\config\config.json"
$script:Config = $null

function Get-KWConfig {
    if (-not $script:Config) {
        $script:Config = Get-Content $script:ConfigPath -Raw | ConvertFrom-Json
    }
    return $script:Config
}

function Write-KWLog {
    param(
        [string]$Message,
        [ValidateSet('INFO','WARN','ERROR')]
        [string]$Level = 'INFO'
    )

    $config = Get-KWConfig
    $logFile = Join-Path $config.paths.logDir "kwatch_$(Get-Date -Format 'yyyy-MM-dd').log"
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$timestamp] [$Level] $Message"

    Add-Content -Path $logFile -Value $entry -Encoding UTF8

    switch ($Level) {
        'INFO'  { Write-Host $entry -ForegroundColor Gray }
        'WARN'  { Write-Host $entry -ForegroundColor Yellow }
        'ERROR' { Write-Host $entry -ForegroundColor Red }
    }
}

function Add-ToQueue {
    param(
        [string]$FilePath,
        [string]$Source,
        [string]$EventType
    )

    $config = Get-KWConfig
    $queuePath = $config.paths.queueFile

    $queue = @()
    if (Test-Path $queuePath) {
        $content = Get-Content $queuePath -Raw -Encoding UTF8
        if ($content -and $content.Trim()) {
            $queue = $content | ConvertFrom-Json
        }
    }

    # Déduplication
    $existing = $queue | Where-Object { $_.filePath -eq $FilePath }
    if ($existing) {
        Write-KWLog "Fichier déjà en queue: $FilePath" -Level WARN
        return
    }

    $entry = @{
        id = [guid]::NewGuid().ToString()
        filePath = $FilePath
        source = $Source
        eventType = $EventType
        addedAt = (Get-Date).ToString("o")
        status = "pending"
    }

    $queue += $entry
    $queue | ConvertTo-Json -Depth 5 | Out-File -FilePath $queuePath -Encoding UTF8

    Write-KWLog "Ajouté à la queue: $FilePath ($Source)"
}

Export-ModuleMember -Function Get-KWConfig, Write-KWLog, Add-ToQueue
'@
    Write-Utf8WithBom -Path "$skillPath\scripts\KnowledgeWatcher.psm1" -Content $moduleContent

    # Start-KnowledgeWatcher.ps1
    $startWatcherContent = @'
# Start-KnowledgeWatcher.ps1
# Démarre les watchers temps réel (Tier 1)

param([switch]$Verbose)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Import module
Import-Module (Join-Path $scriptDir "KnowledgeWatcher.psm1") -Force

$config = Get-KWConfig
$sourcesPath = Join-Path (Split-Path $scriptDir) "config\sources.json"
$sources = Get-Content $sourcesPath -Raw | ConvertFrom-Json

Write-KWLog "Démarrage Knowledge Watcher..."

# Créer les watchers Tier 1
$watchers = @()
foreach ($source in $sources.tier1.sources) {
    if (-not (Test-Path $source.path)) {
        Write-KWLog "Chemin introuvable: $($source.path)" -Level WARN
        continue
    }

    $watcher = New-Object System.IO.FileSystemWatcher
    $watcher.Path = $source.path
    $watcher.Filter = "*.*"
    $watcher.IncludeSubdirectories = $true
    $watcher.EnableRaisingEvents = $true

    $action = {
        $path = $Event.SourceEventArgs.FullPath
        $name = $Event.SourceEventArgs.Name
        $changeType = $Event.SourceEventArgs.ChangeType

        # Ignorer certains fichiers
        if ($path -match '\.(tmp|bak|swp)$') { return }
        if ($path -match '\\\.git\\') { return }

        Import-Module (Join-Path $Event.MessageData.ScriptDir "KnowledgeWatcher.psm1") -Force
        Add-ToQueue -FilePath $path -Source $Event.MessageData.SourceName -EventType $changeType
    }

    $messageData = @{ ScriptDir = $scriptDir; SourceName = $source.name }

    Register-ObjectEvent -InputObject $watcher -EventName Created -Action $action -MessageData $messageData | Out-Null
    Register-ObjectEvent -InputObject $watcher -EventName Changed -Action $action -MessageData $messageData | Out-Null
    Register-ObjectEvent -InputObject $watcher -EventName Renamed -Action $action -MessageData $messageData | Out-Null

    $watchers += $watcher
    Write-KWLog "Watcher démarré: $($source.name) -> $($source.path)"
}

# Sauvegarder état
$statePath = $config.paths.stateFile
$state = @{
    watchers = @{
        pid = $PID
        startedAt = (Get-Date).ToString("o")
        count = $watchers.Count
    }
    lastProcessed = $null
}
$state | ConvertTo-Json -Depth 5 | Out-File -FilePath $statePath -Encoding UTF8

Write-KWLog "Knowledge Watcher actif - $($watchers.Count) watchers"
Write-Host "`nAppuyez sur Ctrl+C pour arrêter..." -ForegroundColor Yellow

# Boucle infinie
try {
    while ($true) { Start-Sleep -Seconds 60 }
} finally {
    foreach ($w in $watchers) { $w.Dispose() }
    Write-KWLog "Watchers arrêtés"
}
'@
    Write-Utf8WithBom -Path "$skillPath\scripts\Start-KnowledgeWatcher.ps1" -Content $startWatcherContent

    # Stop-KnowledgeWatcher.ps1
    $stopWatcherContent = @'
# Stop-KnowledgeWatcher.ps1
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module (Join-Path $scriptDir "KnowledgeWatcher.psm1") -Force

$config = Get-KWConfig
$statePath = $config.paths.stateFile

if (Test-Path $statePath) {
    $state = Get-Content $statePath -Raw | ConvertFrom-Json
    if ($state.watchers.pid) {
        try {
            Stop-Process -Id $state.watchers.pid -Force -ErrorAction Stop
            Write-KWLog "Processus $($state.watchers.pid) arrêté"
        } catch {
            Write-KWLog "Processus non trouvé: $($state.watchers.pid)" -Level WARN
        }
    }
}

# Reset state
@{ watchers = @{}; lastProcessed = $null } | ConvertTo-Json | Out-File -FilePath $statePath -Encoding UTF8
Write-Host "Knowledge Watcher arrêté" -ForegroundColor Green
'@
    Write-Utf8WithBom -Path "$skillPath\scripts\Stop-KnowledgeWatcher.ps1" -Content $stopWatcherContent

    # Commandes
    @"
# /kwatch-start

## Description
Démarre les watchers temps réel (Tier 1).

## Utilisation
``````
/kwatch-start
``````

## Action
Exécute:
``````powershell
& "$env:USERPROFILE\.claude\skills\knowledge-watcher-skill\scripts\Start-KnowledgeWatcher.ps1"
``````

Note: Nécessite un terminal ouvert. Utilisez Ctrl+C pour arrêter.
"@ | Out-File -FilePath "$skillPath\commands\start.md" -Encoding UTF8

    @"
# /kwatch-status

## Description
Affiche le dashboard de Knowledge Watcher.

## Utilisation
``````
/kwatch-status
``````

## Informations affichées
- État des watchers (actif/inactif)
- Nombre d'éléments en queue
- Dernière exécution par tier
- Statistiques de capture
"@ | Out-File -FilePath "$skillPath\commands\status.md" -Encoding UTF8

    Write-Success "Installé: knowledge-watcher-skill"
}

function Install-ObsidianSkill {
    Write-Step "Installation: obsidian-skill"

    $skillPath = Join-Path $Config.SkillsDir "obsidian-skill"

    if (Test-Path $skillPath) {
        Write-Success "Déjà installé: $skillPath"
        return
    }

    New-Item -ItemType Directory -Path $skillPath -Force | Out-Null
    New-Item -ItemType Directory -Path "$skillPath\commands" -Force | Out-Null
    New-Item -ItemType Directory -Path "$skillPath\wizards" -Force | Out-Null

    @"
# Obsidian Skill - Administration Vault

## Description
Agent pour administrer et maintenir un vault Obsidian.

## Vault Path
``$env:USERPROFILE\Documents\Knowledge``

## Commandes
| Commande | Description |
|----------|-------------|
| /obs-health | Diagnostic complet du vault |
| /obs-links | Gestion des liens (broken, orphans) |
| /obs-tags | Analyse et nettoyage des tags |
| /obs-clean | Nettoyage fichiers inutiles |

## Tags
#obsidian #pkm #maintenance
"@ | Out-File -FilePath "$skillPath\SKILL.md" -Encoding UTF8

    Write-Success "Installé: obsidian-skill"
}

function Install-FileorgSkill {
    Write-Step "Installation: fileorg-skill"

    $skillPath = Join-Path $Config.SkillsDir "fileorg-skill"

    if (Test-Path $skillPath) {
        Write-Success "Déjà installé: $skillPath"
        return
    }

    New-Item -ItemType Directory -Path $skillPath -Force | Out-Null
    New-Item -ItemType Directory -Path "$skillPath\commands" -Force | Out-Null
    New-Item -ItemType Directory -Path "$skillPath\wizards" -Force | Out-Null

    @"
# FileOrg Skill - Organisation de Fichiers

## Description
Agent pour organiser les fichiers selon la convention ISO 8601.

## Convention de Nommage
``````
[DATE]_[CATEGORIE]_[DESCRIPTION]_[VERSION].[EXT]
``````

Exemples:
- ``2026-02-05_Facture_Multipass-Design_v01.pdf``
- ``2026-02-05_Photo_Vacances-Paris_001.jpg``

## Commandes
| Commande | Description |
|----------|-------------|
| /file-organize | Organiser un dossier |
| /file-rename | Renommer selon convention |
| /file-analyze | Analyser structure |
| /file-duplicates | Trouver doublons |

## Tags
#files #organization #iso8601
"@ | Out-File -FilePath "$skillPath\SKILL.md" -Encoding UTF8

    Write-Success "Installé: fileorg-skill"
}

# ============================================================================
# INSTALLATION MCP SERVER
# ============================================================================

function Install-MCPServer {
    if ($SkipMCP) {
        Write-Step "MCP Server: ignoré (--SkipMCP)"
        return
    }

    Write-Step "Installation: knowledge-assistant MCP Server"

    $mcpPath = Join-Path $Config.MCPDir "knowledge-assistant"

    if (Test-Path $mcpPath) {
        Write-Success "Déjà installé: $mcpPath"
    } else {
        # Clone depuis GitHub
        try {
            git clone $Config.MCPRepoUrl $mcpPath 2>&1 | Out-Null
            Write-Success "Cloné: $($Config.MCPRepoUrl)"
        } catch {
            Write-Warning "Clone échoué, création manuelle..."
            New-Item -ItemType Directory -Path $mcpPath -Force | Out-Null
            New-Item -ItemType Directory -Path "$mcpPath\src" -Force | Out-Null

            # Créer pyproject.toml
            @"
[project]
name = "knowledge-assistant"
version = "1.0.0"
requires-python = ">=3.10"
dependencies = [
    "mcp>=1.0.0",
    "pyyaml>=6.0",
]

[project.scripts]
knowledge-assistant = "src.server:main"
"@ | Out-File -FilePath "$mcpPath\pyproject.toml" -Encoding UTF8

            # __init__.py
            "" | Out-File -FilePath "$mcpPath\src\__init__.py" -Encoding UTF8

            Write-Success "Structure MCP créée manuellement"
        }
    }

    # Mettre à jour les chemins dans server.py si existe
    $serverPy = Join-Path $mcpPath "src\server.py"
    if (Test-Path $serverPy) {
        $content = Get-Content $serverPy -Raw
        $content = $content -replace 'C:\\Users\\r2d2\\', "$env:USERPROFILE\"
        $content | Out-File -FilePath $serverPy -Encoding UTF8
        Write-Success "Chemins adaptés dans server.py"
    }
}

# ============================================================================
# CONFIGURATION SETTINGS
# ============================================================================

function Update-Settings {
    Write-Step "Configuration: settings.json"

    $settingsPath = Join-Path $Config.ClaudeDir "settings.json"

    $settings = @{
        autoUpdatesChannel = "latest"
    }

    if (-not $SkipMCP) {
        $mcpPath = Join-Path $Config.MCPDir "knowledge-assistant"
        $settings.mcpServers = @{
            "knowledge-assistant" = @{
                type = "stdio"
                command = "uv"
                args = @(
                    "run",
                    "--directory",
                    $mcpPath,
                    "python",
                    "-m",
                    "src.server"
                )
            }
        }
    }

    $settings | ConvertTo-Json -Depth 5 | Out-File -FilePath $settingsPath -Encoding UTF8
    Write-Success "settings.json configuré"
}

# ============================================================================
# TEMPLATES OBSIDIAN
# ============================================================================

function Install-ObsidianTemplates {
    Write-Step "Installation: Templates Obsidian"

    $templatesPath = Join-Path $Config.VaultPath "_Templates"

    # Template Concept
    @"
---
title: "{{title}}"
date: {{date}}
type: concept
tags:
  - concept
related: []
---

# {{title}}

## Définition


## Points Clés
-

## Liens
-

## Références
-
"@ | Out-File -FilePath "$templatesPath\Template-Concept.md" -Encoding UTF8

    # Template Conversation
    @"
---
title: "{{title}}"
date: {{date}}
type: conversation
tags:
  - dev/claude-code
related: []
---

# {{title}}

## Résumé


## Points Clés
-

## Code


## Liens
-
"@ | Out-File -FilePath "$templatesPath\Template-Conversation.md" -Encoding UTF8

    # Template Daily
    @"
---
title: "{{date}}"
date: {{date}}
type: daily
tags:
  - daily
---

# {{date}}

## Objectifs
- [ ]

## Notes


## Liens créés
-

## Réflexions

"@ | Out-File -FilePath "$templatesPath\Template-Daily.md" -Encoding UTF8

    # Template Troubleshooting
    @"
---
title: "Fix: {{title}}"
date: {{date}}
type: troubleshooting
tags:
  - troubleshooting
related: []
---

# Fix: {{title}}

## Problème


## Cause


## Solution


## Prévention

"@ | Out-File -FilePath "$templatesPath\Template-Troubleshooting.md" -Encoding UTF8

    Write-Success "Templates installés: Concept, Conversation, Daily, Troubleshooting"
}

# ============================================================================
# TÂCHES PLANIFIÉES
# ============================================================================

function Register-ScheduledTasks {
    if ($SkipScheduledTasks) {
        Write-Step "Tâches planifiées: ignorées (--SkipScheduledTasks)"
        return
    }

    Write-Step "Enregistrement: Tâches planifiées Windows"

    $skillPath = Join-Path $Config.SkillsDir "knowledge-watcher-skill"
    $scriptsPath = Join-Path $skillPath "scripts\scheduled"

    # Créer les scripts scheduled s'ils n'existent pas
    if (-not (Test-Path $scriptsPath)) {
        New-Item -ItemType Directory -Path $scriptsPath -Force | Out-Null
    }

    # Tier 2 - Hourly
    $tier2Content = @'
# KnowledgeWatcher-Tier2-Hourly.ps1
$skillPath = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Import-Module (Join-Path $skillPath "scripts\KnowledgeWatcher.psm1") -Force
Write-KWLog "Tier 2 (Hourly) - Démarrage"
# TODO: Implémenter traitement Downloads, Formations
Write-KWLog "Tier 2 (Hourly) - Terminé"
'@
    Write-Utf8WithBom -Path "$scriptsPath\KnowledgeWatcher-Tier2-Hourly.ps1" -Content $tier2Content

    # Tier 3 - Daily
    $tier3Content = @'
# KnowledgeWatcher-Tier3-Daily.ps1
$skillPath = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Import-Module (Join-Path $skillPath "scripts\KnowledgeWatcher.psm1") -Force
Write-KWLog "Tier 3 (Daily) - Démarrage"
# TODO: Implémenter traitement Bookmarks, Scripts
Write-KWLog "Tier 3 (Daily) - Terminé"
'@
    Write-Utf8WithBom -Path "$scriptsPath\KnowledgeWatcher-Tier3-Daily.ps1" -Content $tier3Content

    # Tier 4 - Weekly
    $tier4Content = @'
# KnowledgeWatcher-Tier4-Weekly.ps1
$skillPath = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Import-Module (Join-Path $skillPath "scripts\KnowledgeWatcher.psm1") -Force
Write-KWLog "Tier 4 (Weekly) - Démarrage"
# TODO: Implémenter traitement Archives
Write-KWLog "Tier 4 (Weekly) - Terminé"
'@
    Write-Utf8WithBom -Path "$scriptsPath\KnowledgeWatcher-Tier4-Weekly.ps1" -Content $tier4Content

    # Enregistrer les tâches (nécessite élévation)
    $tasks = @(
        @{
            Name = "KnowledgeWatcher-Tier2-Hourly"
            Script = "$scriptsPath\KnowledgeWatcher-Tier2-Hourly.ps1"
            Trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Hours 1)
        },
        @{
            Name = "KnowledgeWatcher-Tier3-Daily"
            Script = "$scriptsPath\KnowledgeWatcher-Tier3-Daily.ps1"
            Trigger = New-ScheduledTaskTrigger -Daily -At "06:00"
        },
        @{
            Name = "KnowledgeWatcher-Tier4-Weekly"
            Script = "$scriptsPath\KnowledgeWatcher-Tier4-Weekly.ps1"
            Trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At "03:00"
        }
    )

    foreach ($task in $tasks) {
        try {
            $existingTask = Get-ScheduledTask -TaskName $task.Name -ErrorAction SilentlyContinue
            if ($existingTask) {
                Write-Success "Tâche existe: $($task.Name)"
                continue
            }

            $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$($task.Script)`""
            Register-ScheduledTask -TaskName $task.Name -Trigger $task.Trigger -Action $action -RunLevel Limited -User $env:USERNAME | Out-Null
            Write-Success "Tâche créée: $($task.Name)"
        } catch {
            Write-Warning "Échec création tâche $($task.Name): $_"
        }
    }
}

# ============================================================================
# MEMORY.md
# ============================================================================

function Create-MemoryFile {
    Write-Step "Création: MEMORY.md"

    $memoryDir = Join-Path $Config.ClaudeDir "projects\$($env:COMPUTERNAME)"
    if (-not (Test-Path $memoryDir)) {
        New-Item -ItemType Directory -Path $memoryDir -Force | Out-Null
    }

    $memoryPath = Join-Path $memoryDir "memory\MEMORY.md"
    $memoryFolder = Split-Path $memoryPath -Parent
    if (-not (Test-Path $memoryFolder)) {
        New-Item -ItemType Directory -Path $memoryFolder -Force | Out-Null
    }

    @"
# Memory - $env:COMPUTERNAME Workspace

## User Context
- **OS**: Windows 11
- **Date Installation**: $(Get-Date -Format 'yyyy-MM-dd')

## Key Paths
- **Obsidian Vault**: ``$($Config.VaultPath)``
- **Skills**: ``$($Config.SkillsDir)``
- **Projects**: ``$($Config.ProjetsPath)``

## Installed Skills
| Skill | Purpose | Commands |
|-------|---------|----------|
| windows-skill | Windows diagnostics | /win-* |
| fileorg-skill | File organization | /fileorg-* |
| obsidian-skill | Obsidian vault management | /obs-* |
| knowledge-skill | Save conversations to Obsidian | /know-* |
| knowledge-watcher-skill | Auto-capture data to Obsidian | /kwatch-* |
| proxmox-skill | Proxmox VM management | /proxmox-* |

## Knowledge Watcher
- **Status**: Installed
- **Location**: ``.claude/skills/knowledge-watcher-skill/``

### Commands
- ``/kwatch-start`` - Start real-time watchers
- ``/kwatch-stop`` - Stop watchers
- ``/kwatch-status`` - Show dashboard
- ``/kwatch-process`` - Process queue manually

## Obsidian Vault Structure
``````
Knowledge/
├── _Attachments/   # Images, files
├── _Daily/         # Daily notes
├── _Inbox/         # New captures
├── _Index/         # Navigation
├── _Templates/     # Templates
├── Code/           # Code snippets
├── Concepts/       # Atomic concepts (C_*)
├── Conversations/  # Claude sessions
├── Formations/     # Learning materials
├── Projets/        # Project notes
└── Références/     # Reference docs
``````

## Technical Notes

### PowerShell UTF-8
- Use BOM for .ps1 files (required for PS 5.1)
- Use no-BOM for data files (.md, .json)
"@ | Out-File -FilePath $memoryPath -Encoding UTF8

    Write-Success "MEMORY.md créé: $memoryPath"
}

# ============================================================================
# MAIN
# ============================================================================

function Main {
    Write-Host @"

╔══════════════════════════════════════════════════════════════╗
║       Claude Code Setup Installer v$script:InstallerVersion                 ║
║       Installation complète des Skills et MCP Servers        ║
╚══════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Magenta

    Write-Host "Configuration:" -ForegroundColor White
    Write-Host "  Vault Obsidian: $($Config.VaultPath)"
    Write-Host "  Skills: $($Config.SkillsDir)"
    Write-Host "  MCP Servers: $($Config.MCPDir)"
    Write-Host ""

    # Exécution
    Test-Prerequisites
    Initialize-DirectoryStructure
    Install-UvPackageManager

    # Skills
    Install-WindowsSkill
    Install-ProxmoxSkill
    Install-KnowledgeSkill
    Install-KnowledgeWatcherSkill
    Install-ObsidianSkill
    Install-FileorgSkill

    # MCP
    Install-MCPServer

    # Configuration
    Update-Settings
    Install-ObsidianTemplates
    Register-ScheduledTasks
    Create-MemoryFile

    Write-Host @"

╔══════════════════════════════════════════════════════════════╗
║                    Installation terminée!                    ║
╚══════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Green

    Write-Host "Prochaines étapes:" -ForegroundColor Yellow
    Write-Host "  1. Redémarrer Claude Code pour charger les skills"
    Write-Host "  2. Tester avec: /win-diagnostic"
    Write-Host "  3. Démarrer le watcher: /kwatch-start"
    Write-Host ""
    Write-Host "Documentation: $($Config.SkillsDir)" -ForegroundColor Cyan
}

# Lancer
Main

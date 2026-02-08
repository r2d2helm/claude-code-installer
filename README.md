# Claude Code Setup Installer

Script d'installation automatique pour reproduire la configuration Claude Code complète sur une nouvelle machine.

## Contenu installé

### Skills (10)
| Skill | Prefixe | Commandes | Wizards | Description |
|-------|---------|-----------|---------|-------------|
| **proxmox-skill** | `/px-*` | 21 | 11 | Administration Proxmox VE 9+ |
| **windows-skill** | `/win-*` | 36 | 10 | Administration Windows 11/Server 2025 |
| **docker-skill** | `/dk-*` | 10 | 3 | Administration Docker et conteneurs |
| **linux-skill** | `/lx-*` | 12 | 3 | Administration serveurs Linux |
| **knowledge-skill** | `/know-*` | 3 | - | Capture et sauvegarde de connaissances |
| **knowledge-watcher** | `/kwatch-*` | 6 | 2 | Surveillance automatique multi-sources |
| **obsidian-skill** | `/obs-*` | 8 | - | Maintenance vault Obsidian |
| **fileorg-skill** | `/file-*` | 9 | - | Organisation fichiers ISO 8601 |
| **vault-guardian** | `/guardian-*` | 3 | - | Maintenance proactive automatisee |
| **meta-router** | `/router`, `/agents`, `/context`, `/infra` | 4 | - | Routage intelligent entre skills |

> **Total : 10 skills, 112 commandes, 29 wizards**

### MCP Server
- **knowledge-assistant** : Recherche dans vault Obsidian avec logique AND multi-termes

### Templates Obsidian
- Concept, Conversation, Daily, Troubleshooting

### Taches planifiees
- Tier 2 (Hourly) : Downloads, Formations
- Tier 3 (Daily 6h) : Bookmarks, Scripts
- Tier 4 (Weekly dim 3h) : Archives

## Prerequis

- Windows 11 23H2+ ou Windows Server 2022/2025
- PowerShell 5.1+ (7.4+ recommande)
- Git
- Python 3.10+ (pour MCP server)
- Claude CLI installe

## Installation

### Option 1 : Telechargement direct

```powershell
# Telecharger le script
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/r2d2helm/claude-code-installer/master/Install-ClaudeCodeSetup.ps1" -OutFile "Install-ClaudeCodeSetup.ps1"

# Executer
.\Install-ClaudeCodeSetup.ps1
```

### Option 2 : Clone du repo

```powershell
git clone https://github.com/r2d2helm/claude-code-installer.git
cd claude-code-installer
.\Install-ClaudeCodeSetup.ps1
```

## Parametres

| Parametre | Description | Defaut |
|-----------|-------------|--------|
| `-VaultPath` | Chemin du vault Obsidian | `$env:USERPROFILE\Documents\Knowledge` |
| `-BasePath` | Repertoire de base pour l'installation | `$env:USERPROFILE` |
| `-SkipScheduledTasks` | Ne pas creer les taches planifiees | `$false` |
| `-SkipMCP` | Ne pas installer le serveur MCP | `$false` |
| `-TestMode` | Mode test (ignore prerequis, skip uv) | `$false` |

## Exemples d'utilisation

```powershell
# Installation standard
.\Install-ClaudeCodeSetup.ps1

# Vault Obsidian personnalise
.\Install-ClaudeCodeSetup.ps1 -VaultPath "D:\MonVault"

# Installation dans un repertoire personnalise
.\Install-ClaudeCodeSetup.ps1 -BasePath "D:\MonProfil"

# Sans taches planifiees
.\Install-ClaudeCodeSetup.ps1 -SkipScheduledTasks

# Sans serveur MCP
.\Install-ClaudeCodeSetup.ps1 -SkipMCP

# Test en environnement isole
.\Install-ClaudeCodeSetup.ps1 -BasePath "C:\Temp\test" -TestMode -SkipScheduledTasks -SkipMCP
```

## Structure creee

```
{BasePath}\
├── .claude\
│   ├── settings.json           # Configuration MCP
│   ├── skills\                 # 10 skills
│   │   ├── SKILL.md            # Meta-Agent Router
│   │   ├── commands\           # Commandes globales (router, agents, context, infra)
│   │   ├── know-save\          # /know-save
│   │   │   └── SKILL.md
│   │   ├── windows-skill\      # /win-* (36 cmd, 10 wizards)
│   │   ├── proxmox-skill\      # /px-* (21 cmd, 11 wizards)
│   │   ├── docker-skill\       # /dk-* (10 cmd, 3 wizards)
│   │   ├── linux-skill\        # /lx-* (12 cmd, 3 wizards)
│   │   ├── knowledge-watcher-skill\  # /kwatch-* (6 cmd, 2 wizards)
│   │   ├── obsidian-skill\     # /obs-* (8 cmd)
│   │   ├── fileorg-skill\      # /file-* (9 cmd)
│   │   └── vault-guardian-skill\  # /guardian-* (3 cmd)
│   ├── mcp-servers\
│   │   └── knowledge-assistant\
│   └── projects\
│       └── {COMPUTERNAME}\
│           └── memory\
│               └── MEMORY.md
├── .local\
│   └── bin\
│       └── claude.exe          # Claude CLI (non installe par ce script)
└── Documents\
    ├── Knowledge\              # Vault Obsidian
    │   ├── _Attachments\
    │   ├── _Daily\
    │   ├── _Inbox\
    │   ├── _Index\
    │   ├── _Templates\         # 4 templates
    │   ├── Code\
    │   ├── Concepts\
    │   ├── Conversations\
    │   ├── Formations\
    │   ├── Projets\
    │   └── References\
    └── Projets\
```

## Format des Skills

Les skills utilisent le format standalone de Claude Code :

```
.claude/skills/<skill-name>/SKILL.md -> /skill-name
```

Exemple : `.claude/skills/know-save/SKILL.md` -> commande `/know-save`

## Post-installation

1. **Redemarrer Claude Code** pour charger les skills
2. **Tester** : `/know-save` ou `/win-diagnostic`
3. **Demarrer le watcher** : `/kwatch-start`

## Depannage

### PowerShell Execution Policy
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Claude CLI non trouve
Installer depuis : https://claude.ai/code

### Taches planifiees echouent
Executer en tant qu'administrateur pour creer les taches.

### Caracteres accentues mal affiches
Le script utilise UTF-8. Si les accents sont mal affiches, verifiez l'encodage de votre terminal :
```powershell
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
```

## Changelog

### v1.1.0 (2026-02-08)
- Ajout de 4 skills: docker-skill, linux-skill, vault-guardian-skill, meta-router
- Total: 10 skills, 112 commandes, 29 wizards
- Mise a jour MEMORY.md avec tous les skills
- Correction compteur proxmox-skill (20 -> 21 commandes)

### v1.0.0 (2026-02-05)
- Installation des 6 skills
- Installation MCP server knowledge-assistant
- Templates Obsidian
- Taches planifiees Knowledge Watcher
- Support `-BasePath` et `-TestMode` pour tests isoles
- Compatible PowerShell 5.1 (UTF-8 BOM)

## Licence

MIT

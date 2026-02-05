# Claude Code Setup Installer

Script d'installation automatique pour reproduire la configuration Claude Code complète sur une nouvelle machine.

## Contenu installé

### Skills (6)
| Skill | Description | Commande |
|-------|-------------|----------|
| **know-save** | Sauvegarder conversations vers Obsidian | `/know-save` |
| **windows-skill** | Administration Windows 11/Server | `/win-*` |
| **proxmox-skill** | Gestion Proxmox VE 9+ | `/pve-*` |
| **knowledge-watcher-skill** | Surveillance automatique multi-sources | `/kwatch-*` |
| **obsidian-skill** | Administration vault Obsidian | `/obs-*` |
| **fileorg-skill** | Organisation fichiers ISO 8601 | `/file-*` |

### MCP Server
- **knowledge-assistant** : Recherche dans vault Obsidian avec logique AND multi-termes

### Templates Obsidian
- Concept, Conversation, Daily, Troubleshooting

### Tâches planifiées
- Tier 2 (Hourly) : Downloads, Formations
- Tier 3 (Daily 6h) : Bookmarks, Scripts
- Tier 4 (Weekly dim 3h) : Archives

## Prérequis

- Windows 11 23H2+ ou Windows Server 2022/2025
- PowerShell 5.1+ (7.4+ recommandé)
- Git
- Python 3.10+ (pour MCP server)
- Claude CLI installé

## Installation

### Option 1 : Téléchargement direct

```powershell
# Télécharger le script
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/r2d2helm/claude-code-installer/main/Install-ClaudeCodeSetup.ps1" -OutFile "Install-ClaudeCodeSetup.ps1"

# Exécuter
.\Install-ClaudeCodeSetup.ps1
```

### Option 2 : Clone du repo

```powershell
git clone https://github.com/r2d2helm/claude-code-installer.git
cd claude-code-installer
.\Install-ClaudeCodeSetup.ps1
```

## Paramètres

| Paramètre | Description | Défaut |
|-----------|-------------|--------|
| `-VaultPath` | Chemin du vault Obsidian | `$env:USERPROFILE\Documents\Knowledge` |
| `-BasePath` | Répertoire de base pour l'installation | `$env:USERPROFILE` |
| `-SkipScheduledTasks` | Ne pas créer les tâches planifiées | `$false` |
| `-SkipMCP` | Ne pas installer le serveur MCP | `$false` |
| `-TestMode` | Mode test (ignore prérequis, skip uv) | `$false` |

## Exemples d'utilisation

```powershell
# Installation standard
.\Install-ClaudeCodeSetup.ps1

# Vault Obsidian personnalisé
.\Install-ClaudeCodeSetup.ps1 -VaultPath "D:\MonVault"

# Installation dans un répertoire personnalisé
.\Install-ClaudeCodeSetup.ps1 -BasePath "D:\MonProfil"

# Sans tâches planifiées
.\Install-ClaudeCodeSetup.ps1 -SkipScheduledTasks

# Sans serveur MCP
.\Install-ClaudeCodeSetup.ps1 -SkipMCP

# Test en environnement isolé
.\Install-ClaudeCodeSetup.ps1 -BasePath "C:\Temp\test" -TestMode -SkipScheduledTasks -SkipMCP
```

## Structure créée

```
{BasePath}\
├── .claude\
│   ├── settings.json           # Configuration MCP
│   ├── skills\                 # 6 skills
│   │   ├── know-save\          # /know-save
│   │   │   └── SKILL.md
│   │   ├── windows-skill\
│   │   ├── proxmox-skill\
│   │   ├── knowledge-watcher-skill\
│   │   ├── obsidian-skill\
│   │   └── fileorg-skill\
│   ├── mcp-servers\
│   │   └── knowledge-assistant\
│   └── projects\
│       └── {COMPUTERNAME}\
│           └── memory\
│               └── MEMORY.md
├── .local\
│   └── bin\
│       └── claude.exe          # Claude CLI (non installé par ce script)
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
    │   └── Références\
    └── Projets\
```

## Format des Skills

Les skills utilisent le format standalone de Claude Code :

```
.claude/skills/<skill-name>/SKILL.md → /skill-name
```

Exemple : `.claude/skills/know-save/SKILL.md` → commande `/know-save`

## Post-installation

1. **Redémarrer Claude Code** pour charger les skills
2. **Tester** : `/know-save` ou `/win-diagnostic`
3. **Démarrer le watcher** : `/kwatch-start`

## Dépannage

### PowerShell Execution Policy
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Claude CLI non trouvé
Installer depuis : https://claude.ai/code

### Tâches planifiées échouent
Exécuter en tant qu'administrateur pour créer les tâches.

### Caractères accentués mal affichés
Le script utilise UTF-8. Si les accents sont mal affichés, vérifiez l'encodage de votre terminal :
```powershell
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
```

## Changelog

### v1.0.0 (2026-02-05)
- Installation des 6 skills
- Installation MCP server knowledge-assistant
- Templates Obsidian
- Tâches planifiées Knowledge Watcher
- Support `-BasePath` et `-TestMode` pour tests isolés
- Compatible PowerShell 5.1 (UTF-8 BOM)

## Licence

MIT

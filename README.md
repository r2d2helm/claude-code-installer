# Claude Code Setup Installer

Script d'installation automatique pour reproduire la configuration Claude Code complète sur une nouvelle machine.

## Contenu installé

### Skills (6)
| Skill | Description | Commandes |
|-------|-------------|-----------|
| **windows-skill** | Administration Windows 11/Server | `/win-*` |
| **proxmox-skill** | Gestion Proxmox VE 9+ | `/pve-*` |
| **knowledge-skill** | Capture connaissances (méthode CODE) | `/know-*` |
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

## Options

```powershell
# Installation standard
.\Install-ClaudeCodeSetup.ps1

# Vault Obsidian personnalisé
.\Install-ClaudeCodeSetup.ps1 -VaultPath "D:\MonVault"

# Sans tâches planifiées
.\Install-ClaudeCodeSetup.ps1 -SkipScheduledTasks

# Sans serveur MCP
.\Install-ClaudeCodeSetup.ps1 -SkipMCP
```

## Structure créée

```
C:\Users\{USER}\
├── .claude\
│   ├── settings.json           # Configuration MCP
│   ├── skills\                 # 6 skills
│   │   ├── windows-skill\
│   │   ├── proxmox-skill\
│   │   ├── knowledge-skill\
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
│       └── claude.exe          # Claude CLI
└── Documents\
    └── Knowledge\              # Vault Obsidian
        ├── _Attachments\
        ├── _Daily\
        ├── _Inbox\
        ├── _Index\
        ├── _Templates\
        ├── Code\
        ├── Concepts\
        ├── Conversations\
        ├── Formations\
        ├── Projets\
        └── Références\
```

## Post-installation

1. **Redémarrer Claude Code** pour charger les skills
2. **Tester** : `/win-diagnostic`
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

## Licence

MIT

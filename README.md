# CyAIAssistant — AI Coding Assistant for the Delphi IDE

![Delphi](https://img.shields.io/badge/Delphi-11%2B-EE1F35?logo=delphi&logoColor=white)
![License](https://img.shields.io/badge/License-GPL--2.0-blue)
![Platform](https://img.shields.io/badge/Platform-Windows-0078D4?logo=windows)

CyAIAssistant is an Open Tools API plugin for Delphi 11+ that brings AI-assisted coding directly into the IDE. Select code, describe what you need, and get a result — without leaving the editor.

---

## Why This Exists

This plugin is a personal learning project. The goal was to explore different ways to integrate AI into a real Delphi development workflow — not just as a chat window, but as something that actually operates on source files and fits naturally into the way the IDE works.

Several approaches are covered:

- **Direct API calls** — sending code to Anthropic Claude, OpenAI, Groq, Mistral or a local Ollama instance and applying the result inside the IDE
- **Agentic AI via Claude Code** — running Claude Code in an isolated VM, letting it operate freely on a copy of the source code, and syncing results back to the development machine over SFTP

The SFTP sync feature was built specifically for the Claude Code use case. Rather than giving an agentic AI direct access to the development machine, the project files are mirrored to a VM over SFTP. Claude Code runs inside the VM, makes changes, and those changes are automatically detected and synced back. The development machine and the AI remain isolated from each other — the SFTP connection is the only bridge.

---

## Features

### Code Assistant — Refactor & Transform Selected Code

Select any code in the editor, open the Code Assistant, and apply an AI transformation.

- **Built-in prompt library** — common tasks like *Add XML doc comments*, *Write unit tests*, *Refactor to use generics*, *Convert to async*, and more, ready with a single click
- **Custom prefix** — prepend your own instructions to any built-in prompt for fine-grained control
- **Side-by-side diff viewer** — before anything is written back, a diff shows exactly what changed, with a unified diff and an editable result view
- **Apply or discard** — one click to apply the result to the editor, or close without touching your code
- Menu entry is only enabled when a source file is open in the editor

---

### AI Chat — Multi-Turn Conversation

A persistent chat window for open-ended work with the AI.

- Full **multi-turn conversation history** — the AI remembers what was said earlier in the session
- **Automatic file detection** — when the AI generates Delphi source files, they are automatically extracted and listed
- **Save individual files** or **save all** to a folder with a single click
- **Open in IDE** — detected files can be saved and immediately opened in the Delphi editor
- **Stop button** — cancel a running request at any time

---

### Unit / Class Assistant — Generate Complete Units from a Description

Describe what you need and let the AI write the whole unit.

- Choose from predefined styles: *Full Unit*, *Class Only*, *Interface + Stub*, *Unit Tests*, or *Free Prompt*
- Preview the generated code before creating the unit
- **Create Unit in IDE** — injects the generated code directly into a new editor window
- Editable result — tweak the AI output in-place before accepting it

---

### SFTP Sync — Isolated AI Agent Workflow

This is the centrepiece of the Claude Code integration. The sync engine mirrors the active Delphi project to a remote directory over SFTP and keeps both sides in sync bidirectionally.

#### How it works

1. On start, all project files matching the configured extensions are uploaded to the remote folder
2. A background task runs on a configurable interval (default: 5 seconds)
3. Each cycle connects to the SFTP server, collects a file list with timestamps from both sides, compares them, and copies newer files in either direction
4. A local file watcher (`FindFirstChangeNotification`) triggers an immediate extra cycle whenever a project file is saved locally, so edits reach the remote side within about half a second
5. A timestamp cache persists across stop/start cycles (stored in `CyAiAssistant.sync`) so the engine never re-syncs files that are already in sync

#### Why SFTP for Claude Code?

Claude Code is a powerful agentic tool — it reads, writes and refactors files autonomously. That capability is exactly what makes direct access to the development machine undesirable during experimentation. The SFTP sync solves this by:

- Keeping Claude Code fully confined inside a VM
- Giving it a working copy of exactly the files it needs, nothing more
- Automatically reflecting its changes back to the development machine
- Allowing the developer to review diffs in the IDE before using any AI-generated code

The result is a workflow where Claude Code can do deep multi-file refactoring inside the VM while the developer retains full control over what gets applied to the real project.

#### Settings

All SFTP settings are stored in `CyAiAssistant.sync` in the project folder — not in the registry — so the configuration travels with the project and can be committed to version control (with the password field cleared).

| Setting | Description |
|---|---|
| Host / Port | SFTP server address |
| Username / Password | Credentials (or private key path for key-based auth) |
| Local folder | Project folder to sync (auto-detected from the open IDE project) |
| Remote folder | Target path on the SFTP server |
| Interval | Sync cycle interval in seconds |
| Include subdirectories | Whether to recurse into subdirectories |
| Watched extensions | Which file types to sync (space or comma separated, e.g. `.pas .dfm .dproj`) |
| Remote file permissions | Unix permission bits applied to uploaded files and created directories |

---

### Settings Dialog

All AI provider configuration in one place:

- API keys and endpoints for each provider
- Model selection with editable model name per provider
- Ollama model browser — load available local models and test connectivity
- **Custom Prompt Manager** — create, edit, reorder and delete your own named prompts
- Global defaults: max tokens, temperature

---

### AI Providers

| Provider | Notes |
|---|---|
| **Anthropic Claude** | claude-opus-4-5, claude-sonnet-4-5, and others |
| **OpenAI** | gpt-4o, gpt-4-turbo, and others |
| **Ollama** | Any locally hosted model — fully offline, nothing leaves the machine |
| **Groq** | llama3-70b, mixtral-8x7b, and others |
| **Mistral AI** | mistral-large, codestral, and others |

---

### IDE Theme Integration

CyAIAssistant follows the active Delphi IDE theme automatically. Full support for dark and light themes — link colors, panel backgrounds and labels all adapt. No jarring white windows in a dark IDE.

---

## Requirements

- Delphi 11 Alexandria or later
- Windows 10 / 11
- An API key for at least one supported provider, **or** a locally running [Ollama](https://ollama.ai) instance for fully offline use
- For SFTP sync: an SFTP server accessible from the development machine (a Linux VM with OpenSSH works well)

---

## Dependencies

- [SSH-Pascal](https://github.com/pyscripter/Ssh-Pascal) — SSH/SFTP library used by the sync engine (`Ssh2Client.pas`, `SftpClient.pas`)

---

## Installation

1. Clone or download this repository
2. Open `CyAIAssistant.dpk` in Delphi
3. Right-click the package in the Project Manager and choose **Install**
4. The *Cypheros AI Assistant* menu entry appears under **Tools** in the IDE
5. Open **Tools → Cypheros AI Assistant → Settings** and enter your API key(s)
6. The libssh2.dll file required for SFTP sync is copied to the Bpl directory during installation. If you don't want this to happen, disable the post-build event

---

## Usage

| Task | How |
|---|---|
| Refactor or transform selected code | Select code → **Tools → Cypheros AI Assistant → Code Assistant** |
| Open AI chat | **Tools → Cypheros AI Assistant → AI Chat** |
| Generate a new unit or class | **Tools → Cypheros AI Assistant → Unit/Class Assistant** |
| Configure SFTP sync | **Tools → Cypheros AI Assistant → SFTP Sync** (requires an open project) |
| Configure providers and prompts | **Tools → Cypheros AI Assistant → Settings** |

---

## The Claude Code VM Workflow in Practice

```
+-------------------------+        SFTP         +-------------------------+
|   Development Machine   | <-----------------> |          VM             |
|                         |                     |                         |
|  Delphi IDE             |   project files      |  Claude Code            |
|  CyAIAssistant plugin   | <-- sync ---------> |  (isolated, no access   |
|  Source code (master)   |                     |   to dev machine)       |
+-------------------------+                     +-------------------------+
```

1. Open project in Delphi IDE
2. Open **SFTP Sync**, configure the VM address and remote path, click **Start Sync**
3. The plugin uploads all project files to the VM
4. Inside the VM, run Claude Code on the synced folder — give it a task
5. Claude Code edits files freely inside the VM
6. CyAIAssistant detects the changes and syncs them back to the development machine within seconds
7. Review the changes in the IDE — use the diff viewer or the normal editor — and decide what to keep

---

## Privacy

- Your code is sent to the AI provider you configure. Review the privacy policy of your chosen provider before use.
- Using **Ollama** keeps all data local — nothing leaves your machine.
- When using the SFTP sync + VM approach, your source code only travels to your own VM — it never leaves your infrastructure.
- API keys are stored in the Windows registry under `HKCU\Software\Cypheros\CyAIAssistant` and are never transmitted anywhere other than the configured API endpoint.

---

## License

CyAIAssistant is released under the [GNU General Public License v2.0](https://www.gnu.org/licenses/old-licenses/gpl-2.0.html).

---

## About

Developed by **Cypheros** as a personal exploration of AI-assisted Delphi development.

[www.cypheros.de](https://www.cypheros.de)

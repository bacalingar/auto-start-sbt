# Project Startup Script

## What is it?

A Bash startup script for WSL (Windows Subsystem for Linux) that automates the process of launching a development project — opening VS Code, starting Docker containers, and opening the app in a browser once it's ready. It is designed to run on login or manually, and supports both interactive and automated modes.

---

## How it works

The script begins by waiting for two conditions to be met: the Windows desktop must be available (detected via `explorer.exe`) and Docker must be responsive. Only once both are ready does it proceed.

It reads a `current_project.txt` file to determine which project was last active. If a current project is recorded, it attempts to run that project automatically. If none is set, it lists available projects from the `~/GitHub` directory and prompts you to select one.

For the selected project, the script:

1. Navigates to the project directory under `~/GitHub/`
2. Confirms a `docker-compose.yml` file exists
3. Opens VS Code in that directory
4. Starts Docker containers via `docker compose up -d` if they aren't already running
5. Verifies that containers are actually running, retrying once if they fail
6. Reads `.env` for `VITE_APP_DOMAIN` and `VITE_PORT` to construct the app URL
7. Tails the `node` container logs and waits for a `webpack compiled successfully` message
8. Opens the app URL in the Windows browser via `explorer.exe`

After running a project interactively, it asks if you want to set it as the new current project, updating `current_project.txt` accordingly.

---

## How to use it

### Prerequisites

- WSL with Bash
- Docker Desktop (accessible from WSL)
- VS Code with the WSL extension and `code` available in PATH
- Projects stored under `~/GitHub/<project-name>/`
- A `scripts/` directory at `~/scripts/` containing `current_project.txt`

### Setup

Create the required supporting files if they don't exist:

```bash
mkdir -p ~/scripts
touch ~/scripts/current_project.txt
```

Make the script executable:

```bash
chmod +x ~/scripts/startup.sh
```

### Running manually

```bash
# Interactive mode — prompts to confirm and select project
~/scripts/startup.sh

# Auto mode — skips confirmation prompts, runs current project directly
~/scripts/startup.sh --auto
```

### Running on login

To run automatically when WSL starts, add this to your `~/.bashrc` or `~/.profile`:

```bash
~/scripts/startup.sh --auto
```

---

## Configuration

Each project's `.env` file should define the following variables for the browser launch to work:

```env
VITE_APP_DOMAIN=localhost
VITE_PORT=3000
```

If `VITE_PORT` is absent, the script opens the app on the domain alone without a port.

---

## Limitations

- **SBT projects only** — the script currently expects a `node` service in `docker-compose.yml` and listens for a `webpack compiled successfully` log message. Projects not using Webpack or not exposing a `node` service will not trigger the browser launch.
- Projects must live directly under `~/GitHub/` with no nesting beyond one level.
- The `.env` file must be in the project root alongside `docker-compose.yml`.

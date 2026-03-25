# Tool Usage Notes

Tool signatures are provided automatically via function calling.
This file documents non-obvious constraints and usage patterns.

## exec — Safety Limits

- Commands have a configurable timeout (default 60s)
- Dangerous commands are blocked (rm -rf, format, dd, shutdown, etc.)
- Output is truncated at 10,000 characters
- `restrictToWorkspace` config can limit file access to the workspace

## exec — Package Persistence (Docker)

When running inside a Docker container, pip and npm packages are configured to install into the mounted volume and survive container restarts:

- `pip install <pkg>` → `/root/.nanobot/pip/` (persistent)
- `npm install -g <pkg>` → `/root/.nanobot/npm/` (persistent)
- `npx <pkg>` cache → `/root/.nanobot/npm/cache/` (persistent)
- `apt-get install` → container filesystem (NOT persistent, use Dockerfile instead)

## cron — Scheduled Reminders

- Please refer to cron skill for usage.

# tmux-harvest

A tmux plugin for [Harvest](https://www.getharvest.com/) time tracking. Start, stop, log, and edit time entries without leaving tmux.

![tmux 3.0+](https://img.shields.io/badge/tmux-3.0%2B-blue)
![Go](https://img.shields.io/badge/Go-1.21%2B-00ADD8)

## Features

- **Timer control** — start, stop, and resume timers from a popup menu
- **Log time** — record hours retroactively (supports `1.5`, `1h30m`, `90m` formats)
- **Edit entries** — modify project, task, hours, or notes on today's entries
- **Daily view** — see today's entries with totals in a formatted table
- **Status bar** — shows running timer (`⏱ 1:23`) or daily total (`4.5h`)
- **Fuzzy selection** — projects and tasks picked via [fzf](https://github.com/junegunn/fzf)
- **Caching** — 30s status cache, 5min project cache to keep things snappy
- **Zero dependencies** — Go standard library only

## Requirements

- tmux 3.0+ (for `display-menu` and `display-popup`)
- Go 1.21+ (to build the binary)
- [fzf](https://github.com/junegunn/fzf)
- A Harvest account with a [personal access token](https://id.getharvest.com/developers)

## Installation

### With [TPM](https://github.com/tmux-plugins/tpm)

Add to your `~/.tmux.conf`:

```bash
set -g @plugin 'nsa-brandon/tmux-harvest'
```

Then press `prefix + I` to install. The Go binary is built automatically on first load.

### Manual

```bash
git clone https://github.com/nsa-brandon/tmux-harvest.git ~/.tmux/plugins/tmux-harvest
cd ~/.tmux/plugins/tmux-harvest
go build -o bin/harvest-tmux ./cmd/harvest-tmux
```

Add to `~/.tmux.conf`:

```bash
run-shell ~/.tmux/plugins/tmux-harvest/harvest.tmux
```

## Configuration

### Harvest credentials

Create `~/Harvest_Invoice/invoice.ini`:

```ini
[Harvest]
account_id = YOUR_ACCOUNT_ID
api_token = YOUR_API_TOKEN
```

### tmux options

```bash
# Keybinding (default: H)
set -g @harvest-key 'H'

# Colors
set -g @harvest-color '#E67E22'       # running timer color
set -g @harvest-dim-color '#8B5A2B'   # stopped/daily total color
```

### Status bar

Add the status script to your status-right (or use with a status bar plugin like [tmux-dotbar](https://github.com/vaaleyard/tmux-dotbar)):

```bash
set -g status-right '#(~/.tmux/plugins/tmux-harvest/scripts/status.sh) %H:%M'
```

## Usage

Press `prefix + H` (or your configured key) to open the menu.

**When a timer is running:**

| Key | Action |
|-----|--------|
| `s` | Stop timer |
| `n` | Start new entry |
| `l` | Log time (no timer) |
| `e` | Edit an entry |
| `v` | View today's log |

**When stopped:**

| Key | Action |
|-----|--------|
| `r` | Resume last entry |
| `n` | Start new entry |
| `l` | Log time (no timer) |
| `e` | Edit an entry |
| `v` | View today's log |

### Hour formats

When logging or editing hours, these formats are accepted:

- `1.5` — decimal hours
- `1h30m` — duration
- `90m` — minutes
- `1h` — hours

## Architecture

```
├── cmd/harvest-tmux/    # CLI entry point
├── internal/
│   ├── api/             # Harvest v2 API client
│   ├── cache/           # JSON file cache with TTL
│   ├── config/          # INI config parser
│   └── format/          # TSV + status bar formatting
└── scripts/             # Bash scripts for tmux UI (fzf, popups, menus)
```

Go handles API calls, caching, and data formatting. Shell scripts handle tmux UI and user interaction.

## License

MIT

# Claude

## Claude Code

[Claude Code](https://code.claude.com/docs/en/quickstart) is Anthropic's terminal-based AI coding agent.

### Linux / WSL

* Install (native install — recommended)
  * `curl -fsSL https://claude.ai/install.sh | bash`
  * `reload` - reload bash (using alias)
  * `claude --version` - verify the install
* Run `claude` and follow the prompts to sign in

### Windows

* Install (PowerShell)
  * `irm https://claude.ai/install.ps1 | iex`
  * Open a new terminal and run `claude --version` to verify
* Run `claude` and follow the prompts to sign in

> N.B. [Git for Windows](https://git-scm.com/downloads/win) is recommended so Claude Code can use the Bash tool — without it, Claude Code uses PowerShell instead. WSL setups do not need Git for Windows.

### Dotfiles

`claude/` is a stow package — `claude/.claude/` is linked into `~/.claude`:

* Claude Code rewrites `settings.json` when you change settings or install plugins — if `ls -l ~/.claude/settings.json` shows it's no longer a symlink, re-run the stow command to adopt the changes back into the repo

### Tips

* `claude update` - apply an update immediately (reports the version change, or that you're already up to date)
  * Native installations also auto-update in the background, so `claude update` is only needed to update without waiting for the next background check
* Claude likes to use `python` when doing tasks like modifying files so it's worth making sure that is installed and on path

### Theme

* Install [Dracula theme](https://github.com/matcra587/claude-themes)
* Restart Claude Code
* Select Dracula `/theme`

### Config

These are config settings I have changed from the default:

* Respect .gitignore in file picker: `false`
* Session recap: `false`

### Plugins

Some plugins are project specific, but these are worth installing at user scope:

* [Chrome DevTools MCP](https://claude.com/marketplace/plugins/chrome-devtools-mcp)
* [Context7](https://claude.com/marketplace/connectors/context7)
* [Superpowers](https://claude.com/marketplace/plugins/superpowers)

### Mods

* [Context Bar](https://statuslin.es/mods/context-bar)
* [Sub Meter](https://statuslin.es/mods/sub-meter)

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

### Updates

* `claude update` - apply an update immediately (reports the version change, or that you're already up to date)
* Native installations also auto-update in the background, so `claude update` is only needed to update without waiting for the next background check

# Font: https://www.nerdfonts.com/ - JetBrainsMono Nerd Font

# omp
# https://ohmyposh.dev/
# https://community.chocolatey.org/packages/oh-my-posh

# $documentsPath = [Environment]::GetFolderPath('MyDocuments')

# oh-my-posh init pwsh --config "$documentsPath\PowerShell\meeg.omp.json" | Invoke-Expression

# Starship
# https://starship.rs/guide/#%F0%9F%9A%80-installation

Invoke-Expression (&starship init powershell)

# fnm

fnm env --use-on-cd | Out-String | Invoke-Expression
fnm completions --shell power-shell | Out-String | Invoke-Expression

# Terminal icons
# https://github.com/devblackops/Terminal-Icons
# Install-Module -Name Terminal-Icons -Repository PSGallery
if (Get-Module -ListAvailable -Name Terminal-Icons) {
    Import-Module -Name Terminal-Icons
}
else {
    Write-Host "Installing Terminal Icons"
    Install-Module -Name Terminal-Icons -Repository PSGallery -Scope CurrentUser
    Import-Module -Name Terminal-Icons
}

# Import the Chocolatey Profile that contains the necessary code to enable
# tab-completions to function for `choco`.
# Be aware that if you are missing these lines from your profile, tab completion
# for `choco` will not function.
# See https://ch0.co/tab-completion for details.
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
  Import-Module "$ChocolateyProfile"
}

# Corepack
function yarn { corepack yarn $args }
function yarnpkg { corepack yarnpkg $args }
function pnpm { corepack pnpm $args }
function pnpx { corepack pnpx $args }
function npm { corepack npm $args }
function npx { corepack npx $args }

# Aliases
if (!(Test-Path alias:which)) {
  New-Alias which Get-Command
}

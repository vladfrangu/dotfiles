# Vlad's dotfiles

Simple dotfiles that I use on my Mac laptop

## Requirements

- brew

### brew packages

- bat
- exa
- gh
- jq
- neofetch
- pyenv
- readline
- starship
- volta
- xz
- zlib
- zsh

### Setting up zsh to use brew zsh instead of /usr/local/bin/zsh

1. Install zsh via brew
1. Find the path for the installed zsh (`where zsh`; for me it's in `/opt/homebrew/bin/zsh`)
1. Append the path to `/etc/shells`
1. Change your shell to it via `chsh -s <path from step 2>` (`chsh -s /opt/homebrew/bin/zsh`)

### Adding spacers to the Mac dock

```bash
defaults write com.apple.dock persistent-apps -array-add '{"tile-type"="spacer-tile";}'; killall Dock
```

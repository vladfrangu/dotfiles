Simple dotfiles that I use on my Mac laptop

## Requirements

- brew
- fig

## Installation

- Install brew, zsh, and other tools

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install bat exa gh starship volta zsh
```

- Install oh-my-zsh

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

- Run the following commands to install required plugins

```bash
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
```

- Insert .zshrc from this repo into your home directory

- Copy `.config` folder from this repo into your home directory

### brew packages I have installed

- autoconf
- bat
- ca-certificates
- deno
- exa
- ffmpeg
- gdbm
- gh
- go (optional)
- jq
- libssh2
- m4
- mpdecimal
- ncurses
- neofetch
- oniguruma
- openssl@1.1
- openssl@3
- pcre
- pkg-config
- pyenv (optional)
- readline
- screenresolution
- sqlite
- starship
- tcl-tk
- volta
- webp
- xz
- zlib
- zsh

### brew casks

- alt-tab
- android-platform-tools
- anydesk
- dotnet-sdk
- figma
- gimp
- google-chrome (used for development only, I use Google Chrome Dev instead)
- google-cloud-sdk
- hex-fiend
- iterm2
- itsycal
- keybase
- raycast
- scroll-reverser
- slack
- temurin (optional; JDK)
- transmission (or alternatively find and install qBitTorrent)

### Other tools installed

- JetBrains Toolbox (optional)
- Docker
- BetterDummy (optional)
- TG Pro
- Visual Studio Code & Visual Studio Code Insiders
- Discord clients
- Insomnia Rest client
- Notion
- iTerm2 (profile available in `iterm2_profile`)
- Warp terminal
- JetBrains Mono Nerd font
- rust via rustup

### Setting up zsh to use brew zsh instead of /usr/local/bin/zsh

1. Install zsh via brew
1. Find the path for the installed zsh (`where zsh`; for me it's in `/opt/homebrew/bin/zsh`)
1. Append the path to `/etc/shells`
1. Change your shell to it via `chsh -s <path from step 2>` (`chsh -s /opt/homebrew/bin/zsh`)

### Adding spacers to the Mac dock

```bash
defaults write com.apple.dock persistent-apps -array-add '{"tile-type"="spacer-tile";}'; killall Dock
```

Simple dotfiles that I use on Linux VPS's

## Requirements

- zsh
- oh-my-zsh

## Installation

- Install zsh, and other tools

```bash
sudo apt install zsh bat exa starship
curl https://get.volta.sh | bash
```

> Note: If `starship` is not present on apt, or your package manager of choice, visit their GitHub page and follow the installation instructions.

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

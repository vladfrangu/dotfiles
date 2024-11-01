# Q pre block. Keep at the top of this file.
[[ -f "${HOME}/Library/Application Support/amazon-q/shell/zshrc.pre.zsh" ]] && builtin source "${HOME}/Library/Application Support/amazon-q/shell/zshrc.pre.zsh"
# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
#ZSH_THEME="spaceship"

# Uncomment the following line to change how often to auto-update (in days).
zstyle ':omz:update' frequency 7

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(
  git
  encode64
  sudo
  volta
  npm
  yarn
  pyenv
  zsh-autosuggestions
  zsh-syntax-highlighting
)

source $ZSH/oh-my-zsh.sh

# User configuration
# eval "$(/opt/homebrew/bin/brew shellenv)"

if [ "$(arch)" = "arm64" ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
else
    eval "$(/usr/local/bin/brew shellenv)"
fi

# bun
export BUN_INSTALL="$HOME/.bun"
# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

export VOLTA_HOME="$HOME/.volta"
export CARGO_HOME="$HOME/.cargo"
export PYENV_ROOT="$HOME/.pyenv"
export DENO_ROOT="$HOME/.deno"
export GOMODULES_PATH="$HOME/go/bin"
export LIBPG="/opt/homebrew/opt/libpq/bin"
export FOUNDRY_HOME="$HOME/.foundry"
export PATH="$LIBPG:$BUN_INSTALL/bin:$GOMODULES_PATH:$DENO_ROOT/bin:$PYENV_ROOT/bin:$VOLTA_HOME/bin:$CARGO_HOME/bin:$FOUNDRY_HOME/bin:$PATH"

# For code-server
export EXTENSIONS_GALLERY='{"serviceUrl":"https://marketplace.visualstudio.com/_apis/public/gallery","cacheUrl":"https://vscode.blob.core.windows.net/gallery/index","itemUrl":"https://marketplace.visualstudio.com/items","controlUrl":"","recommendationsUrl":""}'

# Initialize gcloud-sdk completions if installed
if [ "$(command -v gcloud)" ]; then
    source "/opt/homebrew/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/path.zsh.inc"
    source "/opt/homebrew/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/completion.zsh.inc"
fi

# Replace ls
if [ "$(command -v eza)" ]; then
    unalias -m 'll'
    unalias -m 'l'
    unalias -m 'la'
    unalias -m 'ls'
    alias ls='eza -G  --color auto --icons -a -s type'
    alias ll='eza -l --color always --icons -a -s type'
fi

# Replace cat
if [ "$(command -v bat)" ]; then
    unalias -m 'cat'
    alias cat='bat -pp --theme="Monokai Extended Bright"'
fi

# Load Autocompletions
if type brew &>/dev/null; then
    FPATH=$(brew --prefix)/share/zsh/site-functions:$FPATH

    autoload -Uz compinit
    compinit
fi

# Initialize starship
eval "$(starship init zsh)"

# Initialize pyenv if present
if [ "$(command -v pyenv)" ]; then
    eval "$(pyenv init -)"
fi

if [ "$(command -v github-copilot-cli)" ]; then
    eval "$(github-copilot-cli alias -- "$0")"
fi

# Replace cd
if [ "$(command -v zoxide)" ]; then
    eval "$(zoxide init zsh)"
    unalias -m 'cd'
    alias cd='z'
    alias cdi='zi'
fi

# Taken from Favna's dotfiles, https://github.com/favware/zsh-git-enhanced/blob/main/zsh-git-enhanced.plugin.zsh#L442-L472, under the MIT license
function git_main_branch() {
    command git rev-parse --git-dir &>/dev/null || return
    local ref
    for ref in refs/{heads,remotes/{origin,upstream}}/{main,trunk,mainline,default,master}; do
        if command git show-ref -q --verify $ref; then
            echo ${ref:t}
            return 0
        fi
    done

    # If no main branch was found, fall back to master but return error
    echo master
    return 1
}

function git_develop_branch() {
    command git rev-parse --git-dir &>/dev/null || return
    local branch
    for branch in dev devel develop development; do
        if command git show-ref -q --verify refs/heads/$branch; then
            echo $branch
            return 0
        fi
    done

    echo dev
    return 1
}

function git-br-delete-useless() {
    git branch --no-color | command grep -vE "^([+*]|\s*($(git_main_branch)|$(git_develop_branch))\s*$)" | sed s/\'/\\\\\'/g | command xargs git branch --delete --force 2>/dev/null
}

function git-squash-diff() {
    git rebase -i HEAD~$(git rev-list --count origin/$(git_main_branch)..$(git rev-parse --abbrev-ref HEAD))
}
# END

function unfuck-vpn-old() {
	sudo route delete default -ifp utun6
	sudo route add default 192.168.1.1 0.0.0.0
	sudo route add default 192.168.100.1 0.0.0.0
}

function unfuck-vpn() {
    ROUTER=$(netstat -nr | grep default | grep 1 | awk '{print $2}' | head -1)

    # Confirm the user connected to the vpn
    echo "You are connected to $ROUTER"
    echo -n "Do you want to unfuck the vpn? Confirm once you connected [y/N] "

    read -q

    echo

    if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
        echo "Aborting..."
        return
    fi

    sudo route delete default -ifp utun6
    sudo route add default $ROUTER 0.0.0.0
}

# Q post block. Keep at the bottom of this file.
[[ -f "${HOME}/Library/Application Support/amazon-q/shell/zshrc.post.zsh" ]] && builtin source "${HOME}/Library/Application Support/amazon-q/shell/zshrc.post.zsh"

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Uncomment the following line to change how often to auto-update (in days).
zstyle ':omz:update' frequency 7

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

plugins=(
    git
    encode64
    sudo
    volta
    npm
    yarn
    zsh-autosuggestions
    zsh-syntax-highlighting
)

source $ZSH/oh-my-zsh.sh

if [ "$(arch)" = "arm64" ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
else
    eval "$(/usr/local/bin/brew shellenv)"
fi

# bun
export BUN_INSTALL="$HOME/.bun"

# volta
export VOLTA_HOME="$HOME/.volta"

# cargo
export CARGO_HOME="$HOME/.cargo"

# deno
export DENO_ROOT="$HOME/.deno"

# go
export GOMODULES_PATH="$HOME/go/bin"

# libpq
export LIBPG="/opt/homebrew/opt/libpq/bin"

# openjdk
export JAVA_HOME="/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home"

# foundry
export FOUNDRY_HOME="$HOME/.foundry"

# apify cli
export APIFY_CLI_INSTALL="$HOME/.apify"
export PATH="$APIFY_CLI_INSTALL/bin:$PATH"

# opencode
export PATH="$HOME/.opencode/bin:$PATH"

export PATH="$LIBPG:$BUN_INSTALL/bin:$GOMODULES_PATH:$DENO_ROOT/bin:$PYENV_ROOT/bin:$VOLTA_HOME/bin:$CARGO_HOME/bin:$FOUNDRY_HOME/bin:$PATH"
export SLACK_DEVELOPER_MENU=true

# For code-server
export EXTENSIONS_GALLERY='{"serviceUrl":"https://marketplace.visualstudio.com/_apis/public/gallery","cacheUrl":"https://vscode.blob.core.windows.net/gallery/index","itemUrl":"https://marketplace.visualstudio.com/items","controlUrl":"","recommendationsUrl":""}'

# Replace ls
if [ "$(command -v eza)" ]; then
    unalias -m 'll'
    unalias -m 'l'
    unalias -m 'la'
    unalias -m 'ls'
    alias ls='eza -G  --color auto --icons -a -s type'
    alias ll='eza -l --color always --icons -a -s type'
fi

# Alias cursor to c if it's installed
if [ "$(command -v cursor)" ]; then
    alias c='cursor'
fi

# Alias claude to dangerously if it's installed
if [ "$(command -v claude)" ]; then
    alias claude='claude --dangerously-skip-permissions'
fi

if [ "$(command -v claudewho-apify)" ]; then
    alias claudea='claudewho-apify --dangerously-skip-permissions'
fi

if [ "$(command -v claudewho-statespacelabs)" ]; then
    alias claudes='claudewho-statespacelabs --dangerously-skip-permissions'
fi

if [ "$(command -v claude-codex)" ]; then
    alias claudex='claude-codex --dangerously-skip-permissions'
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

# Replace cd
if [[ "$(command -v zoxide)" && "$CLAUDECODE" != "1" ]]; then
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

# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

[[ -f ~/.inshellisense/init/zsh/init.zsh ]] && source ~/.inshellisense/init/zsh/init.zsh

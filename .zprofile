# Fig pre block. Keep at the top of this file.
. "$HOME/.fig/shell/zprofile.pre.zsh"

# User configuration
eval "$(/opt/homebrew/bin/brew shellenv)"

export VOLTA_HOME="$HOME/.volta"
export CARGO_HOME="$HOME/.cargo"
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$VOLTA_HOME/bin:$CARGO_HOME/bin:$PATH"

# Initialize pyenv if present
if [ "$(command -v pyenv)" ]; then
  eval "$(pyenv init -)"
fi

# Fig post block. Keep at the bottom of this file.
. "$HOME/.fig/shell/zprofile.post.zsh"

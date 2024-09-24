# dotfiles
Setup for environments on many platforms


## Software Required:
- zsh
- [Neovim](https://neovim.io)
- [Zellij](https://zellij.dev)
- [Alacritty](https://github.com/alacritty/alacritty/releases)
- [Rust](https://www.rust-lang.org/tools/install)
- [Node](https://nodejs.org/en)
- [Lua](https://www.lua.org/download.html#tools)

### Windows Requirements
- [Cygwin or MinGW](https://www.cygwin.com/index.html)

## Instructions
- Setup $XDG_CONFIG_HOME, $ZDOTDIR.
    ~/.zshenv
    ```
    │export PATH="/opt/homebrew/bin:$PATH"                                                                                                                                              │
    │export XDG_CONFIG_HOME=".../.../dotfiles"                                                                                                                        │
    │export ZDOTDIR=${ZDOTDIR:=${XDG_CONFIG_HOME}/zsh}                                                                                                                                  │
    ```
- .cargo folder should be in ~/
- Install Tree sitter cli:
    ```
    cargo install tree-sitter-cli
    npm install tree-sitter-cli
    ```
## WSL Instructions:
```
export PATH="$PATH:/opt/nvim-linux64/bin"
export NVM_DIR="$HOME/dotfiles/nvm"
source $XDG_CONFIG_HOME/zsh/spaceship-vi-mode/spaceship-vi-mode.plugin.zsh
source ~/.zsh/spaceship/spaceship.zsh
alias vi=nvim
alias python=~/pyenv/bin/python3.11
alias pip=~/pyenv/bin/pip3.11
export ORACLE_HOME=/opt/oracle/instantclient_21_8
export LD_LIBRARY_PATH=$ORACLE_HOME:$LD_LIBRARY_PATH
export PATH=$PATH:$ORACLE_HOME
```

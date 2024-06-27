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

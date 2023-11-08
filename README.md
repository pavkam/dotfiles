# My personal `dotfiles`

Inside these `dotfiles` you will be able to find the following setup:

* general setup for unix utilities including `mc`, `htop`, `wget`, `less` and more,
* `neovim` and my personal config,
* `tmux` and some plugins,
* `vscode` and its plugins,
* `fzf` and additional settings,
* `zsh`, including `oh-my-zsh` plus plugins,
* `powerline` for `vim` and `zsh`,
* `git` defaults and aliases,
* `.editorconfig` with tons of settings for `JetBrains` IDEs.
* other stuff...

# Noteworthy things

* The `dotfiles`` were developed on **Manjaro Linux** initially and will tentatively install all dependencies on **Arch** (and related) distributions. Currently, using macOS and Homebrew setup primarily during my day-to-day so the installer is mostly tailored toward that goal.
* My workflow is deeply influenced by `fzf` as well so a lot of commands will pipe out put through the fuzzy finder,
* `Neovim` is used as the primary editor in conjunction with `tmux` and `kitty` as my primary development environment,

# Screens

![image](https://github.com/pavkam/dotfiles/assets/7327309/81c0d485-5eec-4d23-ac2b-d19f376646fb)
![image](https://github.com/pavkam/dotfiles/assets/7327309/9249e3ec-4351-4e0a-85d9-7025f67be4e3)
![image](https://user-images.githubusercontent.com/7327309/147490998-1a600287-3555-4bce-9a29-d06c2e476aee.png)
![image](https://user-images.githubusercontent.com/7327309/147490417-8197f664-31df-45fe-87b4-74ae495cee19.png)
![image](https://user-images.githubusercontent.com/7327309/147490500-31312ab3-922b-45ea-9c1a-f2d7f689901b.png)
![image](https://user-images.githubusercontent.com/7327309/147490587-126afbd3-d68b-464d-b8e5-6abd6cb1a1dc.png)

# Installation

The following command will download and install the dotfiles:
```sh
git clone git@github.com:pavkam/dotfiles.git ~/.dotfiles && cd ~/.dotfiles && ./install.sh
```

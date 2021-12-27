# My personal `dotfiles`
Inside these dotfiles you will be able to find the following setup:
* general setup for unix utilities including `mc`, `htop`, `wget`, `less` and more,
* `vim` and its plugins,
* `vscode` and its plugins,
* `fzf` and additional settings,
* `zsh`, including `oh-my-zsh` plus plugins,
* `powerline` for `vim` and `zsh`,
* `git` defaults and aliases,
* other stuff... 

Note, the dotfiles were developed on **Manjaro Linux** and will only install dependencies on **Arch** (and related) distributions. On other OSes ot will be up to you to install the dependancies.

My workflow is deeply influenced by `fzf` as well so a lot of commands will pipe out put through the fuzzy finder. Start by pressing `CTRL + tilde` in the zsh shell to see the core menu "_quickies-menu_".

# Screens
![image](https://user-images.githubusercontent.com/7327309/147490998-1a600287-3555-4bce-9a29-d06c2e476aee.png)
![image](https://user-images.githubusercontent.com/7327309/147490417-8197f664-31df-45fe-87b4-74ae495cee19.png)
![image](https://user-images.githubusercontent.com/7327309/147490500-31312ab3-922b-45ea-9c1a-f2d7f689901b.png)
![image](https://user-images.githubusercontent.com/7327309/147490587-126afbd3-d68b-464d-b8e5-6abd6cb1a1dc.png)

# Installation

The following command will download and install the dotfiles:
```sh
git clone git@github.com:pavkam/dotfiles.git ~/.dotfiles && cd ~/.dotfiles && ./install.sh 
```

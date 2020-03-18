vim-hs-type
===========

This plugin starts as a fork of [vim-hdevtools] and is now still in development. It aims to improve getting type information ignoring every other abilities of hdevtools, cause they all are better done by [haskell-ide-engine].

## Installation

First of all you have to install [hdevtools], if you didn't this yet.

You can do it via [stack] from Stackage:
```shell
$ stack install hdevtools
```

or via [cabal] from Hackage:
```shell
$ cabal install hdevtools
```

Then you can use your favourite plugin manager to install `vim-hs-type` into Vim. I prefer [vim-plug], so in my case I add this to my `vimrc` (`init.vim` actually, cause I use [Neovim]):
```
Plug 'fimmind/vim-hs-type'
```
then restart Vim and run `:PlugInstall`.

[vim-hdevtools]:      https://github.com/bitc/vim-hdevtools
[vim-plug]:           https://github.com/junegunn/vim-plug
[neovim]:             https://neovim.io/
[hdevtools]:          https://github.com/hdevtools/hdevtools
[haskell-ide-engine]: https://github.com/haskell/haskell-ide-engine
[stack]:              http://haskellstack.org
[cabal]:              https://www.haskell.org/cabal/

vim-hs-type
===========

This plugin started as a fork of [vim-hdevtools] and is now still in development. It aims to improve getting type information ignoring every other abilities of [hdevtools], cause they all are better done by [haskell-ide-engine].

## Why is it better than [vim-hdevtools]?
1. **Interacting with types.** Opened window contains types as a plain text, so you can interact with it as with a plain text.
2. **Multiple projects support.** While [vim-hdevtools] stops only first started [hdevtools] server and only in directory where you opened Vim, `vim-hs-type` stops them all, even if they are in different projects and directories.
3. **Interacting with expressions.** `vim-hs-type` supports `ie` and `ae` text objects (see [Usage](##Usage)).
4. **More clean and readable code.**
5. **More customisation abilities**. See [Configuration](##Configuration).

## Installation

First of all you have to install [hdevtools], if you didn't do this yet.

You can do it via [stack] from Stackage:
```shell
$ stack install hdevtools
```

or via [cabal] from Hackage:
```shell
$ cabal install hdevtools
```

Then you can use your favourite plugin manager to install `vim-hs-type` into Vim. For [vim-plug]:
```
Plug 'fimmind/vim-hs-type'
```

## Usage

Main function of this plugin is `vim_hs_type#type()`. When you run it, a window containing all types of expressions under cursor is opened (You can close it with `<Esc>` or `gq`). Most likely in your case this won't look exactly the same, cause I have many other plugins installed, but for my setup it looks this way:

![](./pictures/function_run.png)

Moving cursor over lines causes highlighting of relevant expression in source code:

![](./pictures/moving_around1.png)
![](./pictures/moving_around2.png)

Also, text object of highlighted expression is available by `ie` and `ae` (latter also selects space around expression similarly to `aw`), but sadly they work only in visual mode, so you can't, for example, use `dae` to delete an expression (while `vaed` works fine).

## Configuration
TODO

## LICENSE

Copyright (c) 2020 Vinogrodskiy Serafim

For full information see `LICENSE.md`.

[vim-hdevtools]:      https://github.com/bitc/vim-hdevtools
[vim-plug]:           https://github.com/junegunn/vim-plug
[neovim]:             https://neovim.io/
[hdevtools]:          https://github.com/hdevtools/hdevtools
[haskell-ide-engine]: https://github.com/haskell/haskell-ide-engine
[stack]:              http://haskellstack.org
[cabal]:              https://www.haskell.org/cabal/

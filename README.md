# marker.nvim

<div align="center">

# marker.nvim

## Simple, yet powerful neovim marks management plugin 🔌

</div>

<div align="center">

![Lua](https://img.shields.io/badge/Made%20with%20Lua-blueviolet.svg?style=for-the-badge&logo=lua&logoColor=white)

</div>

<div align="center">

![License](https://img.shields.io/badge/License-MIT-brightgreen?style=flat-square)
![Status](https://img.shields.io/badge/Status-Beta-informational?style=flat-square)
![Neovim](https://img.shields.io/badge/Neovim-0.9+-green.svg?style=flat-square&logo=Neovim&logoColor=white)

</div>

</div>

## Overview

![WARNING]

> This plugin is still in early alpha version. Expect breaking changes 💥

## ⚡️Requirements

It should work with any fairly modern neovim version. I tested that for the following:

- `neovim` >= 0.9 and nightly 0.11-dev releases

## 💻 Installation

Install the `marker.nvim` neovim plugin with your favourite package manager:

[Lazy](https://github.com/folke/lazy.nvim)

```lua
-- marker.nvim
return {
  "mgierada/marker.nvim",
  dependencies = { "leath-dub/snipe.nvim" },
  enabled = true,
  config = function()
    require("marker").setup({
      position = "topleft",
      mappings = {
        open = "<leader>ml",
        select = "<cr>",
        cancel = "<esc>",
        preview = "p"
      },
    })
  end,
}
```

## Inspiration

The plugin is inspired by other awesome plugins and borrows some concepts:

- https://github.com/leath-dub/snipe.nvim
- https://github.com/nicholasxjy/snipe-marks.nvim
- https://github.com/ThePrimeagen/harpoon

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=mgierada/marker.nvim&type=Timeline)](https://star-history.com/#mgierada/marker.nvim&Timeline)

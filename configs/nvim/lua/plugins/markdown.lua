return {
  {
    "MeanderingProgrammer/render-markdown.nvim",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-tree/nvim-web-devicons",
    },
    ft = { "markdown" },
    opts = {
      latex = { enabled = false },  -- Disable LaTeX warnings
      heading = {
        sign = false,
        icons = {
          "󰎤 ",
          "󰎧 ",
          "󰎪 ",
          "󰎭 ",
          "󰎱 ",
          "󰎳 ",
        },
      },
      checkbox = {
        enabled = true,
        unchecked = { icon = "󰄱 " },
        checked = { icon = "󰄲 " },
        custom = {
          todo = {
            raw = "[-]",
            rendered = "󰥔 ",
            highlight = "RenderMarkdownTodo",
          },
        },
      },
      bullet = {
        icons = { "●", "○", "◆", "◇" },
      },
      code = {
        sign = false,
        width = "block",
        right_pad = 1,
        language_pad = 1,
        border = "thin",
      },
    },
  },
}

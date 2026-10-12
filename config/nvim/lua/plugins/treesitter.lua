return {
  "nvim-treesitter/nvim-treesitter",
  build = ":TSUpdate",

  config = function()
    require("nvim-treesitter.config").setup({
      opts = {
        ensure_installed = {
        "lua",
        "vim",
        "vimdoc",
        "bash",
        "markdown",
        "markdown_inline",
        "javascript",
        "typescript",
        "tsx",
        "json",
        "yaml",
        "html",
        "css",
        "python",
        "kotlin",
        "java",
        "rust",
        "markdown",
        "markdown"
      },

      auto_install = true,

      highlight = {
        enable = true,
      },

      indent = {
        enable = true,
      },
    }
  })
  end,
}

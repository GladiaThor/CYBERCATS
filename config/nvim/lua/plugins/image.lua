-- ~/.config/nvim/lua/plugins/image.lua
return {
  {
    "3rd/image.nvim",
    build = false,
    opts = {
      backend = "kitty",
      processor = "magick_cli",

      integrations = {
        markdown = {
          enabled = true,
          download_remote_images = true,
          only_render_image_at_cursor = true,
          only_render_image_at_cursor_mode = "popup",
          filetypes = { "markdown", "vimwiki", "quarto" },
        },
        html = { enabled = true },
        css = { enabled = true },
      },

      max_height_window_percentage = 50,
      window_overlap_clear_enabled = true,
      editor_only_render_when_focused = true,

      hijack_file_patterns = {
        "*.png",
        "*.jpg",
        "*.jpeg",
        "*.gif",
        "*.webp",
        "*.avif",
      },
    },
  },
}

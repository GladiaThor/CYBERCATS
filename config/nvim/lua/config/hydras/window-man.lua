local Hydra = require("hydra")

Hydra({
  name = "Windows",
  mode = "n",
  body = "<C-w>",
  heads = {
    { "h", "<C-w><" },
    { "l", "<C-w>>" },
    { "j", "<C-w>-" },
    { "k", "<C-w>+" },
    { "q", nil, { exit = true } },
  },
})

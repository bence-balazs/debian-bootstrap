#!/usr/bin/env bash
#
# bootstrap-nvim-minimal.sh
# Minimal Neovim setup on Debian:
#   - Latest Neovim (pulled from GitHub releases, not apt)
#   - lazy.nvim plugin manager
#   - vscode.nvim colorscheme (Mofiqul/vscode.nvim)
#   - lualine.nvim statusline (codedark theme, matches vscode.nvim)
#   - Sane defaults + basic leader-based keybinds
#
# No LSP, no treesitter, no Mason, no Go/YAML/Kubernetes tooling.
# See bootstrap-nvim.sh for the full dev-environment version.
#
# Usage: ./bootstrap-nvim-minimal.sh

set -euo pipefail

CONFIG_DIR="$HOME/.config/nvim"
BACKUP_DIR="$HOME/.config/nvim.bak.$(date +%Y%m%d%H%M%S)"

echo "==> Checking dependencies"

for pkg in git curl; do
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
        echo "    Installing missing dependency: $pkg"
        sudo apt install -y "$pkg"
    fi
done

# --- Install/update Neovim from the latest official GitHub release ---
NVIM_INSTALL_DIR="/opt/nvim"
NVIM_BIN_LINK="/usr/local/bin/nvim"

echo "    Fetching latest Neovim release info from GitHub..."
LATEST_TAG="$(curl -fsSL https://api.github.com/repos/neovim/neovim/releases/latest | grep -oP '"tag_name":\s*"\K[^"]+')"

if [[ -z "$LATEST_TAG" ]]; then
    echo "    ERROR: Could not determine latest Neovim release (GitHub API rate-limited or unreachable)."
    if command -v nvim >/dev/null 2>&1; then
        echo "    Falling back to existing installed nvim: $(nvim --version | head -1)"
    else
        echo "    No nvim installed and could not fetch a release. Aborting."
        exit 1
    fi
else
    CURRENT_VERSION=""
    if command -v nvim >/dev/null 2>&1; then
        CURRENT_VERSION="$(nvim --version | head -1 | grep -oP 'NVIM \K[^\s]+')"
    fi

    if [[ "$CURRENT_VERSION" == "$LATEST_TAG" ]]; then
        echo "    Already on latest Neovim ($LATEST_TAG)"
    else
        echo "    Installing Neovim $LATEST_TAG (current: ${CURRENT_VERSION:-none}) to $NVIM_INSTALL_DIR"

        ARCH="$(uname -m)"
        case "$ARCH" in
            x86_64) ASSET="nvim-linux-x86_64.tar.gz" ;;
            aarch64|arm64) ASSET="nvim-linux-arm64.tar.gz" ;;
            *) echo "    ERROR: Unsupported architecture: $ARCH"; exit 1 ;;
        esac

        DOWNLOAD_URL="https://github.com/neovim/neovim/releases/download/${LATEST_TAG}/${ASSET}"
        TMP_TAR="$(mktemp --suffix=.tar.gz)"

        if ! curl -fsSL "$DOWNLOAD_URL" -o "$TMP_TAR"; then
            echo "    Primary asset name not found, trying legacy naming..."
            rm -f "$TMP_TAR"
            ASSET="nvim-linux64.tar.gz"
            DOWNLOAD_URL="https://github.com/neovim/neovim/releases/download/${LATEST_TAG}/${ASSET}"
            curl -fsSL "$DOWNLOAD_URL" -o "$TMP_TAR"
        fi

        sudo rm -rf "$NVIM_INSTALL_DIR"
        sudo mkdir -p "$NVIM_INSTALL_DIR"
        sudo tar xzf "$TMP_TAR" -C "$NVIM_INSTALL_DIR" --strip-components=1
        rm -f "$TMP_TAR"

        sudo ln -sf "$NVIM_INSTALL_DIR/bin/nvim" "$NVIM_BIN_LINK"

        echo "    Installed: $(nvim --version | head -1)"
    fi
fi

NVIM_VERSION="$(nvim --version | head -1)"
echo "    Active Neovim: $NVIM_VERSION"

# --- Backup existing config if present ---
if [[ -d "$CONFIG_DIR" ]]; then
    echo "==> Existing nvim config found, backing up to $BACKUP_DIR"
    mv "$CONFIG_DIR" "$BACKUP_DIR"
fi

mkdir -p "$CONFIG_DIR/lua/config"
mkdir -p "$CONFIG_DIR/lua/plugins"

echo "==> Writing config files"

# ---------------------------------------------------------------------------
# init.lua — entrypoint
# ---------------------------------------------------------------------------
cat > "$CONFIG_DIR/init.lua" << 'EOF'
require("config.options")
require("config.lazy")
require("config.keymaps")
EOF

# ---------------------------------------------------------------------------
# options.lua — sane defaults + leader keys
# ---------------------------------------------------------------------------
cat > "$CONFIG_DIR/lua/config/options.lua" << 'EOF'
local opt = vim.opt

-- Leader keys must be set before lazy.nvim loads (config.lazy is required
-- right after this file), so they live here rather than in keymaps.lua.
vim.g.mapleader = " "
vim.g.maplocalleader = " "

opt.number = true
opt.relativenumber = false
opt.termguicolors = true          -- required for vscode.nvim colors
opt.mouse = "a"
opt.clipboard = "unnamedplus"     -- use system clipboard
opt.ignorecase = true
opt.smartcase = true
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.smartindent = true
opt.wrap = false
opt.cursorline = true
opt.scrolloff = 8
opt.signcolumn = "yes"
opt.splitright = true
opt.splitbelow = true
opt.undofile = true

-- show tabs
opt.list = true
opt.listchars = {
  tab = "» ",
  trail = "·",
  extends = "›",
  precedes = "‹",
  nbsp = "␣",
}
EOF

# ---------------------------------------------------------------------------
# keymaps.lua — basic bindings, no plugin-specific ones
# ---------------------------------------------------------------------------
cat > "$CONFIG_DIR/lua/config/keymaps.lua" << 'EOF'
-- Leader keys are set in config/options.lua (must happen before lazy.nvim loads)

local map = vim.keymap.set

-- Save / quit
map("n", "<leader>w", "<cmd>w<cr>", { desc = "Save" })
map("n", "<leader>q", "<cmd>q<cr>", { desc = "Quit" })
map("n", "<leader>wq", "<cmd>wq<cr>", { desc = "Save and quit" })

-- Window navigation
map("n", "<C-h>", "<C-w>h", { desc = "Move to left window" })
map("n", "<C-l>", "<C-w>l", { desc = "Move to right window" })
map("n", "<C-j>", "<C-w>j", { desc = "Move to window below" })
map("n", "<C-k>", "<C-w>k", { desc = "Move to window above" })

-- Buffer navigation
map("n", "<leader>bn", "<cmd>bnext<cr>", { desc = "Next buffer" })
map("n", "<leader>bp", "<cmd>bprevious<cr>", { desc = "Previous buffer" })
map("n", "<leader>bd", "<cmd>bdelete<cr>", { desc = "Delete buffer" })

-- Clear search highlight
map("n", "<leader>nh", "<cmd>nohlsearch<cr>", { desc = "Clear search highlight" })

-- Better indenting in visual mode (keeps selection after indent)
map("v", "<", "<gv", { desc = "Indent left, keep selection" })
map("v", ">", ">gv", { desc = "Indent right, keep selection" })
EOF

# ---------------------------------------------------------------------------
# lazy.lua — bootstrap lazy.nvim plugin manager
# ---------------------------------------------------------------------------
cat > "$CONFIG_DIR/lua/config/lazy.lua" << 'EOF'
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup("plugins", {
  install = { colorscheme = { "vscode" } },
  checker = { enabled = false },
})
EOF

# ---------------------------------------------------------------------------
# plugins/theme.lua — vscode.nvim
# ---------------------------------------------------------------------------
cat > "$CONFIG_DIR/lua/plugins/theme.lua" << 'EOF'
return {
  "Mofiqul/vscode.nvim",
  lazy = false,
  priority = 1000,
  config = function()
    require("vscode").setup({
      transparent = true,
      italic_comments = true,
      underline_links = true,
      disable_nvimtree_bg = true,
      terminal_colors = true,
    })
    vim.cmd.colorscheme("vscode")
  end,
}
EOF

# ---------------------------------------------------------------------------
# plugins/statusline.lua — lualine.nvim (codedark theme, matches vscode.nvim)
# ---------------------------------------------------------------------------
cat > "$CONFIG_DIR/lua/plugins/statusline.lua" << 'EOF'
return {
  "nvim-lualine/lualine.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  event = "VeryLazy",
  config = function()
    require("lualine").setup({
      options = {
        theme = "codedark",
        component_separators = { left = "|", right = "|" },
        section_separators = { left = "", right = "" },
        globalstatus = true,
      },
      sections = {
        lualine_a = { "mode" },
        lualine_b = { "branch", "diff", "diagnostics" },
        lualine_c = { { "filename", path = 1 } },
        lualine_x = { "filetype" },
        lualine_y = { "progress" },
        lualine_z = { "location" },
      },
    })
  end,
}
EOF

echo ""
echo "==> Done. Config written to $CONFIG_DIR"
[[ -d "$BACKUP_DIR" ]] && echo "    Old config backed up to $BACKUP_DIR"
echo ""
echo "Next steps:"
echo "  1. Run: nvim"
echo "     lazy.nvim will bootstrap itself and install the theme automatically."
echo "  2. Wait for the plugin install window to finish, then restart nvim."
echo ""
echo "Keymaps (leader = space):"
echo "  <space>w    save"
echo "  <space>q    quit"
echo "  <space>wq   save and quit"
echo "  <space>bn   next buffer"
echo "  <space>bp   previous buffer"
echo "  <space>bd   delete buffer"
echo "  <space>nh   clear search highlight"
echo "  Ctrl+h/j/k/l  move between split windows"
-- Custom plugins for kickstart.nvim
-- File explorer (oil.nvim), Git UI (lazygit.nvim), and motion (flash.nvim)

return {
  -- ============================================================================
  -- flash.nvim: Navigate with search labels, enhanced motions, treesitter
  -- ============================================================================
  {
    'folke/flash.nvim',
    event = 'VeryLazy',
    ---@type Flash.Config
    opts = {
      -- Labels show on f/t motions too (jump labels on repeating chars)
      modes = {
        char = {
          jump_labels = true,
        },
        -- Flash labels appear during / and ? search
        search = {
          enabled = true,
        },
      },
    },
    keys = {
      -- Core: snipe to any match
      { 's', mode = { 'n', 'x', 'o' }, function() require('flash').jump() end, desc = 'Flash' },

      -- Treesitter: select treesitter nodes (use ; and , to grow/shrink)
      { 'S', mode = { 'n' }, function() require('flash').treesitter() end, desc = 'Flash Treesitter Select' },

      -- Remote: operate on a distant location, then come back (e.g. yr → pick target → iw → yanks word remotely)
      { 'r', mode = 'o', function() require('flash').remote() end, desc = 'Remote Flash' },

      -- Treesitter search: search + select surrounding treesitter node (e.g. yR → type pattern → pick node)
      { 'R', mode = { 'o', 'x' }, function() require('flash').treesitter_search() end, desc = 'Treesitter Search' },

      -- Toggle flash during / or ? search
      { '<c-s>', mode = { 'c' }, function() require('flash').toggle() end, desc = 'Toggle Flash Search' },

      -- Jump to a line (labels every line)
      {
        'gl',
        mode = { 'n', 'x', 'o' },
        function()
          require('flash').jump {
            search = { mode = 'search', max_length = 0 },
            label = { after = { 0, 0 } },
            pattern = '^',
          }
        end,
        desc = 'Flash Line',
      },

      -- Jump to word beginnings only
      {
        'gw',
        mode = { 'n', 'x', 'o' },
        function()
          require('flash').jump {
            search = {
              mode = function(str)
                return '\\<' .. str
              end,
            },
          }
        end,
        desc = 'Flash Word',
      },

      -- Flash with current word under cursor (like * but with labels)
      {
        'g*',
        mode = { 'n' },
        function()
          require('flash').jump { pattern = vim.fn.expand '<cword>' }
        end,
        desc = 'Flash current word',
      },

      -- Continue last flash search
      {
        'gs',
        mode = { 'n', 'x', 'o' },
        function()
          require('flash').jump { continue = true }
        end,
        desc = 'Flash continue last',
      },

      -- Diagnostics jump: labels every diagnostic, shows float without moving cursor
      {
        'gD',
        mode = { 'n' },
        function()
          require('flash').jump {
            matcher = function(win)
              return vim.tbl_map(function(diag)
                return {
                  pos = { diag.lnum + 1, diag.col },
                  end_pos = { diag.end_lnum + 1, diag.end_col - 1 },
                }
              end, vim.diagnostic.get(vim.api.nvim_win_get_buf(win)))
            end,
            action = function(match, state)
              vim.api.nvim_win_call(match.win, function()
                vim.api.nvim_win_set_cursor(match.win, match.pos)
                vim.diagnostic.open_float()
              end)
              state:restore()
            end,
          }
        end,
        desc = 'Flash to diagnostic',
      },

      -- Treesitter incremental selection (Ctrl-Space to start, keep pressing to grow, BS to shrink)
      {
        '<C-Space>',
        mode = { 'n', 'x', 'o' },
        function()
          require('flash').treesitter {
            actions = {
              ['<C-Space>'] = 'next',
              ['<BS>'] = 'prev',
            },
          }
        end,
        desc = 'Flash Treesitter incremental select',
      },
    },
  },

  -- ============================================================================
  -- oil.nvim: Edit filesystem like a buffer
  -- ============================================================================
  {
    'stevearc/oil.nvim',
    ---@module 'oil'
    ---@type oil.SetupOpts
    opts = {
      -- Use default file explorer (replaces netrw)
      default_file_explorer = true,
      -- Columns to display
      columns = {
        'icon',
        -- 'permissions',
        -- 'size',
        -- 'mtime',
      },
      -- Keymaps in oil buffer
      keymaps = {
        ['g?'] = { 'actions.show_help', mode = 'n' },
        ['<CR>'] = 'actions.select',
        ['<C-v>'] = { 'actions.select', opts = { vertical = true } },
        ['<C-x>'] = { 'actions.select', opts = { horizontal = true } },
        ['<C-t>'] = { 'actions.select', opts = { tab = true } },
        ['<C-p>'] = 'actions.preview',
        ['<C-c>'] = { 'actions.close', mode = 'n' },
        ['q'] = { 'actions.close', mode = 'n' },
        ['<C-r>'] = 'actions.refresh',
        ['-'] = { 'actions.parent', mode = 'n' },
        ['_'] = { 'actions.open_cwd', mode = 'n' },
        ['`'] = { 'actions.cd', mode = 'n' },
        ['~'] = { 'actions.cd', opts = { scope = 'tab' }, mode = 'n' },
        ['gs'] = { 'actions.change_sort', mode = 'n' },
        ['gx'] = 'actions.open_external',
        ['g.'] = { 'actions.toggle_hidden', mode = 'n' },
      },
      view_options = {
        -- Show hidden files (dotfiles)
        show_hidden = true,
      },
      -- Floating window config
      float = {
        padding = 2,
        max_width = 0.8,
        max_height = 0.8,
        border = 'rounded',
      },
    },
    -- Optional dependencies
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    -- Lazy loading is not recommended for oil
    lazy = false,
    keys = {
      -- File explorer keymaps under <leader>e and <leader>f
      { '-', '<CMD>Oil<CR>', desc = 'Open parent directory (Oil)' },
      { '<leader>e', '<CMD>Oil<CR>', desc = '[E]xplorer (Oil)' },
      { '<leader>E', '<CMD>Oil --float<CR>', desc = '[E]xplorer float (Oil)' },
      { '<leader>fe', '<CMD>Oil<CR>', desc = '[F]ile [E]xplorer (Oil)' },
      { '<leader>fE', '<CMD>Oil --float<CR>', desc = '[F]ile [E]xplorer float' },
    },
  },

  -- ============================================================================
  -- lazygit.nvim: Lazygit integration
  -- ============================================================================
  {
    'kdheepak/lazygit.nvim',
    lazy = true,
    cmd = {
      'LazyGit',
      'LazyGitConfig',
      'LazyGitCurrentFile',
      'LazyGitFilter',
      'LazyGitFilterCurrentFile',
    },
    dependencies = {
      'nvim-lua/plenary.nvim',
    },
    keys = {
      -- Git keymaps under <leader>g
      { '<leader>gg', '<cmd>LazyGit<cr>', desc = '[G]it Lazy[G]it' },
      { '<leader>gG', '<cmd>LazyGitCurrentFile<cr>', desc = '[G]it Lazygit (current file)' },
      { '<leader>gl', '<cmd>LazyGitFilter<cr>', desc = '[G]it [L]og (lazygit)' },
      { '<leader>gf', '<cmd>LazyGitFilterCurrentFile<cr>', desc = '[G]it [F]ile history' },
    },
    config = function()
      -- Lazygit configuration
      vim.g.lazygit_floating_window_scaling_factor = 0.9
      vim.g.lazygit_floating_window_border_chars = { '╭', '─', '╮', '│', '╯', '─', '╰', '│' }
    end,
  },
}

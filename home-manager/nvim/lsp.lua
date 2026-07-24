vim.keymap.set('n', '<space>d', vim.diagnostic.setloclist, {desc = "Add buffer diagnostics to the location list."})

-- Use LspAttach autocommand to only map the following keys
-- after the language server attaches to the current buffer
vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('UserLspConfig', {}),
  callback = function(ev)
    -- Enable completion triggered by <c-x><c-o>
    vim.bo[ev.buf].omnifunc = 'v:lua.vim.lsp.omnifunc'

    -- Buffer local mappings.
    -- See `:help vim.lsp.*` for documentation on any of the below functions
    local opts = function(str)
      return { buffer = ev.buf, desc = str }
    end

    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    if client.server_capabilities.codeLensProvider then vim.lsp.codelens.refresh({ bufnr = bufnr }) end

    vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts("Declaration"))
    vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts("Definition"))
    vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts("Implementation"))
    vim.keymap.set('n', '<M-k>', vim.lsp.buf.signature_help, opts("Signature Help"))
    vim.keymap.set('i', '<M-k>', vim.lsp.buf.signature_help, opts("Signature Help"))
    vim.keymap.set('n', '<space>wa', vim.lsp.buf.add_workspace_folder, opts("Add Workspace Folder"))
    vim.keymap.set('n', '<space>wr', vim.lsp.buf.remove_workspace_folder, opts("Remove Workspace Folder"))
    vim.keymap.set('n', '<space>wl', function()
      print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
    end, opts("List Workspace Folders"))
    vim.keymap.set('n', '<space>D', vim.lsp.buf.type_definition, opts("Type Definition"))
    vim.keymap.set('n', '<space>r', vim.lsp.buf.rename, opts("Rename Symbol"))
    vim.keymap.set({ 'n', 'v' }, '<space>a', vim.lsp.buf.code_action, opts("Code Action"))
    vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts("Buffer References"))
    vim.keymap.set('n', '<localleader>f', function()
      vim.lsp.buf.format { async = true }
    end, opts("Format Buffer"))
  end,
})

-- nvim-lspconfig 0.11+ deprecated the require('lspconfig').X.setup{} framework.
-- Use the built-in vim.lsp.config (merge settings onto the shipped lsp/<name>.lua)
-- + vim.lsp.enable (activate). pruned elixirls/solargraph (unused template leftovers).

vim.lsp.config('nixd', {
  cmd = { "nixd" },
  settings = {
    nixd = {
      nixpkgs = {
        expr = "import <nixpkgs> { }",
      },
      formatting = {
        command = { "nixfmt" },
      },
      -- (removed the templated `options` block that pointed at a foreign flake's
      --  nixosConfigurations.k-on / homeConfigurations."ruixi@k-on" — those don't
      --  exist here and made nixd error. nixpkgs completion/diagnostics still work.)
    },
  },
})

vim.lsp.config('lua_ls', {
  settings = {
    Lua = {
      runtime = {
        version = 'LuaJIT',
        path = vim.split(package.path, ';'),
      },
      diagnostics = { globals = {'vim', 'hs'}, },
      workspace = {
        library = {
          [vim.fn.expand('$VIMRUNTIME/lua')] = true,
          [vim.fn.expand('$VIMRUNTIME/lua/vim/lsp')] = true,
          [vim.fn.expand('/Applications/Hammerspoon.app/Contents/Resources/extensions/hs/')] = true
        },
      },
    },
  },
})

-- pyright (Python), gopls (Go), markdown_oxide, ts_ls (TypeScript) use shipped defaults.
vim.lsp.enable({ 'nixd', 'lua_ls', 'pyright', 'gopls', 'markdown_oxide', 'ts_ls' })

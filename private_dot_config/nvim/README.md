### clear app old compiler parsers (it should recompile them with new treesitter)
```
rm -rf ~/.local/share/nvim/lazy/nvim-treesitter/parser/
```

### install tree-sitter-cli (needed now)
```bash
sudo apt-get install libclang-dev
cargo install --locked tree-sitter-cli
```

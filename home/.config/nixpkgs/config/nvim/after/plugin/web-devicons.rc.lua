local status, devicons = pcall(require, 'nvim-web-devicons')
if (not status) then return end

devicons.setup({
  override = {},
  -- globally enable default icons (default to false)
  -- will get overriden by `get_icons` option
  default = true
})

-- laingrain.lua — neovim colorscheme
-- Structural clone of lackluster: nearly-monochrome gray ramp, one chromatic accent.
-- Gray ramp replaced with cool blue-grays from the laingrain wallpaper palette.
-- #0042ff takes the role luster plays in lackluster — function definitions only.
--
-- Usage: colorscheme laingrain

vim.cmd("highlight clear")
if vim.fn.exists("syntax_on") == 1 then vim.cmd("syntax reset") end
vim.g.colors_name = "laingrain"
vim.opt.background = "dark"

local H = vim.api.nvim_set_hl

-- ── Palette ──────────────────────────────────────────────────────────────────
-- Background ramp (cool blue-gray, darkening toward black)
local bg   = "#000000"   -- pure black (Normal bg)
local bg1  = "#0a0b12"   -- near-black blue
local bg2  = "#131520"   -- very dark blue-gray (floats, menus)
local bg3  = "#1e2130"   -- dark blue-gray (cursorline)
local bg4  = "#303850"   -- medium-dark (line numbers, borders, comments)
local bg5  = "#485870"   -- medium (dim text, titles, fold markers)

-- Foreground ramp (cool blue-tinted grays)
local fg_dim = "#606880"  -- subdued (punctuation, func calls, operators)
local fg_mid = "#8090a8"  -- medium (types, consts, members)
local fg     = "#c0c6d8"  -- main text (from laingrain foreground)
local fg_br  = "#d8dcf0"  -- bright (visual fg on dark, rarely seen)

-- Accent — the single chromatic color, mirrors luster's role in lackluster
local accent  = "#0042ff"  -- function *definitions* (most structural highlight)
local accent2 = "#2878b0"  -- builtins, string escapes, secondary accent

-- Semantic roles
local c_string  = "#4a5878"  -- strings: muted cool blue (like lackluster's #708090 lack)
local c_keyword = "#606880"  -- keywords: same as fg_dim — visible but not dominant
local c_return  = "#2878b0"  -- return/exception: slightly warmer than keyword
local c_comment = "#303850"  -- comments: bg4, barely above background

-- Status/log
local c_green  = "#28a060"  -- add, success
local c_orange = "#b09830"  -- warn, diff-change, deprecated
local c_red    = "#c03050"  -- error, diff-delete
-- ─────────────────────────────────────────────────────────────────────────────

-- ── Core text ────────────────────────────────────────────────────────────────
H(0, "Normal",      { fg = fg,    bg = "none" })
H(0, "NonText",     { fg = bg5 })
H(0, "EndOfBuffer", { fg = bg1 })
H(0, "Whitespace",  { fg = bg2 })
H(0, "Title",       { fg = bg5 })

-- ── Cursor / lines ───────────────────────────────────────────────────────────
H(0, "CursorLine",   { bg = bg3 })
H(0, "CursorLineNr", { fg = fg_mid })
H(0, "LineNr",       { fg = bg4 })
H(0, "SignColumn",   { fg = bg4, bg = "none" })
H(0, "ColorColumn",  { bg = bg1 })

-- ── Search ───────────────────────────────────────────────────────────────────
H(0, "Search",     { fg = bg, bg = c_string })
H(0, "CurSearch",  { fg = bg, bg = fg })
H(0, "IncSearch",  { link = "CurSearch" })
H(0, "Substitute", { link = "Search" })

-- ── Visual ───────────────────────────────────────────────────────────────────
H(0, "Visual",    { fg = bg, bg = fg })
H(0, "VisualNOS", { link = "Visual" })

-- ── Folds ────────────────────────────────────────────────────────────────────
H(0, "Folded",     { fg = bg4 })
H(0, "FoldColumn", { fg = bg4 })

-- ── Messages / health ────────────────────────────────────────────────────────
H(0, "Error",             { fg = c_red })
H(0, "ErrorMsg",          { link = "Error" })
H(0, "WarningMsg",        { fg = c_orange })
H(0, "ModeMsg",           { fg = fg })
H(0, "MoreMsg",           { fg = fg })
H(0, "MsgArea",           { fg = fg })
H(0, "NvimInternalError", { fg = c_red })
H(0, "healthError",       { fg = c_red })
H(0, "healthSuccess",     { fg = c_green })
H(0, "healthWarning",     { fg = c_orange })

-- ── Statusline ───────────────────────────────────────────────────────────────
H(0, "StatusLine",   { fg = fg_mid, bg = bg2 })
H(0, "StatusLineNC", { fg = bg4,    bg = bg1 })

-- ── Tabline ──────────────────────────────────────────────────────────────────
H(0, "Tabline",     { fg = bg4,    bg = bg2 })
H(0, "TablineSel",  { fg = bg,     bg = fg })
H(0, "TablineFill", { fg = fg_mid, bg = bg2 })

-- ── Floats ───────────────────────────────────────────────────────────────────
-- Note: apply_transparency() in lua/config/ui.lua re-applies hardcoded gray
-- values on every ColorScheme event, overriding these. Update those values
-- in ui.lua if you want full coherence with this palette.
H(0, "NormalFloat", { fg = fg,  bg = bg2 })
H(0, "FloatBorder", { fg = bg4, bg = bg2 })
H(0, "FloatTitle",  { fg = bg5 })

-- ── Completion menu ──────────────────────────────────────────────────────────
H(0, "Pmenu",      { fg = fg_dim, bg = bg2 })
H(0, "PmenuSbar",  { bg = bg3 })
H(0, "PmenuThumb", { bg = bg5 })
H(0, "PmenuSel",   { fg = bg,    bg = fg,  bold = true })

-- ── Other UI ─────────────────────────────────────────────────────────────────
H(0, "WinSeparator", { fg = bg4 })
H(0, "MatchParen",   { fg = bg, bg = c_string })
H(0, "QuickFixLine", { fg = c_green })

-- ── Syntax (classic groups) ──────────────────────────────────────────────────
-- Variable hierarchy (mirrors lackluster): main text for vars, step down for everything else
H(0, "Identifier",  { fg = fg_mid })
H(0, "Function",    { fg = accent })    -- definitions: the single chromatic pop
H(0, "Variable",    { fg = fg })
H(0, "Statement",   { fg = c_keyword })
H(0, "Keyword",     { fg = c_keyword })
H(0, "Conditional", { link = "Keyword" })
H(0, "Repeat",      { link = "Keyword" })
H(0, "Label",       { link = "Keyword" })
H(0, "Exception",   { link = "Keyword" })
H(0, "PreProc",     { link = "Keyword" })
H(0, "Type",        { fg = fg_mid })
H(0, "Constant",    { fg = fg_mid })
H(0, "String",      { fg = c_string })
H(0, "Character",   { link = "String" })
H(0, "Number",      { link = "Constant" })
H(0, "Boolean",     { link = "Constant" })
H(0, "Float",       { link = "Constant" })
H(0, "Special",     { fg = c_string })
H(0, "Operator",    { fg = fg_dim })
H(0, "Delimiter",   { fg = fg_dim })
H(0, "Comment",     { fg = c_comment })
H(0, "SpecialComment", { fg = c_comment })
H(0, "Todo",        { fg = fg_dim })
H(0, "Question",    { fg = fg_dim })
H(0, "Quote",       { fg = c_string })

-- ── Treesitter ───────────────────────────────────────────────────────────────
-- Keywords
H(0, "@keyword",            { fg = c_keyword })
H(0, "@keyword.return",     { fg = c_return })   -- return pops slightly from keywords
H(0, "@keyword.exception",  { fg = c_return })
H(0, "@attribute",          { fg = c_keyword })
H(0, "@label",              { fg = bg5 })

-- Types
H(0, "@type",               { fg = fg_mid })
H(0, "@type.definition",    { fg = fg })
H(0, "@type.builtin",       { fg = fg_mid })
H(0, "@type.toml",          { fg = fg })

-- Variables
H(0, "@variable",           { fg = fg })
H(0, "@variable.member",    { fg = fg_mid })
H(0, "@variable.parameter", { fg = fg_mid })
H(0, "@variable.builtin",   { fg = fg })
H(0, "@property",           { fg = fg_mid })
H(0, "@property.json",      { fg = fg_dim })
H(0, "@property.yaml",      { fg = fg_dim })
H(0, "@property.toml",      { fg = fg_dim })

-- Constants
H(0, "@constant",         { fg = fg_mid })
H(0, "@constant.builtin", { fg = fg_mid })
H(0, "@boolean",          { fg = fg_mid })
H(0, "@number",           { fg = fg_mid })

-- Punctuation (low visual weight — disappears into background)
H(0, "@operator",               { fg = fg_dim })
H(0, "@punctuation.bracket",    { fg = fg_dim })
H(0, "@punctuation.special",    { fg = fg_dim })
H(0, "@punctuation.delimiter",  { fg = fg_dim })
H(0, "@constructor",            { fg = fg_dim })

-- Functions — definitions get the accent, calls stay subdued
H(0, "@function",              { fg = accent })
H(0, "@function.method",       { fg = accent })
H(0, "@function.call",         { fg = fg_dim })
H(0, "@function.method.call",  { fg = fg_dim })
H(0, "@function.builtin",      { fg = accent2 })
H(0, "@module.builtin",        { fg = accent2 })

-- Strings
H(0, "@string",           { fg = c_string })
H(0, "@character",        { fg = c_string })
H(0, "@string.escape",    { fg = accent2 })
H(0, "@string.special",   { fg = accent2 })
H(0, "@string.regexp",    { fg = accent2 })

-- Comments
H(0, "@comment",                { fg = c_comment })
H(0, "@comment.documentation",  { fg = c_comment })
H(0, "@comment.todo",           { fg = fg_dim })
H(0, "@comment.note",           { fg = fg_dim })
H(0, "@comment.warn",           { fg = c_orange })
H(0, "@comment.error",          { fg = c_red })

-- Markup
H(0, "@markup.heading",             { fg = bg5 })
H(0, "@markup.quote",               { fg = fg_dim })
H(0, "@markup.strong",              { fg = bg4 })
H(0, "@markup.italic",              { fg = bg4 })
H(0, "@markup.strikethrough",       { fg = bg4 })
H(0, "@markup.underline",           { underline = true })
H(0, "@markup.list",                { fg = bg4 })
H(0, "@markup.list.checked",        { fg = accent2 })
H(0, "@markup.list.unchecked",      { fg = c_red })
H(0, "@markup.link",                { fg = fg_dim })
H(0, "@markup.link.label",          { fg = fg_dim })
H(0, "@markup.link.url",            { fg = bg4 })
H(0, "@markup.math",                { fg = c_orange })

-- Tags (HTML/JSX)
H(0, "@tag",            { fg = bg5 })
H(0, "@tag.delimiter",  { fg = bg5 })
H(0, "@tag.attribute",  { fg = bg4 })
H(0, "@tag.builtin",    { fg = bg5 })

-- LSP (linked to treesitter equivalents)
H(0, "@lsp.type.keyword",    { link = "@keyword" })
H(0, "@lsp.type.function",   { link = "@function" })
H(0, "@lsp.type.variable",   { link = "@variable" })
H(0, "@lsp.type.operator",   { link = "@operator" })
H(0, "@lsp.type.type",       { link = "@type" })
H(0, "@lsp.type.string",     { link = "@string" })
H(0, "@lsp.type.number",     { link = "@number" })
H(0, "@lsp.type.boolean",    { link = "@boolean" })
H(0, "@lsp.type.enumMember", { link = "@variable.member" })

-- ── Diagnostics ──────────────────────────────────────────────────────────────
-- Virtual text and hover: all muted (bg4) except error — mirrors lackluster
H(0, "DiagnosticOk",          { fg = bg4 })
H(0, "DiagnosticHint",        { fg = bg4 })
H(0, "DiagnosticInfo",        { fg = bg4 })
H(0, "DiagnosticWarn",        { fg = bg4 })
H(0, "DiagnosticError",       { fg = c_red })
H(0, "DiagnosticDeprecated",  { fg = bg4 })
H(0, "DiagnosticUnnecessary", { fg = bg4 })
H(0, "DiagnosticVirtualTextOk",   { fg = bg4 })
H(0, "DiagnosticVirtualTextHint", { fg = bg4 })
H(0, "DiagnosticVirtualTextInfo", { fg = bg4 })
H(0, "DiagnosticVirtualTextWarn", { fg = bg4 })
H(0, "DiagnosticVirtualTextError",{ fg = c_red })
-- Signs: full color
H(0, "DiagnosticSignOk",         { fg = c_green })
H(0, "DiagnosticSignInfo",        { fg = fg_dim })
H(0, "DiagnosticSignHint",        { fg = fg_dim })
H(0, "DiagnosticSignWarn",        { fg = c_orange })
H(0, "DiagnosticSignError",       { fg = c_red })
H(0, "DiagnosticSignDeprecated",  { fg = c_orange })
-- Underlines
H(0, "DiagnosticUnderlineOk",    { undercurl = true, sp = c_green })
H(0, "DiagnosticUnderlineWarn",  { undercurl = true, sp = c_orange })
H(0, "DiagnosticUnderlineInfo",  { undercurl = true, sp = fg_dim })
H(0, "DiagnosticUnderlineHint",  { undercurl = true, sp = fg_dim })
H(0, "DiagnosticUnderlineError", { undercurl = true, sp = c_red })

-- ── Diff ─────────────────────────────────────────────────────────────────────
H(0, "Added",         { fg = c_green })
H(0, "Changed",       { fg = fg_dim })
H(0, "Removed",       { fg = c_orange })
H(0, "DiffAdd",       { fg = c_green })
H(0, "DiffChange",    { fg = fg_dim })
H(0, "DiffDelete",    { fg = c_orange })
H(0, "DiffText",      { fg = bg5 })
H(0, "DiffAdded",     { fg = c_green })
H(0, "DiffRemoved",   { fg = c_orange })
H(0, "DiffChanged",   { fg = fg_dim })
H(0, "DiffIndexLine", { fg = bg5 })
H(0, "DiffLine",      { fg = fg_dim })

-- ── Spell ────────────────────────────────────────────────────────────────────
H(0, "SpellBad",   { undercurl = true })
H(0, "SpellLocal", { link = "SpellBad" })
H(0, "SpellCap",   { link = "SpellBad" })
H(0, "SpellRare",  { link = "SpellBad" })

-- ── Plugins ──────────────────────────────────────────────────────────────────

-- Gitsigns
H(0, "GitSignsAdd",            { fg = c_green })
H(0, "GitSignsChange",         { fg = fg_dim })
H(0, "GitSignsDelete",         { fg = c_orange })
H(0, "GitSignsAddNr",          { fg = c_green })
H(0, "GitSignsChangeNr",       { fg = fg_dim })
H(0, "GitSignsDeleteNr",       { fg = c_orange })

-- NvimTree
H(0, "NvimTreeNormal",              { fg = fg,      bg = "none" })
H(0, "NvimTreeNormalNC",            { fg = fg,      bg = "none" })
H(0, "NvimTreeFolderName",          { fg = accent2 })
H(0, "NvimTreeFolderIcon",          { fg = accent2 })
H(0, "NvimTreeOpenedFolderName",    { fg = accent })
H(0, "NvimTreeRootFolder",          { fg = bg5 })
H(0, "NvimTreeExecFile",            { fg = c_green })
H(0, "NvimTreeSymlink",             { fg = c_string })
H(0, "NvimTreeBookmark",            { fg = c_string })
H(0, "NvimTreeEmptyFolderName",     { fg = bg5 })
H(0, "NvimTreeIndentMarker",        { fg = bg3 })

-- Bufferline
H(0, "BufferLineFill",              { bg = bg1 })
H(0, "BufferLineBackground",        { fg = bg4,    bg = bg2 })
H(0, "BufferLineBufferSelected",    { fg = fg,     bg = "none", bold = true })
H(0, "BufferLineBufferVisible",     { fg = fg_dim, bg = bg1 })
H(0, "BufferLineSeparator",         { fg = bg1,    bg = bg2 })
H(0, "BufferLineIndicatorSelected", { fg = accent })

-- Indent-blankline
H(0, "IblIndent", { fg = bg3 })
H(0, "IblScope",  { fg = bg4 })

-- Which-key (overrides apply_transparency() hardcoded values)
H(0, "WhichKeyFloat",  { bg = bg2 })
H(0, "WhichKeyBorder", { bg = bg2, fg = bg4 })
H(0, "WhichKey",       { fg = fg,  bold = true })
H(0, "WhichKeySep",    { fg = bg4 })
H(0, "WhichKeyDesc",   { fg = fg_mid })
H(0, "WhichKeyGroup",  { fg = accent2, bold = true })

-- Trouble
H(0, "TroubleNormal", { fg = bg5, bg = "none" })
H(0, "TroubleCode",   { fg = fg_dim })

-- CMP (completion)
H(0, "CmpItemKind",             { fg = fg_mid })
H(0, "CmpItemAbbrMatch",        { fg = accent2, bold = true })
H(0, "CmpItemAbbrMatchFuzzy",   { fg = accent2 })
H(0, "CmpItemAbbr",             { fg = fg_dim })
H(0, "CmpItemAbbrDeprecated",   { fg = bg4, strikethrough = true })
H(0, "CmpItemMenu",             { fg = c_string })

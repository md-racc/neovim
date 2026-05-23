-- =============================================================================
-- CODE OUTLINE
-- =============================================================================

local ok_aerial, aerial = pcall(require, "aerial")
if ok_aerial then
  aerial.setup({ attach_mode = "cursor", layout = { default_direction = "right" } })
end

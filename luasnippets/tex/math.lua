local ls = require("luasnip")
local s  = ls.snippet
local t  = ls.text_node
local i  = ls.insert_node

return {
  -- Math environments
  s("mk",    { t("$"), i(1), t("$") }),
  s("dm",    { t({ "\\[", "\t" }), i(1), t({ "", "\\]" }) }),
  s("align", { t({ "\\begin{align*}", "\t" }), i(1), t({ "", "\\end{align*}" }) }),
  s("cases", { t({ "\\begin{cases}", "\t" }), i(1), t(" & \\text{if } "), i(2), t({ "", "\\end{cases}" }) }),
  s("mat",   { t({ "\\begin{pmatrix}", "\t" }), i(1), t({ "", "\\end{pmatrix}" }) }),

  -- Fractions / powers
  s("frac",  { t("\\frac{"), i(1), t("}{"), i(2), t("}") }),
  s("sqrt",  { t("\\sqrt{"), i(1), t("}") }),

  -- Sums, integrals, limits
  s("sum",   { t("\\sum_{"), i(1, "n=1"), t("}^{"), i(2, "\\infty"), t("}") }),
  s("prod",  { t("\\prod_{"), i(1, "n=1"), t("}^{"), i(2, "\\infty"), t("}") }),
  s("int",   { t("\\int_{"), i(1, "a"), t("}^{"), i(2, "b"), t("}"), i(3), t("\\,d"), i(4, "x") }),
  s("lim",   { t("\\lim_{"), i(1, "x"), t(" \\to "), i(2, "\\infty"), t("}") }),

  -- Decorators
  s("hat",   { t("\\hat{"),   i(1), t("}") }),
  s("vec",   { t("\\vec{"),   i(1), t("}") }),
  s("bar",   { t("\\bar{"),   i(1), t("}") }),
  s("tilde", { t("\\tilde{"), i(1), t("}") }),

  -- Norms and absolute value
  s("norm",  { t("\\|"), i(1), t("\\|") }),
  s("abs",   { t("|"),   i(1), t("|") }),

  -- Text in math mode
  s("text",  { t("\\text{"), i(1), t("}") }),

  -- Derivatives
  s("ddt",   { t("\\frac{d}{dt}") }),
  s("ddx",   { t("\\frac{d}{dx}") }),
  s("ppt",   { t("\\frac{\\partial}{\\partial t}") }),
  s("ppx",   { t("\\frac{\\partial}{\\partial x}") }),
  s("pp",    { t("\\frac{\\partial "), i(1), t("}{\\partial "), i(2), t("}") }),

  -- Common symbols
  s("inf",   { t("\\infty") }),
  s("...",   { t("\\ldots") }),
  s("cdots", { t("\\cdots") }),
  s("EE",    { t("\\exists") }),
  s("AA",    { t("\\forall") }),
  s("inn",   { t("\\in") }),
  s("notin", { t("\\notin") }),
  s("sub",   { t("\\subset") }),
  s("sube",  { t("\\subseteq") }),
  s("=>",    { t("\\implies") }),
  s("<=>",   { t("\\iff") }),
  s("nab",   { t("\\nabla") }),
  s("pd",    { t("\\partial") }),

  -- Greek letters
  s("alpha",   { t("\\alpha") }),
  s("beta",    { t("\\beta") }),
  s("gamma",   { t("\\gamma") }),
  s("Gamma",   { t("\\Gamma") }),
  s("delta",   { t("\\delta") }),
  s("Delta",   { t("\\Delta") }),
  s("epsilon", { t("\\epsilon") }),
  s("zeta",    { t("\\zeta") }),
  s("eta",     { t("\\eta") }),
  s("theta",   { t("\\theta") }),
  s("Theta",   { t("\\Theta") }),
  s("kappa",   { t("\\kappa") }),
  s("lambda",  { t("\\lambda") }),
  s("Lambda",  { t("\\Lambda") }),
  s("mu",      { t("\\mu") }),
  s("nu",      { t("\\nu") }),
  s("xi",      { t("\\xi") }),
  s("pi",      { t("\\pi") }),
  s("Pi",      { t("\\Pi") }),
  s("rho",     { t("\\rho") }),
  s("sigma",   { t("\\sigma") }),
  s("Sigma",   { t("\\Sigma") }),
  s("tau",     { t("\\tau") }),
  s("phi",     { t("\\phi") }),
  s("Phi",     { t("\\Phi") }),
  s("chi",     { t("\\chi") }),
  s("psi",     { t("\\psi") }),
  s("Psi",     { t("\\Psi") }),
  s("omega",   { t("\\omega") }),
  s("Omega",   { t("\\Omega") }),
}

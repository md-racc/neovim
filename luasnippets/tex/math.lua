-- =============================================================================
-- luasnippets/tex/math.lua
-- LaTeX snippets ported from Obsidian latex-suite-snippets.js
-- Requires: vimtex (math-zone detection), LuaSnip (enable_autosnippets = true)
--
-- Return format: regular_snippets, autosnippets
-- Auto snippets fire when typed; regular snippets expand via Tab/cmp.
-- =============================================================================

local ls  = require("luasnip")
local s   = ls.snippet
local sn  = ls.snippet_node
local t   = ls.text_node
local i   = ls.insert_node
local f   = ls.function_node
local d   = ls.dynamic_node
local rep = require("luasnip.extras").rep

-- ---------------------------------------------------------------------------
-- Context conditions
-- ---------------------------------------------------------------------------
local in_math = function() return vim.fn["vimtex#syntax#in_mathzone"]() == 1 end
local in_text = function() return vim.fn["vimtex#syntax#in_mathzone"]() == 0 end
local mc = { condition = in_math, show_condition = in_math }
local tc = { condition = in_text, show_condition = in_text }

-- ---------------------------------------------------------------------------
-- Snippet constructors
-- ---------------------------------------------------------------------------
-- math-mode auto
local function ma(trig, nodes, extra)
  return s(vim.tbl_extend("force", { trig = trig }, extra or {}), nodes, mc)
end
-- text-mode auto
local function ta(trig, nodes, extra)
  return s(vim.tbl_extend("force", { trig = trig }, extra or {}), nodes, tc)
end
-- math-mode manual (expanded via Tab / cmp)
local function mm(trig, nodes)
  return s(trig, nodes, mc)
end
-- capture group shorthand (1-indexed, matches latex-suite [[0]] = capture 1)
local function cap(n)
  return f(function(_, snip) return snip.captures[n] end)
end
-- visual selection (use d(n, get_visual) in snippet body)
local function get_visual(_, parent)
  local sel = parent.snippet.env.SELECT_RAW
  return (sel and #sel > 0) and sn(nil, i(1, sel)) or sn(nil, i(1))
end

-- ---------------------------------------------------------------------------
-- Greek letters (for generated \greek hat/bar/etc. snippets)
-- ---------------------------------------------------------------------------
local GREEK = {
  "alpha","beta","gamma","Gamma","delta","Delta","epsilon","varepsilon",
  "zeta","eta","theta","Theta","vartheta","iota","kappa","lambda","Lambda",
  "mu","nu","xi","Xi","pi","Pi","rho","sigma","Sigma","tau",
  "upsilon","Upsilon","phi","Phi","varphi","chi","psi","Psi","omega","Omega",
}

-- ===========================================================================
-- MANUAL SNIPPETS  (first return table)
-- ===========================================================================
local snips = {
  -- Expand \command to full form with bounds (type the command + Tab)
  mm("\\sum",  { t("\\sum_{"), i(1,"i"), t("="), i(2,"1"), t("}^{"), i(3,"N"), t("} "), i(4) }),
  mm("\\prod", { t("\\prod_{"), i(1,"i"), t("="), i(2,"1"), t("}^{"), i(3,"N"), t("} "), i(4) }),
  mm("\\int",  { t("\\int "), i(1), t(" \\, d"), i(2,"x"), t(" "), i(3) }),
  mm("\\bigcap", { t("\\bigcap_{"), i(1), t("}^{"), i(2), t("} "), i(3) }),
  mm("\\bigcup", { t("\\bigcup_{"), i(1), t("}^{"), i(2), t("} "), i(3) }),

  -- Partial derivative (manual: "par" Tab)
  mm("par", { t("\\frac{ \\partial "), i(1,"y"), t(" }{ \\partial "), i(2,"x"), t(" } "), i(3) }),

  -- Convenience aliases kept from old config (also available as auto // and sq)
  mm("frac", { t("\\frac{"), i(1), t("}{"), i(2), t("}"), i(3) }),
  mm("sqrt", { t("\\sqrt{"), i(1), t("}"), i(2) }),
}

-- ===========================================================================
-- AUTOSNIPPETS  (second return table)
-- ===========================================================================
local autosnips = {

  -- =========================================================================
  -- MATH ENVIRONMENTS  (text-mode: fire outside $...$, create math blocks)
  -- =========================================================================
  ta("mk", { t("$"), i(1), t("$") }),
  ta("dm", { t({"\\[", "\t"}), i(1), t({"", "\\]"}) }, { wordTrig = true }),

  -- \begin{env} ... \end{env}  (no math/text condition: useful everywhere in tex)
  s({ trig = "beg" }, {
    t("\\begin{"), i(1,"env"), t({"}", "\t"}), i(2), t({"", "\\end{"}), rep(1), t("}"),
  }),

  -- =========================================================================
  -- GREEK LETTERS  (@x shortcuts, math mode)
  -- =========================================================================
  ma("@a", { t("\\alpha") }),
  ma("@b", { t("\\beta") }),
  ma("@g", { t("\\gamma") }),
  ma("@G", { t("\\Gamma") }),
  ma("@d", { t("\\delta") }),
  ma("@D", { t("\\Delta") }),
  ma("@e", { t("\\epsilon") }),
  ma(":e", { t("\\varepsilon") }),
  ma("@z", { t("\\zeta") }),
  ma("@t", { t("\\theta") }),
  ma("@T", { t("\\Theta") }),
  ma(":t", { t("\\vartheta") }),
  ma("@i", { t("\\iota") }),
  ma("@k", { t("\\kappa") }),
  ma("@l", { t("\\lambda") }),
  ma("@L", { t("\\Lambda") }),
  ma("@s", { t("\\sigma") }),
  ma("@S", { t("\\Sigma") }),
  ma("@u", { t("\\upsilon") }),
  ma("@U", { t("\\Upsilon") }),
  ma("@o", { t("\\omega") }),
  ma("@O", { t("\\Omega") }),
  ma("ome", { t("\\omega") }),
  ma("Ome", { t("\\Omega") }),

  -- Greek letter full names (math mode, manual-style but kept as auto for speed)
  ma("alpha",   { t("\\alpha") }),   ma("beta",    { t("\\beta") }),
  ma("gamma",   { t("\\gamma") }),   ma("Gamma",   { t("\\Gamma") }),
  ma("delta",   { t("\\delta") }),   ma("Delta",   { t("\\Delta") }),
  ma("epsilon", { t("\\epsilon") }), ma("zeta",    { t("\\zeta") }),
  ma("eta",     { t("\\eta") }),     ma("theta",   { t("\\theta") }),
  ma("Theta",   { t("\\Theta") }),   ma("kappa",   { t("\\kappa") }),
  ma("lambda",  { t("\\lambda") }),  ma("Lambda",  { t("\\Lambda") }),
  ma("mu",      { t("\\mu") }),      ma("nu",      { t("\\nu") }),
  ma("xi",      { t("\\xi") }),      ma("pi",      { t("\\pi") }),
  ma("Pi",      { t("\\Pi") }),      ma("rho",     { t("\\rho") }),
  ma("sigma",   { t("\\sigma") }),   ma("Sigma",   { t("\\Sigma") }),
  ma("tau",     { t("\\tau") }),     ma("phi",     { t("\\phi") }),
  ma("Phi",     { t("\\Phi") }),     ma("chi",     { t("\\chi") }),
  ma("psi",     { t("\\psi") }),     ma("Psi",     { t("\\Psi") }),
  ma("omega",   { t("\\omega") }),   ma("Omega",   { t("\\Omega") }),

  -- =========================================================================
  -- TEXT IN MATH, FONTS
  -- =========================================================================
  ma("text", { t("\\text{ "), i(1), t(" }"), i(2) }),
  ma("bf",   { t("\\mathbf{"), i(1), t("}") }),
  ma("rm",   { t("\\mathrm{"), i(1), t("}"), i(2) }),

  -- =========================================================================
  -- BASIC OPERATIONS
  -- =========================================================================
  ma("sr",   { t("^{2}") }),
  ma("cb",   { t("^{3}") }),
  ma("rd",   { t("^{"), i(1), t("}"), i(2) }),
  ma("_",    { t("_{"), i(1), t("}"), i(2) }),
  ma("sts",  { t("_\\text{"), i(1), t("}") }),
  ma("sq",   { t("\\sqrt{ "), i(1), t(" }"), i(2) }),
  ma("//",   { t("\\frac{"), i(1), t("}{"), i(2), t("}"), i(3) }),
  ma("ee",   { t("e^{ "), i(1), t(" }"), i(2) }),
  ma("invs", { t("^{-1}") }),
  ma("conj", { t("^{*}") }),
  ma("dag",  { t("^{\\dagger}") }),

  -- exp/log/ln: add backslash, preserve preceding char
  ma("([^\\\\])(exp|log|ln)", { cap(1), t("\\"), cap(2) }, { regTrig = true }),
  -- det: add backslash
  ma("([^\\\\])(det)", { cap(1), t("\\det") }, { regTrig = true }),
  -- Re, Im, trace
  ma("Re",    { t("\\mathrm{Re}") }),
  ma("Im",    { t("\\mathrm{Im}") }),
  ma("trace", { t("\\mathrm{Tr}") }),

  -- =========================================================================
  -- DECORATORS  (no preceding letter)
  -- =========================================================================
  ma("hat",   { t("\\hat{"),       i(1), t("}"), i(2) }),
  ma("bar",   { t("\\bar{"),       i(1), t("}"), i(2) }),
  ma("dot",   { t("\\dot{"),       i(1), t("}"), i(2) }, { priority = 100 }),
  ma("ddot",  { t("\\ddot{"),      i(1), t("}"), i(2) }),
  ma("cdot",  { t("\\cdot") }),
  ma("tilde", { t("\\tilde{"),     i(1), t("}"), i(2) }),
  ma("und",   { t("\\underline{"), i(1), t("}"), i(2) }),
  ma("vec",   { t("\\vec{"),       i(1), t("}"), i(2) }),
  ma("pmod",  { t("\\pmod{"), i(1,"n"), t("}"), i(2) }),

  -- Decorators with preceding letter: xhat → \hat{x}
  ma("([a-zA-Z])hat",   { t("\\hat{"),       cap(1), t("}") }, { regTrig = true }),
  ma("([a-zA-Z])bar",   { t("\\bar{"),       cap(1), t("}") }, { regTrig = true }),
  ma("([a-zA-Z])dot",   { t("\\dot{"),       cap(1), t("}") }, { regTrig = true, priority = 100 }),
  ma("([a-zA-Z])ddot",  { t("\\ddot{"),      cap(1), t("}") }, { regTrig = true, priority = 200 }),
  ma("([a-zA-Z])tilde", { t("\\tilde{"),     cap(1), t("}") }, { regTrig = true }),
  ma("([a-zA-Z])und",   { t("\\underline{"), cap(1), t("}") }, { regTrig = true }),
  ma("([a-zA-Z])vec",   { t("\\vec{"),       cap(1), t("}") }, { regTrig = true }),
  -- Bold: x., or .,x → \mathbf{x}
  ma("([a-zA-Z]),%.", { t("\\mathbf{"), cap(1), t("}") }, { regTrig = true }),
  ma("([a-zA-Z])%.,", { t("\\mathbf{"), cap(1), t("}") }, { regTrig = true }),

  -- =========================================================================
  -- AUTO SUBSCRIPTS
  -- x3 → x_{3},  x_{3}4 → x_{34}
  -- =========================================================================
  ma("([A-Za-z])(%d)", { cap(1), t("_{"), cap(2), t("}") },
    { regTrig = true, priority = 100 }),
  ma("([A-Za-z])_{(%d+)}(%d)", { cap(1), t("_{"), cap(2), cap(3), t("}") },
    { regTrig = true, priority = 200 }),

  -- =========================================================================
  -- NAMED SUBSCRIPTS
  -- =========================================================================
  ma("xnn", { t("x_{n}") }),  ma("xii", { t("x_{i}") }),
  ma("xjj", { t("x_{j}") }),  ma("xkk", { t("x_{k}") }),
  ma("xp1", { t("x_{n+1}") }),
  ma("ynn", { t("y_{n}") }),  ma("yii", { t("y_{i}") }),
  ma("yjj", { t("y_{j}") }),  ma("ykk", { t("y_{k}") }),
  ma("Aii", { t("A_{i}") }),  ma("Ajj", { t("A_{j}") }),
  ma("Akk", { t("A_{k}") }),  ma("Ann", { t("A_{n}") }),
  ma("vii", { t("v_{i}") }),  ma("vjj", { t("v_{j}") }),
  ma("vkk", { t("v_{k}") }),  ma("vnn", { t("v_{n}") }),
  ma("aii", { t("a_{i}") }),  ma("ajj", { t("a_{j}") }),
  ma("akk", { t("a_{k}") }),  ma("ann", { t("a_{n}") }),
  ma("cii", { t("c_{i}") }),  ma("cjj", { t("c_{j}") }),
  ma("ckk", { t("c_{k}") }),  ma("cnn", { t("c_{n}") }),
  ma("nii", { t("n_{i}") }),  ma("njj", { t("n_{j}") }),
  ma("nkk", { t("n_{k}") }),

  -- =========================================================================
  -- SYMBOLS
  -- =========================================================================
  ma("ooo",  { t("\\infty") }),
  ma("sum",  { t("\\sum") }),
  ma("prod", { t("\\prod") }),
  ma("lim",  { t("\\lim_{ "), i(1,"n"), t(" \\to "), i(2,"\\infty"), t(" } "), i(3) }),
  ma("+-",   { t("\\pm") }),
  ma("-+",   { t("\\mp") }),
  ma("...",  { t("\\dots") }),
  ma("nabl", { t("\\nabla") }),
  ma("xx",   { t("\\times") }),
  ma("**",   { t("\\cdot") }),
  ma("para", { t("\\parallel") }),
  ma("mid",  { t("\\mid ") }),

  -- =========================================================================
  -- RELATIONS
  -- =========================================================================
  ma("===",  { t("\\equiv") }),
  ma("!=",   { t("\\neq") }),
  ma(">=",   { t("\\geq") }),
  ma("<=",   { t("\\leq") }),
  ma(">>",   { t("\\gg") }),
  ma("<<",   { t("\\ll") }),
  ma("simm", { t("\\sim") }),
  ma("sim=", { t("\\simeq") }),
  ma("prop", { t("\\propto") }),

  -- =========================================================================
  -- ARROWS
  -- =========================================================================
  ma("<->", { t("\\leftrightarrow ") }),
  ma("->",  { t("\\to") }),
  ma("!>",  { t("\\mapsto") }),
  ma("=>",  { t("\\implies") }),
  ma("=<",  { t("\\impliedby") }),

  -- =========================================================================
  -- SET THEORY & LOGIC
  -- =========================================================================
  ma("and",   { t("\\cap") }),
  ma("orr",   { t("\\cup") }),
  ma("band",  { t("\\bigcap") }),
  ma("borr",  { t("\\bigcup") }),
  ma("inn",   { t("\\in") }),
  ma("notin", { t("\\not\\in") }),
  ma("nin",   { t("\\notin") }),
  ma("sub=",  { t("\\subseteq") }),
  ma("sup=",  { t("\\supseteq") }),
  ma("subn",  { t("\\nsubseteq ") }),
  ma("supn",  { t("\\supsetneq ") }),
  ma("eset",  { t("\\emptyset") }),
  ma("empty", { t("\\varnothing") }),
  ma("set",   { t("\\{ "), i(1), t(" \\}"), i(2) }),
  -- Quantifiers
  ma("fa",    { t("\\forall ") }),
  ma("ex",    { t("\\exists ") }),
  ma("nex",   { t("\\nexists ") }),
  -- Logical connectives
  ma("iff",   { t("\\iff ") }),
  ma("neg",   { t("\\neg ") }),
  ma("land",  { t("\\land ") }),
  ma("lor",   { t("\\lor ") }),

  -- =========================================================================
  -- NAMED SETS
  -- =========================================================================
  ma("LL",  { t("\\mathcal{L}") }),
  ma("HH",  { t("\\mathcal{H}") }),
  ma("CC",  { t("\\mathbb{C}") }),
  ma("RR",  { t("\\mathbb{R}") }),
  ma("ZZ",  { t("\\mathbb{Z}") }),
  ma("NN",  { t("\\mathbb{N}") }),
  ma("QQ",  { t("\\mathbb{Q}") }),
  ma("pow", { t("\\mathcal{P}("), i(1), t(")") }),

  -- =========================================================================
  -- DERIVATIVES & INTEGRALS
  -- =========================================================================
  ma("ddt",  { t("\\frac{d}{dt} ") }),
  -- pa + two letters → specific partial: paxy → \frac{\partial x}{\partial y}
  ma("pa([A-Za-z])([A-Za-z])", {
    t("\\frac{ \\partial "), cap(1), t(" }{ \\partial "), cap(2), t(" } "),
  }, { regTrig = true }),
  -- int (unescaped): add backslash, preserve preceding char
  ma("([^\\\\])int", { cap(1), t("\\int") }, { regTrig = true, priority = 100 }),
  -- Definite integral with bounds
  ma("dint",  { t("\\int_{"), i(1,"0"), t("}^{"), i(2,"1"), t("} "), i(3), t(" \\, d"), i(4,"x"), t(" "), i(5) }),
  ma("oint",  { t("\\oint") }),
  ma("iint",  { t("\\iint") }),
  ma("iiint", { t("\\iiint") }),
  ma("oinf",  { t("\\int_{0}^{\\infty} "), i(1), t(" \\, d"), i(2,"x"), t(" "), i(3) }),
  ma("infi",  { t("\\int_{-\\infty}^{\\infty} "), i(1), t(" \\, d"), i(2,"x"), t(" "), i(3) }),

  -- =========================================================================
  -- TRIG FUNCTIONS  (add backslash before bare function names)
  -- =========================================================================
  ma("([^\\\\])(arcsin|arccos|arctan|sin|cos|tan|csc|sec|cot)",
    { cap(1), t("\\"), cap(2) }, { regTrig = true }),
  ma("([^\\\\])(sinh|cosh|tanh|coth)",
    { cap(1), t("\\"), cap(2) }, { regTrig = true }),

  -- =========================================================================
  -- VISUAL OPERATIONS  (select text in visual mode, then trigger snippet)
  -- =========================================================================
  ma("U", { t("\\underbrace{ "), d(1, get_visual), t(" }_{ "), i(2), t(" }") }),
  ma("O", { t("\\overbrace{ "),  d(1, get_visual), t(" }^{ "), i(2), t(" }") }),
  ma("B", { t("\\underset{ "),   i(1), t(" }{ "),  d(2, get_visual), t(" }") }),
  ma("C", { t("\\cancel{ "),     d(1, get_visual), t(" }") }),
  ma("K", { t("\\cancelto{ "),   i(1), t(" }{ "),  d(2, get_visual), t(" }") }),
  ma("S", { t("\\sqrt{ "),       d(1, get_visual), t(" }") }),

  -- =========================================================================
  -- PHYSICS / QUANTUM MECHANICS
  -- =========================================================================
  ma("kbt",   { t("k_{B}T") }),
  ma("msun",  { t("M_{\\odot}") }),
  ma("xor",   { t("\\oplus ") }),
  ma("ox",    { t("\\otimes ") }),
  ma("bra",   { t("\\bra{"),    i(1), t("} "), i(2) }),
  ma("ket",   { t("\\ket{"),    i(1), t("} "), i(2) }),
  ma("brk",   { t("\\braket{ "), i(1), t(" | "), i(2), t(" } "), i(3) }),
  ma("outer", { t("\\ket{"), i(1,"\\psi"), t("} \\bra{"), rep(1), t("} "), i(2) }),

  -- =========================================================================
  -- CHEMISTRY
  -- =========================================================================
  ma("pu",  { t("\\pu{ "),  i(1), t(" }") }),
  ma("cee", { t("\\ce{ "),  i(1), t(" }") }),
  ma("he4", { t("{}^{4}_{2}He ") }),
  ma("he3", { t("{}^{3}_{2}He ") }),
  ma("iso", { t("{}^{"), i(1,"4"), t("}_{"), i(2,"2"), t("}"), i(3,"He") }),

  -- =========================================================================
  -- MATRIX / MISC ENVIRONMENTS  (regex: match variant prefix)
  -- =========================================================================
  -- pmat, bmat, Bmat, vmat, Vmat → \begin{pmatrix}...\end{pmatrix}
  ma("([pbBvV]mat)", {
    t("\\begin{"), cap(1), t({"rix}", "\t"}), i(1), t({"", "\\end{"}), cap(1), t("rix}"),
  }, { regTrig = true }),
  -- matrix, cases, align, array
  ma("(matrix|cases|align|array)", {
    t("\\begin{"), cap(1), t({"}", "\t"}), i(1), t({"", "\\end{"}), cap(1), t("}"),
  }, { regTrig = true }),

  -- =========================================================================
  -- BRACKETS
  -- =========================================================================
  ma("avg",   { t("\\langle "),  i(1), t(" \\rangle "), i(2) }),
  ma("norm",  { t("\\lvert "),   i(1), t(" \\rvert "), i(2) }, { priority = 200 }),
  ma("Norm",  { t("\\lVert "),   i(1), t(" \\rVert "), i(2) }, { priority = 200 }),
  ma("ceil",  { t("\\lceil "),   i(1), t(" \\rceil "), i(2) }),
  ma("floor", { t("\\lfloor "),  i(1), t(" \\rfloor "), i(2) }),
  ma("mod",   { t("|"), i(1), t("|"), i(2) }),
  ma("lr(",   { t("\\left( "),   i(1), t(" \\right) "), i(2) }),
  ma("lr{",   { t("\\left\\{ "), i(1), t(" \\right\\} "), i(2) }),
  ma("lr[",   { t("\\left[ "),   i(1), t(" \\right] "), i(2) }),
  ma("lr|",   { t("\\left| "),   i(1), t(" \\right| "), i(2) }),
  ma("lra",   { t("\\left< "),   i(1), t(" \\right> "), i(2) }),

  -- =========================================================================
  -- MISC MATH
  -- =========================================================================
  ma("tag", { t("\\tag{"), i(1), t("}"), i(2) }),
  ma("tayl", {
    i(1,"f"), t("("), i(2,"x"), t(" + "), i(3,"h"), t(") = "),
    rep(1), t("("), rep(2), t(") + "),
    rep(1), t("'("), rep(2), t(")"), rep(3),
    t(" + "), rep(1), t("''("), rep(2), t(") \\frac{"), rep(3), t("^{2}}{2!} + \\dots"), i(4),
  }),

  -- =========================================================================
  -- ASYMPTOTIC NOTATION  (COP3503)
  -- =========================================================================
  ma("Oh",      { t("\\mathcal{O}("), i(1), t(")") }),
  ma("Om",      { t("\\Omega("),      i(1), t(")") }),
  ma("Th",      { t("\\Theta("),      i(1), t(")") }),
  ma("lgn",     { t("\\log n") }),
  ma("lgN",     { t("\\log N") }),
  ma("nlgn",    { t("n \\log n") }),
  ma("polylog", { t("\\text{poly}\\log(n)") }),
  ma("Oconst",  { t("\\mathcal{O}(1)") }),
  ma("Olin",    { t("\\mathcal{O}(n)") }),
  ma("Olog",    { t("\\mathcal{O}(\\log n)") }),
  ma("Onlog",   { t("\\mathcal{O}(n \\log n)") }),
  ma("Osq",     { t("\\mathcal{O}(n^2)") }),
  ma("Ocub",    { t("\\mathcal{O}(n^3)") }),
  ma("Oexp",    { t("\\mathcal{O}(2^n)") }),
  ma("Ofac",    { t("\\mathcal{O}(n!)") }),

  -- =========================================================================
  -- TEXT MODE: PROOF SCAFFOLDING  (COT3100)
  -- =========================================================================
  ta("tfae",  { t({"TFAE:", "1. "}), i(1), t({"", "2. "}), i(2), t({"", "3. "}), i(3) }),
  ta("wts",   { t("**WTS:** "), i(1) }),
  ta("pf>",   { t("**Proof.** "), i(1), t(" $\\square$") }),
  ta("qed",   { t("$\\square$") }),
  ta("thm>",  { t("**Theorem.** "), i(1) }),
  ta("lem>",  { t("**Lemma.** "), i(1) }),
  ta("cor>",  { t("**Corollary.** "), i(1) }),
  ta("defn>", { t("**Definition.** "), i(1) }),
}

-- ---------------------------------------------------------------------------
-- Generated snippets: \greek hat/bar/dot/etc. and \greek sr/cb/rd
-- e.g.  \alpha hat → \hat{\alpha},   \alpha sr → \alpha^{2}
-- ---------------------------------------------------------------------------
local decorators = {
  { "hat",   "\\hat" },
  { "bar",   "\\bar" },
  { "dot",   "\\dot" },
  { "ddot",  "\\ddot" },
  { "tilde", "\\tilde" },
  { "und",   "\\underline" },
  { "vec",   "\\vec" },
}
for _, g in ipairs(GREEK) do
  for _, dec in ipairs(decorators) do
    local suffix, cmd = dec[1], dec[2]
    table.insert(autosnips, ma(
      "\\" .. g .. " " .. suffix,
      { t(cmd .. "{\\" .. g .. "}") }
    ))
  end
  table.insert(autosnips, ma("\\" .. g .. " sr", { t("\\" .. g .. "^{2}") }))
  table.insert(autosnips, ma("\\" .. g .. " cb", { t("\\" .. g .. "^{3}") }))
  table.insert(autosnips, ma("\\" .. g .. " rd", { t("\\" .. g .. "^{"), i(1), t("}"), i(2) }))
end

return snips, autosnips

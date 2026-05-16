-- FuzzyScorer: fuzzy matching engine using the FZF algorithm via FFI.
-- Wraps the vendored fzf_lib (C library) for fast fuzzy scoring and match position highlighting.
-- Used by FuzzyPicker for real-time filtering as the user types.

local FuzzyScorer = Class('FuzzyScorer')

---@class FuzzyScorerOpts
---@field case_mode? integer  -- 0=smart_case, 1=ignore_case, 2=respect_case
---@field fuzzy? boolean      -- true=fuzzy match, false=exact match

---@param opts FuzzyScorerOpts|nil
function FuzzyScorer:init(opts)
    opts = opts or {}
    local ok, fzf = pcall(require, 'ide.vendor.fzf_lib')
    if not ok then
        self._available = false
        return
    end
    self._fzf = fzf
    self._available = true
    self._slab = fzf.allocate_slab()
    self._cache = {}
    self._cache_count = 0
    self._case_mode = opts.case_mode or 0
    self._fuzzy = opts.fuzzy ~= false
end

--- Check if the native FZF library is available.
---@return boolean
function FuzzyScorer:is_available()
    return self._available
end

--- Get or create a parsed pattern for a prompt string.
---@param prompt string
---@return userdata|nil
function FuzzyScorer:_get_pattern(prompt)
    if not self._available or prompt == '' then return nil end
    if not self._cache[prompt] then
        -- Evict oldest patterns when cache grows too large
        if self._cache_count >= 50 then
            self:reset()
        end
        self._cache[prompt] = self._fzf.parse_pattern(prompt, self._case_mode, self._fuzzy)
        self._cache_count = (self._cache_count or 0) + 1
    end
    return self._cache[prompt]
end

--- Score a line against a prompt.
---@param line string # the text to score
---@param prompt string # the search query
---@return integer # 0 = no match, positive = match quality (higher is better)
function FuzzyScorer:score(line, prompt)
    if not self._available or prompt == '' then return 1 end
    local pattern = self:_get_pattern(prompt)
    if not pattern then return 0 end
    return self._fzf.get_score(line, pattern, self._slab)
end

--- Get match highlight positions for a line.
---@param line string
---@param prompt string
---@return integer[]|nil # 1-indexed character positions of matched characters, or nil
function FuzzyScorer:positions(line, prompt)
    if not self._available or prompt == '' then return nil end
    local pattern = self:_get_pattern(prompt)
    if not pattern then return nil end
    return self._fzf.get_pos(line, pattern, self._slab)
end

--- Clear cached patterns and free resources.
function FuzzyScorer:reset()
    if not self._available then return end
    for _, p in pairs(self._cache) do
        self._fzf.free_pattern(p)
    end
    self._cache = {}
    self._cache_count = 0
end

--- Free all resources.
function FuzzyScorer:destroy()
    self:reset()
    if self._slab then
        self._fzf.free_slab(self._slab)
        self._slab = nil
    end
end

--- Score and sort a list of items.
---@param items table[] # list of items
---@param prompt string # search query
---@param ordinal fun(item: table): string # function to extract searchable text
---@return table[] # sorted items (best match first), filtered to matches only
function FuzzyScorer:filter(items, prompt, ordinal)
    if prompt == '' then return items end

    local scored = {}
    for _, item in ipairs(items) do
        local text = ordinal(item)
        local s = self:score(text, prompt)
        if s > 0 then
            scored[#scored + 1] = { item = item, score = s }
        end
    end

    table.sort(scored, function(a, b) return a.score > b.score end)

    local result = {}
    for _, s in ipairs(scored) do
        result[#result + 1] = s.item
    end
    return result
end

---@return string
function FuzzyScorer:__tostring()
    return string.format('FuzzyScorer(%s)', self._available and 'native' or 'unavailable')
end

return FuzzyScorer

local _, FK = ...

-- Keys are the English strings. A missing translation falls back to the key,
-- so enUS needs no entries of its own and other locales only override what
-- they have translated.
local L = setmetatable({}, {
	__index = function(_, key)
		return key
	end,
})

FK.L = L

-- Test runner for the parts of Firekeeper that do not touch the WoW API.
--
--   lua tests/run.lua
--
-- Addon files are loaded the way the game loads them: each chunk is called with
-- (addonName, sharedTable) as its vararg.

local root = (arg and arg[0] or ""):match("^(.*)[/\\]tests[/\\][^/\\]+$") or "."

local FK = {}

local function loadAddonFile(relativePath)
	local path = root .. "/" .. relativePath
	local chunk, err = loadfile(path)
	if not chunk then
		error("could not load " .. path .. ": " .. tostring(err))
	end
	return chunk("Firekeeper", FK)
end

for _, file in ipairs({
	"Locales/enUS.lua",
	"Data/BuffGroups.lua",
	"Data/CampObjects.lua",
	"Core/Plan.lua",
	"Core/Cooldowns.lua",
}) do
	loadAddonFile(file)
end

local failures, total = 0, 0

local t = {}

function t.equals(actual, expected, message)
	total = total + 1
	if actual ~= expected then
		failures = failures + 1
		print(("  FAIL %s\n    expected: %s\n    actual:   %s"):format(
			message or "", tostring(expected), tostring(actual)))
		return false
	end
	return true
end

function t.isTrue(value, message)
	return t.equals(not not value, true, message)
end

function t.count(list, expected, message)
	return t.equals(#list, expected, message)
end

local suites = { "data_test", "plan_test", "cooldowns_test" }

for _, suite in ipairs(suites) do
	local chunk = assert(loadfile(root .. "/tests/" .. suite .. ".lua"))
	local tests = chunk(FK, t)
	local names = {}
	for name in pairs(tests) do
		table.insert(names, name)
	end
	table.sort(names)

	print(suite)
	for _, name in ipairs(names) do
		local before = failures
		tests[name]()
		print(("  %s %s"):format(failures == before and "ok  " or "FAIL", name))
	end
end

print(("\n%d checks, %d failed"):format(total, failures))
os.exit(failures == 0 and 0 or 1)

-- Prints the Lua errors BugGrabber recorded in the session that last wrote its saved
-- variables, Firekeeper's in full and everyone else's as a count. BugGrabber keeps:
--
--   BugGrabberDB = { session = n, errors = { { message, stack, locals, session, time, counter }, ... } }
--
--   lua5.1 bugs.lua "<path to !BugGrabber.lua>"

local path = assert(arg[1], "usage: lua5.1 bugs.lua <path to !BugGrabber.lua>")

-- The file is Lua the game wrote. Run it with nothing in scope but the table it fills.
local chunk = assert(loadfile(path))
local env = {}
setfenv(chunk, env)
chunk()

local db = env.BugGrabberDB or {}
local ours, earlier, others = {}, 0, 0
for _, err in ipairs(db.errors or {}) do
	local text = tostring(err.message) .. "\n" .. tostring(err.stack)
	local isOurs = text:find("Firekeeper", 1, true) ~= nil
	if not isOurs then
		others = others + (err.session == db.session and 1 or 0)
	elseif err.session == db.session then
		table.insert(ours, err)
	else
		earlier = earlier + 1
	end
end

local function indent(text, maxLines)
	local lines = {}
	for line in tostring(text or ""):gmatch("[^\n]+") do
		if #lines == maxLines then
			table.insert(lines, "    ...")
			break
		end
		table.insert(lines, "    " .. line)
	end
	return table.concat(lines, "\n")
end

print(("Session %s: %d Firekeeper error(s), %d from other addons; %d Firekeeper error(s) in earlier sessions")
	:format(tostring(db.session), #ours, others, earlier))
for i, err in ipairs(ours) do
	print(("\n[%d] x%s at %s\n%s"):format(i, tostring(err.counter or 1), tostring(err.time), indent(err.message, 5)))
	print("  stack:\n" .. indent(err.stack, 12))
	if err.locals then
		print("  locals:\n" .. indent(err.locals, 12))
	end
end

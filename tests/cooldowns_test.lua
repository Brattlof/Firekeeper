local FK, t = ...

local Cooldowns = FK.Cooldowns
local tests = {}

function tests.base_cooldown_is_one_hour()
	t.equals(Cooldowns.Duration(nil), 3600, "an hour with no Legacy perks")
end

function tests.field_guide_shortens_the_cooldown()
	t.equals(Cooldowns.Duration({ fieldGuide = 1 }), 3312, "rank 1 takes off 8%")
	t.equals(Cooldowns.Duration({ fieldGuide = 3 }), 2736, "three ranks take off 24%")
end

function tests.field_guide_cannot_remove_the_cooldown()
	t.equals(Cooldowns.Duration({ fieldGuide = 99 }), 360, "capped at 90% off")
end

function tests.remaining_counts_down_and_stops_at_zero()
	t.equals(Cooldowns.Remaining(1000, 1000), 3600, "just placed")
	t.equals(Cooldowns.Remaining(1000, 2800), 1800, "half way")
	t.equals(Cooldowns.Remaining(1000, 9000), 0, "long past")
	t.equals(Cooldowns.Remaining(nil, 9000), 0, "never placed is ready")
end

function tests.is_ready_follows_remaining()
	t.equals(Cooldowns.IsReady(1000, 2000), false, "still on cooldown")
	t.equals(Cooldowns.IsReady(1000, 5000), true, "off cooldown")
	t.equals(Cooldowns.IsReady(1000, 2000, { fieldGuide = 99 }), true, "Legacy ranks count")
end

function tests.format_is_readable()
	t.equals(Cooldowns.Format(0), "ready", "zero reads as ready")
	t.equals(Cooldowns.Format(45), "45s", "seconds")
	t.equals(Cooldowns.Format(125), "2m 05s", "minutes and seconds")
	t.equals(Cooldowns.Format(1800), "30m", "long waits round to minutes")
end

return tests

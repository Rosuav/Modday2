-- Log messages appear in .../PAYDAY 2/mods/logs/ but aren't flushed
-- Even worse, unwritten messages appear to be lost on termination.
-- BLT:Log(LogLevel.ERROR, "Hello, world")

-- Instead, use this for logging, which shows up in local chat.
function say(msg)
	managers.chat:_receive_message(1, "NOTICE", msg, Color("29A4F6"))
end

Hooks:PostHook(PlayerManager, 'on_used_body_bag', 'alert_out_of_bags',
function(self, data)
	local pagers_used = managers.groupai:state():get_nr_successful_alarm_pager_bluffs()
	if pagers_used < 4 and self._local_player_body_bags < 1 then
		say("That was your last body bag! Grab " .. (4 - pagers_used) .. " more!")
	end
end)

--[[ Previous attempts at the autoreload idea, which may have reference value in triggering other actions
function check_autoreload()
	say("Checking for autoreload")
	local weapon_unit = managers.player:equipped_weapon_unit()
	if weapon_unit then
		local clip = weapon_unit:base()._ammo_remaining_in_clip
		say("Clip " .. clip)
		if weapon_unit:base():can_reload() and clip < 1 then
			-- weapon_unit:base():on_reload() -- this is a free reload, not "trigger the reload animation"
		end
	end
end

Hooks:PostHook(RaycastWeaponBase, "fire", "auto_reload",
function(self, from_pos, direction, dmg_mul, shoot_player, spread_mul, autohit_mul, suppr_mul, target_unit)
	if self._setup.user_unit == managers.player:player_unit() then
		-- It's the player who just fired.
		say("Clip left " .. self._ammo_remaining_in_clip)
		check_autoreload()
	end
end)
--]]

-- Precomputed sines of every sixteenth of a circle, first quadrant:
local sixteenths = {0.19509032201612825, 0.5555702330196022, 0.8314696123025452, 0.9807852804032304}
local labels = {"N", "NNE", "NE", "ENE"}

function check_compass(self, input)
	-- Where am I? If you're pressing both Reload and Interact at once, you're lost, and need to
	-- be told where you are. Okay, that's not exactly what I do, but I say where you're facing.
	-- Note that when your mask is off, simply pressing Interact will do this.
	if input.btn_interact_press then
		-- self._cam_fwd_flat is (x, y, 0) representing a unit vector (ie x*x+y*y will always
		-- equal 1). We want the angle of that vector, then divide that by 1/16th of a circle
		-- and round to the nearest cardinal position. However, since trignometric functions
		-- are expensive (and cardinals even more so, whether we're talking about birds or
		-- clergy), it's better to use the rectangular dimensions directly.
		-- Step 1: Precompute one quadrant's coordinates. (It doesn't matter whether we use
		-- sin or cos here, just determines which way around we look at it.)
		-- [sin(x / 8 * pi) for x in range(5)]
		-- Notionally, this gives us our target locations. However, it's more useful to have
		-- the boundaries between them, which we can use in comparisons. So shift around a bit.
		-- [sin((x / 8 + 1/16) * pi) for x in range(4)]
		-- Step 2: Find which octant we're in - NE, NW, SW, SE - and adjust accordingly.
		local x = math.abs(self._cam_fwd_flat.x)
		local label = "E" -- The highest X values correspond to being nearly out of the quadrant.
		for i, pos in pairs(sixteenths) do
			if x < pos then
				label = labels[i]
				break
			end
		end
		-- Cool. That's fine if we're in the NE quadrant. What if we're not?
		if self._cam_fwd_flat.x < 0 then
			label = string.gsub(label, "E", "W")
		end
		if self._cam_fwd_flat.y < 0 then
			label = string.gsub(label, "N", "S")
		end
		say("You are facing: " .. label)
	end
end

Hooks:PreHook(PlayerMaskOff, "_check_action_interact", "compass",
function(self, t, input)
	check_compass(self, input)
end)

Hooks:PreHook(PlayerStandard, "_check_action_reload", "auto_reload",
function(self, t, input)
	if input.btn_reload_press then
		check_compass(self, input)
	end
	-- Autoreload: if you need to reload and can reload, assume you're pressing the reload key
	local weapon_unit = managers.player:equipped_weapon_unit()
	if weapon_unit then
		local clip = weapon_unit:base()._ammo_remaining_in_clip
		if clip < 1 and weapon_unit:base():can_reload() then
			input.btn_reload_press = true
		end
	end
end)

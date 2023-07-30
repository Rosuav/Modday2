-- Log messages appear in .../PAYDAY 2/mods/logs/ but aren't flushed
-- Even worse, unwritten messages appear to be lost on termination.
-- BLT:Log(LogLevel.ERROR, "Hello, world")

-- Instead, use this for logging, which shows up in local chat.
function say(msg)
	managers.chat:_receive_message(1, "NOTICE", msg, Color("29A4F6"))
end

-- Set values in here to true to enable cheat-level hacks. Most of them were developed
-- in order to tinker with other features, but they're also useful in the same way that
-- other cheat codes are, so I'm keeping them :) Plus, it's hilariously funny how easily
-- the AI can get confused when you mess with some of these things.
modday2_hacks = {
	-- pager_reset = 1, -- Reset pager usage every time you bag someone.
	-- wireframes = 1, -- Show wireframes for all enemies - great for debugging Survival Instincts, which still isn't working (2023-07-21)
	-- more_stuff = 1, -- Give more stuff. See below for details on exactly what it gives.
	-- glasses_off = 1, -- Transport the Payday Gang to a myopia utopia!
	-- smekalka = 1, -- Teach Russian ingenuity to the dozers...
	-- insurance = 1, -- Buy murder insurance before you go.
	-- dark_cameras = 1, -- Cameras go dark.
}

Hooks:PostHook(PlayerManager, 'on_used_body_bag', 'alert_out_of_bags',
function(self, data)
	local pagers_used = managers.groupai:state():get_nr_successful_alarm_pager_bluffs()
	if pagers_used < 4 and self._local_player_body_bags < 1 then
		say("That was your last body bag! Grab " .. (4 - pagers_used) .. " more!")
	end
	if modday2_hacks.pager_reset then
		-- say("Pagers used: " .. pagers_used .. ". Resetting to zero.")
		managers.groupai:state()._nr_successful_alarm_pager_bluffs = 0
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

function check_compass(self, input, mode)
	-- Inspect your weapon and your compass at once.
	if input.btn_cash_inspect_press then
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
		-- Testing, needs a proper place (maybe this? probably not).
		-- Query how many enemies there are on the map.
		local enemies, civilians = 0, 0
		for _, data in pairs(managers.enemy:all_enemies()) do
			if modday2_hacks.wireframes then
				-- Hack for testing: Highlight everyone as they get counted
				data.unit:contour():add("mark_enemy_damage_bonus", true, 2)
				managers.network:session():send_to_peers_synched("spot_enemy", data.unit)
			end
			enemies = enemies + 1
		end
		for _, data in pairs(managers.enemy:all_civilians()) do
			if modday2_hacks.wireframes then
				data.unit:contour():add("mark_enemy", true, 1)
				managers.network:session():send_to_peers_synched("spot_enemy", data.unit)
			end
			civilians = civilians + 1
		end
		label = label .. " (enem " .. enemies .. ", civ " .. civilians .. ")"
		say("You are " .. mode .. " and facing: " .. label)
		-- managers.experience:give_experience(1000, true)
	end
end

-- The player may be in any of a number of game states. They have different restrictions on what
-- you can and can't do, but we want the compass check to be available in all of them.
-- Others to consider: PlayerClean, PlayerCarry (both subclasses of PlayerStandard so maybe fine?)
-- Unsure which modes are triggered when.
-- Note that having hooks on a subclass MAY stop the superclass hook from firing. Unsure. For safety,
-- hook different functions or ensure that the subclass does everything the superclass would.

-- No equipment carried (eg Golden Grin Casino, stealth entrance, prior to collecting gear)
Hooks:PreHook(PlayerCivilian, "_check_action_interact", "compass",
function(self, t, input)
	check_compass(self, input, "a Civilian")
end)

-- Casing mode (stealth heist before masking up)
Hooks:PreHook(PlayerMaskOff, "_check_action_interact", "compass",
function(self, t, input)
	check_compass(self, input, "Casing")
end)

-- Others
Hooks:PreHook(PlayerDriving, "_check_action_exit_vehicle", "compass",
function(self, t, input)
	-- Hooking exit_vehicle means that, if you're a passenger and able to shoot, you
	-- will get double messages. Unideal. Unsure about passenger not able to shoot.
	check_compass(self, input, "Driving")
end)
Hooks:PreHook(PlayerClean, "_check_action_interact", "compass",
function(self, t, input)
	check_compass(self, input, "Clean") -- Never seen this one
end)
Hooks:PreHook(PlayerFatal, "_check_action_interact", "compass",
function(self, t, input)
	check_compass(self, input, "Fatally Wounded") -- Bleeding out, completely sideways, can't shoot
end)
Hooks:PreHook(PlayerCarry, "_check_action_interact", "compass",
function(self, t, input)
	check_compass(self, input, "Carrying") -- if we lose this, does Compass stop working while carrying something?
end)

-- Normal situation, the majority of situations
Hooks:PreHook(PlayerStandard, "_check_action_reload", "auto_reload",
function(self, t, input)
	check_compass(self, input, "Getting Rich")
	-- Autoreload: if you need to reload and can reload, assume you're pressing the reload key
	local weapon_unit = managers.player:equipped_weapon_unit()
	if weapon_unit then
		local clip = weapon_unit:base()._ammo_remaining_in_clip
		if clip < 1 and weapon_unit:base():can_reload() then
			input.btn_reload_press = true
		end
	end
end)

-- Run some initialization checks
Hooks:PostHook(PlayerManager, "spawned_player", "modday2_initialization",
function(self, id, unit)
	-- Imagine if your AI companions could lend you their cable ties.
	-- If there are three AIs, assume that they have the default of
	-- two ties apiece, and grant you six more (doubling your stash
	-- if you have Forced Friendship). However, if there are two AIs,
	-- assume that one of them hands to you, and the other might hand
	-- to the other player. And if there's only one AI, well, magic
	-- happens, and he shares his two ties among the three of you, so
	-- you get one each. (These figures assume that everyone's using
	-- this same mod, even if not everyone is.)
	-- UNFORTUNATELY! Twelve cable ties exceeds the game's limit of
	-- nine. So if you're playing solo and have Forced Friendship, you
	-- miss out on three ties. Can we buff that maximum??
	DelayedCalls:Add("MoreTiesPls", 0.5, function()
		-- The bots don't exist as the player spawns. Give them half a
		-- second to arrive. (Can we hook on that too?)
		local bots = managers.groupai:state():amount_of_ai_criminals()
		if bots == 3 then self:add_cable_ties(6) end
		if bots == 2 then self:add_cable_ties(2) end
		if bots == 1 then self:add_cable_ties(1) end
	end)
end)

-- To adjust the effects of different skill/perk upgrades, do this (here at top level):
if modday2_hacks.more_stuff then
	-- This particular one makes the body bag upgrade (that normally adds 1 to your max body bags, for
	-- a total of 2) instead add 7 (for a total of 8 if you have that skill, or the normal 1 if not).
	-- For upgrades that can happen more than once, there'll be an inner table with multiple values.
	tweak_data.upgrades.values.bodybags_bag.quantity[1] = 7
	-- Or this changes the multiplier for the armor bonus from Iron Man - normally 30% bonus (1.3).
	-- Note that this does NOT affect the menu, only in-game.
	tweak_data.upgrades.values.player.armor_multiplier[1] = 1.5
end

-- Glasses off, everyone. You can't see a thing.
-- Fun fact: This can result in guards that hear a non-silenced drill, walk up to it, but have no
-- idea what this thing is that's right in front of him.
if modday2_hacks.glasses_off then
	for _, chartype in pairs(tweak_data.character.presets.detection) do
		for _, mode in pairs(chartype) do
			mode.dis_max = 1 -- centimeter.
		end
	end
	for _, mode in pairs(tweak_data.attention.settings) do
		mode.max_range = 1 -- centimeter also, presumably
	end
end
-- Replace armor with ingenuity, and I don't mean the helicopter
if modday2_hacks.smekalka then
	tweak_data.character.tank.HEALTH_INIT = 1
end
-- Killing civvies happens sometimes during testing.
if modday2_hacks.insurance then
	tweak_data.upgrades.values.player.cleaner_cost_multiplier[1] = 0
end

if modday2_hacks.dark_cameras then
	Hooks:PostHook(SecurityCamera, "set_detection_enabled", "dark_cameras",
	function(self, state, settings, mission_element)
		-- say("Camera has range " .. self._range)
		self._range = 1
		self._suspicion_range = 1
	end)
end

function heading_from_vector(vec)
	return math.floor(mvector3.angle(vec, math.Y))
end

-- TODO: Govern this with a skill. Open question: What tier of skill?
-- Maybe attach it to Marksman Ace, T2 Sharpshooter skill? Or replace that altogether?
Hooks:PostHook(NewRaycastWeaponBase, "check_highlight_unit", "survival_instincts",
function(self, unit)
	if true then return end -- hacked out until I figure out how to put it behind a skill
	-- Replicate the logic from the original: if highlighting wouldn't be done,
	-- survival instincts highlighting won't be either.
	if not self._can_highlight then return end
	if not self._can_highlight_with_skill and self:is_second_sight_on() then return end
	if unit:in_slot(8) and alive(unit:parent()) then unit = unit:parent() or unit end
	if not unit or not unit:base() then return end
	if unit:character_damage() and unit:character_damage().dead and unit:character_damage():dead() then return end

	-- Govern this some other way? Implication is: "squint at 'em, see if there's anything to steal".
	if unit:character_damage() and unit:character_damage()._pickup and unit:character_damage()._pickup ~= "ammo" then
		unit:contour():add("tmp_invulnerable", true, 1) -- Can we get a different colour?
		managers.network:session():send_to_peers_synched("spot_enemy", unit)
		-- Force the item to be dropped immediately
		-- unit:character_damage():drop_pickup()
		-- unit:character_damage()._pickup = nil
	end
	-- if true then return end

	local is_enemy_in_cool_state = managers.enemy:is_enemy(unit) and not managers.groupai:state():enemy_weapons_hot()
	if not is_enemy_in_cool_state and not unit:base().can_be_marked then return end
	-- Okay. Highlighting would have indeed been done.
	-- Scan all enemies and cameras to see if any of them would be able to see this one.
	local can_be_seen = false
	local unit_pos = unit:position()
	if not unit_pos then return end
	-- Calibrate both Pythagorean distance and the mvector3.direction() distance
	-- against what a rangefinder says.
	-- local my_pos = managers.player:local_player():movement():m_head_pos()
	-- local tmp_vec1 = Vector3()
	-- local dis = mvector3.direction(tmp_vec1, my_pos, unit_pos)
	-- local dis2 = math.pow(my_pos.x - unit_pos.x, 2) + math.pow(my_pos.y - unit_pos.y, 2) + math.pow(my_pos.z - unit_pos.z, 2)
	-- say("Distance " .. dis .. " or " .. math.pow(dis2, 0.5))
	-- Conclusion: Both distance calculations agree that the map unit is the centimeter.
	local msg = heading_from_vector(unit:movement():m_head_rot():z())
	for _, data in pairs(managers.enemy:all_enemies()) do
		-- NOTE: For the purposes of this check, we assume a max distance of 10,000 and
		-- max angle of 120. These are by far the most common values in the tweakdata
		-- tables, with some enemy types having lower vision, and snipers having wider
		-- FOV, but this is a good default for stealth.
		-- TODO: What's the detection range for a corpse? Is that lower than 100m?
		local man_pos = data.unit:movement():m_head_pos()
		local tmp_vec1 = Vector3()
		local dis = mvector3.direction(tmp_vec1, man_pos, unit_pos)
		if data.unit ~= unit and dis < 10000 then
			local fwd = data.unit:movement():m_head_rot():z()
			local angle = mvector3.angle(fwd, unit_pos - man_pos)
			-- say(msg .. " - " .. heading_from_vector(fwd) .. "/" .. heading_from_vector(tmp_vec1) .. " = " .. angle)

			-- Note that coplogicbase.lua lerps from 180 down to 120, but somehow this is
			-- giving me the wrong results if I use those numbers. So we're calculating
			-- the boresight angle and ensuring that we're within +/- 60°. Note also that,
			-- even though logically this should be the range (-60, 60), the angle() method
			-- always returns positive numbers, so we just look at (0, 60) and can thus use
			-- a simple inequality check.
			local angle_max = math.lerp(90, 60, math.clamp((dis - 150) / 700, 0, 1))
			if angle < angle_max then
				local vis_ray = World:raycast("ray", man_pos, unit_pos, "slot_mask", managers.slot:get_mask("AI_visibility"), "ray_type", "ai_vision")

				if not vis_ray or vis_ray.unit:key() == unit:key() then
					can_be_seen = true
					-- say("Enemy can see enemy at dist " .. dis)
					-- For debugging: Highlight the one who can see the target.
					data.unit:contour():add("medic_heal", true, 1) -- Green highlight
					managers.network:session():send_to_peers_synched("spot_enemy", data.unit)
					say("Visible! " .. angle .. " / " .. angle_max)
				else
					say("Blocked: " .. angle .. " / " .. angle_max)
				end
			else
				say("Not vis: " .. angle .. " / " .. angle_max)
			end
		end
	end
	for _, cam in pairs(SecurityCamera.cameras) do
		if alive(cam) and cam:enabled() and not cam:base():destroyed() then
			-- Logic replicated from SecurityCamera:_upd_acquire_new_attention_objects
			-- but instead of looking at all "objects worthy of attention" (eg corpses),
			-- we just look at the current unit.
			local camself = cam:base()
			local cam_pos = camself._pos
			local cam_fwd = camself._look_fwd

			if cam_pos then
				local dis = math.pow(cam_pos.x - unit_pos.x, 2) + math.pow(cam_pos.y - unit_pos.y, 2) + math.pow(cam_pos.z - unit_pos.z, 2)
				if dis < math.pow(camself._range, 2) then
					local vis_ray = camself._unit:raycast("ray", cam_pos, unit_pos, "slot_mask", camself._visibility_slotmask, "ray_type", "ai_vision")

					-- is it okay to just say vis_ray.unit == unit?
					if not vis_ray or vis_ray.unit:key() == unit:key() then
						local in_cone = true

						if camself._cone_angle ~= nil then
							local dir = (unit_pos - cam_pos):normalized()
							in_cone = cam_fwd:angle(dir) <= camself._cone_angle * 0.5
						end

						if in_cone then can_be_seen = true end
					end
				end
			end
		end
	end
	local my_pos = managers.player:local_player():movement():m_head_pos()
	-- local tmp_vec1 = Vector3()
	-- mvector3.direction(tmp_vec1, my_pos, unit_pos)
	local tmp_vec1 = unit_pos - my_pos
	local fwd = managers.player:local_player():movement():m_head_rot():z()
	local angle1 = math.floor(mvector3.angle(fwd, tmp_vec1))
	local angle2 = math.floor(mvector3.angle(tmp_vec1, fwd))
	say(heading_from_vector(fwd) .. " / " .. heading_from_vector(tmp_vec1) .. " = " .. angle1 .. " = " .. angle2)
	if not can_be_seen then return end
	--say("Can be seen!")
	unit:contour():add("tmp_invulnerable", true, 1) -- Add a temporary yellow highlight
	managers.network:session():send_to_peers_synched("spot_enemy", unit)
end)

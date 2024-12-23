EventCoordinator = {}

local events = {
	["AttackedBy"] = {},
	["RollResult"] = {},
	["StatusApplied"] = {},
	["CombatStarted"] = {},
	["CombatRoundStarted"] = {},
	["LeftCombat"] = {},
	["CastSpell"] = {},
}

--- API method to register functions that operate under the same event, for performance reasons
function EventCoordinator:RegisterEventProcessor(eventName, eventFunc)
	table.insert(events[eventName], eventFunc)
end

Ext.Osiris.RegisterListener("AttackedBy", 7, "before", function(defender, attackerOwner, attacker2, damageType, damageAmount, damageCause, storyActionID)
	if MCM.Get("enabled") then
		for _, func in pairs(events["AttackedBy"]) do
			local success, error = pcall(function()
				func(defender, attackerOwner, attacker2, damageType, damageAmount, damageCause, storyActionID)
			end)

			if not success then
				Logger:BasicError("Received error while processing event AttackedBy: \n%s", error)
			end
		end
	end
end)

Ext.Osiris.RegisterListener("RollResult", 6, "before", function(eventName, roller, rollSubject, resultType, isActiveRoll, criticality)
	if MCM.Get("enabled") then
		for _, func in pairs(events["RollResult"]) do
			local success, error = pcall(function()
				func(eventName, roller, rollSubject, resultType, isActiveRoll, criticality)
			end)

			if not success then
				Logger:BasicError("Received error while processing event RollResult: \n%s", error)
			end
		end
	end
end)

Ext.Osiris.RegisterListener("StatusApplied", 4, "after", function(object, status, causee, storyActionID)
	if MCM.Get("enabled") then
		for _, func in pairs(events["StatusApplied"]) do
			local success, error = pcall(function()
				func(object, status, causee, storyActionID)
			end)
			if not success then
				Logger:BasicError("Received error while processing event StatusApplied: \n%s", error)
			end
		end
	end
end)

Ext.Osiris.RegisterListener("CombatStarted", 1, "before", function(combatGuid)
	if MCM.Get("enabled") then
		for _, func in pairs(events["CombatStarted"]) do
			local success, error = pcall(function()
				func(combatGuid)
			end)

			if not success then
				Logger:BasicError("Received error while processing event CombatStarted: \n%s", error)
			end
		end
	end
end)

Ext.Osiris.RegisterListener("LeftCombat", 2, "after", function (object, combatGuid)
	if MCM.Get("enabled") then
		for _, func in pairs(events["LeftCombat"]) do
			local success, error = pcall(function()
				func(object, combatGuid)
			end)

			if not success then
				Logger:BasicError("Received error while processing event LeftCombat: \n%s", error)
			end
		end
	end
end)

Ext.Osiris.RegisterListener("CombatRoundStarted", 2, "before", function(combatGuid, round)
	if MCM.Get("enabled") then
		for _, func in pairs(events["CombatRoundStarted"]) do
			local success, error = pcall(function()
				func(combatGuid, round)
			end)

			if not success then
				Logger:BasicError("Received error while processing event CombatRoundStarted: \n%s", error)
			end
		end
	end
end)

Ext.Osiris.RegisterListener("CastSpell", 5, "after", function(caster, spell, spellType, spellElement, storyActionID)
	if MCM.Get("enabled") then
		Logger:BasicTrace("Processing CastSpell event: \n\t|caster| = %s\n\t|spell| = %s\n\t|spellType| = %s\n\t|storyActionID| = %s",
			caster,
			spell,
			spellType,
			storyActionID)

		for _, func in pairs(events["CastSpell"]) do
			local success, error = pcall(function()
				func(caster, spell, spellType, spellElement, storyActionID)
			end)

			if not success then
				Logger:BasicError("Received error while processing event CastSpell: \n%s", error)
			end
		end
	end
end)

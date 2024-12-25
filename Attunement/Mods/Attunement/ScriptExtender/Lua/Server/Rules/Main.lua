-- Thanks Focus
---@return AttunementRules
local function GetDifficulty()
	local difficulty = Osi.GetRulesetModifierString("cac2d8bd-c197-4a84-9df1-f86f54ad4521")
	if difficulty == "HARD" and Osi.GetRulesetModifierBool("338450d9-d77d-4950-9e1e-0e7f12210bb3") == 1 then
		difficulty = "HONOUR"
	end
	return ConfigManager.ConfigCopy.rules[difficulty] or ConfigManager.ConfigCopy.rules["Base"]
end

Ext.Osiris.RegisterListener("LevelGameplayReady", 2, "after", function(levelName, isEditorMode)
	local difficultyRules = GetDifficulty()

	---@type PassiveData
	local attunementPassive = Ext.Stats.Get("ATTUNEMENT_ACTION_RESOURCE_PASSIVE")
	attunementPassive.Boosts = string.format("ActionResource(Attunement,%s,0)", difficultyRules.totalAttunementLimit)
	attunementPassive:Sync()

	for _, player in pairs(Osi.DB_Players:Get(nil)) do
		player = player[1]
		if Osi.HasPassive(player, "ATTUNEMENT_ACTION_RESOURCE_PASSIVE") == 1 then
			-- Using ReplenishType `Never` prevents restoring resource through Stats and Osiris, so hacking it
			---@type EntityHandle
			local charEntity = Ext.Entity.Get(player)

			local resources = charEntity.ActionResources.Resources

			-- TODO: Add a ModVar to track max number of attunement slots so when the difficulty is changed, we math this out correctly
			local attunementResource = resources["0869d45b-9bdf-4315-aeae-da7fb6a7ca09"][1]
			attunementResource.MaxAmount = difficultyRules.totalAttunementLimit
			attunementResource.Amount = difficultyRules.totalAttunementLimit

			charEntity:Replicate("ActionResources")
		else
			Osi.AddPassive(player, "ATTUNEMENT_ACTION_RESOURCE_PASSIVE")
		end
	end
end)

Ext.Osiris.RegisterListener("TemplateEquipped", 2, "after", function(itemTemplate, character)
	---@type ItemTemplate
	local template = Ext.ServerTemplate.GetTemplate(string.sub(itemTemplate, -36))

	---@type Weapon|Armor|Object
	local stat = Ext.Stats.Get(template.Stats)

	local passiveApplied = string.match(stat.PassivesOnEquip, "ATTUNEMENT_REQUIRES_ATTUNEMENT_PASSIVE_" .. string.gsub(stat.Slot, " ", "_"))
	if passiveApplied then
		-- ---@type PassiveData
		-- local passive = Ext.Stats.Get(passiveApplied)
		-- Ext.Loca.UpdateTranslatedString(passive.DisplayName, Ext.Loca.GetTranslatedString("h8288b3f51c2c45dda3da9331fbddefd7dafd"))
		-- Ext.Loca.UpdateTranslatedString(passive.Description, Ext.Loca.GetTranslatedString("he5b84d40ad6f4fd498974b3a152182549c3f"))
	end
end)

Ext.Osiris.RegisterListener("TemplateUnequipped", 2, "after", function(itemTemplate, character)
	---@type ItemTemplate
	local template = Ext.ServerTemplate.GetTemplate(string.sub(itemTemplate, -36))

	---@type Weapon|Armor|Object
	local stat = Ext.Stats.Get(template.Stats)

	local passiveApplied = string.match(stat.PassivesOnEquip, "ATTUNEMENT_REQUIRES_ATTUNEMENT_PASSIVE_" .. string.gsub(stat.Slot, " ", "_"))
	if passiveApplied then
		-- ---@type PassiveData
		-- local passive = Ext.Stats.Get(passiveApplied)
		-- Ext.Loca.UpdateTranslatedString(passive.DisplayName, Ext.Loca.GetTranslatedString("h9003c2521b87482a9cb8cad70e010e84ce6g"))
		-- Ext.Loca.UpdateTranslatedString(passive.Description, Ext.Loca.GetTranslatedString("hdbe3209ca8da48f4accec8d329f59a1e283f"))

		-- Using ReplenishType `Never` prevents restoring resource through Stats and Osiris, so hacking it
		---@type EntityHandle
		local charEntity = Ext.Entity.Get(character)

		local resources = charEntity.ActionResources.Resources

		local attunementResource = resources["0869d45b-9bdf-4315-aeae-da7fb6a7ca09"][1]
		attunementResource.Amount = attunementResource.Amount + 1
		attunementResource.MaxAmount = attunementResource.Amount

		charEntity:Replicate("ActionResources")
	end
end)

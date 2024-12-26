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

Ext.Osiris.RegisterListener("Equipped", 2, "after", function(item, character)
	if Osi.HasActiveStatus(item, "ATTUNEMENT_REQUIRES_ATTUNEMENT_STATUS") == 1 then
		Osi.ApplyStatus(item, "ATTUNEMENT_IS_ATTUNED_STATUS", -1, 1)
		Osi.UseSpell(character, "ATTUNE_EQUIPMENT", character)
	end
end)

Ext.Osiris.RegisterListener("AddedTo", 3, "after", function(item, inventoryHolder, addType)
	---@type ItemTemplate
	local template = Ext.Template.GetTemplate(string.sub(Osi.GetTemplate(item), -36))

	if template.TemplateType == "item" and Osi.IsEquipped(item) == 0 then
		---@type Weapon|Armor|Object
		local stat = Ext.Stats.Get(template.Stats)

		if string.find(stat.UseCosts, "Attunement") then
			Osi.ApplyStatus(item, "ATTUNEMENT_REQUIRES_ATTUNEMENT_STATUS", -1, 1)
		end
	end
end)

Ext.Osiris.RegisterListener("Unequipped", 2, "after", function(item, character)
	---@type ItemTemplate
	local template = Ext.ServerTemplate.GetTemplate(string.sub(Osi.GetTemplate(item), -36))

	---@type Weapon|Armor|Object
	local stat = Ext.Stats.Get(template.Stats)

	if string.find(stat.UseCosts, "Attunement") then
		Osi.ApplyStatus(item, "ATTUNEMENT_REQUIRES_ATTUNEMENT_STATUS", -1, 1)

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

Ext.Osiris.RegisterListener("LevelGameplayReady", 2, "after", function(levelName, isEditorMode)
	local functionsToRun = BuildRelevantStatFunctions()
	for _, template in pairs(Ext.Template.GetAllRootTemplates()) do
		if template.TemplateType == "item" then
			---@type ItemStat
			local stat = Ext.Stats.Get(template.Stats)

			if stat and stat.Rarity ~= "Common" and (stat.ModifierList == "Weapon" or stat.ModifierList == "Armor") then
				for _, func in pairs(functionsToRun) do func(stat) end

				stat:Sync()
			end
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
		---@type ItemStat
		local stat = Ext.Stats.Get(template.Stats)

		if string.find(stat.UseCosts, "Attunement") then
			Osi.ApplyStatus(item, "ATTUNEMENT_REQUIRES_ATTUNEMENT_STATUS", -1, 1)
		end
	end
end)

Ext.Osiris.RegisterListener("Unequipped", 2, "after", function(item, character)
	---@type ItemTemplate
	local template = Ext.ServerTemplate.GetTemplate(string.sub(Osi.GetTemplate(item), -36))

	---@type ItemStat
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

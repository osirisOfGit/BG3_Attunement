Ext.Osiris.RegisterListener("LevelGameplayReady", 2, "after", function(levelName, isEditorMode)
	local functionsToRun = BuildRelevantStatFunctions()
	if #functionsToRun > 0 then
		for _, template in pairs(Ext.Template.GetAllRootTemplates()) do
			if template.TemplateType == "item" then
				---@type ItemStat
				local stat = Ext.Stats.Get(template.Stats)

				if stat and stat.Rarity ~= "Common" and (stat.ModifierList == "Weapon" or stat.ModifierList == "Armor") then
					stat.UseCosts = string.match(stat.UseCosts, "^[^;]*")

					for _, func in pairs(functionsToRun) do func(stat) end

					stat:Sync()
				end
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

local cachedResources = {}

Ext.Osiris.RegisterListener("Unequipped", 2, "after", function(item, character)
	-- Using ReplenishType `Never` prevents restoring resource through Stats and Osiris, so hacking it
	---@type EntityHandle
	local charEntity = Ext.Entity.Get(character)
	local resources = charEntity.ActionResources.Resources

	---@type ItemTemplate
	local template = Ext.ServerTemplate.GetTemplate(string.sub(Osi.GetTemplate(item), -36))

	---@type ItemStat
	local stat = Ext.Stats.Get(template.Stats)

	for cost in string.gmatch(stat.UseCosts, "([^;]+)") do
		local costName = string.match(cost, "^[^:]+")

		local resource
		if string.match(costName, "^.*Attunement$") then
			local cachedResourceID = cachedResources[costName]
			if not cachedResourceID then
				for _, actionResourceId in pairs(Ext.StaticData.GetAll("ActionResource")) do
					---@type ResourceActionResource
					local resource = Ext.StaticData.Get(actionResourceId, "ActionResource")
					if resource.Name == costName then
						cachedResources[costName] = actionResourceId
						cachedResourceID = actionResourceId
						break
					end
				end
			end
			resource = resources[cachedResourceID][1]
			resource.Amount = resource.Amount + 1
			resource.MaxAmount = resource.Amount
		end
	end
	charEntity:Replicate("ActionResources")
end)

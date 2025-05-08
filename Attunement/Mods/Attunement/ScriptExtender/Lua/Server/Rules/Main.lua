---@type {[string]: number}
local maxAmounts = {}

---@param itemUUID GUIDSTRING
---@return ItemStat?
local function FixAttunementStatus(itemUUID)
	---@type EntityHandle
	local itemEntity = Ext.Entity.Get(itemUUID)

	-- Transmogging changes the stat on the item, so we can't find the stat via the template, since that will give us the original stat
	---@type ItemStat
	local stat = Ext.Stats.Get(itemEntity.Data.StatsId)

	if stat then
		local requiresAttunement = stat.UseCosts and (string.find(stat.UseCosts, ";Attunement:1") or string.find(stat.UseCosts, "^Attunement:1"))

		if requiresAttunement then
			if Osi.IsEquipped(itemUUID) == 1 then
				if Osi.HasActiveStatus(itemUUID, "ATTUNEMENT_IS_ATTUNED_STATUS") == 0 then
					Osi.ApplyStatus(itemUUID, "ATTUNEMENT_IS_ATTUNED_STATUS", -1, 1)
				end
			else
				if Osi.HasActiveStatus(itemUUID, "ATTUNEMENT_REQUIRES_ATTUNEMENT_STATUS") == 0 then
					Osi.ApplyStatus(itemUUID, "ATTUNEMENT_REQUIRES_ATTUNEMENT_STATUS", -1, 1)
				end
			end
		else
			if Osi.HasActiveStatus(itemUUID, "ATTUNEMENT_REQUIRES_ATTUNEMENT_STATUS") == 1 then
				Osi.RemoveStatus(itemUUID, "ATTUNEMENT_REQUIRES_ATTUNEMENT_STATUS")
			end
			if Osi.HasActiveStatus(itemUUID, "ATTUNEMENT_IS_ATTUNED_STATUS") == 1 then
				Osi.RemoveStatus(itemUUID, "ATTUNEMENT_IS_ATTUNED_STATUS")
			end
		end

		return stat
	end
end

-- Credit to SwissFred57 in Larian Discord for the initial code
local function FixAttunementStatusOnEquipables(container, depth)
	depth = depth or 0

	if depth > 2 then
		Logger:BasicInfo(
			"Finished processing all items in inventory within 2 levels (limited for performance reasons) - if you have relevant items contained in even more nested containers, move them to main inventory, save, then reload")
		return
	end

	---@type EntityHandle
	local entity = Ext.Entity.Get(container)
	if not entity or not entity.InventoryOwner then
		Logger:BasicWarning("DeepIterateInventory: Entity %s does not have an inventory? Report this on Nexus please", container)
		return
	end

	local primaryInventory = entity.InventoryOwner.PrimaryInventory
	if not primaryInventory or not primaryInventory.InventoryContainer then
		Logger:BasicWarning("DeepIterateInventory: Entity %s does not have an inventory? Report this on Nexus please", container)
		return
	end

	for _, item in pairs(primaryInventory.InventoryContainer.Items) do
		local itemUUID = item.Item.Uuid.EntityUuid
		local isContainer = Osi.IsContainer(itemUUID)

		if isContainer == 1 then
			FixAttunementStatusOnEquipables(itemUUID, depth + 1)
		elseif Osi.IsEquipable(itemUUID) == 1 then
			FixAttunementStatus(itemUUID)
		end
	end
end

local cachedResources = {}

local function getCachedResource(costName)
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
	return cachedResourceID
end

---@param playerEntity EntityHandle
local function ProcessEquippedItemsOnChar(playerEntity)
	Logger:BasicDebug("Updating equipped + equipable items for %s", playerEntity.DisplayName and playerEntity.DisplayName.Name:Get() or playerEntity.Uuid.EntityUuid)
	local player = playerEntity.Uuid.EntityUuid
	local resources = playerEntity.ActionResources.Resources

	for resourceName, maxAmount in pairs(maxAmounts) do
		local resource = resources[getCachedResource(resourceName)][1]
		resource.MaxAmount = maxAmount
		resource.Amount = maxAmount
	end

	local toUnequip = {}

	local sentNotification = false
	for itemSlot, _ in pairs(Ext.Enums.ItemSlot) do
		itemSlot = tostring(itemSlot)
		-- Getting this aligned with Osi.EQUIPMENTSLOTNAME, because, what the heck Larian (╯°□°）╯︵ ┻━┻
		if itemSlot == Ext.Enums.StatsItemSlot[Ext.Enums.StatsItemSlot.MeleeMainHand] then
			itemSlot = "Melee Main Weapon"
		elseif itemSlot == Ext.Enums.StatsItemSlot[Ext.Enums.StatsItemSlot.MeleeOffHand] then
			itemSlot = "Melee Offhand Weapon"
		elseif itemSlot == Ext.Enums.StatsItemSlot[Ext.Enums.StatsItemSlot.RangedMainHand] then
			itemSlot = "Ranged Main Weapon"
		elseif itemSlot == Ext.Enums.StatsItemSlot[Ext.Enums.StatsItemSlot.RangedOffHand] then
			itemSlot = "Ranged Offhand Weapon"
		end

		local equippedItem = Osi.GetEquippedItem(player, itemSlot)
		if equippedItem then
			local stat = FixAttunementStatus(equippedItem)

			if stat then
				local unequippedItem = false
				for cost in string.gmatch(stat.UseCosts, "([^;]+)") do
					local costName = string.match(cost, "^[^:]+")

					if string.match(costName, "^.*Attunement$") then
						local resourceToModify = resources[getCachedResource(costName)][1]
						if resourceToModify.Amount <= 0 then
							resourceToModify.Amount = resourceToModify.Amount - 1

							if not unequippedItem then
								table.insert(toUnequip, equippedItem)
								unequippedItem = true
							end

							if not sentNotification then
								sentNotification = true
								Osi.ShowNotification(player,
									(playerEntity.DisplayName.Name:Get() or playerEntity.Uuid.EntityUuid) ..
									" had items unequipped due to exceeding Attunement/Rarity Equip Limits")
							end
						else
							resourceToModify.Amount = resourceToModify.Amount - 1
							resourceToModify.MaxAmount = resourceToModify.Amount

							if resourceToModify.Amount <= 0 then
								Osi.ApplyStatus(player, costName, -1, 1)
							elseif Osi.HasActiveStatus(player, costName) == 1 then
								Osi.RemoveStatus(player, costName)
							end
						end
					end
				end
			end
		end
	end

	playerEntity:Replicate("ActionResources")
	FixAttunementStatusOnEquipables(player)
	for _, item in pairs(toUnequip) do
		Osi.Unequip(player, item)
	end
end

local playerSubs = {}
local levelReadySub
levelReadySub = Ext.Osiris.RegisterListener("LevelGameplayReady", 2, "after", function(levelName, isEditorMode)
	local functionsToRun
	functionsToRun, maxAmounts = BuildRelevantStatFunctions()
	maxAmounts = maxAmounts or {}

	if #functionsToRun > 0 then
		for _, template in pairs(Ext.Template.GetAllRootTemplates()) do
			if template.TemplateType == "item" then
				---@type ItemStat
				local stat = Ext.Stats.Get(template.Stats)
				local success, err = pcall(function()
					if stat and stat.Rarity ~= "Common" and (stat.ModifierList == "Weapon" or stat.ModifierList == "Armor") then
						stat.UseCosts = string.match(stat.UseCosts, "^[^;]*")

						for _, func in pairs(functionsToRun) do func(stat) end

						stat:Sync()
					end
				end)

				if not success then
					local mod = Ext.Mod.GetMod(stat.ModId).Info
					Logger:BasicWarning("Error processing stat %s (from Mod '%s' by '%s') for template %s: %s",
						stat.Name,
						mod.Name,
						mod.Author,
						template.Name,
						err)
				end
			end
		end

		for _, player in pairs(Osi.DB_Players:Get(nil)) do
			player = player[1]

			---@type EntityHandle
			local playerEntity = Ext.Entity.Get(player)

			local timerRef
			-- I hate this too, but adding/changing the boosts are synchronous events, not blocking method calls, so need to wait for them to fire
			---@diagnostic disable-next-line: param-type-mismatch
			playerSubs[player] = Ext.Entity.Subscribe("ActionResources", function()
				if timerRef then
					Ext.Timer.Cancel(timerRef)
				end
				timerRef = Ext.Timer.WaitFor(500, function()
					Ext.Entity.Unsubscribe(playerSubs[player])
					playerSubs[player] = ""
					timerRef = nil

					ProcessEquippedItemsOnChar(playerEntity)
				end)
			end, playerEntity)

			Ext.Timer.WaitFor(2000, function()
				if playerSubs[player] ~= "" then
					Ext.Entity.Unsubscribe(playerSubs[player])
				end
				playerSubs[player] = nil

				if not next(playerSubs) then
					Logger:BasicInfo("Initialization complete")
				end
			end)
		end
	end
	Ext.Osiris.UnregisterListener(levelReadySub)
end)

Ext.Osiris.RegisterListener("Equipped", 2, "after", function(item, character)
	if MCM.Get("enabled") then
		Logger:BasicDebug("%s equipped %s", character, item)
		---@type EntityHandle
		local charEntity = Ext.Entity.Get(character)
		local resources = charEntity.ActionResources.Resources

		---@type EntityHandle
		local itemEntity = Ext.Entity.Get(item)

		-- Transmogging changes the stat on the item, so we can't find the stat via the template, since that will give us the original stat
		---@type ItemStat
		local stat = Ext.Stats.Get(itemEntity.Data.StatsId)

		if not stat then
			return
		end

		for cost in string.gmatch(stat.UseCosts, "([^;]+)") do
			local costName = string.match(cost, "^[^:]+")
			if string.find(costName, "Attunement") then
				if costName == "Attunement" then
					if Osi.HasActiveStatus(item, "ATTUNEMENT_REQUIRES_ATTUNEMENT_STATUS") == 1
					then
						Osi.ApplyStatus(item, "ATTUNEMENT_IS_ATTUNED_STATUS", -1, 1)
						if MCM.Get("cast_animation")
							and (Osi.IsInCombat(character) == 0 or MCM.Get("cast_animation_combat"))
						then
							Osi.UseSpell(character, "ATTUNE_EQUIPMENT", character)
						end
					else
						goto continue
					end
				end
				local resource = resources[getCachedResource(costName)][1]
				if resource.Amount == 0 then
					Osi.ApplyStatus(character, costName, -1, 1)
				end
				::continue::
			end
		end
	end
end)

Ext.Osiris.RegisterListener("AddedTo", 3, "after", function(item, inventoryHolder, addType)
	if MCM.Get("enabled") then
		Logger:BasicDebug("%s was added to %s with addType %s", item, inventoryHolder, addType)

		if Osi.IsEquipable(item) == 1 and Osi.IsEquipped(item) == 0 then
			---@type EntityHandle
			local itemEntity = Ext.Entity.Get(item)

			-- Transmogging changes the stat on the item, so we can't find the stat via the template, since that will give us the original stat
			---@type ItemStat
			local stat = Ext.Stats.Get(itemEntity.Data.StatsId)

			if stat and (string.find(stat.UseCosts, ";Attunement:1") or string.find(stat.UseCosts, "^Attunement:1")) and Osi.HasActiveStatus then
				Osi.ApplyStatus(item, "ATTUNEMENT_REQUIRES_ATTUNEMENT_STATUS", -1, 1)
			end
		elseif Osi.IsContainer(item) == 1 then
			FixAttunementStatusOnEquipables(item)
		end
	end
end)

Ext.Osiris.RegisterListener("Opened", 1, "after", function(item)
	if MCM.Get("enabled") and Osi.IsContainer(item) == 1 then
		FixAttunementStatusOnEquipables(item)
	end
end)

Ext.Osiris.RegisterListener("RequestCanLoot", 2, "after", function(looter, target)
	if MCM.Get("enabled") then
		FixAttunementStatusOnEquipables(target)
	end
end)

Ext.Osiris.RegisterListener("Unequipped", 2, "after", function(item, character)
	if MCM.Get("enabled") then
		Logger:BasicDebug("%s unequipped %s", character, item)

		---@type EntityHandle
		local charEntity = Ext.Entity.Get(character)

		ProcessEquippedItemsOnChar(charEntity)
	end
end)

Ext.Osiris.RegisterListener("CharacterDisarmed", 3, "after", function(character, item, slotName)
	Logger:BasicDebug("%s was disarmed of %s", character, item)

	ProcessEquippedItemsOnChar(Ext.Entity.Get(character))
end)

-- Ext.Vars.RegisterUserVariable("Attunement_Item_Preview")

function PeerToUserID(peerID)
	-- usually just userid+1
	return (peerID & 0xffff0000) | 0x0001
end

local previewingItems = {}

Ext.RegisterNetListener(ModuleUUID .. "SpawnItem", function(channel, templateUUID, user)
	local character = Osi.GetCurrentCharacter(PeerToUserID(user))

	Osi.TemplateAddTo(templateUUID, character, 1)

	table.insert(previewingItems, templateUUID)

	
	Ext.Timer.WaitFor(1000, function()
		previewingItems[#previewingItems + 1] = nil
	end)
end)

Ext.Osiris.RegisterListener("TemplateAddedTo", 4, "after", function(objectTemplate, object2, inventoryHolder, addType)
	local templateUUID = string.sub(objectTemplate, -36)
	for i, template in pairs(previewingItems) do
		if templateUUID == template then
			Logger:BasicInfo("%s started previewing %s", inventoryHolder, object2)
			previewingItems[i] = nil

			local equippedItem = Osi.GetEquippedItem(inventoryHolder, Ext.Stats.Get(Osi.GetStatString(object2)).Slot)

			Osi.Equip(inventoryHolder, object2, 1, 1)

			-- local characterEntity = Ext.Entity.Get(inventoryHolder)
			-- local previewTracker = characterEntity.Vars.Attunement_Item_Preview or {}
			-- previewTracker[object2] = equippedItem or ""

			Ext.Timer.WaitFor(60000, function()
				Logger:BasicInfo("Cleaning up preview item %s from %s", object2, inventoryHolder)
				Osi.RequestDelete(object2)
				if equippedItem then
					Osi.Equip(inventoryHolder, equippedItem, 1, 1)
					Logger:BasicInfo("Reequipping %s to %s", equippedItem, inventoryHolder)
				end
			end)
			return
		end
	end
end)

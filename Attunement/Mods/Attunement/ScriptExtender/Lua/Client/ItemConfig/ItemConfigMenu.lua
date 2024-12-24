---@type table<FixedString, ItemTemplate>
local allItemRoots = {}
local function populateTemplateTable()
	local indexedList = {}
	local mapCopy = {}
	for templateName, template in pairs(Ext.ClientTemplate.GetAllRootTemplates()) do
		if template.TemplateType == "item" and template.EquipmentTypeID ~= "00000000-0000-0000-0000-000000000000" then
			---@cast template ItemTemplate
			table.insert(indexedList, template.DisplayName:Get() or templateName)
			mapCopy[template.DisplayName:Get() or templateName] = template
		end
	end
	-- Fewest amount of characters to most, so more relevant results are at the top of the list
	table.sort(indexedList, function(a, b)
		return #a < #b
	end)
	for _, name in pairs(indexedList) do
		allItemRoots[name] = mapCopy[name]
	end
end
populateTemplateTable()

-- Credit to EasyCheat
-- https://bg3.norbyte.dev/search?q=rarity#result-f23802a9083da2ad18665deb188a569752dc7900
---@type { [ItemDataRarity] : vec3 }
local rarityColors = {
	Common = { 1.00, 1.00, 1.00, 1.0 },
	Uncommon = { 0.00, 0.66, 0.00, 1.0 },
	Rare = { 0.20, 0.80, 1.00, 1.0 },
	VeryRare = { 0.64, 0.27, 0.91, 1.0 },
	Legendary = { 0.92, 0.78, 0.03, 1.0 },
}

Mods.BG3MCM.IMGUIAPI:InsertModMenuTab(ModuleUUID, "Item Configuration",
	--- @param tabHeader ExtuiTreeParent
	function(tabHeader)
		tabHeader.TextWrapPos = 0

		--#region Search
		local searchInput = tabHeader:AddInputText("")
		searchInput.Hint = "Case-insensitive - use * to wildcard. Example: *ing*trap* for BURNING_TRAPWALL"
		searchInput.AutoSelectAll = true
		searchInput.EscapeClearsAll = true

		-- local resultsPopup = tabHeader:AddPopup("ResultsPopup")
		-- resultsPopup.NoFocusOnAppearing = true

		local bulkEdit = tabHeader:AddButton("Bulk Edit")

		local resultsTable = tabHeader:AddTable("ResultsTable", 4)
		resultsTable.Hideable = true
		resultsTable.Visible = false
		resultsTable.ScrollY = true
		resultsTable.SizingStretchProp = true
		resultsTable.RowBg = true

		local headerRow = resultsTable:AddRow()
		headerRow.Headers = true
		headerRow:AddCell():AddText("Template")
		headerRow:AddCell():AddText("Rarity")
		headerRow:AddCell():AddText("Blacklisted")

		--#region Edit Popup
		-- local editPopup = tabHeader:AddPopup("EditItem")
		-- local editTable = editPopup:AddTable("EditTable", 3)
		-- editTable.SizingStretchProp = true

		-- ---@param itemList {[string]: ItemTemplate}
		-- local function EditItem(itemList)
		-- 	editPopup:Open()

		-- 	for templateName, itemTemplate in pairs(itemList) do
		-- 		local newRow = editTable:AddRow()
		-- 		local nameCell = newRow:AddCell()
		-- 		nameCell:AddImage(itemTemplate.Icon or "Item_Unknown", { 32, 32 }).Border = rarityColors[itemStat.Rarity]
		-- 		nameCell:AddText(templateName).SameLine = true

		-- 		--#region Rarity
		-- 		editPopup:AddText("Rarity")
		-- 		local rarityCombo = editPopup:AddCombo("")
		-- 		rarityCombo.SameLine = true
		-- 		local opts = {}
		-- 		for rarity, _ in pairs(rarityColors) do
		-- 			table.insert(opts, rarity)
		-- 		end
		-- 		rarityCombo.Options = opts
		-- 		--#endregion
		-- 	end

		-- 	editPopup:AddButton("Save")
		-- end
		--#endregion

		local delayTimer
		searchInput.OnChange = function()
			if delayTimer then
				Ext.Timer.Cancel(delayTimer)
			end

			delayTimer = Ext.Timer.WaitFor(150, function()
				resultsTable.Visible = true
				for _, child in pairs(resultsTable.Children) do
					---@cast child ExtuiTableRow
					if not child.Headers then
						child:Destroy()
					end
				end

				if #searchInput.Text >= 3 then
					local upperSearch = string.upper(searchInput.Text)
					for templateName, itemTemplate in pairs(allItemRoots) do
						if string.find(string.upper(templateName), upperSearch) then
							local newRow = resultsTable:AddRow()
							newRow.IDContext = itemTemplate.Id
							newRow.UserData = itemTemplate

							---@type Armor|Weapon
							local itemStat = Ext.Stats.Get(itemTemplate.Stats)

							local nameCell = newRow:AddCell()
							local icon = nameCell:AddImage(itemTemplate.Icon or "Item_Unknown", { 32, 32 })
							icon.Border = rarityColors[itemStat.Rarity]
							
							nameCell:AddText(templateName).SameLine = true

							local rarityCombo = newRow:AddCell():AddCombo("")
							rarityCombo.SameLine = true
							local opts = {}
							local selectIndex = 0
							for rarity, _ in pairs(rarityColors) do
								if rarity == itemStat.Rarity then
									selectIndex = #opts
								end
								table.insert(opts, rarity)
							end
							rarityCombo.Options = opts
							rarityCombo.SelectedIndex = selectIndex
							rarityCombo.OnChange = function ()
								itemStat.Rarity = rarityCombo.Options[rarityCombo.SelectedIndex + 1]
								icon.Border = rarityColors[itemStat.Rarity]
								_P(itemTemplate.Id)
							end
						end
					end
				end
			end)
		end
		--#endregion
	end)

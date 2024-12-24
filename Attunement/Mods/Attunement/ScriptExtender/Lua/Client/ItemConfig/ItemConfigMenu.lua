---@type table<FixedString, ItemTemplate>
local allItemRoots = {}
local sortedRoots = {}

local function populateTemplateTable()
	for templateName, template in pairs(Ext.ClientTemplate.GetAllRootTemplates()) do
		---@cast template ItemTemplate
		if template.TemplateType == "item" then
			---@type Armor|Weapon
			local stat = Ext.Stats.Get(template.Stats)

			local name = template.DisplayName:Get() or templateName
			if stat and stat.Rarity ~= "Common" and (stat.ModifierList == "Weapon" or stat.ModifierList == "Armor") and not allItemRoots[name] then
				table.insert(sortedRoots, name)
				allItemRoots[name] = template
			end
		end
	end
	-- Fewest amount of characters to most, so more relevant results are at the top of the list
	table.sort(sortedRoots)
end
populateTemplateTable()

-- https://bg3.norbyte.dev/search?q=rarity#result-f23802a9083da2ad18665deb188a569752dc7900
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
		tabHeader:AddText("Items with 'Common' rarity are filtered out")
		local searchInput = tabHeader:AddInputText("")
		searchInput.Hint = "Case-insensitive"
		searchInput.AutoSelectAll = true
		searchInput.EscapeClearsAll = true

		local resultsTable = tabHeader:AddTable("ResultsTable", 4)
		resultsTable.Hideable = true
		resultsTable.Visible = false
		resultsTable.ScrollY = true
		resultsTable.SizingFixedSame = true
		resultsTable.RowBg = true

		local headerRow = resultsTable:AddRow()
		headerRow.Headers = true
		headerRow:AddCell():AddText("Template")
		headerRow:AddCell():AddText("Rarity")
		headerRow:AddCell():AddText("Requires Attunement")

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
					for _, templateName in pairs(sortedRoots) do
						if string.find(string.upper(templateName), upperSearch) then
							local itemTemplate = allItemRoots[templateName]

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
							rarityCombo.OnChange = function()
								itemStat.Rarity = rarityCombo.Options[rarityCombo.SelectedIndex + 1]
								icon.Border = rarityColors[itemStat.Rarity]
								_P(itemTemplate.Id)
							end

							local requiresAttunement = newRow:AddCell():AddCheckbox("", itemStat.Boosts ~= "" or itemStat.PassivesOnEquip ~= "")
						end
					end
				end
			end)
		end
		--#endregion
	end)

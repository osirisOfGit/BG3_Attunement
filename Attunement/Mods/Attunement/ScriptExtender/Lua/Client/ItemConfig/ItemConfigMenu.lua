---@type table<FixedString, ItemTemplate>
local allItemRoots = {}
local sortedRoots = {}

local function populateTemplateTable()
	for templateName, template in pairs(Ext.ClientTemplate.GetAllRootTemplates()) do
		---@cast template ItemTemplate
		if template.TemplateType == "item" then
			---@type Armor|Weapon|Object
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

-- Has to happen in the client since StatsLoaded fires before the server starts up, so... might as well do here
Ext.Events.StatsLoaded:Subscribe(function()
	populateTemplateTable()

	for statName, raritySetting in pairs(ConfigurationStructure.config.items.rarityOverrides) do
		Ext.Stats.Get(statName).Rarity = raritySetting.New
	end

	local slotsCreated = {}

	for _, template in pairs(allItemRoots) do
		---@type Weapon|Armor|Object
		local stat = Ext.Stats.Get(template.Stats)

		-- Friggen lua falsy logic
		local shouldAttune = ConfigurationStructure.config.items.requiresAttunementOverrides[stat.Name]
		if shouldAttune == nil then
			shouldAttune = (stat.Boosts ~= "" or stat.PassivesOnEquip ~= "" or stat.StatusOnEquip ~= "")
		end

		if shouldAttune and (not stat.UseCosts or not string.find(stat.UseCosts, "Attunement:")) then
			if not stat.UseCosts then
				stat.UseCosts = "Attunement:1"
			else
				stat.UseCosts = stat.UseCosts .. (stat.UseCosts == "" and "" or ";") .. "Attunement:1"
			end

			if not slotsCreated[stat.Slot] then
				Ext.Stats.Create("ATTUNEMENT_REQUIRES_ATTUNEMENT_PASSIVE_" .. string.gsub(tostring(stat.Slot), " ", "_"), "PassiveData", "ATTUNEMENT_REQUIRES_ATTUNEMENT_PASSIVE"):Sync()
				slotsCreated[stat.Slot] = true
			end
			stat.PassivesOnEquip = stat.PassivesOnEquip .. (stat.PassivesOnEquip == "" and "" or ";") .. "ATTUNEMENT_REQUIRES_ATTUNEMENT_PASSIVE_" .. string.gsub(stat.Slot, " ", "_")
		end
	end

	Logger:BasicInfo("Successfully applied Rarity overrides")
	Logger:BasicDebug("Applied the following Rarity overrides: \n%s", Ext.Json.Stringify(ConfigurationStructure:GetRealConfigCopy().items.rarityOverrides))
end)


Mods.BG3MCM.IMGUIAPI:InsertModMenuTab(ModuleUUID, "Item Configuration",
	--- @param tabHeader ExtuiTreeParent
	function(tabHeader)
		tabHeader.TextWrapPos = 0

		local itemConfig = ConfigurationStructure.config.items

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
							icon.Border = RarityColors[itemStat.Rarity]

							nameCell:AddText(templateName).SameLine = true

							--#region Rarity
							local rarityCell = newRow:AddCell()
							local rarityCombo = rarityCell:AddCombo("")
							local opts = {}
							local selectIndex = 0
							for _, rarity in ipairs(RarityEnum) do
								if rarity == itemStat.Rarity then
									selectIndex = #opts
								end
								table.insert(opts, rarity)
							end
							rarityCombo.Options = opts
							rarityCombo.SelectedIndex = selectIndex

							-- ico comes from https://github.com/AtilioA/BG3-MCM/blob/83bbf711ac5feeb8d026345e2d64c9f19543294a/Mod Configuration Menu/Public/Shared/GUI/UIBasic_24-96.lsx#L1529
							local resetRarityButton = rarityCell:AddImageButton("resetRarity", "ico_reset_d", { 32, 32 })
							resetRarityButton.SameLine = true
							resetRarityButton.Visible = itemConfig.rarityOverrides[itemStat.Name] ~= nil
							resetRarityButton.OnClick = function()
								itemStat.Rarity = itemConfig.rarityOverrides[itemStat.Name].Original

								for i, rarity in ipairs(rarityCombo.Options) do
									if rarity == itemStat.Rarity then
										rarityCombo.SelectedIndex = i - 1
										icon.Border = RarityColors[itemStat.Rarity]
										break
									end
								end

								itemConfig.rarityOverrides[itemStat.Name].delete = true
								itemConfig.rarityOverrides[itemStat.Name] = nil
								resetRarityButton.Visible = false
							end

							rarityCombo.OnChange = function()
								local rarityOverride = itemConfig.rarityOverrides[itemStat.Name]
								---@type Rarity
								local selectedRarity = rarityCombo.Options[rarityCombo.SelectedIndex + 1]

								if not rarityOverride then
									itemConfig.rarityOverrides[itemStat.Name] = {
										Original = itemStat.Rarity,
										New = selectedRarity,
									}
								elseif rarityOverride.Original ~= selectedRarity then
									rarityOverride.New = selectedRarity
								else
									itemConfig.rarityOverrides[itemStat.Name].delete = true
									itemConfig.rarityOverrides[itemStat.Name] = nil
								end

								resetRarityButton.Visible = itemConfig.rarityOverrides[itemStat.Name] ~= nil
								itemStat.Rarity = selectedRarity
								icon.Border = RarityColors[itemStat.Rarity]
							end
							--#endregion

							local attunmentCell = newRow:AddCell()
							-- Friggen lua falsy logic
							local checkTheBox = itemConfig.requiresAttunementOverrides[itemStat.Name]
							if checkTheBox == nil then
								checkTheBox = string.find(itemStat.UseCosts, "Attunement") ~= nil
							end
							local requiresAttunement = attunmentCell:AddCheckbox("", checkTheBox)

							-- ico comes from https://github.com/AtilioA/BG3-MCM/blob/83bbf711ac5feeb8d026345e2d64c9f19543294a/Mod Configuration Menu/Public/Shared/GUI/UIBasic_24-96.lsx#L1529
							local resetAttunement = attunmentCell:AddImageButton("resetAttunement", "ico_reset_d", { 32, 32 })
							resetAttunement.SameLine = true
							resetAttunement.Visible = itemConfig.requiresAttunementOverrides[itemStat.Name] ~= nil
							resetAttunement.OnClick = function()
								requiresAttunement.Checked = not itemConfig.requiresAttunementOverrides[itemStat.Name]
								itemConfig.requiresAttunementOverrides[itemStat.Name] = nil
								resetAttunement.Visible = false
							end
							requiresAttunement.OnChange = function()
								if requiresAttunement.Checked == (string.find(itemStat.UseCosts, "Attunement") ~= nil) then
									itemConfig.requiresAttunementOverrides[itemStat.Name] = nil
									resetAttunement.Visible = false
								else
									itemConfig.requiresAttunementOverrides[itemStat.Name] = requiresAttunement.Checked
									resetAttunement.Visible = true
								end
							end
						end
					end
				end
			end)
		end
		--#endregion
	end)

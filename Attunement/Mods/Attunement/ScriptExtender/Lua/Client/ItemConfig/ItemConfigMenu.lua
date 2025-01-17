Ext.Require("Client/ItemConfig/ItemConfigTranslations.lua")

---@type table<FixedString, ItemTemplate>
local rootsByName = {}
local sortedTemplateNames = {}

local templateNameByModId = {}
local modIdByModName = {}

local function populateTemplateTable()
	for templateName, template in pairs(Ext.ClientTemplate.GetAllRootTemplates()) do
		---@cast template ItemTemplate
		if template.TemplateType == "item" then
			---@type ItemStat
			local stat = Ext.Stats.Get(template.Stats)

			local success, error = pcall(function()
				local name = template.DisplayName:Get() or templateName
				if stat
					and (stat.ModifierList == "Weapon" or stat.ModifierList == "Armor")
					and (stat.Slot ~= "Underwear" and not string.find(stat.Slot, "Vanity"))
					and not rootsByName[name]
				then
					table.insert(sortedTemplateNames, name)
					rootsByName[name] = template

					if stat.ModId ~= "" then
						if not templateNameByModId[stat.ModId] then
							modIdByModName[Ext.Mod.GetMod(stat.ModId).Info.Name] = stat.ModId
							templateNameByModId[stat.ModId] = {}
						end
						table.insert(templateNameByModId[stat.ModId], name)
						table.sort(templateNameByModId[stat.ModId])
					end
				end
			end)
			if not success then
				Logger:BasicWarning("Couldn't load stat %s (from Mod '%s') into the table due to %s", stat.Name,
					stat.ModId ~= "" and Ext.Mod.GetMod(stat.ModId).Info.Name or "Unknown",
					error)
			end
		end
	end

	table.sort(sortedTemplateNames)
end

-- Has to happen in the client since StatsLoaded fires before the server starts up, so... might as well do here
Ext.Events.StatsLoaded:Subscribe(function()
	if MCM.Get("enabled") then
		for statName, raritySetting in pairs(ConfigurationStructure.config.items.rarityOverrides) do
			local stat = Ext.Stats.Get(statName)
			if stat then
				stat.Rarity = raritySetting.New
			end
		end

		Logger:BasicInfo("Successfully applied Rarity overrides")
		Logger:BasicDebug("Applied the following Rarity overrides: \n%s", Ext.Json.Stringify(ConfigurationStructure:GetRealConfigCopy().items.rarityOverrides))
	end
end)

---@param tooltip ExtuiTooltip
---@param itemStat ItemStat
---@param itemTemplate ItemTemplate
local function BuildStatusTooltip(tooltip, itemStat, itemTemplate)
	tooltip:AddText("\n")
	tooltip:AddText(Translator:translate("Item Display Name: ") .. (itemTemplate.DisplayName:Get() or "N/A"))
	tooltip:AddText(Translator:translate("Stat Name: ") .. itemStat.Name)

	-- local description = itemTemplate.Description:Get() or "N/A"
	-- -- Getting rid of all content contained in <>, like <LsTags../> and <br/>
	-- description = string.gsub(description, "<.->", "")
	-- local desc = tooltip:AddText("Description: " .. description)
	-- desc.TextWrapPos = 600

	if itemStat.Using ~= "" then
		tooltip:AddText(Translator:translate("Using: ") .. itemStat.Using)
	end

	if itemStat.Slot ~= "" then
		tooltip:AddText(Translator:translate("Slot: ") .. itemStat.Slot)
	end

	if itemStat.PassivesOnEquip ~= "" then
		tooltip:AddText(Translator:translate("PassivesOnEquip: ") .. itemStat.PassivesOnEquip)
	end

	if itemStat.StatusOnEquip ~= "" then
		tooltip:AddText(Translator:translate("StatusOnEquip: ") .. itemStat.StatusOnEquip)
	end

	if itemStat.Boosts ~= "" then
		tooltip:AddText(Translator:translate("Boosts: ") .. itemStat.Boosts).TextWrapPos = 900
	end

	if itemStat.ModId ~= "" then
		local mod = Ext.Mod.GetMod(itemStat.ModId).Info
		tooltip:AddText(string.format(Translator:translate("From mod '%s' by '%s'"), mod.Name, mod.Author))
	end

	if itemStat.OriginalModId ~= "" and itemStat.OriginalModId ~= itemStat.ModId then
		local mod = Ext.Mod.GetMod(itemStat.OriginalModId).Info
		tooltip:AddText(string.format(Translator:translate("Originally from mod '%s' by '%s'"), mod.Name, mod.Author))
	end
end

local rarityTranslatedTable = {}

local filterSettings = {
	rarity = {},
	attunement = {
		["Gives Passive(s)"] = true,
		["Gives Status(es)"] = true,
		["Gives Boost(s)"] = true
	}
}

local cachedResults = {}

Mods.BG3MCM.IMGUIAPI:InsertModMenuTab(ModuleUUID, "Item Configuration",
	--- @param tabHeader ExtuiTreeParent
	function(tabHeader)
		if next(rootsByName) then
			-- got some reports of the imgui stuff being built twice - guess MCM is calling this twice somehow?
			return
		end

		populateTemplateTable()
		tabHeader.TextWrapPos = 0

		local itemConfig = ConfigurationStructure.config.items

		tabHeader:AddText(Translator:translate("Reload to see changes on existing items"))
		--#region Search
		tabHeader:AddText(Translator:translate("Items with 'Common' rarity are filtered out by default"))

		tabHeader:AddText(Translator:translate("Items with Rarity Level"))
		local rarityThreshold = tabHeader:AddCombo("")
		rarityThreshold.SameLine = true
		rarityThreshold.WidthFitPreview = true
		local opts = {}
		local selectIndex = 0
		for _, rarity in ipairs(RarityEnum) do
			if rarity == itemConfig.attunementRarityThreshold then
				selectIndex = #opts
			end
			rarityTranslatedTable[Translator:translate(rarity)] = rarity

			table.insert(opts, Translator:translate(rarity))
		end
		rarityThreshold.Options = opts
		rarityThreshold.SelectedIndex = selectIndex
		rarityThreshold.OnChange = function(rarityThresholdCombo)
			itemConfig.attunementRarityThreshold = rarityTranslatedTable[rarityThresholdCombo.Options[rarityThresholdCombo.SelectedIndex + 1]]
		end

		tabHeader:AddText(Translator:translate("or above can default to requiring Attunement")).SameLine = true

		local searchInput = tabHeader:AddInputText("")
		searchInput.Hint = "Case-insensitive"
		searchInput.AutoSelectAll = true
		searchInput.EscapeClearsAll = true

		tabHeader:AddText(Translator:translate("List all items by mod - will be cleared if above search is used"))
		local getAllForModCombo = tabHeader:AddCombo("")
		getAllForModCombo.WidthFitPreview = true
		local modOpts = {}
		for modId, _ in pairs(templateNameByModId) do
			table.insert(modOpts, Ext.Mod.GetMod(modId).Info.Name)
		end
		table.sort(modOpts)
		getAllForModCombo.Options = modOpts

		local resultsTable = tabHeader:AddTable("ResultsTable", 4)
		resultsTable.Hideable = true
		resultsTable.Visible = false
		resultsTable.ScrollY = true
		resultsTable.RowBg = true
		-- using table sizing methods shrinks the headers if there are no rows, so users can't change the filters
		resultsTable:AddColumn("Stat", "WidthStretch")
		resultsTable:AddColumn("Rarity")
		resultsTable:AddColumn("Attunement")

		local headerRow = resultsTable:AddRow()
		headerRow.Headers = true
		headerRow:AddCell():AddText(Translator:translate("Template"))

		local rarityHeaderCell = headerRow:AddCell()
		rarityHeaderCell:AddText(Translator:translate("Rarity"))
		local rarityFilterPopup = tabHeader:AddPopup("RarityFilter")
		local rarityFilterButton = rarityHeaderCell:AddImageButton("FilterRarity", "filter", { 24, 24 })
		rarityFilterButton.SameLine = true
		rarityFilterButton:SetColor("Button", { 1, 1, 1, 0 })
		rarityFilterButton.OnClick = function()
			rarityFilterPopup:Open()
		end

		local attunmentHeaderCell = headerRow:AddCell()
		attunmentHeaderCell:AddText(Translator:translate("Requires Attunement"))
		local attumenetFilterButton = attunmentHeaderCell:AddImageButton("FilterAttunement", "filter", { 24, 24 })
		local attunementFilterPopup = tabHeader:AddPopup("AttunementFilter")
		attumenetFilterButton.SameLine = true
		attumenetFilterButton:SetColor("Button", { 1, 1, 1, 0 })
		attumenetFilterButton.OnClick = function()
			attunementFilterPopup:Open()
		end

		local function displayResultInTable(templateName, usingCache)
			if not usingCache then
				table.insert(cachedResults, templateName)
			end

			local itemTemplate = rootsByName[templateName]

			---@type Armor|Weapon
			local itemStat = Ext.Stats.Get(itemTemplate.Stats)

			if filterSettings.rarity[itemStat.Rarity] == false
				or (itemStat.Boosts ~= "" and not filterSettings.attunement["Gives Boost(s)"])
				or (itemStat.PassivesOnEquip ~= "" and not filterSettings.attunement["Gives Passive(s)"])
				or (itemStat.StatusOnEquip ~= "" and not filterSettings.attunement["Gives Status(es)"])
			then
				return
			end

			local newRow = resultsTable:AddRow()
			newRow.IDContext = itemTemplate.Id
			newRow.UserData = itemTemplate

			local nameCell = newRow:AddCell()
			local spawnItem = nameCell:AddImageButton("Spawn_Item", "Spell_Conjuration_MageHand", { 32, 32 })
			spawnItem:Tooltip():AddText("\t\t" .. Translator:translate("Preview item - will equip to your controlled character for 60 seconds"))
			spawnItem.OnClick = function()
				Ext.Net.PostMessageToServer(ModuleUUID .. "SpawnItem", itemTemplate.Id)
			end

			local icon = nameCell:AddImage(itemTemplate.Icon or "Item_Unknown", { 32, 32 })
			icon.SameLine = true
			icon.Border = RarityColors[itemStat.Rarity]

			nameCell:AddText(templateName).SameLine = true

			BuildStatusTooltip(nameCell:Tooltip(), itemStat, itemTemplate)

			--#region Rarity
			local rarityCell = newRow:AddCell()
			local rarityCombo = rarityCell:AddCombo("")
			rarityCombo.Options = rarityThreshold.Options
			local raritySelectIndex = 0
			for index, rarity in pairs(rarityThreshold.Options) do
				if rarity == itemStat.Rarity then
					raritySelectIndex = index - 1
				end
			end
			rarityCombo.SelectedIndex = raritySelectIndex

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
				local selectedRarity = rarityTranslatedTable[rarityCombo.Options[rarityCombo.SelectedIndex + 1]]

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
				-- Friggen lua falsy logic
				checkTheBox = RarityEnum[itemStat.Rarity] >= RarityEnum[itemConfig.attunementRarityThreshold] and
					(itemStat.Boosts ~= "" or itemStat.PassivesOnEquip ~= "" or itemStat.StatusOnEquip ~= "")
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
				if requiresAttunement.Checked == (RarityEnum[itemStat.Rarity] >= RarityEnum[itemConfig.attunementRarityThreshold] and (itemStat.Boosts ~= "" or itemStat.PassivesOnEquip ~= "" or itemStat.StatusOnEquip ~= "")) then
					itemConfig.requiresAttunementOverrides[itemStat.Name] = nil
					resetAttunement.Visible = false
				else
					itemConfig.requiresAttunementOverrides[itemStat.Name] = requiresAttunement.Checked
					resetAttunement.Visible = true
				end
			end
		end

		for _, rarity in ipairs(rarityThreshold.Options) do
			---@type ExtuiSelectable
			local raritySelect = rarityFilterPopup:AddSelectable(rarity, "DontClosePopups")
			filterSettings.rarity[rarity] = filterSettings.rarity[rarity] or (rarity ~= "Common")
			raritySelect.Selected = filterSettings.rarity[rarity]

			---@param selectable ExtuiSelectable
			raritySelect.OnClick = function(selectable)
				filterSettings.rarity[rarityTranslatedTable[rarity]] = selectable.Selected

				rarityFilterButton:SetColor("Button", { 1, 1, 1, 0 })
				for filterRarity, filteringValue in pairs(filterSettings.rarity) do
					if (filterRarity == "Common" and filteringValue) or (filterRarity ~= "Common" and not filteringValue) then
						-- green with 50% opacity
						rarityFilterButton:SetColor("Button", { 0.09, 0.55, 0.04, 0.5 })
						break
					end
				end

				for _, child in pairs(resultsTable.Children) do
					---@cast child ExtuiTableRow
					if not child.Headers then
						child:Destroy()
					end
				end

				for _, result in pairs(cachedResults) do
					displayResultInTable(result, true)
				end
			end
		end

		for option, value in pairs(filterSettings.attunement) do
			---@type ExtuiSelectable
			local attunementSelect = attunementFilterPopup:AddSelectable(Translator:translate(option), "DontClosePopups")
			attunementSelect.Selected = value

			attunementSelect.OnClick = function()
				filterSettings.attunement[option] = attunementSelect.Selected

				attumenetFilterButton:SetColor("Button", { 1, 1, 1, 0 })
				for _, filteringValue in pairs(filterSettings.attunement) do
					if not filteringValue then
						-- green with 50% opacity
						attumenetFilterButton:SetColor("Button", { 0.09, 0.55, 0.04, 0.5 })
						break
					end
				end

				for _, child in pairs(resultsTable.Children) do
					---@cast child ExtuiTableRow
					if not child.Headers then
						child:Destroy()
					end
				end

				for _, result in pairs(cachedResults) do
					displayResultInTable(result, true)
				end
			end
		end

		getAllForModCombo.OnChange = function()
			resultsTable.Visible = true
			cachedResults = {}
			for _, child in pairs(resultsTable.Children) do
				---@cast child ExtuiTableRow
				if not child.Headers then
					child:Destroy()
				end
			end
			-- \[[[^_^]]]/
			for _, templateName in pairs(templateNameByModId[modIdByModName[getAllForModCombo.Options[getAllForModCombo.SelectedIndex + 1]]]) do
				displayResultInTable(templateName)
			end
		end

		local delayTimer
		searchInput.OnChange = function()
			if delayTimer then
				Ext.Timer.Cancel(delayTimer)
			end

			getAllForModCombo.SelectedIndex = -1

			delayTimer = Ext.Timer.WaitFor(150, function()
				cachedResults = {}
				resultsTable.Visible = true
				for _, child in pairs(resultsTable.Children) do
					---@cast child ExtuiTableRow
					if not child.Headers then
						child:Destroy()
					end
				end

				if #searchInput.Text >= 3 then
					local upperSearch = string.upper(searchInput.Text)
					for _, templateName in pairs(sortedTemplateNames) do
						if string.find(string.upper(templateName), upperSearch) then
							displayResultInTable(templateName)
						end
					end
				end
			end)
		end
		--#endregion
	end)

Ext.Events.StatsLoaded:Subscribe(function(e)
	for _, actionResourceGUID in pairs(Ext.StaticData.GetAll("ActionResource")) do
		---@type ResourceActionResource
		local actionResourceDefiniton = Ext.StaticData.Get(actionResourceGUID, "ActionResource")
		if string.find(actionResourceDefiniton.Name, "Attunement") then
			actionResourceDefiniton.IsHidden = true
			actionResourceDefiniton.ShowOnActionResourcePanel = false
		end
	end
end)

---@param button ExtuiButton
local function setEnabledButtonColor(button, enabled, rarityColor)
	if enabled then
		button:SetColor("Button", rarityColor)
	else
		button:SetColor("Button", { 0.458, 0.4, 0.29, 0.5 })
	end
end

Mods.BG3MCM.IMGUIAPI:InsertModMenuTab(ModuleUUID, "Rules",
	--- @param tabHeader ExtuiTreeParent
	function(tabHeader)
		tabHeader.TextWrapPos = 0

		local attuneConfig = ConfigurationStructure.config.rules

		tabHeader:AddText("All configurations are per-character's equipment - reload your save to apply changes. Add difficulty-specific configs using the + button below.")

		local difficultyGroup = tabHeader:AddGroup("Difficulties")

		---@param diffId Difficulties|'Base'
		---@return ExtuiCollapsingHeader
		local function buildDifficultySections(diffId)
			local difficultyConfig = attuneConfig.difficulties[diffId]
			if not difficultyConfig then
				attuneConfig.difficulties[diffId] = TableUtils:DeeplyCopyTable(ConfigurationStructure.DynamicClassDefinitions.rules)
				difficultyConfig = attuneConfig.difficulties[diffId]
			end

			local section = difficultyGroup:AddCollapsingHeader(diffId)
			section:AddText("Total Number Of Attuned Items Allowed")
			local totalAttuneLimitSlider = section:AddSliderInt("", difficultyConfig.totalAttunementLimit, 1, 12)

			totalAttuneLimitSlider.OnChange = function()
				difficultyConfig.totalAttunementLimit = totalAttuneLimitSlider.Value[1]
			end

			section:AddNewLine()
			section:AddText("Equipped Limits By Rarity (Accessories includes instruments, for compatibility with trinket mods)")
			local slotTable = section:AddTable("RarityBySlot", 5)
			slotTable.SizingStretchSame = true
			slotTable.BordersInnerH = true
			slotTable:SetStyle("ChildBorderSize", 20)

			local headerRow = slotTable:AddRow()
			headerRow.Headers = true
			headerRow:AddCell():AddText("")
			headerRow:AddCell():AddText("Total")
			headerRow:AddCell():AddText("Weapons")
			headerRow:AddCell():AddText("Armor")
			headerRow:AddCell():AddText("Accessories")

			for _, rarity in ipairs(RarityEnum) do
				local rarityLimitConfig = difficultyConfig.rarityLimits[rarity]
				if not rarityLimitConfig then
					difficultyConfig.rarityLimits[rarity] = TableUtils:DeeplyCopyTable(ConfigurationStructure.DynamicClassDefinitions.rarityLimitPerSlot)
					rarityLimitConfig = difficultyConfig.rarityLimits[rarity]
				end
				if not attuneConfig.guiRules[rarity] then
					attuneConfig.guiRules[rarity] = {}
				end

				local slotRow = slotTable:AddRow()
				slotRow:AddCell():AddText(rarity):SetColor("Text", RarityColors[rarity])

				for _, category in ipairs(RarityLimitCategories) do
					local rarityColor = TableUtils:DeeplyCopyTable(RarityColors[rarity])
					rarityColor[4] = 0.5 -- turn down the alpha, it bright AF

					local sliderCell = slotRow:AddCell()
					local slider = sliderCell:AddSliderInt("", rarityLimitConfig[category], 1,
						ConfigurationStructure.DynamicClassDefinitions.rarityLimitPerSlot[category])
					slider:SetColor("SliderGrab", rarityColor)
					slider.OnChange = function()
						rarityLimitConfig[category] = slider.Value[1]
					end

					if not attuneConfig.guiRules[rarity][category] then
						attuneConfig.guiRules[rarity][category] = TableUtils:DeeplyCopyTable(ConfigurationStructure.DynamicClassDefinitions.rules.rarityGuiDisplay)
					end
					local guiRules = attuneConfig.guiRules[rarity][category]

					local resourceButton = sliderCell:AddButton("R")
					resourceButton:SetStyle("FramePadding", 20, 0)
					setEnabledButtonColor(resourceButton, guiRules["resource"], rarityColor)

					local statusOnLimit = sliderCell:AddButton("SOL")
					statusOnLimit:SetStyle("FramePadding", 20, 0)
					statusOnLimit.SameLine = true
					setEnabledButtonColor(statusOnLimit, guiRules["statusOnLimit"], rarityColor)

					resourceButton.OnClick = function()
						guiRules["resource"] = not guiRules["resource"]
						setEnabledButtonColor(resourceButton, guiRules["resource"], rarityColor)
					end
					statusOnLimit.OnClick = function()
						guiRules["statusOnLimit"] = not guiRules["statusOnLimit"]
						setEnabledButtonColor(statusOnLimit, guiRules["statusOnLimit"], rarityColor)
					end
				end
			end

			return section
		end

		buildDifficultySections("Base")

		local addRowButton = tabHeader:AddButton("+")
		local difficultyPopop = tabHeader:AddPopup("")

		for _, difficulty in ipairs(Difficulties) do
			---@type ExtuiSelectable
			local difficultySelect = difficultyPopop:AddSelectable(difficulty, "DontClosePopups")

			difficultySelect.OnActivate = function()
				if difficultySelect.UserData then
					attuneConfig[difficulty].delete = true
					attuneConfig[difficulty] = nil
					difficultySelect.UserData:Destroy()
					difficultySelect.UserData = nil
				else
					difficultySelect.UserData = buildDifficultySections(difficulty)
				end
			end

			if attuneConfig[difficulty] then
				difficultySelect.Selected = true
				difficultySelect:OnActivate()
			end
		end

		addRowButton.OnClick = function()
			difficultyPopop:Open()
		end
	end)

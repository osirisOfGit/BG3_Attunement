Ext.Require("Client/Rules/RulesTranslations.lua")

local cachedResources = {}
local function initialize()
	for _, actionResourceGUID in pairs(Ext.StaticData.GetAll("ActionResource")) do
		---@type ResourceActionResource
		local actionResourceDefiniton = Ext.StaticData.Get(actionResourceGUID, "ActionResource")

		if string.find(actionResourceDefiniton.Name, ".*Attunement.*") then
			cachedResources[actionResourceDefiniton.Name] = actionResourceGUID
		end
	end
end

Ext.Events.StatsLoaded:Subscribe(function(e)
	---@type {[string]: RarityGuiRules}
	local transformedRarityGuiRules = {}

	if ConfigurationStructure.config.rules.rarityGuiRules then
		for rarity, rarityEntry in pairs(ConfigurationStructure.config.rules.rarityGuiRules) do
			if rarity ~= "Common" then
				for category, categoryEntry in pairs(rarityEntry) do
					if category ~= "Attunement Slots" then
						transformedRarityGuiRules[rarity .. category .. "LimitAttunement"] = categoryEntry
					end
				end
			end
		end
	end

	for _, actionResourceGUID in pairs(Ext.StaticData.GetAll("ActionResource")) do
		---@type ResourceActionResource
		local actionResourceDefiniton = Ext.StaticData.Get(actionResourceGUID, "ActionResource")

		if string.find(actionResourceDefiniton.Name, ".*Attunement.*") then
			if transformedRarityGuiRules[actionResourceDefiniton.Name] then
				actionResourceDefiniton.ShowOnActionResourcePanel = transformedRarityGuiRules[actionResourceDefiniton.Name]["resource"]
			else
				actionResourceDefiniton.ShowOnActionResourcePanel = ConfigurationStructure.config.rules.attunementGuiRules["resource"]
			end
		end
	end

	for statName, guiRule in pairs(transformedRarityGuiRules) do
		local success, error = pcall(function()
			---@type StatusData
			local stat = Ext.Stats.Get(statName)
			stat.StatusPropertyFlags = guiRule["statusOnLimit"] and {} or { "DisableOverhead", "DisableCombatlog", "DisablePortraitIndicator" }
			stat:Sync()
		end)

		if not success then
			Logger:BasicError("Couldn't process stat %s due to %s", statName, error)
		end
	end
end)

---@param button ExtuiButton
local function setEnabledButtonColor(button, enabled, enabledColor)
	if enabled then
		button:SetColor("Button", enabledColor)
	else
		button:SetColor("Button", { 0.458, 0.4, 0.29, 0.5 })
	end
end

Mods.BG3MCM.IMGUIAPI:InsertModMenuTab(ModuleUUID, "Rules",
	--- @param tabHeader ExtuiTreeParent
	function(tabHeader)
		if not next(cachedResources) then
			initialize()
		else
			return
		end

		tabHeader.TextWrapPos = 0

		local attuneConfig = ConfigurationStructure.config.rules

		local moreInfo = tabHeader:AddImageButton("More Info", "Action_Help", { 45, 45 })
		local moreInfoTooltip = moreInfo:Tooltip()
		moreInfoTooltip:AddText("\t\t" ..
			Translator:translate("\t\tAll configurations are per-character's equipment - reload to apply changes. Add difficulty-specific configs using the + button below."))
		moreInfoTooltip:AddText(Translator:translate("Each slider comes with two buttons: A button to show the Action Resource ('RES') and one to show the status ('STAT')"))
		moreInfoTooltip:AddText(Translator:translate(
			"The resource only shows when you're _below_ the equip limit for the given resource, and the status only shows when you've reached the given equip limit"))
		moreInfoTooltip:AddText(Translator:translate("The button settings are copied between difficulties - only the sliders are per-difficulty"))

		local difficultyGroup = tabHeader:AddGroup("Difficulties")

		---@param diffId Difficulties|'Base'
		---@return ExtuiCollapsingHeader
		local function buildDifficultySections(diffId)
			local difficultyConfig = attuneConfig.difficulties[diffId]
			if not difficultyConfig then
				attuneConfig.difficulties[diffId] = TableUtils:DeeplyCopyTable(ConfigurationStructure.DynamicClassDefinitions.rules)
				difficultyConfig = attuneConfig.difficulties[diffId]
			end

			local section = difficultyGroup:AddCollapsingHeader(Translator:translate(diffId))

			section:AddText(Translator:translate("Total Number Of Attuned Items Allowed"))
			local totalAttuneLimitSlider = section:AddSliderInt("", difficultyConfig.totalAttunementLimit, 1,
				ConfigurationStructure.DynamicClassDefinitions.rules.totalAttunementLimit)
			local attunementGuiRules = ConfigurationStructure.config.rules.attunementGuiRules
			local attunementResourceButton = section:AddButton(Translator:translate("RES"))
			attunementResourceButton:SetStyle("FramePadding", 15, 0)
			setEnabledButtonColor(attunementResourceButton, attunementGuiRules["resource"], { 0.458, 0.4, 0.29, 1.0 })

			local attunementStatusButton = section:AddButton(Translator:translate("STAT"))
			attunementStatusButton:SetStyle("FramePadding", 20, 0)
			attunementStatusButton.SameLine = true
			setEnabledButtonColor(attunementStatusButton, attunementGuiRules["statusOnLimit"], { 0.458, 0.4, 0.29, 1.0 })

			attunementResourceButton.OnClick = function()
				attunementGuiRules["resource"] = not attunementGuiRules["resource"]
				setEnabledButtonColor(attunementResourceButton, attunementGuiRules["resource"], { 0.458, 0.4, 0.29, 1.0 })
				Ext.StaticData.Get(cachedResources["Attunement"], "ActionResource").ShowOnActionResourcePanel = attunementGuiRules["resource"]
			end
			attunementStatusButton.OnClick = function()
				attunementGuiRules["statusOnLimit"] = not attunementGuiRules["statusOnLimit"]
				setEnabledButtonColor(attunementStatusButton, attunementGuiRules["statusOnLimit"], { 0.458, 0.4, 0.29, 1.0 })
				---@type StatusData
				local stat = Ext.Stats.Get("Attunement")
				stat.StatusPropertyFlags = attunementGuiRules["statusOnLimit"] and {} or { "DisableOverhead", "DisableCombatlog", "DisablePortraitIndicator" }
				stat:Sync()
			end

			totalAttuneLimitSlider.OnChange = function()
				difficultyConfig.totalAttunementLimit = totalAttuneLimitSlider.Value[1]
			end

			section:AddNewLine()
			section:AddText(Translator:translate("Equipped Limits By Rarity (Accessories includes instruments, for compatibility with trinket mods)"))
			local slotTable = section:AddTable("RarityBySlot", 6)
			slotTable.SizingStretchSame = true
			slotTable.BordersInnerH = true
			slotTable:SetStyle("ChildBorderSize", 20)

			local headerRow = slotTable:AddRow()
			headerRow.Headers = true
			headerRow:AddCell():AddText("")
			headerRow:AddCell():AddText(Translator:translate("Total"))
			headerRow:AddCell():AddText(Translator:translate("Weapons"))
			headerRow:AddCell():AddText(Translator:translate("Armor"))
			headerRow:AddCell():AddText(Translator:translate("Accessories"))
			headerRow:AddCell():AddText(Translator:translate("# of Attunement Slots Consumed") .. " (?)"):Tooltip():AddText(
			"Every item equipped will use the specified amount of Attunement Slots when equipped")

			for _, rarity in ipairs(RarityEnum) do
				if rarity ~= "Common" then
					local rarityLimitConfig = difficultyConfig.rarityLimits[rarity]
					if not rarityLimitConfig then
						difficultyConfig.rarityLimits[rarity] = TableUtils:DeeplyCopyTable(ConfigurationStructure.DynamicClassDefinitions.rarityLimitPerSlot)
						rarityLimitConfig = difficultyConfig.rarityLimits[rarity]
					end

					if not rarityLimitConfig["Attunement Slots"] then
						rarityLimitConfig["Attunement Slots"] = 1
					end

					if not attuneConfig.rarityGuiRules[rarity] then
						attuneConfig.rarityGuiRules[rarity] = {}
					end

					local slotRow = slotTable:AddRow()
					slotRow:AddCell():AddText(Translator:translate(rarity)):SetColor("Text", RarityColors[rarity])

					for _, category in ipairs(RarityLimitCategories) do
						local rarityColor = TableUtils:DeeplyCopyTable(RarityColors[rarity])
						rarityColor[4] = 0.5 -- turn down the alpha, it bright AF

						local sliderCell = slotRow:AddCell()
						local slider = sliderCell:AddSliderInt("", rarityLimitConfig[category], 1, ConfigurationStructure.DynamicClassDefinitions.rarityLimitPerSlot[category])
						slider:SetColor("SliderGrab", rarityColor)
						slider.OnChange = function()
							rarityLimitConfig[category] = slider.Value[1]
						end

						if not attuneConfig.rarityGuiRules[rarity][category] then
							attuneConfig.rarityGuiRules[rarity][category] = TableUtils:DeeplyCopyTable(ConfigurationStructure.DynamicClassDefinitions.rules.rarityGuiDisplay)
						end
						local guiRules = attuneConfig.rarityGuiRules[rarity][category]

						if category ~= "Attunement Slots" then
							local resourceButton = sliderCell:AddButton(Translator:translate("RES"))
							resourceButton:SetStyle("FramePadding", 10, 0)
							setEnabledButtonColor(resourceButton, guiRules["resource"], rarityColor)

							local statusOnLimit = sliderCell:AddButton(Translator:translate("STAT"))
							statusOnLimit:SetStyle("FramePadding", 7, 0)
							statusOnLimit.SameLine = true
							setEnabledButtonColor(statusOnLimit, guiRules["statusOnLimit"], rarityColor)

							resourceButton.OnClick = function()
								guiRules["resource"] = not guiRules["resource"]
								setEnabledButtonColor(resourceButton, guiRules["resource"], rarityColor)
								Ext.StaticData.Get(cachedResources[rarity .. category .. "LimitAttunement"], "ActionResource").ShowOnActionResourcePanel = guiRules["resource"]
							end
							statusOnLimit.OnClick = function()
								guiRules["statusOnLimit"] = not guiRules["statusOnLimit"]
								setEnabledButtonColor(statusOnLimit, guiRules["statusOnLimit"], rarityColor)
								---@type StatusData
								local stat = Ext.Stats.Get(rarity .. category .. "LimitAttunement")
								stat.StatusPropertyFlags = guiRules["statusOnLimit"] and {} or { "DisableOverhead", "DisableCombatlog", "DisablePortraitIndicator" }
								stat:Sync()
							end
						end
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
					attuneConfig.difficulties[difficulty].delete = true
					attuneConfig.difficulties[difficulty] = nil
					difficultySelect.UserData:Destroy()
					difficultySelect.UserData = nil
				else
					difficultySelect.UserData = buildDifficultySections(difficulty)
				end
			end

			if attuneConfig.difficulties[difficulty] then
				difficultySelect.Selected = true
				difficultySelect:OnActivate()
			end
		end

		addRowButton.OnClick = function()
			difficultyPopop:Open()
		end
	end)

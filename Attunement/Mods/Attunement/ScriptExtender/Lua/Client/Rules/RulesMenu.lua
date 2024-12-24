Mods.BG3MCM.IMGUIAPI:InsertModMenuTab(ModuleUUID, "Rules",
	--- @param tabHeader ExtuiTreeParent
	function(tabHeader)
		tabHeader.TextWrapPos = 0

		local attuneConfig = ConfigurationStructure.config.rules

		tabHeader:AddText("All configurations are per-character's equipment")

		local difficultyGroup = tabHeader:AddGroup("Difficulties")

		---@param difficultyData ResourceRuleset|'Base'
		---@return ExtuiCollapsingHeader
		local function buildDifficultySections(difficultyData)
			local diffId = difficultyData == "Base" and difficultyData or difficultyData.ResourceUUID
			local difficultyConfig = attuneConfig[diffId]
			if not difficultyConfig then
				attuneConfig[diffId] = TableUtils:DeeplyCopyTable(ConfigurationStructure.DynamicClassDefinitions.rules)
				difficultyConfig = attuneConfig[diffId]
			end

			local section = difficultyGroup:AddCollapsingHeader(difficultyData == "Base" and "Base" or (difficultyData.DisplayName:Get() or difficultyData.Name))
			section:AddText("Total Number Of Attuned Items Allowed")
			local totalAttuneLimitSlider = section:AddSliderInt("", difficultyConfig.totalAttunementLimit, 1, 12)
			-- totalAttuneLimitSlider.SameLine = true
			totalAttuneLimitSlider.OnChange = function ()
				difficultyConfig.totalAttunementLimit = totalAttuneLimitSlider.Value[1]
			end

			section:AddNewLine()
			section:AddText("Equipped Limits By Rarity")
			local slotTable = section:AddTable("RarityBySlot", 5)
			slotTable.SizingStretchProp = true

			local headerRow = slotTable:AddRow()
			headerRow.Headers = true
			headerRow:AddCell():AddText("")
			headerRow:AddCell():AddText("Total")
			headerRow:AddCell():AddText("Weapons")
			headerRow:AddCell():AddText("Armor")
			headerRow:AddCell():AddText("Accessories")

			for _, rarity in ipairs(RarityEnum) do
				local slotRow = slotTable:AddRow()
				slotRow:AddCell():AddText(rarity):SetColor("Text", RarityColors[rarity])
				for _, category in ipairs(RarityLimitCategories) do
					local rarityColor = TableUtils:DeeplyCopyTable(RarityColors[rarity])
					rarityColor[4] = 0.5 -- turn down the alpha, it bright AF
					local slider = slotRow:AddCell():AddSliderInt("", difficultyConfig.rarityLimitPerSlot[category], 1, ConfigurationStructure.DynamicClassDefinitions.rules.rarityLimitPerSlot[category])
					slider:SetColor("SliderGrab", rarityColor)
					slider.OnChange = function ()
						difficultyConfig.rarityLimitPerSlot[category] = slider.Value[1]
					end
				end
			end

			return section
		end

		buildDifficultySections("Base")

		local addRowButton = tabHeader:AddButton("+")
		local difficultyPopop = tabHeader:AddPopup("")

		for _, difficulty in pairs(Ext.StaticData.GetAll("Ruleset")) do
			---@type ResourceRuleset
			local difficultyData = Ext.StaticData.Get(difficulty, "Ruleset")
			if difficultyData.ShowInCustom then
				---@type ExtuiSelectable
				local difficultySelect = difficultyPopop:AddSelectable((difficultyData.DisplayName:Get() or difficultyData.Name), "DontClosePopups")

				difficultySelect.OnActivate = function()
					if difficultySelect.UserData then
						difficultySelect.UserData:Destroy()
						difficultySelect.UserData = nil
					else
						difficultySelect.UserData = buildDifficultySections(difficultyData)
					end
				end

				if attuneConfig[difficultyData.ResourceUUID] then
					difficultySelect.Selected = true
					difficultySelect:OnActivate()
				end
			end
		end

		addRowButton.OnClick = function()
			difficultyPopop:Open()
		end
	end)

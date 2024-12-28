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
			local difficultyConfig = attuneConfig[diffId]
			if not difficultyConfig then
				attuneConfig[diffId] = TableUtils:DeeplyCopyTable(ConfigurationStructure.DynamicClassDefinitions.rules)
				difficultyConfig = attuneConfig[diffId]
			end

			local section = difficultyGroup:AddCollapsingHeader(diffId)
			section:AddText("Total Number Of Attuned Items Allowed")
			local totalAttuneLimitSlider = section:AddSliderInt("", difficultyConfig.totalAttunementLimit, 1, 12)
			-- totalAttuneLimitSlider.SameLine = true
			totalAttuneLimitSlider.OnChange = function()
				difficultyConfig.totalAttunementLimit = totalAttuneLimitSlider.Value[1]
			end

			section:AddNewLine()
			section:AddText("Equipped Limits By Rarity (Accessories includes instruments, for compatibility with trinket mods)")
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
				local rarityLimitConfig = difficultyConfig.rarityLimits[rarity]
				if not rarityLimitConfig then
					difficultyConfig.rarityLimits[rarity] = TableUtils:DeeplyCopyTable(ConfigurationStructure.DynamicClassDefinitions.rarityLimitPerSlot)
					rarityLimitConfig = difficultyConfig.rarityLimits[rarity]
				end

				local slotRow = slotTable:AddRow()
				slotRow:AddCell():AddText(rarity):SetColor("Text", RarityColors[rarity])

				for _, category in ipairs(RarityLimitCategories) do
					local rarityColor = TableUtils:DeeplyCopyTable(RarityColors[rarity])
					rarityColor[4] = 0.5 -- turn down the alpha, it bright AF

					local slider = slotRow:AddCell():AddSliderInt("", rarityLimitConfig[category], 1,
						ConfigurationStructure.DynamicClassDefinitions.rarityLimitPerSlot[category])
					slider:SetColor("SliderGrab", rarityColor)
					slider.OnChange = function()
						rarityLimitConfig[category] = slider.Value[1]
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

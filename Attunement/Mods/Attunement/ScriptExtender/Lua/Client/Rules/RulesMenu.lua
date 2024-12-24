Mods.BG3MCM.IMGUIAPI:InsertModMenuTab(ModuleUUID, "Rules",
	--- @param tabHeader ExtuiTreeParent
	function(tabHeader)
		tabHeader.TextWrapPos = 0

		tabHeader:AddText("All configurations are per-character's equipment")

		local difficultyGroup = tabHeader:AddGroup("Difficulties")

		---@param difficulty string
		---@return ExtuiCollapsingHeader
		local function buildDifficultySections(difficulty)
			local section = difficultyGroup:AddCollapsingHeader(difficulty)
			section:AddText("Total Number Of Attuned Items Allowed")
			section:AddSliderInt("", 5, 1, 12).SameLine = true

			section:AddText("Total Number of Each Rarity Allowed")

			local totalSliderGroup = section:AddGroup("totalSlider")

			section:AddText("Limit Per Slot Group")
			local slotTable = section:AddTable("RarityBySlot", 4)
			slotTable.SizingStretchProp = true

			local headerRow = slotTable:AddRow()
			headerRow.Headers = true
			headerRow:AddCell():AddText("")
			headerRow:AddCell():AddText("Weapons")
			headerRow:AddCell():AddText("Armor")
			headerRow:AddCell():AddText("Accessories")

			for rarity, color in pairs({
				Common = { 1.00, 1.00, 1.00, 1.0 },
				Uncommon = { 0.00, 0.66, 0.00, 1.0 },
				Rare = { 0.20, 0.80, 1.00, 1.0 },
				VeryRare = { 0.64, 0.27, 0.91, 1.0 },
				Legendary = { 0.92, 0.78, 0.03, 1.0 },
			}) do
				totalSliderGroup:AddText(rarity):SetColor("Text", color)
				totalSliderGroup:AddSliderInt("", 12, 1, 12).SameLine = true

				local slotRow = slotTable:AddRow()
				slotRow:AddCell():AddText(rarity):SetColor("Text", color)
				for _, numberOfSlots in pairs({4, 5, 3} ) do
					slotRow:AddCell():AddSliderInt("", numberOfSlots, 1, numberOfSlots)
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
				local difficultySelect = difficultyPopop:AddSelectable(difficultyData.DisplayName:Get() or difficultyData.Name, "DontClosePopups")

				difficultySelect.OnActivate = function()
					if difficultySelect.UserData then
						difficultySelect.UserData:Destroy()
						difficultySelect.UserData = nil
					else
						difficultySelect.UserData = buildDifficultySections(difficultyData.DisplayName:Get() or difficultyData.Name)
					end
				end

				-- if universal.npc_multipliers[npcType] then
				-- 	difficultySelect.Selected = true
				-- 	difficultySelect:OnActivate()
				-- end
			end
		end

		addRowButton.OnClick = function()
			difficultyPopop:Open()
		end
	end)

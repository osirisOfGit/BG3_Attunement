-- https://bg3.norbyte.dev/search?q=rarity#result-f23802a9083da2ad18665deb188a569752dc7900

---@enum Rarity
RarityEnum = {
	Common = 1,
	Uncommon = 2,
	Rare = 3,
	VeryRare = 4,
	Legendary = 5,
	[1] = "Common",
	[2] = "Uncommon",
	[3] = "Rare",
	[4] = "VeryRare",
	[5] = "Legendary"
}

RarityColors = {
	Common = { 1, 1, 1, 0.6 },
	Uncommon = { 0.00, 0.66, 0.00, 1.0 },
	Rare = { 0.20, 0.80, 1.00, 1.0 },
	VeryRare = { 0.64, 0.27, 0.91, 1.0 },
	Legendary = { 0.92, 0.78, 0.03, 1.0 },
}

if Ext.IsClient() then
	Translator:RegisterTranslation({
		["Common"] = "h946e5228701f4acca6ecb49d275ee7e0e4e9",
		["Uncommon"] = "hd547009b37a14dc2b8a5140db50ac5013050",
		["Rare"] = "h1e84b7f41e9c477f9cbf104b0c01f5170g1d",
		["VeryRare"] = "hccaa2492212e4dba8dbed27aa5e9f2c6d97g",
		["Legendary"] = "h8e755293e99f4772b83589687d07154e0b4c",
	})
end

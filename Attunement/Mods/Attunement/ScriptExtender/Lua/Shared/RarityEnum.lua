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
	Common = { 1.00, 1.00, 1.00, 1.0 },
	Uncommon = { 0.00, 0.66, 0.00, 1.0 },
	Rare = { 0.20, 0.80, 1.00, 1.0 },
	VeryRare = { 0.64, 0.27, 0.91, 1.0 },
	Legendary = { 0.92, 0.78, 0.03, 1.0 },
}

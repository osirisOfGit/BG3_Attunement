Ext.Vars.RegisterModVariable(ModuleUUID, "Injury_Report", {
	Server = true,
	Client = true,
	WriteableOnServer = true,
	WriteableOnClient = true,
	SyncToClient = true,
	SyncToServer = true
})

Ext.Require("Shared/Utils/_FileUtils.lua")
Ext.Require("Shared/Utils/_ModUtils.lua")
Ext.Require("Shared/Utils/_Logger.lua")
Ext.Require("Shared/Utils/_TableUtils.lua")

Logger:ClearLogFile()

-- Ext.Require("Server/ECSPrinter.lua")

Ext.Require("Server/_DifficultyClassMap.lua")
Ext.Require("Server/_EventCoordinator.lua")

Ext.Require("Shared/Configurations/_ConfigurationStructure.lua")
Ext.Require("Server/_ConfigManager.lua")

Ext.Require("Shared/Attunement/_ConfigHelper.lua")
Ext.Require("Server/Attunement/_Damage.lua")
Ext.Require("Server/Attunement/_RandomInjuryOnCondition.lua")
Ext.Require("Server/Attunement/_Healing.lua")
Ext.Require("Server/Attunement/_ApplyOnStatus.lua")
Ext.Require("Server/Attunement/_RemoveOnStatus.lua")

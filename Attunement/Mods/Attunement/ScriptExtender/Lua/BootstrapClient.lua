Ext.Require("Shared/Utils/_TableUtils.lua")
Ext.Require("Shared/Utils/_FileUtils.lua")
Ext.Require("Shared/Utils/_ModUtils.lua")
Ext.Require("Shared/Utils/_Logger.lua")

Ext.Events.StatsLoaded:Subscribe(function()
	Logger:ClearLogFile()
end)

Ext.Require("Shared/Configurations/_ConfigurationStructure.lua")

ConfigurationStructure:InitializeConfig()

Ext.Require("Client/ItemConfig/ItemConfigMenu.lua")
Ext.Require("Client/Rules/RulesMenu.lua")

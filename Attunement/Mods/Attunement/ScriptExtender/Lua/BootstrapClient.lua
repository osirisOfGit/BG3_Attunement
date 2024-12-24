-- PersistentVars = {}

Ext.Require("Shared/Utils/_TableUtils.lua")
Ext.Require("Shared/Utils/_FileUtils.lua")
Ext.Require("Shared/Utils/_ModUtils.lua")
Ext.Require("Shared/Utils/_Logger.lua")

Ext.Require("Shared/Configurations/_ConfigurationStructure.lua")

ConfigurationStructure:InitializeConfig()

Ext.Require("Client/_DataSearchHelper.lua")
Ext.Require("Client/ItemConfig/ItemConfigMenu.lua")
-- Ext.Require("Client/Attunement/Attunement/AttunementMenu.lua")

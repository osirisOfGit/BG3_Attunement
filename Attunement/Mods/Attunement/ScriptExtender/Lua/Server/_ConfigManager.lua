ConfigManager = {}

ConfigManager.ConfigCopy = {}

-- Need to make sure the server's copy of the config is up-to-date since that's where the actual functionality is
Ext.RegisterNetListener(ModuleUUID .. "_UpdateConfiguration", function(_, _, _)
	ConfigurationStructure:UpdateConfigForServer()
	ConfigManager.ConfigCopy = ConfigurationStructure:GetRealConfigCopy()


end)

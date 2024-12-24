ConfigManager = {}

ConfigManager.ConfigCopy = {}

Ext.RegisterNetListener(ModuleUUID .. "_UpdateConfiguration", function(_, _, _)
	ConfigManager.ConfigCopy = ConfigurationStructure:UpdateConfigForServer()
end)

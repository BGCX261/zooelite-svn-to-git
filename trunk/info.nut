/*
 * This file is part of ZooElite, an OpenTTD AI
 *
 */

// min OpenTTD nightly: 2009-01-18

class ZooElite extends AIInfo {
	function GetAuthor()      { return "Cameron Muesco and Charlie Croom"; }
	function GetName()        { return "ZooElite"; }
	function GetShortName()   { return "ZOOE"; }
	function GetDescription() { return "ZooElite aims to be harder, better, faster, stronger."; }
	function GetVersion()     { return 1; }
	function GetDate()        { return "2010-01-14"; }
	function GetUrl()         { return "Coming Soon"; }
	function UseAsRandomAI()  { return false; }
	function CreateInstance() { return "ZooElite"; }
	
	// There is no saved state, but by setting <= this version, users
	// will not use an older version that might not handle the vehicles
	// as well as the one that was used to make the save game
	function CanLoadFromVersion(version) { return version <= GetVersion(); }

	function GetSettings() {
		AddSetting({name = "avoid_town_road_grid", description = "Avoid building bus stops and depots on town road grid", easy_value = 1, medium_value = 1, hard_value = 1, custom_value = 1, flags = AICONFIG_BOOLEAN});
		AddSetting({name = "forbid_town_road_grid", description = "Forbid building bus stops and depots on town road grid", easy_value = 1, medium_value = 0, hard_value = 0, custom_value = 0, flags = AICONFIG_BOOLEAN});
		AddSetting({name = "debug_signs", description = "Enable building debug signs", easy_value = 0, medium_value = 0, hard_value = 0, custom_value = 0, flags = AICONFIG_BOOLEAN});
		AddSetting({
			name = "debug_level", 
			description = "Debug Level", 
			min_value = 1, 
			max_value = 5, 
			easy_value = 4, 
			medium_value = 4, 
			hard_value = 4, 
			custom_value = 4, 
			flags = 0
		});
		AddLabels("debug_level", {_1 = "Verbose", _2 = "High", _3 = "Informative", _4 = "Normal", _5 = "Critical Only"});
	}

}

/* Tell the core we are an AI */
RegisterAI(ZooElite());

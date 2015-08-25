
//Get Potentially usable, existing rail station placements for a given city
//returns a list of stations within the constant STATION_REUSE_DISTANCE_FROM_TOWN
function ZooElite::GetRailStationsForCity(townId) {
	//Get a list of stations which are bus stops in this town
	local stations = AIStationList(AIStation.STATION_TRAIN);
	
	//Special Valuate
	for(local stationIndex = stations.Begin(); stations.HasNext(); stationIndex = stations.Next()) {
		local distance = AIMap.DistanceManhattan(AIBaseStation.GetLocation(stationIndex), AITown.GetLocation(townId));
		stations.SetValue(stationIndex, distance);
	}
	
	//Figure out how far we want to go
	stations.RemoveAboveValue(STATION_REUSE_DISTANCE_FROM_TOWN);
	stations.Sort(AIAbstractList.SORT_BY_VALUE, false);
	LogManager.Log("Found " + stations.Count() + " potentially valid, existing station placements", 1);
	return stations;
}

//This function actually finds an appropriate build site for the given specifications
//ARGS: TownId, TileId to search from, Direction to point (MUST BE FAR ENOUGH AWAY), number of platforms, boolean is_terminus
//RETURNS: stationId of new station?

function ZooElite::BuildRailStationForTown(townId, tileId, direction_of_tileId, platforms, is_terminus) {
	
	//Attempt to determine if we could build on this spot
	local square_x = RAIL_STATION_PLATFORM_LENGTH + 2 * (platforms);
	if(is_terminus)
		square_x -= platforms - 2;
	
	//One for return track, one for bus stations, one for road from bus stations?
	local square_y = 3 + platforms;
	if(!is_terminus)
		square_y -= 1;
		
	
	local tilelist = AITileList();
	local seed_tile = 0;
	
	//TODO: What we actually want here is a station associated with a town...it doesn't have to be in a town
	//		Moreover, do we want to check from the city distance or now?
	//Attempt to find exsisting stations close to the town
	if(AITown.IsValidTown(townId) && !AIMap.IsValidTile(tileId)) {
		seed_tile = AITown.GetLocation(townId);
	} else {
		seed_tile = tileId;
	}
	
	LogManager.Log("Attempting to get rail station for " + AITown.GetName(townId) + " with size " + square_x + " and " + square_y, 4);
	/*	local curStations = ZooElite.GetRailStationsForCity(townId);
		if(curStations.Count() > 0) {
			LogManager.Log("Reusing existing station #" + curStations.Begin(), 3);
			town_table[townId].rail_station_id = curStations.Begin();
			LinkTileToTown(station_table[curStations.Begin()].bus_stops[0], townId);
			return curStations.Begin();
		}*/
	
	local searchRadius = RAIL_STATION_SEARCH_RADIUS;
	
	//TODO: IMPORTANT: Improve this algorithm, we otherwise restrict the search too much when things are close to the edge, maybe we should expand in the other directions?
	//Ensure we aren't analyzing off the map as this will cause issues
	//SafeAddRectangle(tilelist, seed_tile, searchRadius);
	
		//We need to manually define the radius
		//SafeAddRectangle(tilelist, seed_tile, searchRadius);
		
		local left_dist = AIMap.GetTileX(seed_tile) - 2;
		local right_dist = AIMap.GetMapSizeX() - 2 - left_dist;
		local top_dist = AIMap.GetTileY(seed_tile) - 2;
		local bot_dist = AIMap.GetMapSizeY() - 2 - top_dist;
		LogManager.Log("Left, Right, Up, Down: " + left_dist + " " + right_dist + " " + top_dist + " " + bot_dist, 1);
		if(searchRadius + square_x < left_dist) 
			left_dist = searchRadius + square_x;
		if(searchRadius < right_dist)
			right_dist = searchRadius;
		if(searchRadius + square_y < top_dist)
			top_dist = searchRadius + square_y;
		if(searchRadius < bot_dist)
			bot_dist = searchRadius;
		
		LogManager.Log("Altered Left, Right, Up, Down: " + left_dist + " " + right_dist + " " + top_dist + " " + bot_dist, 1);
		local top_corner = AIMap.GetTileIndex(AIMap.GetTileX(seed_tile) - left_dist + 1, AIMap.GetTileY(seed_tile) - top_dist + 1);
		local bot_corner = AIMap.GetTileIndex(AIMap.GetTileX(seed_tile) + right_dist - 1, AIMap.GetTileY(seed_tile) + bot_dist - 1);
		tilelist.AddRectangle(top_corner,bot_corner);
		Sign(top_corner, "Search Corner 1");
		Sign(bot_corner, "Search Corner 2");
	
	

	//Ensure that we are on the right side of the tile
	local town_to_tile = AIMap.DistanceManhattan(seed_tile, direction_of_tileId);
	LogManager.Log("Town to Tile Distance: " + town_to_tile, 1);
	tilelist.Valuate(AIMap.DistanceManhattan, direction_of_tileId);
	tilelist.RemoveAboveValue(town_to_tile + RAILSTATION_IN_DIRECTION_OF_FLEX);
	
	
	
	//OK So now we have a pretty good list, time to start testing rectangles, we want a station like so:
	// 	  B B B
	// 	/SSSSSS-\
	//	/SSSSSS--\
	//	/SSSSSS---\
	//	/SSSSSS----\---------
	//	\--------------------
	//
	//Equates to around a  5x15 rectangle, or 5x9 core with extension. (platforms + 1)
	//Search is a 5x11 rectange, attempt to clear extra tile if needed, then search the rail extension.
	
	//Or for a non terminus station
	// 		   /-SSSSSS-\
	//		  /--SSSSSS--\
	//		 /---SSSSSS---\
	//------/----SSSSSS----\---------
	//-----/----------------\--------
	
	
	//IMPORTANT: TODO: RIGHT NOW THIS FUNCTION IS CONFUSING BECAUSE HORIZONTAL AND VERTICAL ARE BACKWARDS OR ARE THEY?
	
	
	//Build seperate vertical tilelist
	local verticletilelist = AITileList();
	verticletilelist.AddList(tilelist);
	
	//Remove unbuildable options
	tilelist.Valuate(canBuildRectangleAtCorner, square_y, square_x);
	tilelist.RemoveValue(0);
	verticletilelist.Valuate(canBuildRectangleAtCorner, square_x, square_y);
	verticletilelist.RemoveValue(0);
	
	//Ok so we may or may not actually be able to build on these...let's try to figure out how much it'd cost
	//Sort results by cost
	for(local tileId = tilelist.Begin(); tilelist.HasNext(); tileId = tilelist.Next()) {
		local result = RAIL_ACTUAL_COST_WEIGHT * CostToLevelRectangle(tileId, square_y + 1, square_x + 1);
		if(result > -1) {
			result += RAIL_STATION_SEARCH_DISTANCE_WEIGHT * AITile.GetBuildCost(AITile.BT_TERRAFORM) 
							* AIMap.DistanceManhattan(GetTileRelative(tileId, Floor(square_y / 2), Floor(square_x / 2)), seed_tile);
			result -= AITile.GetBuildCost(AITile.BT_TERRAFORM) * RAIL_STATION_SEARCH_CARGO_WEIGHT * AITile.GetCargoProduction(GetTileRelative(tileId, Floor(square_x / 2), Floor(square_y / 2)), GetPassengerCargoID(), 4, 4, 4);
			//Sign(tileId, result);
		}
		tilelist.SetValue(tileId, result);
	}
	tilelist.RemoveValue(-1);
	tilelist.Sort(AIAbstractList.SORT_BY_VALUE, true);
	for(local tileId = verticletilelist.Begin(); verticletilelist.HasNext(); tileId = verticletilelist.Next()) {
		local result = CostToLevelRectangle(tileId, square_x + 1, square_y + 1);
		if(result > -1) {
			result += RAIL_STATION_SEARCH_DISTANCE_WEIGHT * AITile.GetBuildCost(AITile.BT_TERRAFORM) 
							* AIMap.DistanceManhattan(GetTileRelative(tileId, Floor(square_x / 2), Floor(square_y / 2)), seed_tile);
			result -= AITile.GetBuildCost(AITile.BT_TERRAFORM) * RAIL_STATION_SEARCH_CARGO_WEIGHT * AITile.GetCargoProduction(GetTileRelative(tileId, Floor(square_x / 2), Floor(square_y / 2)), GetPassengerCargoID(), 4, 4, 4);
			//Sign(tileId, result);
		}
		
		verticletilelist.SetValue(tileId, result);
	}
	verticletilelist.RemoveValue(-1);
	verticletilelist.Sort(AIAbstractList.SORT_BY_VALUE, true);
	
	//This means we can't build here...sad
	if(verticletilelist.Count() == 0 && tilelist.Count() == 0) {
		LogManager.Log("Unable to find suitable location to build station in " + AITown.GetName(townId), 4);
		return false;
	}
	
	//TODO: ADD A FUNCTION TO GENERATE A SCORING METRIC
	//Evaluate each, and choose the best plot to build on
	//local vert_propisiton = verticletilelist.Begin();
	//local horz_propisiton = tilelist.Begin();
	LogManager.Log("Found " + verticletilelist.Count() + " " + tilelist.Count() + " locations for " +  AITown.GetName(townId), 4);
	
	
	//The below routines run through different possible station orientations and configurations to find the most viable one
	local result = false;
	if(is_terminus) {
		while((verticletilelist.Count() > 0 || tilelist.Count() > 0) && result == false) {
			
			local top_left_tile = null;
			local horizontal = true;
			local swap = true;
			local vert_propisiton = 0;
			local horz_propisiton = 0;
			
			if(verticletilelist.Count() > 0) {
				vert_propisiton = verticletilelist.Begin();
			}
			if(tilelist.Count() > 0) {
				horz_propisiton = tilelist.Begin();
			}
			
			if(vert_propisiton == 0) {
				top_left_tile = horz_propisiton;
			} else if(horz_propisiton == 0 || verticletilelist.GetValue(vert_propisiton) < tilelist.GetValue(horz_propisiton)) {
				top_left_tile = vert_propisiton;
				horizontal = false;
			} else {
				top_left_tile = horz_propisiton;
			}
			
			
			if(horizontal) {
				local spot2 = GetTileRelative(top_left_tile, square_y, square_x);
				local spot1 = GetTileRelative(top_left_tile, 0, 0);
				if(canBuildRectangleAtCorner(spot1, 1, -DOWN_TRACK_SPACE) && 
						(verticletilelist.Count() + tilelist.Count() == 1 ||
						AIMap.DistanceManhattan(spot1, direction_of_tileId) < AIMap.DistanceManhattan(spot2, direction_of_tileId) + RAILSTATION_IN_DIRECTION_OF_FLEX)) {
						result = ZooElite.BuildTrainStation(townId, top_left_tile, platforms, is_terminus, horizontal, true);						
				} else if(canBuildRectangleAtCorner(spot2, -1, DOWN_TRACK_SPACE) && 
						(verticletilelist.Count() + tilelist.Count() == 1 ||
							AIMap.DistanceManhattan(spot2, direction_of_tileId) < AIMap.DistanceManhattan(spot1, direction_of_tileId) + RAILSTATION_IN_DIRECTION_OF_FLEX)) {
						result = ZooElite.BuildTrainStation(townId, top_left_tile, platforms, is_terminus, horizontal, false);						
				} else {
					tilelist.RemoveTop(1);
				}
				if(result == false) {
					tilelist.RemoveTop(1);
				}
			} else {
				local spot2 = GetTileRelative(top_left_tile, square_x, 0);
				local spot1 = GetTileRelative(top_left_tile, 0, square_y);
				if(canBuildRectangleAtCorner(spot1, -DOWN_TRACK_SPACE, -1) && 
						(verticletilelist.Count() + tilelist.Count() == 1 ||
							AIMap.DistanceManhattan(spot1, direction_of_tileId) < AIMap.DistanceManhattan(spot2, direction_of_tileId) + RAILSTATION_IN_DIRECTION_OF_FLEX)) {
							
					result = ZooElite.BuildTrainStation(townId, top_left_tile, platforms, is_terminus, horizontal, true);				
				} else if(canBuildRectangleAtCorner(spot2, DOWN_TRACK_SPACE, 1) && 
						(verticletilelist.Count() + tilelist.Count() == 1 || 
							AIMap.DistanceManhattan(spot2, direction_of_tileId) < AIMap.DistanceManhattan(spot1, direction_of_tileId) + RAILSTATION_IN_DIRECTION_OF_FLEX)) {
					result = ZooElite.BuildTrainStation(townId, top_left_tile, platforms, is_terminus, horizontal, false);						
				} else {
					verticletilelist.RemoveTop(1);
				}
				if(result == false) {
					verticletilelist.RemoveTop(1);
				}
			}
			
		}
		//Run through for through-stations...little more difficult
	} else {
		while((verticletilelist.Count() > 0 || tilelist.Count() > 0) && result == false) {
			//LogManager.Log("Found " + verticletilelist.Count() + " " + tilelist.Count() + " locations for " +  AITown.GetName(townId), 4);
			if(AICompany.GetBankBalance(AICompany.COMPANY_SELF) < 25000) {
				LogManager.Log("Money low, station building failing...", 4);
				return false;
			}
			local top_left_tile = null;
			local horizontal = true;
			local swap = true;
			
			local horz_propisiton = null;
			local vert_propisiton = null;
			
			if(verticletilelist.Count() > 0) {
				vert_propisiton = verticletilelist.Begin();
			}
			
			if(tilelist.Count() > 0) {
				horz_propisiton = tilelist.Begin();
			}
			
			local left_bot_bool = null;
			local right_bot_bool = null;
			if(verticletilelist.Count() == 0) {
				top_left_tile = horz_propisiton;
			} else if(tilelist.Count() == 0 || verticletilelist.GetValue(vert_propisiton) < tilelist.GetValue(horz_propisiton)) {
				top_left_tile = vert_propisiton;
				horizontal = false;
			} else {
				top_left_tile = horz_propisiton;
			}
			if(horizontal == true) {
				//1   --PPPPPPP--    3
				//   /--PPPPPPP--\
				//2-/---PPPPPPP---\--4
				// -/---PPPPPPP----\-
				//Sign(top_left_tile, "TL");
				local spot1 = GetTileRelative(top_left_tile, 2, 0);
				local spot2 = GetTileRelative(spot1, platforms - 2, 0);				
				local spot3 = GetTileRelative(spot1, 0, square_x + 1);
				local spot4 = GetTileRelative(spot3, platforms - 2, 0);	
				
				//Sign(spot1, "1");
				//Sign(spot2, "2");
				//Sign(spot3, "3");
				//Sign(spot4, "4");
					
				local left_bot_bool = null;
				local right_bot_bool = null;
				if(canBuildRectangleAtCorner(spot1, 1, -DOWN_TRACK_SPACE) && canBuildRectangleAtCorner(spot2, 1, -DOWN_TRACK_SPACE)) {
					if(AIMap.DistanceManhattan(spot1, direction_of_tileId) < AIMap.DistanceManhattan(spot2, direction_of_tileId)) {
						left_bot_bool = 0;
					} else {
						left_bot_bool = 1;
					}
				} else if(canBuildRectangleAtCorner(spot1, 1, -DOWN_TRACK_SPACE)) {
					left_bot_bool = 0;
				} else if(canBuildRectangleAtCorner(spot2, 1, -DOWN_TRACK_SPACE)) {
					left_bot_bool = 1;
				} else {
					tilelist.RemoveTop(1);
					continue;
				}
				if(canBuildRectangleAtCorner(spot3, 1, DOWN_TRACK_SPACE) && canBuildRectangleAtCorner(spot4, 1, DOWN_TRACK_SPACE)) {
					if(AIMap.DistanceManhattan(spot3, direction_of_tileId) < AIMap.DistanceManhattan(spot4, direction_of_tileId)) {
						right_bot_bool = 0;
					} else {
						right_bot_bool = 1;
					}
				} else if(canBuildRectangleAtCorner(spot3, 1, DOWN_TRACK_SPACE)) {
					right_bot_bool = 0;
				} else if(canBuildRectangleAtCorner(spot4, 1, DOWN_TRACK_SPACE)) {
					right_bot_bool = 1;
				} else {
					tilelist.RemoveTop(1);
					continue;
				}
				result = BuildRegionalStation(top_left_tile, platforms, horizontal, false, left_bot_bool, right_bot_bool);	
				if(result == false) {
					tilelist.RemoveTop(1);
				}						

			} else {
				//vertical
				local spot1 = top_left_tile;
				local spot2 = GetTileRelative(top_left_tile, 0, platforms - 2);				
				local spot3 = GetTileRelative(top_left_tile, square_x + 1, 0);
				local spot4 = GetTileRelative(spot3, 0, platforms - 2);	
				
				if(canBuildRectangleAtCorner(spot1, -DOWN_TRACK_SPACE, 1) && canBuildRectangleAtCorner(spot2, -DOWN_TRACK_SPACE, 1)) {
					if(AIMap.DistanceManhattan(spot1, direction_of_tileId) < AIMap.DistanceManhattan(spot2, direction_of_tileId)) {
						left_bot_bool = 0;
					} else {
						left_bot_bool = 1;
					}
				} else if(canBuildRectangleAtCorner(spot1, -DOWN_TRACK_SPACE, 1)) {
					left_bot_bool = 0;
				} else if(canBuildRectangleAtCorner(spot2, -DOWN_TRACK_SPACE, 1)) {
					left_bot_bool = 1;
				} else {
					verticletilelist.RemoveTop(1);
					continue;
				}
				if(canBuildRectangleAtCorner(spot3, DOWN_TRACK_SPACE, 1) && canBuildRectangleAtCorner(spot4, DOWN_TRACK_SPACE, 1)) {
					if(AIMap.DistanceManhattan(spot3, direction_of_tileId) < AIMap.DistanceManhattan(spot4, direction_of_tileId)) {
						right_bot_bool = 0;
					} else {
						right_bot_bool = 1;
					}
				} else if(canBuildRectangleAtCorner(spot3, DOWN_TRACK_SPACE, 1)) {
					right_bot_bool = 0;
				} else if(canBuildRectangleAtCorner(spot4, DOWN_TRACK_SPACE, 1)) {
					right_bot_bool = 1;
				} else {
					verticletilelist.RemoveTop(1);
					continue;
				}
				result = ZooElite.BuildRegionalStation(top_left_tile, platforms, horizontal, false, left_bot_bool, right_bot_bool);		
				if(result == false) {
					verticletilelist.RemoveTop(1);
				}
			}
		}
	}
	if(result == false) {
		LogManager.Log("Unable to find any station placements", 5);
		return false;
	}
	return result;
		
	/*
	//Lastly, asess the tiles in the order of closest to in direct line OR COST TO LEVEL
	//Special Valuate
	for(local tileIndex = tilelist.Begin(); tilelist.HasNext(); tileIndex = tilelist.Next()) {
		local sum = 2* AIMap.DistanceManhattan(tileIndex, AITown.GetLocation(townId))
						+ AIMap.DistanceManhattan(tileIndex, tileId);
		tilelist.SetValue(tileIndex, sum);
		AITile.BT_TERRAFORM
	}
	tilelist.Sort(AIAbstractList.SORT_BY_VALUE, true);
	*/
}

//Figure out if we can build here...
function canBuildRectangleAtCorner(tileId, square_x, square_y) {
	
	if(!AITile.IsBuildableRectangle(tileId, square_x, square_y))
		return false;
	
	local tilelist = AITileList();	
	tilelist.AddRectangle(tileId, GetTileRelative(tileId, square_x, square_y)); 
	//Create our target rectangle and get the tile count for comparison
	local old_count = tilelist.Count();
	tilelist.Valuate(AITile.IsBuildable);
	tilelist.RemoveValue(0);
	tilelist.Valuate(AITile.IsWaterTile);
	tilelist.RemoveValue(1);
	tilelist.Valuate(AITile.IsCoastTile);
	tilelist.RemoveValue(1);
	if(tilelist.Count() != old_count) {
		return false;
	}
	
	return true;
}

//Return the cost to flatten this rectangle
function CostToLevelRectangle(tileId, square_x, square_y) {
	local level_cost = 0;
	//tileId = top_left_tile;
	{{
		local test = AITestMode();
		local account = AIAccounting();
		local tiles = AITileList();
		tiles.AddRectangle(tileId, GetTileRelative(tileId, square_x - 1, square_y - 1));
		local prev_count = tiles.Count();
		tiles.Valuate(AITile.GetSlope);
		tiles.KeepValue(0);
		if(tiles.Count() == prev_count)
			return 1;
		if(!LevelLand(GetTileRelative(tileId, -1, -1), GetTileRelative(tileId, square_x, square_y)))
			return -1;

		level_cost = account.GetCosts();
	}}

	return level_cost;
}

//Big nasty function to build a big regional station
//Regional stations MAY have bus stops. Because they can serve as base stations.
function ZooElite::BuildRegionalStation(top_left_tile, platforms, horz, shift, left_bot_bool, right_bot_bool) {

	//Create the object to store data on
	local this_station = Station();
	this_station.platforms = platforms;
	
	//in case it is used as a base station
	this_station.bus_stops = [];
	this_station.bus_front_tiles = [];
	this_station.serviced_cities = [];
	this_station.routes = [null, null];
	this_station.station_tile = top_left_tile;
	
	local is_terminus = false;
	local width = RAIL_STATION_PLATFORM_LENGTH + 2 * (platforms + 1);
	local height = platforms + 2;
	if(is_terminus)
		width -= platforms - 1;
	if(horz) {
		local temp = width;
		width = height;
		height = temp;
	}	
	AITile.DemolishTile(top_left_tile);
	AITile.DemolishTile(GetTileRelative(top_left_tile, width, height));
	Sign(GetTileRelative(top_left_tile, 0, 0), "Corner 1");
	Sign(GetTileRelative(top_left_tile, width, height), "Corner 2");
	local corner1 = top_left_tile;
	local corner2 = GetTileRelative(top_left_tile, width, height);
	local level_result = LevelLand(top_left_tile, GetTileRelative(top_left_tile, width, height));
	if(level_result == false) {
		LogManager.Log("Unable to level tiles for station", 4);
		return false;
	}
	
	
	//TODO: Set railtype that we're using, how does this change?
	local types = AIRailTypeList();
	local rail_type = types.Begin();
	if(rail_type != AIRail.GetCurrentRailType()) {
		LogManager.Log("Get money to Convert Rail Type", 4);
		GetMoney(60000);
		LogManager.Log("Converting Rail Type", 4);
		AIRail.ConvertRailType(AIMap.GetTileIndex(1,1), AIMap.GetTileIndex(AIMap.GetMapSizeX() - 2, AIMap.GetMapSizeY() - 2), rail_type);
		AIRail.SetCurrentRailType(rail_type);
	}
	local stationId = 0;
	if(horz) {
		LogManager.Log("Building regional, horizontal configuration", 4);
		
		//two directions since it is non-terminus
		this_station.station_dir = [dtp.NS_LINE, dtp.SN_LINE];
		
		//We shift the actual tile so that we have room for rails on both sides
		top_left_tile = GetTileRelative(top_left_tile, 2, platforms + 1);
		local top_right_tile = GetTileRelative(top_left_tile, 0, RAIL_STATION_PLATFORM_LENGTH);
		//so the station should actually line up to the top of the bounding box
		local success = AIRail.BuildRailStation(top_left_tile, AIRail.RAILTRACK_NW_SE, platforms, RAIL_STATION_PLATFORM_LENGTH, AIBaseStation.STATION_NEW);

		if(!success) {
			if(AIError.GetLastError() == AIError.ERR_LOCAL_AUTHORITY_REFUSES) {
				LogManager.Log("Town authority are being jerks, sending appeasement trees", 3);
				ImproveRating(AITile.GetClosestTown(top_left_tile), corner1, corner2);
				success = AIRail.BuildRailStation(top_left_tile, AIRail.RAILTRACK_NW_SE, platforms, RAIL_STATION_PLATFORM_LENGTH, AIBaseStation.STATION_NEW);
				if(!success) {
					LogManager.Log("Roll to save failed: " + AIError.GetLastErrorString(), 4);
					return false;
				}
			} else {
				LogManager.Log(AIError.GetLastErrorString(), 4);
				return false;
			}
		}
		
		stationId = AIStation.GetStationID(top_left_tile);
		
		
		
		//Build hookups and signals for each side
			local exit_tile = GetTileRelative(top_left_tile, left_bot_bool * platforms - left_bot_bool, -platforms - 1);
			local entry_tile = GetTileRelative(exit_tile, Neg1Bool(left_bot_bool), 0);
			
			//This is intentional
			this_station.exit_tile = entry_tile;
			this_station.exit_tile2 = GetTileRelative(entry_tile, 0, -1);
			this_station.enter_tile = exit_tile;
			this_station.enter_tile2 = GetTileRelative(exit_tile, 0, -1);
			
			//make sure we never block the track with roads
			ZooElite.off_limit_tiles.push(this_station.enter_tile2);
			ZooElite.off_limit_tiles.push(this_station.exit_tile2);
			ZooElite.off_limit_tiles.push(GetTileRelative(this_station.enter_tile2, 0, -1));
			ZooElite.off_limit_tiles.push(GetTileRelative(this_station.exit_tile2, 0, -1));
			

			
			//Build Entry and exit tiles
			AIRail.BuildRailTrack(exit_tile, AIRail.RAILTRACK_NW_SE);
			AIRail.BuildRailTrack(entry_tile, AIRail.RAILTRACK_NW_SE);
			if(left_bot_bool == 0) {
				AIRail.BuildSignal(exit_tile, GetTileRelative(exit_tile, 0, 1), AIRail.SIGNALTYPE_NORMAL);
				AIRail.BuildSignal(entry_tile, GetTileRelative(entry_tile, 0, -1), AIRail.SIGNALTYPE_PBS_ONEWAY);
			} else {
				AIRail.BuildSignal(entry_tile, GetTileRelative(entry_tile, 0, 1), AIRail.SIGNALTYPE_NORMAL);
				AIRail.BuildSignal(exit_tile, GetTileRelative(exit_tile, 0, -1), AIRail.SIGNALTYPE_PBS_ONEWAY);
			}
			
			for(local i = 1; i < platforms; i++) {
				AIRail.BuildRailTrack(GetTileRelative(exit_tile, 0, 1 * i), AIRail.RAILTRACK_NW_SE);
				AIRail.BuildRailTrack(GetTileRelative(entry_tile, 0, 1 * i), AIRail.RAILTRACK_NW_SE);
				for(local j = 0; j < platforms - i; j++) {
					AIRail.BuildRailTrack(GetTileRelative(exit_tile, Neg1Bool(left_bot_bool) * j,  1 * (i + j)), GetTrackDirection(AIRail.RAILTRACK_NW_SW, left_bot_bool));
					AIRail.BuildRailTrack(GetTileRelative(exit_tile, Neg1Bool(left_bot_bool) * j + Neg1Bool(left_bot_bool),  1 * (i + j)), GetTrackDirection(AIRail.RAILTRACK_NE_SE, left_bot_bool));
				}
				//Build platform rail and signal	
			}
			
			//Do the twist
			AIRail.BuildRailTrack(GetTileRelative(entry_tile, 0 , platforms - 1), GetTrackDirection(AIRail.RAILTRACK_NW_NE, left_bot_bool));
			AIRail.BuildRailTrack(GetTileRelative(exit_tile, 0, platforms -  1), GetTrackDirection(AIRail.RAILTRACK_SW_SE, left_bot_bool));
			
			for(local i = 0; i < platforms; i++) {
				AIRail.BuildRailTrack(GetTileRelative(exit_tile, Neg1Bool(left_bot_bool) * i, platforms), AIRail.RAILTRACK_NW_SE);
				AIRail.BuildSignal(GetTileRelative(exit_tile, Neg1Bool(left_bot_bool) * i, platforms), GetTileRelative(exit_tile, (1 - 2 * left_bot_bool) * i, platforms + 1), AIRail.SIGNALTYPE_PBS);
			}
			
			
		//Build Second side
			local entry_tile = GetTileRelative(top_right_tile, right_bot_bool * platforms - right_bot_bool, platforms);
			local exit_tile = GetTileRelative(entry_tile, Neg1Bool(right_bot_bool), 0);
			this_station.enter2_tile = entry_tile;
			this_station.enter2_tile2 = GetTileRelative(entry_tile, 0, 1);
			this_station.exit2_tile = exit_tile;
			this_station.exit2_tile2 = GetTileRelative(exit_tile, 0, 1);
			
			//make sure we never block the track with roads
			ZooElite.off_limit_tiles.push(this_station.enter2_tile2);
			ZooElite.off_limit_tiles.push(this_station.exit2_tile2);
			ZooElite.off_limit_tiles.push(GetTileRelative(this_station.enter2_tile2, 0, 1));
			ZooElite.off_limit_tiles.push(GetTileRelative(this_station.exit2_tile2, 0, 1));
			

			
			//Build Entry/Exit Tracks
			AIRail.BuildRailTrack(exit_tile, AIRail.RAILTRACK_NW_SE);
			AIRail.BuildRailTrack(entry_tile, AIRail.RAILTRACK_NW_SE);
			if(right_bot_bool == 0) {
				AIRail.BuildSignal(exit_tile, GetTileRelative(exit_tile, 0, -1), AIRail.SIGNALTYPE_NORMAL);
				AIRail.BuildSignal(entry_tile, GetTileRelative(entry_tile, 0, 1), AIRail.SIGNALTYPE_PBS_ONEWAY);
			} else {
				AIRail.BuildSignal(entry_tile, GetTileRelative(entry_tile, 0, -1), AIRail.SIGNALTYPE_NORMAL);
				AIRail.BuildSignal(exit_tile, GetTileRelative(exit_tile, 0, 1), AIRail.SIGNALTYPE_PBS_ONEWAY);
			}
			
			for(local i = 1; i < platforms; i++) {
				AIRail.BuildRailTrack(GetTileRelative(exit_tile, 0, -i), AIRail.RAILTRACK_NW_SE);
				AIRail.BuildRailTrack(GetTileRelative(entry_tile, 0, -i), AIRail.RAILTRACK_NW_SE);
				for(local j = 0; j < platforms - i; j++) {
					AIRail.BuildRailTrack(GetTileRelative(entry_tile, Neg1Bool(right_bot_bool) * j,  -1 * (i + j)), GetTrackDirection(AIRail.RAILTRACK_SW_SE, right_bot_bool));
					AIRail.BuildRailTrack(GetTileRelative(entry_tile, Neg1Bool(right_bot_bool) * j + Neg1Bool(right_bot_bool),  -1 * (i + j)), GetTrackDirection(AIRail.RAILTRACK_NW_NE, right_bot_bool));
				}
				//Build platform rail and signal	
			}
			
			//Do the twist
			
			AIRail.BuildRailTrack(GetTileRelative(entry_tile, 0, -platforms + 1), GetTrackDirection(AIRail.RAILTRACK_NW_SW, right_bot_bool));
			AIRail.BuildRailTrack(GetTileRelative(exit_tile, 0, -platforms + 1), GetTrackDirection(AIRail.RAILTRACK_NE_SE, right_bot_bool));
			
			for(local i = 0; i < platforms; i++) {
				AIRail.BuildRailTrack(GetTileRelative(entry_tile, Neg1Bool(right_bot_bool) * i, -platforms), AIRail.RAILTRACK_NW_SE);
				AIRail.BuildSignal(GetTileRelative(entry_tile, Neg1Bool(right_bot_bool) * i, -platforms), GetTileRelative(entry_tile, Neg1Bool(right_bot_bool) * i, -platforms - 1), AIRail.SIGNALTYPE_PBS);
			}
		
		//bus stop locations just incase we use this as a base station.	
		local build_tile = true;
		local start_tile = GetTileRelative(top_left_tile, -1, 0);
		for(local i = 0; i < RAIL_STATION_PLATFORM_LENGTH; i++) {
			local active_tile = GetTileRelative(start_tile, 0, i);
			local front_tile  = GetTileRelative(start_tile, -1, i);
			if(build_tile) {
				//success = AIRoad.BuildRoadStation(active_tile, front_tile, AIRoad.ROADVEHTYPE_BUS, stationId);
				//AIRoad.BuildRoad(active_tile, front_tile);
				build_tile = false;
				this_station.bus_front_tiles.push(front_tile);
				this_station.bus_stops.push(active_tile);
				//Sign(active_tile, "BS");
			} else {
				build_tile = true;
			}
			//AIRoad.BuildRoad(front_tile, GetTileRelative(start_tile, -1, i + 1));
		}
			
	} else {
		LogManager.Log("Building regional, vertical configuration", 4);
		//two directions since it is none terminus
		this_station.station_dir = [dtp.EW_LINE, dtp.WE_LINE];
		//We shift the actual tile so that we have room for rails on both sides
		top_left_tile = GetTileRelative(top_left_tile, platforms + 1, 0);
		local top_right_tile = GetTileRelative(top_left_tile, RAIL_STATION_PLATFORM_LENGTH, 0);
		//so the station should actually line up to the top of the bounding box
		local success = AIRail.BuildRailStation(top_left_tile, AIRail.RAILTRACK_NE_SW, platforms, RAIL_STATION_PLATFORM_LENGTH, AIBaseStation.STATION_NEW);

		if(!success) {
			if(AIError.GetLastError() == AIError.ERR_LOCAL_AUTHORITY_REFUSES) {
				LogManager.Log("Town authority are being jerks, sending appeasement trees", 3);
				//ImproveRating(AITile.GetClosestTown(top_left_tile), corner1, corner2);
				success = AIRail.BuildRailStation(top_left_tile, AIRail.RAILTRACK_NW_SE, platforms, RAIL_STATION_PLATFORM_LENGTH, AIBaseStation.STATION_NEW);
				if(!success) {
					LogManager.Log("Roll to save failed: " + AIError.GetLastErrorString(), 4);
					return false;
				}
			} else {
				LogManager.Log(AIError.GetLastErrorString(), 4);
				return false;
			}
		}
		stationId = AIStation.GetStationID(top_left_tile);
		
		
		//Build hookups and signals for each side
			local exit_tile = GetTileRelative(top_left_tile, -platforms - 1, left_bot_bool * platforms - left_bot_bool);
			local entry_tile = GetTileRelative(exit_tile, 0, Neg1Bool(left_bot_bool));
			this_station.enter_tile = entry_tile;
			this_station.enter_tile2 = GetTileRelative(entry_tile, -1, 0);
			this_station.exit_tile = exit_tile;
			this_station.exit_tile2 = GetTileRelative(exit_tile, -1, 0);
			
			//make sure we never block the track with roads
			ZooElite.off_limit_tiles.push(this_station.enter_tile2);
			ZooElite.off_limit_tiles.push(this_station.exit_tile2);
			ZooElite.off_limit_tiles.push(GetTileRelative(this_station.enter_tile2, -1, 0));
			ZooElite.off_limit_tiles.push(GetTileRelative(this_station.exit_tile2, -1, 0));
			

			
			//Build Entry and exit tiles
			Sign(exit_tile, "Exit Tile");
			AIRail.BuildRailTrack(exit_tile, AIRail.RAILTRACK_NE_SW);
			AIRail.BuildRailTrack(entry_tile, AIRail.RAILTRACK_NE_SW);
			if(left_bot_bool == 1) {
				AIRail.BuildSignal(exit_tile, GetTileRelative(exit_tile, 1, 0), AIRail.SIGNALTYPE_NORMAL);
				AIRail.BuildSignal(entry_tile, GetTileRelative(entry_tile, -1, 0), AIRail.SIGNALTYPE_PBS_ONEWAY);
			} else {
				AIRail.BuildSignal(entry_tile, GetTileRelative(entry_tile, 1, 0), AIRail.SIGNALTYPE_NORMAL);
				AIRail.BuildSignal(exit_tile, GetTileRelative(exit_tile, -1, 0), AIRail.SIGNALTYPE_PBS_ONEWAY);
			}
			
			//bus stop locations just incase we use this as a base station.	
			local build_tile = true;
			local start_tile = GetTileRelative(top_left_tile, -1, 2);
			for(local i = 1; i < platforms; i++) {
				AIRail.BuildRailTrack(GetTileRelative(exit_tile, 1 * i, 0), AIRail.RAILTRACK_NE_SW);
				AIRail.BuildRailTrack(GetTileRelative(entry_tile, 1 * i, 0), AIRail.RAILTRACK_NE_SW);
				for(local j = 0; j < platforms - i; j++) {
					AIRail.BuildRailTrack(GetTileRelative(exit_tile, 1 * (i + j), Neg1Bool(left_bot_bool) * j - left_bot_bool), GetTrackDirection(AIRail.RAILTRACK_NE_SE, left_bot_bool));
					AIRail.BuildRailTrack(GetTileRelative(exit_tile, 1 * (i + j), Neg1Bool(left_bot_bool) * j + 1 -left_bot_bool), GetTrackDirection(AIRail.RAILTRACK_NW_SW, left_bot_bool));
				}
				//Build platform rail and signal	
			}
			
			//Do the twist
			if(left_bot_bool == 1) {
				AIRail.BuildRailTrack(GetTileRelative(entry_tile, platforms - 1, 0), AIRail.RAILTRACK_NE_SE);
				AIRail.BuildRailTrack(GetTileRelative(exit_tile, platforms -  1, 0), AIRail.RAILTRACK_NW_SW);
			} else {
				AIRail.BuildRailTrack(GetTileRelative(entry_tile, platforms - 1, 0), GetTrackDirection(AIRail.RAILTRACK_NW_NE, left_bot_bool));
				AIRail.BuildRailTrack(GetTileRelative(exit_tile, platforms -  1, 0), GetTrackDirection(AIRail.RAILTRACK_SW_SE, left_bot_bool));
			}
			
			for(local i = 0; i < platforms; i++) {
				AIRail.BuildRailTrack(GetTileRelative(exit_tile, platforms, Neg1Bool(left_bot_bool) * i), AIRail.RAILTRACK_NE_SW);
				AIRail.BuildSignal(GetTileRelative(exit_tile, platforms, Neg1Bool(left_bot_bool) * i), GetTileRelative(exit_tile, platforms + 1, Neg1Bool(left_bot_bool) * i), AIRail.SIGNALTYPE_PBS);
			}
			
			
		//Build Second side
			local entry_tile = GetTileRelative(top_right_tile, platforms, right_bot_bool * platforms - right_bot_bool);
			local exit_tile = GetTileRelative(entry_tile, 0, Neg1Bool(right_bot_bool));
			this_station.enter2_tile = entry_tile;
			this_station.enter2_tile2 = GetTileRelative(entry_tile, 1, 0);
			this_station.exit2_tile = exit_tile;
			this_station.exit2_tile2 = GetTileRelative(exit_tile, 1, 0);
			
			//make sure we never block the track with roads
			ZooElite.off_limit_tiles.push(this_station.enter2_tile2);
			ZooElite.off_limit_tiles.push(this_station.exit2_tile2);
			ZooElite.off_limit_tiles.push(GetTileRelative(this_station.enter2_tile2, 1, 0));
			ZooElite.off_limit_tiles.push(GetTileRelative(this_station.exit2_tile2, 1, 0));
			
			
			//Build Entry/Exit Tracks
			AIRail.BuildRailTrack(exit_tile, AIRail.RAILTRACK_NE_SW);
			AIRail.BuildRailTrack(entry_tile, AIRail.RAILTRACK_NE_SW);
			if(right_bot_bool == 1) {
				AIRail.BuildSignal(exit_tile, GetTileRelative(exit_tile, -1, 0), AIRail.SIGNALTYPE_NORMAL);
				AIRail.BuildSignal(entry_tile, GetTileRelative(entry_tile, 1, 0), AIRail.SIGNALTYPE_PBS_ONEWAY);
			} else {
				AIRail.BuildSignal(entry_tile, GetTileRelative(entry_tile, -1, 0), AIRail.SIGNALTYPE_NORMAL);
				AIRail.BuildSignal(exit_tile, GetTileRelative(exit_tile, 1, 0), AIRail.SIGNALTYPE_PBS_ONEWAY);
			}
			
			for(local i = 1; i < platforms; i++) {
				AIRail.BuildRailTrack(GetTileRelative(exit_tile, -i, 0), AIRail.RAILTRACK_NE_SW);
				AIRail.BuildRailTrack(GetTileRelative(entry_tile, -i, 0), AIRail.RAILTRACK_NE_SW);
				for(local j = 0; j < platforms - i; j++) {
					AIRail.BuildRailTrack(GetTileRelative(entry_tile, -1 * (i + j), Neg1Bool(right_bot_bool) * j + 1 - right_bot_bool), GetTrackDirection(AIRail.RAILTRACK_NW_NE, right_bot_bool));
					AIRail.BuildRailTrack(GetTileRelative(entry_tile, -1 * (i + j), Neg1Bool(right_bot_bool) * j - right_bot_bool), GetTrackDirection(AIRail.RAILTRACK_SW_SE, right_bot_bool));
				}
				//Build platform rail and signal	
			}
			
			//Do the twist
			if(right_bot_bool == 1) {
				AIRail.BuildRailTrack(GetTileRelative(entry_tile, -platforms + 1, 0), GetTrackDirection(AIRail.RAILTRACK_NW_SW, right_bot_bool));
				AIRail.BuildRailTrack(GetTileRelative(exit_tile, -platforms + 1, 0), GetTrackDirection(AIRail.RAILTRACK_NE_SE, right_bot_bool));
			} else {
				AIRail.BuildRailTrack(GetTileRelative(entry_tile, -platforms + 1, 0), AIRail.RAILTRACK_NE_SE);
				AIRail.BuildRailTrack(GetTileRelative(exit_tile, -platforms + 1, 0), AIRail.RAILTRACK_NW_SW);	
			}
			
			for(local i = 0; i < platforms; i++) {
				AIRail.BuildRailTrack(GetTileRelative(entry_tile, -platforms, Neg1Bool(right_bot_bool) * i), AIRail.RAILTRACK_NE_SW);
				AIRail.BuildSignal(GetTileRelative(entry_tile, -platforms, Neg1Bool(right_bot_bool) * i), GetTileRelative(entry_tile, -platforms - 1, Neg1Bool(right_bot_bool) * i), AIRail.SIGNALTYPE_PBS);
			}
		
		//in case we want bus stops
		local build_tile = true;
		local start_tile = GetTileRelative(top_left_tile, 0, platforms);
		for(local i = 0; i < RAIL_STATION_PLATFORM_LENGTH; i++) {
			local active_tile = GetTileRelative(start_tile, i, 0);
			local front_tile  = GetTileRelative(start_tile, i, 1);
			if(build_tile) {
				//success = AIRoad.BuildRoadStation(active_tile, front_tile, AIRoad.ROADVEHTYPE_BUS, stationId);
				//AIRoad.BuildRoad(active_tile, front_tile);
				build_tile = false;
				this_station.bus_front_tiles.push(front_tile);
				this_station.bus_stops.push(active_tile);
				//Sign(active_tile, "BS");
			} else {
				build_tile = true;
			}
			//AIRoad.BuildRoad(front_tile, GetTileRelative(start_tile, i + 1, 1));
		}
	}
	this_station.stationId = stationId;
	station_table[stationId] <- this_station;
	return stationId;
	
}

//Some Helper stuff
function GetTrackDirection(dir, rot) {
	if(rot == 0)
		return dir;
	switch (dir) {
		case AIRail.RAILTRACK_NW_SE: return AIRail.RAILTRACK_NW_SE;
		case AIRail.RAILTRACK_NW_SW: return AIRail.RAILTRACK_NW_NE;
		case AIRail.RAILTRACK_NE_SE: return AIRail.RAILTRACK_SW_SE;
		case AIRail.RAILTRACK_SW_SE: return AIRail.RAILTRACK_NE_SE;
		case AIRail.RAILTRACK_NW_NE: return AIRail.RAILTRACK_NW_SW;	
	}	
}

function Neg1Bool(aBool) {
	return (1 - 2 * aBool);
}

function Pos1Bool(aBool) {
	return (-1 + 2 * aBool);
}

//Build normal city train station.
//This is a terminus which will have bus stops attached to townId
function ZooElite::BuildTrainStation(townId, top_left_tile, platforms, is_terminus, horz, shift) {
	local dtp = ai_instance.dtp;
	//Create the object to store data on
	local this_station = Station();
	this_station.platforms = platforms;
	this_station.bus_stops = [];
	this_station.bus_front_tiles = [];
	this_station.serviced_cities = [];
	this_station.routes = [null, null];

	//Let's level it quick
	local width = RAIL_STATION_PLATFORM_LENGTH + (2 * platforms);
	local height = 3 + platforms;
	if(is_terminus)
		width -= platforms - 2;
	if(horz) {
		local temp = width;
		width = height;
		height = temp;
	}
	AITile.DemolishTile(top_left_tile);
	AITile.DemolishTile(GetTileRelative(top_left_tile, width + 1, height + 1));
	
	
	Sign(GetTileRelative(top_left_tile, 0, 0), "Corner 1");
	Sign(GetTileRelative(top_left_tile, width, height), "Corner 2");
	
	AITile.LevelTiles(top_left_tile, GetTileRelative(top_left_tile, width + 1, height + 1));
	
	//TODO: Set railtype that we're using, how does this change?
	//local types = AIRailTypeList();
	//AIRail.SetCurrentRailType(types.Begin());

	
	//TODO: We only handle terminuses at this point
	//Determine if top_left_tile is towards the city or not
	if(AIMap.DistanceManhattan(AITown.GetLocation(townId), top_left_tile) > AIMap.DistanceManhattan(AITown.GetLocation(townId), GetTileRelative(top_left_tile, width, height))) {
		//Shoot, it's backwards, we'll get around to this later	
		//I think this is somewhere else already?
	}
	
	local stationId = 0;
	
	if(horz && !shift) {
		LogManager.Log("Building normal, horizontal configuration", 4);
		this_station.station_dir = [dtp.SN_LINE];
		//We shift the actual tile so that we have room for the bus stations
		top_left_tile = GetTileRelative(top_left_tile, 2, 0);
		
		local success = AIRail.BuildRailStation(GetTileRelative(top_left_tile, 0, 2), AIRail.RAILTRACK_NW_SE, platforms, RAIL_STATION_PLATFORM_LENGTH, AIBaseStation.STATION_NEW);

		if(!success) {
			if(AIError.GetLastError() == AIError.ERR_LOCAL_AUTHORITY_REFUSES) {
				LogManager.Log("Town authority are being jerks, sending appeasement trees", 3);
				ImproveRating(AITile.GetClosestTown(top_left_tile), corner1, corner2);
				success = AIRail.BuildRailStation(top_left_tile, AIRail.RAILTRACK_NW_SE, platforms, RAIL_STATION_PLATFORM_LENGTH, AIBaseStation.STATION_NEW);
				if(!success) {
					LogManager.Log("Roll to save failed: " + AIError.GetLastErrorString(), 4);
					return false;
				}
			} else {
				LogManager.Log(AIError.GetLastErrorString(), 4);
				return false;
			}
		}
		
		stationId = AIStation.GetStationID(GetTileRelative(top_left_tile, 0, 2));
		this_station.stationId = stationId;
		
		local turn_tile = GetTileRelative(top_left_tile, platforms, 0);
		AIRail.BuildRailTrack(turn_tile, AIRail.RAILTRACK_NE_SE);
		AIRail.BuildSignal(turn_tile, GetTileRelative(turn_tile, -1, 0), AIRail.SIGNALTYPE_NORMAL);
		
		//The next two things build the loop around back...only for terminus
		if(is_terminus) {
			for(local i = 0; i < platforms; i++) {
				local tile = GetTileRelative(top_left_tile, i, 0);
				AIRail.BuildRailTrack(tile, AIRail.RAILTRACK_SW_SE);
				AIRail.BuildRailTrack(GetTileRelative(top_left_tile, i, 1), AIRail.RAILTRACK_NW_SE);
				AIRail.BuildSignal(GetTileRelative(top_left_tile, i, 1), GetTileRelative(top_left_tile, i, 2), AIRail.SIGNALTYPE_PBS);
			}
			for(local i = 1; i < platforms; i++) {
				local tile = GetTileRelative(top_left_tile, i, 0);
				AIRail.BuildRailTrack(tile, AIRail.RAILTRACK_NE_SW);
			}		
			local signal_tile = false;
			local exit_tile = turn_tile;
			for(local i = 1; i <= RAIL_STATION_PLATFORM_LENGTH + platforms + 1; i++) {
				local tile = GetTileRelative(turn_tile, 0, i);
				AIRail.BuildRailTrack(tile, AIRail.RAILTRACK_NW_SE);
				if(!signal_tile) {
					signal_tile = true;
				} else {
					AIRail.BuildSignal(tile, GetTileRelative(tile, 0, -1), AIRail.SIGNALTYPE_NORMAL);
					signal_tile = false;
				}
				exit_tile = tile;
			}
			this_station.exit_tile = exit_tile;
			this_station.exit_tile2 = GetTileRelative(exit_tile, 0, 1);
			
			//Exit is now properly built, build entrances
			local entry_tile = GetTileRelative(exit_tile, -1, 0);
			this_station.enter_tile = entry_tile;
			this_station.enter_tile2 = GetTileRelative(entry_tile, 0, 1);
			AIRail.BuildRailTrack(entry_tile, AIRail.RAILTRACK_NW_SE);
			AIRail.BuildSignal(entry_tile, GetTileRelative(entry_tile, 0, 1), AIRail.SIGNALTYPE_PBS_ONEWAY);
			for(local i = 1; i < platforms; i++) {
				AIRail.BuildRailTrack(GetTileRelative(entry_tile, 0, -1 * i), AIRail.RAILTRACK_NW_SE);
				for(local j = 0; j < platforms - i; j++) {
					AIRail.BuildRailTrack(GetTileRelative(entry_tile, -1 * j,  -1 * (i + j)), AIRail.RAILTRACK_NE_SE);
					AIRail.BuildRailTrack(GetTileRelative(entry_tile, -1 * j - 1,  -1 * (i + j)), AIRail.RAILTRACK_NW_SW);
				}	
			}
		}
		
		local build_tile = true;
		local start_tile = GetTileRelative(top_left_tile, -1, 2);
		for(local i = 0; i < RAIL_STATION_PLATFORM_LENGTH; i++) {
			local active_tile = GetTileRelative(start_tile, 0, i);
			local front_tile  = GetTileRelative(start_tile, -1, i);
			if(build_tile) {
				//success = AIRoad.BuildRoadStation(active_tile, front_tile, AIRoad.ROADVEHTYPE_BUS, stationId);
				//AIRoad.BuildRoad(active_tile, front_tile);
				build_tile = false;
				this_station.bus_front_tiles.push(front_tile);
				this_station.bus_stops.push(active_tile);
			} else {
				build_tile = true;
			}
			//AIRoad.BuildRoad(front_tile, GetTileRelative(start_tile, -1, i + 1));
		}
		this_station.serviced_cities.push(townId);
		
	} else if (horz && shift) {
		LogManager.Log("Building flipped, horizontal configuration", 4);
		this_station.station_dir = [dtp.NS_LINE];
		//This is tough because we literally want to spin the entire station 180 degrees
		local bot_right = GetTileRelative(top_left_tile, width, height);
		
		//We shift the actual tile so that we have room for the bus stations
		bot_right = GetTileRelative(bot_right, -2, 0);
		
		local success = AIRail.BuildRailStation(GetTileRelative(bot_right, -1 * platforms, -RAIL_STATION_PLATFORM_LENGTH - 1), AIRail.RAILTRACK_NW_SE, platforms, RAIL_STATION_PLATFORM_LENGTH, AIBaseStation.STATION_NEW);
		LogManager.Log(AIError.GetLastErrorString(), 4);
		if(!success) {
			if(AIError.GetLastError() == AIError.ERR_LOCAL_AUTHORITY_REFUSES) {
				LogManager.Log("Town authority are being jerks, sending appeasement trees", 3);
				ImproveRating(AITile.GetClosestTown(top_left_tile), corner1, corner2);
				success = AIRail.BuildRailStation(top_left_tile, AIRail.RAILTRACK_NW_SE, platforms, RAIL_STATION_PLATFORM_LENGTH, AIBaseStation.STATION_NEW);
				if(!success) {
					LogManager.Log("Roll to save failed: " + AIError.GetLastErrorString(), 4);
					return false;
				}
			} else {
				LogManager.Log(AIError.GetLastErrorString(), 4);
				return false;
			}
		}
		stationId = AIStation.GetStationID(GetTileRelative(bot_right, -1 * platforms, -RAIL_STATION_PLATFORM_LENGTH - 1));
		
		local turn_tile = GetTileRelative(bot_right, -1 * platforms - 1, 0);
		AIRail.BuildRailTrack(turn_tile, AIRail.RAILTRACK_NW_SW);
		AIRail.BuildSignal(turn_tile, GetTileRelative(turn_tile, 1, 0), AIRail.SIGNALTYPE_NORMAL);
		for(local i = 0; i < platforms; i++) {
			local tile = GetTileRelative(bot_right, -i - 1, 0);
			AIRail.BuildRailTrack(tile, AIRail.RAILTRACK_NW_NE);
			AIRail.BuildRailTrack(GetTileRelative(bot_right, -i - 1, -1), AIRail.RAILTRACK_NW_SE);
			AIRail.BuildSignal(GetTileRelative(bot_right, -i - 1, -1), GetTileRelative(bot_right, -i - 1, -2), AIRail.SIGNALTYPE_PBS);
		}
		for(local i = 1; i < platforms; i++) {
			local tile = GetTileRelative(bot_right, -i - 1, 0);
			AIRail.BuildRailTrack(tile, AIRail.RAILTRACK_NE_SW);
		}
		
		local signal_tile = false;
		local exit_tile = turn_tile;
		for(local i = 1; i <= RAIL_STATION_PLATFORM_LENGTH + platforms + 1; i++) {
			local tile = GetTileRelative(turn_tile, 0, -i);
			AIRail.BuildRailTrack(tile, AIRail.RAILTRACK_NW_SE);
			if(!signal_tile) {
				signal_tile = true;
			} else {
				AIRail.BuildSignal(tile, GetTileRelative(tile, 0, 1), AIRail.SIGNALTYPE_NORMAL);
				signal_tile = false;
			}
			exit_tile = tile;
		}
		
		
		//Exit is now properly built, build entrances
		local entry_tile = GetTileRelative(exit_tile, 1, 0);
		AIRail.BuildRailTrack(entry_tile, AIRail.RAILTRACK_NW_SE);
		AIRail.BuildSignal(entry_tile, GetTileRelative(entry_tile, 0, -1), AIRail.SIGNALTYPE_PBS_ONEWAY);
		for(local i = 1; i < platforms; i++) {
			AIRail.BuildRailTrack(GetTileRelative(entry_tile, 0, 1 * i), AIRail.RAILTRACK_NW_SE);
			for(local j = 0; j < platforms - i; j++) {
				AIRail.BuildRailTrack(GetTileRelative(entry_tile, j, (i + j)), AIRail.RAILTRACK_NW_SW);
				AIRail.BuildRailTrack(GetTileRelative(entry_tile, j + 1, (i + j)), AIRail.RAILTRACK_NE_SE);
			}	
		}
		
		local build_tile = true;
		local start_tile = GetTileRelative(bot_right, 0, -2);
		for(local i = 0; i < RAIL_STATION_PLATFORM_LENGTH; i++) {
			local active_tile = GetTileRelative(start_tile, 0, -i);
			local front_tile  = GetTileRelative(start_tile, 1, -i);
			if(build_tile) {
				//success = AIRoad.BuildRoadStation(active_tile, front_tile, AIRoad.ROADVEHTYPE_BUS, stationId);
				//AIRoad.BuildRoad(active_tile, front_tile);
				build_tile = false;
				this_station.bus_front_tiles.push(front_tile);
				this_station.bus_stops.push(active_tile);
			} else {
				build_tile = true;
			}
			//AIRoad.BuildRoad(front_tile, GetTileRelative(start_tile, 1, -i - 1));
		}
		
		this_station.exit_tile = exit_tile;
		this_station.enter_tile = entry_tile;
		this_station.exit_tile2 = GetTileRelative(exit_tile, 0, -1);
		this_station.enter_tile2 = GetTileRelative(entry_tile, 0, -1);
		this_station.stationId = stationId;
		this_station.serviced_cities.push(townId);
		
	} else if(!horz && !shift) {
		LogManager.Log("Building normal, vertical configuration", 4);
		this_station.station_dir = [dtp.WE_LINE];
		local bot_right = GetTileRelative(top_left_tile, width, height);
		local success = AIRail.BuildRailStation(GetTileRelative(top_left_tile, 2, 1), AIRail.RAILTRACK_NE_SW, platforms, RAIL_STATION_PLATFORM_LENGTH, AIBaseStation.STATION_NEW);
		if(!success) {
			if(AIError.GetLastError() == AIError.ERR_LOCAL_AUTHORITY_REFUSES) {
				LogManager.Log("Town authority are being jerks, sending appeasement trees", 3);
				ImproveRating(AITile.GetClosestTown(top_left_tile), corner1, corner2);
				success = AIRail.BuildRailStation(top_left_tile, AIRail.RAILTRACK_NW_SE, platforms, RAIL_STATION_PLATFORM_LENGTH, AIBaseStation.STATION_NEW);
				if(!success) {
					LogManager.Log("Roll to save failed: " + AIError.GetLastErrorString(), 4);
					return false;
				}
			} else {
				LogManager.Log(AIError.GetLastErrorString(), 4);
				return false;
			}
		}
		stationId = AIStation.GetStationID(GetTileRelative(top_left_tile, 2, 1));
		//Build rail around
		AIRail.BuildRailTrack(top_left_tile, AIRail.RAILTRACK_SW_SE);
		AIRail.BuildSignal(top_left_tile, GetTileRelative(top_left_tile, 0, 1), AIRail.SIGNALTYPE_NORMAL);
		local turn_tile = top_left_tile;
		
		for(local i = 1; i <= platforms; i++) {
			local tile = GetTileRelative(top_left_tile, 0, i);
			AIRail.BuildRailTrack(tile, AIRail.RAILTRACK_NW_SW);
			AIRail.BuildRailTrack(GetTileRelative(top_left_tile, 1, i), AIRail.RAILTRACK_NE_SW);
			AIRail.BuildSignal(GetTileRelative(top_left_tile, 1, i), GetTileRelative(top_left_tile, 2, i), AIRail.SIGNALTYPE_PBS);
		}
		for(local i = 1; i < platforms; i++) {
			local tile = GetTileRelative(top_left_tile, 0, i);
			AIRail.BuildRailTrack(tile, AIRail.RAILTRACK_NW_SE);
		}
		
		local signal_tile = false;
		local exit_tile = turn_tile;
		for(local i = 1; i <= RAIL_STATION_PLATFORM_LENGTH + platforms + 1; i++) {
			local tile = GetTileRelative(turn_tile, i, 0);
			AIRail.BuildRailTrack(tile, AIRail.RAILTRACK_NE_SW);
			if(!signal_tile) {
				signal_tile = true;
			} else {
				AIRail.BuildSignal(tile, GetTileRelative(tile, -1, 0), AIRail.SIGNALTYPE_NORMAL);
				signal_tile = false;
			}
			exit_tile = tile;
		}
		
		//Exit is now properly built, build entrances
		local entry_tile = GetTileRelative(exit_tile, 0, 1);
		AIRail.BuildRailTrack(entry_tile, AIRail.RAILTRACK_NE_SW);
		AIRail.BuildSignal(entry_tile, GetTileRelative(entry_tile, 1, 0), AIRail.SIGNALTYPE_PBS_ONEWAY);
		for(local i = 1; i < platforms; i++) {
			AIRail.BuildRailTrack(GetTileRelative(entry_tile, -1 * i, 0), AIRail.RAILTRACK_NE_SW);
			for(local j = 0; j < platforms - i; j++) {
				AIRail.BuildRailTrack(GetTileRelative(entry_tile, -1 * (i + j), 1 * j), AIRail.RAILTRACK_SW_SE);
				AIRail.BuildRailTrack(GetTileRelative(entry_tile,  -1 * (i + j), 1 * j + 1), AIRail.RAILTRACK_NW_NE);
			}	
		}
		
		local build_tile = true;
		local start_tile = GetTileRelative(top_left_tile, 2, platforms + 1);
		for(local i = 0; i < RAIL_STATION_PLATFORM_LENGTH; i++) {
			local active_tile = GetTileRelative(start_tile, i, 0);
			local front_tile  = GetTileRelative(start_tile, i, 1);
			if(build_tile) {
				//success = AIRoad.BuildRoadStation(active_tile, front_tile, AIRoad.ROADVEHTYPE_BUS, stationId);
				//AIRoad.BuildRoad(active_tile, front_tile);
				build_tile = false;
				this_station.bus_front_tiles.push(front_tile);
				this_station.bus_stops.push(active_tile);
			} else {
				build_tile = true;
			}
			//AIRoad.BuildRoad(front_tile, GetTileRelative(start_tile, i + 1, 1));
		}
		
		this_station.exit_tile = exit_tile;
		this_station.enter_tile = entry_tile;
		this_station.exit_tile2 = GetTileRelative(exit_tile, 1, 0);
		this_station.enter_tile2 = GetTileRelative(entry_tile, 1, 0);
		this_station.stationId = stationId;
		this_station.serviced_cities.push(townId);
		
	} else if(!horz && shift) {
		LogManager.Log("Building flipped, vertical configuration", 4);
		this_station.station_dir = [dtp.EW_LINE];
		local bot_right = GetTileRelative(top_left_tile, width, height);
		local success = AIRail.BuildRailStation(GetTileRelative(bot_right, -1 * RAIL_STATION_PLATFORM_LENGTH - 1, -1 * platforms), AIRail.RAILTRACK_NE_SW, platforms, RAIL_STATION_PLATFORM_LENGTH, AIBaseStation.STATION_NEW);
		if(!success) {
			if(AIError.GetLastError() == AIError.ERR_LOCAL_AUTHORITY_REFUSES) {
				LogManager.Log("Town authority are being jerks, sending appeasement trees", 3);
				ImproveRating(AITile.GetClosestTown(top_left_tile), corner1, corner2);
				success = AIRail.BuildRailStation(top_left_tile, AIRail.RAILTRACK_NW_SE, platforms, RAIL_STATION_PLATFORM_LENGTH, AIBaseStation.STATION_NEW);
				if(!success) {
					LogManager.Log("Roll to save failed: " + AIError.GetLastErrorString(), 4);
					return false;
				}
			} else {
				LogManager.Log(AIError.GetLastErrorString(), 4);
				return false;
			}
		}
		stationId = AIStation.GetStationID(GetTileRelative(bot_right, -1 * RAIL_STATION_PLATFORM_LENGTH - 1, -1 * platforms));
		//Build rail around
		AIRail.BuildRailTrack(bot_right, AIRail.RAILTRACK_NW_NE);
		AIRail.BuildSignal(bot_right, GetTileRelative(bot_right, -1, 0), AIRail.SIGNALTYPE_NORMAL);
		local turn_tile = bot_right;
		
		for(local i = 1; i <= platforms; i++) {
			local tile = GetTileRelative(bot_right, 0, -i);
			AIRail.BuildRailTrack(tile, AIRail.RAILTRACK_NE_SE);
			AIRail.BuildRailTrack(GetTileRelative(bot_right, -1, -i), AIRail.RAILTRACK_NE_SW);
			AIRail.BuildSignal(GetTileRelative(bot_right, -1, -i), GetTileRelative(bot_right, -2, -i), AIRail.SIGNALTYPE_PBS);
		}
		for(local i = 1; i < platforms; i++) {
			local tile = GetTileRelative(bot_right, 0, -i);
			AIRail.BuildRailTrack(tile, AIRail.RAILTRACK_NW_SE);
		}
		
		local signal_tile = false;
		local exit_tile = turn_tile;
		for(local i = 1; i <= RAIL_STATION_PLATFORM_LENGTH + platforms + 1; i++) {
			local tile = GetTileRelative(turn_tile, -i, 0);
			AIRail.BuildRailTrack(tile, AIRail.RAILTRACK_NE_SW);
			if(!signal_tile) {
				signal_tile = true;
			} else {
				AIRail.BuildSignal(tile, GetTileRelative(tile, 1, 0), AIRail.SIGNALTYPE_NORMAL);
				signal_tile = false;
			}
			exit_tile = tile;
		}
		
		//Exit is now properly built, build entrances
		local entry_tile = GetTileRelative(exit_tile, 0, -1);
		AIRail.BuildRailTrack(entry_tile, AIRail.RAILTRACK_NE_SW);
		AIRail.BuildSignal(entry_tile, GetTileRelative(entry_tile, -1, 0), AIRail.SIGNALTYPE_PBS_ONEWAY);
		for(local i = 1; i < platforms; i++) {
			AIRail.BuildRailTrack(GetTileRelative(entry_tile, i, 0), AIRail.RAILTRACK_NE_SW);
			for(local j = 0; j < platforms - i; j++) {
				AIRail.BuildRailTrack(GetTileRelative(entry_tile, (i + j), -1 * j), AIRail.RAILTRACK_NW_NE);
				AIRail.BuildRailTrack(GetTileRelative(entry_tile, (i + j), -1 * j - 1), AIRail.RAILTRACK_SW_SE);
			}	
		}
		local build_tile = true;
		local start_tile = GetTileRelative(bot_right, -2, -platforms - 1);
		for(local i = 0; i < RAIL_STATION_PLATFORM_LENGTH; i++) {
			local active_tile = GetTileRelative(start_tile, -i, 0);
			local front_tile  = GetTileRelative(start_tile, -i, -1);
			if(build_tile) {
				//success = AIRoad.BuildRoadStation(active_tile, front_tile, AIRoad.ROADVEHTYPE_BUS, stationId);
				//AIRoad.BuildRoad(active_tile, front_tile);
				this_station.bus_front_tiles.push(front_tile);
				build_tile = false;
				this_station.bus_stops.push(active_tile);
			} else {
				build_tile = true;
			}
			//AIRoad.BuildRoad(front_tile, GetTileRelative(start_tile, -i - 1, -1));
		}
		this_station.exit_tile = exit_tile;
		this_station.enter_tile = entry_tile;
		this_station.exit_tile2 = GetTileRelative(exit_tile, -1, 0);
		this_station.enter_tile2 = GetTileRelative(entry_tile, -1, 0);
		this_station.stationId = stationId;
		this_station.serviced_cities.push(townId);
	}
	
	station_table[stationId] <- this_station;
	town_table[townId].rail_station_id = stationId;
	return stationId;
	
}


function ZooElite::BuildBaseStation(towns, top_left_tile, is_terminus) {
	local center_tile = AIMap.GetTileIndex(AIMap.GetMapSizeX() / 2, AIMap.GetMapSizeY() / 2);
	//////////////////////////////
	//make sure we have enough money to build
	local balance = AICompany.GetBankBalance(AICompany.ResolveCompanyID(AICompany.COMPANY_SELF));
	while(balance < 50000) {
		LogManager.Log("Cash Low", 4);
			if(AICompany.GetLoanAmount() + AICompany.GetLoanInterval() <= AICompany.GetMaxLoanAmount()) {
				AICompany.SetLoanAmount(AICompany.GetLoanAmount() + AICompany.GetLoanInterval());
				//loaned++;
			}
			else {
				ZooElite.Sleep(500);
				LogManager.Log("Wait for cash to build bus roads", 4);
			}
		balance = AICompany.GetBankBalance(AICompany.ResolveCompanyID(AICompany.COMPANY_SELF));
	}
	local baseStation = ZooElite.BuildRailStationForTown(towns.Begin(), top_left_tile, center_tile, 4, is_terminus);
	//////////////////////////
		
	if(baseStation != false) {
		//LogManager.Log("should be building bus stops", 4);
		local bus_stop_success = station_table[baseStation].buildBusStops();
		if(bus_stop_success == false) {
			LogManager.Log("Station failed due to bus stops", 4);
			return false;
		}
	}
	return baseStation;
}
//Connnect a station to all the towns in a base region with busses
function ZooElite::ConnectBaseRegion(baseRegion) {
	local baseStation = baseRegion[2];
	local towns = baseRegion[1];
	
	if(baseStation == false) {
		LogManager.Log("Base Station Failed!", 4);
		return false;
	}
	
	//local firstIter = true;
	towns.Valuate(AITown.GetPopulation);
	towns.Sort(AIAbstractList.SORT_BY_VALUE, false);
	foreach(town, townIndex in towns) {
		
		if(AITown.GetPopulation(town) < 150) {
			LogManager.Log("skipping town " + AITown.GetName(town) + "cause its to small", 4);
			continue;
		}
		
		LogManager.Log("attempting to connect to base station " + baseStation, 4);
		
		GetMoney(50000);
		local success = station_table[baseStation].connectStopsToTown(town);
		if(!success) {
			continue;
		}
		//}
		//road_tester = null;
		//AICompany.SetLoanAmount(AICompany.GetLoanAmount() + 50000*loaned);
		station_table[baseStation].connectStopsToTown(town);
		
		town_table[town].rail_station_id = baseStation;
		station_table[baseStation].serviced_cities.push(town);

		//First build a center station, then additional ones...more efficent
		/*local station_tester = AITestMode();
		local loaned = 0;
		ZooElite.BuildMaxBusStationsInTown(town, 1);
		ZooElite.BuildMaxBusStationsInTown(town, 3);
		ZooElite.BuildDepotForTown(town);*/
		GetMoney(50000);
		
		local town_servicable = ZooElite.BuildMaxBusStationsInTown(town, 1);
		if(!town_servicable) {
			//TODO: We need to place this back on the stack to be developed later once it grows
			return baseStation;	
		}
		ZooElite.BuildMaxBusStationsInTown(town, 3);
		ZooElite.BuildDepotForTown(town);
		
		

		//possible cash management?
		GetMoney(50000);
		ZooElite.AdjustBusesInTown(town);
		added_towns.append(town);
	}
		
	return baseStation;
}
//Check if this tile could be valid...valid means that the tile must be buildable and ALL tiles around it must be too
//TODO: Note that in the future we could ease this restriction
function ZooElite::GetBuildableTilesAround(tileid) {
	if(!AITile.IsBuildable(tileid)) {
		return 0;
	}
	local tilelist = GetNeighbours8(tileid);
	tilelist.Valuate(AITile.IsBuildable);
	tilelist.RemoveValue(0);
	return tilelist.Count();
}

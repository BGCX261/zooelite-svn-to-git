class CustomPathFinder extends RoadPathFinder {   
	function InitializePath(sources, goals, ignored_tiles) {      
		local nsources = [];      
		foreach (node in sources) {        
			nsources.push([node, 0xFF]);      
		}      
		this._pathfinder.InitializePath(nsources, goals, ignored_tiles);   
	}
}

//Builds at most -max- more stations in the given town
//returns an array of stations built
function ZooElite::BuildMaxBusStationsInTown(town, max) {
	
	//Limit the number of station to max or some other number we invent
	local pop = AITown.GetPopulation(town);
	pop = Floor(pop / 250);
	if(pop < 1)
		pop = 1;
	LogManager.Log("Limiting to " + pop + " stations", 2);
	local array = [];
	if(max < 1)
		array = ZooElite.FindPlacesInTownForMaxNMoreBusStations(town, pop);
	else
		array = ZooElite.FindPlacesInTownForMaxNMoreBusStations(town, max);
		
	//Something went wrong
	if(array == false)
		return false;
		
	//Sort each list of tiles based on how many passengers each list would pull
	local testmode = AITestMode();
	local failed = [7];
	array.sort(custom_compare);
	local max_list = [];
	while(failed.len() != 0 && array.len() > 0) {
		 max_list = array.top();
		failed = ZooElite.BuildBusStationList(max_list);
		if(failed.len() == 0) {
			//Choose this set to build
			testmode = null;
			LogManager.Log("Built "+ max_list.len() +"  Stations in " + AITown.GetName(town), 3);
			failed = ZooElite.BuildBusStationList(max_list);
		} else {
			array.remove(array.len() - 1);
		}
	}
	
	//Once we break the loop, return what we built
	if(failed.len() == 0) {
		return max_list;
	}
	
}

//Build station list assuming that you already have verified the tile you want
//Returns list of stations we failed to build
function ZooElite::BuildBusStationList(list) {
	//If the list is empty or null, break
	if(list == false || list.len() < 1)
		return false;
	//Go through list
	local failedLocations = [];
	foreach(tileIndex in list) {
		local success = false;
		local temptilelist = GetNeighbours4(tileIndex);
			if(AIRoad.IsRoadTile(tileIndex)) {
				//We want a drive through, now to orient it
				LogManager.Log("Building Drive through Station on: " + tileIndex, 1);
				for(local frontTileIndex = temptilelist.Begin(); temptilelist.HasNext(); frontTileIndex = temptilelist.Next()) {
					//Are we facing a road tile
					if(!success && AIRoad.IsRoadTile(frontTileIndex)) {
						LogManager.Log("Attempting to face: " + frontTileIndex, 1);
						success = AIRoad.BuildDriveThroughRoadStation(tileIndex, frontTileIndex, AIRoad.ROADVEHTYPE_BUS, AIStation.STATION_NEW);
						AIRoad.BuildRoad(tileIndex, frontTileIndex);
					} else {
						LogManager.Log("Skipping: " + frontTileIndex, 1);
					}
				}
			} else {
				//we want a depot...orient
				LogManager.Log("Trying to build depot at " + tileIndex, 1);
				for(local frontTileIndex = temptilelist.Begin(); temptilelist.HasNext(); frontTileIndex = temptilelist.Next()) {
					//Are we facing a road tile?
					if(!success && AIRoad.IsRoadTile(frontTileIndex)) {
						LogManager.Log("Attempting to face: " + frontTileIndex, 1);
						success = AIRoad.BuildRoadStation(tileIndex, frontTileIndex, AIRoad.ROADVEHTYPE_BUS, AIStation.STATION_NEW);
						AIRoad.BuildRoad(tileIndex, frontTileIndex);
					} else {
						LogManager.Log("Skipping: " + frontTileIndex, 1);
					}
				}
			}
		if(!success) {
			//TODO: Change This since we might be running in test from above
			failedLocations.push(tileIndex);
			LogManager.Log("Failed to build station in " + AITown.GetName(AITile.GetClosestTown(tileIndex)) + " on tile " + tileIndex + "! Error: " + AIError.GetLastErrorString()	, 1);	
		}
	}
	return failedLocations;
}

//Builds a road depot in the given town (or returns an already existing one)
function ZooElite::BuildDepotForTown(townId) {
	local depots = AIDepotList(AITile.TRANSPORT_ROAD);
	depots.Valuate(AITile.GetClosestTown);
	depots.KeepValue(townId);
	if(depots.Count() > 1) {
		return depots.Begin();
	}
	
	//Search...similar to bus station placer
	local tilelist = AITileList();
	local seed_tile = AITown.GetLocation(townId);
	
	//TODO: Constant?
	local searchRadius = 20;
	if(AIMap.DistanceFromEdge(seed_tile) <= searchRadius)
		searchRadius = AIMap.DistanceFromEdge(seed_tile) - 1;
	
	tilelist.AddRectangle(AIMap.GetTileIndex(AIMap.GetTileX(seed_tile) - searchRadius, AIMap.GetTileY(seed_tile) - searchRadius),
							AIMap.GetTileIndex(AIMap.GetTileX(seed_tile) + searchRadius, AIMap.GetTileY(seed_tile) + searchRadius));
	//Remove everywhere we cannot build, compute viability and sort
	tilelist.Valuate(AITile.GetClosestTown);
	tilelist.KeepValue(townId);
	
	//Filter and Build simultaneously
	local success = false;
	for(local tileId = tilelist.Begin(); tilelist.HasNext() && !success; tileId = tilelist.Next()) {
		if(getNumRoadNeighbors(tileId) > 0 && AITile.IsBuildable(tileId) && !AIRoad.IsRoadTile(tileId) && AITile.GetSlope(tileId) == AITile.SLOPE_FLAT) {
			//Try to build a depot
			//Get road neighbors
			local temptilelist = GetNeighbours4(tileId);
			for(local frontTileIndex = temptilelist.Begin(); temptilelist.HasNext(); frontTileIndex = temptilelist.Next()) {
				//Are we facing a road tile?
				if(!success && AIRoad.IsRoadTile(frontTileIndex) &&  AITile.GetSlope(frontTileIndex) == AITile.SLOPE_FLAT && AITile.GetMinHeight(tileId) == AITile.GetMinHeight(frontTileIndex)) {
					LogManager.Log("Attempting to face: " + frontTileIndex, 1);
					success = AIRoad.BuildRoadDepot(tileId, frontTileIndex);
					if(success && AIRoad.IsRoadDepotTile(tileId)) {
						AIRoad.BuildRoad(tileId, frontTileIndex);
						return tileId;
					}
				} else {
					LogManager.Log("Skipping: " + frontTileIndex, 1);
				}
			}
		}
	}
	LogManager.Log("Unable to find depot placement for " + AITown.GetName(townId), 4);
	return false;
}

//Make sure all the stations are optimally connected
function ZooElite::EnhanceRoadConnectionsInTown(townId) {
	local station_list = ZooElite.GetBusStationsInCity(townId);
	foreach(idx, station in station_list) {
		local tile1 = AIStation.GetFrontTile(station);
		foreach(idx, station2 in station_list) {
			if(station2 > station1) {
				local tile2 = AIStation.GetFrontTile(station2);
				ZooElite.LinkTileToTile(tile1, tile2);
			}
		}
	}
}

//Links the given tile to the other given tile (Usually another town or station)
//returns false on failure - true on successful building.
function ZooElite::LinkTileToTile(tileId, tileId2) {
	//local town_loc = AITown.GetLocation(townId);
	//Holder Function for rail builder
	/* Create an instance of the pathfinder. */
	local pathfinder = CustomPathFinder();
	/* Set the cost for making a turn high. */
	pathfinder.cost.turn = 250;
	pathfinder.cost.no_existing_road = 200;
	pathfinder.cost.slope = 200;
	pathfinder.cost.bridge_per_tile = 300;
	
	//TODO: Add some Intelligence to figure out if we can afford things based on available cash / master plan
	pathfinder.cost.tunnel_per_tile = 200;
	LogManager.Log("Pathing Stations", 2);
	pathfinder.InitializePath([tileId], [tileId2], ZooElite.off_limit_tiles);

	/* Try to find a path. */
  local path = false;
  while (path == false) {
	path = pathfinder.FindPath(100);
	ZooElite.Sleep(1);
  }

  
  if (path == null) {
	/* No path was found. */
	AILog.Error("pathfinder.FindPath return null");
	return false;
  }
  	
	/* If a path was found, build a road over it. */
	//AND FIND SUITABLE STATION SPOT
	while (path != null) {
		local par = path.GetParent();
		if (par != null) {
		  local last_node = path.GetTile();
		  if (AIMap.DistanceManhattan(path.GetTile(), par.GetTile()) == 1 ) {
			if (!AIRoad.BuildRoad(path.GetTile(), par.GetTile())) {
			  /* An error occured while building a piece of road. TODO: handle it. 
			   * Note that is can also be the case that the road was already build. */
			}
		  } else {
			/* Build a bridge or tunnel. */
			if (!AIBridge.IsBridgeTile(path.GetTile()) && !AITunnel.IsTunnelTile(path.GetTile())) {
			  /* If it was a road tile, demolish it first. Do this to work around expended roadbits. */
			  if (AIRoad.IsRoadTile(path.GetTile())) AITile.DemolishTile(path.GetTile());
			  if (AITunnel.GetOtherTunnelEnd(path.GetTile()) == par.GetTile()) {
				if (!AITunnel.BuildTunnel(AIVehicle.VT_ROAD, path.GetTile())) {
				  /* An error occured while building a tunnel. TODO: handle it. */
				}
			  } else {
				local bridge_list = AIBridgeList_Length(AIMap.DistanceManhattan(path.GetTile(), par.GetTile()) + 1);
				bridge_list.Valuate(AIBridge.GetMaxSpeed);
				bridge_list.Sort(AIAbstractList.SORT_BY_VALUE, false);
				if (!AIBridge.BuildBridge(AIVehicle.VT_ROAD, bridge_list.Begin(), path.GetTile(), par.GetTile())) {
				  /* An error occured while building a bridge. TODO: handle it. */
				}
			  }
			}
		  }
		}
		path = par;
	}
	LogManager.Log("Pathing Done!", 2);
	return true;
}
//Attempts to find the optimial position for up to num more stations in given city
//Returns a list of lists of station positions

function ZooElite::FindPlacesInTownForMaxNMoreBusStations(townId, num) {
	//Setup Vars
	local searchRadius = 4;
	
	if(AITown.GetRating(townId, AICompany.ResolveCompanyID(AICompany.COMPANY_SELF)) < AITown.TOWN_RATING_MEDIOCRE)
		ImproveRating(townId, 0, 0);
	
	//TODO: This should probably be passed down from a higher up function, which knows how many are already in the town
	if(AITown.GetHouseCount(townId) > 9) {
		searchRadius = Floor(BUS_RADIUS_MULTIPLIER*SquareRoot(AITown.GetHouseCount(townId)));
	}
	
	//TODO: Is this the best we can do?
	//local curStations = ZooElite.GetBusStationsInCity(townId);
	local curStations = AIStationList(AIStation.STATION_BUS_STOP);
	
	curStations.Valuate(AIBaseStation.GetLocation);
	
	LogManager.Log("Searching for stations in town: " + AITown.GetName(townId) +" with Radius: " + searchRadius, 3);
	
	local tilelist = AITileList();
	local seed_tile = AITown.GetLocation(townId);
	
	tilelist.AddRectangle(AIMap.GetTileIndex(AIMap.GetTileX(seed_tile) - searchRadius, AIMap.GetTileY(seed_tile) - searchRadius),
							AIMap.GetTileIndex(AIMap.GetTileX(seed_tile) + searchRadius, AIMap.GetTileY(seed_tile) + searchRadius)); 
							
	LogManager.Log("Inital Tiles: " + tilelist.Count(), 1);
	//Create TileList to check against, and check each tile to get it's passenger production...
	
	//Remove everywhere we cannot build, compute viability and sort
	tilelist.Valuate(isValidSpotForStation);
	tilelist.RemoveValue(0);
	
	tilelist.Valuate(AITile.GetClosestTown);
	tilelist.KeepValue(townId);
	
	LogManager.Log("Buildable / Road Tiles: " + tilelist.Count(), 1);
	//Get rid of all locations that would impinge on current stations
	foreach(stationIndex, stationTileId in curStations) {
		tilelist.Valuate(AIMap.DistanceMax, stationTileId);
		tilelist.RemoveBelowValue(7);
	}
	
	LogManager.Log("Total Buildable, Non-Conflicting, Valid Tiles: " + tilelist.Count(), 3);
	
	//TODO:Really this should be randomized for optimal performance, but who cares
	tilelist.Valuate(AITile.GetCargoProduction, GetPassengerCargoID(), 1, 1, 4);
	tilelist.RemoveValue(0);
	tilelist.Sort(AIAbstractList.SORT_BY_VALUE, false);
	
	//Setup the inital list to pass
	local initalTileList = [];
	for(local tileIndex = tilelist.Begin(); tilelist.HasNext(); tileIndex = tilelist.Next()) {
		local list = [];
		list.push(tileIndex);
		initalTileList.push(list);
	}
	
	//now we need to figure out how to evaluate it all
	//TODO: VERY IMPORTANT ALGORITHM
	local array = ZooElite.findLocationCombinations(tilelist, num, initalTileList);
	if(array.len() == 0) {
		LogManager.Log("Unable to find valid " + num + " station configuration for " + AITown.GetName(townId),4);
		return false;
	}
		
	return array;
}

//Recursively find locations for AT MOST num stations using tileList
//Returns a list of station locations for busses which are all valid (Assuming valid input)
//	and which do not have an overlapping catchment
function ZooElite::findLocationCombinations(tileList, num, resultList) {

	if(num < 2)
		return resultList;
	
	local newArray = [];
	
	LogManager.Log("Starting pair analyzer for " + num + " more stations with result sizes " + resultList.len(), 1);
	foreach(list in resultList) {
		local tempTileList = AIAbstractList();
		tempTileList.AddList(tileList);
		
		//Prune the list with anything that would conflict with the previously selected stations
		foreach(tileIndex in list) {
			//This Restriction serves to eliminate duplicate lists by forcing an ascending certain order
			tempTileList.Valuate(tileSelf);
			tempTileList.RemoveBelowValue(tileIndex);
			tempTileList.RemoveValue(tileIndex);
			
			//Remove all instances where they would have overlap in the catchment area
			tempTileList.Valuate(AIMap.DistanceMax, tileIndex);
			tempTileList.RemoveBelowValue(8);
			
		}
		
		//Try to add every other tile to this list (which is still valid)
		for(local tileIndex2 = tempTileList.Begin(); tempTileList.HasNext(); tileIndex2 = tempTileList.Next()) {
			local array = [];
			array.extend(list);
			array.push(tileIndex2);
			newArray.push(array);
		}
	}
	
	num--;
	if(newArray.len() == 0)
		return resultList;
		
	return ZooElite.findLocationCombinations(tileList, num, newArray);
}
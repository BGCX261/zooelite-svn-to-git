function custom_compare(a,b)
{
	local sum_a = 0;
	local sum_b = 0;
	foreach(tileId in a) {
			//LogManager.Log(tileId, 3);
			//sum_a += tilelistbackup.GetValue(tileId);
			sum_a += AITile.GetCargoProduction(tileId, GetPassengerCargoID(), 1, 1, 4);
	}
	foreach(tileId in b) {
			//LogManager.Log(tileId, 3);
			//sum_b += tilelistbackup.GetValue(tileId);
			sum_b += AITile.GetCargoProduction(tileId, GetPassengerCargoID(), 1, 1, 4);
	}
	if(sum_a > sum_b) return 1
	else if(sum_a < sum_b) return -1
	return 0;
}

function isValidSpotForStation(tileId) {
	if((getNumRoadNeighbors(tileId) > 0 && AITile.IsBuildable(tileId) && !AIRoad.IsRoadTile(tileId) && AITile.GetSlope(tileId) == AITile.SLOPE_FLAT)
			|| (AIRoad.IsRoadTile(tileId) && isStraightRoad(tileId) && AITile.GetSlope(tileId) == AITile.SLOPE_FLAT))
		return 1;
	return 0;	
}

function isStraightRoad(tile_id) {
	if((AIRoad.IsRoadTile(GetTileRelative(tile_id, -1, 0)) || AIRoad.IsRoadTile(GetTileRelative(tile_id, 1, 0)))
		&& !AIRoad.IsRoadTile(GetTileRelative(tile_id, 0, -1)) && !AIRoad.IsRoadTile(GetTileRelative(tile_id, 0, 1)))
		return true;
	if((AIRoad.IsRoadTile(GetTileRelative(tile_id, 0, -1)) || AIRoad.IsRoadTile(GetTileRelative(tile_id, 0, 1)))
		&& !AIRoad.IsRoadTile(GetTileRelative(tile_id, -1, 0)) && !AIRoad.IsRoadTile(GetTileRelative(tile_id, 1, 0)))
		return true;
	return false;
}

function getNumRoadNeighbors(tile_id) {
	local sum = 0;
	local list = GetNeighbours4(tile_id);
	foreach(tile, index in list) {
		if(AIRoad.IsRoadTile(tile) && AITile.GetMaxHeight(tile) == AITile.GetMaxHeight(tile_id))
			sum ++;
	}
	return sum;
}

function tileSelf(tile_id) {
	return tile_id;
}

function ZooElite::GetBusStationsInCity(townId) {
	//Get a list of stations which are bus stops in this town
	local stations = AIStationList(AIStation.STATION_BUS_STOP);
	stations.Valuate(AIStation.GetNearestTown);
	stations.KeepValue(townId);
	return stations;
}

function ZooElite::NumStationsTownCanSupport(townId) {

}

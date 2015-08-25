//tracks.nut
//require("util/direction.nut");

//f1 and f2 tell us whether we are using the backup plans. They start at 0, 0 when inpute by user
function ZooElite::ConnectStations(fudge, time_out, stationId1, stationId2, f1, f2) {
	LogManager.Log("Connecting Stations: " + stationId1 + " and " + stationId2, 4);
	
	//for junctions
	local JUNCTION_GAP_SIZE = 0;
	local MAXIMUM_DISTANCE_JUNCTION_POINT = 15000;
	local junction_failed = 0;
	local junction_1 = 0;
	local junction_2 = 0;
	
	//ClearSigns();
	//station_table[stationId1].signStation();
	//station_table[stationId2].signStation();

		dtp = ai_instance.dtp;

		//the tiles that we will pass to the path finder
		//the first element of the array is the first choice. The others are the second choices
		local station1_tile;
		local station2_tile;
		local dirIndex1 = [];
		local dirIndex2 = [];
		
		//the stations we are working with
		local station2 = station_table[stationId2];
		local station1 = station_table[stationId1];

		
		/* PATHING FROM THIS STATION */
		//dealing with terminal station with only 1 directions:
		if(station2.station_dir.len() == 1) {
			//must use the only direction
			dirIndex2.push(0);

			//make it connect up right depending on station orientation.
			if(station2.station_dir[0] == dtp.SN_LINE) {
				station2_tile = station2.exit_tile;
				AITile.LevelTiles(GetTileRelative(station2_tile, -1, 0), GetTileRelative(station2_tile, 3, 2));
			}	
			else if (station2.station_dir[0] == dtp.NS_LINE) {
				station2_tile = GetTileRelative(station2.enter_tile, 0, 1);
				AITile.LevelTiles(GetTileRelative(station2_tile, -1, 0), GetTileRelative(station2_tile, 3, -2));

			}
			else if (station2.station_dir[0] == dtp.WE_LINE) {
				station2_tile = station2.enter_tile;
				AITile.LevelTiles(GetTileRelative(station2_tile, 0, -1), GetTileRelative(station2_tile, 2, 3));

			}
			else if (station2.station_dir[0] == dtp.EW_LINE) {
				station2_tile = GetTileRelative(station2.exit_tile, 1, 0);
				AITile.LevelTiles(GetTileRelative(station2_tile, 0, -1), GetTileRelative(station2_tile, -2, 3));
			}			
		}
		
		//non termial station, must choose the side to connect to
		if(station2.station_dir.len() == 2) {
			//if its a NS/SN station
			if(station2.station_dir[0] == dtp.NS_LINE) {
				if(AIMap.GetTileY(AIBaseStation.GetLocation(station2.stationId)) >
					AIMap.GetTileY(AIBaseStation.GetLocation(station1.stationId)) ) {
					//then our station is more north so should use the NS-direction
					dirIndex2.push(0); //the preferable directions
					dirIndex2.push(1); //the backup plan
				}
				else {
					dirIndex2.push(1); //the preferable directions
					dirIndex2.push(0); //the backup plan
				}
			}
			//if its a EW/WE station
			if(station2.station_dir[0] == dtp.EW_LINE) {
				if(AIMap.GetTileX(AIBaseStation.GetLocation(station2.stationId)) >
					AIMap.GetTileX(AIBaseStation.GetLocation(station1.stationId)) ) {
					//then our station is more ease so should use the EW-direction
					dirIndex2.push(0); //the preferable directions
					dirIndex2.push(1); //the backup plan
				}
				else {
					dirIndex2.push(1); //the preferable directions
					dirIndex2.push(0); //the backup plan
				}
			}
			
			//now choose the proper tiles to path to: (remember REGIONAL station)
			if(station2.station_dir[dirIndex2[f2]] == dtp.SN_LINE) {
				//LogManager.Log("SN_LINE", 4);
				local exitside = station2.exit2_tile;
				local enterside = station2.enter2_tile;
				if(Direction.GetDirectionsToTile(exitside, enterside).first == Direction.EAST) station2_tile = enterside;
				else station2_tile = exitside;

				//Sign(GetTileRelative(station2_tile, 2, 4), "levelB");
				//Sign(GetTileRelative(station2_tile, -3, 4), "levelE");
				AITile.LevelTiles(station2_tile, GetTileRelative(station2_tile, -3, 4));
				AITile.LevelTiles(station2_tile, GetTileRelative(station2_tile, 3, 4));
			}
			else if (station2.station_dir[dirIndex2[f2]] == dtp.NS_LINE) {
				local exitside = GetTileRelative(station2.exit_tile, 0, 1);
				local enterside = GetTileRelative(station2.enter_tile, 0, 1);
				if(Direction.GetDirectionsToTile(exitside, enterside).first == Direction.EAST) station2_tile = enterside;
				else station2_tile = exitside;
				
				Sign(GetTileRelative(station2_tile, 2, -4), "levelB");
				Sign(GetTileRelative(station2_tile, -3, -4), "levelE");
				AITile.LevelTiles(station2_tile, GetTileRelative(station2_tile, -3, -4));
				AITile.LevelTiles(station2_tile, GetTileRelative(station2_tile, 3, -4));
			}
			else if (station2.station_dir[dirIndex2[f2]] == dtp.WE_LINE) {
				local exitside = station2.exit2_tile;
				local enterside = station2.enter2_tile;
				if(Direction.GetDirectionsToTile(exitside, enterside).first == Direction.NORTH) station2_tile = enterside;
				else station2_tile = exitside;
				
				AITile.LevelTiles(station2_tile, GetTileRelative(station2_tile, 4, -3));
				AITile.LevelTiles(station2_tile, GetTileRelative(station2_tile, 4, 3));
			}
			else if (station2.station_dir[dirIndex2[f2]] == dtp.EW_LINE) {
				local exitside = GetTileRelative(station2.exit_tile, 1, 0);
				local enterside = GetTileRelative(station2.enter_tile, 1, 0);
				if(Direction.GetDirectionsToTile(exitside, enterside).first == Direction.NORTH) station2_tile = enterside;
				else station2_tile = exitside;
				
				AITile.LevelTiles(station2_tile, GetTileRelative(station2_tile, -4, -3));
				AITile.LevelTiles(station2_tile, GetTileRelative(station2_tile, -4, 3));
			}
		}
		
		local station2_part = station2.station_dir[dirIndex2[f2]];
		
		//now finally we must check if all our work was in vain and we need a junction:
		if(station2.routes[dirIndex2[f2]] != null) {
			junction_2 = 1;
			LogManager.Log("Need to buildJunction for station: " + station2.stationId, 4);
			local djb = DoubleJunctionBuilder([station2.routes[dirIndex2[f2]][1]],
										AIBaseStation.GetLocation(station1.stationId) , JUNCTION_GAP_SIZE , MAXIMUM_DISTANCE_JUNCTION_POINT);
			LogManager.Log("Path Tile: " + AIMap.GetTileY(station2.routes[dirIndex2[f2]][1].tile), 4);
			LogManager.Log("Station Tile: " + AIMap.GetTileY(AIBaseStation.GetLocation(station2.stationId)), 4);
			LogManager.Log("Prefered Direction: " + Direction.GetDirectionsToTile(AIBaseStation.GetLocation(station2.stationId), AIBaseStation.GetLocation(station1.stationId)).first, 4);
			local junction_information2 = djb.BuildJunction(Direction.GetDirectionsToTile(AIBaseStation.GetLocation(station1.stationId),
																					AIBaseStation.GetLocation(station2.stationId)).first);//aqui esta o erro (Nao so aqui)
			DoubleRailroadBuilder.RepairTrack(station2.routes[dirIndex2[f2]]);
			if(junction_information2 == null) {
				LogManager.Log("Junction construction failed", 4);
				junction_failed = 1;
			}
			else {
				station2_tile = dtp.parts[junction_information2.junction_part_index].previous_part_offset + junction_information2.tile;
				station2_part = dtp.GetOppositePart(dtp.parts[junction_information2.junction_part_index].previous_part);
			
				//make it connect up right depending on station orientation.
				if(station2_part == dtp.SN_LINE) {
					station2_tile = GetTileRelative(station2_tile, 0, -1);
				}	
				else if (station2_part == dtp.NS_LINE) {
					station2_tile = GetTileRelative(station2_tile, 0, 1);
				}
				else if (station2_part == dtp.WE_LINE) {
					station2_tile = GetTileRelative(station2_tile, -1, 0);
				}
				else if (station2_part == dtp.EW_LINE) {
					station2_tile = GetTileRelative(station2_tile, 1, 0);
				}	
			}
		}
		
		//-------------------------------------------//
		//-------------------------------------------//
		/*PATHING TO THIS STATION */
		
		//if its a TERMINAL station
		if(station1.station_dir.len() == 1) {
			//must use the only direction
			dirIndex1.push(0);
			//make it connect up right depending on station orientation.
			if(station1.station_dir[0] == dtp.SN_LINE) {
				station1_tile = station1.exit_tile2;
			}
			else if (station1.station_dir[0] == dtp.NS_LINE) {
				station1_tile = station1.enter_tile;
			}	
			else if (station1.station_dir[0] == dtp.WE_LINE) {
				station1_tile = station1.enter_tile2;
			}
			else if (station1.station_dir[0] == dtp.EW_LINE) {
				station1_tile = station1.exit_tile;
			}
		}
		
		//non termial station, must choose the side to connect to
		if(station1.station_dir.len() == 2) {
			//if its a NS/SN station
			if(station1.station_dir[0] == dtp.NS_LINE) {
				if(AIMap.GetTileY(AIBaseStation.GetLocation(station1.stationId)) >
					AIMap.GetTileY(AIBaseStation.GetLocation(station2.stationId)) ) {
					//then our station is more north so should use the NS-direction
					dirIndex1.push(0); //preferable direction
					dirIndex1.push(1); //backup plan
				}
				else {
					dirIndex1.push(1); //preferable direction
					dirIndex1.push(0); //backup plan
				}
			}
			//if its a EW/WE station
			if(station1.station_dir[0] == dtp.EW_LINE) {
				if(AIMap.GetTileX(AIBaseStation.GetLocation(station1.stationId)) >
					AIMap.GetTileX(AIBaseStation.GetLocation(station2.stationId)) ) {
					//then our station is more east so should use the EW-direction
					dirIndex1.push(0); //preferable direction
					dirIndex1.push(1); //backup plan
				}
				else {
					dirIndex1.push(1); //preferable direction
					dirIndex1.push(0); //backup plan
				}
			}
			
			//no choose pathing tile. (Remember: this is NONTERIMAL station going TO IT)
			if(station1.station_dir[dirIndex1[f1]] == dtp.SN_LINE) {
				LogManager.Log("SN_LINE", 4);
				local exitside = station1.exit2_tile2;
				local enterside = station1.enter2_tile2;
				if(Direction.GetDirectionsToTile(exitside, enterside).first == Direction.EAST) station1_tile = enterside;
				else station1_tile = exitside;
				AITile.LevelTiles(station1_tile, GetTileRelative(station1_tile, -3, 4));
				AITile.LevelTiles(station1_tile, GetTileRelative(station1_tile, 3, 4));
			}
			else if (station1.station_dir[dirIndex1[f1]] == dtp.NS_LINE) {
				local exitside = station1.exit_tile;
				local enterside = station1.enter_tile;
				if(Direction.GetDirectionsToTile(exitside, enterside).first == Direction.EAST) station1_tile = enterside;
				else station1_tile = exitside;
				AITile.LevelTiles(station1_tile, GetTileRelative(station1_tile, -3, -4));
				AITile.LevelTiles(station1_tile, GetTileRelative(station1_tile, 3, -4));
				
			}	
			else if (station1.station_dir[dirIndex1[f1]] == dtp.WE_LINE) {
				local exitside = station1.exit2_tile2;
				local enterside = station1.enter2_tile2;
				if(Direction.GetDirectionsToTile(exitside, enterside).first == Direction.NORTH) station1_tile = enterside;
				else station1_tile = exitside;
				AITile.LevelTiles(station1_tile, GetTileRelative(station1_tile, 4, -3));
				AITile.LevelTiles(station1_tile, GetTileRelative(station1_tile, 4, 3));
			}
			else if (station1.station_dir[dirIndex1[f1]] == dtp.EW_LINE) {
				local exitside = station1.exit_tile;
				local enterside = station1.enter_tile;
				if(Direction.GetDirectionsToTile(exitside, enterside).first == Direction.NORTH) station1_tile = enterside;
				else station1_tile = exitside;
				AITile.LevelTiles(station1_tile, GetTileRelative(station1_tile, -4, -3));
				AITile.LevelTiles(station1_tile, GetTileRelative(station1_tile, -4, 3));
			}
		}
		
		local station1_part = station1.station_dir[dirIndex1[f1]];
		
		//now finally we must check if all our work was in vain and we need a junction:
		if(station1.routes[dirIndex1[f1]] != null) {
			junction_1 = 1;
			LogManager.Log("Need to buildJunction for station: " + station1.stationId, 4);
			local djb = DoubleJunctionBuilder([station1.routes[dirIndex1[f1]][1]],
										AIBaseStation.GetLocation(station2.stationId) , JUNCTION_GAP_SIZE , MAXIMUM_DISTANCE_JUNCTION_POINT);
			local junction_information1 = djb.BuildJunction(Direction.GetDirectionsToTile(AIBaseStation.GetLocation(station2.stationId),
																					AIBaseStation.GetLocation(station1.stationId)).first);//aqui esta o erro (Nao so aqui)
			DoubleRailroadBuilder.RepairTrack(station1.routes[dirIndex1[f1]]);
			if(junction_information1 == null) {
				LogManager.Log("Junction1 construction failed", 4);
				junction_failed = 1;
			}
			else { 
				station1_tile = dtp.parts[junction_information1.junction_part_index].previous_part_offset + junction_information1.tile;
				station1_part = dtp.GetOppositePart(dtp.parts[junction_information1.junction_part_index].previous_part);
				
			}
		}
		
		//--------------------------------//
		/////// BUILD TRACK  ////////////////
		/*if(!recursive) {
			local testModeInstance = AITestMode();
			ZooElite.ConnectStations(stationId2, stationId1, true);
			testModeInstance = null;
		}*/
		
		local drrb;
		local double_railroad;
		if(!junction_failed) {
			Sign(station2_tile, "station2_tile");
			Sign(station1_tile, "station1_tile");
			
			drrb = DoubleRailroadBuilder(fudge, time_out, station2_tile, station1_tile, station2_part, 
												dtp.GetOppositePart(station1_part));
				
			double_railroad = drrb.BuildTrack();
		}
		else {
			double_railroad = null;
		}
		
		if(double_railroad != null && double_railroad != false) {
			if(!junction_1) {
				station1.routes[dirIndex1[f1]] = [0, double_railroad.path, double_railroad.path.reversePath()];
			}
			else {
				DoubleRailroadBuilder.RepairTrack(station1.routes[dirIndex1[f1]]);
			}
			if(!junction_2) {
				station2.routes[dirIndex2[f2]] = [1, double_railroad.path.reversePath(), double_railroad.path];
			}
			else {
				DoubleRailroadBuilder.RepairTrack(station2.routes[dirIndex2[f2]]);
			}
			
			/*//local drrdb = DoubeDepotBuilder();
			local depot;
			if(!(depot = DoubleDepotBuilder.BuildDepots(double_railroad.path, 100000, true))) {
				LogManager.Log("Second choice depot", 4);
				depot = DoubleDepotBuilder.BuildDepots(double_railroad.path, 100000, false);
			}*/
			
			local depot = double_railroad.first_depot_tile;
			
			local station1_route_count = 0;
			local station2_route_count = 0;
			
			if(station1.lines == null) {
				//new station
				station1.lines = [];
			} else {
				//already must be connected
				station1_route_count = station1.lines.len();
			}
			if(station2.lines == null) {
				//new station
				station2.lines = [];
			} else {
				station2_route_count = station2.lines.len();
			}
			
			LogManager.Log(AITown.GetName(AITile.GetClosestTown(station1.station_tile)) + " has " + station1_route_count + " and " + AITown.GetName(AITile.GetClosestTown(station2.station_tile)) + " has " + station2_route_count, 4);
			
			local route = null;
			
			GetMoney(70000);
			
			if((station1_route_count == 0 && station2_route_count == 0) || junction_1 || junction_2) {
				route = Route(stationId1, stationId2, depot, station1.routes[dirIndex1[f1]][1], station1.routes[dirIndex1[f2]][1]);
				station1.lines.push(route);
				station2.lines.push(route);
				route_table.push(route);
				route.balanceRailService();
			} else if(station1_route_count > 0 && station2_route_count == 0) {
				route = station1.lines.pop();
				route.servicedStations.push(stationId2);
				route.paths.push([station1.routes[dirIndex1[f1]][1], station1.routes[dirIndex1[f2]][1]]);
				route.balanceRailService();
				route.updateOrders();
				station1.lines.push(route);
				station2.lines.push(route);
			} else if(station1_route_count == 0 && station2_route_count > 0) {
				route = station2.lines.pop();
				route.servicedStations.push(stationId1);
				route.balanceRailService();
				route.updateOrders();
				station1.lines.push(route);
				station2.lines.push(route);
			}
			
			
			return route;
			
			/*LogManager.Log("the tile for station1 path is: " + double_railroad.path.tile, 4);
			Sign(double_railroad.path.tile, "pathTile");
			LogManager.Log("the tile at station 1 is: " + station1_tile, 4);
			Sign(station1_tile, "station1");
			LogManager.Log("the tile at station 2 is: " + station2_tile, 4);
			Sign(station2_tile, "station2");*/
			//Sign(station2.routes[dirIndex2].tile, "pathRev");
			//Sign(station2.routes[dirIndex2].child_path.tile, "childRev");
			//Sign(station2.routes[dirIndex2].child_path.child_path.tile, "child2Rev");
		}
		
		else {
			local new_route;
		
			LogManager.Log("first try to fudge", 4);
			if(fudge == 1 && f1 == 0 && f2 == 0) {
				new_route = ConnectStations(100, 100, stationId1, stationId2, 0, 0);
				if(new_route != null) {
					return new_route;
				}
			}
			
			else {			
				LogManager.Log("need to try alternative path", 4);
			
				if(f1 == 0 && f2 == 0) {
					new_route = ConnectStations(1, 100, stationId1, stationId2, 1, 0);
		
				}
				if(f1 == 1 && f2 == 0) {
					new_route = ConnectStations(1, 100, stationId1, stationId2, 0, 1);
				}
				if(f1 == 0  && f2 == 1) {
					new_route = ConnectStations(1, 100, stationId1, stationId2, 1, 1);
				}
				if(f1 == 1 && f2 ==1) {
					//we have exausted all possbilities
					LogManager.Log("pathing failed!", 2);
					return 0;
				}
			
				if(new_route != null) {
					return new_route;
				}
			}
		}
			
	LogManager.Log("Pathing Done!", 2);
}
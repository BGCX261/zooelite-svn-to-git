/*
 * trAIns - An AI for OpenTTD
 * Copyright (C) 2009  Luis Henrique O. Rios
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.

 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
*/


class DoubleRailroadStationBuilder {
	/* Public: */
	/* All possible positions for PRE_SIGNALED stations. */
	static SOUTH_EAST = 0;
	static SOUTH_WEST = 1;
	static NORTH_EAST = 2;
	static NORTH_WEST = 3;
	static EAST_NORTH = 4;
	static EAST_SOUTH = 5;
	static WEST_NORTH = 6;
	static WEST_SOUTH = 7;

	/* The station types. */
	static PRE_SIGNALED = 0;
	static TERMINUS = 1;

	constructor(n_plataforms , plataform_length , main_exit_direction , secondary_exit_direction ,
		terraforming_max_cost , station_type){
		this.n_plataforms = n_plataforms;
		this.plataform_length = plataform_length;
		this.main_exit_direction = main_exit_direction;
		this.secondary_exit_direction = secondary_exit_direction;
		this.terraforming_max_cost = terraforming_max_cost;
		this.station_type = station_type;
	}

	function BuildIndustryRailroadStation(industry , produces);
	function GetIndustryRailroadStationCost(industry , produces);

	static function ConvertRailroadStation(station_information , rail_type);
	static function DemolishRailroadStation(station_information);

	/* Private: */
	n_plataforms = null;
	plataform_length = null;
	main_exit_direction = null;
	secondary_exit_direction = null;
	target_tile = null;
	covered_tile_list = null;
	terraforming_max_cost = null;
	station_type = null;

	function DecideStationPosition(land);
	function StationLandEvaluation(land , self);
	function StationCoversIndustry(station_tile , tracks_parallel_x);

	static function IterateOverStationTracks(station_information , track_callback , track_callback_param ,
		signal_callback , signal_callback_param);
	static function BuildStationTracks(station_information);
	static function BuildRailTrack(tile , rail_track , unused);
	static function BuildRailSignal(tile , rail_track , unused);
	static function DemolishRailTrack(tile , rail_track , unused);
	static function DummyRailSignal(unused1 , unused2 , unused3 , unused4 , unused5);
	static function ConvertRailTrack(tile , unused , rail_type);
	static function GetRailTrackCost(unused1 , unused2 , tracks_cost);
	static function GetRailSignalCost(unused1 , unused2 , unused3 , unused4 , signals_cost);
}

class DoubleRailroadStationBuilder.DoubleTrackStationInformation {
	exit_direction = null;
	exit_part_tile = null;
	exit_part = null;
	land = null;
	n_plataforms = null;
	plataform_length = null;
	station_tile = null;
	station_position = null;
	station_type = null;
}

function DoubleRailroadStationBuilder::DecideStationPosition(land){
	local station_information = DoubleTrackStationInformation();
	local exit_directions = array(0);

	station_information.land = land;
	station_information.exit_direction = Direction.INVALID_DIRECTION;

	/* The tracks will be parallel to X axis. */
	if(land.swaped_w_h){
		if(main_exit_direction == Direction.WEST || secondary_exit_direction == Direction.WEST){
			exit_directions.push(Direction.WEST);
			exit_directions.push(Direction.EAST);
		}else{
			exit_directions.push(Direction.EAST);
			exit_directions.push(Direction.WEST);
		}
	/* The tracks will be parallel to Y axis. */
	}else{
		if(main_exit_direction == Direction.SOUTH || secondary_exit_direction == Direction.SOUTH){
			exit_directions.push(Direction.SOUTH);
			exit_directions.push(Direction.NORTH);
		}else{
			exit_directions.push(Direction.NORTH);
			exit_directions.push(Direction.SOUTH);
		}
	}

	switch(station_type){
		case PRE_SIGNALED:
			foreach(direction in exit_directions){
				station_information.exit_part_tile = land.t[0];
				station_information.station_tile = land.t[0];

				switch(direction){
					/* The exit will point to WEST. */
					case Direction.WEST:
						station_information.station_tile += AIMap.GetTileIndex(5 , 0);
						if(AIMap.GetTileY(target_tile) > AIMap.GetTileY(land.t[0])){
							station_information.station_tile += AIMap.GetTileIndex(0 , 2);
							station_information.station_position = WEST_NORTH;
							station_information.exit_part_tile += AIMap.GetTileIndex(3 , 2);
						}else{
							station_information.station_position = WEST_SOUTH;
							station_information.exit_part_tile += AIMap.GetTileIndex(3 , n_plataforms);
						}
						station_information.exit_part = DoubleTrackParts.EW_LINE;
						if(!StationCoversIndustry(station_information.station_tile , true)) continue;
						station_information.exit_direction = Direction.WEST;
					break;

					/* The exit will point to EAST. */
					case Direction.EAST:
						station_information.station_tile += AIMap.GetTileIndex(2 , 0);
						if(AIMap.GetTileY(target_tile) > AIMap.GetTileY(land.t[0])){
							station_information.station_tile += AIMap.GetTileIndex(0 , 2);
							station_information.station_position = this.EAST_NORTH;
							station_information.exit_part_tile += AIMap.GetTileIndex(plataform_length + 4 , 2);
						}else{
							station_information.station_position = this.EAST_SOUTH;
							station_information.exit_part_tile += AIMap.GetTileIndex(plataform_length + 4 , n_plataforms);
						}
						station_information.exit_part = DoubleTrackParts.WE_LINE;
						if(!StationCoversIndustry(station_information.station_tile , true)) continue;
						station_information.exit_direction = Direction.EAST;
					break;

					/* The exit will point to SOUTH. */
					case Direction.SOUTH:
						station_information.station_tile += AIMap.GetTileIndex(0 , 5);
						if(AIMap.GetTileX(target_tile) > AIMap.GetTileX(land.t[0])){
							station_information.station_tile += AIMap.GetTileIndex(2 , 0);
							station_information.station_position = this.SOUTH_EAST;
							station_information.exit_part_tile += AIMap.GetTileIndex(2 , 3);
						}else{
							station_information.station_position = this.SOUTH_WEST;
							station_information.exit_part_tile += AIMap.GetTileIndex(n_plataforms , 3);
						}
						station_information.exit_part = DoubleTrackParts.NS_LINE;
						if(!StationCoversIndustry(station_information.station_tile , false)) continue;
						station_information.exit_direction = Direction.SOUTH;
					break;

					/* The exit will point to NORTH. */
					case Direction.NORTH:
						station_information.station_tile += AIMap.GetTileIndex(0 , 2);
						if(AIMap.GetTileX(target_tile) > AIMap.GetTileX(land.t[0])){
							station_information.station_tile += AIMap.GetTileIndex(2 , 0);
							station_information.station_position = this.NORTH_EAST;
							station_information.exit_part_tile += AIMap.GetTileIndex(2 , plataform_length + 4);
						}else{
							station_information.station_position = this.NORTH_WEST;
							station_information.exit_part_tile += AIMap.GetTileIndex(n_plataforms , plataform_length + 4);
						}
						station_information.exit_part = DoubleTrackParts.SN_LINE;
						if(!StationCoversIndustry(station_information.station_tile , false)) continue;
						station_information.exit_direction = Direction.NORTH;
					break;
				}
				if(station_information.exit_direction != Direction.INVALID_DIRECTION) break;
			}
		break;
		case TERMINUS:
			foreach(direction in exit_directions){
				station_information.exit_part_tile = land.t[0];
				station_information.station_tile = land.t[0];

				switch(direction){
					/* The exit will point to NORTH. */
					case Direction.NORTH:
						station_information.exit_part_tile += AIMap.GetTileIndex(1 , plataform_length + 2);
						station_information.exit_part = DoubleTrackParts.SN_LINE;
						if(!StationCoversIndustry(station_information.station_tile , true)) continue;
						station_information.exit_direction = Direction.NORTH;
						station_information.station_position = Direction.NORTH;
					break;

					/* The exit will point to SOUTH. */
					case Direction.SOUTH:
						station_information.station_tile += AIMap.GetTileIndex(0 , 5);
						station_information.exit_part_tile += AIMap.GetTileIndex(1 , 3);
						station_information.exit_part = DoubleTrackParts.NS_LINE;
						if(!StationCoversIndustry(station_information.station_tile , true)) continue;
						station_information.exit_direction = Direction.SOUTH;
						station_information.station_position = Direction.SOUTH;
					break;

					/* The exit will point to EAST. */
					case Direction.EAST:
						station_information.exit_part_tile += AIMap.GetTileIndex(plataform_length + 2 , 1);
						station_information.exit_part = DoubleTrackParts.WE_LINE;
						if(!StationCoversIndustry(station_information.station_tile , true)) continue;
						station_information.exit_direction = Direction.EAST;
						station_information.station_position = Direction.EAST;
					break;

					/* The exit will point to WEST. */
					case Direction.WEST:
						station_information.station_tile += AIMap.GetTileIndex(5 , 0);
						station_information.exit_part_tile += AIMap.GetTileIndex(3 , 1);
						station_information.exit_part = DoubleTrackParts.EW_LINE;
						if(!StationCoversIndustry(station_information.station_tile , true)) continue;
						station_information.exit_direction = Direction.WEST;
						station_information.station_position = Direction.WEST;
					break;
				}
				if(station_information.exit_direction != Direction.INVALID_DIRECTION) break;
			}
		break;
	}
	if(station_information.exit_direction == Direction.INVALID_DIRECTION) return null;
	return station_information;
}

function DoubleRailroadStationBuilder::StationCoversIndustry(station_tile , tracks_parallel_x){
	local w , h;
	local area_w , area_h;

	if(tracks_parallel_x){
		area_w = plataform_length;
		area_h = n_plataforms;
	}else{
		area_h = plataform_length;
		area_w = n_plataforms;
	}

 	for(w = 0 ; w < area_w ; w++){
		for(h = 0 ; h < area_h ; h++){
			if(covered_tile_list.HasItem(station_tile + AIMap.GetTileIndex(w , h)))
				return true;
		}
	}
	return false;
}

function DoubleRailroadStationBuilder::StationLandEvaluation(land , self){
	local station_information = self.DecideStationPosition(land);

	if(station_information == null) return 0.0;
	if(station_information.exit_direction == self.main_exit_direction) return 1.0;
	else if(station_information.exit_direction == self.secondary_exit_direction) return 0.75;
	else if(station_information.exit_direction != Direction.GetOppositeDirection(self.main_exit_direction))
		return 0.25;
	else return 0.125;
}

/* FIXME: this function is wrong because it is nothing considering the inflation. */
function DoubleRailroadStationBuilder::GetIndustryRailroadStationCost(industry , produces){
	local w , h;
	local coverage_radius = AIStation.GetCoverageRadius(AIStation.STATION_TRAIN);
	local ila;
	local total_cost;
	local station_information;

	w = n_plataforms + 2;
	h = plataform_length + 7;
	target_tile = AIIndustry.GetLocation(industry);
	if(produces) covered_tile_list = AITileList_IndustryProducing (industry , coverage_radius);
	else covered_tile_list = AITileList_IndustryAccepting(industry , coverage_radius);

	ila = IndustryLandAllocator(w , h , DoubleRailroadStationBuilder.StationLandEvaluation ,
		this , terraforming_max_cost , true , 0.75 , coverage_radius , industry);
	{
		local ai_test_mode = AITestMode();
		local cost = AIAccounting();
		local land = ila.AllocateLand();
		if(land == null) return null;
		total_cost = cost.GetCosts();
		station_information = DecideStationPosition(land);
		station_information.plataform_length = plataform_length;
		station_information.n_plataforms = n_plataforms;
	}
	local flat_tile = Tile.GetFlatTile(AIIndustry.GetLocation(industry));
	local tracks_cost , signals_cost , station_cost;
	local error = false;

	signals_cost = Pair(0 , 75);
	if(flat_tile != null){
		local ai_test_mode = AITestMode();
		{
			local cost = AIAccounting();
			if(AIRail.BuildRailStation(flat_tile , AIRail.RAILTRACK_NE_SW , 1 , 1 , AIStation.STATION_NEW)){
				station_cost = cost.GetCosts() * n_plataforms * plataform_length;
			}else error = true;
		}
		{
			local cost = AIAccounting();
			if(AIRail.BuildRailTrack(flat_tile , AIRail.RAILTRACK_NE_SW)){
				tracks_cost = Pair(0 , cost.GetCosts());
			}else error = true;
		}
	}
	if(flat_tile == null || error){
		tracks_cost = Pair(0 , 150);
		station_cost = 450 * n_plataforms * plataform_length;
	}
	IterateOverStationTracks(station_information , DoubleRailroadStationBuilder.GetRailTrackCost , tracks_cost ,
		DoubleRailroadStationBuilder.GetRailSignalCost , signals_cost);
	total_cost = total_cost + signals_cost.first + tracks_cost.first + station_cost;
	return total_cost;
}

function DoubleRailroadStationBuilder::BuildIndustryRailroadStation(industry , produces){
	local w , h;
	local land;
	local coverage_radius = AIStation.GetCoverageRadius(AIStation.STATION_TRAIN);
	local ila;
	local station_information;

	switch(station_type){
		case PRE_SIGNALED:
			w = n_plataforms + 2;
			h = plataform_length + 7;
		break;
		case TERMINUS:
			assert(n_plataforms >= 2);
			w = n_plataforms;
			h = plataform_length + 5;
		break;
	}

	target_tile = AIIndustry.GetLocation(industry);
	if(produces) covered_tile_list = AITileList_IndustryProducing (industry , coverage_radius);
	else covered_tile_list = AITileList_IndustryAccepting(industry , coverage_radius);

	ila = IndustryLandAllocator(w , h , DoubleRailroadStationBuilder.StationLandEvaluation ,
		this , terraforming_max_cost , true , 0.75 , coverage_radius , industry);
	land = ila.AllocateLand();

	if(land == null) return null;

	station_information = DecideStationPosition(land);

	/* Build the station. */
	{
		local station_direction;
		if(station_information.exit_direction == Direction.SOUTH ||
			station_information.exit_direction == Direction.NORTH) station_direction = AIRail.RAILTRACK_NW_SE;
		else station_direction = AIRail.RAILTRACK_NE_SW;

		if(!AIRail.BuildRailStation(station_information.station_tile , station_direction , n_plataforms ,
			plataform_length , AIStation.STATION_NEW )){
			return null;
		}
	}

	station_information.plataform_length = plataform_length;
	station_information.n_plataforms = n_plataforms;
	station_information.land = land;
	station_information.station_type = station_type;

	/* Build station tracks. */
	if(!BuildStationTracks(station_information)){
		DoubleRailroadStationBuilder.DemolishRailroadStation(station_information);
		return null;
	}

	return station_information;
}

function DoubleRailroadStationBuilder::ConvertRailTrack(tile , unused , rail_type){
	AIRail.ConvertRailType(tile , tile , rail_type);
	return true;
}

function DoubleRailroadStationBuilder::DemolishRailTrack(tile , rail_track , unused){
	AIRail.RemoveRailTrack(tile , rail_track);
	return true;
}

function DoubleRailroadStationBuilder::DummyRailSignal(unused1 , unused2 , unused3 , unused4 , unused5){
	return true;
}

function DoubleRailroadStationBuilder::GetRailTrackCost(unused1 , unused2 , tracks_cost){
	tracks_cost.first += tracks_cost.second;
	return true;
}

function DoubleRailroadStationBuilder::GetRailSignalCost(unused1 , unused2 , unused3 , unused4 , signals_cost){
	signals_cost.first += signals_cost.second;
	return true;
}

function DoubleRailroadStationBuilder::BuildRailTrack(tile , rail_track , unused){
	return AIRail.BuildRailTrack(tile , rail_track);
}

function DoubleRailroadStationBuilder::BuildRailSignal(tile , rail_track , sense , signal_type , unused){
	return RailroadCommon.BuildSignal(tile , rail_track , sense , signal_type);
}

function DoubleRailroadStationBuilder::IterateOverTracksOfTerminusStation(station_information , track_callback ,
	track_callback_param , signal_callback , signal_callback_param){

	local t0 = station_information.land.t[0];
	local plataform_length = station_information.plataform_length;
	local n_plataforms = station_information.n_plataforms;

	switch(station_information.station_position){
		case Direction.NORTH:
			for(local i = 0 ; i < n_plataforms ; i++){
				if(!track_callback(t0 + AIMap.GetTileIndex(i , plataform_length) ,
					AIRail.RAILTRACK_NW_SE , track_callback_param)) return false;
				if(!signal_callback(t0 + AIMap.GetTileIndex(i , plataform_length) ,
					AIRail.RAILTRACK_NW_SE , RailroadCommon.DOUBLE_SENSE , AIRail.SIGNALTYPE_EXIT ,
						signal_callback_param)) return false;
			}

			if(!track_callback(t0 + AIMap.GetTileIndex(0 , plataform_length + 2) ,
				AIRail.RAILTRACK_NW_SE , track_callback_param)) return false;
			if(!track_callback(t0 + AIMap.GetTileIndex(1 , plataform_length + 2) ,
				AIRail.RAILTRACK_NW_SE , track_callback_param)) return false;
			if(!signal_callback(t0 + AIMap.GetTileIndex(0 , plataform_length + 2) ,
				AIRail.RAILTRACK_NW_SE , RailroadCommon.CLOCKWISE , AIRail.SIGNALTYPE_NORMAL ,
					signal_callback_param)) return false;
			if(!signal_callback(t0 + AIMap.GetTileIndex(1 , plataform_length + 2) ,
				AIRail.RAILTRACK_NW_SE , RailroadCommon.COUNTERCLOCKWISE , AIRail.SIGNALTYPE_ENTRY ,
					signal_callback_param)) return false;

			if(!track_callback(t0 + AIMap.GetTileIndex(0 , plataform_length + 1) ,
				AIRail.RAILTRACK_NW_SE , track_callback_param)) return false;
			if(!track_callback(t0 + AIMap.GetTileIndex(0 , plataform_length + 1) ,
				AIRail.RAILTRACK_NW_SW , track_callback_param)) return false;
			if(!track_callback(t0 + AIMap.GetTileIndex(0 , plataform_length + 1) ,
				AIRail.RAILTRACK_SW_SE , track_callback_param)) return false;
			if(!track_callback(t0 + AIMap.GetTileIndex(1 , plataform_length + 1) ,
				AIRail.RAILTRACK_NW_SE , track_callback_param)) return false;
			if(!track_callback(t0 + AIMap.GetTileIndex(1 , plataform_length + 1) ,
				AIRail.RAILTRACK_NE_SE , track_callback_param)) return false;
			for(local i = 1 ; i < (n_plataforms - 1) ; i++){
				if(i == 1)
					if(!track_callback(t0 + AIMap.GetTileIndex(1 , plataform_length + 1) ,
						AIRail.RAILTRACK_SW_SE , track_callback_param)) return false;
				if(!track_callback(t0 + AIMap.GetTileIndex(i , plataform_length + 1) ,
					AIRail.RAILTRACK_NE_SW , track_callback_param)) return false;
			}
			for(local i = 1 ; i < n_plataforms ; i++){
				if(!track_callback(t0 + AIMap.GetTileIndex(i , plataform_length + 1) ,
					AIRail.RAILTRACK_NW_NE , track_callback_param)) return false;
			}
		break;

		case Direction.SOUTH:
			for(local i = 0 ; i < n_plataforms ; i++){
				if(!track_callback(t0 + AIMap.GetTileIndex(i , 4) ,
					AIRail.RAILTRACK_NW_SE , track_callback_param)) return false;
				if(!signal_callback(t0 + AIMap.GetTileIndex(i , 4) ,
					AIRail.RAILTRACK_NW_SE , RailroadCommon.DOUBLE_SENSE , AIRail.SIGNALTYPE_EXIT ,
						signal_callback_param)) return false;
			}

			if(!track_callback(t0 + AIMap.GetTileIndex(0 , 2) ,
				AIRail.RAILTRACK_NW_SE , track_callback_param)) return false;
			if(!track_callback(t0 + AIMap.GetTileIndex(1 , 2) ,
				AIRail.RAILTRACK_NW_SE , track_callback_param)) return false;
			if(!signal_callback(t0 + AIMap.GetTileIndex(0 , 2) ,
				AIRail.RAILTRACK_NW_SE , RailroadCommon.CLOCKWISE , AIRail.SIGNALTYPE_ENTRY ,
					signal_callback_param)) return false;
			if(!signal_callback(t0 + AIMap.GetTileIndex(1 , 2) ,
				AIRail.RAILTRACK_NW_SE , RailroadCommon.COUNTERCLOCKWISE , AIRail.SIGNALTYPE_NORMAL ,
					signal_callback_param)) return false;

			if(!track_callback(t0 + AIMap.GetTileIndex(0 , 3) ,
				AIRail.RAILTRACK_NW_SE , track_callback_param)) return false;
			if(!track_callback(t0 + AIMap.GetTileIndex(0 , 3) ,
				AIRail.RAILTRACK_NW_SW , track_callback_param)) return false;
			if(!track_callback(t0 + AIMap.GetTileIndex(0 , 3) ,
				AIRail.RAILTRACK_SW_SE , track_callback_param)) return false;
			if(!track_callback(t0 + AIMap.GetTileIndex(1 , 3) ,
				AIRail.RAILTRACK_NW_SE , track_callback_param)) return false;
			if(!track_callback(t0 + AIMap.GetTileIndex(1 , 3) ,
				AIRail.RAILTRACK_NW_NE , track_callback_param)) return false;
			for(local i = 1 ; i < (n_plataforms - 1) ; i++){
				if(i == 1)
					if(!track_callback(t0 + AIMap.GetTileIndex(1 , 3) ,
						AIRail.RAILTRACK_NW_SW , track_callback_param)) return false;
				if(!track_callback(t0 + AIMap.GetTileIndex(i , 3) ,
					AIRail.RAILTRACK_NE_SW , track_callback_param)) return false;
			}
			for(local i = 1 ; i < n_plataforms ; i++){
				if(!track_callback(t0 + AIMap.GetTileIndex(i , 3) ,
					AIRail.RAILTRACK_NE_SE , track_callback_param)) return false;
			}
		break;

		case Direction.WEST:
			for(local i = 0 ; i < n_plataforms ; i++){
				if(!track_callback(t0 + AIMap.GetTileIndex(4 , i) ,
					AIRail.RAILTRACK_NE_SW , track_callback_param)) return false;
				if(!signal_callback(t0 + AIMap.GetTileIndex(4 , i) ,
					AIRail.RAILTRACK_NE_SW , RailroadCommon.DOUBLE_SENSE , AIRail.SIGNALTYPE_EXIT ,
						signal_callback_param)) return false;
			}

			if(!track_callback(t0 + AIMap.GetTileIndex(2 , 0) ,
				AIRail.RAILTRACK_NE_SW , track_callback_param)) return false;
			if(!track_callback(t0 + AIMap.GetTileIndex(2 , 1) ,
				AIRail.RAILTRACK_NE_SW , track_callback_param)) return false;
			if(!signal_callback(t0 + AIMap.GetTileIndex(2 , 0) ,
				AIRail.RAILTRACK_NE_SW , RailroadCommon.CLOCKWISE , AIRail.SIGNALTYPE_NORMAL ,
					signal_callback_param)) return false;
			if(!signal_callback(t0 + AIMap.GetTileIndex(2 , 1) ,
				AIRail.RAILTRACK_NE_SW , RailroadCommon.COUNTERCLOCKWISE , AIRail.SIGNALTYPE_ENTRY ,
					signal_callback_param)) return false;

			if(!track_callback(t0 + AIMap.GetTileIndex(3 , 0) ,
				AIRail.RAILTRACK_NE_SW , track_callback_param)) return false;
			if(!track_callback(t0 + AIMap.GetTileIndex(3 , 0) ,
				AIRail.RAILTRACK_NE_SE , track_callback_param)) return false;
			if(!track_callback(t0 + AIMap.GetTileIndex(3 , 0) ,
				AIRail.RAILTRACK_SW_SE , track_callback_param)) return false;
			if(!track_callback(t0 + AIMap.GetTileIndex(3 , 1) ,
				AIRail.RAILTRACK_NE_SW , track_callback_param)) return false;
			if(!track_callback(t0 + AIMap.GetTileIndex(3 , 1) ,
				AIRail.RAILTRACK_NW_NE , track_callback_param)) return false;
			for(local i = 1 ; i < (n_plataforms - 1) ; i++){
				if(i == 1)
					if(!track_callback(t0 + AIMap.GetTileIndex(3 , 1) ,
						AIRail.RAILTRACK_NE_SE , track_callback_param)) return false;
				if(!track_callback(t0 + AIMap.GetTileIndex(3 , i) ,
					AIRail.RAILTRACK_NW_SE , track_callback_param)) return false;
			}
			for(local i = 1 ; i < n_plataforms ; i++){
				if(!track_callback(t0 + AIMap.GetTileIndex(3 , i) ,
					AIRail.RAILTRACK_NW_SW , track_callback_param)) return false;
			}
		break;

		case Direction.EAST:
			for(local i = 0 ; i < n_plataforms ; i++){
				if(!track_callback(t0 + AIMap.GetTileIndex(plataform_length , i) ,
					AIRail.RAILTRACK_NE_SW , track_callback_param)) return false;
				if(!signal_callback(t0 + AIMap.GetTileIndex(plataform_length , i) ,
					AIRail.RAILTRACK_NE_SW , RailroadCommon.DOUBLE_SENSE , AIRail.SIGNALTYPE_EXIT ,
						signal_callback_param)) return false;
			}

			if(!track_callback(t0 + AIMap.GetTileIndex(2 + plataform_length , 0) ,
				AIRail.RAILTRACK_NE_SW , track_callback_param)) return false;
			if(!track_callback(t0 + AIMap.GetTileIndex(2 + plataform_length , 1) ,
				AIRail.RAILTRACK_NE_SW , track_callback_param)) return false;
			if(!signal_callback(t0 + AIMap.GetTileIndex(2 + plataform_length , 0) ,
				AIRail.RAILTRACK_NE_SW , RailroadCommon.CLOCKWISE , AIRail.SIGNALTYPE_ENTRY ,
					signal_callback_param)) return false;
			if(!signal_callback(t0 + AIMap.GetTileIndex(2 + plataform_length , 1) ,
				AIRail.RAILTRACK_NE_SW , RailroadCommon.COUNTERCLOCKWISE , AIRail.SIGNALTYPE_NORMAL ,
					signal_callback_param)) return false;

			if(!track_callback(t0 + AIMap.GetTileIndex(1 + plataform_length , 0) ,
				AIRail.RAILTRACK_NE_SW , track_callback_param)) return false;
			if(!track_callback(t0 + AIMap.GetTileIndex(1 + plataform_length , 0) ,
				AIRail.RAILTRACK_NE_SE , track_callback_param)) return false;
			if(!track_callback(t0 + AIMap.GetTileIndex(1 + plataform_length , 0) ,

				AIRail.RAILTRACK_SW_SE , track_callback_param)) return false;
			if(!track_callback(t0 + AIMap.GetTileIndex(1 + plataform_length , 1) ,
				AIRail.RAILTRACK_NE_SW , track_callback_param)) return false;
			if(!track_callback(t0 + AIMap.GetTileIndex(1 + plataform_length , 1) ,
				AIRail.RAILTRACK_NW_SW , track_callback_param)) return false;
			for(local i = 1 ; i < (n_plataforms - 1) ; i++){
				if(i == 1)
					if(!track_callback(t0 + AIMap.GetTileIndex(1 + plataform_length , 1) ,
						AIRail.RAILTRACK_SW_SE , track_callback_param)) return false;
				if(!track_callback(t0 + AIMap.GetTileIndex(1 + plataform_length , i) ,
					AIRail.RAILTRACK_NW_SE , track_callback_param)) return false;
			}
			for(local i = 1 ; i < n_plataforms ; i++){
				if(!track_callback(t0 + AIMap.GetTileIndex(1 + plataform_length , i) ,
					AIRail.RAILTRACK_NW_NE , track_callback_param)) return false;
			}
		break;
	}

	return true;
}

function DoubleRailroadStationBuilder::IterateOverTracksOfPreSignaledStation(station_information , track_callback ,
	track_callback_param , signal_callback , signal_callback_param){

	local t0 = station_information.land.t[0];
	local plataform_length = station_information.plataform_length;
	local n_plataforms = station_information.n_plataforms;

	switch(station_information.station_position){
		case DoubleRailroadStationBuilder.SOUTH_WEST:
			for(local i = 1 ; i <= n_plataforms ; i++)
				if(!track_callback(t0 + AIMap.GetTileIndex(i , plataform_length + 6) ,
					AIRail.RAILTRACK_NE_SW , track_callback_param)) return false;
			if(!track_callback(t0 + AIMap.GetTileIndex(1 + n_plataforms , plataform_length + 6) ,
				AIRail.RAILTRACK_NW_NE , track_callback_param)) return false;
			if(!track_callback(t0 + AIMap.GetTileIndex(1 + n_plataforms , plataform_length + 5) ,
				AIRail.RAILTRACK_NW_SE , track_callback_param)) return false;
			if(!track_callback(t0 + AIMap.GetTileIndex(1 + n_plataforms , plataform_length + 4) ,
				AIRail.RAILTRACK_NE_SE , track_callback_param)) return false;
			if(!track_callback(t0 + AIMap.GetTileIndex(n_plataforms , plataform_length + 4) ,
				AIRail.RAILTRACK_NW_SW , track_callback_param)) return false;

			for(local i = 2 ; i <= plataform_length + 3 ; i++){
				if(!track_callback(t0 + AIMap.GetTileIndex(n_plataforms , i) ,
					AIRail.RAILTRACK_NW_SE , track_callback_param)) return false;
				if(!signal_callback(t0 + AIMap.GetTileIndex(n_plataforms , i) ,
					AIRail.RAILTRACK_NW_SE , RailroadCommon.COUNTERCLOCKWISE , AIRail.SIGNALTYPE_NORMAL ,
						signal_callback_param)) return false;
			}

			for(local i = 0 ; i < n_plataforms ; i++){
				if(!track_callback(t0 + AIMap.GetTileIndex(i , 4) ,
					AIRail.RAILTRACK_NW_SE , track_callback_param)) return false;
				if(!signal_callback(t0 + AIMap.GetTileIndex(i , 4) , AIRail.RAILTRACK_NW_SE ,
					RailroadCommon.CLOCKWISE , AIRail.SIGNALTYPE_EXIT , signal_callback_param)) return false;
				if(i < n_plataforms - 1)
					if(!track_callback(t0 + AIMap.GetTileIndex(i , 3) ,
						AIRail.RAILTRACK_SW_SE , track_callback_param)) return false;
				if(i > 0 && i < n_plataforms - 1)
					if(!track_callback(t0 + AIMap.GetTileIndex(i , 3) ,
						AIRail.RAILTRACK_NE_SW , track_callback_param)) return false;
				if(!track_callback(t0 + AIMap.GetTileIndex(i , 5 + plataform_length) ,
					AIRail.RAILTRACK_NW_SE , track_callback_param)) return false;
				if(!signal_callback(t0 + AIMap.GetTileIndex(i , 5 + plataform_length) ,
					AIRail.RAILTRACK_NW_SE , RailroadCommon.CLOCKWISE , AIRail.SIGNALTYPE_NORMAL ,
						signal_callback_param)) return false;
				if(!track_callback(t0 + AIMap.GetTileIndex(i , 6 + plataform_length) ,
					AIRail.RAILTRACK_NW_SW , track_callback_param)) return false;
			}

			if(n_plataforms > 1)
				if(!track_callback(t0 + AIMap.GetTileIndex(n_plataforms - 1 , 3) ,
					AIRail.RAILTRACK_NW_NE , track_callback_param)) return false;

			if(!track_callback(t0 + AIMap.GetTileIndex(n_plataforms - 1 , 2) ,
				AIRail.RAILTRACK_NW_SE , track_callback_param)) return false;
			if(!track_callback(t0 + AIMap.GetTileIndex(n_plataforms - 1 , 3) ,
				AIRail.RAILTRACK_NW_SE , track_callback_param)) return false;

			if(!signal_callback(t0 + AIMap.GetTileIndex(1 + n_plataforms , plataform_length + 5 ) ,
				AIRail.RAILTRACK_NW_SE , RailroadCommon.COUNTERCLOCKWISE , AIRail.SIGNALTYPE_NORMAL ,
					signal_callback_param)) return false;
			if(!signal_callback(t0 + AIMap.GetTileIndex(n_plataforms - 1 , 2) ,
				AIRail.RAILTRACK_NW_SE , RailroadCommon.CLOCKWISE , AIRail.SIGNALTYPE_ENTRY ,
					signal_callback_param)) return false;

		break;

		case DoubleRailroadStationBuilder.SOUTH_EAST:
			for(local i = 1 ; i <= n_plataforms ; i++)
				if(!track_callback(t0 + AIMap.GetTileIndex(i , plataform_length + 6) ,
					AIRail.RAILTRACK_NE_SW , track_callback_param)) return false;
			if(!track_callback(t0 + AIMap.GetTileIndex(0 , plataform_length + 6) ,
				AIRail.RAILTRACK_NW_SW , track_callback_param)) return false;
			if(!track_callback(t0 + AIMap.GetTileIndex(0 , plataform_length + 5) ,
				AIRail.RAILTRACK_NW_SE , track_callback_param)) return false;
			if(!track_callback(t0 + AIMap.GetTileIndex(0 , plataform_length + 4) ,
				AIRail.RAILTRACK_SW_SE , track_callback_param)) return false;
			if(!track_callback(t0 + AIMap.GetTileIndex(1 , plataform_length + 4) ,
				AIRail.RAILTRACK_NW_NE , track_callback_param)) return false;

			for(local i = 2 ; i <= plataform_length + 3 ; i++){
				if(!track_callback(t0 + AIMap.GetTileIndex(1 , i) ,
					AIRail.RAILTRACK_NW_SE , track_callback_param)) return false;
				if(!signal_callback(t0 + AIMap.GetTileIndex(1 , i) , AIRail.RAILTRACK_NW_SE ,
					RailroadCommon.CLOCKWISE , AIRail.SIGNALTYPE_NORMAL , signal_callback_param)) return false;
			}

			for(local i = 0 ; i < n_plataforms ; i++){
				if(!track_callback(t0 + AIMap.GetTileIndex(2 + i , 4) ,
					AIRail.RAILTRACK_NW_SE , track_callback_param)) return false;
				if(!signal_callback(t0 + AIMap.GetTileIndex(2 + i , 4) , AIRail.RAILTRACK_NW_SE ,
					RailroadCommon.COUNTERCLOCKWISE , AIRail.SIGNALTYPE_NORMAL , signal_callback_param)) return false;
				if(i > 0)
					if(!track_callback(t0 + AIMap.GetTileIndex(2 + i , 3) ,
						AIRail.RAILTRACK_NE_SE , track_callback_param)) return false;
				if(i > 1)
					if(!track_callback(t0 + AIMap.GetTileIndex(1 + i , 3) ,
						AIRail.RAILTRACK_NE_SW , track_callback_param)) return false;
				if(!track_callback(t0 + AIMap.GetTileIndex(2 + i , 5 + plataform_length) ,
					AIRail.RAILTRACK_NW_SE , track_callback_param)) return false;
				if(!signal_callback(t0 + AIMap.GetTileIndex(2 + i , 5 + plataform_length) ,
					AIRail.RAILTRACK_NW_SE , RailroadCommon.COUNTERCLOCKWISE , AIRail.SIGNALTYPE_EXIT ,
						signal_callback_param)) return false;
				if(!track_callback(t0 + AIMap.GetTileIndex(2 + i , 6 + plataform_length) ,
					AIRail.RAILTRACK_NW_NE , track_callback_param)) return false;
			}

			if(n_plataforms > 1)
				if(!track_callback(t0 + AIMap.GetTileIndex(2 , 3) ,
					AIRail.RAILTRACK_NW_SW , track_callback_param)) return false;

			if(!track_callback(t0 + AIMap.GetTileIndex(2 , 2) ,
				AIRail.RAILTRACK_NW_SE , track_callback_param)) return false;
			if(!track_callback(t0 + AIMap.GetTileIndex(2 , 3) ,
				AIRail.RAILTRACK_NW_SE , track_callback_param)) return false;

			if(!signal_callback(t0 + AIMap.GetTileIndex(2 , 2) , AIRail.RAILTRACK_NW_SE ,
				RailroadCommon.COUNTERCLOCKWISE , AIRail.SIGNALTYPE_NORMAL , signal_callback_param)) return false;
			if(!signal_callback(t0 + AIMap.GetTileIndex(0 , plataform_length + 5) ,
				AIRail.RAILTRACK_NW_SE , RailroadCommon.CLOCKWISE , AIRail.SIGNALTYPE_ENTRY ,
					signal_callback_param)) return false;
		break;

		case DoubleRailroadStationBuilder.NORTH_EAST:
			for(local i = 1 ; i <= n_plataforms ; i++)
				if(!track_callback(t0 + AIMap.GetTileIndex(i , 0) ,
					AIRail.RAILTRACK_NE_SW , track_callback_param)) return false;
			if(!track_callback(t0 + AIMap.GetTileIndex(0 , 0) ,
				AIRail.RAILTRACK_SW_SE , track_callback_param)) return false;
			if(!track_callback(t0 + AIMap.GetTileIndex(0 , 1) ,
				AIRail.RAILTRACK_NW_SE , track_callback_param)) return false;
			if(!track_callback(t0 + AIMap.GetTileIndex(0 , 2) ,
				AIRail.RAILTRACK_NW_SW , track_callback_param)) return false;
			if(!track_callback(t0 + AIMap.GetTileIndex(1 , 2) ,
				AIRail.RAILTRACK_NE_SE , track_callback_param)) return false;

			for(local i = 3 ; i <= plataform_length + 4 ; i++){
				if(!track_callback(t0 + AIMap.GetTileIndex(1 , i) ,
					AIRail.RAILTRACK_NW_SE , track_callback_param)) return false;
				if(!signal_callback(t0 + AIMap.GetTileIndex(1 , i) , AIRail.RAILTRACK_NW_SE ,
					RailroadCommon.CLOCKWISE , AIRail.SIGNALTYPE_NORMAL , signal_callback_param)) return false;
			}

			for(local i = 0 ; i < n_plataforms ; i++){
				if(!track_callback(t0 + AIMap.GetTileIndex(2 + i , 1) ,
					AIRail.RAILTRACK_NW_SE , track_callback_param)) return false;
				if(!signal_callback(t0 + AIMap.GetTileIndex(2 + i , 1) , AIRail.RAILTRACK_NW_SE ,
					RailroadCommon.COUNTERCLOCKWISE , AIRail.SIGNALTYPE_NORMAL , signal_callback_param)) return false;
				if(i > 0)
					if(!track_callback(t0 + AIMap.GetTileIndex(2 + i , 3 + plataform_length) ,
						AIRail.RAILTRACK_NW_NE , track_callback_param)) return false;
				if(i > 0 && i < n_plataforms - 1 )
					if(!track_callback(t0 + AIMap.GetTileIndex(2 + i , 3 + plataform_length) ,
						AIRail.RAILTRACK_NE_SW , track_callback_param)) return false;
				if(!track_callback(t0 + AIMap.GetTileIndex(2 + i , 2 + plataform_length) ,
					AIRail.RAILTRACK_NW_SE , track_callback_param)) return false;
				if(!signal_callback(t0 + AIMap.GetTileIndex(2 + i , 2 + plataform_length) ,
					AIRail.RAILTRACK_NW_SE , RailroadCommon.COUNTERCLOCKWISE , AIRail.SIGNALTYPE_EXIT ,
						signal_callback_param)) return false;
				if(!track_callback(t0 + AIMap.GetTileIndex(2 + i , 0) ,
					AIRail.RAILTRACK_NE_SE , track_callback_param)) return false;
			}

			if(n_plataforms > 1)
				if(!track_callback(t0 + AIMap.GetTileIndex(2 , 3 + plataform_length) ,
					AIRail.RAILTRACK_SW_SE , track_callback_param)) return false;

			if(!track_callback(t0 + AIMap.GetTileIndex(2 , 3 + plataform_length) ,
				AIRail.RAILTRACK_NW_SE , track_callback_param)) return false;
			if(!track_callback(t0 + AIMap.GetTileIndex(2 , 4 + plataform_length) ,
				AIRail.RAILTRACK_NW_SE , track_callback_param)) return false;

			if(!signal_callback(t0 + AIMap.GetTileIndex(0 , 1) , AIRail.RAILTRACK_NW_SE ,
				RailroadCommon.CLOCKWISE , AIRail.SIGNALTYPE_NORMAL , signal_callback_param)) return false;
			if(!signal_callback(t0 + AIMap.GetTileIndex(2 , 4 + plataform_length) ,
				AIRail.RAILTRACK_NW_SE , RailroadCommon.COUNTERCLOCKWISE , AIRail.SIGNALTYPE_ENTRY ,
					signal_callback_param)) return false;
		break;

		case DoubleRailroadStationBuilder.NORTH_WEST:
			for(local i = 1 ; i <= n_plataforms ; i++)
				if(!track_callback(t0 + AIMap.GetTileIndex(i , 0) ,
					AIRail.RAILTRACK_NE_SW , track_callback_param)) return false;
			if(!track_callback(t0 + AIMap.GetTileIndex(n_plataforms + 1 , 0) ,
				AIRail.RAILTRACK_NE_SE , track_callback_param)) return false;
			if(!track_callback(t0 + AIMap.GetTileIndex(n_plataforms + 1 , 1) ,
				AIRail.RAILTRACK_NW_SE , track_callback_param)) return false;
			if(!track_callback(t0 + AIMap.GetTileIndex(n_plataforms + 1 , 2) ,
				AIRail.RAILTRACK_NW_NE , track_callback_param)) return false;
			if(!track_callback(t0 + AIMap.GetTileIndex(n_plataforms , 2) ,
				AIRail.RAILTRACK_SW_SE , track_callback_param)) return false;

			for(local i = 3 ; i <= plataform_length + 4 ; i++){
				if(!track_callback(t0 + AIMap.GetTileIndex(n_plataforms , i) ,
					AIRail.RAILTRACK_NW_SE , track_callback_param)) return false;
				if(!signal_callback(t0 + AIMap.GetTileIndex(n_plataforms , i) , AIRail.RAILTRACK_NW_SE ,
					RailroadCommon.COUNTERCLOCKWISE , AIRail.SIGNALTYPE_NORMAL , signal_callback_param)) return false;
			}

			for(local i = 0 ; i < n_plataforms ; i++){
				if(!track_callback(t0 + AIMap.GetTileIndex(i , 1) ,
					AIRail.RAILTRACK_NW_SE , track_callback_param)) return false;
				if(!signal_callback(t0 + AIMap.GetTileIndex(i , 1) , AIRail.RAILTRACK_NW_SE ,
					RailroadCommon.CLOCKWISE , AIRail.SIGNALTYPE_EXIT , signal_callback_param)) return false;
				if(i < n_plataforms - 1)
					if(!track_callback(t0 + AIMap.GetTileIndex(i , 3 + plataform_length) ,
						AIRail.RAILTRACK_NW_SW , track_callback_param)) return false;
				if(i > 0 && i < n_plataforms - 1 )
					if(!track_callback(t0 + AIMap.GetTileIndex(i , 3 + plataform_length) ,
						AIRail.RAILTRACK_NE_SW , track_callback_param)) return false;
				if(!track_callback(t0 + AIMap.GetTileIndex(i , 2 + plataform_length) ,
					AIRail.RAILTRACK_NW_SE , track_callback_param)) return false;
				if(!signal_callback(t0 + AIMap.GetTileIndex(i , 2 + plataform_length) ,
					AIRail.RAILTRACK_NW_SE , RailroadCommon.CLOCKWISE , AIRail.SIGNALTYPE_NORMAL ,
						signal_callback_param)) return false;
				if(!track_callback(t0 + AIMap.GetTileIndex(i , 0) ,
					AIRail.RAILTRACK_SW_SE , track_callback_param)) return false;
			}

			if(n_plataforms > 1)
				if(!track_callback(t0 + AIMap.GetTileIndex(n_plataforms - 1 , 3 + plataform_length) ,
					AIRail.RAILTRACK_NE_SE , track_callback_param)) return false;

			if(!track_callback(t0 + AIMap.GetTileIndex(n_plataforms - 1 , 3 + plataform_length) ,
				AIRail.RAILTRACK_NW_SE , track_callback_param)) return false;
			if(!track_callback(t0 + AIMap.GetTileIndex(n_plataforms - 1 , 4 + plataform_length) ,
				AIRail.RAILTRACK_NW_SE , track_callback_param)) return false;

			if(!signal_callback(t0 + AIMap.GetTileIndex(n_plataforms - 1 , 4 + plataform_length ) ,
				AIRail.RAILTRACK_NW_SE , RailroadCommon.CLOCKWISE , AIRail.SIGNALTYPE_NORMAL ,
					signal_callback_param)) return false;
			if(!signal_callback(t0 + AIMap.GetTileIndex(n_plataforms + 1 , 1) ,
				AIRail.RAILTRACK_NW_SE , RailroadCommon.COUNTERCLOCKWISE , AIRail.SIGNALTYPE_ENTRY ,
					signal_callback_param)) return false;
		break;

		case DoubleRailroadStationBuilder.EAST_NORTH:
			for(local i = 1 ; i <= n_plataforms ; i++)
				if(!track_callback(t0 + AIMap.GetTileIndex(0 , i) ,
					AIRail.RAILTRACK_NW_SE , track_callback_param)) return false;
			if(!track_callback(t0 + AIMap.GetTileIndex(0 , 0) ,
				AIRail.RAILTRACK_SW_SE , track_callback_param)) return false;
			if(!track_callback(t0 + AIMap.GetTileIndex(1 , 0) ,
				AIRail.RAILTRACK_NE_SW , track_callback_param)) return false;
			if(!track_callback(t0 + AIMap.GetTileIndex(2 , 0) ,
				AIRail.RAILTRACK_NE_SE , track_callback_param)) return false;
			if(!track_callback(t0 + AIMap.GetTileIndex(2 , 1) ,
				AIRail.RAILTRACK_NW_SW , track_callback_param)) return false;

			for(local i = 3 ; i <= plataform_length + 4 ; i++){
				if(!track_callback(t0 + AIMap.GetTileIndex(i , 1) ,
					AIRail.RAILTRACK_NE_SW , track_callback_param)) return false;
				if(!signal_callback(t0 + AIMap.GetTileIndex(i , 1) , AIRail.RAILTRACK_NE_SW ,
					RailroadCommon.CLOCKWISE , AIRail.SIGNALTYPE_NORMAL , signal_callback_param)) return false;
			}

			for(local i = 0 ; i < n_plataforms ; i++){
				if(!track_callback(t0 + AIMap.GetTileIndex(1 , 2 + i) ,
					AIRail.RAILTRACK_NE_SW , track_callback_param)) return false;
				if(!signal_callback(t0 + AIMap.GetTileIndex(1 , 2 + i) , AIRail.RAILTRACK_NE_SW ,
					RailroadCommon.COUNTERCLOCKWISE , AIRail.SIGNALTYPE_EXIT , signal_callback_param)) return false;
				if(i > 0)
					if(!track_callback(t0 + AIMap.GetTileIndex(3 + plataform_length , 2 + i) ,
						AIRail.RAILTRACK_NW_NE , track_callback_param)) return false;
				if(i > 0 && i < n_plataforms - 1 )
					if(!track_callback(t0 + AIMap.GetTileIndex(3 + plataform_length , 2 + i) ,
						AIRail.RAILTRACK_NW_SE , track_callback_param)) return false;
				if(!track_callback(t0 + AIMap.GetTileIndex(2 + plataform_length , 2 + i) ,
					AIRail.RAILTRACK_NE_SW , track_callback_param)) return false;
				if(!signal_callback(t0 + AIMap.GetTileIndex(2 + plataform_length , 2 + i) ,
					AIRail.RAILTRACK_NE_SW , RailroadCommon.COUNTERCLOCKWISE , AIRail.SIGNALTYPE_NORMAL ,
						signal_callback_param)) return false;
				if(!track_callback(t0 + AIMap.GetTileIndex(0 , 2 + i) ,
					AIRail.RAILTRACK_NW_SW , track_callback_param)) return false;
			}

			if(n_plataforms > 1)
				if(!track_callback(t0 + AIMap.GetTileIndex(3 + plataform_length , 2) ,
					AIRail.RAILTRACK_SW_SE , track_callback_param)) return false;

			if(!track_callback(t0 + AIMap.GetTileIndex(3 + plataform_length , 2) ,
				AIRail.RAILTRACK_NE_SW , track_callback_param)) return false;
			if(!track_callback(t0 + AIMap.GetTileIndex(4 + plataform_length , 2) ,
				AIRail.RAILTRACK_NE_SW , track_callback_param)) return false;

			if(!signal_callback(t0 + AIMap.GetTileIndex(4 + plataform_length , 2) ,
				AIRail.RAILTRACK_NE_SW , RailroadCommon.COUNTERCLOCKWISE , AIRail.SIGNALTYPE_NORMAL ,
					signal_callback_param)) return false;
			if(!signal_callback(t0 + AIMap.GetTileIndex(1 , 0) ,
				AIRail.RAILTRACK_NE_SW , RailroadCommon.CLOCKWISE , AIRail.SIGNALTYPE_ENTRY ,
					signal_callback_param)) return false;
		break;

		case DoubleRailroadStationBuilder.EAST_SOUTH:
			for(local i = 1 ; i <= n_plataforms ; i++)
				if(!track_callback(t0 + AIMap.GetTileIndex(0 , i) ,
					AIRail.RAILTRACK_NW_SE , track_callback_param)) return false;
			if(!track_callback(t0 + AIMap.GetTileIndex(0 , 1 + n_plataforms) ,
				AIRail.RAILTRACK_NW_SW , track_callback_param)) return false;
			if(!track_callback(t0 + AIMap.GetTileIndex(1 , 1 + n_plataforms) ,
				AIRail.RAILTRACK_NE_SW , track_callback_param)) return false;
			if(!track_callback(t0 + AIMap.GetTileIndex(2 , 1 + n_plataforms) ,
				AIRail.RAILTRACK_NW_NE , track_callback_param)) return false;
			if(!track_callback(t0 + AIMap.GetTileIndex(2 , n_plataforms) ,
				AIRail.RAILTRACK_SW_SE , track_callback_param)) return false;

			for(local i = 3 ; i <= plataform_length + 4 ; i++){
				if(!track_callback(t0 + AIMap.GetTileIndex(i , n_plataforms) ,
					AIRail.RAILTRACK_NE_SW , track_callback_param)) return false;
				if(!signal_callback(t0 + AIMap.GetTileIndex(i , n_plataforms) , AIRail.RAILTRACK_NE_SW ,
					RailroadCommon.COUNTERCLOCKWISE , AIRail.SIGNALTYPE_NORMAL , signal_callback_param)) return false;
			}

			for(local i = 0 ; i < n_plataforms ; i++){
				if(!track_callback(t0 + AIMap.GetTileIndex(1 , i) ,
					AIRail.RAILTRACK_NE_SW , track_callback_param)) return false;
				if(!signal_callback(t0 + AIMap.GetTileIndex(1 , i) , AIRail.RAILTRACK_NE_SW ,
					RailroadCommon.CLOCKWISE , AIRail.SIGNALTYPE_NORMAL , signal_callback_param)) return false;
				if(i < n_plataforms - 1)
					if(!track_callback(t0 + AIMap.GetTileIndex(3 + plataform_length , i) ,
						AIRail.RAILTRACK_NE_SE , track_callback_param)) return false;
				if(i > 0 && i < n_plataforms - 1 )
					if(!track_callback(t0 + AIMap.GetTileIndex(3 + plataform_length , i) ,
						AIRail.RAILTRACK_NW_SE , track_callback_param)) return false;
				if(!track_callback(t0 + AIMap.GetTileIndex(2 + plataform_length , i) ,
					AIRail.RAILTRACK_NE_SW , track_callback_param)) return false;
				if(!signal_callback(t0 + AIMap.GetTileIndex(2 + plataform_length , i) ,
					AIRail.RAILTRACK_NE_SW , RailroadCommon.CLOCKWISE , AIRail.SIGNALTYPE_EXIT ,
						signal_callback_param)) return false;
				if(!track_callback(t0 + AIMap.GetTileIndex(0 , i) ,
					AIRail.RAILTRACK_SW_SE , track_callback_param)) return false;
			}

			if(n_plataforms > 1)
				if(!track_callback(t0 + AIMap.GetTileIndex(3 + plataform_length , n_plataforms - 1) ,
					AIRail.RAILTRACK_NW_SW , track_callback_param)) return false;

			if(!track_callback(t0 + AIMap.GetTileIndex(3 + plataform_length , n_plataforms - 1) ,
				AIRail.RAILTRACK_NE_SW , track_callback_param)) return false;
			if(!track_callback(t0 + AIMap.GetTileIndex(4 + plataform_length , n_plataforms - 1) ,
				AIRail.RAILTRACK_NE_SW , track_callback_param)) return false;

			if(!signal_callback(t0 + AIMap.GetTileIndex(4 + plataform_length , n_plataforms - 1) ,
				AIRail.RAILTRACK_NE_SW , RailroadCommon.CLOCKWISE , AIRail.SIGNALTYPE_ENTRY ,
					signal_callback_param)) return false;
			if(!signal_callback(t0 + AIMap.GetTileIndex(1 , 1 + n_plataforms) ,
				AIRail.RAILTRACK_NE_SW , RailroadCommon.COUNTERCLOCKWISE , AIRail.SIGNALTYPE_NORMAL ,
					signal_callback_param)) return false;
		break;

		case DoubleRailroadStationBuilder.WEST_SOUTH:
			for(local i = 1 ; i <= n_plataforms ; i++)
				if(!track_callback(t0 + AIMap.GetTileIndex(plataform_length + 6 , i) ,
					AIRail.RAILTRACK_NW_SE , track_callback_param)) return false;
			if(!track_callback(t0 + AIMap.GetTileIndex(plataform_length + 6 , 1 + n_plataforms) ,
				AIRail.RAILTRACK_NW_NE , track_callback_param)) return false;
			if(!track_callback(t0 + AIMap.GetTileIndex(plataform_length + 5 , 1 + n_plataforms) ,
				AIRail.RAILTRACK_NE_SW , track_callback_param)) return false;
			if(!track_callback(t0 + AIMap.GetTileIndex(plataform_length + 4 , 1 + n_plataforms) ,
				AIRail.RAILTRACK_NW_SW , track_callback_param)) return false;
			if(!track_callback(t0 + AIMap.GetTileIndex(plataform_length + 4 , n_plataforms) ,
				AIRail.RAILTRACK_NE_SE , track_callback_param)) return false;

			for(local i = 2 ; i <= plataform_length + 3 ; i++){
				if(!track_callback(t0 + AIMap.GetTileIndex(i , n_plataforms) ,
					AIRail.RAILTRACK_NE_SW , track_callback_param)) return false;
				if(!signal_callback(t0 + AIMap.GetTileIndex(i , n_plataforms) , AIRail.RAILTRACK_NE_SW ,
					RailroadCommon.COUNTERCLOCKWISE , AIRail.SIGNALTYPE_NORMAL , signal_callback_param)) return false;
			}

			for(local i = 0 ; i < n_plataforms ; i++){
				if(!track_callback(t0 + AIMap.GetTileIndex(4 , i) ,
					AIRail.RAILTRACK_NE_SW , track_callback_param)) return false;
				if(!signal_callback(t0 + AIMap.GetTileIndex(4 , i) , AIRail.RAILTRACK_NE_SW ,
					RailroadCommon.CLOCKWISE , AIRail.SIGNALTYPE_NORMAL , signal_callback_param)) return false;
				if(i < n_plataforms - 1)
					if(!track_callback(t0 + AIMap.GetTileIndex(3 , i) ,
						AIRail.RAILTRACK_SW_SE , track_callback_param)) return false;
				if(i > 0 && i < n_plataforms - 1 )
					if(!track_callback(t0 + AIMap.GetTileIndex(3 , i) ,
						AIRail.RAILTRACK_NW_SE , track_callback_param)) return false;
				if(!track_callback(t0 + AIMap.GetTileIndex(5 + plataform_length , i) ,
					AIRail.RAILTRACK_NE_SW , track_callback_param)) return false;
				if(!signal_callback(t0 + AIMap.GetTileIndex(5 + plataform_length , i) ,
					AIRail.RAILTRACK_NE_SW , RailroadCommon.CLOCKWISE , AIRail.SIGNALTYPE_EXIT ,
					signal_callback_param)) return false;
				if(!track_callback(t0 + AIMap.GetTileIndex(6 + plataform_length , i) ,
					AIRail.RAILTRACK_NE_SE , track_callback_param)) return false;
			}

			if(n_plataforms > 1)
				if(!track_callback(t0 + AIMap.GetTileIndex(3 , n_plataforms - 1) ,
					AIRail.RAILTRACK_NW_NE , track_callback_param)) return false;

			if(!track_callback(t0 + AIMap.GetTileIndex(2 , n_plataforms - 1) ,
				AIRail.RAILTRACK_NE_SW , track_callback_param)) return false;
			if(!track_callback(t0 + AIMap.GetTileIndex(3 , n_plataforms - 1) ,
				AIRail.RAILTRACK_NE_SW , track_callback_param)) return false;

			if(!signal_callback(t0 + AIMap.GetTileIndex(plataform_length + 5 , 1 + n_plataforms) ,
				AIRail.RAILTRACK_NE_SW , RailroadCommon.COUNTERCLOCKWISE , AIRail.SIGNALTYPE_ENTRY ,
					signal_callback_param)) return false;
			if(!signal_callback(t0 + AIMap.GetTileIndex(2 , n_plataforms - 1) ,
				AIRail.RAILTRACK_NE_SW , RailroadCommon.CLOCKWISE , AIRail.SIGNALTYPE_NORMAL ,
					signal_callback_param)) return false;
		break;

		case DoubleRailroadStationBuilder.WEST_NORTH:
			for(local i = 1 ; i <= n_plataforms ; i++)
				if(!track_callback(t0 + AIMap.GetTileIndex(6 + plataform_length , i) ,
					AIRail.RAILTRACK_NW_SE , track_callback_param)) return false;
			if(!track_callback(t0 + AIMap.GetTileIndex(6 + plataform_length , 0) ,
				AIRail.RAILTRACK_NE_SE , track_callback_param)) return false;
			if(!track_callback(t0 + AIMap.GetTileIndex(5 + plataform_length , 0) ,
				AIRail.RAILTRACK_NE_SW , track_callback_param)) return false;
			if(!track_callback(t0 + AIMap.GetTileIndex(4 + plataform_length , 0) ,
				AIRail.RAILTRACK_SW_SE , track_callback_param)) return false;
			if(!track_callback(t0 + AIMap.GetTileIndex(4 + plataform_length , 1) ,
				AIRail.RAILTRACK_NW_NE , track_callback_param)) return false;

			for(local i = 2 ; i <= plataform_length + 3 ; i++){
				if(!track_callback(t0 + AIMap.GetTileIndex(i , 1) ,
					AIRail.RAILTRACK_NE_SW , track_callback_param)) return false;
				if(!signal_callback(t0 + AIMap.GetTileIndex(i , 1) , AIRail.RAILTRACK_NE_SW ,
					RailroadCommon.CLOCKWISE , AIRail.SIGNALTYPE_NORMAL , signal_callback_param)) return false;
			}

			for(local i = 0 ; i < n_plataforms ; i++){
				if(!track_callback(t0 + AIMap.GetTileIndex(4 , 2 + i) ,
					AIRail.RAILTRACK_NE_SW , track_callback_param)) return false;
				if(!signal_callback(t0 + AIMap.GetTileIndex(4 , 2 + i) , AIRail.RAILTRACK_NE_SW ,
					RailroadCommon.COUNTERCLOCKWISE , AIRail.SIGNALTYPE_EXIT , signal_callback_param)) return false;
				if(i > 0)
					if(!track_callback(t0 + AIMap.GetTileIndex(3 , 2 + i) ,
						AIRail.RAILTRACK_NW_SW , track_callback_param)) return false;
				if(i > 1 )
					if(!track_callback(t0 + AIMap.GetTileIndex(3 , 1 + i) ,
						AIRail.RAILTRACK_NW_SE , track_callback_param)) return false;
				if(!track_callback(t0 + AIMap.GetTileIndex(5 + plataform_length , 2 + i) ,
					AIRail.RAILTRACK_NE_SW , track_callback_param)) return false;
				if(!signal_callback(t0 + AIMap.GetTileIndex(5 + plataform_length , 2 + i) ,
					AIRail.RAILTRACK_NE_SW , RailroadCommon.COUNTERCLOCKWISE , AIRail.SIGNALTYPE_NORMAL ,
						signal_callback_param)) return false;
				if(!track_callback(t0 + AIMap.GetTileIndex(6 + plataform_length , 2 + i) ,
					AIRail.RAILTRACK_NW_NE , track_callback_param)) return false;
			}

			if(n_plataforms > 1)
				if(!track_callback(t0 + AIMap.GetTileIndex(3 , 2) ,
					AIRail.RAILTRACK_NE_SE , track_callback_param)) return false;

			if(!track_callback(t0 + AIMap.GetTileIndex(2 , 2) ,
				AIRail.RAILTRACK_NE_SW , track_callback_param)) return false;
			if(!track_callback(t0 + AIMap.GetTileIndex(3 , 2) ,
				AIRail.RAILTRACK_NE_SW , track_callback_param)) return false;

			if(!signal_callback(t0 + AIMap.GetTileIndex(2 , 2) ,
				AIRail.RAILTRACK_NE_SW , RailroadCommon.COUNTERCLOCKWISE , AIRail.SIGNALTYPE_ENTRY ,
					signal_callback_param)) return false;
			if(!signal_callback(t0 + AIMap.GetTileIndex(5 + plataform_length , 0) ,
				AIRail.RAILTRACK_NE_SW , RailroadCommon.CLOCKWISE , AIRail.SIGNALTYPE_NORMAL ,
					signal_callback_param)) return false;
		break;
	}

	return true;
}

function DoubleRailroadStationBuilder::BuildStationTracks(station_information){
	switch(station_type){
		case PRE_SIGNALED:
			return IterateOverTracksOfPreSignaledStation(station_information ,
				DoubleRailroadStationBuilder.BuildRailTrack , null ,
				DoubleRailroadStationBuilder.BuildRailSignal , null);
		break;
		case TERMINUS:
			return IterateOverTracksOfTerminusStation(station_information ,
				DoubleRailroadStationBuilder.BuildRailTrack , null ,
				DoubleRailroadStationBuilder.BuildRailSignal , null);
		break;
	}
}

function DoubleRailroadStationBuilder::ConvertRailroadStation(station_information , rail_type){
	local tile = station_information.station_tile;
	local station_direction;
	if(station_information.exit_direction == Direction.SOUTH ||
		station_information.exit_direction == Direction.NORTH) station_direction = AIRail.RAILTRACK_NW_SE;
	else station_direction = AIRail.RAILTRACK_NE_SW;
	if(station_direction == AIRail.RAILTRACK_NE_SW){
		tile += AIMap.GetTileIndex(station_information.plataform_length - 1 ,
			station_information.n_plataforms - 1);
	}else{
		tile += AIMap.GetTileIndex(station_information.n_plataforms - 1 ,
			station_information.plataform_length - 1);
	}
	AIRail.ConvertRailType(station_information.station_tile , tile , rail_type);
	switch(station_information.station_type){
		case DoubleRailroadStationBuilder.PRE_SIGNALED:
			DoubleRailroadStationBuilder.IterateOverTracksOfPreSignaledStation(station_information ,
				DoubleRailroadStationBuilder.ConvertRailTrack , rail_type ,
				DoubleRailroadStationBuilder.DummyRailSignal , null);
		break;
		case DoubleRailroadStationBuilder.TERMINUS:
			DoubleRailroadStationBuilder.IterateOverTracksOfTerminusStation(station_information ,
				DoubleRailroadStationBuilder.ConvertRailTrack , rail_type ,
				DoubleRailroadStationBuilder.DummyRailSignal , null);
		break;
	}
}

function DoubleRailroadStationBuilder::DemolishRailroadStation(station_information){
	switch(station_information.station_type){
		case DoubleRailroadStationBuilder.PRE_SIGNALED:
			DoubleRailroadStationBuilder.IterateOverTracksOfPreSignaledStation(station_information ,
				DoubleRailroadStationBuilder.DemolishRailTrack , null ,
				DoubleRailroadStationBuilder.DummyRailSignal , null);
		break;
		case DoubleRailroadStationBuilder.TERMINUS:
			DoubleRailroadStationBuilder.IterateOverTracksOfTerminusStation(station_information ,
				DoubleRailroadStationBuilder.DemolishRailTrack , null ,
				DoubleRailroadStationBuilder.DummyRailSignal , null);
		break;
	}
	AITile.DemolishTile(station_information.station_tile);
}

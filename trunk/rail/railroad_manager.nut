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


class RailroadManager {
	/* Public: */
	constructor(){
		railroad_routes_marked_to_demolish = array(0);
		railroad_routes = array(0);
		pending_actions = array(0);
		n_railroad_routes_blocked = 0;
		::ai_instance.scheduler.CreateTask(AdjustNumTrainsInRailroadRoutes , this , Scheduler.WEEKLY_INTERVAL);
		::ai_instance.scheduler.CreateTask(InvestMoneyOnRailroads , this , Scheduler.TRIWEEKLY_INTERVAL);
		::ai_instance.scheduler.CreateTask(MaintainRailroadRoutes , this , Scheduler.BIWEEKLY_INTERVAL);
	}
	function InformIndustryClosure(industry_id);

	/* Private: */
	/* Constants: */
	static PLATFORM_LENGTH = 5;
	static DESTINATION_NUM_PLATFORMS = 2;
	static SOURCE_NUM_PLATFORMS = 2;

	static INDUSTRY_MINIMUM_PRODUCTION = 88;

	static RAILROAD_ROUTE_DISTANCE = 250;
	static RAILROAD_ROUTE_DISTANCE_TOLERANCE = 80;

	static JUNCTION_GAP_SIZE = 20;
	static MAXIMUM_DISTANCE_JUNCTION_POINT = 150;

	static STATION_TERRAFORMING_MAXIMUM_COST = 30000;

	static MINIMUM_MONEY_INVEST = 250000;
	static MININUM_MONEY_CHANGE_LOCOMOTIVE = 150000;

	static INTERVAL_CHANGE_LOCOMOTIVE = 5 * 365;

	static MAXIMUM_NUM_ROUTE_SOURCES = 5;

	static MININUM_NUM_SAMPLES = 18

	railroad_routes_marked_to_demolish = null;
	railroad_routes = null;
	pending_actions = null;
	n_railroad_routes_blocked = null;

	function InvestMoneyOnIndustry(just_primary , reservation_id);
	function BuildNewIndustryRailroadRoute(industry , cargo , reservation_id);
	function ExpandIndustryRailroadRoute(industry , cargo , railroad_route , reservation_id);
	function DemolishIndustryRailroadRoute(railroad_route);
	function MarkRailroadRouteToBeDemolished(railroad_route_index);
	function DemolishMarkedIndustryRailroadRoutes();
	function BuildNewTrain(railroad_route , source);
	function CalculateRailroadRouteMaxNumTrains(railroad_route , source);
	function GetCurrentSourceNumTrains(railroad_route , source);
	function GetNumTrainsNegativeProfit(railroad_route , source);
	function IsIndustryAlreadyInRailroadRoute(industry);
	function SellRailroadRouteVehicles(railroad_route , next_action);
	function AdjustNumTrainsInRailroadRoutes(self);
	function InsertAction(action);
	function InvestMoneyOnRailroads(self);
	function ExecuteActions(self);

	static function GetOrdedCargos();
	static function ChooseWagon(cargo , rail_type);
	static function CalculateNumberOfWagons(locomotive_id , wagon_id , plataform_length);
}

class Source {
	s_industry = null;
	ssi = null;
	cargo = null;
	wagon_id = null;
	group_id = null;
	double_railroad = null;
	num_wagons = null;

	n_trains = null;
	last_check = null;
	n_trains_at_station = null;
	n_samples = null;

	constructor(){
		last_check = AIDate.GetCurrentDate();
		n_trains_at_station = n_samples = 0;
	}
}

class RailroadRoute {
	d_industry = null;
	dsi = null;
	locomotive_id = null;
	rail_type = null;
	sources = null;
	last_locomotive_update = null;
	is_blocked = null;

	constructor(){
		is_blocked = false;
	}
}

/* Actions: */
class Action {
	/* Public: */
	function Block();
	function Unblock();
	function Finished();

	/* Private: */
	railroad_route = null;
	next_action = null;
}

class ActionSellRailroadRouteVehicles extends Action {
	/* Public: */
	function Block(){
		if(must_block)
			railroad_route.is_blocked = true;
		return must_block;
	}
	function Unblock(){
		return false;
	}
	function Finished(){
		return finished || !must_block;
	}

	/* Private: */
	function VehiclesSoldCallback(self){
		self.finished = true;
	}
	must_block = null;
	finished = null;
}

class ActionConvertRailroadRouteRailType extends Action {
	/* Public: */
	function Finished(){
		foreach(source in railroad_route.sources){
			DoubleRailroadStationBuilder.ConvertRailroadStation(source.ssi , railroad_route.rail_type);
			DoubleRailroadBuilder.ConvertTrack(source.double_railroad.path , railroad_route.rail_type);
		}
		DoubleRailroadStationBuilder.ConvertRailroadStation(railroad_route.dsi , railroad_route.rail_type);
		return true;
	}

	function Unblock(){
		railroad_route.is_blocked = false;
		return true;
	}
	/* Private: */
	old_rail_type = null;
}

class ActionDemolishRailroadRoute extends Action {
	/* Public: */
	function Finished(){
		foreach(source in railroad_route.sources){
			DoubleRailroadStationBuilder.DemolishRailroadStation(source.ssi);
			DoubleRailroadBuilder.DemolishDoubleRailroad(source.double_railroad.path);
		}
		DoubleRailroadStationBuilder.DemolishRailroadStation(railroad_route.dsi);
		return true;
	}
	function Unblock(){
		railroad_route.is_blocked = false;
		return true;
	}
}

class ActionBuildRouteDoubleRailroad extends Action {
	/* Public: */
	function Block(){
		return true;
	}
	function Unblock(){
		return true;
	}
	function Finished(){
		if(drrb == null){
			local dtp = ::ai_instance.dtp;
			drrb = DoubleRailroadBuilder(source.ssi.exit_part_tile ,
				dtp.GetOppositePartTile(railroad_route.dsi.exit_part_tile , railroad_route.dsi.exit_part) ,
				source.ssi.exit_part ,
				dtp.GetOppositePart(railroad_route.dsi.exit_part));
			LogMessagesManager.PrintLogMessage(drrb.tostring());
		}

		source.double_railroad = drrb.BuildTrack();
		if(source.double_railroad == null){
			local industry_manager = ::ai_instance.industry_manager;
			DoubleRailroadStationBuilder.DemolishRailroadStation(source.ssi);
			DoubleRailroadStationBuilder.DemolishRailroadStation(railroad_route.dsi);
			/* TODO: The problem can be at destination station. */
			industry_manager.BlockIndustry(source.s_industry);
			::ai_instance.money_manager.ReleaseReservation(reservation_id);
			return true;
		}else if(source.double_railroad == false) return false;

		source.group_id = AIGroup.CreateGroup(AIVehicle.VT_RAIL);

		railroad_route.last_locomotive_update = AIDate.GetCurrentDate();
		railroad_route.sources = [source];
		railroad_manager.railroad_routes.push(railroad_route);
		::ai_instance.money_manager.ReleaseReservation(reservation_id);
		return true;
	}

	/* Private: */
	source = null;
	railroad_manager = null;
	reservation_id = null;
	drrb = null;
}

class ActionBuildRouteExpasionDoubleRailroad extends Action {
	/* Public: */
	function Block(){
		railroad_route.is_blocked = true;
		return true;
	}
	function Unblock(){
		railroad_route.is_blocked = false;
		return true;
	}
	function Finished(){
		if(drrb == null){
			local dtp = ::ai_instance.dtp;
			drrb = DoubleRailroadBuilder(source.ssi.exit_part_tile ,
				dtp.parts[junction_information.junction_part_index].previous_part_offset +
				junction_information.tile ,
				source.ssi.exit_part ,
				dtp.parts[junction_information.junction_part_index].previous_part);
			LogMessagesManager.PrintLogMessage(drrb.tostring());
		}
		source.double_railroad = drrb.BuildTrack();

		if(source.double_railroad == null){
			local industry_manager = ::ai_instance.industry_manager;
			DoubleRailroadStationBuilder.DemolishRailroadStation(source.ssi);
			DoubleJunctionBuilder.DemolishJunction(junction_information);
			industry_manager.BlockIndustry(source.s_industry);
			::ai_instance.money_manager.ReleaseReservation(reservation_id);
			return true;
		}else if(source.double_railroad == false) return false;

		source.wagon_id = RailroadManager.ChooseWagon(source.cargo , railroad_route.rail_type);
		source.group_id = AIGroup.CreateGroup(AIVehicle.VT_RAIL);
		railroad_route.sources.push(source);
		::ai_instance.money_manager.ReleaseReservation(reservation_id);
		return true;
	}

	/* Private: */
	junction_information = null;
	source = null;
	reservation_id = null;
	drrb = null;
}

class LocomotiveValuator {
	largest_price = null;
	largest_reliability = null;
	largest_max_speed = null;
	largest_power = null;
	largest_weight = null;

	constructor(engines){
		engines.Valuate(AIEngine.GetPrice);
		engines.Sort(AIAbstractList.SORT_BY_VALUE , false);
		largest_price = engines.GetValue(engines.Begin());

		engines.Valuate(AIEngine.GetReliability);
		engines.Sort(AIAbstractList.SORT_BY_VALUE , false);
		largest_reliability = engines.GetValue(engines.Begin());

		engines.Valuate(AIEngine.GetMaxSpeed);
		engines.Sort(AIAbstractList.SORT_BY_VALUE , false);
		largest_max_speed = engines.GetValue(engines.Begin());

		engines.Valuate(AIEngine.GetPower);
		engines.Sort(AIAbstractList.SORT_BY_VALUE , false);
		largest_power = engines.GetValue(engines.Begin());

		engines.Valuate(AIEngine.GetWeight);
		engines.Sort(AIAbstractList.SORT_BY_VALUE , false);
		largest_weight = engines.GetValue(engines.Begin());
	}

	function _tostring(){
		local s = "Largest price: " + largest_price.tostring();
		s += " Largest reliability: " + largest_reliability.tostring();
		s += " Largest max speed: " + largest_max_speed.tostring();
		s += " Largest power: " + largest_power.tostring();
		s += " Largest weight: " + largest_weight.tostring();
		return s;
	}

	static function ValuateLocomotive(id , lv){
		local v = 1.0;
		v *= AIEngine.GetReliability(id).tofloat() / lv.largest_reliability.tofloat();
		v *= AIEngine.GetMaxSpeed(id).tofloat() / lv.largest_max_speed.tofloat();
		v *= AIEngine.GetWeight(id).tofloat() / lv.largest_weight.tofloat();
		v *= AIEngine.GetPower(id).tofloat() / lv.largest_power.tofloat();
		v /= (AIEngine.GetPrice(id).tofloat() / lv.largest_price.tofloat());
		v *= 1000;
		return v.tointeger();
	}
}

class RailTypeValuator {
	lv = null;

	constructor(){
		local engines = AIEngineList(AIVehicle.VT_RAIL);
		engines.Valuate(AIEngine.IsValidEngine);
		engines.KeepValue(1);
		engines.Valuate(AIEngine.IsWagon);
		engines.KeepValue(0);
		lv = LocomotiveValuator(engines);
	}

	static function ValuateRailType(id , rtv){
		local v = 0;
		local engines = AIEngineList(AIVehicle.VT_RAIL);
		engines.Valuate(AIEngine.IsValidEngine);
		engines.KeepValue(1);
		engines.Valuate(AIEngine.IsWagon);
		engines.KeepValue(0);
		engines.Valuate(AIEngine.CanRunOnRail , id);
		engines.KeepValue(1);
		engines.Valuate(LocomotiveValuator.ValuateLocomotive , rtv.lv);
		engines.Sort(AIAbstractList.SORT_BY_VALUE , false);
		return engines.GetValue(engines.Begin());
	}
}

class IndustryValuator {
	static function ValuateIndustry(industries){
		local cargos = RailroadManager.GetOrdedCargos();

		foreach(industry in industries){
			local v , last_month_production , stations_around;
			last_month_production = AIIndustry.GetLastMonthProduction(industry.industry_id ,
				industry.cargo).tofloat();
			if(last_month_production == 0){
				industry.valuation = 0;
				continue;
			}
			v = last_month_production.tofloat();
			v *= 1.0 - AIIndustry.GetLastMonthTransported(industry.industry_id ,
				industry.cargo).tofloat() / last_month_production.tofloat();
			stations_around = AIIndustry.GetAmountOfStationsAround(industry.industry_id);
			v /= (stations_around.tofloat() + 1.0);
			v *= cargos.GetValue(industry.cargo).tofloat();
			industry.valuation = v.tointeger();
		}
		industries.sort(IndustryUsage.compare);
	}
}

function RailroadManager::SellRailroadRouteVehicles(railroad_route , next_action){
	local route_vehicles = AIList();
	local action_srrv = ActionSellRailroadRouteVehicles();
	local vehicle_seller = ::ai_instance.vehicle_seller;

	action_srrv.railroad_route = railroad_route;
	action_srrv.next_action = next_action;
	action_srrv.must_block = next_action != null;
	action_srrv.finished = false;
	foreach(source in railroad_route.sources){
		local vehicles = AIVehicleList_Group(source.group_id);
		source.num_wagons = null;
		route_vehicles.AddList(vehicles);
		source.wagon_id = ChooseWagon(source.cargo , railroad_route.rail_type);
	}
	/* Now sell the old trains. */
	vehicle_seller.SellVehicles(route_vehicles , action_srrv.VehiclesSoldCallback , action_srrv);
	InsertAction(action_srrv);
}

function RailroadManager::MarkRailroadRouteToBeDemolished(railroad_route_index){
	railroad_routes_marked_to_demolish.push(railroad_route_index);
}

function RailroadManager::DemolishMarkedIndustryRailroadRoutes(){
	railroad_routes_marked_to_demolish.sort();
	railroad_routes_marked_to_demolish.reverse();
	while(railroad_routes_marked_to_demolish.len() != 0){
		local length = railroad_routes.len();
		local railroad_route_index = railroad_routes_marked_to_demolish.pop();
		local railroad_route = railroad_routes[railroad_route_index];

		/* Remove the element from the array. */
		if(railroad_route_index + 1 != length)
			railroad_routes[railroad_route_index] = railroad_routes[length - 1];
		railroad_routes.pop();

		DemolishIndustryRailroadRoute(railroad_route);
	}
}

function RailroadManager::DemolishIndustryRailroadRoute(railroad_route){
	local action_drr = ActionDemolishRailroadRoute();

	action_drr.railroad_route = railroad_route;
	action_drr.next_action = null;
	SellRailroadRouteVehicles(railroad_route , action_drr);

	foreach(source in railroad_route.sources){
		AIGroup.DeleteGroup(source.group_id);
	}
}

function RailroadManager::IsIndustryAlreadyInRailroadRoute(industry){
	if(railroad_routes == null) return false;
	foreach(route in railroad_routes){
		foreach(source in route.sources){
			if(source.s_industry == industry) return true;
		}
	}
	return false;
}

function RailroadManager::GetOrdedCargos(){
	local cargos = AICargoList();
	cargos.Valuate(AICargo.IsValidCargo);
	cargos.KeepValue(1);
	cargos.Valuate(AICargo.HasCargoClass , AICargo.CC_PASSENGERS);
	cargos.KeepValue(0);
	cargos.Valuate(AICargo.HasCargoClass , AICargo.CC_MAIL);
	cargos.KeepValue(0);
	cargos.Valuate(AICargo.GetCargoIncome , 20 , 10);
	cargos.Sort(AIAbstractList.SORT_BY_VALUE , false);
	if(cargos.Count() == 0) throw("There is no cargos I can deal with.");
	return cargos;
}

function RailroadManager::ChooseWagon(cargo , rail_type){
	local engines = AIEngineList(AIVehicle.VT_RAIL);
	engines.Valuate(AIEngine.IsValidEngine);
	engines.KeepValue(1);
	engines.Valuate(AIEngine.IsWagon);
	engines.KeepValue(1);
	engines.Valuate(AIEngine.CanRunOnRail , rail_type);
	engines.KeepValue(1);
	engines.Valuate(AIEngine.CanRefitCargo , cargo);
	engines.KeepValue(1);
	engines.Valuate(AIEngine.GetPrice);
	engines.Sort(AIAbstractList.SORT_BY_VALUE , true);
	if(engines.Count() == 0) return null;
	return engines.Begin();
}

function RailroadManager::ChooseLocomotive(cargo , rail_type , locomotive_max_price){
	local engines = AIEngineList(AIVehicle.VT_RAIL);
	engines.Valuate(AIEngine.IsValidEngine);
	engines.KeepValue(1);
	engines.Valuate(AIEngine.IsWagon);
	engines.KeepValue(0);
	engines.Valuate(AIEngine.CanRunOnRail , rail_type);
	engines.KeepValue(1);
	local lv = LocomotiveValuator(engines);
	engines.Valuate(LocomotiveValuator.ValuateLocomotive , lv);
	engines.Sort(AIAbstractList.SORT_BY_VALUE , false);
	return engines.Begin();
}

function RailroadManager::GetCurrentSourceNumTrains(railroad_route , source){
	return AIGroup.GetNumEngines(source.group_id , railroad_route.locomotive_id);
}

/* Return the number of trains that had a negative profit on last year and have a
	negative profit on the current year. */
function RailroadManager::GetNumTrainsNegativeProfit(railroad_route , source){
	local source_vehicles = AIVehicleList_Group(source.group_id);
	source_vehicles.Valuate(AIVehicle.GetAge);
	source_vehicles.RemoveBelowValue(365 * 2);
	source_vehicles.Valuate(AIVehicle.GetProfitLastYear);
	source_vehicles.RemoveAboveValue(-1);
	source_vehicles.Valuate(AIVehicle.GetProfitThisYear);
	source_vehicles.RemoveAboveValue(-1);
	return source_vehicles.Count();
}

/* TODO: Use parameters to configure this function: terraforming. */
/* TODO: Deal with secondary industries. */
function RailroadManager::InvestMoneyOnIndustry(just_primary , reservation_id){
	local cargos = GetOrdedCargos();
	local rtv = RailTypeValuator();
	local rail_types = AIRailTypeList();
	local industry_manager = ::ai_instance.industry_manager;
	local selected_industries = array(0);
	local aux;

	rail_types.Valuate(AIRail.IsRailTypeAvailable);
	rail_types.KeepValue(1);
	rail_types.Valuate(RailTypeValuator.ValuateRailType , rtv);
	rail_types.Sort(AIAbstractList.SORT_BY_VALUE , false);

	foreach(cargo , dummy in cargos){
		/* Select a railtype. */
		foreach(rail_type , dummy in rail_types){
			/* Try to find a wagon. */
			aux = ChooseWagon(cargo , rail_type);
			if(aux == null) continue;
			/* Try to find a locomotive. */
			aux = ChooseLocomotive(cargo , rail_type , 0);
			if(aux == null) continue;
			/* Try to find the industries. */
			local s_industries = AIIndustryList_CargoProducing(cargo);
			local d_industries = AIIndustryList_CargoAccepting(cargo);
			if(d_industries.Count() == 0) continue; /* TODO: Destination may be a city. */

			s_industries.Valuate(AIIndustry.IsValidIndustry);
			s_industries.KeepValue(1);
			s_industries.Valuate(AIIndustry.IsBuiltOnWater);
			s_industries.KeepValue(0);
			if(s_industries.Count() == 0) continue;

			foreach(industry , dummy in s_industries){
				if(industry_manager.IsIndustryBlocked(industry) ||
					IsIndustryAlreadyInRailroadRoute(industry) ||
					(just_primary && !AIIndustryType.IsRawIndustry(AIIndustry.GetIndustryType(industry))) ||
					(railroad_routes.len() != 0 && /* TODO: Use the amount of cargo transported. */
						AIIndustry.GetLastMonthProduction(industry , cargo) < INDUSTRY_MINIMUM_PRODUCTION)) continue;
				selected_industries.push(IndustryUsage(industry , cargo));
			}
		}
	}
 	IndustryValuator.ValuateIndustry(selected_industries);
	foreach(industry in selected_industries){
		/* First, try to connect the industry using a existent route. */
		local industry_tile = AIIndustry.GetLocation(industry.industry_id);
		if(railroad_routes.len() != 0){
			local expasions_distance = AIList();
			for(local i = 0 ; i < railroad_routes.len() ; i++){
				local railroad_route = railroad_routes[i];
				local possible_junction , djb;
				local distance;
				local paths = array(0);

				/* Limit the number of sources to avoid traffic jams. */
				if(railroad_route.sources.len() >= MAXIMUM_NUM_ROUTE_SOURCES) continue;
				/* Does the industry accept the production? */
				if(!AIIndustry.IsCargoAccepted(railroad_route.d_industry , industry.cargo)) continue;

				distance = AITile.GetDistanceManhattanToTile(industry_tile ,
					AIIndustry.GetLocation(railroad_route.d_industry));
				if((distance - RAILROAD_ROUTE_DISTANCE_TOLERANCE) <= RAILROAD_ROUTE_DISTANCE &&
					RAILROAD_ROUTE_DISTANCE <= (distance + RAILROAD_ROUTE_DISTANCE_TOLERANCE)){
					foreach(source in railroad_route.sources){
						paths.push(source.double_railroad.path);
					}
					djb = DoubleJunctionBuilder(paths , industry_tile , JUNCTION_GAP_SIZE ,
						MAXIMUM_DISTANCE_JUNCTION_POINT);
					possible_junction = djb.GetBestPossibleJunction();
					if(possible_junction != null){
						local distance = possible_junction.distance;
						expasions_distance.AddItem(i , distance.tointeger());
					}
				}
			}
			if(expasions_distance.Count() != 0){
				expasions_distance.Sort(AIAbstractList.SORT_BY_VALUE , true);
				foreach(route_index , dummy in expasions_distance){
					local railroad_route = railroad_routes[route_index];
					if(ExpandIndustryRailroadRoute(industry.industry_id , industry.cargo ,
						railroad_route , reservation_id))
						return true;
				}
			}
		}
		if(BuildNewIndustryRailroadRoute(industry.industry_id , industry.cargo , reservation_id)) return true;
	}
	::ai_instance.money_manager.ReleaseReservation(reservation_id);
	return false;
}

/* TODO: Use parameters to configure this function: terraforming. */
/* TODO: Deal with secondary industries. */
function RailroadManager::BuildNewIndustryRailroadRoute(industry_id , cargo , reservation_id){
	local industry_manager = ::ai_instance.industry_manager;
	local rtv = RailTypeValuator();
	local railroad_route = RailroadRoute();
	local rail_types = AIRailTypeList();
	local source = Source();

	rail_types.Valuate(AIRail.IsRailTypeAvailable);
	rail_types.KeepValue(1);
	rail_types.Valuate(RailTypeValuator.ValuateRailType , rtv);
	rail_types.Sort(AIAbstractList.SORT_BY_VALUE , false);

	/* Select a railtype. */
	foreach(rail_type, dummy in rail_types){
		/* Try to find a wagon. */
		source.wagon_id = ChooseWagon(cargo , rail_type);
		if(source.wagon_id == null) continue;
		/* Try to find a locomotive. */
		railroad_route.locomotive_id = ChooseLocomotive(cargo , rail_type , 0);
		if(railroad_route.locomotive_id == null) continue;
		railroad_route.rail_type = rail_type;
		AIRail.SetCurrentRailType(rail_type);
		break;
	}
	if(railroad_route.rail_type == null) return false;
	/* Try to find the destination industry. */
	local d_industries = AIIndustryList_CargoAccepting(cargo);
	if(d_industries.Count() == 0) return false;
	source.s_industry = industry_id;

	foreach(d_industry , dummy in d_industries){
		if(industry_manager.IsIndustryBlocked(d_industry)) continue;
		local distance = AITile.GetDistanceManhattanToTile(AIIndustry.GetLocation(industry_id) ,
			AIIndustry.GetLocation(d_industry));
		if((distance - RAILROAD_ROUTE_DISTANCE_TOLERANCE) <= RAILROAD_ROUTE_DISTANCE &&
			RAILROAD_ROUTE_DISTANCE <= (distance + RAILROAD_ROUTE_DISTANCE_TOLERANCE)){
			railroad_route.d_industry = d_industry;
			/* Now try to construct the route. */
			local ssi , dsi;
			/* Build the stations. */
			{
				local s_m_exit_direction , d_m_exit_direction , s_s_exit_direction ,
					d_s_exit_direction , directions;

				directions = Direction.GetDirectionsToTile(AIIndustry.GetLocation(source.s_industry) ,
					AIIndustry.GetLocation(railroad_route.d_industry));
				s_m_exit_direction = directions.first;
				s_s_exit_direction = directions.second;
				d_m_exit_direction = Direction.GetOppositeDirection(s_m_exit_direction);
				d_s_exit_direction = Direction.GetOppositeDirection(s_s_exit_direction);

				local s = DoubleRailroadStationBuilder(SOURCE_NUM_PLATFORMS , PLATFORM_LENGTH , s_m_exit_direction ,
					s_s_exit_direction , STATION_TERRAFORMING_MAXIMUM_COST , DoubleRailroadStationBuilder.TERMINUS);
				ssi = s.BuildIndustryRailroadStation(source.s_industry , true);

				if(ssi != null){
					local d = DoubleRailroadStationBuilder(DESTINATION_NUM_PLATFORMS , PLATFORM_LENGTH ,
						d_m_exit_direction , d_s_exit_direction , STATION_TERRAFORMING_MAXIMUM_COST ,
						DoubleRailroadStationBuilder.PRE_SIGNALED);
					dsi = d.BuildIndustryRailroadStation(railroad_route.d_industry , false);
					if(dsi == null){
						DoubleRailroadStationBuilder.DemolishRailroadStation(ssi);
						industry_manager.BlockIndustry(railroad_route.d_industry);
					}
				}else{
					industry_manager.BlockIndustry(source.s_industry);
					/* FIXME: need to check what was the problem. */
				}
			}

			if(ssi == null) return false;
			if(dsi == null) continue;
			LogMessagesManager.PrintLogMessage("Distance between stations: " +
				AIMap.DistanceManhattan(ssi.station_tile , dsi.station_tile) + ".");

			source.ssi = ssi;
			source.cargo = cargo;
			railroad_route.dsi = dsi;

			/* Create the action to build the railroad. */
			{
				local action_brdrr = ActionBuildRouteDoubleRailroad();
				action_brdrr.railroad_route = railroad_route;
				action_brdrr.source = source;
				action_brdrr.railroad_manager = this;
				action_brdrr.reservation_id = reservation_id;
				InsertAction(action_brdrr);
			}
			return true;
		}
	}
	return false;
}

function RailroadManager::ExpandIndustryRailroadRoute(industry , cargo , railroad_route , reservation_id){
	local industry_manager = ::ai_instance.industry_manager;
	local industry_tile = AIIndustry.GetLocation(industry);
	local industry_type = AIIndustry.GetIndustryType(industry);
	local junction_information , djb , ssi , directions , dsb , drrb;
	local possible_junction;
	local source = Source();
	local paths = array(0);

	foreach(source in railroad_route.sources){
		paths.push(source.double_railroad.path);
	}
	AIRail.SetCurrentRailType(railroad_route.rail_type);

	/* Try to build the junction, the new station and the tracks. */
	djb = DoubleJunctionBuilder(paths , industry_tile , JUNCTION_GAP_SIZE , MAXIMUM_DISTANCE_JUNCTION_POINT);
	possible_junction = djb.GetBestPossibleJunction();
	if(possible_junction == null) return false;
	junction_information = possible_junction.junction_information;
	directions = Direction.GetDirectionsToTile(industry_tile , junction_information.path.tile);
	dsb = DoubleRailroadStationBuilder(SOURCE_NUM_PLATFORMS , PLATFORM_LENGTH , directions.first ,
		directions.second , STATION_TERRAFORMING_MAXIMUM_COST , DoubleRailroadStationBuilder.TERMINUS);
	ssi = dsb.BuildIndustryRailroadStation(industry , true);
	if(ssi == null){
		industry_manager.BlockIndustry(industry);
		return false;
	}

	djb = DoubleJunctionBuilder(paths , ssi.exit_part_tile , JUNCTION_GAP_SIZE , MAXIMUM_DISTANCE_JUNCTION_POINT);
	junction_information = djb.BuildJunction(ssi.exit_direction);//aqui esta o erro (Nao so aqui)
	if(junction_information == null){
		DoubleRailroadStationBuilder.DemolishRailroadStation(ssi);
		industry_manager.BlockIndustry(industry);
		return false;
	}

	source.s_industry = industry;
	source.ssi = ssi;
	source.cargo = cargo;

	/* Create the action to build the railroad. */
	{
		local action_bredrr = ActionBuildRouteExpasionDoubleRailroad();
		action_bredrr.railroad_route = railroad_route;
		action_bredrr.source = source;
		action_bredrr.reservation_id = reservation_id;
		action_bredrr.junction_information = junction_information;
		InsertAction(action_bredrr);
	}
	return true;
}

function RailroadManager::BuildNewTrain(railroad_route , source){
	local locomotive_cost , wagon_cost , total_cost;
	local locomotive , wagon;
	local reservation_id;

	/* Get the locomotive cost. */
	locomotive_cost = AIEngine.GetPrice(railroad_route.locomotive_id);

	/* Get the wagon cost. */
	wagon_cost = AIEngine.GetPrice(source.wagon_id);

	total_cost = source.num_wagons == null ? locomotive_cost + wagon_cost :
		locomotive_cost + wagon_cost * source.num_wagons;
	reservation_id = ::ai_instance.money_manager.ReserveMoney(total_cost);
	if(reservation_id == null) return false;

	/* If it is the first train. */
	if(source.num_wagons == null){

	//	locomotive = AIVehicle.BuildVehicle(source.double_railroad.first_depot_tile ,
		//	railroad_route.locomotive_id);
		if(!AIVehicle.IsValidVehicle(locomotive)){
			if(AIError.GetLastErrorString() == AIError.ERR_NOT_ENOUGH_CASH){
				::ai_instance.money_manager.ReleaseReservation(reservation_id);
				return false;
			}else
				throw("I could not build the train: " + AIError.GetLastErrorString() + ".");
		}
		AIVehicle.RefitVehicle(locomotive , source.cargo);

		//wagon = AIVehicle.BuildVehicle(source.double_railroad.first_depot_tile , source.wagon_id);
		if(!AIVehicle.IsValidVehicle(wagon)){
			if(AIError.GetLastErrorString() == AIError.ERR_NOT_ENOUGH_CASH){
				AIVehicle.SellVehicle(locomotive);
				::ai_instance.money_manager.ReleaseReservation(reservation_id);
				return false;
			}
			else
				throw("I could not build the wagon: " + AIError.GetLastErrorString() + ".");
		}
		AIVehicle.RefitVehicle(wagon , source.cargo);

		/* Calculate the number of wagons. */
		{
			local locomotive_length = AIVehicle.GetLength(locomotive) , wagon_length;
			AIVehicle.MoveWagon(wagon , 0 , locomotive , 0);
			wagon_length = AIVehicle.GetLength(locomotive) - locomotive_length;
			source.num_wagons = (source.ssi.plataform_length * 16 - locomotive_length)/
				wagon_length;
		}
		assert(source.num_wagons > 0);
		AIVehicle.SellVehicle(locomotive);
		::ai_instance.money_manager.ReleaseReservation(reservation_id);
		return false;

	}else{

	//	locomotive = AIVehicle.BuildVehicle(source.double_railroad.first_depot_tile ,
			//railroad_route.locomotive_id);
		if(!AIVehicle.IsValidVehicle(locomotive)){
			::ai_instance.money_manager.ReleaseReservation(reservation_id);
			return false;
		}
		AIVehicle.RefitVehicle(locomotive , source.cargo);
		for(local i = 0 ; i < source.num_wagons ; i++){
		//	wagon = AIVehicle.BuildVehicle(source.double_railroad.first_depot_tile , source.wagon_id);
			if(!AIVehicle.IsValidVehicle(wagon)){
				AIVehicle.SellVehicle(locomotive);
				::ai_instance.money_manager.ReleaseReservation(reservation_id);
				return false;
			}
			AIVehicle.RefitVehicle(wagon , source.cargo);
			AIVehicle.MoveWagon(wagon , 0 , locomotive , 0);
		}
	}

	AIGroup.MoveVehicle(source.group_id , locomotive);
	AIOrder.AppendOrder(locomotive , source.ssi.station_tile , AIOrder.AIOF_FULL_LOAD_ANY);
	AIOrder.AppendOrder(locomotive , railroad_route.sources[0].double_railroad.last_depot_tile ,
		AIOrder.AIOF_NONE);
	AIOrder.AppendOrder(locomotive , railroad_route.dsi.station_tile , AIOrder.AIOF_NONE);
	AIOrder.AppendOrder(locomotive , source.double_railroad.first_depot_tile ,
		AIOrder.AIOF_NONE);
	AIVehicle.StartStopVehicle(locomotive);
	::ai_instance.money_manager.ReleaseReservation(reservation_id);
	return true;
}

/* TODO: Use the amount of cargo waiting on station. */
/* TODO: Consider the number of stations around the industry. */
function RailroadManager::CalculateRailroadRouteMaxNumTrains(railroad_route , source){
	if(source.num_wagons == null) return 1;

	local load_time , transport_time;
	local num_trains;
	local tiles_per_day = (AIEngine.GetMaxSpeed(railroad_route.locomotive_id) * 0.8 * 74.0) / 256.0 / 16.0;

	transport_time = (AIMap.DistanceManhattan(AIIndustry.GetLocation(source.s_industry) ,
		AIIndustry.GetLocation(railroad_route.d_industry)) * 2.0)/tiles_per_day;
	load_time = (AIEngine.GetCapacity(source.wagon_id) * source.num_wagons)/
		(AIIndustry.GetLastMonthProduction(source.s_industry , source.cargo) * 0.7 / 30.0) +
		(5 / tiles_per_day);

	num_trains = ((transport_time + load_time)/load_time).tointeger();
	if(num_trains == 0) num_trains++;
	else if(num_trains > 8) num_trains = 8;
	return num_trains;
}

function RailroadManager::InformIndustryClosure(industry_id){
	/* Check to see if some route must be demolished. */
	foreach(railroad_route_index , railroad_route in railroad_routes){
		/* TODO: Check if the station can receive the cargo. */
		if(railroad_route.d_industry == industry_id){
			MarkRailroadRouteToBeDemolished(railroad_route_index);
		}
	}
}

function RailroadManager::AdjustNumTrainsInRailroadRoutes(self){
	this = self;
	foreach(railroad_route in railroad_routes){
		foreach(source in railroad_route.sources){
			local source_vehicles = AIVehicleList_Group(source.group_id);
			source_vehicles.Valuate(AIVehicle.GetState);
			source_vehicles.KeepValue(AIVehicle.VS_AT_STATION);
			source_vehicles.Valuate(AIVehicle.GetLocation);
			foreach(vehicle_id , location in source_vehicles){
				if(AITile.IsStationTile(location) &&
					AIStation.GetStationID(location) == AIStation.GetStationID(source.ssi.station_tile))
					source.n_trains_at_station++;
			}
			source.n_samples++;

			if(source.last_check + 365 < AIDate.GetCurrentDate()){
				local ratio;
				local negative_trains = GetNumTrainsNegativeProfit(railroad_route , source);

				if(source.n_trains != null &&
					source.n_trains == GetCurrentSourceNumTrains(railroad_route , source)){

					if(negative_trains == 0 /* && !traffic_jam */){
						if(source.n_samples >= MININUM_NUM_SAMPLES){
							ratio = source.n_trains_at_station.tofloat()/source.n_samples.tofloat();
							if(ratio < 1) source.n_trains++;
						}
					}else{
						source.n_trains -= negative_trains;
						source.n_trains = source.n_trains < 1 ? 1 : source.n_trains;
					}
				}
				source.last_check = AIDate.GetCurrentDate();
				source.n_trains_at_station = source.n_samples = 0;
			}
		}
	}
	return false;
}

function RailroadManager::InsertAction(action){
	if(pending_actions.len() == 0){
		::ai_instance.scheduler.CreateTask(ExecuteActions , this , Scheduler.NO_INTERVAL);
	}
	pending_actions.push(action);
	if(action.Block()) n_railroad_routes_blocked++;
}

function RailroadManager::ExecuteActions(self){
	this = self;
	/* Execute the pending actions. */
	if(pending_actions.len() > 0){
		local top_index = pending_actions.len() - 1;
		if(pending_actions[top_index].Finished()){
			if(pending_actions[top_index].next_action == null){
				if(pending_actions[top_index].Unblock()) n_railroad_routes_blocked--;
				pending_actions.pop();
			}else	pending_actions[top_index] = pending_actions[top_index].next_action;
		}
	}
	return pending_actions.len() == 0;
}

function RailroadManager::MaintainRailroadRoutes(self){
	this = self;
	foreach(railroad_route in railroad_routes){
		if(railroad_route.is_blocked) continue;
		/* Check if the route need more trains. */
		foreach(source in railroad_route.sources){
			/* TODO: Check if we can build more trains. */

			if(source.n_trains == null){
				BuildNewTrain(railroad_route , source);
				source.n_trains = CalculateRailroadRouteMaxNumTrains(railroad_route , source);
			}

			if(source.n_trains > GetCurrentSourceNumTrains(railroad_route , source)){
				local n_trains = GetCurrentSourceNumTrains(railroad_route , source);
				if(BuildNewTrain(railroad_route , source)) n_trains++;
				while(n_trains < source.n_trains){
					if(BuildNewTrain(railroad_route , source)) n_trains++;
					else break;
				}
			}else	if(source.n_trains < GetCurrentSourceNumTrains(railroad_route , source)){
				local n_trains_to_sell = GetCurrentSourceNumTrains(railroad_route , source) - source.n_trains;
				local source_trains = AIVehicleList_Group(source.group_id);
				foreach(vehicle_id , dummy in source_trains){
					if(n_trains_to_sell <= 0) break;
					::ai_instance.vehicle_seller.SellVehicle(vehicle_id);
					/* Remove the vehicle from the source group. */
					AIGroup.MoveVehicle(AIGroup.GROUP_DEFAULT , vehicle_id);
					n_trains_to_sell--;
				}
			}
		}

		/* Check if we need to change the locomotive and the rail type. */
		if(AIDate.GetCurrentDate() - railroad_route.last_locomotive_update > INTERVAL_CHANGE_LOCOMOTIVE){
			if(AICompany.GetBankBalance(AICompany.COMPANY_SELF) > MININUM_MONEY_CHANGE_LOCOMOTIVE){
				local engines = AIEngineList(AIVehicle.VT_RAIL);
				engines.Valuate(AIEngine.IsValidEngine);
				engines.KeepValue(1);
				engines.Valuate(AIEngine.IsWagon);
				engines.KeepValue(0);
				local lv = LocomotiveValuator(engines);
				engines.Valuate(LocomotiveValuator.ValuateLocomotive , lv);
				engines.Sort(AIAbstractList.SORT_BY_VALUE , false);

				if(engines.GetValue(railroad_route.locomotive_id) < engines.GetValue(engines.Begin())){
					local action_crrrt = null;
					if(AIEngine.CanRunOnRail(engines.Begin() , railroad_route.rail_type) &&
						AIEngine.HasPowerOnRail(engines.Begin() , railroad_route.rail_type)){

						LogMessagesManager.PrintLogMessage("I am going to change the route locomotive to " +
							AIEngine.GetName(engines.Begin()) + ".");
					}else{
						LogMessagesManager.PrintLogMessage(
							"I am going to change the route rail type to use the locomotive " +
							AIEngine.GetName(engines.Begin()) + ".");
						action_crrrt = ActionConvertRailroadRouteRailType();
						action_crrrt.old_rail_type = railroad_route.rail_type;
						action_crrrt.railroad_route = railroad_route;
						railroad_route.rail_type = AIEngine.GetRailType(engines.Begin());
					}
					SellRailroadRouteVehicles(railroad_route , action_crrrt);
					railroad_route.locomotive_id = engines.Begin();
					railroad_route.last_locomotive_update = AIDate.GetCurrentDate();
					/* Set the number of trains to null because it needs be recalculated as
						the locomotive type changed. */
					foreach(source in railroad_route.sources){
						source.n_trains = null;
						source.n_trains_at_station = source.n_samples = 0;
					}
				}
			}
		}
	}
	/* This condition is very restrictive. */
	if(n_railroad_routes_blocked == 0)
		DemolishMarkedIndustryRailroadRoutes();
	return false;
}

function RailroadManager::InvestMoneyOnRailroads(self){
	local reservation_id;
	this = self;

	if(n_railroad_routes_blocked != 0) return false;

	/* We are going to create our first route. */
	/* TODO Check if it done well and diminish the distance if not. */
	if(railroad_routes.len() == 0){
		reservation_id = ::ai_instance.money_manager.ReserveMoney(0);
		if(reservation_id != null)
			InvestMoneyOnIndustry(true , reservation_id);
	}else{
		reservation_id = ::ai_instance.money_manager.ReserveMoney(MINIMUM_MONEY_INVEST);
		/* If we have sufficient money we must invest it. */
		if(reservation_id != null)
			InvestMoneyOnIndustry(true , reservation_id);
	}
	return false;
}

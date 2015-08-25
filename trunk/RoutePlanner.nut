//TODO: measure by approx route distance/cost rather than actual distance (quick algorithms for finding obstructions?)
//TODO: buildability measure of tile
//TODO: Routes after minimum spanning tree
//TODO: take into acount approx. capacities
//NOTE: check out test mode

import("pathfinder.road", "RoadPathFinder", 3);
require("log_manager.nut");
require("constants.nut");
require("helper.nut");
//require("road/road.nut");
//require("road/builder.nut");
//require("road/placer.nut");
//require("road/vehicle.nut");
//require("rail/finder.nut");
//require("rail/tracks.nut");
require("obects/town.nut");
require("obects/station.nut");
require("RouteChooser.nut");


class RoutePlanner	{
routes = [];
};

//starts the recursive region building process
function RoutePlanner::buildNetwork() {
	//step one - we don't want to work with towns. We work with base regions - stations connected to a close group of towns with roads
	//a base region can have any number of town, from 1 to usually a max of around 6.
	local towns = AITownList();
	RoutePlanner.getBaseRegions(towns);
	
	//each base region in list has 5 parameters:
	//0 - center, 1- towns, 2 - stationid, 3 - built?, 4 - connected?
	
	//this is the routes we will contruct
	//local routes = RoutePlanner.getMinSpanningRoutes();
	local route_chooser = RouteChooser(base_regions);
	//local routes = RoutePlanner.getTopRoutes();
	
	while(AICompany.GetBankBalance(AICompany.COMPANY_SELF) < 100000) {
		this.Sleep(200);
		LogManager.Log("waiting for money", 4);
		local next_task = task_list[i];
		next_task.Exectute();
		i++; 
	}
	local route_count = 0;
	while(route_count < route_chooser.max_routes) {
		route_count ++;
		local route = route_chooser.getNextRoute();
		if(route == null) {
			LogManager.Log("holy shit finished all the routes!", 4);
			break;
		}
	
		if(base_regions[route[0]][3] == 0) {
			base_regions[route[0]][2] = ZooElite.BuildBaseStation(base_regions[route[0]][1], base_regions[route[0]][0], 0);
			base_regions[route[0]][3] = 1;
		}
		if(base_regions[route[1]][3] == 0) {
			base_regions[route[1]][2] = ZooElite.BuildBaseStation(base_regions[route[1]][1], base_regions[route[1]][0], 0);
			base_regions[route[1]][3] = 1;
		}
		
		if(base_regions[route[0]][2] != false && base_regions[route[1]][2] != false) {
			local new_route = ZooElite.ConnectStations(base_regions[route[0]][2], base_regions[route[1]][2], 0, 0);
			if(new_route) {
				//new_route.balanceRailService();
			}
		
			if(base_regions[route[0]][4] == 0) {
				ZooElite.ConnectBaseRegion(base_regions[route[0]]);
				base_regions[route[0]][4] = 1;
				
			}
			if(base_regions[route[1]][4] == 0) {
				ZooElite.ConnectBaseRegion(base_regions[route[1]]);
				base_regions[route[1]][4] = 1;
				
			}
		}
		
		while(AICompany.GetBankBalance(AICompany.COMPANY_SELF) < 100000) {
			this.Sleep(200);
			LogManager.Log("waiting for money", 4);
		}
	}		

	
}

//this will take a map full of towns and determine small "base regions -> each to be serviced by a single train station 
//connected to the towns with roads
//returns an array of arrays
//each base region holds: center of region, towns in region, whether or not it has been built, and the regional station id (null if not build yet or failed)
function RoutePlanner::getBaseRegions(towns) {

	//will hold region's locations (centers and towns in each region
	local regions;

	//will hold centers of regions
	local regionCenters = array(towns.Count());
	
	//will hold towns in each base region
	local bucketList = array(towns.Count(), null);
	
	//initialize buckets
	for(local i = 0; i < towns.Count(); i += 1) {
		bucketList[i] = AIList();
	}

	//now really initialize the buckets and the region centers
	local i = 0;
	foreach(town, townIndex in towns) {
		bucketList[i].AddItem(town, town);
		regionCenters[i] = AITown.GetLocation(town);
		i += 1;
	}
	
	//if we have only one town in this region
	if(regionCenters.len() == 1) {
		base_regions.push([regionCenters[0], bucketList[0], null, 0]);
	}

	//run through agglomeration until the regions we are creating are too big
	
	local aggRegion1 = 0;
	local aggRegion2 = 1;
	local minDistance = AIMap.DistanceSquare(regionCenters[0], regionCenters[1]);
	for(local r = 0; r < regionCenters.len()-1; r += 1)	{
		for(local c = r+1; c < regionCenters.len(); c += 1) {
				
			local newDistance = AIMap.DistanceSquare(regionCenters[r], regionCenters[c]);
			if(newDistance < minDistance) {
				minDistance = newDistance;
				aggRegion1 = r;
				aggRegion2 = c;
			}	
		}	
	}
	
	while(minDistance < 2000) {
		LogManager.Log("the regions to aggregate are: " + aggRegion1 + " , " + aggRegion2, 4);
	
		//now we need to actually aggregate these regions:
		//we will copy everything into a new bucketlist with 1 less element
		local newBucketList = array(bucketList.len() - 1, null);
		//initialize buckets
		for(local i = 0; i < newBucketList.len(); i += 1) {
			newBucketList[i] = AIList();
		}
		
		//add regions to bucketList with towns from Region1 and Region2 going into the same bucket
		local j = 1;
		for(local i = 0; i < bucketList.len(); i += 1) {
			if(i == aggRegion1 || i == aggRegion2) {
				foreach(town in bucketList[i]) {
					newBucketList[0].AddItem(town, town);
				}
			}
			else {
				foreach(town in bucketList[i]) {
					newBucketList[j].AddItem(town, town);
				}
				j += 1;
			}
		}
		
		//now recalculate the region centers
		local newRegionCenters = array(newBucketList.len(), null);
		
		for(local i = 0; i < newRegionCenters.len(); i += 1) {
			local xSum = 0;
			local ySum = 0;
			local numTowns = 0;

			//sum x and y coordinates of all towns in region
			foreach(town in newBucketList[i]) {
				xSum += AIMap.GetTileX(AITown.GetLocation(town));
				ySum += AIMap.GetTileY(AITown.GetLocation(town));
				numTowns += 1;
			}
		
			//averages
			local xAvg = xSum / numTowns;
			local yAvg = ySum / numTowns;
			//LogManager.Log("region " + i + " has " + numTowns + " towns", 4);
			//LogManager.Log("region " + i + " has " + xSum + " xSum", 4);
			//LogManager.Log("region " + i + " has " + ySum + " ySum", 4);
		
			//LogManager.Log("region " + i + "now at center: " + xAvg + ", " + yAvg, 4);
			//set region to average x and y value:
			newRegionCenters[i] = AIMap.GetTileIndex(xAvg, yAvg);
		}
		
		bucketList = newBucketList;
		regionCenters = newRegionCenters;

		//now calculate the next 2 regions to aggregate
		//first we figure out which 2 regions to combine
		aggRegion1 = 0;
		aggRegion2 = 1;
		minDistance = AIMap.DistanceSquare(regionCenters[aggRegion1], regionCenters[aggRegion2]);
		for(local r = 0; r < regionCenters.len()-1; r += 1)	{
			for(local c = r+1; c < regionCenters.len(); c += 1) {
				
				local newDistance = AIMap.DistanceSquare(regionCenters[r], regionCenters[c]);
				if(newDistance < minDistance) {
					minDistance = newDistance;
					aggRegion1 = r;
					aggRegion2 = c;
				}	
			}	
		}

	}
	
	local rebalanced_centers = array(bucketList.len(), null);
	for(local i = 0; i < bucketList.len(); i++) {
		local xSum = 0;
		local ySum = 0;
		local popSum = 0;
		local numTowns = 0;
		foreach(town in bucketList[i]) {
			xSum += AIMap.GetTileX(AITown.GetLocation(town))*AITown.GetPopulation(town);
			ySum += AIMap.GetTileY(AITown.GetLocation(town))*AITown.GetPopulation(town);
			popSum += AITown.GetPopulation(town);
			numTowns++;
			//LogManager.Log("town pop: " + AITown.GetPopulation(town), 4);
		}
		
		local xAvg = xSum/(popSum);
		local yAvg = ySum/(popSum);
		
		rebalanced_centers[i] = AIMap.GetTileIndex(xAvg, yAvg);
		if(!AIMap.IsValidTile(rebalanced_centers[i])) {
			LogManager.Log("the tile is fucked", 4);
		}
		/*else {
			LogManager.Log("rebalanced center " + i + " at tile " +  rebalanced_centers[i], 4);
		}*/
	}
		
		
	
	RoutePlanner.addBaseRegions([rebalanced_centers, bucketList]);
	return 0;
}

//the main function that is called recursively to build regions on a set of towns
//starts with all the towns in the map - eventually gets down to small regions and builds bus routes.
function buildRegion(towns, townsCenter) {
	
	//find the center of the region where we will build the regional station
	local regionCenter = townsCenter;
	
	//no we cluster the towns into smaller regions. The number of smaller regions will determine the number of platforms at the station.
	local subRegions = RoutePlanner.aggCluster(towns);
	local numSubRegions = subRegions[0].len();
	
	
	//our region is minimally sized
	if(numSubRegions == 1) {
		LogManager.Log("Adding BaseRegion with center: " + regionCenter, 4);
		RoutePlanner.addBaseRegion(subRegions);
		return 0;
	}
	
	//otherwise we recursively build the subregions and connect them to the regional station that we build
	
	//first we build the regional station
	//BuildRegionalStation(regionCenter, numSubRegions, 0, 0, 0, 0);
	
	//now we scroll through subregions, recursively building and connecting
	local i = 0;
	foreach(region in subRegions) {
		buildRegion(subRegions[1][i], subRegions[0][i]);
		i += 1;
	}
	
	//mark the regions and build statoins so we know whats going on (towns.len() gives us some sense of what level of map this region is part of)
	/*for(local i = 0; i < regions[0].len(); i += 1) {
	
			Sign(regions[0][i], towns.Count() + "Region " + i);
			//build station at town closest to center of region
			local minDistance = -1;
			local city;
			foreach (town in regions[1][i]) {
				local newMin = AIMap.DistanceSquare(AITown.GetLocation(town), regions[0][i]);
				if(minDistance == -1 || newMin < minDistance) {
					city = town;
					minDistance = newMin;
				}
			}
		}
	
	local regionalRoutes;
	
	//now we get the list of regional routes - each route is defined by a pair of regions
	regionalRoutes = RoutePlanner.getTopRoutes(regions);
	*/
	//now "build" routes just to get a sense of stuff (right now we just mark routes)
	//before building a route call the function recursively on the regions it connects
	
	//mark which subregions we have already built
	/*local alreadyBuilt = array(regions[0].len(), 0);
	for(local j = 0; j < regionalRoutes.len(); j += 1) {
		local route = regionalRoutes[j];
		//TODO:how do we pass/refer to regions. bucketList???
		if(alreadyBuilt[route[0]] == 0) {
			RoutePlanner.buildRegions(regions[1][route[0]]);
			alreadyBuilt[route[0]] = 1;
		}
		if(alreadyBuilt[route[1]] == 0) {
			RoutePlanner.buildRegions(regions[1][route[1]]);
			alreadyBuilt[route[1]] = 1;
		}
		*/
		/*//now we want to connect 2 given regions by the towns closest to their centers
		local city0;
		local city1;
		local minDistance = -1;
		foreach (town0 in regions[1][route[0]]) {
			local newMin = AIMap.DistanceSquare(AITown.GetLocation(town0), regions[0][route[0]]);
			if(minDistance == -1 || newMin < minDistance) {
				city0 = town0;
				minDistance = newMin;
			}
		}
		
		minDistance = -1;
		foreach (town1 in regions[1][route[1]]) {
			local newMin = AIMap.DistanceSquare(AITown.GetLocation(town1), regions[0][route[1]]);
			if(minDistance == -1 || newMin < minDistance) {
				city1 = town1;
				minDistance = newMin;
			}
		}*/
		
		
		//local station2 = BuildRegionalStation(regions[0][route[1]], 4, 0, 0);
		//local station2 = ZooElite.BuildRegionalStation(city1, 0, AITown.GetLocation(city0), 3, true);
		
		//Connect the two stations using rails...actually works more or less...
		//ZooElite.ConnectStations(stations[route[0]], stations[route[1]]);
		//ZooElite.ConnectStations(stations[route[1]], stations[route[0]]);
		
		//local Yinc =  AIMap.GetTileY(AITown.GetLocation(city0)) - AIMap.GetTileY(AITown.GetLocation(city1));
		//LogManager.Log("Yinc: " + Yinc,3);
		//local Xinc =  AIMap.GetTileX(AITown.GetLocation(city0)) - AIMap.GetTileX(AITown.GetLocation(city1));
		/*local Xinc =  ((AIMap.GetTileX(regions[0][route[0]]) - AIMap.GetTileX(regions[0][route[1]])));
		local Yinc =  ((AIMap.GetTileY(regions[0][route[0]]) - AIMap.GetTileY(regions[0][route[1]])));

		local curY = 20*AIMap.GetTileY(regions[0][route[1]]);
		local curX = 20*AIMap.GetTileX(regions[0][route[1]]);
		for(local i = 0; i < 21; i += 1) {
			Sign(AIMap.GetTileIndex(curX/20, curY/20), "R" + j);
			curY += Yinc;
			curX += Xinc;
		}
	}
	*/
	
	return 0;//regions;
	
}

//finds regions using a v means clustering algorithm
//note: no longer used
//TODO: make useful by moving towns to regions that are easiest to get to rather than by just doing distance
function RoutePlanner::vMeansCluster(towns) {
	local regionCount = towns.Count()/5;
	LogManager.Log("Creating: " + regionCount + " regions" , 3);
	
	local regions = RoutePlanner.aggCluster(towns);
	local regionCenters = regions[0];
	local bucketList;
	/*local regions = array(regionCount, null);
	
	//assign regions to centers of 6 first towns
	//locations will then change by the k-means algorithm
	local tempRegion = AITown.GetLocation(towns.Begin());
	for(local i = 0; i < regionCount; i += 1) {
		regions[i] = tempRegion;
		tempRegion = AITown.GetLocation(towns.Next());
	} */

	//run through the algorithm a specified number of times to refine regions
	for(local i = 0; i < 1; i+= 20) {

		local towns = AITownList();
	
		bucketList = array(regionCount, null);
	
		//initialize buckets
		for(local i = 0; i < regionCount; i += 1) {
			bucketList[i] = AIList();
		}
	
		//assign each town to closest region
		foreach(town, townIndex in towns) {
			local currentAssignment = 0;
			local minDistance = SquareRoot(AITown.GetDistanceSquareToTile(town, regionCenters[currentAssignment]));
		
			//check each region to see if we should assign to it
			for(local i = 1; i < regionCount; i += 1) {
				local newDistance = SquareRoot(AITown.GetDistanceSquareToTile(town, regionCenters[i]));
				//if there is a closer region update the assignment
				if(newDistance < minDistance) {
					minDistance = newDistance;
					currentAssignment = i;
				
				}
			}
		
			//actually place town in correct bucket
			//TODO: figure out this sloppy key/value shit
			bucketList[currentAssignment].AddItem(town, town);
		
			LogManager.Log("bucketList " + currentAssignment + "was just added to with town  " + town, 3);
			//LogManager.Log("bucketList last element: " + bucketList[0].tostring(), 3);
		}
	
		//now update centers of regions
		for(local i = 0; i < regionCount; i += 1) {
			local xSum = 0;
			local ySum = 0;
			local numTowns = 0;

			//sum x and y coordinates of all towns in region
			foreach(town in bucketList[i]) {
				xSum += AIMap.GetTileX(AITown.GetLocation(town));
				ySum += AIMap.GetTileY(AITown.GetLocation(town));
				numTowns += 1;
			}
		
			//averages
			local xAvg = xSum / numTowns;
			local yAvg = ySum / numTowns;
			LogManager.Log("region " + i + " has " + numTowns + " towns", 3);
			LogManager.Log("region " + i + " has " + xSum + " xSum", 3);
			LogManager.Log("region " + i + " has " + ySum + " ySum", 3);
		
			LogManager.Log("region " + i + "now at center: " + xAvg + ", " + yAvg, 3);
			//set region to average x and y value:
			regionCenters[i] = AIMap.GetTileIndex(xAvg, yAvg);
		}
	}
	
	regions = [regionCenters, bucketList];
	return regions;
}


//finds regions using an agglomerated clustering algorithm
//returns 2-d array - regions[0] = region centers, regions[1] = bucketList
//TODO: speed up algorithm for larger town counts - need to aggregate multiple regions on each pass
//TODO: continue clustering after threshold miss (use skip index and sorting)
function RoutePlanner::aggCluster(towns) {

	//will hold region's locations (centers and towns in each region
	local regions;
	
	//will hold centers of regions
	local regionCenters = array(towns.Count());
	//will hold actual towns in region
	//LogManager.Log("the number of towns is: " + towns.Count(), 3);
	local numAggs = towns.Count()-4;
	if(numAggs < 0) {
		numAggs = 0;
	}
	
	//LogManager.Log("the number of recursions will be: " + finalNumRegions, 3);
	local bucketList = array(towns.Count(), null);
	
	//initialize buckets
	for(local i = 0; i < towns.Count(); i += 1) {
		bucketList[i] = AIList();
	}

	local diameter;
	local centerMassX = 0;
	local centerMassY = 0;
	local centerMassTile;
	
	//initially, each town is a region
	local i = 0; //regionID
	foreach(town, townIndex in towns) {
		bucketList[i].AddItem(town, town);
		regionCenters[i] = AITown.GetLocation(town);
		centerMassX += AIMap.GetTileX(regionCenters[i]);
		centerMassY += AIMap.GetTileY(regionCenters[i]);
		i += 1;
	}
	
	centerMassTile = AIMap.GetTileIndex(centerMassX/towns.Count(), centerMassY/towns.Count());
	diameter = AIMap.DistanceSquare(centerMassTile, AITown.GetLocation(towns.Begin()));
	foreach(town, townIndex in towns) {
		if(AIMap.DistanceSquare(centerMassTile, AITown.GetLocation(town)) > diameter) {
			diameter = AIMap.DistanceSquare(centerMassTile, AITown.GetLocation(town));
		}
	}
	
	local threshold = 2000;
	if(diameter < threshold) {
		local buckets = AIList();
		foreach(town, townIndex in towns) {
			buckets.AddItem(town, town);
		}
		return [[centerMassTile], [buckets]];
	}
	
	//if we have only one town in this region
	if(regionCenters.len() == 1) {
		return [regionCenters, bucketList];
	}

	//run through agglomeration a certain number of times
	local minDistance = AIMap.DistanceSquare(regionCenters[0], regionCenters[1]);
	for(local r = 0; r < regionCenters.len()-1; r += 1)	{
		for(local c = r+1; c < regionCenters.len(); c += 1) {
				
			local newDistance = AIMap.DistanceSquare(regionCenters[r], regionCenters[c]);
			if(newDistance < minDistance) {
				minDistance = newDistance;
			}	
		}	
	}
	
	local j = 0;
	/*if(numAggs < 4) {
		numAggs = regionCenters.len()-1;
	}*/
	local subRegionCount = regionCenters.len()-1;
	while((j < numAggs) || ((minDistance < 1000) && (j < subRegionCount))) {
	//LogManager.Log("j: " + j,4);
		j += 1;
		//first we figure out which 2 regions to combine
		local aggRegion1 = 0;
		local aggRegion2 = 1;
		local tempMinDistance = AIMap.DistanceSquare(regionCenters[aggRegion1], regionCenters[aggRegion2]);
		for(local r = 0; r < regionCenters.len()-1; r += 1)	{
			for(local c = r+1; c < regionCenters.len(); c += 1) {
				
				local newDistance = AIMap.DistanceSquare(regionCenters[r], regionCenters[c]);
				if(newDistance < tempMinDistance) {
					tempMinDistance = newDistance;
					aggRegion1 = r;
					aggRegion2 = c;
				}	
			}	
		}
		
		minDistance = tempMinDistance;
	
		//stop the algorithm if it is creating too spead out of regions
		/*local maxDiam = 5000;
		if(minDistance > maxDiam) {
			break;
		}*/
		
		LogManager.Log("the regions to aggregate are: " + aggRegion1 + " , " + aggRegion2, 4);
	
		//now we need to actually aggregate these regions:
		//we will copy everything into a new bucketlist with 1 less element
		local newBucketList = array(bucketList.len() - 1, null);
		//initialize buckets
		for(local i = 0; i < newBucketList.len(); i += 1) {
			newBucketList[i] = AIList();
		}
		
		//add regions to bucketList with towns from Region1 and Region2 going into the same bucket
		local j = 1;
		for(local i = 0; i < bucketList.len(); i += 1) {
			if(i == aggRegion1 || i == aggRegion2) {
				foreach(town in bucketList[i]) {
					newBucketList[0].AddItem(town, town);
				}
			}
			else {
				foreach(town in bucketList[i]) {
					newBucketList[j].AddItem(town, town);
				}
				j += 1;
			}
		}
		
		//now recalculate the region centers
		local newRegionCenters = array(newBucketList.len(), null);
		
		for(local i = 0; i < newRegionCenters.len(); i += 1) {
			local xSum = 0;
			local ySum = 0;
			local numTowns = 0;

			//sum x and y coordinates of all towns in region
			foreach(town in newBucketList[i]) {
				xSum += AIMap.GetTileX(AITown.GetLocation(town));
				ySum += AIMap.GetTileY(AITown.GetLocation(town));
				numTowns += 1;
			}
		
			//averages
			local xAvg = xSum / numTowns;
			local yAvg = ySum / numTowns;
			//LogManager.Log("region " + i + " has " + numTowns + " towns", 4);
			//LogManager.Log("region " + i + " has " + xSum + " xSum", 4);
			//LogManager.Log("region " + i + " has " + ySum + " ySum", 4);
		
			//LogManager.Log("region " + i + "now at center: " + xAvg + ", " + yAvg, 4);
			//set region to average x and y value:
			newRegionCenters[i] = AIMap.GetTileIndex(xAvg, yAvg);
		}
		
		/*//only continue if this will not produce a region that is too big
		local threshold = 3000;
		local maxDiam = 0;
		foreach(town in newBucketList[0]) {
			local diam = SquareRoot(AITown.GetDistanceSquareToTile(town, newRegionCenters[0]));
			if(diam > maxDiam)
				maxDiam = diam;
		}
		*/
		//if(maxDiam < threshold) {
			bucketList = newBucketList;
			regionCenters = newRegionCenters;
		//}
	}
	
	//now return buckets and centers
	regions = [regionCenters, bucketList];
	return regions;
}


//draws regions closer to nearby regions
function RoutePlanner::regionBalance(regions, regionalRoutes) {

	
	local newRegions = [array(regions[0].len(), null), regions[1]];
	for(local i = 0; i < regions[0].len(); i += 1) {
		local region = regions[0][i];
		local connectedRegions = [];
		
		foreach(route in regionalRoutes) {
			if(route[0] == i) {
				connectedRegions.append(route[1]);
			}
			if(route[1] == i) {
				connectedRegions.append(route[0]);
			}
		}
		LogManager.Log("region " + i + " has " + connectedRegions.len() + " connected regions", 4);
		local xSum = 0;
		local ySum = 0;
		
		xSum += 5*AIMap.GetTileX(region)/6;
		ySum += 5*AIMap.GetTileY(region)/6;
		foreach(connectedRegion in connectedRegions) {
			xSum += AIMap.GetTileX(regions[0][connectedRegion])/(6*connectedRegions.len());
			ySum += AIMap.GetTileY(regions[0][connectedRegion])/(6*connectedRegions.len());
		}
		newRegions[0][i] = AIMap.GetTileIndex(xSum, ySum);
		LogManager.Log("region " + i + " is now at center: " + xSum + ", " + ySum, 4);
	}
	
	return newRegions;
}

//this will move a region to a relatively near by city if that is more efficient
function RoutePlanner::adjustRegions(regions) {

	local newRegions = [array(regions[0].len(), null), regions[1]];
	local regionCenters = regions[0];
	for(local i = 0; i < regionCenters.len(); i += 1) {
		local region = regionCenters[i];
		newRegions[0][i] = region;
		//get the average diameter of the region
		local diameter = 0;
		local townCount = 0;
		foreach(town, townid in regions[1][i]) {
			diameter += SquareRoot(AITown.GetDistanceSquareToTile(town, region));
			townCount += 1;
		}
		
		//local threshold = diameter / (townCount*5);
		local threshold = 200;
		
		//now check towns. If one is very close to the region move the region center to the town
		foreach(town, townid in regions[1][i]) {
			if(SquareRoot(AITown.GetDistanceSquareToTile(town, region)) < threshold) {
				newRegions[0][i] = AITown.GetLocation(town);
				threshold = SquareRoot(AITown.GetDistanceSquareToTile(town, region));
			}
		}
	}
	
	return newRegions;
}

//will create a minimum spanning tree covering all towns passed in

function RoutePlanner::getMinSpanningRoutes() {
	//for each region pair - measure approx. cost (distance?, test mode? water check and shit?)
	//run kruskal's or similar algoritm
	
	//list of all possible regional routes
	local possibleRoutes = array(base_regions.len()*(base_regions.len()-1)/2, null);
	
	
	
	for(local i = 0; i < possibleRoutes.len(); i += 1) {
		possibleRoutes[i] = array(3, null);
	}
	
						
	local c = 0;
	for(local i = 0; i < base_regions.len(); i += 1) {
		for(local j = i + 1; j < base_regions.len(); j += 1) {
			possibleRoutes[c][0] = i;
			possibleRoutes[c][1] = j;
			possibleRoutes[c][2] = SquareRoot(AIMap.DistanceSquare(base_regions[i][0], base_regions[j][0]));
			c += 1;
		}
	}
	
	//sort to have shortest routes
	possibleRoutes.sort(route_compare);
	for(local i = 0; i < possibleRoutes.len(); i += 1) {
		LogManager.Log("possible route lenth: " + possibleRoutes[i][2] + " from " + possibleRoutes[i][0] + " to " +possibleRoutes[i][1], 4);
	}
	
	//now run algorithm.
	local regionalRoutes = [];
	local clusters = array(base_regions.len(), null);
	for(local i = 0; i < clusters.len(); i += 1) {
		clusters[i] = i;
	}
	for(local i = 0; i < possibleRoutes.len(); i += 1) {
		if(clusters[possibleRoutes[i][0]] != clusters[possibleRoutes[i][1]]) {
			regionalRoutes.append([possibleRoutes[i][0], possibleRoutes[i][1], possibleRoutes[i][2]]);
			local newClusterNum = clusters[possibleRoutes[i][1]];
			local oldClusterNum = clusters[possibleRoutes[i][0]];
			for(local j = 0; j < clusters.len(); j += 1) {
				if(clusters[j] == oldClusterNum) {
					clusters[j] = newClusterNum;
				}
			}
		}
	}
	
	foreach(route in regionalRoutes) {
		LogManager.Log("route from: " + route[0] + " to " + route[1] + " with length: " + route[2], 4);
		
		local Xinc =  AIMap.GetTileX(base_regions[route[0]][0]) - AIMap.GetTileX(base_regions[route[1]][0]);
		local Yinc =  AIMap.GetTileY(base_regions[route[0]][0]) - AIMap.GetTileY(base_regions[route[1]][0]);

		local curY = 20*AIMap.GetTileY(base_regions[route[1]][0]);
		local curX = 20*AIMap.GetTileX(base_regions[route[1]][0]);
		for(local i = 0; i < 21; i += 1) {
			Sign(AIMap.GetTileIndex(curX/20, curY/20), "R");
			curY += Yinc;
			curX += Xinc;
		}
	}
	return regionalRoutes;
}





//##########################################################################################################
//##########################################################################################################
//##########################################################################################################
//##########################################################################################################

//each route holds: base region 1, base region 2, distance?
function RoutePlanner::getTopRoutes() {
	
	//list of regional populations - saves time to precalculate:
	local regional_pops = array(base_regions.len(), 0);
	for(local i = 0; i < base_regions.len(); i += 1) {
		foreach(town in base_regions[i][1]) {
			regional_pops[i] += AITown.GetPopulation(town);
		}
	}
	

	//list of all possible regional routes
	local possibleRoutes = [];
	
	local c = 0;
	//in this loop we initialize possible routes
	for(local i = 0; i < base_regions.len(); i += 1) {
		for(local j = i + 1; j < base_regions.len(); j += 1) {
			local region1 = i;
			local region2 = j;
			local totalPop = regional_pops[i] + regional_pops[j];
			local distance = SquareRoot(AIMap.DistanceSquare(base_regions[i][0], base_regions[j][0]));
			
			//now decide whether to add route:
			if(distance > 0) { // < 250) {
				local newRoute = array(6,0);
				newRoute[0] = region1;
				newRoute[1] = region2;
				newRoute[2] = 0; //not added yet
				newRoute[3] = -1; //no shortest path yet
				newRoute[4] = totalPop;
				newRoute[5] = distance;
				
				possibleRoutes.append(newRoute);
				c += 1;
			}
		}	
	}
	
	LogManager.Log("possible routes length: " + possibleRoutes.len(), 4);
	
	local regionalRoutes = [];
	//basically tells what connected piece of the graph a node is in
	local clusters = array(base_regions.len(), null);
	for(local i = 0; i < clusters.len(); i += 1) {
		clusters[i] = i;
	}
	
	for(local i = 0; i < possibleRoutes.len(); i += 1) {
		LogManager.Log("possible route from " + possibleRoutes[i][0] + " to " + possibleRoutes[i][1], 4);
	}
	
	//MAJOR LOOP: LOOPUS MAXIMUS
	//in this loop we add routes - the best first and then adjust the minpath for remaining routes and restart.
	for(local i = 0; i < 10; i += 1) {
		//holds the route we are currently planning on adding
		local currentBest = 0;
		local currentFlowImprovement = 0;
		
		//we iterate through all routes and see how adding them will effect flow:
		for(local j = 0; j < possibleRoutes.len(); j += 1) {
		
			//don't check if already added
			if(possibleRoutes[j][2] == 1) {
				continue;
			}
			
			local flowImprovement = 0;
			
			//will hold the new minimum paths between routes once the candidate route (j) is added
			local newMinPaths = array(possibleRoutes.len(), -1);
			
			//a clone of regionalRoutes that we add the candidate route to
			local testRoutes = [];
			
			for(local k = 0; k < regionalRoutes.len(); k += 1){
					testRoutes.append(regionalRoutes[k]);
				}
			//add on the candidate route
			testRoutes.append(possibleRoutes[j]);
			
			//a clone of clusters updated to reflect the addition of the candidate route:
			local testClusters = array(clusters.len(), null);
			
			//after adding edge update clusters...like a boss! ->this could definately be made more efficient
			local newClusterNum = clusters[possibleRoutes[j][1]];
			local oldClusterNum = clusters[possibleRoutes[j][0]];
			for(local j = 0; j < clusters.len(); j += 1) {
				if(clusters[j] == oldClusterNum) {
					testClusters[j] = newClusterNum;
				}
				else {
					testClusters[j] = clusters[j];
				}
			}
					
			
			//new recalculate all min paths
			for(local j = 0; j < possibleRoutes.len(); j += 1) {
			
				//if the route already exists don't check
				if(possibleRoutes[j][2] == 1) {
					continue;
				}
				//2 regions in in route
				local region1 = possibleRoutes[j][0];
				local region2 = possibleRoutes[j][1];
				newMinPaths[j] = RoutePlanner.findMinPath(region1, region2, testRoutes, testClusters);
			}
			//record the flow factor:
			for(local i = 0; i < newMinPaths.len(); i += 1) {
			
				if(possibleRoutes[i][2] == 1) {
					continue;
				}
				local oldFlow;
				local newFlow;
				if(possibleRoutes[i][3] == -1) {
					oldFlow = 0;
				}
				else {
					oldFlow = (1.0*possibleRoutes[i][4])/possibleRoutes[i][3];
				}
				if(newMinPaths[i] == -1) {
					newFlow = 0;
				}
				else {
					newFlow = (1.0*possibleRoutes[i][4])/newMinPaths[i];
				}
				
				flowImprovement += (newFlow - oldFlow);
			}		
			
			//now check to see if this candidate is the new best route
			if(flowImprovement > currentFlowImprovement) {
				currentFlowImprovement = flowImprovement;
				currentBest = j;
			}
			
			LogManager.Log(regionalRoutes.len() + " possible route flowImprovement: " + flowImprovement + ", minpath: "  + possibleRoutes[j][3] + ", distance: " + possibleRoutes[j][5] + " from " + possibleRoutes[j][0] + " to " +possibleRoutes[j][1], 4);
		}
		//add best route
		if(currentFlowImprovement < 10) {
			LogManager.Log("to small to add", 4);
			break;
		}
		regionalRoutes.append(possibleRoutes[currentBest]);
		possibleRoutes[currentBest][2] = 1;
		LogManager.Log("added route from: " + possibleRoutes[currentBest][0] + " to " + possibleRoutes[currentBest][1] + "with flowImprovement: " + currentFlowImprovement, 4);
		
		//after adding edge update clusters...like a boss! ->this could definately be made more efficient
		local newClusterNum = clusters[possibleRoutes[currentBest][1]];
		local oldClusterNum = clusters[possibleRoutes[currentBest][0]];
		for(local j = 0; j < clusters.len(); j += 1) {
			if(clusters[j] == oldClusterNum) {
				clusters[j] = newClusterNum;
			}
		}	
	}
	
	foreach(route in regionalRoutes) {
		LogManager.Log("route from: " + route[0] + " to " + route[1] + " with length: " + route[2], 4);
		
		local Xinc =  AIMap.GetTileX(base_regions[route[0]][0]) - AIMap.GetTileX(base_regions[route[1]][0]);
		local Yinc =  AIMap.GetTileY(base_regions[route[0]][0]) - AIMap.GetTileY(base_regions[route[1]][0]);

		local curY = 20*AIMap.GetTileY(base_regions[route[1]][0]);
		local curX = 20*AIMap.GetTileX(base_regions[route[1]][0]);
		for(local i = 0; i < 21; i += 1) {
			Sign(AIMap.GetTileIndex(curX/20, curY/20), "R");
			curY += Yinc;
			curX += Xinc;
		}
	}
	return regionalRoutes;
}

//finds the minimum path between 2 nodes in a weighted graph (Dijkstra's algorithm)
function RoutePlanner::findMinPath(region1, region2, regionalRoutes, clusters) {
	local minPath = -1;
	//LogManager.Log("looking region: " + region1 + " to " + region2, 4);
	if(clusters[region1] != clusters[region2]) {
		return minPath;
	}
	
 	for(local i = 0; i < regionalRoutes.len(); i += 1) {	
		//if there is a direct connection:
		if((regionalRoutes[i][0] == region1 && regionalRoutes[i][1] == region2) ||
			(regionalRoutes[i][0] == region2 && regionalRoutes[i][1] == region1)) {
				minPath = regionalRoutes[i][5];
				//LogManager.Log("direct link from: region " + region1 + " to region " + region2, 4);
			}
		else if (regionalRoutes[i][0] == region1) {
			if(clusters[regionalRoutes[i][1]] == clusters[region1]) {
				//LogManager.Log("recurse", 4);
				local newClusters= array(clusters.len(), null);
				for(local j = 0; j < clusters.len(); j += 1) {
					newClusters[j] = clusters[j];
				}
				newClusters[region1] = -1;
				local recurseValue = RoutePlanner.findMinPath(regionalRoutes[i][1], region2, regionalRoutes, newClusters);
				local tempMinPath = regionalRoutes[i][5] + recurseValue;
				if(recurseValue != -1 && (minPath == -1 || tempMinPath < minPath)) {
					minPath = tempMinPath;
				}
			}
		}
		else if (regionalRoutes[i][1] == region1) {
			if(clusters[regionalRoutes[i][1]] == clusters[region1]) {
				local newClusters= array(clusters.len(), null);
				for(local j = 0; j < clusters.len(); j += 1) {
					newClusters[j] = clusters[j];
				}
				newClusters[region1] = -1;
				local recurseValue = RoutePlanner.findMinPath(regionalRoutes[i][0], region2, regionalRoutes, newClusters);
				local tempMinPath = regionalRoutes[i][5] + recurseValue;
				if(recurseValue != -1 && (minPath == -1 || tempMinPath < minPath)) {
					minPath = tempMinPath;
				}
			}
		}
	}
			
	return minPath;
}

function RoutePlanner::addBaseRegions(regions) {

	for(local i = 0; i < regions[0].len(); i += 1) {
		//LogManager.Log("BASE REGION", 4);
		Sign(regions[0][i], "BASE REGION");
		//ZooElite.BuildBaseStation(regions[1][i], regions[0][i], 1, 0, 0);
	
		base_regions.push([regions[0][i], regions[1][i], null, 0, 0]);
	}
}

function route_compare(a,b)
{
if(a[2]>b[2]) return 1;
else if(a[2]<b[2]) return -1;
return 0;
}

function descendingRouteCompare(a,b)
{
if(a[2]>b[2]) return -1;
else if(a[2]<b[2]) return 1;
return 0;
}



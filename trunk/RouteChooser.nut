class RouteChooser {
	regional_pops = null;
	possibleRoutes = null;
	regionalRoutes = null;
	clusters = null;
	max_routes = 0;
	base_regions = null;
	old_clusters = null;
	last_route_index = 0;
	DISTANCE_MIN = 100;
	
	constructor(base_regions) {
		this.base_regions = base_regions;
		//list of regional populations - saves time to precalculate:
		this.regional_pops = array(base_regions.len(), 0);
		for(local i = 0; i < base_regions.len(); i += 1) {
			foreach(town in base_regions[i][1]) {
				this.regional_pops[i] += SquareRoot(AITown.GetPopulation(town));
			}
		}
	

		//list of all possible regional routes
		this.possibleRoutes = [];
	
		local c = 0;
		//in this loop we initialize possible routes
		for(local i = 0; i < base_regions.len(); i += 1) {
			for(local j = i + 1; j < base_regions.len(); j += 1) {
				local region1 = i;
				local region2 = j;
				local totalPop = this.regional_pops[i] + this.regional_pops[j];
				local distance = SquareRoot(AIMap.DistanceSquare(base_regions[i][0], base_regions[j][0]));
				/*if(distance < DISTANCE_FUDGE) {
					distance = distance*5;
				}*/
			
				//now decide whether to add route:
				if(distance > 0 && distance < 200) {
					local newRoute = array(6,0);
					newRoute[0] = region1;
					newRoute[1] = region2;
					newRoute[2] = 0; //not added yet
					newRoute[3] = -1; //no shortest path yet
					newRoute[4] = totalPop;
					newRoute[5] = distance;
				
					this.possibleRoutes.append(newRoute);
					c += 1;
				}
			}	
		}
	
		LogManager.Log("possible routes length: " + this.possibleRoutes.len(), 4);
		
		this.max_routes = this.possibleRoutes.len()
	
		this.regionalRoutes = [];
		//basically tells what connected piece of the graph a node is in
		this.clusters = array(base_regions.len(), null);
		for(local i = 0; i < this.clusters.len(); i += 1) {
			this.clusters[i] = i;
		}
	
		for(local i = 0; i < this.possibleRoutes.len(); i += 1) {
			LogManager.Log("possible route from " + this.possibleRoutes[i][0] + " to " + this.possibleRoutes[i][1], 4);
		}
	}
	
	
	
	function getNextRoute() {
	
		//holds the route we are currently planning on adding
		local currentBest = 0;
		local currentFlowImprovement = 0;
		
		//we iterate through all routes and see how adding them will effect flow:
		for(local j = 0; j < this.possibleRoutes.len(); j += 1) {
		
			//don't check if already added
			if(this.possibleRoutes[j][2] == 1) {
				continue;
			}
			//if it is two short at beginning
			if(regionalRoutes.len() < 2 && possibleRoutes[j][5] < DISTANCE_MIN) {
				//LogManager.Log("Dont consider route: " + j, 4);
				continue;
			}
			
			local flowImprovement = 0;
			
			//will hold the new minimum paths between routes once the candidate route (j) is added
			local newMinPaths = array(this.possibleRoutes.len(), -1);
			
			//a clone of regionalRoutes that we add the candidate route to
			local testRoutes = [];
			
			for(local k = 0; k < this.regionalRoutes.len(); k += 1){
					testRoutes.append(this.regionalRoutes[k]);
				}
			//add on the candidate route
			testRoutes.append(this.possibleRoutes[j]);
			
			//a clone of clusters updated to reflect the addition of the candidate route:
			local testClusters = array(clusters.len(), null);
			
			//after adding edge update clusters...like a boss! ->this could definately be made more efficient
			local newClusterNum = this.clusters[this.possibleRoutes[j][1]];
			local oldClusterNum = this.clusters[this.possibleRoutes[j][0]];
			for(local j = 0; j < this.clusters.len(); j += 1) {
				if(this.clusters[j] == oldClusterNum) {
					testClusters[j] = newClusterNum;
				}
				else {
					testClusters[j] = this.clusters[j];
				}
			}
					
			
			//new recalculate all min paths
			for(local j = 0; j < this.possibleRoutes.len(); j += 1) {
			
				//if the route already exists don't check
				if(this.possibleRoutes[j][2] == 1) {
					continue;
				}
				//2 regions in in route
				local region1 = this.possibleRoutes[j][0];
				local region2 = this.possibleRoutes[j][1];
				newMinPaths[j] = RoutePlanner.findMinPath(region1, region2, testRoutes, testClusters);
			}
			//record the flow factor:
			for(local i = 0; i < newMinPaths.len(); i += 1) {
			
				if(this.possibleRoutes[i][2] == 1) {
					continue;
				}
				local oldFlow;
				local newFlow;
				if(this.possibleRoutes[i][3] == -1) {
					oldFlow = 0;
				}
				else {
					oldFlow = (1.0*this.possibleRoutes[i][4])/this.possibleRoutes[i][3];
				}
				if(newMinPaths[i] == -1) {
					newFlow = 0;
				}
				else {
					newFlow = (1.0*this.possibleRoutes[i][4])/newMinPaths[i];
				}
				
				flowImprovement += (newFlow - oldFlow);
			}		
			
			//now check to see if this candidate is the new best route
			if(flowImprovement > currentFlowImprovement) {
				currentFlowImprovement = flowImprovement;
				currentBest = j;
			}
			
			//LogManager.Log(this.regionalRoutes.len() + " possible route flowImprovement: " + flowImprovement + ", minpath: "  + this.possibleRoutes[j][3] + ", distance: " + this.possibleRoutes[j][5] + " from " + this.possibleRoutes[j][0] + " to " +this.possibleRoutes[j][1], 4);
		}
		//add best route
		if(currentFlowImprovement < 0) {
			LogManager.Log("to small to add", 4);
			return null;
		}
		this.regionalRoutes.append(possibleRoutes[currentBest]);
		this.possibleRoutes[currentBest][2] = 1;
		LogManager.Log("added route from: " + this.possibleRoutes[currentBest][0] + " to " + this.possibleRoutes[currentBest][1] + "with flowImprovement: " + currentFlowImprovement, 4);
		
		//after adding edge update clusters...like a boss! ->this could definately be made more efficient
		
		local newClusterNum = this.clusters[possibleRoutes[currentBest][1]];
		local oldClusterNum = this.clusters[possibleRoutes[currentBest][0]];
		this.old_clusters = array(this.clusters.len(), 0);
		for(local j = 0; j < this.clusters.len(); j += 1) {
			this.old_clusters[j] = this.clusters[j];
			if(this.clusters[j] == oldClusterNum) {
				this.clusters[j] = newClusterNum;
			}
		}	
	
		local route = this.possibleRoutes[currentBest];
		this.last_route_index = currentBest;
		LogManager.Log("route from: " + route[0] + " to " + route[1] + " with length: " + route[2], 4);
		
		local Xinc =  AIMap.GetTileX(this.base_regions[route[0]][0]) - AIMap.GetTileX(this.base_regions[route[1]][0]);
		local Yinc =  AIMap.GetTileY(this.base_regions[route[0]][0]) - AIMap.GetTileY(this.base_regions[route[1]][0]);

		local curY = 20*AIMap.GetTileY(this.base_regions[route[1]][0]);
		local curX = 20*AIMap.GetTileX(this.base_regions[route[1]][0]);
		for(local i = 0; i < 21; i += 1) {
			Sign(AIMap.GetTileIndex(curX/20, curY/20), "R");
			curY += Yinc;
			curX += Xinc;
		}
		
		return route;
	}

	//this is basically if a station fucks up
	function unGetRoute() { 
		LogManager.Log("need to unget route", 4);
		this.regionalRoutes.pop();
		this.clusters = this.old_clusters;
		this.possibleRoutes[this.last_route_index][4] = 0;
	}
}
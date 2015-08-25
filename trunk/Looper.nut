require("log_manager.nut");
require("constants.nut");
require("helper.nut");
require("obects/town.nut");
require("obects/station.nut");
require("RouteChooser.nut");

class Looper {
	static LOANS_ON = true;
};

function Looper::Loop() {

	LogManager.Log(AIMap.IsValidTile(AIMap.GetTileIndex(1,1)), 4);
	LogManager.Log(AIMap.IsValidTile(AIMap.GetTileIndex(AIMap.GetMapSizeX()-2, AIMap.GetMapSizeY()-2)), 4);
	
	Sign(AIMap.GetTileIndex(1,1), "TOP");
	Sign(AIMap.GetTileIndex(AIMap.GetMapSizeX()-2, AIMap.GetMapSizeY()-2), "BOTTOM");

	local VEHICLE_UPDATE = 2;
	local BUILD_ROUTE = 2;
	local MANAGE_FUNDS = 1;
	local CLEAR_LOAN = 5;
	
	
	//first divide map into small regions
	local towns = AITownList();
	RoutePlanner.getBaseRegions(towns);
	
	//the object that will spit out routes:
	local route_chooser = RouteChooser(base_regions);
	local i = 0;
	//we have a counter to decide how often to do tasks
	local counter = 0;
	//this counts number of routes actually contructed
	local built = 0;
	local stored_route = null;
	
	while(true) {
		LogManager.Log("Main Loop",4);
		//ClearSigns();
		
		counter++;
		built++;
		
		if(built % CLEAR_LOAN == 0) {
			/*while(AICompany.GetLoanAmount() > 0) {
				AICompany.SetLoanAmount(AICompany.GetLoanAmount() - AICompany.GetLoanInterval());
			}*/
			//LOANS_ON = false;
		}
		if(counter % MANAGE_FUNDS == 0) {
			local balance = AICompany.GetBankBalance(AICompany.ResolveCompanyID(AICompany.COMPANY_SELF));
			while(balance > 80000) {
				AICompany.SetLoanAmount(AICompany.GetLoanAmount() - AICompany.GetLoanInterval());
				balance = AICompany.GetBankBalance(AICompany.ResolveCompanyID(AICompany.COMPANY_SELF));
			}
			while(balance < 50000) {
				if(LOANS_ON) {
					AICompany.SetLoanAmount(AICompany.GetLoanAmount() + AICompany.GetLoanInterval());
				}
				else {
					ZooElite.Sleep(500);
				}
				balance = AICompany.GetBankBalance(AICompany.ResolveCompanyID(AICompany.COMPANY_SELF));
			}
		}
				
		if(counter % VEHICLE_UPDATE == 0) {
			foreach(town in added_towns) {
				ZooElite.AdjustBusesInTown(town);
			}
			foreach(route in route_table) {
				route.balanceRailService();
			}
		}
		
		if(counter % BUILD_ROUTE == 0) {
			local route;
			
			if(stored_route == null) {
				LogManager.Log("Going to get route", 4);
				route = route_chooser.getNextRoute();
			}
			else {
				route = stored_route;
				stored_route == null;
			}
			
			//we shouldn't build if we're too poor
			if(false) {//AICompany.GetBankBalance(AICompany.COMPANY_SELF)) {
				/*LogManager.Log("need to wait for more money", 4);
				this.Sleep(500);
				stored_route = route;
				continue;*/
			}
			
			//go ahead and build
			else {
				if(route == null) {
					LogManager.Log("Wow! Endgame.", 4);
					return 0;
				}
				else {
					LogManager.Log("About to start actual route construction", 4);
					if(base_regions[route[0]][3] == 0) {
						base_regions[route[0]][2] = ZooElite.BuildBaseStation(base_regions[route[0]][1], base_regions[route[0]][0], 0);
						base_regions[route[0]][3] = 1;
					}
					
					if(base_regions[route[1]][3] == 0) {
						base_regions[route[1]][2] = ZooElite.BuildBaseStation(base_regions[route[1]][1], base_regions[route[1]][0], 0);
						base_regions[route[1]][3] = 1;
					}
						
					local new_route = false;
						
					if(base_regions[route[0]][2] != false && base_regions[route[1]][2] != false) {
						local balance = AICompany.GetBankBalance(AICompany.ResolveCompanyID(AICompany.COMPANY_SELF));
						LogManager.Log("Before tracking, balance is: " + balance, 4);
						GetMoney(50000);
						
						if(built < 3) {
							new_route = ZooElite.ConnectStations(1, 350, base_regions[route[0]][2], base_regions[route[1]][2], 0, 0);
						}
						else {
							new_route = ZooElite.ConnectStations(1, 100, base_regions[route[0]][2], base_regions[route[1]][2], 0, 0);
						}
					}
					else {   //one of the base stations failed so we aren't going to build the route
						route_chooser.unGetRoute();
						LogManager.Log("Backtracked due to bus failure", 4);
						built--;
						continue;
					}
						
					if(base_regions[route[0]][4] == 0 && new_route) {
						ZooElite.ConnectBaseRegion(base_regions[route[0]]);
						base_regions[route[0]][4] = 1;
					}
					if(base_regions[route[1]][4] == 0 && new_route) {
						ZooElite.ConnectBaseRegion(base_regions[route[1]]);
						base_regions[route[1]][4] = 1;
					}
					
					if(!new_route) { //something failed
						route_chooser.unGetRoute();
						LogManager.Log("Backtracked due to route failure", 4);
						built--;
						continue;
					
					}
				}
			}
		}
		//END new route building
				
	}
}
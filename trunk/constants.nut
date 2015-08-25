//Constants

const SAFETY_MARGIN = 2500;	// extra money to keep around for bankrupcy checks
const STATION_REUSE_DISTANCE_FROM_TOWN = 30; //Maximum distance from any given city a station must be to be reused
const RAIL_STATION_PLATFORM_LENGTH = 6; //Shouldn't it just be constant? Of course.
const RAILSTATION_IN_DIRECTION_OF_FLEX = 8; //When finding rail placements, this is how much deviation it will allow the station to be NOT in the direction of the dest tile from the seed_tile.
const RAIL_ACTUAL_COST_WEIGHT = 2; //Weight of actual cost to level/build
const RAIL_STATION_SEARCH_DISTANCE_WEIGHT = 1; //Larger give more weight to distance from search tile - Originally 4
const RAIL_STATION_SEARCH_CARGO_WEIGHT = 2; //Larger gives more weight to the station being close to passengers - Originally 2
const BUS_RADIUS_MULTIPLIER = 1.4; //Multiplier * sqrrt of houses in town gives search radius. Raise to allow more deviation from a square configuration, but longer search times
const CITY_BUS_CAPACITY_THRESHOLD = 0.7; //If the transported cargo falls under this percent of production, more busses will be created
const CITY_BUS_CAPACITY_TARGET = 0.8; //Should be higher than threshold...target pct to rebalance to when checking busses (Should be < 1)
const DOWN_TRACK_SPACE = 3; //Length tracks must be able to run from station
const SIGNAL_SPACING = 6; //Obvious
const RAIL_STATION_SEARCH_RADIUS = 15; //Radius around given point to search. Trade-offs obvious. Shouldn't be larger than about 30, also should be <= STATION_REUSE_DISTANCE_FROM_TOWN
const SATURATION_CONSTANT = 4; //Lower constant means a lower bus saturation point

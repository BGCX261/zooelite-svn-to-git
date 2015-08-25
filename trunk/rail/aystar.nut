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


/* Based on OpenTTD AyStar library. */
class AyStarNode {
	tile = null;
	part_index = null;
	reference_part_index = null;
	parent_node = null;
	user_data = null;/* TODO: Choose a better name. */
	f = null;
	g = null;
	h = null;

	constructor(tile , part_index , reference_part_index , user_data , parent_node , g , h){
		this.tile = tile;
		this.part_index = part_index;
		this.reference_part_index = reference_part_index;
		this.user_data = user_data;
		this.parent_node = parent_node;
		this.g = g;
		this.h = h;
		f = g + h;
	}

	static function CompareForSearch(n1 , n2){
		if(n1.tile > n2.tile) return 1;
		else if(n1.tile < n2.tile) return -1;
		else{
			if(n1.part_index > n2.part_index){
				return 1;
			}else if(n1.part_index < n2.part_index){
				return -1;
			}else
				return n1.reference_part_index - n2.reference_part_index;
		}
	}

	static function FindNode(tile , part_index , reference_part_index , nodes){
		local left , right , middle;
		local node = AyStarNode(tile , part_index , reference_part_index , null , null , 0 , 0);

		left = 0;
		right = nodes.len() - 1;
		while(left <= right){
			local aux;

			middle = (left + right)/2;
			aux = AyStarNode.CompareForSearch(nodes[middle] ,  node);
			if(aux > 0)
				right = middle - 1;
			else if(aux < 0)
				left = middle + 1;
			else
				return nodes[middle];
		}
		return null;
	}

	/* Compare for Heap. */
	function _cmp(other) {
		if(this.f == other.f){
			if(this.h == other.h){
				local this_changes_direction = 0;
				local other_changes_direction = 0;
				local dtp = ::ai_instance.dtp;

				if(this.parent_node != null && dtp.ChangedDirection(this.parent_node.part_index , part_index))
					this_changes_direction = 1;
				if(other.parent_node != null && dtp.ChangedDirection(other.parent_node.part_index , other.part_index))
					other_changes_direction = 1;

				if(this_changes_direction == other_changes_direction){
					if(dtp.IsLine(part_index)) return -1;
					else if(dtp.IsLine(other.part_index)) return 1;
					else return 0;
				}else return this_changes_direction - other_changes_direction;
			}else return h - other.h;
		}else return f - other.f;
	}

	function _tostring(){
		return "<" + Tile.ToString(tile) + " , " + ::ai_instance.dtp.ToString(part_index) + ">";
	}
};

class Path {
	parent_path = null;
	child_path = null;

	tile = null;
	part_index = null;
	user_data = null;
	depot_information = null;
	junction_information = null;

	constructor(node){
		tile = node.tile;
		part_index = node.part_index;
		user_data = node.user_data;
	}

	function reversePath() {
		local path_count = this.Count();
		//local test = this.child_path;
		local new_path = null;
		local previous_path = null;
		local current_path = null;
		local i = 2;
		while(i <= path_count) {
			current_path = this.getSwitchedTile(path_count-i);
			current_path.parent_path = previous_path;
			if(previous_path != null) {
				previous_path.child_path = current_path;
			}
			previous_path = current_path;
			if(i == 2) {
				new_path = current_path;
			}
			//LogManager.Log("current path has" + i + " has tileId " + current_path.tile, 4);
			i += 1;
		}
		
		LogManager.Log("new path tile is " + new_path.tile, 4);
		return new_path;
		/*if(this.child_path != null) {
			this.child_path.reversePath();
			this.child_path.child_path = this;
			this.parent_path = this.child_path;
			this.child_path = null;
		}*/
	}
	
	function getSwitchedTile(tile_num) {
		
		local i = 0;
		local path = this;
		//if(path == null){
		//	LogManager.Log("fuck", 4);
		//}
		while(i < tile_num){
			path = path.child_path;
			i++;
		}
		
		local dtp = DoubleTrackParts();
		if(path.part_index == DoubleTrackParts.BRIDGE){
			local user_data = path.user_data;
			local new_user_data = BridgeInformation();
			new_user_data.exit_tile = user_data.start_tile;
			new_user_data.start_tile = user_data.exit_tile;
			new_user_data.part_index = dtp.GetOppositePart(user_data.part_index);
			new_user_data.primary_bridges = user_data.primary_bridges;
			new_user_data.secondary_bridges = user_data.secondary_bridges;
			new_user_data.secondary_rail_offset = user_data.secondary_rail_offset ;
				
			local new_path = Path(AyStarNode(path.tile , path.part_index, 0 , new_user_data, null , 0 , 0));
			return new_path;
		}
		else {		
			local new_path = Path(AyStarNode(path.tile , dtp.GetOppositePart(path.part_index), 0 , null , null , 0 , 0));
			//LogManager.Log("switched tile " + tile_num + " has tileId " + new_path.tile, 4);
			return new_path;
		}
	}
	
	function Count() {
		local count = 1;
		local path = this;

		while(path != null){
			count++;
			path = path.child_path;
		}
		return count;
	}

	function Append(path_to_append){
		local path = this;
		while(path.child_path != null) path = path.child_path;
		path.child_path = path_to_append;
		path_to_append.parent_path = path;
	}
}

class AyStar {
	/* Public: */
	constructor(cost_callback , estimate_callback , neighbours_callback , end_node_callback ,
		cost_callback_param = null , estimate_callback_param = null , neighbours_callback_param = null ,
		end_node_callback_param = null){

		if(typeof(cost_callback) != "function")
			throw("'cost_callback' has to be a function-pointer.");
		if(typeof(estimate_callback) != "function")
			throw("'estimate_callback' has to be a function-pointer.");
		if(typeof(neighbours_callback) != "function")
			throw("'neighbours_callback' has to be a function-pointer.");
		if(typeof(end_node_callback) != "function")
			throw("'end_node_callback' has to be a function-pointer.");

		this.cost_callback = cost_callback;
		this.estimate_callback = estimate_callback;
		this.neighbours_callback = neighbours_callback;
		this.end_node_callback = end_node_callback;

		this.cost_callback_param = cost_callback_param;
		this.estimate_callback_param = estimate_callback_param;
		this.neighbours_callback_param = neighbours_callback_param;
		this.end_node_callback_param = end_node_callback_param;
		dtp = ::ai_instance.dtp;
	}
	function InitializePath(sources);
	function FindPath(iterations);

	/* Private: */
	static offsets = [[0 , 1] , [1 , 0] , [0 , -1] , [-1 , 0] , [-1 , -1] , [1 , -1] , [-1 , 1] , [1 , 1]];

	cost_callback = null;
	cost_callback_param = null;

	estimate_callback = null;
	estimate_callback_param = null;

	neighbours_callback = null;
	neighbours_callback_param = null;

	end_node_callback = null;
	end_node_callback_param = null;

	open = null;
	closed = null;
	nodes = null;
	dtp = null;

	function CreateNode(tile , part_index , user_data);
	function CreateFinalPath(node);
	function ExpandNodeNeighbours(parent_node);
	function InsertInClosedList(tile , part_index , reference_part_index);
	function IsInClosedList(tile , part_index , reference_part_index);
	function InsertNode(node);
}

function AyStar::CreateNode(tile , part_index , user_data , parent_node){
	local reference_part_index = dtp.IsBridgeOrTunnel(part_index) ? user_data.part_index : 0;
	return AyStarNode(tile , part_index , reference_part_index , user_data , parent_node ,
		cost_callback(parent_node , tile , part_index , user_data , cost_callback_param) ,
		estimate_callback(parent_node , tile , part_index , user_data , estimate_callback_param));
}

function AyStar::InsertInClosedList(tile , part_index , reference_part_index){
	switch(part_index){
		case DoubleTrackParts.BRIDGE:
			assert(reference_part_index != null && dtp.IsLine(reference_part_index));
			part_index = (1 << part_index) | (reference_part_index << (DoubleTrackParts.BRIDGE + 1 + 4));
		break;
		case DoubleTrackParts.TUNNEL:
			assert(reference_part_index != null && dtp.IsLine(reference_part_index));
			part_index = (1 << part_index) | (reference_part_index << (DoubleTrackParts.BRIDGE + 1));
		break;
		default:
			part_index = 1 << part_index;
		break;
	}
	if(closed.HasItem(tile)){
		local v = closed.GetValue(tile);
		v = v | part_index;
		closed.ChangeItem(tile , v);
	}else{
		closed.AddItem(tile , part_index);
	}
}

function AyStar::IsInClosedList(tile , part_index , reference_part_index){
	switch(part_index){
		case DoubleTrackParts.BRIDGE:
			assert(dtp.IsLine(reference_part_index));
			part_index = (1 << part_index) | (reference_part_index << (DoubleTrackParts.BRIDGE + 1 + 4));
		break;
		case DoubleTrackParts.TUNNEL:
			assert(dtp.IsLine(reference_part_index));
			part_index = (1 << part_index) | (reference_part_index << (DoubleTrackParts.BRIDGE + 1));
		break;
		default:
			part_index = 1 << part_index;
		break;
	}
	if(closed.HasItem(tile)){
		local v = closed.GetValue(tile);
		if((v & part_index) == part_index) return true;
	}
	return false;
}

function AyStar::InsertNode(node){
	nodes.push(node);
}

function AyStar::ExpandNodeNeighbours(parent_node){
	local neighbour_nodes = neighbours_callback(parent_node , neighbours_callback_param);

	foreach(neighbour_node in neighbour_nodes){
		local node = CreateNode(neighbour_node[0] , neighbour_node[1] , neighbour_node[2] , parent_node);

		if(node.g != 0){
			open.Insert(node);
			InsertNode(node);
			InsertInClosedList(neighbour_node[1] == DoubleTrackParts.BRIDGE ? neighbour_node[2].start_tile :
				neighbour_node[0] , neighbour_node[1] , node.reference_part_index);
		}
	}
}

function AyStar::InitializePath(source_nodes , ignored_nodes){
	if(typeof(source_nodes) != "array" || source_nodes.len() == 0)
		throw("'source_nodes' has be a non-empty array.");
	if(typeof(ignored_nodes) != "array") throw("'ignored_nodes' has be an array.");

	this.open = BinaryHeap();
	this.closed = AIList();
	nodes = array(0);/* TODO: Maybe use a hash here. */

	foreach(ignored_node in ignored_nodes)
		InsertInClosedList(ignored_node[1] == DoubleTrackParts.BRIDGE ? ignored_node[2].start_tile :
			ignored_node[0] , ignored_node[1] , ignored_node[2]);

	foreach(source_node in source_nodes){
		local node = CreateNode(source_node[0] , source_node[1] , source_node[2] , null);

		assert(!end_node_callback(node , end_node_callback_param));
		InsertNode(node);
		InsertInClosedList(source_node[1] == DoubleTrackParts.BRIDGE ? source_node[2].start_tile : source_node[0] ,
			source_node[1] , node.reference_part_index);
		ExpandNodeNeighbours(node);
	}
}

function AyStar::CreateFinalPath(node){
	local lowest_cost_node , parent_tile , tile , part_index , path = Path(node) , parent_path;

	nodes.sort(AyStarNode.CompareForSearch);

	while(true){
		lowest_cost_node = null;
		foreach(offset in offsets){
			part_index = path.part_index;

			if(part_index == DoubleTrackParts.BRIDGE){
				local user_data = path.user_data;

				tile = user_data.start_tile
				part_index = user_data.part_index;
				switch(part_index){
					case dtp.EW_LINE:
						tile += AIMap.GetTileIndex(1 , 0);
					break;
					case DoubleTrackParts.NS_LINE:
						tile += AIMap.GetTileIndex(0 , 1);
					break;
				}
			}else
				tile = path.tile;
			parent_tile = tile + AIMap.GetTileIndex(offset[0] , offset[1]);

			/* Iterate over the previous parts. */
			foreach(parent_part_index in dtp.parts[part_index].previous_parts){
				if(parent_tile + dtp.parts[parent_part_index].next_tile != tile) continue;

				node = AyStarNode.FindNode(parent_tile , parent_part_index , 0 , nodes);
				if(node != null && (lowest_cost_node == null || lowest_cost_node.g > node.g))
					lowest_cost_node = node;

				/* Try to find a bridge. */
				if(dtp.IsLine(parent_part_index)){
					node = AyStarNode.FindNode(parent_tile , DoubleTrackParts.BRIDGE , parent_part_index , nodes);
					if(node != null && (lowest_cost_node == null || lowest_cost_node.g > node.g))
						lowest_cost_node = node;
				}
			}
		}
		assert(lowest_cost_node != null);
		parent_path = Path(lowest_cost_node);
		path.parent_path = parent_path;
		parent_path.child_path = path;
		path = parent_path;
		if(lowest_cost_node.parent_node.parent_node == null)
			break;
	}

	return path;
}

function AyStar::FindPath(iterations = -1){
	if(open == null) throw("can't execute over an uninitialized path");

	while(open.Count() > 0 && (iterations == -1 || iterations-- > 0)){
		/* Get the node with the best score so far. */
		local node = open.Pop();

		/* Check if we found the end */
		if(end_node_callback(node , end_node_callback_param)){
			LogManager.Log("Visited nodes: " + nodes.len().tostring() + ".", 4);
			return CreateFinalPath(node);
		/* Scan all neighbours */
		}else
			ExpandNodeNeighbours(node);
	}

	if(open.Count() > 0) return false;
	CleanPath();
	return null;
}

function AyStar::CleanPath(){
	this.closed = null;
	this.open = null;
	this.nodes = null;
}

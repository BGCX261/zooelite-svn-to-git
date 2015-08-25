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


/* Based on OpenTTD Binary Heap library. */

/**
 * Binary Heap.
 *  Peek and Pop always return the current lowest value in the list.
 *  Sort is done on insertion and on deletion.
 */
class BinaryHeap {
	queue = null;
	count = 0;

	constructor(){
		queue = array(0);
	}

	/**
	 * Insert a new entry in the list.
	 *  The complexity of this operation is O(ln n).
	 * @param item The item to add to the list.
	 */
	function Insert(item);

	/**
	 * Pop the first entry of the list.
	 *  This is always the item with the lowest priority.
	 *  The complexity of this operation is O(ln n).
	 * @return The item of the entry with the lowest priority.
	 */
	function Pop();

	/**
	 * Peek the first entry of the list.
	 *  This is always the item with the lowest priority.
	 *  The complexity of this operation is O(1).
	 * @return The item of the entry with the lowest priority.
	 */
	function Peek();

	/**
	 * Get the amount of current items in the list.
	 *  The complexity of this operation is O(1).
	 * @return The amount of items currently in the list.
	 */
	function Count();

	/**
	 * Check if an item exists in the list.
	 *  The complexity of this operation is O(n).
	 * @param item The item to check for.
	 * @return True if the item is already in the list.
	 */
	function Exists(item);
};

function BinaryHeap::Insert(item){
	/* Append dummy entry */
	queue.append(null);
	count++;

	local hole;
	/* Find the point of insertion */
	for(hole = count - 1 ; hole > 0 && item <= queue[hole / 2] ; hole /= 2)
		queue[hole] = queue[hole / 2];
	/* Insert new pair */
	queue[hole] = item;

	return true;
}

function BinaryHeap::Pop(){
	if(count == 0) return null;

	local node = queue[0];
	/* Remove the item from the list by putting the last value on top */
	queue[0] = queue[count - 1];
	queue.pop();
	count--;
	/* Bubble down the last value to correct the tree again */
	BubbleDown();

	return node;
}

function BinaryHeap::Peek(){
	if(count == 0) return null;

	return queue[0];
}

function BinaryHeap::Count(){
	return count;
}

function BinaryHeap::Exists(item){
	/* Brute-force find the item (there is no faster way, as we don't have the priority number) */
	foreach(node in queue){
		if(item.Equals(node)) return node;
	}

	return null;
}

function BinaryHeap::BubbleDown(){
	if(count == 0) return;

	local hole = 1;
	local tmp = queue[0];

	/* Start switching parent and child until the tree is restored */
	while(hole * 2 < count + 1) {
		local child = hole * 2;
		if(child != count && queue[child] <= queue[child - 1]) child++;
		if(queue[child - 1] > tmp) break;

		queue[hole - 1] = queue[child - 1];
		hole = child;
	}
	/* The top value is now at his new place */
	queue[hole - 1] = tmp;
}

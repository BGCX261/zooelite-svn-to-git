/*
 * ZooElite - An AI for OpenTTD
 * Copyright (C) 2009  Charlie Croom and Cameron Muesco
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


class LogManager {
	/* Public: */
	static function Log(message, level);

	/* Private: */
	static function PrintErrorMessage(message);
	static function PrintLogMessage(message);
	static function PrintWarningMessage(message);
}

function LogManager::Log(message, level){
	if(level == 4) {
		LogManager.PrintWarningMessage(message);
	} else if(level == 5) {
		LogManager.PrintErrorMessage(message);
	} else if(level >= ZooElite.GetSetting("debug_level")) {
		LogManager.PrintLogMessage(message);
	}
	//Eat the message since it's below our logging level
}

function LogManager::PrintErrorMessage(message){
	AILog.Error(LogManager.GetCurrentDateString() + ": " + message);
}

function LogManager::PrintLogMessage(message){
	AILog.Info(LogManager.GetCurrentDateString() + ": " + message);
}

function LogManager::PrintWarningMessage(message){
	AILog.Warning(LogManager.GetCurrentDateString() + ": " + message);
}

function LogManager::GetCurrentDateString(){
	local now = AIDate.GetCurrentDate();
	local day = AIDate.GetDayOfMonth(now);
	local month = AIDate.GetMonth(now);

	day = day <= 9 ? "0" + day.tostring() : day.tostring();
	month = month <= 9 ? "0" + month.tostring() : month.tostring();

	return day + "/" + month + "/" + AIDate.GetYear(now).tostring();
}

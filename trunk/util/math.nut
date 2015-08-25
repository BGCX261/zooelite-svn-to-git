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


class Math {

	static function sqrt(a){
		local i , b , delta , p , x , z;
		local c = [1.01865 , -2.17822 , 2.06854 , 0.10112];

		p = 1.0;
		b = a;

		if(a > 1.0){
			do{
				b *= 0.01;
				p *= 10.0;
			}while(b > 1.0);
		}

		if(a < 0.01){
			do{
				b *= 100.0;
				p *= 0.1;
			}while(b <= 0.01);
		}

		z = c[0];
		i = 1;
		while(i <= 3){
			z = z * b + c[i];
         i++;
		}

		z = z * p;
      i = 0;
		do{
			x = (z + a/z) * 0.5;
			delta = x - z;
			if(delta < 0) delta = -delta;
			z = x;
		}while(delta >= 0.0001 && ++i < 100);

		return x;
	}
}

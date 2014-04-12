# watch-fm Pebble Watch Face

A last.fm album art watchface for the pebble smart watch. Watches your last.fm recently played stream and updates current track and album art.

## Build Instructions

Clone this repository in an appropriate directory:

	git clone https://github.com/bitbased/watch-fm.git

Prerequisites:

This project uses coffeescript for cleaner JS code. `wscript` has been modified to concatenate all js resources into `pebble-js-app.js` with `.js` resources above `.coffee` resources.

    pip install CoffeeScript

Build:

    pebble build

Install:

	pebble install --phone [phone ip here]

## License

Copyright (C) 2014 Brant Wedel

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.

You may contact the author at brant@bitbased.net

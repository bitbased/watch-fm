# watch-fm Pebble Watch Face

A last.fm album art watchface for the pebble smart watch. Watches your last.fm recently played stream and updates current track and album art.

![screenshot](https://cloud.githubusercontent.com/assets/1801892/8323613/7081fca4-1a0c-11e5-9dc1-224677e78e3f.png)

Download: https://apps.getpebble.com/en_US/application/5348549aa093cd29b2000051

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

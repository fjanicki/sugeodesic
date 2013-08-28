#	Geodesic Dome Creator - A plug-in for SketchUp for creating Geodesic Domes
#    Copyright (C) 2013 Paul Matthews
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

#
# Initializer for Geodesic Dome Creator

require 'sketchup.rb'
require 'extensions.rb'


# Load the extension.
extension_name = ("Geodesic Dome Creator")

fs_extension = SketchupExtension.new(
    extension_name, "su_geodesic/actloader.rb")


fs_extension.description = ("Use the Geodesic Dome Creator " +
	"to create full customized domes in a matter of minutes. Customize the size, " +
	"frequency, base platonic solid and much more.")

fs_extension.version = "0.1.2"
fs_extension.creator = "Paul Matthews"
fs_extension.copyright = "2013, Paul Matthews"

# Register the extension with Sketchup.
Sketchup.register_extension fs_extension, true

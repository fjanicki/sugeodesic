#	Geodesic Dome Creator allows you to create fully customized Geodesic 
#	Domes from within SketchUp
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

# First we pull in the standard API hooks.
require 'sketchup.rb'


class Geodesic
	#Main Configuration items
	@@g_frequency = 3
	@@g_radius = 150
	@@g_platonic_solid = 8
	@@g_fraction = 0.5
	@@g_center = Geom::Point3d.new ([0, 0, -@@g_radius + 2 * @@g_radius * @@g_fraction])
	
	@@draw_primitive_solid_faces = 0
	@@primitive_face_material = [rand(255), rand(255), rand(255)]

	@@draw_tesselated_faces = 0
	@@tesselated_face_material = [rand(255), rand(255), rand(255)]
	
	#Metal hub configuration
	@@draw_metal_hubs = 1
	@@metal_hub_outer_radius = 2.25
	@@metal_hub_outer_thickness = 0.25
	@@metal_hub_depth_depth = 4

	#Wood strut configuration
	@@draw_wood_struts = 1
	@@wood_strut_dist_from_hub = 3
	@@wood_strut_thickness = 1.5
	@@wood_strut_depth = 3.5

	@@wood_strut_material = Sketchup::Color.new(255,215,0)


	
	#created dome data is stored in these arrays
	@@primitive_points = []
	@@strut_points = []
	@@strut_hubs = []

	
	#tolerance factor to circumvent small number errors
	@@g_tolerance = 0.5
	
	def draw()
			#Create the base Geodesic Dome points
			if (@@g_platonic_solid == 4)
				create_tetrahedron()							
			end
			if (@@g_platonic_solid == 8)
				create_octahedron()				
			end
			if (@@g_platonic_solid == 20)
				create_icosahedron()
			end
			
			if (@@draw_metal_hubs == 1)
				add_metal_hubs()
			end
			
			#Add wooden struts
			if(@@draw_wood_struts == 1)
				add_wood_struts()
			end
						
	end
	
	#Creates the points of the tesselated tetrahedron
	#the points from this are used to draw all other aspects of the dome
	def create_tetrahedron()
		# Get handles to our model and the Entities collection it contains.
		model = Sketchup.active_model
		entities = model.entities

		#Get the length of a side
		r2 = @@g_radius / 2
		
		#translation transformation to account for the origin centered start and the fraction of dome desired
		t = Geom::Transformation.translation(@@g_center)
		
		#Create the points of the tetrahedron
		tetrahedron = []
		tetrahedron.push(Geom::Point3d.new([0, r2, r2]).transform!(t))
		tetrahedron.push(Geom::Point3d.new([0, -r2, r2]).transform!(t))
		tetrahedron.push(Geom::Point3d.new([r2, 0, -r2]).transform!(t))
		tetrahedron.push(Geom::Point3d.new([-r2, 0, -r2]).transform!(t))

		# draw the triangles of the tetrahedron
		tetra_faces = []
		if(@@draw_primitive_solid_faces == 1)
			tetra_faces.push(entities.add_face(tetrahedron[0], tetrahedron[1], tetrahedron[3]))
			tetra_faces.push(entities.add_face(tetrahedron[1], tetrahedron[2], tetrahedron[3]))
			tetra_faces.push(entities.add_face(tetrahedron[2], tetrahedron[0], tetrahedron[3]))
			tetra_faces.push(entities.add_face(tetrahedron[0], tetrahedron[1], tetrahedron[2]))
		end
		
		#decompose each face of the tetrahedron
		tesselate(tetrahedron[0], tetrahedron[1], tetrahedron[3])
		tesselate(tetrahedron[1], tetrahedron[2], tetrahedron[3])
		tesselate(tetrahedron[2], tetrahedron[0], tetrahedron[3])
		tesselate(tetrahedron[0], tetrahedron[1], tetrahedron[2])
	end

	
	#Creates the points of the tesselated octahedron
	#the points from this are used to draw all other aspects of the dome
	def create_octahedron()
		# Get handles to our model and the Entities collection it contains.
		model = Sketchup.active_model
		entities = model.entities

		#Get the length of a side
		a = @@g_radius * Math.sqrt(2) / 2
		
		#translation transformation to account for the origin centered start and the fraction of dome desired
		t = Geom::Transformation.translation(@@g_center)
		
		#Create the points of the octahedron
		octahedron = []
		octahedron.push(Geom::Point3d.new([-a, -a, 0]).transform!(t))
		octahedron.push(Geom::Point3d.new([a, -a, 0]).transform!(t))
		octahedron.push(Geom::Point3d.new([a, a, 0]).transform!(t))
		octahedron.push(Geom::Point3d.new([-a, a, 0]).transform!(t))
		octahedron.push(Geom::Point3d.new([0, 0, @@g_radius]).transform!(t))
		octahedron.push(Geom::Point3d.new([0, 0, -@@g_radius]).transform!(t))
		
		# draw the triangles of the octahedron
		octa_faces = []
		if(@@draw_primitive_solid_faces == 1)
			octa_faces.push(entities.add_face (octahedron[0], octahedron[1], octahedron[4]))
			octa_faces.push(entities.add_face octahedron[1], octahedron[2], octahedron[4])
			octa_faces.push(entities.add_face octahedron[2], octahedron[3], octahedron[4])
			octa_faces.push(entities.add_face octahedron[3], octahedron[0], octahedron[4])
			octa_faces.push(entities.add_face octahedron[0], octahedron[1], octahedron[5])
			octa_faces.push(entities.add_face octahedron[1], octahedron[2], octahedron[5])
			octa_faces.push(entities.add_face octahedron[2], octahedron[3], octahedron[5])
			octa_faces.push(entities.add_face octahedron[3], octahedron[0], octahedron[5])
		end
		
		#decompose each face of the octahedron
		tesselate(octahedron[0], octahedron[1], octahedron[4])
		tesselate(octahedron[1], octahedron[2], octahedron[4])
		tesselate(octahedron[2], octahedron[3], octahedron[4])
		tesselate(octahedron[3], octahedron[0], octahedron[4])
		tesselate(octahedron[0], octahedron[1], octahedron[5])
		tesselate(octahedron[1], octahedron[2], octahedron[5])
		tesselate(octahedron[2], octahedron[3], octahedron[5])
		tesselate(octahedron[3], octahedron[0], octahedron[5])		
	end

	#Creates the points of the tesselated icosahedron
	#the points from this are used to draw all other aspects of the dome
	def create_icosahedron()
		# Get handles to our model and the Entities collection it contains.
		model = Sketchup.active_model
		entities = model.entities

		#Calculate golden section
		golden_section = (1 + Math.sqrt(5)) / 2
		
		#Get variables for creating the 3 perpendicular rectangles the icosahedron will be created from
		b = Math.sqrt((@@g_radius * @@g_radius) / (golden_section * golden_section + 1))
		a = b * golden_section

		#create an icosahedron and rotate it around the z-axis 30 degrees so that hemispheres lie flat
		# Create a series of "points", each a 3-item array containing x, y, and z.
		p = Geom::Point3d.new([0,0,0])	# rotate from the origin
		v = Geom::Vector3d.new([0,1,0]) # axis of rotation
		r = Math::PI / 180 * 31.7		# rotate so hemisphere is level
		t1 = Geom::Transformation.rotation(p, v, r)

		#translation transformation to account for the origin centered start and the fraction of dome desired
		t2 = Geom::Transformation.translation(@@g_center)

		#create the points of the icosahedron
		icosahedron = Array.new(12)
		icosahedron.push(Geom::Point3d.new([-a, -b, 0]).transform!(t1).transform!(t2))
		icosahedron.push(Geom::Point3d.new([a, -b, 0]).transform!(t1).transform!(t2))
		icosahedron.push(Geom::Point3d.new([a, b, 0]).transform!(t1).transform!(t2))
		icosahedron.push(Geom::Point3d.new([-a, b, 0]).transform!(t1).transform!(t2))
		icosahedron.push(Geom::Point3d.new([-b, 0, -a]).transform!(t1).transform!(t2))
		icosahedron.push(Geom::Point3d.new([b, 0, -a]).transform!(t1).transform!(t2))
		icosahedron.push(Geom::Point3d.new([b, 0, a]).transform!(t1).transform!(t2))
		icosahedron.push(Geom::Point3d.new([-b, 0, a]).transform!(t1).transform!(t2))
		icosahedron.push(Geom::Point3d.new([0, a, b]).transform!(t1).transform!(t2))
		icosahedron.push(Geom::Point3d.new([0, -a, b]).transform!(t1).transform!(t2))
		icosahedron.push(Geom::Point3d.new([0, -a, -b]).transform!(t1).transform!(t2))
		icosahedron.push(Geom::Point3d.new([0, a, -b]).transform!(t1).transform!(t2))
		
		# Call methods on the Entities collection to draw stuff.
		#new_face3 = entities.add_face icosahedron[8], icosahedron[9], icosahedron[10], icosahedron[11]
		
		# draw the triangles of the icosahedron
		icosa_faces = []
		if(@@draw_primitive_solid_faces == 1)
			icosa_faces.push(entities.add_face(icosahedron[1], icosahedron[6], icosahedron[9])) 
			icosa_faces.push(entities.add_face(icosahedron[1], icosahedron[2], icosahedron[6])) 
			icosa_faces.push(entities.add_face(icosahedron[2], icosahedron[6], icosahedron[8])) 
			icosa_faces.push(entities.add_face(icosahedron[6], icosahedron[7], icosahedron[8])) 
			icosa_faces.push(entities.add_face(icosahedron[6], icosahedron[7], icosahedron[9])) 
			icosa_faces.push(entities.add_face(icosahedron[1], icosahedron[9], icosahedron[10])) 
			icosa_faces.push(entities.add_face(icosahedron[1], icosahedron[5], icosahedron[10])) 
			icosa_faces.push(entities.add_face(icosahedron[1], icosahedron[2], icosahedron[5])) 
			icosa_faces.push(entities.add_face(icosahedron[2], icosahedron[5], icosahedron[11])) 
			icosa_faces.push(entities.add_face(icosahedron[2], icosahedron[8], icosahedron[11])) 
			icosa_faces.push(entities.add_face(icosahedron[4], icosahedron[5], icosahedron[10])) 
			icosa_faces.push(entities.add_face(icosahedron[4], icosahedron[5], icosahedron[11])) 
			icosa_faces.push(entities.add_face(icosahedron[0], icosahedron[4], icosahedron[10])) 
			icosa_faces.push(entities.add_face(icosahedron[0], icosahedron[9], icosahedron[10])) 
			icosa_faces.push(entities.add_face(icosahedron[0], icosahedron[7], icosahedron[9])) 
			icosa_faces.push(entities.add_face(icosahedron[3], icosahedron[7], icosahedron[8])) 
			icosa_faces.push(entities.add_face(icosahedron[0], icosahedron[3], icosahedron[7])) 
			icosa_faces.push(entities.add_face(icosahedron[0], icosahedron[3], icosahedron[4])) 
			icosa_faces.push(entities.add_face(icosahedron[3], icosahedron[4], icosahedron[11])) 
			icosa_faces.push(entities.add_face(icosahedron[3], icosahedron[8], icosahedron[11])) 
		end
		
		#decompose each face of the icosahedron
		tesselate(icosahedron[1], icosahedron[6], icosahedron[9])
		tesselate(icosahedron[1], icosahedron[2], icosahedron[6])
		tesselate(icosahedron[2], icosahedron[6], icosahedron[8])
		tesselate(icosahedron[6], icosahedron[7], icosahedron[8])
		tesselate(icosahedron[6], icosahedron[7], icosahedron[9])
		tesselate(icosahedron[1], icosahedron[9], icosahedron[10])
		tesselate(icosahedron[1], icosahedron[5], icosahedron[10])
		tesselate(icosahedron[1], icosahedron[2], icosahedron[5])
		tesselate(icosahedron[2], icosahedron[5], icosahedron[11])
		tesselate(icosahedron[2], icosahedron[8], icosahedron[11])
		tesselate(icosahedron[4], icosahedron[5], icosahedron[10])
		tesselate(icosahedron[4], icosahedron[5], icosahedron[11])
		tesselate(icosahedron[0], icosahedron[4], icosahedron[10])
		tesselate(icosahedron[0], icosahedron[9], icosahedron[10])
		tesselate(icosahedron[0], icosahedron[7], icosahedron[9])
		tesselate(icosahedron[3], icosahedron[7], icosahedron[8])
		tesselate(icosahedron[0], icosahedron[3], icosahedron[7])
		tesselate(icosahedron[0], icosahedron[3], icosahedron[4])
		tesselate(icosahedron[3], icosahedron[4], icosahedron[11])
		tesselate(icosahedron[3], icosahedron[8], icosahedron[11])
	end

	def add_metal_hubs()
		# Get handles to our model and the Entities collection it contains.
		model = Sketchup.active_model
		entities = model.entities

		#Calculate the inner radius
		inner_radius = @@metal_hub_outer_radius - @@metal_hub_outer_thickness

		#Create a hub for each point
		@@primitive_points.each_with_index { |c, index|
			#Draw only the positive hub for a dome
			if (c[2] > -@@g_tolerance)
				hub = entities.add_group
				outer_circle = hub.entities.add_circle(c, Geom::Vector3d.new(@@g_center.vector_to(c)), @@metal_hub_outer_thickness)				
				inner_circle = hub.entities.add_circle(c, Geom::Vector3d.new(@@g_center.vector_to(c)), inner_radius)
				outer_end_face = hub.entities.add_face outer_circle
				inner_end_face = hub.entities.add_face inner_circle
				hub.entities.erase_entities inner_end_face		#remove the inner face we just added (need to do this to create cylinder end
				outer_end_face.pushpull -@@metal_hub_depth_depth, false

				#Add hub to the global hub list
				@@strut_hubs.push(hub)
			end
		}	
	end

	def add_wood_struts()
		#Add the struts
		@@strut_points.each { |c|
			strut_faces = add_wood_strut(@@primitive_points[c[0]], @@primitive_points[c[1]], @@wood_strut_dist_from_hub)	

			#Add the hub plates
			#This currently relies on being here so that it gets the correct faces passed to it.
			if (@@draw_metal_hubs == 1)
#				add_hub_plates(strut_faces, @@strut_hubs[c[0]], @@strut_hubs[c[1]], strut_dist_from_hub)
			end
		}	
	end
	
	#Private functions
	private
	
	# Given 3 points that make up a triangle, decompose the triangle into 
	# [@@g_frequency] smaller triangles along each side
	def tesselate (p1, p2, p3)
		# Get handles to our model and the Entities collection it contains.
		model = Sketchup.active_model
		entities = model.entities

		#n = ((@@g_frequency * @@g_frequency + 3 * @@g_frequency + 2) / 2)
		
		#Create a group to hold everything
		group = entities.add_group
		
		c  = 0
		order = @@g_frequency + 1
		row = 0
		rf = row / @@g_frequency
		$p_s = [p1[0] + (p3[0] - p1[0]) * rf, p1[1] + (p3[1] - p1[1]) * rf, p1[2] + (p3[2] - p1[2]) * rf]
		$p_e = [p2[0] + (p3[0] - p2[0]) * rf, p2[1] + (p3[1] - p2[1]) * rf, p2[2] + (p3[2] - p2[2]) * rf]

		while c < order
		
			if (order == 1)
				@@primitive_points.push(Geom::Point3d.new ($p_s[0], $p_s[1], $p_s[2]))	#last point is already the right length
			else 
				co1 = c.to_f / (order - 1)
				x = $p_s[0] + ($p_e[0] - $p_s[0]) * co1
				y = $p_s[1] + ($p_e[1] - $p_s[1]) * co1
				z = $p_s[2] + ($p_e[2] - $p_s[2]) * co1
				p = Geom::Point3d.new ([x, y, z])
				
				length = @@g_center.distance(p)
				ratio = @@g_radius.to_f / length
				v = @@g_center.vector_to(p)
				v.length = @@g_radius
				@@primitive_points.push(Geom::Point3d.new (extend_line(@@g_center, p, @@g_radius)))
			end
			p_num = @@primitive_points.size() - 1
		
			#TODO Remove duplicate points in @@primitive_points and @@strut_points
			if (c > 0)
				if (@@primitive_points[p_num][2] >= -@@g_tolerance && @@primitive_points[p_num - 1][2] >= -@@g_tolerance)
					@@strut_points.push([p_num - 1, p_num])
				end
			end
		
			if (order < @@g_frequency + 1)
				if (@@primitive_points[p_num - order][2] >= -@@g_tolerance && @@primitive_points[p_num][2] >= -@@g_tolerance)
					@@strut_points.push([p_num - order, p_num])
				end			
				if (@@primitive_points[p_num - order - 1][2] >= -@@g_tolerance && @@primitive_points[p_num][2] >= -@@g_tolerance)
					@@strut_points.push([p_num - order - 1, p_num])
				end

				if (@@draw_tesselated_faces == 1)
					face = entities.add_face @@primitive_points[p_num - order], @@primitive_points[p_num - order - 1], @@primitive_points[p_num]	
					face.material = @@tesselated_face_material
					face.back_material = @@tesselated_face_material
				end

				if (c > 0)
					if (@@draw_tesselated_faces == 1)
						face = entities.add_face @@primitive_points[p_num - order - 1], @@primitive_points[p_num], @@primitive_points[p_num - 1]		
						face.material = @@tesselated_face_material
						face.back_material = @@tesselated_face_material
						#group.entities.add_face(face)
					end
				end
			end
			c += 1
			
			if (c == order)
				c = 0
				order -= 1
				row += 1
				rf = row.to_f / @@g_frequency
				$p_s = [p1[0] + (p3[0] - p1[0]) * rf, p1[1] + (p3[1] - p1[1]) * rf, p1[2] + (p3[2] - p1[2]) * rf]
				$p_e = [p2[0] + (p3[0] - p2[0]) * rf, p2[1] + (p3[1] - p2[1]) * rf, p2[2] + (p3[2] - p2[2]) * rf]
			end
			p_num += 1
		end
	end

	# Creates a strut orientated to face out from the origin
# The ends are [distance] back from the points [p1, p2] to accommodate hubs
# The ends are also angled to allow closer mounting to the hubs
def add_wood_strut(p1, p2, distance)
	# Get handles to our model and the Entities collection it contains.
	model = Sketchup.active_model
	entities = model.entities

	#create a group for our strut
	strut = entities.add_group

	#Create a vector of inset length (this will be how far back from the hub the strut starts
	v1 = Geom::Vector3d.new(p2[0] - p1[0], p2[1] - p1[1], p2[2] - p1[2])
	v1.length = distance
	
	#calculate the inset point ends 
	pt1 = Geom::Point3d.new(p1[0] + v1[0], p1[1] + v1[1], p1[2] + v1[2])
	pt2 = Geom::Point3d.new(p2[0] - v1[0], p2[1] - v1[1], p2[2] - v1[2])

	#create some vectors so that we can create the 4 points that will make the plane of strut at correct orientation
	v2 = Geom::Vector3d.new(@@g_center.vector_to(p1))
	v3 = Geom::Vector3d.new(@@g_center.vector_to(p2))
	v4 = Geom::Vector3d.new(p2.vector_to(p1))
	
	#calculate the normal
	n1 = v2.cross v4
	n2 = v3.cross v4
	n1.length = @@wood_strut_thickness / 2
	n2.length = @@wood_strut_thickness / 2

	#create the outer facing points
	pt3 = pt1 + n1
	pt4 = pt1 - n1
	pt5 = pt2 + n2
	pt6 = pt2 - n2
	
	#create the inner facing points
	v2.length = @@wood_strut_depth
	v3.length = @@wood_strut_depth
	
	pt7 = pt3 - v2
	pt8 = pt4 - v2
	pt9 = pt5 - v3
	pt10 = pt6 - v3

	#create the faces of the strut
	face = Array.new(6)
	face[0] = strut.entities.add_face pt3, pt4, pt6, pt5
	face[1] = strut.entities.add_face pt8, pt7, pt9, pt10
	face[2] = strut.entities.add_face pt3, pt4, pt8, pt7
	face[3] = strut.entities.add_face pt4, pt6, pt10, pt8	#side that hub will connect to hub
	face[4] = strut.entities.add_face pt5, pt6, pt10, pt9
	face[5] = strut.entities.add_face pt3, pt5, pt9, pt7	#side that hub will connect to hub
	
	#set the color of the strut
	color = @@wood_strut_material
	face[0].material = color; face[0].back_material = color;
	face[1].material = color; face[1].back_material = color;
	face[2].material = color; face[2].back_material = color;
	face[3].material = color; face[3].back_material = color;
	face[4].material = color; face[4].back_material = color;
	face[5].material = color; face[5].back_material = color;
	
	#return the side faces that will be used to fix the hub side plates to
	return face[3], face[5]
end	

	
end

# Add a menu item to launch our plugin.
UI.menu("PlugIns").add_item("Draw Geodesic") {
  # Call our new method.
  #draw_menu
  
  geo = Geodesic.new
  geo.draw()
}

def draw_menu

	dialog = UI::WebDialog.new("Geodesic Creator", true, "", 410, 875, 1030, 0, true)
	# Find and show our html file
	html_path = Sketchup.find_support_file "geodesic.html" ,"Plugins"
	dialog.set_file(html_path)
	#dialog.set_url 'http://www.tdteam.com/work/engineeringtheworld/name.html'
	dialog.show
	 
	prompts = ["Dome Frequency", "Dome Radius"]

	dialog.add_action_callback("typeName") {|dialog, action|
		input = UI.inputbox prompts, [], [], "Enter Geodesic Parameters"
		input[0] = input[0].to_s.chomp
		input[1] = input[1].to_s.chomp
		if input[0] == '' || input[1] == ''
		  UI.messagebox 'You have to enter values'
		else
		  #name = input[0] + ' ' + input[1]
		  #dialog.execute_script("dataFromSketchup('#{name}')")
		  #dialog.hide
		  draw_icosahedron(input[0].to_i, input[1].to_i)
		end
	}
	#show console call up
	dialog.add_action_callback("showConsole") {|dialog, action| Sketchup.send_action("showRubyPanel:")}

end





def add_hub_plates(strut_faces, hub1, hub2, extend_dist)
	# Get handles to our model and the Entities collection it contains.
	model = Sketchup.active_model
	entities = model.entities

	plate_thickness = 0.25

	hub_plate = entities.add_group
	face1_coords = calc_hub_plate_face(strut_faces[0], 0, hub1, extend_dist)
	face1 = hub_plate.entities.add_face (face1_coords[0], face1_coords[1], face1_coords[2], face1_coords[3])

	#Create a normal to the inner face
	normal  = face1.normal
	normal.length = plate_thickness
	vertices = strut_faces[0].vertices
	tmp_grp = entities.add_group
	tmp_face2 = tmp_grp.entities.add_face(vertices[0].position - normal, vertices[1].position - normal, vertices[2].position - normal, vertices[3].position - normal)
	face2_coords = calc_hub_plate_face(tmp_face2, 0, hub1, extend_dist)
	hub_plate.entities.add_face (face2_coords[0], face2_coords[1], face2_coords[2], face2_coords[3])
	
	#empty the temporary group
	tmp_grp.entities.clear!

#	hub_plate.entities.add_face (f3v[0].position, f3v[1].position, f3v[2].position, f3v[3].position)
#	hub_plate.entities.add_face (f4v[0].position, f4v[1].position, f4v[2].position, f4v[3].position)
#	hub_plate.entities.add_face (f5v[0].position, f5v[1].position, f5v[2].position, f5v[3].position)

	
#	face6 = calc_hub_plate_face(strut_faces[0], 1, hub2, extend_dist)
#	face11 = calc_hub_plate_face(strut_faces[1], 1, hub1, extend_dist)
#	face16 = calc_hub_plate_face(strut_faces[1], 0, hub2, extend_dist)
	
	
end

def calc_hub_plate_face(strut_face, strut_end, hub, extend_dist)
	# Get handles to our model and the Entities collection it contains.
	model = Sketchup.active_model
	entities = model.entities
	
	hub_flange_length = 4

	#get the vertices of the face
	strut_vertices = strut_face.vertices

	#Create a vector of inset length so that we can extend the face to intersect with the hub
	v1 = Geom::Vector3d.new(strut_vertices[1].position[0] - strut_vertices[0].position[0], strut_vertices[1].position[1] - strut_vertices[0].position[1], strut_vertices[1].position[2] - strut_vertices[0].position[2])
	v1.length = extend_dist	
		
	#Create points extended from the strut face to within hub	
	tmp_grp1 = entities.add_group
	if (strut_end == 0)
		tmp_p1 = strut_vertices[1].position + v1
		tmp_p2 = strut_vertices[2].position + v1
		tmp_face1  = tmp_grp1.entities.add_face strut_vertices[1].position, tmp_p1, tmp_p2, strut_vertices[2].position
	else
		tmp_p1 = strut_vertices[3].position - v1
		tmp_p2 = strut_vertices[0].position - v1	
		tmp_face1 = tmp_grp1.entities.add_face strut_vertices[0].position, tmp_p2, tmp_p1, strut_vertices[3].position
	end
	
	#Intersect the two faces 
	tr = Geom::Transformation.new()
	tmp_grp1_entities = tmp_grp1.entities
	
	new_edge = tmp_grp1_entities.intersect_with(false, tr, tmp_grp1_entities, tr, false, [tmp_face1, hub])

	hub_plate_coords = []
	if (strut_end == 0)
		v1 = new_edge[0].end
		v2 = new_edge[0].other_vertex v1
		v3 = new_edge[1].end
		v4 = new_edge[1].other_vertex v1

		#two edges will be returned we need to find the one that is on the outside of the cylinder
		#We also need to check the order of the points so we create a rectangle face not a box tie
		d1 = strut_vertices[1].position.distance_to_line([v1.position, v2.position])
		d2 = strut_vertices[1].position.distance_to_line([v3.position, v4.position])
		if (d1 < d2) 
			d3 = strut_vertices[1].position.distance v1.position
			d4 = strut_vertices[1].position.distance v2.position
			p1 = extend_line(strut_vertices[1].position, strut_vertices[0].position, hub_flange_length)
			p2 = extend_line(strut_vertices[2].position, strut_vertices[3].position, hub_flange_length)
			if (d3 < d4)
				hub_plate_coords = [v2.position, v1.position, p1, p2]	
			else
				hub_plate_coords = [v1.position, v2.position, p1, p2]
			end
		else
			d3 = strut_vertices[1].position.distance v1.position
			d4 = strut_vertices[1].position.distance v2.position
			p1 = extend_line(strut_vertices[1].position, strut_vertices[0].position, hub_flange_length)
			p2 = extend_line(strut_vertices[2].position, strut_vertices[3].position, hub_flange_length)
			if (d3 < d4)
				hub_plate_coords = [v3.position, v4.position, p1, p2]	
			else
				hub_plate_coords = [v4.position, v3.position, p1, p2]	
			end
		end		
	else
		v1 = new_edge[0].end
		v2 = new_edge[0].other_vertex v1
		v3 = new_edge[1].end
		v4 = new_edge[1].other_vertex v1
		#hub_plate.entities.add_face p1, p2, vertices[0], vertices[3]

		#two edges will be returned we need to find the one that is on the outside of the cylinder
		#We also need to check the order of the points so we create a rectangle face not a box tie
		d1 = strut_vertices[0].position.distance_to_line([v2.position, v1.position])
		d2 = strut_vertices[0].position.distance_to_line([v4.position, v3.position])
		p1 = extend_line(strut_vertices[0].position, strut_vertices[1].position, hub_flange_length)
		p2 = extend_line(strut_vertices[3].position, strut_vertices[2].position, hub_flange_length)
		if (d1 < d2) 
			d3 = strut_vertices[0].position.distance v1.position
			d4 = strut_vertices[0].position.distance v2.position
			if (d3 < d4)
				hub_plate_coords = [v2.position, v1.position, p1, p2]	
			else
				hub_plate_coords = [v1.position, v2.position, p1, p2]
			end
		else
			d3 = strut_vertices[0].position.distance v1.position
			d4 = strut_vertices[0].position.distance v2.position
			if (d3 < d4)
				hub_plate_coords = [v3.position, v4.position, p1, p2]		
			else
				hub_plate_coords = [v4.position, v3.position, p1, p2]
			end
		end
		
	end
	tmp_grp1.entities.clear!

	#return the hub face plate
	return hub_plate_coords
end

#Returns a point along the [p1/p2] line [dist] from [p1] in the direction of [p2]
def extend_line(p1, p2, dist)
	#v = Geom::Vector3d.new (p2[0] - p1[0], p2[1] - p1[1], p2[2] - p1[2])
	v = p1.vector_to(p2)

	v.length = dist
	return p1 + v
end



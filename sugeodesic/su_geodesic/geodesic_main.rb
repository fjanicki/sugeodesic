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


# Add a menu item to launch our plug-in.
UI.menu("PlugIns").add_item("Geodesic Creator") {
  
  #Instantiate the Geodesic
  geo = Geodesic::Geodesic.new
  
  #configuration will call draw() once complete
  geo.configure()

}

$interrupt = 0

module Geodesic

	class Geodesic
		
		def initialize()
			#Main Configuration items
			@g_frequency = 3
			@g_radius = 150
			@g_platonic_solid = 20
			
			@g_fraction_num = 1
			@g_fraction_den = 2
			@g_fraction = @g_fraction_num.to_f / @g_fraction_den.to_f
			@g_center = Geom::Point3d.new([0, 0, -@g_radius + 2 * @g_radius * @g_fraction])
			
			@draw_primitive_solid_faces = 0
			@draw_primative_vertex_points = 1
			@primitive_face_material = [255, 255, 255]

			@draw_tessellated_faces = 0
			@face_material = Sketchup.active_model.materials.add "face_material"
			
			#Generic Hub configuration
			@draw_hubs = 1
			@hub_material = Sketchup.active_model.materials.add "hub_material"
			
			#Sphere hub configuration
			@draw_sphere_hubs = 1
			@sphere_hub_radius = 5
			
			#Metal hub configuration
			@draw_metal_hubs = 1
			@metal_hub_outer_radius = 1.50
			@metal_hub_outer_thickness = 0.25
			@metal_hub_depth_depth = 4

			#Generic Strut configuration
			@draw_struts = 1
			@strut_material = Sketchup.active_model.materials.add "strut_material"
			@flatten_strut_base = 1
			
			#Rectangular strut configuration
			@draw_wood_struts = 1
			@wood_strut_dist_from_hub = 3
			@wood_strut_thickness = 1.5
			@wood_strut_depth = 3.5

			#Cylinder strut configuration
			@draw_cylinder_struts = 1
			@cylinder_strut_extension = -4
			@cylinder_strut_radius = 3
			@cylinder_strut_radius = 2
				
			#Wood frame configuration
			@draw_wood_frame = 1
			@frame_separation = 12
			@draw_base_frame = 0
			@base_frame_height = 36
			
			#Dome reference data is stored in these arrays
			#@geodesic = nil
			@geodesic = Sketchup.active_model.entities.add_group		#Main object everything contributes to
			@primitive_points = []
			@strut_points = []
			@triangle_points = []
			@base_points = []		#Points that are around the base of the dome
			
			#Dome shape data is stored in these arrays
			@strut_hubs = []
			@all_edges = []
			@frame_struts = []

			#variables for statistics timer
			@start_time = 0
			@end_time = 0
			
			#tolerance factor to circumvent small number errors
			@g_tolerance = 0.5
			

			#Check the SKM Tools are enabled (Webdialog functionality is enabled if present)
			@SKMTools_installed = 0
			if (Sketchup.find_support_file("SKMtools_loader.rb","Plugins") != nil)
				@SKMTools_installed = 1
			end
		end
		
		
		#HTML pop-up menu to configure and create the Geodesic Dome
		def configure
			dialog = UI::WebDialog.new("Geodesic Dome Creator", true, "GU_GEODESIC", 800, 800, 200, 200, true)
			# Find and show our html file
			html_path = Sketchup.find_support_file "su_geodesic/html/geodesic.html" ,"Plugins"
			dialog.set_file(html_path)
			dialog.show
			
			#Add handlers for all of the variable changes from the HTML side 

			dialog.add_action_callback("DOMContentLoaded") { |dlg, msg|
				#Once page is loaded send extra configuration
				script = 'dataFromSketchup("SKMTools_installed", ' + @SKMTools_installed.to_s() + ');'
				dialog.execute_script(script) 
			}
			dialog.add_action_callback("platonic_solid") do |dlg, msg|
				@g_platonic_solid = Integer(msg) 
				dialog.execute_script('send_setting();') 
			end
			dialog.add_action_callback("frequency") do |dlg, msg|
				@g_frequency = Integer(msg) 
				dialog.execute_script('send_setting();') 
			end
			dialog.add_action_callback("fraction_num") do |dlg, msg|
				@g_fraction_num = Integer(msg) 
				dialog.execute_script('send_setting();') 
			end
			dialog.add_action_callback("fraction_den") do |dlg, msg|
				@g_fraction_den = Integer(msg) 
				dialog.execute_script('send_setting();') 
			end
			dialog.add_action_callback("radius") do |dlg, msg|
				@g_radius = Float(msg) 
				dialog.execute_script('send_setting();') 
			end		
			dialog.add_action_callback("thickness") do |dlg, msg|
				@wood_strut_thickness = Float(msg) 
				dialog.execute_script('send_setting();') 
			end		
			dialog.add_action_callback("depth") do |dlg, msg|
				@wood_strut_depth = Float(msg) 
				dialog.execute_script('send_setting();') 
			end		
			dialog.add_action_callback("draw_faces") do |dlg, msg|
				@draw_tessellated_faces = Integer(msg) 
				dialog.execute_script('send_setting();') 
			end
			dialog.add_action_callback("face_material") { |dlg, msg|
				filepath = msg
				filepath = msg.gsub('\\','/')
				if (filepath == "")
					@face_material = [255, 255, 255]
				else
					if File.exists?(filepath)
						@face_material = SKM.import(filepath)
					end
				end
				dialog.execute_script('send_setting();') 
			}
			dialog.add_action_callback("face_opacity") do |dlg, msg|
				if (@face_material.class != Array)
					@face_material.alpha = Float(msg) / 100
				end
				dialog.execute_script('send_setting();') 
			end
			dialog.add_action_callback("strut_material") { |dlg, msg|
				filepath = msg
				filepath = msg.gsub('\\','/')
				if (filepath == "")
					@strut_material = [255, 215, 0]	
				else
					if File.exists?(filepath)
						puts 'Do strut'
						@strut_material = SKM.import(filepath)
						puts 'bugger...'
					end
				end
				dialog.execute_script('send_setting();') 
			}
			dialog.add_action_callback("hub_material") { |dlg, msg|
				filepath = msg
				filepath = msg.gsub('\\','/')
				if (filepath == "")
					@hub_material = [255, 255, 255]				
				else
					if File.exists?(filepath)	#Only assign alpha if a material was assigned (not a default color)
						@hub_material = SKM.import(filepath)
					end
				end
				dialog.execute_script('send_setting();') 
			}
			
			dialog.add_action_callback("draw_struts") do |dlg, msg|
				@draw_struts = Integer(msg) 
				dialog.execute_script('send_setting();') 
			end
			dialog.add_action_callback("draw_hubs") do |dlg, msg|
				@draw_hubs = Integer(msg) 
				dialog.execute_script('send_setting();') 
			end
			dialog.add_action_callback("draw_metal_hubs") do |dlg, msg|
				@draw_metal_hubs = Integer(msg) 
				dialog.execute_script('send_setting();') 
			end
			dialog.add_action_callback("draw_wood_frame") do |dlg, msg|
				@draw_wood_frame = Integer(msg) 
				dialog.execute_script('send_setting();') 
			end
			dialog.add_action_callback("draw_cpoints") do |dlg, msg|
				@draw_primative_vertex_points = Integer(msg) 
				dialog.execute_script('send_setting();') 
			end
			dialog.add_action_callback("sphere_radius") do |dlg, msg|
				@sphere_hub_radius = Float(msg) 
				dialog.execute_script('send_setting();') 
			end
			dialog.add_action_callback("strut_type") do |dlg, msg|
				if (msg == "rectangular")
					@draw_wood_struts = 1					
					@draw_cylinder_struts = 0
				end
				if (msg == "cylindrical")
					@draw_wood_struts = 0					
					@draw_cylinder_struts = 1
				end
				dialog.execute_script('send_setting();') 
			end
			dialog.add_action_callback("hub_type") do |dlg, msg|
				if (msg == "Spherical")
					@draw_sphere_hubs = 1
					@draw_metal_hubs = 0
				end
				if (msg == "Cylindrical")
					@draw_sphere_hubs = 0
					@draw_metal_hubs = 1
				end
				if (msg == "None")
					@draw_sphere_hubs = 0
					@draw_metal_hubs = 0
				end
				dialog.execute_script('send_setting();') 
			end
			dialog.add_action_callback("flatten_strut_base") do |dlg, msg|
				@flatten_strut_base = Integer(msg) 
				dialog.execute_script('send_setting();') 
			end
			dialog.add_action_callback("draw_base_frame") do |dlg, msg|
				@draw_base_frame = Integer(msg)
				dialog.execute_script('send_setting();') 
			end
			dialog.add_action_callback("base_frame_height") do |dlg, msg|
				@base_frame_height = Float(msg)
				dialog.execute_script('send_setting();') 
			end
			dialog.add_action_callback("strut_radius") do |dlg, msg|
				@cylinder_strut_radius = Float(msg)
				dialog.execute_script('send_setting();') 
			end	
			dialog.add_action_callback("strut_extension") do |dlg, msg|
				@cylinder_strut_extension = Float(msg)
				dialog.execute_script('send_setting();') 
			end	
			dialog.add_action_callback("strut_offset") do |dlg, msg|
				@cylinder_strut_offset = Float(msg)
				dialog.execute_script('send_setting();') 
			end				
			dialog.add_action_callback( "create_geodesic" ) do |dlg, msg|
				#Let the user know we've started
				#script = 'messageFromSketchup("Processing has started.. Give me a minute or two\n (time varies depending on settings).");'
				#t1 = Thread.new(dialog.execute_script(script))
				
				processing = UI::WebDialog.new("Working on your request...", true, "GU_GEODESIC_PROCESSING", 500, 200, 200, 400, true)
				html_path = Sketchup.find_support_file "su_geodesic/html/processing.html" ,"Plugins"
				processing.set_file(html_path)
				processing.show			
				script = "from_ruby('Processing stuff');"
				processing.execute_script(script)
				
				#@do_draw = 1
				#puts "Create Geodesic:" + msg
				#puts "Platonic Solid: #{@g_platonic_solid}"
				#puts "Frequency: #{@g_frequency.to_s}"
				
				#The geodesic is configured, now draw it
				#t2 = Thread.new{draw()}
				dialog.close	
				draw()
				#Wait until complete before printing statistics
				#t2.join
				
				#Print statistics to the Ruby Console
				#t3 = Thread.new{statistics()}
				statistics()
				
				#Close the dialogs
				processing.close
				
			end
		end
			
	#Trying to work out how to modify one of the class instance variables...
	#	def add_handler(dialog, handle, type, mapping)
	#		if (type == "Int")
	#			dialog.add_action_callback(handle) do |dlg, msg|
	#				mapping = Integer(msg) 
	#			end
	#		end
	#		if (type == "Float")
	#			dialog.add_action_callback(handle) do |dlg, msg|
	#				mapping = Float(msg) 
	#			end
	#		end
	#	end
		
		def draw()
			@start_time = Time.now		#start timer for statistics measurements

			#Update fraction in case it was changed in the configuration
			@g_fraction = @g_fraction_num.to_f / @g_fraction_den.to_f
			@g_center = Geom::Point3d.new([0, 0, -@g_radius + 2 * @g_radius * @g_fraction])

			#Create the base Geodesic Dome points
			if (@g_platonic_solid == 4)
				create_tetrahedron()							
			end
			if (@g_platonic_solid == 8)
				create_octahedron()				
			end
			if (@g_platonic_solid == 20)
				create_icosahedron()
			end
			
			if (@flatten_strut_base == 1)
				flatten_base()
			end
			
			if (@draw_base_frame == 1)
				create_base_frame()
			end 
			
			#Add_hubs
			add_hubs()
			
			#Add struts			
			add_struts()

			#Add vertex construction points
			if (@draw_primative_vertex_points == 1)
				add_vertex_points()
			end
			
			if(@draw_wood_frame == 1)
				add_wood_frame()
			end
			
			@end_time = Time.now		#start timer for statistics measurements
			
		end
		
		def statistics()
			num_hubs = @strut_hubs.size
			num_struts = @all_edges.size
			num_frame_struts = @frame_struts.size
			
			print("Statistics\n^^^^^^^^^^\n\n")
			
			print("Frequency: #{@g_frequency}\n")
			print("Platonic Solid: #{@g_platonic_solid}\n")
			frac = @g_fraction * 100
			print("Sphere Fraction: #{frac}\n")
			print("Radius: #{@g_radius}\n\n")

			print("Number of Hubs: \t#{num_hubs}\n")
			print("Number of Struts:\t#{num_struts}\n")
			print("Number of Frame Struts:\t#{num_frame_struts}\n")
			
			elapsed = @end_time - @start_time
			if (elapsed > 3600)
				hours = 0
				while (elapsed > 3600)
					elapsed -= 3600
					hours += 1
				end
				if (hours > 0)
					hour_str = "#{hours} hrs "
				else
					hour_str = ""
				end
			end
			if (elapsed > 60)
				minutes = 0
				while (elapsed > 60)
					elapsed -= 60
					minutes += 1
				end
				if (minutes > 0)
					min_str = "#{minutes} mins "
				else
					min_str = ""
				end
			end
			sec_str = "#{elapsed} secs"
			print("\nProcessing Time: #{hour_str}#{min_str}#{sec_str}\n")
		end
		
		#Creates the points of the tessellated tetrahedron
		#the points from this are used to draw all other aspects of the dome
		def create_tetrahedron()

			#Get the length of a side
			r2 = @g_radius / 2
			
			#translation transformation to account for the origin centered start and the fraction of dome desired
			t = Geom::Transformation.translation(@g_center)
			
			#Create the points of the tetrahedron
			tetrahedron = []
			tetrahedron.push(Geom::Point3d.new([0, r2, r2]).transform!(t))
			tetrahedron.push(Geom::Point3d.new([0, -r2, r2]).transform!(t))
			tetrahedron.push(Geom::Point3d.new([r2, 0, -r2]).transform!(t))
			tetrahedron.push(Geom::Point3d.new([-r2, 0, -r2]).transform!(t))

			tetra_faces = []
			c = [0, 1, 3, 1, 2, 3, 2, 0, 3, 0, 1, 2] 
			
			for i in 0..3	
				d = i * 3
				j = c[d]
				k = c[d + 1]
				l = c[d + 2]
				# draw the triangles of the tetrahedron
				if(@draw_primitive_solid_faces == 1)
					if (all_pos_z([tetrahedron[j], tetrahedron[k], tetrahedron[l]]) == 0)
						tetra_faces.push(@geodesic.entities.add_face(tetrahedron[j], tetrahedron[k], tetrahedron[l]))
					end
				end
				#decompose each face of the tetrahedron
				tessellate(tetrahedron[j], tetrahedron[k], tetrahedron[l])
			end	
			
		end
	
		#Creates the points of the tessellated octahedron
		#the points from this are used to draw all other aspects of the dome
		def create_octahedron()
			#Get the length of a side
			a = @g_radius * Math.sqrt(2) / 2
			
			#translation transformation to account for the origin centered start and the fraction of dome desired
			t = Geom::Transformation.translation(@g_center)
			
			#Create the points of the octahedron
			octahedron = []
			octahedron.push(Geom::Point3d.new([-a, -a, 0]).transform!(t))
			octahedron.push(Geom::Point3d.new([a, -a, 0]).transform!(t))
			octahedron.push(Geom::Point3d.new([a, a, 0]).transform!(t))
			octahedron.push(Geom::Point3d.new([-a, a, 0]).transform!(t))
			octahedron.push(Geom::Point3d.new([0, 0, @g_radius]).transform!(t))
			octahedron.push(Geom::Point3d.new([0, 0, -@g_radius]).transform!(t))
					
			octa_faces = []			
			c = [0, 1, 4, 1, 2, 4, 2, 3, 4, 3, 0, 4, 0, 1, 5, 1, 2, 5, 2, 3, 5, 3, 0, 5] 			
			for i in 0..7	
				d = i * 3
				j = c[d]
				k = c[d + 1]
				l = c[d + 2]
				# draw the triangles of the octahedron
				if(@draw_primitive_solid_faces == 1)
					if (all_pos_z([octahedron[j], octahedron[k], octahedron[l]]) == 0)
						icosa_faces.push(@geodesic.entities.add_face(octahedron[j], octahedron[k], octahedron[l])) 
					end
				end
				#decompose each face of the octahedron
				tessellate(octahedron[j], octahedron[k], octahedron[l])
			end							
		end

		#Creates the points of the tessellated icosahedron
		#the points from this are used to draw all other aspects of the dome
		def create_icosahedron()
			# Get handles to our model and the Entities collection it contains.
			model = Sketchup.active_model
			entities = model.entities

			#Calculate golden section
			golden_section = (1 + Math.sqrt(5)) / 2
			
			#Get variables for creating the 3 perpendicular rectangles the icosahedron will be created from
			b = Math.sqrt((@g_radius * @g_radius) / (golden_section * golden_section + 1))
			a = b * golden_section

			#create an icosahedron and rotate it around the z-axis 30 degrees so that hemispheres lie flat
			# Create a series of "points", each a 3-item array containing x, y, and z.
			p = Geom::Point3d.new([0,0,0])	# rotate from the origin
			v = Geom::Vector3d.new([0,1,0]) # axis of rotation
			r = Math::PI / 180 * 31.7		# rotate so hemisphere is level
			t1 = Geom::Transformation.rotation(p, v, r)

			#translation transformation to account for the origin centered start and the fraction of dome desired
			t2 = Geom::Transformation.translation(@g_center)

			#create the points of the icosahedron
			icosahedron = []
			c = [-a, -b, 0, a, -b, 0, a, b, 0, -a, b, 0, -b, 0, -a, b, 0, -a, b, 0, a, -b, 0, a, 0, a, b, 0, -a, b, 0, -a, -b, 0, a, -b]
			
			for i in 0..11
				d = i * 3
				j = c[d]
				k = c[d + 1]
				l = c[d + 2]
				icosahedron.push(Geom::Point3d.new([j, k, l]).transform!(t1).transform!(t2))			
			end
					
			icosa_faces = []			
			c = [1, 6, 9, 1, 2, 6, 2, 6, 8, 6, 7, 8, 6, 7, 9, 1, 9, 10, 1, 5,  10, 1, 2, 5, 2, 5, 11, 2, 8, 11, 4, 5, 10, 4, 5, 11, 0, 4, 10, 0, 9, 10, 0, 7, 9, 3, 7, 8, 0, 3, 7, 0, 3, 4, 3,4, 11, 3, 8, 11] 			
			for i in 0..19
				d = i * 3
				j = c[d]
				k = c[d + 1]
				l = c[d + 2]
				# draw the triangles of the icosahedron
				if(@draw_primitive_solid_faces == 1)
					if (all_pos_z([icosahedron[j], icosahedron[k], icosahedron[l]]) == 0)
						icosa_faces.push(@geodesic.entities.add_face(icosahedron[j], icosahedron[k], icosahedron[l])) 
					end
				end
				#decompose each face of the icosahedron
				tessellate(icosahedron[j], icosahedron[k], icosahedron[l])
			end					
		end
		
		def all_pos_z(pts)
			if (pts[0][2] > -@g_tolerance && pts[1][2] > -@g_tolerance && pts[1][2] > -@g_tolerance)
				return 0
			else
				return 1
			end
		end
		
		def flatten_base()
			indexed_points = []		# list of points with indexes so we can track the points after sorting
			sorted_points = []		# sorted list of points, first element of each sub-array is point reference
		
			#Create a list of points along with their presorted indices
			@primitive_points.each_with_index { |c, index|
				if (c[2] > -@g_tolerance) then 
					indexed_points.push([index, c[0], c[1], c[2]]) 
				end
			}
			
			#Sort the list by z axis
			sorted_points = indexed_points.sort_by { |a| a[3] }

			#Get the length of one of the struts to determine height grouping
			sp = @strut_points[0]
			p1 =  @primitive_points[sp[0]]
			p2 =  @primitive_points[sp[1]]
			len =  (p1.distance p2) / 4		# half the length is enough to separate bottom layer from remainder
			
			smallest = sorted_points[0][3]		# track the smallest z to pull the other points to
			last = smallest					# track the last point's z
			
			#Get the points in the lowest layer
			sorted_points.each { |c|
				if (c[3] - last < len) then
					@base_points.push c[0]		# push the index of the point to be flatten				
				else
					break
				end
				
				last = c[3]
				if (c[3] < smallest) then
					smallest = c[3]
				end
			}
			
			#flatten the base			
			@base_points.each { |c|
				p = @primitive_points[c]
				v = Geom::Vector3d.new (p[0], p[1], smallest)
				v.length = @g_radius
				@primitive_points[c][0] = v[0]
				@primitive_points[c][1] = v[1]
				@primitive_points[c][2] = v[2]
				#Sketchup.active_model.entities.add_line p, [p[0], p[1], p[2] - 50]			
			}			
						
		end
		
		def create_base_frame()
			base_struts = []
		
			#Find all of the struts around the base
			@strut_points.each_with_index { |s, index|
				f1 = 0
				f2 = 0
				@base_points.each { |b|	
					p1 = Geom::Point3d.new @primitive_points[b]
					v = Geom::Vector3d.new [0, 0, -50]
#					Sketchup.active_model.entities.add_line p1, p1 - v
					if (s[0] == b) then
						f1 = 1
					end					
					if (s[1] == b) then
						f2 = 1
					end					
				}
				if (f1 == 1 && f2 == 1) then
					base_struts.push index
				end
			}
			
			#Create a vertical strut at the origin to use as a component
			vstrut = @geodesic.entities.add_group		#create group to hold our strut
			ht = @wood_strut_thickness / 2
			hd = @wood_strut_depth / 2
			top_face = vstrut.entities.add_face [-ht, hd, 0], [ht, hd, 0], [ht, -hd, 0], [-ht, -hd, 0]
			hgt = (@base_frame_height - 2 * @wood_strut_thickness)
			top_face.pushpull hgt, true
			vstrut_comp = vstrut.to_component			
			#get the definition of the vstrut so we can make more
			vstrut_def = vstrut_comp.definition			

			
			base_struts.each_with_index { |b, index|
				p1 = Geom::Point3d.new @primitive_points[@strut_points[b][0]]
				p2 = Geom::Point3d.new @primitive_points[@strut_points[b][1]]

				#Create a vector of inset length (this will be how far back from the hub the strut starts
				v = []
				v[0] = Geom::Vector3d.new(p2[0] - p1[0], p2[1] - p1[1], p2[2] - p1[2])
				v[0].length = @wood_strut_dist_from_hub
				
				#calculate the inset point ends 
				pt1 = p1 + v[0]
				pt2 = p2 - v[0]

				#create some vectors so that we can create the 4 points that will make the plane of strut at correct orientation
				v[1] = Geom::Vector3d.new(@g_center.vector_to(p1))
				v[2] = Geom::Vector3d.new(@g_center.vector_to(p2))
				v[3] = Geom::Vector3d.new(p2.vector_to(p1))
				v[4] = Geom::Vector3d.new([0, 0, @wood_strut_thickness])

				#calculate the normal
				n1 = v[1].cross v[3]
				n2 = v[2].cross v[3]
				
				n1.length = @wood_strut_thickness / 2 
				n2.length = @wood_strut_thickness / 2 
				
				#create the outer facing points
				pt3 = pt1 + n1	
				pt4 = pt1 - n1	
				pt5 = pt2 + n2	
				pt6 = pt2 - n2	

				#find out which are the upper and lower points
				if (pt3[2] > pt4[2]) then
					#pt4,6 are on the bottom
					p1b = pt4
					p2b = pt6
					p1t = pt3
					p2t = pt5
				else
					#pt3,5 are on the bottom
					p1b = pt3
					p2b = pt5
					p1t = pt4
					p2t = pt6
				end
				p3f = p1b - v[4]
				p4f = p2b - v[4]
		
				#create the inner facing points
				v[1].length = @wood_strut_depth
				v[2].length = @wood_strut_depth
				
				pt7 = p1b - v[1]
				pt8 = p2b - v[2]
				pt9 = Geom::Point3d.new pt7 - v[4]
				pt10 = Geom::Point3d.new pt8 - v[4]
				pt9[2] = p3f[2]
				pt10[2] = p4f[2]
				pt9 = extend_line(p3f, pt9, @wood_strut_depth)
				pt10 = extend_line(p4f, pt10, @wood_strut_depth)
			
				p7_2 = Geom.intersect_line_line [pt9, pt9 + v[4]], [pt7, pt7 - v[1]]
				p8_2 = Geom.intersect_line_line [pt10, pt10 + v[4]], [pt8, pt8 - v[2]]
				
				
				#Create the angled face to level the bottom
				create_solid([p1b ,p2b ,p3f ,p4f, p7_2, p8_2, pt9, pt10])
				
				#create a temporary face to detect the intersection of the line extension with
				t1 = p1 + v[4]
				t2 = p2 + v[4]

				v[0].length = @wood_strut_dist_from_hub * 2
				#Front Point Determination	
				status, pt11 = line_plane_intersection([p1t, p1t - v[0]], [@g_center, p1, t1])
				if (status == 1) then
					v[5] = Geom::Vector3d.new(pt11 - p1)
					p13 = p1 - v[5] - v[4]
				end 
				status, pt12 = line_plane_intersection([p2t, p2t + v[0]], [@g_center, p2, t2])
				if (status == 1) then
					v[6] = Geom::Vector3d.new(pt12 - p2)
					p14 = p2 - v[6] - v[4]
				end 

				#Back Point Determination
				p15 = p1t - v[1]
				p16 = p2t - v[2]				
				status, pt11 = line_plane_intersection([p15, p15 - v[0]], [@g_center, p1, t1])
				if (status == 1) then
					p17 = pt11 - v[5] - v[5]
					p19 = p17 - v[4]
					p19[2] = p13[2]
					p21 = extend_line(p13, p19, @wood_strut_depth)
				end 
				status, pt12 = line_plane_intersection([p16, p16 + v[0]], [@g_center, p2, t2])
				if (status == 1) then
					p18 = pt12 - v[6] - v[6]
					p20 = p18 - v[4]
					p20[2] =  p14[2]
					p22 = extend_line(p14, p20, @wood_strut_depth)
				end 
				
				#Create the top of the frame (horizontal strut)
				create_solid([p13 ,p14 ,p13 - v[4] ,p14 - v[4], p21, p22, p21 - v[4], p22 - v[4]])
				#create variables for 'top of frame'
				tf1 = p13 - v[4]
				tf2 = p14 - v[4]
				tf3 = p21 - v[4]
				tf4 = p22 - v[4]

				#Create more vertical struts
				trans = Geom::Transformation.translation([tf3[0] - ht, tf3[1] - hd, tf3[2]])
				new_vstrut = @geodesic.entities.add_instance vstrut_def, trans

				trans = Geom::Transformation.translation([tf4[0] - ht, tf4[1] - hd, tf4[2]])
				new_vstrut = @geodesic.entities.add_instance vstrut_def, trans

				
				#Create a vertical strut 
				#fsh = Geom::Vector3d.new [0,0, -(@base_frame_height - 2 * @wood_strut_thickness)]	#vertical frame strut height
				#s_vec = tf1 - tf2
				#f_vec = fsh.cross s_vec
				#f_vec.length = @wood_strut_depth
				#tf5 = tf3 - f_vec
				#tf6 = tf3 + f_vec
				#check for an intersection so we know the vector has the right sign
				#d1 = tf1.distance(tf5) + tf2.distance(tf5)
				#d2 = tf1.distance(tf6) + tf2.distance(tf6)	
				#if (d1 < d2) then
				#	tf5_6_1 = tf5
				#	tf5_6_2 = tf4 - f_vec
				#else
				#	tf5_6_1 = tf6
				#	tf5_6_2 = tf4 + f_vec
				#end

				#tf7 = extend_line(tf5_6_1, tf2, @wood_strut_thickness)
				#tf8 = extend_line(tf3, tf4, @wood_strut_thickness)
				#create_solid([tf5_6_1 ,tf7 ,tf5_6_1 + fsh ,tf7 + fsh, tf3, tf8, tf3 + fsh, tf8 + fsh])
				
				#Turn the Vertical Strut into a component for reuse
				#v_strut_grp = @geodesic.entities.add_group
				#v_strut_comp = v_strut_grp.to_component
				#v_strut_def = v_strut_comp.definition
				
				#m1 = extend_line(tf5_6_1, tf2, @wood_strut_thickness)
				#trans = Geom::Transformation.translation(m1)
				#new_v_strut = @geodesic.entities.add_instance v_strut_def, trans
			
				
			}
			
		end
		
		def isPointUnique(array, pnt)
			array.each_with_index { |p, index|
				v = Geom::Vector3d.new(pnt - p);
				if (v.length < @g_tolerance)
					return index;
				end	
			}
			return -1
		end
		
		def add_hubs()
			if (@draw_hubs == 1)
				if (@draw_sphere_hubs == 1)
					add_sphere_hubs()
				end
				
				if (@draw_metal_hubs == 1)
					add_metal_hubs()
				end
			end
		end

		def add_vertex_points()
			u_hubs = []
		
			#Create a hub for each point
			@primitive_points.each { |c|
				#only draw hubs at unique points (the primitive_points list contains duplicates)
				if (isPointUnique(u_hubs, c) == -1)
					u_hubs.push(c)
					if (c[2] > -@g_tolerance)
						@geodesic.entities.add_cpoint c
					end
				end
			}		
		end
		
		def add_sphere_hubs()
			u_hubs = []

			#Create a hub
			hub = @geodesic.entities.add_group
			circle1 = hub.entities.add_circle([0,0,0], Geom::Vector3d.new([1, 0, 0]), @sphere_hub_radius)				
			circle2 = hub.entities.add_circle([0,0,0], Geom::Vector3d.new([0, 1, 0]), @sphere_hub_radius)	
			c1_face = hub.entities.add_face circle1
			c1_face.followme circle2
			smooth(hub)
			
			#cycle through the sphere faces and assign material to all
			faces = []
			hub.entities.each{|f|
				faces << f if f.class == Sketchup::Face
			}
			
			faces.each { |face|
				face.material = @hub_material
				face_back_material = @hub_material
			}
			hub_comp = hub.to_component
			
			#get the definition of the hub so we can make more
			hub_def = hub_comp.definition
			
			#Create a hub for each point
			@primitive_points.each { |c|
				#only draw hubs at unique points (the primitive_points list contains duplicates				
				if (isPointUnique(u_hubs, c) == -1)
					u_hubs.push(c)
					if (c[2] > -@g_tolerance)
						#Create some copies of our hub component
						trans = Geom::Transformation.translation(c)
						new_hub = @geodesic.entities.add_instance hub_def, trans

						#Add hub to the global hub list
						@strut_hubs.push(new_hub)
					end
				end
			}

			#Delete our master component
			@geodesic.entities.erase_entities hub_comp
		end
		
		#Smooth the edges of a shape
		def smooth(shape)
			edges = []
			shape.to_a.each{|e|
				edges << e if e.class == Sketchup::Edge
				e.entities.each{|ee|edges << ee if ee.class == Sketchup::Edge}if e.class == Sketchup::Group
			}
			edges.each{|edge|
			ang = edge.faces[0].normal.angle_between(edge.faces[1].normal)
			   if edge.faces[1]
				 edge.soft = true if ang < 45.degrees
				 edge.smooth = true if ang < 45.degrees
			   end
			}
		end
		

		
		def add_metal_hubs()
			u_hubs = []

			#Calculate the inner radius
			inner_radius = @metal_hub_outer_radius - @metal_hub_outer_thickness

			#TODO: having trouble getting the rotation right on the component version
			#hub = @geodesic.entities.add_group
			#outer_circle = hub.entities.add_circle([0, 0, 0], Geom::Vector3d.new([0, 0, 1]), @metal_hub_outer_radius)				
			#inner_circle = hub.entities.add_circle([0, 0, 0], Geom::Vector3d.new([0, 0, 1]), inner_radius)
			#outer_end_face = hub.entities.add_face outer_circle
			#inner_end_face = hub.entities.add_face inner_circle
			#hub.entities.erase_entities inner_end_face		#remove the inner face we just added (need to do this to create cylinder end
			#outer_end_face.pushpull @metal_hub_depth_depth, false
			#hub_comp = hub.to_component
			
			#get the definition of the hub so we can make more
			#hub_def = hub_comp.definition

			
			#Create a hub for each point
			@primitive_points.each_with_index { |i, index|
				if (isPointUnique(u_hubs, i) == -1)
					u_hubs.push(i)
					#Draw only the positive hub for a dome
					if (i[2] > -@g_tolerance)
						#Create some copies of our hub component

						hub = @geodesic.entities.add_group
						outer_circle = hub.entities.add_circle(i, Geom::Vector3d.new(@g_center.vector_to(i)), @metal_hub_outer_radius)				
						inner_circle = hub.entities.add_circle(i, Geom::Vector3d.new(@g_center.vector_to(i)), inner_radius)
						outer_end_face = hub.entities.add_face outer_circle
						inner_end_face = hub.entities.add_face inner_circle
						hub.entities.erase_entities inner_end_face		#remove the inner face we just added (need to do this to create cylinder end
						outer_end_face.pushpull -@metal_hub_depth_depth, false
						#cycle through the sphere faces and assign material to all
						faces = []
						hub.entities.each{|f|
							faces << f if f.class == Sketchup::Face
						}
						
						faces.each { |face|
							face.material = @hub_material
							face_back_material = @hub_material
						}						
						
						#p = Geom::Point3d.new(@g_center)	# rotate from the origin
						#p = Geom::Point3d.new([0, 0, 0])	

												
						#Create a copy, but don't move it (it needs rotating first
						#trans = Geom::Transformation.translation([0,0,0])
						#new_hub = @geodesic.entities.add_instance hub_def, trans
						
						#Create a vector pointing up the Z axis
						#z_vec = Geom::Vector3d.new [0, 0, 1]
						
						#Turn our target point into a unit vector
						#v = Geom::Vector3d.new i[0], i[1], i[2]
						#v.length = 1
						
						#v_x = Geom::Vector3d.new i[0], 0, i[2]
						#v_y = Geom::Vector3d.new 0, i[1], i[2]
						
						#Get the angle (theta) between the Z-axis and the vector
						#ang_x = (z_vec.angle_between v_x)
						#ang_y = (z_vec.angle_between v_y)
						
						#Create the rotation matrix
						#c = Math::cos(theta)
						#s = Math::sin(-theta)
						#t = 1 - Math::cos(theta)
						#r = [t * v.x * v.x + c, t * v.x * v.y - s * v.z, t * v.x * v.z + s * v.y, 0, +
						#	t * v.x * v.y + s * v.z, t * v.y * v.y + c, t * v.y * v.z - s * v.x, 0, +
						#	t * v.x * v.z - s * v.y, t * v.y * v.z + s * v.x, t * v.z * v.z + c, +
						#	0, 0, 0, 0, 1]
		
											
						#r1 = Geom::Transformation.new(r)
						#Create a rotation transform and rotate the object
						#r1 = Geom::Transformation.rotation(p, [0,1,0], ang_x)
						#r2 = Geom::Transformation.rotation(p, [1,0,0], ang_y)
						#t = r1 * r2
						#new_hub.transform!(t)
						
						#Translate to final destination
						#t = Geom::Transformation.translation(i)
						#new_hub.transform!(t)
						
						#Add hub to the global hub list
						#@strut_hubs.push(new_hub)

						#Add hub to the global hub list
						@strut_hubs.push(hub)
					end
				end
			}	
		end

		def isLineUnique(array, line)
			array.each_with_index { |p, index|
				v1_1 = Geom::Vector3d.new(line[0] - p[0]);
				v1_2 = Geom::Vector3d.new(line[1] - p[0]);
				v2_1 = Geom::Vector3d.new(line[1] - p[1]);
				v2_2 = Geom::Vector3d.new(line[0] - p[1]);
				#Check the points in both orientations
				if (v1_1.length < @g_tolerance && v2_1.length < @g_tolerance)
					return index;
				end
				if (v1_2.length < @g_tolerance && v2_2.length < @g_tolerance)
					return index;
				end
			}
			return -1;
		end
		
		def add_struts()
			@u_struts = []
			#Add the struts
			@strut_points.each { |c|
				if (@primitive_points[c[0]][2] > -@g_tolerance && @primitive_points[c[1]][2] > -@g_tolerance) then
					if (isLineUnique(@u_struts, [@primitive_points[c[0]], @primitive_points[c[1]]]) == -1)
						@u_struts.push([@primitive_points[c[0]], @primitive_points[c[1]]])
						
						if (@draw_struts == 1)
							if (@draw_wood_struts == 1)
								@all_edges.push(add_wood_strut(@primitive_points[c[0]], @primitive_points[c[1]], @wood_strut_dist_from_hub))
							end
							
							if (@draw_cylinder_struts == 1)
								@all_edges.push(add_cylinder_strut(@primitive_points[c[0]], @primitive_points[c[1]]))				
							end
						end
						#Add the hub plates
						#This currently relies on being here so that it gets the correct faces passed to it.
						if (@draw_metal_hubs == 1)
							#add_hub_plates(strut_faces, @strut_hubs[c[0]], @strut_hubs[c[1]], strut_dist_from_hub)
						end
					end
				end
			}	
		end
				
		def add_wood_frame()
		
			@triangle_points.each { |pts|
				orient = orientate(pts)
				pp0 = @primitive_points[pts[orient]]	
				pp1 = @primitive_points[pts[(orient + 1) % 3]]	
				pp2 = @primitive_points[pts[(orient + 2) % 3]]
				
				#create some vectors so that we can create the 4 points that will make the plane of strut at correct orientation
				v1 = Geom::Vector3d.new(@g_center.vector_to(pp1))
				v2 = Geom::Vector3d.new(@g_center.vector_to(pp2))
				v3 = Geom::Vector3d.new(pp2.vector_to(pp1))
				
				#calculate the normal
				n1 = v1.cross v3
				n2 = v2.cross v3
				n1.length = @wood_strut_thickness / 2
				n2.length = @wood_strut_thickness / 2

				#create the outer facing points
				pt = []
				pt[0] = pp1 + n1
				pt[1] = pp1 - n1
				pt[2] = pp2 + n2
				pt[3] = pp2 - n2

				#create the inner facing points
				v1.length = @wood_strut_depth
				v2.length = @wood_strut_depth
				
				pt[4] = pt[2] - v1
				pt[5] = pt[3] - v1
				pt[6] = pt[4] - v2
				pt[7] = pt[5] - v2
				
				#work out which pair of points is closer so that the frame doesn't go through strut
				if (pp0.distance(pt[0]) < pp0.distance(pt[1]))
					pt_a = pt[0]
					pt_b = pt[2]
					pt_c = pt[4]
					pt_d = pt[6]					
				else
					pt_a = pt[1]
					pt_b = pt[3]	
					pt_c = pt[5]
					pt_d = pt[7]	
				end
	#			entities.add_face pt_a, pt_b, pt_c		#face to do intersections with
				
				m1 = midpoint(pp1, pp2)
				center = centroid([pp0, pp1, pp2])
				v = Geom::Vector3d.new(center - m1)		#Vector we'll use for orientating all frame struts
				v.length = m1.distance(pp0)
				
				seperation = @frame_separation / 2	#first distance is 1/2 amount as it is either side of center
				dist_left = pt_a.distance(pt_b) / 2 - seperation - @wood_strut_dist_from_hub
				offset = seperation
				half_thickness = @wood_strut_thickness / 2
				while (dist_left > @frame_separation / 2 + half_thickness)
					ex1_1 = extend_line(m1, pp1, offset - half_thickness)
					ex1_2 = extend_line(m1, pp1, offset + half_thickness)
					ex2_1 = extend_line(m1, pp2, offset - half_thickness)
					ex2_2 = extend_line(m1, pp2, offset + half_thickness)
					status, i1_1 = line_plane_intersection([ex1_1, ex1_1 + v], [pt_a, pt_b, pt_c])
					status, i1_2 = line_plane_intersection([ex1_2, ex1_2 + v], [pt_a, pt_b, pt_c])
					status, i2_1 = line_plane_intersection([ex2_1, ex2_1 + v], [pt_a, pt_b, pt_c])
					status, i2_2 = line_plane_intersection([ex2_2, ex2_2 + v], [pt_a, pt_b, pt_c])

					pl1 = get_closest_plane(center, [pp0, pp1])
					pl2 = get_closest_plane(center, [pp0, pp2])
					status, i1_1e = line_plane_intersection([i1_1, i1_1 + v], [pl1[0], pl1[1], pl1[2]])
					status, i1_2e = line_plane_intersection([i1_2, i1_2 + v], [pl1[0], pl1[1], pl1[2]])
					status, i2_1e = line_plane_intersection([i2_1, i2_1 + v], [pl2[0], pl2[1], pl2[2]])
					status, i2_2e = line_plane_intersection([i2_2, i2_2 + v], [pl2[0], pl2[1], pl2[2]])
					
					v2 = Geom::Vector3d.new(@g_center.vector_to(i1_1))
					v2.length = @wood_strut_depth
					i3_1 = i1_1 - v2
					i3_2 = i1_2 - v2
					i4_1 = i2_1 - v2
					i4_2 = i2_2 - v2
					status, i3_1e = line_plane_intersection([i3_1, i3_1 + v], [pl1[0], pl1[1], pl1[2]])
					status, i3_2e = line_plane_intersection([i3_2, i3_2 + v], [pl1[0], pl1[1], pl1[2]])
					status, i4_1e = line_plane_intersection([i4_1, i4_1 + v], [pl2[0], pl2[1], pl2[2]])
					status, i4_2e = line_plane_intersection([i4_2, i4_2 + v], [pl2[0], pl2[1], pl2[2]])

					#Now that we have the 8 points, create the faces of the frame strut
					s1 = create_solid([i1_1, i1_1e, i1_2, i1_2e, i3_1, i3_1e, i3_2, i3_2e])	
					s2 = create_solid([i2_1, i2_1e, i2_2, i2_2e, i4_1, i4_1e, i4_2, i4_2e])	
					
					@frame_struts.push(s1)				
					@frame_struts.push(s2)
					
					#update variables for next iteration
					dist_left -= seperation
					seperation = @frame_separation
					offset += seperation
				end
			}
		end
		
		def create_solid(pts)

			#create the faces of the solid
			solid = @geodesic.entities.add_group
			face = Array.new(6)
			face[0] = solid.entities.add_face pts[0], pts[1], pts[3], pts[2]
			face[1] = solid.entities.add_face pts[0], pts[1], pts[5], pts[4]
			face[2] = solid.entities.add_face pts[0], pts[2], pts[6], pts[4]
			face[3] = solid.entities.add_face pts[2], pts[3], pts[7], pts[6]	
			face[4] = solid.entities.add_face pts[1], pts[3], pts[7], pts[5]
			face[5] = solid.entities.add_face pts[4], pts[5], pts[7], pts[6]	
			
			#set the color of the solid
			color = @strut_material
			for c in 0..5
				face[c].material = color
				face[c].back_material = color		
			end

			return solid
		end
		
		#given 2 pts, calculate the 4 points that make the closest facing plane that would make up a strut
		def get_closest_plane(pt, pts)
			p1 = pts[0]
			p2 = pts[1]
			
			#Create a vector of inset length (this will be how far back from the hub the strut starts
			v1 = Geom::Vector3d.new(p2[0] - p1[0], p2[1] - p1[1], p2[2] - p1[2])
			v1.length = @wood_strut_dist_from_hub
			
			#calculate the inset point ends 
			pt1 = Geom::Point3d.new(p1[0] + v1[0], p1[1] + v1[1], p1[2] + v1[2])
			pt2 = Geom::Point3d.new(p2[0] - v1[0], p2[1] - v1[1], p2[2] - v1[2])

			#create some vectors so that we can create the 4 points that will make the plane of strut at correct orientation
			v2 = Geom::Vector3d.new(@g_center.vector_to(p1))
			v3 = Geom::Vector3d.new(@g_center.vector_to(p2))
			v4 = Geom::Vector3d.new(p2.vector_to(p1))
			
			#calculate the normal
			n1 = v2.cross v4
			n2 = v3.cross v4
			n1.length = @wood_strut_thickness / 2
			n2.length = @wood_strut_thickness / 2

			#create the outer facing points
			pt3 = pt1 + n1
			pt4 = pt1 - n1
			pt5 = pt2 + n2
			pt6 = pt2 - n2
			
			#create the inner facing points
			v2.length = @wood_strut_depth
			v3.length = @wood_strut_depth
			
			pt7 = pt3 - v2
			pt8 = pt4 - v2
			pt9 = pt5 - v3
			pt10 = pt6 - v3

			if (pt.distance(pt3) < pt.distance(pt4))
				return [pt3, pt5, pt9, pt7]
			else
				return [pt4, pt6, pt10, pt8]		
			end
		end
		
		#Given 3 points references(array) pick the that when joined to the center of the opposing side gives 
		#the most up/down lines (for frame orientation)
		def orientate(pts)
			#Get centroid of triangle
			c = centroid([@primitive_points[pts[0]], @primitive_points[pts[1]], @primitive_points[pts[2]]])
			
			#Collect which points are above and below the center point in Z
			above = []
			below = []
			for i in 0..2
				if (@primitive_points[pts[i]][2] > c[2])
					above.push(i)
				else
					below.push(i)
				end
			end
		
			#The best orientation is the point by itself
			if (above.size() == 1)
				return above[0]
			else
				return below[0]
			end
		end
		
		#returns the centroid of a triangle given points
		def centroid(pts)
			m1 = midpoint(pts[1], pts[2])
			m2 = midpoint(pts[0], pts[1])
			c = Geom.intersect_line_line [pts[0], m1], [pts[2], m2]
			
			return c
		end
		
		#Return the midpoitn of two points
		def midpoint(p1, p2)
			v = Geom::Vector3d.new(p2 - p1)
			v.length = p1.distance(p2) / 2
			
			return p1 + v
		end
		
		# Given 3 points that make up a triangle, decompose the triangle into 
		# [@g_frequency] smaller triangles along each side
		def tessellate (p1, p2, p3)
			c  = 0
			order = @g_frequency + 1
			row = 0
			rf = row / @g_frequency
			$p_s = [p1[0] + (p3[0] - p1[0]) * rf, p1[1] + (p3[1] - p1[1]) * rf, p1[2] + (p3[2] - p1[2]) * rf]
			$p_e = [p2[0] + (p3[0] - p2[0]) * rf, p2[1] + (p3[1] - p2[1]) * rf, p2[2] + (p3[2] - p2[2]) * rf]

			while c < order
			
				if (order == 1)
					@primitive_points.push(Geom::Point3d.new([$p_s[0], $p_s[1], $p_s[2]]))	
				else 
					co1 = c.to_f / (order - 1)
					x = $p_s[0] + ($p_e[0] - $p_s[0]) * co1
					y = $p_s[1] + ($p_e[1] - $p_s[1]) * co1
					z = $p_s[2] + ($p_e[2] - $p_s[2]) * co1
					p = Geom::Point3d.new([x, y, z])
					
					length = @g_center.distance(p)
					ratio = @g_radius.to_f / length
					v = @g_center.vector_to(p)
					v.length = @g_radius
					
					@primitive_points.push(Geom::Point3d.new(extend_line(@g_center, p, @g_radius)))
				end
				p_num = @primitive_points.size() - 1
			
				if (c > 0)
					#if (@primitive_points[p_num][2] >= -1 * @g_tolerance && @primitive_points[p_num - 1][2] >= -1 * @g_tolerance)
						@strut_points.push([p_num - 1, p_num])
					#end
				end
			
				if (order < @g_frequency + 1)
					#if (@primitive_points[p_num - order][2] >= -@g_tolerance && @primitive_points[p_num][2] >= -@g_tolerance)
						@strut_points.push([p_num - order, p_num])
					#end			
					#if (@primitive_points[p_num - order - 1][2] >= -@g_tolerance && @primitive_points[p_num][2] >= -@g_tolerance)
						@strut_points.push([p_num - order - 1, p_num])
					#end

					if (@primitive_points[p_num - order][2] >= -@g_tolerance && @primitive_points[p_num - order - 1][2] >= -@g_tolerance && @primitive_points[p_num][2] >= -@g_tolerance)
						if (@draw_tessellated_faces == 1)
							face = @geodesic.entities.add_face @primitive_points[p_num - order], @primitive_points[p_num - order - 1], @primitive_points[p_num]	
							face.material = @face_material
							face.back_material = @face_material
						end
						@triangle_points.push([p_num - order, p_num - order - 1, p_num])
					end

					if (c > 0)
						if (@primitive_points[p_num - order - 1][2] >= -@g_tolerance && @primitive_points[p_num][2] >= -@g_tolerance && @primitive_points[p_num - 1][2] >= -@g_tolerance)
							if (@draw_tessellated_faces == 1)
								face = @geodesic.entities.add_face @primitive_points[p_num - order - 1], @primitive_points[p_num], @primitive_points[p_num - 1]		
								face.material = @face_material
								face.back_material = @face_material
							end
							@triangle_points.push([p_num - order - 1, p_num, p_num - 1])
						end
					end
				end
				c += 1
				
				if (c == order)
					c = 0
					order -= 1
					row += 1
					rf = row.to_f / @g_frequency
					$p_s = [p1[0] + (p3[0] - p1[0]) * rf, p1[1] + (p3[1] - p1[1]) * rf, p1[2] + (p3[2] - p1[2]) * rf]
					$p_e = [p2[0] + (p3[0] - p2[0]) * rf, p2[1] + (p3[1] - p2[1]) * rf, p2[2] + (p3[2] - p2[2]) * rf]
				end
				p_num += 1
			end
			
		end
		
		def add_cylinder_strut(p1, p2)

			#create a group for our strut
			strut = @geodesic.entities.add_group

			#Create a vector of inset length (this will be how far back from the hub the strut starts
			v1 = Geom::Vector3d.new(p2[0] - p1[0], p2[1] - p1[1], p2[2] - p1[2])
			v1.length = @cylinder_strut_extension.abs
			
			#calculate the inset point ends 
			if (@cylinder_strut_extension != 0)
				if (@cylinder_strut_extension < 0) 
					pt1 = Geom::Point3d.new(p1[0] + v1[0], p1[1] + v1[1], p1[2] + v1[2])
					pt2 = Geom::Point3d.new(p2[0] - v1[0], p2[1] - v1[1], p2[2] - v1[2])
				else 
					pt1 = Geom::Point3d.new(p1[0] - v1[0], p1[1] - v1[1], p1[2] - v1[2])
					pt2 = Geom::Point3d.new(p2[0] + v1[0], p2[1] + v1[1], p2[2] + v1[2])
				end 
			else
				pt1 = Geom::Point3d.new(p1[0], p1[1], p1[2])
				pt2 = Geom::Point3d.new(p2[0], p2[1], p2[2])
			end
			
			#create some vectors so that we can create the 4 points that will make the plane of strut at correct orientation
			v2 = Geom::Vector3d.new(@g_center.vector_to(p1))
			v3 = Geom::Vector3d.new(@g_center.vector_to(p2))
			v4 = Geom::Vector3d.new(p2.vector_to(p1))	
			
			n1 = v2.cross v4
			n1.length = @cylinder_strut_offset
			pt1o = Geom::Point3d.new(pt1[0] - n1[0], pt1[1] - n1[1], pt1[2] - n1[2])
			pt2o = Geom::Point3d.new(pt2[0] + n1[0], pt2[1] + n1[1], pt2[2] + n1[2])
			
			#strut.entities.add_line pt1o, pt2o
			
			circle = strut.entities.add_circle pt1o, pt1o.vector_to(pt2o), @cylinder_strut_radius
			circle_face = strut.entities.add_face circle

			color = @strut_material
			circle_face.material = color; circle_face.back_material = color;

			dist = pt1.distance(pt2)
			circle_face.pushpull dist, false

		end
		
		# Creates a strut orientated to face out from the origin
		# The ends are [distance] back from the points [p1, p2] to accommodate hubs
		# The ends are also angled to allow closer mounting to the hubs
		def add_wood_strut(p1, p2, distance)

			#create a group for our strut
			strut = @geodesic.entities.add_group

			#Create a vector of inset length (this will be how far back from the hub the strut starts
			v1 = Geom::Vector3d.new(p2[0] - p1[0], p2[1] - p1[1], p2[2] - p1[2])
			v1.length = distance
			
			#calculate the inset point ends 
			pt1 = Geom::Point3d.new(p1[0] + v1[0], p1[1] + v1[1], p1[2] + v1[2])
			pt2 = Geom::Point3d.new(p2[0] - v1[0], p2[1] - v1[1], p2[2] - v1[2])

			#create some vectors so that we can create the 4 points that will make the plane of strut at correct orientation
			v2 = Geom::Vector3d.new(@g_center.vector_to(p1))
			v3 = Geom::Vector3d.new(@g_center.vector_to(p2))
			v4 = Geom::Vector3d.new(p2.vector_to(p1))
			
			#calculate the normal
			n1 = v2.cross v4
			n2 = v3.cross v4
			n1.length = @wood_strut_thickness / 2
			n2.length = @wood_strut_thickness / 2

			#create the outer facing points
			pt3 = pt1 + n1
			pt4 = pt1 - n1
			pt5 = pt2 + n2
			pt6 = pt2 - n2
			
			#create the inner facing points
			v2.length = @wood_strut_depth
			v3.length = @wood_strut_depth
			
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
			color = @strut_material
			for c in 0..5
				face[c].material = color;
				face[c].back_material = color			
			end
			
			#return the side faces that will be used to fix the hub side plates to
			return face[3], face[5]
		end	

		#Returns a point along the [p1/p2] line [dist] from [p1] in the direction of [p2]
		def extend_line(p1, p2, dist)
			#v = Geom::Vector3d.new (p2[0] - p1[0], p2[1] - p1[1], p2[2] - p1[2])
			v = p1.vector_to(p2)

			v.length = dist
			return p1 + v
		end		

		def line_line_intersection(line1, line2)
		 
		  point = Geom.intersect_line_line(line1,line2) 
		  if not point ### no intersection of edges' lines 
			return nil
		  else ### see if cross/touch 
			d11 = point.distance(line1[0]) + point.distance(line1[1]) 
			d12 = line1[0].distance(line1[1]) + 0.0 
			d21 = point.distance(line2[0]) + point.distance(line2[1]) 
			d22 = line2[0].distance(line2[1]) + 0.0 
			if ((d11 <= d12) or (d11 - d12 < 1e-10)) and ((d21 <= d22) or (d21 - d22 < 1e-10)) 
				return point 
			end 
				return nil
		  end
		end 
		
		#Given a line (defined by 2 Point3d's and a plane defined by 3 Point3d's, return point of incidence
		#A status will also be returned -1 = Parallel, no intersection, 0 = Line is coincident with plane, 1 = normal intersection, 
		#	2 = no intersection unless the line is considered infinite ray
		def line_plane_intersection(line, plane)
			#Create some vectors from the line and plane
			p_v1 = Geom::Vector3d.new(plane[1] - plane[0])
			p_v2 = Geom::Vector3d.new(plane[2] - plane[0])
			
			l1 = Geom::Point3d.new(line[0])
			l2 = Geom::Point3d.new(line[1])
			
			l_v = Geom::Vector3d.new(l2 - l1)
			
			#The point of intersection we will return
			intersect = Geom::Point3d.new([0,0,0])
			
			#Get the normal to the plane
			p_norm = p_v1.cross(p_v2)
			
			#Check if the line is parallel to the plane
			parallel = p_norm.dot(l_v)
			if (parallel == 0)
				#Now check if the line is also ON the plane
				if ( p_norm.dot(line[0] - plane[0]) != 0)
					#the line is actually on the plane
					status = 0
				else	
					#it is just parallel
					status = -1
				end
			else
				w = Geom::Vector3d.new([plane[1].x - l1.x, plane[1].y - l1.y, plane[1].z - l1.z])
				t = p_norm.dot(w) / parallel
				
				if (t >= 0 and t <= 1)
					#The 'finite' line intersects the plane
					status = 1
				else
					#The 'infinite' line intersects the plane
					status = 2
				end

				#Calculate the point on the line
				intersect = Geom::Point3d.new([t * l2.x + (1 - t) * l1.x, t * l2.y + (1 - t) * l1.y, t * l2.z + (1 - t) * l1.z])
			end
			
			return [status, intersect]
		end
		
	end	#End of Class Geodesic



	#Not being used until I get around to fixing them =)
	def add_hub_plates(strut_faces, hub1, hub2, extend_dist)

		plate_thickness = 0.25

		hub_plate = @geodesic.add_group
		face1_coords = calc_hub_plate_face(strut_faces[0], 0, hub1, extend_dist)
		face1 = hub_plate.entities.add_face(face1_coords[0], face1_coords[1], face1_coords[2], face1_coords[3])

		#Create a normal to the inner face
		normal  = face1.normal
		normal.length = plate_thickness
		vertices = strut_faces[0].vertices
		tmp_grp = entities.add_group
		tmp_face2 = tmp_grp.entities.add_face(vertices[0].position - normal, vertices[1].position - normal, vertices[2].position - normal, vertices[3].position - normal)
		face2_coords = calc_hub_plate_face(tmp_face2, 0, hub1, extend_dist)
		hub_plate.entities.add_face(face2_coords[0], face2_coords[1], face2_coords[2], face2_coords[3])
		
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



end # su_geodesic

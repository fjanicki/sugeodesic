#	Geodesic Dome Creator allows you to create fully customized Geodesic 
#	Domes from within SketchUp
#    Copyright (C) 2013-2015 Paul Matthews
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
			@g_radius_x = 100
			@g_radius_y = 100
			@g_radius_z = 100
			@g_platonic_solid = 20
			
			@g_fraction_num = 1
			@g_fraction_den = 2
			@g_fraction = @g_fraction_num.to_f / @g_fraction_den.to_f
			@g_center = Geom::Point3d.new([0, 0, -(@g_radius_z) + 2 * @g_radius_z * @g_fraction])
			
			@draw_primitive_solid_faces = false
			@draw_primative_vertex_points = false
			@primitive_face_material = [255, 255, 255]

			@draw_tessellated_faces = false
			@face_material = Sketchup.active_model.materials.add "face_material"
			
			#Generic Hub configuration
			@draw_hubs = false
			@hub_material = Sketchup.active_model.materials.add "hub_material"
			
			#Sphere hub configuration
			@draw_sphere_hubs = 0
			@sphere_hub_radius = 5
			
			#Cylindrical hub configuration
			@draw_cylinder_hubs = false
			@cylindrical_hub_outer_radius = 1.50
			@cylindrical_hub_outer_thickness = 0.25
			@cylindrical_hub_depth_depth = 4

			#Generic Strut configuration
			@draw_struts = false
			@strut_material = Sketchup.active_model.materials.add "strut_material"
			@flatten_strut_base = false
			
			#Rectangular strut configuration
			@draw_rect_struts = false
			@rect_strut_dist_from_hub = 3
			@rect_strut_thickness = 1.5
			@rect_strut_depth = 3.5

			#Cylinder strut configuration
			@draw_cylinder_struts = false
			@cylinder_strut_extension = -4
			@cylinder_strut_radius = 3
			@cylinder_strut_radius = 2
					
			#Rectangular frame configuration
			@draw_rect_frame = false
			@frame_separation = 12
			@draw_base_frame = false
			@base_frame_height = 36
			
			#Dome reference data is stored in these arrays
			#@geodesic = nil
			@geodesic = Sketchup.active_model.entities.add_group		#Main object everything contributes to
			@primitive_points = []
			@strut_points = []
			@triangle_points = []
			@base_points = []		#Points that are around the base of the dome
			@clipped_triangles = []	#array to store any clipped triangles
			
			#Dome shape data is stored in these arrays
			@hubs = []
			@all_edges = []
			@struts = []

			#variables for statistics timer
			@start_time = 0
			@end_time = 0
			
			#tolerance factor to circumvent small number errors
			@g_tolerance = 0.5
			#@g_tolerance = 100
			

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
				#Once page is loaded send the configuration file
				loadConfiguration(dialog)
			
				#Once page is loaded send extra configuration
				script = 'dataFromSketchup("SKMTools_installed", ' + @SKMTools_installed.to_s() + ');'
				dialog.execute_script(script) 
			}
			
			
			dialog.add_action_callback( "create_geodesic" ) do |dlg, msg|
				# Integer variables
				@g_frequency = Integer(dialog.get_element_value("g_frequency"))
				@g_fraction_num = Integer(dialog.get_element_value("g_fraction_num"))
				@g_fraction_den = Integer(dialog.get_element_value("g_fraction_den"))
			
				# Boolean variables		
				@draw_primative_vertex_points = dialog.execute_script("getcheckboxvalue('draw_primative_vertex_points')")
				#@draw_base_frame = dialog.execute_script("getcheckboxvalue('draw_base_frame')")
				#@draw_rect_frame = dialog.execute_script("getcheckboxvalue('draw_rect_frame')")
				#@flatten_strut_base = dialog.execute_script("getcheckboxvalue('flatten_strut_base')")
				@draw_faces = dialog.execute_script("getcheckboxvalue('draw_faces')")
				@draw_struts = dialog.execute_script("getcheckboxvalue('draw_struts')")
				@draw_hubs = dialog.execute_script("getcheckboxvalue('draw_hubs')")
				
					
				# Floating Point variables
				@g_radius_x = Float(dialog.get_element_value("g_radius_x"))
				@g_radius_y = Float(dialog.get_element_value("g_radius_y"))
				@g_radius_z = Float(dialog.get_element_value("g_radius_z"))
				@rect_strut_depth = Float(dialog.get_element_value("rect_strut_depth"))
				@rect_strut_thickness = Float(dialog.get_element_value("rect_strut_thickness"))
				@sphere_radius = Float(dialog.get_element_value("sphere_radius"))
				@base_frame_height = Float(dialog.get_element_value("base_frame_height"))
				@cylinder_strut_radius = Float(dialog.get_element_value("cylinder_strut_radius"))
				@cylinder_strut_extension = Float(dialog.get_element_value("cylinder_strut_extension"))
				@cylinder_strut_offset = Float(dialog.get_element_value("cylinder_strut_offset"))

				#setFloat(dialog, @, "")
												
				#puts "strut_material: " + @strut_material
				#puts "hub_material: " + @hub_material
				#setMaterial(dialog, @strut_material, "strut_material")			
				#setMaterial(dialog, @hub_material, "hub_material")
				@strut_material = [255, 255, 0]
				@hub_material = [192, 192, 192]
				#puts "strut_material: " + @strut_material
				#puts "hub_material: " + @hub_material
				
				# Specific variables
				val = dialog.get_element_value("face_material").gsub('\\','/')
				if (val == "")
					@face_material = [255, 255, 255]
				else
					if File.exists?(val)
						@face_material = SKM.import(val)
					end
				end

				#Platonic Solid
				v = Integer(dialog.get_element_value("ps4"))
				if (v == 1) 
					@g_platonic_solid = 4
				end				
				v = Integer(dialog.get_element_value("ps8"))
				if (v == 1) 
					@g_platonic_solid = 8
				end
				v = Integer(dialog.get_element_value("ps20"))
				if (v == 1) 
					@g_platonic_solid = 20
				end
				
				#Strut Type
				v = Integer(dialog.get_element_value("st_rect"))
				if (v == 1) 
					@draw_rect_struts = true					
					@draw_cylinder_struts = false	
				end				
				v = Integer(dialog.get_element_value("st_cyl"))
				if (v == 1) 
					@draw_rect_struts = false					
					@draw_cylinder_struts = true
				end			
			
				#Hub Type
				v = Integer(dialog.get_element_value("ht_sph"))
				if (v == 1) 
					@draw_sphere_hubs = true
					@draw_cylinder_hubs = false
				end				
				v = Integer(dialog.get_element_value("ht_cyl"))
				if (v == 1) 
					@draw_sphere_hubs = false
					@draw_cylinder_hubs = true
				end	
				v = Integer(dialog.get_element_value("ht_non"))
				if (v == 1) 
					@draw_sphere_hubs = false
					@draw_cylinder_hubs = false
				end	
				
			
				#dialog.add_action_callback("face_opacity") do |dlg, msg|
				#	puts 'in face_opacity'
				#	if (@face_material.class != Array)
				#		puts 'in face_opacity if'
				#		@face_material.alpha = Float(msg) / 100
				#	end
				#	puts 'in face_opacity done if'
				#	dialog.execute_script('send_setting();') 
				#end
			
				#Let the user know we've started
				#script = 'messageFromSketchup("Processing has started.. Give me a minute or two\n (time varies depending on settings).");'
				#t1 = Thread.new(dialog.execute_script(script))
				
				processing = UI::WebDialog.new("Working on your request...", true, "GU_GEODESIC_PROCESSING", 500, 200, 200, 400, true)
				html_path = Sketchup.find_support_file "su_geodesic/html/processing.html" ,"Plugins"
				processing.set_file(html_path)
				processing.show			
				#script = "from_ruby('Processing stuff');"
				#processing.execute_script(script)			
				dialog.close	
				draw()
				
				#Save the configuration for the next load
				saveConfiguration()
				
				#Print statistics to the Ruby Console
				statistics()
				
				#Close the dialogs
				processing.close			
			end
		end

		def loadConfiguration(dialog)
			d = "su_geodesic"
			f = "configuration.ini"
			
			
			#Check the configuration directory exists
			if (File.directory?(d) && File.file?(d + '/' + f))
				puts 'found the configuration file'
				
				#load the configuration file
				line_num = 0
				text = File.open(d + '/' + f).read
				text.gsub!(/\r\n?/, "\n")

				#process each line and send the data to the js side
				text.each_line do |line|
					line = line.strip
					var, val = line.split(/:/)
				  
					c = "setVar('" + var + "', '" + val + "')"
					dialog.execute_script(c)
					
				end
				
			end		
		end
		
		def saveConfiguration()			
			d = "su_geodesic"
			f = "configuration.ini"

			if (!File.directory?(d))
				puts 'dir does not exist'
				system 'mkdir', '-p', d
			end
			File.open(d + '/' + f, "w+") { |file| 
				
				# Integer variables
				file.puts("g_frequency:" + @g_frequency.to_s)
				file.puts("g_fraction_num:" + @g_fraction_num.to_s)
				file.puts("g_fraction_den:" + @g_fraction_den.to_s)	
			
				# Boolean variables		
				file.puts("draw_primative_vertex_points:" + @draw_primative_vertex_points.to_s)
				#file.puts("draw_base_frame:" + @draw_base_frame.to_s)
				#file.puts("draw_rect_frame:" + @draw_rect_frame.to_s)
				#file.puts("flatten_strut_base:" + @flatten_strut_base.to_s)
				file.puts("draw_faces:" + @draw_faces.to_s)
				file.puts("draw_struts:" + @draw_struts.to_s)
				file.puts("draw_hubs:" + @draw_hubs.to_s)
				
				# Floating Point variables
				file.puts("g_radius_x:" + @g_radius_x.to_s)
				file.puts("g_radius_y:" + @g_radius_y.to_s)
				file.puts("g_radius_z:" + @g_radius_z.to_s)
				file.puts("rect_strut_depth:" + @rect_strut_depth.to_s)
				file.puts("rect_strut_thickness:" + @rect_strut_thickness.to_s)
				file.puts("sphere_radius:" + @sphere_radius.to_s)
				file.puts("base_frame_height:" + @base_frame_height.to_s)
				file.puts("cylinder_strut_radius:" + @cylinder_strut_radius.to_s)
				file.puts("cylinder_strut_extension:" + @cylinder_strut_extension.to_s)
				file.puts("cylinder_strut_offset:" + @cylinder_strut_offset.to_s)
				
				# Specific variables
				if (@g_platonic_solid == 4) 
					file.puts("ps4:1")
					file.puts("ps8:0")
					file.puts("ps20:0")
				end				
				if (@g_platonic_solid == 8) 
					file.puts("ps4:0")
					file.puts("ps8:1")
					file.puts("ps20:0")
				end
				if (@g_platonic_solid == 20) 
					file.puts("ps4:0")
					file.puts("ps8:0")
					file.puts("ps20:1")
				end
				
				if (@draw_rect_struts == true && @draw_cylinder_struts == false) 
					file.puts("st_rect:1")
					file.puts("st_cyl:0")
				end				
				if (@draw_rect_struts == false && @draw_cylinder_struts == true) 
					file.puts("st_rect:0")
					file.puts("st_cyl:1")
				end	
				
				if (@draw_sphere_hubs = true && @draw_cylinder_hubs = false) 
					file.puts("ht_sph:1")
					file.puts("ht_cyl:0")
					file.puts("ht_non:0")
				end				

				if (@draw_sphere_hubs = false && @draw_cylinder_hubs = true) 
					file.puts("ht_sph:0")
					file.puts("ht_cyl:1")
					file.puts("ht_non:0")
				end	

				if (@draw_sphere_hubs = false && @draw_cylinder_hubs = false) 
					file.puts("ht_sph:0")
					file.puts("ht_cyl:0")
					file.puts("ht_non:1")
				end	
				
			}
		end
		
		def setMaterial(dialog, var, val)
			filepath = dialog.get_element_value(val).gsub('\\','/')
			puts "filepath: " + filepath
			var = [255, 255, 255]				
			
			#if (filepath == "")
			#	var = [255, 255, 255]				
			#else
			#	if File.exists?(filepath)	#Only assign alpha if a material was assigned (not a default color)
			#		var = SKM.import(filepath)
			#	end
			#end
		
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
			@g_center = Geom::Point3d.new([0, 0, -(@g_radius_z) + 2 * @g_radius_z * @g_fraction] ) 
			
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
			
			if (@flatten_strut_base == true)
				flatten_base()
			end
			
			if (@draw_base_frame == true)
				create_base_frame()
			end 
			
			#Add_hubs
			add_hubs()
			
			#Add struts			
			add_struts()

			#Add vertex construction points
			if (@draw_primative_vertex_points == true)
				add_vertex_points()
			end
			
			if(@draw_rect_frame == true)
				add_rectangular_frame()
			end
			
			@end_time = Time.now		#start timer for statistics measurements
			
		end
		
		def statistics()
			num_hubs = @hubs.size
			num_struts = @all_edges.size
			num_frame_struts = @struts.size
			
			print("Statistics\n^^^^^^^^^^\n\n")
			
			print("Frequency: #{@g_frequency}\n")
			print("Platonic Solid: #{@g_platonic_solid}\n")
			frac = @g_fraction * 100
			print("Sphere Fraction: #{frac}\n")
			print("Radius: X: #{@g_radius_x} Y: #{@g_radius_y} Z: #{@g_radius_z}\n\n")

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

			#Get the length of the sides
			r2x = @g_radius_x / 2
			r2y = @g_radius_y / 2
			r2z = @g_radius_z / 2
			print("Radius: X: #{r2x} Y: #{r2y} Z: #{r2y}\n\n")
			
			#translation transformation to account for the origin centred start and the fraction of dome desired
			t = Geom::Transformation.translation(@g_center)
			
			#Create the points of the tetrahedron
			tetrahedron = []
			tetrahedron.push(Geom::Point3d.new([0, r2y, r2z]).transform!(t))
			tetrahedron.push(Geom::Point3d.new([0, -r2y, r2z]).transform!(t))
			tetrahedron.push(Geom::Point3d.new([r2x, 0, -r2z]).transform!(t))
			tetrahedron.push(Geom::Point3d.new([-r2x, 0, -r2z]).transform!(t))

			tetra_faces = []
			c = [0, 1, 3, 1, 2, 3, 2, 0, 3, 0, 1, 2] 
			
			for i in 0..3	
				d = i * 3
				j = c[d]
				k = c[d + 1]
				l = c[d + 2]
				# draw the triangles of the tetrahedron
				if(@draw_primitive_solid_faces == true)
					if (all_pos_z([tetrahedron[j], tetrahedron[k], tetrahedron[l]]) == 0)
						#tetra_faces.push(@geodesic.entities.add_face(tetrahedron[j], tetrahedron[k], tetrahedron[l]))
					end
				end
				#decompose each face of the tetrahedron
				tessellate(tetrahedron[j], tetrahedron[k], tetrahedron[l])
			end	
			
		end
	
		#Creates the points of the tessellated octahedron
		#the points from this are used to draw all other aspects of the dome
		def create_octahedron()
			#Get the length of a sides
			r2o2 = Math.sqrt(2) / 2
			ax = @g_radius_x * r2o2
			ay = @g_radius_y * r2o2
			az = @g_radius_z * r2o2
			
			#translation transformation to account for the origin centred start and the fraction of dome desired
			t = Geom::Transformation.translation(@g_center)
			
			#Create the points of the octahedron
			octahedron = []
			octahedron.push(Geom::Point3d.new([-ax, -ay, 0]).transform!(t))
			octahedron.push(Geom::Point3d.new([ax, -ay, 0]).transform!(t))
			octahedron.push(Geom::Point3d.new([ax, ay, 0]).transform!(t))
			octahedron.push(Geom::Point3d.new([-ax, ay, 0]).transform!(t))
			octahedron.push(Geom::Point3d.new([0, 0, az]).transform!(t))
			octahedron.push(Geom::Point3d.new([0, 0, -az]).transform!(t))
					
			octa_faces = []			
			c = [0, 1, 4, 1, 2, 4, 2, 3, 4, 3, 0, 4, 0, 1, 5, 1, 2, 5, 2, 3, 5, 3, 0, 5] 			
			for i in 0..7	
				d = i * 3
				j = c[d]
				k = c[d + 1]
				l = c[d + 2]
				# draw the triangles of the octahedron
				if(@draw_primitive_solid_faces == true)
					if (all_pos_z([octahedron[j], octahedron[k], octahedron[l]]) == 0)
						#octa_faces.push(@geodesic.entities.add_face(octahedron[j], octahedron[k], octahedron[l])) 
					end
				end
				#decompose each face of the octahedron
				tessellate(octahedron[j], octahedron[k], octahedron[l])
			end							
		end

		def create_ellipse(a, b)
			#number of line segments in the ellipse
			sections = 36
			
			#extract the major axis length
			if (a[0] != 0) 
				a_l = a[0]
			end
			if (a[1] != 0) 
				a_l = a[1]
			end
			if (a[2] != 0)
				a_l = a[2]
			end
			a_sqr = a_l * a_l
			
			#extract the minor axis length
			if (b[0] != 0) 
				b_l = b[0] 
			end
			if (b[1] != 0) 
				b_l = b[1]
			end
			if (b[2] != 0) 
				b_l = b[2]
			end
			b_sqr = b_l * b_l
			#print("b_l: #{b_l}\n")			
			
			if (a[0] == 0 && b[0] == 0)
				v = Geom::Vector3d.new([1, 0, 0])
				p = Geom::Point3d.new([0, 1, 0])
			end
			if (a[1] == 0 && b[1] == 0)
				v = Geom::Vector3d.new([0, 1, 0])
				p = Geom::Point3d.new([0, 0, 1])
			end
			if (a[2] == 0 && b[2] == 0)
				v = Geom::Vector3d.new([0, 0, 1])			
				p = Geom::Point3d.new([1, 0, 0])
			end

			#create the points
			points = []
			for i in 0 .. sections - 1
				r = i *(2 * Math::PI / sections)
				t1 = Geom::Transformation.rotation([0,0,0], v, r)
				#t2 = Geom::Transformation.translation(Geom::Vector3d.new([0,0,@g_center[2]]))
				p2 = (Geom::Point3d.new(p)).transform!(t1)
				
				cos_r_sqr = Math::cos(r) * Math::cos(r)
				sin_r_sqr = Math::sin(r) * Math::sin(r)
				ell_radius = a_l * b_l / (Math::sqrt(a_sqr * sin_r_sqr + b_sqr * cos_r_sqr))
				p3 = extend_line(Geom::Point3d.new([0,0,0]), p2, ell_radius)
				z = p3[2] + @g_center[2]
				p3[2] = z
				
				points.push(p3)
			end
			
			#create the lines
			for i in 0 .. sections - 1
				Sketchup.active_model.entities.add_line points[i], points[(i+1)%sections]
			end
			
		end

		#Returns the radius of an ellipse at angle theta (0-2PI)
		def get_ellipse_radius(a, b, theta)
		
			a_sqr = a * a
			b_sqr = b * b
			cos_theta_sqr = Math::cos(theta) * Math::cos(theta)
			sin_theta_sqr = Math::sin(theta) * Math::sin(theta)
			
			radius = Math.sqrt((a_sqr * b_sqr) / (a_sqr * sin_theta_sqr + b_sqr * cos_theta_sqr))

			return radius
		end
		
		
		#Returns the radius of an ellipsoid at angle theta (0-2PI from x [longitude]) and phi (0-PI from z [latitude])
		def get_ellipsoid_radius(a, b , c, theta, phi)
		
			a_sqr = a * a
			b_sqr = b * b
			c_sqr = c * c
			cos_theta_sqr = Math::cos(theta) * Math::cos(theta)
			sin_theta_sqr = Math::sin(theta) * Math::sin(theta)
			cos_phi_sqr = Math::cos(phi) * Math::cos(phi)
			sin_phi_sqr = Math::sin(phi) * Math::sin(phi)
			
			radius = Math.sqrt((a_sqr * b_sqr * c_sqr) / (b_sqr * c_sqr * cos_theta_sqr * sin_phi_sqr + a_sqr * c_sqr * sin_theta_sqr * sin_phi_sqr + a_sqr * b_sqr * cos_phi_sqr))

			return radius
		end
		
		#Returns angle from x axis (rotation around z-axis)
		def get_theta(p)
		
			v = Geom::Vector3d.new([p[0], p[1], 0])
			theta = v.angle_between([1, 0, 0])
			if (p[1] < 0 )
				theta = theta + Math::PI
			end 
			a = theta * 180 / Math::PI
			#puts "get_theta: #{p[0]}, #{p[1]}, #{p[2]} [- #{@g_center[2]} to 1, 0, 0 : #{a}"
			return theta
		end

		#Returns angle from +z axis 
		def get_phi(p)
		
			v = Geom::Vector3d.new([p[0], p[1], p[2] - @g_center[2]])
			phi = v.angle_between([0, 0, 1])

			return phi
		end
		
		#Creates the points of the tessellated icosahedron
		#the points from this are used to draw all other aspects of the dome
		def create_icosahedron()
			# Get handles to our model and the Entities collection it contains.
			model = Sketchup.active_model
			entities = model.entities
						
			#Used to draw bounding ellipses for debugging
			#create_ellipse(Geom::Vector3d.new([@g_radius_x, 0, 0]), Geom::Vector3d.new([0, @g_radius_y, 0]))
			#create_ellipse(Geom::Vector3d.new([0, @g_radius_y, 0]), Geom::Vector3d.new([0, 0, @g_radius_z]))
			#create_ellipse(Geom::Vector3d.new([0, 0, @g_radius_z]), Geom::Vector3d.new([@g_radius_x, 0, 0]))
			
			x_sqr = @g_radius_x * @g_radius_x
			y_sqr = @g_radius_y * @g_radius_y
			z_sqr = @g_radius_z * @g_radius_z

			#create an icosahedron and rotate it around the z-axis 31.7 degrees so that hemispheres lie flat
			# Create a series of "points", each a 3-item array containing x, y, and z.
			p = Geom::Point3d.new([0,0,0])	# rotate from the origin
			v = Geom::Vector3d.new([0,1,0]) # axis of rotation
			angle = 31.7
			#angle = 0
			r = Math::PI / 180 * angle		# rotate so hemisphere is level
			t1 = Geom::Transformation.rotation(p, v, r)
			t2 = Geom::Transformation.translation(Geom::Vector3d.new([0,0,@g_center[2]]))
			
			#Array to hold the icosahedron points
			icosahedron = []

			#Calculate the golden ratio
			gr = (1 + Math::sqrt(5)) / 2

						
			#calculate the rotated point in the 'x axis' face
			c1 = (Geom::Point3d.new([-gr, 1, 0]).transform!(t1).transform!(t2))	
			c2 = (Geom::Point3d.new([gr, 1, 0]).transform!(t1).transform!(t2))
			c3 = (Geom::Point3d.new([gr, -1, 0]).transform!(t1).transform!(t2))
			c4 = (Geom::Point3d.new([-gr, -1, 0]).transform!(t1).transform!(t2))
			e1 = get_ellipse_radius(@g_radius_x, @g_radius_y, get_theta(c1))
			e2 = get_ellipse_radius(@g_radius_x, @g_radius_y, get_theta(c1))
			e3 = get_ellipse_radius(@g_radius_x, @g_radius_y, get_theta(c1))
			e4 = get_ellipse_radius(@g_radius_x, @g_radius_y, get_theta(c1))
			icosahedron.push(Geom::Point3d.new(extend_line(Geom::Point3d.new(@g_center), c1, e1)))
			icosahedron.push(Geom::Point3d.new(extend_line(Geom::Point3d.new(@g_center), c2, e2)))
			icosahedron.push(Geom::Point3d.new(extend_line(Geom::Point3d.new(@g_center), c3, e3)))
			icosahedron.push(Geom::Point3d.new(extend_line(Geom::Point3d.new(@g_center), c4, e4)))
			#@geodesic.entities.add_face(icosahedron[0], icosahedron[1], icosahedron[2], icosahedron[3]) 
			
			#calculate the rotated point in the 'y axis' face
			c1 = (Geom::Point3d.new([0, -gr, -1]).transform!(t1).transform!(t2))
			c2 = (Geom::Point3d.new([0, gr, -1]).transform!(t1).transform!(t2))	
			c3 = (Geom::Point3d.new([0, gr, 1]).transform!(t1).transform!(t2))
			c4 = (Geom::Point3d.new([0, -gr, 1]).transform!(t1).transform!(t2))
			e1 = get_ellipse_radius(@g_radius_z , @g_radius_y, get_phi(c1))
			e2 = get_ellipse_radius(@g_radius_z , @g_radius_y, get_phi(c2))
			e3 = get_ellipse_radius(@g_radius_z , @g_radius_y, get_phi(c3))
			e4 = get_ellipse_radius(@g_radius_z , @g_radius_y, get_phi(c4))
			icosahedron.push(Geom::Point3d.new(extend_line(Geom::Point3d.new(@g_center), c1, e1)))
			icosahedron.push(Geom::Point3d.new(extend_line(Geom::Point3d.new(@g_center), c2, e2)))
			icosahedron.push(Geom::Point3d.new(extend_line(Geom::Point3d.new(@g_center), c3, e3)))
			icosahedron.push(Geom::Point3d.new(extend_line(Geom::Point3d.new(@g_center), c4, e4)))
			#@geodesic.entities.add_face(icosahedron[4], icosahedron[5], icosahedron[6], icosahedron[7]) 

			#calculate the rotated point in the 'z axis' face
			c1 = (Geom::Point3d.new([-1, 0, gr]).transform!(t1).transform!(t2))	
			c2 = (Geom::Point3d.new([1, 0, gr]).transform!(t1).transform!(t2))
			c3 = (Geom::Point3d.new([1, 0, -gr]).transform!(t1).transform!(t2))
			c4 = (Geom::Point3d.new([-1, 0, -gr]).transform!(t1).transform!(t2))
			e1 = get_ellipse_radius(@g_radius_z, @g_radius_x, get_phi(c1))
			e2 = get_ellipse_radius(@g_radius_z, @g_radius_x, get_phi(c2))
			e3 = get_ellipse_radius(@g_radius_z, @g_radius_x, get_phi(c3))
			e4 = get_ellipse_radius(@g_radius_z, @g_radius_x, get_phi(c4))
			icosahedron.push(Geom::Point3d.new(extend_line(Geom::Point3d.new(@g_center), c1, e1)))
			icosahedron.push(Geom::Point3d.new(extend_line(Geom::Point3d.new(@g_center), c2, e2)))
			icosahedron.push(Geom::Point3d.new(extend_line(Geom::Point3d.new(@g_center), c3, e3)))
			icosahedron.push(Geom::Point3d.new(extend_line(Geom::Point3d.new(@g_center), c4, e4)))
			#@geodesic.entities.add_face(icosahedron[8], icosahedron[9], icosahedron[10], icosahedron[11]) 
									
			icosa_faces = []			
			#create the triangles (faces) clockwise
			c = [5,10,1,1,10,2,2,10,4,4,10,11,4,11,3,3,11,0,0,11,5,5,11,10,   0,5,6,6,5,1,2,4,7,7,4,3,   9,6,1,9,1,2,9,2,7,9,7,8,8,7,3,8,3,0,8,0,6,8,6,9] 			
			
			for i in 0..19
				d = i * 3
				j = c[d]
				k = c[d + 1]
				l = c[d + 2]
				# draw the triangles of the icosahedron
				#if(@draw_primitive_solid_faces == true)
					#if (all_pos_z([icosahedron[j], icosahedron[k], icosahedron[l]]) == 0)
						#icosa_faces.push(@geodesic.entities.add_face(icosahedron[j], icosahedron[k], icosahedron[l])) 
					#end
				#end
				
				#decompose each face of the icosahedron
				tessellate(icosahedron[j], icosahedron[k], icosahedron[l])
			end	

			#Process and triangles that were clipped
			#process_clipped_triangles()
			
			end
		
		def process_clipped_triangles()
			p = Geom::Point3d.new ([0, 0, 0])
			v = Geom::Vector3d.new 0, 0, 1
		
			@clipped_triangles.each do |t|
				ppp = find_third_point([t[0], t[1], t[2]])

				if (ppp != nil)
					intersect = intersect_line_plane(@primitive_points[t[1]], @primitive_points[ppp], p, v, 0.000001)
					pt = find_point(intersect)
					i_p = 0
					if (pt != nil)
						puts "found intersect"
						i_p = pt
					else
						@primitive_points.push intersect
						i_p = @primitive_points.size - 1
					end
					intersect2 = intersect_line_plane(@primitive_points[t[0]], @primitive_points[t[2]], p, v, 0.000001)
					pt = find_point(intersect2)
					i2_p = 0
					if (pt != nil)
						puts "found intersect2"
						i2_p = pt
					else
						@primitive_points.push intersect
						i2_p = @primitive_points.size - 1
					end
					
					puts "#{intersect} #{intersect2} #{@primitive_points[t[0]]}"
					#face = @geodesic.entities.add_face @primitive_points[t[0]], intersect, intersect2
					#face = @geodesic.entities.add_face @primitive_points[t[0]], @primitive_points[i_p], @primitive_points[i2_p]

					#face.material = 'red'
					#face.back_material = 'red'
					@triangle_points.push([@primitive_points[t[0]], intersect, intersect2])

					puts "p #{t[0]} : #{@primitive_points[t[0]]}"
					puts "i #{i_p} : #{intersect}"
					puts "i2 #{i2_p} : #{intersect2}"
					#@strut_points.push ([i_p, i2_p])
					#@strut_points.push ([i2_p, t[0]])
					#@strut_points.push ([t[0], i_p])
					
				end 
			end
		end
		
		#returns the pimitive_point id is the inpput point exists
		def find_point(point)
			ret = nil
			for p in 0 .. (@primitive_points.size - 1)
				if (@primitive_points[p][0] == point[0] and @primitive_points[p][0] == point[0] and @primitive_points[p][0] == point[0])
					return p
				end
			end			
			return ret
		end
		
		def all_pos_z(pts)
			if (pts[0][2] > -(@g_tolerance) && pts[1][2] > -(@g_tolerance) && pts[1][2] > -(@g_tolerance))
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
				if (c[2] > -(@g_tolerance)) then 
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
				v = Geom::Vector3d.new [p[0], p[1], smallest]
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
			ht = @rect_strut_thickness / 2
			hd = @rect_strut_depth / 2
			top_face = vstrut.entities.add_face [-ht, hd, 0], [ht, hd, 0], [ht, -hd, 0], [-ht, -hd, 0]
			hgt = (@base_frame_height - 2 * @rect_strut_thickness)
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
				v[0].length = @rect_strut_dist_from_hub
				
				#calculate the inset point ends 
				pt1 = p1 + v[0]
				pt2 = p2 - v[0]

				#create some vectors so that we can create the 4 points that will make the plane of strut at correct orientation
				v[1] = Geom::Vector3d.new(@g_center.vector_to(p1))
				v[2] = Geom::Vector3d.new(@g_center.vector_to(p2))
				v[3] = Geom::Vector3d.new(p2.vector_to(p1))
				v[4] = Geom::Vector3d.new([0, 0, @rect_strut_thickness])

				#calculate the normal
				n1 = v[1].cross v[3]
				n2 = v[2].cross v[3]
				
				n1.length = @rect_strut_thickness / 2 
				n2.length = @rect_strut_thickness / 2 
				
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
				v[1].length = @rect_strut_depth
				v[2].length = @rect_strut_depth
				
				pt7 = p1b - v[1]
				pt8 = p2b - v[2]
				pt9 = Geom::Point3d.new pt7 - v[4]
				pt10 = Geom::Point3d.new pt8 - v[4]
				pt9[2] = p3f[2]
				pt10[2] = p4f[2]
				pt9 = extend_line(p3f, pt9, @rect_strut_depth)
				pt10 = extend_line(p4f, pt10, @rect_strut_depth)
			
				p7_2 = Geom.intersect_line_line [pt9, pt9 + v[4]], [pt7, pt7 - v[1]]
				p8_2 = Geom.intersect_line_line [pt10, pt10 + v[4]], [pt8, pt8 - v[2]]
				
				
				#Create the angled face to level the bottom
				create_solid([p1b ,p2b ,p3f ,p4f, p7_2, p8_2, pt9, pt10])
				
				#create a temporary face to detect the intersection of the line extension with
				t1 = p1 + v[4]
				t2 = p2 + v[4]

				v[0].length = @rect_strut_dist_from_hub * 2
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
					p21 = extend_line(p13, p19, @rect_strut_depth)
				end 
				status, pt12 = line_plane_intersection([p16, p16 + v[0]], [@g_center, p2, t2])
				if (status == 1) then
					p18 = pt12 - v[6] - v[6]
					p20 = p18 - v[4]
					p20[2] =  p14[2]
					p22 = extend_line(p14, p20, @rect_strut_depth)
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
				#fsh = Geom::Vector3d.new [0,0, -(@base_frame_height - 2 * @rect_strut_thickness)]	#vertical frame strut height
				#s_vec = tf1 - tf2
				#f_vec = fsh.cross s_vec
				#f_vec.length = @rect_strut_depth
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

				#tf7 = extend_line(tf5_6_1, tf2, @rect_strut_thickness)
				#tf8 = extend_line(tf3, tf4, @rect_strut_thickness)
				#create_solid([tf5_6_1 ,tf7 ,tf5_6_1 + fsh ,tf7 + fsh, tf3, tf8, tf3 + fsh, tf8 + fsh])
				
				#Turn the Vertical Strut into a component for reuse
				#v_strut_grp = @geodesic.entities.add_group
				#v_strut_comp = v_strut_grp.to_component
				#v_strut_def = v_strut_comp.definition
				
				#m1 = extend_line(tf5_6_1, tf2, @rect_strut_thickness)
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
			if (@draw_hubs == true)
				if (@draw_sphere_hubs == true)
					add_sphere_hubs()
				end
				
				if (@draw_cylinder_hubs == true)
					add_cylindrical_hubs()
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
					if (c[2] > -(@g_tolerance))
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
					if (c[2] > -(@g_tolerance))
						#Create some copies of our hub component
						trans = Geom::Transformation.translation(c)
						new_hub = @geodesic.entities.add_instance hub_def, trans

						#Add hub to the global hub list
						@hubs.push(new_hub)
					end
				end
			}

			#Delete our master component
			@geodesic.entities.erase_entities hub_comp
		end
		
		#Smooth the edges of a shape
		def smooth(shape)
			edges = []
			
			Array(shape).each{|e|
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
		

		
		def add_cylindrical_hubs()
			u_hubs = []

			#Calculate the inner radius
			inner_radius = @cylindrical_hub_outer_radius - @cylindrical_hub_outer_thickness

			#TODO: having trouble getting the rotation right on the component version
			#hub = @geodesic.entities.add_group
			#outer_circle = hub.entities.add_circle([0, 0, 0], Geom::Vector3d.new([0, 0, 1]), @cylindrical_hub_outer_radius)				
			#inner_circle = hub.entities.add_circle([0, 0, 0], Geom::Vector3d.new([0, 0, 1]), inner_radius)
			#outer_end_face = hub.entities.add_face outer_circle
			#inner_end_face = hub.entities.add_face inner_circle
			#hub.entities.erase_entities inner_end_face		#remove the inner face we just added (need to do this to create cylinder end
			#outer_end_face.pushpull @cylindrical_hub_depth_depth, false
			#hub_comp = hub.to_component
			
			#get the definition of the hub so we can make more
			#hub_def = hub_comp.definition

			
			#Create a hub for each point
			@primitive_points.each_with_index { |i, index|
				if (isPointUnique(u_hubs, i) == -1)
					u_hubs.push(i)
					#Draw only the positive hub for a dome
					if (i[2] > -(@g_tolerance))
						#Create some copies of our hub component

						hub = @geodesic.entities.add_group
						outer_circle = hub.entities.add_circle(i, Geom::Vector3d.new(@g_center.vector_to(i)), @cylindrical_hub_outer_radius)				
						inner_circle = hub.entities.add_circle(i, Geom::Vector3d.new(@g_center.vector_to(i)), inner_radius)
						outer_end_face = hub.entities.add_face outer_circle
						inner_end_face = hub.entities.add_face inner_circle
						hub.entities.erase_entities inner_end_face		#remove the inner face we just added (need to do this to create cylinder end
						outer_end_face.pushpull -(@cylindrical_hub_depth_depth), false
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
						#@hubs.push(new_hub)

						#Add hub to the global hub list
						@hubs.push(hub)
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
				if (@primitive_points[c[0]][2] > -(@g_tolerance) && @primitive_points[c[1]][2] > -(@g_tolerance)) then
					if (isLineUnique(@u_struts, [@primitive_points[c[0]], @primitive_points[c[1]]]) == -1)
						@u_struts.push([@primitive_points[c[0]], @primitive_points[c[1]]])
						
						if (@draw_struts == true)
							if (@draw_rect_struts == true)
								@all_edges.push(add_rectangular_strut(@primitive_points[c[0]], @primitive_points[c[1]], @rect_strut_dist_from_hub))
							end
							
							if (@draw_cylinder_struts == true)
								@all_edges.push(add_cylinder_strut(@primitive_points[c[0]], @primitive_points[c[1]]))				
							end
						end
						#Add the hub plates
						#This currently relies on being here so that it gets the correct faces passed to it.
						if (@draw_cylinder_hubs == true)
							#add_hub_plates(strut_faces, @hubs[c[0]], @hubs[c[1]], strut_dist_from_hub)
						end
					end
				end
			}	
		end
				
		def add_rectangular_frame()
		
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
				n1.length = @rect_strut_thickness / 2
				n2.length = @rect_strut_thickness / 2

				#create the outer facing points
				pt = []
				pt[0] = pp1 + n1
				pt[1] = pp1 - n1
				pt[2] = pp2 + n2
				pt[3] = pp2 - n2

				#create the inner facing points
				v1.length = @rect_strut_depth
				v2.length = @rect_strut_depth
				
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
				
				seperation = @frame_separation / 2	#first distance is 1/2 amount as it is either side of centre
				dist_left = pt_a.distance(pt_b) / 2 - seperation - @rect_strut_dist_from_hub
				offset = seperation
				half_thickness = @rect_strut_thickness / 2
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
					v2.length = @rect_strut_depth
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
					
					@struts.push(s1)				
					@struts.push(s2)
					
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
			v1.length = @rect_strut_dist_from_hub
			
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
			n1.length = @rect_strut_thickness / 2
			n2.length = @rect_strut_thickness / 2

			#create the outer facing points
			pt3 = pt1 + n1
			pt4 = pt1 - n1
			pt5 = pt2 + n2
			pt6 = pt2 - n2
			
			#create the inner facing points
			v2.length = @rect_strut_depth
			v3.length = @rect_strut_depth
			
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
		
		#Return the midpoint of two points
		def midpoint(p1, p2)
			v = Geom::Vector3d.new(p2 - p1)
			v.length = p1.distance(p2) / 2
			
			return p1 + v
		end
			
		def dot_product (l1, l2)
			#l1.zip(l2).map { |a,b| a*b }.inject {|sum,el| sum+el}
			
			sum=0
			for a in 0 .. 2
				sum+= l1[a] * l2[a]
			end
			
			return sum
		end
		
		#<given 3 points of a triangle find the co-joined triangle that has both p0 and p1 in common
		def find_third_point(triangle)
		
			for t in 0 .. (@triangle_points.size - 1)
				a = nil
				a = 0 if (@triangle_points[t][0] == triangle[0])
				a = 1 if (@triangle_points[t][1] == triangle[0])
				a = 2 if (@triangle_points[t][2] == triangle[0])
				b = nil
				b = 0 if (@triangle_points[t][0] == triangle[1])
				b = 1 if (@triangle_points[t][1] == triangle[1])
				b = 2 if (@triangle_points[t][2] == triangle[1])	
				#puts "#{@triangle_points[t]} #{triangle}"
				#puts "#{@triangle_points[t]} : #{triangle}"
				#puts "a: #{a} b: #{b}"
				if (a != nil and b != nil and @triangle_points[t][3 - a - b] != triangle[2])
					puts "** #{@triangle_points[t][3 - a - b]} : #{@triangle_points[t]} #{triangle}"
					return @triangle_points[t][3 - a - b]
				end
			end	
			puts "no match!"
			
			return nil		#didn't find a match (there should always be a match)
		end
		
		def intersect_line_plane(p0, p1, p_co, p_no, epsilon)
			#p0, p1: define the line
			#p_co, p_no: define the plane:
			#p_co is a point on the plane (plane coordinate).
			#p_no is a normal vector defining the plane direction; does not need to be normalized.

			#return a Vector or None (when the intersection can't be found).
			
			u = p1 - p0
			w = p_co - p0
			dot = dot_product(p_no, u)

			if (dot.abs > epsilon)
				# the factor of the point between p0 -> p1 (0 - 1)
				# if 'fac' is between (0 - 1) the point intersects with the segment.
				# otherwise:
				#  < 0.0: behind p0.
				#  > 1.0: infront of p1.
				fac = -dot_product(p_no, w) / dot
				u2 = Geom::Vector3d.new u[0] * fac, u[1] * fac, u[2] * fac
				return p0 - u2
			else
				# The segment is parallel to plane
				return nil
			end
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

			#keep any intersect points here until we can integrate them in the main list at the end
			intersect_points = []
			intersect_lines = []
			intersect_triangles = []
			while c < order
				#puts "c: #{c} order: #{order}"
				if (order == 1)
					#theta = get_theta($p_s)
					#phi = get_phi($p_s)
					#p = Geom::Point3d.new([$p_s[0], $p_s[1], $p_s[2]])
					#l = get_ellipsoid_radius(@g_radius_x, @g_radius_y , @g_radius_z, theta, phi)
					#@primitive_points.push(Geom::Point3d.new(extend_line(@g_center, p, l)))
					@primitive_points.push(Geom::Point3d.new([$p_s[0], $p_s[1], $p_s[2]]))	
				else 
					#calculate the location of the tessellated point on the triangle
					co1 = c.to_f / (order - 1)
					x = $p_s[0] + ($p_e[0] - $p_s[0]) * co1
					y = $p_s[1] + ($p_e[1] - $p_s[1]) * co1
					z = $p_s[2] + ($p_e[2] - $p_s[2]) * co1
					p = Geom::Point3d.new([x, y, z])

					v = @g_center.vector_to(p)
					plane_proj = Geom::Vector3d.new x, y, @g_center[2]
					x_axis = Geom::Vector3d.new 1, 0, 0
					z_axis = Geom::Vector3d.new 0, 0, 1
					
					theta = get_theta(p)
					phi = get_phi(p)
									
					v.length = get_ellipsoid_radius(@g_radius_x, @g_radius_y , @g_radius_z, theta, phi)
					new_p = Geom::Point3d.new(extend_line(@g_center, p, v.length))
					
					
					#text=Sketchup.active_model.active_entities.add_text("theta: #{tt} phi: #{pp}", new_p, v)

					@primitive_points.push(new_p)
				end
				p_num = @primitive_points.size() - 1
			
				if (c > 0)
					#if (@primitive_points[p_num][2] >= -1 * @g_tolerance && @primitive_points[p_num - 1][2] >= -1 * @g_tolerance)
						#create 'horizontal' strut
						@strut_points.push([p_num - 1, p_num])
					#end
				end
			
				if (order < @g_frequency + 1)
					#if (@primitive_points[p_num - order][2] >= -(@g_tolerance) && @primitive_points[p_num][2] >= -(@g_tolerance))
						#create 'diagonal' strut 1
						@strut_points.push([p_num - order, p_num])
					#end			
					#if (@primitive_points[p_num - order - 1][2] >= -(@g_tolerance) && @primitive_points[p_num][2] >= -(@g_tolerance))
						#create 'diagonal' strut 1
						@strut_points.push([p_num - order - 1, p_num])
					#end

					#add faces (if they are above z-axis) so that we draw a dome instead of an egg
					#positive_count = 0 
					
					negatives = []
					positives = []
					if (@primitive_points[p_num - order][2] >= 0) 
						#positive_count += 1
						positives.push (p_num - order)
					else 
						negatives.push (p_num - order)
					end
					if (@primitive_points[p_num - order - 1][2] >= 0)
						#positive_count += 1	
						positives.push (p_num - order - 1)
					else
						negatives.push (p_num - order - 1)
					end
					if (@primitive_points[p_num][2] >= 0)
						#positive_count += 1	
						positives.push p_num
					else 
						negatives.push p_num
					end
					if (positives.size == 3)
						if (@draw_tessellated_faces == true)
							#add 'upside down' faces
							#    *****
							#     * *
							#      *
							
							face = @geodesic.entities.add_face @primitive_points[p_num - order], @primitive_points[p_num - order - 1], @primitive_points[p_num]	
							face.material = @face_material
							face.back_material = @face_material
						end
						@triangle_points.push([p_num - order, p_num - order - 1, p_num])
					elsif (positives.size == 2)
						#support for clipped triangle						
						p = Geom::Point3d.new([0, 0, 0])
						v = Geom::Vector3d.new 0, 0, 1
						if (@primitive_points[positives[0]][2] > @primitive_points[positives[1]][2])
							preferred_positive = 0
						else
							preferred_positive = 1
						end
						#puts "p0: #{positives[0]} p1: #{ negatives[0]}"
						intersect = intersect_line_plane(@primitive_points[positives[preferred_positive]], @primitive_points[negatives[0]], p, v, 0.000001)
						#@geodesic.entities.add_line [0, 0, 0], intersect
						#@geodesic.entities.add_line positives[preferred_positive], negatives[0]	
						#puts "new face: #{positives[0]}, #{positives[1]}, #{intersect}"
						if (intersect != @primitive_points[positives[0]] and intersect != @primitive_points[positives[1]])
#							intersect_points.push(Geom::Point3d.new(intersect))
#							intersect_lines.push([intersect_points.size - 1, positives[0]])
#							intersect_lines.push([intersect_points.size - 1, positives[1]])
#							intersect_triangles.push([positives[0], positives[1], intersect_points.size - 1])
							#puts "i_t: #{intersect_triangles.size}"

#							face = @geodesic.entities.add_face @primitive_points[positives[0]], @primitive_points[positives[1]], @primitive_points[negatives[0]]
							#if (@draw_tessellated_faces == true)
#								face = @geodesic.entities.add_face @primitive_points[positives[0]], @primitive_points[positives[1]], intersect
								#face.material = [0, 255, 255]
								#face.back_material = [0, 255, 255]
								#face.material = @face_material
								#face.back_material = @face_material
							#end
						end
						@triangle_points.push([p_num - order, p_num - order - 1, p_num])
					elsif (positives.size == 1)
						#@geodesic.entities.add_face @primitive_points[p_num - order], @primitive_points[p_num - order - 1], @primitive_points[p_num]
						
						arr = [p_num - order, p_num - order - 1, p_num]

						arr2 = sort_by_z(arr)
						#arr2 = arr.sort_by{|a| a[2]}.reverse
						#@clipped_triangles.push [p_num - order, p_num - order - 1, p_num]
						#puts "arr2: #{@primitive_points[arr2[0]]} #{@primitive_points[arr2[1]]} #{@primitive_points[arr2[2]]}"
#						@clipped_triangles.push [arr2[0], arr2[1], arr2[2]]
						#we need the two points with the highest z axis values in the first 2 positions to find the other co-incident triangle
						#ppp = find_third_point([arr[0], arr[1], arr[2]])
						#puts "ppp: #{ppp}"
						#@triangle_points.push([p_num - order, p_num - order - 1, p_num])
					else # all negative
#						@triangle_points.push([p_num - order, p_num - order - 1, p_num])
					end

					#add faces (if they are above z-axis) so that we draw a dome instead of an egg
					if (c > 0)
						#positive_count = 0
						negatives = []
						positives = []
						if (@primitive_points[p_num - order - 1][2] >= 0) 
							#positive_count += 1
							positives.push (p_num - order - 1)
						else 
							negatives.push (p_num - order - 1)
						end
						if (@primitive_points[p_num][2] >= 0)
							#positive_count += 1	
							positives.push p_num
						else 
							negatives.push p_num
						end
						if (@primitive_points[p_num - 1][2] >= 0)
							#positive_count += 1		
							positives.push (p_num - 1)
						else 
							negatives.push (p_num - 1)
						end
						if (positives.size == 3)
							if (@draw_tessellated_faces == true)
								#add 'right side up' faces
								#      *
								#     * *
								#    *****
								
								face = @geodesic.entities.add_face @primitive_points[p_num - order - 1], @primitive_points[p_num], @primitive_points[p_num - 1]		
								face.material = @face_material
								face.back_material = @face_material
							end
							@triangle_points.push([p_num - order - 1, p_num, p_num - 1])
						elsif (positives.size == 2)
							#support for clipped triangle
							p = Geom::Point3d.new([0, 0, 0])
							v = Geom::Vector3d.new 0, 0, 1
							if (@primitive_points[positives[0]][2] > @primitive_points[positives[1]][2])
								preferred_positive = 0
							else
								preferred_positive = 1
							end
							#puts "2 p0: #{positives[0]} p1: #{ negatives[0]}"
							intersect = intersect_line_plane(@primitive_points[positives[preferred_positive]], @primitive_points[negatives[0]], p, v, 0.000001)
							if (intersect != @primitive_points[positives[0]] and intersect != @primitive_points[positives[1]])
#								intersect_points.push(intersect)
#								intersect_lines.push([intersect_points.size - 1, positives[0]])
#								intersect_lines.push([intersect_points.size - 1, positives[1]])
								#intersect_triangles.push(@primitive_points[positives[0]], @primitive_points[positives[1]], intersect)
#								intersect_triangles.push([positives[0], positives[1], intersect_points.size - 1])
								#puts "i_t: #{intersect_triangles.size}"
#								face = @geodesic.entities.add_face @primitive_points[positives[0]], @primitive_points[positives[1]], @primitive_points[negatives[0]]
								#if (@draw_tessellated_faces == true)
#									face = @geodesic.entities.add_face @primitive_points[positives[0]], @primitive_points[positives[1]], intersect
									#face.material = [0, 255, 255]
									#face.back_material = [0, 255, 255]
									#face.material = @face_material
									#face.back_material = @face_material
								#end
							end
							#@geodesic.entities.add_line [0, 0, 0], intersect
							#@geodesic.entities.add_line positives[preferred_positive], negatives[0]	
#							@triangle_points.push([p_num - order - 1, p_num, p_num - 1])
						elsif (positives.size == 1)
							#@geodesic.entities.add_face @primitive_points[p_num - order - 1], @primitive_points[p_num], @primitive_points[p_num - 1]
							arr = [p_num - order - 1, p_num, p_num - 1]
							
							arr2 = sort_by_z(arr)
							#arr2 = arr.sort_by{|a| a[2]}.reverse
							#puts "arr2: #{arr2[0]} #{arr2[1]} #{arr2[2]}"
							#@clipped_triangles.push [p_num - order - 1, p_num, p_num - 1]
#							@clipped_triangles.push [arr2[0], arr2[1], arr2[2]]
							#we need the two points with the highest z axis values in the first 2 positions to find the other co-incident triangle
							#ppp = find_third_point([arr[0], arr[1], arr[2]])
							#puts "ppp: #{ppp}"
							#@triangle_points.push([p_num - order - 1, p_num, p_num - 1])
						else #all negative
#							@triangle_points.push([p_num - order - 1, p_num, p_num - 1])
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

			#Add any clipped points, struts and triangles back into the main lists
			for l in 0 .. (intersect_lines.size - 1)
				@strut_points.push [(intersect_lines[l][0] + @primitive_points.size), intersect_lines[l][1]]
			end
			pre_prim_size = @primitive_points.size

			for p in 0 .. (intersect_points.size - 1)
				@primitive_points.push intersect_points[p]
				#puts "adding: #{@primitive_points.size}"
			end

			for t in 0 .. (intersect_triangles.size - 1)
				@triangle_points.push ([intersect_triangles[t][0], intersect_triangles[t][1], (intersect_triangles[t][2] + pre_prim_size)])
			end	

		end
		
		def sort_by_z(arr)
			arr2 = []
			if (@primitive_points[arr[0]][2] >= @primitive_points[arr[1]][2] and @primitive_points[arr[0]][2] >= @primitive_points[arr[2]][2])
				arr2[0] = arr[0]
				if (@primitive_points[arr[1]][2] >= @primitive_points[arr[2]][2])
					arr2[1] = arr[1] 
					arr2[2] = arr[2]
				else
					arr2[1] = arr[2]
					arr2[2] = arr[1]
				end
			end
			if (@primitive_points[arr[1]][2] >= @primitive_points[arr[0]][2] and @primitive_points[arr[1]][2] >= @primitive_points[arr[2]][2])
				arr2[0] = arr[1]
				if (@primitive_points[arr[0]][2] >= @primitive_points[arr[2]][2])
					arr2[1] = arr[0] 
					arr2[2] = arr[2]
				else
					arr2[1] = arr[2]
					arr2[2] = arr[0]
				end						
			end
			if (@primitive_points[arr[2]][2] >= @primitive_points[arr[0]][2] and @primitive_points[arr[2]][2] >= @primitive_points[arr[1]][2])
				arr2[0] = arr[2]
				if (@primitive_points[arr[0]][2] >= @primitive_points[arr[1]][2])
					arr2[1] = arr[0]
					arr2[2] = arr[1]
				else
					arr2[1] = arr[1]
					arr2[2] = arr[0]
				end
			end 
			return arr2
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
		
		# Creates a strut orientated to face out from the center of the shape
		# The ends are [distance] back from the points [p1, p2] to accommodate hubs
		# The ends are also angled to allow closer mounting to the hubs
		def add_rectangular_strut(p1, p2, distance)

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
			n1.length = @rect_strut_thickness / 2
			n2.length = @rect_strut_thickness / 2

			#create the outer facing points
			pt3 = pt1 + n1
			pt4 = pt1 - n1
			pt5 = pt2 + n2
			pt6 = pt2 - n2
			
			#create the inner facing points
			v2.length = @rect_strut_depth
			v3.length = @rect_strut_depth
			
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
		#normal  = face1.normal
		#normal.length = plate_thickness
		#vertices = strut_faces[0].vertices
		#tmp_grp = entities.add_group
		#tmp_face2 = tmp_grp.entities.add_face(vertices[0].position - normal, vertices[1].position - normal, vertices[2].position - normal, vertices[3].position - normal)
		#face2_coords = calc_hub_plate_face(tmp_face2, 0, hub1, extend_dist)
		#hub_plate.entities.add_face(face2_coords[0], face2_coords[1], face2_coords[2], face2_coords[3])
		
		#empty the temporary group
		#tmp_grp.entities.clear!

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

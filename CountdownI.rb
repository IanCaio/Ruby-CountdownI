#!/usr/bin/ruby

require 'ruby-libappindicator'

# DEBUG FUNCTION
DEBUG=true
def debug(message)
	if DEBUG==true
		puts "DEBUG: "+message
	end
end

# SOME CONSTANTS
BLUE_ICON_RANGE = 600		#10 minutes
ORANGE_ICON_RANGE = 300		#5 minutes
# So here is how it goes: Timer > 10 minutes icon is blue. 10 minutes > Timer > 5 minutes icon is orange. Timer < 5 minutes
# icon is red. Timer is 0 icon is black.

# MAIN CLASS
class CountdownI_Class < AppIndicator::AppIndicator
	# Class variables
	@notify_delay		#Delay between the timer notifications
	@enable_notify		#Enable notifications?
	@persistent_timer	#Should the timer be persistent between calls? (Keeping track of the same timer every time you launch)

	@target_timer		#The epoch time where the timer will be over
	@countdown_timer	#The seconds remaining

	@indicator_icons	#Array with the different paths to the icons the indicator will use
	
	@is_running = false	#Did we start the timer?
	
	# Initialization (Set the indicator and the default variables values)
	def initialize(name, icon, category)
		super

		#Gtk + AppIndicator Setup
		#Getting icons paths
		@indicator_icons = []
		@indicator_icons[0] = File.realpath("./Icons/IconBlack.png")
		@indicator_icons[1] = File.realpath("./Icons/IconBlue.png")
		@indicator_icons[2] = File.realpath("./Icons/IconOrange.png")
		@indicator_icons[3] = File.realpath("./Icons/IconRed.png")
		
		mainmenu = Gtk::Menu.new
		
		#Start the timer
		mainmenu_start = Gtk::MenuItem.new("Start timer...")
		mainmenu_start.signal_connect("activate"){
			#We parse the mainmenu_start menu item as an argument because if we start the counter
			#we need to disable this item.
			self.start_timer(mainmenu_start)
		}
		
		mainmenu.append(mainmenu_start)
		mainmenu_start.show()
		
		#Quit
		mainmenu_quit = Gtk::MenuItem.new("Quit")
		mainmenu_quit.signal_connect("activate"){
			self.quit_timer()
		}

		mainmenu.append(mainmenu_quit)
		mainmenu_quit.show()

		set_menu(mainmenu)
		set_status(AppIndicator::Status::ACTIVE)

		#Default variables values
		@notify_delay=300
		@enable_notify=false
		@countdown_timer=30
		@persistent_timer=false
	end

	# Read the configuration file if it's present and readable (if it isn't present creates the default one)
	def read_config()
		#Checks if configuration file exists and if it's readable. If it doesn't exist, write one with default
		#values. If it does exist but isn't readable, leave it there and use default values. Else, just use the
		#values from the file.
		if(File.exists?(File.realpath("./Config")+"/CountdownI.config"))
			debug("Config file exists!")
			if(File.readable?(File.realpath("./Config/CountdownI.config")))
				debug("Config file is readable!")
				debug("Reading:")
				config_file = File.open(File.realpath("./Config/CountdownI.config"),"r")

				while(line = config_file.gets)
					if(!line.start_with?("//") && line.chomp.length>0)
						param_value_list = line.split("=")
						debug("Parameter: #{param_value_list[0]} - Value: #{param_value_list[1]}")
						
						case param_value_list[0]
							when "NOTIFY DELAY"
								@notify_delay=param_value_list[1].to_i
							when "ENABLE NOTIFY"
								if(param_value_list[1].chomp == "TRUE")
									@enable_notify=true
								else
									@enable_notify=false
								end
							when "INITIAL TIMER"
								@countdown_timer=param_value_list[1].to_i
							when "PERSISTENT TIMER"
								if(param_value_list[1].chomp == "TRUE")
									@persistent_timer=true
								else
									@persistent_timer=false
								end
						end
					end
				end
				config_file.close
			else
				debug("Config file not readable. Using default values...")
			end
		else
			debug("Config file not present. Writing the default one...")
			config_file = File.open(File.realpath("./Config")+"/CountdownI.config","w")

			# Write default configuration file
			config_file.write("//The configuration file is simple:\n//NOTIFY DELAY=<number> being number in the range 60-1200 seconds\n//ENABLE NOTIFY=TRUE/FALSE anything other than that means false.\n//INITIAL TIMER=<number> the initial countdown timer\n//PERSISTENT TIMER=TRUE/FALSE anything other than that means false.\n\nNOTIFY DELAY=300\nENABLE NOTIFY=FALSE\nINITIAL TIMER=30\nPERSISTENT TIMER=FALSE\n")
			
			config_file.close
		end

		# Check the values and use default ones if anything is odd:
		if(@notify_delay < 60 || @notify_delay > 1200)
			@notify_delay = 300
		end
		if(@countdown_timer <= 0)
			@countdown_timer = 30
		end
	end

	def set_timer()
		debug("Current epoch time = "+Time.new.strftime("%s"))
		
		# If the timer is not persistent, just calculate the target timer from the current epoch time
		if(@persistent_timer == false)
			debug("Persistent timer is Off!")
			
			@target_timer = Time.new.to_i + @countdown_timer
			
			debug("Countdown timer = "+@countdown_timer.to_s)
			debug("Target timer = "+@target_timer.to_s)
		else
		# If the timer is persistent, we check the target timer from the restore file if it exists or create one if it doesn't
			debug("Persistent timer is On!")
			debug("Restore file path: "+File.realpath("./")+"/countdown.restore")
			
			# File is there, we just restore the target timer
			if(File.exists?(File.realpath("./")+"/countdown.restore"))
				debug("Restore file is present")
				if(File.readable?(File.realpath("./")+"/countdown.restore"))
					debug("Restore file is readable")
					
					restore_file = File.open(File.realpath("./countdown.restore"),"r")
					
					while(line = restore_file.gets)
						@target_timer = line.to_i
					end
					
					@countdown_timer = @target_timer - Time.new.to_i
					
					debug("Target timer from restore file = "+@target_timer.to_s)
					debug("Countdown timer = "+@countdown_timer.to_s)
					
					restore_file.close
				else
					#This error shouldn't happen if the user didn't play around with chmod/chown...
					puts("[ERROR]: You don't have permissions to read the restore file...")
					exit(1)
				end
			else
			# File isn't there, we should create it
				debug("Restore file not present!")
				
				@target_timer = Time.new.to_i + @countdown_timer
			
				debug("Countdown timer = "+@countdown_timer.to_s)
				debug("Target timer = "+@target_timer.to_s)
				
				# Effectively writes the restore file
				self.write_restore_file
			end
		end
	end
	
	def write_restore_file()
		debug("Writing restore file:")
		if(File.exists?(File.realpath("./")+"/countdown.restore"))
			debug("Restore file exists already")
			if(File.writable?(File.realpath("./")+"/countdown.restore"))
				debug("Restore file is writable")
				
				restore_file = File.open(File.realpath("./countdown.restore"),"w")
				
				restore_file.write(@target_timer.to_s)
				
				restore_file.close
			else
				#This error shouldn't happen if the user didn't play around with chmod/chown...
				puts("[ERROR]: You don't have permissions to write to the restore file...")
				exit(1)
			end
		else
			debug("Restore file doesn't exist. Writing it...")
			
			restore_file = File.open(File.realpath("./")+"/countdown.restore","w")
			
			restore_file.write(@target_timer.to_s)
			
			restore_file.close
		end
	end
	
	def remove_restore_file()
		debug("Removing restore file:")
		if(File.exists?(File.realpath("./")+"/countdown.restore"))
			debug("Restore file is present")
			if(File.writable?(File.realpath("./")+"/countdown.restore"))
				debug("Restore file is writable, so probably deletable too")
				debug("Deleting restore file...")
				
				File.delete(File.realpath("./countdown.restore"))
			else
				#This error shouldn't happen if the user didn't play around with chmod/chown...
				puts("[ERROR]: You don't have write permissions to the restore file...")
				exit(1)
			end
		else
			debug("Restore file is not present. Not deleting anything")
		end
	end
	
	def update_timer()
		@countdown_timer = @target_timer - Time.new.to_i
		
		if(@countdown_timer < 0)
			@countdown_timer = 0
		end
		
		if(@countdown_timer > BLUE_ICON_RANGE)
			self.set_icon(@indicator_icons[1])
		elsif(@countdown_timer > ORANGE_ICON_RANGE)
			self.set_icon(@indicator_icons[2])
		elsif(@countdown_timer > 0)
			self.set_icon(@indicator_icons[3])
		else
			self.set_icon(@indicator_icons[0])
		end
	end
	
	def start_timer(caller_menuitem)
		#We will display a window where the user can set the timer
		#or choose to get the parameters from the config file.
		
		start_window = Gtk::Window.new()
		start_window.set_border_width(10)
		
		start_from_config_btn = Gtk::Button.new("Get from config file")
		start_from_config_btn.signal_connect("clicked"){
			#Read the configuration file and set the parameters
			self.read_config()

			debug("VALUES: ")
			debug('Enable notify: '+@enable_notify.to_s)
			debug('Notify delay: '+@notify_delay.to_s)
			debug('Initial timer: '+@countdown_timer.to_s)
			debug('Persistent timer: '+@persistent_timer.to_s)

			debug("Setting timer:")

			#Set the timer
			self.set_timer()

			#Timeout function that will update the indicator
			GLib::Timeout.add(1000){
				self.update_timer()
	
				self.set_label("Time left: "+@countdown_timer.to_s+" seconds", "CountdownI")
	
				true
			}
		
			@is_running = true
			
			start_window.destroy()
			
			#The menuitem from the indicator is now inactive
			caller_menuitem.set_sensitive(false)
		}
		
		start_window.add(start_from_config_btn)
		
		start_window.show_all
	end
	
	def quit_timer()
		#If we didn't start the timer yet, we don't need to bother with the restore file
		if(@is_running == true)
			#If the time is up, we are in the persistent mode and there is a restore file, remove it...
			if(CountdownI.instance_variable_get("@persistent_timer") && CountdownI.instance_variable_get("@countdown_timer")<=0)
				CountdownI.remove_restore_file()
			end
		end
		
		Gtk.main_quit()
	end
end

# Program flow

Gtk.init()

#Create the indicator object
CountdownI = CountdownI_Class.new("CountdownI", File.realpath("./Icons/IconBlack.png"), AppIndicator::Category::APPLICATION_STATUS)

Gtk.main()

#!/usr/bin/ruby

require 'ruby-libappindicator'

# Small debugging function
DEBUG = true
def debug(message)
  if DEBUG == true
    puts 'DEBUG: ' + message
  end
end

# CLASSES DESIGN
#
# Classes:
#   1) Indicator Class
#     Will hold all the methods and attributes regarding the indicator
#     itself and the submenus from the indicator.
#   2) Configuration Class
#     Will contain methods to open and parse the configuration file, and
#     also save the current configurations to it.
#     Will contain methods and attributes regarding the settings from the
#     countdown app.
#   3) Timer Class
#     Will contain the attributes and methods that will be responsable
#     for keeping track of the countdown timer.

class Indicator < AppIndicator::AppIndicator
  # There are 4 icon colors: Blue, Orange, Red and Black.
  # | BLUE |{RANGE1}| ORANGE  |{RANGE2}| RED  |{0}| BLACK
  # Icon will be blue when the time left is over RANGE1, orange when
  # the time left is between RANGE1 and RANGE2, red when the time left
  # is between RANGE2 and 0 and black when the time is up.
  ICON_RANGE1 = 600
  ICON_RANGE2 = 300

  def initialize(name, icon, category)
    # Original AppIndicator initialization
    super
    
    # Initialization of variables
    # Create a configuration object
    @config = Configuration.new
    
    # Create a timer object
    @timer = Timer.new(@config)
    
    # Bulk setup
    setup
  end
  
  def setup
    # Read the configuration file and set values
    @config.read
    
    # Set the timer object
    @timer.set
    
    # Set the indicator itself
    set_indicator
    
    # Set the timeout function
    GLib::Timeout.add(1000){
      update
    }
    
    if @config.notify?
      GLib::Timeout.add(@config.notifydelay*1000){
        send_notify
      }
    end
  end
  
  # Set the AppIndicator with a "Quit" button
  def set_indicator    
    indicatormenu = Gtk::Menu.new
    
    indicatormenu_quit = Gtk::MenuItem.new("Quit")
    indicatormenu_quit.signal_connect("activate"){
      quit_timer
    }
    indicatormenu.append(indicatormenu_quit)
    indicatormenu_quit.show
    
    set_menu(indicatormenu)
    set_status(AppIndicator::Status::ACTIVE)
  end
  
  # Will return the real path of each Icon to an array on first call.
  # On all subsequent calls it will return the array contents.
  def self.indicator_icons
    @indicator_icons ||= [
        File.realpath("./Icons/IconBlack.png"),
        File.realpath("./Icons/IconBlue.png"),
        File.realpath("./Icons/IconOrange.png"),
        File.realpath("./Icons/IconRed.png")
    ]
  end
  
  def send_notify
    if @timer.timeleft > ICON_RANGE1
      Kernel::system("notify-send --icon='"+Indicator.indicator_icons[1]+"' 'CountdownI: "+@timer.timeleft.to_s+" seconds left!'")
    elsif @timer.timeleft > ICON_RANGE2
      Kernel::system("notify-send --icon='"+Indicator.indicator_icons[2]+"' 'CountdownI: "+@timer.timeleft.to_s+" seconds left!'")
    elsif @timer.timeleft > 0
      Kernel::system("notify-send --icon='"+Indicator.indicator_icons[3]+"' 'CountdownI: "+@timer.timeleft.to_s+" seconds left!'")
    end
    
    if @timer.timeleft > 0
      true
    else
      false
    end
  end
  
  def update
    @timer.update
    
    if @timer.timeleft > ICON_RANGE1
      set_icon(Indicator.indicator_icons[1])
    elsif @timer.timeleft > ICON_RANGE2
      set_icon(Indicator.indicator_icons[2])
    elsif @timer.timeleft > 0
      set_icon(Indicator.indicator_icons[3])
    else
      set_icon(Indicator.indicator_icons[0])
    end
    
    set_label('Time left: ' + @timer.timeleft.to_s + ' seconds', 'CountdownI')
    
    if @timer.timeleft > 0
      true
    else
      Kernel::system("notify-send --icon='"+Indicator.indicator_icons[0]+"' 'CountdownI: Time is up!'")
      false
    end
  end
  
  def quit_timer
    if @config.persistent?
      if @timer.timeleft <= 0
        @timer.remove_restore_file
      end
    end
    
    Gtk::main_quit
  end
end

class Configuration
  @enablenotify
  @persistenttimer
  
  attr_reader :initialtimer
  attr_reader :notifydelay
  
  def initialize
    debug("Initializing Config")
  end
  
  def notify?
    @enablenotify
  end
  
  def persistent?
    @persistenttimer
  end
  
  # Set the default values
  def set_default
    @enablenotify = true
    @persistenttimer = false
    @initialtimer = 30
    @notifydelay = 300
  end
  
  # Check the values
  def check_values
    # Check the values and use default ones if anything is odd:
    if(@notifydelay < 60 || @notifydelay > 1200)
      @notifydelay = 300
    end
    if @initialtimer <= 0
      @initialtimer = 30
    end
  end
  
  # Read the configuration files and set the variables accordingly
  def read
    debug("Reading Configuration File!")
    #Checks if configuration file exists and if it's readable. If it doesn't exist, write one with default
    #values. If it does exist but isn't readable, leave it there and use default values. Else, just use the
    #values from the file.
	if(File.exists?(File.realpath("./Config")+"/CountdownI.config") && File.readable?(File.realpath("./Config/CountdownI.config")))
      debug("Config file exists and is readable!")
      debug("Reading:")
      config_file = File.open(File.realpath("./Config/CountdownI.config"),"r")

      while line = config_file.gets
        if(!line.start_with?("//") && line.chomp.length>0)
          param_value_list = line.split("=")
          debug("Parameter: #{param_value_list[0]} - Value: #{param_value_list[1]}")

          case param_value_list[0]
            when "NOTIFY DELAY"
              @notifydelay = param_value_list[1].to_i
            when "ENABLE NOTIFY"
              if(param_value_list[1].chomp == "TRUE")
                @enablenotify = true
              else
                @enablenotify = false
              end
            when "INITIAL TIMER"
              @initialtimer = param_value_list[1].to_i
            when "PERSISTENT TIMER"
              if(param_value_list[1].chomp == "TRUE")
                @persistenttimer = true
              else
                @persistenttimer = false
              end
          end
        end
      end
      
      config_file.close
      
      # Check the values and use default ones if anything is odd
      check_values
    else
      debug("Can't read configuration file. Using default values...")
      
      # Set default values
      set_default
    end
  end
end

class Timer  
  attr_accessor :targettimer
  attr_accessor :timeleft
  
  def initialize(config)
    debug('Initializing Timer')
    @config = config
  end
  
  def set
    debug('Current epoch time: = '+Time.new.strftime('%s'))
    
    # If timer is persistent, look for file
    if @config.persistent?
      debug('Persistent timer is On')
      
      if File.exists?(File.realpath('./')+'/countdown.restore')
        if File.readable?(File.realpath('./')+'/countdown.restore')
          debug('Restoring timer from restore file')
          
          restore_file = File.open(File.realpath('./countdown.restore'), 'r')
          
          while line = restore_file.gets
            @targettimer = line.to_i
          end
          
          @timeleft = @targettimer - Time.new.to_i
          
          debug('Target timer: ' + @targettimer.to_s)
          debug('Time left: ' + @timeleft.to_s)
          
          restore_file.close
        else
          puts "[ERROR]: You don't have the permissions to read the restore file..."
          exit(1)
        end
      else
        debug('Restore file not present')
        
        @targettimer = Time.new.to_i + @config.initialtimer
        @timeleft = @config.initialtimer
        
        write_restore_file
      end
    else
      debug('Persistent timer is off')

      @targettimer = Time.new.to_i + @config.initialtimer
      @timeleft = @config.initialtimer
    end
  end
  
  def write_restore_file
    debug('Writing restore file:')
    
    if File.exists?(File.realpath('./')+'/countdown.restore')
      debug('Restore file exists already')
      if File.writable?(File.realpath('./')+'/countdown.restore')
        debug('Restore file is writable')

        restore_file = File.open(File.realpath('./countdown.restore'), 'w')

        restore_file.write(@targettimer.to_s)

        restore_file.close
      else
        #This error shouldn't happen if the user didn't play around with chmod/chown...
        puts "[ERROR]: You don't have permissions to write to the restore file..."
        exit 1
      end
    else
      debug("Restore file doesn't exist. Writing it...")

      restore_file = File.open(File.realpath('./')+'/countdown.restore', 'w')

      restore_file.write(@targettimer.to_s)

      restore_file.close
    end
  end
  
  def remove_restore_file
    debug("Removing restore file:")
    if File.exists?(File.realpath("./")+"/countdown.restore")
      debug("Restore file is present")
      if File.writable?(File.realpath("./")+"/countdown.restore")
        debug("Restore file is writable, so probably deletable too")
        debug("Deleting restore file...")

        File.delete(File.realpath("./countdown.restore"))
      else
        #This error shouldn't happen if the user didn't play around with chmod/chown...
        puts "[ERROR]: You don't have write permissions to the restore file..."
        exit 1
      end
    else
      debug("Restore file is not present. Not deleting anything")
    end
  end
  
  def update
    @timeleft = @targettimer - Time.new.to_i
    
    if @timeleft < 0
      @timeleft = 0
    end
  end
end

# MAIN FLOW

Gtk.init

CountdownI = Indicator.new("CountdownI", Indicator.indicator_icons[0], AppIndicator::Category::APPLICATION_STATUS)

Gtk.main

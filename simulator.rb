=begin
 start_app launch the simulator with an application
  arguments
    required
      app_path            # Path to iOS .app bundle
    options
      :iphone or :ipad      # Select device family, default is :iphone
      :retina               # Run retina simulator. default is not :retina
      :tall                 # 4-inch iphone (implies :retina) (Does nothing together with :ipad). default is not :tall
      :sdk => "x.y"         # Select sdk version. You must have the selected sdk installed in your `xcode-select --print-path`. default is latest sdk

  Example
    sim = Simulator.new
    sim.terminate          # Make sure no instances are already running (sim needs to be restarted when selecting locale)
    sim.locale = sim.available_locales.last                 # Select a locale
    sim.start_app APP_PATH, :ipad, :retina, :sdk => "6.1"   # Start iPad Retina simulator running iOS 6.1
    sim.rotate_right       # Put simulator in landscape mode
    sleep 15               # Need to wait a bit for simulator to start, install the app bundle, and start the app
    sim.save_screenshot "screenshot.png"     # Save a screenshot
    sim.terminate
=end
class Simulator
  # Find some paths
  LOCAL_PATH = File.split(__FILE__).first
  PNGPASTE_PATH = File.expand_path(File.join(LOCAL_PATH, 'bin', 'pngpaste', 'pngpaste'))
  
  # Helper class to interface with osx defaults. There might be a better way.
  class Defaults
    def initialize(domain)
      @domain = domain
    end
  
    class DefaultsError < RuntimeError; end
  
    def get key
      ArgumentError.new key unless key and key.length != 0
      cmd = "defaults read #{@domain} #{key}"
      proc = IO.popen(cmd)
      output = proc.read.strip
      proc.close
      raise DefaultsError.new("#{$?}: #{cmd}") if $?.to_i != 0
      output
    end
  
    def set key, value
      args = value
      case value
      when Array
        args = "-array #{value.join(" ")}"
      when String
        args = "-string #{value}"
      else
        raise RuntimeError.new("Don't know how to transform #{value.class}")
      end
      cmd = "defaults write #{@domain} #{key} #{args}"
      raise RuntimeError.new("failed #{cmd}") unless system(cmd)
    end
  end
  
  # Wraps ios-sim
  class IOSSim
    # Available args and defaults:
    # :app => nil [just start simulator] # Path to app to start
    # :retina => false
    # :tall => false
    # :family => 'iPhone'
    # :sdk => nil  [latest]      # or string version number, example "6.1" or "7.0"
    # :wait => true              # Will block until simulator is closed
    # :args => ['list', 'of']    # Array of strings to pass to the simulator
    IOS_SIM_PATH = File.expand_path(File.join(LOCAL_PATH, 'bin', 'ios-sim', 'ios-sim'))
    def launch opts = {}
      args = [IOS_SIM_PATH]
      args << 'start' unless opts[:app]
      args << 'launch' if opts[:app]
      args << opts[:app] if opts[:app]
      args << '--retina' if opts[:retina] || opts[:tall]
      args << '--tall' if opts[:tall]
      args << ["--family", "#{opts[:family]}"] if opts[:family]
      args << ["--sdk", opts[:sdk]] if opts[:sdk]
      args << '--exit' unless opts[:wait]
      args << (['--args'] << opts[:args]) if opts[:args]
      args << {:err=>[:child, :out]}
      args.flatten!
      @proc = IO.popen(args)
      if opts[:wait]
        puts @proc.read 
        @proc.close
        raise "error executing #{args}" if $?.exitstatus != 0
      end
    end
    
    def exec args
      terminate
      sk = ["/usr/local/bin/ios-sim", *args, :err=>[:child, :out]]
      @proc = IO.popen(sk)
      @proc.read
      @proc.close
    end
    
    def terminate
      Process.kill("KILL", @proc.pid) if @proc
      @proc = nil
    end

    DESC = /Simulator - /i
    SDK = /\t.+\.sdk/i
    def available_sdks
      sdks = {}
      last_line = nil
      exec("showsdks").each_line.map do |line|
        case line
        when DESC
          last_line = line.strip
        when SDK
          sdks[last_line] = line.strip
        end
      end
      sdks
    end
  end
  
  def simulator_defaults
    @simulator_defaults ||= Defaults.new("com.apple.iphonesimulator")
  end
  
  def simulator_preferences
    @simulator_preferences ||= Defaults.new(plist_path)
  end
  
  def plist_path
    currentSDKRoot = simulator_defaults.get "currentSDKRoot"
    match = currentSDKRoot.match(/iPhoneSimulator.platform\/Developer\/SDKs\/iPhoneSimulator(.+).sdk/)
    raise "Did not find current sdk" unless match
    version = match.to_a.last
    "~/Library/Application\\ Support/iPhone\\ Simulator/#{version}/Library/Preferences/.GlobalPreferences.plist"
  end
  
  def sim
    @sim ||= IOSSim.new
  end
  
  class AppNotFound < RuntimeError; end
  def start_app app_path, *args
    raise AppNotFound.new(app_path) unless File.exists?(app_path)
    opts = args.select { |arg| arg.is_a?(Hash) }.first or {}
    flags = {}
    flags[:family] = 'ipad' if args.include? :ipad
    flags[:retina] = args.include? :retina
    flags[:tall] = args.include? :tall
    flags[:wait] = args.include? :wait
    flags[:app] = app_path
    flags.update(opts) if opts
    sim.launch flags
  end
  
  class LocaleNotFound < RuntimeError; end
  
  def locale
    available_locales.first
  end
  
  def locale= lang
    s = available_locales
    # raise LocaleNotFound.new("'#{lang}' not found in #{s}") unless s.include?(lang)
    $stderr.puts "Warning: '#{lang}' not found in original list of locales #{s}"
    s.delete(lang)
    s.insert(0, lang)
    langs = s.map { |e| e.index("-") ? "\"#{e}\"" : e }
    simulator_preferences.set "AppleLanguages", langs
  end
  
  def available_locales
    simulator_preferences.get("AppleLanguages").split(",").map do |l|
      l.gsub(/[()\n"']/, '').strip
    end
  end
  
  def terminate
    sim.terminate
    `killall 'iPhone Simulator'`
  end
  
  def _applescript code
    proc = IO.popen('osascript', 'r+')
    proc.puts code
    proc.close_write
    proc.close
    $?.exitstatus
  end
  
  def save_snapshot filepath
    path, name = File.split(filepath)
    puts "Saving snapshot to #{File.join(path, name)}"
    
    _applescript 'tell application "System Events"
      tell process "iOS Simulator"
        tell menu bar 1
          tell menu bar item "Edit"
            tell menu "Edit"
              click menu item "Copy Screen"
            end tell
          end tell
        end tell
      end tell
    end tell'
    
    system("mkdir -p '#{path}'")
    sleep 0.5 # chill a bit for snap to complete
    system("'#{PNGPASTE_PATH}' '#{filepath}'")
  end
  
  alias_method :save_screenshot, :save_snapshot
end

class Simulator # Add some useful scripts
  def rotate_left
    _applescript 'tell application "System Events"
      tell process "iOS Simulator"
        tell menu bar 1
          tell menu bar item "Hardware"
            tell menu "Hardware"
              click menu item "Rotate Left"
            end tell
          end tell
        end tell
      end tell
    end tell'
  end

  def rotate_right
    _applescript 'tell application "System Events"
      tell process "iOS Simulator"
        tell menu bar 1
          tell menu bar item "Hardware"
            tell menu "Hardware"
              click menu item "Rotate Right"
            end tell
          end tell
        end tell
      end tell
    end tell'
  end
  
  def shake
    _applescript 'tell application "System Events"
      tell process "iOS Simulator"
        tell menu bar 1
          tell menu bar item "Hardware"
            tell menu "Hardware"
              click menu item "Shake Gesture"
            end tell
          end tell
        end tell
      end tell
    end tell'
  end
end
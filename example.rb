require './simulator'
require './nuremote'


def startNu
  NuRemote::BlockingClient.new('localhost')
end

def startSimulator
  arguments = [:iphone, :tall, :retina, :sdk => "6.1"]
  
  app_path = "SomeAwesome.app"
  app_path = File.expand_path("~/Documents/Spotify/Code/iphoneRelease/DerivedData/Spotify+features/Build/Products/Debug-iphonesimulator/Spotify.app")
  sim = Simulator.new
  sim.start_app app_path, *arguments
  sim
end


sim = startSimulator
# Wait a while for simulator, and app, to start
sleep 15
# Connecto to the nu remote
nu = startNu
# Set application in required state
nu.nu("(((UIApplication sharedApplication) delegate) getReadyForScreenshotNumber:1)")
# Save a screenshot
sim.save_screenshot "./screenshot.png"
# Close the simulator
sim.terminate
require './simulator'
require './nuremote'

app_path = "SomeAwesome.app"
app_path = File.expand_path("~/Documents/Spotify/Code/iphoneRelease/DerivedData/Spotify+features/Build/Products/Debug-iphonesimulator/Spotify.app")
sim = Simulator.new
# Set a locale
sim.locale = sim.available_locales.last
# Select simulator options
sim_arguments = [:iphone, :tall, :retina, :sdk => "6.1"]
# Start an application
sim.start_app app_path, *sim_arguments
# Wait a while for simulator, and app, to start
sleep 15
# Connecto to the nu remote
nu = NuRemote::BlockingClient.new('localhost')
# Set application in required state
nu.nu("(((UIApplication sharedApplication) delegate) getReadyForScreenshotNumber:1)")
# Save a screenshot
sim.save_screenshot "./screenshot.png"
# Stop the nu client
nu.close
# Close the simulator
sim.terminate
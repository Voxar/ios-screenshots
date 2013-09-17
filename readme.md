What
====
This is a collection of tools that might help you automate taking screenshots for your iOS application

Check top of each script for more info.

example.rb
----------
Short example of how you might use simulator.rb and nuremote.rb

simulator.rb
------------
Wraps bin/ios-sim that is used to boot the simulator. 
Also features a few apple scripts to interact with the simulator, and to save a screenshot.

nuremote.rb
-----------
Super simple client for the [Nu Remoting](https://github.com/nevyn/NuRemoting) tool which lets you interface with your app in a simple scripted way through a TCP socket.

Follow the instructions in the readme at [the Nu Remoting github page](https://github.com/nevyn/NuRemoting) to add it to your app. 


More snippets
-------------
To crop the status bar from your screenshots you can use the following [ImageMagic](http://www.imagemagick.org) for retina screenshots (20 instead of 40 for non-retina)

    $ convert 'source.png' -crop -0+40 -gravity South 'target.png'"
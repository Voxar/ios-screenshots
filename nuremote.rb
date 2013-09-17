=begin

This is a simple module to communicate with the iOS NuRemoter

Only basic protocol support so far

Just a simple blocking client that expects exactly one response for exactly one command

Example: 
  client = NuRemote::Client.new("localhost")
  client.send("(set main [[[UIApplication sharedApplication] delegate] description])")
  response = client.receive
  # or 
  response = client.nu("(set main [[[UIApplication sharedApplication] delegate] description])")
  puts "#{response.code} #{response.status}: #{response.body}"

=end


require 'socket'
Thread.abort_on_exception=true

module NuRemote
  PORT = 8023
  TIMEOUT = 10
  
  class BlockingClient
    class ConnectionError < RuntimeError; end
    
    def initialize(host, port = PORT)
      @terminator = "\n\n"
      @socket = TCPSocket.new(host, port)
      r, w, e = IO.select(nil, [@socket], [@socket], TIMEOUT)
      raise ConnectionError.new("Error connecting to nu server") if e.length > 0
    end
    
    def write text
      @socket.write(text)
    end
    
    def send text
      write(text + @terminator)
    end
    
    def _receive_packet
      # Read a whole packet
      buffer = ""
      begin
        data = @socket.recv(1024)
        buffer << data
      rescue
        # Fake returned error
        buffer = "1000 InternalError\t\n\n"
      end while !buffer.end_with?(@terminator)
      buffer
    end
    
    # Returns array [code, status, output]
    def _parse_packet packet
      header, body = packet.split("\t", 2)
      code, status = header.split(' ')
      [code.to_i, status, body.strip]
    end
    
    def close
      @socket.close
    end
    
    # Returns hash of [:code => Number, :status => String, :body => String]
    def receive
      Hash[[:code, :status, :body].zip(_parse_packet(_receive_packet))]
    end
    
    def nu code
      send(code)
      receive
    end
  end
end
#!/usr/bin/ruby

require 'optparse'
require 'socket'

class TCPMUXC
    attr_accessor :bind_port, :host, :port

    def initialize(bind_port, host, port, cmd)
        @bind_port = bind_port
        @host      = host
        @port      = port
        @cmd       = cmd
    end

    def transfer(src, dst)
        return Thread.start {
            loop {
                data = src.recv(8192)

                if data.empty?
                    src.shutdown
                    dst.shutdown
                    break
                end

                dst.send(data, 0)
            }
        }
    end

    def biditransfer(s1, s2)
        [ transfer(s1, s2),
          transfer(s2, s1) ].each { |thread| thread.join }
    end

    def handle(client)
        remote = TCPSocket.open(@host, @port)
        remote.puts(@cmd)
        response = remote.gets

		if response[0] == '-' then
			raise response.rstrip
		end

		biditransfer(client, remote) unless client == nil
    end

    def run
		# test service
		handle(nil)

        server = TCPServer.open(@bind_port)

        loop {
            Thread.start(server.accept) do |client|
                handle(client)
            end
        }
    end
end

def run_main
	options = {}

	optparse = OptionParser.new do |opts|
		opts.banner = "Usage: tcpmxc.rb [options] bind host cmd"

		opts.on('-h', '--help', 'Display this screen') do
			puts opts
			exit
		end

		options[:port] = 1
		opts.on('-p', '--port PORT', "tcpmuxd port (default: #{options[:port]})") do |port|
			options[:port] = port
		end

	end

	optparse.parse!

	if ARGV.length == 3 then
		bind = ARGV[0]
		host = ARGV[1]
		cmd  = ARGV[2]
	else
		puts optparse.help
		exit
	end

	tcpmxc = TCPMUXC.new(bind, host, options[:port], cmd)
	tcpmxc.run
end

run_main

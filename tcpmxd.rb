#!/usr/bin/ruby

require 'optparse'
require 'socket'

class TCPMXD
    attr_accessor :host, :port, :cmds

    def initialize(host, port, services)
        @cmds = { 'help'  => {:type => :internal, :object => self, :method => :help} }.update(services)
        @host = host
        @port = port
        @server = TCPServer.open(@port)
    end

    def help(client)
        @cmds.keys.each do |cmd|
            client.puts(cmd)
        end
    end

    def transfer(src, dst, line=false)
        return Thread.start {
            loop {
                data = src.recv(8192)

                if data.empty? then
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

    def forward(client, host, port)
        remote = TCPSocket.open(host, port)
        biditransfer(client, remote)
    end

    def handle(client)
        cmd = client.gets(32)

        if @cmds.keys.include?(cmd.rstrip) then
            m = @cmds[cmd.rstrip]
            client.puts("+OK")

            case m[:type]
                when :internal
                    m[:object].send(m[:method], client)
                when :forward
                    forward(client, m[:host], m[:port])
            end
        else
            client.puts("-ERR: No such service")
        end

        client.close
    end

    def run
        loop {
            Thread.start(@server.accept) do |client|
                handle(client)
            end
        }
    end
end


def run_main
	options = {}

	optparse = OptionParser.new do |opts|
		opts.banner = "Usage: tcpmxd.rb [options] bind port cmd"

		opts.on('-h', '--help', 'Display this screen') do
			puts opts
			exit
		end

		options[:config] = '/etc/tcpmxd.cf'
		opts.on('-c', '--config FILE', "read config from FILE (default: #{options[:config]})") do |file|
			options[:config] = file
		end

		options[:bind] = '0.0.0.0'
		opts.on('-b', '--bind HOST', "tcpmuxd bind address (default: #{options[:bind]})") do |host|
			options[:bind] = host
		end

		options[:port] = 1
		opts.on('-p', '--port PORT', "tcpmuxd port (default: #{options[:port]})") do |port|
			options[:port] = port
		end

		options[:daemon] = false
		opts.on('-d', '--daemon', "daemonize process") do
			options[:daemon] = true
		end

	end

	optparse.parse!

    load options[:config]

	if ARGV.length != 0 then
		puts optparse.help
		exit
	end

    tcpmxd = TCPMXD.new(options[:bind], options[:port], TCPMXDConf::Services)

    pid = fork do
        tcpmxd.run
    end

    if options[:daemon] then
        Process.detach(pid)
    else
        Process.wait(pid)
    end
end

run_main

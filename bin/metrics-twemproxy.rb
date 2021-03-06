#! /usr/bin/env ruby
#
#   twemproxy-metrics
#
# DESCRIPTION:
#   This plugin gets the stats data provided by twemproxy
#   and sends it to graphite.
#
# OUTPUT:
#   metric data
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: json
#   gem: socket
#
# USAGE:
#  #YELLOW
#
# NOTES:
#
# LICENSE:
#   Copyright 2014 Toni Reina <areina0@gmail.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.

require 'sensu-plugin/metric/cli'
require 'socket'
require 'timeout'
require 'json'

#
# Twemproxy metrics
#
class Twemproxy2Graphite < Sensu::Plugin::Metric::CLI::Graphite
  SKIP_ROOT_KEYS = %w(service source version uptime timestamp).freeze

  option :host,
         description: 'Twemproxy stats host to connect to',
         short: '-h HOST',
         long: '--host HOST',
         required: false,
         default: '127.0.0.1'

  option :port,
         description: 'Twemproxy stats port to connect to',
         short: '-p PORT',
         long: '--port PORT',
         required: false,
         proc: proc(&:to_i),
         default: 22_222

  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         required: false,
         default: "#{Socket.gethostname}.twemproxy"

  option :timeout,
         description: 'Timeout in seconds to complete the operation',
         short: '-t SECONDS',
         long: '--timeout SECONDS',
         required: false,
         proc: proc(&:to_i),
         default: 5

  def run
    Timeout.timeout(config[:timeout]) do
      sock = TCPSocket.new(config[:host], config[:port])
      data = JSON.parse(sock.read)
      pools = data.keys - SKIP_ROOT_KEYS

      pools.each do |pool_key|
        if not data[pool_key].is_a?(Hash)
          output "#{config[:scheme]}.#{pool_key}", data[pool_key]
          next
        end
        data[pool_key].each do |key, value|
          if value.is_a?(Hash)
            value.each do |key_server, value_server|
              mangled_key = key.gsub ".", "_"
              output "#{config[:scheme]}.#{mangled_key}.#{key_server}", value_server
            end
          else
            output "#{config[:scheme]}.#{key}", value
          end
        end
      end
    end
    ok
  rescue Timeout::Error
    warning 'Connection timed out'
  rescue Errno::ECONNREFUSED
    warning "Can't connect to #{config[:host]}:#{config[:port]}"
  end
end

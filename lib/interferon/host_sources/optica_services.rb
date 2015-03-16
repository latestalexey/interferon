require 'net/http'
require 'json'
require 'set'

module Interferon::HostSources
  class OpticaServices
    include Logging

    def initialize(options)
      raise ArgumentError, "missing host for optica source" \
        unless options['host']

      @host = options['host']
      @port = options['port'] || 80
      @envs = options['environments'] || []
    end

    def list_hosts
      con = Net::HTTP.new(@host, @port)
      con.read_timeout = 60
      con.open_timeout = 60

      response = con.get('/')
      data = JSON::parse(response.body)

      services = Hash.new{ |h,service| h[service] = {
          :source => 'optica_services',
          :service => service,

          :owners => [],
          :owner_groups => [],
          :consumer_roles => Set.new,
          :consumer_machine_count => 0,
          :provider_machine_count => 0,
        }}

      data['nodes'].each do |ip, host|
        next unless @envs.empty? or @envs.include?(host['environment'])

        # make it easier by initializing possibly-missing data to sane defaults
        host['ownership'] ||= {}
        host['nerve_services'] ||= []
        host['synapse_services'] ||= []

        # provider info
        host['nerve_services'].each do |service|
          services[service][:provider_machine_count] += 1

          services[service][:owners].concat(host['ownership']['people'] || [])
          services[service][:owner_groups].concat(host['ownership']['groups'] || [])
        end

        # consumer info
        host['synapse_services'].each do |service|
          services[service][:consumer_roles].add(host['role'])
          services[service][:consumer_machine_count] += 1
        end
      end

      # convert all sets to arrays
      services.each do |k,v|
        services[k][:consumer_roles] = v[:consumer_roles].to_a
      end

      return services.values
    end
  end
end

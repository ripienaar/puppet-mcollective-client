Puppet::Parser::Functions::newfunction(:get_fact, :type => :rvalue) do |vals|
  require 'mcollective'
  require 'mcollective/orchestrate'

  agent = "rpcutil"
  fact = nil
  filter = {}

  if vals.size == 2
    raise("Fact names must be strings") unless vals[0].is_a?(String)
    raise("Filters must be a hash") unless vals[1].is_a?(Hash)

    fact = vals[0]
    filter = vals[1]
  else
    raise("Need to supply fact name and filter when retrieving a fact")
  end

  discovered = MCollective::Orchestrate::Discover.new(agent, filter)
  node = discovered.nodes.first

  raise("Did not find any nodes matching filter") if discovered.size == 0
  raise("Found more than 1 node matching filter, cannot continue") unless discovered.size == 1

  reply = MCollective::Orchestrate::Mco.rpc agent, :get_fact, :stdout => StringIO.new do
    @arguments = {:fact => fact}

    discovered.limit @client
  end

  raise("Did not receive any results from %s" % node) if reply[:stats].responses == 0

  fact_value = reply[:results].first

  raise("Could not retrieve fact %s from %s: %s" % [fact, node, fact_value[:statusmsg]]) unless reply[:stats].failcount == 0

  fact_value[:data][:value]
end

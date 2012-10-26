Puppet::Parser::Functions::newfunction(:get_fact, :type => :rvalue) do |vals|
  require 'mcollective'

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

  options = {:verbose      => false,
             :config       => MCollective::Util.config_file_for_user,
             :progress_bar => false,
             :filter       => MCollective::Util.empty_filter}

  client = MCollective::RPC::Client.new(agent, :configfile => options[:config], :options => options)

  if filter["compound_filter"]
    raise "Compound filters must be strings" unless resource[:compound_filter].is_a?(String)
    client.compound_filter(filter[:compound_filter])
  end

  Array(filter["identity_filter"]).each {|f| client.identity_filter f}
  Array(filter["class_filter"]).each {|f| client.class_filter f}
  Array(filter["fact_filter"]).each {|f| client.fact_filter f}

  raise("Did not find any nodes matching filter") if client.discover.size == 0
  raise("Found more than 1 node matching filter, cannot continue") unless client.discover.size == 1

  results = client.get_fact(:fact => fact)

  raise("Did not receive any results from %s" % client.discover.first) if results.empty?

  results.first[:data][:value]
end



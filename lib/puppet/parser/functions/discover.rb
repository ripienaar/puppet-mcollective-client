Puppet::Parser::Functions::newfunction(:discover, :type => :rvalue) do |vals|
  require 'mcollective'
  require 'mcollective/orchestrate'

  agent = "rpcutil"
  filter = {}

  if vals.size > 0
    if vals[0].is_a?(String)
      agent = vals[0]

      filter = vals[1] if vals[1].is_a?(Hash)
    else
      filter = vals[0]
    end
  end

  MCollective::Orchestrate::Discover.new(agent, filter).nodes
end


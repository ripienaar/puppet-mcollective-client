require 'mcollective'
require 'mcollective/orchestrate'

o = MCollective::Orchestrate.new(:app_cluster_upgrade)

begin
  o.application.orchestrate
rescue => e
  puts "Could not complete orchestration: %s" % MCollective::Util.colorize(:red, e)
end

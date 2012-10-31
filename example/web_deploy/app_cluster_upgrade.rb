def orchestrate
  # makes sure all the needed agents exist before starting
  requires :agents => [:rpcutil, :haproxy, :appmgr, :angelianotify, :nrpe]

  ask("Backend Name", :backend)
  ask("App Revision", :revision)
  ask("Cluster Name", :cluster)

  validate(@backend, :string)
  validate(@revision, :string)
  validate(@cluster, :string)

  announce("Updating cluster %s" % @cluster)

  load_balancer = discover(:class => "haproxy", :when_empty => "No load balancers found")
  servers = discover(:appmgr, :fact => "cluster=#{@cluster}", :when_empty => "No web servers found")

  msg = "%s updated %d node cluster %s to revision %s" % [ENV["USER"], servers.size, @cluster, @revision]

  load_balancer.ping
  servers.ping

  app_update(@cluster, @backend, @revision, servers, load_balancer)

  #Angelia.sendmsg("boxcar://rip@devco.net", msg)

  announce(msg)
end

def app_update(cluster, backend, revision, servers, load_balancer)
  Haproxy.disable servers, backend do
    load_balancer.limit @client
  end

  Mco.rpc :appmgr, :upgrade do
    @arguments = {:revision => revision}

    @tries = 2

    servers.limit @client

    @verbose = true
    @client.batch_size = 2
  end

  Nrpe.runcommand :check_load do
    @tries = 10

    servers.limit @client
  end

  Haproxy.enable servers, backend do
    load_balancer.limit @client
  end

  Mco.rpc :appmgr, :status do
    @post_actions = :summarize

    servers.limit @client
  end
end

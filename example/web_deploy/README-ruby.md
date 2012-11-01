Code Walkthrough
================

The full script can be seen in the file [app_cluster_upgrade.rb.](https://github.com/ripienaar/puppet-mcollective/blob/master/example/web_deploy/app_cluster_upgrade.rb).  This is a
fairly complex example specifically to demonstrate a complexity that you might
find in the real world.  It interacts with 5 different agents and various
different nodes in parallel.

The end goal is to have an orchestration script that you can run like this:

    $ puppet orchestrate app_cluster_upgrade backend=app cluster=alfa revision=10 --ruby

Here the backend is the HAProxy backend name that is the front for this web app

We'll step through the code next, it's best to have the script open next to the
walkthrough for clarity.

The orchestration system will call the *orchestrate* method to start the process,
this is a standard Ruby method and you can call any methods or objects etc.

    def orchestrate
      # makes sure all the needed agents exist before starting
      requires :agents => [:rpcutil, :haproxy, :appmgr, :angelianotify, :nrpe]

We wouldn't want the orchestration run to fail half way through because a agent
is not installed properly so we validate the agents upfraont, this just checks
that the DDL files are installed on the client.


      ask("Backend Name", :backend)
      ask("App Revision", :revision)
      ask("Cluster Name", :cluster)

      validate(@backend, /\A[a-z]+\Z/)
      validate(@revision, /\A\d+\Z/)
      validate(@cluster, /\A[a-z]+\Z/)

      announce("Updating cluster %s" % @cluster)

Now we ask for the input, the script will check if any input was provided on the
command line, if not it will prompt the user to type in an answer. Any answer either
provided on the CLI or when prompted gets saved in variables *@backend* etc.

Validation on input is done using the standard MCollective validation subsystem
if you have any validation plugins you can use those for example *validate(@x, :string)*

We give an informative message to the console for the user using the *announce()*
method, it really just prints the string given clearly.

We don't yet know what machines we are upgrading or what the load balancer is
and we certainly don't want to hard code this so we use mcollective discovery
to find these:

      load_balancer = discover(:class => "haproxy", :when_empty => "No load balancers found")
      load_balancer.ping

      servers = discover(:appmgr, :fact => "cluster=#{@cluster}", :when_empty => "No web servers found")
      servers.ping

First we're finding machine with the *haproxy* class installed and then we are
finding machines that have the *appmgr* agent and that belong to the cluster
provided on the CLI.  In both cases if no nodes around found the error supplied
in *:when_empty* will be raised.

We do a *rpcutil#ping* to the discovered nodes which ensures each node is alive
on the MCollective network.

MCollective can now do discovery against data caches, databases, flatfiles etc
so you are not guaranteed to only speak to machines that are up.  This is ideal
for deployers since you typically want to address a set of pre-known hosts
rather than rely on network discovery.

In a real world you will no doubt want to add more filters here or whatever, you
need to be sure to only hit the load balancers actually hosting this app.  There
are a few options here including writing a data plugin that returns the list of
apps hosted.  The right way will depend heavily on your environment.

We're ready to do the update now, the update process has been written in seperate
method which we'll cover in detail in a bit:

      app_update(@cluster, @backend, @revision, servers, load_balancer)

We're simply passing in the user supplied input and the discovered nodes into the
method.

Once the deploy is done we send the iPhone push message and show a message on the
console:

      msg = "%s updated %d node cluster %s to revision %s" % [ENV["USER"], servers.size, @cluster, @revision]
      Angelia.sendmsg("boxcar://rip@devco.net", msg)
      announce(msg)
    end

So that's the basic flow with few details of the actual updating, so lets take a
look at the *app_update* method:

    def app_update(cluster, backend, revision, servers, load_balancer)
      Haproxy.disable servers, backend do
        load_balancer.limit @client
      end

After the normal method creation step we call to the HAproxy agent and disable
the webservers.  Here we're using a helper - *Haproxy.disable* - that just takes
the list of webservers and backend as arguments.

We use the discovered *load_balancer* as source of truth for this RPC request
using its limit helper.

      Mco.rpc :appmgr, :upgrade do
        @arguments = {:revision => revision}
        servers.limit @client

        @client.batch_size = 2
        @tries = 2
        @verbose = true
      end

Here we communicate with the *appmgr#upgrade* action passing to it the revision
we were supplied.  We limit the deploy to just the web nodes we discovered earlier.
We supply a batch size of 2 and we allow the deploy to be retried once if the
first failed for whatever reason.  Your upgrade process must be idempotent for
this to work.  Here the *@client* variable is a standard *MCollective::RPC::Client*
object that you would usually create using *rpcclient()*

      Nrpe.runcommand :check_load do
        @tries = 10

        servers.limit @client
      end

With the upgrade complete we call to *nrpe#runcommand* to check the load average
on all the HTTP servers.  We allow this to retry 10 times - the default sleep
between tries is 10 seconds.  This gives the load average 100 seconds to recover
back to normal levels after the deploy.

      Haproxy.enable servers, backend do
        load_balancer.limit @client
      end

This is the reverse of the previous Haproxy call, we're just enabling the machines
on the load balancer

      Mco.rpc :appmgr, :status do
        @post_actions = :summarize

        servers.limit @client
      end
    end

Finally we just call the *appmgr#status* action to show the revision that was
deployed.  Setting the *@post_actions* to *:summarize* means any aggregate data
declared in the DDL will be displayed here.

Output
======

When run against cluster *bravo* this is the output you might see:

    $ puppet orchestrate app_cluster_upgrade backend=app cluster=bravo revision=20
    Loading script example/web_deploy/app_cluster_upgrade.rb

    >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    >>>>>>>>> Updating cluster bravo
    >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

    >>>>>>>>> calling haproxy#disable for 1 node(s)
    >>>>>>>>> done haproxy#disable [discovered=1 responses=1 failcount=0 okcount=1 totaltime=0.043374 batch=0]
    >>>>>>>>> calling appmgr#upgrade for 4 node(s)
       ...... processing result from dev3.devco.net [OK]
       ...... processing result from dev9.devco.net [OK]
       ...... processing result from dev5.devco.net [OK]
       ...... processing result from dev7.devco.net [OK]
    >>>>>>>>> done appmgr#upgrade [discovered=4 responses=4 failcount=0 okcount=4 totaltime=2.167856 batch=2]
    >>>>>>>>> calling nrpe#runcommand for 4 node(s)
    >>>>>>>>> done nrpe#runcommand [discovered=4 responses=4 failcount=0 okcount=4 totaltime=0.220746 batch=0]
    >>>>>>>>> calling haproxy#enable for 1 node(s)
    >>>>>>>>> done haproxy#enable [discovered=1 responses=1 failcount=0 okcount=1 totaltime=0.149378 batch=0]
    >>>>>>>>> calling appmgr#status for 4 node(s)

    Summary of Revision:

       Revision 3: 4 nodes

    >>>>>>>>> done appmgr#status [discovered=4 responses=4 failcount=0 okcount=4 totaltime=0.091924 batch=0]

    >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    >>>>>>>>> rip updated 4 node cluster bravo to revision 3
    >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>


Audit Logs
==========

Of course the whole process is subject to the MCollective AAA model.  Based on the logs you can see the deploy took just 3 seconds.

Audit log from a webserver:

    reqid=f765badda50053d29025b28094342ecf: reqtime=1351372442 caller=cert=rip@devco.net agent=rpcutil action=ping data={:process_results=>true}
    reqid=494894202ec05c1a8f7db09405ecc6fe: reqtime=1351372443 caller=cert=rip@devco.net agent=appmgr action=upgrade data={:revision=>20}
    reqid=9be5fb39c9bc5cd8a1ce7b9707ee5deb: reqtime=1351372445 caller=cert=rip@devco.net agent=nrpe action=runcommand data={:process_results=>true, :command=>"check_load"}
    reqid=68b329da9893e34099c7d8ad5cb9c940: reqtime=1351372445 caller=cert=rip@devco.net agent=appmgr action=upgrade data={:process_results=>true}


Audit log from the load balanccer:

    reqid=65b60fad17a55505b08f22f857774b59: reqtime=1351372442 caller=cert=rip@devco.net agent=rpcutil action=ping data={:process_results=>true}
    reqid=7356037b6ae6537c8e9c73c7ce858ca5: reqtime=1351372442 caller=cert=rip@devco.net agent=haproxy action=disable data={:process_results=>true, :server=>"dev4.devco.net,dev8.devco.net,dev2.devco.net,dev6.devco.net,dev10.devco.net", :backend=>"app"}
    reqid=6e5a2a861d715654a9d168be7db4723d: reqtime=1351372445 caller=cert=rip@devco.net agent=haproxy action=enable data={:process_results=>true, :server=>"dev4.devco.net,dev8.devco.net,dev2.devco.net,dev6.devco.net,dev10.devco.net", :backend=>"app"}

Audit log from the notification server:

    reqid=e0b25f064e645aef9567f82ec92266f3: reqtime=1351372445 caller=cert=rip@devco.net agent=angelianotify action=sendmsg data={:process_results=>true, :recipient=>"boxcar://rip@devco.net", :message=>"rip updated 4 node cluster bravo to revision 20", :subject=>"puppet orchestration"}


Overview
========

This is a demonstration of a hypothetical web application spread over 9 web
server nodes fronted by a HAProxy load balancer.  There are 2 servers providing
the *angelia* service via an agent and we use the MCollective HA facilities to
redundantly access one of these for notification.

In order to help with management of the estate a fact called *cluster* has been
added and the nodes have been broken in to 2 sets - clusters *alfa* and *bravo*.

The orchestration script uses the *rpcutil*, *haproxy*, *appmgr*, *nrpe* and
*angelia* mcollective Agents combining them all into a single deployment script.

The script is written using the Puppet DSL and takes advantage of the
relationship system between resources, ordering, classes, facts and defines to
create a real time multi node orchestration script.

![Web App Overview](https://raw.github.com/ripienaar/puppet-mcollective/master/example/web_deploy/web_deploy.jpg)

We will follow a playbook for upgrading the web app, for the sake of
demonstration we will update the stack one cluster at a time.  The orchestration
steps will have to be re-run once per cluster.

The playbook is written to update all the nodes in the cluster at the same time
in a parallel manner.  Alternative approaches updating the nodes 1 at a time
could also be taken but this demonstrates how the to take advantage of the
parallel nature of mcollective, my deployment step is very minimal but the
entire process completes in 3 seconds including any discovery delays etc.

The steps in our play book are as follows:

  1. Determine the list of load balancer(s)
  1. Determine the list of webservers in the given cluster
  1. Using the *rpcutil* agent check the list of webservers and load balancers are all responding, you'd typically use a discovery cache for this use case so this step validates the nodes you intended to deploy to were all available.
  1. Using the *haproxy* agent set the webservers all in maintenance mode
  1. Using the *appmgr* agent update the web application to the desired revision. Do this in batches of 2 nodes to manage load on databases
  1. Using the *nrpe* agent check the load average, keep checking it for up to 100 seconds allowing it to settle post deploy
  1. Using the *haproxy* agent enable the webservers
  1. Using the *angelia* agent notify the administrator using iPhone push

If any step in this process fails the dependant steps will not complete.
Specifically if any of the intermediate steps fail like a node fails to upgrade
or the monitoring check never reaches an OK state the machine will not be
enabled for traffic leaving the administrator to investigate the cause.

For best effect all these agents are written idempotently so that once the issue
has been resolved the orchestration can just be run again.

Code Walkthrough
================

The full script can be seen in the file [app_cluster_upgrade.mc.](app_cluster_upgrade.mc.).  This is a
fairly complex example specifically to demonstrate a complexity that you might
find in the real world.  It interacts with 5 different agents and various
different nodes in parallel.

It's pretty simple if you know Puppet, please review the script and then look
through the detailed description below.

The end goal is to have an orchestration script that you can run like this:

    $ puppet orchestrate app_cluster_upgrade backend=app cluster=alfa revision=10

Here the backend is the HAProxy backend name that is the front for this web app

We'll step through the code next, it's best to have the script open next to the
walkthrough for clarity.

First we validate the input is all given, we use some functions from
*puppetlabs-stdlib* for this.


    if empty($backend) { fail('Please specify a backend to manage using $backend') }
    if empty($revision) { fail('Please specify a revision to manage using $revision') }
    if empty($cluster) { fail('Please specify a cluster to manage using $cluster') }

We don't yet know what machines we are upgrading or what the load balancer is
and we certainly don't want to hard code this so we use mcollective discovery
to find these:

    $load_balancer = discover({"class" => haproxy})
    $servers = discover(appmgr, {fact => "cluster=${cluster}"})

    if empty($load_balancer) { fail("Could not find any loadbalancers to manage") }
    if empty($servers) { fail("Could not find any servers to manage") }

First we're finding machine with the *haproxy* class installed and then we are
finding machines that have the *appmgr* agent and that belong to the cluster
provided on the CLI.

In a real world you will no doubt want to add more filters here or whatever, you
need to be sure to only hit the load balancers actually hosting this app.  There
are a few options here including writing a data plugin that returns the list of
apps hosted.  The right way will depend heavily on your environment.

We'll later display some messages and notify an iPhone so we'll just prepare the
status message and such now:

    $server_count = size($servers)
    $msg = "${id} updated ${server_count} node cluster ${cluster} to revision ${revision}"

We now have all the data we need and we can start the actual update process.  We
have a defined type called *app::update* that we'll cover later - for now we're
just using this define and two others:


    app::update{$cluster:
      backend       => $backend,
      revision      => $revision,
      load_balancer => $load_balancer,
      nodes         => $servers
    } ->

    angelia{$cluster:
      msg           => $msg,
      recipient     => "boxcar://rip@devco.net"
    } ->

    mco::say{"done":
      msg => $msg
    }

So here we first update the cluster, then notify the Boxcar on my iPhone and
finally show some text on the console to indicate we're done.

The arrows is called *chaining* in Puppet and denotes both ordering and
dependencies.  It means if something goes wrong in the update stage no messages
will be send and so forth.

So that's the basic flow with few details of the actual updating, so lets take a
look at the *app::update* define:


      define app::update($backend, $revision, $nodes, $load_balancer) {
        if is_string($nodes) {
          $workers = [$nodes]
        } elsif is_array($nodes) {
          $workers = $nodes
        } else {
          fail("Don't know how to deploy to nodes: ${nodes}")
        }

So this is your basic define pre-amble, the various types we will call needs
nodes to be an array so we're just setting that up and doing some simple data
validation here.

        mco::ping{"${name}-lb": identity_filter => $load_balancer} ->
        mco::ping{"${name}-workers": identity_filter => $nodes} ->

Next we're going to do a normal *rpcutil#ping* specifically specifying our
desired nodes as identities.  This has the effect of doing a quick round trip
test to be sure mcollective is able to communicate with these node.

MCollective can now do discovery against data caches, databases, flatfiles etc
so you are not guaranteed to only speak to machines that are up.  This is ideal
for deployers since you know typically want to address a set of pre-known hosts
rather than rely on network discovery.


      haproxy::disable{$name:
        server          => join($workers, ","),
        backend         => $backend,
        identity_filter => $load_balancer
      } ->

Next we pass our list of HTTP servers as a comma separated list to the
*haproxy#disable* action which will use the HAProxy Socket API to disable the
nodes.  If any node cannot be disabled this action fails.


      mcollective{"update_${name}":
        agent           => appmgr,
        action          => upgrade,
        arguments       => {revision => $revision},
        identity_filter => $workers,
        tries           => 2,
        batch_size      => 2
      } ->

Here we communicate with the *appmgr#upgrade* action passing to it the revision
we were passed.  We limit the deploy to just the nodes we discovered earlier.
We supply a batch size of 2 and we allow the deploy to be retried once if the
first failed for whatever reason.  Your upgrade process must be idempotent for
this to work.


      nrpe::runcommand{"check_load":
        tries           => 10,
        identity_filter => $workers
      } ->

With the upgrade complete we call to *nrpe#runcommand* to check the load average
on all the HTTP servers.  We allow this to retry 10 times - the default sleep
between tries is 10 seconds.  This gives the load average to recover back to
normal levels within 100 seconds of the deploy.


      haproxy::enable{$name:
        server          => join($workers, ","),
        backend         => $backend,
        identity_filter => $load_balancer
      }
    }

And finally should that pass we are ready to enable the web servers again in the
load balancer via the *haproxy#enable* action that also take a comma separated
list of workers.

Output
======

When run against cluster *bravo* this is the output you might see:

    $ puppet orchestrate app_cluster_upgrade backend=app cluster=bravo revision=20
    /Stage[main]//Update_multiple[bravo]/Mc::Ping[bravo]/Mcollective[ping_bravo]/agent: rpcutil#ping executed succesfully on 4 nodes after 1 try
    /Stage[main]//Update_multiple[bravo]/Haproxy::Disable[bravo]/Mcollective[haproxy::disable::app/bravo]/agent: haproxy#disable executed succesfully on 1 node after 1 try
    /Stage[main]//Update_multiple[bravo]/Mcollective[update_bravo]/agent: appmgr#upgrade executed succesfully on 4 nodes after 1 try
    /Stage[main]//Update_multiple[bravo]/Nrpe::Runcommand[check_load]/Mcollective[nrpe_check_load]/agent: nrpe#runcommand executed succesfully on 4 nodes after 1 try
    /Stage[main]//Update_multiple[bravo]/Haproxy::Enable[bravo]/Mcollective[haproxy::enable::app/bravo]/agent: haproxy#enable executed succesfully on 1 node after 1 try
    /Stage[main]//Angelia[rip updated 4 node cluster bravo to revision 20]/Mcollective[angelia_notify_rip updated 4 node cluster bravo to revision 20]/agent: angelianotify#sendmsg executed succesfully on 1 node after 1 try
    /Stage[main]//Mc::Say[done]/Exec[done]/returns:  _________________________________________________
    /Stage[main]//Mc::Say[done]/Exec[done]/returns: < rip updated 4 node cluster bravo to revision 20 >
    /Stage[main]//Mc::Say[done]/Exec[done]/returns:  -------------------------------------------------
    /Stage[main]//Mc::Say[done]/Exec[done]/returns:        \   ,__,
    /Stage[main]//Mc::Say[done]/Exec[done]/returns:         \  (oo)____
    /Stage[main]//Mc::Say[done]/Exec[done]/returns:            (__)    )\
    /Stage[main]//Mc::Say[done]/Exec[done]/returns:               ||--|| *
    /Stage[main]//Mc::Say[done]/Exec[done]/returns: executed successfully
    Finished catalog run in 2.10 seconds

Audit Logs
==========

Of course the whole process is subject to the MCollective AAA model.  Based on the logs you can see the deploy took just 3 seconds.

Audit log from a webserver:

    reqid=f765badda50053d29025b28094342ecf: reqtime=1351372442 caller=cert=rip@devco.net agent=rpcutil action=ping data={:process_results=>true}
    reqid=494894202ec05c1a8f7db09405ecc6fe: reqtime=1351372443 caller=cert=rip@devco.net agent=appmgr action=upgrade data={:revision=>20}
    reqid=9be5fb39c9bc5cd8a1ce7b9707ee5deb: reqtime=1351372445 caller=cert=rip@devco.net agent=nrpe action=runcommand data={:process_results=>true, :command=>"check_load"}


Audit log from the load balanccer:

    reqid=65b60fad17a55505b08f22f857774b59: reqtime=1351372442 caller=cert=rip@devco.net agent=rpcutil action=ping data={:process_results=>true}
    reqid=7356037b6ae6537c8e9c73c7ce858ca5: reqtime=1351372442 caller=cert=rip@devco.net agent=haproxy action=disable data={:process_results=>true, :server=>"dev4.devco.net,dev8.devco.net,dev2.devco.net,dev6.devco.net,dev10.devco.net", :backend=>"app"}
    reqid=6e5a2a861d715654a9d168be7db4723d: reqtime=1351372445 caller=cert=rip@devco.net agent=haproxy action=enable data={:process_results=>true, :server=>"dev4.devco.net,dev8.devco.net,dev2.devco.net,dev6.devco.net,dev10.devco.net", :backend=>"app"}

Audit log from the notification server:

    reqid=e0b25f064e645aef9567f82ec92266f3: reqtime=1351372445 caller=cert=rip@devco.net agent=angelianotify action=sendmsg data={:process_results=>true, :recipient=>"boxcar://rip@devco.net", :message=>"rip updated 4 node cluster bravo to revision 20", :subject=>"puppet orchestration"}


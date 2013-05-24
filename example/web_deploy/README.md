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

For best effect all these agents are written idempotently so that once the issue
has been resolved the orchestration can just be run again.

Two example orchestration scripts are provided one written using the Puppet
DSL and one using the Ruby DSL.  Both scripts have the same end result and
both scripts demonstrate how to interact with multiple different agents in
one script.

Ruby DSL vs Puppet DSL
======================

The main difference between the 2 DSLs is how you can interact with the data.

The Puppet DSL behaves like any Puppet DSL. It gets compiled and turned into a
catalog and then the catalog gets applied.  You do not have any ability to inspect
or branch based on the data returned from the MCollective RPC calls.  It's a
pure fire and forget style script with no user interaction and a boolean pass
or fail result.

In the Ruby DSL you have access to all the data and stats and can do any kind of
branching or logic based on that.

See the files [README-ruby.md](https://github.com/ripienaar/puppet-mcollective/blob/master/example/web_deploy/README-ruby.md) and [README-puppet.md](https://github.com/ripienaar/puppet-mcollective/blob/master/example/web_deploy/README-puppet.md) for a walkthrough of the two different orchestration scripts.

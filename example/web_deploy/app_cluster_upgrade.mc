# validate the input....
if empty($backend) { fail('Please specify a backend to manage using $backend') }
if empty($revision) { fail('Please specify a revision to manage using $revision') }
if empty($cluster) { fail('Please specify a cluster to manage using $cluster') }

# find a load balancer and list of worker nodes
$load_balancer = discover({"class" => haproxy})
$servers = discover(appmgr, {fact => "cluster=${cluster}"})

if empty($load_balancer) { fail("Could not find any loadbalancers to manage") }
if empty($servers) { fail("Could not find any servers to manage") }

$server_count = size($servers)
$msg = "${id} updated ${server_count} node cluster ${cluster} to revision ${revision}"

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

# Given an array or nodes, a revision, a list of nodes to update and
# a load balancer that fronts the nodes this will:
#
#   - disable all the nodes on the load balancer
#   - update them to a new revision in a 2 per batch series
#   - make sure their load average is ok for up to 100 seconds
#   - enable all the nodes in the load balancer
define app::update($backend, $revision, $nodes, $load_balancer) {
  if is_string($nodes) {
    $workers = [$nodes]
  } elsif is_array($nodes) {
    $workers = $nodes
  } else {
    fail("Don't know how to deploy to nodes: ${nodes}")
  }

  # makes sure they are all up, cached discovery
  mco::ping{"${name}-lb": identity_filter => $load_balancer} ->
  mco::ping{"${name}-workers": identity_filter => $nodes} ->

  haproxy::disable{$name:
    server          => join($workers, ","),
    backend         => $backend,
    identity_filter => $load_balancer
  } ->

  mcollective{"update_${name}":
    agent           => appmgr,
    action          => upgrade,
    arguments       => {revision => $revision},
    identity_filter => $workers,
    tries           => 2,
    batch_size      => 2
  } ->

  nrpe::runcommand{"check_load":
    tries           => 10,
    identity_filter => $workers
  } ->

  haproxy::enable{$name:
    server          => join($workers, ","),
    backend         => $backend,
    identity_filter => $load_balancer
  }
}


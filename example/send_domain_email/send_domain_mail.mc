# mcollective orchestration script that takes a recipient domain
# checks if there are any severs on the network with mail for
# that domain and then forces a delivery attempt on all the mail
# in all the mailqueue on all servers

if ($recipient == undef) { fail('Please specify a recipient domain with $recipient') }

# count how many machines have email for the recipient domain using the domain_mailq()
# data plugin from the eximng plugin, this returns a list of host names with mail
# for the recipient domain in their mail queues
$relays = discover(eximng, {compound => "exim::mailrelay and domain_mailq('${recipient}').size > 0"})
$relay_count = size($relays)

if empty($relays) { fail("There is no mail for '${recipient}' in the mail queue") }

mco::say{"start": msg => "Attempting to deiver mail for domain '${recipient}' from ${relay_count} mail relays"} ->

# use the eximng agent delivermatching action to deliver
# on the nodes discovered earlier
exim::delivermatching{$recipient: identity_filter => $relays}

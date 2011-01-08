#!/usr/bin/env puppet
#
# This example shows how the refreshonly mechanism works. 
#
# In this example we provide a changeable resource (a file) with a notify
# relationship with an mcollective service restart call that has the
# refreshonly parameter defined as 'true'.
#
# Using the Time.now content you can see how the file on change triggers
# as expected, and changing the content to something static (like foo) will 
# mean nothing happens.
# 
file {"/tmp/foo1":
#  content => "foo",
  content => inline_template("<%= Time.now %>"),
  notify => Mcollective["test1"],
}
mcollective {"test1":
  agent => "service",
  action => "restart",
  arguments => {
    "service" => "rsyslog",
  },
  identity_filter => ["puppet1"],
  disctimeout => 3,
  timeout => 10,
  refreshonly => true,
}

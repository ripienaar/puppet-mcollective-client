What?
=====

A prototype that lets you create a series of related and dependant jobs using the Puppet syntax, graph, dependencies, defines, classes and other syntax.

The idea is to be able to specify a number of related RPC jobs in a file and run them using Puppet Apply

Example:
========

<pre>
# Deploys a package using mcollective
define deploy_package($fact_filter = "", $identity_filter="", $fact_filter="", $class_filter="") {
    mcollective{"deploy_package_${name}":
        agent           => "package",
        action          => "update",
        fact_filter     => $fact_filter,
        identity_filter => $identity_filter,
        class_filter    => $class_filter,
        arguments       => {"package" => $name},
    }
}

# Restart a service using mcollective
define restart_service($fact_filter = "", $identity_filter="", $fact_filter="", $class_filter="") {
    mcollective{"restart_service_${name}":
        agent           => "service",
        action          => "restart",
        fact_filter     => $fact_filter,
        identity_filter => $identity_filter,
        class_filter    => $class_filter,
        arguments       => {"service" => $name},
    }
}

# Notify using the Angelia notification service, only 1 message get sent when
# multiple Angelia systems are on the same network
define angelia($recipient, $subject) {
    mcollective{"angelia_notify_${name}":
        agent           => "angelianotify",
        action          => "sendmsg",
        arguments       => {"message" => $name, "recipient" => $recipient, "subject" => $subject},
        limit_nodes     => 1,
    }
}

class packages {
    deploy_package{["zsh", "httpd", "php"]: class_filter => "/dev_server/"}
}

include packages

# Deploy the package over all dev servers,
# restart the webservers on the dev servers,
# notifies the admin via Angelia hosted on other servers
# and finally use a native puppet exec to give visual feedback
Class["packages"] ->
restart_service{"httpd": class_filter => "/dev_server/"} ->
angelia{"hello world": subject => "test", recipient => "xmpp://ripienaar@jabber.org"}  ~>
exec{"done":
    command     => "/usr/bin/cowsay 'finished spammning!'",
    logoutput   => true,
    refreshonly => true,
    require     => Restart_service["httpd"]
}
</pre>


Sample output:
==============

<pre>
$ puppet deploy.pp
notice: /Stage[main]/Packages/Deploy_package[php]/Mcollective[deploy_package_php]/ensure: created
notice: /Stage[main]/Packages/Deploy_package[httpd]/Mcollective[deploy_package_httpd]/ensure: created
notice: /Stage[main]/Packages/Deploy_package[zsh]/Mcollective[deploy_package_zsh]/ensure: created
notice: /Stage[main]//Restart_service[httpd]/Mcollective[restart_service_httpd]/ensure: created
notice: /Stage[main]//Angelia[hello world]/Mcollective[angelia_notify_hello world]/ensure: created
notice: /Stage[main]//Exec[done]/returns:  _____________________
notice: /Stage[main]//Exec[done]/returns: &lt; finished spammning! &gt;
notice: /Stage[main]//Exec[done]/returns:  ---------------------
notice: /Stage[main]//Exec[done]/returns:         \   ^__^
notice: /Stage[main]//Exec[done]/returns:          \  (oo)\_______
notice: /Stage[main]//Exec[done]/returns:             (__)\       )\/\
notice: /Stage[main]//Exec[done]/returns:                 ||----w |
notice: /Stage[main]//Exec[done]/returns:                 ||     ||
notice: /Stage[main]//Exec[done]: Triggered 'refresh' from 1 events
</pre>

Or when run verbosely

<pre>
info: Applying configuration version '1293210366'
info: Mcollective[deploy_package_httpd](provider=mcollective): Result from dev1.domain1.net: OK
info: Mcollective[deploy_package_httpd](provider=mcollective): Result from dev1.domain2.net: OK
info: Mcollective[deploy_package_httpd](provider=mcollective): Result from dev2.domain1.net: OK
info: Mcollective[deploy_package_httpd](provider=mcollective): Result from dev3.domain1.net: OK
notice: /Stage[main]/Packages/Deploy_package[httpd]/Mcollective[deploy_package_httpd]/ensure: created
info: Mcollective[deploy_package_zsh](provider=mcollective): Result from dev2.domain1.net: OK
info: Mcollective[deploy_package_zsh](provider=mcollective): Result from dev1.domain2.net: OK
info: Mcollective[deploy_package_zsh](provider=mcollective): Result from dev1.domain1.net: OK
info: Mcollective[deploy_package_zsh](provider=mcollective): Result from dev3.domain1.net: OK
notice: /Stage[main]/Packages/Deploy_package[zsh]/Mcollective[deploy_package_zsh]/ensure: created
info: Mcollective[deploy_package_php](provider=mcollective): Result from dev2.domain1.net: OK
info: Mcollective[deploy_package_php](provider=mcollective): Result from dev1.domain2.net: OK
info: Mcollective[deploy_package_php](provider=mcollective): Result from dev1.domain1.net: OK
info: Mcollective[deploy_package_php](provider=mcollective): Result from dev3.domain1.net: OK
notice: /Stage[main]/Packages/Deploy_package[php]/Mcollective[deploy_package_php]/ensure: created
info: Mcollective[restart_service_httpd](provider=mcollective): Result from dev2.domain1.net: OK
info: Mcollective[restart_service_httpd](provider=mcollective): Result from dev1.domain1.net: OK
info: Mcollective[restart_service_httpd](provider=mcollective): Result from dev3.domain1.net: OK
info: Mcollective[restart_service_httpd](provider=mcollective): Result from dev1.domain2.net: OK
notice: /Stage[main]//Restart_service[httpd]/Mcollective[restart_service_httpd]/ensure: created
info: Mcollective[angelia_notify_hello world](provider=mcollective): Result from monitor1.domain1.net: OK
notice: /Stage[main]//Angelia[hello world]/Mcollective[angelia_notify_hello world]/ensure: created
info: /Stage[main]//Angelia[hello world]/Mcollective[angelia_notify_hello world]: Scheduling refresh of Exec[done]
notice: /Stage[main]//Exec[done]/returns:  _____________________
notice: /Stage[main]//Exec[done]/returns: &lt; finished spammning! &gt;
notice: /Stage[main]//Exec[done]/returns:  ---------------------
notice: /Stage[main]//Exec[done]/returns:         \   ^__^
notice: /Stage[main]//Exec[done]/returns:          \  (oo)\_______
notice: /Stage[main]//Exec[done]/returns:             (__)\       )\/\
notice: /Stage[main]//Exec[done]/returns:                 ||----w |
notice: /Stage[main]//Exec[done]/returns:                 ||     ||
notice: /Stage[main]//Exec[done]: Triggered 'refresh' from 1 events

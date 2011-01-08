Puppet::Type.newtype(:mcollective) do
    @doc = "Create Marionette Collective RPC jobs from Puppet"

    ensurable

    newparam(:name) do
        desc "A name for this job"

        isnamevar
    end

    newparam(:config) do
        desc "Configuration file to use"

        defaultto "/etc/mcollective/client.cfg"
    end

    newparam(:ensure) do
        defaultto "present"
    end

    newparam(:class_filter) do
        desc "The Class filter for the request"

        defaultto false
    end

    newparam(:identity_filter) do
        desc "The Identity filter for the request"

        defaultto false
    end

    newparam(:fact_filter) do
        desc "The Fact filter for the request"

        defaultto false
    end

    newparam(:agent) do
        desc "The agent to call"
    end

    newparam(:action) do
        desc "The action to call"
    end

    newparam(:arguments) do
        desc "The arguments to send to the action"

        defaultto {}
    end

    newparam(:limit_nodes) do
        desc "Limits the nodes we'll interact with to a subset of discovered nodes"

        defaultto false
    end

    newparam(:disctimeout) do
        desc "Timeout for doing discovery in seconds."

        defaultto 2
    end

    newparam(:timeout) do
        desc "Timeout for calling remote agents."

        defaultto 5
    end

    validate do
        self.fail "Agent name is required" unless self[:agent]
        self.fail "Action name is required" unless self[:action]
    end
end

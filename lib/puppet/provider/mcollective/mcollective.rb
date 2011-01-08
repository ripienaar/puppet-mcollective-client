require 'mcollective'

Puppet::Type.type(:mcollective).provide :mcollective do
    include MCollective::RPC

    desc "MCollective Provider"

    commands :mcrpc => "mc-rpc"

    def create
        # Create options and supply them to the client
        # this prevents it from parsing command line
        # arguments etc
        options = {:verbose    => false,
                   :timeout    => resource[:timeout].to_f,
                   :disctimeout=> resource[:disctimeout].to_f,
                   :config     => resource[:config],
                   :filter     => MCollective::Util.empty_filter}

        client = rpcclient(resource[:agent], {:options => options})
        client.progress = false

        client.limit_targets  = resource[:limit_nodes].to_i if resource[:limit_nodes]

        if resource[:identity_filter]
            resource[:identity_filter].each {|f| client.identity_filter f}
        end

        if resource[:class_filter]
            resource[:class_filter].each {|f| client.class_filter f}
        end

        if resource[:fact_filter]
            if resource[:fact_filter].respond_to?(:each_pair)
                resource[:fact_filter].each_pair {|f,v| client.fact_filter f, v}
            end
        end

        args = {}
        if resource[:arguments].keys.size > 0
            resource[:arguments].each_pair do |k,v|
                args[k.to_sym] = v
            end
        end

        nodes_responded = []

        client.send(resource[:action], args) do |resp|
            begin
                nodes_responded << resp[:senderid]

                info "Result from #{resp[:senderid]}: #{resp[:body][:statusmsg]}"
            rescue Exception => e
                self.fail "Failed to invoke RPC request on #{resp[:senderid]}: #{e.class}: #{e}"
            end
        end

        no_responses = client.discover - nodes_responded

        if resource[:limit_nodes]
            if nodes_responded.size < resource[:limit_nodes].to_i
                self.fail "No response from  #{no_responses.size} node(s)"
            end
        elsif no_responses.size > 0
            self.fail "No responses from #{no_responses.size} node(s)"
        end
    end

    def destroy
    end

    def exists?
        false
    end
end

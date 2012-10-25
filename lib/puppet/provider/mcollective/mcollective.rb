Puppet::Type.type(:mcollective).provide :mcollective do
  desc "MCollective Provider"

  commands :mco => "mco"

  require 'mcollective'

  def call_rpc
    # Create options and supply them to the client
    # this prevents it from parsing command line
    # arguments etc
    options = {:verbose      => false,
               :config       => (resource[:config] || MCollective::Util.config_file_for_user),
               :progress_bar => false,
               :filter       => MCollective::Util.empty_filter}

    client = MCollective::RPC::Client.new(resource[:agent], :configfile => options[:config], :options => options)

    client.limit_targets  = Integer(resource[:limit_nodes]) if resource[:limit_nodes]

    client.batch_size = Integer(resource[:batch_size]) if resource[:batch_size]
    client.batch_sleep_time = Float(resource[:batch_sleep_time]) if resource[:batch_sleep_time]

    if resource[:compound_filter]
      self.fail "Compound filters must be strings" unless resource[:compound_filter].is_a?(String)

      client.compound_filter(resource[:compound_filter])
    end

    if resource[:identity_filter]
      resource[:identity_filter].each {|f| client.identity_filter f}
    end

    if resource[:class_filter]
      resource[:class_filter].each {|f| client.class_filter f}
    end

    if resource[:fact_filter]
      if resource[:fact_filter].respond_to?(:each_pair)
        resource[:fact_filter].each_pair {|f,v| client.fact_filter f, v}
      else
        self.fail "Could not parse fact filter"
      end
    end

    args = {}

    if resource[:arguments] && resource[:arguments].keys.size > 0
      resource[:arguments].each_pair do |k,v|
        args[k.to_sym] = v
      end
    end

    self.fail "Did not discovery any nodes matching criteria" unless client.discover.size > 0

    client.send(resource[:action], args) do |resp|
      begin
        if resp[:body][:statuscode] == 0
          info "Result from %s: %s" % [resp[:senderid], resp[:body][:statusmsg]]
        else
          raise(resp[:body][:statusmsg])
        end
      rescue => e
        self.fail "Failed to invoke RPC request on #{resp[:senderid]}: #{e.class}: #{e}"
      end
    end

    self.fail("No response from %d node(s)" % client.stats.noresponsefrom.size) if client.stats.noresponsefrom.size > 0
  end
end

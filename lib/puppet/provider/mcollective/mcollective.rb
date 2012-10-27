Puppet::Type.type(:mcollective).provide :mcollective do
  desc "MCollective Provider"

  commands :mco => "mco"

  require 'mcollective'

  def setup_client
    # Create options and supply them to the client
    # this prevents it from parsing command line
    # arguments etc
    options = {:verbose      => false,
               :config       => MCollective::Util.config_file_for_user,
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

    Array(resource[:identity_filter]).each {|f| client.identity_filter f}
    Array(resource[:class_filter]).each {|f| client.class_filter f}
    Array(resource[:fact_filter]).each {|f| client.fact_filter f}

    client
  end

  def call_rpc
    client = setup_client

    tries = Integer(resource[:tries])
    try = 0

    (0...tries).each do |try|
      begin
        Puppet.debug("Trying %s#%s, try number %d" % [resource[:agent], resource[:action], try])
        attempt_rpc_call(client)

        break
      rescue => e
        if try < tries - 1
          Puppet.notice("Try %d failed: %s: %s" % [try, e.class, e])
          sleep Integer(resource[:try_sleep_time])
        else
          self.fail("Failed after %d tries: %s" % [try, e])
        end
      end
    end

    Puppet.debug("Completed after %d tries" % try)

    {:tries => try + 1, :nodes => client.stats.responses}
  end

  def attempt_rpc_call(client)
    args = {}

    if resource[:arguments] && resource[:arguments].keys.size > 0
      resource[:arguments].each_pair do |k,v|
        args[k.to_sym] = v
      end

      string_to_ddl_type(args, client.ddl.action_interface(resource[:action]))
    end

    raise "Did not discovery any nodes matching criteria" unless client.discover.size > 0

    client.send(resource[:action], args) do |resp|
      if resp[:body][:statuscode] == 0
        info "Result from %s: %s" % [resp[:senderid], resp[:body][:statusmsg]]
      else
        raise(resp[:body][:statusmsg])
      end
    end

    raise("No response from %d node(s)" % client.stats.noresponsefrom.size) if client.stats.noresponsefrom.size > 0
  end

  def string_to_ddl_type(arguments, ddl)
    return if ddl.empty?

    arguments.keys.each do |key|
      if ddl[:input].keys.include?(key)
        case ddl[:input][key][:type]
          when :boolean
            arguments[key] = MCollective::DDL.string_to_boolean(arguments[key])

          when :number, :integer, :float
            arguments[key] = MCollective::DDL.string_to_number(arguments[key])
        end
      end
    end
  end
end

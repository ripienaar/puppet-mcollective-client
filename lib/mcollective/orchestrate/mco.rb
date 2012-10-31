module MCollective
  class Orchestrate
    class Mco
      attr_accessor :post_actions, :failure_mode, :tries, :arguments, :silent
      attr_accessor :try_sleep_time, :filter
      attr_reader :client, :action, :agent, :options

      # TODO add filtering
      # TODO add some kind of post result validation block
      def initialize(agent, action, options={})
        @agent = agent.to_s
        @action = action.to_s
        @options = options
        @client = Orchestrate.client_factory(agent)

        @post_actions = []
        @failure_mode = :first
        @tries = 1
        @try_sleep_time = 0
        @silent = true
        @arguments = {}
        @filter = {}

        @stdin = options.fetch(:stdin, STDIN)
        @stdout = options.fetch(:stdout, STDOUT)
        @stderr = options.fetch(:stderr, STDERR)
        @stdout.sync = true
        @stderr.sync = true
      end

      def process_filter
        return if @filter.empty?

        raise "Filter must be a hash" unless @filter.is_a?(Hash)

        @filter = Hash[@filter.map{|k, v| [k.to_sym, v]}]

        @filter.keys.each do |key|
          raise "#{key} is not a valid filter" unless [:compound, :identity, :class, :fact, :agent].include?(key)
        end

        if @filter[:compound]
          raise "Compound filters must be strings" unless @filter[:compound].is_a?(String)
          @client.compound_filter(@filter[:compound])
        end

        Array(@filter[:identity]).each {|f| @client.identity_filter f}
        Array(@filter[:class]).each {|f| @client.class_filter f}
        Array(@filter[:fact]).each {|f| @client.fact_filter f}
        Array(@filter[:agent]).each {|f| @client.agent_filter f}
      end

      def to_s
        "%s#%s" % [@agent, @action]
      end

      def perform_post_actions
        if Array(@post_actions).include?(:summarize)
          @stdout.puts
          @stdout.puts @client.stats.text_for_aggregates unless @client.stats.aggregate_summary.empty?
        end
      end

      def call
        args = {}
        results = []

        process_filter

        if @arguments && @arguments.keys.size > 0
          @arguments.each_pair do |k,v|
            args[k.to_sym] = v
          end

          string_to_ddl_type(args, @client.ddl.action_interface(@action.to_s))
        end

        @stdout.puts ">>>>>>>>> calling %s for %s node(s)" % [Util.colorize(:bold, to_s), @client.discover.size]

        try = 0

        (0...@tries).each do |try|
          results.clear

          begin
            @stdout.puts("   ...... trying %s#%s, try number %d" % [Util.colorize(:bold, to_s), try]) unless try == 0

            attempt_rpc_call(args, results)

            break
          rescue => e
            if try < @tries - 1
              @stdout.puts Util.colorize(:yellow, "   ...... try %d failed: %s: %s" % [try, e.class, e])
              sleep @try_sleep_time
            else
              @stdout.puts Util.colorize(:red, "   ...... failed after %d tries" % [try, e])
              raise("Failed after %d tries: %s" % [try, e])
            end
          end
        end

        perform_post_actions

        @stdout.puts ">>>>>>>>> done %s [discovered=%d responses=%d failcount=%d okcount=%d totaltime=%f batch=%d]" % [Util.colorize(:bold, to_s), @client.stats.discovered, @client.stats.responses, @client.stats.failcount, @client.stats.okcount, @client.stats.totaltime, @client.batch_size]

        {:results => results, :stats => @client.stats, :tries => try}
      end

      def attempt_rpc_call(args, results)
        raise "Did not discover any nodes matching criteria" unless @client.discover.size > 0

        @client.method_missing(@action, args) do |reply|
          begin
            rpc_result = RPC::Result.new(@agent, @action, {:sender => reply[:senderid], :statuscode => reply[:body][:statuscode],
                                         :statusmsg => reply[:body][:statusmsg], :data => reply[:body][:data]})

            msg = "   ...... processing result from %s [%s]" % [rpc_result[:sender], rpc_result[:statusmsg]]

            if rpc_result[:statuscode] == 0
              @stdout.puts Util.colorize(:green, msg) if @verbose
            else
              @stdout.puts Util.colorize(:red, msg)
            end

            results << rpc_result

            raise(RPCError, rpc_result[:statusmsg]) if rpc_result[:statuscode] == 1
          rescue
            @stdout.puts Util.colorize(:red, "   ...... failing fast due to %s [%s] result from %s" % [rpc_result[:statuscode], rpc_result[:statusmsg], rpc_result[:sender]])
            raise if @failure_mode == :first
          end
        end

        raise("No response from %d node(s)" % @client.stats.noresponsefrom.size) if @client.stats.noresponsefrom.size > 0
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

      def self.rpc(agent, action, options={}, &blk)
        rpc = Mco.new(agent, action, options)
        rpc.instance_eval(&blk) if block_given?

        rpc.call
      end
    end
  end
end

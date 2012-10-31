module MCollective
  class Orchestrate
    class Application
      def initialize(script, options={})
        @script = script

        @stdin = options.fetch(:stdin, STDIN)
        @stdout = options.fetch(:stdout, STDOUT)
        @stderr = options.fetch(:stderr, STDERR)
        @stdout.sync = true
        @stderr.sync = true

        load_script unless options[:skip_loading]
      end

      def load_script
        if File.exist?(@script)
          puts "Loading script %s" % @script
          instance_eval(File.read(@script), @script, 1)
        else
          raise "Could not find orchestration script %s" % @script
        end
      end

      def orchestrate
        raise("Please provide a orchestrate method")
      end

      def discover(*args)
        agent = :rpcutil
        filter = {}
        options = {}

        if args.size == 1
          raise "The filter must be a hash" unless args[0].is_a?(Hash)
          filter = args[0]
        elsif args.size >= 2
          raise "The agent must be a string or symbol" unless [String, Symbol].include?(args[0].class)
          raise "The filter must be a hash" unless args[1].is_a?(Hash)
          agent = args[0].to_s
          filter = args[1]
        end

        options[:when_empty] = filter.delete(:when_empty)

        Discover.new(agent.to_s, filter, options)
      end

      def ask(question, varname, options={})
        varname = varname.to_s

        raise "Variable names can only be lower case alphanumeric and underscore" unless varname =~ /^[a-z_]+$/

        unless answer = ENV[varname.upcase]
          @stdout.print("%s: " % question)
          answer = @stdin.gets.chomp
        end

        raise("Please supply a value for %s" % varname) if answer == ""

        instance_variable_set("@#{varname}", answer)
      end

      def validate(var, validation)
        Validator.validate(var, validation)
      end

      def requires(requirements)
        requirements.fetch(:agents, []).each do |agent|
          DDL.new(agent.to_s, :agent)
        end
      end

      def announce(msg)
        puts
        puts Util.colorize(:bold, ">" * (msg.size + 11))
        puts Util.colorize(:bold, ">>>>>>>>> %s" % msg)
        puts Util.colorize(:bold, ">" * (msg.size + 11))
        puts
      end
    end
  end
end

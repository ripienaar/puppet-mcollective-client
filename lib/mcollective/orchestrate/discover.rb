module MCollective
  class Orchestrate
    class Discover
      attr_reader :nodes, :client

      def initialize(agent, filter, options={})
        @options = options
        @agent = agent
        @filter = filter
        @nodes = []

        apply_filter

        discover unless options[:skip_discover]
        validate unless options[:skip_validation] || options[:skip_discover]
      end

      def ping
        client = Orchestrate.client_factory("rpcutil")
        client.discover :nodes => @nodes
        client.ping
      end

      def client
        @client ||= Orchestrate.client_factory(@agent)
      end

      def apply_filter
        filter = Hash[@filter.map{|k, v| [k.to_sym, v]}]

        filter.keys.each do |key|
          raise "#{key} is not a valid filter" unless [:compound, :identity, :class, :fact, :agent].include?(key)
        end

        if filter[:compound]
          raise "Compound filters must be strings" unless filter[:compound].is_a?(String)
          client.compound_filter(filter[:compound])
        end

        Array(filter[:identity]).each {|f| client.identity_filter f}
        Array(filter[:class]).each {|f| client.class_filter f}
        Array(filter[:fact]).each {|f| client.fact_filter f}
        Array(filter[:agent]).each {|f| client.agent_filter f}
      end

      def discover
        @nodes = client.discover.clone
      end

      def validate
        if @options[:when_empty]
          raise @options[:when_empty] if @nodes.empty?
        end
      end

      def limit(client)
        client.discover :nodes => @nodes.clone
      end

      def size
        @nodes.size
      end
    end
  end
end

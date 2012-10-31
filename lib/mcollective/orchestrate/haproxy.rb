module MCollective
  class Orchestrate
    class Haproxy
      def self.disable(servers, backend, &blk)
        Mco.rpc(:haproxy, :disable) do
          @arguments = {:server => servers.nodes.join(","),
                        :backend => backend}

          instance_eval(&blk) if block_given?
        end
      end

      def self.enable(servers, backend, &blk)
        Mco.rpc(:haproxy, :enable) do
          @arguments = {:server => servers.nodes.join(","),
                        :backend => backend}

          instance_eval(&blk) if block_given?
        end
      end
    end
  end
end

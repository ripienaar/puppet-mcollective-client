module MCollective
  class Orchestrate
    class Nrpe
      def self.runcommand(command, &blk)
        Mco.rpc(:nrpe, :runcommand) do
          @arguments = {:command => command.to_s}

          instance_eval(&blk) if block_given?
        end
      end
    end
  end
end


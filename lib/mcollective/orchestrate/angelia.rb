module MCollective
  class Orchestrate
    class Angelia
      def self.sendmsg(recipient, msg)
        Mco.rpc(:angelianotify, :sendmsg) do
          @arguments = {:message => msg, :recipient => recipient}

          @client.limit_targets = 1
        end
      end
    end
  end
end


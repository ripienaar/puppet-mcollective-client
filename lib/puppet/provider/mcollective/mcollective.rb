Puppet::Type.type(:mcollective).provide :mcollective do
  desc "MCollective Provider"

  commands :mco => "mco"

  require 'mcollective'
  require 'mcollective/orchestrate'

  def call_rpc
    request = @resource

    result = MCollective::Orchestrate::Mco.rpc request[:agent], request[:action], :stdout => StringIO.new do
      @client.limit_targets = Integer(request[:limit_nodes]) if request[:limit_nodes]
      @client.batch_size = Integer(request[:batch_size]) if request[:batch_size]
      @client.batch_sleep_time = Float(request[:batch_sleep_time]) if request[:batch_sleep_time]

      @filter = {:compound => request[:compound_filter],
                 :identity => request[:identity_filter],
                 :fact => request[:fact_filter],
                 :class => request[:class_filter]}

      @tries = Integer(request[:tries])
      @try_sleep_time = Integer(request[:try_sleep_time])

      @arguments = request[:arguments]

      # TODO
      # post_hook = lambda { .....}
    end

    {:tries => result[:tries], :nodes => result[:stats].responses, :stats => result[:stats]}
  end
end

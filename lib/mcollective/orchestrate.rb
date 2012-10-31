module MCollective
  class Orchestrate
    autoload :Application, "mcollective/orchestrate/application"
    autoload :Discover, "mcollective/orchestrate/discover"
    autoload :Angelia, "mcollective/orchestrate/angelia"
    autoload :Mco, "mcollective/orchestrate/mco"
    autoload :Haproxy, "mcollective/orchestrate/haproxy"
    autoload :Nrpe, "mcollective/orchestrate/nrpe"

    attr_reader :application

    def initialize(orchestration_name, options={})
      Applications.load_config unless options[:skip_config]

      @application = Application.new("%s.mc" % orchestration_name, :skip_loading => true)

      @application.load_script unless options[:skip_loading]
    end

    def self.client_factory(agent)
      options = {:verbose      => false,
                 :config       => Util.config_file_for_user,
                 :progress_bar => false,
                 :filter       => Util.empty_filter}

      client = RPC::Client.new(agent.to_s, :configfile => options[:config], :options => options)
    end
  end
end

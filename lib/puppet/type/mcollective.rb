Puppet::Type.newtype(:mcollective) do
  @doc = "Create Marionette Collective RPC jobs from Puppet"

  # TODO(kb) This is a reimplementation of the exec refreshonly behaviour
  # and is in dire need of a cleanup.

  # Create a new check mechanism.  It's basically just a parameter that
  # provides one extra 'check' method.
  def self.newcheck(name, &block)
    @checks ||= {}

    check = newparam(name, &block)
    @checks[name] = check
  end

  def self.checks
    @checks.keys
  end

  newcheck(:refreshonly) do
    desc "The command should only be run as a refresh mechanism for when a dependent object is changed."
    newvalues(:true, :false)

    # We always fail this test, because we're only supposed to run
    # on refresh.
    def check(value)
      # We have to invert the values.
      if value == :true
        false
      else
        true
      end
    end
  end

  def refresh
    self.debug("test refresh")
    provider.call_rpc
  end

  # Verify that we pass all of the checks.  The argument determines whether
  # we skip the :refreshonly check, which is necessary because we now check
  # within refresh
  def check(refreshing = false)
    self.class.checks.each do |check|
      next if refreshing and check == :refreshonly
      if @parameters.include?(check)
        val = @parameters[check].value
        val = [val] unless val.is_a? Array
        val.each do |value|
          return false unless @parameters[check].check(value)
        end
      end
    end

    true
  end

  # TODO(kb) We are essentially abusing the property system to make
  # something trigger every time like an exec (except of course if
  # refreshonly is used). Need to find a better way to do this.
  newproperty(:agent) do |property|
    desc "The agent to call"

    def change_to_s(currentvalue, newvalue)
      "executed succesfully"
    end

    def retrieve
      if @resource.check
        return :notrun
      else
        return self.should
      end
    end

    def sync
      provider.call_rpc
    end
  end

  newparam(:name) do
    desc "A name for this job"

    isnamevar
  end

  newparam(:config) do
    desc "Configuration file to use"

    defaultto false
  end

  newparam(:compound_filter) do
    desc "The Compound filter for the request"

    defaultto false
  end

  newparam(:class_filter) do
    desc "The Class filter for the request"

    defaultto false
  end

  newparam(:identity_filter) do
    desc "The Identity filter for the request"

    defaultto false
  end

  newparam(:fact_filter) do
    desc "The Fact filter for the request"

    defaultto false
  end

  newparam(:action) do
    desc "The action to call"
  end

  newparam(:arguments) do
    desc "The arguments to send to the action"

    defaultto {}
  end

  newparam(:limit_nodes) do
    desc "Limits the nodes we'll interact with to a subset of discovered nodes"

    defaultto false
  end

  newparam(:disctimeout) do
    desc "Timeout for doing discovery in seconds."

    validate do |val|
      raise ArgumentError, "value must be a number greater than zero." if not @resource.is_pos_float?(val)
    end

    defaultto false
  end

  newparam(:timeout) do
    desc "Timeout for calling remote agents."

    validate do |val|
      raise ArgumentError, "value must be a number greater than zero." if not @resource.is_pos_float?(val)
    end

    defaultto false
  end

  newparam(:tries) do
    desc "Retries the RPC call a number of times, fails only if it never gets a successfull result set"

    validate do |val|
      raise ArgumentError, "value must be a number greater than zero." if not @resource.is_pos_float?(val)
    end

    defaultto 1
  end

  newparam(:try_sleep_time) do
    desc "How long to wait between each attempt to run the action"

    validate do |val|
      raise ArgumentError, "value must be a number greater than zero." if not @resource.is_pos_float?(val)
    end

    defaultto 10
  end

  newparam(:batch_sleep_time) do
    desc "Time to sleep between each batch"

    validate do |val|
      raise ArgumentError, "value must be a number greater than zero." if not @resource.is_pos_float?(val)
    end

    defaultto false
  end

  newparam(:batch_size) do
    desc "Perform the action in batches"

    validate do |val|
      raise ArgumentError, "value must be a number greater than zero." if not @resource.is_pos_float?(val)
    end

    defaultto false
  end

  validate do
    self.fail "Agent name is required" unless self[:agent]
    self.fail "Action name is required" unless self[:action]
  end

  def is_pos_float?(val)
    is_num = begin Float(val) ; true end rescue false
    if (is_num) and (val.to_f > 0) then
      true
    else
      false
    end
  end
end

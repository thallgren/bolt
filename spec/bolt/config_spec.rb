require 'spec_helper'
require 'bolt/config'

describe Bolt::Config do
  let(:config) { Bolt::Config.new }

  describe "when initializing" do
    it "accepts keyword values" do
      config = Bolt::Config.new(concurrency: 200)
      expect(config.concurrency).to eq(200)
    end

    it "uses a default value when none is given" do
      config = Bolt::Config.new
      expect(config.concurrency).to eq(100)
    end

    it "does not use a default value when nil is given" do
      config = Bolt::Config.new(concurrency: nil)
      expect(config.concurrency).to eq(nil)
    end

    it "rejects unknown keys" do
      expect {
        Bolt::Config.new(what: 'why')
      }.to raise_error(NameError)
    end

    it "accepts integers for connection-timeout" do
      config = {
        transports: {
          ssh: { connect_timeout: 42 },
          winrm: { connect_timeout: 999 },
          pcp: {}
        }
      }
      expect {
        Bolt::Config.new(config).validate
      }.not_to raise_error
    end

    it "does not accept values that are not integers" do
      config = {
        transports: {
          ssh: { connect_timeout: '42s' }
        }
      }
      expect {
        Bolt::Config.new(config).validate
      }.to raise_error(Bolt::CLIError)
    end
  end
end

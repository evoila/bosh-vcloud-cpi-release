require 'spec_helper'

module VCloudCloud
  module Steps
    describe SaveAgentEnv do
      let(:env_metadata_key_value) {"env_metadata"}
      let(:meta_data_link_href) {"http://meta_data/link/href"}

      let(:env) do
        env = double("vcloud env")
        env.stub(:inspect) {"env data"}
        env
      end

      let(:save_file) do
        file = double("env save file")
        file.stub(:write) do |data|
          data
        end
      end

      let(:vm) do
        vm = double("vcloud vm")
        vm.stub_chain(:metadata_link, :href) {meta_data_link_href}
        vm.stub(:urn) {"urn:vm:id"}
        vm
      end

      let(:client) do
        client = double("vcloud client")
        client.stub(:logger) { Bosh::Clouds::Config.logger }
        client.stub(:reload) { |arg| arg }
        client
      end


      describe ".perform" do
        let(:none_response) { double("none response") }
        let(:empty_response) { double("empty response") }

        before do
          allow(empty_response).to receive(:readlines).and_return([])
          allow(none_response).to receive(:readlines).and_return([ VCloudCloud::Steps::SaveAgentEnv::NO_ERROR_SHELL_OUTPUT_HACK ])
        end

        it "invokes method successfully" do
          state = {:vm => vm, :env_metadata_key => env_metadata_key_value}

          step = described_class.new state, client
          expect(client).to receive(:reload).once.ordered.with(vm)
          allow(step).to receive(:create_iso_cmd).and_return('myIsoCreationUtil')
          allow(Open3).to receive(:popen3).and_return([nil, empty_response, none_response])

          expect(client).to receive(:invoke_and_wait).once.ordered.with(:put, "#{meta_data_link_href}/#{env_metadata_key_value}", kind_of(Hash))
          expect(client).to receive(:reload).once.ordered.with(vm)

          step.perform
          expect(state[:iso]).to eql "#{state[:tmpdir]}/env.iso"
        end

        it "raises exception due to failed cmd" do
          #setup the test input
          state = {:vm => vm, :env_metadata_key => env_metadata_key_value}

          step = described_class.new state, client
          client.should_receive(:reload).once.ordered.with(vm)
          allow(step).to receive(:create_iso_cmd).and_return('myIsoCreationUtil')
          allow(Open3).to receive(:popen3).and_return([nil, empty_response, empty_response])
          allow_message_expectations_on_nil

          #execute the test
          expect{step.perform}.to raise_exception RuntimeError
          expect(state[:iso]).to be_nil
        end
      end

      describe ".cleanup" do
        it ".deletes temp folder" do
          #setup the test input
          tmp_dir = '/tmp/foo'
          state = {:tmpdir => tmp_dir}

          #configure mock expectations
          FileUtils.should_receive(:remove_entry_secure).once.with(tmp_dir)

          #execute the test
          step = described_class.new state, client
          step.cleanup
        end

        it ".has no temp folder to delte" do
          #setup the test input
          state = {}

          # configure mocks
          FileUtils.stub(:remove_entry_secure) {raise "Should not call remove on empty tmpdir"}

          # execute the test
          step = described_class.new state, client
          step.cleanup
        end
      end
    end
  end
end

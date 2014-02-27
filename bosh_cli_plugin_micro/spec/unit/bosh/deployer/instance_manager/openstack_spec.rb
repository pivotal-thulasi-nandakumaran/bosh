require 'spec_helper'
require 'fog'
require 'fog/openstack/models/compute/servers'
require 'bosh/deployer/instance_manager/openstack'
require 'bosh/deployer/registry'

module Bosh::Deployer
  describe InstanceManager::Openstack do
    subject(:openstack) { described_class.new(instance_manager, config, logger) }

    let(:instance_manager) { instance_double('Bosh::Deployer::InstanceManager') }

    let(:config) do
      instance_double(
        'Bosh::Deployer::Configuration',
        cloud_options: {
          'properties' => {
            'registry' => {
              'endpoint' => 'fake-registry-endpoint',
            },
            'openstack' => {
              'private_key' => 'fake-private-key',
            },
          },
        },
      )
    end

    let(:logger) { instance_double('Logger', info: nil) }

    before { allow(Registry).to receive(:new).and_return(registry) }
    let(:registry) { instance_double('Bosh::Deployer::Registry') }

    before { allow(File).to receive(:exists?).with(/\/fake-private-key$/).and_return(true) }

    %w(client_services_ip agent_services_ip).each do |method|
      describe "##{method}" do
        before do
          allow(config).to receive(:client_services_ip).
            and_return('fake-client-services-ip')
        end

        context 'when there is a bosh VM' do
          let(:instance) { instance_double('Fog::Compute::OpenStack::Server') }

          before do
            instance_manager.stub_chain(:state, :vm_cid).and_return('fake-vm-cid')
            instance_manager.stub_chain(:cloud, :openstack, :servers, :get).and_return(instance)
          end

          context 'when there is a floating ip' do
            before do
              allow(instance).to receive(:floating_ip_address).
                and_return('fake-floating-ip')
            end

            it 'returns the floating ip' do
              expect(subject.send(method)).to eq('fake-floating-ip')
            end
          end

          context 'when there is no floating ip' do
            before do
              allow(instance).to receive(:floating_ip_address).and_return(nil)
              allow(instance).to receive(:private_ip_address).and_return('fake-private-ip')
            end

            it 'returns the private ip' do
              expect(subject.send(method)).to eq('fake-private-ip')
            end
          end
        end

        context 'when there is no bosh VM' do
          before { instance_manager.stub_chain(:state, :vm_cid).and_return(nil) }

          it 'returns client services ip according to the configuration' do
            expect(subject.send(method)).to eq('fake-client-services-ip')
          end
        end
      end
    end

    describe '#internal_services_ip' do
      before do
        allow(config).to receive(:internal_services_ip).
          and_return('fake-internal-services-ip')
      end

      it 'returns internal services ip according to the configuration' do
        expect(subject.internal_services_ip).to eq('fake-internal-services-ip')
      end
    end
  end
end

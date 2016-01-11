#
# Copyright 2015, Noah Kantrowitz
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'spec_helper'

describe PoisePython::Resources::PythonPackage do
  describe PoisePython::Resources::PythonPackage::Resource do
  end # /describe PoisePython::Resources::PythonPackage::Resource

  describe PoisePython::Resources::PythonPackage::Provider do
    let(:test_resource) { nil }
    let(:test_provider) { described_class.new(test_resource, chef_run.run_context) }

    describe 'actions' do
      let(:package_name) { nil }
      let(:current_version) { nil }
      let(:candidate_version) { nil }
      let(:test_resource) { PoisePython::Resources::PythonPackage::Resource.new(package_name, chef_run.run_context) }
      subject { test_provider.run_action }
      before do
        current_version = self.current_version
        candidate_version = self.candidate_version
        allow(test_provider).to receive(:load_current_resource) do
          current_resource = double('current_resource', package_name: package_name, version: current_version)
          test_provider.instance_eval do
            @current_resource = current_resource
            @candidate_version = candidate_version
          end
        end
      end

      describe 'action :install' do
        before { test_provider.action = :install }

        context 'with package_name foo' do
          let(:package_name) { 'foo' }
          let(:candidate_version) { '1.0.0' }
          it do
            expect(test_provider).to receive(:python_shell_out!).with(%w{-m pip.__main__ install foo==1.0.0}, {})
            subject
          end
        end # /context with package_name foo

        context 'with package_name ["foo", "bar"]' do
          let(:package_name) { %w{foo bar} }
          let(:candidate_version) { %w{1.0.0 2.0.0} }
          it do
            expect(test_provider).to receive(:python_shell_out!).with(%w{-m pip.__main__ install foo==1.0.0 bar==2.0.0}, {})
            subject
          end
        end # /context with package_name ["foo", "bar"]

        context 'with options' do
          let(:package_name) { 'foo' }
          let(:candidate_version) { '1.0.0' }
          before { test_resource.options('--editable') }
          it do
            expect(test_provider).to receive(:python_shell_out!).with('-m pip.__main__ install --editable foo\\=\\=1.0.0', {})
            subject
          end
        end # /context with options

        context 'with a package with extras' do
          let(:package_name) { 'foo[bar]' }
          let(:candidate_version) { '1.0.0' }
          it do
            expect(test_provider).to receive(:python_shell_out!).with(%w{-m pip.__main__ install foo[bar]==1.0.0}, {})
            subject
          end
        end # /context with a package with extras
      end # /describe action :install

      describe 'action :upgrade' do
        before { test_provider.action = :upgrade }

        context 'with package_name foo' do
          let(:package_name) { 'foo' }
          let(:candidate_version) { '1.0.0' }
          it do
            expect(test_provider).to receive(:python_shell_out!).with(%w{-m pip.__main__ install --upgrade foo==1.0.0}, {})
            subject
          end
        end # /context with package_name foo

        context 'with package_name ["foo", "bar"]' do
          let(:package_name) { %w{foo bar} }
          let(:candidate_version) { %w{1.0.0 2.0.0} }
          it do
            expect(test_provider).to receive(:python_shell_out!).with(%w{-m pip.__main__ install --upgrade foo==1.0.0 bar==2.0.0}, {})
            subject
          end
        end # /context with package_name ["foo", "bar"]
      end # /describe action :upgrade

      describe 'action :remove' do
        before { test_provider.action = :remove }

        context 'with package_name foo' do
          let(:package_name) { 'foo' }
          let(:current_version) { '1.0.0' }
          it do
            expect(test_provider).to receive(:python_shell_out!).with(%w{-m pip.__main__ uninstall --yes foo}, {})
            subject
          end
        end # /context with package_name foo

        context 'with package_name ["foo", "bar"]' do
          let(:package_name) { %w{foo bar} }
          let(:current_version) { %w{1.0.0 2.0.0} }
          it do
            expect(test_provider).to receive(:python_shell_out!).with(%w{-m pip.__main__ uninstall --yes foo bar}, {})
            subject
          end
        end # /context with package_name ["foo", "bar"]
      end # /describe action :remove
    end # /describe actions

    describe '#parse_pip_outdated' do
      let(:text) { '' }
      subject { test_provider.send(:parse_pip_outdated, text) }

      context 'with no content' do
        it { is_expected.to eq({}) }
      end # /context with no content

      context 'with standard content' do
        let(:text) { <<-EOH }
boto (Current: 2.25.0 Latest: 2.38.0 [wheel])
botocore (Current: 0.56.0 Latest: 1.1.1 [wheel])
certifi (Current: 14.5.14 Latest: 2015.4.28 [wheel])
cffi (Current: 0.8.1 Latest: 1.1.2 [sdist])
Fabric (Current: 1.9.1 Latest: 1.10.2 [wheel])
EOH
        it { is_expected.to eq({'boto' => '2.38.0', 'botocore' => '1.1.1', 'certifi' => '2015.4.28', 'cffi' => '1.1.2', 'fabric' => '1.10.2'}) }
      end # /context with standard content

      context 'with malformed content' do
        let(:text) { <<-EOH }
boto (Current: 2.25.0 Latest: 2.38.0 [wheel])
botocore (Current: 0.56.0 Latest: 1.1.1 [wheel])
certifi (Current: 14.5.14 Latest: 2015.4.28 [wheel])
cffi (Current: 0.8.1 Latest: 1.1.2 [sdist])
Fabric (Future: 1.9.1 [wheel])
EOH
        it { is_expected.to eq({'boto' => '2.38.0', 'botocore' => '1.1.1', 'certifi' => '2015.4.28', 'cffi' => '1.1.2'}) }
      end # /context with malformed content
    end # /describe #parse_pip_outdated

    describe '#parse_pip_list' do
      let(:text) { '' }
      subject { test_provider.send(:parse_pip_list, text) }

      context 'with no content' do
        it { is_expected.to eq({}) }
      end # /context with no content

      context 'with standard content' do
        let(:text) { <<-EOH }
eventlet (0.12.1)
Fabric (1.9.1)
fabric-rundeck (1.2, /Users/coderanger/src/bal/fabric-rundeck)
flake8 (2.1.0.dev0)
EOH
        it { is_expected.to eq({'eventlet' => '0.12.1', 'fabric' => '1.9.1', 'fabric-rundeck' => '1.2', 'flake8' => '2.1.0.dev0'}) }
      end # /context with standard content

      context 'with malformed content' do
        let(:text) { <<-EOH }
eventlet (0.12.1)
Fabric (1.9.1)
fabric-rundeck (1.2, /Users/coderanger/src/bal/fabric-rundeck)
flake 8 (2.1.0.dev0)
EOH
        it { is_expected.to eq({'eventlet' => '0.12.1', 'fabric' => '1.9.1', 'fabric-rundeck' => '1.2'}) }
      end # /context with malformed content
    end # /describe #parse_pip_list
  end # /describe PoisePython::Resources::PythonPackage::Provider
end

# frozen_string_literal: true

require 'spec_helper'
require 'inventory_helper'

describe InventoryHelper, type: :class do
  include_context('with tmpdir')

  let(:inventory_file) { tmpdir }
  let(:inventory) { described_class.open(inventory_file) }

  let(:node_uri) { 'testing' }
  let(:node_name) { node_uri }
  let(:node_data) do
    {
      uri: node_uri,
      name: node_name,
      config: {
        transport: 'whocares'
      }
    }
  end

  describe '.open' do
    it 'correctly opens and saves new inventory file' do
      expect(inventory.save).to be_a described_class
    end

    context 'non-existent inventory path' do
      let(:inventory_file) { File.join(tmpdir, 'testing/testing.yaml') }

      it 'fails to open inventory file' do
        expect { inventory.save }.to raise_error(RuntimeError, %r{directory for storing inventory does not exist})
      end
    end
  end

  describe '.lookup' do
    let(:node_name) { 'somethingelse' }

    before(:each) do
      inventory.add(node_data, 'whocares').save
    end

    it 'by uri' do
      expect(inventory.lookup(node_uri)).to be_a Hash
    end

    it 'by name' do
      expect(inventory.lookup(name: node_name)).to be_a Hash
    end

    it 'fallback to name' do
      expect(inventory.lookup(node_name)).to be_a Hash
    end

    it 'only in group' do
      expect(inventory.lookup(node_uri, group: 'whocares')).to be_a Hash
    end

    it 'not in group' do
      expect { inventory.lookup(node_uri, group: 'nogroup') }.to raise_error(RuntimeError, "Failed to lookup target #{node_uri}")
    end
  end

  describe '.add' do
    it 'add a node' do
      expect(inventory.add(node_data, 'whocares').save).to be_a described_class
    end
  end

  describe '.remove' do
    it 'remove a node' do
      expect(inventory.add(node_data, 'whocares').save).to be_a described_class
      expect(inventory.remove(inventory.lookup(node_uri))).to be_a described_class
      expect { inventory.delete(inventory.lookup(node_uri)) }.to raise_error(RuntimeError, "Failed to lookup target #{node_uri}")
    end
  end
end

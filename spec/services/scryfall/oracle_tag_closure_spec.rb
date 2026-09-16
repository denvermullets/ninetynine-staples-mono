require 'rails_helper'

RSpec.describe Scryfall::OracleTagClosure, type: :service do
  def depths(rows, descendant)
    rows.select { |row| row[:descendant_id] == descendant }.to_h { |row| [row[:ancestor_id], row[:depth]] }
  end

  it 'gives every tag a depth-0 row, including tags with no parents' do
    rows = described_class.call(parents: { 1 => [], 2 => [1] })

    expect(depths(rows, 1)).to eq(1 => 0)
    expect(depths(rows, 2)).to eq(2 => 0, 1 => 1)
  end

  it 'walks a chain to every ancestor with its distance' do
    rows = described_class.call(parents: { 1 => [], 2 => [1], 3 => [2] })

    expect(depths(rows, 3)).to eq(3 => 0, 2 => 1, 1 => 2)
  end

  # Tagger is a DAG: a tag reachable along two paths gets one row, at the shorter distance
  it 'keeps the shortest distance when two paths reach the same ancestor' do
    rows = described_class.call(parents: { 1 => [], 2 => [1], 3 => [2, 1] })

    expect(depths(rows, 3)).to eq(3 => 0, 2 => 1, 1 => 1)
  end

  it 'survives a cycle in community-edited data' do
    rows = described_class.call(parents: { 1 => [2], 2 => [1] })

    expect(depths(rows, 1)).to eq(1 => 0, 2 => 1)
  end
end

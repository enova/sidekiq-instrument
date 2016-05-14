require 'spec_helper'

describe Sidekiq::Instrument do
  it 'has a version number' do
    expect(Sidekiq::Instrument::VERSION).not_to be nil
  end

  it 'does something useful' do
    expect(false).to eq(true)
  end
end

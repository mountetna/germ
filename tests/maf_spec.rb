require 'maf'

describe Maf do
  it 'should have a header' do
    maf.should have_a('header')
  end
end

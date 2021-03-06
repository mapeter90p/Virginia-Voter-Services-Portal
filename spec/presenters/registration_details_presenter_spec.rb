require 'spec_helper'

describe RegistrationDetailsPresenter do

  describe '#party' do
    specify { rdp(party: '').party.should == 'none' }
    specify { rdp(party: 'Democrat').party.should == 'Democrat' }
    specify { rdp(party: 'other', other_party: 'Choppers').party.should == 'Choppers' }
  end

  describe "status_options" do
    it "should place overseas before everything else" do
      rdp(uocava: true).status_options.should == [ "overseas", "separator", "residential_voter" ]
    end
  end

  private

  def rdp(data)
    data[:current_residence] = data.delete(:uocava) ? 'outside' : 'in'
    RegistrationDetailsPresenter.new(FactoryGirl.build(:registration, data))
  end

end

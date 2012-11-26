json.success  true
json.record do |r|
  r.voterId             @reg.voter_id
  
  r.givenName           @reg.first_name
  r.middleName          @reg.middle_name
  r.familyName          @reg.last_name
  r.nameSuffix          @reg.suffix if @reg.suffix.present?

  r.gender              @reg.gender
  r.phone               @reg.phone if @reg.phone.present?
  r.email               @reg.email if @reg.email.present?

  r.preferredLanguage   @reg.lang_preference
  r.addressConfidential @reg.is_confidential_address == '1'

  r.electoralAddress do |a|
    if @reg.vvr_is_rural == '1'
      a.rural           @reg.vvr_rural
    else
      a.street_number   @reg.vvr_street_number
      a.street_name     @reg.vvr_street_name
      a.street_type     @reg.vvr_street_type
      a.street_suffix   @reg.vvr_street_suffix if @reg.vvr_street_suffix.present?
      a.apt             @reg.vvr_apt if @reg.vvr_apt.present?
      a.locality        @reg.vvr_county_or_city if @reg.vvr_county_or_city.present?
      a.town            @reg.vvr_town
      a.state           @reg.vvr_state
      a.zip5            @reg.vvr_zip5
      a.zip4            @reg.vvr_zip4 if @reg.vvr_zip4.present?
    end
  end
  
  if r.currently_overseas?
    r.electoralAddressAvailable         @reg.vvr_uocava_residence_available
    r.electoralAddressUnavailableSince  @reg.vvr_uocava_residence_unavailable_since.try(:strftime, "%Y-%m-%d")
  end

  r.mailingAddress do |a|
    # TODO 
  end

  r.pollingDistricts do |p|
    p.precinctName        @reg.poll_precinct
    p.localityName        @reg.poll_locality
    p.electoralDistrict   @reg.poll_district
    p.pricinctSplitUID    @reg.poll_pricinct_split
  end
end

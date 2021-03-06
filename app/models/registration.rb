class Registration < ActiveRecord::Base

  include Concern::SerializedAttrs

  scope :stale, lambda { where([ "created_at < ?", 1.day.ago ]) }

  SERVICE_BRANCHES        = [ 'Army', 'Air Force', 'Marines', 'Merchant Marine', 'Navy' ]

  # When checking for changes on the form to determine if that's a purely absentee request,
  # ignore these keys.
  IGNORE_CHANGES_IN_KEYS  = [ :voter_id, :current_residence, :ssn, :no_ssn, :dmv_id, :no_dmv_id,
                              :existing, :poll_locality, :poll_precinct, :poll_district,
                              :information_correct, :privacy_agree ]

  # All absentee request related fields. This list is used to determine
  # if there are any form fields that have changed. If not, we use a different
  # title for the PDF.
  ABSENTEE_REQUEST_FIELDS = [ :requesting_absentee, :rab_election,
                              :rab_election_name, :rab_election_date,
                              :absentee_until,
                              :ab_reason, :ab_street_number,
                              :ab_street_name, :ab_street_type,
                              :ab_apt, :ab_city, :ab_state, :ab_zip5, :ab_zip4, :ab_country,
                              :ab_field_1, :ab_field_2, :ab_time_1, :ab_time_2 ]

  serialized_attr :voter_id

  # Eligibility
  serialized_attr :citizen, :old_enough, :residence

  serialized_attr :outside_type
  serialized_attr :service_branch, :service_id, :rank

  serialized_attr :rights_revoked
  serialized_attr :rights_felony, :rights_felony_restored, :rights_felony_restored_in, :rights_felony_restored_on
  serialized_attr :rights_mental, :rights_mental_restored, :rights_mental_restored_on

  # Identity
  serialized_attr :first_name, :middle_name, :last_name, :suffix
  serialized_attr :dob, :gender, :ssn, :no_ssn, :dmv_id, :no_dmv_id
  serialized_attr :phone, :email

  # Contact info
  serialized_attr :vvr_county_or_city, :vvr_address_1, :vvr_address_2
  serialized_attr :vvr_town, :vvr_state, :vvr_zip5, :vvr_zip4
  serialized_attr :vvr_is_rural
  serialized_attr :vvr_uocava_residence_available, :vvr_uocava_residence_unavailable_since
  serialized_attr :mau_address, :mau_address_2, :mau_city, :mau_city_2, :mau_state, :mau_postal_code, :mau_country, :mau_type
  serialized_attr :ma_address, :ma_address_2, :ma_city, :ma_state, :ma_zip5, :ma_zip4, :ma_is_different
  serialized_attr :apo_address, :apo_address_2, :apo_city, :apo_state, :apo_zip5
  serialized_attr :pr_status, :pr_cancel
  serialized_attr :pr_first_name, :pr_middle_name, :pr_last_name, :pr_suffix
  serialized_attr :pr_address, :pr_address_2, :pr_city, :pr_state, :pr_zip5, :pr_zip4, :pr_is_rural, :pr_county_or_city

  # Options
  serialized_attr :choose_party, :party, :other_party
  serialized_attr :is_confidential_address, :ca_type
  serialized_attr :need_assistance, :as_first_name, :as_middle_name, :as_last_name, :as_suffix, :as_address, :as_address_2, :as_city, :as_state, :as_zip5, :as_zip4
  serialized_attr :requesting_absentee, :rab_election,
                  :rab_election_name, :rab_election_date,
                  :absentee_until
  serialized_attr :ab_reason, :ab_street_number,
                  :ab_street_name, :ab_street_type,
                  :ab_apt, :ab_city, :ab_state, :ab_zip5, :ab_zip4, :ab_country,
                  :ab_field_1, :ab_field_2, :ab_time_1, :ab_time_2
  serialized_attr :be_official

  # Complete Registration
  serialized_attr :information_correct, :privacy_agree, :submission_failed

  # Current status fields (from server)
  serialized_attr :existing
  serialized_attr :current_residence, :military, :overseas
  serialized_attr :absentee_for_elections, :past_elections
  serialized_attr :current_absentee_until           # overseas absentee
  serialized_attr :poll_precinct, :poll_locality, :poll_district, :districts, :poll_pricinct_split
  serialized_attr :ppl_location_name, :ppl_address, :ppl_city, :ppl_state, :ppl_zip, :voting_location, :electoral_board_contacts
  serialized_attr :lang_preference
  serialized_attr :upcoming_elections, :ob_eligible

  before_create :review_absentee_until
  before_save   :cleanup_ssn

  alias :ob_eligible? :ob_eligible

  # TRUE if new registration is eligible
  def eligible?
    self.citizen == '1' &&
    self.old_enough == '1' &&
    self.dob.try(:past?) &&
    (!AppConfig['ssn_required'] || self.ssn.present?) &&
    (self.rights_revoked == '0' ||
     ((self.rights_felony == '1' || self.rights_mental == '1') &&
      (self.rights_felony == '0' || (self.rights_felony_restored == '1' && self.rights_felony_restored_in.present? && self.rights_felony_restored_on.try(:past?))) or
      (self.rights_mental == '0' || (self.rights_mental_restored == '1' && self.rights_mental_restored_on.try(:past?)))))
  end

  def full_name
    [ first_name, middle_name, last_name, suffix ].delete_if(&:blank?).join(' ')
  end

  def pr_full_name
    [ pr_first_name, pr_middle_name, pr_last_name, pr_suffix ].delete_if(&:blank?).join(' ')
  end

  def as_full_name
    [ as_first_name, as_middle_name, as_last_name, as_suffix ].delete_if(&:blank?).join(' ')
  end

  def as_full_address
    [ as_address,
      as_address_2,
      [ as_city, as_state, [ as_zip5, as_zip4 ].rjoin('-') ].rjoin(' ')
    ].rjoin(', ')
  end

  def protected_voter_address
    if uocava?
      if mau_type == 'apo'
        [ apo_address, apo_address_2, apo_city, apo_state, apo_zip5, nil ]
      else
        [ mau_address, mau_address_2, [ mau_city, mau_city_2 ].rjoin(' '), mau_state, mau_postal_code, mau_country ]
      end
    else
      [ ma_address, ma_address_2, ma_city, ma_state, [ ma_zip5, ma_zip4 ].rjoin('-'), nil ]
    end
  end

  def ssn4
    self.ssn ? self.ssn.gsub(/[^0-9]/, '')[-4, 4] : nil
  end

  def absentee?
    self.requesting_absentee == '1'
  end

  def currently_overseas?
    self.current_residence == 'outside'
  end

  def currently_residential?
    !currently_overseas?
  end

  def uocava?
    self.residence == 'outside'
  end

  def residential?
    !uocava?
  end

  def requesting_absentee?
    self.requesting_absentee == '1'
  end

  def no_form_changes?
    (self.data_changes - ABSENTEE_REQUEST_FIELDS).empty?
  end

  def update_attributes(d)
    # Reset previous data storage to be able to track the most recent changes
    self.previous_data = nil
    super(d)
  end

  # Initializes the record for the update workflow
  def init_update_to(kind)
    self.residence = self.current_residence

    unless kind.blank?
      self.residence           = kind == 'overseas' ? 'outside' : 'in'
      self.requesting_absentee = !!(kind =~ /absentee|overseas/) ? '1' : '0'

      self.rab_election        = nil
      self.rab_election_name   = nil
      self.rab_election_date   = nil
      self.ab_field_1          = nil
      self.ab_field_2          = nil
      self.ab_time_1           = nil
      self.ab_time_2           = nil
      self.ab_reason           = nil
      self.ab_street_number    = nil
      self.ab_street_name      = nil
      self.ab_street_type      = nil
      self.ab_apt              = nil
      self.ab_city             = nil
      self.ab_state            = nil
      self.ab_zip5             = nil
      self.ab_zip4             = nil
      self.ab_country          = nil
    end

    init_absentee_until
  end

  # Initializes the absentee_until field by the rules set in options
  def init_absentee_until
    self.absentee_until = AppConfig['enable_uocava_end_date_choice'] ? 1.year.from_now : 1.year.from_now.end_of_year
  end

  # TRUE if we are changing the absentee period
  def extending_absentee_period?
    self.current_absentee_until.try(:strftime, "%Y-%m-%d") != self.absentee_until.try(:strftime, "%Y-%m-%d")
  end

  # Existing voter type (used in logs)
  def voter_type
    return nil if voter_id.blank?

    if uocava?
      "Overseas / Military Absentee"
    elsif absentee?
      "Domestic Absentee"
    else
      "Residential Voter"
    end
  end

  def data_changes
    changed_keys = []

    nd = self.data || {}
    pd = self.previous_data || {}

    pd.each do |k, v|
      changed_keys << k unless nd[k].to_s == v.to_s
    end

    changed_keys.uniq - IGNORE_CHANGES_IN_KEYS
  end

  def paperless_submission_allowed?
    self.is_confidential_address != '1' || self.ca_type != 'TSC'
  end

  private

  def review_absentee_until
    return if self.absentee_until.blank?

    if AppConfig['enable_uocava_end_date_choice']
      max_date = 1.year.from_now
    else
      max_date = 1.year.from_now.end_of_year
    end

    self.absentee_until = max_date if self.absentee_until.to_i > max_date.to_i
  end

  def cleanup_ssn
    self.ssn.gsub!(/[^0-9]/, '') if self.ssn.present?
  end
end

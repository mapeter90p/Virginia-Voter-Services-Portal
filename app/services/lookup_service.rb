class LookupService < LookupApi

  # stub registration lookup
  def self.registration(record)
    if AppConfig['enable_dmvid_lookup'] && record_complete?(record)
      return dmv_address_lookup(record)
    else
      return { registered: false, dmv_match: false }
    end
  rescue RecordNotFound
    { registered: false, dmv_match: false }
  end

  # Returns absentee status items in an array.
  # Raises: LookupApi::RecordNotFound if record wasn't found
  # for whatever reason.
  def self.absentee_status_history(voter_id, dob, locality)
    election_ids = collect_election_ids_for_voter(voter_id)
    return collect_elections_details(voter_id, election_ids, dob, locality)
  rescue Timeout::Error
    raise LookupTimeout
  end

  def self.voter_elections(voter_id)
    all_voter_elections(voter_id).select do |e|
      has_ballot_for?(voter_id, e[:id])
    end
  end

  def self.ballot_info(voter_id, election_uid)
    Rails.cache.fetch("ballot_info:#{voter_id}:#{election_uid}", expires_in: 1.second) do
      q = { VoterIDnumber: voter_id, electionId: election_uid }

      xml = parse_uri('GetVipBallotsByVoterId', q) do |res, method = nil|
        DebugLogging.log("GetVipBallotsByVoterId", res)
        raise "Server error" if res.code =~ /^5/
        raise RecordNotFound if res.code != '200'
        res.body
      end

      parse_ballot_xml(xml)
    end
  end

  private

  def self.all_voter_elections(voter_id)
    Rails.cache.fetch("voter_elections:#{voter_id}", expires_in: 1.second) do
      q = { voterIDnumber: voter_id }

      xml = parse_uri('GetVipElectionByVoterId', q) do |res, method = nil|
        DebugLogging.log("GetVipElectionByVoterId", res)
        raise RecordNotFound if res.code != '200'
        res.body
      end

      parse_elections_xml(xml)
    end
  end

  def self.collect_election_ids_for_voter(voter_id)
    all_voter_elections(voter_id).map { |e| e[:id] }
  end

  def self.collect_elections_details(voter_id, election_ids, dob, locality)
    election_ids.map do |election_id|
      collect_election_details(voter_id, election_id, dob, locality)
    end.flatten
  end

  def self.collect_election_details(voter_id, election_id, dob, locality)
    q = {
      voterIDnumber:  voter_id,
      localityName:   locality,
      dobMonth:       dob.month,
      dobDay:         dob.day,
      dobYear:        dob.year,
      electionId:     election_id }

    xml = parse_uri('GetVoterTransactionLogByVoterId', q) do |res, method = nil|
      DebugLogging.log("GetVoterTransactionLogByVoterId", res)
      raise RecordNotFound if res.code != '200'
      res.body
    end

    parse_transaction_log_xml(xml)
  end

  def self.dmv_address_lookup(r)
    parse_dmv_lookup_xml(send_request(r))
  end

  def self.record_complete?(r)
    r[:dmv_id].present? &&
      r[:ssn].present? &&
      r[:dob_month].present? &&
      r[:dob_day].present? &&
      r[:dob_year].present?
  end

  def self.send_request(r)
    q = {
      DmvIDnumber:                  r[:dmv_id] || '',
      ssn9:                         r[:ssn].to_s.gsub(/[^0-9]/, ''),
      dobMonth:                     r[:dob_month],
      dobDay:                       r[:dob_day],
      dobYear:                      r[:dob_year],
      eligibleCitizen:              r[:eligible_citizen],
      eligible18nextElection:       r[:eligible_18_next_election],
      eligibleVAresident:           r[:eligible_va_resident],
      eligibleNotRevokedUnrestored: r[:eligible_unrevoked_or_restored],
      hashType:                     "none"
    }

    parse_uri 'voterByDMVIDnumber', q do |res, method = nil|
      if res.code == '200'
        DebugLogging.log("voterByDMVIDnumber", res)
        return res.body
      end

      # raise legit not found error
      if res.code == '400' && (
         /Voter wasn't found in the system/i =~ res.body ||
         /not found/i =~ res.body ||
         /not available/i =~ res.body ||
         /not active/i =~ res.body)

        Rails.logger.error("NOT FOUND: LOOKUP code=#{res.code}\n#{res.body}") if AppConfig['api_debug_logging']
        raise RecordNotFound
      end

      Rails.logger.error("INTERNAL ERROR: LOOKUP code=#{res.code}\n#{res.body}") if AppConfig['api_debug_logging']
      ErrorLogRecord.log("Lookup: unknown error", code: res.code, body: res.body)
      LogRecord.lookup_error(res.body)

      raise RecordNotFound
    end
  end

  def self.parse_dmv_lookup_xml(xml)
    doc = Nokogiri::XML::Document.parse(xml)
    doc.remove_namespaces!

    prot = doc.css('CheckBox[Type="IsProtected"]').try(:text) == 'yes'

    o = {
      registered: doc.css('CheckBox[Type="SBEMatch"]').try(:text) == 'yes',
      dmv_match:  doc.css('CheckBox[Type="DMVMatch"]').try(:text) == 'yes'
    }

    # if protected, don't include the address
    return o if prot

    ea = doc.css('ElectoralAddress').first
    if ea
      if ft = ea.css('FreeTextAddress').first
        zip = ft.css("AddressLine[type='Zip']").try(:text).to_s

        o[:address] = {
          address_1:      ft.css("AddressLine[type='AddressLine1']").try(:text),
          address_2:      ft.css("AddressLine[type='AddressLine2']").try(:text),
          town:           ft.css("AddressLine[type='City']").try(:text),
          zip5:           zip[0, 5],
          zip4:           zip[5, 4]
        }
      elsif pa = ea.css('PostalAddress').first
        o[:address] = {
          address_1:      pa.css('Thoroughfare').first.try(:text),
          address_2:      pa.css('OtherDetail').try(:text),
          town:           pa.css('Locality').try(:text),
          zip5:           (pa.css('PostCode').try(:text) || "")[0, 5]
        }
      end
    end

    o
  end

  def self.parse_elections_xml(xml)
    doc = Nokogiri::XML::Document.parse(xml)
    doc.remove_namespaces!
    doc.css('election').map do |o|
      id = o['id']
      name = (o.css('name').first).text.to_s.strip
      { id: id, name: name }
    end
  end

  def self.parse_transaction_log_xml(xml)
    doc = Nokogiri::XML::Document.parse(xml)
    doc.remove_namespaces!
    doc.css('voterTransactionRecord').map do |vtr|
      date      = vtr.css('date').text
      request   = vtr.css('form type').text
      request   = vtr.css('form').text if request.blank?

      { request:    request,
        action:     vtr.css('action').text,
        date:       Date.parse(date).strftime('%b %d, %Y'),
        registrar:  vtr.css('leo').text.to_s.strip,
        notes:      vtr.css('notes').text.to_s.strip,
        form_notes: vtr.css('formNote').text.to_s.strip }
    end
  end

  def self.parse_ballot_xml(xml)
    doc = Nokogiri::XML::Document.parse(xml)
    doc.remove_namespaces!

    contests = doc.css('contest').map do |c|
      type = c.css('contest_type').first.text

      candidates = c.css('candidate').map do |a|
        candidate = { name: a.css('name').first.text }

        if type =~ /Contest/i
          candidate[:sort_order] = a.css('sort_order').first.try(:text).to_i
          candidate[:candidate_url] = a.css('candidate_url').first.try(:text)
          candidate[:party] = a.css('party name').first.try(:text)
          candidate[:email] = a.css('email').first.try(:text)
        end

        candidate
      end.sort_by { |e| e[:sort_order] }

      { type: type,
        sort_order: c.css('sort_order').first.text.to_i,
        office: c.css('office').first.text,
        candidates: candidates }
    end

    { election: {
      name: doc.css('election name').first.text.strip,
      date: Date.parse(doc.css('election date').first.text)
    },

      locality: doc.css('locality name').first.try(:text),
      precinct: doc.css('precinct name').first.try(:text),

      contests: contests.sort_by { |e| e[:sort_order] }
    }
  end

  def self.has_ballot_for?(voter_id, election_uid)
    ballot_info(voter_id, election_uid).present?
  rescue RecordNotFound
    false
  end
end

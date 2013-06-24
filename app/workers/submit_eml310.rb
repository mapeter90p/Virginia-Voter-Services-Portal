require 'builder'

class SubmitEml310

  # Possible reasons: bad EML310, service unavailable
  class SubmissionError < StandardError
    attr_reader :code

    def initialize(code = nil, message = nil)
      super message
      @code = code
    end
  end

  def self.submit_update(reg)
    return submit(reg, "voterRecordUpdateRequest")
  end

  def self.submit_new(reg)
    return submit(reg, "voterRegistrationRequest")
  rescue SubmissionError => e
    if e.message == 'already registered'
      return submit_update(reg)
    else
      raise e
    end
  end

  private

  def self.submit(reg, method)
    response = nil
    result = {}

    # don't submit anything if disabled
    if submission_enabled?
      response = send_request(reg, method)
      result = parse(response)
    end

    result
  rescue => e
    if e.kind_of? SubmissionError
      raise e
    else
      raise SubmissionError
    end
  end

  def self.send_request(reg, method)
    uri = URI("#{SubmitEml310.submission_url}/#{method}")
    req = Net::HTTP::Post.new(uri.path)
    req.body = registration_xml(reg)
    req.content_type = 'multipart/form-data'

    return Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(req)
    end
  end

  def self.submission_enabled?
    submission_url.present?
  end

  def self.submission_url
    @submission_url ||= AppConfig['eml310_submit_url']
  end

  # returns registration EML310
  def self.registration_xml(reg)
    xml = Builder::XmlMarkup.new
    Eml310Builder.build(reg, xml)
  end

  def self.successful_response?(res)
    res.kind_of? Net::HTTPSuccess
  end

  # parses the response
  def self.parse(res)
    if successful_response?(res)
      return res.body !~ /pending signature/i
    else
      raise SubmissionError.new(res.code, res.body)
    end
  end
end

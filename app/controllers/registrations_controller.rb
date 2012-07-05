class RegistrationsController < ApplicationController

  before_filter :requires_registration, except: [ :new, :create ]

  def new
    LogRecord.log('VoterRegistrationRequest', 'start')

    options = RegistrationRepository.pop_search_query(session)
    options.merge!(
      residence:      params[:residence],
      requesting_absentee: params[:residence] == 'outside' ? '1' : '0',
      absentee_until: 1.year.from_now)

    @registration = Registration.new(options)
  end

  def create
    data = params[:registration]
    Converter.params_to_date(data,
      :vvr_uocava_residence_unavailable_since,
      :dob,
      :absentee_until,
      :rights_restored_on)

    Converter.params_to_time(data,
      :ab_time_1, :ab_time_2)

    @registration = Registration.new(data)

    if @registration.save
      RegistrationRepository.store_registration(session, @registration)
      render :show
    else
      flash.now[:error] = 'Please review your request data and try submitting again'
      render :new
    end
  end

  def show
    @registration = current_registration
    @update       = !@registration.previous_data.blank?
    respond_to do |f|
      f.html
      f.pdf do
        voter_id = nil
        doctype  = 'VoterRegistrationRequest'

        if @update
          voter_id  = @registration.voter_id
          doctype   = @registration.requesting_absentee == '1' ? 'AbsenteeRequest+VoterRegistrationUpdateRequest' : 'VoterRegistrationUpdateRequest'
        end

        LogRecord.log(doctype, 'complete', voter_id)

        render layout: false
      end
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to :root
  end

  def edit
    @registration = current_registration

    # "kind" comes from the review form where we either maintain or
    # change the status.
    @registration.init_update_to(params[:kind].to_s)

    LogRecord.log("VoterRegistrationUpdateRequest", "start", @registration.voter_id)
  end

  def update
    data = params[:registration]
    Converter.params_to_date(data,
      :vvr_uocava_residence_unavailable_since,
      :dob,
      :absentee_until,
      :rights_restored_on)

    Converter.params_to_time(data,
      :ab_time_1, :ab_time_2)

    @registration = current_registration
    unless @registration.update_attributes(data)
      redirect_to :edit_registration, alert: 'Please review your registration data and try again'
    end
  end

end

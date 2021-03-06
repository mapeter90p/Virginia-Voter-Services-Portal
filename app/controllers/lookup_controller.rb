class LookupController < ApplicationController

  rescue_from LookupApi::RecordNotFound do |ex|
    render json: { success: true, items: [] }
  end

  rescue_from LookupApi::LookupTimeout do |ex|
    render json: { success: false, message: "Servers are busy. Please retry later." }
  end

  def registration
    render json: LookupService.registration(params[:record].symbolize_keys)
  end

  def absentee_status_history
    reg = current_registration
    items = LookupService.absentee_status_history(reg.voter_id, reg.dob, reg.vvr_county_or_city)
    items = items.each do |i|
      i[:request] = I18n.t("view.absentee_status.request.#{i[:request]}", default: i[:request]) unless i[:request].blank?
      i[:action]  = I18n.t("view.absentee_status.action.#{i[:action]}", default: i[:action]) unless i[:action].blank?

      notes = []
      notes << I18n.t("view.absentee_status.formnotes.#{i[:form_notes]}", default: i[:form_notes]) unless i[:form_notes].blank?
      notes << I18n.t("view.absentee_status.notes.#{i[:notes]}", default: i[:notes]) unless i[:notes].blank?

      i[:notes] = notes.join("; ")
    end
    render json: { success: true, items: items }
  end

  def my_ballot
    reg = current_registration

    elections = LookupService.voter_elections(reg.voter_id).map do |e|
      { url:  ballot_info_path(e[:id]),
        name: [ e[:name], I18n.t('ballot_info.election') ].reject(&:blank?).join(' ') }
    end

    render json: { success: true, items: elections }
  end

end

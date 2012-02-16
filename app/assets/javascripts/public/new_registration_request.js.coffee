# Eligibility section
class EligibilitySection extends Forms.Section
  constructor: (navigationListener) ->
    @oname  = 'registration_request'
    oid     = "##{@oname}"
    section = $('#eligibility')

    # Fields
    @citizen            = $("#{oid}_citizen")
    @age                = $("#{oid}_old_enough")
    @residence          = $("input[name='#{@oname}[residence]']")
    @residenceInside    = $("#{oid}_residence_in")
    @livingOutside      = $("input[name='#{@oname}[outside_type]']")
    @oaServiceId        = $("#{oid}_outside_active_service_id")
    @oaRank             = $("#{oid}_outside_active_rank")
    @osServiceId        = $("#{oid}_outside_spouse_service_id")
    @osRank             = $("#{oid}_outside_spouse_rank")
    @convicted          = $("input[name='#{@oname}[convicted]']")
    @convictedRestored  = $("#{oid}_convicted_restored")
    @convictedFalse     = $("#{oid}_convicted_false")
    @mental             = $("input[name='#{@oname}[mental]']")
    @mentalRestored     = $("#{oid}_mental_restored")
    @mentalFalse        = $("#{oid}_mental_false")

    # Configure feedback popover on Next button
    btnNext = $('button.next', section)
    popover = new Feedback.Popover(btnNext)
    popover.addItem(new Feedback.Checked(@citizen, 'Citizenship criteria'))
    popover.addItem(new Feedback.Checked(@age, 'Age criteria'))
    popover.addItem(new Feedback.Checked(@residence, 'Residence selection'))
    popover.addItem(new Feedback.Checked(@livingOutside, 'Reason for living outside', skipIf: => !@residenceOutside()))
    popover.addItem(new Feedback.Filled(@oaServiceId, 'Your service ID', skipIf: => !@outsideActive()))
    popover.addItem(new Feedback.Filled(@oaRank, 'Your rank / grade / rate', skipIf: => !@outsideActive()))
    popover.addItem(new Feedback.Filled(@osServiceId, 'Your spouse\'s service ID', skipIf: => !@outsideSpouse()))
    popover.addItem(new Feedback.Filled(@osRank, 'Your spouse\'s rank / grade / rate', skipIf: => !@outsideSpouse()))
    popover.addItem(new Feedback.Checked(@convicted, 'Convictions status'))
    popover.addItem(new Feedback.Checked(@mental, 'Mental status'))
    unrestoredRights = "You can't vote until your rights are restored"
    popover.addItem(new Feedback.Checked(@convictedRestored, unrestoredRights, skipIf: => @convictedFalse.is(":checked") or !@convicted.is(":checked") ))
    popover.addItem(new Feedback.Checked(@mentalRestored, unrestoredRights, skipIf: => @mentalFalse.is(":checked") or !@mental.is(":checked") ))

    new Forms.BlockToggleField(oid + '_residence_outside', 'div.outside')
    new Forms.BlockToggleField(oid + '_outside_type_active_duty', 'div.add')
    new Forms.BlockToggleField(oid + '_outside_type_spouse_active_duty', 'div.sadd')
    new Forms.BlockToggleField(oid + '_convicted_true', '.convicted-details')
    new Forms.BlockToggleField(oid + '_convicted_restored', '.convicted-details .restored')
    new Forms.BlockToggleField(oid + '_mental_true', '.mental-details')
    new Forms.BlockToggleField(oid + '_mental_restored', '.mental-details .restored')

    super '#eligibility', navigationListener

  residenceType: -> $("input:checked[name='#{@oname}[residence]']").val()
  residenceOutside: -> @residenceType() == 'outside'
  outsideType: -> $("input:checked[name='#{@oname}[outside_type]']").val()
  outsideActive: -> @residenceOutside() and @outsideType() == 'active_duty'
  outsideSpouse: -> @residenceOutside() and @outsideType() == 'spouse_active_duty'

  isComplete: =>
    @checked(@citizen) and @checked(@age) and
      (@checked(@residenceInside) or
        (@outsideType() == 'active_duty' and @filled(@oaServiceId) and @filled(@oaRank)) or
        (@outsideType() == 'spouse_active_duty' and @filled(@osServiceId) and @filled(@osRank)) or
        (@outsideType() or '').match(/temporarily/)) and
      (@checked(@convictedFalse) or @checked(@convictedRestored)) and
      (@checked(@mentalFalse) or @checked(@mentalRestored))



# Identify Yourself section
class IdentitySection extends Forms.Section
  constructor: (navigationListener) ->
    oname   = 'registration_request'
    oid     = "##{oname}"
    section = $('#identity')

    # Fields
    @lastName = $("#{oid}_last_name")
    @gender   = $("#{oid}_gender")
    @gender   = false if @gender.length == 0
    @ssn      = $("#{oid}_ssn")
    @dln      = $("#{oid}_dln")
    @noSsn    = $("#{oid}_no_ssn")

    # Configure feedback popover on Next button
    popover = new Feedback.Popover($('button.next', section))
    popover.addItem(new Feedback.Filled(@lastName, 'Last name'))
    popover.addItem(new Feedback.Filled(@gender, 'Gender')) if @gender
    popover.addItem(new Feedback.Filled(@ssn, 'Social Security #', skipIf: => @noSsn.is(":checked")))
    popover.addItem(new Feedback.Filled(@dln, 'Drivers license or State ID', skipIf: => !@noSsn.is(":checked")))

    new Forms.BlockToggleField("#{oid}_no_ssn", '.dln')

    super '#identity', navigationListener

  validSsn: ->
    @ssn.val().match(new RegExp(@ssn.attr('data-format'), 'gi'))

  validDln: ->
    @dln.val().match(new RegExp(@dln.attr('data-format'), 'gi'))

  isComplete: =>
    return @filled(@lastName) and
      (!@gender or @filled(@gender)) and
      (if @checked(@noSsn) then @validDln() else @validSsn())



class ContactInfoSection extends Forms.Section
  constructor: (navigationListener) ->
    oname    = 'registration_request'
    oid      = "##{oname}"
    @section = $('#contact_info')

    @residenceOutside = $("#{oid}_residence_outside").change(@onResidenceChange)

    @vvrCityOrCounty = $("#{oid}_vvr_county_or_city")
    @vvrStreetNumber = $("#{oid}_vvr_street_number")
    @vvrStreetName   = $("#{oid}_vvr_street_name")
    @vvrCity         = $("#{oid}_vvr_town_or_city")
    @vvrZip5         = $("#{oid}_vvr_zip5")
    @vvrIsRural      = $("#{oid}_vvr_is_rural")
    @vvrRural        = $("#{oid}_vvr_rural")


    new Forms.BlockToggleField("#{oid}_vvr_uocava_residence_available_false", '.residence_unavailable')
    new Forms.BlockToggleField("#{oid}_mau_type_non-us", '.maut-non-us')
    new Forms.BlockToggleField("#{oid}_mau_type_apo", '.maut-apo')
    new Forms.BlockToggleField("#{oid}_is_confidential_address", '.confidental_address')
    new Forms.BlockToggleField("#{oid}_has_existing_reg_true", '.existing_reg')
    new Forms.BlockToggleField("#{oid}_ma_other", '.ma_other')
    new Forms.BlockToggleField("#{oid}_vvr_is_rural", '.vvr_rural', '.vvr_common')
    new Forms.BlockToggleField("#{oid}_ma_is_rural", '.ma_rural', '.ma_common')
    new Forms.BlockToggleField("#{oid}_er_is_rural", '.er_rural', '.er_common')

    # DEBUG
    # @residenceOutside.attr('checked', 'checked')

    votingResidenceItem = new Feedback.CustomItem('Voting residence',
      isComplete: @isVotingResidenceComplete,
      watch: [ @vvrCityOrCounty, @vvrStreetNumber, @vvrStreetName, @vvrCity, @vvrZip5, @vvrIsRural, @vvrRural ]
    )

    # Configure feedback popover on Next button
    popover = new Feedback.Popover($('button.next', @section))
    popover.addItem(votingResidenceItem)

    @onResidenceChange()
    super '#contact_info', navigationListener

  isVotingResidenceComplete: =>
    rural = @checked(@vvrIsRural)
    @filled(@vvrCityOrCounty) and
      (rural  and @filled(@vvrRural)) or
      (!rural and @filled(@vvrStreetNumber) and @filled(@vvrStreetName) and @filled(@vvrCity) and @filled(@vvrZip5))

  onResidenceChange: =>
    uocava   = $(".uocava", @section)
    domestic = $(".domestic", @section)
    if @residenceOutside.is(':checked')
      uocava.show()
      domestic.hide()
    else
      uocava.hide()
      domestic.show()

  isComplete: =>
    @isVotingResidenceComplete()

class Form extends Forms.MultiSectionForm
  constructor: ->
    super [
      new EligibilitySection(this),
      new IdentitySection(this),
      new ContactInfoSection(this),
    ], new Forms.StepIndicator(".steps")


$ ->
  return unless $('form#new_registration_request').length > 0
  new Form



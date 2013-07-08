pageSteps = {
  'eligibility':      1,
  'identity':         2,
  'address':          3,
  'options':          4,
  'confirm':          5,
  'oath':             5,
  'submit_online':    5,
  'final':            5,
  'download':         5,
  'congratulations':  5
}

finalizationPageSteps = {
  'view':             1,
  'address':          2,
  'options':          3,
  'final':            4,
  'download':         4,
  'congratulations':  4
}

class UpdateRegistration extends Registration
  constructor: (initPage = 0) ->
    super($('input#registration_residence').val())

    @augmentEligibilityFields()
    @augmentIdentityFields()
    @initConfirmFields()

    # overrides default criteria (see in registration.js)
    @isEligible = ko.computed =>
      @citizen() == '1' and
      @oldEnough() == '1' and
      (!@ssnRequired() or (!@noSSN() and filled(@ssn()))) and
      @hasEligibleRights()

    new Popover('#eligibility .next.btn', @eligibilityErrors)
    new Popover('#identity .next.btn', @identityErrors)
    new Popover('#mailing .next.btn', @addressesErrors)
    new Popover('#options .next.btn', @optionsErrors)
    new Popover('#oath .next.btn', @oathErrors)
    new Popover('#confirm .next.btn', @confirmErrors)

    # Init absenteeUntil
    rau = $("#registration_absentee_until").val()
    rau = moment().add('days', 45).format("YYYY-MM-DD") if !filled(rau)
    @setAbsenteeUntil(rau)

    # Navigation
    @page = ko.observable('eligibility')
    @step = ko.computed => pageSteps[@page()]

    # Watch for url changes
    $(window).hashchange =>
      @gotoPage(location.hash.replace('#', ''))

    if $("#registration_requesting_absentee:not([disabled])").is(":checked")
      @gotoPage('options')

  augmentEligibilityFields: ->
    @eligibilityErrors = ko.computed =>
      errors = []
      errors.push("Citizenship criteria") unless @citizen()
      errors.push("Age criteria") unless @oldEnough()
      errors.push("Voting rights criteria") if @rightsNotFilled()
      errors.push('Social Security #') if !ssn(@ssn()) and !@noSSN()
      errors

    @eligibilityInvalid = ko.computed => @eligibilityErrors().length > 0

  augmentIdentityFields: ->
    @identityErrors = ko.computed =>
      errors = []
      errors.push('First name') unless filled(@firstName())
      errors.push('Last name') unless filled(@lastName())
      errors.push('Phone number') unless @validPhone()
      errors.push('Email address') unless @validEmail()

      if (@middleNameRequired() and !filled(@middleName()) and !@noMiddleName())
        errors.push('Middle name')

      if (@nameSuffixRequired() and !filled(@suffix()) and !@noSuffix())
        errors.push('Name suffix')
      errors

  initConfirmFields: ->
    @confirmErrors = ko.computed =>
      errors = []
      errors.push("Your last name") unless filled(@lastName())
      errors
    @confirmInvalid = ko.computed => @confirmErrors().length > 0

  submitForm: ->
    $("form.edit_registration")[0].submit()

  gotoPage: (page, e) =>
    return if e && $(e.target).hasClass('disabled')
    page = 'eligibility' unless filled(page)
    @page(page)
    location.hash = page

  prevPage: => window.history.back()
  eligibilityPage: (_, e) => @gotoPage('eligibility', e)
  nextFromIdentity: (_, e) => @gotoPage('address', e)
  nextFromAddress: (_, e) => @gotoPage('options', e)
  nextFromOptions: (_, e) => @gotoPage('confirm', e)
  nextFromConfirm: (_, e) => @gotoPage('oath', e)
  nextFromOath: (_, e) =>
    if @paperlessSubmission()
      @gotoPage('submit_online', e)
    else
      @submitForm()


$ ->
  if $("#update_registration").length > 0
    ko.applyBindings(new UpdateRegistration())

  if $("#update_finalization").length > 0
    ko.applyBindings(new Finalization(finalizationPageSteps))

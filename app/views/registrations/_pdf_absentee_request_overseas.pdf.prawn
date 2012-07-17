pdf_labeled_block pdf, "Absentee" do
  pdf_checkbox pdf, "I will not be able to vote in person, and would like to vote absentee"
  pdf_checkbox pdf, rr.absentee_type

  if rr.residence_still_available?
    pdf_checkbox pdf, "My Virginia residence is still available to me"
  else
    pdf_checkbox pdf, "My Virginia residence is is no longer available to me"
    pdf_fields pdf, [
      { columns: 1, value: rr.residence_unavailable_since, label: 'last residence at the above address' }
    ]
  end

  if rr.outside_type_with_details?
    pdf.move_down 15
    pdf_fields pdf, [
      { columns: 1, value: rr.military_branch, label: 'service branch' },
      { columns: 1, value: rr.military_service_id, label: 'service id' },
      { columns: 1, value: rr.military_rank, label: 'rank, grade, or rate' }
    ]
  end
  
  pdf.move_down 15
  pdf_fields pdf, [
    { columns: 1, value: "until #{rr.absentee_status_until}", label: 'absentee status duration' }
  ]
end

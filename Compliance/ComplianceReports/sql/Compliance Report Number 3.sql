
declare @userID uniqueidentifier, @rosterYearID uniqueidentifier; 
select @userID = ID from UserProfile where UserName = 'enrich:julielott'
select @rosterYearID = ID from RosterYear where StartYear = 2014

; with iiCTE as (
	select LocationID = loc.ID
		, SubmissionTypeID = mst.ID
		, SubmissionModeID = msm.ID
		, Location = loc.DisplayName
		, SubmissionType = mst.Name
		, SubmissionMode = msm.Name
		, TemplateName = t.Name
		, TemplateID = t.ID
		, LayoutID = tl.ID 
		, InputAreaID = tl.ControlId
		, tl.ParentId 
		, tlSequence = tl.Sequence --- will always be zero in the anchor
		, CTELevel = 0 -- keep this consistent with other formlet sequences that start at 0
		, ControlType = tct.Name
		, ControlIsRepeatable = tc.IsRepeatable
		, DisplaySequence = cast(100+tl.Sequence as varchar(max)) -- add 100 for sorting in alpha order 
	from MonSubmissionType mst -- this will narrow the result set to only CO DMS-related formlets.
	left join MonSubmissionMode msm on mst.ID = msm.SubmissionTypeID
	left join MonLocation loc on mst.LocationID = loc.ID -- select * from MonLocation -- select * from MonSubmissionType 
	left join MonProgram p on loc.ProgramID = p.ID
	left join FormTemplate t on mst.FormTemplateID = t.ID
	left join FormTemplateLayout tl on t.ID = tl.TemplateID
	left join FormTemplateControl tc on tl.ControlID = tc.Id
	left join FormTemplateControlType tct on tc.TypeID = tct.ID
	--left join (select distinct SubmissionTypeID, SubmissionModeID
	--			from MonSubmissions 
	--			where OrgUnitID = '3B26E265-39EA-422D-A17C-B8C8D9E312D8' -- Brighton
	--			) subs on mst.ID = subs.SubmissionTypeID and subs.SubmissionModeID = msm.ID
	where tl.ParentId is null
	and loc.ID = '651161A6-8091-448D-826A-1235735134A4'
	and msm.ID = '61C193FE-4781-4071-A68F-124A151DDA17' -- (Standard Review)
	---

	union all 

	select c.LocationID
		, c.SubmissionTypeID
		, c.SubmissionModeID
		, c.Location
		, c.SubmissionType
		, c.SubmissionMode
		, TemplateName = t.Name
		, TemplateID = t.ID
		, LayoutID = tl.ID 
		, InputAreaID = tl.ControlId
		, tl.ParentId 
		, tlSequence = tl.Sequence 
		, CTELevel = c.CTELevel+1 
		, ControlType = tct.Name
		, ControlIsRepeatable = tc.IsRepeatable
		, DisplaySequence = c.DisplaySequence+'_'+cast(100+tl.Sequence as varchar(max)) -- add 100 for sorting in alpha order 
	from FormTemplate t 
	join FormTemplateLayout tl on t.ID = tl.TemplateID and tl.ParentId is not null -- inner join
	join FormTemplateControl tc on tl.ControlID = tc.Id
	join FormTemplateControlType tct on tc.TypeID = tct.ID
	join iiCTE c on tl.ParentID = c.LayoutID

)
, attributesCTE as (
	select 
		c.TemplateID
		, c.LocationID
		, c.SubmissionTypeID
		, c.SubmissionModeID
		, c.Location, c.SubmissionType, c.SubmissionMode, c.TemplateName
		, c.InputAreaID
		, AttributeID = ii.ID
		, c.ParentId
		, c.LayoutID
		, SubmissionAreaID = msa2.ID
		, DisplaySequence = c.DisplaySequence+isnull('_'+cast(100+ii.Sequence as varchar(max)),'')
		, AttributeSequence = row_number() over (partition by c.Location, c.SubmissionType, c.SubmissionMode, c.TemplateName order by c.DisplaySequence+isnull('_'+cast(100+ii.Sequence as varchar(max)),''))
-- the reverseAttributeSequence allows us to distinguish the comments field from other text fields
		, reverseAttributeSequence = row_number() over (partition by c.Location, c.SubmissionType, c.SubmissionMode, c.TemplateName, msa2.Label order by c.DisplaySequence+isnull('_'+cast(100+ii.Sequence as varchar(max)),'') desc)
		, c.ControlType
		, InputItemType = iit.Name
		, SubmissionAreaLabel = msa2.Label
		, SubmissionAreaSequence = msa2.Sequence
		, ii.ReportLabel
		, ii.Code
		, Attribute = isnull(ii.reportlabel, ii.code)
		, ii.Label
	from iiCTE c
	join iiCTE c2 on c.SubmissionModeID = c2.SubmissionModeID and c.ParentID = c2.LayoutID 
	join FormTemplateInputItem ii on c.InputAreaID = ii.InputAreaId 
	left join FormTemplateInputItemType iit on ii.TypeId = iit.Id
	left join MonSubmissionItem mii on ii.id = mii.FormTemplateInputItemID
	left join MonSubmissionArea msa2 on c2.InputAreaID = msa2.FormTemplateControlID
) 

select [Administrative Unit] = ou.Name
	, Item = 'Example'
	, [Type of Review] = a.SubmissionMode
	, a.SubmissionAreaSequence
--	, a.SubmissionAreaID
	, a.SubmissionAreaLabel
	, Pct = cast(sum(case sfo.ReportLabel when 'Met' then 1 end)/sum(case when sfo.ReportLabel in ('Met', 'Not Met') then 1 end*1.0)*100 as money)
from FormInstance fi
left join FormInstanceInterval fii on fi.ID = fii.InstanceID
left join FormInputValue fiv on fii.ID = fiv.IntervalID
left join attributesCTE a on fiv.InputFieldId = a.AttributeID
-- mon
left join MonSubmissionRecordForm rf on fii.InstanceID = rf.ID  
left join MonSubmissionRecord r on rf.SubmissionRecordID = r.ID
left join MonSubmissions sub on r.SubmissionsID = sub.ID
left join OrgUnit ou on sub.OrgUnitID = ou.ID
left join RosterYear ry on sub.RosterYearID = ry.ID

-- single select
join FormInputSingleSelectValue ssv on fiv.ID = ssv.ID -- and a.InputItemType = 'SingleSelect' -- inner join, not nec to check a.inputitemtype
left join FormTemplateInputSelectFieldOption sfo on ssv.SelectedOptionID = sfo.ID

where fi.TemplateID = 'F87DC304-78EB-49DC-AB61-16EBDCA2174C' -- Compliance Checklist
and SubmissionAreaID in (
	'FD836CC5-ECE7-475D-8F4B-70B4E5A3E235'	-- Dates of Meeting (Confirm dates with evidence in the file)
	, 'AB755A6C-83D3-4594-9DFE-83CD52FE7CFD' -- Present Levels of Academic Achievement and Functional Performance
	, '97075423-230C-4D80-99C5-C8053D08615B' -- Post-School Considerations
	, '3FDCF6FB-8270-400B-BB6D-3A241FCD675A' -- Annual Goals/Objectives
	, '4E87012B-8E77-46DA-A1ED-728E4E2E8C71' -- Accommodations and Modifications
	, 'CE9CF93B-7EF0-417C-BE5D-CE97BF5A7E67' -- State/District Assessments
	, '660326E3-1C67-4248-B82D-B72E29561699' -- Service Delivery Statement
	, '8C783B24-F2D3-4A2A-AE5D-1D7256D144A5' -- Recommended Placement in the LRE
	, 'CDCBDA88-1D38-4EA4-A7E7-875046A21BC0' -- Prior Written Notice
	, '14D8D04C-191F-429D-98C8-9FB1B8B7DF33' -- Appendix A: Early Childhood IEP
	, 'EA0784B9-9712-4291-962B-15147DCD3775' -- Appendix B: Evaluation/Reevaluation
	)
and ou.ID in (select OrgUnitID from UserProfileOrgUnit where UserProfileID = @userID)
and RosterYearID = @rosterYearID 
group by ou.Name, a.SubmissionMode, a.SubmissionAreaSequence, a.SubmissionAreaID, a.SubmissionAreaLabel
order by ou.name, SubmissionAreaSequence


declare 
	@userID uniqueidentifier= '546F8D65-330B-4EA2-B4D9-0992A8DA8384', 
	@rosterYearID uniqueidentifier = '83EEB57A-4E8C-449C-9543-7BDC3FE056C0', 
	@sectionID uniqueidentifier 


/*
	Leaving comments in the code for future troubleshooting if necessary.
	1. At one point the MonSubmissionArea ID was used to filter required sections, but this can change when the formlet changes.
		Use the FormTemplateControl ID instead.
	2. In this version of the query the CTE looks only at the Formlet metadata, and later left joins to the MonSubmissionArea
	3. 

*/
; with iiCTE as (
	select TemplateID = t.ID
		, TemplateName = t.Name
		, LayoutID = tl.ID 
		, LayoutControlID = tl.ControlId -- aka InputAreaID
		, ControlIsRepeatable = tc.IsRepeatable
		, LayoutParentID = tl.ParentId 
		, LayoutSequence = tl.Sequence --- will always be zero in the anchor
		, DisplaySequence = cast(100+tl.Sequence as varchar(max)) -- add 100 for sorting in alpha order 
		, CTELevel = 0 -- keep this consistent with other formlet sequences that start at 0
	from FormTemplate t 
	left join FormTemplateLayout tl on t.ID = tl.TemplateID
	left join FormTemplateControl tc on tl.ControlID = tc.Id
	where t.ID = 'F87DC304-78EB-49DC-AB61-16EBDCA2174C'
	and tl.ParentId is null
	
	union all 

	select c.TemplateID
		, c.TemplateName
		, LayoutID = tl.ID 
		, LayoutControlID = tl.ControlId -- aka InputAreaID
		, ControlIsRepeatable = tc.IsRepeatable
		, LayoutParentID = tl.ParentId 
		, LayoutSequence = tl.Sequence 
		, DisplaySequence = c.DisplaySequence+'_'+cast(100+tl.Sequence as varchar(max)) -- add 100 for sorting in alpha order 
		, CTELevel = c.CTELevel+1 
	from iiCTE c 
	join FormTemplateLayout tl on c.LayoutID = tl.ParentID
	join FormTemplateControl tc on tl.ControlID = tc.Id
)
, attributesCTE as (
	select 
		c.TemplateID
		, SectionID = c2.LayoutControlID
		, Section = msa.Label -- SubmissionArea
		, SectionSequence = msa.Sequence -- AreaSequence
		, AttributeID = ii.ID
		, ShortName = isnull(ii.reportlabel, ii.code) -- Attribute
		, Sequence = row_number() over (partition by c.TemplateID order by c.DisplaySequence+isnull('_'+cast(100+ii.Sequence as varchar(max)),''))
		, AttributeType = iit.Name -- InputItemType
		, IsNote = case when row_number() over (partition by c2.TemplateID, c2.LayoutControlID order by c.DisplaySequence+isnull('_'+cast(100+ii.Sequence as varchar(max)),'') desc) = 1 then 1 else 0 end
		, Statement = ii.Label -- InputItemLabel
		, ii.Code
		, ii.ReportLabel
		--, DisplaySequence = c.DisplaySequence+isnull('_'+cast(100+ii.Sequence as varchar(max)),'')
		--	, '	, '''+convert(varchar(36), a.LayoutControlID)+''' -- '+msa.Label -- use this to get the list of ControlIDs to filter by (paste into this query and delete the rows that are nto required).
	from iiCTE c
	join iiCTE c2 on c.LayoutParentID = c2.LayoutID 
	join FormTemplateInputItem ii on c.LayoutControlID = ii.InputAreaId 
	left join FormTemplateInputItemType iit on ii.TypeId = iit.Id
	left join MonSubmissionArea msa on c2.LayoutControlID = msa.FormTemplateControlID
)

, formDataDetail as (
	select [Administrative Unit] = ou.Name
		, SASID = rav.Value
		--, InstanceID = fi.ID
		--, RecordID = r.ID
		--, a.SectionID
		, a.Section
		, StatementSequence = a.Sequence 
		, a.ShortName
		, a.Statement
		--, a.ReportLabel
		--, a.AttributeID
		, a.IsNote
		, Value =
			case 
				when AttributeType = 'SingleSelect' then convert(varchar(max), sfo.Label) -- note: We can use Label instead of ReportLabel -- ReportLabel = Met, Label = Yes
				when AttributeType = 'Text' then convert(varchar(max), tv.Value)
			end
	from FormInstance fi
	left join FormInstanceInterval fii on fi.ID = fii.InstanceID
	left join FormInputValue fiv on fii.ID = fiv.IntervalID
	left join attributesCTE a on fiv.InputFieldId = a.AttributeID -- inner join or else null attribute (text)
	-- mon
	left join MonSubmissionRecordForm rf on fii.InstanceID = rf.ID  
	left join MonSubmissionRecord sr on rf.SubmissionRecordID = sr.ID
	left join MonRecordSelection rs on sr.RecordSelectionID = rs.ID
	left join MonRecord r on rs.RecordID = r.ID -- note the difference between Submission Record and Record
	left join MonSubmissions sub on sr.SubmissionsID = sub.ID
	left join OrgUnit ou on sub.OrgUnitID = ou.ID
	left join RosterYear ry on sub.RosterYearID = ry.ID

	-- single select
	left join FormInputSingleSelectValue ssv on fiv.ID = ssv.ID -- and a.InputItemType = 'SingleSelect' -- inner join, single select only - not nec to check a.inputitemtype
	left join FormTemplateInputSelectFieldOption sfo on ssv.SelectedOptionID = sfo.ID

	-- text
	left join FormInputTextValue tv on fiv.Id = tv.Id

	-- SASID
	left join MonRecordAttributeValue rav on r.ID = rav.RecordID and rav.AttributeID = '1BDFF8C6-44FE-477B-8C82-2439C5355C57'
-- 	left join MonRecordAttribute ra on rav.AttributeID = ra.ID

	where fi.TemplateID = 'F87DC304-78EB-49DC-AB61-16EBDCA2174C' -- Compliance Checklist
	and rs.ExcludedDate is null
	--and ou.ID in (select OrgUnitID from UserProfileOrgUnit where UserProfileID = @userID)
	--and RosterYearID = @rosterYearID 

	---- TESTING
 		and ou.ID = '3B26E265-39EA-422D-A17C-B8C8D9E312D8'
	---- TESTING
)


--select SASID, count(*) tot 
select * 
from formDataDetail 
where SASID = '3759523282'
--group by SASID
order by SASID, StatementSequence



--select * from MonRecord where ID = '441A3DF8-E865-45CB-B0E2-48D5E88BA48E'

--exec x_DATATEAM.FindGuid '441A3DF8-E865-45CB-B0E2-48D5E88BA48E'

--select * from dbo.MonSubmissionRecord where ID = '441A3DF8-E865-45CB-B0E2-48D5E88BA48E' -- as opposed to MonRecord
--	select * from MonRecordSelection rs where ID = 'E7DF2A99-040E-4D44-9FA0-6DDBBC83979F'
--select * from dbo.MonSubmissionRecordForm where SubmissionRecordID = '441A3DF8-E865-45CB-B0E2-48D5E88BA48E'


--select * from MonRecord where ID = '308195AB-760A-4CC1-A8ED-2067B2B505D3'

--select * from MOnRecordAttribute

--select * from MonRecordAttributeValue where RecordID = '308195AB-760A-4CC1-A8ED-2067B2B505D3'




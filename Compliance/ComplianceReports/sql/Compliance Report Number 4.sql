
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
	where c2.LayoutControlID in (
		'7AA6797C-9F89-462A-B667-34F821F8D325' -- Dates of Meeting (Confirm dates with evidence in the file)
		, '4249765D-446C-4199-9A4A-1961C6CD81C2' -- Present Levels of Academic Achievement and Functional Performance
		, 'C4404A98-12EB-4791-8341-8E21FAF7E553' -- Post-School Considerations
		, 'B66A23BC-4292-4F42-A73B-1025C6A0A8C7' -- Annual Goals/Objectives
		, '0574F0D4-2A51-41E2-BC1D-DFCFF34CE0A0' -- Accommodations and Modifications
		, '67373EE2-C726-4E60-864B-AA66EDF9D71F' -- State/District Assessments
		, 'AEFB23A3-4DAE-4B7E-8C2F-1D620584D814' -- Service Delivery Statement
		, '367FBEB2-DC15-4E78-B2ED-9CF12D05F59E' -- Recommended Placement in the LRE
		, '98DA711A-5190-474E-8636-8CD8330C63BC' -- Prior Written Notice
		, '2498D42E-85DE-484B-B609-E9823B6C99B1' -- Appendix A: Early Childhood IEP
		, '500F3BAE-FFE7-4876-A2D8-B79DF0D3B300' -- Appendix B: Evaluation/Reevaluation
	) 
)

, sectionStatementCount as (
	select a.SectionID, a.Section, a.SectionSequence, Total = count(*) 
	from attributesCTE a
	where a.AttributeType = 'SingleSelect'
	group by a.SectionID, a.Section, a.SectionSequence
)

, formDataDetail as (
	select [Administrative Unit] = ou.Name
		, a.SectionID
		, a.Section
		, a.ShortName
		, a.Statement
		, a.ReportLabel
		, a.AttributeID
		-- One Annual Goals Statement is to be considered with the Post-Secondary data calculation. We are increasing the sequence number to differentiate it.
		, StatementSequence = case when a.Section = '' then 700+a.Sequence else a.Sequence end -- setting the sequence again here..
		, InstanceID = fi.ID
		, Yes = case when sfo.ReportLabel = 'Met' then 1 when sfo.ReportLabel = 'Not Applicable' then 1 else 0 end
		--, ac.SectionCount
		--, rs.ExcludedDate
	from FormInstance fi
	left join FormInstanceInterval fii on fi.ID = fii.InstanceID
	left join FormInputValue fiv on fii.ID = fiv.IntervalID
	join attributesCTE a on fiv.InputFieldId = a.AttributeID -- inner join or else null attribute (text)
	-- mon
	left join MonSubmissionRecordForm rf on fii.InstanceID = rf.ID  
	left join MonSubmissionRecord r on rf.SubmissionRecordID = r.ID
	left join MonRecordSelection rs on r.RecordSelectionID = rs.ID
	left join MonSubmissions sub on r.SubmissionsID = sub.ID
	left join OrgUnit ou on sub.OrgUnitID = ou.ID
	left join RosterYear ry on sub.RosterYearID = ry.ID

	-- single select
	join FormInputSingleSelectValue ssv on fiv.ID = ssv.ID -- and a.InputItemType = 'SingleSelect' -- inner join, single select only - not nec to check a.inputitemtype
	left join FormTemplateInputSelectFieldOption sfo on ssv.SelectedOptionID = sfo.ID

	---- areaSectionCount
	--left join areaSectionCount ac on a.SubmissionAreaID = ac.SubmissionAreaID

	where fi.TemplateID = 'F87DC304-78EB-49DC-AB61-16EBDCA2174C' -- Compliance Checklist
	and ou.ID in (select OrgUnitID from UserProfileOrgUnit where UserProfileID = @userID)
	and RosterYearID = @rosterYearID 
	and rs.ExcludedDate is null

	---- TESTING
 		--and ou.ID = '3B26E265-39EA-422D-A17C-B8C8D9E312D8'
	---- TESTING
)
, AUSampleSize as (
	select [Administrative Unit] = case when grouping([Administrative Unit]) = 0 then [Administrative Unit] else 'State' end
		, SortBit = grouping([Administrative Unit])
		, IEPCount = count(distinct InstanceID) 
	from formDataDetail
	group by rollup([Administrative Unit])
)
, instanceCounts as (
	select fdd.[Administrative Unit]
		, fdd.InstanceID
		, InstanceYesCount = sum(fdd.Yes) 
		, SectionCount = max(ac.Total)
	from formDataDetail fdd
	left join sectionStatementCount ac on fdd.SectionID = ac.SectionID
	group by fdd.[Administrative Unit], fdd.InstanceID
)
, AUCounts as (
	select [Administrative Unit] = case when grouping([Administrative Unit]) = 0 then [Administrative Unit] else 'State' end
		, SectionID
		, Section
		, ShortName -- SectionLabel
		, Statement -- InputItemLabel
		, ReportLabel
		, AttributeID
		, StatementSequence
		, ItemYesCount = sum(fdd.Yes)
		, SortBit = grouping([Administrative Unit])
	from formDataDetail fdd
	group by rollup([Administrative Unit]), SectionID, Section, ShortName, Statement, StatementSequence, ReportLabel, AttributeID
)

select *
from (
select 
	Section = case when @sectionID = '97075423-230C-4D80-99C5-C8053D08615B' then 'Post-School Considerations' else ac.Section end
	, ac.[Administrative Unit]
	, ac.ShortName
	--, ReportLabel
	, Statement
	, ac.StatementSequence
	, PerItemPct = cast(round((ac.ItemYesCount/cast(ss.IEPCount as float))*100, 2) as decimal(5,1))
		--, ss.IEPCount
		--, ac.ItemYesCount
	, ac.SortBit
from AUCounts ac
left join AUSampleSize ss on ac.[Administrative Unit] = ss.[Administrative Unit]
) t
order by SortBit, [Administrative Unit], StatementSequence


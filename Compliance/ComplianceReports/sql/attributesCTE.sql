
-- select * from UserProfile where username = 'enrich:julielott'
-- select * from rosteryear where StartYear = 2014


--in this one remove the Mon referenes in the root CTE, and add them in another CTE later. This will limit the root CTE to the 208 rows.

declare @userID uniqueidentifier, @rosterYearID uniqueidentifier
select @userID = '546F8D65-330B-4EA2-B4D9-0992A8DA8384', @rosterYearID = '83EEB57A-4E8C-449C-9543-7BDC3FE056C0'

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
		, c2.LayoutControlID
		, AttributeID = ii.ID
		, Attribute = isnull(ii.reportlabel, ii.code)
		, Sequence = row_number() over (partition by c.TemplateID order by c.DisplaySequence+isnull('_'+cast(100+ii.Sequence as varchar(max)),''))
		, InputItemType = iit.Name
		, IsNote = case when row_number() over (partition by c2.TemplateID, c2.LayoutControlID order by c.DisplaySequence+isnull('_'+cast(100+ii.Sequence as varchar(max)),'') desc) = 1 then 1 else 0 end
		, InputItemLabel = ii.Label
		, ii.Code
		, ii.ReportLabel
		--, DisplaySequence = c.DisplaySequence+isnull('_'+cast(100+ii.Sequence as varchar(max)),'')
	from iiCTE c
	join iiCTE c2 on c.LayoutParentID = c2.LayoutID 
	join FormTemplateInputItem ii on c.LayoutControlID = ii.InputAreaId 
	left join FormTemplateInputItemType iit on ii.TypeId = iit.Id
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
select 
	Section = msa.Label -- SubmissionArea
	, SectionSequence = msa.Sequence -- AreaSequence
	, a.AttributeID
	, AttributeType = a.InputItemType
	, a.Sequence
	, ShortName = a.Attribute
	, a.IsNote
	, Statement = a.InputItemLabel -- named it differently here and in CTE to show origination path (too many names in too many places).
	--	, '	, '''+convert(varchar(36), a.LayoutControlID)+''' -- '+msa.Label -- use this to get the list of ControlIDs to filter by (paste into this query and delete the rows that are nto required).
from attributesCTE a
join MonSubmissionArea msa on a.LayoutControlID = msa.FormTemplateControlID
order by Sequence






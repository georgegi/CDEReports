
if object_id('x_DATATEAM.Compliance_Formlet_Attributes') is not null
drop view x_DATATEAM.Compliance_Formlet_Attributes
go

create view x_DATATEAM.Compliance_Formlet_Attributes
as
with iiCTE as (
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
) -- select * from iiCTE

select 
	c.TemplateID
-- SubmissionAreas correlate to the Sections of an IEP
	, SectionID = msa.ID
	, Section = msa.Label -- SubmissionArea
	, SectionSequence = msa.Sequence -- AreaSequence
-- Attributes are the statements (or questions) for each of the Sections
	, AttributeID = ii.ID
	, ShortName = isnull(ii.reportlabel, ii.code) -- Attribute
	, Sequence = row_number() over (partition by c.TemplateID order by c.DisplaySequence+isnull('_'+cast(100+ii.Sequence as varchar(max)),''))
	, AttributeType = iit.Name -- InputItemType
	, IsNote = case when row_number() over (partition by c2.TemplateID, c2.LayoutControlID order by c.DisplaySequence+isnull('_'+cast(100+ii.Sequence as varchar(max)),'') desc) = 1 then 1 else 0 end
	, Statement = ii.Label -- InputItemLabel
	, ii.Code
	, ii.ReportLabel
	--	, '	, '''+convert(varchar(36), a.LayoutControlID)+''' -- '+msa.Label -- use this to get the list of ControlIDs to filter by (paste into this query and delete the rows that are nto required).
from iiCTE c
join iiCTE c2 on c.LayoutParentID = c2.LayoutID 
join FormTemplateInputItem ii on c.LayoutControlID = ii.InputAreaId 
left join FormTemplateInputItemType iit on ii.TypeId = iit.Id
left join MonSubmissionArea msa on c2.LayoutControlID = msa.FormTemplateControlID
go

grant select on x_DATATEAM.Compliance_Formlet_Attributes to public
go

sp_refreshview 'x_DATATEAM.Compliance_Formlet_Attributes'
go




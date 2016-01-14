if object_id('x_DATATEAM.MonFormletColumns') is not null
drop view x_DATATEAM.MonFormletColumns
go

create view x_DATATEAM.MonFormletColumns
as
with iiCTE as (
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
-- x_datateam.findguid '944F0B10-8733-4D8C-BBAA-BC4B73891BEF'
	left join MonProgram p on loc.ProgramID = p.ID
	left join FormTemplate t on mst.FormTemplateID = t.ID
	left join FormTemplateLayout tl on t.ID = tl.TemplateID
	left join FormTemplateControl tc on tl.ControlID = tc.Id
	left join FormTemplateControlType tct on tc.TypeID = tct.ID
	where tl.ParentId is null

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

select 
	c.TemplateID
	, c.LocationID
	, c.SubmissionTypeID
	, c.SubmissionModeID
	, c.Location, c.SubmissionType, c.SubmissionMode, c.TemplateName
	, DisplaySequence = c.DisplaySequence+isnull('_'+cast(100+ii.Sequence as varchar(max)),'')
	, AttributeSequence = row_number() over (partition by Location, SubmissionType, SubmissionMode, TemplateName order by c.DisplaySequence+isnull('_'+cast(100+ii.Sequence as varchar(max)),''))
	, c.ControlType
	, InputItemType = iit.Name
	, ControlProperty = cp.Name
	, AttributeID = ii.ID
	, ii.ReportLabel
	, ii.Code
	, Attribute = isnull(ii.reportlabel, ii.code)
	, ii.ReportWeight
	, ii.Label
from iiCTE c
join FormTemplateInputItem ii on c.InputAreaID = ii.InputAreaId 
left join FormTemplateInputItemType iit on ii.TypeId = iit.Id
left join FormTemplateControlProperty cp on c.InputAreaID = cp.ControlId and cp.Name <> 'Level' and cp.Value <> 'sparse' 
left join MonSubmissionItem mii on ii.id = mii.FormTemplateInputItemID
-- order by Location, SubmissionType, SubmissionMode, TemplateName, IntSequence
go

grant select on x_DATATEAM.MonFormletColumns to public
go

exec sp_refreshview 'x_DATATEAM.MonFormletColumns'
go

--select Sequence = -1, 'select InstanceID'
--union all
--select AttributeSequence, '	, ['+Attribute+'] = max(case when AttributeID = '''+convert(varchar(36), AttributeID)+''' then Value end)'
--from x_DATATEAM.MonFormletColumns c
--where TemplateName = 'Post-School Outcome Survey'
--union all
--select 999, 'from x_DATATEAM.MonFormlet_Key_Attribute_Value 
--where TemplateID = '''+convert(varchar(36), TemplateID)+'''
--group by InstanceID
--'
--from (select top 1 TemplateID from x_DATATEAM.MonFormletColumns where TemplateName = 'Post-School Outcome Survey') x


/*



select Sequence, '	, ['+Attribute+'] = max(case when c.AttributeID = '''+convert(varchar(36), AttributeID)+''' then Value end)'
from x_DATATEAM.MonFormletColumns c
where TemplateName = 'Post-School Outcome Survey'



select distinct Sequence, '	, ['+Attribute+'] = max(case when c.AttributeID = '''+convert(varchar(36), AttributeID)+''' then Value end)'
from x_DATATEAM.MonFormletColumns c
where TemplateName = 'Compliance Checklist'
-- and SubmissionModeID = @SubmissionModeID


*/



/*


select TemplateName, count(distinct AttributeID)
from x_DATATEAM.FormletColumns
group by TemplateName
order by 1


select TemplateName, count(distinct SubmissionModeID)
from x_DATATEAM.FormletColumns
group by TemplateName
order by 1

select TemplateName, ModeCount = count(distinct SubmissionModeID), FieldCount = count(distinct AttributeID)
from x_DATATEAM.FormletColumns
group by TemplateName
order by 1

select *
from x_DATATEAM.FormletColumns
where TemplateName = 'Compliance Checklist'
and InputItemID = '5F341056-5935-4F9C-8717-01E3F4A9061C'


*/

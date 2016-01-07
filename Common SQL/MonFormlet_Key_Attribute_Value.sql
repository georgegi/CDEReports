USE [CDE_Prodreal]
GO

/****** Object:  View [x_DATATEAM].[MonFormlet_Key_Attribute_Value]    Script Date: 1/7/2016 3:14:45 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


create view [x_DATATEAM].[MonFormlet_Key_Attribute_Value]
as
with iiCTE as (
	select Location = loc.DisplayName
		, SubmissionType = mst.Name
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
	left join MonLocation loc on mst.LocationID = loc.ID
	left join MonProgram p on loc.ProgramID = p.ID
	left join FormTemplate t on mst.FormTemplateID = t.ID
	left join FormTemplateLayout tl on t.ID = tl.TemplateID
	left join FormTemplateControl tc on tl.ControlID = tc.Id
	left join FormTemplateControlType tct on tc.TypeID = tct.ID
	where tl.ParentId is null

	union all 

	select c.Location
		, c.SubmissionType
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
), 
frmdata as (
	select c.Location
		, c.SubmissionType
		, AU = ou.Name
		, AUCode = ou.Number
		, OrgUnitID = ou.ID
		, RosterYearID = ry.ID
		, RosterYear = convert(char(4), StartYear)+' - '+ right(convert(char(4), StartYear+1), 2)
		, c.TemplateID
		, c.TemplateName
		, AttributeID = ii.Id
		, miiLabel = mii.Label
		, ControlProperty = cp.Value
		, AttributeCode = ii.Code
		, AttributeReportLabel = ii.ReportLabel
		, AttributeLabel = ii.Label
		, InputItemType = iit.Name
		, DisplaySequence = c.DisplaySequence+isnull('_'+cast(100+ii.Sequence as varchar(max)),'') -- add 100 for sorting in alpha order 
		, InputItemSequence = ii.Sequence
		, miiSequence = mii.Sequence
		, InstanceID = fi.Id
		, rf.SubmissionRecordID
		, Value = convert(varchar(max), case 
					when iit.Name = 'SingleSelect' then isnull(sfo.ReportLabel, sfo.Label)
					when iit.name = 'Text' then txv.Value
					when iit.name = 'Date' then convert(varchar, dtv.Value, 101)
					when iit.name = 'Flag' then convert(varchar(5), flv.Value)
				end)
		--, LikertScore = case when ReportWeight is null then NULL else sfo.Sequence+1 end
		, ii.ReportWeight
		, ValueSequence = sfo.Sequence
		, SelectFieldLabel = convert(varchar(max), case 
			when iit.Name = 'SingleSelect' then sfo.Label
			when iit.name = 'Text' then txv.Value
			when iit.name = 'Date' then convert(varchar, dtv.Value, 101)
			when iit.name = 'Flag' then convert(varchar(5), flv.Value)
		end)
		--, WeightedScore = case when ReportWeight is null then NULL else sfo.Sequence+1 end*ii.ReportWeight
	from MonSubmissionRecordForm rf
	left join MonSubmissionRecord r on rf.SubmissionRecordID = r.ID
	left join MonSubmissions sub on r.SubmissionsID = sub.ID
	left join OrgUnit ou on sub.OrgUnitID = ou.ID
	left join RosterYear ry on sub.RosterYearID = ry.ID
-- form data
	left join FormInstance fi on rf.ID = fi.ID -- c.TemplateID = fi.TemplateID
	left join FormInstanceInterval fii on fi.ID = fii.InstanceID 
	left join FormInputValue fiv on fii.ID = fiv.IntervalID -- and ii.Id = fiv.InputFieldId
	left join iiCTE c on fi.TemplateId = c.TemplateID
	left join FormTemplateInputItem ii on c.InputAreaID = ii.InputAreaId and fiv.InputFieldId = ii.Id 
	left join FormTemplateInputItemType iit on ii.TypeId = iit.Id
	left join FormTemplateControlProperty cp on c.InputAreaID = cp.ControlId and cp.Name <> 'Level' and cp.Value <> 'sparse' 
	left join MonSubmissionItem mii on ii.id = mii.FormTemplateInputItemID
-- text
	left join FormInputTextValue txv on fiv.Id = txv.Id and iit.name = 'Text'
-- single select
	left join FormInputSingleSelectValue ssv on fiv.ID = ssv.ID and iit.Name = 'SingleSelect'
	left join dbo.FormTemplateInputSelectFieldOption sfo on ssv.SelectedOptionID = sfo.ID
-- date
	left join FormInputDateValue dtv on fiv.ID = dtv.ID and iit.Name = 'Date' -- select * from FormTemplateInputItemType
-- flag
	left join FormInputFlagValue flv on fiv.Id = flv.Id and iit.Name = 'Flag' 
	where ii.Id is not null
)

select f.Location,
	f.SubmissionType,
	OrgUnitID,
	RosterYearID,
	RosterYear,
	AU,
	AUCode,
	f.TemplateID,
	f.TemplateName, 
	f.AttributeID, 
	miiLabel, 
	ControlProperty, 
	AttributeCode, 
	AttributeReportLabel, 
	AttributeLabel, 
	f.InputItemType, 
	DisplaySequence, 
	InputItemSequence, 
	miiSequence, 
	InstanceID, 
	SubmissionRecordID, 
	Value,
	SelectFieldLabel,
	ReportWeight,
	Weighted = cast(NULL as bit)
from frmdata f

union all
---- add a row for likert score
select f.Location,
	f.SubmissionType,
	OrgUnitID,
	RosterYearID,
	RosterYear,
	AU,
	AUCode,
	f.TemplateID,
	f.TemplateName, 
	f.AttributeID, miiLabel, 
	ControlProperty, 
	AttributeCode = 'L'+AttributeCode, 
	AttributeReportLabel = 'Likert Score '+AttributeCode, 
	AttributeLabel = 'Likert Score '+AttributeCode, 
	InputItemType = 'Derived', 
	DisplaySequence = 'B'+DisplaySequence, 
	InputItemSequence, 
	miiSequence, 
	InstanceID, 
	SubmissionRecordID, 
	Value = cast(ValueSequence+1 as varchar(max)),
	SelectFieldLabel,
	ReportWeight,
	Weighted = cast(0 as bit)
from frmdata f 
where ReportWeight is not null

union all
---- add a row for weighted score
select f.Location,
	f.SubmissionType,
	OrgUnitID,
	RosterYearID,
	RosterYear,
	AU,
	AUCode,
	f.TemplateID,
	f.TemplateName, 
	f.AttributeID, 
	miiLabel, 
	ControlProperty, 
	AttributeCode = 'W'+AttributeCode, 
	AttributeReportLabel = 'Weighted Score '+AttributeCode, 
	AttributeLabel = 'Weighted Score '+AttributeCode, 
	InputItemType = 'Derived', 
	DisplaySequence = 'C'+DisplaySequence, 
	InputItemSequence, 
	miiSequence, 
	InstanceID, 
	SubmissionRecordID, 
	Value = cast((ValueSequence+1)*ReportWeight as varchar(max)),
	SelectFieldLabel,
	ReportWeight,
	Weighted = cast(1 as bit)
from frmdata f 
where ReportWeight is not null


GO



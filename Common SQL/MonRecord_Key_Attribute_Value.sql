
if object_id('x_DATATEAM.MonRecord_Key_Attribute_Value') is not null
drop view x_DATATEAM.MonRecord_Key_Attribute_Value
go


create view x_DATATEAM.MonRecord_Key_Attribute_Value
as
with recdata as (
	select 
		SubmissionsID = subs.ID
		, st.LocationID 
		, subs.SubmissionTypeID
		, subs.SubmissionModeID
		, subs.RosterYearID
		, reca.RecordSetID
		, recsel.RecordID
		, srf.SubmissionRecordID
		, InstanceID = srf.ID
		, OrgUnitID = ou.ID
		, Location = loc.DisplayName
		, SubmissionType = st.Name
		, SubmissionMode = sm.Name
		, RecordSet = rs.Name
		, AU = ou.Name
		, AUCode = isnull(ou.Number, 'Blank')
		, RosterYear = convert(char(4), StartYear)+'-'+right(convert(varchar(4), StartYear+1), 2)
		, AttributeID = reca.ID
		, AttributeSequence = reca.SequenceNumber
		, Attribute = reca.Name 
		, Col = reca.Name 
		, recav.Value
		, subs.StartedDate
		, subs.ClosedDate
		, TemplateID = st.FormTemplateID
		, SubmissionSequence = subrec.SequenceNumber+1
	from dbo.MonSubmissions subs 
	join dbo.MonSubmissionRecord subrec on subs.ID = subrec.SubmissionsID
	left join dbo.MonSubmissionRecordForm srf on subrec.ID = srf.SubmissionRecordID
	left join dbo.MonRecordSelection recsel on recsel.ID = subrec.RecordSelectionID
	left join dbo.OrgUnit ou on subs.OrgUnitID = ou.ID
	left join dbo.MonRecordAttributeValue recav on recsel.RecordID = recav.RecordID 
	left join dbo.MonRecordAttribute reca on recav.AttributeID = reca.ID
	left join dbo.MonSubmissionMode sm on subs.SubmissionModeID = sm.ID
	left join dbo.MonSubmissionType st on subs.SubmissionTypeID = st.ID
	left join dbo.MonLocation loc on st.LocationID = loc.ID
	left join dbo.MonRecordSet rs on reca.RecordSetID = rs.ID
	left join dbo.RosterYear ry on subs.RosterYearID = ry.ID
	where 1=1
		and subs.ReliabilityCheckOfSubmissionsID is null -- is not a reliability check
		and subs.DeletedDate is null 
		and recsel.ExcludedDate is null
)
--, DataLengths as (
--	select AttributeID, maxlenvalue = max(len(value))
--	from recdata
--	--where InputItemType in ('SingleSelect', 'Text')
--	group by AttributeID
--)
--, ColumnSizes as (
--	select AttributeID, maxlenvalue, ColumnDataType = 
--		case when cast(isnull(maxlenvalue, 20)*1.5 as int) > 3000 then 'varchar(max' else 'varchar('+cast(cast(isnull(maxlenvalue, 20)*1.5 as int) as varchar(5)) end+')'
--	from DataLengths
--)

--select r.*, z.ColumnDataType 
--from recdata r
--join ColumnSizes z on r.AttributeID = z.AttributeID

select * from recdata -- the columnsizes cte takes significantly longer to run. (37 seconds compared to immediate)
GO



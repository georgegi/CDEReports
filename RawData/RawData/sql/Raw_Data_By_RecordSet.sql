/*

select Location = loc.DisplayName, ParentSetID = parentSet.ID, ParentSetName = parentset.Name
from MonSubmissions subs -- there are submissions that are "based on" individual records, not sets
left join MonSubmissionType mst on subs.SubmissionTypeID = mst.ID
left join MonSubmissionMode msm on subs.SubmissionModeID = msm.ID
left join MonRecordSet childSet on subs.RecordSetID = childSet.ID
	and subs.DeletedDate is null 
	and subs.ReliabilityCheckOfSubmissionsID is null
left join MonRecordSet parentSet on childSet.SampledFromID = parentSet.ID
left join MonRecordAttribute a on parentSet.ID = a.RecordSetID
left join OrgUnit ou on subs.OrgUnitID = ou.ID
left join MonLocation loc on mst.LocationID = loc.ID
left join MonProgram p on loc.ProgramID = p.ID
left join (select RecordSetID from MonRecordAttribute where RecordSetID is not null group by RecordSetID) att on parentSet.ID = att.RecordSetID
where 1=1
and att.RecordSetID is not null -- we only need recordsets that have attributes
and p.DisplayName = 'Special Education'
group by parentSet.ID, parentset.Name, loc.DisplayName


--select * from UserProfile where UserName = 'enrich:georgegi'


exec x_DATATEAM.Raw_Data_By_RecordSet '04E5044C-3FBE-42EE-9945-4E88BBD98B88', '1E3B056E-2F4E-40CA-9FD9-55D36C3254D6'



*/



if object_id('x_DATATEAM.Raw_Data_By_RecordSet') is not null
drop proc x_DATATEAM.Raw_Data_By_RecordSet
go


create proc x_DATATEAM.Raw_Data_By_RecordSet
	@userID uniqueidentifier,
	@recordSetID uniqueidentifier
as
-- declare @recordSetID uniqueidentifier = 'A6D0DC62-A691-4598-AECB-F48643F752CF', @userID uniqueidentifier = '04E5044C-3FBE-42EE-9945-4E88BBD98B88'

set nocount on;
SET FMTONLY OFF;

declare @qrec varchar(max)='' -- Query MonRecord data
	, @qfrm varchar(max)=''  -- Query MonForm data
	, @qsel varchar(max)='' -- Query MonRecordSelection data
	, @rcols varchar(max)='' -- Pivoted MonRecord columns
	, @fcols varchar(max)='' -- Pivoted MonForm columns
	, @rlist varchar(max)='' -- Record column names list
	, @flist varchar(max)='' -- Formlet column names list
	, @templateID varchar(36)='' -- varchar to use in dynamic SQL below
	, @sasidID varchar(36)='' -- varchar to use in dynamic SQL below
	, @bigq varchar(max) = '' -- we combine @qsel, @qrec and @qfrm into one big query


if(@recordSetID != '00000000-0000-0000-0000-000000000000')
BEGIN
;with recAttributes as (
select	-- Do we only need attributes from parent record sets? Some child sets exist without recordattributes (only formlet data?)
	Program = p.DisplayName
	, Location = loc.DisplayName
	, SubmissionType = mst.Name
	, TemplateID = mst.FormTemplateID
	, SubmissionMode = msm.Name
	, ParentSetID = childSet.SampledFromID
	, AttributeID = a.ID
	, Attribute = a.Name
	, AttributeSequence = a.SequenceNumber
	, AttributeType = 'Text'
from MonSubmissions subs -- there are submissions that are "based on" individual records, not sets
left join MonSubmissionType mst on subs.SubmissionTypeID = mst.ID
left join MonSubmissionMode msm on subs.SubmissionModeID = msm.ID
left join MonRecordSet childSet on subs.RecordSetID = childSet.ID
	and subs.DeletedDate is null 
	and subs.ReliabilityCheckOfSubmissionsID is null
left join MonRecordAttribute a on childSet.SampledFromID = a.RecordSetID -- SampledFromID is the parent recordset
left join OrgUnit ou on subs.OrgUnitID = ou.ID
left join MonLocation loc on mst.LocationID = loc.ID
left join MonProgram p on loc.ProgramID = p.ID
left join (select RecordSetID from MonRecordAttribute where RecordSetID is not null group by RecordSetID) att on childSet.SampledFromID = att.RecordSetID
where 1=1
and att.RecordSetID is not null -- we only need recordsets that have attributes (??)
and p.DisplayName = 'Special Education'
and childSet.SampledFromID = @recordSetID -- SampledFromID is the parent recordset
group by p.DisplayName
	, loc.DisplayName
	, mst.Name
	, msm.Name
	, childSet.SampledFromID
	, a.ID
	, a.Name
	, a.SequenceNumber 
	, FormTemplateID
)
, iiCTE as (
	select 
		  TemplateID = t.ID
		, TemplateName = t.Name
		, LayoutID = tl.ID 
		, InputAreaID = tl.ControlId
		, tl.ParentId 
		, tlSequence = tl.Sequence --- will always be zero in the anchor
		, CTELevel = 0 -- keep this consistent with other formlet sequences that start at 0
		, ControlType = tct.Name
		, ControlIsRepeatable = tc.IsRepeatable
		, DisplaySequence = cast(100+tl.Sequence as varchar(max)) -- add 100 for sorting in alpha order 
	from (
			select TemplateID
			from recAttributes 
			group by TemplateID
		) ra
		left join FormTemplate t on ra.TemplateID = t.ID
		left join FormTemplateLayout tl on t.ID = tl.TemplateID
		left join FormTemplateControl tc on tl.ControlID = tc.Id
		left join FormTemplateControlType tct on tc.TypeID = tct.ID
		where tl.ParentId is null

		union all 

		select 
			  c.TemplateID
			, TemplateName = t.Name
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
, frmAttributes as (
	select 
		  c.TemplateID
		, c.TemplateName
		, c.InputAreaID
		, c.ParentId
		, c.LayoutID
		, c.ControlType
		, InputItemType = iit.Name
		, AttributeID = ii.ID
		, DisplaySequence = c.DisplaySequence+isnull('_'+cast(100+ii.Sequence as varchar(max)),'')
		, AttributeSequence = row_number() over (partition by c.TemplateName order by c.DisplaySequence+isnull('_'+cast(100+ii.Sequence as varchar(max)),''))
		, Attribute = case when ii.ReportWeight is null then isnull(ii.reportlabel, ii.code) else ii.Code end
		, ii.ReportLabel
		, ii.Code
		, InputItemLabel = ii.Label
		, Weighted = case when ii.ReportWeight is null then 0 else 1 end
	from iiCTE c
	join iiCTE c2 on c.ParentID = c2.LayoutID 
	join FormTemplateInputItem ii on c.InputAreaID = ii.InputAreaId 
	left join FormTemplateInputItemType iit on ii.TypeId = iit.Id
)
, pivotedAttributes as (
	select Type = 'Rec', r.TemplateID, r.AttributeID, r.Attribute, r.AttributeSequence, r.AttributeType
		, ColumnExpression = '	, ['+Attribute+'] = max(case when (x.AttributeID = '''+convert(varchar(36), r.AttributeID)+''') then Value end)'
	from recAttributes r
	union all
	select Type = 'Frm', f.TemplateID, f.AttributeID, f.Attribute, f.AttributeSequence, AttributeType = f.InputItemType
		, ColumnExpression = '	, ['+Attribute+'] = max(case when (fiv.InputFieldID = '''+convert(varchar(36), f.AttributeID)+''') then '+
			case 
				when f.InputItemType = 'Text' then 'replace(replace(replace(replace(replace(replace(replace(replace(replace(convert(varchar(max), txv.Value), ''<span>'', ''''), ''</span>'', ''''), ''<p>'', ''''), ''</p>'', ''''), ''&nbsp'', ''''), '';'', ''''), char(13)+char(10), ''''), char(13), ''''), char(10), '''')' -- removing newlines because they don't import cleanly into Excel
				when f.InputItemType = 'Flag' then 'convert(varchar(10), flv.Value)'
				when f.InputItemType = 'Date' then 'convert(varchar, dtv.Value, 101)'
				when f.InputItemType = 'SingleSelect' then 'convert(varchar(max), sfo.Label)' -- may need to remove newlines here
				when f.InputItemtype = 'MultiSelect' then 'cast(''Multi-select data not pulled'' as varchar(max))' --- when multi-selects are added, the values should all be on one line with no CRLF, because the users export the output to CSV for import into Excel, and with CRLFs in the data the records do not import cleanly into Excel
					-- in the Peformance record sets, the following 2 fields are multi-select
					--Q11R	Reason(s) for leaving school early:
					--Q12R	Possible reason(s) student would have stayed:
				else 'CheckAttributeType'  -- the query will break (on purpose) if we find new datatypes that are not handled in the case statement. 
			end+' end)' 
	from frmAttributes f 
)
, tID as (
	select TemplateID
	from recAttributes 
	group by TemplateID
)
, sasidID as (
	select AttributeID from pivotedAttributes where Type = 'rec' and Attribute = 'SASID'
)

select 
	  @templateID = tID.TemplateID
	, @sasidID = sasidID.AttributeID
	, @rcols = @rcols + case when x.Type = 'Rec' then x.ColumnExpression else '' end +char(13)+char(10)
	, @fcols = @fcols + case when x.Type = 'Frm' then x.ColumnExpression else '' end +char(13)+char(10)
	, @rlist = @rlist + case when x.Type = 'Rec' then ', qr.['+x.Attribute+']' else '' end 
	, @flist = @flist + case when x.Type = 'Frm' then ', qf.['+x.Attribute+']' else '' end 
from pivotedAttributes x
cross join tID 
cross join sasidID
order by AttributeSequence

print @rlist
print @flist



select
	  @qrec = 'select RecordID = r.ID
'+@rcols+'from MonRecord r
join MonRecordSet rs on r.RecordSetID = rs.ID 
join MonRecordAttribute a on a.RecordSetID = rs.ID
join MonRecordAttributeValue x on r.ID = x.RecordID
	and x.AttributeID = a.ID 
where rs.ID = '''+convert(varchar(36), @recordSetID)+'''
group by r.ID'

	, @qfrm = 'select RecordID = r.ID
'+@fcols+'from MonRecordSet parentSet
join MonRecord r on parentSet.ID = r.RecordSetID
join MonRecordSelection sel on r.ID = sel.RecordID
join MonSubmissionRecord sr on sel.ID = sr.RecordSelectionID
join MonSubmissionRecordForm rf on sr.ID = rf.SubmissionRecordID
---- form data
left join FormInstance fi on rf.ID = fi.ID 
left join FormInstanceInterval fii on fi.ID = fii.InstanceID 
left join FormInputValue fiv on fii.ID = fiv.IntervalID

-- need the datatype, so we must join to FormTemplateInputItem again
left join FormTemplateInputItem ii on  fiv.InputFieldId = ii.Id 
left join FormTemplateInputItemType iit on ii.TypeId = iit.Id
left join FormTemplateControlProperty cp on ii.InputAreaId = cp.ControlId and cp.Name <> ''Level'' and cp.Value <> ''sparse''

left join FormInputTextValue txv on fiv.Id = txv.Id and iit.Name = ''Text''
-- single select
left join FormInputSingleSelectValue ssv on fiv.ID = ssv.ID and iit.Name = ''SingleSelect''
left join dbo.FormTemplateInputSelectFieldOption sfo on ssv.SelectedOptionID = sfo.ID
-- date
left join FormInputDateValue dtv on fiv.ID = dtv.ID and iit.Name = ''Date''
-- flag
left join FormInputFlagValue flv on fiv.Id = flv.Id and iit.Name = ''Flag''
where parentSet.ID = '''+convert(varchar(36), @recordSetID)+'''
and fi.TemplateID = '''+@templateID+'''
group by r.ID',

@qsel = '
		select
			  sel.RecordID
			, SubmissionRecordID = sr.ID
			, SubmissionSequence = sr.SequenceNumber
			, IsExcluded = case when sel.ExcludedDate is null then 0 else 1 end
			, sr.SubmissionsID
			, sr.RecordSelectionID
			, SASID = sasid.Value
			, AU = ou.Name
		from MonSubmissions subs 
		join MonSubmissionRecord sr on subs.ID = sr.SubmissionsID 
			and subs.DeletedDate is null
			and subs.ReliabilityCheckOfSubmissionsID is null
		left join MonRecordSet rs on subs.RecordSetID = rs.ID
		left join MonRecordSelection sel on subs.RecordSetID = sel.RecordSetID 
			and sr.RecordSelectionID = sel.ID 
		LEFT JOIN MonRecordAttributeValue sasid on sel.RecordID = sasid.RecordID and sasid.AttributeID = '''+@sasidID+'''
		LEFT JOIN OrgUnit ou on subs.OrgUnitID = ou.ID

		where rs.SampledFromID = '''+convert(varchar(36), @recordSetID)+'''
		and subs.OrgUnitID in (select OrgUnitID from UserProfileOrgUnit where UserProfileID = '''+convert(varchar(36), @userID)+''')
		'
,	@bigq = '
	select 
		qs.AU
		, qs.SASID as SASID2
		, qs.SubmissionSequence
		, qs.IsExcluded
		'+@rlist+'
		'+@flist+'
	from ('+@qsel+') qs
	INNER JOIN (
	select RecordID = r.ID
'+@rcols+'from MonRecord r
join MonRecordSet rs on r.RecordSetID = rs.ID 
join MonRecordAttribute a on a.RecordSetID = rs.ID
join MonRecordAttributeValue x on r.ID = x.RecordID
	and x.AttributeID = a.ID 
where rs.ID = '''+convert(varchar(36), @recordSetID)+'''
group by r.ID) qr on qs.RecordID = qr.RecordID

LEFT JOIN (select RecordID = r.ID
	'+@fcols+'from MonRecordSet parentSet
	join MonRecord r on parentSet.ID = r.RecordSetID
	join MonRecordSelection sel on r.ID = sel.RecordID
	join MonSubmissionRecord sr on sel.ID = sr.RecordSelectionID
	join MonSubmissionRecordForm rf on sr.ID = rf.SubmissionRecordID
	---- form data
	left join FormInstance fi on rf.ID = fi.ID 
	left join FormInstanceInterval fii on fi.ID = fii.InstanceID 
	left join FormInputValue fiv on fii.ID = fiv.IntervalID

	-- need the datatype, so we must join to FormTemplateInputItem again
	left join FormTemplateInputItem ii on  fiv.InputFieldId = ii.Id 
	left join FormTemplateInputItemType iit on ii.TypeId = iit.Id
	left join FormTemplateControlProperty cp on ii.InputAreaId = cp.ControlId and cp.Name <> ''Level'' and cp.Value <> ''sparse''

	left join FormInputTextValue txv on fiv.Id = txv.Id and iit.Name = ''Text''
	-- single select
	left join FormInputSingleSelectValue ssv on fiv.ID = ssv.ID and iit.Name = ''SingleSelect''
	left join dbo.FormTemplateInputSelectFieldOption sfo on ssv.SelectedOptionID = sfo.ID
	-- date
	left join FormInputDateValue dtv on fiv.ID = dtv.ID and iit.Name = ''Date''
	-- flag
	left join FormInputFlagValue flv on fiv.Id = flv.Id and iit.Name = ''Flag''
	where parentSet.ID = '''+convert(varchar(36), @recordSetID)+'''
	and fi.TemplateID = '''+@templateID+'''
	group by r.ID
	) qf on qr.RecordID = qf.RecordID
'

exec (@bigq)

go
END

grant exec on x_DATATEAM.Raw_Data_By_RecordSet to public
go


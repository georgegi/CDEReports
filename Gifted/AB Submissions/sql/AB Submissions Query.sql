

/*

select loc.ProgramID
	, LocationSequence = loc.Sequence
	--, Program = p.DisplayName
	--, t.LocationID
	, Location = loc.DisplayName
	--, m.SubmissionTypeID
	--, SubmissionType = t.Name
	--, SubmissionModeID = m.ID
	, SubmissionMode = m.Name
	, t.FormTemplateID
from MonProgram p
join MonLocation loc on p.ID = loc.ProgramID
join MonSubmissionType t on loc.ID = t.LocationID
join MonSubmissionMode m on t.ID = m.SubmissionTypeID
where loc.ProgramID = '58FFE83B-EA3A-4703-A505-023B8E306B64'
order by LocationSequence, SubmissionMode

--Profile	Annual Profile Review
--Profile	Comprehensive Program Plan
--Profile	Early Access Addendum
--Profile	Programming Details
--Profile	Programming Details Worksheet
--Monitoring	ALP Review
--Monitoring	AU Self Evaluation
--Fiscal	Annual Budget Review
--Fiscal	AU Budget: i. Proposed Budget (due April 15)
--Fiscal	AU Budget: ii. Adjusted Budget (due September 30)
--Fiscal	AU Budget: iii. Expended Budget (due for prior year September 30)
--Fiscal	BOCES & Multi District AU Working Budgets
--Fiscal	Gifted Education Universal Screening and Qualified Personnel Grant
--Family E & C	Family Engagement & Communication Review
--Performance	Performance Review
--Improvement	Improvement Timeline
--Improvement	Improvement Timeline Results


select * from UserProfile where UserName = 'enrich:georgegi'

*/

declare @userID uniqueidentifier = '04E5044C-3FBE-42EE-9945-4E88BBD98B88'


;with giftedStuff as (
	select t.LocationID
		, Location = loc.DisplayName
		, LocationSequence = loc.Sequence
		, m.SubmissionTypeID
		, SubmissionType = t.Name
		, SubmissionModeID = m.ID
		, SubmissionMode = m.Name
		, t.FormTemplateID
	from MonLocation loc 
	join MonSubmissionType t on loc.ID = t.LocationID
	join MonSubmissionMode m on t.ID = m.SubmissionTypeID
	where loc.ProgramID = '58FFE83B-EA3A-4703-A505-023B8E306B64' -- Gifted Education
	--order by Location, SubmissionType, SubmissionMode
)
, AUs as (
	select distinct subs.OrgUnitID, AU = ou.Name
	from MonSubmissions subs
	join OrgUnit ou on subs.OrgUnitID = ou.ID
	join giftedStuff g on subs.SubmissionTypeID = g.SubmissionTypeID
	where ou.ID in (select OrgUnitID from UserProfileOrgUnit where UserProfileID = @userID)

)
, rosterYears as (
	select distinct subs.RosterYearID, RosterYear = convert(char(4), ry.StartYear)+'-'+right(convert(varchar(4), ry.StartYear+1), 2)
	from MonSubmissions subs
	join RosterYear ry on subs.RosterYearID = ry.ID
	join giftedStuff g on subs.SubmissionTypeID = g.SubmissionTypeID
	where ry.StartYear > 2013
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
			select FormTemplateID
			from giftedStuff
			group by FormTemplateID
		) x
		left join FormTemplate t on x.FormTemplateID = t.Id
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

select aury.AU
	, aury.RosterYear
	, g.Location
	, g.SubmissionMode
	, subs.StartedDate
	, a.Code
	, a.InputItemLabel
	, sfo.Label
	, sfo.ReportLabel
from frmAttributes a
left join giftedStuff g on a.TemplateID = g.FormTemplateID
cross join (select * from AUs cross join rosterYears) aury 
left join MonSubmissions subs on g.SubmissionModeID = subs.SubmissionModeID -- 970
	and aury.OrgUnitID = subs.OrgUnitID
	and aury.RosterYearID = subs.RosterYearID
	and subs.DeletedDate is null -- 889
	and subs.ReliabilityCheckOfSubmissionsID is null -- 889
left join OrgUnit ou on subs.OrgUnitID = ou.ID
left join RosterYear ry on subs.RosterYearID = ry.ID
left join MonSubmissionRecord sr on subs.ID = sr.SubmissionsID -- 889
left join MonSubmissionRecordForm rf on sr.ID = rf.SubmissionRecordID -- 889
left join FormInstance fi on rf.ID = fi.Id -- 889
left join FormInstanceInterval fii on fi.Id = fii.InstanceId -- 889
left join FormInputValue fiv on fii.Id = fiv.IntervalId -- note that fiv has an IntervalID column, but this is something different
	and a.AttributeID = fiv.InputFieldId -- 889
	-- when left joining, we get 890 records!
left join FormInputSingleSelectValue ssv on fiv.Id = ssv.Id
left join FormTemplateInputSelectFieldOption sfo on ssv.SelectedOptionID = sfo.ID
where a.InputItemLabel like '%assistance%' -------------------------------------------------- may change this later to specific list
		--and aury.OrgUnitID = 'BAC758EC-E6DA-4D10-A6DB-A6207862B084'
		--and aury.RosterYearID = 'F9662967-A3BF-4677-819B-C809AB363CE9'
order by AU, RosterYear, g.LocationSequence, g.SubmissionMode, a.InputItemLabel






/*


-- select * from MonRecord where RecordSetID = 'E4E1CC93-ABC3-43C5-8D1E-0E45F7F4EB89' -- 1 record
select * from MonSubmissionRecord where SubmissionsID = '56C10745-31CE-4084-8182-0A7CE2CDCA0E'
-- select * from MonRecordSelection where ID = '11EA8187-D34D-4E3E-AD02-8890A89E9412'
select * from MonSubmissionRecordForm where SubmissionRecordID = '6A32EF35-0A33-4630-B1EE-B041E7A5F9B7' -- instance ID



-- select * from MonRecordSet where ID = 'E4E1CC93-ABC3-43C5-8D1E-0E45F7F4EB89'
-- select * from MonRecordSet where SampledFromID = 'E4E1CC93-ABC3-43C5-8D1E-0E45F7F4EB89'

select * from MonRecord where RecordSetID = 'E4E1CC93-ABC3-43C5-8D1E-0E45F7F4EB89' -- 1 record

select * from MonSubmissionRecord where SubmissionsID = '56C10745-31CE-4084-8182-0A7CE2CDCA0E'

--select * from MonRecordSelection where ID = '11EA8187-D34D-4E3E-AD02-8890A89E9412'


select * from MonSubmissionRecordForm where SubmissionRecordID = '6A32EF35-0A33-4630-B1EE-B041E7A5F9B7' -- instance ID



*/



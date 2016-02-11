

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



select * from UserProfile where UserName = 'enrich:georgegi'

*/

declare @userID uniqueidentifier = '04E5044C-3FBE-42EE-9945-4E88BBD98B88'


;with giftedStuff as (
	select t.LocationID
		, LocationSequence = loc.Sequence
		, Location = loc.DisplayName
		, m.SubmissionTypeID
		, SubmissionType = t.Name
		, SubmissionModeID = m.ID
		, SubmissionMode = m.Name
		, t.FormTemplateID
		, ModeSequence = row_number() over (partition by 1 order by loc.Sequence, t.name, case m.Name when 'Annual Budget Review' then 'AU Budget: Review' else m.name end)
	from MonLocation loc 
	join MonSubmissionType t on loc.ID = t.LocationID
	join MonSubmissionMode m on t.ID = m.SubmissionTypeID
	where loc.ProgramID = '58FFE83B-EA3A-4703-A505-023B8E306B64' -- Gifted Education
	and m.id not in (
		  '9BA63D26-C4E3-4ACF-AE78-8F9583CD4EE3'	-- Profile	Programming Details Worksheet
		, '7A85EDD5-DB08-423C-B29A-EDA17D3F10D5'	-- Fiscal	BOCES & Multi District AU Working Budgets
		)
	--order by LocationSequence, SubmissionType, case m.Name when 'Annual Budget Review' then 'AU Budget: Review' else m.name end
)
, AUs as (
	select distinct subs.OrgUnitID, AU = ou.Name
	from MonSubmissions subs
	join OrgUnit ou on subs.OrgUnitID = ou.ID
	join giftedStuff g on subs.SubmissionTypeID = g.SubmissionTypeID
	where ou.ID in (select OrgUnitID from UserProfileOrgUnit where UserProfileID = @userID)
	and subs.DeletedDate is null -- 889
	and subs.ReliabilityCheckOfSubmissionsID is null -- 889
	and ou.name not in ('TEST', 'TEST AU', 'SAML TEST - Douglas RE-1 Castle Rock')
)
, rosterYears as (
	select distinct subs.RosterYearID, RosterYear = convert(char(4), ry.StartYear)+'-'+right(convert(varchar(4), ry.StartYear+1), 2)
	from MonSubmissions subs
	join RosterYear ry on subs.RosterYearID = ry.ID
	join giftedStuff g on subs.SubmissionTypeID = g.SubmissionTypeID
	where 1=1
	and subs.DeletedDate is null -- 889
	and subs.ReliabilityCheckOfSubmissionsID is null -- 889
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
, results as (
	select aury.AU
		, aury.RosterYear
		, g.Location
		, g.SubmissionModeID
		, g.SubmissionMode
		, SubmissionDate = convert(varchar, subs.StartedDate, 101) -- convert to text later
		, a.Code
		, a.InputItemLabel
		, InstanceID = fi.Id
		, sfo.Label
		, g.ModeSequence
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
	where 
		a.InputItemLabel like '%assistance%' -------------------------------------------------- may change this later to specific list
		or
		(g.SubmissionModeID = '33F88AE5-682B-4EAF-BA73-8A3E14A036CE' and a.InputItemType = 'Date' and a.Code in ('Rev1', 'Rev2'))
)

select AU, RosterYear, Location, SubmissionMode, SubmissionModeID, ModeSequence, Attribute = 'SubmissionDate', AttributeSequence = 0, InputItemLabel = 'Date of Submission', Value = max(SubmissionDate)
from results r
group by AU, RosterYear, Location, SubmissionMode, SubmissionModeID, ModeSequence
union all
select AU, RosterYear, Location, SubmissionMode, SubmissionModeID, ModeSequence, Attribute = Code, AttributeSequence = 1, InputItemLabel, Value = r.Label
from results r
--where AU = 'Eagle Re 50, Eagle' -- testing 
order by AU, RosterYear, ModeSequence, AttributeSequence, Attribute, InputItemLabel


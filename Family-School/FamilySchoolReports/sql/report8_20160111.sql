--declare @userID uniqueidentifier, @language varchar(10), @disabMatch varchar(10), @AUonly varchar(10) ; select @userID = ID, @language = 'All', @disabMatch = 'All' from UserProfile where username = 'Enrich:julielott';
with vCTE as (
select 	
	fiv.InputFieldId,
	fii.InstanceID,
	--fiv.IntervalId,
	LayoutSequence = ftl.Sequence,
	InputItemSequence = ftii.Sequence+1,
	InputItemCode = ftii.code, 
	InputItemLabel = ftii.label,
	Response = cast(sfo.Label as varchar(max)),
	LikertScore = case when ftii.ReportWeight is null then NULL else sfo.Sequence+1 end,
	ftii.ReportWeight,
	OrgUnitID = ou.ID,
	AdminUnit = ou.Name
from FormInstanceInterval fii
left join FormInputValue fiv on fii.ID = fiv.IntervalID
left join FormTemplateInputItem ftii on fiv.InputFieldId = ftii.Id
left join FormTemplateLayout ftl on ftii.InputAreaID = ftl.ControlID
left join FormInputSingleSelectValue ssv on fiv.Id = ssv.Id
left join FormTemplateInputSelectFieldOption sfo on ssv.SelectedOptionId = sfo.ID and sfo.DeletedDate is null
left join dbo.MonSubmissionRecordForm subf on fii.InstanceID = subf.ID
left join dbo.MonSubmissionRecord subrec on subf.SubmissionRecordID = subrec.ID
left join dbo.MonSubmissions subs on subrec.SubmissionsID = subs.ID
left join dbo.OrgUnit ou on subs.OrgUnitID = ou.ID
where ftl.TemplateID = '77763BF6-1956-482B-9476-252613D08EB5'
and ftii.Id not in ('39A53975-620F-478D-8E01-DADCDA7C33C8', '16A4B3B9-71CD-4FFD-868F-E4091B26D9F2')
)
, pCTE as (
select 
	InstanceId
	, Lang = max(case when InputFieldId = '404A0FC4-2442-40E0-910B-75680AEF47C7' then Response end) -- Language
	, Submission = max(case when InputFieldId = '3448DDD2-D188-4A3B-8439-B52A39F91130' then Response end) -- Mail, Phone, Email
	, Reported = max(case when InputFieldId = '6B65E1F4-21CE-4223-B9F7-F610239A4E85' then Response end) -- Disability Match
	, LikertCount = count(LikertScore)
from vCTE 
group by InstanceId
)
, qCTE as (
select 
    --v.InputFieldId, v.InstanceID, v.LayoutSequence, v.InputItemSequence, v.InputItemCode, 
    Question = v.InputItemLabel, 
	Response = isnull(v.Response, 'Blank'), v.LikertScore, v.ReportWeight,
	p.Lang, p.Submission, DisabilityMatch = isnull(p.Reported, 'Blank'), v.OrgUnitID, v.AdminUnit
from vCTE v
join pCTE p on v.InstanceId = p.InstanceId and p.LikertCount > 0 
where v.ReportWeight is not null
--and v.InstanceId = 'BE1A1B00-1713-4B6D-8378-F54BD0045EA9'
--order by InputItemSequence
)
,x as (
	select 
		AdminUnit = case when grouping(AdminUnit) = 0 then AdminUnit else 'STATE' end -- set to STATE for group by rollup AdminUnit
		, Question = case when grouping(Question) = 0 then Question else 'Total' end 
		, LikertScore = avg(cast(LikertScore as float)) -- float for precise division
		, SortBit = grouping(AdminUnit) -- who needs a case statement??? !!!
	from qCTE 
	where 
		OrgUnitID in (select OrgUnitID from UserProfileOrgUnit where UserProfileID = @userID) 
		AND (@language = 'All' or cast(Lang as varchar(10)) = @language) 
		AND (@disabMatch = 'All' or cast(DisabilityMatch as varchar(10)) = @disabMatch) 
	group by rollup (AdminUnit), Question -- Add 100 so we can sort alpha
)

select t.AdminUnit, TopQuestion = t.Question, TopLikert = t.LikertScore, BottomQuestion = t2.Question, BottomLikert = t2.LikertScore,  t.SortBit, t.Sequence
from (
	select x.AdminUnit, x.Question, LikertScore = cast(round(cast(x.LikertScore as float), 2) as money), SortBit, Sequence = row_number() over (partition by AdminUnit order by LikertScore desc)
	from x
) t
join  (
	select x.AdminUnit, x.Question, LikertScore = cast(round(cast(x.LikertScore as float), 2) as money), SortBit, Sequence = row_number() over (partition by AdminUnit order by LikertScore)
	from x
) t2 ON t.AdminUnit = t2.AdminUnit
where t.Sequence in (1,2,3) and t.Sequence = t2.Sequence
order by SortBit, AdminUnit, Sequence


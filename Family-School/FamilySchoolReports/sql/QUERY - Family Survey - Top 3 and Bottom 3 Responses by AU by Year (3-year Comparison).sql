/*

CREATE view [x_DATATEAM].[FamilySurveyMonSubmissions]
as
select
	OrgUnitID = ou.ID,
	InstanceID = subf.id, -- MonSubmissionRecordForm.ID = FormInstanceInterval.InstanceID and FormInputValue.IntervalId = FormInstanceInterval.Id 
	RosterYearID = ry.ID,
	RosterYear = convert(char(4), ry.StartYear)+'-'+right(convert(char(4), ry.StartYear+1),2),
	AdminUnit = ou.Name, 
	District = isnull(ravD.Value, 'Blank'), 
	School = isnull(ravS.Value, 'Blank'),
	Disability = isnull(ravX.Value,'Blank'),
	Disab = case isnull(ravX.Value,'Blank')
				when '01' then 'ID'
				when '03' then 'SED'
				when '04' then 'SLD'
				when '05' then 'HI'
				when '06' then 'VI'
				when '07' then 'PD'
				when '08' then 'SLI'
				when '09' then 'DB'
				when '10' then 'MD'
				when '11' then 'DD'
				when '12' then 'IT'
				when '13' then 'Aut'
				when '14' then 'TBI'
				when '15' then 'OI'
				when '16' then 'OHI'
				else isnull(ravX.Value,'Blank')
			end,
	Grade = isnull(ravG.Value,'Blank'),
	rec.SearchKey
	--, fiv.*
from dbo.MonSubmissionRecordForm subf
left join dbo.MonSubmissionRecord subrec on subf.SubmissionRecordID = subrec.ID
left join dbo.MonRecordSelection recsel on subrec.RecordSelectionID = recsel.ID
left join dbo.MonRecordAttributeValue ravD on recsel.RecordID = ravD.RecordID and ravD.AttributeID = 'BD03127F-FE39-4374-A449-6F4C98756872' -- District of Attendance
left join dbo.MonRecordAttributeValue ravS on recsel.RecordID = ravS.RecordID and ravS.AttributeID = '526737A1-1F20-4942-A327-FAC37CF00E41' -- School Code
left join dbo.MonRecordAttributeValue ravX on recsel.RecordID = ravX.RecordID and ravX.AttributeID = '75F3907C-A65F-49C7-AEFB-9E4D332D7A04' -- Primary Disability
left join dbo.MonRecordAttributeValue ravG on recsel.RecordID = ravG.RecordID and ravG.AttributeID = '03E037CD-0C6E-4736-8472-9E4D37CA6E70' -- Grade Level
left join dbo.MonRecord rec on recsel.RecordID = rec.ID	 
left join dbo.MonSubmissions subs on subrec.SubmissionsID = subs.ID
left join dbo.OrgUnit ou on subs.OrgUnitID = ou.ID
left join dbo.RosterYear ry on subs.RosterYearID = ry.ID
where recsel.ExcludedDate is null
	and subs.SubmissionTypeID = 'C11CD949-99D0-4DF8-9DCE-96463226CF12' -- Family Survey
	and subs.SubmissionModeID != '3CDBA38D-33CA-4B7A-96BA-4BA439E6B3EA' -- Outside Sample
	and subs.ReliabilityCheckOfSubmissionsID is null -- is not a reliability check
	and subs.DeletedDate is null 



--GO




if object_id('x_DATATEAM.FamilySurveyResponses') is not null
drop view x_DATATEAM.FamilySurveyResponses
--go

CREATE view x_DATATEAM.FamilySurveyResponses
as
--/* 
--	Eliminate records where all values are NULL, per Miki and Cindy.
--*/
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
	ftii.ReportWeight
from FormInstanceInterval fii
left join FormInputValue fiv on fii.ID = fiv.IntervalID
left join FormTemplateInputItem ftii on fiv.InputFieldId = ftii.Id
left join FormTemplateLayout ftl on ftii.InputAreaID = ftl.ControlID
left join FormInputSingleSelectValue ssv on fiv.Id = ssv.Id
left join FormTemplateInputSelectFieldOption sfo on ssv.SelectedOptionId = sfo.ID and sfo.DeletedDate is null
where ftl.TemplateID = '77763BF6-1956-482B-9476-252613D08EB5'
and ftii.Id not in ('39A53975-620F-478D-8E01-DADCDA7C33C8', '16A4B3B9-71CD-4FFD-868F-E4091B26D9F2')
)

select v.InputFieldId, v.InstanceID, v.LayoutSequence, v.InputItemSequence, v.InputItemCode, v.InputItemLabel, 
	Response = isnull(v.Response, 'Blank'), v.LikertScore, v.ReportWeight
from vCTE v
left join (
	select InstanceID
	from vCTE 
	where InputFieldID <> '6B65E1F4-21CE-4223-B9F7-F610239A4E85'
	group by InstanceID
	having count(Response) = 0
) vnulls on v.InstanceID = vnulls.InstanceID
where vnulls.InstanceID is null
--go

grant select on x_DATATEAM.FamilySurveyResponses to public
--go

sp_refreshview 'x_DATATEAM.FamilySurveyResponses' 
--go




create view [x_DATATEAM].[FamilySurveyMaster]
as
with pivotCTE 
as (
	select
		sub.InstanceID,
		sub.OrgUnitID,
--		sub.Roster
		sub.RosterYear,
		sub.AdminUnit, 
		sub.District, 
		sub.School, 
		sub.SearchKey, 
		sub.Disability, 
		sub.Disab,
		Grade = case when sub.Grade in ('006', '007') then '006,007' else sub.Grade end,
		Language = isnull(lang.Response, 'Blank'),
		DisabilityMatch = isnull(dmch.Response, 'Blank'),
		AttributeID = ftii.Id,
		QuestionSequence = ftii.Sequence+1, -- Question sequence
		QuestionCode = ftii.Code,
		Question = ftii.Label,
		QuestionReportLabel = ftii.ReportLabel,
		Response = qq.Response, 
		qq.LikertScore,
		ResponseWeight = ftii.ReportWeight, 
		WeightedScore = qq.LikertScore*qq.ReportWeight,
		LikertGT3 = case when qq.LikertScore > 3 then 'Likert 4 or 5' else '' end
	--select sub.*
	from x_DATATEAM.FamilySurveyMonSubmissions sub 
	left join x_DATATEAM.FamilySurveyResponses qq on sub.InstanceID = qq.InstanceId and qq.LayoutSequence = 4 -- responses to questions
	left join FormTemplateInputItem ftii on qq.InputFieldId = ftii.Id -- to get the questions fields
	left join x_DATATEAM.FamilySurveyResponses lang on sub.InstanceID = lang.InstanceId and lang.LayoutSequence = 0 -- lang
	left join x_DATATEAM.FamilySurveyResponses dmch on sub.InstanceID = dmch.InstanceID and dmch.LayoutSequence = 2 -- Reported (disab match)
) 

select p.*, Likert75 = case when lk75.Likert75 >= 12 then 1 else 0 end
from pivotCTE p
left join (select 
	p.InstanceID, 
	Likert75 = sum(case when p.LikertScore > 3 then 1 else 0 end)
	from pivotCTE p
	group by p.InstanceID
	) lk75 on p.InstanceID = lk75.InstanceID

--GO

*/



--======================================================================================================
--======================================================================================================
--                                             REPORT QUERY                                             
--======================================================================================================
--======================================================================================================


/* <parameters>
	<parameter>
		<variable>@userID</variable>
		<datatype>uniqueidentifier</datatype>
	</parameter>
	<parameter>
		<prompt>Which language do you want to run the report for? </prompt>
		<variable>@language</variable>
		<datatype>varchar(10)</datatype>
		<options>
			select ID, Name 
			from (Values ('All', 'All'), ('English', 'English'), ('Spanish', 'Spanish'), ('Blank', 'Blank')) t (ID, Name)
		</options>
	</parameter>
	<parameter>
		<prompt>Show student whose IEP disability matches the reported disability? </prompt>
		<variable>@disabMatch</variable>
		<datatype>varchar(10)</datatype>
		<options>
			select ID, Name
			from (values ('All', 'All'), ('Yes', 'Yes'), ('No', 'No'), ('Blank', 'Blank')) t (ID, Name)
		</options>
	</parameter>
</parameters>*/


--create view x_DATATEAM.CCDates
--as
--select d.ID
--	, d.StartYear
--	, d.StartDate
--	, d.EndDate
--	--, FourthTuesdayOct
--	--, AsOfDate = case when d.FourthTuesdayOct > convert(date, GETDATE()) then convert(date, GETDATE()) else d.FourthTuesdayOct end
--from (
--select x.ID, 
--	x.StartYear, 
--	x.StartDate, 
--	EndDate = dateadd(dd, -1, x.EndDate)
--	-- , FourthTuesdayOct = dateadd(dd, 21+case when dwOct1 in (1, 2, 3) then 3 else 10 end-dwOct1, Oct1) 
--from (select *, Oct1 = dateadd(mm, 3, StartDate), dwOct1 = datepart(dw, dateadd(mm, 3, StartDate)) from dbo.RosterYear) x
--) d
--GO




declare @userID uniqueidentifier, @language varchar(10), @disabMatch varchar(10), @AUonly varchar(10) ; select @userID = ID, @language = 'All', @disabMatch = 'All' from UserProfile where username = 'Enrich:julielott'

;with x as ( -- declare @userID uniqueidentifier, @language varchar(10), @disabMatch varchar(10), @AUonly varchar(10) ; select @userID = ID, @language = 'All', @disabMatch = 'All' from UserProfile where username = 'Enrich:julielott'
	select 
		AdminUnit = case when grouping(AdminUnit) = 0 then AdminUnit else 'STATE' end -- set to STATE for group by rollup AdminUnit
		, RosterYear
		, Question = case when grouping(Question) = 0 then Question else 'Total' end 
		, LikertScore = avg(cast(LikertScore as float)) -- float for precise division
		, SortBit = grouping(AdminUnit) -- who needs a case statement??? !!!
	from x_DATATEAM.FamilySurveyMaster 
	where 
		OrgUnitID in (select OrgUnitID from UserProfileOrgUnit where UserProfileID = @userID) AND
		(@language = 'All' or cast(Language as varchar(10)) = @language) AND
		(@disabMatch = 'All' or cast(DisabilityMatch as varchar(10)) = @disabMatch) AND
		RosterYearID in (select ID from RosterYear where StartYear in (select StartYear from RosterYear where getdate() between StartDate and dateadd(yy, 2, EndDate)))
AND ADMINUNIT = 'Adams 14, Commerce City' ------- TEST
	group by AdminUnit, RosterYear, Question 
--order by AdminUnit, RosterYear, LikertScore
)

select *
from (
	select x.AdminUnit, RosterYear, x.Question, Position = 'Top', LikertScore = cast(round(cast(x.LikertScore as float), 2) as money), SortBit, Sequence = row_number() over (partition by AdminUnit, RosterYear order by case when LikertScore is not null then 0 else 1 end, LikertScore desc)
	from x
) t
where Sequence in (1,2,3) -- sort descending in the row_number partion by will make these the bottom 3
union all
select *
from (
	select x.AdminUnit, RosterYear, x.Question, Position = 'Bottom', LikertScore = cast(round(cast(x.LikertScore as float), 2) as money), SortBit, Sequence = row_number() over (partition by AdminUnit, RosterYear order by case when LikertScore is not null then 0 else 1 end, LikertScore)
	from x
) t
where Sequence in (1,2,3) -- sort ascending in the row_number partion by will make these the bottom 3
order by SortBit, AdminUnit, RosterYear, Position desc, Sequence
-- and AdminUnit = 'State'

--select AdminUnit
--	, Q1 = cast([101] as varchar(10)) -- varchar or else decimals removed when rendered on web page
--	, Q2 = cast([102] as varchar(10)) -- can't remember why we cast as varchar here instead of in the derived table.
--	, Q3 = cast([103] as varchar(10))
--	, Q4 = cast([104] as varchar(10))
--	, Q5 = cast([105] as varchar(10))
--	, Q6 = cast([106] as varchar(10))
--	, Q7 = cast([107] as varchar(10))
--	, Q8 = cast([108] as varchar(10))
--	, Q9 = cast([109] as varchar(10))
--	, Q10 = cast([110] as varchar(10))
--	, Q11 = cast([111] as varchar(10))
--	, Q12 = cast([112] as varchar(10))
--	, Q13 = cast([113] as varchar(10))
--	, Q14 = cast([114] as varchar(10))
--	, Q15 = cast([115] as varchar(10))
--	, Q16 = cast([116] as varchar(10))
--from (
--	select x.AdminUnit, x.QuestionSequenceChar, LikertScore = cast(round(cast(x.LikertScore as float), 2) as money), SortBit
--	from x
--	where (@AUonly = 'All' or (@AUonly = 'AUs only'))
--) t
--pivot (
--	avg(LikertScore) for QuestionSequenceChar in ([101], [102], [103], [104], [105], [106], [107], [108], [109], [110], [111], [112], [113], [114], [115], [116])
--	) as p
--order by Sortbit, AdminUnit



--select * from UserProfile where username = 'Enrich:julielott'






; with xCTE as (
select 
	Question
	, QuestionSequence
	, AdminUnit 
	, Score = m.LikertScore 
	, Weight = m.ResponseWeight
	, m.WeightedScore 
-- declare @userID uniqueidentifier, @language varchar(10), @disabMatch varchar(10), @rosterYearID uniqueidentifier ; select @userID = ID, @language = 'All', @disabMatch = 'All' from UserProfile where UserName = 'Enrich:julielott' ; select @rosterYearID = (select ID from RosterYear where StartYear = 2014) ; select *
from x_DATATEAM.FamilySurveyMaster m
where 
	OrgUnitID in (select OrgUnitID from UserProfileOrgUnit where UserProfileID = @userID) AND
	(@language = 'All' or cast(Language as varchar(10)) = @language) AND
	(@disabMatch = 'All' or cast(DisabilityMatch as varchar(10)) = @disabMatch) AND
	m.RosterYearID = @rosterYearID
)

select Question
	, QuestionSequence
	, AdminUnit
	, Score = sum(Score)
	, Weight = max(Weight)
	, WeightedScore = sum(WeightedScore)
from xCTE
group by Question, QuestionSequence, AdminUnit
order by QuestionSequence, AdminUnit
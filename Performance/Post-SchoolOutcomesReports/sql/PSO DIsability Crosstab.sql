
/*
select distinct RecordSetID, RecordSet
from x_DATATEAM.MonRecord_Key_Attribute_Value 
where SubmissionModeID = '79F0BE6F-FB97-4087-BD56-568027C9487D'

select distinct RosterYearID, RosterYear
from x_DATATEAM.MonRecord_Key_Attribute_Value 
where SubmissionModeID = '79F0BE6F-FB97-4087-BD56-568027C9487D'
order by RosterYear



	select c.AttributeID, Questions = Label
	from x_DATATEAM.MonFormletColumns c
	where TemplateID = 'CCC693C1-307D-4376-9F9A-9FB719D7FD98'
	and AttributeID in (
	'F13BEA86-0D1F-4CBD-B5E2-D0D503025CF4',
	'8A22F45F-00DA-476E-8518-32CDDA6B2A6F',
	'B692B2A5-3CF4-4DA0-914C-79582035ECD2',
	'7210D5D6-8C80-4142-9FC0-403A1F5FD4B5',
	'AB580A29-A884-4CE9-BB34-7BBAF0CCDCAE',
	'FE144957-0E09-4054-B361-E917386D421D',
	'6D75A464-21D5-48C4-8AC0-801A1C0F4203',
	'4F9C41FF-719F-494D-AB60-0DA1198F25E4',
	'1835C6CA-2386-4BC7-A731-3A44394684BF',
	'F73B52E1-26BC-4E40-904A-9F60CF9AFE43',
	'B58CA53B-A6D7-43B6-9EC7-31A32EC9051A',
	'B8D601A1-7AEC-453F-9CFE-BDAC5E0938EC',
	'456938AC-2A36-4A31-B93A-F026B6D299BE'
)
*/

declare @userID uniqueidentifier, @rosterYearID uniqueidentifier, @recordSetID uniqueidentifier, @templateID uniqueidentifier, @questionID uniqueidentifier ; 
set @userID = '546F8D65-330B-4EA2-B4D9-0992A8DA8384'
set @rosterYearID = '83EEB57A-4E8C-449C-9543-7BDC3FE056C0'
select @recordSetID = 'A6D0DC62-A691-4598-AECB-F48643F752CF'

select @templateID = (select top 1 TemplateID from x_DATATEAM.MonRecord_Key_Attribute_Value where RecordSetID = @recordSetID)
set @questionID = 'F13BEA86-0D1F-4CBD-B5E2-D0D503025CF4'

;with rData as (
	select TemplateID, InstanceID, RecordSet, AU, AUCode, RosterYear, AttributeID, AttributeSequence, Attribute, Value, SubmissionSequence, RecordSetID
	from x_DATATEAM.MonRecord_Key_Attribute_Value r
	where 1=1
	and SubmissionModeID = '79F0BE6F-FB97-4087-BD56-568027C9487D' -- PS Interview
	and OrgUnitID in (select OrgUnitID from UserProfileOrgUnit where UserProfileID = @userID)
	and RosterYearID = @rosterYearID
	and (RecordSetID is null or RecordSetID = @recordSetID)
)
, disab as (
select Code, Abbreviation
from (Values 
		('01', 'ID'), 
		('03', 'SED'), 
		('04', 'SLD'), 
		('05', 'HI'), 
		('06', 'VI'), 
		('07', 'PD'), 
		('08', 'SLI'), 
		('09', 'DB'), 
		('10', 'MD'), 
		('11', 'DD'), 
		('12', 'IT'), 
		('13', 'Aut'), 
		('14', 'TBI'), 
		('15', 'OI'), 
		('16', 'OHI')
	) d (Code, Abbreviation)
)
, rPivot as (
	select InstanceID
		, r.AU
		, [ADMIN_UNIT_CODE] = max(case when AttributeID = '5A18DC11-C92A-498C-A231-519B0BB9C5A0' then Value end)
		, [DISTRICT_OF_ATTENDANCE] = max(case when AttributeID = '1CEF0429-8BFF-4799-BFF2-23861737B229' then Value end)
		, [SCHOOL_CODE] = max(case when AttributeID = '2D73FDD2-E725-4B97-A1BE-74D0C0066FA0' then Value end)
		, [GENDER_STUDENT] = max(case when AttributeID = '7B7330CD-C397-48C7-9119-2F4D84373FAB' then Value end)
		, [FEDERAL_RACE_STUDENT] = max(case when AttributeID = '285BCCBD-7A70-4999-AE54-9DF05567A3E3' then Value end)
		, [PRIMARY_DISABILITY] = max(case when AttributeID = '8E9BEE88-F15A-4EEF-B036-940EC0EFFF06' then d.Abbreviation end)
		, [REASON_EXITED_SPED] = max(case when AttributeID = 'B4438144-4BF5-4C47-8F37-79C69B3F31B7' then Value end)
	from x_DATATEAM.MonRecord_Key_Attribute_Value r
	left join disab d on r.Value = d.Code and r.AttributeID = '8E9BEE88-F15A-4EEF-B036-940EC0EFFF06'
	where 1=1
	and SubmissionModeID = '79F0BE6F-FB97-4087-BD56-568027C9487D' -- PS Interview
	and OrgUnitID in (select OrgUnitID from UserProfileOrgUnit where UserProfileID = @userID)
	and RosterYearID = @rosterYearID
	and (RecordSetID is null or RecordSetID = @recordSetID)
	group by InstanceID, AU
)
, fPivot as (
	select f.InstanceID
		, Answer = max(case when f.Value = 'Met' then 1 else 0 end)
	from rPivot r
	left join x_DATATEAM.MonFormlet_Key_Attribute_Value f on r.InstanceID = f.InstanceID
	where f.AttributeID = @questionID
	group by f.InstanceID
)

select 
	AdminUnit = case when grouping(r.AU) = 0 then r.AU else 'State Total' end
	, District = case when grouping(r.DISTRICT_OF_ATTENDANCE) = 0 then r.DISTRICT_OF_ATTENDANCE else 'Admin Unit Total' end
	, School = case when grouping(r.SCHOOL_CODE) = 0 then r.SCHOOL_CODE else 'District Total' end
	, Disability = r.PRIMARY_DISABILITY
	, nSize = count(distinct r.InstanceID)
	, MetCount = sum(f.Answer)
	, pct = cast(round(((sum(f.Answer)*100.0)/count(distinct r.InstanceID)),2) as decimal(5,2))
	, AUSortBit = grouping(r.AU)
	, DistrictSortBit = grouping(r.DISTRICT_OF_ATTENDANCE)
	, SchoolSortBit = grouping(r.SCHOOL_CODE)
from rPivot r
left join fPivot f on r.InstanceID = f.InstanceID
group by rollup(r.AU, r.DISTRICT_OF_ATTENDANCE, r.SCHOOL_CODE), r.PRIMARY_DISABILITY
order by AUSortBit, AU, DistrictSortBit, District, SchoolSortBit, School

--- order by 1, 4



--Adams 1, Mapleton	Aut	1	0.00
--Adams 1, Mapleton	HI	1	0.00
--Adams 1, Mapleton	ID	1	100.00
--Adams 1, Mapleton	MD	5	0.00
--Adams 1, Mapleton	PD	2	50.00
--Adams 1, Mapleton	SED	4	0.00
--Adams 1, Mapleton	SLD	20	15.00
--Adams 1, Mapleton	SLI	1	0.00
--Adams 1, Mapleton	TBI	1	0.00


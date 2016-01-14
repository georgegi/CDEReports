
declare @userID uniqueidentifier, @rosterYearID uniqueidentifier, @recordSetID uniqueidentifier, @templateID uniqueidentifier, @questionID uniqueidentifier ; 
set @userID = '546F8D65-330B-4EA2-B4D9-0992A8DA8384'
set @rosterYearID = '83EEB57A-4E8C-449C-9543-7BDC3FE056C0'
select @recordSetID = 'A6D0DC62-A691-4598-AECB-F48643F752CF'

--select @templateID = (select top 1 TemplateID from x_DATATEAM.MonRecord_Key_Attribute_Value where RecordSetID = @recordSetID)
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
, exitReason as (
	select StateCode, Name
	from PrgStatus
	where ProgramID = 'F98A8EF2-98E2-4CAC-95AF-D7D89EF7F80C'
	and IsExit = 1
	and DeletedDate is null
)
, gender as (
	select StateCode, Name = DisplayValue 
	from EnumValue 
	where Type = 'D6194389-17AC-494C-9C37-FD911DA2DD4B' 
	and IsActive = 1
)
, rPivot as (
	select InstanceID
		, r.AU
		, [ADMIN_UNIT_CODE] = max(case when AttributeID = '5A18DC11-C92A-498C-A231-519B0BB9C5A0' then Value end)
		, [DISTRICT_OF_ATTENDANCE] = max(case when AttributeID = '1CEF0429-8BFF-4799-BFF2-23861737B229' then Value end)
		, [SCHOOL_CODE] = max(case when AttributeID = '2D73FDD2-E725-4B97-A1BE-74D0C0066FA0' then Value end)
		, [GENDER_STUDENT] = max(case when AttributeID = '7B7330CD-C397-48C7-9119-2F4D84373FAB' then g.Name end)
		, [FEDERAL_RACE_STUDENT] = max(case when AttributeID = '285BCCBD-7A70-4999-AE54-9DF05567A3E3' then Value end)
		, [PRIMARY_DISABILITY] = max(case when AttributeID = '8E9BEE88-F15A-4EEF-B036-940EC0EFFF06' then d.Abbreviation end)
		, [REASON_EXITED_SPED] = max(case when AttributeID = 'B4438144-4BF5-4C47-8F37-79C69B3F31B7' then isnull(e.Name, Value) end)
	from x_DATATEAM.MonRecord_Key_Attribute_Value r
	left join disab d on r.Value = d.Code and r.AttributeID = '8E9BEE88-F15A-4EEF-B036-940EC0EFFF06'
	left join exitReason e on r.Value = e.StateCode and r.AttributeID = 'B4438144-4BF5-4C47-8F37-79C69B3F31B7'
	left join gender g on r.Value = g.StateCode and r.AttributeID = '7B7330CD-C397-48C7-9119-2F4D84373FAB'
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
	, Gender = r.GENDER_STUDENT
	, nSize = count(distinct r.InstanceID)
	, MetCount = sum(f.Answer)
	, pct = cast(round(((sum(f.Answer)*100.0)/count(distinct r.InstanceID)),2) as decimal(5,2))
	, AUSortBit = grouping(r.AU)
	, DistrictSortBit = grouping(r.DISTRICT_OF_ATTENDANCE)
	, SchoolSortBit = grouping(r.SCHOOL_CODE)
from rPivot r
left join fPivot f on r.InstanceID = f.InstanceID
group by rollup(r.AU, r.DISTRICT_OF_ATTENDANCE, r.SCHOOL_CODE), 
	r.GENDER_STUDENT
order by AUSortBit, AU, DistrictSortBit, District, SchoolSortBit, School





--select kav.Value  
--from rPivot r 
--join x_DATATEAM.MonRecord_Key_Attribute_Value kav on r.InstanceID = kav.InstanceID
--where r.GENDER_STUDENT = '01'
--and kav.Attribute = 'First_name_student'

	/*
			begin tran
			update e set StateCode = case when Code = 'F' then '01' else '02' end 
			--- select *
			from EnumValue e
			where Type = 'D6194389-17AC-494C-9C37-FD911DA2DD4B' 
			and IsActive = 1

			rollback 
			commit
	*/

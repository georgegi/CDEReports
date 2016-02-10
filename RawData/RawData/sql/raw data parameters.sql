
declare @programID uniqueidentifier = '0C390AC9-A77A-418E-BE84-49207395DDDD'
	, @locationID uniqueidentifier = '95E46CA3-89CC-4F00-9504-4160405E1954'
	, @rosterYearID uniqueidentifier = '83EEB57A-4E8C-449C-9543-7BDC3FE056C0'
	, @submissionModeID uniqueidentifier = '1A4C0468-C2F1-442A-85DA-F9F13E6CE435' -- Survey, not Outside Sample
	, @userID uniqueidentifier = '546F8D65-330B-4EA2-B4D9-0992A8DA8384';



-- Program parameter
select distinct ID = ProgramID, Name = Program
from x_DATATEAM.RawDataParameters p
order by 2

-- Location Parameter
select distinct ID = LocationID, Name = Location
from x_DATATEAM.RawDataParameters p
where ProgramID = @programID
order by 2


-- RosterYear parameter
select distinct ID = RosterYearID, Name = RosterYear
from x_DATATEAM.RawDataParameters p
where ProgramID = @programID
and LocationID = @locationID
and SubmissionModeID = @submissionModeID
order by 2

-- SubmissionMode parameter
select distinct ID = SubmissionModeID, Name = SubmissionMode
from x_DATATEAM.RawDataParameters p
where ProgramID = @programID
and LocationID = @locationID
-- and RosterYearID = @rosterYearID
order by 2


-- RecordSet parameter 
select distinct ID = p.RecordSetSampledFromID, Name = p.RecordSetSampledFrom
from x_DATATEAM.RawDataParameters p
where p.ProgramID = @programID
and LocationID = @locationID
and RosterYearID = @rosterYearID
and SubmissionModeID = @submissionModeID
order by 2


-- 04838E5A-84A7-4E2D-9444-7C34C1764BF3	RDA_Ind8_Parent_Survey_Samples_01_16_2015












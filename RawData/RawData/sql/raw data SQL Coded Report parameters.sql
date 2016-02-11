


select ID = parentSet.ID, Name = loc.DisplayName+' > '+msm.Name+' > '+parentset.Name
	-- , rosteryear = convert(char(4), ry.StartYear)+'-'+right(convert(varchar(4), ry.StartYear+1), 2)
from MonSubmissions subs 
left join MonSubmissionType mst on subs.SubmissionTypeID = mst.ID
left join MonSubmissionMode msm on subs.SubmissionModeID = msm.ID
left join MonRecordSet childSet on subs.RecordSetID = childSet.ID
	and subs.DeletedDate is null 
	and subs.ReliabilityCheckOfSubmissionsID is null
left join MonRecordSet parentSet on childSet.SampledFromID = parentSet.ID
-- left join RosterYear ry on subs.RosterYearID = ry.ID
left join MonLocation loc on mst.LocationID = loc.ID
left join MonProgram p on loc.ProgramID = p.ID
left join (select RecordSetID from MonRecordAttribute where RecordSetID is not null group by RecordSetID) att on parentSet.ID = att.RecordSetID
where 1=1
and att.RecordSetID is not null -- we only need recordsets that have attributes
and p.DisplayName = 'Special Education'
group by parentSet.ID, loc.DisplayName+' > '+msm.Name+' > '+parentset.Name
	-- , convert(char(4), ry.StartYear)+'-'+right(convert(varchar(4), ry.StartYear+1), 2)
order by 2



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

; WITH giftedStuff AS (SELECT        t .LocationID, LocationSequence = loc.Sequence, Location = loc.DisplayName, m.SubmissionTypeID, SubmissionType = t .Name, 
                                                                        SubmissionModeID = m.ID, SubmissionMode = m.Name, t .FormTemplateID, ModeSequence = row_number() OVER (partition BY 1
                                               ORDER BY loc.Sequence, t .name, CASE m.Name WHEN 'Annual Budget Review' THEN 'AU Budget: Review' ELSE m.name END)
FROM            MonLocation loc JOIN
                         MonSubmissionType t ON loc.ID = t .LocationID JOIN
                         MonSubmissionMode m ON t .ID = m.SubmissionTypeID
WHERE        loc.ProgramID = '58FFE83B-EA3A-4703-A505-023B8E306B64' /* Gifted Education*/ AND 
                         m.id NOT IN ('9BA63D26-C4E3-4ACF-AE78-8F9583CD4EE3'/* Profile	Programming Details Worksheet*/ , 
                         '7A85EDD5-DB08-423C-B29A-EDA17D3F10D5'/* Fiscal	BOCES & Multi District AU Working Budgets*/ )/*order by LocationSequence, SubmissionType, case m.Name when 'Annual Budget Review' then 'AU Budget: Review' else m.name end*/ ),
 AUs AS
    (SELECT DISTINCT subs.OrgUnitID, AU = ou.Name
      FROM            MonSubmissions subs JOIN
                                OrgUnit ou ON subs.OrgUnitID = ou.ID JOIN
                                giftedStuff g ON subs.SubmissionTypeID = g.SubmissionTypeID
      WHERE        ou.ID IN
                                    (SELECT        OrgUnitID
                                      FROM            UserProfileOrgUnit
                                      WHERE        UserProfileID = @userID) AND subs.DeletedDate IS NULL /* 889*/ AND subs.ReliabilityCheckOfSubmissionsID IS NULL /* 889*/ AND 
                                ou.name NOT IN ('TEST', 'TEST AU', 'SAML TEST - Douglas RE-1 Castle Rock')), rosterYears AS
    (SELECT DISTINCT subs.RosterYearID, RosterYear = CONVERT(char(4), ry.StartYear) + '-' + RIGHT(CONVERT(varchar(4), ry.StartYear + 1), 2)
      FROM            MonSubmissions subs JOIN
                                RosterYear ry ON subs.RosterYearID = ry.ID JOIN
                                giftedStuff g ON subs.SubmissionTypeID = g.SubmissionTypeID
      WHERE        1 = 1 AND subs.DeletedDate IS NULL /* 889*/ AND subs.ReliabilityCheckOfSubmissionsID IS NULL/* 889*/ ), iiCTE AS
    (SELECT        TemplateID = t .ID, TemplateName = t .Name, LayoutID = tl.ID, InputAreaID = tl.ControlId, tl.ParentId, 
                                tlSequence = tl.Sequence/*- will always be zero in the anchor*/ , CTELevel = 0/* keep this consistent with other formlet sequences that start at 0*/ , 
                                ControlType = tct.Name, ControlIsRepeatable = tc.IsRepeatable, DisplaySequence = cast(100 + tl.Sequence AS varchar(max))
      /* add 100 for sorting in alpha order */ FROM (SELECT        FormTemplateID
                                                                                                        FROM            giftedStuff
                                                                                                        GROUP BY FormTemplateID) x LEFT JOIN
                                FormTemplate t ON x.FormTemplateID = t .Id LEFT JOIN
                                FormTemplateLayout tl ON t .ID = tl.TemplateID LEFT JOIN
                                FormTemplateControl tc ON tl.ControlID = tc.Id LEFT JOIN
                                FormTemplateControlType tct ON tc.TypeID = tct.ID
      WHERE        tl.ParentId IS NULL
      UNION ALL
      SELECT        c.TemplateID, TemplateName = t .Name, LayoutID = tl.ID, InputAreaID = tl.ControlId, tl.ParentId, tlSequence = tl.Sequence, CTELevel = c.CTELevel + 1, 
                               ControlType = tct.Name, ControlIsRepeatable = tc.IsRepeatable, DisplaySequence = c.DisplaySequence + '_' + cast(100 + tl.Sequence AS varchar(max))
      /* add 100 for sorting in alpha order */ FROM FormTemplate t JOIN
                               FormTemplateLayout tl ON t .ID = tl.TemplateID AND tl.ParentId IS NOT NULL /* inner join*/ JOIN
                               FormTemplateControl tc ON tl.ControlID = tc.Id JOIN
                               FormTemplateControlType tct ON tc.TypeID = tct.ID JOIN
                               iiCTE c ON tl.ParentID = c.LayoutID), frmAttributes AS
    (SELECT        c.TemplateID, c.TemplateName, c.InputAreaID, c.ParentId, c.LayoutID, c.ControlType, InputItemType = iit.Name, AttributeID = ii.ID, 
                                DisplaySequence = c.DisplaySequence + isnull('_' + cast(100 + ii.Sequence AS varchar(max)), ''), AttributeSequence = row_number() OVER (partition BY 
                                c.TemplateName
      ORDER BY c.DisplaySequence + isnull('_' + cast(100 + ii.Sequence AS varchar(max)), '')), Attribute = CASE WHEN ii.ReportWeight IS NULL THEN isnull(ii.reportlabel, ii.code) 
ELSE ii.Code END, ii.ReportLabel, ii.Code, InputItemLabel = ii.Label, Weighted = CASE WHEN ii.ReportWeight IS NULL THEN 0 ELSE 1 END
FROM            iiCTE c JOIN
                         iiCTE c2 ON c.ParentID = c2.LayoutID JOIN
                         FormTemplateInputItem ii ON c.InputAreaID = ii.InputAreaId LEFT JOIN
                         FormTemplateInputItemType iit ON ii.TypeId = iit.Id), results AS
    (SELECT        aury.AU, aury.RosterYear, g.Location, g.SubmissionModeID, g.SubmissionMode, SubmissionDate = CONVERT(varchar, subs.StartedDate, 
                                101)/* convert to text later*/ , a.Code, a.InputItemLabel, InstanceID = fi.Id, sfo.Label, g.ModeSequence
      FROM            frmAttributes a LEFT JOIN
                                giftedStuff g ON a.TemplateID = g.FormTemplateID CROSS JOIN
                                    (SELECT        *
                                      FROM            AUs CROSS JOIN
                                                                rosterYears) aury LEFT JOIN
                                MonSubmissions subs ON g.SubmissionModeID = subs.SubmissionModeID /* 970*/ AND aury.OrgUnitID = subs.OrgUnitID AND 
                                aury.RosterYearID = subs.RosterYearID AND subs.DeletedDate IS NULL /* 889*/ AND subs.ReliabilityCheckOfSubmissionsID IS NULL /* 889*/ LEFT JOIN
                                OrgUnit ou ON subs.OrgUnitID = ou.ID LEFT JOIN
                                RosterYear ry ON subs.RosterYearID = ry.ID LEFT JOIN
                                MonSubmissionRecord sr ON subs.ID = sr.SubmissionsID /* 889*/ LEFT JOIN
                                MonSubmissionRecordForm rf ON sr.ID = rf.SubmissionRecordID /* 889*/ LEFT JOIN
                                FormInstance fi ON rf.ID = fi.Id /* 889*/ LEFT JOIN
                                FormInstanceInterval fii ON fi.Id = fii.InstanceId /* 889*/ LEFT JOIN
                                FormInputValue fiv ON fii.Id = fiv.IntervalId /* note that fiv has an IntervalID column, but this is something different*/ AND 
                                a.AttributeID = fiv.InputFieldId /* when left joining, we get 890 records!*/ LEFT JOIN
                                FormInputSingleSelectValue ssv ON fiv.Id = ssv.Id LEFT JOIN
                                FormTemplateInputSelectFieldOption sfo ON ssv.SelectedOptionID = sfo.ID
      WHERE        a.InputItemLabel LIKE '%assistance%' /*------------------------------------------------ may change this later to specific list*/ OR
                                (g.SubmissionModeID = '33F88AE5-682B-4EAF-BA73-8A3E14A036CE' AND a.InputItemType = 'Date' AND a.Code IN ('Rev1', 'Rev2')))

    SELECT        AU, RosterYear, Location, SubmissionMode, SubmissionModeID, ModeSequence, Attribute = 'SubmissionDate', AttributeSequence = 0, 
                              InputItemLabel = 'Date of Submission', Value = max(SubmissionDate)
     FROM            results r
     GROUP BY AU, RosterYear, Location, SubmissionMode, SubmissionModeID, ModeSequence
UNION ALL
SELECT        AU, RosterYear, Location, (case Code when 'Rev1' then '4 Month' when 'Rev2' then '8 Month' else SubmissionMode end) SubmissionMode, SubmissionModeID, ModeSequence, Attribute = Code, AttributeSequence = 1, InputItemLabel, Value = r.Label
FROM            results r
/*where AU = 'Eagle Re 50, Eagle' -- testing */ ORDER BY AU, RosterYear, ModeSequence, AttributeSequence, Attribute, InputItemLabel
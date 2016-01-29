
/*
	We are using a view to get the SubmissionAreaIDs because we know 
	the SubmissionArea and FormTemplateControl IDs will change
	but the FormTemplateInputItem IDs will not change. 
	Here we use the first ID in each of the sections we need
*/

select ID = a.SectionID, Name = a.Section
from x_DATATEAM.Compliance_Formlet_Attributes a
where a.attributeid in ( -- here we are showing all statements within a section so we can show in the code which ones are purposely excluded
-- Present Levels of Academic Achievement and Functional Performance
	  'C3691975-B896-4129-9E16-C313059AADC5' -- Child's Strengths (first input item)
-- Post-School Considerations
	, 'E20F00B1-E4D6-4C17-95E1-88071DD17278' -- Post Goals - Education (first input item)
-- Annual Goals/Objectives
	, '775BCA18-5502-4B40-878F-EB0C4EDC6244' -- Goals Link to Postsecondary Goals (first input item)
-- Service Delivery Statement
	, 'AD1683EE-3E5F-479A-A2FE-2769E59D9947' -- Purpose of Services (first input item)
-- Recommended Placement in the LRE
	, '25FAB41E-3EFD-46B2-9AB1-8C37580134D8' -- Placement Decision (first input item)
	)
order by 2



--where a.FormTemplateControlID in (
--'C4404A98-12EB-4791-8341-8E21FAF7E553' -- (1) -- Post-School Considerations
--, '4249765D-446C-4199-9A4A-1961C6CD81C2' -- (4) -- Present Levels of Academic Achievement and Functional Performance
--, 'B66A23BC-4292-4F42-A73B-1025C6A0A8C7' -- (5) -- Annual Goals/Objectives
--, 'AEFB23A3-4DAE-4B7E-8C2F-1D620584D814' -- (6) -- Service Delivery Statement
--, '367FBEB2-DC15-4E78-B2ED-9CF12D05F59E' -- (7) -- Recommended Placement in the LRE
--)

module namespace stats = "http://tools.aidinfolabs.org/api/stats";

import module namespace base = "http://kitwallace.me/iati-b" at "iati-b.xqm";
import module namespace codes = "http://kitwallace.me/iati-c" at "iati-c.xqm";

declare namespace iati-ad = "http://tools.aidinfolabs.org/api/AugmentedData";

declare function stats:sum-activities($activities as element(iati-activity)*, $date-from , $date-to, $type) {
           sum($activities/*/value
             [@iati-ad:transaction-type=$type]
             [@iati-ad:transaction-date ge $date-from]
             [@iati-ad:transaction-date lt $date-to]
             /@iati-ad:USD-value
           )
};

declare function stats:host-statistics($query) {
     let $activity-collection := concat($base:data,$query/corpus,"/activities")
     let $activitySets := doc(concat($base:data,$query/corpus,"/activitySets.xml"))/activitySets/activitySet
     for $host in distinct-values($activitySets/host)
     let $activitySets := $activitySets[host=$host]
     let $activities := collection($activity-collection)/iati-activity[@iati-ad:activitySet = $activitySets/download_url][@iati-ad:live]
     return 
        element host {
           element download_url {$host},
           element activitySets {count($activitySets)},
           element activitySets-download {count($activitySets[download-modified])},
           element activities {count($activities)},
           element live-activities {count($activities[@iati-ad:include])}
        }
};

declare function stats:funder-statistics($query) {
     let $activity-collection := concat($base:data,$query/corpus,"/activities")
     let $all-activities := collection($activity-collection)/iati-activity[@iati-ad:live]
     for $ref in distinct-values($all-activities//@iati-ad:funder)
     let $funder := codes:code-value("Funder",$ref,$query/corpus)
     let $activities := $all-activities[participating-org/@iati-ad:funder=$ref]
     let $years := 2009 to 2013
     return  
        element funder {
           $funder/code,
           $funder/name,
           element activities {count($activities)},
           element activities-with-results {count($activities[results])},
           element activities-with-documents {count($activities[document-link])},
           element activities-with-conditions {count($activities[conditions])},
           element activities-with-locations {count($activities[location])},
           element activities-with-DAC {count($activities[sector/@vocabulary="DAC" ])},
           element activities-with-multiple-sectors {count($activities[count(sector) > 1])},
           
           for $type in codes:codelist("ValueType")/*
           for $year in $years
           let $date-from := concat($year,"-01-01")
           let $date-to:= concat ($year + 1 ,"01-01")
           return 
              element total {
                   attribute type {$type/code},
                   attribute year {$year},
                   stats:sum-activities($activities , $date-from , $date-to, $type/code) 
              }
        }      
};

declare function stats:all-statistics($query) {
  element stats {
      attribute corpus {$query/corpus},
      stats:host-statistics($query),
      stats:funder-statistics($query)
  }
};


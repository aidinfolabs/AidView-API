module namespace iati-sum = "http://kitwallace.me/iati-sum";
import module namespace iati-c = "http://kitwallace.me/iati-c" at "iati-c.xqm";
declare namespace iati-ad = "http://tools.aidinfolabs.org/api/AugmentedData";

(:
declare function iati-sum:transaction($activity, $type, $date-from , $date-to) {
   sum($activity/transaction[transaction-type/@iati-ad:transaction-type=$type][transaction-date/@iso-date ge $date-from][transaction-date/@iso-date le $date-to]/value/@iati-ad:USD-value)
};

declare function iati-sum:planned-disbursement($activity , $date-from , $date-to) {
  sum($activity/planned-disbursement[period-start/@iso-date ge $date-from][period-start/@iso-date le $date-to]/value/@iati-ad:USD-value)
};

declare function iati-sum:budget($activity , $date-from , $date-to) {
 sum($activity/budget[period-date/@iso-date ge $date-from][period-date/@iso-date le $date-to]/value/@iati-ad:USD-value)
}; 

:)

(:
declare function iati-sum:activity($activity, $date-from , $date-to, $types) {
let $types := if (exists($types)) then $types else $iati-sum:types
return
   element iati-ad:transaction-summary {
      for $type in $types
      return
      if ($type="PD")
      then  iati-sum:planned-disbursement($activity, $date-from , $date-to)
      else if ($type eq "TB")
      then  iati-sum:budget($activity, $date-from , $date-to)
      else iati-sum:transaction($activity, $type, $date-from , $date-to)
   } 
};
:)

declare function iati-sum:activities($activities as element(iati-activity)*, $date-from , $date-to, $types) {
let $types := if (exists($types)) then $types else iati-c:codelist("ValueType")/code
return
   element iati-ad:transaction-summary {
      for $type in $types
      return
        element iati-ad:value-analysis {
         attribute code {string($type)},
         attribute USD-value {
(:      if ($type="PD")
      then  sum (for $activity in $activities return iati-sum:planned-disbursement($activity, $date-from , $date-to))
      else if ($type eq "TB")
      then  sum (for $activity in $activities return iati-sum:budget($activity, $date-from , $date-to))
      else  sum(for $activity in $activities return iati-sum:transaction($activity, $type, $date-from , $date-to))
 :)
           sum($activities/*/value
             [@iati-ad:transaction-type=$type]
             [@iati-ad:transaction-date ge $date-from]
             [@iati-ad:transaction-date le $date-to]
             /@iati-ad:USD-value
           )
         } 
      }
  }
};
module namespace olap = "http://tools.aidinfolabs.org/api/olap";
declare namespace iati-ad = "http://tools.aidinfolabs.org/api/AugmentedData";
import module namespace config = "http://tools.aidinfolabs.org/api/config" at "config.xqm";
import module namespace codes = "http://tools.aidinfolabs.org/api/codes" at "codes.xqm";

declare function olap:sum-activities($activities as element(iati-activity)*, $date-from , $date-to) {
   element transaction-summary {
      for $type in ("C","D","E","IF","IR","LR","PD","R","TB")  
      let $value := 
          sum($activities/*/value
             [@iati-ad:transaction-type=$type]
             [@iati-ad:transaction-date ge $date-from]
             [@iati-ad:transaction-date lt $date-to]
             /@iati-ad:USD-value
           )
      where $value ne 0.0
      return
        element summary {
         attribute code {$type},
         attribute date-from {$date-from},
         attribute date-to {$date-to},
         attribute USD-value {$value} 
      }
  }
};

declare function olap:sum-activities($activities as element(iati-activity)*, $year) {
let $date-from := concat($year,"-01-01")
let $date-to:= concat ($year + 1 ,"-01-01")
for $type in ("C","D","E","IF","IR","LR","PD","R","TB") 
      
      let $value := 
          sum($activities/*/value
             [@iati-ad:transaction-type=$type]
             [@iati-ad:transaction-date ge $date-from]
             [@iati-ad:transaction-date lt $date-to]
             /@iati-ad:USD-value
           )
      where $value ne 0.0
      return
        element summary {
         attribute code {$type},
         attribute year {$year},
         attribute USD-value {$value} 
      }
};

declare function olap:sum-activities($activities as element(iati-activity)*) {
   element transaction-summary {
      for $type in ("C","D","E","IF","IR","LR","PD","R","TB")  
      let $value := 
          sum($activities/*/value
             [@iati-ad:transaction-type=$type]
             /@iati-ad:USD-value
           )
      where $value ne 0.0
      return
        element summary {
         attribute code {$type},
         attribute USD-value {$value} 
      }
  }
};

declare function olap:tree-group($activities as element(iati-activity)*, $dimensions as element(param)*, $corpus , $levels)  {
if (empty($dimensions))
then 
   element summary{
       element value { sum ($activities/@iati-ad:project-value) },
       element count {count($activities)},
       olap:sum-activities($activities)
   }
else
let $dimension := $dimensions[1]
let $facet := element facet {$dimension/@name/string()}
let $sub-dimensions := subsequence($dimensions,2)
let $group-exp := concat("distinct-values($activities/",$dimension/@path,")")
let $group-codes := util:eval($group-exp)
return
for $group-code in $group-codes
let $code := codes:code-value($dimension/@name,$group-code,$corpus)
let $exp := concat("$activities[",$dimension/@path, " eq $group-code]")
let $group-activities := util:eval($exp)
let $level :=
        element level {
            $facet,
            $code/name,
            element code {$group-code}
         } 
let $levels  := ($levels,$level)
return
   if (empty($sub-dimensions))
   then 
     let $e := if (empty($levels/facet)) then error ((),"x",$levels) else ()
     return
     element {concat(string-join($levels/facet,"-"),"-summary")} {
       for $level in $levels
       return (
              element {concat($level/facet,"-code")} {$level/code/string()},
              element {concat($level/facet,"-name")} {$level/name/string()}
               ),
       element value {sum ($group-activities/@iati-ad:project-value) },
       element count {count($group-activities)},
       olap:sum-activities($group-activities)
   }
   else 
       olap:tree-group($group-activities,$sub-dimensions,$corpus,$levels) 

};

declare function olap:group($activities as element(iati-activity)*, $dimension as element(param)*, $corpus )  {
if (empty($dimension))
then 
   element summary{
       element value { sum ($activities/@iati-ad:project-value) },
       element count {count($activities)},
       olap:sum-activities($activities)
   }
else
let $facet := $dimension/@name/string()
let $group-exp := concat("distinct-values($activities/",$dimension/@path,")")
let $group-codes := util:eval($group-exp)
return
for $group-code in $group-codes
let $code := codes:code-value($dimension/@name,$group-code,$corpus)
let $exp := concat("$activities[",$dimension/@path, " eq $group-code]")
let $group-activities := util:eval($exp)
return
     element {$facet} {   
       element code {$group-code},
       element name {$code/name/string()},
       element value {sum ($group-activities/@iati-ad:project-value) },
       element count {count($group-activities)},
       olap:sum-activities($group-activities)
    }
};

declare function olap:stats($activities, $dimension as element(param)*, $years, $corpus) {
let $facet := $dimension/@name/string()
let $group-exp := concat("distinct-values($activities/",$dimension/@path,")")
let $group-codes := util:eval($group-exp)
return
for $group-code in $group-codes
let $code := codes:code-value($dimension/@name,$group-code,$corpus)
let $exp := concat("$activities[",$dimension/@path, " eq $group-code]")
let $group-activities := util:eval($exp)
return
     element {$facet} {   
       element code {$group-code},
       element name {$code/name/string()},
       element value {sum ($group-activities/@iati-ad:project-value) },
       element count {count($group-activities)},
       element included {count($group-activities[@iati-ad:include])},
       element with-location {count($activities[location])},
       element with-result {count($activities[result])},
       element with-document {count($activities[document-link])},
       element with-conditions {count($activities[conditions])},
       element with-DAC-sectors {count($activities[sector/@vocabulary="DAC"])},
       
       for $year in $years 
       return  olap:sum-activities($activities , $year )        
    }
};

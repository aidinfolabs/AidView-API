module namespace olap = "http://tools.aidinfolabs.org/api/olap";

declare namespace iati-ad = "http://tools.aidinfolabs.org/api/AugmentedData";
import module namespace config = "http://tools.aidinfolabs.org/api/config" at "../lib/config.xqm";
import module namespace codes = "http://tools.aidinfolabs.org/api/codes" at "../lib/codes.xqm";
import module namespace activity = "http://tools.aidinfolabs.org/api/activity" at "../lib/activity.xqm";  
import module namespace wfn = "http://kitwallace.me/wfn" at "/db/lib/wfn.xqm";
import module namespace num = "http://kitwallace.me/num" at "/db/lib/num.xqm";
import module namespace url = "http://kitwallace.me/url" at "/db/lib/url.xqm";


declare function olap:meta-dimensions() {
   doc(concat($config:config,"olap.xml"))//dimension
};

declare function olap:meta-dimension($facet as xs:string) {
   olap:meta-dimensions()[@name = $facet]
};

declare function olap:file($context) {
    concat($config:olap,$context/corpus,"/all.xml")
};

declare function olap:host-statistics( $context) {
     for $host in activity:corpus-hosts($context/corpus)
     let $activitySets := activity:host-activitySets($context/corpus,$host)
     let $activities := activity:set-activities($context/corpus, $activitySets/package)
     return 
        element Host {
           element code {$host},
           element activitySets {count($activitySets)},
           element activitySets-download {count($activitySets[download-modified])},
           element count-all {count($activities)},
           element count {count($activities[@iati-ad:include])}
        }
};

declare function olap:sum-activities($activities as element(iati-activity)*, $date-from , $date-to) {
   element transaction-summary {
      for $type in ("C","D","E","IF","IR","LR","PD","R","TB")  
      let $value := 
          sum($activities/*/value
             [@iati-ad:transaction-type = $type]
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

declare function olap:sum-activities($activities as element(iati-activity)*, $year as xs:integer) {
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

(: 
devised for a tree structure dimensional analysis - not yet needed - would need rework 
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

:)

(:  create the olap summary for a facet, guided by the dimension description in the olap configuration file :)

declare function olap:compute-facet( $dimension as element(dimension)*, $years as xs:string*, $context) {
let $facet := $dimension/@name/string()
let $group-exp := concat("distinct-values(collection('",$config:data,$context/corpus,"/activities')/iati-activity[@iati-ad:live]/",$dimension/@path,")")
let $group-codes := util:eval($group-exp)
return
for $group-code in $group-codes[. ne '']
let $code := codes:code-value($facet,$group-code)
let $exp := concat("collection('",$config:data,$context/corpus,"/activities')/iati-activity[",$dimension/@path, " = $group-code]")
let $group-activities := util:eval($exp,true())
let $name := codes:code-value($dimension/@code,$group-code)/name
let $name := if  (empty($name) and $dimension/@mine)
             then 
                    let $laststep := tokenize($dimension/@path,"/")[last()]
                    let $rest := substring-before($dimension/@path,$laststep)
                    let $rest := if (ends-with($rest,"/")) then  substring($rest,1, string-length($rest) - 1 ) else $rest
                    let $exp := concat("distinct-values(collection('",$config:data,$context/corpus,"/activities')/iati-activity[@iati-ad:live]/",$rest,"[",$laststep,"= $group-code]/text())")  
                    let $posnames := util:eval($exp,true())
                    let $posnames := $posnames[. ne ""] 
                    return
                          if (count($posnames) = 1)
                          then element name {attribute mined {"true"},  $posnames}
                          else if (count($posnames) > 3)
                          then element name {attribute matches {count($posnames)} }
                          else 
                            let $name :=  (for $n in $posnames order by string-length($n) return $n) [last()]
                            return 
                               element name {attribute mined {"true"}, $name}
               
              else $name
   return
     element {$facet} { 
       element code {$group-code},
       $name,
       element value {sum ($group-activities/@iati-ad:project-value) },
       element count-all {count($group-activities)},
       element count {count($group-activities[@iati-ad:include])},
       if ($dimension/summary ="compliance") then 
       (
       element with-location {count(collection(concat($config:data,$context/corpus))/activities/iati-activity[location][iati-ad:live])},
       element with-result {count(collection(concat($config:data,$context/corpus))/activities/iati-activity[result][iati-ad:live])},
       element with-document {count(collection(concat($config:data,$context/corpus))/activities/iati-activity[document-link][iati-ad:live])},
       element with-conditions {count(collection(concat($config:data,$context/corpus))/activities/iati-activity[conditions][iati-ad:live])},
       element with-DAC-sectors {count(collection(concat($config:data,$context/corpus))/activities/iati-activity[sector/@vocabulary="DAC"][iati-ad:live])}
       )
       else (),
       if ($dimension/summary="financial")
       then 
       for $year in $years 
       return  olap:sum-activities($group-activities , $year ) 
       else ()       
    }
};

declare function olap:compute-facets($context) {
let $corpus := $context/corpus
let $dimensions := doc(concat($config:config,"olap.xml"))/dimensions
let $years := $dimensions/(@from-year to @to-year)
let $olap-file :=
 <dimensions dateTime="{current-dateTime()}">
  
   {
   for $dimension in $dimensions/dimension[@path][@cache]
   return  olap:compute-facet($dimension, $years, $context)
    }
    
    {olap:host-statistics( $context)}
 </dimensions> 
let $store := xmldb:store(concat($config:olap,$corpus), "all.xml", $olap-file) 
return count($olap-file/*)
};

(:  pages :)

declare function olap:summary-page($summary,$dimension) {
     let $count-all := xs:integer($summary/count-all)
     let $years := $dimension/../(@from-year to @to-year)
     return 
          <div>
             <h3>Summary</h3>
               <table>
                  <tr><th>Code</th><td>{$summary/code/string()}</td></tr>
                  <tr><th>Name</th><td>{$summary/name/string()}  {if ($summary/name/@mined) then "*" else ()}</td></tr>
                  <tr><th>Total Activities </th><td>{$count-all}</td></tr>
                  <tr><th>Included Activities </th><td>{$summary/count/text()} 
                 { if ($count-all > 0) then concat(" (",round($summary/count div $count-all * 100 ),"%)") else () }
                 </td></tr>
                  {if ($summary/value) 
                   then <tr><th>Total Value(USD 2010)</th><td>{num:format-number(xs:double($summary/value),"$,000")}</td></tr>
                   else ()
                  }
              </table>  
           {if ($dimension/summary = "sets")
            then 
               <div>
                <h3>Sets</h3>
                <table>
                  <tr><th>Number of Activity Sets</th><td>{$summary/activitySets/text()}</td></tr>
                  <tr><th>Number downloaded </th><td>{$summary/activitySets-download/text()}</td></tr>
                </table>   
               </div>
             else ()
           }
           {if ($dimension/summary = "compliance")
            then 
                <div>
                <h3>Compliance</h3>
                 <table>
                  <tr><th>Activities with locations </th><td>{$summary/activities-with-locations/text()}</td></tr>
                  <tr><th>Activities with DAC sectors </th><td>{$summary/activities-with-DAC/text()}</td></tr>
                  <tr><th>Activities with multiple sectors</th><td>{$summary/activities-with-multiple-sectors/text()}</td></tr> 
                  <tr><th>Activities with results </th>
                        <td>{$summary/activities-with-results/text()}</td>
                        <td>{round($summary/activities-with-results div $count-all * 100 )}</td>
                  </tr>
                  <tr><th>Activities with documents </th>
                       <td>{$summary/activities-with-documents/text()}</td>
                       <td>{round($summary/activities-with-documents div $count-all * 100 )}</td>
                  </tr>
                  <tr><th>Activities with conditions </th>
                      <td>{$summary/activities-with-conditions/text()}</td>
                      <td>{round($summary/activities-with-conditions div $count-all * 100 )}</td>
                  </tr>
                </table>
               </div>
            else ()
            }
            {if ($dimension/summary="financial")
             then 
             <div>
              <h3>Financial Summary - all values in USD </h3>              
              <table border="1">
              <tr><th>Code</th><th>Transaction Type</th>{for $year in $years return <th>{$year}</th>}<th>Total</th></tr>
              {for $type in codes:codelist("ValueType")/*
               let $year-totals := 
                  for $year in $years       
                  return $summary/summary[@code=$type/code][@year=$year]/@USD-value
               let $total := sum($year-totals)
               return 
                 if ($total ne 0)
                 then
                 <tr>
                   <td>{$type/code/string()}</td><td>{$type/name/string()}</td>
                   {for $year in $years
                    let $value := $summary/summary[@code=$type/code][@year=$year]/@USD-value
                    return
                      if ($value)
                      then <td>{wfn:value-in-ks($value)}</td>
                      else <td/>
                   }
                   <td>{wfn:value-in-ks($total)}</td>
                </tr>
                else ()
               }
               </table>  
              </div>
            else ()
            }
       </div>
};

(: general facet pages :)

declare function olap:facet-list($facet as xs:string, $context) {
<div>
    <div class="nav">
        {url:path-menu(concat($context/_root,"corpus/",$context/corpus,"/",$facet),(),$config:map)}
    </div>
    <div>
       {let $filename := olap:file($context)
        let $file := doc($filename)
        return 
        <div>
          <table class="sortable"> 
            <tr><th>Code</th><th>Name</th><th>Activities</th><th>Included</th><th>Value</th></tr>
            {
             for $facet-occ in doc(olap:file($context))/dimensions/*[name() = $facet]
             order by $facet-occ/code
             return
                   <tr>
                      <th><a href="{$context/_root}corpus/{$context/corpus}/{$facet}/{$facet-occ/code}">{$facet-occ/code/string()}</a></th>
                      <td> {$facet-occ/name/string()}</td>
                      <td>{$facet-occ/count-all/string()}</td>
                      <td>{$facet-occ/count/string()}</td>
                      {if ($facet-occ/value)
                       then <td>{num:format-number(xs:double($facet-occ/value),"$,000")}</td>
                       else ()
                       }
                       <td><a href="{$context/_root}corpus/{$context/corpus}/{$facet}/{$facet-occ/code}/activity"> ..more</a></td>
                   </tr>
            }
         </table> 
        </div>
        }
     </div>
</div>   
};

declare function olap:host-stats($context) {
 let $dimension := olap:meta-dimension("Host") 
 let $summary := doc(olap:file($context))/dimensions/Host[code=$context/Host]
 return 
   if ($summary)
   then olap:summary-page($summary,$dimension)
   else ()
};

declare function olap:facet-occ($facet as xs:string, $context) {
 let $dimension := olap:meta-dimension($facet) 
 let $value := $context/*[name(.) = $facet]
 let $summary :=  doc(olap:file($context))/dimensions/*[name(.) = $facet][code=$value]
 let $name := ($summary/name,codes:code-value($facet,$value)/name)[1]
 return
<div>
            <div class="nav">
                {url:path-menu(concat($context/_root,"corpus/",$context/corpus,"/",$facet,"/",$value),("activity"),$config:map)}
                {if ($dimension/@feed)
                 then ( " > ", <a href="{$context/_fullpath}.rss"  title="RSS feed for changes in the last {$config:rss-age} days">RSS</a>)
                 else ()
                 }
            </div>
            <h2>{$value} : {$name/string()}</h2>
            {if ($summary) then olap:summary-page($summary,$dimension) else () } 
            {if ($dimension/link)
             then 
           <div>
            <h3>Links</h3>
             <ul>
              {for $link in $dimension/link
              let $href := replace($link/@href,"\{value\}",$value)
              return
               <li>
                 {if ($link/@iframe)
                 then <iframe src="{$href}" width="600" height="800" frameborder="0"/>
                 else <a class="external" href="{$href}">{$link/@label/string()}</a>
                 }
               </li>
              }
              </ul>
            </div>
             else ()
            }
</div>   
};

declare function olap:select-facet-activities($facet as xs:string, $context) as element(iati-activity)* {
   let $dimension := olap:meta-dimension($facet) 
   let $value := $context/*[name(.) = $facet]
   let $dir := concat($config:data,$context/corpus,"/activities")
   let $exp := concat("collection($dir)/iati-activity[@iati-ad:live][",$dimension/@path,"= $value]")
   return util:eval($exp)
};

declare function olap:facet-activities($facet as xs:string, $context) as element(div) {
   let $dimension := olap:meta-dimension($facet) 
   let $activities := olap:select-facet-activities($facet,$context)
   let $value := $context/*[name(.) = $facet]
   let $summary := doc(olap:file($context))/*[name(.) = $facet][code=$value]
   return
       <div>
           <div class="nav">
              {url:path-menu($context/_fullpath,(),$config:map)}
             </div>
           <h3>{$summary/name/string()}</h3>
           {activity:page($activities,$context,concat($context/_root,"corpus/",$context/corpus,"/",$facet,"/",$value,"/activity"))}        
       </div>

};
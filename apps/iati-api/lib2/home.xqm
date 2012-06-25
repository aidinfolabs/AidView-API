module namespace home = "http://kitwallace.me/home";
import module namespace iati-b = "http://kitwallace.me/iati-b" at "iati-b.xqm";
import module namespace iati-l = "http://kitwallace.me/iati-l" at "iati-l.xqm";
import module namespace iati-v = "http://kitwallace.me/iati-v" at "iati-v.xqm";
import module namespace iati-c = "http://kitwallace.me/iati-c" at "iati-c.xqm";
import module namespace wfn =  "http://kitwallace.me/wfn" at "/db/lib/wfn.xqm";
import module namespace zipapp = "http://kitwallace.me/zipapp" at "/db/lib/zipapp.xqm";

declare namespace iati-ad = "http://tools.aidinfolabs.org/api/AugmentedData";

declare function home:print-value($val as xs:double) {
   let $aval := math:abs($val)
   let $scaled-value :=
      if ($aval > 1.0E9) then concat(string(round-half-to-even($val div 1.0E9,3)),"b")
      else if ($aval > 1.0E6) then concat(string(round-half-to-even($val div 1.0E6,3)),"m")
      else if ($aval > 1.0E3) then concat(string(round-half-to-even($val div 1.0E3,3)),"k")
      else $val
   return 
      if ($val < 0) then <span style="color:red">{$scaled-value}</span> else <span>{$scaled-value}</span>
};

declare function home:sum-activities($activities as element(iati-activity)*, $date-from , $date-to, $type) {
           sum($activities/*/value
             [@iati-ad:transaction-type=$type]
             [@iati-ad:transaction-date ge $date-from]
             [@iati-ad:transaction-date lt $date-to]
             /@iati-ad:USD-value
           )
};

declare function home:content($query,$script) {
let $activity-collection := concat($iati-b:data,$query/corpus,"/activities")

return 
(: --------- type=host  --------------------- :)
if (exists($query/corpus) and $query/type = "host" and empty($query/host))
then
     let $activitySets := doc(concat($iati-b:data,$query/corpus,"/activitySets.xml"))/activitySets/activitySet
     let $hosts := doc(concat($iati-b:base,"cache/",$query/corpus,"/corpus-statistics.xml"))/stats/host
     
     return  <div  class="cache">
               <div class="nav">
                  <span>Hosts</span> >
               </div>
               <div class="body">
               <table class="sortable">
                 <tr><th>Host</th></tr>
                  {for $host in $hosts
                  
                   return <tr>
                          <td><a href="?type=host&amp;host={$host/download_url}">{$host/download_url/text()}</a></td>
                          <td>{$host/activitySets/text()}</td>
                          <td>{$host/activitySets-download/text()}</td>
                        </tr>
                  }
                </table>
               </div>
          </div>

 else 
 if (exists($query/corpus) and $query/type="host"  and exists($query/host))
 then 
     let $host-data := doc(concat($iati-b:data,"hosts.xml"))/hosts/host[@name=$query/host]  (: general host file - for comments :)
     let $host := doc(concat($iati-b:base,"cache/",$query/corpus,"/corpus-statistics.xml"))/stats/host[download_url=$query/host]
     return  <div  class="cache">
               <div class="nav">
                 
                 <a href="?type=host">Hosts</a> >
                 <span>{$query/host//string()}</span> >
                 <a href="?type=activitySet&amp;host={$query/host}">Activity Sets</a> | 
                 <a href="?type=activitySet&amp;host={$query/host}&amp;search=loaded">Loaded</a> |
                 <a href="?type=activitySet&amp;host={$query/host}&amp;search=notloaded">Not Loaded</a> |
                 <a href="?type=activitySet&amp;host={$query/host}&amp;search=stale">Stale</a>
               </div>

               <div class="body">
               <h2>Data</h2>
               <ul>
                  <li>Number of Activity Sets {$host/activitySets/text()}</li>
                  <li>Number downloaded {$host/activitySets-download/text()}</li>
                  <li>Activities {$host/activities/text()}</li>
                  <li>Live activities {$host/live-activities/text()}</li>
               </ul>
               <h2>Comment</h2>
               <pre>{$host-data/comment/string()} </pre>
                
               </div>
          </div>
 else 
(: --------- type=funder  --------------------- :)
if (exists($query/corpus) and $query/type = "funder" and empty($query/funder))
then
    let $activities := collection($activity-collection)/iati-activity[@iati-ad:live]
    let $funders := doc(concat($iati-b:base,"cache/",$query/corpus,"/corpus-statistics.xml"))/stats/funder
    return  <div  class="cache">
               <div class="nav">              
                  <span>Funders</span> >
               </div>

               <div class="body">
                <table class="sortable">
                 <tr><th>Code</th><th>Name</th><th># Activities</th></tr>
                  {for $funder in $funders
                   return <tr>
                          <td><a href="?type=funder&amp;funder={$funder/code}">{$funder/code/string()}</a></td>
                          <td>{$funder/name/string()}</td>
                          <td>{$funder/activities/text()}</td>
                         </tr>
                  }
                </table>
               </div>
          </div>

 else 
 if (exists($query/corpus) and $query/type="funder"  and exists($query/funder))
 then 
     let $funder := doc(concat($iati-b:base,"cache/",$query/corpus,"/corpus-statistics.xml"))/stats/funder[code=$query/funder]
     let $count := xs:integer($funder/activities)
     let $years := 2009 to 2013
     return  <div  class="cache">
               <div class="nav">
                 
                 <a href="?type=funder">Funders</a> >
                   <span>{$funder/code/string()}&#160; {$funder/name/string()}</span> >
                </div>

               <div class="body">
               
               <h2>Statistics</h2>
               <table>
                  <tr><th></th><th># of activities</th><th>%</th></tr>
                  <tr><th>Total </th><td>{$funder/activities/text()}</td></tr>
                  <tr><th>Activities with locations </th><td>{$funder/activities-with-locations/text()}</td></tr>
                  <tr><th>Activities with DAC sectors </th><td>{$funder/activities-with-DAC/text()}</td></tr>
                  <tr><th>Activities with multiple sectors</th><td>{$funder/activities-with-multiple-sectors/text()}</td></tr> 
                  <tr><th>Activities with results </th>
                        <td>{$funder/activities-with-results/text()}</td>
                        <td>{round($funder/activities-with-results div $count * 100 )}</td>
                  </tr>
                  <tr><th>Activities with documents </th>
                       <td>{$funder/activities-with-documents/text()}</td>
                       <td>{round($funder/activities-with-documents div $count * 100 )}</td>
                  </tr>
                  <tr><th>Activities with conditions </th>
                      <td>{$funder/activities-with-conditions/text()}</td>
                      <td>{round($funder/activities-with-conditions div $count * 100 )}</td>
                  </tr>
               </table>
               <h2>Financial Summary - all values in USD </h2>
               
              <table>
              <tr><th>Code</th><th>Transaction Type</th>{for $year in $years return <th>{$year}</th>}<th>Total</th></tr>
              {for $type in iati-c:codelist("ValueType")/*
               let $year-totals := 
                  for $year in $years         
                  return $funder/total[@type=$type/code][@year=$year]
               let $total := sum($year-totals)
               return 
                 if ($total ne 0)
                 then
                 <tr>
                   <td>{$type/code/string()}</td><td>{$type/name/string()}</td>
                   {for $year in $years         
                   return
                   <td>{home:print-value($year-totals[@year = $year])}</td>
                   }
                   <td>{home:print-value($total)}</td>
                </tr>
                else ()
              }
              </table>          
             </div>
       </div>
 else 
(: --------------- type = activitySet   ---------------- :)  
  if (exists($query/corpus) and $query/type="activitySet" )
  then
     let $activitySet := doc(concat($iati-b:data,$query/corpus,"/activitySets.xml"))/activitySets
     let $activitySets :=  
          if (exists($query/src))
          then 
              $activitySet/activitySet[download_url eq $query/src] 
          else 
              let $activitySets := $activitySet/activitySet
              return
                 if (exists($query/host)) 
                 then
                      $activitySets[host=$query/host]
                 else $activitySets 
     let $activitySets := 
          if ($query/search = "loaded") 
          then  $activitySets[download-modified] 
          else if ($query/search="notloaded")
          then  $activitySets[empty(download-modified)]       
          else if ($query/search="stale")
          then  $activitySets[cache_modified > download-modified]       
          else $activitySets          
     let $selected-activitySets :=subsequence(subsequence($activitySets,$query/start),1,$query/pagesize)
     return 
       if ($query/mode="view" and empty($query/src))
       then 
      <div>
         <div class="nav">
           
           
           {if (empty($query/host))
            then <a href="?type=host">Hosts</a> 
            else <a href="?type=host&amp;host={$query/host}">{$query/host/string()}</a>
           } >
           <span>Activity Sets {$query/host/string()}</span> > 
          </div>
  
        <div>
         {wfn:paging(concat("?corpus=",$query/corpus,"&amp;type=activitySet&amp;host=",$query/host,"&amp;search=",$query/search),$query/start,$query/pagesize,count($activitySets))}
          {iati-l:short-list-activitySets($selected-activitySets,$query/corpus)}
         </div>
     </div>
     else if ($query/mode="view" and exists($query/src))
     then
         let $activities := collection($activity-collection)/iati-activity[@iati-ad:activitySet=$query/src]
         let $selected-activities := subsequence(subsequence($activities,$query/start),1,$query/pagesize)
         return 
     <div>
        <div class="nav"> 
           
           
           <a href="?type=activitySet">Activity Sets</a> >
           <span>{$query/src/string()}</span> >
  <!--         <a href="?type=activitySet&amp;src={encode-for-uri($query/src)}&amp;mode=analysis">Analysis</a>  -->
       </div>
       <div>
          {wfn:paging(concat("?corpus=",$query/corpus,"&amp;type=activitySet&amp;src=",encode-for-uri($query/src)),$query/start,$query/pagesize,count($activities))}
          {iati-l:list-activities($selected-activities, $query/corpus)}
      </div>
    </div>
        
   else if ($query/mode="analysis" and exists($query/src) and empty($query/id))
   then  let $activities := collection($activity-collection)/iati-activity[@iati-ad:activitySet=$query/src][@iati-ad:live]       
         return
         <div>
          <div class="nav">
              
              
              <a href="?type=activitySet">Activity Sets</a> >
              <a href="?type=activitySet&amp;src={encode-for-uri($query/src)}">{$query/src}</a> >
              <span>Analysis</span>
          </div>
           {iati-v:activities-analysis($activities,concat("?mode=analysis&amp;corpus=",$query/corpus,"&amp;type=activitySet&amp;src=",encode-for-uri($query/src),"&amp;id="))}
         </div>
   else if ($query/mode="analysis" and  exists($query/src) and exists($query/id))
   then  let $activities := collection($activity-collection)/iati-activity[@iati-ad:activitySet=$query/src][@iati-ad:live]       
         return 
            <div>
             <div class="nav">
              
              
              <a href="?type=activitySet">Activity Sets</a> >
              <a href="?type=activitySet&amp;src={encode-for-uri($query/src)}">{$query/src}</a> >
              <a href="?type=activitySet&amp;src={encode-for-uri($query/src)}&amp;mode=analysis">Analysis</a> >
              <span>Code {$query/id}</span>
          </div>
            {iati-v:path-analysis($activities,$query/id)}
            </div>
   else if ($query/mode="analysis" and empty($query/src) and empty($query/id))
   then  let $activities := collection($activity-collection)/iati-activity   
         return
         <div>
          <div class="nav">
              
              
              <a href="?type=activitySet">Activity Sets</a> >
               <span>Analysis</span>
          </div>
           {iati-v:activities-analysis($activities,concat("?mode=analysis&amp;corpus=",$query/corpus,"&amp;type=activitySet&amp;id="))}
         </div>
   else if ($query/mode="analysis" and empty($query/src) and exists($query/id))
   then  let $activities := collection($activity-collection)/iati-activity[@iati-ad:live]  
         return 
            <div>
             <div class="nav">
              
              
              <a href="?type=activitySet">Activity Sets</a> >
              <a href="?type=activitySet&amp;mode=analysis">Analysis</a> >
              <span>Code {$query/id/string()}</span>
          </div>
            {iati-v:path-analysis($activities,$query/id)}
            </div>

    else ()
    
(: ------  type = activity ---------------- :)
 
   else if ($query/type="activity" and exists($query/corpus))
        then if ($query/mode="view" and exists($query/id) and $query/format="html")
             then 
               let $activity := collection($activity-collection)/iati-activity[iati-identifier=$query/id][@iati-ad:live]
               let $source := $activity/@iati-ad:activitySet/string()
            return
       <div>
           <div class="nav">
           
           
           <a href="?type=activitySet">Activity Sets</a> >
           <a href="?type=activitySet&amp;src={encode-for-uri($source)}">{$source}</a> >
           <span>{$query/id/string()}</span>
           <a href="?mode=view&amp;type=activity&amp;id={$query/id}&amp;format=xml">XML</a>

         </div>
         <div>
              { iati-v:validate-activity($activity)}
         </div>
       </div>
    else if ($query/mode="view" and exists($query/id) and $query/format="xml")
    then let $doc := collection($activity-collection)/iati-activity[iati-identifier=$query/id][@iati-ad:live]
             return $doc
     else ()
(: ------  type = code - master ---------------- :)
   else if ($query/type="code" and  empty(request:get-parameter("corpus",())))
   then 
      if ($query/mode="view" and empty($query/id))
      then 
       <div>
          <div class="nav">
           
            <span>Codelist Index</span>
          </div>
         <div class="body">
         {iati-c:code-index-as-html ()}
         </div>
       </div>
      else if ($query/mode="view" and  empty(request:get-parameter("corpus",())) and  exists($query/id))
      then  
       <div>
          <div class="nav">
           
           <a href="?type=code">Codelist Index</a>
           <span>{$query/id/string()}</span>
          </div>
         <div class="body">
         {iati-c:code-list-as-html($query/id)}
         </div>
       </div>
      else ()
 (:  --------- code and corpus -------------  :)
  else if ($query/type="code" and exists(request:get-parameter("corpus",())))
    then 
      if ($query/mode="view" and empty($query/id))
      then
        <div>
         <div class="nav">
           
           
           <span>Codelist Index</span>
         </div>
         <div class="body">
            {iati-c:code-index-as-html ($query/corpus)}
         </div>
       </div>
      else if ($query/mode="view" and exists($query/id))
      then 
       <div>
          <div class="nav">
           
           
           <a href="?type=code">Codelist Index</a>
           <span>{$query/id/string()}</span>
          </div>
         <div class="body">
            {iati-c:code-list-as-html($query/corpus ,$query/id)}
         </div> 
       </div>  
       
      else ()
  
   else if ($query/type="rule")
   then 
    <div>
          <div class="nav">
           
            <span>Rules</span>
          </div>
         <div class="body">
         {iati-v:rules-as-html()}
         </div>
       </div>
   else if ($query/mode="stats")
   then 
      let $activitySets := doc(concat($iati-b:data,$query/corpus,"/activitySets.xml"))/activitySets
       return
      <div class="cache">
          <div class="nav">
           <span>Stats</span>
          </div>
          <div>
            <div>Number of activitySets {count($activitySets/activitySet)}</div>
            <div>Number of ckan packages {count($activitySets/activitySet[package])}</div>
            <div>Number of activitySets loaded {count($activitySets/activitySet[download-modified])}</div>
            <div>Number of activities {count(collection($activity-collection)/iati-activity)}</div>
            <div>Number of live activities {count(collection($activity-collection)/iati-activity[@iati-ad:live])}</div>
            <div>Number of included activities {count(collection($activity-collection)/iati-activity[@iati-ad:include])}</div>
           </div>
      </div>
  else if ($query/mode="resources")
  then  <div >
          <div class="nav">
           
           <span>Application resources</span> 
          </div>
          <div>
            <table border ="1" class="sortable">
            <tr><th width="30%">Resource</th><th>Exported</th><th>Description</th></tr>
            {for $resource in doc(concat($iati-b:system,"resources.xml"))//resource
             return 
               <tr>
                   <td>
                      {if (ends-with($resource/@path,".xml") or ends-with($resource/@path,".xconf")) 
                       then <a href="/exist/rest/{$resource/@path}">{$resource/@path/string()}</a>
                       else $resource/@path/string()
                      }
                   </td>
                   <td>{if (empty($resource/@ignore)) then "*" else () }</td>
                   <td>{$resource/description/string()}</td>
               </tr>
            }
            </table>
          </div>
        </div>

  else if (exists($query/corpus))
   then 
      let $corpus := doc(concat($iati-b:system,"corpusindex2.xml"))//corpus[@name=$query/corpus]
      return 
      <div>
          <div class="nav">
            <a href="?type=host&amp;mode=view">Hosts</a> |
            <a href="?type=funder&amp;mode=view">Funders</a> |
            <a href="?type=activitySet">Activity Sets</a> |
            <a href="?type=code">Corpus Codelist</a> |
            <a href="?mode=stats">Statistics</a> |
            <a href="xquery/woapi.xq?corpus={$query/corpus}">Query</a>  |
  <!--         <a href="?type=activitySet&amp;mode=analysis">Analysis</a> -->

          </div>
        <div class="body">
        <h2>Views</h2>
        <ul>
           <li><a href="?type=code&amp;mode=view">Code list</a></li>
          <li> <a href="?type=rule&amp;mode=view">Rules</a></li>
          <li> <a target="_blank" href="xquery/validate.xq">Standalone Validator</a> </li>
          <li> <a target="_blank" href="xquery/woapi.xq?corpus={$query/corpus}">API</a> </li>
          <li> <a target="_blank" href="xquery/admin.xq">Admin</a> corpus updates - requires login</li>
         </ul>
         <h2>Links</h2>
            <ul>
                <li>
                    <a class="external" href="http://www.iatistandard.org">IATI Standard</a>
                </li>
                <li>
                    <a  class="external" href="http://www.iatiregistry.org/">IATI Registry</a>
                </li>
                <li>
                    <a  class="external" href="http://www.aidinfo.org/">AidInfo</a>
                </li>
                <li>
                    <a  class="external" href="http://tools.aidinfolabs.org/">AidInfoLabs</a>
                </li>
                <li>
                    <a  class="external" href="http://tools.aidinfolabs.org/explorer">IATI Data Explorer</a>
                </li>
            </ul>
         <h2>Implementation</h2>
           <ul>
             <li><a href="?mode=resources">Implementation resources</a></li>
           </ul>
         </div>
      </div>
    else ()
};


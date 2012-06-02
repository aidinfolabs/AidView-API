module namespace activity = "http://tools.aidinfolabs.org/api/activity";
import module namespace wfn = "http://kitwallace.me/wfn" at "/db/lib/wfn.xqm";  
import module namespace config = "http://tools.aidinfolabs.org/api/config" at "../lib/config.xqm";  
import module namespace codes = "http://tools.aidinfolabs.org/api/codes" at "../lib/codes.xqm";  
import module namespace olap = "http://tools.aidinfolabs.org/api/olap" at "../lib/olap.xqm";  
import module namespace num = "http://kitwallace.me/num" at "/db/lib/num.xqm";
import module namespace jxml = "http://kitwallace.me/jxml" at "/db/lib/jxml.xqm";

declare namespace iati-ad = "http://tools.aidinfolabs.org/api/AugmentedData";

(: use with caution - better performance if inlined :)

declare function activity:corpus-meta() {
  doc(concat($config:config,"corpusindex.xml"))//corpus
};

declare function activity:corpus-meta($name) {
  doc(concat($config:config,"corpusindex.xml"))//corpus[@name=$name]
};

declare function activity:corpus($corpus as xs:string)  as element(activity)* {
  collection(concat($config:data,$corpus,"/activities"))/iati-activity[@iati-ad:live]
};

declare function activity:activity($corpus as xs:string, $id as xs:string )  as element(activity)? {
   collection(concat($config:data,$corpus,"/activities"))/iati-activity[iati-identifier = $id][@iati-ad:live]
};

declare function activity:set-activities($corpus,$package) {
 collection(concat($config:data,$corpus,"/activities"))/iati-activity[@iati-ad:activitySet = $package][@iati-ad:live]
};

declare function activity:corpus($corpus as xs:string, $q as xs:string) {
  let $path := concat("collection(",$config:data,$corpus,"/activities)/iati-activity[@iati-ad:live]",$q)
  return util:eval($path)
};

declare function activity:activitySet-doc($corpus as xs:string) {
  doc(concat($config:data,$corpus,"/activitySets.xml"))/activitySets
};

declare function activity:corpus-hosts($corpus) {
   distinct-values(doc(concat($config:data,$corpus,"/activitySets.xml"))/*/activitySet/host)
};

declare function activity:host-activitySets($corpus,$host) {
    doc(concat($config:data,$corpus,"/activitySets.xml"))//activitySet[host = $host]
};

declare function activity:activitySet($corpus,$package) {
    doc(concat($config:data,$corpus,"/activitySets.xml"))//activitySet[package = $package]
};

declare function activity:activitySet-with-url($context) {
    doc(concat($config:data,$context/corpus,"/activitySets.xml"))//activitySet[download_url = $context/url]
};

declare function activity:activitySets($corpus as xs:string) {
  activity:activitySet-doc($corpus)/activitySet
};


declare function activity:ckan-packages($context) {
      let $url1 := concat($config:ckan-base,"/api/search/package?filetype=activity&amp;limit=1000")
      (: inelegant - should use the count and split into multiples of 1000 :)
      let $url2 := concat($config:ckan-base,"/api/search/package?filetype=activity&amp;start=1001&amp;limit=1000")
      let $list1 :=jxml:convert-url($url1,<params><rough/></params>)
      let $list2:=jxml:convert-url($url2,<params><rough/></params>)
      return  ($list1//results/item,$list2//results/item)
};

(:  pages :)

declare function activity:page($activities, $context, $path) {
let $subset := subsequence($activities,$context/start,$context/pagesize)
return
  <div>
           {wfn:paging-with-path2($path,$context/start,$context/pagesize,count($activities))}
          <table>  
            {for $activity in $subset
             return
                 <tr>
                    <td><a href="{$context/_root}corpus/{$context/corpus}/activity/{replace($activity/iati-identifier,"/","_")}">{$activity/iati-identifier/string()}</a></td>
                    <td>{$activity/title/string()}</td>
                 </tr> 
            }
         </table>           
  </div>
};


declare function activity:set-page($activitySets,$context,$path) {
let $subset := subsequence($activitySets,$context/start,$context/pagesize)
return
  <div>
          {wfn:paging-with-path2($path,$context/start,$context/pagesize,count($activitySets))}
          <table>  
            <tr><th>Host</th><th>CKAN</th><th>Set</th><th>Download</th><th>Activities</th><th>Downloaded</th></tr>
            {for $activitySet in $subset
             
             return
               if (exists($activitySet/host))
               then
                 <tr>
                   <td><a href="{$context/corpus}/Host/{$activitySet/host}">{$activitySet/host/string()}</a></td>
                   <td><a href="http://www.iatiregistry.org/dataset/{$activitySet/package}">CKAN</a></td>
                   <td><a href="{$context/_root}corpus/{$context/corpus}/set/{$activitySet/package}/activity">{$activitySet/package/string()}</a></td>
                   <td><a href="{$activitySet/download_url}">url</a></td>
                   <td>{count(collection(concat($config:data,$context/corpus,"/activities"))/iati-activity[@iati-ad:activitySet= $activitySet/package][@iati-ad:live])  }
                   </td>
                   <td>{$activitySet/download-modified/string()}</td>
                   {if ($context/isadmin) then <td><a href="{$context/_root}corpus/{$context/corpus}/set/{$activitySet/package}/download">Download</a></td> else ()}
                   {if ($context/isadmin and $activitySet/download-modified) then <td><a href="{$context/_root}corpus/{$context/corpus}/set/{$activitySet/package}/delete">delete</a></td>
                    else ()
                    }
                 </tr>
                else 
                 <tr>
                   <td>Missing</td>
                   <td>{$activitySet/package/string()}</td>
                   <td><a href="http://www.iatiregistry.org/dataset/{$activitySet/package}">CKAN</a></td>
  
                 </tr>
            }
         </table>           
  </div>
};

declare function activity:package-page($context) {
 let $activitySets := activity:activitySets($context/corpus)
 let $packages := activity:ckan-packages($context) 
 let $count := count($packages)
 let $pagesize :=25
 return
  <table>
     <tr><th>range</th><th>#extracted</th><th>Extracted</th></tr>
     {for $i in (1 to xs:integer( $count div $pagesize) + 1)
      let $start := ($i - 1) * $pagesize + 1
      let $loaded := count(for $package in subsequence($packages,$start,$pagesize) 
                           where exists (activity:activitySet($context/corpus,$package)/metadata_modified)
                           return $package
                           )
      return
       <tr>
           <td>{$start} to {$start + $pagesize - 1}</td>
           <td>{$loaded}</td>
           <td><a href="{$context/_root}corpus/{$context/corpus}/ckansubset?start={$start}&amp;pagesize={$pagesize}">extract</a></td>
       </tr>
      }
  </table>
};

declare function activity:node-name($node,$name) {
if ($name/string() eq normalize-space($node) or $node/string() eq "") 
then concat ("/",$name) 
else if (empty($name))
then $node/string()
else concat($node," /",$name)
};

declare function activity:code-as-html($node,$codelist) {
  if ($node)
  then 
              <tr>
                <th>{string-join(tokenize($node/name(),"-")," ")}</th>
                <td>{$node/@code/string()}</td>
                <td>{(codes:code-value($codelist,$node/@code)/name/string(),concat("(",$node,")"))[1]}</td>
              </tr>
   else ()
};

declare function activity:transaction-summary($activity) {
  let $years := 2009 to 2013
  let $summaries :=
     for $year in $years
     return olap:sum-activities($activity, $year)
  return 
    if (exists($summaries))
    then
    <tr>
      <th>Transaction Summary</th>
      <td>Values in $USD [2012]</td>
      <td>
    <table border="1">
      <tr>
      <th></th>
      {for $year in $years
       where $summaries[@year=$year]
       return element th {$year}}
      </tr>
     {for $code in ("C","D","E","IF","IR","LR","PD","R","TB")  
      where exists($summaries[@code=$code])
      return
        <tr>
          <th>{codes:code-value("ValueType",$code)/name/string()}</th>
          {for $year in $years 
           let $value := $summaries[@year=$year][@code=$code]/@USD-value
           where $summaries[@year=$year]
           return 
             if ($value)
             then element td {wfn:value-in-ks($value)}
             else element td {}
          }
        </tr>
      }
    </table>
   </td>
   </tr>
   else ()
};

declare function activity:as-html($nodes as node()*, $context ) {
   for $node in $nodes
   return
     typeswitch ($node) 
       case element(iati-activity) return
          <div class="activity">
              <h1>{$node/iati-identifier/string()}  : {string(($node/title[@xml:lang='en'], $node/title)[1])}</h1>
              {let $table :=
              <table>
                <tr><th>Hierarchy </th> <td></td> <td>{codes:code-value("RelatedActivityType",$node/@hierarchy)/name/string()}</td> </tr>
                {if ($node/@iati-ad:project-value castable as xs:double)
                 then <tr><th>Project value </th> <td>USD</td><td>{num:format-number(xs:double($node/@iati-ad:project-value),"$,000")}</td></tr>
                 else ()
                }
                 {activity:as-html($node/title, $context)}
                 {activity:as-html($node/description, $context)}
                 {activity:as-html($node/activity-status, $context)}
                   {activity:as-html($node/activity-date, $context)}
                {activity:code-as-html($node/collaboration-type, "CollaborationType")}
                {activity:code-as-html($node/default-flow-type, "FlowType")}
                 {activity:code-as-html($node/default-aid-type, "AidType")}
                 {activity:code-as-html($node/default-tied-status, "TiedStatus")}
                 {activity:code-as-html($node/default-finance-type, "FinanceType")}
                 {activity:as-html($node/reporting-org, $context)}
                 {activity:as-html($node/activity-website,$context)}
                 {activity:as-html($node/contact-info,$context)} 
                 {activity:as-html($node/participating-org, $context)}
                 {activity:as-html($node/recipient-region, $context)}
                 {activity:as-html($node/recipient-country, $context)}
                 {activity:as-html($node/sector, $context)}
                 {activity:as-html($node/related-activity, $context)}
                 {activity:transaction-summary($node)}
                 {activity:as-html($node/location,$context)}
                 
             
              </table> 
              return
               <table>
                 {for $row at $i in $table/tr
                  return
                    element tr {
                      if ($i mod 2 = 1) then attribute class {"bar"} else (),
                      $row/*
                    }
                 }
               </table>
             }
          </div>
        case element(activity-status) return
             let $name := codes:code-value("ActivityStatus",$node/@code)/name
             return <tr><th>Activity Status</th><td/><td>{$name/string()}</td></tr>
        case element(activity-date) return
              <tr>
                 <th>Date</th>
                 <td>{$node/@type/string()}</td>
                 <td>{let $date := ($node/@iso-date,$node)[1]
                      return 
                         if ($date castable as xs:date)
                         then datetime:format-date(xs:date($date),"dd MMM yyyy")
                         else $date
                      }
                 </td>
              </tr>
       
        case element(title) return
             let $lang := ($node/@xml:lang,"en")[1]
             let $name := codes:code-value("Language",$lang)/name
             return <tr><th>Title</th><td >{$name/string()}</td><td colspan="2">{$node/string()}</td></tr>
        case element(description) return
             let $lang := ($node/@xml:lang,"en")[1]
             let $name := codes:code-value("Language",$lang)/name
             return <tr><th>Description</th><td >{$name/string()}</td><td  colspan="2">{$node/string()}</td></tr>
        case element(reporting-org) return
             let $org := codes:code-value("OrganisationIdentifier",$node/@ref,$context/corpus)
             let $name := $org/name
             return 
                 <tr>
                    <th>Organisation</th>
                    <td>Reporting&#160;<a href="{$context/_root}corpus/{$context/corpus}/Publisher/{$node/@ref}">{$node/@ref/string()} </a> </td>
                    <td>
                    {activity:node-name($node,$name)}</td>
                    </tr>
        case element(participating-org) return
             let $org := codes:code-value("OrganisationIdentifier",$node/@ref,$context/corpus)
             let $name := $org/name
             let $type := codes:code-value("OrganisationType",$node/@type)
             return 
                <tr>
                  <th>Organisation</th>
                  <td>{$node/@role/string()}&#160;<a href="{$context/_root}corpus/{$context/corpus}/Participant/{$node/@ref}">{$node/@ref/string()}</a> </td>
                  <td>{activity:node-name($node,$name)}</td>
                </tr>
        case element(recipient-country) return
             let $country := codes:code-value("Country",$node/@code)
             return 
               <tr>
                 <th>Country</th>
                 <td><a href="{$context/_root}corpus/{$context/corpus}/Country/{$node/@code}">{$node/@code/string()}</a></td>
                 <td>{$country/name/string()}</td>
               </tr>
        case element(recipient-region) return
             let $region := codes:code-value("Region",$node/@code)
             return 
               <tr>
                 <th>Region</th>
                 <td><a href="{$context/_root}corpus/{$context/corpus}/Region/{$node/@code}">{$node/@code/string()}</a></td>
                 <td>{$region/name/string()}</td>
               </tr>
        case element(sector) return
             let $sector := 
                if ($node/@vocabulary = "DAC")
                then codes:code-value("Sector",$node/@code)
                else if ($node/@vocabulary = "DAC-3")
                then codes:code-value("SectorCategory",$node/@code)
                else ()
             return 
               <tr>
                 <th>Sector : {string($node/@vocabulary)} </th>
                 <td>
                   {if ($node/@vocabulary = "DAC" and $node/@code)
                    then <a href="{$context/_root}corpus/{$context/corpus}/Sector/{$node/@code}">{$node/@code/string()}</a>
                    else if ($node/@vocabulary = "DAC-3")
                    then <a href="{$context/_root}corpus/{$context/corpus}/SectorCategory/{$node/@code}">{$node/@code/string()}</a>
                    else ()
                   }
                   &#160;{if ($node/@percentage) then concat(" (",$node/@percentage,"%)") else () }
                 </td>
                 <td>               
                   {($sector/name,$node)[1]/string()}
                </td>
               </tr>
         case element(activity-website) return
              <tr>
                <th>Activity Website</th>
                <td></td>
                <td><a class="external" href="{$node}">{$node/string()}</a></td>
              </tr>
        case element(contact-info) return
              <tr>
                <th>Contact</th>
                <td/>
                <td>
                  {string-join(($node/person-name,$node/organisation,$node/mailing-address),", ")}&#160;
                  <a class="external" href="mailto:{$node/email}">{$node/email/string()}</a>
                </td>
               </tr>
        case element(related-activity) return
              <tr>
                <th>{codes:code-value("RelatedActivityType",$node/@type)/name/string()}&#160;Activity</th>
                <td>
                <a href="{$context/_root}corpus/{$context/corpus}/activity/{$node/@ref}">{$node/@ref/string()}</a>
                </td>
                <td>{$node/string()}</td>
              </tr>
       case element(location) return
              <tr>
                <th>Location</th>
                <td>{if ($node/coordinates) then 
                     <a href="http://www.openstreetmap.org/index.html?mlat={$node/coordinates/@latitude}&amp;mlon={$node/coordinates/@longitude}&amp;zoom=8">
                     Map
                     </a>
                     else ()
                    }
                </td>    
                <td>{$node/name/string()}</td>
              </tr>
            
       default return ()
};
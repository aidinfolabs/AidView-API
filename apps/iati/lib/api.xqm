
(:  
  This module provides functions to support the api, initially for whiteoctober
   Version 2 - performance improved
:)
  
module namespace api = "http://tools.aidinfolabs.org/api/api";
declare namespace iati-ad = "http://tools.aidinfolabs.org/api/AugmentedData";

import module namespace config = "http://tools.aidinfolabs.org/api/config" at "../lib/config.xqm";
import module namespace codes = "http://tools.aidinfolabs.org/api/codes" at "../lib/codes.xqm";
import module namespace olap = "http://tools.aidinfolabs.org/api/olap" at "../lib/olap.xqm";

import module namespace log = "http://kitwallace.me/log" at "/db/lib/log.xqm";
import module namespace ui = "http://kitwallace.me/ui" at "/db/lib/ui.xqm";

declare variable $api:parameters :=  doc(concat($config:config,"api.xml"))//param;
declare variable $api:version := "2012-04-26T17:00:00";
declare variable $api:max-activities := 3000;  (: maximum number of individual activities returned - if more then nothing !! :)
declare variable $api:corpii := doc(concat($config:config,"corpusindex.xml"))//corpus[empty(@hidden)];
(:
uses 
  codes:code-value($code, $value)
  codes:codelist($code)
  codes:codelist($code,$corpus)

  changed path expression to for loop in sum - almost twice the speed
  
  group functions use the olap codelists in place of distinct-values
  
:)

declare function api:sum-activities($activities as element(iati-activity)*, $date-from , $date-to, $types) {
let $types := if (exists($types)) then $types else ("C","D","E","IF","IR","LR","PD","R","TB")  
return
   element iati-ad:transaction-summary {
      for $type in $types
      return
        element iati-ad:value-analysis {
         attribute code {string($type)},
         attribute USD-value {
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

(:  
the complexity of the query leads to a generic approach in which a path expression is constructed and evaled. 

:)

declare function api:query-activities ($query as element(query) ) as element(activity)* {
  let $filters := 
     for $term in $query/term
     order by xs:integer($term/@priority)
     return 
        if (exists($term/and))
        then 
            for $value in $term/and/value
            return 
                 concat ("[",$term/path,"='",$value,"']")
         else if (exists($term/or))
         then 
             concat ("[",$term/path,"=(", 
                string-join(
                   for $value in $term/or/value
                   return concat("'",$value,"'"),
                   ",")
              ,")]")
         else
          if (exists($term/@datatype))
          then 
             concat("[",$term/@datatype,"(",$term/path,") ",$term/@comp," ",$term/@datatype,"('",$term/value,"')]")
          else (: default is xs:string :)
             concat ("[",$term/path,"='",$term/value,"']")
  let $filters := if ($query/search and string-length($query/search) > 3 ) 
  then concat($filters,"[fn:query((title|description),'",replace($query/search,"'","''"),"')]") else $filters
  let $exp := concat("collection('",$config:data,$query/corpus,"/activities')/iati-activity[@iati-ad:live][@iati-ad:include]",string-join($filters,""))
  return  util:eval($exp)
};

declare function api:activity-group-summary ($activities as element(iati-activity)*, $query as element(query)) {
   api:sum-activities($activities, $query/start-date , $query/end-date,
     if (exists($query/transaction))
     then $query/transaction
     else codes:codelist("ValueType")/*/code
   )
};

declare function api:group-by-all($query  as element(query),$activities as element(iati-activity)*)  {
let $facet := "All"
return 
   element {$facet} {
             (
             element value { sum ($activities/@iati-ad:project-value)},
             element count { count($activities)},
            if ($query/result eq "summary")
            then api:activity-group-summary($activities,$query)
             else ()
            )
       }
};

(:  some alternative approaches to the grouping task which have been tried 

(:  this function performs a distinct values to get the actual codes in the selected activities :)

declare function api:group-by-country-d($query  as element(query),$activities as element(iati-activity)*)  {
for $country in distinct-values($activities/recipient-country/@iati-ad:country)
let $code := codes:code-value("Country",$country)
let $country-activities := $activities[recipient-country/@iati-ad:country eq $country]
return 
   element Country {
       $code/code,
       $code/name,
       if ($query/result eq "ids") then ()
       else 
            (element value { sum ($country-activities/recipient-country[@iati-ad:country = $country]/@iati-ad:project-value)},
             element count {  count($country-activities) },
             if ($query/result eq "summary")
             then api:activity-group-summary($country-activities,$query)
             else ()
            )
       }
};


(: this is a generic function using the paths in the olap configuration file - but it is not as a fas as the hard coded grouping functions :)

declare function api:group-by-country-m($query  as element(query),$activities as element(iati-activity)*)  {
let $facet := "Country"
let $meta-dimension := olap:meta-dimension($facet) 
for $group in codes:codelist($facet, $query/corpus)
let $group-activities :=  util:eval(concat("$activities[",$meta-dimension/@path,"= $group/code]"))
let $count := count($group-activities)
where $count > 0
return 
   element {$facet} {
       $group/code,
       $group/name,
       if ($query/result eq "ids") then ()
       else 
            (element value { sum ($group-activities/@iati-ad:project-value)},
             element count { $count},
             if ($query/result eq "summary")
             then api:activity-group-summary($group-activities,$query)
             else ()
            )
       }
};

(: this version uses the group by construct of XQuery 3.0 - doesnt help because activities can have multiple countries :)
declare function api:group-by-country-g($query  as element(query),$activities as element(iati-activity)*)  {
for $activity in $activities
group $activity as $group-activities by $activity/recipient-country[1]/@iati-ad:country as $group-code
return
let $code := codes:code-value("Country",$group-code,$query/corpus)
return 
   element Country {
       element code {$group-code/string()},
       element name {$code/name/string()},
       if ($query/result eq "ids") then ()
       else 
            (
             element value { sum ($group-activities/@iati-ad:project-value)},
             element count { $count},
            if ($query/result eq "summary")
            then api:activity-group-summary($group-activities,$query)
             else ()
            )
       }
};
:)


declare function api:group-summary($facet as xs:string, $group as node() ,$group-activities as element(iati-activity)* ,$query as element(query))  as node()* {
let $count := count($group-activities)
where $count > 0
return 
   element {$facet} {
       $group/code,
       $group/name,
       if ($query/result eq "ids") then ()
       else 
            (element value { sum ($group-activities/@iati-ad:project-value)},
             element count { $count},
             if ($query/result eq "summary")
             then api:activity-group-summary($group-activities,$query)
             else ()
            )
       }
};

(: this function starts from the olap code list - its the fastest approach  :)


declare function api:group-by-country($query  as element(query),$activities as element(iati-activity)*)  {
let $facet := "Country"
for $group in codes:codelist($facet)/*
let $group-activities :=  $activities[recipient-country/@iati-ad:country eq $group/code]
return 
  api:group-summary($facet,$group,$group-activities,$query)
};

declare function api:group-by-region($query  as element(query),$activities as element(iati-activity)*)  {
let $facet := "Region"
for $group in codes:codelist($facet, $query/corpus)
let $group-activities :=  $activities[recipient-region/@iati-ad:region eq $group/code]
return 
   api:group-summary($facet,$group,$group-activities,$query)
};

declare function api:group-by-funder($query  as element(query),$activities as element(iati-activity)*)  {
let $facet := "Funder"
for $group in codes:codelist($facet, $query/corpus)
let $group-activities :=  $activities[participating-org/@iati-ad:funder eq $group/code]
return 
   api:group-summary($facet,$group,$group-activities,$query)
};

declare function api:group-by-sector($query  as element(query),$activities as element(iati-activity)*)  {
let $facet := "Sector"
for $group in codes:codelist($facet)/*
let $group-activities :=  $activities[sector/@iati-ad:sector eq $group/code]
return 
   api:group-summary($facet,$group,$group-activities,$query)
};

declare function api:group-by-category($query  as element(query),$activities as element(iati-activity)*)  {
let $facet := "SectorCategory"
for $group in codes:codelist($facet, $query/corpus)
let $group-activities :=  $activities[sector/@iati-ad:category eq $group/code]
return 
   api:group-summary($facet,$group,$group-activities,$query)
};

(: fetch summary results from the olap cache if it is suitable

:)

declare function api:query-olap($query) {
let $olap := collection(concat($config:base,"olap/", $query/corpus))/dimensions
return
  if (empty($olap) or exists($query/search) or empty($query/groupby)) then ()
  else  if (count($query/term) = 1 and not($query/term/@name = "ID")  and $query/groupby="All" )
  then  
     $olap/*[name()= $query/term/@name][code = $query/term//value]
  else  if (count($query/term) = 1  and $query/groupby eq $query/term/@name )  (:grouping by the selected term :)
  then  
     $olap/*[name()= $query/term/@name][code = $query/term//value]
  else if (empty($query/term) and exists($query/groupby) and $query/groupby ne "All")
  then 
     $olap/*[name()= $query/groupby]
  else if (empty($query/term) and exists($query/groupby) and $query/groupby="All")
  then 
     $olap/summary   (: no summary of a facet stored at present :)
  else ()
};

(: analyse the query string and create a query object :)

declare function api:get-url-query() as element(query){
element query {
 for $search in $api:parameters
 let $rvalues := string-join(request:get-parameter($search/@name,()),",")
 return 
   if (exists($rvalues) and $rvalues ne "")
   then 
    element term {
      attribute name {$search/@name},
      attribute priority {($search/@priority,"10")[1]},
      $search/@datatype,
      $search/@comp,
      element path {$search/@path/string()},
     if (contains($rvalues,";"))
     then 
        element and {
          for $val in tokenize($rvalues,";")
          return 
            element value{normalize-space($val)}
        }
     else if (contains($rvalues,","))
     then
        element or {
          for $val in tokenize($rvalues,",")
          return 
            element value{normalize-space($val)}
       }
     else  
       element value {normalize-space($rvalues)}
    }
  else (),
  ui:get-parameter("groupby",()),
  ui:get-parameter("orderby",()),
  ui:get-parameter("transaction",()),
  ui:get-parameter("start-date","1900-01-01"),
  ui:get-parameter("end-date","2100-01-01"),
  ui:get-parameter("start","1"),
  ui:get-parameter("pagesize",()),
  ui:get-parameter("result","help"),
  ui:get-parameter("format","xml"),
  ui:get-parameter("callback",()),
  ui:get-parameter("corpus",$api:corpii[@default]/@name/string()),
  ui:get-parameter("search",()),
  ui:get-parameter("test","yes")  
  }
};

declare function api:api-help($query as element(query)) as element(html) {
<html>
   <head>
     <title>IATI-API Query</title>
     <link rel="stylesheet" type="text/css" href="../assets/screen-2.css"/>

  </head>
    <body>
       <h1><a href="../data">IATI-API</a> Activity API</h1>
         <form action="?">
          <table border="1">
              { for $field at $i in $api:parameters
                return
                    element tr {
                      element th {$field/@name/string()},
                      if ($i = 1) then element td {
                          attribute rowspan {count($api:parameters)},
                          "Activities are selected on the basis of these conditions.  Conditions for different facets are ANDed. Multiple values for the same facet are ORed.  HTML forms create multiple parameters but multiple values may also be comma separated"
                          }
                      else (),
                      element td {
                        if (exists($field/@code))
                        then 
                           let $codelist:= codes:codelist($field/@name,$query/corpus)

                           return
                        element select {
                            attribute name {$field/@name},
                            attribute multiple {"multiple"},
                            attribute size {"5"},
                               element option { attribute value {""} ,concat(" ..any ",$field/@code) },             
                                 for $code in $codelist
                                 order by $code/name
                                 return
                                    element option {
                                       attribute value {$code/code},
                                       concat($code/code," : ", if ($code/name ne "") then $code/name else " not listed ")
                                    }
           
                               }
                       else 
                         <input type="string" name="{$field/@name}" size="100"/>
                        }
                     }
               }
       <tr><th>Search</th><td>string search in title, description and sector names</td><td>
       <input type="text" name="search" size="20"/></td></tr>
       <tr><th>start-date</th><td>The start date for transaction summary - yyyy-mm-dd default way back</td>
       <td><input type="text" name="start-date" size="10"/></td>
       </tr>
       <tr><th>end-date</th><td>The end date for transaction summary - yyyy-mm-dd default way forword</td>
       <td><input type="text" name="end-date" size="10"/></td>
       </tr>
       <tr><th>transaction type</th>
          <td>transaction type for transaction summary. 'Transaction' here includes planned disbursements and budgets.</td>
          <td><select name="transaction"multiple="multiple" size="10">
            <option value="">all transaction types</option>
            {for $code in codes:codelist("ValueType")/*
             let $name := $code/name/string()
             return
               <option value="{$code/code}" title="{$code/description}"> 
               {$code/code/string()} - {$name}
               </option> 
            }
          </select>
          </td>
       </tr>
       <tr><th>groupby</th>
           <td>The facet of the data over which activities are to be summarised</td>
           <td><select name="groupby" size="7" >
                 <option value="">no grouping</option>
                 <option value="All">group all selected activities</option>
                { for $field at $i in $api:parameters[@group="yes"]
                  let $name := $field/@name/string()
                  return
                    element option {
                        if ($name = $query/groupby )
                        then attribute selected {"selected"}
                        else (),
                        $name
                    }
                 }
                </select>
           </td>
        </tr>
        <tr><th>orderby</th><td>order in which results are returned</td>
           <td>
             <select name="orderby" size="6">
               <option value=""> unordered</option>
               <option value="value">value - deceasing activity  value</option>
               <option value="count">count - decreasing number of activities</option>
               <option value="code">code - alphabetic order of code or iati-identifier</option>
               <option value="name">name - alphabetic order of name or title</option>
               <option value="start-actual">start-actual- descending order of actual project start date</option>
              </select>
           </td>
        </tr>
        <tr><th>start</th>
            <td>index of first item to be returned : default 1</td>
            <td><input type="string" name="start" size="5" value="{($query/start,"1")[1]}"/></td>
        </tr>
        <tr><th>pagesize</th>
            <td>number of items to be returned : default all items</td>
            <td><input type="string" name="pagesize" size="5" value="{$query/pagesize}"/></td>
        </tr>

        <tr><th>result</th>
            <td>default help</td>
            <td>
              <select name="result" size="6">
                <option value="values">values  : code,name and value of group or activity</option>           
                <option value="count"> count : number of activities selected</option>
                <option value="ids">ids : list of ids of groups or activities </option>           
                <option value="summary">summary : for activities: base data + transaction summary for all or selected transaction types</option>
                <option value="geo">geo : for activities: base data + locations where available</option>
                <option value="list">list  : for activities :  code,name,value and funding org of activity</option>           
                <option value="details">details : for activities: selected data</option>
                <option value="full">full : full, augmented XML of activities selected</option>
               <option value="help">help : API documentation</option>
              </select>
           </td>
         </tr>
        <tr><th>format</th><td>default xml</td>
            <td>
              <select name="format" size="2">
                <option>xml</option>
                <option>json</option>
              </select>
            </td>
        </tr>
        <tr><th>callback</th>
            <td>callback for JSONP : optional</td>
            <td>  
                <input type="string" name="callback" size="20" value="{$query/callback}"/>
            </td>
        </tr>
       <tr><th>corpus</th>
            <td>set of activities to search over ; </td>
            <td>  
                <select name="corpus" size="3">
                {for $corpus in $api:corpii
                 return 
                    element option {
                       if ($corpus/@name = $query/corpus)
                       then attribute selected {"selected"}
                       else (),
                       $corpus/@name/string()
                    }
               }
              </select>
            </td>
        </tr>
        <tr><th>test</th><td>if yes, the query is returned along with the elapsed milliseconds</td>
            <td><select name="test">
                   <option>yes</option>
                   <option>no</option>
                </select>
            </td>
        </tr>
      </table>
       <input type="submit" />


      </form>
      <h2>Examples (running on the default corpus)</h2>
      <ul>
         <li> <a href="?groupby=Country&amp;result=values&amp;test=yes">All activities grouped by Country</a></li>
         <li> <a href="?Country=AF&amp;groupby=Sector&amp;result=values&amp;test=yes">Activities in Afganistan grouped by Sector</a></li>
         <li> <a href="?groupby=Funder&amp;result=values&amp;test=yes">All activities grouped by Funder</a></li>
         <li> <a href="?ID=GB-1-102603-101&amp;result=full&amp;test=yes">The full document for a specific activity</a></li>

      </ul>
   </body>
 </html>
};

declare function api:api() {
let $run-start := util:system-time()
let $query := api:get-url-query()
return
if ($query/result= ("count","ids","values","summary","full","geo","details","list"))
then 
  let $selected-groups := 
      if (empty($query/groupby)) then ()
      else
         let $selected-groups := api:query-olap($query)
         return 
            if ($selected-groups) 
            then $selected-groups 
            else 
              let $selected-activities := api:query-activities($query) 
              let $activity-count := count($selected-activities)
              return
                  if ($query/groupby eq "All")
                  then api:group-by-all($query,$selected-activities)
                  else  if ($query/groupby eq "Country")
                  then api:group-by-country($query,$selected-activities)
                  else if ($query/groupby eq "Region")
                  then api:group-by-region($query,$selected-activities)
                  else if ($query/groupby eq "SectorCategory")
                  then api:group-by-category($query,$selected-activities)
                  else if ($query/groupby eq "Sector")
                  then api:group-by-sector($query,$selected-activities)
                  else if ($query/groupby eq "Funder")
                  then api:group-by-funder($query,$selected-activities)
                  else ()
                  
   let $selected-groups :=
        if (empty($selected-groups)) then ()
        else if (empty($query/orderby))
             then $selected-groups
             else if ($query/orderby eq "name")
             then for $group in $selected-groups order by $group/name  return $group
             else if ($query/orderby eq "code")
             then for $group in $selected-groups order by $group/code return $group
             else if ($query/orderby eq "value")
             then for $group in $selected-groups order by xs:double($group/value) descending return $group
             else if ($query/orderby eq "count")
             then for $group in $selected-groups order by xs:double($group/count) descending return $group
             else $selected-groups
        
  let $group-count := count($selected-groups)
     
  let $selected-activities :=
      if (exists($query/groupby)) then ()
      else  api:query-activities($query) 
  
  let $activity-count := count($selected-activities)
  
  let $selected-activities :=
      if ($activity-count = 0 or ($activity-count > $api:max-activities and empty($query/pagesize)) ) then ()   (: then sort the  activities :)
      else 
      if (empty($query/orderby))
      then $selected-activities
      else if ($query/orderby eq "name")
      then for $activity in $selected-activities order by $activity/title[1]  return $activity
      else if ($query/orderby eq "code")
      then for $activity in $selected-activities order by $activity/iati-identifier return $activity
      else if ($query/orderby eq "value")
      then for $activity in $selected-activities order by xs:double($activity/@iati-ad:project-value) descending return $activity
      else if ($query/orderby eq "start-actual")
      then for $activity in $selected-activities[activity-date/@type="start-actual"] order by $activity/activity-date[@type="start-actual"] descending return $activity
      else $selected-activities
 (: for pagination an item may be an activity or a group :)
     
  let $selected-items := if ($query/groupby) then $selected-groups else $selected-activities     
 
  let $selected-items := 
      if ($query/start castable as xs:integer)
      then subsequence($selected-items,xs:integer($query/start))
      else  $selected-items
  let $selected-items := 
      if ($query/pagesize castable as xs:integer)
      then subsequence($selected-items,1,xs:integer($query/pagesize))
      else  $selected-items

let $run-end := util:system-time()
let $run-milliseconds := (($run-end - $run-start) div xs:dayTimeDuration('PT1S'))  * 1000 
(: let $logit := log:log-request("iati","api",concat($run-milliseconds,"-",$activity-count,"-",$group-count)) :)

let $result :=
element result {
   attribute version {$api:version},
   attribute activity-count {$activity-count},
   if (exists($query/groupby)) 
   then attribute group-count {count($selected-groups)} 
   else (),
   if ($query/test eq "yes") 
   then 
      element test {
        attribute elapsed-milliseconds {$run-milliseconds},     

          $query
      }
   else (),
   if ($query/result eq "count")
   then ()
   else if ($query/result=("values","ids"))
   then if (empty($query/groupby))
        then 
             for $activity in $selected-items 
             return 
                element iati-activity {
                     element code {$activity/iati-identifier/string()},
                     element name {$activity/title[1]/string()},
                     element value {$activity/@iati-ad:project-value/string()}
              }
         else $selected-items 
   else if ($query/result="list" and empty($query/groupby))
   then 
             for $activity in $selected-items 
             return 
                element iati-activity {
                     element code {$activity/iati-identifier/string()},
                     element name {$activity/title[1]/string()},
                     element value {$activity/@iati-ad:project-value/string()},
                     $activity/participating-org[@iati-ad:funder][1]
                }
  else if ($query/result eq "summary" and empty($query/groupby))
  then
     for $activity in $selected-items
     return
      element iati-activity {
         $activity/iati-identifier,
         $activity/title[1],
         $activity/recipient-country,       
         api:sum-activities($activity,$query/start-date, $query/end-date,$query/transaction)
      }
 else if ($query/result eq "details" and empty($query/groupby))
 then
     for $activity in $selected-items
     return
      element iati-activity {
         $activity/
         (iati-identifier,title[1],reporting-org,participating-org,recipient-country,recipient-region, 
          collaboration-type, default-flow-type, default-aid-type, default-tied-status, related-activity, document-link, 
          activity-date, description, sector, contact-info),
         api:sum-activities($activity,$query/start-date, $query/end-date,$query/transaction)
      }
  else if ($query/result eq "summary" and exists($query/groupby))
  then
     $selected-items   
  else if ($query/result eq "full" and empty($query/groupby))
  then 
     $selected-items
  else ()
}

return
  if ($query/format eq "xml")
  then $result
  else if ($query/format eq "json")
  then 
       let $option := util:declare-option ("exist:serialize","method=text media-type=application/json")
       let $header := response:set-header("Access-Control-Allow-Origin", "*")
       let $json := util:serialize($result,"method=json media-type=application/json")    (: ok  in 2.0 :)
       return
           if ($query/callback ne "")
           then 
              concat($query/callback,"(",$json,")")
           else $json
  else ()  
else 
  let $option := util:declare-option("exist:serialize","method=xhtml media-type=text/html")
  return
      api:api-help($query)
}; 
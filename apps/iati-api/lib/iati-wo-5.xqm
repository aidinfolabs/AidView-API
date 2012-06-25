(:  
  This module provides functions to support the api, initially for whiteoctober
  
:)
  
module namespace iati-wo = "http://kitwallace.me/iati-wo";
declare namespace iati-ad = "http://tools.aidinfolabs.org/api/AugmentedData";

import module namespace iati-b = "http://kitwallace.me/iati-b" at "iati-b.xqm";
import module namespace iati-c = "http://kitwallace.me/iati-c" at "iati-c.xqm";

import module namespace log = "http://kitwallace.me/log" at "/db/lib/log.xqm";
import module namespace ui = "http://kitwallace.me/ui" at "/db/lib/ui.xqm";
import module namespace json="http://kitwallace.me/json" at "../lib/json.xqm";

declare variable $iati-wo:parameters :=  doc(concat($iati-b:system,"woquery.xml"))//param;
declare variable $iati-wo:version := "2011-11-19T17:00:00";
declare variable $iati-wo:id := util:uuid();
(:
uses 
  iati-c:code-value($code, $value)
  iati-c:codelist($code)
  iati-c:codelist($code,$corpus)


  changed path expression to for loop in sum - almost twice the speed
  
  group functions could be refactored to perhaps 2 using eval 
  
:)

declare function iati-wo:sum-activities($activities as element(iati-activity)*, $date-from , $date-to, $types) {
let $types := if (exists($types)) then $types else iati-c:codelist("ValueType")/code
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

declare function iati-wo:query-activities ($query as element(query) ) as element(activity)* {
  let $logit := log:log-request("iati-p","api","start-expression")
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
  let $exp := concat("collection('",$iati-b:data,$query/corpus,"/activities')/iati-activity",string-join($filters,""),"[@iati-ad:live][@iati-ad:include]")
  let $logit := log:log-request("iati-p",$iati-wo:id,$exp)

  let $activities := util:eval($exp)
  let $logit := log:log-request("iati-p",$iati-wo:id,string(count($activities)))
  return $activities
 };

declare function iati-wo:activity-group-values ($activities) {

     (element value { sum (for $activity in $activities return xs:double($activity/@iati-ad:project-value))},
      element count {count($activities)}
     )
};

declare function iati-wo:activity-group-summary ($activities, $query) {
   iati-wo:sum-activities($activities, $query/start-date , $query/end-date,
     if (exists($query/transaction))
     then $query/transaction
     else iati-c:codelist("ValueType")/*/code
   )
};

declare function iati-wo:group-by-country($query  as element(query),$activities as element(iati-activity)*)  {
let $facet := "Country"
let $group-codes := distinct-values($activities/recipient-country/@iati-ad:country)
return
for $group-code in $group-codes
let $code := iati-c:code-value($facet,$group-code,$query/corpus)
return 
   element {$facet} {
       element code {$group-code},
       element name {$code/name/string()},
       if ($query/result eq "ids") then ()
       else 
           let $group-activities := $activities[recipient-country/@iati-ad:country eq $group-code]
           return
            (
            iati-wo:activity-group-values($group-activities),
            if ($query/result eq "summary")
            then iati-wo:activity-group-summary($group-activities,$query)
             else ()
            )
       }
};

declare function iati-wo:group-by-region($query  as element(query),$activities as element(iati-activity)*)  {
let $facet := "Region"
let $group-codes := distinct-values($activities/recipient-region/@iati-ad:region)
return

for $group-code in $group-codes
let $code := iati-c:code-value($facet,$group-code,$query/corpus)
return 
   element {$facet} {
       element code {$group-code},
       element name {$code/name/string()},
       if ($query/result = "ids") then ()
       else 
         let $group-activities :=  $activities[recipient-region/@iati-ad:region eq $group-code]
         return
            (
            iati-wo:activity-group-values($group-activities),
            if ($query/result eq "summary")
            then iati-wo:activity-group-summary($group-activities,$query)
             else ()
            )
       }
};

declare function iati-wo:group-by-funder($query  as element(query),$activities as element(iati-activity)*)  {
let $facet := "Funder"
let $group-codes := distinct-values($activities/participating-org/@iati-ad:funder)
return

for $group-code in $group-codes
let $code := iati-c:code-value("Funder",$group-code,$query/corpus)
return 
   element {$facet} {
       element code {$group-code},
       element name {$code/name/string()},
       if ($query/result eq "ids") then ()
       else
         let $group-activities := $activities[participating-org/@iati-ad:funder eq $group-code]
         return
            (
            iati-wo:activity-group-values($group-activities),
            if ($query/result eq "summary")
            then iati-wo:activity-group-summary($group-activities,$query)
             else ()
            )
       }
};


declare function iati-wo:group-by-sector($query  as element(query),$activities as element(iati-activity)*)  {
  let $logit := log:log-request("iati-p",$iati-wo:id,"group by sector")
let $facet :="Sector"
let $group-codes := distinct-values($activities/sector/@iati-ad:sector)
  let $logit := log:log-request("iati-p",$iati-wo:id,"distinct")
return

for $group-code at $i in $group-codes
let $code := iati-c:code-value($facet,$group-code,$query/corpus)
 let $logit := if ($i = 1 or $i mod 10 = 0) then log:log-request("iati-p",$iati-wo:id,"code value") else ()
return 
   element {$facet} {
       element code {$group-code},
       element name {$code/name/string()},
       if ($query/result eq "ids") then ()
       else
         let $group-activities :=  $activities[sector/@iati-ad:sector eq $group-code]
         let $logit := if ($i = 1 or $i mod 10 = 0) then log:log-request("iati-p",$iati-wo:id,"grouped") else ()
        return
            (
            iati-wo:activity-group-values($group-activities),
            if ($query/result eq "summary")
            then iati-wo:activity-group-summary($group-activities,$query)
             else ()
            )
         }
};


declare function iati-wo:group-by-category($query  as element(query),$activities as element(iati-activity)*)  {
let $facet := "SectorCategory"
let $group-codes := distinct-values($activities/sector/@iati-ad:category)
return

for $group-code in $group-codes
let $code := iati-c:code-value($facet,$group-code,$query/corpus)
return 
   element {$facet} {
       element code {$group-code},
       element name {$code/name/string()},
       if ($query/result eq "ids") then ()
       else
         let $group-activities:=  $activities[sector/@iati-ad:category eq $group-code]
         return
            (
            iati-wo:activity-group-values($group-activities),
            if ($query/result eq "summary")
            then iati-wo:activity-group-summary($group-activities,$query)
             else ()
            )
         }
};

declare function iati-wo:get-url-query() as element(query){
element query {
 for $search in $iati-wo:parameters
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
  ui:get-parameter("corpus","test2"),
  ui:get-parameter("test","yes")  
  }
};
 
declare function iati-wo:api-help($query) {
<html>
   <head>
     <title>IATI-API Query</title>
     <link rel="stylesheet" type="text/css" href="../assets/screen-2.css"/>
     <meta name="robots" content="noindex, nofollow"/>

  </head>
    <body>
       <h1><a href="admin.xq">IATI-API</a> Activity API</h1>
         <form action="?">
          <table border="1">
              { for $field at $i in $iati-wo:parameters
                return
                    element tr {
                      element th {$field/@name/string()},
                      if ($i = 1) then element td {
                          attribute rowspan {count($iati-wo:parameters)},
                          "Activities are selected on the basis of these conditions.  Conditions for different facets are ANDed. Multiple values for the same facet are ORed.  HTML forms create multiple parameters but multiple values may also be comma separated"
                          }
                      else (),
                      element td {
                        if (exists($field/@code))
                        then 
                           let $codelist := iati-c:codelist($field/@name,$query/corpus)

                           return
                        element select {
                            attribute name {$field/@name},
                            attribute multiple {"multiple"},
                            attribute size {"5"},
                               element option { attribute value {""} ,concat(" ..any ",$field/@code) },             
                                 for $code in $codelist/*
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
            {for $code in iati-c:codelist("ValueType")/*
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
           <td><select name="groupby" size="6" >
                 <option value="">no grouping</option>
                { for $field at $i in $iati-wo:parameters[@group="yes"]
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
             <select name="orderby" size="4">
               <option value=""> unordered</option>
               <option value="value">value - deceasing activity  value</option>
               <option value="count">count - decreasing number of activities</option>
               <option value="code">code - alphabetic order of code or iati-identifier</option>
               <option value="name">name - alphabetic order of name or title</option>
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
                {for $corpus in doc(concat($iati-b:system,"corpusindex.xml"))//corpus[empty(@hidden)]/text()
                 return 
                    element option {
                       if ($corpus = $query/corpus)
                       then attribute selected {"selected"}
                       else (),
                       $corpus
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

declare function iati-wo:api() {
let $run-start := util:system-time()
let $logit := log:log-request("iati-p",$iati-wo:id,"start")

let $query := iati-wo:get-url-query()
let $logit := log:log-request("iati-p",$iati-wo:id,"query")
return
if ($query/result= ("count","ids","values","summary","full","geo"))
then 
  let $selected-activities := iati-wo:query-activities($query) 

 let $logit := log:log-request("iati-p",$iati-wo:id,"selected")

let $activity-count := count($selected-activities)
let $selected-groups := 
    if (exists($query/groupby))
      then if ($query/groupby eq "Country")
      then iati-wo:group-by-country($query,$selected-activities)
      else if ($query/groupby eq "Region")
      then iati-wo:group-by-region($query,$selected-activities)
      else if ($query/groupby eq "SectorCategory")
      then iati-wo:group-by-category($query,$selected-activities)
      else if ($query/groupby eq "Sector")
      then  iati-wo:group-by-sector($query,$selected-activities)

      else if ($query/groupby eq "Funder")
      then iati-wo:group-by-funder($query,$selected-activities)
      else ()
   else ()
let $logit := log:log-request("iati-p",$iati-wo:id,"grouped")
   
let $group-count := count($selected-groups)

let $selected-groups :=
      if (exists($selected-groups))
      then if (empty($query/orderby))
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
      else ()
      
let $logit := log:log-request("iati-p",$iati-wo:id,"sorted")
     
let $selected-activities :=
      if (empty($query/groupby))   (: then sort the  activities :)
      then if (empty($query/orderby))
      then $selected-activities
      else if ($query/orderby eq "name")
      then for $activity in $selected-activities order by $activity/title[1]  return $activity
      else if ($query/orderby eq "code")
      then for $activity in $selected-activities order by $activity/iati-identifier return $activity
      else if ($query/orderby eq "value")
      then for $activity in $selected-activities order by xs:double($activity/@iati-ad:project-value) descending return $activity
      else $selected-activities
      else ()
      
(: for pagination an item may be an activity or a group :)
let $selected-items :=  if (exists($query/groupby)) then $selected-groups else $selected-activities
let $selected-items := 
      if ($query/start castable as xs:integer)
      then subsequence($selected-items,xs:integer($query/start))
      else  $selected-items
let $selected-items := 
      if ($query/pagesize castable as xs:integer)
      then subsequence($selected-items,1,xs:integer($query/pagesize))
      else  $selected-items

let $logit := log:log-request("iati-p",$iati-wo:id,"paginated")
let $run-end := util:system-time()
let $run-milliseconds := (($run-end - $run-start) div xs:dayTimeDuration('PT1S'))  * 1000 

let $result :=
element result {
   attribute version {$iati-wo:version},
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
  
  else if ($query/result eq "summary" and empty($query/groupby))
  then
     for $activity in $selected-items
     return
      element iati-activity {
         $activity/iati-identifier,
         $activity/title,
         $activity/reporting-org/@code,
         $activity/recipient-country,
         iati-wo:sum-activities($activity,$query/start-date, $query/end-date,$query/transaction)
      }
  else if ($query/result eq "summary" and exists($query/groupby))
  then
     $selected-items   
  else if ($query/result eq "full" and empty($query/groupby))
  then 
     $selected-items
  else if ($query/result eq "geo" and empty($query/groupby))
  then   
     let $geo-locations := collection(concat($iati-b:base,"geo"))
     for $activity in $selected-items
     let $activity-location := $geo-locations//iati-activity[iati-identifier = $activity/iati-identifier]
     return
        element iati-activity {
            $activity/iati-identifier,
            $activity/title,
            $activity/reporting-org/@code,
            $activity/recipient-country,
            $activity-location/location
          }
  else ()
}
let $logit := log:log-request("iati-p",$iati-wo:id,"reported")

return
  if ($query/format eq "xml")
  then $result
  else if ($query/format eq "json")
  then 
       let $option := util:declare-option ("exist:serialize","method=text media-type=application/json")
       let $header := response:set-header("Access-Control-Allow-Origin", "*")
       let $json  := json:xml-to-json($result)
(:     let $json := util:serialize($result,"method=json media-type=application/json"  - preferable but unusable - returns two copies  see bugtracker :)
       return
           if ($query/callback ne "")
           then 
              concat($query/callback,"(",$json,")")
           else $json
  else ()  
else 
  let $option := util:declare-option("exist:serialize","method=xhtml media-type=text/html")
  return
      iati-wo:api-help($query)
}; 
import module namespace iati-b = "http://kitwallace.me/iati-b" at "../lib/iati-b.xqm";
import module namespace iati-c = "http://kitwallace.me/iati-c" at "../lib/iati-c.xqm";
import module namespace iati-wo = "http://kitwallace.me/iati-wo" at "../lib/iati-wo.xqm";

import module namespace ui = "http://kitwallace.me/ui" at "/db/lib/ui.xqm";

declare function local:get-url-query($parameters) as element(query){
element query {
 for $search in $parameters
 let $rvalues := string-join(request:get-parameter($search/@name,()),",")
 order by $search/@name
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
  ui:get-parameter("start-date",()),
  ui:get-parameter("end-date",()),
  ui:get-parameter("start","1"),
  ui:get-parameter("pagesize",()),
  ui:get-parameter("result",()),
  ui:get-parameter("corpus","test2"),
  ui:get-parameter("search",()),
  ui:get-parameter("test","yes")  
  }
};

let $parameters :=  doc(concat($iati-b:system,"woquery.xml"))//param

let $query := local:get-url-query($parameters)

return 
 if ($query/result = "help")
 then 
     let $serialise := util:declare-option("exist:serialize","method=html media-type=text/html")
     return iati-wo:api-help($query)
 else 
 
let $run-start := util:system-time()
let $olap := doc(concat($iati-b:base,"olap/", $query/corpus,".xml"))/dimensions
let $selected-groups :=
  if (empty($olap)) then ()
  else if (count($query/term) = 1 and not($query/term/@name = "ID")  and $query/groupby="All" )
  then 
    let $filter :=
                concat(
                        "[code =(",                      
                        string-join(
                            for $value in $query/term//value
                            return concat("'",$value,"'"),
                            ","),
                        ")]"
                )
    let $exp := concat("$olap/",$query/term/@name,$filter)
    return util:eval($exp)
  else if (empty($query/term) and exists($query/groupby) and $query/groupby ne "All")
  then 
     let $exp := concat("$olap/",$query/groupby)
     return util:eval($exp)
  else if (empty($query/term) and exists($query/groupby) and $query/groupby="All")
  then 
     $olap/summary
  else ()
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
     
let $run-end := util:system-time()
let $run-milliseconds := (($run-end - $run-start) div xs:dayTimeDuration('PT1S'))  * 1000
return
<result  milliseconds = "{$run-milliseconds}" >
  {$query}
  {$selected-groups}
</result>
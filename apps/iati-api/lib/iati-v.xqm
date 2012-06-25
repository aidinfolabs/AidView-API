(:
 this module deals with validating an activity 
 
 :)
 
module namespace iati-v = "http://kitwallace.me/iati-v";
import module namespace iati-b = "http://kitwallace.me/iati-b" at "iati-b.xqm";
import module namespace iati-c = "http://kitwallace.me/iati-c" at "iati-c.xqm";

declare variable $iati-v:errorTypes :=
  <errorTypes>
    
    <errorType name="Schema" priority="1" class="error"/>
    <errorType name="Compliance" priority="2" class="warn"/>
  </errorTypes>;

declare function iati-v:error($message as element(message)) as element(errorType)? {
  $iati-v:errorTypes/errorType[@name=$message/@errortype]
};

declare function iati-v:validation-analysis ($messages as element(message)*)  as element(validation) {
  let $messages := 
         for $distinct in distinct-values($messages)
         return $messages[. = $distinct][1]
  let $errorAnalysis :=
    element errorTypes
      {
      for $errorType in $iati-v:errorTypes/errorType
      return
          element errorType {
             $errorType/@name,
             attribute count {count($messages[@errortype = $errorType/@name])}        
          }
      }
  let $errors := sum($errorAnalysis/errorType/@count)
  return 
    element validation {
        attribute count {$errors},
        $errorAnalysis,
        $messages
    }
};

declare function iati-v:activities-analysis($activities as element(iati-activity)*, $distribution-url as xs:string?) as element(div) {
       <div> <p>Counting only values which are not the empty string  </p>
             <table border="1" class="sortable">
               <thead>
                 <tr><th>Code</th><th>Name</th><th>Path</th><th># occurrences</th><th/></tr>
               </thead>
               <tbody>
                
               { let $paths := $iati-b:paths/path[@code]
                 for $path in $paths
                 let $code := $path/@code/string()
                 let $name := string(($path/@name,$path/@code)[1])
                 let $exp := concat("$activities/",$path,"[. ne '']")
                 let $activities := util:eval($exp)
                 let $count := count($activities)
                 order by $code
                 return 
                  <tr> {if ($count ne 0) then attribute class {"good"} else () }
                      <td>{$code}</td>
                      <td>{$name}</td>
                      <td>{$path/string()}</td>
                      <td>{$count}</td>
                      <td>{if ($count = 0) then () else  <a href="{$distribution-url}{encode-for-uri($path)}">Distribution</a>}</td>
                  </tr>
                }
                </tbody>
             </table>
       </div>
};

declare function iati-v:path-analysis($activities as element(iati-activity)*, $path as xs:string) as element(div) {
  let $pathentry := $iati-b:paths/path[. = $path]
  let $exp := concat("distinct-values($activities/",$path,"[. ne ''])")
  let $groups := util:eval($exp)
  return
  <div>
  <h2>{$pathentry/@code/string()} &#160; {$pathentry/@name/string()} No of groups {count($groups)}</h2>
  <table border="1" class="sortable">
  <tr><th>Value</th><th>Code</th><th>Code name</th><th># activities</th></tr>
    {for $group in $groups
     let $code := iati-c:code-value($pathentry/@code/string(),$group)
     let $exp := concat("count($activities[",$path ," = $group])")
     let $count := util:eval($exp)
     return
      <tr><td>{$group}</td><td>{$code/code/string()}</td><td>{$code/name/string()}</td><td>{$count}</td></tr>
    }
  </table>
  </div>
};

declare function iati-v:assertion-validation($activity as element(iati-activity)) as element(message)* {
    for $path in $iati-b:paths/path[@assertion]
    let $exp := $path
    let $result := util:eval($exp)
    return
      if (not($result))
      then <message  activity = "{$activity/iati-identifier}" errortype="{($path/@errortype,'Compliance')[1]}"> {$path/@assertion/string()}</message>
      else ()
};

declare function iati-v:activity-schema-validation($activity as element(iati-activity)) as element(message)* {
  let $schema   := doc(concat($iati-b:base,"schemas/iati-activities-schema.xsd"))
  let $common   := doc(concat($iati-b:base,"schemas/iati-common.xsd"))
  let $xml      := doc(concat($iati-b:base,"schemas/xml.xsd"))
  let $report :=  validation:jaxv-report($activity, ($schema,$common,$xml))
  for $error in $report/message
  return <message  activity = "{$activity/iati-identifier}" errortype='Schema'>{$error}</message>
};

declare function iati-v:activity-validation($activity as element(iati-activity)) as element(message)* {
  let $schema-errors := iati-v:activity-schema-validation($activity)
  let $assertion-errors := iati-v:assertion-validation($activity)
  return ($schema-errors,$assertion-errors)
};

declare function iati-v:validate-activity($activity as element(iati-activity)) as element(div){
  let $messages := iati-v:activity-validation($activity)
  let $report := iati-v:validation-analysis($messages)
  let $parsedXML := iati-v:nested-validation($activity,"",$activity)
  return
    <div>
      <table>
      <tbody>  
      {for $message in $report/message
       let $errorType := iati-v:error($message)
       order by xs:integer($errorType/@priority), $message/@errortype, $message
       return 
       <tr>         
          <td class="{$errorType/@class}">{$message/@errortype/string()}</td>
          <td>{$message/string()}</td>
       </tr>
      }
      {for $class in ("error","warn","missing")
       let $count := count($parsedXML//span[@class=$class])
       return
         if ($count > 0)
         then 
          <tr>
            <td class="{$class}">{$class}</td>
            <td>{$count}</td>
         </tr>
         else ()
      }
      </tbody>
      </table>
      {$parsedXML}
    </div>
};

declare function iati-v:check($value as xs:string, $path as xs:string) as element(span)* {
(: should allow for multiple test on the same path :) 
     let $path := if (starts-with ($path,"/")) then substring($path,2) else $path
     let $test := $iati-b:paths/path[. = $path]
     let $test := if ($test) 
                  then $test 
                  else $iati-b:paths/path[.= tokenize($path,"/")[last()]]
     let $error :=
        if (empty($test)) then 
             ()
        else 
        if ($test/@code)
        then if ($value="")
             then <span class="warn">empty</span>
             else 
                let $code := iati-c:code-value($test/@code,$value)
                return 
                  if (empty($code))
                  then <span class="missing">Unknown <a href="?type=code&amp;id={$test/@code}">{$test/@code/string()}</a></span>
                  else <span class="good"><a href="?type=code&amp;id={$test/@code}">{$test/@code/string()}</a> : {$code/name/string()}</span>
        else if ($test/@id = "Activity")
             then if ($value="")
                  then <span class="warn">empty</span>
                  else  <span ><a href="?mode=view&amp;type=activity&amp;id={$value}">Activity</a></span>
         else if ($test/@type="xs:anyURI")
        then 
              if (exists(doc($value)))
                 then <span class="good"><a href="{$value}">Link</a></span>
                 else <span class="error">Bad link <a href="{$value}">Link</a></span>

        else if ($test/@type)
        then 
            let $exp := concat("'",$value,"' castable as ",$test/@type)
            let $e := util:eval($exp)
            return
              if ($e)
              then <span class="good">{$test/@type/string()}</span>
              else <span class="error">Invalid {$test/@type/string()}</span>
              else ()
 (:     let $e := error((),"x",$error) :)
      return $error
};

declare function iati-v:nested-validation($activity as element(iati-activity), $path as xs:string, $element)  {
    if (exists ($element/(@*|node())))
    then 
     <table border="1">
        {if (exists($element/text()))
         then 
           let $check := iati-v:check($element,$path)
           return
               <tr  class="text">
                    <th ></th>
                    <td >{$element/text()} {$check}</td>                  
              </tr>
         else ()
       }
       {for $attribute in $element/@*
       let $path := concat($path,"/@",name($attribute))
       let $check := iati-v:check($attribute,$path)
       return
         <tr  class="attribute">
              <th>@{name($attribute)}</th>
              <td>{string($attribute)} {$check}</td>
          </tr>
       }
       {for $node in $element/*
        let $path := concat($path,"/",name($node))
        let $check := iati-v:check($node,$path)
        return 
            <tr class="element">
                 <th>{name($node)}</th> 
                 <td>
                    { iati-v:nested-validation($activity,$path,$node)    } 
                 </td>
             </tr>       
        }
    </table>
    else  
         $element/text()
};
 
declare function iati-v:rules-as-html() {
<div>
  <table class="sortable">
  <thead>
  <tr><th>Order</th><th>Class</th><th>Detail</th><th>Expresssion</th></tr>
  </thead>
  <tbody>
  {
  for $check at $i in $iati-b:paths/path
  return
     if (exists($check/@code))
     then 
         <tr><td>{$i}</td><th>Code</th><td><a href="?type=code&amp;id={$check/@code}">{$check/@code/string()}</a></td><td>{$check/string()}</td></tr>
     else if (exists($check/@type))
     then
        <tr><td>{$i}</td><th>Type</th><td>{$check/@type/string()}</td><td>{$check/string()}</td></tr>

     else if (exists($check/@assertion))
     then 
        <tr><td>{$i}</td><th>Compliance</th><td>{$check/@assertion/string()}</td><td>{replace($check,"$activity","")}</td></tr>
    else ()
  }
  </tbody>
  </table>
</div>
};
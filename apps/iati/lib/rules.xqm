(:
 this module deals with validating a document against a set of rules
 
 inso far is it is bound to the codes module it is specific to IATI
 
  
 :)
 
module namespace rules = "http://tools.aidinfolabs.org/api/rules";
import module namespace config = "http://tools.aidinfolabs.org/api/config" at "../lib/config.xqm";
import module namespace codes = "http://tools.aidinfolabs.org/api/codes" at "../lib/codes.xqm";
import module namespace wfn = "http://kitwallace.me/wfn" at "/db/lib/wfn.xqm";

declare variable $rules:rulesets := collection(concat($config:config,"rules"))/ruleset;
declare variable $rules:profiles := collection(concat($config:config,"/profiles"))/profile;
declare variable $rules:activity-rulesets := $rules:rulesets[@root="iati-activity"];

declare function rules:profile($name as xs:string)  as element(profile) {
    $rules:profiles[@name=$name]
};

declare function rules:ruleset($name as xs:string) as element(ruleset)?{
    ($rules:rulesets[concat(@name,"-",@version) = $name],
     $rules:rulesets[@name=$name]
     )[1]
};

declare function rules:profile-rules($name as xs:string)  {
    let $profile := rules:profile($name)
    for $rulesetname in $profile/ruleset/@name
    return rules:ruleset($rulesetname)/rule   (: simple concatenation :)
};

declare function rules:codelist-rules($codelist) {
   $rules:activity-rulesets/rule[codelist=$codelist]
};

declare function rules:check-node($doc, $this, $steps as xs:string*, $rules as element(rule) ) as element(span)* {
     let $leaf := $steps[last()]
     let $path := concat("/",string-join($steps,"/"))

     for $rule in $rules[path = ($path,$leaf)]
     where (empty($rule/pre) or (exists($rule/pre)) and util:eval($rule/pre))
     return
        if ($rule/codelist)
        then if (empty($this))
             then <result rule="{$rule/@id}" error="missing"/>
             else 
                let $code := codes:code-value($rule/codelist,$this)
                return 
                  if (empty($code))
                  then <result rule="{$rule/@id}" error="unknown"/>
                  else <result rule="{$rule/@id}" name="{$code/name}"/> 
        else if ($rule/type)
        then 
            let $exp := concat("'",$this,"' castable as ",$rule/type)
            let $e := util:eval($exp)  (: try here :)
            return
              if ($e)
              then <result rule="{$rule/@id}"/>
              else <result rule="{$rule/@id}" error="invalid"/>
        else if ($rule/assertion)
        then   
             let $result := util:eval($rule/assertion)
             return
               if (not($result))
               then <result rule="{$rule/@id}" error="fail"/>
               else <result rule="{$rule/@id}"/>
        else ()
 
};

declare function rules:check-sequence($doc, $node, $steps as xs:string*,  $rules as element(rule) ) as element(span)* {
  let $path := concat("/",string-join($steps,"/"))
  let $sequence := if (exists($steps)) then concat($path,"/*") else "/*" 
  let $rules := $rules[path = $sequence] 
  return
    if (empty($rules)) then ()
    else 
    let $this := util:eval(concat("$doc",if (exists($steps)) then $path else "")) (:the set of all nodes with this path :)
    let $first := $this[1]   (: this is the first element with this path in the document :)
    return
      if (not($node is $first)) then ()
      else
       for $rule in $rules
       return     
          let $result := 
               if (empty($rule/pre) or (exists($rule/pre)) and util:eval($rule/pre))
               then util:eval($rule/assertion)
               else ()
          return
               if (empty($result))
               then ()
               else if ($result) 
               then <result rule="{$rule/@id}"/>
               else <result rule="{$rule/@id}" error="fail"/>
};

declare function rules:validation-errors($doc, $this, $steps as xs:string*,  $rules)  {
    if (exists ($this/(@*|node())))
    then 
       (
       for $check in rules:check-sequence($doc, $this, $steps, $rules)[@error]
       let $rule := $rules[@id=$check/@rule]
       return
          element error {
             attribute ruleset {tokenize($rule/@id,":")[1]},
             $check/@*,
             $rule/*
          }
       , 
       
       for $attribute in $this/@*
       for $check in rules:check-node($doc, $attribute, ($steps,concat("@",name($attribute))) , $rules)[@error]
       let $rule := $rules[@id=$check/@rule]
       return
          element error {
             attribute ruleset {tokenize($rule/@id,":")[1]},
             $check/@*,
             element value {string($attribute)},
             $rule/*
          }
       ,
       
        for $node in $this/node()
        return       
           rules:validation-errors($doc, $node, ($steps,name($node)) , $rules) 
      )
   else ()
};
 
declare function rules:validation-errors($doc,$rules) {
  rules:validation-errors($doc,$doc,(),$rules)
};

declare function rules:validate-doc($doc, $this, $steps as xs:string*, $rules ,$mode)  {
    if (exists ($this/(@*|node())))
    then 
      element table {
        attribute border {1},
        for $check in rules:check-sequence($doc, $this, $steps, $rules)
        where $mode="full" or ($mode="errors" and exists($check/@error))
        return 
          <tr>
            <th>*</th>
            <td>{rules:check-as-html($check,$rules)}</td>
          </tr>,
                   
        for $check in rules:check-node($doc, $this, $steps, $rules)
        where $mode="full" or ($mode="errors" and exists($check/@error))
        return 
          <tr>
            <th></th>
            <td>{rules:check-as-html($check,$rules)}</td>
          </tr>,

        if (exists($this/text()))
         then 
          <tr  class="text">
             <th ></th>
             <td >{$this/text()}</td>                  
          </tr>
         else ()
       ,
       for $attribute in $this/@*
       return
         <tr  class="attribute">
              <th>@{name($attribute)}</th>
              <td>{string($attribute)}
                {for $check in rules:check-node($doc, $attribute, ($steps,concat("@",name($attribute))), $rules)
                 where $mode="full" or ($mode="errors" and exists($check/@error))
                 return rules:check-as-html($check,$rules)
                }
              </td>
          </tr>
        ,
        for $node in $this/node()
        return       
             <tr class="element">
                 <th>{name($node)}</th> 
                 <td>
                    { rules:validate-doc($doc, $node, ($steps,name($node)), $rules, $mode)    } 
                 </td>
             </tr> 
      }
    else  
         $this/text()
};

declare function rules:validate-doc($doc,$rules,$mode) {
    let $report := rules:validate-doc($doc,$doc,(),$rules,$mode)
    let $errors := count($report//span[@class="fail"])
    return 
    <div>
        {if ($errors = 0)
         then <h2>No  Errors </h2>
         else <h2 class="fail">{$errors} Errors</h2>
        }
       {$report}
    </div>
};

declare function rules:view-doc($doc, $this, $steps as xs:string*, $rules as element(rule)*)  {
    if (exists ($this/(@*|node())))
    then 
      element table {
        attribute border {1},
        if (exists($this/text()))
         then 
          <tr class="text">
             <th ></th>
             <td >{$this/text()}</td>                  
          </tr>
         else ()
       ,
       for $attribute in $this/@*
       return
         <tr  class="attribute">
              <th>@{name($attribute)}</th>
              <td>{if (starts-with($attribute,"http://"))
                   then <a href="{$attribute}">{string($attribute)}</a>
                   else string($attribute)
                   }
                  {rules:expand-code($attribute,($steps,concat("@",name($attribute))), $rules)}
              </td>
          </tr>
        ,
        for $node in $this/node()
        return       
             <tr class="element">
                 <th>{name($node)}</th> 
                 <td>
                    { rules:view-doc($doc, $node, ($steps,name($node)), $rules) } 
                 </td>
             </tr> 
      }
    else  
         $this/text()
};
 
declare function rules:view-doc($doc,$rules  as element(rule)*) {
   rules:view-doc($doc,$doc,(),$rules) 
};

declare function rules:expand-code($this,$steps,$rules) {     
     let $leaf := $steps[last()]
     let $path := concat("/",string-join($steps,"/"))
     for $rule in $rules[path = ($path,$leaf)][codelist]
     where (empty($rule/pre) or (exists($rule/pre)) and util:eval($rule/pre))
     return
        if ($this ne "")
        then 
         let $code := codes:code-value($rule/codelist,$this)
         return 
           if (empty($code))
           then <span class="warn"> {if ($rule/codelist = "OrganisationIdentifier")
                       then <a href="http://opencirce.org/org/code/{$this}">{string($this)}</a>
                       else ()
                      }   missing  &#160; <a href="/data/codelist/{$rule/codelist}">{$rule/codelist/string()}</a></span>
           else <span class="info">
                      {if ($rule/codelist = "OrganisationIdentifier")
                       then <a href="http://opencirce.org/org/code/{$code/code}">{$code/name/string()}</a>
                       else $code/name/string()
                      }              

                   &#160;  
                   <a href="/data/codelist/{$rule/codelist}">{$rule/codelist/string()}</a>
                 </span>
        else <span class="warn"> empty  &#160;<a href="/data/codelist/{$rule/codelist}">{$rule/codelist/string()}</a></span>
       
};


declare function rules:check-as-html($check,$rules) {
let $rule := $rules[@id=$check/@rule]
return
  if (empty($rule)) then () else
  (<span>
     {if ($check/@error) then attribute class {"fail"} else attribute class{"pass"}}
     <a href="/data/rule/{$rule/@id}">R</a>
   </span>,
   <span>
     {string-join((
      $check/@error,
      $rule/type,
      $check/@name,
      $rule/description),
      " "
      )
      }
      &#160;
   
      {
      if ($rule/codelist) 
      then <a href="/data/codelist/{$rule/codelist}">{$rule/codelist/string()} </a>
      else ()
      }
 
   </span>
  )
};


declare function rules:rulesets-as-html () as element(div) {
         <div>
            <table border="1">
             {for $ruleset in $rules:rulesets
              return
                 <tr><td><a href="/data/ruleset/{$ruleset/@name}">{string($ruleset/@name)}</a> </td> 
                     <td>{$ruleset/@root/string()}</td>
                     <td>{$ruleset/@version/string()}</td>
                     <td>{$ruleset/description/node()}</td>
                 </tr>
             }
            </table>
          </div>
};

declare function rules:ruleset-as-html($name as xs:string ) as element(div) {
let $ruleset := $rules:rulesets[@name=$name]
return
<div>
  <h1>{string-join(($ruleset/@name,$ruleset/@version,$ruleset/@xml:lang,$ruleset/@root)," ")}</h1>
  <div>{$ruleset/description/node()}</div>

  <table class="sortable" border="1">
  <thead>
   <tr><th>id</th><th>Test</th><th>Path</th>
   <th>Description</th></tr>
  </thead>
  <tbody>
  {
  for $rule in $ruleset/rule
  return
     <tr>
        <td><a href="/data/rule/{$rule/@id}">{string($rule/@id)}</a></td>
        <td>{if($rule/codelist) then "Code" else if ($rule/type) then "Type" else if ($rule/target) then "Ref" else if ($rule/assertion) then "Assertion" else ()}</td>
        <td>{string($rule/path)}</td>     
        <td>{$rule/description/text()}</td>
     </tr>
   
  }
  </tbody>
  </table>
</div>
};

declare function rules:ruleset-as-csv($name as xs:string) {
let $config :=
<table>
   <column name="path" />
   <column name="type" />
   <column name="pre"/>
   <column name="codelist"/>
   <column name="assertion"/>
   <column name="description"/>
</table>
let $ruleset := $rules:rulesets[@name=$name]
let $table :=  wfn:element-to-csv($ruleset, $config)
return $table
};

declare function rules:rule-as-html ($rule as element(rule)) as element(div) {
let $t := tokenize($rule/@id,":")
return
   <div>
     <table class="sortable" border="1">
       <tr><th>Ruleset</th><td><a href="?ruleset={$t[1]}">{$t[1]}</a></td></tr>
       <tr><th>id</th><td>{string($rule/@id)}</td></tr>
       <tr><th>Path</th><td>{string($rule/path)}</td></tr>
       {if ($rule/pre) then  <tr><th>Pre-condition</th><td>{string($rule/pre)}</td></tr> else ()}
       {if ($rule/assertion) then <tr><th>Assertion</th><td>{string($rule/assertion)}</td></tr> else ()}
       {if ($rule/type) then <tr><th>Type</th><td>{string($rule/type)}</td></tr> else ()}
       {if ($rule/target) then <tr><th>Ref</th><td>{string($rule/target)}</td></tr>  else ()}
       {if ($rule/codelist) then <tr><th>Codelist</th><td><a href="/data/codelist/{$rule/codelist}">{string($rule/codelist)}</a></td></tr>  else ()}
       <tr><th>Description</th><td>{
         if ($rule/description) 
         then string($rule/description)
         else if ($rule/codelist) then "Code"
         else if ($rule/type) then "Type"
         else if ($rule/target) then "Ref"
         else ()
         }</td></tr>
     </table>
   </div>
};


declare function rules:error-summary($errors as element(error)* ) as element(summary) {
 element summary {
    attribute errors {count($errors)},
    for $ruleset in distinct-values($errors/@ruleset)
    return
      element ruleset {
          attribute name {$ruleset},
          attribute errors {count($errors[@ruleset= $ruleset])},
          for $rule in distinct-values($errors[@ruleset=$ruleset]/@rule)
          let $errors := $errors[@rule = $rule]
          let $terror := $errors[1]
          return
             element rule {
               attribute id {$rule},
               attribute errors {count($errors[@rule=$rule])},
               string(($terror/type,$terror/codelist,$terror/description)[1])
             }
          }
   }    
};

declare function rules:error-summary-as-html($summary as element(summary)) as element(div) {
<div>
   {if ($summary/@errors = 0)
   then <h2>No Errors</h2>
   else <h2 class="fail">Total errors :{$summary/@errors/string()} </h2>
   }
   {
   for $ruleset in $summary/ruleset
   return
     <div>
        <h2><a href="/data/ruleset/{$ruleset/@name}">{$ruleset/@name/string()}</a>  errors : {$ruleset/@errors/string()}</h2>
         <ul>
         {for $rule in $ruleset/rule
          return
           <li><a href="/data/rule/{$rule/@id}">{$rule/@id/string()}</a> &#160; 
           {$rule/@errors/string()} &#160;{$rule/string()}</li>
         }
        </ul>
     </div>
   }
</div>
};
(: codelist :)

declare function rules:codelist-rules-as-html($codelist) {
   <div>
     <table border="1">
        {for $rule in rules:codelist-rules($codelist)
        return
          <tr>
             <th><a href="/data/ruleset/{$rule/../@name}">{$rule/../@name/string()}</a></th>
             <td>{$rule/path/string()}</td>
          </tr>
        }
    </table>
  </div>
};


(: profiles :)

declare function rules:profiles-as-html () as element(div){
         <div>
            <table border="1">
             {for $profile in $rules:profiles
              return
                 <tr><td><a href="/data/profile/{$profile/@name}">{string($profile/@name)}</a> </td> 
                     <td>{$profile/description/node()}</td>
                 </tr>
             }
            </table>
          </div>
};

declare function rules:profile-as-html ($name as xs:string) as element(div) {
let $profile := $rules:profiles[@name=$name]
return
         <div>
            <table border="1">
                 <tr><td>{string($profile/@name)}</td> 
                     <td>{$profile/@root/string()}</td>
                     <td colspan="2">{$profile/description/node()}</td>
                 </tr>
                 {for $ruleset in $profile/ruleset
                 return 
                   <tr><td><a href="/data/ruleset/{$ruleset/@name}">{$ruleset/@name/string()}</a></td><td>{$ruleset/@threshold/string()}</td>
                      
                      <td>
                        <table>
                           {for $rule in $ruleset/rule
                           return
                             <tr><td><a href="/data/rule/{$rule/@id}">{$rule/@id/string()}</a></td><td>{$rule/@threshold/string()}</td></tr>
                           }
                        </table>
                     </td>
                  </tr>
                 }
            </table>
          </div>
};

declare function rules:profile-summary($summaries as element(summary)*, $profile as element(profile)) {
let $activity-count := count($summaries)
return
   element report {
      attribute activities {$activity-count},
      for $ruleset in $profile/ruleset
      let $failed-activities := $summaries/ruleset[@name=$ruleset/@name]
      let $passes := $activity-count - count($failed-activities)
      let $pass-rate := round($passes div $activity-count * 100)
      let $threshold := xs:integer($ruleset/@threshold)
      return 
       element ruleset {
            attribute name {$ruleset/@name},
            attribute passes {$passes},
            attribute pass-rate {$pass-rate},
            attribute threshold {$threshold},
            if ($pass-rate ge $threshold) then attribute pass {} else (),
            for $ruleid in distinct-values($failed-activities/rule/@id)
            order by $ruleid
            return
               let $failed-rules := $failed-activities/rule[@id=$ruleid]
               let $passes := $activity-count - count($failed-rules)
               let $pass-rate := round($passes div $activity-count * 100)
               let $threshold := xs:integer(($ruleset/rule[@id=$ruleid]/@threshold,100)[1])
            return
              element rule {
                attribute id {$ruleid},
                attribute passes {$passes},
                attribute pass-rate {$pass-rate},
                attribute threshold {$threshold},
                if ($pass-rate ge $threshold) then attribute pass {} else (),
                 $failed-rules[1]/string()
              }
       }
    }
};

declare function rules:profile-report-to-html($report) {
<div>
   <h1>Profile report : {$report/@activities/string()} Activities</h1>
   {for $ruleset in $report/ruleset
    let $rules := rules:ruleset($ruleset/@name)/rule
    return 
     <div>
     <h2>
       {attribute class {if ($ruleset/@pass) then "good" else "error"}}
       {$ruleset/@name/string()}  passes {$ruleset/@pass-rate/string()}%  threshold {$ruleset/@threshold/string()}%</h2>
       <table border="1">
          <tr>
             <th>Rule</th>
             <th>Passes</th>
             <th>Passes%</th>
             <th>Threshold%</th>
             <th>Description</th>
          </tr>
       {for $rule in $rules
        let $error := $ruleset/rule[@id=$rule/@id]
        return 
          if ($error)
          then
          <tr>
              {attribute class {if ($error/@pass) then "good" else "error"}}
              <td><a href="/data/rule/{$rule/@id}">{$rule/@id/string()}</a></td>
              <td>{$error/@passes/string()}</td>
              <td>{$error/@pass-rate/string()}</td>
              <td>{$error/@threshold/string()}</td>
              <td>{$rule/description/string()}</td>
         </tr>
         else 
             <tr>
              {attribute class { "good" }}
               <td><a href="/data/rule/{$rule/@id}">{$rule/@id/string()}</a></td>
              <td></td>
              <td></td>
              <td></td>
              <td>{$rule/description/string()}</td>
         </tr>

       }
       </table>
     </div>
   }
</div>

};
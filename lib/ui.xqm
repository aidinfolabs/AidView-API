module namespace ui= "http://kitwallace.me/ui";
import module namespace wfn = "http://kitwallace.me/wfn" at "/db/lib/wfn.xqm";

declare function ui:get-entity($entity) {
element {($entity/@entity,$entity/@name)[1]}
  {for $attribute in $entity/attribute[not(@form-type="file")]
   return
     ui:get-parameter($attribute/@name/string(), $attribute/@default/string())
  }
};

declare function ui:get-entity-from-form($form) {
element {$form/@entity}
  {for $attribute in $form/attribute[not(@form-type="file")]
   return
     ui:get-parameter($attribute/@name/string(), $attribute/@default/string())
  }
};

declare function ui:entity-to-form($entity) {
  <div>
    {for $attribute in $entity/attribute
     return 
       <div>
          <label for="{$attribute/@name}" title="{$attribute/comment}">{string(($attribute/@form-label,$attribute/@name)[1])}</label>
          <input type="{string(($attribute/@form-type,'text')[1])}" name="{$attribute/@name}" id="{$attribute/@name}" size="{$attribute/@size}"/>
       </div>
    } 
  </div>  
};

declare function ui:entity-to-form-2($entity, $current) {
<div>
  {for $attribute in $entity/attribute[@hidden]
   return 
     <input type="hidden" name="{$attribute/@name}" id="{$attribute/@name}" value="{$current/*[name(.) = $attribute/@name]}"/>
   }
  <table>
    {for $attribute in $entity/attribute[empty(@hidden)]
     return 
        <tr>
          <th><label for="{$attribute/@name}" title="{$attribute/comment}">{string(($attribute/@form-label,$attribute/@name)[1])}</label></th>
          <td>
          {if ($attribute/option)
           then 
              <select name="{$attribute/@name}" id="{$attribute/@name}" size="{$attribute/@size}">
                {let $val := $current/*[name(.) = $attribute/@name]
                 for $option in $attribute/option
                 return
                   element option {
                      $option/@*,
                      if ($option/@value = $val) then attribute selected {"selected"} else (),
                      $option/node()
                   }
                }
              </select>
           else if ($attribute/@form-type="text")
           then 
             let $dim:= tokenize($attribute/@size,"\*")
             return
               <textarea name="{$attribute/@name}" id="{$attribute/@name}" rows="{$dim[1]}" cols="{$dim[2]}">
                  {$current/*[name(.) = $attribute/@name]/node()}
               </textarea>
           else
              <input type="{string(($attribute/@form-type,'text')[1])}" name="{$attribute/@name}" id="{$attribute/@name}" size="{$attribute/@size}"
               value="{$current/*[name(.) = $attribute/@name]}"/>
           }  
          </td>
       </tr>
    } 
  </table>  
</div>
};

declare function ui:csv-to-entity($csv, $entity, $delimiter) {
let $rows := tokenize($csv, "&#10;")
return
   element  {concat($entity/@name,"s")}  { 
          attribute created {current-dateTime()},
          for $row in $rows
          let $cols := tokenize(normalize-space($row),$delimiter)  
          let $row :=
                element {$entity/@name} 
                   { 
                    for $attribute at $i in $entity/attribute[@computed]
                    let $value := $cols[$i] 
                    let $value := normalize-space($value) 
                    let $valid := 
                         if ($attribute/@datatype) 
                         then if ($attribute/@datatype = "decimal" and $value castable as xs:decimal) 
                              then $value castable as xs:decimal
                              else if ($attribute/@datatype = "integer")
                              then $value castable as xs:integer
                              else if ($attribute/@format) 
                              then matches($value,$attribute/@format)
                              else $value ne ""
                         else $value ne ""
                    let $value := 
                      if ($valid) 
                      then if ($attribute/@compute) 
                           then util:eval($attribute/@compute)
                           else $value
                      else ()
                    
                    return  
                       if (exists($value) or $attribute/@nullable = "true")
                       then 
                          element {$attribute/@name} { $value}
                       else () 
                    }

            return 
                 $row
          }
};

declare function ui:get-parameter($name as xs:string?, $default as xs:string?) {
  let $vals := request:get-parameter($name,$default)
  return
    if (exists($vals))
    then 
       for $val in $vals
       let $val := normalize-space($val)
       return 
         if ($val ne "")
         then element {$name} {$val}
         else ()
    else ()
};

declare function ui:dot ($doc, $format) {
    let $form :=
        <httpclient:fields>
           <httpclient:field name="output" value="{$format}"/>
           <httpclient:field name="dot" value="{normalize-space($doc)}" />
       </httpclient:fields>   
    let $response := httpclient:post-form(xs:anyURI("http://www.cems.uwe.ac.uk/~cjwallac/apps/services/dot2media.php"),$form,false(),())
    return $response/httpclient:body/node()
};

declare function ui:rows-as-table($label , $rows) {
  if (exists($rows))
  then 
     <tr>
        <th>{$label}</th>
        <td>
            <table class="level3">
              {$rows}
            </table>
        </td>
     </tr> 
   else ()
};

declare function ui:row($label, $data) {
  if (exists($data))
  then 
     <tr>
        <th>{$label}</th>
        <td>
           {$data}
        </td>
     </tr> 
   else ()
};

 
declare function ui:element-to-nested-table($element) {
    if (exists ($element/(@*|*)))
    then 
     <table>
        {if (exists($element/text()))
         then <tr  class="text">
                    <th ></th>
                    <td >{$element/text()}</td>
              </tr>
         else ()
       }
       {for $attribute in $element/@*
       return
         <tr  class="attribute">
              <th>@{name($attribute)}</th>
              <td>{string($attribute)}</td>
         </tr>
       }
       {for $node in $element/*
       return 
            <tr class="element">
                 <th>{name($node)}</th> 
                 <td>
                    { ui:element-to-nested-table($node)    }
                 </td>
             </tr>       
        }
    </table>
    else   
       $element/text() 
};
 
 declare function ui:element-to-table($element) {

(: assumes all items in $elemnt/* have the same simple element structure determined by the structure of the first item :)
let $first := $element/*[1]
return
  <table border="1" class="sortable">
     <tr>
        <th>Row</th>
        {for $node in $first/*
         return <th>{wfn:camel-case-to-words(name($node))}</th> 
        }
     </tr>
      {for $row at $i in $element/*
       return
         <tr> 
             <td>{$i}</td>
            {for $node in $first/*
             let $data := data($row/*[name(.)=name($node)])
             return <td>{$data}</td> 
           } 
         </tr>
      }
   </table>
 };
 
 declare function ui:element-to-csv($element) as xs:string {

(: returns a  multi-line string of comma delimited strings  :)
let $sep := ","
return
string-join(
  (string-join($element/*[1]/*/name(.),$sep),
   for $row in $element/*
       return
         string-join(
          for $node in $element/*[1]/*
          let $data := string($row/*[name(.)=name($node)])
          return
               if (contains($data,$sep))
               then concat('"',$data,'"')
               else $data
           , $sep)
   ),$str:nl )
};

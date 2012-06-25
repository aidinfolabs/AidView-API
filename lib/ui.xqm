module namespace ui= "http://kitwallace.me/ui";
import module namespace wfn = "http://kitwallace.me/wfn" at "/db/lib/wfn.xqm";

declare function ui:get-entity($entity) {
element {$entity/@name}
  {for $attribute in $entity/attribute
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


declare function ui:get-parameter($name as xs:string?, $default as xs:string?) {
  let $vals := request:get-parameter($name,())
  return
    if (exists($vals) and string-join($vals,"") ne "")
    then 
       for $val in $vals
       let $val := normalize-space($val)
       return 
         if ($val ne "")
         then element {$name} {$val}
         else ()
    else  if (exists($default) )
    then element {$name} {$default}
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
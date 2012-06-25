module namespace mapp = "http://kitwallace.me/mapp";

declare function mapp:model($model,$entity) {
  $model/entity[@name=name($entity)]
};

declare function mapp:entity($data,$id) {
  $data//*[id=$id]
};

declare function mapp:label($model,$entity as element()?) {
  let $model := mapp:model($model,$entity)
  return string(util:eval($model/attribute[@name="label"]/rule))
};

declare function mapp:search-label($model,$entity as element()?) {
  let $model := mapp:model($model,$entity)
  return 
     if (exists($model/attribute[@name="searchlabel"]))
     then string(util:eval($model/attribute[@name="searchlabel"]/rule))
     else string(util:eval($model/attribute[@name="label"]/rule))
};

declare function mapp:previous($entity) {
  $entity/preceding-sibling::*[1]/id
};

declare function mapp:next($entity) {
  $entity/following-sibling::*[1]/id
};

declare function mapp:entity-label($model,$id as xs:string?) as xs:string?{
  if (exists($id))
  then mapp:label($model, mapp:entity($model, $id))
  else ()
};

declare function mapp:make-view($query,$type,$entity) as element(table) {
<div>
 <table>
 <tr><th>Type</th><td>{name($entity)}</td></tr>
 {
 for $attribute in $type/attribute[empty(@primarykey)]
 for $item in 
      if (exists($attribute/@derived))
      then string(util:eval($attribute/rule))
      else $entity/*[name(.) = $attribute/@name]/string()

 where $item ne ""
 return
  <tr>
    <th> {if (exists($attribute/@derived)) then "/" else ()}
    {($attribute/@label,$attribute/@name)[1]/string()}
   </th>
    <td>
    {
     if (exists ($type/../entity[@name= $attribute/@type]))
     then 
       <a class="internal" href="?mode=view&amp;id={$item}">{mapp:entity-label($item)}</a>
     else if ($attribute/@type="uri")
     then 
       <a class="external" href="{$item}" target="_blank">{$item}</a>
     else if ($attribute/@type="image")
     then 
       <a  href="{$item}"><img src="{$item}" height="300"  /></a>
     else 
       $item
    }
    </td>
  </tr>
  }

  {for $rel in $mapp:data//*[. = $entity/id][not(name(.)="id")]
   let $relentity := $rel/..
   let $label := mapp:label($relentity)
   order by $label
   return 
     <tr><th>is {name($rel)} of </th><td><a href="?mode=view&amp;id={$relentity/id}">{$label}</a></td></tr>
  }
 </table>
 
</div>
};

declare function mapp:view-entity($query) as element(div) {
 let $entity := mapp:entity($query/id)
 let $model := mapp:model($entity)
 return 
   mapp:make-view($query,$model,$entity)
};

declare function mapp:entity-selection($type,$attribute,$value)  {
<select name="{$attribute/@name}">
 {if (exists($attribute/@min)) then
   element option {
     if (empty ($value) or $value="")
     then attribute selected {"true"}
     else (),
     attribute value {""},
     " none "
   }
  else ()
 }
 {for $entity in $mapp:data//*[name(.) = $type]
  let $label := mapp:label($entity)
  order by $label
  return 
    if ($entity/id = $value)
    then <option value="{$entity/id}" selected="true">{$label}</option>
    else <option value="{$entity/id}">{$label}</option>
 }
</select> 
};

declare function mapp:type-selection($type,$attribute,$value)  {
<select name="{$attribute/@name}">
 {if (exists($attribute/@min)) then
   element option {
     if (empty ($value) or $value="")
     then attribute selected {"true"}
     else (),
     attribute value {""},
     " none "
   }
  else ()
 }
 {for $enum in $type/enum
  order by $enum
  return 
    if ($value = $enum/@value)
    then <option value="{$enum/@value}" selected="true">{$enum/string()}</option>
    else <option value="{$enum/@value}">{$enum/string()}</option>
 }
</select> 
};

declare function mapp:make-form($query,$type,$element) as element(form) {
 <form action="?">
   <input type="hidden" name="mode" value="update"/>
   <input type="hidden" name="Type" value="{$type/@name}"/>
   <input type="hidden" name="id" value="{$query/id}"/>
   <input type="submit" value="Update"/>

   <table>
 <tr><th>Type</th><td/><td>{name($element)}</td></tr>
{for $attribute in $type/attribute[empty(@derived)]
let $atype := $type/../type[@name= $attribute/@type]
let $aentity :=  $type/../entity[@name= $attribute/@type]
let $maxlength := ($attribute/@maxlength, $type/../type[@name=$attribute/@type]/@maxlength)[1]
let $item := 
  if (empty($attribute/@per-editor))
  then $element/*[name(.) = $attribute/@name]
  else $element/*[name(.) = $attribute/@name][@editor=$query/user]
return
  <tr>
    <th><span>
        {if (exists($attribute/comment)) then attribute title {$attribute/comment} else ()}
        {($attribute/@label,$attribute/@name)[1]/string()}
        </span> 
    </th>
    <td>{$item/@editor/string()}</td>
    <td>
      {if (exists ($aentity))
       then mapp:entity-selection($attribute/@type,$attribute,$item) 
       else if (exists($atype/enum))
       then mapp:type-selection($atype,$attribute,$item)
       else if (exists($attribute/@primarykey))
       then $item/string()
       else if (contains($maxlength,"x"))
       then let $dim := tokenize($maxlength,"x")
       return 
         <textarea name="{$attribute/@name}" rows="{$dim[1]}" cols="{$dim[2]}">
           {$item/string()}
         </textarea>
      else 
         <input name="{$attribute/@name}" value ="{$item}" size="{$maxlength}"/>
         }
    </td>
  </tr>   
 }  
     </table>
</form>
};

declare function mapp:edit-entity($query) {
 let $entity := mapp:entity($query/id)
 let $model := mapp:model($entity)
 return
    mapp:make-form($query,$model,$entity)
};

declare function mapp:default-entity($query) {
 let $type := $query/type
 let $model := $mapp:model/entity[@name=$type]
 let $last := $mapp:data//*[name(.)=$type][last()]
 let $n := xs:integer(substring-after($last/id,"-"))
 let $next := $n + 1
 let $newid := concat(substring-before($last/id,"-"),"-",$next)
 let $entity :=
   element {$type} {
      attribute editor {$query/user},
      element id { $newid},
      for $attribute in $model/attribute[@default]
      return 
         element {$attribute/@name} {$attribute/@default}
   }
 let $update := update insert $entity into $last/..
 return $newid
};

declare function mapp:create-entity($query) {
 let $newid := mapp:default-entity($query)
 return
    request:redirect-to(xs:anyURI(concat(request:get-url(),"?mode=edit&amp;id=",$newid)))
};

declare function mapp:update-entity($query,$model,$entity) {
for $attribute in $model/attribute
let $value := normalize-space(request:get-parameter($attribute/@name,()))
let $oldItem := 
     if (exists($attribute/@per-editor))
     then $entity/*[name(.)=$attribute/@name][@editor= $query/user]
     else $entity/*[name(.)=$attribute/@name]
let $newItem := element {$attribute/@name} {attribute editor {$query/user}, $value}
return 
   if ($value ne "" and (empty($oldItem) or $value ne $oldItem))
   then 
      if (exists($oldItem))
      then update replace $oldItem with $newItem
      else update insert $newItem into $entity
   else if (exists($oldItem) and $value = "")
      then update delete $oldItem 
   else ()
};

declare function mapp:update-entity($query) {
  let $entity := mapp:entity($query/id)
  let $model := mapp:model($entity)
  let $update := mapp:update-entity($query,$model,$entity)
  return 
    request:redirect-to(xs:anyURI(concat(request:get-url(),"?mode=view&amp;id=",$query/id)))
};

declare function mapp:check-delete($query) {
  let $entity := mapp:entity($query/id)
  return 
   <div>
     <h2>Delete?</h2>
     <p> About to delete {name($entity)} : {$entity/id/string()} : {mapp:label($entity)} <a href="?mode=delete&amp;id={$entity/id}">Delete</a>  <a href="?mode=view&amp;id={$entity/id}">View</a> </p>
   </div>
};

declare function mapp:delete-entity($query) {
  let $entity := mapp:entity($query/id)
  let $previous := mapp:previous($entity)
  let $update := update delete $entity
  return 
    request:redirect-to(xs:anyURI(concat(request:get-url(),"?mode=view&amp;id=",$previous)))
};

declare function mapp:search($query,$model,$data) {
let $type := $query/type
let $q := $query/q
return
<div>
 <form action="?">
  <input type="hidden" name="mode" value="page"/>
  Go to page <input type="text" name="id" />
  <input type="submit" value=" View "/>
 </form>

 <form action="?">
  <input type="hidden" name="mode" value="search"/>
  Search for <input type="text" name="q" value="{$query/q}"/>
  in <select name="type">
  {for $type in $mapp:model/entity/@name
   return 
    if ($type = $query/type)
    then <option selected="true">{$type/string()}</option>
    else <option>{$type/string()}</option>
  }
  </select>
  <input type="submit" value="search"/>
 </form>
 {if (exists($query/q) and $query/q ne "")
  then 
 <ul>
 {for $entity in $mapp:data//*[name(.)=$type][matches(.,$query/q,"i")]
  let $label := mapp:label($entity)
  order by $label
  return 
   <li><a href="?mode=view&amp;id={$entity/id}">{$label}</a> 
   {if ($entity/page) then <span>Page <a href="?mode=page&amp;id={$entity/page}">{$entity/page/string()} </a> </span> else () }
   </li>
 } 
</ul>
  else ()
  }
</div>
};

declare function mapp:list($query,$model,$data) as element(div) {
<div>
  <h2>List of {$query/type}s</h2>
  <ul>
    {let $type := $query/type
     for $entity in $data//*[name(.) = $type]
     let $label := mapp:search-label($model, $entity)
     order by $label
     return 
       <li><a href="?mode=view&amp;id={$entity/id}">{if ($label ne " : ") then $label else $entity/id/string()}</a>
        {if (exists($entity/image)) then " (image) " else ()}
       </li>
    }
  </ul>
</div>
};

declare function mapp:menu ($query,$model,$data) {
let $mode := $query/mode
return
<div>
 <span id="home"><a href="?mode=home">Home</a></span> 
 <span id="nav">
  {
   if ($mode="edit")
   then 
      let $entity := mapp:entity($data,$query/id) 
      return
      (   <span><a href="?mode=help">Help</a></span> ,
          <span><a href="?mode=view&amp;id={$query/id}"> View </a></span>,
          <span><a href="?mode=create&amp;Type={name($entity)}"> New </a></span>,
          <span><a href="?mode=check-delete&amp;id={$entity/id}"> Delete </a></span>
      )
   else if ($mode="view")
   then 
      let $entity := mapp:entity($data, $query/id) 
      let $previous := mapp:previous($entity)
      let $next := mapp:next($entity)
      return
      (   <span><a href="?mode=help">Help</a></span> ,
          <span><a href="?mode=list&amp;Type={name($entity)}">All {concat(name($entity),"s ")}</a></span>,
          if (exists($entity/page)) then <span><a href="?mode=page&amp;id={$entity/page}"> Page </a></span> else () ,
          if ($previous) then <span><a href="?mode=view&amp;id={$previous}"> Previous </a></span> else " Previous ",
          if ($next) then <span><a href="?mode=view&amp;id={$next}"> Next </a></span> else " Next ",
          if (exists($query/user)) then <span><a href="?mode=edit&amp;id={$query/id}"> Edit </a></span> else () 
      )
   else if ($mode="home")
   then  
      (  <span><a href="?mode=help">Help</a></span> ,
         for $type in $model/entity/@name
          return 
          <span><a href="?mode=list&amp;Type={$type}">{$type/string()}s</a></span>
         ,
         <span><a href="?mode=search"> Search </a></span> ,
         if (empty($query/user)) then <span><a href="?mode=login-form">Login</a></span> else () ,
         if (exists($query/user)) then  <span><a href="?mode=users">Users</a></span>  else () ,
         if (exists($query/user)) then  <span><a href="?mode=logout">Logout</a></span> else () 
      )
     else ()
     }
  </span>
</div>
};


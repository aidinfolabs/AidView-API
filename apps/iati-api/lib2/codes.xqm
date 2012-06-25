(:
  this module deals with accessing, loading and and caching codelists
  
  todo: 
  
  I should be able to link to the iati codelists  eg. FileFormat is http://iatistandard.org/codelists/file_format 
   - I could edit the names into the index or construct this name with some string manipulation 
   
:)

module namespace iati-c = "http://kitwallace.me/iati-c";
import module namespace iati-b = "http://kitwallace.me/iati-b" at "iati-b.xqm";

declare namespace h = "http://www.w3.org/1999/xhtml";
declare namespace iati-ad = "http://tools.aidinfolabs.org/api/AugmentedData";

declare variable $iati-c:codes := concat($iati-b:base,"codes/");
declare variable $iati-c:code-index := doc(concat($iati-b:base,"codes/codeindex.xml"))/codelist;
declare variable $iati-c:iati-base := "http://www.iatistandard.org/api/codelists/";

declare function iati-c:code-metadata($code as xs:string)  as element(codelist)? {
  $iati-c:code-index/codelist[id=$code]
};

declare function iati-c:codelist($code as xs:string)  as element(codelist)? {
  doc(concat($iati-c:codes,$code,".xml"))/codelist
};

declare function iati-c:codelist($code as xs:string, $corpus as xs:string ) as element(codelist)? {
  doc(concat($iati-b:data,$corpus,"/codes/",$code,".xml"))/codelist
};

declare function iati-c:code-value($code as xs:string, $id as xs:string) {
  iati-c:codelist($code)/*[code=$id]
};

declare function iati-c:code-value($code as xs:string, $id as xs:string ,$corpus as xs:string ) {
  iati-c:codelist($code,$corpus)/*[code=$id]
};

declare function iati-c:code-index-as-html ()  as element(div){
  <div>
   <table border="1" class="sortable">
   <tr><th>Codelist</th><th>Entries</th><th>Description</th></tr>
   {
   for $code in $iati-c:code-index/codelist
   let $id := $code/id
   let $count := count(iati-c:codelist($id)/*)
   return 
     <tr>
        <td>{if (exists(iati-c:codelist($id)))
             then <a href="?type=code&amp;id={$id}">{$code/name/string()}</a>
             else $code/name/string()
             }
        </td>
        <td>{$count}</td>
        <td>{$code/description/string()}</td>
     </tr> 
   }
   </table>
  </div>
};

declare function iati-c:code-index-as-html ($corpus as xs:string)  as element(div){
  <div>
   <table border="1" class="sortable">
   <tr><th>Codelist</th><th>Entries</th></tr>
   {
   for $filename in xmldb:get-child-resources(concat($iati-b:data,$corpus,"/codes"))
   let $id := substring-before($filename,".")
   let $codelist := iati-c:codelist($id,$corpus)
   let $count := count($codelist/*)
   return 
     <tr>
        <td> <a href="?corpus={$corpus}&amp;type=code&amp;id={$id}">{$id}</a>  </td>
        <td>{$count}</td>
     </tr> 
   }
   </table>
  </div>
};

declare function iati-c:code-list-as-html($id as xs:string) as element(div) {
  <div>
   <table border="1" class="sortable">
   <tr><th class="sorttable_alpha">Code</th><th>Name</th></tr>
   {
   let $list := iati-c:codelist($id)
   for $code in $list/*
   order by $code/name
   return 
     <tr><td>{$code/code/string()}</td><td>{$code/name/string()}</td>
     </tr>
   }
   </table>
  </div>
};

declare function iati-c:code-list-as-html($corpus as xs:string, $id as xs:string) as element(div) {
  <div>
   <table border="1" class="sortable">
   <tr><th class="sorttable_alpha">Code</th><th>Name</th></tr>
   {
   let $list := iati-c:codelist($id,$corpus)
   for $code in $list/*
   order by $code/name
   return 
     <tr><td>{$code/code/string()}</td><td>{$code/name/string()}</td>
     </tr>
   }
   </table>
  </div>
};

declare function iati-c:cache-codes($corpus as xs:string, $cache-def as element(cache-def) ) {

<div>
{
let $activities := collection(concat($iati-b:data,$corpus,"/activities"))/iati-activity[@iati-ad:live]
for $code in $cache-def/code
let $path := $code/@path
let $exp := concat("distinct-values($activities/",$path,"[. ne ''])")
let $codelist := 
  element codelist {
    for $value in util:eval($exp)
    let $name := 
       if (exists($code/@cache))
       then  iati-c:code-value($code/@code,$value,$corpus)/name
       else iati-c:code-value($code/@code,$value)/name
    let $name := if  (empty($name))
                 then 
                    let $laststep := tokenize($path,"/")[last()]
                    let $rest := substring-before($path,$laststep)
                    let $rest := if (ends-with($rest,"/")) then  substring($rest,1, string-length($rest) - 1 ) else $rest
                    let $exp := concat("$activities/",$rest,"[",$laststep,"=$value][. ne ''][1]")
                    let $ename := util:eval($exp)
                    return 
                      $ename
                 else $name
                 
    order by $name
    return 
      element {$code/@name} {
        element code {$value},
        element name {$name/string()}
        }
   }
let $store := xmldb:store(concat($iati-b:data,$corpus,"/codes"),concat($code/@name,".xml"),$codelist)
return
  <div>{$code/@name/string()} cached  {count($codelist/*)} entries <a href="/exist/rest/{$store}">View</a></div>
}
</div>
};

(:  
   These functions download all codes from the IATI standard site.  
   Some code lists are not in the XML API so are downloaded by scraping the HTML pages
   OrganisationIdentifiers are mined from 
   SectorCategory is a derived listing created by normalising the category data in the Sector table
   
:)   

declare function iati-c:store-list($id as xs:string, $codelist as element(codelist)? ) as element(div) {
   if (exists($codelist/*))
   then 
   let $store := xmldb:store($iati-c:codes,concat($id,".xml"),$codelist)
   let $storedlist := iati-c:codelist($id)
   let $update := update insert attribute dateModified {current-dateTime()} into $storedlist
   return    
     <div>{$id} stored : {count($storedlist/*)} entries</div>
   else 
     <div>{$id} empty</div>
};

declare function iati-c:get-code-list($id as xs:string) as element(codelist)? {
   let $XML := httpclient:get(xs:anyURI(concat($iati-c:iati-base,$id)),false(),())
   let $headers := $XML/httpclient:headers
   let $codelist := $XML/httpclient:body/codelist
   return $codelist
};


declare function iati-c:get-organisation-identifier-list()  as element(codelist){
<codelist>
{
let $base := "http://iatistandard.org/codelists/organisation_identifier_"
for $page in ("bilateral","multilateral","ingo")
let $url := concat($base,$page)
let $table := httpclient:get(xs:anyURI($url),false(),())//h:table[1]/h:tbody
for $tr in $table/h:tr
where normalize-space($tr/h:td[1]) ne ""
return
  element OrganisationalIdentifier {
      element code { $tr/h:td[1]/string()},
      element abbreviation {$tr/h:td[3]/string()},
      element name {$tr/h:td[4]/string() }
  }
}
</codelist>
};

declare function iati-c:cache-organisation-identifier-codes($corpus as xs:string) as element (div){ 
let $activities := collection(concat($iati-b:data,$corpus,"/activities"))/iati-activity
let $codelist := iati-c:get-organisation-identifier-list($activities)
let $store := xmldb:store(concat($iati-b:data,$corpus,"/codes"),"OrganisationIdentifier.xml",$codelist)
return
  <div>{$corpus} OrganisationIdentifer stored {count($codelist/*)} entries </div>
};

(: mine a set of activities for the organisations and their names 
   if more than 3 names, no name is used - maybe a set of names with a common prefix - could try to find that common stem 
   otherwise take the longest of the possible names - where the names are close in length, should compute the levenstein distance 
      to ensure they are nearly the same - may choose the mixed case version if one is uppercase only 
   following suggestion from Tim, default will be the decoded organisation type 
     
:)

declare function iati-c:get-organisation-identifier-list($activities as element(iati-activity)*) as element(codelist){
<codelist>
{
for $code in 
    distinct-values($activities/participating-org/@iati-ad:org)

let $selected-orgs := $activities/participating-org[@iati-ad:org eq $code]
let $types := distinct-values($selected-orgs/@type)
    
let $names :=  distinct-values($selected-orgs[empty(@xml:lang) or @xml:lang="en"][text() ne ""])
let $prefname := if (count($names) > 3)
                 then  if (exists($types))
                       then iati-c:code-value("OrganisationType",$types[1])/name
                       else "unknown"
                 else (let $lengths := for $n in $names return string-length($n)
                      let $max := max($lengths)
                      for $n in $names 
                         return if (string-length($n) = $max) then $n  else ()
                      )[1] 
where exists($prefname)
return 
   <OrganisationIdentifier>
         <code>{$code}</code>
         <name>{$prefname}</name> 
   </OrganisationIdentifier>
}
</codelist>
};

declare function iati-c:get-sector-category-list() as element(codelist) {
let $sectors := iati-c:codelist("Sector")/*
let $codelist := 
<codelist last-modified="{current-dateTime()}">
{
  for $categoryCode in distinct-values($sectors/category)
  let $category := $sectors[category=$categoryCode][1]
  return 
  element SectorCategory {
      element code { $categoryCode},
      element name {$category/category-name/string()},
      element description {$category/description/string()}
  }
}
</codelist>
return $codelist
};

declare function iati-c:download-codelists() as element(div) {
<div>
{

   for $codelist in $iati-c:code-index/codelist[empty(derived)]
   let $id := $codelist/id/string()
   let $list := iati-c:get-code-list($id)
   return
      iati-c:store-list($id,$list)
}


{let $list := iati-c:get-organisation-identifier-list()
 return iati-c:store-list("OrganisationIdentifier",$list)
}

{let $list := iati-c:get-sector-category-list()
 return iati-c:store-list("SectorCategory",$list)
}

</div> 
};
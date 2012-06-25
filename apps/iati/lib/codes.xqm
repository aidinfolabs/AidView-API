(:
  this module deals with accessing, loading and  viewing codelists
  This version supports codelist versions and language variants and codelist metadata
  
:)

module namespace codes = "http://tools.aidinfolabs.org/api/codes";
import module namespace config = "http://tools.aidinfolabs.org/api/config" at "../lib/config.xqm";
import module namespace wfn = "http://kitwallace.me/wfn" at "/db/lib/wfn.xqm";
import module namespace date = "http://kitwallace.me/date" at "/db/lib/date.xqm";

declare namespace h = "http://www.w3.org/1999/xhtml";
declare namespace iati-ad = "http://tools.aidinfolabs.org/api/AugmentedData";

declare variable $codes:codes := concat($config:base,"codes");  (: the full code set :)
declare variable $codes:current := concat($config:olap,"_codes");  (: the current code set :)
declare variable $codes:metadata := doc(concat($config:base,"codes/metadata.xml"))/metadata;
declare variable $codes:iatistandard := "http://iatistandard.org/api/codelists/";


(: the complete reference data :)
declare function codes:code-metadata($code as xs:string)  as element(codelist)? {
  $codes:metadata/codelist[name=$code]
};

declare function codes:codelist-all($name){
  collection($codes:codes)/codelist[@name = $name]
};

declare function codes:codelist($code as xs:string, $version as xs:string? , $lang as xs:string?)  as element(codelist)? {
  let $lists :=  collection($codes:codes)/codelist[@name=$code]
  let $lists := 
    if (exists($version))
    then $lists[@version = $version]
    else $lists[@version = max($lists/@version) ]
  return
    if (exists($lang))
    then $lists[@xml:lang = $lang]
    else $lists[@xml:lang = "en"]
};

(: these functions fetch from the current code lists :)

declare function codes:codelist($code as xs:string)  as element(codelist)? {
  collection($codes:current)/codelist[@name = $code]
};

declare function codes:code-value($code as xs:string, $id as xs:string) {
   collection($codes:current)/codelist[@name = $code]/*[code=$id]
};


declare function codes:codelist($code as xs:string, $corpus as xs:string ) { 
  collection(concat($config:olap,$corpus))/dimensions/*[name(.) = $code]
};

declare function codes:code-value($code as xs:string, $id as xs:string ,$corpus as xs:string ) { 
  collection(concat($config:olap,$corpus))/dimensions/*[name(.) = $code]/summary[code=$id]
};

declare function codes:code-index-as-html ()  as element(div){
  <div>
   <table border="1" class="sortable">
   <tr><th>Codelist</th><th>Entries</th><th>Description</th><th>Elements</th></tr>
   {
   for $code in $codes:metadata/codelist
   let $name := $code/name
   let $codelist := codes:codelist($name)
   let $count := count($codelist/*)
   return 
     <tr>
        <td>{if (exists(codes:codelist($name)))
             then <a href="/data/codelist/{$name}">{$code/label/string()}</a>
             else $code/label/string()
             }
        </td>
        <td>{$count}</td>
        <td>{$code/description/string()}</td>
        <td>{string-join(for $node in $codelist/*[1]/* return name($node),",")}</td>  
     </tr> 
   }
   </table>
  </div>
};

declare function codes:code-list-as-html($name as xs:string, $version as xs:string?, $lang as xs:string?) as element(div) {
let $list := codes:codelist($name,$version,$lang)
return
  <div>
   <h3>{concat($list/@name ," ",$list/@version," ",$list/@xml:lang)}</h3>
   {wfn:table-to-html($list)}
  </div>
};

declare function codes:code-value-as-html($codelist as xs:string, $id as xs:string) as element (div) {
  <div>
    <table border="1">
       {let $value := codes:code-value($codelist,$id)
        for $node in $value/*
        return 
          <tr><th>{name($node)}</th><td>{$node/string()}</td></tr>
        }
    </table>
  </div>
};

declare function codes:code-list-metadata-as-html($name as xs:string) as element(div) {
let $metadata := codes:code-metadata($name)
let $current := codes:codelist($name)
return
  <div>
    <table border="1">
       <tr><th>Name</th><td>{$metadata/name/string()}</td></tr>
       <tr><th>Label</th><td>{$metadata/label/string()}</td></tr>
       <tr><th>Description</th><td>{$metadata/description/string()}</td></tr>
       <tr><th>IATI Version</th><td>{$metadata/version/string()}</td></tr>
       {for $source in $metadata/source
       return
       <tr>
          <th>Source</th>
          <td>
          <table> 
             <tr><th>Authority</th><td>{$source/authority/string()}</td></tr>
             <tr><th>Version</th><td>{$source/version/string()}</td></tr>
             <tr><th>Version date</th><td>{$source/version-date/string()}</td></tr>
             {for $link in $source/link
              return
                 <tr><th>Link</th><td><a class="external" href="{$link/@href}">{$link/@title/string()}</a></td></tr>
             }
          </table>
         </td>
       </tr>
       }
       <tr><th>Discussion</th><td>{$metadata/discussion/string()}</td></tr> 
       <tr><th>Versions</th><td>
          <table>
           <tr><th>Version</th><th>Date</th><th>Lang</th><th>Current?</th></tr>
           {for $codelist  in codes:codelist-all($name)
            order by $codelist/@version, $codelist/@xml:lang
            return 
            <tr>
                <th>{$codelist/@version/string()}</th> 
                <td>{datetime:format-dateTime(xs:dateTime($codelist/@date-last-modified),"dd MMM yyyy")}</td>
                <td><a href="/data/codelist/{$name}/version/{$codelist/@version}/lang/{$codelist/@xml:lang}">{$codelist/@xml:lang/string()}</a></td>
                <td>{if ($codelist/@version = $current/@version)
                     then "Yes"
                     else ()
                    }
                </td>
                <td>{$codelist/comment/node()}</td>
            </tr>
           }
          </table>
         </td>
        </tr>
    </table>
  </div>
};

declare function codes:cache-codes() {
   for $code in $codes:metadata/codelist
   let $name := $code/name
   let $codelist := codes:codelist($name,(),"en")  (:cache the latest english version :)
   let $store := xmldb:store($codes:current,concat($name,".xml"),$codelist)
   return $name
};

(:  
   These functions download all codes from the IATI standard site.  
   Some code lists are not in the XML API so are downloaded by scraping the HTML pages
   OrganisationIdentifiers are mined from 3 HTML pages on the IATI standard site
   SectorCategory is a derived listing created by normalising the category data in the Sector table
   TransactionType is derived from  .. by adding two more codes  
:)   

declare function codes:store-list($id as xs:string, $codelist as element(codelist)? ) as element(div) {
   if (exists($codelist/*))
   then 
      let $version := "1.0"
      let $lang := "en"  
      let $scodelist := 
         element codelist {
              attribute name {$id},
              attribute date-last-modified { current-dateTime()},
              attribute version {$version},
              attribute xml:lang {$lang},
              $codelist/@*,
              $codelist/*
         }
              
      let $store := xmldb:store($codes:codes,concat($id,"-",$version,"-",$lang,".xml"),$scodelist)    
      return    
        <div>{$id} stored : {count($scodelist/*)} entries</div>
   else 
     <div>{$id} empty</div>
};

declare function codes:get-code-list($id as xs:string) as element(codelist)? {
   let $XML := httpclient:get(xs:anyURI(concat($codes:iatistandard,$id)),false(),())
   let $headers := $XML/httpclient:headers
   let $codelist := $XML/httpclient:body/codelist
   return $codelist
};


declare function codes:get-organisation-identifier-list()  as element(codelist){
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

declare function codes:cache-organisation-identifier-codes($corpus as xs:string) as element (div){ 
let $activities := collection(concat($config:data,$corpus,"/activities"))/iati-activity
let $codelist := codes:get-organisation-identifier-list($activities)
let $store := xmldb:store(concat($config:data,$corpus,"/codes"),"OrganisationIdentifier.xml",$codelist)
return
  <div>{$corpus} OrganisationIdentifer stored {count($codelist/*)} entries </div>
};

(: mine a set of activities for the organisations and their names 
   if more than 3 names, no name is used - maybe a set of names with a common prefix - could try to find that common stem 
   otherwise take the longest of the possible names - where the names are close in length, should compute the levenstein distance 
      to ensure they are nearly the same - may choose the mixed case version if one is uppercase only 
   following suggestion from Tim, default will be the decoded organisation type 
     
:)

declare function codes:get-organisation-identifier-list($activities as element(iati-activity)*) as element(codelist){
<codelist>
{
for $code in 
    distinct-values(($activities/participating-org/@iati-ad:org,$activities/reporting-org/@ref))

let $selected-orgs := $activities/participating-org[@iati-ad:org eq $code]
let $types := distinct-values($selected-orgs/@type)
    
let $names :=  distinct-values($selected-orgs[empty(@xml:lang) or @xml:lang="en"][text() ne ""])
let $prefname := if (count($names) > 3)
                 then  if (exists($types))
                       then codes:code-value("OrganisationType",$types[1])/name
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

declare function codes:get-sector-category-list() as element(codelist) {
let $sectors := codes:codelist("Sector")/*
let $codelist := 
<codelist>
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

declare function codes:get-value-type-list() as element(codelist) {
let $types := codes:codelist("TransactionType")/*
let $codelist := 
<codelist>
  { $types}

   <TransactionType>
        <code>PD</code>
        <name>Planned Disbursements</name>
        <description/>
    </TransactionType>
    <TransactionType>
        <code>TB</code>
        <name>Total Budget</name>
        <description/>
    </TransactionType>
</codelist>
return $codelist
};

declare function codes:download-codelists() as element(div) {
<div>
{

   for $codelist in $codes:metadata/codelist[empty(derived)]
   let $name := $codelist/name/string()
   let $list := codes:get-code-list($name)
   return
      codes:store-list($name,$list)
}


{let $list := codes:get-organisation-identifier-list()
 return codes:store-list("OrganisationIdentifier",$list)
}

{let $list := codes:get-sector-category-list()
 return codes:store-list("SectorCategory",$list)
}

{let $list := codes:get-value-type-list()
 return codes:store-list("ValueType",$list)
}

</div> 
};


declare function codes:rss() {
<rss version="2.0">
<channel>
<title>IATI code change list</title>
<description>Notifications of any changes to codelist versions</description>
<link>{$config:host}/data/codelist</link>
{for $codelist in collection($codes:codes)/codelist[@name]
 let $link := concat($config:host,"/data/codelist/",$codelist/@name,"/version/",$codelist/@version,"/lang/",$codelist/@xml:lang)
 let $description := 
     ($codelist/comment/node(),"created")[1]
 order by $codelist/@date-last-modified descending
 return 
    <item>
      <title>{concat($codelist/@name," version: ", $codelist/@version, " lang: ",$codelist/@xml:lang)}</title>
        <link>{$link}</link>
        <guid>{$link}</guid>
        <pubDate>{date:datetime-to-RFC-822($codelist/@date-last-modified)}</pubDate>
        <description>{$description}</description>
    </item>
}
</channel>
</rss>
};
module namespace iati-rss = "http://kitwallace.me/iati-rss";
import module namespace iati-b = "http://kitwallace.me/iati-b" at "../lib/iati-b.xqm";
import module namespace iati-c = "http://kitwallace.me/iati-c" at "../lib/iati-c.xqm";
import module namespace ui = "http://kitwallace.me/ui" at "/db/lib/ui.xqm";
import module namespace wfn = "http://kitwallace.me/wfn" at "/db/lib/wfn.xqm";

declare namespace iati-ad = "http://tools.aidinfolabs.org/api/AugmentedData";
declare namespace atom = "http://www.w3.org/2005/Atom";
declare variable $iati-rss:host := "http://subscribe.aidinfolabs.org";
declare variable $iati-rss:age := "90";

declare variable $iati-rss:wordchars := 
  element wordchars {
    element replace {attribute find {codepoints-to-string((226,128,147))}, attribute replace {"&#8211;"}, attribute name {"en dash"}}, 
    element replace {attribute find {codepoints-to-string((226,128,148))}, attribute replace {"&#8212;"}, attribute name {"em dash"}}, 
    element replace {attribute find {codepoints-to-string((226,128,152))}, attribute replace {"&#8216;"}, attribute name {"Single left quote"}}, 
    element replace {attribute find {codepoints-to-string((226,128,153))}, attribute replace {"&#8217;"}, attribute name {"Single right quote"}},
    element replace {attribute find {codepoints-to-string((226,128,154))}, attribute replace {"&#8218;"}, attribute name {"Single low-9 left quote"}}, 
    element replace {attribute find {codepoints-to-string((226,128,155))}, attribute replace {"&#8219;"}, attribute name {"Single high-reversed-9 quote"}},
    element replace {attribute find {codepoints-to-string((226,128,156))}, attribute replace {"&#8220;"}, attribute name {"Double right quote"}},
    element replace {attribute find {codepoints-to-string((226,128,157))}, attribute replace {"&#8221;"}, attribute name {"Double right quote"}},
    element replace {attribute find {codepoints-to-string((226,128,158))}, attribute replace {"&#8222;"}, attribute name {"Double low-9 quote"}},
    element replace {attribute find {codepoints-to-string((226,128,159))}, attribute replace {"&#8223;"}, attribute name {"Double high reversed-9 quote"}},
    element replace {attribute find {codepoints-to-string((226,128,172))}, attribute replace {"&#8230;"}, attribute name {"ellipsis"}}
  };
  
declare function iati-rss:clean-text($text) {
  wfn:replace($text,$iati-rss:wordchars/*)
};

declare function iati-rss:table-to-csv($table){
let $sep := ","
let $nl :="&#10;"
return
string-join(
  (string-join($table/tr[1]/*,$sep),
   for $row in $table/tr[position() > 1]
       return
         string-join((
          for $data in $row/*
          return
              concat('"',$data,'"')
           )
       , $sep)
   ),$nl )
};

declare function iati-rss:activity-to-rss($activity) {
<item>
    <guid isPermaLink="false">{$activity/iati-identifier/string()}-{$activity/@iati-ad:activity-modified/string()}</guid>
    <title>{$activity/title/string()}</title>
    <description>{iati-rss:clean-text($activity/description)}</description>
    <link>http://iatiexplorer.org/explorer/activity/?activity={$activity/iati-identifier/string()}</link>
 <!--   <link>http://data.aidinfolabs.org/?activity={$activity/iati-identifier}</link> -->
</item>
};

declare function iati-rss:query() {
let $query :=
element query { 
   ui:get-parameter("mode","rss"),
   ui:get-parameter("activity",()),
   ui:get-parameter("country",()),
   ui:get-parameter("sector",()),
   ui:get-parameter("corpus",'fullB'),
   ui:get-parameter("age", $iati-rss:age )
 }
return 
  element query {
     $query/*,
     element since {current-dateTime() - xs:dayTimeDuration(concat("P",$query/age,"D"))}
  }
};

declare function iati-rss:query-activities ($query as element(query) ) as element(activity)* {
   let $filter := 
       if ($query/country) 
       then 
          concat("[recipient-country/@iati-ad:country='",$query/country,"']")
       else if ($query/sector) 
       then 
          concat("[sector/@iati-ad:category='",$query/sector,"']")
       else ()
  let $exp := concat("collection('",$iati-b:data,$query/corpus,"/activities')/iati-activity[@iati-ad:live][@iati-ad:include]",$filter,"[@iati-ad:activity-modified > $query/since]")
  let $activities := util:eval($exp)
  return $activities
 };
 
declare function iati-rss:feed($query) {
let $selected-activities := iati-rss:query-activities($query)
return 
<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">
<channel>
<title>IATI activities in 
   {if ($query/country) 
    then iati-c:code-value("Country",$query/country)/name/string()
    else if ($query/sector) 
    then concat("Sector ", iati-c:code-value("SectorCategory",$query/sector)/name)
    else ()
   } : Changes since {string($query/since)} 
</title>
<description></description>
<link>{request:get-url()}?{request:get-query-string()}</link>
<atom:link  rel="self" type="application/rss+xml" href="{$iati-rss:host}?{request:get-query-string()}"/>
{for $activity in $selected-activities
 return 
    iati-rss:activity-to-rss($activity)
}
</channel>
</rss>
};

declare function iati-rss:csv-feeds() {
    <table>
      <tr><td>CATEGORY</td><td>RSS FEED</td></tr>
      {for $country in iati-c:codelist("Country")/*
       let $link := concat($iati-rss:host,"?country=",$country/code)
       return
          <tr>
             <td>{$country/name/string()}</td>
             <td><a href="{$link}">{$link}</a></td>
          </tr>
      }
      {for $sectorcategory in iati-c:codelist("SectorCategory")/*
       let $link := concat($iati-rss:host,"?sector=",$sectorcategory/code)
       return
          <tr>
             <td>{$sectorcategory/name/string()}</td>
             <td><a href="{$link}">{$link}</a></td>
         </tr>
      }
      
    </table>
};

declare function iati-rss:activity($query) {
   collection(concat($iati-b:data,$query/corpus,"/activities"))/iati-activity[@iati-ad:live][iati-identifier=$query/activity]
};
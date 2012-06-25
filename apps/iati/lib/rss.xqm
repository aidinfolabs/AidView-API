module namespace rss = "http://tools.aidinfolabs.org/api/rss";
import module namespace config = "http://tools.aidinfolabs.org/api/config" at "../lib/config.xqm";
import module namespace codes = "http://tools.aidinfolabs.org/api/codes" at "../lib/codes.xqm";
import module namespace olap = "http://tools.aidinfolabs.org/api/olap" at "../lib/olap.xqm";  
import module namespace wfn = "http://kitwallace.me/wfn" at "/db/lib/wfn.xqm";

declare namespace iati-ad = "http://tools.aidinfolabs.org/api/AugmentedData";
declare namespace atom = "http://www.w3.org/2005/Atom";

declare function rss:country-feed($context) {
let $since := current-dateTime() - xs:dayTimeDuration(concat("P",($context/age,$config:rss-age)[1],"D"))
let $activities := olap:select-facet-activities("Country",$context)
let $selected-activities := $activities
let $url := concat ($config:host,$context/_fullpath,".rss")
return 
<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">
<channel>
<title>IATI activities in {codes:code-value("Country",$context/Country)/name/string()} : Changes since {datetime:format-dateTime($since,"d MMM yyyy")} </title>
<link>{$url}</link>
<atom:link  rel="self" type="application/rss+xml" href="{$url}"/>
{for $activity in $selected-activities
 return 
    rss:activity-to-rss($activity,$context)
}
</channel>
</rss>
};

declare function rss:sectorCategory-feed($context) {
let $since := current-dateTime() - xs:dayTimeDuration(concat("P",($context/age,$config:rss-age)[1],"D"))
let $activities := olap:select-facet-activities("SectorCategory",$context)
let $selected-activities := $activities[@iati-ad:activity-modified > $since ]
let $url := concat ($config:host,$context/_fullpath,".rss")
return 
<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">
<channel>
<title>IATI activities in {codes:code-value("SectorCategory",$context/SectorCategory)/name/string()} : Changes since {datetime:format-dateTime($since,"d MMM yyyy")}</title>
<link>{$url}</link>
<atom:link  rel="self" type="application/rss+xml" href="{$url}"/>
{for $activity in $selected-activities
 return 
    rss:activity-to-rss($activity,$context)
}
</channel>
</rss> 
};


declare function rss:activity-to-rss($activity,$context) {
<item>
    <guid isPermaLink="false">{$activity/iati-identifier/string()}-{$activity/@iati-ad:activity-modified/string()}</guid>
    <title>{$activity/title/string()}</title>
    <description>{wfn:clean-text($activity/description)}</description>
    <link>{$config:host}/corpus{$context/corpus}/activity/{$activity/iati-identifier}</link>
</item>
};

declare function rss:feeds($context) {
    <feeds>
      {for $country in codes:codelist("Country")/Country
       let $link := concat($config:host,"/data/corpus/($context/corpus}/Country/*",$country/code,".rss")
       order by $country/code
       return
          <feed>
             <CATEGORY>{$country/name/string()}</CATEGORY>
             <URL>{$link}</URL>
          </feed>
      }
      {for $sectorCategory in codes:codelist("SectorCategory")/SectorCategory
       let $link := concat($config:host,"/data//corpus/($context/corpus}/SectorCategory/*",$sectorCategory/code,".rss")
       order by $sectorCategory/code
       return
          <feed>
             <CATEGORY>{$sectorCategory/name/string()}</CATEGORY>
             <URL>{$link}</URL>
         </feed>
      }   
    </feeds>
};

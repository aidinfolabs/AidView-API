(: 
<a class="arrowLink" href="/en/IATI/Activities?countryCode=ZIM">Zimbabwe</a>

:)
import module namespace iati-b = "http://kitwallace.me/iati-b" at "../lib/iati-b.xqm";
import module namespace iati-l = "http://kitwallace.me/iati-l" at "../lib/iati-l.xqm";

declare namespace h = "http://www.w3.org/1999/xhtml";
let $bar := if (request:get-parameter("key",()) ne "1418") then () else 
let $host := "gfweb-dev.cloudapp.net"
let $page := httpclient:get(xs:anyURI(concat("http://",$host,"/en/IATI/Index")),false(),())
let $links := $page//h:a[@class="arrowLink"]/@href/string()
let $corpus := "fullB"
let $query :=
<query>
  <corpus>{$corpus}</corpus>
  <pipeline>pipeline</pipeline>
</query>
let $activitySets := doc(concat($iati-b:data,$query/corpus,"/activitySets.xml"))/activitySets

return
<links>
 {for $link in $links[position() < 3]
  let $url := concat("http://",$host,$link)
  return 
   <link>{iati-l:download-url($url, $activitySets ,$query)}</link> 
 }
</links>
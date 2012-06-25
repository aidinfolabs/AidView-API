import module namespace config = "http://tools.aidinfolabs.org/api/config" at "../lib/config.xqm";
import module namespace olap = "http://tools.aidinfolabs.org/api/olap" at "../lib/olap.xqm";
import module namespace stats = "http://tools.aidinfolabs.org/api/stats" at "../lib/stats.xqm";

declare namespace iati-ad = "http://tools.aidinfolabs.org/api/AugmentedData";

let $run-start := util:system-time()
let $corpus := request:get-parameter("corpus","test2")
let $dimensions := doc(concat($config:system,"woquery.xml"))/parameters
let $activities := collection(concat($config:data,$corpus,"/activities"))/iati-activity[@iati-ad:live][@iati-ad:include]
let $olap-file := xmldb:store(
     concat($config:base,"olap"),
     concat($corpus,".xml"), 
     element dimensions { attribute dateTime {current-dateTime()}, attribute corpus {$corpus} }
     )
     
let $olap := doc($olap-file)/dimensions
let $result := 
element olap { 
   $olap/@*,  
   let $summary :=
       olap:group($activities,(),$corpus)
   let $update := update insert $summary into $olap
   return 
     element dimension {"summary"}
     ,
   for  $dimension in $dimensions/param[@group]
   let $summary :=
       olap:group($activities,$dimension,$corpus)
   let $update := update insert $summary into $olap
   return 
     element dimension {$dimension/@name/string()}
}

let $run-end := util:system-time()
let $run-milliseconds := (($run-end - $run-start) div xs:dayTimeDuration('PT1S'))  * 1000


return
  element result {
      attribute milliseconds {$run-milliseconds},
      $result
     }

import module namespace iati-b = "http://kitwallace.me/iati-b" at "../lib/iati-b.xqm";
import module namespace iati-olap = "http://kitwallace.me/iati-olap" at "../lib/iati-olap.xqm";
declare namespace iati-ad = "http://tools.aidinfolabs.org/api/AugmentedData";

let $run-start := util:system-time()
let $corpus := request:get-parameter("corpus","test2")
let $dimensions := doc(concat($iati-b:system,"woquery.xml"))/parameters
let $activities := collection(concat($iati-b:data,$corpus,"/activities"))/iati-activity[@iati-ad:live]
let $olap-file := xmldb:store(
     concat($iati-b:base,"olap"),
     concat($corpus,"-stats.xml"), 
     element dimensions { attribute dateTime {current-dateTime()}, attribute corpus {$corpus} }
     )
let $olap := doc($olap-file)/dimensions

let $result := 
element olap { 
   $olap/@*,  
   for $dimension in $dimensions/param[@from-year]
   let $years := $dimension/(@from-year to @to-year)
   let $stats :=
       iati-olap:stats($activities,$dimension, $years, $corpus)
   let $update := update insert $stats into $olap
   return 
     $dimension
}

let $run-end := util:system-time()
let $run-milliseconds := (($run-end - $run-start) div xs:dayTimeDuration('PT1S'))  * 1000


return
  element result {
      attribute milliseconds {$run-milliseconds},
      $result
     }

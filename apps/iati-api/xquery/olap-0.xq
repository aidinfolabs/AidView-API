import module namespace iati-b = "http://kitwallace.me/iati-b" at "../lib/iati-b-2.xqm";
import module namespace iati-olap = "http://kitwallace.me/iati-olap" at "../lib/iati-olap.xqm";

let $corpus := request:get-parameter("corpus","test2")
let $dimensions := doc(concat($iati-b:system,"woquery.xml"))/parameters
let $config := doc(concat($iati-b:system,"olap.xml"))/axes
let $activities := collection(concat($iati-b:data,$corpus,"/activities"))/iati-activity
let $olap-file := xmldb:store(concat($iati-b:base,"olap"), concat($corpus,".xml"), 
    element dimensions { attribute dateTime {current-dateTime()}, attribute corpus {$corpus}
    }
    )
let $olap := doc($olap-file)/dimensions
return
element olap { 
   $olap/@*,  
   for $axis in $config/axis
   let $dimensions := for $axis in $axis/dimension order by $axis return $dimensions/param[@name=$axis]
   let $summary :=
       iati-olap:tree-group($activities,$dimensions,$corpus,())
   let $update := update insert $summary into $olap
   return 
     element dimension {string-join($dimensions/@name,"-")}
} 

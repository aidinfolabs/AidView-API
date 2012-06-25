import module namespace iati-b = "http://kitwallace.me/iati-b" at "../lib/iati-b.xqm";

declare namespace iati-ad = "http://tools.aidinfolabs.org/api/AugmentedData";

let $run-start := util:system-time()

let $activities := collection(concat($iati-b:data,"fullB/activities"))/iati-activity[@iati-ad:live][@iati-ad:include][iati-identifier='GB-1-201397-101']

let $run-end := util:system-time()
let $run-milliseconds := (($run-end - $run-start) div xs:dayTimeDuration('PT1S'))  * 1000 
return 
 <result ms="{$run-milliseconds}"  count="{count($activities)}">

 </result>
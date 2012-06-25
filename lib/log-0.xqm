module namespace log ="http://kitwallace.me/log";
declare variable $log:ipcache := doc("/db/apps/logger/geo/ipcache.xml")/addresses;

declare function log:log($id) {
   doc(concat("/db/apps/logger/data/",$id,"/log.xml"))/log
};

declare function log:ignore($id) {
   doc(concat("/db/apps/logger/data/",$id,"/ignore.xml"))/hosts
};

declare function log:geocode-ip($ip as xs:string)  as element(address)? {
let $address := $log:ipcache/address[@ip = $ip][1]
return 
    if ($address)
    then $address
    else 
    if (empty ($ip) or $ip eq "")
    then ()
    else
         let $response := doc(concat("http://freegeoip.appspot.com/xml/",$ip))/Response
         return 
           if (exists($address/Latitude))
           then 
              let $address := 
               element address {
                     attribute ip {$ip},
                     attribute latitude {$response/Latitude},
                     attribute longitude {$response/Longitude},
                     attribute country {$response/CountryName},
                     attribute city {$response/City}
               }
             let $update := update insert $address into  $log:ipcache
             return $address
           else ()
};
 
declare function log:log-request($is  as xs:string) {
  log:log-request($id,(),())
};

declare function log:log-request($id  as xs:string, $script as xs:string?) {
  log:log-request($id,$script,())
};

declare function log:log-request( $id as xs:string, $script as xs:string?, $appdata as xs:string? ) {
let $log := log:log($id)
let $logrecord :=
 element logrecord {
     attribute dateTime {util:system-dateTime()},
     attribute host {request:get-hostname()},
     if (exists($script)) then attribute script {$script} else (),
     attribute queryString {request:get-query-string()},
     $appdata
  }
return 
     update insert $logrecord into $log
};

declare function log:list-log($records,$start as xs:integer,$pagesize as xs:integer) {
let $records := subsequence(subsequence($records,$start),1,$pagesize)
return
if (empty($records)) then () else
<table class="sortable" border="1">
 <tr><th>dateTime</th><th>host</th><th>script</th><th>queryString</th><td>data</td></tr>
 {for $record in $records
  return
    <tr>
    <td>{$record/@dateTime/string()}</td>
    <td>{$record/@host/string()}</td>
    <td>{$record/@script/string()}</td>
    <td>{$record/@queryString/string()}</td>
    <td>{$record/string()}</td>
    </tr>
  }
</table>

};
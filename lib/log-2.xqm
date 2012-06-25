module namespace log ="http://kitwallace.me/log";
declare variable $log:base := "/db/apps/logger/";
declare variable $log:data := concat($log:base,"data/");
declare variable $log:ipcache := doc(concat($log:base,"geo/ipcache.xml"))/addresses;

declare function log:log($id) {
   doc(concat($log:data,$id,"/log.xml"))/log
};

declare function log:ignore($id) {
   doc(concat($log:data,$id,"/ignore.xml"))/hosts
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
         let $response := doc(concat("http://api.ipinfodb.com/v2/ip_query.php?key=49581a37083029045c9b631e561a16e4ab6950ad39bb5d68700fa89894e259dd&amp;ip=",$ip))/Response
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

declare function log:list-log($records) {
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

declare function log:archive($id as xs:string) {
   let $log := doc(concat($log:data,$id,"/log.xml"))
   let $archive-name := concat("log-",replace(current-dateTime(),":","-"),".xml")
   let $copy := xmldb:copy(concat($log:data,$id),concat($log:data,$id,"/archive"), "log.xml")
   let $rename := xmldb:rename(concat($log:data,$id,"/archive"), "log.xml", $archive-name)
   let $store := xmldb:store(concat($log:data,$id),"log.xml",<log/>)
   return $archive-name
};

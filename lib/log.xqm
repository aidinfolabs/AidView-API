module namespace log ="http://kitwallace.me/log";

declare variable $log:db := "/db/apps/sys/";
declare variable $log:ipcache := doc(concat($log:db,"data/ipcache.xml"))/addresses;

declare function log:logs($id) {
   concat("/db/apps/",$id,"/logs")
};

declare function log:log($id) {
   doc(concat("/db/apps/",$id,"/logs/log.xml"))/log
};
 
declare function log:ignore($id) {
   doc(concat("/db/apps/",$id,"/logs/ignore.xml"))/hosts
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
         let $url := concat("http://api.ipinfodb.com/v2/ip_query.php?key=49581a37083029045c9b631e561a16e4ab6950ad39bb5d68700fa89894e259dd&amp;ip=",$ip)
         let $response := util:catch("*",doc($url)/Response,())
         return 
           if (exists($response/Latitude))
           then 
              let $address := 
               element address {
                     attribute ip {$ip},
                     attribute latitude {$response/Latitude},
                     attribute longitude {$response/Longitude},
                     attribute country {$response/CountryName},
                     attribute city {$response/City}
               }
             let $update := update insert $address into $log:ipcache

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
     attribute dateTime {current-dateTime()},
     attribute host {tokenize(request:get-header("X-Forwarded-For"),", ")[1]},
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
   let $dir := log:logs($id)
   let $archive-name := concat("log-",replace(current-dateTime(),":","-"),".xml")
   let $rename := xmldb:rename($dir,"log.xml", $archive-name)
   let $store := xmldb:store($dir,"log.xml",<log/>)
   return $archive-name
};

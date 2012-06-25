module namespace sms= "http://kitwallace.me/sms";
declare variable $sms:uri := "http://api.clickatell.com/http";
declare variable $sms:apps := collection("/db/apps/sms");

declare function sms:send($to, $text, $mtype, $api_id) {
(: get authorisation :)
 let $login:= xmldb:login("/db/apps","admin","perdika")
 let $account := $sms:apps//sms:Account[@api_id=$api_id]
 let $authurl := <url>{$sms:uri}/auth?user={string($account/@username)}&amp;password={string($account/@password)}&amp;api_id={$api_id}</url>
 let $authresult := httpclient:get (xs:anyURI($authurl),false(),())//httpclient:body/HTML/body/text()
 let $sessionid := substring-after($authresult,"OK: ")
 (: send message :)
 let $sendurl := <url>{$sms:uri}/sendmsg?session_id={$sessionid}&amp;to={$to}&amp;text={encode-for-uri($text)}&amp;msg_type={$mtype}</url>
 let $sendresult :=  httpclient:get (xs:anyURI($sendurl),false(),())//httpclient:body/HTML/body/text()
 return $sendresult
};

declare function sms:route-sms($from,$text,$to,$timestamp,$api_id as xs:string)  as element(response)? {
(: called by Clickatell :)
<response>
{ let $login:= xmldb:login("/db/apps","admin","perdika")
let $application := $sms:apps/sms:Application[sms:Account[@api_id=$api_id]]
return
 if (empty($application) or empty($from)) then ()
else
let $prefix := if (contains($text," ")) then substring-before ($text," ") else $text
let $message := encode-for-uri(substring-after($text,concat($prefix," ")))
let $route := $application/sms:Route[@prefix = lower-case($prefix)]
return
   if (exists($route))
   then 
        let $uri := xs:anyURI(<url>{string($route/@uri)}from={$from}&amp;text={$message}&amp;prefix={$prefix}</url>)
        let $response := httpclient:get($uri,false(),())//httpclient:body/response 
        return
             if (exists($response/reply))
             then 
              for $reply in $response/reply
              return 
                     <sent>                  
                       {sms:send($from,substring($reply,1,140),string($route/@mtype),$api_id)}
                    </sent>            
             else                             
                    <fail>No response{$response}</fail>               
   else      
           <fail>No route found for {$prefix} </fail>
 }
 </response>
};

declare function sms:route-sms($from,$text) {
  sms:route-sms($from,$text,(),current-dateTime(),"446364")
};
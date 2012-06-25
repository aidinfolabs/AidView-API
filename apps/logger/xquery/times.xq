declare option exist:serialize "method=xhtml media-type=text/html";

declare function local:log-intervals($records) {
  let $start := xs:dateTime($records[1]/@dateTime)
  return  local:log-intervals(subsequence($records,2),$start)
};
declare function local:log-intervals($records, $previous as xs:dateTime) {
  if(exists($records))
  then let $first := $records[1]
       let $time := xs:dateTime($first/@dateTime)
       let $ms := round((($time - $previous) div xs:dayTimeDuration('PT1S'))  * 1000) 
       let $irecord := element record {attribute ms {$ms}, attribute dateTime {$time}, $first/string()}
       return ($irecord, local:log-intervals(subsequence($records,2),$time))
  else ()
};

let $logname:= request:get-parameter("log",())
let $n := xs:integer(request:get-parameter("n",20))
let $log := doc(concat("/db/apps/logger/data/",$logname,"/log.xml"))/log
return
  <table>
   {for $job in subsequence(reverse(distinct-values($log/logrecord/@script)),1,$n)
    return
      <tr><td>{$job}</td>
      <td><table>
      {
    let $records := $log/logrecord[@script=$job]
    for $record at $i in  local:log-intervals($records)
    return
      <tr>
      <td>{if ($i = 1) then $record/@dateTime/string() else () }
      </td><td>{$record/string()}</td>
      <td>{$record/@ms/string()}</td>
      </tr>
     }
     </table>
     </td>
     </tr>
    }
  </table>

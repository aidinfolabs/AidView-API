import module namespace log = "http://kitwallace.me/log" at "/db/lib/log.xqm";
import module namespace wfn = "http://kitwallace.me/wfn" at "/db/lib/wfn.xqm";
import module namespace ui = "http://kitwallace.me/ui" at "/db/lib/ui.xqm";


declare function local:entity-to-url-params ($entity,$omit) {
 string-join(
    for $field in $entity/*[.ne ""]
    where not(name($field) = $omit)
    return
       concat(name($field),"=",$field)
    ,"&amp;"
   )
};

let $query-model := 
<entity name="query">
  <attribute name="mode" />
  <attribute name="format" default="html"/>
  <attribute name="log" />
  <attribute name="script" />
  <attribute name="host" />
  <attribute name="filter"/>
  <attribute name="id"/>
  <attribute name="start" default="1"/>
  <attribute name="pagesize" default="20"/>
</entity>

let $query := ui:get-entity($query-model)
let $records := log:log($query/log)/logrecord
let $content := 
    if (exists($query/log) and $query/mode="archive")
    then  
        let $login := xmldb:login("/db/apps/logger","admin","perdika")
        let $archive := log:archive($query/log)
        return
         <div>
         <div class="nav">
           <a href="?log={$query/log}">{$query/log/string()}</a> >
           <a href="?log={$query/log}&amp;mode=view">View all</a>
         </div>
         <div class="body">
         
          Log archived to {$archive}
         </div>
      </div>
    else 
    if (exists($query/log) and $query/mode = "view")
    then 
      let $records := if (exists($query/script)) then $records[@script=$query/script] else $records
      let $records := if (exists($query/host)) then $records[@host=$query/host] else $records
      let $records := if (exists($query/filter)) then $records[not (@host = log:ignore($query/log)/host)] else $records
      let $max := count($records)
      let $records := subsequence(subsequence($records,xs:integer($query/start)),1,xs:integer($query/pagesize))
      return 
       <div>
         <div class="nav">
           <a href="?log={$query/log}">{$query/log/string()}</a> >
           <a href="?log={$query/log}&amp;mode=view">View all</a> |
           <a href="?log={$query/log}&amp;mode=view&amp;filter=filter">Ignore listed hosts</a> > 
           <span>{string-join(($query/script,$query/host,$query/filter),",")}</span>
         </div>
      <div class="body">
        {wfn:paging(concat("?",local:entity-to-url-params($query,("start","pagesize"))),$query/start,$query/pagesize,$max)}
        {log:list-log($records)}
      </div>
    </div>
    else if (exists($query/log))
    then
      <div>
       <div class="nav">
           <a href="?log={$query/log}">{$query/log/string()}</a> >
           <a href="?log={$query/log}&amp;mode=view">View all</a> |   
           <a href="?log={$query/log}&amp;mode=archive">Archive</a>    
       </div>
       <div class="body">
       <h2>Scripts</h2>
       <ul>
        {for $script in distinct-values($records/@script)
         return 
           <li><a href="?log={$query/log}&amp;script={$script}&amp;mode=view">{$script}</a></li>
        }
       </ul>
       <h2>Hosts</h2>
       <ul>
        {for $host in distinct-values($records/@host)
         return 
           <li><a href="?log={$query/log}&amp;host={$host}&amp;mode=view">{$host}</a></li>
        }
       </ul>
       </div>
     </div>
     else 
         <div>Log browser</div>
 return
    if ($query/format = "html")
    then let $s := util:declare-option("exist:serialize","method=xhtml media-type=text/html")
         return
           <html>
             <head>
                <title>Activity Log {$query/log/string}</title>
                <link rel="stylesheet" type="text/css" href="../assets/screen.css"></link>
                <script src="../../jscript/sorttable.js" type="text/javascript" charset="utf-8"></script>
             </head>
             <body>
               {$content}
             </body>
           </html>
     else ()
                

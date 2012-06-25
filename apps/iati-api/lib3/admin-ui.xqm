module namespace admin-ui = "http://kitwallace.me/admin-ui";
import module namespace config = "http://kitwallace.me/config" at "config.xqm";
import module namespace load = "http://kitwallace.me/load" at "load.xqm";
import module namespace validate = "http://kitwallace.me/validate" at "validate.xqm";
import module namespace codes = "http://kitwallace.me/codes" at "codes.xqm";
import module namespace wfn =  "http://kitwallace.me/wfn" at "/db/lib/wfn.xqm";
import module namespace login = "http://kitwallace.me/login" at "/db/lib/login.xqm";
import module namespace zipapp = "http://kitwallace.me/zipapp" at "/db/lib/zipapp.xqm";

declare namespace iati-ad = "http://tools.aidinfolabs.org/api/AugmentedData";
declare variable $admin-ui:members := doc(concat($config:system,"members.xml"))/members;

declare function admin-ui:admin-content($query,$script) {
let $activity-collection := concat($config:data,$query/corpus,"/activities")

return 
if (empty($query/membername))
then  
  if ($query/mode="login-form" )
  then login:login-form()
  else if ($query/mode="login")
  then login:login($admin-ui:members)
  else <div><a href="?mode=login">Login</a></div>

else
  if (empty($query/corpus) and $query/mode="create") 
  then 
        <div>
               <div class="nav">
                 
                <span>Create Corpus</span> >
               </div>

            <div class="body">
             <form action="?">
               <input type="hidden" name="mode" value="create"/>
               Corpus <input type="text" name="corpus" size="20"/>
               <input type="submit" value="Create Corpus"/>
             </form>  
            </div>
          </div>
  else if (exists($query/corpus) and $query/mode="create")
  then 
       let $collection := xmldb:create-collection($config:data,$query/corpus)
       let $codes :=  xmldb:create-collection(concat($config:data,$query/corpus),"codes")
       let $activities :=  xmldb:create-collection(concat($config:data,$query/corpus),"activities")
       let $log :=  xmldb:store(concat($config:data,$query/corpus),"log.xml",element log{})
       let $createactivitySets := xmldb:store(concat($config:data,$query/corpus),"activitySets.xml",element activitySets{}) 
       let $indexupdate := update insert $query/corpus into doc(concat($config:system,"corpusindex.xml"))/corpusindex
       let $index := concat("/db/system/config",$config:data)
       let $indexcollection := xmldb:create-collection($index,$query/corpus)
       let $corpus-index := concat($index,$query/corpus)
       let $indexcodes :=  xmldb:create-collection($corpus-index,"codes")
       let $indexactivities :=  xmldb:create-collection($corpus-index,"activities")
       let $activitySetconfig := xmldb:store($corpus-index,"collection.xconf",doc(concat($config:system,"activitySet.collection.xconf")))
       let $codeconfig := xmldb:store(concat($corpus-index,"/codes"),"collection.xconf",doc(concat($config:system,"code.collection.xconf")))
       let $activityconfig := xmldb:store(concat($corpus-index,"/activities"),"collection.xconf",doc(concat($config:system,"activity.collection.xconf")))
       return 
         response:redirect-to(xs:anyURI(concat($script,"?corpus=",$query/corpus)))
         
  else  if (exists($query/corpus) and $query/mode="download"  and $query/type="registry")
  then 
     let $activitySets := doc(concat($config:data,$query/corpus,"/activitySets.xml"))/activitySets
     let $scan-ckan := load:ckan-activitySets($activitySets)
     return  response:redirect-to(xs:anyURI(concat($script,"?corpus=",$query/corpus,"&amp;type=activitySet")) )   
  else if (exists($query/corpus) and $query/mode="download" and $query/type="web" and empty($query/src))
       then 
           <div>
               <div class="nav">
                 
                 <a href="?corpus={$query/corpus}">{$query/corpus}</a> >
                 <span>Download Form</span> >
               </div>

            <div class="body">
             <form action="?">
               <input type="hidden" name="corpus" value="{$query/corpus}"/>
               <input type="hidden" name="type" value="web"/>
               <input type="hidden" name="mode" value="download"/>
               Host <input type="text" name="host" size="30"/><br/>
               URL <input type="text" name="src" size="100"/>
               <input type="submit" value="Download"/>
             </form>  
            </div>
          </div>
     
  else if (exists($query/corpus) and $query/mode="download" and $query/type="web" and exists($query/src))
       then 
          let $activitySets := doc(concat($config:data,$query/corpus,"/activitySets.xml"))/activitySets
          
          let $download := load:download-url($query/src, $activitySets, $query)
          return 
            response:redirect-to(xs:anyURI(concat($script,"?corpus=",$query/corpus,"&amp;type=activitySet&amp;src=",encode-for-uri($query/src))))
  else
(: --------- type=host  --------------------- :)
if (exists($query/corpus) and $query/type = "host" and empty($query/host))
then
     let $activitySets := doc(concat($config:data,$query/corpus,"/activitySets.xml"))/activitySets/activitySet
     return  <div>
               <div class="nav">
                 
                 <a href="?corpus={$query/corpus}">{$query/corpus}</a> >
                 <span>Hosts</span> >
               </div>

               <div class="body">
                <table class="sortable">
                 <tr><th>Host</th><th>#activity sets</th><th>#loaded </th><th>#not loaded</th><th>#stale</th></tr>
                  {for $host in distinct-values($activitySets/host)
                   let $host-activitySets := $activitySets[host = $host]
                   return <tr>
                          <td><a href="?corpus={$query/corpus}&amp;type=host&amp;host={$host}">{$host}</a></td>
                          <td>{count($host-activitySets)}</td>
                          <td>{count($host-activitySets[download-modified])}</td>
                          <td>{count($host-activitySets[empty(download-modified)])}</td>
                          <td>{count($host-activitySets[download-modified][ cache-modified > download-modified])}</td>
                        </tr>
                  }
                </table>
               </div>
          </div>

 else 
 if (exists($query/corpus) and $query/type="host"  and exists($query/host))
 then 
     let $host := doc(concat($config:data,"hosts.xml"))/hosts/host[@name=$query/host]  (: general host file - for comments :)
     let $activitySets := doc(concat($config:data,$query/corpus,"/activitySets.xml"))/activitySets/activitySet[host=$query/host]
     let $activities := collection($activity-collection)/iati-activity[@iati-ad:activitySet = $activitySets/download_url][@iati-ad:live]
     return  <div>
               <div class="nav">
                 
                 <a href="?corpus={$query/corpus}">{$query/corpus}</a> >
                 <a href="?corpus={$query/corpus}&amp;type=host">Hosts</a> >
                 <span>{$query/host/string()} </span> >
                 <a href="?corpus={$query/corpus}&amp;type=activitySet&amp;host={$query/host}">Activity Sets</a> | 
                 <a href="?corpus={$query/corpus}&amp;type=activitySet&amp;host={$query/host}&amp;search=loaded">Loaded</a> |
                 <a href="?corpus={$query/corpus}&amp;type=activitySet&amp;host={$query/host}&amp;search=notloaded">Not Loaded</a> |
                 <a href="?corpus={$query/corpus}&amp;type=activitySet&amp;host={$query/host}&amp;search=stale">Stale</a>
               </div>

               <div class="body">
               <h2>Data</h2>
               <ul>
                  <li>Number of Activity Sets {count($activitySets)}</li>
                  <li>Number downloaded {count($activitySets[download-modified])}</li>
                  <li>Number not loaded {count($activitySets[empty(download-modified)])}</li>
                  <li>Number stale {count($activitySets[download-modified][ cache-modified > download-modified])}</li>
                  <li>Activities {count($activities)}</li>
                  <li>Included activities {count($activities[@iati-ad:include])} </li>
               </ul>
               <h2>Activity Analysis</h2>
               <ul>
                 <li>Funders {for $ref in distinct-values($activities/participating-org/@iati-ad:funder)
                              let $funder := codes:code-value("Funder",$ref,$query/corpus)
                              return concat($ref," : ",$funder/name/string())
                              }</li>
               </ul>
               <!--
               <h2>Tasks</h2>
               <ul>
                 <li><a href="?corpus={$query/corpus}&amp;type=activitySet&amp;host={$query/host}&amp;mode=download">Download a page</a></li>
                 <li><a href="?corpus={$query/corpus}&amp;type=activitySet&amp;host={$query/host}&amp;mode=download&amp;pagesize=10000">Download all</a></li>
                 <li><a href="?corpus={$query/corpus}&amp;type=activitySet&amp;host={$query/host}&amp;mode=delete">Delete a page</a> Use with great care</li>
                <li><a href="?corpus={$query/corpus}&amp;type=activitySet&amp;host={$query/host}&amp;mode=delete&amp;pagesize=10000">Delete all</a> Use with great care</li>
                <li><a href="?corpus={$query/corpus}&amp;type=activitySet&amp;host={$query/host}&amp;mode=analysis">Code Analysis</a></li>  not yet implemented 
               </ul>
               -->
               <h2>Comment</h2>
               <pre>{$host/comment/string()} </pre>
                
               </div>
          </div>
 else 

(: --------------- type = activitySet   ---------------- :)  
  if (exists($query/corpus) and $query/type="activitySet" )
  then
     let $activitySet := doc(concat($config:data,$query/corpus,"/activitySets.xml"))/activitySets
     let $activitySets :=  
          if (exists($query/src))
          then 
              $activitySet/activitySet[download_url eq $query/src] 
          else 
              let $activitySets := $activitySet/activitySet
              return
                 if (exists($query/host)) 
                 then
                      $activitySets[host=$query/host]
                 else $activitySets 
     let $activitySets := 
          if ($query/search = "loaded") 
          then  $activitySets[download-modified] 
          else if ($query/search="notloaded")
          then  $activitySets[empty(download-modified)]       
          else if ($query/search="stale")
          then  $activitySets[download-modified][cache-modified > download-modified]       
          else $activitySets          
     let $selected-activitySets :=subsequence(subsequence($activitySets,$query/start),1,$query/pagesize)
     return 
       if ($query/mode="view" and empty($query/src))
       then 
      <div>
         <div class="nav">
           
           <a href="?corpus={$query/corpus}">{$query/corpus/string()}</a> >
           {if (empty($query/host))
            then <a href="?corpus={$query/corpus}&amp;type=host">Hosts</a> 
            else <a href="?corpus={$query/corpus}&amp;type=host&amp;host={$query/host}">{$query/host/string()}</a>
           } >
           <span>Activity Sets {$query/host/string()}</span> > 
          {if ($query/search) then (<span>{$query/search/string()}</span>, " > ") else () }

           <a href="?corpus={$query/corpus}&amp;type=activitySet&amp;host={$query/host}&amp;search={$query/search}&amp;mode=download&amp;pagesize=200">Download</a>
          </div>
  
        <div>
         {wfn:paging(concat("?corpus=",$query/corpus,"&amp;type=activitySet&amp;host=",$query/host,"&amp;search=",$query/search),$query/start,$query/pagesize,count($activitySets))}
          {load:list-activitySets($selected-activitySets,$query/corpus)}
         </div>
     </div>
     else if ($query/mode="view" and exists($query/src))
     then
         let $activities := collection($activity-collection)/iati-activity[@iati-ad:activitySet=$query/src][@iati-ad:live]
         let $selected-activities := subsequence(subsequence($activities,$query/start),1,$query/pagesize)
         return 
     <div>
        <div class="nav"> 
           
           <a href="?corpus={$query/corpus}">{$query/corpus/string()}</a> >
           <a href="?corpus={$query/corpus}&amp;type=activitySet">Activity Sets</a> >
           <span>{$query/src/string()}</span> >
           <a href="?corpus={$query/corpus}&amp;type=activitySet&amp;src={encode-for-uri($query/src)}&amp;mode=analysis">Analysis</a>
       </div>
       <div>
          {wfn:paging(concat("?corpus=",$query/corpus,"&amp;type=activitySet&amp;src=",encode-for-uri($query/src)),$query/start,$query/pagesize,count($activities))}
          {load:list-activities($selected-activities, $query/corpus)}
      </div>
    </div>
    else if ($query/mode=("refresh","download"))
    then
         let $download := load:download-activities($selected-activitySets,$query)
         return 
           response:redirect-to(xs:anyURI(concat($script,"?corpus=",$query/corpus,"&amp;type=activitySet")))

   else if ($query/mode="delete" and exists($query/src))
   then 
        let $delete := load:remove-activities($selected-activitySets,$query/corpus)
        return response:redirect-to(xs:anyURI(concat($script,"?corpus=",$query/corpus,"&amp;type=activitySet&amp;host=",$query/host)))
        
   else if ($query/mode="delete" and exists($query/host))
   then 
        let $deletions :=
           for $activitySet in $selected-activitySets[modified-download]
           return load:remove-activities($activitySet,$query/corpus)
        return response:redirect-to(xs:anyURI(concat($script,"?corpus=",$query/corpus,"&amp;type=host&amp;host={$query/host}")))
        
   else if ($query/mode="analysis" and exists($query/src) and empty($query/id))
   then  let $activities := collection($activity-collection)/iati-activity[@iati-ad:activitySet=$query/src][@iati-ad:live]       
         return
         <div>
          <div class="nav">
              
              <a href="?corpus={$query/corpus}">{$query/corpus/string()}</a> >
              <a href="?corpus={$query/corpus}&amp;type=activitySet">Activity Sets</a> >
              <a href="?corpus={$query/corpus}&amp;type=activitySet&amp;src={encode-for-uri($query/src)}">{$query/src}</a> >
              <span>Analysis</span>
          </div>
           {validate:activities-analysis($activities,concat("?mode=analysis&amp;corpus=",$query/corpus,"&amp;type=activitySet&amp;src=",encode-for-uri($query/src),"&amp;id="))}
         </div>
   else if ($query/mode="analysis" and  exists($query/src) and exists($query/id))
   then  let $activities := collection($activity-collection)/iati-activity[@iati-ad:activitySet=$query/src][@iati-ad:live]       
         return 
            <div>
             <div class="nav">
              
              <a href="?corpus={$query/corpus}">{$query/corpus/string()}</a> >
              <a href="?corpus={$query/corpus}&amp;type=activitySet">Activity Sets</a> >
              <a href="?corpus={$query/corpus}&amp;type=activitySet&amp;src={encode-for-uri($query/src)}">{$query/src}</a> >
              <a href="?corpus={$query/corpus}&amp;type=activitySet&amp;src={encode-for-uri($query/src)}&amp;mode=analysis">Analysis</a> >
              <span>Code {$query/id}</span>
          </div>
            {validate:path-analysis($activities,$query/id)}
            </div>
   else if ($query/mode="analysis" and empty($query/src) and empty($query/id))
   then  let $activities := collection($activity-collection)/iati-activity[@iati-ad:live]   
         return
         <div>
          <div class="nav">
              
              <a href="?corpus={$query/corpus}">{$query/corpus/string()}</a> >
              <a href="?corpus={$query/corpus}&amp;type=activitySet">Activity Sets</a> >
               <span>Analysis</span>
          </div>
           {validate:activities-analysis($activities,concat("?mode=analysis&amp;corpus=",$query/corpus,"&amp;type=activitySet&amp;id="))}
         </div>
   else if ($query/mode="analysis" and empty($query/src) and exists($query/id))
   then  let $activities := collection($activity-collection)/iati-activity[@iati-ad:live]  
         return 
            <div>
             <div class="nav">
              
              <a href="?corpus={$query/corpus}">{$query/corpus/string()}</a> >
              <a href="?corpus={$query/corpus}&amp;type=activitySet">Activity Sets</a> >
              <a href="?corpus={$query/corpus}&amp;type=activitySet&amp;mode=analysis">Analysis</a> >
              <span>Code {$query/id/string()}</span>
          </div>
            {validate:path-analysis($activities,$query/id)}
            </div>

    else ()
    
(: ------  type = activity ---------------- :)
 
   else if ($query/type="activity" and exists($query/corpus))
        then if ($query/mode="view" and exists($query/id) and $query/format="html")
             then 
               let $activity := collection($activity-collection)/iati-activity[iati-identifier=$query/id][@iati-ad:live]
               let $source := $activity/@iati-ad:activitySet/string()
            return
       <div>
           <div class="nav">
           
           <a href="?corpus={$query/corpus}">{$query/corpus/string()}</a> >
           <a href="?corpus={$query/corpus}&amp;type=activitySet">Activity Sets</a> >
           <a href="?corpus={$query/corpus}&amp;type=activitySet&amp;src={encode-for-uri($source)}">{$source}</a> >
           <span>{$query/id/string()}</span>
           <a href="?corpus={$query/corpus}&amp;mode=view&amp;type=activity&amp;id={$query/id}&amp;format=xml">XML</a>

         </div>
         <div>
              { validate:validate-activity($activity)}
         </div>
       </div>
    else if ($query/mode="view" and exists($query/id) and $query/format="xml")
    then let $doc := collection($activity-collection)/iati-activity[iati-identifier=$query/id][@iati-ad:live]
             return $doc
     else if ($query/mode="reindex")
     then xmldb:reindex($activity-collection)
     else ()
(: ------  type = code - master ---------------- :)
   else if ($query/type="code" and empty($query/corpus))
   then 
      if ($query/mode="view" and empty($query/id))
      then 
       <div>
          <div class="nav">
           
            <span>Codelist Index</span>
          </div>
         <div class="body">
         {codes:code-index-as-html ()}
         </div>
       </div>
      else if ($query/mode="view" and exists($query/id))
      then  
       <div>
          <div class="nav">
           
           <a href="?type=code">Codelist Index</a>
           <span>{$query/id/string()}</span>
          </div>
         <div class="body">
         {codes:code-list-as-html($query/id)}
         </div>
       </div>
      else if ($query/mode="reindex" )
      then  
         let $reindex := xmldb:reindex(concat($config:base,"codes"))
         return response:redirect-to(xs:anyURI("admin.xq?mode=view&amp;type=code"))
         
      else if ($query/mode="download")
      then  let $download := codes:download-codelists()
            return response:redirect-to(xs:anyURI("admin.xq?mode=view&amp;type=code"))
      else ()
 (:  --------- code and corpus -------------  :)
  else if ($query/type="code" and exists($query/corpus))
    then 
      if ($query/mode="view" and empty($query/id))
      then
        <div>
         <div class="nav">
           
           <a href="?corpus={$query/corpus}">{$query/corpus/string()}</a> >
           <span>Codelist Index</span>
         </div>
         <div class="body">
            {codes:code-index-as-html ($query/corpus)}
         </div>
       </div>
      else if ($query/mode="view" and exists($query/id))
      then 
       <div>
          <div class="nav">
           
           <a href="?corpus={$query/corpus}">{$query/corpus/string()}</a> >
           <a href="?corpus={$query/corpus}&amp;type=code">Codelist Index</a>
           <span>{$query/id/string()}</span>
          </div>
         <div class="body">
            {codes:code-list-as-html($query/corpus ,$query/id)}
         </div> 
       </div>  
       
      else if ($query/mode="reindex" ) 
      then  
         let $reindex := xmldb:reindex(concat($config:data,$query/corpus,"/codes"))
         return response:redirect-to(xs:anyURI(concat("admin.xq?corpus=",$query/corpus,"&amp;type=code")))
     
      else if ($query/mode="cache")
      then  
          let $cache-def := doc(concat($config:system,"cache-codes.xml"))/cache-def
          let $cache :=  codes:cache-codes($query/corpus,$cache-def)
          return response:redirect-to(xs:anyURI(concat("admin.xq?corpus=",$query/corpus,"&amp;type=code")))
      else if ($query/mode="cache-orgs")
      then let $cache := codes:cache-organisation-identifier-codes($query/corpus)
        return  response:redirect-to(xs:anyURI(concat("admin.xq?corpus=",$query/corpus,"&amp;type=code&amp;id=OrganisationIdentifier")))

      else ()
  
   else if ($query/type="rule")
   then 
    <div>
          <div class="nav">
           
            <span>Rules</span>
          </div>
         <div class="body">
         {validate:rules-as-html()}
         </div>
       </div>
   else if ($query/mode="stats")
   then 
      let $activitySets := doc(concat($config:data,$query/corpus,"/activitySets.xml"))/activitySets
       return
      <div>
          <div class="nav">
           
           <a href="?corpus={$query/corpus}">{$query/corpus/string()}</a> >
           <span>Stats</span>
          </div>
          <div>
            <div>Number of activitySets {count($activitySets/activitySet)}</div>
            <div>Number of ckan packages {count($activitySets/activitySet[package])}</div>
            <div>Number of activitySets loaded {count($activitySets/activitySet[download-modified])}</div>
            <div>Number of activities {count(collection($activity-collection)/iati-activity)}</div>
            <div>Number of live activities {count(collection($activity-collection)/iati-activity[@iati-ad:live])}</div>
            <div>Number of included activities {count(collection($activity-collection)/iati-activity[@iati-ad:include])} (activity-status not 4 or 5)</div>
           </div>
      </div>
  else if (exists($query/corpus) and $query/mode = "zip")
  then let $zip := zipapp:zip( 
       (concat($config:data,$query/corpus), concat("/db/system/config",$config:data,$query/corpus))
       , concat($query/corpus,"-",current-date())
       )
       return
         <div> Corpus zipped <a href="{$zip}">{$zip}</a> </div>
  else if (empty($query/corpus) and $query/mode = "zip")
  then let $zip := zipapp:zip(doc(concat($config:system,"resources.xml"))//resource[empty(@ignore)]/@path , replace(concat("configase-",current-dateTime()),":","-"))
       return
         <div> iati-api zipped <a href="{$zip}">{$zip}</a> </div>
  else if (empty($query/corpus) and $query/mode="resources")
  then  <div>
          <div class="nav">
           
           <span>Application resources</span> 
          </div>
          <div>
            <table border ="1" class="sortable">
            <tr><th width="30%">Resource</th><th>Exported</th><th>Description</th></tr>
            {for $resource in doc(concat($config:system,"resources.xml"))//resource
             return 
               <tr>
                   <td>
                      {if (ends-with($resource/@path,".xml") or ends-with($resource/@path,".xconf")) 
                       then <a href="/exist/rest/{$resource/@path}">{$resource/@path/string()}</a>
                       else $resource/@path/string()
                      }
                   </td>
                   <td>{if (empty($resource/@ignore)) then "*" else () }</td>
                   <td>{$resource/description/string()}</td>
               </tr>
            }
            </table>
          </div>
        </div>
  else if ($query/mode="register")
  then login:register($query)
  else if ($query/mode="add-member")
  then login:add-member($query, $admin-ui:members )
  else if ($query/mode="logout")
  then login:logout()

  else if (exists($query/corpus))
   then 
      <div>
          <div class="nav">
           
           <span>{$query/corpus/string()}</span> >
           <a href="?corpus={$query/corpus}&amp;type=host">Hosts</a> |
           <a href="?corpus={$query/corpus}&amp;type=activitySet">Activity Sets</a> |
           <a href="?corpus={$query/corpus}&amp;type=code">Codelist</a> |
           <a href="?corpus={$query/corpus}&amp;mode=stats">Statistics</a> |
           <a href="woapi.xq?corpus={$query/corpus}">Query</a>  |
           <a href="?corpus={$query/corpus}&amp;type=activitySet&amp;mode=analysis">Analysis</a>

          </div>
        <div>
        <h2>Views</h2>
        <ul>
              <li><a href="/exist/rest/{concat($config:data,$query/corpus,"/log.xml")}">Update Log </a> = raw XML at present</li>
        
        </ul>
         <h2>Update tasks</h2>
         <ul>
              <li><a href="?corpus={$query/corpus}&amp;mode=download&amp;type=registry">Download Activity Set metadata from the registry</a> </li>
              <li>Download required activitySets</li>
              <li><a href="?corpus={$query/corpus}&amp;mode=download&amp;type=web">Download Activity Set from the web </a></li>
              <li><a href="?corpus={$query/corpus}&amp;mode=reindex&amp;type=activity">Reindex activities</a></li>
      <!--        <li><a href="?corpus={$query/corpus}&amp;mode=cache-orgs&amp;type=code">Cache OrganisationIdentifiers</a> very slow</li>  -->
              <li><a href="?corpus={$query/corpus}&amp;mode=cache&amp;type=code">Cache corpus codes</a></li>
              <li><a href="?corpus={$query/corpus}&amp;mode=reindex&amp;type=code">Reindex codes</a></li>
              <li><a href="?corpus={$query/corpus}&amp;mode=zip">Zip up the corpus</a></li>
             </ul>
          </div>
        </div>

   else if (empty($query/corpus))
   then 
      <div>
        <div class="nav">
           <span>Home</span> 
          {if (empty($query/membername)) 
          then <a href="?mode=login-form">Login</a>
          else ( <span>{$query/membername/string()} Logged in</span>, <a href="?mode=logout">Logout</a>)
         }

        </div>
        <div class="body">
        <h2>Views</h2>
        <ul>
        <li><a href="?type=code&amp;mode=view">Code list</a></li>
        <li> <a href="?type=rule&amp;mode=view">Rules</a></li>
        <li> <a href="validate.xq">Standalone Validator</a> </li>
        <li> <a href="woapi.xq">API</a> </li>

        </ul>
        <h2>Corpii</h2>
        <ul>
        {  for $corpus in doc(concat($config:system,"corpusindex.xml"))//corpus[empty(@hidden)]
            return 
            <li> <a href="?corpus={$corpus}">{$corpus/string()}</a> </li>
        }
        </ul>
              <h2>Views</h2>
        <ul>
               <li><a href="?mode=resources">Application resources</a></li>
               <li><a href="/exist/rest/{concat($config:data,"pipeline-errors.xml")}">Errors encountered in the pipeline - for all corpii</a> </li>
               <li><a target="_blank" href="../../logger/xquery/browse.xq?log=iati">Browse the activity log</a> </li>
        </ul>
 
        <h2>Update tasks</h2>
        <ul>
          <li><a href="?type=code&amp;mode=download">Download master code list </a></li>
           <li><a href="?type=code&amp;mode=reindex">Reindex codes</a></li>
          <li><a href="?type=corpus&amp;mode=create">Create a new corpus</a></li>
          <li><a href="?mode=register">Register new member</a></li>
          <li><a href="?mode=zip">Zip up the code base</a></li>
         </ul>
         <h2>Test scripts</h2>
         
         <ul>
          {for $script in collection (concat($config:base,"tests"))/TestSet
           return 
              <li><a target="_blank" href="../../sys/runTests.xq?testfile={$config:base}tests/{util:document-name($script)}">{$script/testName/string()}</a> {$script/description/string()}</li>
          }
         </ul>
            <h2>Links</h2>
            <ul>
                <li>
                    <a class="external" href="http://www.iatistandard.org">IATI Standard</a>
                </li>
                <li>
                    <a  class="external" href="http://www.iatiregistry.org/">IATI Registry</a>
                </li>
                <li>
                    <a  class="external" href="http://www.aidinfo.org/">AidInfo</a>
                </li>
                <li>
                    <a  class="external" href="http://tools.aidinfolabs.org/">AidInfoLabs</a>
                </li>
                <li>
                    <a  class="external" href="http://tools.aidinfolabs.org/explorer">IATI Data Explorer</a>
                </li>
            </ul>
       </div>
     
      </div>
    else ()
};


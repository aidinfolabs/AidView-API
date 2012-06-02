module namespace ui = "http://tools.aidinfolabs.org/api/ui";
declare namespace iati-ad = "http://tools.aidinfolabs.org/api/AugmentedData";

import module namespace rules = "http://tools.aidinfolabs.org/api/rules" at "../lib/rules.xqm";
import module namespace codes = "http://tools.aidinfolabs.org/api/codes" at "../lib/codes.xqm";  
import module namespace config = "http://tools.aidinfolabs.org/api/config" at "../lib/config.xqm";  
import module namespace activity = "http://tools.aidinfolabs.org/api/activity" at "../lib/activity.xqm";   
import module namespace pipeline = "http://tools.aidinfolabs.org/api/pipeline" at "../lib/pipeline.xqm";  
import module namespace olap = "http://tools.aidinfolabs.org/api/olap" at "../lib/olap.xqm";  
import module namespace rss = "http://tools.aidinfolabs.org/api/rss" at "../lib/rss.xqm";  
import module namespace load = "http://tools.aidinfolabs.org/api/load" at "../lib/load.xqm";  
import module namespace jobs = "http://tools.aidinfolabs.org/api/jobs" at "../lib/jobs.xqm";
import module namespace wfn = "http://kitwallace.me/wfn" at "/db/lib/wfn.xqm";
import module namespace url = "http://kitwallace.me/url" at "/db/lib/url.xqm";
import module namespace jxml = "http://kitwallace.me/jxml" at "/db/lib/jxml.xqm";

(: this function coerces a path to a query string - part of the unimplemented activity set profiling :)
declare function ui:activitySelector($context) {
  string-join(
    (if ($context/set) then   concat("set=",$context/set) else (),
     if ($context/funder) then   concat("funder=",$context/funder) else (),
     if ($context/publisher) then   concat("publisher=",$context/publisher) else (),
     if ($context/activity) then   concat("activity=",$context/activity) else ()
    )
  ,"&amp;"
  )
};

(:  the following functions are called from the dispatcher :)

declare function ui:home($context) as element(div) {
 <div>
            <div class="nav">
              <span>Home</span> >
              <a href="{$context/_root}codelist">Codelists</a> |
              <a href="{$context/_root}ruleset">Rulesets</a> |
              <a href="{$context/_root}corpus">Corpuses</a> | 
              <a href="{$context/_root}profile">Profiles</a> |
              <a href="{$context/_root}pipeline">Pipelines</a> |
              <a href="{$context/_root}doc">About</a> 
              |  {if ($context/isadmin) then <a href="/data/">Public</a> else  <a title="requires authenication"  href="/admin/">Admin</a> }
              {if ($context/isadmin) then (" | ",<a href="{$context/_root}jobs">Scheduled Jobs</a> ) else ()}
             </div>
             
               <div>
               <h2>Test Activity Set</h2>
               
               Load and validate an arbitrary activitySet document: <form action="{$context/_fullpath}load">
               URL <input type="text" name="url" size="60"/> 
               <input type="submit" value="Load"/>
               </form>
               </div>
             
               <h2>Links</h2>
              <ul>
                <li><a class="external" href="../xquery/woapi.xq">Query API</a></li>
                <li><a class="external" href="http://www.iatistandard.org">IATI Standard</a></li>
                <li><a  class="external" href="http://www.iatiregistry.org/">IATI Registry</a></li>
                <li><a  class="external" href="http://www.aidinfo.org/">AidInfo</a></li>
                <li><a  class="external" href="http://tools.aidinfolabs.org/">AidInfoLabs</a></li>
                <li><a  class="external" href="http://tools.aidinfolabs.org/explorer">IATI Data Explorer</a></li>
                <li><a href="http://opencirce.org/org">Open Circe </a>  OrganisationIdentifiers</li>            
                <li><a href="http://exist-db.org">eXist-db</a></li>
              </ul>
               {if ($context/isadmin)
                then 
                 <div>
                 <h2>Admin</h2>
                 <ul>
                   <li><a href="http://{$config:ip}:8080/exist">Exist admin</a></li>
                   <li><a href="http://{$config:ip}:8080/exist/rest/apps/sys/xq/export-2.xq?resourceFile=/db/apps/iati/system/resources.xml">Code and configuration Resources</a> View and/or Export off-site before updating code</li>
                   <li><a href="http://{$config:ip}:8080/exist/rest/apps/sys/xq/export-2.xq?resourceFile=/db/apps/iati/system/resources-full.xml">Full Resources</a> Everything </li>
                   <li><a href="http://{$config:ip}:8080/exist/rest/apps/sys/xq/export-2.xq?resourceFile=/db/apps/iati/system/resources-data.xml">Data</a> Just the date - mainly only for application prep</li>
                   <li><a href="http://{$config:ip}:8080/exist/rest/apps/sys/xq/systemProperties.xq">System Properties</a></li>
                   <li><a href="http://{$config:ip}:8080/exist/rest/apps/sys/xq/browseLog.xq?log=iati">Log</a> This is a log of web activity - currently {$config:logging} </li>                  
                   <li><a href="../system/jobs.xml">Job list</a></li>
                 </ul>
                 <h2>Tests</h2>
                 <ul>            
                   {for $test in collection (concat($config:base,"tests"))/TestSet
                    let $name := util:document-name($test)
                    return 
                      <li><a href="http://{$config:ip}:8080/exist/rest/apps/sys/xq/runTests.xq?testfile={$config:base}tests/{$name}">{$test/testName/string()}</a></li>
                   }               
                 </ul>
                 </div>
                else ()
               }
</div>
};

declare function ui:jobs($context) as element(div) {
       <div>
          <div class="nav">
               {url:path-menu($context/_fullpath,(),$config:map)}  
          </div>
          <ul>
          {for $job in jobs:scheduled-jobs()
           return <li>{$job/@name/string()} : state {$job//state/string()} </li>
          }
          </ul>
      </div>
};

declare function ui:all-corpus($context) as element(div) {
<div>
          <div class="nav">
               {url:path-menu($context/_fullpath,(),$config:map)}  
               | <a href="{$context/_root}doc/corpus">About</a>
          </div>
           <table>
            {
            let $corpii := activity:corpus-meta()
            let $corpii := if ($context/isadmin) then $corpii else $corpii[empty(@hidden)]
            for $corpus in $corpii
             let $acount := count(activity:corpus($corpus/@name))
             return
               <tr>
                 <td><a href="{$context/_root}corpus/{$corpus/@name}">{$corpus/@name/string()}</a></td>
                 <td>{$acount}</td>
                 <td>{if ($corpus[@default]) then "default" else ()}</td>
                 <td>{$corpus/description/node()}</td>
                 <td>{$corpus/@pipeline/string()}</td>
                 <td>{$corpus/description/node()}</td>
               </tr>
            }  
            </table>
</div>

};


declare function ui:corpus($context) as element(div) {
 <div>
           <div class="nav">
               {url:path-menu($context/_fullpath,("set", "activity","search"),$config:map)}  
               |  <a href="/xquery/woapi.xq?corpus={$context/corpus}">Query API</a> 
            </div>
            <div>
             <h2>Facets</h2>
            <ul>
               {for $dimension in olap:meta-dimensions()
                return 
                   <li><a href="{$context/_fullpath}/{$dimension/@name}">{$dimension/@name/string()}</a></li>
               }
            </ul>
             </div>
            {if ($context/isadmin) then
            <div>
            
               
               <h2>Load Activity Set</h2>
               
               Load an activitySet document from source :
               <form action="{$context/_fullpath}load">
               URL <input type="text" name="url" size="60"/> 
               <input type="submit" value="Load"/>
               </form>
               
               
              <h2>Tasks</h2>
               <ul>
                   <li><a href="{$context/_root}corpus/{$context/corpus}/ckan">Page Refresh from CKAN</a> This extracts the list of packages and then fetches a subset (start for pagesize) packages and updates the activitySet if necessary</li>
                   <li><a href="{$context/_root}corpus/{$context/corpus}/ckanall">Full Refresh from CKAN</a> Runs the full extract as a background task (cause thrashing at present so avoid)</li>
                   <li><a href="{$context/_root}corpus/{$context/corpus}/download">Download</a> This will attempt to download all sets</li>
                   <li><a href="{$context/_root}corpus/{$context/corpus}/olap">Create OLAP</a> Create the OLAP summary - required after a download to bring the summaries inline</li>
                   <li><a href="{$context/_root}corpus/{$context/corpus}/reindex">Reindex</a> Reindex the corpus data.</li>
                   <li><a href="http://{$config:ip}:8080/exist/rest/apps/sys/xq/export-2.xq?resourceFile=/db/apps/iati/data/{$context/corpus}/resources.xml">Backup</a>
                   
                   This zips the data in the corpus into a file in /var/www/backups so that it can be copied externally - approx 2k * no of activities</li>
                </ul>
            
            </div>
             else ()
            }
 </div>
};

(: work to do - needs a form 
:)

declare function ui:corpus-reindex($context) as element(div) {
<div>
            <div class="nav">
               {url:path-menu($context/_fullpath,(),$config:map)}  
           </div>
            {xmldb:reindex(concat($config:data,$context/corpus))}
            
 </div>  

};

declare function ui:corpus-download($context) as element(div) {
<div>
            <div class="nav">
               {url:path-menu($context/_fullpath,(),$config:map)}  
           </div>
               {jobs:start-download($context/corpus,"","","update") }          
 </div>  
};

declare function ui:corpus-olap($context) as element(div) {

        <div>
             <div class="nav">
               {url:path-menu($context/_fullpath,(),$config:map)}  
              
             </div>
              {jobs:start-olap($context/corpus)}
         </div>  
};

declare function ui:corpus-ckan($context) as element(div) {
 
    <div>
            <div class="nav">
               {url:path-menu($context/_fullpath,(),$config:map)}  
            </div>

           <div>
           {activity:package-page($context)}
           </div>
   
    </div>
};

declare function ui:corpus-ckanall($context) as element(div) {
 
    <div>
            <div class="nav">
               {url:path-menu($context/_fullpath,(),$config:map)}  
            </div>

           <div>
           {jobs:start-ckan($context/corpus)}
           </div>
   
    </div>
};

declare function ui:corpus-ckansubset($context) as element(div) {
 
    <div>
            <div class="nav">
               {url:path-menu($context/_fullpath,(),$config:map)} 
               
            </div>

           <div>
           {load:ckan-activitySets($context)}
           </div>
   
    </div>
};

declare function ui:hosts($context) {
 <div>
            <div class="nav">
               {url:path-menu($context/_fullpath,(),$config:map)}  
            </div>

            <div>
            <h2>Summary</h2>
              {let $sets := activity:activitySets($context/corpus)
               let $activities := activity:corpus($context/corpus)
               return
                 <table>
                    <tr><th>Number of Sets </th><td>{count($sets)}</td></tr>
                    <tr><th>Number of Valid Sets </th><td>{count($sets[empty(error)])}</td></tr>
                    <tr><th>Number of Sets downloaded </th><td>{count($sets[download-modified])}</td></tr>
                    <tr><th>Total number of activities</th><td>{count($activities)}</td></tr>
                    <tr><th>Number included </th><td>{count($activities[@iati-ad:include])}</td></tr>
                 
                 </table>
              }
           <h2>Hosts</h2>
           <table> 
             <tr><th>Host</th><th>Activity Sets</th><th>Downloaded</th></tr>
            {for $host in  activity:corpus-hosts($context/corpus)
             let $sets := activity:host-activitySets($context/corpus,$host)
             order by $host
             return
                   <tr>
                      <td><a href="{$context/_fullpath}/{$host}">{$host}</a></td>
                      <td>{count($sets)}</td>
                      <td>{count($sets[download-modified])}</td>
                   </tr>
            }
         </table>   
         </div>
</div>
};

declare function ui:host($context) {
      <div>
            <div class="nav">
               {url:path-menu($context/_fullpath,("set","download", "delete"),$config:map)}
            </div>
            <div> 
              <h2>Current Summary</h2>
              {let $sets := activity:host-activitySets($context/corpus,$context/Host)
               let $activities := activity:set-activities($context/corpus,$sets/package)
               return
                 <table>
                    <tr><th>Number of Sets </th><td>{count($sets)}</td></tr>
                    <tr><th>Number of Valid Sets </th><td>{count($sets[empty(error)])}</td></tr>
                    <tr><th>Number of Sets downloaded </th><td>{count($sets[download-modified])}</td></tr>
                    <tr><th>Total number of activities</th><td>{count($activities)}</td></tr>
                    <tr><th>Number included </th><td>{count($activities[@iati-ad:include])}</td></tr>
                 
                 </table>
              }
              {
              let $cached-summary := olap:host-stats($context)
              return 
                if ($cached-summary)
                then
                  <div>
                     <h2>Cached summary</h2>
                     {$cached-summary}
                 </div>
              else ()
              }            
            </div>          
      </div>
};

declare function ui:set-page($context, $activitySets) {
       <div>
            <div class="nav">
               {url:path-menu($context/_fullpath,(),$config:map)}
             </div>
            {activity:set-page($activitySets,$context,$context/_fullpath)}                 
       </div>
};      

declare function ui:set-activity-page($context, $activities) {
  <div>
            <div class="nav">
                    {url:path-menu($context/_fullpath,(),$config:map)}
            >  <span>{$context/set}</span>
               <span>Activities</span> >
             <a href="{$context/_root}corpus/{$context/corpus}/profile/{$context/set}">Profile</a>
            </div>
           {activity:page($activities,$context,$context/_fullpath)}        
  </div> 
};

declare function ui:host-download($context) {
  <div>
            <div class="nav">
                    {url:path-menu($context/_fullpath,(),$config:map)}
            </div>
            {jobs:start-download($context/corpus,$context/Host,"","update") }        
  </div> 
};

declare function ui:set-download($context, $activitySets) {
  <div>
            <div class="nav">
                    {url:path-menu(concat($context/_root,"corpus/",$context/corpus,"/"),(),$config:map)}
            >  <span>{$context/set}</span>
               <span>Download</span> >
            </div>
           {let $download := load:download-activities($activitySets,$context)
            return activity:set-page($activitySets,$context,$context/_fullpath)
           }        
  </div> 
};

declare function ui:remove-activities($context, $activitySets) {
  <div>
            <div class="nav">
                    {url:path-menu(concat($context/_root,"corpus/",$context/corpus,"/"),(),$config:map)}
            >  
               <span>Delete activities</span> >
            </div>
           {load:remove-activities($activitySets,$context)}        
  </div> 
};

declare function ui:activities-page($context,$activities) {
<div>
            <div class="nav">
               {url:path-menu($context/_fullpath,(),$config:map)}
              <a href="{$context/_root}doc/activities">About</a>
            </div>
             {activity:page($activities,$context,concat($context/_root,"corpus/",$context/corpus,"/activity"))}
</div>
};

declare function ui:activity-page($context,$activity) {
 <div>
           <div class="nav">
              {url:path-menu($context/_fullpath,("full","profile"),$config:map)}
              |
               <a href="{$context/_root}corpus/{$context/corpus}/set/{$activity/@iati-ad:activitySet}">Activity Set</a>
              |  <a href="{$context/_root}corpus/{$context/corpus}/activity/{replace($context/activity,"/","_")}.xml">XML</a>          
           </div>
            <div>          
                {activity:as-html($activity,$context)}
           </div>
</div>
};  

declare function ui:load-url($context) {
  let $set :=  load:external-activitySet($context)
  return   
     ui:set-page($context,$set) 
};

declare function ui:search-corpus($context) {
   let $results := 
    if ($context/q)
    then collection(concat($config:data,$context/corpus,"/activities"))/iati-activity[ft:query((title|description), $context/q/string())]
    else ()
   return 
      <div>
            <div class="nav">
               {url:path-menu($context/_fullpath,(),$config:map)}
              <a href="{$context/_root}doc/activities">About</a>
            </div>
            <div> 
               <form action="{$context/_fullpath}">
               Search activity descriptions and titles <input type="text" name="q" value="{$context/q}" size="40"/>
               <input type="submit" value="search"/>
               </form>             
              {activity:page($results,$context,concat($context/_root,"corpus/",$context/corpus,"/search?q=",$context/q))}
            </div>
     </div>
};    

(: 
this very large selection is the dispatcher for HTML page requests - 
the if ()then ..else structure would be better implement in XQuery 3 using a switch statement 
or a table lookup and eval 
:)

declare function ui:content($context) { 
let $sig := $context/_signature
return
       if ($sig="") then ui:home($context)
       
  else if ($sig = "load" and $context/url) then 
     ui:load-url(element context {
                     $context/(* except corpus),
                     element corpus {"vstore"}, 
                     element mode {"refresh"} 
                  }
                )
  else if ($sig = "corpus") then ui:all-corpus($context)
  else if ($sig = "corpus/*") then ui:corpus($context)
  else if ($context/isadmin and $sig = "jobs") then ui:jobs($context)
  else if ($context/isadmin and $sig = "corpus/*/reindex") then ui:corpus-reindex($context)
  else if ($context/isadmin and $sig = "corpus/*/olap") then ui:corpus-olap($context)
  else if ($context/isadmin and $sig = "corpus/*/ckan") then ui:corpus-ckan($context)
  else if ($context/isadmin and $sig = "corpus/*/ckanall") then ui:corpus-ckanall($context)
  else if ($context/isadmin and $sig = "corpus/*/ckansubset") then ui:corpus-ckansubset($context)
  else if ($context/isadmin and $sig = "corpus/*/download") then ui:corpus-download($context)   
  else if ($sig="corpus/*/search") then ui:search-corpus($context)
   else if ($sig="corpus/*/Host") then ui:hosts($context)
   else if ($sig="corpus/*/Host/*") then ui:host($context)
   else if ($sig="corpus/*/Host/*/set") then ui:set-page($context, activity:host-activitySets($context/corpus,$context/Host))
   else if ($sig="corpus/*/Host/*/download") then ui:host-download($context)
   else if ($context/isadmin and $sig="corpus/*/Host/*/delete")  then ui:remove-activities($context, activity:host-activitySets($context/corpus,$context/Host))
   else if ($sig="corpus/*/set") then ui:set-page($context, activity:activitySets($context/corpus))
   else if ($sig="corpus/*/set/*") then ui:set-page($context, activity:activitySet($context/corpus,$context/set))
   else if ($context/isadmin and $sig = "corpus/*/load" and $context/url) then 
     ui:load-url(element context {
                     $context/*,
                     element mode {"refresh"} 
                  }
                )
   else if ($sig="corpus/*/set/*/download")  then ui:set-download($context, activity:activitySet($context/corpus,$context/set))
   else if ($context/isadmin and $sig="corpus/*/set/*/delete") then ui:remove-activities($context, activity:activitySet($context/corpus,$context/set))
   else if ($sig="corpus/*/set/*/activity") then ui:set-activity-page($context,  activity:set-activities($context/corpus,$context/set))
   else if ($sig="corpus/*/activity") then ui:activities-page($context,activity:corpus($context/corpus))
   else if ($sig="corpus/*/activity/*") then ui:activity-page($context, activity:activity($context/corpus,$context/activity))
       
   (:  paths to facets arent parsed by the url function so we have to use the steps themselves 
    - rather clumsy - it would be more consistant to change the url format to /facet/Country/code/AL
    :)

  else if ($context/corpus and $context/_step[3]= olap:meta-dimensions()[@path]/@name)
            then if (exists($context/_step[4]) and $context/_step[5]="activity")  then olap:facet-activities($context/_step[3],$context) 
            else if (exists($context/_step[4]))  then olap:facet-occ($context/_step[3],$context) 
            else if (empty($context/_step[4]))  then olap:facet-list($context/_step[3],$context) 
            else ()

(:  these paths for validation of selections of activities but this not yet implemented :)

(:

else if ($sig="corpus/*/profile/*/report") 
      then    
          let $rules := rules:profile-rules($context/profile)
          let $summaries :=
              for $activity in activity:corpus($context/corpus,$context/q)
              let $errors := rules:validation-errors($activity,  $rules)
              return rules:error-summary($errors)
          let $report := rules:profile-summary($summaries, $profile)
          return 
            <div>
             <div class="nav">
              <a href="{$context/_root}">Home</a> >
              <a href="{$context/_root}profile" >Profiles</a> >         
              <span>{$profile/@name/string()}</span>
            </div>
                 {rules:profile-report-to-html($report)}
             </div>
             
 :)   
(:          
      else if ($sig="corpus/*/profile/*/summary")
      then 
   just a test selecting only for a set 
        let $selector := ui:activitySelector($context)
        let $activities:= activity:corpus($context/corpus)[@iati-ad:activitySet = $context/set]
        let $rules := rules:profile-rules($context/profile)
        let $summaries := for $activity in $activities 
                        let $errors := rules:validation-errors($activity,$rules)
                        return rules:error-summary($errors)
        let $report := rules:profile-summary($summaries,rules:profile($context/profile))
         
        return
           <div>
              <div class="nav">
                 {url:path-menu(concat($context/_root,"/corpus/",$context/corpus,"/profile?",$selector,"Activity"),(),$config:map)}
              </div>
              <div>
              <h2>{$selector}</h2>
                {rules:profile-report-to-html($report)}
              </div>
           </div>  
:)
 
  (:  profiles  :)
       
      else if ($sig="corpus/*/profile")
      then 
           let $selector := ui:activitySelector($context)
           return
           <div>
              <div class="nav">
                 {url:path-menu($context/_fullpath,(),$config:map)}
              </div>
              <div>
               <h2>{$selector}</h2>
                <table>
                  {for $profile in $rules:profiles[@root="activity"]
                   let $name := $profile/@name/string()
                   return
                      <tr><th>{$name}</th>
                         <td>{$profile/description/node()}</td>
                         <td><a href="{$context/_root}corpus/{$context/corpus}/profile/{$name}/summary?{$selector}">Summary</a> </td>
                      </tr>
                  }
                </table>
              </div>
           </div>  
    else if ($sig="corpus/*/activity/*/full")
      then 
        let $activity :=  activity:activity($context/corpus,$context/activity)
        return
           <div>
              <div class="nav">
                {url:path-menu($context/_fullpath,("profile"),$config:map)}
              <a href="{$context/_root}corpus/{$context/corpus}/activitySet/set/activity/{$activity/@iati-ad:activitySet}">Activity Set</a>         
           </div>
              <div>
                 {rules:view-doc($activity,())}
              </div>
           </div>   
     else if ($sig="corpus/*/activity/*/profile")
      then 
           <div>
              <div class="nav">
                 {url:path-menu($context/_fullpath,(),$config:map)}
              </div>
              <div>
                <ul>
                  {for $profile in $rules:profiles[@root="activity"]
                   let $name := $profile/@name/string()
                   order by $name
                   return
                      <li>{$name} :  {$profile/description/node()} >
                        <a href="{$context/_root}corpus/{$context/corpus}/activity/{replace($context/activity,"/","_")}/profile/{$name}/errors">errors</a> |
                        <a href="{$context/_root}corpus/{$context/corpus}/activity/{replace($context/activity,"/","_")}/profile/{$name}/full">full</a> |
                        <a href="{$context/_root}corpus/{$context/corpus}/activity/{replace($context/activity,"/","_")}/profile/{$name}/summary">summary</a> 
                      </li>
                  }
                </ul>
              </div>
           </div>  
           
      else if ($sig="corpus/*/activity/*/profile/*/errors")
      then 
        let $activity :=  activity:activity($context/corpus,$context/activity)
        let $rules := rules:profile-rules($context/profile)
        let $report := rules:validate-doc($activity, $rules,"errors") 
        return
           <div>
              <div class="nav">
                 {url:path-menu($context/_fullpath,(),$config:map)}
                 <a href="{concat($context/_fullpath,'.xml')}">XML</a>
              </div>
              <div>
                  {$report}
              </div>
           </div>  
      else if ($sig="corpus/*/activity/*/profile/*/full")
      then 
        let $activity :=  activity:activity($context/corpus,$context/activity)
        let $rules := rules:profile-rules($context/profile)
        let $report := rules:validate-doc($activity, $rules,"full") 
        return
           <div>
              <div class="nav">
                 {url:path-menu($context/_fullpath,(),$config:map)}
                 <a href="{concat($context/_fullpath,'.xml')}">XML</a>
               </div>
              <div>
                {$report}
              </div>
           </div>  

     else if ($sig="corpus/*/activity/*/profile/*/summary")
      then 
        let $activity :=   activity:activity($context/corpus,$context/activity)
        let $rules := rules:profile-rules($context/profile)
        let $errors := rules:validation-errors($activity,  $rules)
        let $summary := rules:error-summary($errors)
        let $report := rules:error-summary-as-html($summary)
        return
           <div>
              <div class="nav">
                  {url:path-menu($context/_fullpath,(),$config:map)}
                  <a href="{concat($context/_fullpath,'.xml')}">XML</a>
              </div>
              <div>
                {$report}
              </div>
           </div>  

      else if ($sig="profile")
      then 
           <div>
             <div class="nav">
              <a href="{$context/_root}">Home</a> >
              <span>Profiles</span> >
              <a href="{$context/_root}doc/profiles"> About</a>
            </div>
            {rules:profiles-as-html()}
         </div>
      else if ($sig= ("profile/*", "corpus/*/activity/*/profile/*"))
      then 
           <div>
             <div class="nav">
              <a href="">Home</a> >
              <a href="{$context/_root}profile">Profiles</a> >
              <span>{$context/profile/string()}</span>              
            </div>
            {rules:profile-as-html($context/profile)}
         </div>

(:  codelists :)
     else if ($sig="codelist")
     then 
         <div>
             <div class="nav">
                {url:path-menu($context/_fullpath,(),$config:map)}
               <a href="{$context/_root}codelist.xml">xml</a> |
              <a href="{$context/_root}codelist.csv">csv</a> |
              <a href="{$context/_root}doc/codelist"> About</a> 
                {if ($context/isadmin) then (" | ", <a href="{$context/_root}codelist-cache" title="Cache the current versions of the code lists">Cache</a> ) else ()}
           </div>
            {codes:code-index-as-html()}
        </div>
     else if ($context/isadmin and $sig="codelist-cache")
     then 
         <div>
             <div class="nav">
                {url:path-menu(concat($context/_root,"codelist/cache"),(),$config:map)} 
            </div>
            {codes:cache-codes()}
        </div>
     else if ($sig="codelist/*/metadata")
     then 
           <div>
             <div class="nav"> 
              {url:path-menu($context/_fullpath,(),$config:map)}
              <a href="{$context/_root}codelist/{$context/codelist}/metadata.xml">xml</a> |
              <a href="{$context/_root}codelist/{$context/codelist}/rules">Rules</a>
           </div>
             {codes:code-list-metadata-as-html($context/codelist)}
           </div>
     else if ($sig="codelist/*/rules")
     then 
           <div>
             <div class="nav"> 
              {url:path-menu($context/_fullpath,(),$config:map)}
              <a href="{$context/_root}codelist/{$context/codelist}/rules.xml">xml</a> 
             </div>
             {rules:codelist-rules-as-html($context/codelist)}
           </div>
     else if ($sig="codelist/*")
     then 
           <div>
             <div class="nav">
              {url:path-menu($context/_fullpath,('metadata'),$config:map)}
             |
              <a href="{$context/_root}codelist/{$context/codelist}.xml">xml</a> |
              <a href="{$context/_root}codelist/{$context/codelist}.csv">csv</a>
             </div>
             {codes:code-list-as-html($context/codelist,(),())}
           </div>
     else if ($sig="codelist/*/version/*/lang/*")
     then 
           <div>
             <div class="nav">
              <a href="{$context/_root}">Home</a> >
              <a href="{$context/_root}codelist">Codelists</a> >
              <span>{$context/codelist/string()}</span> |
              <a href="{$context/_root}codelist/{$context/codelist}/metadata">Metadata</a> |
              <a href="{$context/_root}codelist/{$context/codelist}/version/{$context/version}/lang/{$context/lang}.xml">xml</a>
             </div>
             {codes:code-list-as-html($context/codelist,$context/version,$context/lang)}
           </div>
           
 (:  rulesets  :)         
     else if ($sig="ruleset")
     then <div>
            <div class="nav">
              {url:path-menu($context/_fullpath,(),$config:map)}
              <a href="{$context/_root}doc/rulesets"> About</a>
            </div>
              {rules:rulesets-as-html()}
          </div>
     else if ($sig="ruleset/*")
     then <div>
            <div class="nav">
             {url:path-menu($context/_fullpath,(),$config:map)}
              <a href="{$context/_root}ruleset/{$context/ruleset}.xml">xml</a> |
              <a href="{$context/_root}ruleset/{$context/ruleset}.csv">csv</a>
            </div>
              {rules:ruleset-as-html($context/ruleset)}
            </div>
     else if ($sig="rule/*")
     then 
          let $rule := $rules:rulesets/rule[@id=$context/rule]
          let $ruleset := tokenize($context/rule,":")[1]
          return 
           <div>
            <div class="nav">
              <a href="{$context/_root}">Home</a> >
              <a href="{$context/_root}ruleset">Rulesets</a> >
              <a href="{$context/_root}ruleset/{$ruleset}">{$ruleset}</a> >
              <span>{$context/rule/string()}</span>
            </div>
               {rules:rule-as-html($rule)}
          </div>
          
(: pipelines :)
      else if ($sig="pipeline")
      then <div>
            <div class="nav">
              <a href="{$context/_root}">Home</a> >
              <span>Pipelines</span> |
              <a href="{$context/_root}doc/pipelines"> About</a>
            </div>
              {pipeline:pipelines-as-html()}
          </div>
     else if ($sig="pipeline/*")
     then <div>
            <div class="nav">
              <a href="{$context/_root}">Home</a> >
              <a href="{$context/_root}pipeline">Pipelines</a> >
              <span>{$context/pipeline}</span> |
              <a href="{$context/_root}pipeline/{$context/pipeline}.xml">xml</a>
            </div>
              {pipeline:pipeline-as-html($context/pipeline)}
            </div>
(: documentation :)
     else if ($sig="doc")
     then 
          <div>
             <div class="nav">
               <a href="{$context/_root}">Home</a> >
               <span>Documentation</span>

             </div>
             <div>
               {for $doc in collection (concat($config:base,"docs"))/div
                return 
                <li><a href="{$context/_root}doc/{$doc/@id}">{$doc/h1/string()}</a> </li>
               }
             </div>
           </div>
     else if ($sig="doc/*")
     then 
          let $doc := collection (concat($config:base,"docs"))/div[@id=$context/doc]
          return
            <div>
             <div class="nav">
               <a href="{$context/_root}">Home</a> >
               <a href="{$context/_root}doc">Documents</a> >
               <span>{$doc/h1/string()}</span>

             </div>
             <div>
               {$doc}
             </div>
           </div>
              
      else  
        <div>
        {$sig} not recognised
        </div>
};

declare function ui:xml($context) {
let $sig := $context/_signature
return 

          if ($sig="ruleset/*")  then  rules:ruleset(($context/ruleset)) 
     else if ($sig="pipeline/*") then pipeline:pipeline($context/pipeline)
     else if ($sig="corpus/*/activity/*")  then  activity:activity($context/corpus,$context/activity)
     else if ($sig="codelist") then $codes:metadata
     else if ($sig="codelist/*") then codes:codelist($context/codelist)
     else if ($sig="codelist/*/metadata")  then codes:code-metadata($context/codelist)
     else if ($sig="codelist/*/rules")  then <result codelist="{$context/codelist}">{rules:codelist-rules($context/codelist)}</result>
     else if ($sig="codelist/*/version/*/lang/*")  then codes:codelist($context/codelist,$context/version,$context/lang)
     else if ($sig="corpus/*/activity/*") then collection(concat("/db/apps/iati{$context/_root}",$context/corpus,"/activities"))/iati-activity[iati-identifier=$context/activity]     
     else if ($sig="corpus/*/activity/*/profile/*/errors")  
     then let $activity :=activity:activity($context/corpus,$context/activity)
          let $rules := rules:profile-rules($context/profile)
          return
             <report activity="{$context/activity}" created="{current-dateTime()}">
                 {rules:validation-errors($activity,  $rules)}
             </report>
     else if ($sig="corpus/*/activity/*/profile/*/summary")
     then let $activity := activity:activity($context/corpus,$context/activity)        
          let $rules := rules:profile-rules($context/profile)
          let $errors := rules:validation-errors($activity,  $rules)
          return rules:error-summary($errors)
     else if ($sig="corpus/*/activity/*")  then activity:activity($context/corpus,$context/activity) 
     else ()
};

declare function ui:csv($context) {
     let $sig := $context/_signature
     let $xml := ui:xml($context)
     return
       if ($sig="ruleset/*") then rules:ruleset-as-csv($context/ruleset)
       else  if ($sig="codelist/*") then  wfn:element-to-csv($xml)
       else  if ($sig="codelist/*/version/*/lang/*") then wfn:element-to-csv($xml)
       else  if ($sig="codelist") then  wfn:element-to-csv($xml)
       else ()
 };
 
 
declare function ui:rss($context) {
let $sig := $context/_signature
return 
            if ($sig="codelist") then codes:rss()
       else if ($sig="corpus/*/Country/*") then rss:country-feed($context)
       else if ($sig="corpus/*/SectorCategory/*") then rss:sectorCategory-feed($context)
       else ()
};

(:
   This module deals with loading and viewing activitySets and activities

:)
module namespace load = "http://tools.aidinfolabs.org/api/load";
import module namespace jxml = "http://kitwallace.me/jxml" at "/db/lib/jxml.xqm"; 
import module namespace date = "http://kitwallace.me/date" at "/db/lib/date.xqm";
import module namespace pipeline = "http://tools.aidinfolabs.org/api/pipeline" at "pipeline.xqm";
import module namespace config = "http://tools.aidinfolabs.org/api/config" at "config.xqm";
declare namespace iati-ad = "http://tools.aidinfolabs.org/api/AugmentedData";

declare variable $load:ckan-base := "http://www.iatiregistry.org/";

(:  ------  Activity package uploading ---------- :)
declare function load:ckan-activitySets($activitySets as element(activitySets))  {
      let $url := concat($load:ckan-base,"/api/search/package?filetype=activity&amp;limit=1000")
      let $list :=jxml:convert-url($url,<params><rough/></params>)
      for $package in $list//results/item 
      let $ckan-activitySet := load:ckan-activitySet($package)
      let $current-activitySet := $activitySets/activitySet[package=$package]
      return 
          if (empty($current-activitySet))
          then update insert $ckan-activitySet into $activitySets
          else if ($ckan-activitySet/metadata_modified > $current-activitySet/metadata_modified)  
               then 
                  let $activitySet := 
                         element activitySet {
                               $ckan-activitySet/node(),
                               $current-activitySet
                         }
                   return update replace $current-activitySet with $activitySet
               else ()  
};

declare function load:ckan-activitySet($package as xs:string)  as element(activitySet) {
       let $meta-url := concat($load:ckan-base,"/api/rest/package/",$package)
       let $metadata := jxml:convert-url($meta-url)/div
       let $url := $metadata/download_url
       return
         element activitySet {
            element package{$package},
            element host {substring-before(substring-after($url,"//"),"/")},
            $url,
            $metadata/metadata_modified,
            element cache-modified {util:system-dateTime()}
         }
};

(:  scan the current $activitySets document and for each check the download-modified against the last-modified-date in the download's http header.
    if the last-modified-date is later, download the document and process the activities
    
    need to add logging
    
:)
declare function load:download-activities($activitySets as element(activitySet)*, $query) {
   let $activity-collection := concat($config:data,$query/corpus,"/activities")
   let $log := doc(concat($config:data,$query/corpus,"/log.xml"))/log
   for $activitySet in $activitySets     
   let $response  := httpclient:head(xs:anyURI($activitySet/download_url),false(),())
   let $headers := $response/httpclient:headers
   let $http-modified := $headers/httpclient:header[@name="Last-Modified"]/@value
   let $http-modified := if (exists($http-modified))
                         then date:RFC-822-to-dateTime($http-modified)  (: convert to xs:date :)
                         else xs:dateTime("2000-01-01T00:00:00Z")
   let $download :=
       if ($query/mode="refresh" or empty($activitySet/download-modified) or (xs:dateTime($activitySet/download-modified) < $http-modified))
       then  load:download-activitySet($activitySet, $query)   
       else ()
   let $datetime := util:system-dateTime()
   let $update-timestamp :=
      if (exists($download)) 
      then 
          if (exists($activitySet/download-modified))
          then update replace $activitySet/download-modified with element download-modified {$datetime}
          else update insert element download-modified {$datetime} into $activitySet
       else ()
   let $update-source-modified :=
      if (exists($download)) 
      then 
          if (exists($activitySet/source-modified))
          then update replace $activitySet/source-modified with element source-modified {$http-modified}
          else update insert element source-modified {$http-modified} into $activitySet
       else ()
   let $logit :=
      if (exists($download)) 
      then update insert element record {  attribute url {$activitySet/download_url}, attribute dateTime {$datetime},attribute action {$query/mode}} into $log
      else update insert element record {  attribute url {$activitySet/download_url}, attribute dateTime {$datetime},attribute action {"none"}} into $log
   return 
      $download
};

(:  download the activities document and add or update the activity cache 
    transform activities through the passed pipeline

:)
declare function load:download-activitySet ($activitySet as element(activitySet), $query) {
    let $activity-collection := concat($config:data,$query/corpus,"/activities")
    let $pipeline := doc(concat($config:system,$query/pipeline,".xml"))/pipeline
    let $url := $activitySet/download_url
    let $response  := httpclient:get(xs:anyURI($url),false(),())
    let $activities := $response/httpclient:body/iati-activities 
    return 
      if (empty($activities))
      then ()
      else 
       let $download := 
         for $activity in $activities/iati-activity
         let $current-activity := collection($activity-collection)/iati-activity[iati-identifier=$activity/iati-identifier][@iati-ad:live]
         return 
            if ($query/mode = "refresh" or empty($current-activity) or (xs:dateTime($activity/@iati-ad:date-last-modified) > xs:dateTime($current-activity/@activity-modified)))
            then  (: transform and then store :)
                let $transformed-activity := 
                   if (exists($pipeline))
                   then pipeline:run-steps($pipeline, $activity)
                   else $activity
               let $delete-old := 
                    for $activity in $current-activity
                    return update delete activity/@iati-ad:live
               let $store := load:store-activity($activitySet,$query/corpus,$transformed-activity)
               return $store
            else  ()(: there appears to be no change here - could do a hash to find out however :)          
        return $url
};

(:  store an activity 
  
:)
declare function load:store-activity($activitySet as element(activitySet), $corpus as xs:string, $activity as element(iati-activity)) {
    let $activity-collection := concat($config:data,$corpus,"/activities")
    let $id := normalize-space($activity/iati-identifier)
    let $filename := concat(util:uuid(),".xml")
    let $store := xmldb:store($activity-collection,$filename,$activity)
    let $stored-activity := doc(concat($activity-collection,"/",$filename))/iati-activity
    let $update := update insert attribute iati-ad:activitySet {$activitySet/download_url} into $stored-activity
    let $update := update insert attribute iati-ad:activity-modified {util:system-dateTime()} into $stored-activity
    let $update := update insert attribute iati-ad:live {'live'} into $stored-activity
    return
        $id
};

declare function load:remove-activities ($activitySet as element(activitySet),$corpus as xs:string) {
      let $activity-collection := concat($config:data,$corpus,"/activities")   
(:      let $dump := concat($config:base,"dump")  ):) 
      let $log := doc(concat($config:data,$corpus,"/log.xml"))/log
      let $datetime := util:system-dateTime()     
      let $delete-stamp := update delete $activitySet/download-modified 
      let $id := $activitySet/download_url
      let $activities := collection($activity-collection)/iati-activity[@iati-ad:activitySet=$id][@iati-ad:live]
       let $deletions :=
         for $activity in $activities
(:         let $file := util:document-name($activity)
         let $delete  := xmldb:move($activity-collection, $dump, $file)
  or      let $delete  := xmldb:remove($activity-collection, $file) - 
 :)  
         let $update := update delete $activity/@iati-ad:live
         return $activity/iati-identifier
      return 
         if (exists($deletions))
         then update insert element record {  attribute url {$activitySet/download_url}, attribute dateTime {$datetime},attribute action {"deleted"}} into $log
         else update insert element record {  attribute url {$activitySet/download_url}, attribute dateTime {$datetime},attribute action {"nothing to delete"}} into $log
};

declare function load:list-activitySets($activitySets as element(activitySet)* ,$corpus as xs:string) as element(div) {
let $activity-collection := concat($config:data,$corpus,"/activities")
return
<div>
      <table border="1" class="sortable">
        <tr>
           <th>source</th>
           <th>CKAN package</th>
           <th>download</th>
           <th>view</th>
           <th>delete</th>           
           <th># live</th>
           <th># included</th>
        </tr>
        {for $activitySet in $activitySets
         let $source := $activitySet/download_url/string()
         let $esource := encode-for-uri($source)
         return 
            <tr>
              <td><a class="external" href="{$source}">{$source}</a></td>
              <th><a class="external" href="{ concat($load:ckan-base,"dataset/",$activitySet/package)}">{$activitySet/package/string()}</a></th>
              <td
              title='{concat(
                  "metadata:",$activitySet/metadata_modified,
                  " ,local-metadata:",$activitySet/cache-modified,
                  " ,source:",$activitySet/source-modified,
                  " ,activities:",$activitySet/download-modified)}
                  '>
                  {if ($activitySet/metadata_modified > $activitySet/download-modified  or $activitySet/source-modified >$activitySet/download-modified)
                  then attribute class {"warn"}
                  else ()
                  }
                 { if (exists($activitySet/download-modified))
                   then <a href="?corpus={$corpus}&amp;mode=refresh&amp;type=activitySet&amp;src={$esource}">Refresh</a>
                   else <a href="?corpus={$corpus}&amp;mode=download&amp;type=activitySet&amp;src={$esource}">Download</a>
                 }
              </td>
              <td>
                 {if (exists($activitySet/download-modified))
                 then <a href="?corpus={$corpus}&amp;mode=view&amp;type=activitySet&amp;src={$esource}">Browse</a>
                 else ()
                 }
              </td>
              <td>
                 {if (exists($activitySet/download-modified))
                 then <a href="?corpus={$corpus}&amp;mode=delete&amp;type=activitySet&amp;src={$esource}">Delete</a>
                 else ()
                 }
              </td>
              <td>{count(collection($activity-collection)/iati-activity[@iati-ad:activitySet=$source][@iati-ad:live])}</td>
              <td>{count(collection($activity-collection)/iati-activity[@iati-ad:activitySet=$source][@iati-ad:live][@iati-ad:include])}</td>
            </tr>
        }
       </table>
</div>
};

declare function load:short-list-activitySets($activitySets as element(activitySet)* ,$corpus as xs:string) as element(div) {
let $activity-collection := concat($config:data,$corpus,"/activities")
return
<div>
      <table border="1" class="sortable">
        <tr>
           <th>source</th>
           <th>CKAN package</th>
           <th>view</th>
           <th># activities</th>
           <th># included activities</th>
        </tr>
        {for $activitySet in $activitySets
         let $source := $activitySet/download_url/string()
         let $esource := encode-for-uri($source)
         return 
            <tr>
              <td><a class="external" href="{$source}">{$source}</a></td>
              <th><a class="external" href="{ concat($load:ckan-base,"dataset/",$activitySet/package)}">{$activitySet/package/string()}</a></th>
              <td>
                 {if (exists($activitySet/download-modified))
                 then <a href="?corpus={$corpus}&amp;mode=view&amp;type=activitySet&amp;src={$esource}">Browse</a>
                 else ()
                 }
              </td>
              <td>{count(collection($activity-collection)/iati-activity[@iati-ad:activitySet=$source][@iati-ad:live])}</td>
              <td>{count(collection($activity-collection)/iati-activity[@iati-ad:activitySet=$source][@iati-ad:live][@iati-ad:include])}</td>
            </tr>
        }
       </table>
</div>
};

declare function load:list-activities ($activities as element(iati-activity)*,$corpus as xs:string) as element(div){
<div>
<table border="1" class="sortable">
        <tr><th>iati-identifier</th><th>title</th></tr>
        {for $activity in $activities
         let $id := $activity/iati-identifier/string()
         let $title := ($activity/title)[1]/string()
         return 
           <tr>
            <td><a href="?corpus={$corpus}&amp;mode=view&amp;type=activity&amp;id={$id}">{$id}</a></td>
            <td>{$title}</td>
           </tr>
        }
 </table>
 </div>
};

declare function load:download-url($source as xs:string, $activitySets as element(activitySets) ,$query) {
let $activity-collection := concat($config:data,$query/corpus,"/activities")
let $activitySet := $activitySets/activitySet[download_url = $source]
let $new-activitySet := 
  <activitySet>
        <download_url>{$source}</download_url>
        <host>{if ($query/host) then $query/host/string() else substring-before(substring-after($source,"//"),"/")}</host>
        <cache-modified>{current-dateTime()}</cache-modified>
  </activitySet>
let $activitySetUpdate := 
       if  (exists($activitySet))
       then update replace $activitySet with $new-activitySet
       else update insert $new-activitySet into $activitySets

let $the-activitySet := $activitySets/activitySet[download_url = $source]

let $download := load:download-activities($the-activitySet,$query)
return $source
};


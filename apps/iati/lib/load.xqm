(:
   This module deals with loading  activitySets and activities
 :)
 
module namespace load = "http://tools.aidinfolabs.org/api/load"; 
import module namespace jxml = "http://kitwallace.me/jxml" at "/db/lib/jxml.xqm"; 
import module namespace date = "http://kitwallace.me/date" at "/db/lib/date.xqm";
import module namespace config = "http://tools.aidinfolabs.org/api/config" at "../lib/config.xqm";
import module namespace activity = "http://tools.aidinfolabs.org/api/activity" at "../lib/activity.xqm";
import module namespace activity-transform = "http://tools.aidinfolabs.org/api/activity-transform" at "../lib/pipeline1.xqm"; (:should be dynamically loaded :) 
import module namespace pipeline = "http://tools.aidinfolabs.org/api/pipeline" at "../lib/pipeline.xqm"; 
declare namespace iati-ad = "http://tools.aidinfolabs.org/api/AugmentedData";


(:  ------  Activity package uploading ---------- :)

declare function load:ckan-activitySets($context)  {
      let $allpackages := activity:ckan-packages($context)
      let $selectedPackages :=
          if ($context/ckansubset)  then subsequence($allpackages,$context/start,$context/pagesize)
          else if ($context/ckanall) then  $allpackages
          else ()
      for $package in  $selectedPackages
      let $current-activitySet := activity:activitySet($context/corpus,$package)
      return 
          if (empty($current-activitySet))
          then      
              let $ckan-activitySet := load:ckan-activitySet($package)
              return update insert $ckan-activitySet into activity:activitySet-doc($context/corpus)
          else 
          if (exists($current-activitySet) and $current-activitySet/error)
          then      
              let $ckan-activitySet := load:ckan-activitySet($package)
              return update replace $current-activitySet with $ckan-activitySet 
          else 
          if (true()) then ()    (: just to get past this loading problem :) 
          else 
               let $ckan-activitySet := load:ckan-activitySet($package)
               return
                  if ($ckan-activitySet/metadata_modified > $current-activitySet/metadata_modified)  
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
       let $meta-url := concat($config:ckan-base,"/api/rest/package/",$package)
       let $metadata := util:catch("*",jxml:convert-url($meta-url)/div,<error>extract failed</error>)
       return 
       if ($metadata/download_url)
       then 
       let $url := $metadata/download_url
       return
         element activitySet {
            element package{$package},
            element host {substring-before(substring-after($url,"//"),"/")},
            $url,
            $metadata/metadata_modified,
            element cache-modified {util:system-dateTime()}
         }
       else 
          element activitySet{
            element package {$package},
            $metadata
          }
};

declare function load:external-activitySet($context)  as element(activitySet) {
        let $current-activitySet := activity:activitySet-with-url($context)
        let $activitySet := 
          if (exists ($current-activitySet))
          then 
         element activitySet {
            $current-activitySet/package,
            element host {"external"},
            element download_url {$context/url/string()},
            element cache-modified {util:system-dateTime()}
         }

         else 
         element activitySet {
            element package{ util:uuid() },
            element host {"external"},
            element download_url {$context/url/string()},
            element cache-modified {util:system-dateTime()}
         }
        
       let $package := 
           if (exists ($current-activitySet))
           then 
              let $update:= update replace $current-activitySet with $activitySet
              return $current-activitySet/package
           else 
              let $update := update insert $activitySet into activity:activitySet-doc($context/corpus)
              return $activitySet/package
      let $set := activity:activitySet($context/corpus,$package)
      let $download := load:download-activities($set,$context)
      return activity:activitySet($context/corpus,$package)
     
};

(:  for each of the selected $activitySets  check the download-modified against the last-modified-date in the download's http header.
    if the last-modified-date is later, download the document and process the activities
    
    
:)
declare function load:download-activities($activitySets as element(activitySet)*, $context) {
   let $activity-collection := concat($config:data,$context/corpus,"/activities")
   let $log := doc(concat($config:data,$context/corpus,"/log.xml"))/log
   let $datetime := util:system-dateTime()

   for $activitySet in $activitySets     
   let $response  := 
    if ($activitySet/download_url)
    then util:catch("*", httpclient:head(xs:anyURI($activitySet/download_url),false(),()),())
    else ()
   return 
   if (empty($response))
   then 
      update insert element record { attribute set {$activitySet/package}, attribute url {$activitySet/download_url}, attribute dateTime {$datetime},attribute action {"url failed"}} into $log
   else 
   let $headers := $response/httpclient:headers
   let $http-modified := $headers/httpclient:header[@name="Last-Modified"]/@value
   let $http-modified := if (exists($http-modified))
                         then date:RFC-822-to-dateTime($http-modified)  (: convert to xs:date :)
                         else xs:dateTime("2000-01-01T00:00:00Z")
   let $download :=
       if ($context/mode="refresh" or empty($activitySet/download-modified) or (xs:dateTime($activitySet/download-modified) < $http-modified) and not($activitySet/ignore))
       then  load:download-activitySet($activitySet, $context)   
       else ()
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
      then update insert element record {  attribute url {$activitySet/download_url}, attribute dateTime {$datetime},attribute action {$context/mode}} into $log
      else update insert element record {  attribute url {$activitySet/download_url}, attribute dateTime {$datetime},attribute action {"none"}} into $log
   return 
      $download
};

(:  download the activities document and add or update the activity cache 
    transform activities through the default pipeline

:)
declare function load:download-activitySet ($activitySet as element(activitySet), $context) {
    let $activity-collection := concat($config:data,$context/corpus,"/activities")
    let $corpus-meta := activity:corpus-meta($context/corpus)
    let $url := $activitySet/download_url
    let $response  := httpclient:get(xs:anyURI($url),false(),())
    let $activities := $response/httpclient:body/iati-activities 
    return 
      if (empty($activities))
      then ()
      else 
       let $download := 
         for $activity in $activities/iati-activity

         let $current-activity := collection($activity-collection)/iati-activity[iati-identifier=$activity/iati-identifier]
         return 
            if ($context/mode = "refresh" or empty($current-activity) or (xs:dateTime($activity/@iati-ad:date-last-modified) > xs:dateTime($current-activity/@activity-modified)))
            then 
                (: transform and then store 
                   
                   let $pipeline := collection(concat($config:config,"pipelines"))/pipeline[@name = $corpus-meta/@pipeline]
                   let $transformed-activity := 
                   if (exists($pipeline))
                   then pipeline:run-steps($pipeline, $activity)
                   else $activity
               :)   
                           
               (:    running a compiled version of the pipeline in pipeline1.xml at present if a pipeline defined in the corpus :)
  
               let $transformed-activity := 
                   if ($corpus-meta/@pipeline)
                   then activity-transform:transform($activity) 
                   else $activity
   
               let $delete-old := 
                    for $activity in $current-activity
                    return
                      (:  update delete $activity[iati-ad:live]  :)
                       xmldb:remove($activity-collection,util:document-name($activity) )  (: ? revert to actual deletion here with 2.0 because its much faster :)
               let $store := load:store-activity($activitySet,$context/corpus,$transformed-activity)
               return $store
            else  ()(: there appears to be no change here - could do a hash to find out however :)          
        return $url
};

(:  store an activity 
  
:)
declare function load:store-activity($activitySet as element(activitySet), $corpus as xs:string, $activity as element(iati-activity)) {
    let $activity-collection := concat($config:data,$corpus,"/activities")
    let $id := normalize-space($activity/iati-identifier)
    let $filename := concat(util:uuid(),".xml")  (: iati-identifiers arnt valid file names in general and have versions :)
    let $activity := 
       element iati-activity {
           $activity/@*,
           attribute iati-ad:activitySet {$activitySet/package},
           attribute iati-ad:activity-modified {util:system-dateTime()} ,
           attribute iati-ad:live {'live'} ,
           $activity/*
        }
    let $store := xmldb:store($activity-collection,$filename,$activity)
    return
        $id
};

declare function load:remove-activities ($activitySets as element(activitySet)*,$context) {
(:      let $dump := concat($config:base,"dump")  ):) 
      let $log := doc(concat($config:data,$context/corpus,"/log.xml"))/log
      let $datetime := util:system-dateTime()  
      for $activitySet in $activitySets
      let $delete-stamp := update delete $activitySet/download-modified 
      let $id := $activitySet/package
      let $activities := collection(concat($config:data,$context/corpus,"/activities"))/iati-activity[@iati-ad:activitySet= $activitySet/package]
      let $deletions :=
         for $activity in $activities
         let $id := string($activity/iati-identifier)
         let $file := util:document-name($activity)
         let $delete  := xmldb:remove(concat($config:data,$context/corpus,"/activities"), $file)  
         return $id
      let $log := 
         if (exists($deletions))
         then update insert element record {  attribute url {$activitySet/download_url}, attribute dateTime {$datetime},attribute action {"deleted"}} into $log
         else update insert element record {  attribute url {$activitySet/download_url}, attribute dateTime {$datetime},attribute action {"nothing to delete"}} into $log
      return  $deletions
};

(:
declare function load:list-activitySets($activitySets as element(activitySet)* ,$corpus as xs:string) as element(div) {
let $activity-collection := concat($config:data,$corpus,"/activities")
return
<div>
      <table border="1" class="sortable">
        <tr>
           <th>source</th>
           <th>CKAN package</th>
           <th>download</th>
           <th>delete</th>           
           <th>view</th>
           <th># live</th>
           <th># included</th>
        </tr>
        {for $activitySet in $activitySets
         let $source := $activitySet/download_url/string()
         let $esource := encode-for-uri($source)
         return 
            <tr>
              <td><a class="external" href="{$source}">{$source}</a></td>
              <th><a class="external" href="{ concat($config:ckan-base,"dataset/",$activitySet/package)}">{$activitySet/package/string()}</a></th>
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
              <th><a class="external" href="{ concat($config:ckan-base,"dataset/",$activitySet/package)}">{$activitySet/package/string()}</a></th>
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

declare function load:download-url($source as xs:string, $activitySets as element(activitySets) ,$context) {
let $activity-collection := concat($config:data,$context/corpus,"/activities")
let $activitySet := $activitySets/activitySet[download_url = $source]
let $new-activitySet := 
  <activitySet>
        <download_url>{$source}</download_url>
        <host>{if ($context/Host) then $context/Host/string() else substring-before(substring-after($source,"//"),"/")}</host>
        <cache-modified>{current-dateTime()}</cache-modified>
  </activitySet>
let $activitySetUpdate := 
       if  (exists($activitySet))
       then update replace $activitySet with $new-activitySet
       else update insert $new-activitySet into $activitySets

let $the-activitySet := $activitySets/activitySet[download_url = $source]
let $download := load:download-activities($the-activitySet,$context)
return $source
};

:)
module namespace admin = "http://tools.aidinfolabs.org/api/admin";
import module namespace config = "http://tools.aidinfolabs.org/api/config" at "../lib/config.xqm";  

declare function admin:create-index-corpii() {
      for $corpus in doc(concat($config:config,"corpusindex.xml"))/corpusindex/corpus
      return admin:create-corpus($corpus)
};

declare function admin:create-corpus($corpus as element(corpus)) {
       let $name := $corpus/@name
       let $collection := xmldb:create-collection($config:data,$name)
       let $activities :=  xmldb:create-collection(concat($config:data,$name),"activities")
       let $log :=  xmldb:store(concat($config:data,$name),"log.xml",element log{})
       let $createactivitySets := xmldb:store(concat($config:data,$name),"activitySets.xml",element activitySets{}) 
       let $set-access :=
           if ($corpus/@hidden)
           then (: set world writeable on the data collection  :)
                ( 
                  xmldb:chmod-collection(concat($config:data,$name),util:base-to-integer(0777,8)),
                  xmldb:chmod-resource(concat($config:data,$name),"activitySets.xml",util:base-to-integer(0766,8)),
                  xmldb:chmod-resource(concat($config:data,$name),"log.xml",util:base-to-integer(0766,8)),
                  xmldb:chmod-collection(concat($config:data,$name,"/activities"),util:base-to-integer(0777,8))             
                )
           else ()
       
   (: indexes :)
 
       let $index := concat("/db/system/config",$config:data)
       let $indexcollection := xmldb:create-collection($index,$name)
       let $corpus-index := concat($index,$name)
       let $indexactivities :=  xmldb:create-collection($corpus-index,"activities")
       let $activitySetconfig := xmldb:store($corpus-index,"collection.xconf",doc(concat($config:system,"activitySet-collection.xconf")))
       let $activityconfig := xmldb:store(concat($corpus-index,"/activities"),"collection.xconf",doc(concat($config:system,"activity-collection-lucene.xconf")))
       
   (: olap :)  
       let $olap :=  xmldb:create-collection($config:olap,$name)
       let $index := concat("/db/system/config",$config:olap)
       let $olap :=  xmldb:create-collection($index,$name)
       let $olapconfig := xmldb:store($index,"collection.xconf",doc(concat($config:system,"olap-collection.xconf")))
       
   (: corpus index :)
       let $corpii := doc(concat($config:config,"corpusindex.xml"))/corpusindex    
       let $indexupdate := 
           if (empty($corpii/corpus[@name = $name]))
           then update insert $corpus into $corpii
           else ()
      return 
          $corpus
};


declare function admin:initialize() {

(: use the corpus index to create the data files :)

<result>
     {admin:create-index-corpii()}   (: create all corpii defined in the corpus-index :)

(: set world excecution on public scripts :)

     {xmldb:chmod-resource(concat($config:base,"xquery"),"data.xq",util:base-to-integer(0755,8))}
     
     {xmldb:chmod-resource(concat($config:base,"xquery"),"woapi.xq",util:base-to-integer(0755,8))}
    {xmldb:chmod-resource(concat($config:base,"xquery"),"ckan-job.xq",util:base-to-integer(0755,8))}
    {xmldb:chmod-resource(concat($config:base,"xquery"),"olap-job.xq",util:base-to-integer(0755,8))}
    {xmldb:chmod-resource(concat($config:base,"xquery"),"download-job.xq",util:base-to-integer(0755,8))}

     {xmldb:reindex($config:base)}
</result>
};
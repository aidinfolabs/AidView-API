module namespace pipeline = "http://tools.aidinfolabs.org/api/pipeline" ;
import module namespace config ="http://tools.aidinfolabs.org/api/config" at "../lib/config.xqm";

declare variable $pipeline:pipelines := collection(concat($config:config,"pipelines"))/pipeline;
declare variable $pipeline:errors := doc(concat($config:data ,"pipeline-errors.xml"))/errors;

declare function  pipeline:pipeline($name as xs:string) as element(pipeline)?{
  $pipeline:pipelines[@name=$name]
};

declare function pipeline:next-step($steps,$activity as element(iati-activity) ) as element (iati-activity)? {
   if (empty($steps)) then $activity 
   else
      let $step := $steps[1]
      let $new-activity := 
          if ($step/xslt)
          then 
               let $xslt := doc($step/xslt)
               return 
                   transform:transform($activity,$xslt,())
          else if ($step/xquery)
          then 
              let $xquery := $step/xquery
              let $module-load :=  if (exists($xquery/@location))
              then util:import-module($xquery/@uri, $xquery/@prefix, $xquery/@location)
              else ()  (: step is in the current library :)
              let $result := util:catch("*",
                              util:eval($xquery),
                              let $log := pipeline:log($activity,$step) return $activity
                             )
              return $result
           else 
               $activity
       return pipeline:next-step(subsequence($steps,2),$new-activity)

};


declare function pipeline:run-steps($pipeline as element(pipeline), $activity as element(iati-activity)) {
    pipeline:next-step($pipeline/step,$activity)
};


declare function pipeline:log ($activity,$step){

 update insert 
    element error {
       attribute dateTime {util:system-dateTime()},
       $step,
       $activity/iati-identifier      
    }   
    into $pipeline:errors
};

declare function pipeline:pipelines-as-html() as element(div) {
  <div>
   <table border="1">
     {for $pipeline in $pipeline:pipelines
      return
       <tr><th><a href="/data/pipeline/{$pipeline/@name}">{$pipeline/@name/string()}</a></th>
           <td>{$pipeline/description/node()}</td>
       </tr>
     }
   </table>
   </div>
};

declare function pipeline:pipeline-as-html($name as xs:string) as element(div) {
let $pipeline := pipeline:pipeline($name)
return
  <div>
  <h2>{$pipeline/@name/string()}</h2>
  <div>{$pipeline/description/node()}</div>
   <table border="1">
     {for $step at $i in $pipeline/step
      return
       <tr><th>{$i}</th>
           <td>{substring-before($step/xquery,"(")}</td>
           <td>{$step/description/node()}</td>
        </tr>
     }
   </table>
   </div>
};

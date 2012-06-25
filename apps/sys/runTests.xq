

(:  Run a suite of tests defined in a test script.

   Chris Wallace Dec 2006
    
   Feb 2007 
           -  format changed to introduce batches of tests
           -  XQuery formated with <pre> ..</pre>
           -  XML formated with the stylesheet based on one from Oliver Becker,  obecker@informatik.hu-berlin.de
           
   March 2007 
           - remove batch level - no value
           - test with basic value results must have output = 'text'
           - pre renamed to prolog
           - test for sequence handled with string-join
           
   June 2007 
          - add execution of url relative to a base 
          - add contains type test in adddition to default of deep-equals
          - run tests in full, then format results
          
    Feb 2009 
          - added to wiki 
          - still issue about exposing files with bare XQuery to execute  
          - restructured
          - added modules to preload -makes test time more comparable
          - use util:catch to run eval so compilation errors are caught
          - string compare under normalize-space - may need to be an option
          - failonly parameter to show only failing tests
          - author element added
          -output format settable at uri or  testset level
            
     April 2009 
          - added epilog 
          - caching busting on url - need to switch to httpclient 
          - added compare =no  for tests to be run only 
          
     February 2011
          - changed to load a file by name - should make sure that only local files can be loaded
          - problem with XML comparison - ok forgot about namespaces 
          - config structure added to simplify parameters
          
     Todo - 
          test options need tidying
          namespace and schema required for test script
          check for multiple contains phrases
          check for not contains
          define tolerance in numerical results
          xqdoc comment standard headings for the documentation on a method
          style the output from util:describe-function
          XML schema for the test script
       
                 
:)
import module namespace ui= "http://kitwallace.me/ui" at "/db/lib/ui.xqm";

declare namespace xsl="http://www.w3.org/1999/XSL/Transform";
declare variable  $xmlss := doc('/db/apps/sys/xmlverbatim.xsl');

declare option exist:serialize "method=xhtml media-type=text/html omit-xml-declaration=no indent=yes 
        doctype-public=-//W3C//DTD&#160;XHTML&#160;1.0&#160;Transitional//EN
        doctype-system=http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd'";


declare function local:get-config($testSet) {
  <config>
     {ui:get-parameter("base",$testSet/base)}
     {ui:get-parameter("pp","yes")}
     {ui:get-parameter("out","yes")}
     {ui:get-parameter("failonly","no")}
  </config>
};

(:     ------------------------------------------------run-test -------------------------------------------:)
declare function local:run-test($test as element(test), $tn as xs:integer, $config as element(config)) as element(testResult) {
let $url := 
       if (exists($test/url))
       then 
            if (starts-with($test/url,'http://'))
            then $test/url
            else concat($config/base,$test/../collection,'/',$test/url)
      else ()
let $moduleLoad := 
     for $module in  $test/../module
     return  util:import-module($module/@uri,$module/@prefix,$module/@location)
let $start := util:system-time()
let $output := 
    if ( not($test/@run='no'))
    then
        if (exists($test/code))
        then util:catch("*",util:eval(concat($test/../prolog,$test/code,$test/../epilog)),<error>Compile error</error>)
        else 
            if (exists($url))
            then doc($url)/*
           else ()
      else ()
let $end := util:system-time()
let $runtimems := (($end - $start) div xs:dayTimeDuration('PT1S')) * 1000
let $expected := 
    if ($test/@output='text') 
    then data($test/expected)
    else $test/expected/node()
 let $OK := 
 if ($test/@compare='no')
 then ()
 else if ($test/@type='contains')
 then contains(string-join($output,' '),$expected) 
 else if ($test/@type='eval')
 then util:eval($expected)
 else  if ($test/@output='text')  
       then normalize-space(string-join(for $x in $output return string($x),' ')) eq normalize-space($expected)       
       else deep-equal($output,$expected) 

return
  <testResult  tn='{$tn}'  pass='{$OK}'>
    <url>{$url}</url>
    <elapsed>{$runtimems}</elapsed>
    <output>{$output}</output>
  </testResult>
};

(: ----------------------------------------------run-test ----------------------------------------:)
declare function local:run-testSet( $testSet as element(TestSet), $config as element(config) ) as element(results){
<results>
  {
  for $test at $tn in $testSet/test
  return local:run-test($test, $tn, $config)
  }
</results>
};

(: ----------------------------------------------show-testSet ---------------------------------:)
declare function local:show-testSet($testSet as element(TestSet) , $results as element(results) , $config as element(config) ) as element(div)  {
let $n := count($testSet/test)
let $npassed := count($results/testResult[@pass='true']) 
let $nfail := count($results/testResult[@pass='false']) 
let $nother := count($results/testResult[@pass='']) 
return 
<div>
  <h1>Test Results for {$testSet/testName} </h1>
  <h2>eXist Version {system:get-version()} :  Revision {system:get-revision()} </h2>

   {if ($n = $npassed)
    then <h2 class='good'> {$n} Test{if($n > 1) then 's' else ()} passed </h2>
    else if ($nfail > 0)
    then <h2 class='bad'>{$npassed} Test{if($npassed > 1) then 's' else ()} passed, {$nfail} Failed,  {$nother} not checked</h2>
    else <h2 class='warn'>{$npassed} Test{if($npassed > 1) then 's' else ()} passed,  {$nother} not checked</h2>
   }
   <h3>Total elapsed time {sum($results/testResult/elapsed)} (ms)</h3>
   {$testSet/description/*}
   {if ($testSet/module)
   then 
   <div>
      <h3>Imported Modules</h3>
      <ul>
      {for $module in $testSet/module
      return <li>module {$module/@prefix/string()} ="{$module/@uri/string()}" at  "{$module/@location/string()}"</li>
      }
      </ul>
   </div>
   else ()
   }
   {if (exists($testSet/author)) then <p>Author: {$testSet/author}</p> else () }
   {if (exists($testSet/prolog)) 
    then 
     <div id='prolog'>
        <h3>Prolog</h3>
        <pre>{$testSet/prolog/string()}</pre>
     </div>
    else ()
   }
   {if (exists($testSet/epilog)) 
    then 
     <div id='epilog'>
        <h3>Epilog</h3>
        <pre>{$testSet/epilog/string()}</pre>
     </div>
    else ()
   }
   { for $result at $tn in $results/testResult
     let $test := $testSet/test[$tn]
     return local:show-test($test,$result,$config)
    }
</div>
};

(: ----------------------------------show-test ----------------------------------:)
declare function local:show-test($test as element(test), $result as element(testResult) , $config as element(config)) as element(div)? {
   let $tn := $result/@tn/string()
   let $id := $test/@id/string()
   let $output :=  
       if ($test/@output='text') 
       then string($result/output)
       else $result/output/node()
       
   let $expected :=  if ($test/@output='text') 
                     then data($test/expected)
                     else $test/expected/node() 
   return 
      if ($config/failonly="yes" and $result/@pass='true')
      then ()
      else
     <div>
      {if ($test/@run='no')
       then <h3 class="warn">Test {$tn}  &#160; {$id} Not run</h3>
       else 
          if ($result/@pass ='')
          then  <h3 class="warn">Test {$tn} &#160; {$id} Not checked</h3>
          else if ($result/@pass='true') 
          then <h3 class="good">Test {$tn} &#160; {$id} Passed</h3>
          else <h3 class="bad">Test {$tn}  &#160; {$id} Failed</h3>
      } 
       <table border="1">
         { if (exists($test/task)) 
           then <tr><th>Task</th><td>{$test/task/node()}</td></tr>
           else ()
         }
         <tr><th>XQuery</th>
             <td>{if ($test/code) 
                  then <pre>{$test/code/string()}</pre> 
                  else 
                  if ($result/url) 

                  then <div><a href="{$result/url}">{$result/url/string()}</a></div>
                  else () 
                 }</td>
         </tr>

{  if ($test/@type=('contains','eval'))
   then
      ( <tr>
         <th>Page Contains </th>
         <td>{ $expected}  </td>
      </tr>,
      if (not($result/@pass='true'))
      then 
         <tr>
           <th>Actual</th>
           <td>{if ($config/pp ='yes')
                  then
                         transform:transform(<doc>{$output}</doc>,$xmlss,())
                  else $output
               }
           </td>
        </tr>
      else ()
      )
   else (
        if ($config/out="yes")
        then <tr><th>Output</th>
             <td>{
             if ($test/@output="html")
                  then  $output
                  else if ($config/pp ='yes')
                  then  transform:transform(<doc>{$output}</doc>,$xmlss,())
                  
                  else <pre>{$output}</pre>
                 }
             </td> 
         </tr>
         else (),
         if (not($result/@pass='true') and $expected) 
          then <tr><th>Expected</th>
               <td>
                  {if ($config/pp ='yes')
                   then transform:transform(<doc>{$expected}</doc>,$xmlss,())
                   else <pre>{$expected}</pre>
                  }
               </td>
               </tr>
          else ()  
         
        )
}
         {if (exists($test/comment)) then <tr><th>Comment</th><td>{$test/comment/node()}</td></tr> else ()}
         <tr><th>Elapsed Time (ms)</th><td>{string($result/elapsed)}</td></tr>
       </table>
 </div>
 };
 
 (: -------------------------------------main -------------------------------------:)
let $testfile := request:get-parameter('testfile',())
let $error := if (not(starts-with($testfile,"/db"))) then error((),"access to external files not permitted",()) else ()
let $testSet := doc($testfile)/TestSet
let $config := local:get-config($testSet)
let $results := local:run-testSet($testSet,$config)
return

<html>
<head>
<title>Test run for {$testSet/TestName/string()}</title>
<link rel="stylesheet" type="text/css" href="test.css" />
<link rel="stylesheet" type="text/css" href="xmlverbatim.css" />
</head>
<body>
    { local:show-testSet($testSet,$results,$config) }  
    
</body>
</html>


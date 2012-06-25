module namespace sparql = "http://kitwallace.me/sparql";
declare namespace r = "http://www.w3.org/2005/sparql-results#";
declare variable $sparql:dbpedia := "http://dbpedia.org/sparql?format=xml&amp;default-graph-uri=http://dbpedia.org&amp;query=";

declare function  sparql:results-to-tuples($rdfxml ) as element(tuple)*  {
   for $result in $rdfxml//r:result
   return
     <tuple>
            { for $binding  in $result/r:binding
               return                
                 if ($binding/r:uri)
                     then   element {$binding/@name}  {
                                    attribute type  {"uri"} , 
                                    string($binding/r:uri) 
                                }
                     else   element {$binding/@name}  {
                                    attribute type {data($binding/r:literal/@datatype)}, 
                                    string($binding/r:literal)
                               }
             }
      </tuple>
 };

declare function sparql:execute-query($query as xs:string, $service as xs:string) {
  let $sparql := concat($service,"?query=",encode-for-uri($query) )
  return  doc($sparql)
};

declare function sparql:execute-query2($query as xs:string, $service as xs:string) {
  let $sparql := concat($service,encode-for-uri($query) )
  return  doc($sparql)
};

declare function sparql:query-to-tuples($query as xs:string, $service as xs:string) {
   sparql:results-to-tuples(sparql:execute-query($query,$service))
};


declare function sparql:dbpedia-tuples($query as xs:string) as element(tuple)* {
let $result := sparql:execute-query2($query,$sparql:dbpedia)
return sparql:results-to-tuples($result)
};


declare function sparql:uri-prefix($uri as xs:string, $namespace as element(namespace)?) as xs:string {
  if (exists($namespace))
  then 
      if (string-length($namespace/prefix)=0)
      then substring-after($uri,$namespace/base)
      else concat($namespace/prefix,":",substring-after($uri,$namespace/base))
  else $uri
};

declare function sparql:uri-namespace($uri as xs:string,$namespaces as element(namespace)* ) {
   if (empty($namespaces))
   then ()
   else if (starts-with($uri,$namespaces[1]/base))
   then $namespaces[1]
   else sparql:uri-namespace($uri,subsequence($namespaces,2))
};


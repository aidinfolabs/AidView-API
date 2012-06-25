module namespace tx = "http://www.kitwallace.me/tx";

declare variable $tx:dbpath := request:get-parameter("dbpath",());
declare variable $tx:base := "http://184.73.216.20/exist/art";
declare variable $tx:namespaces := doc(concat($tx:dbpath,"/data/namespaces.xml"))//namespace;
declare variable $tx:triples :=  collection(concat($tx:dbpath,"/data"))//triple;
declare variable $tx:label := "http://www.w3.org/2000/01/rdf-schema#label";
declare variable $tx:type:= "http://www.w3.org/1999/02/22-rdf-syntax-ns#type";
declare variable $tx:inverse:= "http://www.w3.org/1999/02/22-rdf-syntax-ns#type";

declare function tx:expand($term,$namespaces) {
  let $tp := tokenize($term,":")
  let $prefix := $tp[1]
  let $uri := $namespaces[@prefix=$prefix]/@uri
  return 
    if ($uri)
    then concat($uri,$tp[2])
    else $term
};
declare function tx:expand($term) {
  tx:expand($term,$tx:namespaces)
};

declare function tx:namespace($uri as xs:string ,$namespaces as element(namespace)* ) {
   if (empty($namespaces))
   then ()
   else if (starts-with($uri,$namespaces[1]/@uri))
   then $namespaces[1]
   else tx:namespace($uri,subsequence($namespaces,2))
};


declare function tx:contract ($uri,$namespaces) {
  let $namespace := tx:namespace($uri,$namespaces)
  return 
     if (exists($namespace))
     then concat($namespace/@prefix,":",substring-after($uri,$namespace/@uri))
     else $uri
};

declare function tx:contract ($uri) {
  tx:contract($uri, $tx:namespaces)
};
declare function tx:inverse($predicate, $triples) {
  $triples[predicate=$tx:inverse][subject=$predicate]/object
};

declare function tx:label($resource) {
  let $label := ($tx:triples[subject=$resource][predicate=$tx:label]/object)[1]
  return 
    if (exists($label))
    then $label/string()
    else tx:contract($resource)
};

declare function tx:type($resource) {
  $tx:triples[subject=$resource][predicate=$tx:type]/object
};

declare function tx:link($resource) {
   if ($resource/@xml:lang)
   then $resource/string()
   else if (starts-with($resource,$tx:base))
   then 
      <a href="{$resource}">{tx:label($resource)}</a>
   else 
      <a class="external" href="{$resource}">{$resource}</a>
};

declare function tx:closure($subject, $predicate, $triples) {
  let $inverse := tx:inverse($predicate,$store)
  let $objects := 
     ($triples[subject=$subject][predicate=$predicate]/object,
      $triples[object=$subject][predicate=$inverse]/subject
     )
(:  let $e := error((),"x",$objects) :)
  return 
    if (exists($objects))
    then 
       ($objects,tx:closure($objects,$predicate,$store))      
    else ()
};

declare function tx:match($triples,$subject,$predicate,$object) {
  let $command := concat(
        "$triples",
        if (exists($subject)) then "[subject=$subject]" else (),
        if (exists($predicate)) then "[predicate=$predicate]" else (),
        if (exists($object)) then "[object=$object]" else ()
       ) 
  return util:eval($command)
};

declare function tx:subject-triples($subject, $triples) {
 $triples[subject=$subject] 
};

declare function tx:predicate-triples($predicate, $triples) {
 $triples[predicate=$predicate] 
};
 
declare function tx:object-triples($object, $triples) {
 $triples[object=$object] 
};
 
declare function tx:resource-triples($resource,$triples) {
  (tx:subject-triples($resource,$triples), tx:object-triples($resource,$triples))
};
  
declare function tx:search-triples($regexp,$triples) {
  $triples[matches(object,$regexp,"i")]
};

declare function tx:triple ($subject,$predicate,$object) as element(triple) {
  <triple>
    <subject>{tx:expand($subject)}</subject>
    <predicate>{tx:expand($predicate)}</predicate>
    <object>
      {let $object := tx:expand($object)
       return 
         if (starts-with ($object,"http"))
         then $object
         else (attribute xml:lang {"en"}, $object)
      }
    </object>
 </triple>
};



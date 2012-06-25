module namespace tables= "http://kitwallace.me/tables";
import module namespace str= "http://kitwallace.me/string" at   "/db/lib/string.xqm";

declare function tables:sequence-to-table($seq) {

(: assumes all items in $seq have the same simple element structure determined by the structure of the first item :)
  <table border="1">
     <tr>
        {for $node in $seq[1]/*
         return <th>{str:camel-case-to-words(name($node))}</th> 
        }
     </tr>
      {for $row in $seq
       return
         <tr>
            {for $node in $seq[1]/*
             let $data := data($row/*[name(.)=name($node)])
             return <td>{$data}</td> 
           } 
         </tr>
      }
   </table>
 };
 
 declare function tables:sequence-to-table2($seq) {

(: assumes all items in $seq have the same simple element structure determined by the structure of the first item :)
  <table border="1">
     <tr>
        {for $node in $seq[1]/*
         return <th>{str:camel-case-to-words(name($node))}</th> 
        }
     </tr>
      {for $row in $seq
       return
         <tr>
            {for $node in $seq[1]/(@*,*)
             let $data := data($row/*[name(.)=name($node)])
             return <td>{$data}</td> 
           } 
         </tr>
      }
   </table>
 };
 
  declare function tables:element-to-csv($element) as xs:string {

(: returns a  multi-line string of comma delimited strings  :)
let $sep := ","
return
string-join(
  (string-join($element/*[1]/*/name(.),$sep),
   for $row in $element/*
       return
         string-join(
          for $node in $element/*[1]/*
          let $data := string($row/*[name(.)=name($node)])
          return
               if (contains($data,$sep))
               then concat('"',$data,'"')
               else $data
           , $sep)
   ),$str:nl )
};

 declare function tables:element-to-SQL-create($element) {
  ("create table ", name($element), $tables:nl,
    
      string-join(
         for $node in $element/*[1]/*
          return 
              concat ("     ",name($node) , " varchar(20)" ),
              concat(',',$str:nl)
          ),
          ";",$str:nl 
     )
 };
 
declare function tables:element-to-SQL-insert ($element) {
(: assumes all children in $element have the same simple element structure determined by the structure of the first item :)
  for  $row in $element/*
       return
        concat (
          " insert into table ",
          name($element), 
 (:
 "(", 
          string-join(
                    for $node in $row/* 
                    return name($node),
                    ','    
                    ) ,
          ") ",
          $str:nl,
  :)
          " values (",
          string-join( 
                  for $node in $element/*[1]/* 
                  return  concat('"',data($row/*[name(.)=name($node)]),'"'),
                  ","
                  ),
          ");",$str:nl
         )
};

declare function tables:element-to-table($element) {

(: assumes all children in $element have the same simple element structure determined by the structure of the first item :)
  <table border="1">
     <tr>
        {for $node in $element/*[1]/*
         return <th>{str:camel-case-to-words(name($node))}</th> 
        }
     </tr>
      {for $row in $element/*
       return
         <tr>
            {for $node in $element/*[1]/*
             let $data := data($row/*[name(.)=name($node)])
             return <td>{$data}</td> 
           } 
         </tr>
      }
   </table>
 };

declare function tables:element-seq-to-table($element) {

(: assumes all children in $element have the same simple element structure determined by the structure of the first item :)
  <table>
     <tr>
        {for $node in $element/*[1]/*
         return <th>{str:camel-case-to-words(name($node))}</th> 
        }
     </tr>
      {for $row in $element/*
       return
         <tr>
            {for $node in $element/*[1]/*
             let $data := data($row/*[name(.)=name($node)])
             return <td>{$data}</td> 
           } 
         </tr>
      }
   </table>
 };


declare function tables:sequence-to-table($seq,$sort) {
 <table border="1">
     <tr>
         {for $node in $seq[1]/*
         return <th><input type="submit" name="Sort" value="{name($node)}"/></th> 
        }   
      </tr>
      {for $row in $seq
        let $sortBy := data($row/*[name(.) = $sort])
        order by $sortBy
        return
         <tr>
            {for $node in $seq[1]/*
             let $data := data($row/*[name(.)=name($node)])
             return <td>{$data}</td> 
           } 
         </tr>
      }
   </table>
 };
 
 declare function tables:sequence-to-table($seq,$sort,$direction) {
 <table border="1">
     <tr>
         {for $node in $seq[1]/*
         return <th><input type="submit" name="Sort" value="{name($node)}"/></th> 
        }   
      </tr>
      { if ($direction = 1) 
       then 
        for $row in $seq
        let $sortBy := data($row/*[name(.) = $sort])
        order by $sortBy ascending
        return
         <tr>
            {for $node in $seq[1]/*
             let $data := data($row/*[name(.)=name($node)])
             return <td>{$data}</td> 
           } 
         </tr>
      else 
         for $row in $seq
        let $sortBy := data($row/*[name(.) = $sort])
        order by $sortBy descending
        return
         <tr>
            {for $node in $seq[1]/*
             let $data := data($row/*[name(.)=name($node)])
             return <td>{$data}</td> 
           } 
         </tr>    
      }
   </table>
 };
 
 declare function tables:sequence-to-table-with-schema($seq,$schema) {
  <table class="sortable">
     <tr>
        {for $column in $schema/Column
         return <th align="right">{string( ($column/@heading,$column/@name)[1])}</th> 
        }
     </tr>
      {for $row in $seq
       return
         <tr>
            {for $column in $schema/Column
             let $data := data($row/*[name(.)=$column/@name])
             return 
                <td>
                   {if ($column/@type=("integer","decimal"))
                    then attribute align {"right"}
                    else ()
                   }
                   {$data}
                </td> 
           } 
         </tr>
      }
   </table>
 };
 
declare function tables:element-to-nested-table($element) {
    if (exists ($element/(@*|*)))
    then 
     <table>
        {if (exists($element/text()))
         then <tr  class="text">
                    <th ></th>
                    <td >{$element/text()}</td>
              </tr>
         else ()
       }
       {for $attribute in $element/@*
       return
         <tr  class="attribute">
              <th>@{name($attribute)}</th>
              <td>{string($attribute)}</td>
         </tr>
       }
       {for $node in $element/*
       return 
            <tr class="element">
                 <th>{name($node)}</th> 
                 <td>
                    { tables:element-to-nested-table($node)    }
                 </td>
             </tr>       
        }
    </table>
    else   $element/text() 
};
 
declare function tables:element-as-table($el, $level) {
  <table class="level{$level}">
    {for $c in $el/*
    let $cs := normalize-space($c)
    let $attr := string-join($c/@*,", ")
    return
      <tr>
          <th>
              {name($c)} </th>
          <td>{ if (exists($c/*))
                    then tables:element-as-table($c,$level + 1)
                    else if (starts-with($cs,"http://"))
                     then <a href="{$cs}">{$cs}</a>
                    else ( $c, $cs,concat(" (",$attr,")"))
                  }
         </td> 
       </tr>
    }
  </table>
};

 declare function tables:path-to-node-with-pos  ( $node as node()? )  as xs:string {
       
string-join(
  for $ancestor in $node/ancestor-or-self::*
  let $sibsOfSameName := $ancestor/../*[name() = name($ancestor)]
  return concat(name($ancestor),
   if (count($sibsOfSameName) <= 1  or  not($ancestor/node()))
   then ''
   else 
   let $i := index-of($sibsOfSameName,$ancestor)
   return concat(
      '[',$i,']'))
 , '/')
 } ;
 
declare function tables:sequence-to-sortable-table($seq) {

(: assumes all children in $element have the same simple element structure determined by the structure of the first item 

  requires Stuart Langridge's sorttable.js
  http://www.kryogenix.org/code/browser/sorttable/sorttable.js
  
:)
  <table  class="sortable" border="1">
     <tr>
        {for $node in $seq[1]/*
         return <th>{for $part in tokenize(name($node),"-") return ($part,<br />)}</th> 
        }
     </tr>
      {for $row in $seq
       return
         <tr>
            {for $node in $seq[1]/*
             let $data := data($row/*[name(.)=name($node)])
             return <td>{$data}</td> 
           } 
         </tr>
      }
   </table>
 };

declare function tables:element-seq-to-sortable-table($element) {

(: assumes all children in $element have the same simple element structure determined by the structure of the first item 

  requires Stuart Langridge's sorttable.js
  http://www.kryogenix.org/code/browser/sorttable/sorttable.js
  
:)
  <table  class="sortable" border="1">
     <tr>
        {for $node in $element/*[1]/*
         return <th>{for $part in tokenize(name($node),"-") return ($part,<br />)}</th> 
        }
     </tr>
      {for $row in $element/*
       return
         <tr>
            {for $node in $element/*[1]/*
             let $data := data($row/*[name(.)=name($node)])
             return <td>{$data}</td> 
           } 
         </tr>
      }
   </table>
 };

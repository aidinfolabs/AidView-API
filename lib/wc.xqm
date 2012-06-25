module namespace wc = "http://kitwallace.me/wc";

declare variable $wc:noise := tokenize(
"the and a to of in i is that it on you this for but with are have be at 
 or as was so if out not my by may should here only she from your than did 
 under same what own its which before am these upon her there were could when
 after an me all they will had into nor mr sir those can shall who his them 
 any been their would has our we then must some other such where while between 
 cannot because up while without whether another might within us just he very 
 off back made over no make",
 "\s+");
 
 declare function wc:analyse-words($text) {
 let $words := 
      tokenize(lower-case(string-join($text," ")),'\W+') 
 let $words := $words[not(. = $wc:noise)]    
 let $dwords := distinct-values($words)
 let $wordCounts :=
     for $word in $dwords
     let $count := count($words[. = $word]) 
     order by $count
     return
         <word count="{$count}">{$word}</word>
 
return
   <result>
    {$wordCounts}
   </result>
};
 
 declare function wc:analyse-words($text,$terms) {
 let $words := 
      tokenize(lower-case(string-join($text," ")),'\W+') 
 let $words := $words[. = $terms]    
 let $dwords := distinct-values($words)
 let $wordCounts :=
     for $word in $dwords
     let $count := count($words[. = $word]) 
     order by $count
     return
         <word count="{$count}">{$word}</word>
 
return
   <result>
    {$wordCounts}
   </result>
};

declare function wc:analyse-phrases($text,$terms,$n) {
 let $words := 
      tokenize(lower-case(string-join($text," ")),'\W+')
      
 let $phrases := 
      for $i in ($n to count($words))
      let $seq := subsequence($words,$i - $n + 1 , $n)
      where $terms = $seq
      return string-join($seq," ")
      
 let $distinct-phrases := distinct-values($phrases)
 let $phraseCounts :=
     for $phrase in $distinct-phrases
     let $count := count($phrases[. = $phrase]) 
     order by $count
     return
         <phrase count="{$count}">{$phrase}</phrase>
 
return
   <result>
    {$phraseCounts}
   </result>
};
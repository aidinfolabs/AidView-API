(:
 : XSLT functions in XQuery

:)

module namespace xslf = "http://www.cems.uwe.ac.uk/xmlwiki/xslf";

declare function xslf:sequence-number($node) as xs:string {
     string(count($node/preceding-sibling::node()[name(.) = name($node)]) + 1)
};

declare function xslf:number($node?) as xs:string {
    if ($node) 
        concat(xslf:number($node/parent::node()),".",  xslf:sequence-number($node))
    else ()
};

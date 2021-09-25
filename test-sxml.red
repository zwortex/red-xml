Red [
	Title:          "Test set for SXML"
    File:           %test-sxml.red
	Description:    "Event oriented XML parser"
	Author:         @zwortex
    License:        {
        Distributed under the Boost Software License, Version 1.0.
        See https://github.com/red/red/blob/master/BSL-License.txt
    }
    Notes:          { ... }
    Version:        0.1.0
    Date:           23/09/2021
    Changelog:      {
        0.1.0 - 23/09/2021
            * initial version
    }
    Tabs:           4
]

#include %sxml.red

test-sxml: context [

    parse-debug!: context [
        ;;
        ;; Debug parse based on parse-trace for debugging 
        ;;
        p-indent: make string! 30

        ;; active trace? or not
        trace?: false

        ;; transient value used to track when to print input buffer
        input?: true

        ;; Adjusted on-parse-event to turn on/off tracing
        on-parse-event: func [
            "Standard parse/trace callback used by PARSE-TRACE"
            event	[word!]   "Trace events: push, pop, fetch, match, iterate, paren, end"
            match?	[logic!]  "Result of last matching operation"
            rule	[block!]  "Current rule at current position"
            input	[series!] "Input series at next position to match"
            stack	[block!]  "Internal parse rules stack"
            return: [logic!]  "TRUE: continue parsing, FALSE: stop and exit parsing"
        ][
            ;probe event
            ;; trace instructions in the input stream
            commented?: false
            if string? input [
                either i: find/match input ";" [
                    commented?: true
                ][
                    i: input
                ]
                if any [ event == 'push event == 'fetch ] [
                    if find/match i "**ON**" [
                        either commented? [
                            remove/part input 7
                        ][
                            trace?: true
                            remove/part input 6
                        ]
                    ]
                ]
                if any [ event == 'push event == 'end ] [
                    if find/match i "**OFF**" [
                        either commented? [
                            remove/part input 8
                        ][
                            trace?: false
                            remove/part input 7
                        ]
                    ]
                    if find/match i "**END**" [
                        either commented? [
                            remove/part input 8
                        ][
                            remove/part input 7
                            return false
                        ]
                    ]
                ]
            ]
            switch event [
                push  [
                    ;if trace? [ print [p-indent "-->"] ]
                    append p-indent "  "
                ]
                pop	  [
                    clear back back tail p-indent
                    ;if trace? [ print [p-indent "<--"] ]
                ]
                fetch [
                    if input? [
                        if trace? [ 
                            ; print [ p-indent mold/flat/part input 50 p-indent ]
                            print [ "==>" mold/flat/part input 50 p-indent ]
                        ]
                        input?: false
                    ]
                    if trace? [ print [ p-indent "=" mold/flat/part rule 50 ] ]
                ]
                match [
                    if trace? [ 
                        ;print [ p-indent "==>" pick ["MATCHED" "not MATCHED"]  match? "<==" ]
                        print [ "==>" pick ["MATCHED" "not MATCHED"]  match? "<==" ] 
                    ]
                    input?: true
                ]
                iterate [

                ]
                paren [

                ]
                end   [
                    if trace? [
                        print ["return:" match?]
                    ]
                ]
            ]
            true
        ]

        set 'parse-debug function [
            "Wrapper for parse/trace using the default event processor"
            input [series!]
            rules [block!]
            /case "Uses case-sensitive comparison"
            /part "Limit to a length or position"
            limit [integer!]
            return: [logic! block!]
        ][
            c: :case
            clear p-indent
            input?: true
            either c [
                parse/case/trace input rules :on-parse-event
            ][
                either part [
                    parse/part/trace input rules limit :on-parse-event
                ][
                    parse/trace input rules :on-parse-event
                ]
            ]
        ]

    ] ;parse-debug

    ;;
    ;; Test the node builder
    ;;
    test-builder: function [
        "Test an xml input document, its sxml output, and the associated conformity level"
        testname [string!] xml-input [string!] sxml-output [block!] level [integer!] 
    ][
        sxml/parse-function: :parse-debug
        res: sxml/decode xml-input
        res-level: sxml/sxml?/trace res

        trim/head/tail xml-input

        either res = sxml-output [
            print pad/with "" 100 #"-"
            print pad/with rejoin [ "OK >>> " testname " sxml output" ] 100 #"-"
            print pad/with "" 100 #"-"
            print xml-input
            print pad/with "" 100 #"-"
            probe res
            print pad/with "" 100 #"-"
        ][
            print pad/with "" 100 #"="
            print pad/with rejoin [ "NOK >>> " testname " sxml output" ] 100 #"="
            print xml-input
            print pad/with rejoin [ "== was expecting ==" ] 100 #"="
            probe sxml-output
            print pad/with rejoin [ "== got ==" ] 100 #"="
            probe res
            print pad/with "" 100 #"="
        ]
        either res-level == level [
            print pad/with rejoin [ "OK >>> " testname " LEVEL " res-level ] 100 #"-"
        ][
            print pad/with rejoin [ "NOK >>> " testname " LEVEL " res-level " was expecting " level " "] 100 #"="
        ]
        print pad/with "" 100 #"—"

    ] ;test-builder
    tst: :test-builder

    ; Special assert for the sake of testing
    assert: function [
            test [string!]
            check [block!]
            op [word!]
            against [any-type!]
    ][
        check-value: do check
        cond: do reduce [ check-value op against ]
        either cond [
            print [ "OK" test "- test:" mold/flat check "- got:" mold/flat check-value ]
        ][
            print [ "NOK" test "- test:" mold/flat check "- expecting:" mold/flat against "- got:" mold/flat check-value ]
        ]
    ] ; assert


; Test run 1
run-sxml-1: function [] [

    ; get a tree to work with
    tree: sxml/decode 
{
<mov:movie tags="Drama;Mystery;Romance;Thriller" imdb="8.2" year="2009" xml:space="default" xmlns:mov="http://www.movie.com">
    <name english="The secret in their eyes">El secreto de sus ojos</name>
    <mov:director name="Juan José Campanella" nationality="Argentina"/>
    <star></star>
    <cast>
        <character name="Benjamín Esposito"><star sex="M" birth="1957">Ricardo Darín</star></character>
        <character name="Irene Menéndez Hastings"><star sex="F" birth="1969">Soledad Villamil</star></character>
    </cast>
    <public>10</public>
    <pitch tone="strident" xml:space="preserve">Un crimen sin castigo. <i>Un amor puro.</i> Una historia que no debe morir.</pitch>
    <!-- end -->
</mov:movie>
}

    ; add fake annotations to attributes also
    append/only tree/2/4/2/2 [_] ; mov:director/name
    append/only tree/2/4/2/3 [_ info "supplement"] ; mov:director/nationality

    assert "sxml-1#0" [ trim/all/lines mold/flat tree ] '== do [ trim/all/lines {
[*TOP*
    [mov:movie [_ [tags "Drama;Mystery;Romance;Thriller"] [imdb "8.2"] [year "2009"] [xml:space "default"] 
        [_ [*NAMESPACES* [mov "http://www.movie.com" "mov"] [xml "http://www.w3.org/XML/1998/namespace" "xml"]]]]
        [name [_ [english "The secret in their eyes"]] "El secreto de sus ojos" ]
        [mov:director 
                [_ [name "Juan José Campanella" [_]] [nationality "Argentina" [_ info "supplement"]]]]
        [star [_]] 
        [cast [_] 
            [character [_ [name "Benjamín Esposito"]] 
                [star [_ [sex "M"] [birth "1957"]] "Ricardo Darín" ]
            ]
            [character [_ [name "Irene Menéndez Hastings"]]
                [star [_ [sex "F"] [birth "1969"]] "Soledad Villamil" ]
            ]
        ] 
        [public [_] "10" ]
        [pitch [_ [tone "strident"] [xml:space "preserve"]] 
            "Un crimen sin castigo. " 
            [i [_] "Un amor puro." ]
            " Una historia que no debe morir."
        ]
        [*COMMENT* " end "]
    ]
]
} ]

    assert "sxml-1#1" [ sxml/squeeze tree/2/4 ] '== [mov:director [_ [name "Juan José Campanella"] [nationality "Argentina" [_ info "supplement"]]]]
    assert "sxml-1#2" [ sxml/squeeze tree/2/5 ] '== [star]
    assert "sxml-1#3" [ sxml/clean tree/2/4 ] '== [mov:director [_ [name "Juan José Campanella"] [nationality "Argentina"]]]
    assert "sxml-1#4" [ sxml/clean tree/2/7 ] '== [public "10"]
    assert "sxml-1#8" [ sxml/name? tree/2 ] '== mov:movie
    assert "sxml-1#9" [ sxml/name? tree/2/4 ] '== mov:director
    assert "sxml-1#10" [ to-string sxml/name? tree/2/5 ] '== "star"
    assert "sxml-1#11" [ sxml/name? tree/2/4/1 ] '== none ; mov:director/name
    assert "sxml-1#12" [ sxml/name? tree/2/4/2 ] '== none ; mov:director/attributes
    ;@ZWT also support annotations
    assert "sxml-1#13" [ to-string sxml/local-name? tree/2 ] '== "movie"
    assert "sxml-1#14" [ to-string sxml/namespace-id? tree/2 ] '== "mov"
    assert "sxml-1#15" [ sxml/children-of tree/2/3 ] '== ["El secreto de sus ojos"]
    assert "sxml-1#16" [ sxml/children-of tree/2/4 ] '== [] ; mov:director
    assert "sxml-1#17" [ sxml/children-of tree/2/8 ] '== [
        "Un crimen sin castigo. "
        [i [_] "Un amor puro."]
        " Una historia que no debe morir."
    ]
    assert "sxml-1#18" [ sxml/has-children? tree/2/3 ] '== true
    assert "sxml-1#19" [ sxml/has-children? tree/2/4 ] '== false ; mov:director
    assert "sxml-1#20" [ sxml/has-children? tree/2/8 ] '== true
    assert "sxml-1#21" [ sxml/has-attributes? tree/2/3 ] '== true
    assert "sxml-1#22" [ sxml/has-attributes? tree/2/5 ] '== false
    assert "sxml-1#23" [ sxml/has-attributes? tree/2/3/2 ] '== false
    assert "sxml-1#24" [ sxml/attributes-of tree/2/3 ] '== [ [english "The secret in their eyes"] ]
    assert "sxml-1#25" [ sxml/attributes-of tree/2/5 ] '== none ; star
    assert "sxml-1#26" [ sxml/attributes-of tree/2/3/2 ] '== none ; text
    assert "sxml-1#27" [ sxml/has-any-children? tree/2/4 ] '== true ; mov:director
    assert "sxml-1#28" [ sxml/has-any-children? tree/2/5 ] '== false ; star
    assert "sxml-1#29" [ sxml/has-any-children? tree/2/7 ] '== true ; public
    assert "sxml-1#30" [ sxml/any-children-of tree/2/4 ] '== [ [_ [name "Juan José Campanella"] [nationality "Argentina"]] ] ; mov:director
    assert "sxml-1#31" [ sxml/any-children-of tree/2/5 ] '== [] ; star
    assert "sxml-1#32" [ sxml/any-children-of tree/2/7 ] '== [ "10" ] ; public
    assert "sxml-1#33" [ sxml/mold-nodes sxml/descendants-of tree/2/6 ] '== 
    {[ Element:character, Element:star, Text:"Ricardo Darín", Element:character, Element:star, Text:"Soledad Villamil" ]} ; cast
    assert "sxml-1#34" [ sxml/node-set? tree/2/4 ] '== false ; mov:director
    assert "sxml-1#35" [ sxml/node-set? at tree/2/6 3 ] '== true ; cast
    assert "sxml-1#36" [ sxml/node-type? tree ] '== sxml/*TOP*
    assert "sxml-1#37" [ sxml/node-type? tree/2 ] '== sxml/*element*
    assert "sxml-1#38" [ sxml/node-type? tree/2/1 ] '== none
    assert "sxml-1#39" [ sxml/node-type? tree/2/2 ] '== sxml/_ 
    assert "sxml-1#40" [ sxml/node-type? tree/2/3/3 ] '== sxml/*text*
    assert "sxml-1#41" [ sxml/comment? tree/2/9 ] '== true
    assert "sxml-1#42" [ sxml/text tree/2/8 ] '== "Un crimen sin castigo.  Una historia que no debe morir."
    assert "sxml-1#43" [ sxml/text tree/2/8/3 ] '== "Un crimen sin castigo. "
    assert "sxml-1#44" [ sxml/attribute tree/2/4 'nationality ] '== "Argentina"
    assert "sxml-1#45" [ sxml/attribute tree/2/4 'new ] '== none
    assert "sxml-1#46" [ sxml/attribute tree/2/6 'new ] '== none
    assert "sxml-1#47" [ 
        sxml/change-content tree/2/5 "The highlights !" 
        sxml/text tree/2/5
    ] '== "The highlights !"
    assert "sxml-1#48" [
        sxml/change-content tree/2/5 "The new highlights !" 
        sxml/text tree/2/5
    ] '== "The new highlights !"
    assert "sxml-1#49" [
        sxml/change-attributes tree/2/5 [[name "Signore Novatore"] [nationality "Boliviana"]]
        sxml/attributes-of tree/2/5
    ] '== [[name "Signore Novatore"] [nationality "Boliviana"]]
    assert "sxml-1#50" [
        sxml/change-attributes tree/2/6 [[only-actors "true"]]
        sxml/attributes-of tree/2/6
    ] '==  [[only-actors "true"]]
    assert "sxml-1#51" [ sxml/change-name tree/2/4 'director 
        to-string sxml/name? tree/2/4
    ] '== "director"
    assert "sxml-1#52" [
        sxml/set-attribute tree/2/3 'english "The secret"
        sxml/attribute tree/2/3 'english
    ] '== "The secret"
    assert "sxml-1#53" [
        sxml/set-attribute tree/2/3 'german "Das Geheimnis in ihren Augen"
        sxml/attribute tree/2/3 'german
    ] '== none
    assert "sxml-1#54" [
        sxml/add-attribute tree/2/3 'english "The secret in their eyes"
        sxml/attribute tree/2/3 'english
    ] '== "The secret"
    assert "sxml-1#55" [
        sxml/add-attribute tree/2/3 'german "Das Geheimnis in ihren Augen"
        sxml/attribute tree/2/3 'german
    ] '== "Das Geheimnis in ihren Augen"
    assert "sxml-1#56" [
        sxml/add-attribute tree/2/7 'name "Brian Ristell"
        sxml/attribute tree/2/7 'name
    ] '== "Brian Ristell"
    assert "sxml-1#57" [
        sxml/change-attribute tree/2/7 'colour "Yellow"
    ] '== none
    assert "sxml-1#58" [
        sxml/change-attribute tree/2/7 'name "Brian Ristella"
    ] '== tree/2/7
    assert "sxml-1#59" [ sxml/element? tree ] '== true ; top
    assert "sxml-1#60" [ sxml/element? tree/1 ] '== false ; top name
    assert "sxml-1#61" [ sxml/element? tree/2 ] '== true ; movie
    assert "sxml-1#62" [ sxml/element? tree/2/2 ] '== false ; movie attributes
    assert "sxml-1#63" [ sxml/element? tree/2/3 ] '== true ; name
    assert "sxml-1#64" [ sxml/text? tree/2/8/3 ] '== true ; pitch/text
    assert "sxml-1#65" [ sxml/attributes? tree/2/8/2 ] '== true ; pitch/_
    assert "sxml-1#66" [ sxml/attributes? tree/2/2/6 ] '== true ; movie/_/_
    append/only tree/2/4/2/2 [_] ; mov:director/_/name
    assert "sxml-1#67" [ sxml/attributes? tree/2/4/2/2/3 ] '== true ; mov:director/_/name/_
    assert "sxml-1#68" [ sxml/node? tree/2/9 ] '== true

    exit

]; run-sxml-1


; Test run 2
run-sxml-2: function [] [

tst "sxml-2#1" {
<WEIGHT unit="pound" xml:space="default">
    <NET certified="certified">67</NET>
    <GROSS>95</GROSS>
</WEIGHT>
}
[*TOP*
    [WEIGHT [_ [unit "pound"] [xml:space "default"] [_ [*NAMESPACES* [xml "http://www.w3.org/XML/1998/namespace" "xml"]]]]
        [NET [_ [certified "certified"]] "67"]
        [GROSS [_] "95"]
    ]
]
3

tst "sxml-2#2" 
{
<BR/>
}
[*TOP*
    [ BR [_] ]
]
3

tst "sxml-2#3"
{
<BR></BR>
}
[*TOP*
    [BR [_]]
]
3

tst "sxml-2#4" {
<P
>^M^/<![CDATA[<BR>^M^/<![CDATA[<BR>]]]]>&gt; </P>
}
[*TOP*
[P [_] "^/<BR>^M^/<![CDATA[<BR>]]> "]
]
3

tst "sxml-2#5" {
<!-- initially, the default
    namespace is 'books' -->
<book xml:space="default" xmlns='urn:loc.gov:books'
    xmlns:isbn='urn:ISBN:0-395-36341-6'>
    <title>Cheaper by the Dozen</title>
    <isbn:number>1568491379</isbn:number>
    <notes>
    <!-- make HTML the default namespace -->
        <p xml:space="preserve" xmlns='urn:w3-org-ns:HTML'>This is a <i>funny</i> book!</p>
    </notes>
</book>
}
[*TOP*
    [*COMMENT* " initially, the default^/    namespace is 'books' "]
    [urn:loc.gov:books:book 
    [_ [xml:space "default"] [_ [*NAMESPACES* [urn:loc.gov:books "urn:loc.gov:books"] [xml "http://www.w3.org/XML/1998/namespace" "xml"]]]] 
        [urn:loc.gov:books:title [_] "Cheaper by the Dozen"]
        [isbn:number [_ [_ [*NAMESPACES* [isbn "urn:ISBN:0-395-36341-6" "isbn"]]]] "1568491379"]
        [urn:loc.gov:books:notes [_]
            [*COMMENT* " make HTML the default namespace "]
            [urn:w3-org-ns:HTML:p [_ [xml:space "preserve"] [_ [*NAMESPACES* [urn:w3-org-ns:HTML "urn:w3-org-ns:HTML"]]]]
                "This is a "
                [urn:w3-org-ns:HTML:i [_] "funny"]
                " book!"
            ]
        ]
    ]
]
1

tst "sxml-2#6" {
<RESERVATION xml:space="default"
xmlns:HTML=
'http://www.w3.org/TR/REC-html40'>
<NAME HTML:CLASS="largeSansSerif">
    Layman, A</NAME><SEAT CLASS='Y' 
HTML:CLASS="largeMonotype">33B</SEAT>
<HTML:A HREF='/cgi-bin/ResStatus'>
    Check Status</HTML:A>
<DEPARTURE>1997-05-24T07:55:00+1
</DEPARTURE></RESERVATION>
}
[*TOP*
    [RESERVATION 
        [_ [xml:space "default"] [_ [*NAMESPACES* [xml "http://www.w3.org/XML/1998/namespace" "xml"] ]] ]
        [NAME [_ [HTML:CLASS "largeSansSerif"] [_ [*NAMESPACES* [HTML "http://www.w3.org/TR/REC-html40" "HTML"]]]]
        "Layman, A"]
        [SEAT [_ [CLASS "Y"] [HTML:CLASS "largeMonotype"]] "33B"]
        [HTML:A [_ [HREF "/cgi-bin/ResStatus"]] "Check Status"]
        [DEPARTURE [_] "1997-05-24T07:55:00+1"]
    ]
]
3

tst "sxml-2#7" {
<movie tags="Drama;Mystery;Romance;Thriller" imdb="8.2" year="2009" xml:space="default">
    <name english="The secret in their eyes">El secreto de sus ojos</name>
    <director name="Juan José Campanella" nationality="Argentina"/>
    <cast>
        <character name="Benjamín Esposito"><star sex="M" birth="1957">Ricardo Darín</star></character>
        <character name="Irene Menéndez Hastings"><star sex="F" birth="1969">Soledad Villamil</star></character>
    </cast>
    <pitch xml:space="preserve">Un crimen sin castigo. <i>Un amor puro.</i> Una historia que no debe morir.</pitch>
</movie>
}
[*TOP*
    [ movie 
        [_ [ tags "Drama;Mystery;Romance;Thriller" ] 
           [imdb "8.2"] [ year "2009" ]
           [ xml:space "default" ]
           [_ [*NAMESPACES* [xml "http://www.w3.org/XML/1998/namespace" "xml"] ] ]
        ]
        [ name [_ [english "The secret in their eyes"]] "El secreto de sus ojos" ]
        [ director [_ [name "Juan José Campanella"] [nationality "Argentina"]] ]
        [ cast [_]
            [ character [_ [name "Benjamín Esposito"]] 
                [ star [_ [sex "M"] [birth "1957"] ] "Ricardo Darín" ]
            ]
            [ character [_ [name "Irene Menéndez Hastings"]]
                [ star [_ [sex "F"] [birth "1969"] ] "Soledad Villamil" ]
            ]
        ]
        [ pitch [_ [xml:space "preserve"]]
            "Un crimen sin castigo. "
            [ i [_] "Un amor puro." ]
            " Una historia que no debe morir."
        ]
    ]
]
3

tst "sxml-2#8" {
<html xmlns="http://www.w3.org/1999/xhtml"
         xml:lang="en" lang="en" xml:space="default">
    <head>
       <title>An example page</title>
    </head>
    <body>
       <h1 id="greeting">Hi, there!</h1>
       <p>This is just an &gt;&gt;example&lt;&lt; to show XHTML &amp; SXML.</p>
    </body>
 </html>
}
[*TOP*
  [http://www.w3.org/1999/xhtml:html [_ [xml:lang "en"] [lang "en"] [xml:space "default"] 
    [_ [*NAMESPACES* [http://www.w3.org/1999/xhtml "http://www.w3.org/1999/xhtml"] [xml "http://www.w3.org/XML/1998/namespace" "xml"]]]]
    [http://www.w3.org/1999/xhtml:head [_]
       [http://www.w3.org/1999/xhtml:title [_] "An example page"]]
    [http://www.w3.org/1999/xhtml:body [_]
       [http://www.w3.org/1999/xhtml:h1 [_ [id "greeting"]] "Hi, there!"]
       [http://www.w3.org/1999/xhtml:p [_]  "This is just an >>example<< to show XHTML & SXML."]
    ]
  ]
]
3

tst "sxml-2#9" {<?xml version="1.0" encoding="utf-8"?>
<?xml-stylesheet href = "beer.css" type = "text/css" ?>
<Beers><table xmlns='http://www.w3.org/1999/xhtml'
><th><td>Name</td></th
><tr><td><details xmlns=""><class>Bitter</class><hop>Fuggles</hop
></details></td></tr><tr><td>Royal Oak</td></tr></table></Beers>
}
[*TOP* 
    [*PI* xml-stylesheet [_] { href = "beer.css" type = "text/css" }] 
    [Beers [_] 
        [http://www.w3.org/1999/xhtml:table [_ [_ [*NAMESPACES* [http://www.w3.org/1999/xhtml "http://www.w3.org/1999/xhtml"]]]] 
            [http://www.w3.org/1999/xhtml:th [_] 
                [http://www.w3.org/1999/xhtml:td [_] "Name" ]
            ] 
            [http://www.w3.org/1999/xhtml:tr [_] 
                [http://www.w3.org/1999/xhtml:td [_] 
                    [details [_] [class [_] "Bitter" ] 
                        [hop [_] "Fuggles" ]
                    ]
                ]
            ] 
            [http://www.w3.org/1999/xhtml:tr [_] 
                [http://www.w3.org/1999/xhtml:td [_] 
                    "Royal Oak"
                ]
            ]
        ]
    ]
]
3

tst "sxml-2#10" {<?xml version="1.0" encoding="utf-8"?>
<movie xml:space="default">
    <title>Star Trek: Insurrection</title>
    <star sex="M" age="35">Patrick Stewart</star>
    <star sex="M" age="25">Brent Spiner</star>
    <theater opening_year="2005">
        <theater-name>MonoPlex 2000</theater-name>
        <showtime>14:15</showtime>
        <showtime>16:30</showtime>
        <showtime/>
        <price>
            <adult>$8.50</adult>
            <child>$5.00</child>
        </price>
    </theater>
    <theater opening_year="2006">
        <theater-name>Bigscreen 1</theater-name>
        <showtime>19:30</showtime>
        <showtime/>
        <price>$6.00</price>
    </theater>
    <theater opening_year="2010" />
</movie>
}
[*TOP* 
    [movie [_ [xml:space "default"] [_ [*NAMESPACES* [xml "http://www.w3.org/XML/1998/namespace" "xml"]]]] 
        [title [_] "Star Trek: Insurrection" ]
        [star [_ [sex "M"] [age "35"]] "Patrick Stewart" ]
        [star [_ [sex "M"] [age "25"]] "Brent Spiner" ]
        [theater [_ [opening_year "2005"]] 
            [theater-name [_] "MonoPlex 2000" ]
            [showtime [_] "14:15" ]
            [showtime [_] "16:30" ]
            [showtime [_]]
            [price [_] 
                [adult [_] "$8.50" ]
                [child [_] "$5.00" ]
            ]
        ]
        [theater [_ [opening_year "2006"]] 
            [theater-name [_] "Bigscreen 1" ]
            [showtime [_] "19:30" ]
            [showtime [_]]
            [price [_] "$6.00" ]
        ]
        [theater [_ [opening_year "2010"]]]
    ]
]
3

tst "sxml-2#11" {
<movie xml:space="default" tags="Drama;Mystery;Romance;Thriller" imdb="8.2" year="2009">
<name english="The secret in their eyes">El secreto de sus ojos</name>
<director name="Juan José Campanella" nationality="Argentina"/>
<cast>
    <character name="Benjamín Esposito"><star sex="M" birth="1957">Ricardo Darín</star></character>
    <character name="Irene Menéndez Hastings"><star sex="F" birth="1969">Soledad Villamil</star></character>
    <character name="Isidoro Gómez"><star sex="M" birth="1978">Javier Godino</star></character>
    <character name="Pablo Sandoval"><star sex="M" birth="1955">Guillermo Francella</star></character>
</cast>
<pitch>Un crimen sin castigo. <i>Un amor puro.</i> Una historia que no debe morir.</pitch>
</movie>
}
[*TOP* 
    [movie [_ [xml:space "default"] [tags "Drama;Mystery;Romance;Thriller"] [imdb "8.2"] [year "2009"] 
        [_ [*NAMESPACES* [xml "http://www.w3.org/XML/1998/namespace" "xml"]]]] 
        [name [_ [english "The secret in their eyes"]] "El secreto de sus ojos" ]
        [director [_ [name "Juan José Campanella"] [nationality "Argentina"]]]
        [cast [_] 
            [character [_ [name "Benjamín Esposito"]] 
                [star [_ [sex "M"] [birth "1957"]] "Ricardo Darín" ]
            ]
            [character [_ [name "Irene Menéndez Hastings"]] 
                [star [_ [sex "F"] [birth "1969"]] "Soledad Villamil" ]
            ]
            [character [_ [name "Isidoro Gómez"]] 
                [star [_ [sex "M"] [birth "1978"]] "Javier Godino" ]
            ]
            [character [_ [name "Pablo Sandoval"]] 
                [star [_ [sex "M"] [birth "1955"]] "Guillermo Francella" ]
            ]
        ]
        [pitch [_] 
            "Un crimen sin castigo." 
            [i [_] "Un amor puro." ]
            "Una historia que no debe morir."
        ]
    ]
]
3

]; run-sxml-2

]; test-sxml

test-sxml/run-sxml-1
test-sxml/run-sxml-2

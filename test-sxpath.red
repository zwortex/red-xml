Red [
    Title:      "Test set for SXPATH"
    File:       %test-sxpath.red
    Author:     @zwortex
    License: {
        Distributed under the Boost Software License, Version 1.0.
        See https://github.com/red/red/blob/master/BSL-License.txt
    }
    Notes:      { ... }
    Version:    0.1.0
    Date:       2021-09-23
    Changelog: {
        0.1.0 - 23/09/2021
            * initial version
    }
    Tabs:    4
]

#include %sxpath.red

test-sxpath: context [

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
            clear p-indent
            input?: true
            either case [
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

run-sxpath-1: function [ ][
    sxp: sxpath
    ; get a tree to work with
    tree: sxml/decode {
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

    assert "sxpath-1#1" [ a: sxp/compile [ pitch i ] a tree/2 ] '== [[i [_] "Un amor puro."]]
    assert "sxpath-1#2" [ a: sxp/compile [ pitch i *text* ] a tree/2 ] '== ["Un amor puro."]
    assert "sxpath-1#3" [ a: sxp/compile [ #... *text* ] a tree/2 ] '== ["El secreto de sus ojos" "Ricardo Darín"
     "Soledad Villamil" "10" "Un crimen sin castigo. " "Un amor puro." " Una historia que no debe morir." ]
    assert "sxpath-1#4" [ a: sxp/compile [ #ns-id mov ] a tree/2 ] '== [
        [mov:director [_ [name "Juan José Campanella"] [nationality "Argentina"]]]
    ]
    assert "sxpath-1#5" [ a: sxp/compile [ #same? tree/2/5 ] a tree/2 ] '== [ [star [_] ] ]
    assert "sxpath-1#6" [ a: sxp/compile [ #or [name public] ] a tree/2 ] '== [ 
        [name [_ [english "The secret in their eyes"]] "El secreto de sus ojos"]
        [public [_] "10"]
    ]
    assert "sxpath-1#7" [ a: sxp/compile [ #not [_ name mov:director cast pitch *COMMENT*] ] a tree/2 ] '== [ 
        [star [_]] [public [_] "10"]
    ]
    assert "sxpath-1#8" [ a: sxp/compile [ sxml/content ] a tree/2/3 ] '== [ "El secreto de sus ojos" ]

    assert "sxpath-1#9" [ 
        a: sxp/compile [ 
            #... [ star ]
        ]
        a tree/2
    ] '== [[star [_]] [star [_ [sex "M"] [birth "1957"]] "Ricardo Darín"] [star [_ [sex "F"] [birth "1969"]] "Soledad Villamil"]]

    assert "sxpath-1#10" [
        a: sxp/compile [
            #... [ star [_] ]
        ]
        a tree/2
    ] '== [[star [_]] [star [_ [sex "M"] [birth "1957"]] "Ricardo Darín"] [star [_ [sex "F"] [birth "1969"]] "Soledad Villamil"]]

    assert "sxpath-1#11" [
        a: sxp/compile [
            #... [ star [ _ [ sex [ #equal? "F" ] ] ] ]
        ]
        a tree/2
    ] '== [[star [_ [sex "F"] [birth "1969"]] "Soledad Villamil" ]]

]; run-sxpath-1

run-sxpath-2: function [] [

    sxp: sxpath

    ; get a tree to work with
    tree: sxml/decode {
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

    assert "sxpath-2#1" [ a: sxp/node-name?? [*TOP*] a tree ] '== true
    assert "sxpath-2#2" [ a: sxp/node-name?? [*TOP*] a tree/2 ] '== false
    assert "sxpath-2#3" [ a: sxp/node-name?? [*TOP* mov:movie] a tree/2 ] '== true
    assert "sxpath-2#4" [ a: sxp/node-name?? [*TOP* cast mov:movie] a tree/2/6 ] '== true
    assert "sxpath-2#5" [ a: sxp/node-type?? '*element* a tree/2/6 ] '== true
    assert "sxpath-2#6" [ a: sxp/node-type?? '*element* a tree/2/4/2 ] '== false
    assert "sxpath-2#7" [ a: sxp/node-type?? '_ a tree/2/4/2 ] '== true
    assert "sxpath-2#8" [ a: sxp/node-type?? '*text* a tree/2/8/3 ] '== true
    assert "sxpath-2#9" [ a: sxp/node-type?? '*text* a tree/2/8/4 ] '== false
    assert "sxpath-2#10" [ a: sxp/node-type?? 'pitch a tree/2/8 ] '== true
    assert "sxpath-2#11" [ a: sxp/node-type?? mov:movie a tree/2 ] '== true
    assert "sxpath-2#12" [ a: sxp/node-namespace?? 'mov a tree/2 ] '== true
    assert "sxpath-2#13" [ a: sxp/node-namespace?? 'mo a tree/2 ] '== false
    assert "sxpath-2#14" [ a: sxp/node-complement?? sxp/node-type?? '*text* a tree/2/8/3 ] '== false
    assert "sxpath-2#15" [ a: sxp/node-complement?? sxp/node-type?? '*text* a tree/2/8/4 ] '== true
    assert "sxpath-2#16" [ a: sxp/node-equal?? tree/2/4 a tree/2/4 ] '== true
    assert "sxpath-2#17" [ a: sxp/node-equal?? tree/2/4 a tree/2/5 ] '== false
    assert "sxpath-2#18" [ a: sxp/nodes-pos?? 3 a sxml/content tree/2/8 ] '== [" Una historia que no debe morir."]
    assert "sxpath-2#19" [ a: sxp/nodes-pos?? -1 a sxml/content tree/2/8 ] '== [" Una historia que no debe morir."]
    assert "sxpath-2#20" [ a: sxp/nodes-pos?? -4 a sxml/content tree/2/8 ] '== []
    assert "sxpath-2#21" [ a: sxp/nodes-pos?? -3 a sxml/content tree/2/8 ] '== [ "Un crimen sin castigo. " ]
    assert "sxpath-2#22" [ a: sxp/nodes-pos?? -2 a sxml/content tree/2/8 ] '== [ [i [_] "Un amor puro." ] ]
    assert "sxpath-2#23" [ a: sxp/nodes-pos?? 0 a sxml/content tree/2/8 ] '== []
    assert "sxpath-2#24" [ a: sxp/keep-match?? sxp/node-type?? '*element* a sxml/content tree/2/8 ] '== [[i [_] "Un amor puro."]]
    assert "sxpath-2#25" [ a: sxp/keep-match?? sxp/node-type?? '*text* a sxml/content tree/2/8 ] '== [ "Un crimen sin castigo. " " Una historia que no debe morir." ]
    assert "sxpath-2#26" [ a: sxp/keep-match?? sxp/node-type?? 'a a sxml/content tree/2/8 ] '== []
    assert "sxpath-2#27" [ a: sxp/keep-until-match?? sxp/node-type?? '*element* a sxml/content tree/2/8 ] '== ["Un crimen sin castigo. "]
    assert "sxpath-2#28" [ a: sxp/keep-after-match?? sxp/node-type?? '*element* a sxml/content tree/2/8 ] '== [" Una historia que no debe morir."]
    assert "sxpath-2#29" [ a: sxp/keep-until-match?? sxp/node-type?? 'a a sxml/content tree/2/8 ] '== ["Un crimen sin castigo. " [i [_] "Un amor puro." ] " Una historia que no debe morir."]
    assert "sxpath-2#30" [ a: sxp/keep-after-match?? sxp/node-type?? 'a a sxml/content tree/2/8 ] '== []
    assert "sxpath-2#31" [
        n: sxml/descendants-of tree/2/8
        a: sxp/keep-match?? sxp/node-type?? '*text*
        n: a n
        f: function [ str ] [ uppercase copy str ]
        sxp/apply-and-join :f n
    ] '== [ "UN CRIMEN SIN CASTIGO. " "UN AMOR PURO." " UNA HISTORIA QUE NO DEBE MORIR." ]
    assert "sxpath-2#32" [ a: sxp/reverse-nodes sxml/content tree/2/8 ] '== [" Una historia que no debe morir." [i [_] "Un amor puro." ] "Un crimen sin castigo. "]
    assert "sxpath-2#33" [ a: sxp/nodes-trace?? "check" a sxml/content tree/2/7 ] '== ["10"]
    assert "sxpath-2#34" [ a: sxp/select-children?? sxp/node-type?? '*text* a tree/2/8 ] '== [ "Un crimen sin castigo. " " Una historia que no debe morir." ]
    assert "sxpath-2#35" [
        a: sxp/select-children?? sxp/node-type?? '*text*
        a sxml/children-of tree/2
    ] '== [ "El secreto de sus ojos" "10" "Un crimen sin castigo. " " Una historia que no debe morir." " end "]
    assert "sxpath-2#36" [ a: sxp/select-first-children?? sxp/node-type?? '*text* 
        a sxml/children-of tree/2
    ] '== [ "El secreto de sus ojos" "10" "Un crimen sin castigo. " ]
    assert "sxpath-2#37" [ a: sxp/select-oneself?? sxp/node-type?? '*text* a tree/2/8/3 ] '== ["Un crimen sin castigo. "]
    assert "sxpath-2#38" [ 
        a: sxp/nodes-join?? 
        reduce [
            sxp/select-children?? sxp/node-type?? 'cast
            sxp/select-children?? sxp/node-type?? 'character
            sxp/select-children?? sxp/node-type?? 'star
            sxp/select-children?? sxp/node-type?? '*text*
        ]
        a tree/2 
    ] '== ["Ricardo Darín" "Soledad Villamil"]

    assert "sxpath-2#39" [ 
        a: sxp/nodes-reduce?? 
        reduce [
            sxp/select-children?? sxp/node-type?? 'cast
            sxp/select-children?? sxp/node-type?? 'character
            sxp/select-children?? sxp/node-type?? 'star
            sxp/select-children?? sxp/node-type?? '*text*
        ]
        a tree/2 
    ] '== ["Ricardo Darín" "Soledad Villamil"]
    assert "sxpath-2#40" [ 
        a: sxp/nodes-or?? 
        reduce [
            sxp/keep-match?? sxp/node-type?? 'star
            sxp/keep-match?? sxp/node-type?? 'public
        ]
        a sxml/children-of tree/2
    ] '== [ [star [_]] [public [_] "10"]]
    assert "sxpath-2#41" [
        a: sxp/nodes-closure?? sxp/node-type?? '*text*
        a tree/2
    ] '== [ "El secreto de sus ojos" "Ricardo Darín" "Soledad Villamil" "10" "Un crimen sin castigo. " 
    "Un amor puro." " Una historia que no debe morir." ]
    assert "sxpath-2#42" [
        a: sxp/node-type?? 'name
        b: sxp/attributes?? :a
        c: sxml/descendants-of tree/2
        b c
    ] '==  [[name "Juan José Campanella"] [name "Benjamín Esposito"] [name "Irene Menéndez Hastings"]]

    assert "sxpath-2#43" [
        a: sxp/node-type?? '*text*
        b: sxp/children?? :a
        b tree/2/8
    ] '== ["Un crimen sin castigo. " " Una historia que no debe morir."]

    assert "sxpath-2#44" [
        a: sxp/attributes?? sxp/node-type?? 'name
        attrs: a sxml/descendants-of tree/2
        a: sxp/parent?? tree (sxp/node-type?? 'character)
        a attrs
    ] '== [
        [character [_ [name "Benjamín Esposito"]] [star [_ [sex "M"] [birth "1957"]] "Ricardo Darín"]]
        [character [_ [name "Irene Menéndez Hastings"]] [star [_ [sex "F"] [birth "1969"]] "Soledad Villamil"]]
    ]

    assert "sxpath-2#45" [
        p: sxp/node-parent?? tree/2 
        p tree/2/7/3
    ] '== reduce [ tree/2/7 ]

    assert "sxpath-2#46" [
        c: sxp/child-nodes??
        c tree/2/8
    ] '== [[i [_] "Un amor puro."]]

    assert "sxpath-2#47" [
        c: sxp/child-elements??
        c tree/2/8
    ] '== [[i [_] "Un amor puro."]]

]; run-sxpath-2

run-sxpath-3: function [][

    sxp: sxpath
    sxl: sxml

    tree1: [
        html [head [title "Slides"]]
        [body
            [p 
                [_ [align "center"]]
                [table 
                    [_ [style "font-size: x-large"]]
                    [tr
                        [td [_ [align "right"]] "Talks "]
                        [td [_ [align "center"]] " = "]
                        [td " slides + transition"]
                    ]
                    [tr 
                        [td]
                        [td [_ [align "center"]] " = "]
                        [td " data + control"]
                    ]
                    [tr 
                        [td]
                        [td [_ [align "center"]] " = "]
                        [td " programs"]
                    ]
                ]
            ]
            [ul
                [li [a [_ [href "slides/slide0001.gif"]] "Introduction"]]
                [li [a [_ [href "slides/slide0010.gif"]] "Summary"]]
            ]
        ]
    ]

    tree3: [poem 
        [_ 
            [title "The Lovesong of J. Alfred Prufrock"]
            [poet "T. S. Eliot"]
        ]
        [stanza
            [line "Let us go then, you and I,"]
            [line "When the evening is spread out against the sky"]
            [line "Like a patient etherized upon a table:"]
        ]
        [stanza
            [line "In the room the women come and go"]
            [line "Talking of Michaelangelo."]
        ]
    ]

    ; Location path, full form: child::para 
    ; Location path, abbreviated form: para
    ; selects the para element children of the context node
    tree: [elem [_] [para [_] "para"] [br [_]] "cdata" [para [_] "second par"]]
    expected: [[para [_] "para"] [para [_] "second par"]]
    assert "sxpath-3#1" [ a: sxp/select-children?? sxp/node-type?? 'para a tree ] '== expected
    assert "sxpath-3#2" [ a: sxp/compile [para] a tree ] '== expected

    ; Location path, full form: child::* 
    ; Location path, abbreviated form: *
    ; selects all element children of the context node
    tree: [elem [_] [para [_] "para"] [br [_]] "cdata" [para "second par"]]
    expected: [[para [_] "para"] [br [_]] [para "second par"]]
    assert "sxpath-3#3" [ a: sxp/select-children?? sxp/node-type?? '*element* a tree ] '== expected
    assert "sxpath-3#4" [ a: sxp/compile [*element*] a tree ] '== expected

    ; Location path, full form: child::text() 
    ; Location path, abbreviated form: text()
    ; selects all text node children of the context node
    tree: [elem [_] [para [_] "para"] [br [_]] "cdata" [para "second par"]]
    expected: ["cdata"]
    assert "sxpath-3#5" [ a: sxp/select-children?? sxp/node-type?? '*text* a tree ] '== expected
    assert "sxpath-3#6" [ a: sxp/compile [*text*] a tree ] '== expected

    ; Location path, full form: child::node() 
    ; Location path, abbreviated form: node()
    ; selects all the children of the context node, whatever their node type
    tree: [elem [_] [para [_] "para"] [br [_]] "cdata" [para "second par"]]
    expected: at tree 2
    assert "sxpath-3#7" [ a: sxp/select-children?? sxp/node-type?? '*any* a tree ] '== expected
    assert "sxpath-3#8" [ a: sxp/compile [*any*] a tree ] '== expected

    ; Location path, full form: child::*/child::para 
    ; Location path, abbreviated form: */para
    ; selects all para grandchildren of the context node
    tree: [ elem [_]
        [para [_] "para"] [br [_]] "cdata" [para "second par"]
        [div 
            [_ [name "aa"]]
            [para "third para"]
        ]
    ]
    expected: [[para "third para"]]
    assert "sxpath-3#9" [
        a: sxp/nodes-join?? [
            [ sxp/select-children?? sxp/node-type?? '*element* ]
            [ sxp/select-children?? sxp/node-type?? 'para ]
        ]
        a tree 
    ] '== expected
    assert "sxpath-3#10" [ a: sxp/compile [*element* para] a tree ] '== expected

    ; Location path, full form: attribute::name 
    ; Location path, abbreviated form: @name
    ; selects the 'name' attribute of the context node
    tree: [elem [_ [name "elem"] [id "idz"]] 
        [para [_] "para"] [br [_]] "cdata" [para [_] "second par"]
        [div [_ [name "aa"]] [para [_] "third para"]]]
    expected: [[name "elem"]]
    assert "sxpath-3#11" [
        a: sxp/nodes-join?? [
            [ sxp/select-children?? sxp/node-type?? '_ ]
            [ sxp/select-children?? sxp/node-type?? 'name ]
        ]
        a tree 
    ] '== expected
    assert "sxpath-3#12" [ a: sxp/compile [_ name] a tree ] '== expected

    ; Location path, full form:  attribute::* 
    ; Location path, abbreviated form: @*
    ; selects all the attributes of the context node
    tree: [elem [_ [name "elem"] [id "idz"]]
        [para [_] "para"] [br [_]] "cdata" [para "second par"]
        [div [_ [name "aa"]] [para [_] "third para"]]]
    expected: [[name "elem"] [id "idz"]]
    assert "sxpath-3#13" [
        a: sxp/nodes-join?? [
            [ sxp/select-children?? sxp/node-type?? '_ ]
            [ sxp/select-children?? sxp/node-type?? '*element* ]
        ]
        a tree 
    ] '== expected
    assert "sxpath-3#14" [ a: sxp/compile [_ *element*] a tree ] '== expected

    ; Location path, full form: descendant::para 
    ; Location path, abbreviated form: .//para
    ; selects the para element descendants of the context node
    tree: [elem [_ [name "elem"] [id "idz"]]
        [para [_] "para"] [br [_]] "cdata" [para "second par"]
        [div [_ [name "aa"]] [para [_] "third para"]]]
    expected: [[para [_] "para"] [para "second par"] [para [_] "third para"]]
    assert "sxpath-3#15" [ a: sxp/nodes-closure?? sxp/node-type?? 'para a tree ] '== expected
    assert "sxpath-3#16" [ a: sxp/compile [#... para] a tree ] '== expected

    ; Location path, full form: self::para 
    ; Location path, abbreviated form: _none_
    ; selects the context node if it is a para element; otherwise selects nothing
    tree: [elem 
        [_ [name "elem"] [id "idz"]] 
        [para [_] "para"]
        [br [_]] "cdata"
        [para "second par"]
        [div [_ [name "aa"]] [para [_] "third para"]]]
    assert "sxpath-3#17" [ a: sxp/select-oneself?? sxp/node-type?? 'para a tree ] '= []
    assert "sxpath-3#18" [ a: sxp/select-oneself?? sxp/node-type?? 'elem a tree ] '== compose/only [(tree)]

    ; Location path, full form: descendant-or-self::node()
    ; Location path, abbreviated form: //
    ; selects the context node, all the children (including attribute nodes)
    ; of the context node, and all the children of all the (element)
    ; descendants of the context node.
    ; This is _almost_ a powerset of the context node.
    tree: [para [_ [name "elem"] [id "idz"]] 
        [para [_] "para"] [br [_]] "cdata" [para "second par"]
        [div [_ [name "aa"]] [para [_] "third para"]]]
    expected: [
        [para [_ [name "elem"] [id "idz"]] 
        [para [_] "para"] [br [_]] "cdata" [para "second par"] 
        [div [_ [name "aa"]] [para [_] "third para"]]]
        [para [_] "para"] "para" [br [_]] "cdata" [para "second par"] "second par" 
        [div [_ [name "aa"]] [para [_] "third para"]] [para [_] "third para"] "third para"
    ]
    assert "sxpath-3#19" [
        a: sxp/nodes-or?? [
            [ sxp/select-oneself?? sxp/node-type?? '*any* ]
            [ sxp/nodes-closure?? sxp/node-type?? '*any* ]
        ]
        a tree
    ] '== expected
    assert "sxpath-3#20" [
        a: sxp/nodes-closure??/with-self sxp/node-type?? '*any*
        a tree
    ] '== expected
    assert "sxpath-3#21" [ a: sxp/compile [#...] a tree ] '== expected

    ; Location path, full form: ancestor::div 
    ; Location path, abbreviated form: _none_
    ; selects all div ancestors of the context node
    ; This Location expression is equivalent to the following:
    ;	/descendant-or-self::div[descendant::node() = curr_node]
    ; This shows that the ancestor:: axis is actually redundant. Still,
    ; it can be emulated as the following SXPath expression demonstrates.

    ; The insight behind "ancestor::div" -- selecting all "div" ancestors
    ; of the current node -- is
    ;  S[ancestor::div] context_node =
    ;    { y | y=subnode*(root), context_node=subnode(subnode*(y)),
    ;          isElement(y), name(y) = "div" }
    ; We observe that
    ;    { y | y=subnode*(root), pred(y) }
    ; can be expressed in SXPath as 
    ;    ((node-or (node-self pred) (node-closure pred)) root-node)
    ; The composite predicate 'isElement(y) & name(y) = "div"' corresponds to 
    ; (node-self (node-typeof? 'div)) in SXPath. Finally, filter
    ; context_node=subnode(subnode*(y)) is tantamount to
    ; (node-closure (node-eq? context-node)), whereas node-reduce denotes the
    ; the composition of converters-predicates in the filtering context.
    root: [div 
        [_ [name "elem"] [id "idz"]] 
        [para [_] "para"] 
        [br [_]] 
        "cdata" 
        [para [_] "second par"]
        [div [_ [name "aa"]] [para [_] "third para"]]
    ]
    expected: compose/only [ (root) (root/7) ]
    a: sxp/nodes-closure?? sxp/node-equal?? "third para"
    context-node: sxml/as-node-or-set a root                            ; select context node using descendant axis
    assert "sxpath-3#22" compose/deep/only [
        a: sxp/nodes-closure??/with-self sxp/nodes-reduce?? [
            [ sxp/select-oneself?? sxp/node-type?? 'div ]              ; div node
            [ sxp/nodes-closure?? sxp/node-same?? (context-node) ]     ; with context-node as descendant
        ]
        a root
    ] '== expected

    ; Location path, full form: child::div/descendant::para 
    ; Location path, abbreviated form: div//para
    ; selects the para element descendants of the div element
    ; children of the context node
    tree: [elem [_ [name "elem"] [id "idz"]]
        [para [_] "para"]
        [br [_]] 
        "cdata"
        [para "second par"]
        [div [_ [name "aa"]]
            [para [_] "third para"]
            [div [para "fourth para"]]
        ]
    ]
    expected: [[para [_] "third para"] [para "fourth para"]]
    assert "sxpath-3#23" [
        a: sxp/nodes-join?? [
            [ sxp/select-children?? sxp/node-type?? 'div ]
            [ sxp/nodes-closure?? sxp/node-type?? 'para ]
        ]
        a tree
    ] '== expected
    assert "sxpath-3#24" [ a: sxp/compile [div #... para] a tree ] '== expected

    ; Location path, full form: /descendant::olist/child::item 
    ; Location path, abbreviated form: //olist/item
    ; selects all the item elements that have an olist parent (which is not root)
    ; and that are in the same document as the context node
    ; See the following test.

    ; Location path, full form: /descendant::td/attribute::align 
    ; Location path, abbreviated form: //td/@align
    ; Selects 'align' attributes of all 'td' elements in tree1
    tree: tree1
    expected: [[align "right"] [align "center"] [align "center"] [align "center"]]
    assert "sxpath-3#25" [
        a: sxp/nodes-join?? [
            [ sxp/nodes-closure?? sxp/node-type?? 'td ]
            [ sxp/select-children?? sxp/node-type?? '_ ]
            [ sxp/select-children?? sxp/node-type?? 'align ]
        ]
        a tree
    ] '== expected
    assert "sxpath-3#26" [ a: sxp/compile [#... td _ align] a tree ] '== expected

    ; Location path, full form: /descendant::td[attribute::align] 
    ; Location path, abbreviated form: //td[@align]
    ; Selects all td elements that have an attribute 'align' in tree1
    tree: tree1
    expected: [[td [_ [align "right"]] "Talks "] [td [_ [align "center"]] " = "]
        [td [_ [align "center"]] " = "] [td [_ [align "center"]] " = "]]
    assert "sxpath-3#27" [
        a: sxp/nodes-reduce?? [
            [ sxp/nodes-closure?? sxp/node-type?? 'td ]
            [ 
                sxp/keep-match?? sxp/nodes-join?? [
                    [ sxp/select-children?? sxp/node-type?? '_ ]
                    [ sxp/select-children?? sxp/node-type?? 'align ]
                ]
            ]
        ]
        a tree
    ] '== expected
    assert "sxpath-3#28" [
        a: sxp/compile compose [#... td ( sxp/select-oneself?? sxp/compile [_ align] ) ]
        a tree
    ] '== expected
    assert "sxpath-3#28-2" [ a: sxp/compile [ [#... td [_ align]]] a tree ] '== expected
    assert "sxpath-3#29" [ a: sxp/compile [#... [td [_ align]]] a tree ] '== expected
    assert "sxpath-3#30" [ a: sxp/compile [#... [[td] [_ align]]] a tree ] '== expected

    ; note! (sxpath ...) is a converter. Therefore, it can be used
    ; as any other converter, for example, in the full-form SXPath.
    ; Thus we can mix the full and abbreviated form SXPath's freely.
    assert "sxpath-3#31" [ 
        a: sxp/nodes-reduce?? [
            [ sxp/nodes-closure?? sxp/node-type?? 'td ]
            [ sxp/keep-match?? sxp/compile [_ align] ]]
        a tree
    ] '== expected

    ; Location path, full form: /descendant::td[attribute::align = "right"] 
    ; Location path, abbreviated form: //td[@align = "right"]
    ; Selects all td elements that have an attribute align = "right" in tree1
    tree: tree1
    expected:  [[td [_ [align "right"]] "Talks "]]
    assert "sxpath-3#32" [
        a: sxp/nodes-reduce?? [
            [ sxp/nodes-closure?? sxp/node-type?? 'td ]
            [ sxp/keep-match?? sxp/nodes-join??
                [
                    [ sxp/select-children?? sxp/node-type?? '_ ]
                    [ sxp/select-children?? sxp/node-equal?? [align "right"] ]
                ]
            ]
        ]
        a tree
    ] '== expected
    assert "sxpath-3#33" [ a: sxp/compile [#... [td [_ [#equal? [align "right"]]]]] a tree ] '== expected

    ; Location path, full form: child::para[position()=1] 
    ; Location path, abbreviated form: para[1]
    ; selects the first para child of the context node
    tree: [elem [_ [name "elem"] [id "idz"]]
        [para [_] "para"] [br [_]] "cdata" [para "second par"]
        [div [_ [name "aa"]] [para [_] "third para"]]]
    expected: [[para [_] "para"]]
    assert "sxpath-3#34" [
        a: sxp/nodes-reduce?? [
            [ sxp/select-children?? sxp/node-type?? 'para ]
            [ sxp/nodes-pos?? 1 ]
        ]
        a tree
    ] '== expected
    assert "sxpath-3#35" [ a: sxp/compile [[para 1]] a tree ] '== expected

    ; Location path, full form: child::para[position()=last()] 
    ; Location path, abbreviated form: para[last()]
    ; selects the last para child of the context node
    tree: [elem [_ [name "elem"] [id "idz"]]
        [para [_] "para"] [br [_]] "cdata" [para "second par"]
        [div [_ [name "aa"]] [para [_] "third para"]]]
    expected: [[para "second par"]]
    assert "sxpath-3#36" [
        a: sxp/nodes-reduce?? [
            [ sxp/select-children?? sxp/node-type?? 'para ]
            [ sxp/nodes-pos?? -1 ]
        ]
        a tree
    ] '== expected
    assert "sxpath-3#37" [ a: sxp/compile [[para -1]] a tree ] '== expected

    ; Illustrating the following Note of Sec 2.5 of XPath:
    ; "NOTE: The location path //para[1] does not mean the same as the
    ; location path /descendant::para[1]. The latter selects the first
    ; descendant para element; the former selects all descendant para
    ; elements that are the first para children of their parents."
    tree: [elem [_ [name "elem"] [id "idz"]]
        [para [_] "para"] [br [_]] "cdata" [para "second par"]
        [div [_ [name "aa"]] [para [_] "third para"]]]
    expected: [[para [_] "para"]]
    assert "sxpath-3#38" [
        a: sxp/nodes-reduce?? [
            [ sxp/nodes-closure?? sxp/node-type?? 'para ]
            [ sxp/nodes-pos?? 1 ]
        ]
        a tree
    ] '== expected
    expected: [[para [_] "para"] [para [_] "third para"]]
    assert "sxpath-3#39" [ a: sxp/compile [#... [para 1]] a tree ] '== expected

    ; Location path, full form: parent::node()
    ; Location path, abbreviated form: ..
    ; selects the parent of the context node. The context node may be
    ; an attribute node!
    ; For the last test:
    ; Location path, full form: parent::*/attribute::name
    ; Location path, abbreviated form: ../@name
    ; Selects the name attribute of the parent of the context node
    tree: [elem [_ [name "elem"] [id "idz"]]
            [para [_] "para"] [br [_]] "cdata" [para "second par"]
            [div [_ [name "aa"]] [para [_] "third para"]]]
    para1: (a: sxp/compile [para] b: a tree b/1) ; the first para node
    para3: (a: sxp/compile [div para] b: a tree b/1) ; the third para node
    div: (a: sxp/compile [#... div] b: a tree b/1) ; div node
    attr: (a: sxp/compile [_ name] a div)
    assert "sxpath-3#40" [
        a: sxp/node-parent?? tree 
        sxml/as-node-or-set a para1
    ] '== tree
    assert "sxpath-3#41" [
        a: sxp/node-parent?? tree 
        sxml/as-node-or-set a para3
    ] '== div
    assert "sxpath-3#42" [
        a: sxp/node-parent?? tree 
        sxml/as-node-or-set a attr
    ] '== div
    assert "sxpath-3#43" [
        a: sxp/nodes-join?? [
            [ sxp/node-parent?? tree ]
            [ sxp/select-children?? sxp/node-type?? '_ ]
            [ sxp/select-children?? sxp/node-type?? 'name ]
        ]
        sxml/as-node-or-set a para3
    ] '== [name "aa"]
    assert "sxpath-3#44" [
        a: sxp/compile compose [
            (sxp/node-parent?? tree) _ name 
        ]
        sxml/as-node-or-set a para3
    ] '== [name "aa"]

    ; Location path, full form: following-sibling::chapter[position()=1]
    ; Location path, abbreviated form: none
    ; selects the next chapter sibling of the context node
    ; The path is equivalent to
    ;  let cnode = context-node
    ;    in
    ;	parent::* / child::chapter [take-after node_eq(self::*,cnode)] 
    ;		[position()=1]
    tree: [document
        [preface "preface"]
        [chapter [_ [id "one"]] "Chap 1 text"]
        [chapter [_ [id "two"]] "Chap 2 text"]
        [chapter [_ [id "three"]] "Chap 3 text"]
        [chapter [_ [id "four"]] "Chap 4 text"]
        [epilogue "Epilogue text"]
        [appendix [_ [id "A"]] "App A text"]
        [References "References"]
    ]
    a: sxp/compile [#... [chapter [_ [#equal? [id "two"]]]]]
    a-node:	sxml/as-node-or-set a tree
    expected: [[ chapter [_ [id "three"]] "Chap 3 text" ]]
    assert "sxpath-3#45" [
        a: sxp/nodes-reduce?? 
        [
            [ 
                sxp/nodes-join??
                [
                    [ sxp/node-parent?? tree ]
                    [ sxp/select-children?? sxp/node-type?? 'chapter ]
                ]
            ]
            [ sxp/keep-after-match?? sxp/node-same?? a-node ]
            [ sxp/nodes-pos?? 1 ]
        ]
        a a-node
    ] '== expected

    ; preceding-sibling::chapter[position()=1]
    ; selects the previous chapter sibling of the context node
    ; The path is equivalent to
    ;  let cnode = context-node
    ;    in
    ;	parent::* / child::chapter [take-until node_eq(self::*,cnode)] 
    ;		[position()=-1]
    tree: [document
        [preface "preface"]
        [chapter [_ [id "one"]] "Chap 1 text"]
        [chapter [_ [id "two"]] "Chap 2 text"]
        [chapter [_ [id "three"]] "Chap 3 text"]
        [chapter [_ [id "four"]] "Chap 4 text"]
        [epilogue "Epilogue text"]
        [appendix [_ [id "A"]] "App A text"]
        [References "References"]
    ]
    a: sxp/compile [#... [chapter [_ [#equal? [id "three"]]]]]
    a-node:	sxml/as-node-or-set a tree
    expected: [[chapter [_ [id "two"]] "Chap 2 text"]]
    assert "sxpath-3#46" [
        a: sxp/nodes-reduce?? 
        [
            [ 
                sxp/nodes-join??
                [
                    [ sxp/node-parent?? tree ]
                    [ sxp/select-children?? sxp/node-type?? 'chapter ]
                ]
            ]
            [ sxp/keep-until-match?? sxp/node-same?? a-node ]
            [ sxp/nodes-pos?? -1 ]
        ]
        a a-node
    ] '== expected

    ; /descendant::figure[position()=42]
    ; selects the forty-second figure element in the document
    ; See the next example, which is more general.

    ; Location path, full form:
    ;    child::table/child::tr[position()=2]/child::td[position()=3] 
    ; Location path, abbreviated form: table/tr[2]/td[3]
    ; selects the third td of the second tr of the table
    a: sxp/nodes-closure?? sxp/node-type?? 'p 
    tree: a tree1
    expected: [[td " data + control"]]
    assert "sxpath-3#47" [
        a: sxp/nodes-join?? 
        [
            [ sxp/select-children?? sxp/node-type?? 'table ]
            [ sxp/nodes-reduce?? 
                [
                    [ sxp/select-children?? sxp/node-type?? 'tr ]
                    [ sxp/nodes-pos?? 2 ]
                ]
            ]
            [ sxp/nodes-reduce??
                [
                    [ sxp/select-children?? sxp/node-type?? 'td ]
                    [ sxp/nodes-pos?? 3 ]
                ]
            ]
        ]
        a tree
    ] '== expected
    assert "sxpath-3#48" [ a: sxp/compile [table [tr 2] [td 3]] a tree ] '== expected

    ; Location path, full form:
    ;		child::para[attribute::type='warning'][position()=5] 
    ; Location path, abbreviated form: para[@type='warning'][5]
    ; selects the fifth para child of the context node that has a type
    ; attribute with value warning
    tree: [chapter
        [para "para1"]
        [para [_ [type "warning"]] "para 2"]
        [para [_ [type "warning"]] "para 3"]
        [para [_ [type "warning"]] "para 4"]
        [para [_ [type "warning"]] "para 5"]
        [para [_ [type "warning"]] "para 6"]
    ]
    expected: [[para [_ [type "warning"]] "para 6"]]
    assert "sxpath-3#49" [
        a: sxp/nodes-reduce?? 
        [
            [ sxp/select-children?? sxp/node-type?? 'para ]
            [ sxp/keep-match??
                sxp/nodes-join?? [
                    [ sxp/select-children?? sxp/node-type?? '_ ]
                    [ sxp/select-children?? sxp/node-equal?? [type "warning"] ]
                ]
            ]
            [ sxp/nodes-pos?? 5 ]
        ]
        a tree
    ] '== expected
    assert "sxpath-3#50" [
        a: sxp/compile [ [[[para [_ [#equal? [type "warning"]]]]] 5 ]]
        a tree
    ] '== expected
    assert "sxpath-3#51" [
        a: sxp/compile [[para [_ [#equal? [type "warning"]]] 5 ]]
        a tree
    ] '== expected

    ; Location path, full form:
    ;		child::para[position()=5][attribute::type='warning'] 
    ; Location path, abbreviated form: para[5][@type='warning']
    ; selects the fifth para child of the context node if that child has a 'type'
    ; attribute with value warning
    tree: [chapter
        [para "para1"]
        [para [_ [type "warning"]] "para 2"]
        [para [_ [type "warning"]] "para 3"]
        [para [_ [type "warning"]] "para 4"]
        [para [_ [type "warning"]] "para 5"]
        [para [_ [type "warning"]] "para 6"]
    ]
    expected: [[para [_ [type "warning"]] "para 5"]]
    assert "sxpath-3#52" [
        a: sxp/nodes-reduce?? 
        [
            [ sxp/select-children?? sxp/node-type?? 'para ]
            [ sxp/nodes-pos?? 5 ]
            [ sxp/keep-match??
                sxp/nodes-join?? [
                    [ sxp/select-children?? sxp/node-type?? '_ ]
                    [ sxp/select-children?? sxp/node-equal?? [type "warning"] ]
                ]
            ]
        ]
        a tree
    ] '== expected
    assert "sxpath-3#53" [
        a: sxp/compile [ [[[para 5]] [_ [#equal? [type "warning"]]]]]
        a tree
    ] '== expected
    assert "sxpath-3#54" [
        a: sxp/compile [[para 5 [_ [#equal? [type "warning"]]]]]
        a tree
    ] '== expected

    ; Location path, full form:
    ;		child::*[self::chapter or self::appendix]
    ; Location path, semi-abbreviated form: *[self::chapter or self::appendix]
    ; selects the chapter and appendix children of the context node
    tree: [document
        [preface "preface"]
        [chapter [_ [id "one"]] "Chap 1 text"]
        [chapter [_ [id "two"]] "Chap 2 text"]
        [chapter [_ [id "three"]] "Chap 3 text"]
        [epilogue "Epilogue text"]
        [appendix [_ [id "A"]] "App A text"]
        [References "References"]
    ]
    expected: [[chapter [_ [id "one"]] "Chap 1 text"]
        [chapter [_ [id "two"]] "Chap 2 text"]
        [chapter [_ [id "three"]] "Chap 3 text"]
        [appendix [_ [id "A"]] "App A text"]
    ]
    assert "sxpath-3#55" [
        a: sxp/nodes-join?? 
        [
            [ sxp/select-children?? sxp/node-type?? '*element* ]
            [ sxp/keep-match??
                sxp/nodes-or?? [
                    [ sxp/select-oneself?? sxp/node-type?? 'chapter ]
                    [ sxp/select-oneself?? sxp/node-type?? 'appendix ]
                ]
            ]
        ]
        a tree
    ] '== expected
    assert "sxpath-3#56" [
        a: sxp/compile 
        compose [*element* ( 
            sxp/nodes-or?? [
                [ sxp/select-oneself?? sxp/node-type?? 'chapter ]
                [ sxp/select-oneself?? sxp/node-type?? 'appendix ]
            ]
        )
        ]
        a tree
    ] '== expected

    ; Location path, full form: child::chapter[child::title='Introduction'] 
    ; Location path, abbreviated form: chapter[title = 'Introduction']
    ; selects the chapter children of the context node that have one or more
    ; title children with string-value equal to Introduction
    ; See a similar example: //td[@align = "right"] above.

    ; Location path, full form: child::chapter[child::title] 
    ; Location path, abbreviated form: chapter[title]
    ; selects the chapter children of the context node that have one or
    ; more title children
    ; See a similar example //td[@align] above.
    print ["Example with tree3: extracting the first lines of every stanza"]
    tree: tree3
    expected: ["Let us go then, you and I," "In the room the women come and go"]
    assert "sxpath-3#57" [
        a: sxp/nodes-join?? 
        [
            [ sxp/nodes-closure?? sxp/node-type?? 'stanza ]
            [ 
              sxp/nodes-reduce??
                [
                    [ sxp/select-children?? sxp/node-type?? 'line ]
                    [ sxp/nodes-pos?? 1 ]
                ]
            ]
            [ sxp/select-children?? sxp/node-type?? '*text* ]
        ]
        a tree
    ] '== expected
    assert "sxpath-3#58" [
        a: sxp/compile [#... stanza [line 1] *text*]
        a tree
    ] '== expected

]; run-sxpath-3

]; test-sxpath

test-sxpath/run-sxpath-1
test-sxpath/run-sxpath-2
test-sxpath/run-sxpath-3


Red [
	Title:          "SXPATH"
    File:           %sxpath.red
	Description:    "XPATH implementation for SXML"
	Author:         @zwortex
    Date:           2021-09-09
	Notes: {
        See : SXPath by Oleg Kiselyov and Kirill Lisovsky
        http://okmij.org/ftp/Scheme/xml.html#SXPath
        http://okmij.org/ftp/Scheme/lib/SXPath.scm
	}
]

#include %sxml.red

sxpath: context [

    debug: false

    ;
    ; Compile an sxpath and returns the function that implements it
    ; and that should be run against the sxml node tree to search
    ;
    ; Sxpath performs the following recursive transformations to turn the original sxpath 
    ; into a suite of sxpath primitives :
    ;
    ; sxpath [] ⇒ nodes-join
    ; sxpath [ step1 subsequent-steps ] ⇒ nodes-join?? (sxpath step1) (sxpath subsequent-steps)
    ; sxpath '// ⇒ descendant-or-self?? :node?
    ; sxpath [#equal? x] ⇒ select-children?? node-equal?? x
    ; sxpath [#same? x] ⇒ select-children?? node-same?? x
    ; sxpath [#or …] => select-children?? node-name?? […]
    ; sxpath [#not …] => select-children?? node-complement?? node-name?? […]
    ; sxpath [#ns-id x] ⇒ select-children?? node-namespace?? x
    ; sxpath word ⇒ select-children?? node-type?? word
    ; sxpath string ⇒ txpath string
    ; sxpath any-function ⇒ :any-function
    ; sxpath [word …] ⇒ sxpath (:word …)
    ; sxpath [path reducer …] ⇒ node-reduce (sxpath path) (sxpathr reducer) …
    ; reducer: number ⇒ node-pos number
    ; reducer: path-filter ⇒ filter (sxpath path-filter)
    ;

    compile: function [
        expr [block!]
        return: [function! none!]
        /namespaces ns-binding
    ][
        parse expr block-rules/main
        b: block-rules/xpath
        if debug [
            print "XPATH Generated"
            probe b
        ]
        either b [
            xp: compose/deep [
                if debug [ print ">xpath" ]
                f: [ (b) ]
                f: do f
                nodes: f nodes
                if debug [ print "<xpath" ]
                nodes
            ]
            fp: function [ nodes ] xp
            if debug [
                print "XPATH"
                probe :fp
            ]
            :fp
        ][
            none
        ]
    ]

    ;
    ; Parse function used - default to standard parse function
    ;
    parse-function: :system/words/parse

    ;; Parse rules for processing xpath block format
    block-rules: context [

        ; variables used in path rules to store local items
        =test: =op: =value: =str: =names: =w: =pos: none
        p: f: g: none

        ; final xpath
        xpath: none

        ; selector and filters
        selector: none
        filters: copy []

        ; chain of converters as it is being built
        converters: copy []

        ; contexts saved when multiple calls to sxpath are made
        contexts: copy []

        ; namespaces binding - key: namespace id - value: namespace value
        namespaces: #()

        ; main rule
        main: [
            (
                clear converters
                xpath: none
            )
            some step
            (
                case [
                    1 == length? converters [
                        xpath: converters/1
                    ]
                    1 < length? converters [
                        xpath: compose/deep [
                            nodes-join?? [ (converters) ]
                        ]
                    ]
                ]
            )
        ]

        ; one-step
        one-step: [
            (
                clear converters
                xpath: none
            )
            step
            (
                case [
                    1 == length? converters [
                        xpath: converters/1
                    ]
                    1 < length? converters [
                        xpath: copy converters
                    ]
                ]
            )
        ]

        ; path is made of sereral steps
        step: [
            descendant
            | op
            | logic
            | string
            | type
            | proc
            | filter
            | end
            | error
        ]

        ; error
        error: [
            p:
            ( 
                print [ "Invalid path step" mold p ]
            )
        ]

        ; descendant operator
        descendant: [
            ( =test: none )
            #... [
                [ end | not word! | ahead '_ ] 
                |
                copy =test [ word! | tag! ]
            ]
            (
                either not =test [
                    append/only converters [ 
                        nodes-closure??/with-self :sxml/any?
                    ]
                ][
                    append/only converters compose [
                        nodes-closure?? node-type?? (either word? =test/1 [to-lit-word =test/1][=test/1])
                    ]
                ]
            )
        ]

        op: [
            [
                copy =op [ #equal? | #same? ]
                copy =value any-type!
                | 
                copy =op #ns-id copy =value [ word! | tag! ]
            ]
            (
                =op: switch =op/1 [
                    #equal? [ 'node-equal?? ]
                    #same? [ 'node-same?? ]
                    #ns-id [ 'node-namespace?? ]
                ]
                =value: (either word? =value/1 [to-lit-word =value/1][=value/1])
                append/only converters compose/only [ 
                    select-children?? (=op) (=value)
                ]
            )
        ]

        string: [
            copy =str string!
            (
                g: txpath =str namespaces
                append/only converters compose [ 
                    ( :g )
                ]
            )
        ]

        logic: [
            copy =op [ #or | #not ] 
            copy =names into [ some [ word! | url! ] ] 
            (
                =op: switch =op/1 [
                    #or [ compose [ node-name?? (=names) ] ]
                    #not [ compose [ node-complement?? node-name?? (=names) ] ]
                ]
                append/only converters compose [ 
                    select-children?? (=op)
                ]
            )
        ]

        type: [
            ahead copy =w [ word! | url! ] if ( not any-function? get/any =w/1 ) skip
            (
                append/only converters compose [
                    select-children?? node-type?? (either word? =w/1 [to-lit-word =w/1][=w/1])
                ]
            )
        ]

        proc: [
            ahead copy =w [ word! | path! ] if ( any-function? get/any =w/1 ) skip
            (
                append/only converters compose/deep [
                    function [ nodes ] [
                        nodes: ( =w/1 ) nodes 
                    ]
                ]
            )
            |
            copy =f [ function! ] 
            (
                append/only converters compose/deep [
                    function [ nodes ] [
                        f: [ ( :=f/1 ) ]
                        f: :f/1
                        nodes: f nodes 
                    ]
                ]
            )
        ]

        filter: [
            ahead block!
            (
                selector: none
                clear filters
            )
            into [
                select-part
                any reducer-part
            ]
            (
                either empty? filters [
                    b: compose [
                        (selector) 
                    ]
                ][
                    b: compose/deep [
                        nodes-reduce?? [
                            [ (selector) ]
                            (filters)
                        ]
                    ]
                ]
                new-line b false
                b: compose/deep [
                    function [ nodes ][
                        f: (b)
                        nodes: sxml/as-node-set nodes
                        nodes: apply-and-join :f nodes
                        nodes
                    ]
                ]
                append/only converters b
            )
        ]

        select-part: [
            ahead copy =w [ word! | url! ] if ( not any-function? get/any =w/1 ) skip
            (
                selector: compose [ select-children?? node-type?? (either word? =w/1 [to-lit-word =w/1][=w/1]) ]
            )
            |
            [
                ( save-context )
                [ into main | one-step ]
                (
                    f: xpath
                    restore-context
                    selector: f
                )
                |
                ( restore-context )
            ]
        ]

        reducer-part: [
            copy =pos integer!
            (
                append/only filters compose [ nodes-pos?? ( =pos ) ]
            )
            |
            (
                save-context
            )
            one-step
            (
                f: xpath
                restore-context
                if f [
                    new-line f false
                    g: compose [
                        keep-match?? (f)
                    ]
                    append/only filters g
                ]
            )
        ]

        ;; Helper functions
        save-context: function [
            "Stores the context aside for processing a sub-xpath"
        ][
            c: reduce [ converters selector filters ]
            append/only contexts c
            self/converters: copy []
            self/selector: none
            self/filters: copy []
        ]

        restore-context: function [
            "Restores the previous context after a sub-xpath has been processed"
        ][
            c: take/last contexts
            self/converters: c/1
            self/selector: c/2
            self/filters: c/3
            self/xpath: none
        ]
    ]

    ;;
    ;; SXPATH primitives
    ;;

    true?: function [
        "True for a value, node or node-set"
        value [any-type!]
        return: [logic!]
    ][
        ; @ZWT error handling
        if unset? :value [
            do make error! "Unexpected value"
        ]
        res: false
        either sxml/node-set? value [
            if not empty? value [ res: true ]
        ][
            if value [ res: true ]
        ]
        return res
    ]

    ;;
    ;; Node tests - see XPath sec 2.3
    ;;

    node-name??: function [
        "Returns a function that test whether a node has a name among the given list"
        names [block!]
    ][
        function [ node ]
        compose/deep [
            if debug [ print "node-name??" ]
            either all [
                block? node
                any [ word? node/1 tag? node/1 url? node/1 ]
                f: find [ (names) ] node/1
                strict-equal? f/1 node/1 ; also same type? @ZWT
            ] [true][false]
        ]
    ]

    node-type??: function [
        { 
            Returns a function that tests whether a node is of a certain type

            Possible types are :
                _ : attributes or annotations
                *element* : any element (see element?)
                *any* : any node (element, attributes, text, comment, pi, entity)
                *data* : a data node (text, number, boolean, but not a list)
                *text* : any string
                *COMMENT* : any comment
                *PI* : any processing instructions
                *ENTITY* : any entity
                <word> : any element of that particular name
        }
        type [word! url! tag!]
        return: [function!]
    ][
        switch/default type [
            *element* [ :sxml/element? ]
            *any* [ function [node] [ true ] ]
            *data* [ function [node] [ not block? node ] ]
            *text* [ function [node] [ string? node ] ]
        ][
            function [node] 
            compose/deep [
                if debug [ print "node-type??" ]
                either all [ 
                    block? node
                    strict-equal? node/1 (either word? type [ to-lit-word type ][type])
                ][ true ] [ false ]
            ]
        ]
    ]

    node-namespace??: function [
        "Returns a function that test whether a node has a name of a given namespace"
        namespace-id [word! issue!] "The sxml namespace id"
    ][
        function [ node ] 
        compose/deep [
            if debug [ print "node-namespace??" ]
            either all [ 
                block? node
                node/1
                not select sxml/reserved-words node/1
                sxml/has-namespace? node/1 (
                    either word? namespace-id [
                        to-lit-word namespace-id
                    ][ namespace-id ]
                )
            ][ true ][ false ]
        ]
    ]

    node-complement??: function [
        { Returns a function that reverse the test result. }
        test [function!]
        return: [function!]
    ][
        function [node] 
        compose/deep [
            if debug [ print "node-complement??" ]
            res: none
            tst: [ ( :test ) ]
            tst: :tst/1
            set/any 'res tst node
            not true? :res
        ]
    ]

    node-equal??: function [
        "Returns a function that tests for node equality"
        value [any-type!]
        return: [function!]
    ][
        function [node] 
        compose/only [
            if debug [ print "node-equal??" ]
            equal? node (value)
        ]
    ]

    node-same??: function [
        "Returns a function that tests for node identity"
        value [any-type!]
        return: [function!]
    ][
        f: function [node] [
            if debug [ print "node-same??" ]
            same? node change-me
        ]
        g: body-of :f
        h: find g 'change-me
        h/1: value
        :f
    ]

    ;;
    ;; Tests on node-sets
    ;;
    nodes-pos??: function [
        "Returns a function that selects the nth node within a node list"
        pos [integer!] {If positive, nth node ; 
            if negative, position is relative to the last position 
            (-1 for the last node, -2 for the node prior to the last node)
            if 0 returns an empty set}
        return: [function!]
    ][
        b: case [
            pos > 0 [
                compose [
                    either n: pick nodes (pos) [
                        reduce [ n ]
                    ][
                        []
                    ]
                ]
            ]
            pos < 0 [
                compose [
                    p: add length? nodes (pos + 1)
                    either all [
                        p >= 1
                        n: pick nodes p
                    ][
                        reduce [ n ]
                    ][
                        []
                    ]
                ]
            ]
            true [ [[]] ]
        ]
        function [nodes] 
        compose [
            if debug [ print "nodes-pos??" ]
            if not nodes [ return nodes ]
            if not sxml/node-set? nodes [ return [] ]
            (b)
        ]
    ]

    keep-match??: function [
        "Returns a function that collects the nodes of node-set that satisfies the given test"
        test [function!]
        return: [function!]
    ][
        function [ nodes ]
        compose/deep [
            if debug [ print ">keep-match??" ]
            res: false
            t: [ ( :test ) ]
            tst: :t/1
            nodes: sxml/as-node-set nodes
            res: none
            c: collect [
                foreach node nodes [
                    set/any 'res tst node
                    if true? :res [
                        keep/only node
                    ]
                ]
            ]
            if debug [ print "<keep-match??" ]
            c
        ]
    ]

    keep-until-match??: function [
        "Returns a function that collects the nodes until the first matching node, that one excluded"
        test [function!]
        return: [block!]
    ][
        function [ nodes ]
        compose/deep [
            if debug [ print ">keep-until-match??" ]
            res: none
            t: [ ( :test ) ]
            tst: :t/1
            n: sxml/as-node-set nodes
            while [
                all [
                    not tail? n
                    any [
                        not set/any 'res tst n/1
                        not true? :res
                    ]
                ]
            ][
                n: next n
            ]
            c: either not tail? n [
                copy/part nodes n
            ][
                nodes
            ]
            if debug [ print "<keep-until-match??" ]
            c
        ]
    ]

    keep-after-match??: function [
        "Returns a function that collects the nodes that follow the first matching node, this one excluded"
        test [function!]
        return: [block!]
    ][
        function [ nodes ]
        compose/deep [
            if debug [ print ">keep-after-match??" ]
            res: none
            t: [ ( :test ) ]
            tst: :t/1
            n: sxml/as-node-set nodes
            while [
                all [
                    not tail? n
                    any [ 
                        not set/any 'res tst n/1
                        not true? :res
                    ]
                ]
            ][
                n: next n
            ]
            n: next n
            res: either tail? n [
                []
            ][
                n
            ]
            if debug [ print "<keep-after-match??" ]
            res
        ]
    ]

    apply-and-join: function [
        "Applies the proc function to each node of the node list and join the results"
        proc [function! native! action!]
        nodes [block!]
    ][
        if debug [ print ">apply-and-join" ]
        nodes: sxml/as-node-set nodes
        nodes: either empty? nodes [ nodes ][
            collect [
                foreach node nodes [
                    res: proc node
                    case [
                        not res [ ]
                        not block? res [ keep res ]
                        empty? res [ ]
                        sxml/node-set? res [ keep res ]
                        true [ keep/only res ]
                    ]
                ]
            ]
        ]
        if debug [ print "<apply-and-join" ]
        nodes
    ]

    reverse-nodes: function [
        "Reverse a node list result"
        nodes
    ][
        if debug [ print ">reverse-nodes" ]
        nodes: either sxml/node-set? nodes [
            reverse copy nodes
        ][
            reduce [ nodes ]
        ]
        if debug [ print "<reverse-nodes" ]
        nodes
    ]

    nodes-trace??: function [
        "Returns a function that outputs the given nodes to the console, and echo them for further processing"
        title [string!]
    ][
        function [ nodes ] 
        compose/deep [
            if debug [ print ">nodes-trace??" ]
            print [ "-->" (title) ":"]
            probe nodes
            if debug [ print "<nodes-trace??" ]
            nodes
        ]
    ]

    ;;
    ;; Combinators
    ;;
    select-children??: function [
        { Returns a function that selects the children nodes of a node set that satisfy the given filter }
        test [function!]
        return: [function!]
    ][
        function [ nodes ]
        compose/deep [
            if debug [ print ">select-children??" ]
            nodes: sxml/as-node-set nodes
            t: [ ( :test ) ]
            tst: :t/1
            c: collect [
                foreach parent nodes [
                    children: sxml/any-children-of parent
                    if children [
                        foreach node children [
                            res: tst node
                            if res [ 
                                keep/only node
                            ]
                        ]
                    ]
                ]
            ]
            if debug [ print "<select-children??" ]
            c
        ]
    ]

    select-first-children??: function [
        { Returns a function that selects the first children of a node set that satisfy the given filter }
        test [function!]
        return: [function!]
    ][
        function [ nodes ]
        compose/deep [
            if debug [ print ">select-first-children??" ]
            t: [ ( :test ) ]
            tst: :t/1
            c: collect [
                foreach parent sxml/as-node-set nodes [
                    children: sxml/content parent
                    if children [
                        foreach node children [
                            res: tst node
                            if res [
                                keep/only node
                                break
                            ]
                        ]
                    ]
                ]
            ]
            if debug [ print "<select-first-children??" ]
            c
        ]
    ]

    select-oneself??: function [
        "Returns a function that apply a test to each node"
        test [function!]
        return: [function!]
    ][
        keep-match?? :test
    ]

    nodes-join??: function [
        { 
            Returns a function that pipe multiple selectors
            First selector is applied on each node of a node set.
            Results are merged and become the new node set on which to apply
            the next selector.
        }
        selectors [ block! ]
        return: [ function! ]
    ][
        ; do possible blocks into functions
        selectors: copy selectors
        forall selectors [
            if block? :selectors/1 [
                poke selectors 1 do selectors/1
            ]
            if not function? :selectors/1 [
                print "Error in selectors - not a function"
                probe selectors/1
            ]
        ]
        function [ nodes ]
        compose/only [
            if debug [ print ">nodes-join??" ]
            sels: (selectors)
            foreach selector sels [
                either sxml/node-set? nodes [
                    nodes: apply-and-join :selector nodes
                ][
                    nodes: selector nodes
                ]
            ]
            if debug [ print "<nodes-join??" ]
            nodes
        ]
    ]

    nodes-reduce??: function [
        {
            Returns a function that chain multiple converters.
            First converter is applied on a node and the resulting node set
            becomes the entry point of the next converter, and so on until all
            converters have been applied.
        }
        converters [ block! ]
        return: [ function! ]
    ][
        converters: copy converters
        forall converters [
            if block? :converters/1 [
                poke converters 1 do converters/1
            ]
            if not function? :converters/1 [
                print "Error in converters - not a function"
                probe converters/1
            ]
        ]
        function [ nodes ]
        compose/only [
            if debug [ print ">nodes-reduce??" ]
            convs: (converters)
            foreach converter convs [
                nodes: converter nodes
            ]
            if debug [ print "<nodes-reduce??" ]
            nodes
        ]
    ]

    nodes-or??: function [
        {Returns a function that applies all converters to a node set 
        and keeps the union of the result - operator | }
        converters [block!]
        return: [function!]
    ][
        converters: copy converters
        forall converters [
            if block? :converters/1 [
                poke converters 1 do converters/1
            ]
            if not function? :converters/1 [
                print "Error in converters - not a function"
                probe converters/1
            ]
        ]
        function [ nodes ]
        compose/only [
            if debug [ print ">nodes-or??" ]
            convs: ( converters )
            c: collect [
                foreach converter convs [
                    n: converter nodes
                    either n [
                        either sxml/node-set? n [
                            keep n
                        ][
                            keep/only n
                        ]
                    ][
                        keep copy []
                    ]
                ]
            ]
            if debug [ print "<nodes-or??" ]
            c
        ]
    ]

    nodes-closure??: function [
        { Returns a function that selects the children, and the descendants of a node-set 
        that satisfy the given test }
        test [function!]
        return: [block!]
        /with-self "Add self as well"
    ][
        function [ nodes ]
        compose/deep [
            if debug [ print ">nodes-closure??" ]
            res: none
            f: [ ( :test ) ]
            f: :f/1
            nodes: sxml/as-node-set nodes
            descendants: apply-and-join (
                either with-self [ quote :sxml/descendants-or-self ][ quote :sxml/descendants-of ]
            ) nodes
            c: collect [
                foreach node descendants [
                    set/any 'res f node
                    if true? :res [
                        keep/only node
                    ]
                ]
            ]
            if debug [ print "<nodes-closure??" ]
            c
        ]
    ]

    ; Attribute axis
    attributes??: function [
        "Returns a function that selects among the attributes of a node set"
        test [ function! ]
        return: [ function! ]
    ][
        function [ nodes ]
        compose/deep [
            if debug [ print ">attributes??" ]
            c: collect [
                foreach node sxml/as-node-set nodes [
                    if sxml/element? node [
                        attrs: sxml/attributes-of node
                        if attrs [
                            foreach attr attrs [
                                res: (:test) attr
                                if res [ 
                                    keep/only attr
                                ]
                            ]
                        ]
                    ]
                ]
            ]
            if debug [ print "<attributes??" ]
            c
        ]
    ]

    ; Child axis
    children??: function [
        "Returns a function that selects children of a node set that satisfy the given test"
        ; compared with select-children, children cannot be PI, Comment or Entity
        test [ function! ]
        return: [ function! ]
    ][
        function [ nodes ]
        compose/deep [
            if debug [ print ">children??" ]
            c: collect [
                tst: [ ( :test ) ]
                tst: :tst/1
                foreach parent sxml/as-node-set nodes [
                    foreach child sxml/children-of parent [
                        if any [
                            sxml/element? child 
                            sxml/text? child
                        ][
                            res: tst child
                            if res [
                                keep/only child
                            ]
                        ]
                    ]
                ]
            ]
            if debug [ print "<children??" ]
            c
        ]
    ]

    ; Parent axis
    parent??: function [
        "Returns a function that selects the parent of a node"
        root [ block! ]
        test [ function! ]
        return: [ function! ]
    ][
        f: function [ nodes ]
        compose/deep [
            if debug [ print ">parent??" ]
            root: root-to-set
            ts: [ (:test) ]
            tst: keep-match?? :ts/1
            result: copy []
            either sxml/node-set? nodes [
                tbl: copy nodes
            ][
                tbl: copy []
                append/only tbl nodes
            ]
            _parents root tbl result
            result: tst result
            if debug [ print "<parent??" ]
            result
        ]
        ; set manually the root node
        g: body-of :f
        h: find g 'root-to-set
        h/1: root
        :f
    ]

    _parents: function [
        "Search for parents of nodes within a node set. Also match attribute node."
        root nodes result 
    ][
        ; search attributes
        attributes: sxml/attributes-of root
        if attributes [
            foreach a attributes [
                if f: find/only/same nodes a [
                    append/only result root
                    remove f
                    if empty? nodes [ exit ]
                ]
            ]
        ]
        ; search elements
        children: sxml/children-of root
        if children [
            foreach c children [
                if f: find/only/same nodes c [
                    append/only result root
                    remove f
                    if empty? nodes [ exit ]
                ]
                if sxml/has-children? c [
                    _parents c nodes result
                ]
            ]
        ]
    ]

    node-parent??: function [
        "Returns a function that selects the node parents of nodes within a nodeset"
        root [ block! ]
        return: [function!]
    ][
        parent?? root node-type?? '*any*
    ]

    child-nodes??: function [
         "Returns a function that selects the node parents of nodes within a nodeset"
        return: [function!]
    ][
        select-children?? :sxml/node?
    ]

    child-elements??: function [
         "Returns a function that selects the node parents of nodes within a nodeset"
        return: [function!]
    ][
        select-children?? :sxml/element?
    ]

    ;;
    ;; Parsing rules for string xpath - PENDING
    ;;
    string-rules: context [

        ;
        ; Implements XPath parse rules as specified in https://www.w3.org/TR/xpath-31/
        ; version https://www.w3.org/TR/2017/REC-xpath-31-20170321/
        ;

        ; A.1 EBNF 
        ; [1]    	XPath 	   ::=    	Expr 	
        ; [2]    	ParamList 	   ::=    	Param ("," Param)* 	
        ; [3]    	Param 	   ::=    	"$" EQName TypeDeclaration? 	
        ; [4]    	FunctionBody 	   ::=    	EnclosedExpr 	
        ; [5]    	EnclosedExpr 	   ::=    	"{" Expr? "}" 	
        ; [6]    	Expr 	   ::=    	ExprSingle ("," ExprSingle)* 	
        ; [7]    	ExprSingle 	   ::=    	ForExpr
        ; | LetExpr
        ; | QuantifiedExpr
        ; | IfExpr
        ; | OrExpr 	
        ; [8]    	ForExpr 	   ::=    	SimpleForClause "return" ExprSingle 	
        ; [9]    	SimpleForClause 	   ::=    	"for" SimpleForBinding ("," SimpleForBinding)* 	
        ; [10]    	SimpleForBinding 	   ::=    	"$" VarName "in" ExprSingle 	
        ; [11]    	LetExpr 	   ::=    	SimpleLetClause "return" ExprSingle 	
        ; [12]    	SimpleLetClause 	   ::=    	"let" SimpleLetBinding ("," SimpleLetBinding)* 	
        ; [13]    	SimpleLetBinding 	   ::=    	"$" VarName ":=" ExprSingle 	
        ; [14]    	QuantifiedExpr 	   ::=    	("some" | "every") "$" VarName "in" ExprSingle ("," "$" VarName "in" ExprSingle)* "satisfies" ExprSingle 	
        ; [15]    	IfExpr 	   ::=    	"if" "(" Expr ")" "then" ExprSingle "else" ExprSingle 	
        ; [16]    	OrExpr 	   ::=    	AndExpr ( "or" AndExpr )* 	
        ; [17]    	AndExpr 	   ::=    	ComparisonExpr ( "and" ComparisonExpr )* 	
        ; [18]    	ComparisonExpr 	   ::=    	StringConcatExpr ( (ValueComp
        ; | GeneralComp
        ; | NodeComp) StringConcatExpr )? 	
        ; [19]    	StringConcatExpr 	   ::=    	RangeExpr ( "||" RangeExpr )* 	
        ; [20]    	RangeExpr 	   ::=    	AdditiveExpr ( "to" AdditiveExpr )? 	
        ; [21]    	AdditiveExpr 	   ::=    	MultiplicativeExpr ( ("+" | "-") MultiplicativeExpr )* 	
        ; [22]    	MultiplicativeExpr 	   ::=    	UnionExpr ( ("*" | "div" | "idiv" | "mod") UnionExpr )* 	
        ; [23]    	UnionExpr 	   ::=    	IntersectExceptExpr ( ("union" | "|") IntersectExceptExpr )* 	
        ; [24]    	IntersectExceptExpr 	   ::=    	InstanceofExpr ( ("intersect" | "except") InstanceofExpr )* 	
        ; [25]    	InstanceofExpr 	   ::=    	TreatExpr ( "instance" "of" SequenceType )? 	
        ; [26]    	TreatExpr 	   ::=    	CastableExpr ( "treat" "as" SequenceType )? 	
        ; [27]    	CastableExpr 	   ::=    	CastExpr ( "castable" "as" SingleType )? 	
        ; [28]    	CastExpr 	   ::=    	ArrowExpr ( "cast" "as" SingleType )? 	
        ; [29]    	ArrowExpr 	   ::=    	UnaryExpr ( "=>" ArrowFunctionSpecifier ArgumentList )* 	
        ; [30]    	UnaryExpr 	   ::=    	("-" | "+")* ValueExpr 	
        ; [31]    	ValueExpr 	   ::=    	SimpleMapExpr 	
        ; [32]    	GeneralComp 	   ::=    	"=" | "!=" | "<" | "<=" | ">" | ">=" 	
        ; [33]    	ValueComp 	   ::=    	"eq" | "ne" | "lt" | "le" | "gt" | "ge" 	
        ; [34]    	NodeComp 	   ::=    	"is" | "<<" | ">>" 	
        ; [35]    	SimpleMapExpr 	   ::=    	PathExpr ("!" PathExpr)* 	
        ; [36]    	PathExpr 	   ::=    	("/" RelativePathExpr?)
        ; | ("//" RelativePathExpr)
        ; | RelativePathExpr 	/* xgc: leading-lone-slash */
        ; [37]    	RelativePathExpr 	   ::=    	StepExpr (("/" | "//") StepExpr)* 	
        ; [38]    	StepExpr 	   ::=    	PostfixExpr | AxisStep 	
        ; [39]    	AxisStep 	   ::=    	(ReverseStep | ForwardStep) PredicateList 	
        ; [40]    	ForwardStep 	   ::=    	(ForwardAxis NodeTest) | AbbrevForwardStep 	
        ; [41]    	ForwardAxis 	   ::=    	("child" "::")
        ; | ("descendant" "::")
        ; | ("attribute" "::")
        ; | ("self" "::")
        ; | ("descendant-or-self" "::")
        ; | ("following-sibling" "::")
        ; | ("following" "::")
        ; | ("namespace" "::") 	
        ; [42]    	AbbrevForwardStep 	   ::=    	"@"? NodeTest 	
        ; [43]    	ReverseStep 	   ::=    	(ReverseAxis NodeTest) | AbbrevReverseStep 	
        ; [44]    	ReverseAxis 	   ::=    	("parent" "::")
        ; | ("ancestor" "::")
        ; | ("preceding-sibling" "::")
        ; | ("preceding" "::")
        ; | ("ancestor-or-self" "::") 	
        ; [45]    	AbbrevReverseStep 	   ::=    	".." 	
        ; [46]    	NodeTest 	   ::=    	KindTest | NameTest 	
        ; [47]    	NameTest 	   ::=    	EQName | Wildcard 	
        ; [48]    	Wildcard 	   ::=    	"*"
        ; | (NCName ":*")
        ; | ("*:" NCName)
        ; | (BracedURILiteral "*") 	/* ws: explicit */
        ; [49]    	PostfixExpr 	   ::=    	PrimaryExpr (Predicate | ArgumentList | Lookup)* 	
        ; [50]    	ArgumentList 	   ::=    	"(" (Argument ("," Argument)*)? ")" 	
        ; [51]    	PredicateList 	   ::=    	Predicate* 	
        ; [52]    	Predicate 	   ::=    	"[" Expr "]" 	
        ; [53]    	Lookup 	   ::=    	"?" KeySpecifier 	
        ; [54]    	KeySpecifier 	   ::=    	NCName | IntegerLiteral | ParenthesizedExpr | "*" 	
        ; [55]    	ArrowFunctionSpecifier 	   ::=    	EQName | VarRef | ParenthesizedExpr 	
        ; [56]    	PrimaryExpr 	   ::=    	Literal
        ; | VarRef
        ; | ParenthesizedExpr
        ; | ContextItemExpr
        ; | FunctionCall
        ; | FunctionItemExpr
        ; | MapConstructor
        ; | ArrayConstructor
        ; | UnaryLookup 	
        ; [57]    	Literal 	   ::=    	NumericLiteral | StringLiteral 	
        ; [58]    	NumericLiteral 	   ::=    	IntegerLiteral | DecimalLiteral | DoubleLiteral 	
        ; [59]    	VarRef 	   ::=    	"$" VarName 	
        ; [60]    	VarName 	   ::=    	EQName 	
        ; [61]    	ParenthesizedExpr 	   ::=    	"(" Expr? ")" 	
        ; [62]    	ContextItemExpr 	   ::=    	"." 	
        ; [63]    	FunctionCall 	   ::=    	EQName ArgumentList 	/* xgc: reserved-function-names */
        ; 				/* gn: parens */
        ; [64]    	Argument 	   ::=    	ExprSingle | ArgumentPlaceholder 	
        ; [65]    	ArgumentPlaceholder 	   ::=    	"?" 	
        ; [66]    	FunctionItemExpr 	   ::=    	NamedFunctionRef | InlineFunctionExpr 	
        ; [67]    	NamedFunctionRef 	   ::=    	EQName "#" IntegerLiteral 	/* xgc: reserved-function-names */
        ; [68]    	InlineFunctionExpr 	   ::=    	"function" "(" ParamList? ")" ("as" SequenceType)? FunctionBody 	
        ; [69]    	MapConstructor 	   ::=    	"map" "{" (MapConstructorEntry ("," MapConstructorEntry)*)? "}" 	
        ; [70]    	MapConstructorEntry 	   ::=    	MapKeyExpr ":" MapValueExpr 	
        ; [71]    	MapKeyExpr 	   ::=    	ExprSingle 	
        ; [72]    	MapValueExpr 	   ::=    	ExprSingle 	
        ; [73]    	ArrayConstructor 	   ::=    	SquareArrayConstructor | CurlyArrayConstructor 	
        ; [74]    	SquareArrayConstructor 	   ::=    	"[" (ExprSingle ("," ExprSingle)*)? "]" 	
        ; [75]    	CurlyArrayConstructor 	   ::=    	"array" EnclosedExpr 	
        ; [76]    	UnaryLookup 	   ::=    	"?" KeySpecifier 	
        ; [77]    	SingleType 	   ::=    	SimpleTypeName "?"? 	
        ; [78]    	TypeDeclaration 	   ::=    	"as" SequenceType 	
        ; [79]    	SequenceType 	   ::=    	("empty-sequence" "(" ")")
        ; | (ItemType OccurrenceIndicator?) 	
        ; [80]    	OccurrenceIndicator 	   ::=    	"?" | "*" | "+" 	/* xgc: occurrence-indicators */
        ; [81]    	ItemType 	   ::=    	KindTest | ("item" "(" ")") | FunctionTest | MapTest | ArrayTest | AtomicOrUnionType | ParenthesizedItemType 	
        ; [82]    	AtomicOrUnionType 	   ::=    	EQName 	
        ; [83]    	KindTest 	   ::=    	DocumentTest
        ; | ElementTest
        ; | AttributeTest
        ; | SchemaElementTest
        ; | SchemaAttributeTest
        ; | PITest
        ; | CommentTest
        ; | TextTest
        ; | NamespaceNodeTest
        ; | AnyKindTest 	
        ; [84]    	AnyKindTest 	   ::=    	"node" "(" ")" 	
        ; [85]    	DocumentTest 	   ::=    	"document-node" "(" (ElementTest | SchemaElementTest)? ")" 	
        ; [86]    	TextTest 	   ::=    	"text" "(" ")" 	
        ; [87]    	CommentTest 	   ::=    	"comment" "(" ")" 	
        ; [88]    	NamespaceNodeTest 	   ::=    	"namespace-node" "(" ")" 	
        ; [89]    	PITest 	   ::=    	"processing-instruction" "(" (NCName | StringLiteral)? ")" 	
        ; [90]    	AttributeTest 	   ::=    	"attribute" "(" (AttribNameOrWildcard ("," TypeName)?)? ")" 	
        ; [91]    	AttribNameOrWildcard 	   ::=    	AttributeName | "*" 	
        ; [92]    	SchemaAttributeTest 	   ::=    	"schema-attribute" "(" AttributeDeclaration ")" 	
        ; [93]    	AttributeDeclaration 	   ::=    	AttributeName 	
        ; [94]    	ElementTest 	   ::=    	"element" "(" (ElementNameOrWildcard ("," TypeName "?"?)?)? ")" 	
        ; [95]    	ElementNameOrWildcard 	   ::=    	ElementName | "*" 	
        ; [96]    	SchemaElementTest 	   ::=    	"schema-element" "(" ElementDeclaration ")" 	
        ; [97]    	ElementDeclaration 	   ::=    	ElementName 	
        ; [98]    	AttributeName 	   ::=    	EQName 	
        ; [99]    	ElementName 	   ::=    	EQName 	
        ; [100]    	SimpleTypeName 	   ::=    	TypeName 	
        ; [101]    	TypeName 	   ::=    	EQName 	
        ; [102]    	FunctionTest 	   ::=    	AnyFunctionTest
        ; | TypedFunctionTest 	
        ; [103]    	AnyFunctionTest 	   ::=    	"function" "(" "*" ")" 	
        ; [104]    	TypedFunctionTest 	   ::=    	"function" "(" (SequenceType ("," SequenceType)*)? ")" "as" SequenceType 	
        ; [105]    	MapTest 	   ::=    	AnyMapTest | TypedMapTest 	
        ; [106]    	AnyMapTest 	   ::=    	"map" "(" "*" ")" 	
        ; [107]    	TypedMapTest 	   ::=    	"map" "(" AtomicOrUnionType "," SequenceType ")" 	
        ; [108]    	ArrayTest 	   ::=    	AnyArrayTest | TypedArrayTest 	
        ; [109]    	AnyArrayTest 	   ::=    	"array" "(" "*" ")" 	
        ; [110]    	TypedArrayTest 	   ::=    	"array" "(" SequenceType ")" 	
        ; [111]    	ParenthesizedItemType 	   ::=    	"(" ItemType ")" 	
        ; [112]    	EQName 	   ::=    	QName | URIQualifiedName 


        ; A.2.1 Terminal Symbols
        ; [113]    	IntegerLiteral 	   ::=    	Digits 	
        ; [114]    	DecimalLiteral 	   ::=    	("." Digits) | (Digits "." [0-9]*) 	/* ws: explicit */
        ; [115]    	DoubleLiteral 	   ::=    	(("." Digits) | (Digits ("." [0-9]*)?)) [eE] [+-]? Digits 	/* ws: explicit */
        ; [116]    	StringLiteral 	   ::=    	('"' (EscapeQuot | [^"])* '"') | ("'" (EscapeApos | [^'])* "'") 	/* ws: explicit */
        ; [117]    	URIQualifiedName 	   ::=    	BracedURILiteral NCName 	/* ws: explicit */
        ; [118]    	BracedURILiteral 	   ::=    	"Q" "{" [^{}]* "}" 	/* ws: explicit */
        ; [119]    	EscapeQuot 	   ::=    	'""' 	
        ; [120]    	EscapeApos 	   ::=    	"''" 	
        ; [121]    	Comment 	   ::=    	"(:" (CommentContents | Comment)* ":)" 	/* ws: explicit */
        ;                 /* gn: comments */
        ; [122]    	QName 	   ::=    	[http://www.w3.org/TR/REC-xml-names/#NT-QName]Names 	/* xgc: xml-version */
        ; [123]    	NCName 	   ::=    	[http://www.w3.org/TR/REC-xml-names/#NT-NCName]Names 	/* xgc: xml-version */
        ; [124]    	Char 	   ::=    	[http://www.w3.org/TR/REC-xml#NT-Char]XML 	/* xgc: xml-version */

        ; [125]    	Digits 	   ::=    	[0-9]+ 	
        ; [126]    	CommentContents 	   ::=    	(Char+ - (Char* ('(:' | ':)') Char*)) 	


    ]

]
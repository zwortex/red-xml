Red [
	Title:          "SXML"
    File:           "%sxml.red"
	Description:    "SXML encoder and decoder"
	Author:         @zwortex
    License:        {
        Distributed under the Boost Software License, Version 1.0.
        See https://github.com/red/red/blob/master/BSL-License.txt
    }
    Notes:          {
        Transposition of SXML format in Red, see following ressources for inputs on SXML format
        http://okmij.org/ftp/Scheme/xml.html
        http://okmij.org/ftp/papers/SXML-paper.pdf
        https://en.wikipedia.org/wiki/SXML

    }
    Version:        0.1.0
    Date:           23/09/2021
    Changelog:      {
        0.1.0 - 23/09/2021
            * initial version
    }
    Tabs:           4
]

#include %sax.red

;comment [

sxml: context [

    ;
    ; Reserved words pointing to itself to be used as pure symbolic values
    ;
    *TOP*: '*TOP*
    *COMMENT*: '*COMMENT*
    *PI*: '*PI*
    *ENTITY*: '*ENTITY*
    _: '_
    *NAMESPACES*: '*NAMESPACES*
    *text*: '*text*
    *element*: '*element* 
    *any*: '*any*
    *data*: '*data*

    ; A dictionnary to maintain the string version of words or issues
    ; that are used as names or prefixes
    names: make hash! []

    as-string: function [
        "Returns the string version of a node name"
        name [word! issue!]
    ][
        s: select names name
        if not s [
            s: to-string name
            ; @ZWT could use put, however issue! is not accepted currently as key
            append names name
            append names s
        ]
        s
    ]

    has-namespace?: function [
        "True if a name belongs to the given namespace"
        name [word! url! tag! issue!] "The name to analyze"
        namespace-id [word! issue!] "The namespace id to check against"
        return: [logic!]
    ][
        return switch/default type?/word name [
            word! issue! [
                s: as-string name
                f: find/match/tail s as-string namespace-id
                either all [
                    f
                    #"|" = first f
                ][ true ][ false ]
            ]
            url! tag! [
                f: find/match/tail name as-string namespace-id
                either all [
                    f
                    #":" = first f ; cannot use f/1 as with url! returns an url!
                ][ true ][ false ]
            ]
        ][ false ]
    ]

    decode: function [
        "Parses an XML string and returns a tree of blocks in SXML"
        data [binary! string!] "XML document to parse"
        /trim "Trim whitespaces"
    ][
        if binary? data [
            data: to string! data
        ]
        self/trim-spaces: trim

        ; setup the reader function
        reader: sax/reader
        reader/parse-function: :parse-function
        reader/handler: sxml-handler

        ; run the parse
        reader/parse-xml data
        sxml-handler/doc

    ]

    ;;
    ;; Package parameters
    ;;

    ; parse function to use - default to standard parse function
    parse-function: :system/words/parse

    ; True if XML prefix should be used as SXML prefix
    reuse-xml-prefix: true

    ; True if spaces should be trimmed
    trim-spaces: true

    ; True if qualified names should be translated into uris 
    names-as-uri?: true

    ; When loading create an attribute node even when no attributes
    force-attribute-node: true

    sxml-handler: make sax/default-handler! [

        ;
        ; SXML/PARSER : Parse an XML document and produces an SXML document
        ;

        do: [
            ;
            ; Turn off handlers that not implemented
            ;

            ; entity-resolver
            self/resolve-entity: none
            ; entity-resolver2
            self/external-subset: none
            self/resolve-entity-ext: none
            ; dtd-handler
            self/notation-decl: none
            self/unparsed-entity-decl: none
            ; decl-handler
            self/attribute-decl: none
            self/element-decl: none
            self/external-entity-decl: none
            self/internal-entity-decl: none
            ; content-handler
            ;set-document-locator: none
            ;start-document: none
            ;end-document: none
            start-prefix-mapping:   none
            end-prefix-mapping: none
            ;start-element: none
            ;end-element: none
            ;characters: none
            self/ignorable-whitespace: none
            self/processing-instruction: none
            self/skipped-entity: none
            ; error-handler
            ;warning                 function!     Receive notification of a warning.
            ;error                   function!     Receive notification of a recoverable error.
            ;fatal-error             function!     Receive notification of a non-recoverable error.
            ; lexical-handler
            self/start-DTD: none
            self/end-DTD: none
            self/start-entity: none
            self/end-entity: none
            ;start-CDATA: none
            ;end-CDATA: none
            ;xml-comment             function!     Report an XML comment anywhere in the document.
            ;; extended handler
            ;xml-declaration         function!     Report additional informations from the prologue.

        ]

        ; locator returned by the content handler
        locator: none

        ; stack to keep track of ongoing elements
        stack: none

        ; true if current element text nodes should be trimmed
        ; the value is computed based on global settings (@ZWT) and xml:space attribute
        trim?: false

        ; main document
        doc: none

        ;;
        ;; Helper functions for names
        ;;

        comment [
            ;
            ; SXML namespaces
            ; http://okmij.org/ftp/Scheme/SXML.html#Namespaces
            ;
            ; Hashtable used to keeps track of namespaces referenced within the document.
            ; The format is : [ uri prefix ]
            ;
            ; Both uri and prefix are unique keys accross the sxml expression : 
            ; - uri : the namespace identifier
            ; - prefix : the sxml prefix, possibly empty for the default mapping
            ;
            ; The xml prefix is kept as annotations in the sxml expression with the following format.
            ; [*NAMESPACES* [<sxml-prefix> <uri> <xml-prefix>] [...]]
            ; 
            ; These are attached to the expression at the appropriate place (either attached to the 
            ; *TOP* node, or to an element node), to reflect the mapping settings made in the original
            ; document (or those to be used to produce an xml document).
            ;
        ]
        namespaces: none

        ; Convert xml names into sxml words, and return a new mapping if any 
        sxml-name: function [
            uri [string! none!] local-name [string! none!] qname [string! none!] 
            mappings [block!]
            return: [word! url!]
        ][
            ;print [ "uri:" uri "local-name:" local-name "qname:" qname ]
            new-mapping?: false
            ;; compute sxml-prefix
            sxml-prefix: xml-prefix: none
            case [
                all [ uri empty? uri ][
                    ; an empty uri denotes a default mapping to nothing in particular
                    ; use local-name only
                ]
                uri [
                    ;; retrieve the prefix mapping if one is known already
                    sxml-prefix: select namespaces uri
                    unless sxml-prefix [
                        ; no mapping and uri is not empty, this mapping should be registered
                        ; if reuse-xml-prefix set, attempt to reuse the xml prefix provided
                        either reuse-xml-prefix [
                            either f: find qname #":" [
                                xml-prefix: copy/part qname f
                                either f: select namespaces xml-prefix [
                                    ; this prefix is already registered, and should not be used again
                                    ; fall back to uri then
                                    sxml-prefix: uri
                                ][
                                    sxml-prefix: xml-prefix
                                ]
                            ][
                                ; no xml prefix, use the full uri
                                sxml-prefix: uri
                            ]
                        ][
                            sxml-prefix: uri
                        ]
                        new-mapping?: true
                    ]
                ]
                true [
                    ;; document may use qualified names, for which the namespace mapping is missing
                    ;; but this can be supplemented here
                    ;; @ZWT see
                    if f: find qname #":" [
                        xml-prefix: copy/part qname f
                        n: find namespaces xml-prefix
                        if n [
                            uri: first back n
                            sxml-prefix: xml-prefix
                            new-mapping?: true
                        ]
                    ]
                ]
            ]
            ;; sxml-prefix should be turned into a word or an uri
            ;; - an uri if prefixed (:) and names-as-uri? is on
            ;; - a word otherwise
            case [
                any [ 
                    not sxml-prefix 
                    word? sxml-prefix
                    url? sxml-prefix 
                ][
                    ; do nothing
                ]
                all [ names-as-uri? find sxml-prefix #":" ] [
                    sxml-prefix: to-url sxml-prefix
                ]
                not empty? sxml-prefix [
                    sxml-prefix: encode-name-as-word sxml-prefix
                ]
                true [
                    ; should not happen
                    sxml-prefix: none
                ]
            ]
            ;; register the new mapping
            if new-mapping? [
                append namespaces uri
                append namespaces sxml-prefix
                either xml-prefix [
                    append/only mappings reduce [ sxml-prefix uri xml-prefix ]
                ][
                    append/only mappings reduce [ sxml-prefix uri ]
                ]
            ]
            ;; sxml-prefix if none => use local-name, 
            ;; otherwise use expanded name - either as url or word
            name: case [
                sxml-prefix [
                    either names-as-uri? [
                        to-url rejoin [ sxml-prefix #":" local-name ]
                    ][
                        ; use #"|" instead of #":" as prefix separator for #":" is not allowed in words
                        to-word rejoin [ sxml-prefix #"|" encode-name-as-word local-name ]
                    ]
                ]
                all [ uri local-name ] [ encode-name-as-word local-name ]
                true [ encode-name-as-word qname ]
            ]
            name
        ]

        comment [
            ;
            ; Reminder of name restrictions between word, uri and xml
            ;
            ; word restrictions : 
            ; exclude control characters, whitespace characters 
            ; exclude punctuation characters from /\^,[](){}"#$%@:; - These are forbidden in word, but not constrained in uris : \^{}"%
            ; also word cannot start with a number
            ; punctuations explicitely authorized in words : ! & ' * + - . < = > ? _ | ~ `
            ;
            ; uri restrictions : 
            ; explicitly authorized : alpha, digits and -._~
            ; explicitly forbidden :  :/#[]@  or  $(),;   - These are separators in uris but authorized in word ?!&'*+=
            ; if forbidden or non explicitly authorized : percent encoded
            ;
            ; xml restrictions :
            ; authorized punctuation is restricted to colon (,) hyphen (-) period (.) underscore (_) middle dot (·)
            ; semi-colon (:) is authorized as well but reserved for namespaces prefix
            ; do not start with digits, diacritics, full stop (.), hyphen (-)
            ; no space of any form : space, fixed space, tab, end of lines
            ; otherwise large range of characters accepted
            ;
        ]

        encode-name-as-word: function [
            {
                Escape a string to be used as a word. A similar strategy as with the pourcent encoding of uris
                is used, except that encoded characters are introduced with the character #"?" 
                instead of #"%" that is forbidden within a word - the ? itself is encoded if already present. 
            }
            str [string!] return: [word!] 
        ][
            digits: charset [ #"0" - #"9" ]
            control-chars: charset [ #"^(0000)" - #"^(001F)" #"^(007F)" #"^(0080)" - #"^(009F)" ]
            spaces: charset [  #"^(09)" #"^(0A)" #"^(0D)" #"^(20)" ]
            punctuation: union charset "/\^,[](){}#$%@:;" charset {"?}
            forbidden-chars: union union control-chars spaces punctuation

            res: copy ""
            foreach c str [
                either forbidden-chars/(c) [
                    h: enhex to-string c
                    append res replace/all h #"%" #"?"
                ][
                    append res c
                ]
            ]
            to-word res
        ]

        decode-name-from-word: function [
            {
                Symetric function from encode-name-as-word that translates back a word name into 
                an XML name
            }
            wd [word!] return: [string!]
        ][
            res: to-string wd
            res: replace/all res #"?" #"%"
            dehex res
        ]

        ;
        ; Handler implementation
        ;

        set-document-locator: function [
            "Receive from the parser an object for locating the origin of SAX document events." 
            locator [object!] 
        ][
            self/locator: locator
        ]

        start-document: function [ "Receive notification of the beginning of a document." ][
            self/namespaces: make hash! []
            self/stack: copy []
            self/doc: reduce [ '*TOP* ]
            push-node doc
        ]

        end-document: function [ "Receive notification of the end of a document."][
            pop-node
        ]

        start-element: function [
            "Receive notification of the beginning of an element." 
            uri [string! none!] local-name [string! none!] qname [string! none!] attributes [object! none!] 
        ][
            ; if the current element is a text, close it first
            if string? first stack [
                close-characters
            ]

            ; retrieve element name and mapping
            mappings: copy []
            name: sxml-name uri local-name qname mappings

            ; new element
            elem-node: reduce [ name ]

            ; process attributes
            if any [
                force-attribute-node
                all [ attributes 0 < attributes/length? ]
                0 < length? mappings
            ][
                append/only elem-node attr-node: reduce [ '_ ]
                ;new-line back tail elem-node true
                i: 0
                while [ i < attributes/length? ][
                    i: i + 1
                    attr-name: sxml-name
                        attributes/uri? i attributes/local-name? i attributes/qname? i
                        mappings
                    ; @ZWT what about type
                    ; attr/4: attributes/type? i
                    attr-value: attributes/value? i
                    append/only attr-node reduce [ attr-name attr-value ]
                ]
                if 0 < length? mappings [
                    append/only attr-node annotations-node: reduce [ '_ ]
                    append/only annotations-node ns-node: reduce [ '*NAMESPACES* ]
                    foreach m mappings [
                        append/only ns-node m
                    ]
                ]
            ]

            ; push the new element in the stack and maintain the context
            push-node elem-node

        ]

        end-element: function [
            "Receive notification of the end of an element."
            uri [string! none!] local-name [string! none!] qname [string! none!]
        ][
            pop-node
        ]

        characters: function [ 
            "Receive notification of character data." 
            start [string!] length [integer!]
        ][
            if any [
                not current: first stack
                not string? current
            ][
                new: copy ""
                insert/only stack new
                append/only current new
                new-line back tail current true
                current: new
            ]
            append/part current start length
        ]

        close-characters: function [
        ][
            if not string? first stack [
                return
            ]
            txt: take stack
            ; shall I trim ?
            if trim? [
                trim/lines txt
            ]
            if empty? txt [ ; clear the node
                take/last first stack
            ]
        ]

        push-node: function [
            "Attach a node to a parent node, push it in the stack and maintain the context"
            node [block!] 
        ][

            ; add the new element to the parent node right-away
            if current: first stack [
                if string? current [
                    ; current node is a text string - close it first
                    close-characters
                    current: first stack
                ]
                append/only current node
                new-line back tail current true
            ]

            ; Leaf nodes are not pushed in the stack
            if find [ *COMMENT* *PI* ] node/1 [
                exit
            ]

            ; create a context and store whatever values are modified
            ; so as to restore them when the node is poped
            ctx: []

            ;  @ZWT rewrite with helper functions
            if all [ 
                block? node/2
                node/2/1 == '_
            ][
                foreach attr next node/2 [
                    if any [ 
                        attr/1 == 'xml|space
                        attr/1 == xml:space
                    ][
                        new-trim?: not equal? attr/2 "preserve" ; case insensitive
                        if new-trim? <> trim? [
                            ; new value - store old value in the context
                            if empty? ctx [ ctx: copy [] ]
                            append/only ctx compose [ trim? (trim?) ]
                            self/trim?: new-trim?
                        ]
                    ]
                ]
            ]

            ; push the context possibly empty
            insert/only stack ctx

            ; push the elem into the stack for further reference
            insert/only stack node

        ]

        pop-node: function [
            "Pop a node and restore the context if needed"
        ][

            ; if current node is a character node close it first
            if string? first stack [
                close-characters
            ]

            ; de-stack current node
            take stack

            ; de-stack old context and restore it
            ctx: take stack
            if not empty? ctx [
                foreach c ctx [
                    set in self c/1 c/2
                ]
            ]

        ]

        xml-comment: function [
            "Report an XML comment anywhere in the document."
            start [string!] length [integer!] 
        ][
            ; new comment node
            comment-node: reduce [
                '*COMMENT*
                copy/part start length
            ]

            ; push it
            push-node comment-node
        ]

        processing-instruction: function [
            "Receive notification of a processing instruction."
            target [string!] data [string!]
        ][
            ; processing instruction node
            pi-node: reduce [
                '*PI*
                encode-name-as-word target
                [_]
                data
            ]

            ; push it
            push-node pi-node
        ]

    ];parser

    comment [
        ; ; element string
        ; elem-as-string: function [ elem [block!] return: [string!] ][
        ;     str: copy ""
        ;     if all [ elem/1 not empty? elem/1 ] [
        ;         ;if 0 < length? str [ append str ", " ]
        ;         append str rejoin [ "uri: " elem/1 ]
        ;     ]
        ;     if all [ elem/2 elem/2 <> elem/3 ] [
        ;         if 0 < length? str [ append str ", " ]
        ;         append str rejoin [ "local-name: " elem/2 ]
        ;     ]
        ;     if elem/3 [
        ;         if 0 < length? str [ append str ", " ]
        ;         append str rejoin [ "qname: " elem/3 ]
        ;     ]
        ;     if elem/4 [
        ;         if 0 < length? str [ append str ", " ]
        ;         append str "("
        ;         attr: elem/4
        ;         forall attr [
        ;             append str attr-as-string attr/1
        ;             append str ", "
        ;         ]
        ;         take/last/part str 2
        ;         append str ")"
        ;     ]
        ;     str
        ; ]

        ; ; attribut string
        ; attr-as-string: function [ attr [block!] return: [string!] ][
        ;     str: copy ""
        ;     if all [ attr/1 not empty? attr/1 ] [
        ;         ;if 0 < length? str [ append str ", " ]
        ;         append str rejoin [ "uri: " attr/1 ]
        ;     ]
        ;     if all [ attr/2 attr/2 <> attr/3 ] [
        ;         if 0 < length? str [ append str ", " ]
        ;         append str rejoin [ "local-name: " attr/2 ]
        ;     ]
        ;     if attr/3 [
        ;         if 0 < length? str [ append str ", " ]
        ;         append str rejoin [ "qname: " attr/3 ]
        ;     ]
        ;     if all [ attr/4 not empty? attr/4 ] [
        ;         if 0 < length? str [ append str ", " ]
        ;         append str rejoin [ "type: " attr/4 ]
        ;     ]
        ;     if attr/5 [
        ;         if 0 < length? str [ append str ", " ]
        ;         append str rejoin [ "value: " attr/5 ]
        ;     ]
        ;     str
        ; ]

        ; ; recursively print-out the xml tree
        ; _as-string-rec: function [ elem [block!] indent [string!] ][
        ;     prin rejoin [ indent "[ " elem-as-string elem ]
        ;     either any [ not elem/5 empty? elem/5 ] [
        ;         print " ]"
        ;     ][
        ;         print ""
        ;         append indent "  "
        ;         print rejoin [ indent "[" ]
        ;         content: elem/5
        ;         forall content [
        ;             either string? content/1 [
        ;                 print rejoin [ indent mold/flat content/1 ] 
        ;             ][
        ;                 _as-string-rec content/1 indent
        ;             ]
        ;         ]
        ;         print rejoin [ indent "]" ]
        ;         clear back back tail indent
        ;         print rejoin [ indent "]" ]
        ;     ]
        ; ]

        ; as-string: function [] [
        ;     indent: copy ""
        ;     _as-string-rec first stack indent
        ; ]
    ]

    sxml-rules: context [
        ;;
        ;; SXML Grammar (version 3.0) adapted to RED - see the following ressources
        ;; http://okmij.org/ftp/Scheme/SXML.html
        ;; http://okmij.org/ftp/Scheme/SXML.html#Grammar
        ;;
        ;; Following is original grammar.
        ;;
        comment [
            ; [1]  <TOP>              ::= ( *TOP* <annotations>? <PI>* <comment>* <Element> )
            ; [2]  <Element>          ::= ( <name> <annot-attributes>? <child-of-element>* )   /* () for list */
            ; [3]  <annot-attributes> ::= {@ <attribute>* <annotations>? }                     /* {} for tagged set */
            ; [4]  <attribute>        ::= ( <name> "value"? <annotations>? )
            ; [5]  <child-of-element> ::= <Element> | character-data-string | <PI> | <comment> | <entity>
            ; [6]  <PI>               ::= ( *PI* pi-target <annotations>? "processing instruction content string" )
            ; [7]  <comment>          ::= ( *COMMENT* "comment string" )
            ; [8]  <entity>           ::= ( *ENTITY* "public-id" "system-id" )
            ; [9]  <name>             ::= <LocalName> | <ExpName>
            ; [10] <LocalName>        ::= NCName
            ; [11] <ExpName>          ::= make-symbol(<namespace-id>:<LocalName>)
            ; [12] <namespace-id>     ::= make-symbol("URI") | user-ns-shortcut
            ; [13] <namespaces>       ::= {*NAMESPACES* <namespace-assoc>* }
            ; [14] <namespace-assoc>  ::= ( <namespace-id> "URI" original-prefix? )
            ; [15] <annotations>      ::= {@ <namespaces>? <annotation>* }
            ; [16] <annotation>       ::= To be defined in the future
        ]
        ;;
        ;; Normalization level
        ;;
        ;; level-0 : 
        ;; - the annot-attributes if present is not necessarily positionned in first place
        ;; - attribute with no values are allowed - like in HTML : [OPTION [_ [checked]]] instead of [OPTION [@ [checked "checked"]]]
        ;; level-1 (default) : forbid level-0 relaxations
        ;; level-2 : level 1 and the following
        ;; - each element has a mandatory annot-attributes, possibly void
        ;; - comment or entity are forbidden - all parsed entities should be expanded (even when external)
        ;; level-3 : level-2 and all text strings should be maximal (no text string nodes should be left as siblings)
        ;;
        ;; Adapted parse rule to validate an SXML data set using RED blocks
        ;;
        ;; Differences :
        ;;
        ;; - names can be words, lit-words, tags or uri
        ;;
        ;; - note that XML names are cases sensitive. Words are also case sensitive in RED. 
        ;; It is only when used as referring a value that their case sensitivity becomes apparent.
        ;;
        ;; - xml names are case sensitive, and SXML use symbols, equivalent to words, to represent those names.
        ;; However in Red, words are case insensitive. To account for that, it is possible to use instead of words,
        ;; tags for implementing names.
        ;; 
        ;; - it is also possible to use url : html:a
        ;;
        ;; - prefixed names, using #":", are either encoded as url, tag or when encoded as word they should 
        ;; use the delimiter #"|" instead, as #":" is a prohibited character within words
        ;;
        ;; - attributes set (annot-attributes) may be implemented using a prefixed block - a block with first element
        ;; being '_ - or with a map
        ;;
        ;; - CDATA is allowed ?
        ;;
        ;; - SXML annotations are extra data associated with an XML node, or attribute
        ;; - Every child is unique; items never share their children even if the latter have the identical content.
        ;;
        ;;

        debug: false ; for debug and trace

        level: none ; level of conformity - see above
        last-element: none ; for checking consecutive text

        ;;
        ;; Local variables used within rules
        ;;
        v: v1: v2: v3: v4: v5: v6: v7: none ; values

        ;; Debug strings
        =name: none
        =attr-name: none

        ; A stack to track and restore local values
        st: none

        TOP: [
            (
                st: copy []
                level: 3 
            )
            '*TOP* opt annotations any PI any a-comment Element
            |
            ( 
                level: -1
            )
        ]
        Element: [
            ( 
                v1: 0 v2: false v3: none v4: false
            )
            into [ 
                copy =name name
                [ annot-attributes (v1: v1 + 1) | none ]
                any [
                    ( 
                        last-element: none 
                    )
                    ; beware child-of-element can recurse on Element => save the v locals if that is so...
                    child-of-element
                    ( 
                        if all [ last-element == 'text v3 == 'text ] [
                            v4: true
                        ] 
                        v3: last-element
                    )
                    |
                    annot-attributes (v1: v1 + 1 v2: true) 
                ]
            ]
            ( 
                if v1 > 1 [
                    if debug [ print ["Element" =name " has more than one annot-attributes node => level -1"] ]
                    level: -1 
                ]
                if v1 == 0 [
                    if debug [ print ["Element" =name " has no annot-attribute node => at most level 1"] ]
                    level: min 1 level 
                ]
                if v2 [
                    if debug [print [ "Element" =name " annot-attributes is not the first child => at most level 0"] ]
                    level: min 0 level 
                ]
                if v4 [
                    if debug [ print [ "Element" =name " multiple consecutive text nodes => at most level 2"]]
                    level: min 2 level 
                ]
            )

        ]

        ; attributes
        annot-attributes: [ into [ '_ any attribute opt annotations ] ] ;; either a block introduced by '_ or a map
        attribute: [
            ( v5: false )
            into [ copy =attr-name name [ value | none ( v5: true) ] opt annotations ]
            (
                if v5 [
                    if debug [ print [ "Attribute" =name "|" =attr-name " has no value => at most level 0" ] ]
                    level: min 0 level
                ]
            )
        ]
        value: character-data: [ string! | number! ] ; revue number?

        ; children
        child-of-element: [
            ahead string! character-data (last-element: 'text) 
            | ahead [ into [ '*PI* thru end ] ] PI (last-element: 'PI) 
            | ahead [ into [ '*COMMENT* thru end ] ] a-comment (last-element: 'comment)
            | ahead [ into [ '*ENTITY* thru end ] ] entity (last-element: 'entity)
            | ahead block! 
                [
                    (
                        ; save current element context
                        append/only st reduce [ v1 v2 v3 v4 ]
                    )
                    Element
                    ( 
                        last-element: 'element
                        ; restore the context in all cases
                        p: take/last st
                        set [v1 v2 v3 v4] p
                    )
                    |
                    (
                        last-element: none
                        p: take/last st
                        set [v1 v2 v3 v4] p
                    )
                    fail
                ]
        ]

        ; processing instruction
        PI: [ into [ '*PI* pi-target opt annotations processing-instruction ]]
        pi-target: [ word! ]
        processing-instruction: [string!]

        ; comment
        a-comment: [ 
            into [ '*COMMENT* s-comment ]
            (
                if debug [ print "Comment node found => at most level 1" ]
                level: min 1 level
            )
        ]
        s-comment: [string!]

        ; entity
        entity: [ 
            into [ '*ENTITY* public-id system-id ]
            (
                if debug [ print "Entity node found => at most level 1" ]
                level: min 1 level
            )
        ]
        public-id: system-id: [ string! ]

        ; names
        name: [ 
            url! ; expanded name
            |
            ahead copy v6 [ word! | tag! ]
            if ( not find reserved-strings v7: to-string v6/1 )
            [
                if (
                    any [
                        all [ word? v6/1 not find v7 #"|" ]
                        all [ tag? v6/1 not find v7 #":" ]
                    ]
                )
                skip ; local name 
                |
                skip ; expanded name
            ]
        ]
        namespace-id: [ url! | word! ] ; url! or user-ns-shortcut
        namespaces: [ into [ '*NAMESPACES* any namespace-assoc ] ]
        namespace-assoc: [ into [ namespace-id URI opt original-prefix ] ]
        URI: [ string! ]
        original-prefix: [ string! ]
        reserved-strings: [ "_" "*NAMESPACES*" "*COMMENT*" "*TOP*" "*PI*" "*ENTITY*" ]

        ; annotations contain auxiliary attributes
        annotations: [ into [ '_ opt namespaces any annotation ] ] ;; map?
        annotation: [ thru end ]

    ]

    sxml?: function [
        { 
          Check whether an expression is a valid sxml expression.

          Returns the corresponding conformity level, either
          -1, the sxml expression is not valid
          0, the sxml expression is valid but either an attributes set is not in first position or an attribute has no value
          1, the sxml expression is valid and none of the relaxed rule of level 0 are met
          2, level 1 + all element have one attributes node
          3, level 2 + all text nodes are the longest possible (no text nodes of the same element are siblings)
        }
        doc [ block! ]
        /trace "Details the fail tests if any"
        return: [ integer! ]
    ][
        sxml-rules/debug: trace
        res: parse-function/case doc sxml-rules/TOP
        either res [
            sxml-rules/level
        ][
            -1
        ]
    ]

    ;;
    ;; sxml helper functions
    ;;

    node-set?: function [
        { True if the given value is a node set.
            A value is a node set if it is a block!, either empty or
            which first element is not a node name }
        value [any-type!]
        return: [logic!]
    ][
        either all [
            block? value
            not any [ word? value/1 url? value/1 tag? value/1 ]
        ][ true ][ false ]
    ]

    as-node-set: function [
        "Returns the value as a node-set if it is not one already."
        value [any-type!]
        return: [block!]
    ][
        case [
            not value [ [] ]
            all [ block? value empty? value ] [ [] ]
            node-set? value [ value ]
            true [ reduce [ value ] ]
        ]
    ]

    as-node-or-set: function [
        "Returns the value as a node-set if one already and not a singleton, otherwise returns the value."
        value [any-type!]
        return: [any-type!]
    ][
        either all [ 
            node-set? value 
            1 == length? value
        ][
            value/1
        ][
            value
        ]
    ]

    ; reserved node names
    reserved-words: #(
        _ #[true] *TOP* #[false] *COMMENT* #[true] *PI* #[true] 
        *ENTITY* #[true] *NAMESPACES* #[true]
    )

    element?: function [
        "True if a node is an element."
        ;; Practically, verify that the node is a block but neither an attribute set, 
        ;; a comment, a pi, an entity, and therefore it must be an element.
        node [any-type!] "The node to test"
        return: [logic!]
    ][
        either all [
            block? node
            any [
                all [
                    word? node/1
                    not select reserved-words node/1
                ]
                tag? node/1 
                url? node/1 
            ]
        ][ true ] [ false ]
    ]

    text?: function [
        "True if the node is a text node"
        node [any-type!] "The node to test"
        return: [logic!]
    ][
        string? node
    ]

    attributes?: function [
    {True if the given node is an attributes set}
        node [any-type!] "An sxml node"
        return: [logic!]
    ][
        either all [
            block? node
            node/1 == '_
        ][ true ][ false ]
    ]

    node?: function [
        {True if the given node is an xml node but not an attributes set, nor a string.}
        node [any-type!] "An sxml node"
        return: [logic!]
    ][
        either all [
            block? node
            not empty? node
            node/1 <> '_
        ] [ true ] [ false ]
    ]

    any?: function [
        {True if the given node is an xml node, an attribute set, a string}
        node [block! string!] "An sxml node"
        return: [logic!]
    ][
        either any [
            node? node
            attributes? node
            text? node
        ] [ true ] [ false ]
    ]

    name?: function [
        { Returns the element name }
        element [any-type!] "The element to test"
        return: [word! url! tag! none!]
    ][
        either element? element [
            return element/1
        ][
            return none
        ] 
    ]

    local-name?: function [
        { Returns the local part of an element name }
        element [any-type!] "The element to test"
        return: [word! url! tag! none!]
    ][
        if not element? element [
            return none
        ]
        name: element/1
        switch type?/word name [
            word! [
                f: find/last w: as-string name #"|"
                either f [
                    to-word next f
                ][
                    none
                ]
            ]
            url! tag! [
                f: find/last name #":"
                either f [
                    next f
                ][
                    none
                ]
            ]
        ]
    ]

    namespace-id?: function [
        { Returns the namespace id of an element }
        element [any-type!] "The element to test"
        return: [word! url! tag! none!]
    ][
        if not element? element [
            return none
        ]
        name: element/1
        switch type?/word name [
            word! [
                f: find/last w: as-string name #"|"
                either f [
                    to-word copy/part w f
                ][ none ]
            ]
            url! tag! [
                f: find/last name #":"
                either f [
                    copy/part name f
                ][ none ]
            ]
        ]
    ]

    has-children?: function [
        "True if the element has children"
        node [block! string!]
        return: [block!]
    ][
        c: children-of node
        either all [ c not c == [] ]
        [ true ][ false ]
    ]

    children-of: content: function [
        { Returns the content of an element : children, text nodes, *PI* etc. but no attribute }
        node [block! string!]
        return: [block!]
    ][
        if not element? node [
            return []
        ]
        first-child: either all [
            block? node/2 node/2/1 == '_
        ][
            at node 3
        ][
            at node 2
        ]
        either first-child [ first-child ] [ [] ]
    ]

    has-attributes?: function [
        "True if a node is an element with attributes"
        node [block!] "Sxml node to test"
        return: [logic!]
    ][
        a: attributes-of node
        either all [ a not a == [] ]
        [ true ][ false ]
    ]

    attributes-of: function [
        "Returns the attributes of an element or none if no attribute set"
        node [block!] "An sxml element"
        return: [block! none!]
    ][
        either all [
            element? node
            block? node/2
            node/2/1 == '_
        ][
            at node/2 2
        ][
            none
        ]
    ]

    has-any-children?: function [
        "Returns true if the given node has any children (not a terminal value)"
        node [any-type!]
        return: [logic!]
    ][
        either all [
            block? node
            not empty? node
            any [
                word? node/1
                tag? node/1
                url? node/1
            ]
            node/2
        ][ true ][ false ]
    ]

    any-children-of: function [
        "Returns any children"
        node [block! string!]
        return: [block!]
    ][
        either has-any-children? node [
            at node 2
        ][
            []
        ]
    ]

    _descendants-of: function [
        "Recursively builds the list of descendants"
        node [block!]
        descendants [block!]
    ][
        children: children-of node
        if empty? children [ exit ]
        foreach c children [
            append/only descendants c
            if element? c [
                _descendants-of c descendants
            ]
        ]
        exit
    ]

    descendants-of: function [
        { Returns all the descendants of an element }
        node [block!]
        return: [block!]
    ][
        either element? node [
            descendants: copy []
            _descendants-of node descendants
            descendants
        ][
            []
        ]
    ]

    descendants-or-self: function [
        { Returns all the descendants of an element, along with the element itself }
        node [block!]
        return: [block!]
    ][
        res: descendants-of node
        insert/only res node
        res
    ]

    mold-node: function [
        "Mold version to output an smxl node"
        node [ block! string! ]
        buf [string!]
    ][
        case [
            element? node [ append buf rejoin ["Element:" name? node ] ]
            text? node [ append buf rejoin ["Text:" mold/part text node 20 ] ]
            comment? node [ append buf rejoin ["Comment:" mold/part text node 20 ] ]
            pi? node [ append buf rejoin ["PI:" mold/part text node 20 ] ]
            top? node [ append buf "Top" ]
            entity? node [ append buf "Entity" ]
            true [ append buf "?" ]
        ]
    ]

    mold-nodes: function [
        "Mold version to output an sxml node or node-set"
        nodes [block!]
        return: [string!]
    ][
        if empty? nodes [
            return ""
        ]
        res: copy ""
        append res "[ "
        foreach node nodes [
            mold-node node res
            append res ", "
        ]
        take/last/part res 2
        append res " ]"
        res
    ]

    node-type?: function [
        {Returns the node type, either 
        *text* (for strings), 
        *element* (for any element, or attribute), 
        _ (for attribute sets)
        *COMMENT*, *PI*, *ENTITY*, *TOP* for these respective nodes}
        node [any-type!]
        return: [logic!]
    ][
        case [
            string? node [ '*text* ]
            all [ block? node node/1 ] [
                f: find/same [_ *COMMENT* *PI* *ENTITY* *TOP* ] node/1
                either f [
                    node/1
                ] [
                    '*element*
                ]
            ]
            true [none]
        ]
    ]

    comment?: function [
        "True if node is a comment node"
        node [block!]
        return: [logic!]
    ][
        either all [
            block? node
            node/1 == '*COMMENT*
        ][ true ][ false ]
    ]

    pi?: function [
        "True if node is a pi node"
        node [block!]
        return: [logic!]
    ][
        either all [
            block? node
            node/1 == '*PI*
        ][ true ][ false ]
    ]

    entity?: function [
        "True if node is an entity node"
        node [block!]
        return: [logic!]
    ][
        either all [
            block? node
            node/1 == '*ENTITY*
        ][ true ][ false ]
    ]

    top?: function [
        "True if node is the root node"
        node [block!]
        return: [logic!]
    ][
        either all [
            block? node
            node/1 == '*TOP*
        ][ true ][ false ]
    ]

    text: function [
        { Returns the concatenation of all text nodes }
        node [block! string!]
        return: [string!]
    ][
        case [ 
            string? node [
                node
            ]
            element? node [
                res: copy ""
                foreach e content node [
                    if string? e [
                        append res e
                    ]
                ]
                res
            ]
            true [ copy "" ]
        ]
    ]

    attribute: function [
        { Returns an attribute value }
        element [block!]
        attr-name [word! url! tag!]
        return: [string! none!]
    ][
        attrs: attributes-of element
        if attrs [
            foreach a attrs [
                if same? attr-name a/1 [
                    return a/2
                ]
            ]
        ]
        return none
    ]

    change-content: function [
        element [block!]
        new-content [block! string! none!]
    ][
        if element? element [
            if has-children? element [
                clear content element
            ]
            if new-content [
                append element new-content
            ]
        ]
        element
    ]

    change-attributes: function [
        element [block!]
        new-attributes [block!]
    ][
        if element? element [
            attrs: attributes-of element
            either attrs [
                clear attrs
            ][
                insert/only at element 2 [_]
                attrs: at element/2 2
            ]
            append attrs new-attributes
        ]
        element
    ]

    change-name: function [
        element [block!]
        name [word! url! tag!]
    ][
        if element? element [
            element/1: name
        ]
        element
    ]

    set-attribute: function [
        "Set an attribute value if the attribute exists already"
        element [block!]
        attr-name [word! url! tag!]
        value [string! number!]
        return: [block!]
    ][
        attrs: attributes-of element
        if attrs [
            foreach a attrs [
                if same? attr-name a/1 [
                    a/2: value
                    break
                ]
            ]
        ]
        element
    ]

    add-attribute: function [
        "Add a new attribute unless it exists already"
        element [block!]
        attr-name [word! url! tag!]
        value [string! number!]
        return: [block!]
    ][
        attrs: attributes-of element
        if not attrs [
            insert/only at element 2 [_]
            attrs: tail element/2
        ]
        while [
            all [ 
                not tail? attrs
                attrs/1/1 <> '_
            ]
        ][
            if same? attr-name attrs/1/1 [
                return element
            ]
            attrs: next attrs
        ]
        insert/only attrs reduce [ attr-name value ]
        element
    ]

    change-attribute: function [
        "Like set-attribute but returns none if the attribute is missing"
        element [block!]
        attr-name [word! url! tag!]
        value [string! number!]
        return: [block! none!]
    ][
        attrs: attributes-of element
        if attrs [
            foreach a attrs [
                if same? attr-name a/1 [
                    a/2: value
                    return element
                ]
            ]
        ]
        none
    ]

    squeeze: function [
        "Eliminates empty attribute lists and auxiliary lists."
        element [block!]
        return: [block!]
    ][
        attrs: attributes-of element
        if not attrs [
            return element
        ]
        while [ not tail? attrs ][
            ; remove empty auxiliary list of attributes
            if attrs/1/1 == '_ [
                if not attrs/1/2 [
                    remove attrs
                    continue
                ]
            ]
            ; auxiliary of attribute
            if all [ attrs/1/3 attrs/1/3/1 == '_ not attrs/1/3/2 ] [
                remove at attrs/1 3
            ]
            attrs: next attrs
        ]
        if not element/2/2 [
            remove at element 2
        ]
        element
    ]

    clean: function [
        "Eliminates empty attribute lists and all auxiliary lists"
        element [block!]
        return: [block!]
    ][
        attrs: attributes-of element
        if not attrs [
            return element
        ]
        while [ not tail? attrs ][
            ; remove auxiliary list of attributes
            if attrs/1/1 == '_ [
                remove attrs
                continue
            ]
            ; remove auxiliary list of attribute
            if all [ attrs/1/3 attrs/1/3/1 == '_ ] [
                remove at attrs/1 3
            ]
            attrs: next attrs
        ]
        ; remove empty attribute list
        if not element/2/2 [
            remove at element 2
        ]
        element
    ]


];sxml 

;]
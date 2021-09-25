Red [
    Title:      "Test set for SAX parser"
    File:       %test-sax.red
    Author:     @zwortex
    License: {
        Distributed under the Boost Software License, Version 1.0.
        See https://github.com/red/red/blob/master/BSL-License.txt
    }
    Notes: { ... }
    Version: 0.1.0
    Date: 23/09/2021
    Changelog: {
        0.1.0 - 23/09/2021
            * initial version
    }
    Tabs:    4
]

#include %sax.red

test-sax: context [

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
                        if trace? [ print [ p-indent mold/flat/part input 50 p-indent ] ]
                        input?: false
                    ]
                    if trace? [ print [ p-indent "=" mold/flat/part rule 50 ] ]
                ]
                match [
                    if trace? [ print [ p-indent "==>" pick ["MATCHED" "not MATCHED"]  match? "<==" ] ]
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
    
    test: make sax/default-handler! [
        ;;=======================================================================
        ;;
        ;; TEST : test sax reader for debug - merely prints out sax events
        ;;
        ;;=======================================================================

        parse: function [ testname [string!] xml-input [string!] out [string!] ][
            reader: :sax/reader
            reader/parse-function: :parse-debug
            reader/handler: self
            self/buffer: none ; reset the buffer
            res: reader/parse-xml xml-input
            if buffer [ trim/head/tail buffer ]
            trim/head/tail out
            trim/head/tail xml-input
            either buffer == out [
                print pad/with "" 100 #"-"
                print pad/with rejoin [ "OK " testname ] 100 #"-"
                print pad/with "" 100 #"-"
                print xml-input
                print pad/with "" 100 #"-"
                print buffer
                print pad/with "" 100 #"-"
                print pad/with "" 100 #"—" ;#"_"
            ][
                print pad/with "" 100 #"="
                print pad/with rejoin [ "NOK >>> " testname " " ] 100 #"="
                print xml-input
                print pad/with "" 100 #"="
                print buffer
                print pad/with rejoin [ "== exp ==" ] 100 #"="
                print out
                print pad/with "" 100 #"="
                print pad/with "" 100 #"—"
            ]

        ] ;parse

        ; locator returned by the reader
        loc: none

        ; output buffer
        buffer: none

        ;;
        ;; output into buf
        ;;
        output: function [ msg [block!] /locate ][
            insert msg ""
            if all [ locate loc ] [
                append msg [ "" msg " - (" loc/line-number ":" loc/column-number ")" ]
            ]
            out: rejoin msg
            if not buffer [
                self/buffer: copy ""
            ]
            append buffer out
            append buffer newline
        ] ;output

        ;;
        ;; Attributes object into debug string
        ;;
        attr-as-string: function [
            attributes [object!] return: [string!]
        ][
            i: 0
            str: copy ""
            while [ i < attributes/length? ][
                i: i + 1
                uri: attributes/uri? i
                local-name: attributes/local-name? i
                qname: attributes/qname? i
                value: attributes/value? i
                spc: either uri [ rejoin [ " <" uri ">" ] ][""]
                append str rejoin [ "" qname spc { = "} value {"} ", " ]
            ]
            if i > 0 [ take/last/part str 2 ]
            str
        ]

        ;;
        ;; content-handler
        ;;
        set-documentLocator: function [ 
            "Receive from the parser an object for locating the origin of SAX document events."
            locator [object!] 
        ][
            self/loc: locator
        ]
        start-document: function [ "Receive notification of the beginning of a document." ] [
            output [ "start-document" ]
        ]
        end-document: function [ "Receive notification of the end of a document."] [
            output [ "end-document" ]
        ]
        start-prefix-mapping: function [ "Begin the scope of a prefix-URI Namespace mapping." 
            prefix [string!] uri [string!]
        ][
            output [ {start-prefix-mapping - '} prefix "' <" uri ">" ]
        ]
        end-prefix-mapping: function [ 
            "End the scope of a prefix-URI mapping." 
            prefix [string!] 
        ][
            output [ {end-prefix-mapping - '} prefix "'" ]
        ]
        start-element: function [ 
            "Receive notification of the beginning of an element." 
            uri [string! none!] local-name [string! none!] qname [string!] attributes [object!]
        ][
            spc: either uri [ rejoin [ " <" uri ">" ] ][""]
            attrs: either attributes/length? > 0 [ rejoin [ " - [ " attr-as-string attributes " ]" ] ][""]
            output [ "start-element - " qname spc attrs ]
        ]
        end-element: function [ 
            "Receive notification of the end of an element." 
            uri [string! none!] local-name [string! none!] qname [string!]
        ][
            spc: either uri [ rejoin [ " <" uri ">" ] ][""]
            output [ "end-element - " qname spc ]
        ]
        characters: function [ 
            "Receive notification of character data." 
            start [string!] length [integer!] ] [
            output [ {characters - "} copy/part start length {"} ]
        ]
        ignorable-whitespace: function [ 
            "Receive notification of ignorable whitespace in element content."
            start [string!] length [integer!]
        ][
            output [ {ignorable-whitespace - "} copy/part start length {"} ]
        ]
        processing-instruction: function [
            "Receive notification of a processing instruction."
            target [string!] data [string!] 
        ][
            output [ "processing-instruction - " target " '" data "'" ]
        ]
        skipped-entity: function [ 
            "Receive notification of a skipped entity."
            name [string!]
        ][
            output [ "skipped-entity - " name ]
        ]

        ;;
        ;; dtd-handler
        ;;
        notation-decl: function [ "Receive notification of a notation declaration event."
            name [string!] public-id [string!] system-id [string!] 
        ][
            output [ "notation-decl - name: " name " public-id: " public-id " system-id: " system-id ]
        ]
        unparsed-entity-decl: function [ "Receive notification of an unparsed entity declaration event."
            name [string!] public-id [string!] system-id [string!] notation-name [string!]
        ][
            output [ "unparsed-entity-decl - name: " name " public-id: " public-id " system-id: " system-id 
            " notation-name: " notation-name ]
        ]

        ;;
        ;; decl-handler
        ;;
        attribute-decl: function [
            "Report an attribute type declaration."
            e-name [string!] a-name [string!] type [string!] mode [string!] value [string!]
        ][
            output [ "attribute-decl - e-name: " e-name " a-name: " a-name " type: " type " mode: " mode " value: " value ]
        ]
        element-decl: function [
            "Report an element type declaration."
            name [string!] model [string!]
        ][
            output [ "element-decl - name: " name " model: " model ]
        ]
        external-entity-decl: function [
            "Report a parsed external entity declaration."
            name [string!] public-id [string!] system-id [string!]
        ][
            output [ "external-entity-decl - name: " name " public-id: " public-id " system-id " system-id ]
        ]
        internal-entity-decl: function [
            "Report an internal entity declaration."
            name [string!] value [string!]
        ][
            output [ "internal-entity-decl - name: " name " value: " value ]
        ]

        ;;
        ;; entity-resolvr
        ;;
        resolve-entity: function [
            "Allow the application to resolve external entities."
            public-id [string!] system-id [string!] return: [ object! ]
        ][
            output [ "resolve-entity - public-id: " public-id " system-id: " system-id ]
            return none
        ]

        ;;
        ;; entity-resolver2
        ;;
        external-subset: function [
            "Allows applications to provide an external subset for documents that don't explicitly define one."
            name [string!] base-uri [string!]
            return: [ object! ] ; input-source
        ][
            output [ "external-subset - name: " name " base-uri: " base-uri ]
            return none
        ]
        resolve-entity-ext: function [
            "Allows applications to map references to external entities into input sources, or tell the parser it should use conventional URI resolution."
            name [string!] public-id [string!] base-uri [string!] system-id [string!]
            return: [ object! ] ; input-source
        ][
            output [ "resolve-entity-ext - name: " name " public-id: " public-id " base-uri: " base-uri " system-id: " system-id ]
            return none
        ]

        ;;
        ;; error-handler
        ;;
        warning: function [
            exception [error!]
        ][
            output [ "warning - " mold exception ]
        ]
        error: function [
            exception [error!]
        ][
            output [ "error - " mold exception ]
        ]
        fatal-error: function [
            exception [error!]
        ][
            output [ "fatal-error - " mold exception ]
        ]

        ;;
        ;; lexical-handler
        ;;
        start-DTD: function [
            "Report the start of DTD declarations, if any."
            name [string!] public-id [string! none!] system-id [string! none!]
        ][
            output [ "start-DTD - name: " name " public-id: " public-id " system-id: " system-id ]
        ]
        end-DTD: function [ "Report the end of DTD declarations." ][
            output [ "end-DTD" ]
        ]
        start-entity: function [
            "Report the beginning of some internal and external XML entities."
            name [string!]
        ][
            output [ "start-entity - name: " name ]
        ]
        end-entity: function [ 
            "Report the end of an entity." name 
        ][
            output [ "end-entity - name: " name ]
        ]
        start-CDATA: function [ 
            "Report the start of a CDATA section." 
        ][
            output [ "start-CDATA" ]
        ]
        end-CDATA: function [
            "Report the end of a CDATA section."
        ][
            output [ "end-CDATA" ]
        ]
        xml-comment: function [
            "Report an XML comment anywhere in the document."
            start [string!] length [integer!] 
        ][
            output [ {xml-comment - "} copy/part start length {"} ]
        ]

        xml-declaration: function [
            "Report additional informations from the prologue"
            xml-version [string! none!]
            encoding [string! none!]
            standalone [logic! none!]
        ][
            output [ "xml-declaration - xml-version: " xml-version " encoding: " encoding " standalone: " standalone ]
        ]

    ] ;test
    tp: none
    do [
        self/tp: :test/parse
    ]

    ; Special assert for the sake of testing
    ; just runs a block of commands and compares the result to an expected value (strict equal)
    ; that's it but pretty useful in itself.
    assert: function [
            test [string!]
            check [block!]
            op [word!]
            against [any-type!]
    ][
        check-value: do check
        against: reduce against
        cond: do reduce [ check-value op against ]
        either cond [
            print [ "OK" test "- test:" mold/flat check "- got:" mold/flat check-value ]
        ][
            print [ "NOK" test "- test:" mold/flat check "- expecting:" mold/flat against "- got:" mold/flat check-value ]
        ]
    ] ; assert

    helper: function [] [
        reader: sax/reader
        ;;
        ;; Test helpers
        ;;
        assert "get-charref#1" [ reader/get-charref "34" ] '== none
        assert "get-charref#2" [ reader/get-charref "&#x110000; "] '== none
        assert "get-charref#3" [ reader/get-charref "&#x3c0;A" ] '== [ #"π" "A" ]
        assert "get-charref#4" [ reader/get-charref "&#198;3" ] '== [ #"Æ" "3" ]
        assert "get-charref#5" [ reader/get-charref "&lt;X" ] '== [ #"<" "X" ]
        assert "get-charref#6" [ reader/get-charref "&lt;" ] '== [ #"<" "" ]
        assert "get-charref#7" [ reader/get-charref "&ampY64332223" ] '== none
        assert "trim-spaces#1" [ reader/trim-spaces copy "   str  s   " ] '== "str s"
        assert "normalise-attr#1" [ reader/normalise-attr "  val  val   val     " ] '== "val val val"
        assert "normalise-attr#1" [ reader/normalise-attr/cdata "val^Mval^M^/val^/" ] '== "val val val "
        assert "normalise-attr#3" [ reader/normalise-attr " &quot; within &quot; &#x3c0; &#64; " ] '== {" within " π @}
        assert "resolve-charrefs#1" [ reader/resolve-charrefs a: "&quot;&#x3c0; &#64;" tail a ] '== [ {"π @} "" ]
        assert "resolve-charrefs#2" [ reader/resolve-charrefs a: "NO & here" tail a ] '== [ "NO & here" "" ]
        assert "resolve-charrefs#3" [ reader/resolve-charrefs a: "NO &quot there" tail a ] '== [ "NO &quot there" "" ]
        assert "resolve-charrefs#4" [ reader/resolve-charrefs a: "YES &quot; this one" tail a ] '== [ {YES " this one} "" ]

    ]; helper

;;
;; Following test functions are not indented as spaces matter in XML
;;

prolog: function []
[

;comment [

;;
;; Test prolog
;;

tp "prolog-1" {<?xml version="1.0" encoding="utf-8"?>} ; at least an element
{
start-document
xml-declaration - xml-version: 1.0 encoding: utf-8 standalone: none
}
tp "prolog-2" {<?xml version="1.0" encoding="utf-8"?><elem/>} 
{
start-document
xml-declaration - xml-version: 1.0 encoding: utf-8 standalone: none
start-element - elem <>
end-element - elem <>
end-document
}
tp "prolog-3" {<?xml version="1.0"  standalone="yes" ?><elem/>}
{
start-document
xml-declaration - xml-version: 1.0 encoding: none standalone: true
start-element - elem <>
end-element - elem <>
end-document
}
tp "prolog-4" {
<elem/>
}{
start-document
start-element - elem <>
end-element - elem <>
end-document
}
tp "prolog-5" {<!-- Hello --><elem/>}{
start-document
xml-comment - " Hello "
start-element - elem <>
end-element - elem <>
end-document
}

tp "prolog-6" { <?xml-stylesheet type="text/xsl" href="style.xsl"?>

<elem/>
}{
start-document
processing-instruction - xml-stylesheet ' type="text/xsl" href="style.xsl"'
start-element - elem <>
end-element - elem <>
end-document
}

; xml declaration, if present, should be the very first thing in the file (not even a space)
tp "prolog-7" {
<?xml version="1.0"?><elem/>
}{
start-document
}

; comment / processing instruction, space, comment after root element
tp "prolog-8" {<elem/>

<!-- Hello --><?process info?>

}
{
start-document
start-element - elem <>
end-element - elem <>
xml-comment - " Hello "
processing-instruction - process ' info'
end-document
}

] ; prolog

element: function [][
;;
;; Test elements
;;

tp "element-1" {
<root><elem/><elem
    /><elem></elem></root>}
{
start-document
start-element - root <>
start-element - elem <>
end-element - elem <>
start-element - elem <>
end-element - elem <>
start-element - elem <>
end-element - elem <>
end-element - root <>
end-document
}

tp "element-2" {<slideshow title="Sample Slide Show" 
date="Date of publication"
    author="Yours Truly"
></slideshow>
}
{
start-document
start-element - slideshow <> - [ title <> = "Sample Slide Show", date <> = "Date of publication", author <> = "Yours Truly" ]
end-element - slideshow <>
end-document
}

tp "element-3" {<item>Why 
<em>WonderWidgets</em> are great</item>}
{
start-document
start-element - item <>
characters - "Why 
"
start-element - em <>
characters - "WonderWidgets"
end-element - em <>
characters - " are great"
end-element - item <>
end-document
}

tp "element-4" {
<theater opening="2006"><name>Bigscreen</name
><showtime><time>19:30</time><price>$6.00</price></showtime
></theater>
}
{
start-document
start-element - theater <> - [ opening <> = "2006" ]
start-element - name <>
characters - "Bigscreen"
end-element - name <>
start-element - showtime <>
start-element - time <>
characters - "19:30"
end-element - time <>
start-element - price <>
characters - "$6.00"
end-element - price <>
end-element - showtime <>
end-element - theater <>
end-document
}

tp "element-5" {
<extra><![CDATA[<projectionist>John Smith</projectionist>]]></extra>
}{
start-document
start-element - extra <>
start-CDATA
characters - "<projectionist>John Smith</projectionist>"
end-CDATA
end-element - extra <>
end-document
}

] ; element

names: function [][
;;
;; Names spaces
;;

tp "names-1" {<?xml version="1.0"?>
<html:html xmlns:html='http://www.w3.org/1999/xhtml'
><html:head><html:title>Frobnostication</html:title></html:head
><html:body><html:p>Moved to <html:a href='http://frob.example.com'
>here.</html:a></html:p></html:body></html:html>
}
{
start-document
xml-declaration - xml-version: 1.0 encoding: none standalone: none
start-prefix-mapping - 'html' <http://www.w3.org/1999/xhtml>
start-element - html:html <http://www.w3.org/1999/xhtml>
start-element - html:head <http://www.w3.org/1999/xhtml>
start-element - html:title <http://www.w3.org/1999/xhtml>
characters - "Frobnostication"
end-element - html:title <http://www.w3.org/1999/xhtml>
end-element - html:head <http://www.w3.org/1999/xhtml>
start-element - html:body <http://www.w3.org/1999/xhtml>
start-element - html:p <http://www.w3.org/1999/xhtml>
characters - "Moved to "
start-element - html:a <http://www.w3.org/1999/xhtml> - [ href <> = "http://frob.example.com" ]
characters - "here."
end-element - html:a <http://www.w3.org/1999/xhtml>
end-element - html:p <http://www.w3.org/1999/xhtml>
end-element - html:body <http://www.w3.org/1999/xhtml>
end-element - html:html <http://www.w3.org/1999/xhtml>
end-prefix-mapping - 'html'
end-document
}

; both namespace prefixes are available throughout
tp "names-2" {
<bk:book xmlns:bk='urn:loc.gov:books' xmlns:isbn='urn:ISBN:0-395-36341-6'
><bk:title>Cheaper by the Dozen</bk:title
><isbn:number>1568491379</isbn:number></bk:book>
}
{
start-document
start-prefix-mapping - 'bk' <urn:loc.gov:books>
start-prefix-mapping - 'isbn' <urn:ISBN:0-395-36341-6>
start-element - bk:book <urn:loc.gov:books>
start-element - bk:title <urn:loc.gov:books>
characters - "Cheaper by the Dozen"
end-element - bk:title <urn:loc.gov:books>
start-element - isbn:number <urn:ISBN:0-395-36341-6>
characters - "1568491379"
end-element - isbn:number <urn:ISBN:0-395-36341-6>
end-element - bk:book <urn:loc.gov:books>
end-prefix-mapping - 'isbn'
end-prefix-mapping - 'bk'
end-document
}

; default namespace
tp "names-3" {
<html xmlns='http://www.w3.org/1999/xhtml'
><body><p>Moved to <a href='http://frob.example.com'>here</a>.</p></body
></html>
}
{
start-document
start-prefix-mapping - '' <http://www.w3.org/1999/xhtml>
start-element - html <http://www.w3.org/1999/xhtml>
start-element - body <http://www.w3.org/1999/xhtml>
start-element - p <http://www.w3.org/1999/xhtml>
characters - "Moved to "
start-element - a <http://www.w3.org/1999/xhtml> - [ href <> = "http://frob.example.com" ]
characters - "here"
end-element - a <http://www.w3.org/1999/xhtml>
characters - "."
end-element - p <http://www.w3.org/1999/xhtml>
end-element - body <http://www.w3.org/1999/xhtml>
end-element - html <http://www.w3.org/1999/xhtml>
end-prefix-mapping - ''
end-document
}

; unprefixed element types are from "books" prefixed from "isbn"
tp "names-4" {<book xmlns='urn:loc.gov:books'
xmlns:isbn='urn:ISBN:0-395-36341-6'
><title>Cheaper by the Dozen</title
><isbn:number>1568491379</isbn:number
></book>}
{
start-document
start-prefix-mapping - '' <urn:loc.gov:books>
start-prefix-mapping - 'isbn' <urn:ISBN:0-395-36341-6>
start-element - book <urn:loc.gov:books>
start-element - title <urn:loc.gov:books>
characters - "Cheaper by the Dozen"
end-element - title <urn:loc.gov:books>
start-element - isbn:number <urn:ISBN:0-395-36341-6>
characters - "1568491379"
end-element - isbn:number <urn:ISBN:0-395-36341-6>
end-element - book <urn:loc.gov:books>
end-prefix-mapping - 'isbn'
end-prefix-mapping - ''
end-document
}

; namespace can be overloaded
tp "names-5" {<book xmlns='urn:loc.gov:books'
xmlns:isbn='urn:ISBN:0-395-36341-6'
><title>Cheaper by the Dozen</title
><isbn:number>1568491379</isbn:number
><notes
><p xmlns='http://www.w3.org/1999/xhtml'
>This is a <i>funny</i> book!</p></notes
></book>}
{
start-document
start-prefix-mapping - '' <urn:loc.gov:books>
start-prefix-mapping - 'isbn' <urn:ISBN:0-395-36341-6>
start-element - book <urn:loc.gov:books>
start-element - title <urn:loc.gov:books>
characters - "Cheaper by the Dozen"
end-element - title <urn:loc.gov:books>
start-element - isbn:number <urn:ISBN:0-395-36341-6>
characters - "1568491379"
end-element - isbn:number <urn:ISBN:0-395-36341-6>
start-element - notes <urn:loc.gov:books>
start-prefix-mapping - '' <http://www.w3.org/1999/xhtml>
start-element - p <http://www.w3.org/1999/xhtml>
characters - "This is a "
start-element - i <http://www.w3.org/1999/xhtml>
characters - "funny"
end-element - i <http://www.w3.org/1999/xhtml>
characters - " book!"
end-element - p <http://www.w3.org/1999/xhtml>
end-prefix-mapping - ''
end-element - notes <urn:loc.gov:books>
end-element - book <urn:loc.gov:books>
end-prefix-mapping - 'isbn'
end-prefix-mapping - ''
end-document
}

; Default name space provided may be empty
tp "names-6" {
<Beers><table xmlns='http://www.w3.org/1999/xhtml'
><th><td>Name</td></th
><tr><td><details xmlns=""><class>Bitter</class><hop>Fuggles</hop
></details></td></tr><tr><td>Royal Oak</td></tr></table></Beers>}
{
start-document
start-element - Beers <>
start-prefix-mapping - '' <http://www.w3.org/1999/xhtml>
start-element - table <http://www.w3.org/1999/xhtml>
start-element - th <http://www.w3.org/1999/xhtml>
start-element - td <http://www.w3.org/1999/xhtml>
characters - "Name"
end-element - td <http://www.w3.org/1999/xhtml>
end-element - th <http://www.w3.org/1999/xhtml>
start-element - tr <http://www.w3.org/1999/xhtml>
start-element - td <http://www.w3.org/1999/xhtml>
start-prefix-mapping - '' <>
start-element - details <>
start-element - class <>
characters - "Bitter"
end-element - class <>
start-element - hop <>
characters - "Fuggles"
end-element - hop <>
end-element - details <>
end-prefix-mapping - ''
end-element - td <http://www.w3.org/1999/xhtml>
end-element - tr <http://www.w3.org/1999/xhtml>
start-element - tr <http://www.w3.org/1999/xhtml>
start-element - td <http://www.w3.org/1999/xhtml>
characters - "Royal Oak"
end-element - td <http://www.w3.org/1999/xhtml>
end-element - tr <http://www.w3.org/1999/xhtml>
end-element - table <http://www.w3.org/1999/xhtml>
end-prefix-mapping - ''
end-element - Beers <>
end-document
}

; default namespace can be empty if not set explicitly, prefix can be unset
tp "names-7" {
<bk:book xmlns:bk='urn:loc.gov:books'
><bk:title>Cheaper by the Dozen</bk:title
><isbn:number>1568491379 <i>temporary</i></isbn:number></bk:book>
}
{
start-document
start-prefix-mapping - 'bk' <urn:loc.gov:books>
start-element - bk:book <urn:loc.gov:books>
start-element - bk:title <urn:loc.gov:books>
characters - "Cheaper by the Dozen"
end-element - bk:title <urn:loc.gov:books>
start-element - isbn:number
characters - "1568491379 "
start-element - i <>
characters - "temporary"
end-element - i <>
end-element - isbn:number
end-element - bk:book <urn:loc.gov:books>
end-prefix-mapping - 'bk'
end-document
}

; a prefixe edi overloaded
tp "names-8" {<edi:x xmlns:edi='http://ecommerce.example.org/schema'
><edi:price xmlns:edi='http://newcommerce.example.org/schema' units='Euro'
>32.18</edi:price></edi:x>}
{
start-document
start-prefix-mapping - 'edi' <http://ecommerce.example.org/schema>
start-element - edi:x <http://ecommerce.example.org/schema>
start-prefix-mapping - 'edi' <http://newcommerce.example.org/schema>
start-element - edi:price <http://newcommerce.example.org/schema> - [ units <> = "Euro" ]
characters - "32.18"
end-element - edi:price <http://newcommerce.example.org/schema>
end-prefix-mapping - 'edi'
end-element - edi:x <http://ecommerce.example.org/schema>
end-prefix-mapping - 'edi'
end-document
}

; no prefix un-declaring - @ZWT should trigger a warning
tp "names-9" {<edi:x xmlns:edi='http://ecommerce.example.org/schema'
><edi:price xmlns:edi='' units='Euro'
>32.18</edi:price></edi:x>}
{
start-document
start-prefix-mapping - 'edi' <http://ecommerce.example.org/schema>
start-element - edi:x <http://ecommerce.example.org/schema>
start-element - edi:price <http://ecommerce.example.org/schema> - [ xmlns:edi = "", units <> = "Euro" ]
characters - "32.18"
end-element - edi:price <http://ecommerce.example.org/schema>
end-element - edi:x <http://ecommerce.example.org/schema>
end-prefix-mapping - 'edi'
end-document
}

; qualified attribute
tp "names-10" {<x xmlns:edi="http://ecommerce.example.org/schema"
><lineItem edi:taxClass="exempt">Baby food</lineItem></x>
}
{
start-document
start-prefix-mapping - 'edi' <http://ecommerce.example.org/schema>
start-element - x <>
start-element - lineItem <> - [ edi:taxClass <http://ecommerce.example.org/schema> = "exempt" ]
characters - "Baby food"
end-element - lineItem <>
end-element - x <>
end-prefix-mapping - 'edi'
end-document
}

; attributes are unique - keep first one
tp "names-11" {<x><bad a="1"  
a="2" /></x>}
{
start-document
start-element - x <>
start-element - bad <> - [ a <> = "1" ]
end-element - bad <>
end-element - x <>
end-document
}

; attributes are unique, through name mapping - keep first one
tp "names-12" {
<x xmlns:n1="http://www.w3.org" 
xmlns:n2="http://www.w3.org" ><bad n1:a="1"  n2:a="2"
/></x>}
{
start-document
start-prefix-mapping - 'n1' <http://www.w3.org>
start-prefix-mapping - 'n2' <http://www.w3.org>
start-element - x <>
start-element - bad <> - [ n1:a <http://www.w3.org> = "1" ]
end-element - bad <>
end-element - x <>
end-prefix-mapping - 'n2'
end-prefix-mapping - 'n1'
end-document
}

; this works as in the second line, the default-namespace does not apply to attributes
tp "names-13" {
<x xmlns:n1="http://www.w3.org" 
xmlns="http://www.w3.org" 
><good a="1"     b="2" 
/><good a="1"     n1:a="2" 
/></x>
}
{
start-document
start-prefix-mapping - 'n1' <http://www.w3.org>
start-prefix-mapping - '' <http://www.w3.org>
start-element - x <http://www.w3.org>
start-element - good <http://www.w3.org> - [ a <> = "1", b <> = "2" ]
end-element - good <http://www.w3.org>
start-element - good <http://www.w3.org> - [ a <> = "1", n1:a <http://www.w3.org> = "2" ]
end-element - good <http://www.w3.org>
end-element - x <http://www.w3.org>
end-prefix-mapping - ''
end-prefix-mapping - 'n1'
end-document
}

] ; names

other: function [][

;;
;; Other
;;

; char refs in content
tp "other-1" {<x>Type <key>less-than</key> (&#x3C0;) to save options. &#169; New institution
This &lt;document&gt; was prepared on &docdate; &amp;
is &apos;classified&apos; and not accessible &quot; - &security-level;.<y/>&quot;</x>}
{
start-document
start-element - x <>
characters - "Type "
start-element - key <>
characters - "less-than"
end-element - key <>
characters - " ("
characters - "π"
characters - ") to save options. "
characters - "©"
characters - " New institution
This "
characters - "<"
characters - "document"
characters - ">"
characters - " was prepared on "
characters - "&docdate;"
characters - " "
characters - "&"
characters - "
is "
characters - "'"
characters - "classified"
characters - "'"
characters - " and not accessible "
characters - """
characters - " - "
characters - "&security-level;"
characters - "."
start-element - y <>
end-element - y <>
characters - """
end-element - x <>
end-document
}

; char refs works also in attribute values, comments, processing instructions but not cdata
tp "other-2" {<x name="  &quot;quoted&quot;    and pi: &#x3C0;  "
><!--&lt;a commment &#169;&gt;--><?process &lt;&#x3C0;&gt;?><![CDATA[no replacement here &lt;&#x3C0;&gt;]]></x>}
{
start-document
start-element - x <> - [ name <> = ""quoted" and pi: π" ]
xml-comment - "<a commment ©>"
processing-instruction - process ' <π>'
start-CDATA
characters - "no replacement here &lt;&#x3C0;&gt;"
end-CDATA
end-element - x <>
end-document
}

; comment cannot have --
tp "other-3" {<!-- A wrong -- comment --><elem/>}
{
start-document
}

tp "other-4" {<!-- A good - comment --><elem/>}
{
start-document
xml-comment - " A good - comment "
start-element - elem <>
end-element - elem <>
end-document
}

] ; other

dtd: function [][
;;
;; DTD
;;
tp "dtd-1" {<!DOCTYPE page [LF  <!ENTITY abc "ABC Inc">LF]
><!DOCTYPE note SYSTEM "Note.dtd">}
{}

tp "dtd-2" {<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE note SYSTEM "Note.dtd">
<note><to>Tove</to><from>Jani</from><heading>Reminder</heading
><body>Don't forget me this weekend!</body
></note>
}
{}

tp "dtd-3" {
<!DOCTYPE note
[
<!ELEMENT note (to,from,heading,body)>
<!ELEMENT to (#PCDATA)>
<!ELEMENT from (#PCDATA)>
<!ELEMENT heading (#PCDATA)>
<!ELEMENT body (#PCDATA)>
]>
}
{}

tp "dtd-4" {
<!ENTITY open-hatch
        SYSTEM "http://www.textuality.com/boilerplate/OpenHatch.xml">
<!ENTITY open-hatch
        PUBLIC "-//Textuality//TEXT Standard open-hatch boilerplate//EN"
        "http://www.textuality.com/boilerplate/OpenHatch.xml">
<!ENTITY hatch-pic
        SYSTEM "../grafix/OpenHatch.gif"
        NDATA gif >
}
{}

tp "dtd-5" {
<!DOCTYPE test PUBLIC "//this/is/a/URI/test" "test.dtd" [
<!NOTATION jpg PUBLIC "JPG 1.0">
<!NOTATION gif PUBLIC "GIF 1.0">
<!NOTATION png PUBLIC "PNG 1.0">
<!NOTATION jpg PUBLIC "JPG 1.0" "image/jpeg">
<!NOTATION gif PUBLIC "GIF 1.0" "image/gif">
<!NOTATION png PUBLIC "PNG 1.0" "image/png">
<!NOTATION gif SYSTEM "image/gif">
<!NOTATION jpg SYSTEM "image/jpeg">
<!NOTATION png SYSTEM "image/png">
<!NOTATION gif89a PUBLIC "-//CompuServe//NOTATION Graphics Interchange Format 89a//EN" "gif">
<!NOTATION TeX  PUBLIC "//this/is/a/URI/TexID" "//TexID">
]>
}
{}

tp "dtd-6" {
<!DOCTYPE test PUBLIC "//this/is/a/URI/test" "test.dtd" [
<!NOTATION TeX  PUBLIC "//this/is/a/URI/TexID" "//TexID">
<!ENTITY ent1 "this is an entity">
<!ENTITY % ent2 "#PCDATA | subel2">
<!ENTITY % extent1 PUBLIC "//this/is/a/URI/extent1" "more.txt">
<!ENTITY extent2 PUBLIC "//this/is/a/URI/extent2" "more.txt">
<!ENTITY unpsd PUBLIC "//this/is/a/URI/me.gif" "me.gif" NDATA TeX>
<?test Do this?>
<!--this is a comment-->
<!ELEMENT subel2 (#PCDATA)>
<!ELEMENT subel1 (subel2 | el4)+>
<!ELEMENT el1 (#PCDATA)>
<!ELEMENT el2 (#PCDATA | subel2)*>
<!ELEMENT el3 (#PCDATA | subel2)*>
<!ELEMENT el4 (#PCDATA)>
<!ELEMENT el5 (#PCDATA | subel1)*>
<!ELEMENT el6 (#PCDATA)>
<!ATTLIST subel1 
    size (big | small) "big" 
    shape (round | square) #REQUIRED>
<!ATTLIST el5 
    el5satt CDATA #IMPLIED>
]>
}
{}

tp "dtd-7" {
    <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
        "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd" [
    <!NOTATION TeX  PUBLIC "//this/is/a/URI/TexID" "/TexID">
    ]>
    <html>
    </html>
}
{}

]; dtd

]; test-sax

test-sax/helper
test-sax/prolog
test-sax/element
test-sax/names
test-sax/other

;test-sax/dtd

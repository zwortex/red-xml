Red [
	Title:          "SAX"
    File:           "%sax.red"
	Description:    "Event oriented XML parser"
	Author:         @zwortex
    Date:           2021-09-23
    Changelog: {
        0.1.0 - 23/09/2021
            * initial version
    }
	Notes: {
        - Red implementation of SAX interface for parsing XML files
        - DTD support pending
	}
]

;; 
;; Global context for isolating xml library
;;
sax: context [

; to avoid conflicting names if any
g-length?: :system/words/length?

;; INTRODUCTION
comment [
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;
    ; This package implements the SAX api (Simple API for XML) by David Megginson
    ; in its version 2 (SAX2.0.1).
    ;
    ; SAX is the de-facto standard for all stateless XML parser : those parsers
    ; that scan through an XML document from start to end, in forward only mode,
    ; and reports XML elements and structures as they are found to the application,
    ; by means of callbacks.
    ;
    ; For more information on SAX, see:
    ;   http://www.saxproject.org/about.html
    ;   https://sourceforge.net/projects/sax/
    ;   https://en.wikipedia.org/wiki/Simple_API_for_XML
    ;
    ; The object XML/READER is used as the base for some more elaborate readers :
    ;   - xml-test : for testing the parsing - it merely echos the xml document's content.
    ;   - xml-to-red : 
    ;   - xml-to-json : for loading an xml document into a json-like structure
    ;
    ; While porting the api written in Java, names have been adjusted to adhere
    ; to Red coding style. For instance,
    ;   XMLReader object translates into xml-reader.
    ;   endElement function translates into end-element
    ;   localName argument converts into local-name
    ;
    ; In other cases, names have been changed to get closer to Red naming conventions
    ; for instance index? rather than getIndex.
    ;
    ; Names may change also in case of name conflicts, as in Java language, the function
    ; arguments are part of the function signature. For instance, if you may have
    ; in the same object, two functions that are called getIndex :
    ;   int getIndex(java.lang.String uri, java.lang.String localName)
    ;   int getIndex(java.lang.String qName)
    ; you end up with two different names: 
    ;   index-l?: function [ uri [string!] local-name [string!] ]
    ;   index-q?: function [ qname [string!] return: [integer!] ]	
    ;
    ; Otherwise, the interface is mostly respected.
    ;
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
];INTRODUCTION

;SAX INTERFACE
comment [
    ;;=======================================================================
    ;;=======================================================================
    ;;
    ;; SAX interface : following objects implement the sax interface.
    ;;
    ;; They are not actual objects but equivalent to Java interface
    ;; objects that need to be overloaded.
    ;;
    ;;=======================================================================
    ;;=======================================================================
];SAX INTERFACE

reader!: make reactor! [

    ;;=======================================================================
    ;;
    ;; READER! : Interface for an XML reader
    ;;
    ;;  @see org.xml.sax.XMLReader
    ;;
    ;; Notes :
    ;;
    ;; - READER! implements Reactor!
    ;;
    ;; reader implements reactor!, but it not for handling callbacks
    ;; to the application but to track updates to its own internals.
    ;; @see xml/reader/content-handler
    ;;
    ;;=======================================================================

    ;;
    ;; Configuration
    ;;

    ;; Feature : logic! values to alter parsing features
    ;; All XMLReaders are required to handle the following set of features
    ;; http://www.saxproject.org/apidoc/org/xml/sax/package-summary.html#package_description
    get-feature: function [ "Look up the value of a feature flag." name [string!] return: [logic!] ][ return false ]
    set-feature: function [ "Set the value of a feature flag." name [string!] value [logic!] ][ ]

    ;; Property : any-type! values to alter parsing features
    ;; see also some possible properties in 
    ;; http://www.saxproject.org/apidoc/org/xml/sax/package-summary.html#package_description
    get-property: function [ "Look up the value of a property."
        name [string!] "The property name, which is a fully-qualified URI." return: [any-type!] ][ return none ]
    setProperty: function [ "Set the value of a property." name [tag!] "" value [any-type!] "" ][ ]

    ;;
    ;; Event handlers
    ;; 
    ;; If the application does not register a specific event handler,
    ;; the reader will ignore the event.
    ;;
    ;; Applications may register a new or different resolver in the
    ;; middle of a parse, and the SAX parser will begin using the new
    ;; resolver immediately.
    ;;
    ;; ( the parser is notified when a handler is changed, using the ownership interface. )
    ;;

    ; current content handler
    content-handler: none ; content-handler! object

    ; current dtd handler
    dtd-handler: none ; dtd-handler! object

    ; current decl handler 
    decl-handler: none ; dcl-handler! object

    ; current entity resolver
    entity-resolver: none ; entity-resolver! object

    ; current entity resolver2
    entity-resolver2: none ; entity-resolver2! object

    ; current error handler
    error-handler: none ; error-handler! object

    ; lexical handler
    lexical-handler: none ; lexical! object

    ; extended handler
    extended-handler: none ; extended handler object

    ;;
    ;; Parsing
    ;;
    parse-xml: function [ xml-source [ string! port! ] ][]

    ; other parse functions - using a different source
    ;parse-source: function [ "Parse an XML document." input [ object! ] ] []
    ;parse-uri: function [ "Parse an XML document from a system identifier (URI)." system-id [ string! ] ] []

];reader!

entity-resolver!: make object! [
    ;;=======================================================================
    ;;
    ;; ENTITY-RESOLVER! : Interface for resolving external entities
    ;;
    ;; @see org.xml.sax.EntityResolver
    ;;
    ;;=======================================================================
    resolve-entity: function [
        "Allow the application to resolve external entities."
        public-id [string!] system-id [string!] return: [ object! ]
    ][ return none ]
];entity-resolver!

entity-resolver2!: make object! [

    ;;=======================================================================
    ;;
    ;; ENTITY-RESOLVER2! : Extended interface for resolving external entities
    ;;
    ;; @see org.xml.sax.ext.EntityResolver2
    ;;
    ;;=======================================================================

    external-subset: function [
        "Allows applications to provide an external subset for documents that don't explicitly define one."
        name [string!] base-uri [string!]
        return: [ object! ] ; input-source
    ][ return none ]
    resolve-entity-ext: function [
        "Allows applications to map references to external entities into input sources, or tell the parser it should use conventional URI resolution."
        name [string!] public-id [string!] base-uri [string!] system-id [string!]
        return: [ object! ] ; input-source
    ][ return none ]

];entity-resolver2!

dtd-handler!: make object! [
    ;;=======================================================================
    ;;
    ;; DTD-HANDLER! : Receives notification of basic DTD-related events.
    ;;
    ;; @see org.xml.sax.DtdHandler
    ;;
    ;;=======================================================================
    notation-decl: function [ "Receive notification of a notation declaration event."
        name [string!] public-id [string!] system-id [string!] ][]
    unparsed-entity-decl: function [ "Receive notification of an unparsed entity declaration event."
        name [string!] public-id [string!] system-id [string!] notation-name [string!] ][]
];dtd-handler!

decl-handler!: make object! [
    ;;=======================================================================
    ;;
    ;; DECL-HANDLER! : Extended DTD declarations
    ;;
    ;; @see org.xml.sax.ext.DeclHandler
    ;;
    ;;=======================================================================
    attribute-decl: function [
        "Report an attribute type declaration."
        e-name [string!] a-name [string!] type [string!] mode [string!] value [string!]
    ][]
    element-decl: function [
        "Report an element type declaration."
        name [string!] model [string!]
    ][]
    external-entity-decl: function [
        "Report a parsed external entity declaration."
        name [string!] public-id [string!] system-id [string!]
    ][]
    internal-entity-decl: function [
        "Report an internal entity declaration."
        name [string!] value [string!]
    ][]
];decl-handler!

content-handler!: make object! [
    ;;=======================================================================
    ;;
    ;; CONTENT-HANDLER! : receives notification of the logical content 
    ;; of a document.
    ;;
    ;; @see org.xml.sax.ContentHandler
    ;;
    ;;=======================================================================
    set-document-locator: function [ 
        "Receive from the parser an object for locating the origin of SAX document events." 
        locator [object!] 
    ][]
    start-document: function [ "Receive notification of the beginning of a document." ][]
    end-document: function [ "Receive notification of the end of a document."][]
    start-prefix-mapping: function [ 
        "Begin the scope of a prefix-URI Namespace mapping." 
        prefix [string!] uri [string!]
    ][]
    end-prefix-mapping: function [ "End the scope of a prefix-URI mapping." prefix [string!] ][]
    start-element: function [
        "Receive notification of the beginning of an element." 
        uri [string! none!] local-name [string! none!] qname [string! none!] attributes [object!] 
    ][]
    end-element: function [
        "Receive notification of the end of an element."
        uri [string! none!] local-name [string! none!] qname [string! none!]
    ][]
    characters: function [ 
        "Receive notification of character data." 
        start [string!] length [integer!]
    ][]
    ignorable-whitespace: function [ 
        "Receive notification of ignorable whitespace in element content."
        start [string!] length [string!]
    ][]
    processing-instruction: function [
        "Receive notification of a processing instruction."
        target [string!] data [string!]
    ][]
    skipped-entity: function [ 
        "Receive notification of a skipped entity."
        name [string!]
    ][]
];content-handler!

error-handler!: make object! [
    ;;=======================================================================
    ;;
    ;; ERROR-HANDLER! : interface for error handling
    ;;
    ;; @see org.xml.sax.ErrorHandler
    ;;
    ;;=======================================================================
    warning: function [ "Receive notification of a warning." exception [error!] ] []
    error: function [ "Receive notification of a recoverable error." exception [error!] ] []
    fatal-error: function [ "Receive notification of a non-recoverable error." exception [error!] ] []
];error-handler!

lexical-handler!: make object! [
    ;;=======================================================================
    ;;
    ;; LEXICAL-HANDLER! : sax2 complements to content-handler
    ;;
    ;; @see org.xml.sax.ext.LexicalHandler
    ;;
    ;;=======================================================================
    start-DTD: function [
        "Report the start of DTD declarations, if any."
        name [string!] public-id [string! none!] system-id [string! none!]
    ][]
    end-DTD: function [ "Report the end of DTD declarations." ][]
    start-entity: [
        "Report the beginning of some internal and external XML entities."
        name [string!]
    ][]
    end-entity: function [ "Report the end of an entity." name ][]
    start-CDATA: function [ "Report the start of a CDATA section." ][]
    end-CDATA: function [ "Report the end of a CDATA section." ][]
    xml-comment: function [
        "Report an XML comment anywhere in the document."
        start [string!] length [integer!] 
    ][]
];lexical-handler!

extended-handler!: make object! [
    ;;=======================================================================
    ;;
    ;; EXTENDED-HANDLER! : not part of SAX
    ;; used to report additional values from the document
    ;;
    ;;=======================================================================
    xml-declaration: function [
        "Report additional informations from the prologue"
        xml-version [string! none!]
        encoding [string! none!]
        standalone [logic! none!]
    ][]

];extended-handler!

default-handler!: construct compose [
    ;;=======================================================================
    ;;
    ;; DEFAULT-HANDLER! : merge all handler interfaces for convenience
    ;;
    ;; see org.xml.sax.helpers.DefaultHandler and org.xml.sax.ext.DefaultHandler2
    ;;
    ;;=======================================================================
    ( body-of content-handler! )
    ( body-of dtd-handler! )
    ( body-of decl-handler! )
    ( body-of entity-resolver! )
    ( body-of entity-resolver2! )
    ( body-of error-handler! )
    ( body-of lexical-handler! )
    ( body-of extended-handler! )
];default-handler!

attributes!: make object! [
    ;;=======================================================================
    ;;
    ;; ATTRIBUTES! : interface for accessing the attributes of an XML element
    ;;
    ;; @see org.xml.sax.Attributes and org.xml.sax.ext.Attributes2
    ;;
    ;;=======================================================================

    ;;
    ;; indexed access
    ;;
    length?: function [ "Return the number of attributes in the list" return: [integer!] ] [ -1 ]
    uri?: function [ "Look up an attribute's Namespace URI by index." index [integer!] return: [string! none!] ] [ none ]
    local-name?: function [ "Look up an attribute's local name by index." index [integer!] return: [string! none!] ] [ none ]
    qname?: function [ "Look up an attribute's XML qualified (prefixed) name by index." index [integer!] return: [string! none!] ] [ none ]
    type?: function [ "Look up an attribute's type by index." index [integer!] return: [string! none!] ] [ none ]
    value?: function [ "Look up an attribute's value by index." index [integer!] return: [string! none!] ] [ none ]

    ;;
    ;; name-based query
    ;;
    index-l?: function [ "Look up the index of an attribute by Namespace name." uri [string!] local-name [string!] return: [integer!] ] [ -1 ]
    type-l?: function [ "Look up an attribute's type by Namespace name." uri [string!] local-name [string!] return: [string! none!] ] [ none ]
    value-l?: function [ "Look up an attribute's value by Namespace name." uri [string!] local-name [string!] return: [string! none!] ] [ none ]

    index-q?: function [ "Look up the index of an attribute by XML qualified (prefixed) name." qname [string!] return: [integer!] ] [ -1 ]
    type-q?: function [ "Look up an attribute's type by XML qualified (prefixed) name." qname [string!] return: [string! none!] ] [ none ]
    value-q?: function [ "Look up an attribute's value by XML qualified (prefixed) name." qname [string!] return: [string! none!] ] [ none ]

];attributes!;

locator!: make object! [
    ;;=======================================================================
    ;;
    ;; LOCATOR! : interface for tracking the current document location
    ;; while parsing
    ;;
    ;; @see org.xml.sax.Locator and org.xml.sax.ext.Locator2
    ;;
    ;;=======================================================================
    public-id: function [ "Return the public identifier for the current document event." return: [string!] ] [ none ]
    system-id: function [ "Return the system identifier for the current document event." return: [string!] ] [ none ]
    line-number: function [ "Return the line number where the current document event ends." return: [integer!] ] [ -1 ]
    column-number: function [ "Return the column number where the current document event ends." return: [integer!] ] [ -1 ]
    encoding: function [ "Returns the name of the character encoding for the entity." return: [string! none!] ] [ return none ]
    xml-version: function [ "Returns the version of XML used for the entity." return: [string! none!] ] [ return none ]
];locator!

;; SAX IMPLEMENTATION
comment [
];SAX IMPLEMENTATION

reader: make reader! [

    ;;=======================================================================
    ;;
    ;; READER : implements the SAX reader! interface using parse function
    ;;
    ;;=======================================================================

    ;;
    ;; Init reader's defaults
    ;;
    _reinit: function [][
        put features feature-namespace-prefixes false
    ]

    ;;
    ;; Reset the parser between two parses
    ;; do not reset default feature settings
    ;;
    _reset: function [][

        ; collected and locator values
        self/system-id: none
        self/public-id: none
        self/match-start: none
        self/match-end: none
        self/last-newline: none
        self/nb-lines: none

        ; reinstate default entities
        self/entities: copy default-entities

        ; namespaces
        clear namespaces
        put/case namespaces "xml" "http://www.w3.org/XML/1998/namespace"  ; it may be redefined but not overriden
        put/case namespaces "xmlns" "http://www.w3.org/2000/xmlns/"       ; if cannot be redefined nor overriden
        put/case namespaces "" ""                                         ; default namespace is empty

        ; stack
        clear stack

    ]

    ;
    ; Parse function used - default to standard parse function
    ;
    parse-function: :system/words/parse

    ;;
    ;; Parse function
    ;;
    parse-xml: function [ xml-source [ string! port! ] ][
        parse-function/case xml-source rules/document
    ]

    ; Map for features
    features: #()
    get-feature: function [ "Look up the value of a feature flag." name [string!] return: [logic!] ][ return false ]
    set-feature: function [ "Set the value of a feature flag." name [string!] value [logic!] ][ ]

    ; Map for properties
    properties: #()
    get-property: function [ "Look up the value of a property."
        name [string!] "The property name, which is a fully-qualified URI." return: [any-type!] ][ return none ]
    setProperty: function [ "Set the value of a property." name [tag!] "" value [any-type!] "" ][ ]

    ;; Helper function to check handler existence and call-back
    check-handler: function [
        "Returns true if the given call-backs is set"
        handler-w [word!]
        callback-w [word!]
        return: [function!]
    ][
        either all [
            h: get in self handler-w
            c: get in h callback-w 
        ][
            return :c
        ][
            return none
        ]
    ]

    ;;
    ;; Handler
    handler: none

    ; use the reactor interface to update related slots => too complex if you ask me
    on-handler-update: function [ src dest ][
        dest/content-handler: src/handler
        dest/dtd-handler: src/handler
        dest/decl-handler: src/handler
        dest/entity-resolver: src/handler
        dest/entity-resolver2: src/handler
        dest/error-handler: src/handler
        dest/lexical-handler: src/handler
        dest/extended-handler: src/handler
    ]
    on-content-handler-update: function [ src dest ][
        if src/content-handler [
            attempt [ src/content-handler/set-document-locator src/locator ]
        ]
    ]

    ; use the reactor interface to update itself when handlers are updated
    do [
        react/link :on-handler-update [ self self ]
        react/link :on-content-handler-update [ self self ]
    ]

    ;;
    ;; Some values collected from ongoing parsing
    ;;
    system-id: none
    public-id: none

    ;;
    ;; Locator to track the position in the document during the parse
    ;;

    ;; Match start and end
    match-start: none ; start of the current matching rule
    match-end: none ; end of the current matching rule

    ;; Newlines counter
    last-newline: none ; last newline encountered in the document (included the last matching rule)
    nb-lines: 0 ; number of lines encountered (included the last matching rule)

    ;; Start the locator - called at the beginning of the parse
    mark-start: function [ rule [word!] start [string!] ] [
        self/match-start: self/match-end: self/last-newline: start
        self/nb-lines: 1
    ]

    ;; Mark keeps track of progresses within the document
    ;; It is called by any rule that triggers a callback call to set the locator properly
    mark: function [ rule [word!] start [string!] ende [string!]]  [
        ; check new match-start and last match-end are identical 
        ; should not occur as it suggests a matching rule (that makes the parse progess)
        ; lacks a call to mark function
        if match-end <> start [
            either all [ match-end start ] [
                print [ "Warning : offset with " rule " of " offset? match-end start ]
            ][
                print [ "Warning : unexpected markers for " rule ]
            ]
            print [ "Last-end:" mold/part match-end 30 ]
            print [ "New-start:" mold/part start 30 ]
        ]
        ; retrieve rules markers
        self/match-start: start
        self/match-end: ende
        ; adjust newline and nb-lines - see XML - End-of-Line Handling
        c: match-start
        while [ c < match-end ][
            switch c/1 [
                #"^(0D)" [ ; CR or CR LF
                    if c/2 == #"^(0A)" [
                        c: next c
                    ]
                    self/last-newline: c
                    self/nb-lines: nb-lines + 1
                ]
                #"^(0A)" [ ; LF alone
                    self/last-newline: c
                    self/nb-lines: nb-lines + 1
                ]
            ]
            c: next c
        ]
    ]

    ;; Locator object used to inform the caller of the progress in the parsing
    ;; @see SAX Locator
    locator: make locator! [

        public-id: function [
            "Return the public identifier for the current document event."
            return: [string!] 
        ][ 
            return public-id
        ]
        system-id: function [
            "Return the system identifier for the current document event."
            return: [string!]
        ][
            return system-id
        ]
        line-number: function [ 
            "Return the line number where the current document event ends."
            return: [integer!]
        ][
            return nb-lines
        ]
        column-number: function [
            "Return the column number where the current document event ends."
            return: [integer!]
        ][
            return ( offset? last-newline match-end ) - 1
        ]
        encoding: function [
            "Returns the name of the character encoding for the entity."
            return: [string! none!]
        ][
            return none
        ]
        xml-version: function [
            "Returns the version of XML used for the entity."
            return: [string! none!]
        ][
            return none
        ]

    ]

    ;;
    ;; Normalise characters that are sent back to the application
    ;; in practice, just clean-up newlines : remove CRs, keep only OAs (see XML > 2.11 End-of-Line Handling )
    normalise-characters: function [
        buf [string!] len [integer!]
        return: [ string! logic! ]
        /test
    ][
        if test [
            normalize?: false
            foreach c buf [
                if c == #"^(0D)" [
                    normalize?: true
                    break
                ]
            ]
            return normalize?
        ]
        cp: copy/part buf len
        replace/all cp [ "^(0D)^(0A)" | "^(0D)" ] "^(0A)"
        print [ "cp" mold cp ]
        cp
    ]

    ;;
    ;; Compute the character corresponding to the given char reference if any
    ;;
    get-charref: function [ str [string!] return: [block! none!] ][
        chars-dec: charset [ #"0" - #"9" ]
        chars-hex: union chars-dec charset [ #"A" - #"Z" #"a" - #"z" ]
        c: none
        if str/1 == #"&" [
            ; search for character reference
            either str/2 == #"#" [
                nb: 0
                s: str
                either s/3 == #"x" [
                    s: at s 4
                    while [ chars-hex/(s/1) ] [
                        i: to-integer case [
                            s/1 <= #"9" [ s/1 - #"0" ]
                            s/1 <= #"Z" [ s/1 - #"A" + 10 ]
                            true [ s/1 - #"a" + 10 ]
                        ]
                        if any [ i > 0 nb > 0 ][
                            nb: nb * 16 + i
                        ]
                        s: next s
                    ]
                ][
                    s: at s 3
                    while [ chars-dec/(s/1) ] [
                        i: to-integer ( s/1 - #"0" )
                        if any [ i > 0 nb > 0 ][
                            nb: nb * 10 + i
                        ]
                        s: next s
                    ]
                ]
                if all [
                    nb <= to-integer #"^(10FFFF)"
                    s/1 == #";"
                ][
                    str: next s
                    c: to-char nb 
                ]
            ][
                ; or predefined entity
                if f: find/part str #";" 6 [
                    s: copy/part str next f
                    m: #(
                        "&lt;" #"<"
                        "&gt;" #">"
                        "&amp;" #"&"
                        "&apos;" #"'"
                        "&quot;" #"^""
                    )
                    c: select m s
                    if c [
                        str: next f
                    ]
                ]
            ]
        ]
        either c [
            reduce [ c str ]
        ][
            none
        ]
    ]

    ;;
    ;; Trim heading and trailing spaces and replace multiple spaces by single spaces
    ;;
    trim-spaces: function [ str [string!] ][
        c: str
        step: 1
        while [ not tail? c ] [
            rem: false
            either c/1 == #"^(20)" [
                case [
                    step == 1 [ rem: true ]
                    if c/-1 == #"^(20)" [ rem: true ]
                ]
            ][
                if step == 1 [ step: step + 1 ]
            ]
            either rem [ remove c ] [ c: next c ]
        ]
        if c/-1 == #"^(20)" [
            clear back c
        ]
        str
    ]

    ;;
    ;; Normalise attribute value
    ;; 3.3.3 Attribute-Value Normalization
    ;; 1- nomalize newlines (#x0D into #x0A)
    ;; 2- starting with an empty string, consider each character
    ;; - replace a character reference by the corresponding character
    ;; - replace an entity reference by the corresponding text, after normalizing it recursively
    ;; - replace any white space (#x20, #xA, #x9) by a simple space (#x20)
    ;; - other characters are added as is
    ;; 3- further, if the value is not of type CDATA,
    ;; - discard any leading and trailing space (#x20)
    ;; - replace multiple spaces (#x20) by a single space (#x20).
    normalise-attr: function [ str [ string! ] /cdata return: [string!]
    ][
        spaces: charset [ #"^(20)" #"^(0D)" #"^(0A)"  #"^(09)" ]
        out: copy ""
        s: str
        while [ not tail? s ][
            case [
                ; remove cr lf and turn cr into space
                s/1 == #"^(0D)" [
                    if all [ s/2 <> #"^(0A)" ] [
                        append out #"^(20)"
                    ]
                    s: next s
                ]
                ; turn reference in its value
                ; currently does not handle entity reference (pending dtd integration)
                s/1 == #"&" [
                    ref: get-charref s
                    either ref [
                        append out ref/1
                        s: ref/2
                    ][
                        append out s/1
                        s: next s
                    ]
                ]
                ; space
                spaces/(s/1) [
                    append out #"^(20)"
                    s: next s
                ]
                true [
                    append out s/1
                    s: next s
                ]
            ]
        ]
        if not cdata [
            trim-spaces out
        ]
        out
    ]

    ;;
    ;; Resolve char references
    ;;
    resolve-charrefs: function [ 
        start [string!] end [integer! string!] return: [block!]
    ][
        end: either integer? end [ 
            at start ( end + 1 )
        ][
            end
        ]
        if any [
            not end
            (head start) <> (head end)
        ][
            return none
        ]
        ; looks for first reference if any
        r: none
        s: start
        while [
            all [ 
                s: find/part s #"&" end
                not r: get-charref s
            ]
        ][
            s: next s
        ]
        ; if any, duplicate and replace
        either r [
            out: copy/part start end
            o: at out 1 + offset? start s
            r/2: at o 1 + offset? s r/2
            forever [
                if r [
                    change/part o r/1 r/2
                ]
                ; next &
                if not all [ 
                    o: next o
                    o: find o #"&"
                ][
                    break
                ]
                r: get-charref o
            ]
            reduce [ out tail out ]
        ][
            reduce [ start end ]
        ]
    ]

    ;;
    ;; Named entities
    ;;
    ;; filled with xml predefined named entities
    ;; that may grow while parsing the dtd
    ;;
    default-entities: #(
        "lt" "<"
        "gt" ">"
        "amp" "&"
        "apos" "'"
        "quot" {"}
    )
    entities: copy default-entities

    ;;
    ;; Notes on Namespaces
    ;;
    comment [

        ;; Name space handling in XML
        ;; see https://www.w3.org/TR/xml-names/
        ;;
        ;; Name spaces are used to avoid conflicts of names within an XML document.
        ;; For instance, if an XML document contains an order for a customer that is
        ;; passed around several providers : each may add to it, its own order-id
        ;; that may conflicts with others.
        ;;
        ;; To prevent any such conflicts, xml allows restricting names to particular
        ;; namespaces. In the previous example, that allows declaring for each provider
        ;; a namespace, and qualify each order-id with the appropriate namespace.
        ;;
        ;; The namespace is an uri (unified ressource indicator) - for instance
        ;; https://www.mycompany.com/WHATEVER . It is an arbitrary name, which sole purpose is to uniquely 
        ;; identify a particular namespace.
        ;; 
        ;; The empty string, though it is a legal URI reference, cannot be used as a namespace name.
        ;; Also beware that these uri are treated as strings (not as real uri). They are case sensitive
        ;; escaped characters are not normalised. For instance https://WWW.mycompany.com/whatever is 
        ;; a different namespace.
        ;;
        ;; In an XML document, one links a name to a particular namespace, by either :
        ;; - qualifying the name : that is adding a prefix to it that specifies the namespace it refers to.
        ;; - or having specified instead a default namespace for all names that are not qualified.
        ;; 
        ;; Prefixes may be declared at any point within the XML document by adding to any XML 
        ;; element an attribute of the form xmlns:<prefix> = "<namespace>". For instance, in the following, 
        ;; <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">, the prefix xs is mapped with the 
        ;; namespace http://www.w3.org/2001/XMLSchema. Attached to the element <xs:schema>, you have :
        ;; - a prefix xs
        ;; - a namespace http://www.w3.org/2001/XMLSchema derived from the prefix
        ;; - a local-name : schema
        ;; - a qualified name (qname) : xs:schema
        ;;
        ;; This mapping of a prefix and namespace holds for any element in the XML hierarchy below,
        ;; and for their attributes, and that includes the attributes of the initial element as well. 
        ;;
        ;; This mapping can be modified at any point within the hierarchy, using the same technique,
        ;; and the new mapping will hold within the sub-tree.
        ;;
        ;; Some prefixes are reserved by XML. They cannot be redefined. All attempt to redefine
        ;; them is ignored. The corresponding namespaces cannot be pointed by other prefixes, 
        ;; nor set as default namespaces (see below).
        ;; xml always refers to http://www.w3.org/XML/1998/namespace
        ;; xmlns always refers to http://www.w3.org/2000/xmlns/
        ;;
        ;; Specifying a default namespace is done using a similar technique. The attribute "xmlns" 
        ;; within an XML element indicates what is the default namespace uri to apply to that 
        ;; element, its attributes as well of the hierachy below, unless overloaded.
        ;;
        ;; A default namespace can be specified in the root element, and it would apply throughout 
        ;; the XML document. However, if none is provided, the default namespace falls back to none.
        ;;
        ;; Normaly local-name should avoid using colons (":") as they conflict with prefixes. 
        ;; This is not enforced, however. If a name has a colon, the left part of it is expected to 
        ;; be a prefix. If none such prefix was defined, it is ignored and the whole name, including
        ;; the prefix and the colon, is returned as a local-name instead.
        ;; 
        ;; To track namespaces, the parser maintains a map of all current namespace definitions
        ;; (prefix => namespace), and a stack to keep track of matching elements as well as old 
        ;; namespace definition that need to be restored.
        ;;
        ;; When entering an XML element, it is pushed in the stack, and when leaving it, a check
        ;; is made to verify the stack contains the same matching element.
        ;; If the element entered holds namespace definitions, they are applied to the namespace
        ;; map. However old mappings are preserved within the stack. Henceforth, when leaving
        ;; the same element, old namespace mappings can be restored approprietly.
        ;;
    ]

    ; Current namespaces prefixes are kept here (prefix => namespace)
    namespaces: make map! []

    ; Stack for holding element and namespace status
    stack: copy []

    ; According to SAX spec. if the following feature is true (default),
    ; element and attributes names are filled with namespace uri and local name
    ;
    ; If that feature is false, uri and local-name are not processed at all.
    ; Names are only provided as qnames.
    ;
    ; @see org.xml.sax
    ; @see content-handler functions start-element, end-element and attributes objects
    feat-namespaces: http://xml.org/sax/features/namespaces
    do [
        put features feat-namespaces true
    ]

    ; According to SAX spec. if the following feature is true (not default), 
    ; qualified name (qname) are provided for elements and attributes and xmlns attributes are reported
    ;
    ; If the feature is false, qualified name are still reported, but xmlns attributes are discarded.
    ;
    ; @see org.xml.sax.Attributes
    feat-namespace-prefixes: http://xml.org/sax/features/namespace-prefixes
    do [
        put features feat-namespace-prefixes false
    ]

    ; According to SAX spec. if the following feature is true (not default),
    ; namespaces attributes (prefixed by xmlns) are placed in the namespace xmlns-uri (see below)
    ; whereas if false, they are not place in any namespace (that was the initial specification).
    ; This is only taken into account if those attributes are preserved, with @namespace-prefixes as true
    ; otherwise they are discarded
    ; @see org.xml.sax.Attributes
    xmlns-uri: http://www.w3.org/2000/xmlns/
    feat-xmlns-uris: http://xml.org/sax/features/xmlns-uris
    do [
        put features feat-xmlns-uris false
    ]

    ; Open an xml element and update namespaces
    open-element: function [ qname attributes empty-element? ] [
        ; process any possible namespace directives
        xmlns: process-namespace-directives attributes/attrs
        ; adjust and check the attributes names
        process-attributes-names attributes/attrs
        ; retrieve element names
        uri: local-name: none ; force local
        set [ uri local-name qname ] names qname 'element
        ; notify handler
        if check-handler 'content-handler 'start-element [
            content-handler/start-element 
                uri
                local-name
                qname
                attributes
        ]
        either empty-element? [
            ; if empty tag, close it immediately
            if check-handler 'content-handler 'end-element [
                content-handler/end-element uri local-name qname
            ]
            ; restore the previous namespace settings if need be
            if xmlns [
                restore-namespaces xmlns
            ]
        ][
            ; save old values for xmnls for later restore
            if xmlns [
                append/only stack reduce [ 'xmlns xmlns ]
            ]
            ; save element for later check
            append/only stack reduce [ 'element uri local-name qname ]
        ]
    ]

    ; Close an xml element
    close-element: function [ qname [string!] return: [logic!] ][
        uri: local-name: none
        set [ uri local-name qname ] names qname 'element
        ; check that top of stack is balanced
        ; note that here qnames are checked (and not uri or local-name) - @ZWT
        t: last stack
        either all [ t t/1 == 'element t/4 == qname ] [
            take/last stack
        ][
            ; @ZWT - abort
            print "=== Abort ==="
            return false
        ]
        ; notify element termination
        if check-handler 'content-handler 'end-element [
            content-handler/end-element uri local-name qname
        ]
        ; restore context if need be
        t: last stack
        if all [ t t/1 == 'xmlns ] [
            xmlns: t/2
            take/last stack
            restore-namespaces xmlns
        ]
    ]

    ; Process elements attributes for any namespace directives
    process-namespace-directives: function [ 
        attributes [block!] return: [map! none!] 
    ][
        ; assert namespaces are to be processed ?
        if not features/(feat-namespaces) [
            return none
        ]
        attrs: attributes
        xmlns: none
        while [ not tail? attrs ] [
            remove?: false
            qname: attrs/1/3
            if m: find/match/tail qname "xmlns" [ ; case insensitive
                xmlns: either xmlns [ xmlns ] [ copy [] ] ; initialise xmlns
                ; determines the prefix if any
                prefix: case [
                    tail? m [
                        ; only xmlns => default namespace, use empty string instead
                        ""
                    ]
                    m/1 == #":" [
                        ; xmlns: => prefix follows
                        either next m [
                            copy next m
                        ][
                            none
                        ]
                    ]
                    true [
                        ; xmlns<something else> => error - see below
                        none
                    ]
                ]
                ; action according to prefix
                either prefix [
                    uri: attrs/1/5
                    either any [ 
                        prefix = "xml" prefix = "xmlns" ; case insensitive check
                    ][
                        ;;
                        ;; xml or xmlns cannot be redefined
                        ;;
                        either [ prefix = "xmlns" ][
                            ; @ZWT xmlns => trigger an error
                            print [ "Attempt to redefine xmlns prefix" ]
                        ][
                            ; @ZWT xml and uri different from default => trigger an error
                            if uri <> select xmnls prefix ; insensitive check
                            [
                                print [ "Attempt to redefine xml prefix" ]
                            ]
                        ]
                    ][
                        either select/case/skip xmlns prefix 2           ; case sensitive test
                        [
                            ; @ZWT warning - duplicate definition
                            print [ "Duplicate definition for " prefix " keep only first definition" ]
                        ][
                            either any [
                                not uri 
                                all [ empty? uri prefix <> "" ]
                            ][
                                ; empty - except if default that can be reset as such
                                ; see @see XML Namespaces - Namespace constraint: No Prefix Undeclaring
                                ; @ZWT warning - missing uri
                                print [ "Missing uri for " prefix ]
                            ][
                                append xmlns reduce [prefix uri]
                                unless features/namespace-prefixes [
                                    remove?: true
                                ]
                            ]
                        ]
                    ]
                ][
                    ; @ZWT warning - attribute starting with xmlns
                    print ["Wrong xmlns attribute '" qname "'"]
                ]
            ]
            either remove? [ remove attrs ][ attrs: next attrs ]
        ]

        ;; adjust global namespaces if need be and notify the user
        if xmlns [
            x: xmlns
            prefix: new-uri: none
            while [ not tail? x ][
                set [ prefix new-uri ] x
                ; exchange old value with new value
                ; new value updates the current namescapes
                ; old value is kept for restoring the prior namespaces when
                ; the element will be left
                old-uri: select/case namespaces prefix ; case-sensitive
                put/case namespaces prefix new-uri
                x/2: old-uri
                if check-handler 'content-handler 'start-prefix-mapping [
                    content-handler/start-prefix-mapping prefix new-uri
                ]
                x: next next x
            ]
        ]
        xmlns
    ]

    ; Restore namespaces ( do it in reverse )
    restore-namespaces: function [ 
        xmlns [block!] "Backuped namespaces @see process-namespace-directives"
    ][
        if tail? xmlns [
            exit
        ]
        prefix: uri: none
        x: tail xmlns
        until [
            x: back back x
            set [ prefix uri ] x
            either uri [
                put/case namespaces prefix uri
            ][
                remove/key namespaces prefix
            ]
            if check-handler 'content-handler 'end-prefix-mapping [
                content-handler/end-prefix-mapping prefix
            ]
            head? X
        ]
    ]

    ; Processes attributes names
    ; 1- populate attribute names
    ; 2- check for uniqueness
    process-attributes-names: function [ attributes [block!] ][
        ;; if namespaces should be handled - compute the names
        if features/(feat-namespaces) [
            attrs: attributes
            forall attrs [
                ; set uri, local-name, qname
                uri: local-name: qname: none
                set [ uri local-name qname ] names attrs/1/3 'attribute
                attrs/1/1: uri
                attrs/1/2: local-name
                attrs/1/3: qname
            ]
        ]
        ;; check attributes for unicity
        ;; if uri/local-name are set, use them, otherwise compare the qnames
        ;; if duplicate attributes are found, report and remove the overriding attributes, second or more
        attrs: attributes
        while [ not tail? attrs ] [
            uri: attrs/1/1
            local-name: attrs/1/2
            qname: attrs/1/3
            n: next attrs
            while [ not tail? n ] [
                duplicate?: either uri [
                    ; if uri is known, compare the full mapping - case sensitive
                    all [ n/1/1 == uri n/1/2 == local-name ]
                ][
                    ; otherwise compare the qnames only
                    n/1/3 == qname
                ]
                either duplicate? [
                    ; @ZWT trigger a warning or error ?
                    print [ "Attribute" qname "and" n/1/3 "are duplicates. Second attribute is ignored." ]
                    remove n
                ][
                    n: next n
                ]
            ]
            attrs: next attrs
        ]
    ]

    ; Process qname into names
    names: function [ qname [string!] type [word!] return: [block!] ][

        if l: find qname #":" [
            ;; 
            ;; Qualified name
            ;;
            prefix: copy/part qname l
            local-name: copy next l
            if find local-name #":" [
                ; Local name should not have a delimiter, as this may conflict with qualified names
                ; see [4] NCName
                ; @ZWT throw a terminal error
                print [ {Local-name with character #":" used in} qname ]
            ]
            if all [ 
                type == 'element find/match/tail local-name "xml"           ; case-insensitive
            ][
                ; Local name beginning with xml should be warned against
                ; @see XML Namespace 3 Declaring Namespaces
                ; ...it is inadvisable to use prefixed names whose LocalPart begins with the letters x, m, l, in any case combination, 
                ; as these names would be reserved if used without a prefix. 
                ; @ZWT throw a warning
                print [ "Local-name starting with xml " qname ]
            ]
            case [
                all [ type == 'attribute prefix = "xmlns" ][ ; case-insensitive
                    either features/xmlns-uris [
                        ; for attributes, if xmln-uris feature is on, replace xmlns prefix with corresponding uri
                        uri: xmlns-uri
                    ][
                        ; otherwise (default), just leave it unset
                        uri: none
                        local-name: none
                    ]
                ]
                prefix = "" [
                    ; prefix cannot be empty, this is not a valid name
                    ; @ZWT warn or error
                    print [ "Qualified name with empty prefix " qname ]
                    qname: local-name
                    uri: none
                    local-name: none
                ]
                uri: select/case namespaces prefix [ ; case-sensitive test 
                    ; uri mapping was found
                ] 
                true [
                    ;; The prefix is not mapped within the document. 
                    ;; Uri and local-name cannot be set.
                    ;; This should not happen, see [NSC: Prefix Declared].
                    ;; However as the caller may supplement the missing mapping, trigger a warning.
                    ;; @ZWT, trigger a warning that a prefix mapping is missing.
                    uri: none
                    local-name: none
                ]
            ]
        ]

        if not find qname #":" [ ; qname may have been modified - see above
            ;;
            ;; Not a qualified name
            ;;
            local-name: qname
            if all [ type == 'element find/match/tail local-name "xml" ][
                ;; Names starting with xml are reserved and should not be used.
                ;; @see XML 2.3 Common Syntactic Constructs
                ;; @ZWT throw an error
                print [ "Unexpected element name starting with xml" qname ]
            ]
            case [
                all [ 
                    type == 'attribute
                    qname = "xmlns"         ; case insensitive
                ][
                    either [ features/xmlns-uris ][
                        ; if xmlns-uris is set, replace uri attribute, otherwise, leave it unset
                        uri: xmlns-uri
                    ][
                        uri: none
                        local-name: none
                    ]
                ]
                all [ 
                    ; default namespace is mapped
                    type == 'element 
                    xmlns: select/case namespaces "" ; case sensitive
                ][
                    uri: xmlns
                ]
                true [
                    uri: "" ; unprefixed attribute or element with no default namespace - set uri to empty
                ]
            ]
        ]

        reduce [ uri local-name qname ]
    ]

    ;;
    ;; Attributes holder used by reader
    ;;
    attributes: make attributes! [

        idx: none           ; last accessed index

        ; stores attributes in the following format 
        ; 1: uri, 2: local-name, 3: qname, 4: type, 5: value
        attrs: copy []

        ; flush the attributes set
        flush: function [][
            self/idx: none
            clear attrs
        ]

        ; add an attribute
        ; uri and local-name are computed in @see process-attribute-names
        ; @ZWT - what about type !
        add: function [ qname [string!] value [string!] ][
            append/only attrs rejoin [ [] none none qname "" value ]
        ]

        ;;
        ;; indexed access
        ;;
        length?: function [ "Return the number of attributes in the list" return: [integer!] ] [
            g-length? attrs
        ]
        uri?: function [ "Look up an attribute's Namespace URI by index." index [integer!] return: [string! none!] ] [
            a: pick attrs self/idx: index
            either a [ a/1 ] [ none ]
        ]
        local-name?: function [ "Look up an attribute's local name by index." index [integer!] return: [string! none!] ] [
            a: pick attrs self/idx: index
            either a [ a/2 ] [ none ]
        ]
        qname?: function [ "Look up an attribute's XML qualified (prefixed) name by index." index [integer!] return: [string! none!] ] [
            a: pick attrs self/idx: index
            either a [ a/3 ] [ none ]
        ]
        type?: function [ "Look up an attribute's type by index." index [integer!] return: [string! none!] ] [
            a: pick attrs self/idx: index
            either a [ a/4 ] [ none ]
        ]
        value?: function [ "Look up an attribute's value by index." index [integer!] return: [string! none!] ] [
            a: pick attrs self/idx: index
            either a [ a/5 ] [ none ]
        ]

        ;;
        ;; name-based query
        ;;
        goto-name: function [ 
            "Find in the attribute list the first attribute that has the given uri and local-name or none"
            uri [string!] local-name [string!] return: [block!]
        ][
            a: at attrs idx
            either all [ a a/1/1 == uri a/1/2 == local-name ][
                a
            ][
                b: a
                until [
                    b: next b
                    if tail? b [
                        b: attrs
                    ]
                    any [
                        all [ b b/1/1 == uri b/1/2 == local-name ]
                        a == b
                    ]
                ]
                either a == b [
                    none
                ][
                    self/idx: index? b
                    b
                ]
            ]
        ]
        index-l?: function [
            "Look up the index of an attribute by Namespace name."
            uri [string!] local-name [string!] return: [integer!]
        ][
            either a: goto-name uri local-name [ index? a ] [ -1 ]
        ]
        type-l?: function [
            "Look up an attribute's type by Namespace name." 
            uri [string!] local-name [string!] return: [string! none!] ][
            either a: goto-name uri local-name [ a/1/4 ] [ none ]
        ]
        value-l?: function [ 
            "Look up an attribute's value by Namespace name." 
            uri [string!] local-name [string!] return: [string!] ][
            either a: goto-name uri local-name [ a/1/5 ] [ none ]
        ]

        goto-qname: function [
            "Find in the attribute list the first attribute that has the given qname or none"
                qname [string!] return: [serie!] 
        ][
            a: at attrs idx
            either all [ a a/1/3 == qname ][
                a
            ][
                b: a
                until [
                    b: next b
                    if tail? b [
                        b: attrs
                    ]
                    any [
                        all [ b b/1/3 == qname ]
                        a == b
                    ]
                ]
                either a == b [
                    none
                ][
                    self/idx: index? b
                    b
                ]
            ]
        ]
        index-q?: function [ 
            "Look up the index of an attribute by XML qualified (prefixed) name - qname." 
            qname [string!] return: [integer!] 
        ][
            either a: goto-qname qname [ index? a ] [ -1 ]
        ]
        type-q?: function [ "Look up an attribute's type by XML qualified (prefixed) name." qname [string!] return: [string!] ][
            either a: goto-qname qname [ a/1/4 ] [ none ]
        ]
        value-q?: function [ "Look up an attribute's value by XML qualified (prefixed) name." qname [string!] return: [string!] ][
            either a: goto-qname qname [ a/1/5 ] [ none ]
        ]
    ]; attributes

    ;;
    ;; Helper functions
    ;; Resolve system literal
    ;;

    ;
    ; decode-url to-url "http://www.textuality.com/boilerplate/OpenHatch.xml"
    ;
    ; scheme: 'http
    ; user-info: none
    ; host: "www.textuality.com"
    ; port: none
    ; path: %/boilerplate/
    ; target: %OpenHatch...
    ;
    ; @see XML - 4.2.2 External Entities
    resolve-system-id: function [ system-id [string!] ][
        uri: to-url system-id
        if not uri [
            ; assume unknown format
            print ["Unknown format for system id " system-id ]
            return system-id
        ]
        dec: decode-url uri
        if all [ dec not dec/fragment ][
            ; assume full url
            return to-string encode-url dec
        ]
        ; maybe a relative url ?
        ; search the stack back for enclosing uri
        uri: none
        s: back tail stack
        if s <> tail s [ 
            until [
                if s/1/1 == 'uri [
                    uri: s/1/2
                    break
                ]
                s: back s
                s == head stack 
            ]
        ]
        if not uri [
            ;; nothing found
            ;; get the current document uri
            ;; @ZWT
            return system-id
        ]
        dec: decode-url to-url uri
        if not dec [
            ;; nothing found
            return system-id
        ]
        dec/target: ""
        if system-id/1 == #"/" [ dec/path: "" ]
        uri: rejoin [ "" to-string encode-url dec system-id ]
        dec: decode-url to-url uri
        either all [ dec not dec/fragment ][
            ; assume full url
            return to-string encode-url dec
        ][
            ; give-up
            return system-id
        ]
    ]

    ;;
    ;; Parsing rules
    ;;
    rules: context [

        ;;
        ;; Following parse rules are pulled out of xml 1.0  https://www.w3.org/TR/xml/
        ;;
        ;; fifth edition (26 nov. 2008) : http://www.w3.org/TR/2008/REC-xml-20081126/ - 
        ;; no errata at the time
        ;;
        ;; Rules for XML Names are also listed at the end. They are not implemented using
        ;; parse rules however. They are taken into account however in the coding part of the parser.
        ;; https://www.w3.org/TR/xml-names/
        ;;
        ;; Note there is a version 1.1 of xml - https://www.w3.org/TR/xml11/ - but it is not widely
        ;; used, nor very useful. For an informed view on the subject, see
        ;; http://www.cafeconleche.org/books/effectivexml/chapters/03.html
        ;;
        ;; Rules are organised in sections that are the same as in the original document. 
        ;; They are listed in the same exact order (except for the first few rules involving charset
        ;; for which the ordering matter). They hold also the same name as in the original document.
        ;; Therefore, it is easy to navigate back to the original spec. for more information.
        ;;
        ;; Original rules are written using the EBNF notation, which format is reminded here
        ;; https://www.w3.org/TR/xml#sec-notation. They are kept as comments and directly
        ;; followed by their counterpart in parse dialect.
        ;;

        ;;
        ;; Local variables and helper functions
        ;; all variables used by the parser are gathered here to avoid spilling them out outside
        ;;

        ;; markers used to keep track of progress in the parsing
        f: l: f1: l1: f2: l2: none

        ;; markers used to extract parts of the input stream
        x: y: x1: y1: x2: y2: none

        ;; local values to a rule
        v: v1: v2: v3: none

        ;; values exported from one rule to another
        v-PubidLiteral: none
        v-SystemLiteral: none
        v-opened?: false
        v-NDataDecl: none
        v-EntityValue: none
        v-encoding: none
        v-standalone: none
        v-version: none

        ; for debugging a parse rule - just add (h "here") or (h 1) to check whether
        ; a rule matches up to that point
        h: function [ str [any-type!] ] [ print either str [ mold str ] [ "here" ] ]

        ; abort the parse
        ab: function [] [ halt ]

        ; Document
        ; [1]   document ::= prolog element Misc*
        document: [
            f:
            (
                _reset
                mark-start 'document-start f
                if check-handler 'content-handler 'start-document [
                    content-handler/start-document
                ]
            )
            prolog
            element
            any Misc
            end
            l:
            (
                mark 'document-end l l
                if check-handler 'content-handler 'end-document [
                    content-handler/end-document
                ]
            )
        ]

        ; Character Range
        ; [2]   Char ::= #x9 | #xA | #xD | [#x20-#xD7FF] | [#xE000-#xFFFD] | [#x10000-#x10FFFF]	/* any Unicode character, excluding the surrogate blocks, FFFE, and FFFF. */
        Char: charset [ #"^(09)" #"^(0A)" #"^(0D)" #"^(20)" - #"^(D7FF)" 
            #"^(E000)" - #"^(FFFD)"
            #"^(10000)" - #"^(10FFFF)"
        ]

        ; White Space
        ; [3]   S ::= (#x20 | #x9 | #xD | #xA)+
        nSpaceChar: charset [ #"^(20)" #"^(09)" #"^(0D)" #"^(0A)" ] ; space - tab - cr - lf / not that cr will be removed anyway
        S: [ some nSpaceChar ]

        ; Names and Tokens
        ; [4]   NameStartChar   ::=     ":" | [A-Z] | "_" | [a-z] | [#xC0-#xD6] | [#xD8-#xF6] | [#xF8-#x2FF] | [#x370-#x37D] | [#x37F-#x1FFF] | [#x200C-#x200D] | [#x2070-#x218F] | [#x2C00-#x2FEF] | [#x3001-#xD7FF] | [#xF900-#xFDCF] | [#xFDF0-#xFFFD] | [#x10000-#xEFFFF]
        ; [4a]  NameChar        ::=     NameStartChar | "-" | "." | [0-9] | #xB7 | [#x0300-#x036F] | [#x203F-#x2040]
        ; [5]   Name            ::=     NameStartChar (NameChar)*
        ; [6]   Names           ::=     Name (#x20 Name)*
        ; [7]   Nmtoken         ::=     (NameChar)+
        ; [8]   Nmtokens        ::=     Nmtoken (#x20 Nmtoken)*

        NameStartChar: charset [ #":" #"A" - #"Z" #"_" #"a" - #"z" #"^(C0)" - #"^(D6)" #"^(D8)" - #"^(F6)" 
            #"^(F8)" - #"^(2FF)" #"^(370)" - #"^(37D)" #"^(37F)" - #"^(1FFF)" #"^(200C)" - #"^(200D)"
            #"^(2070)" - #"^(218F)" #"^(2C00)" - #"^(2FEF)" #"^(3001)" - #"^(D7FF)"
            #"^(F900)" - #"^(FDCF)" #"^(FDF0)" - #"^(FFFD)" #"^(10000)" - #"^(EFFFF)"
        ]
        NameChar: union NameStartChar
            charset [ #"-" #"." #"0" - #"9" #"^(B7)" #"^(0300)" - #"^(036F)" #"^(203F)" - #"^(2040)" ]
        Name: [ NameStartChar any NameChar ]
        Names: [ Name any [ #"^(20)" Name ] ]
        Nmtoken: [ some NameChar ]
        Nmtokens: [ Nmtoken any [ #"^(20)" Nmtoken ] ]

        ; Literals
        ; [9]   EntityValue     ::=      '"' ([^%&"] | PEReference | Reference)* '"'
        ;             |  "'" ([^%&'] | PEReference | Reference)* "'"
        ; [10]  AttValue        ::=      '"' ([^<&"] | Reference)* '"'
        ;             |  "'" ([^<&'] | Reference)* "'"
        ; [11]  SystemLiteral   ::=     ('"' [^"]* '"') | ("'" [^']* "'")
        ; [12]  PubidLiteral    ::=     '"' PubidChar* '"' | "'" (PubidChar - "'")* "'"
        ; [13]  PubidChar       ::=     #x20 | #xD | #xA | [a-zA-Z0-9] | [-'()+,./:=?;!*#@$_%]
        nEntityValueChar1: charset [not {%&"}]
        nEntityValueChar2: charset [not "%&'"]
        EntityValue: [
            x: [
            #"^"" any [ nEntityValueChar1 | PEReference | Reference ]  #"^"" 
            | 
            #"'" any [ nEntityValueChar2 | PEReference | Reference ]  #"'" 
            ] y:
            (
                comment [ DTD pending
                    v-EntityValue: copy/part next x back y
                ]
            )
        ]
        nAttValueChar1: charset [not {<&"}]
        nAttValueChar2: charset [not "<&'"]
        AttValue: [ 
            #"^"" any [ nAttValueChar1 | Reference ] #"^""
            | 
            #"'" any [ nAttValueChar2 | Reference ] #"'"
        ]
        nSystemLiteralChar1: charset [ not #"^"" ]
        nSystemLiteralChar2: charset [ not #"'" ]
        SystemLiteral: [
            x: [
                #"^"" any nSystemLiteralChar1 #"^"" 
                | 
                #"'" any nSystemLiteralChar2 #"'"
            ] y:
            ( 
                v-SystemLiteral: copy/part next x back y
            )
        ]
        PubidChar: union charset [ #"^(20)" #"^(0D)" #"^(0A)" #"a" - #"z" #"A" - #"Z" #"0" - #"9" ]
            charset "-'()+,./:=?;!*#@$_%"
        PubidChar2: exclude PubidChar charset #"'"
        PubidLiteral: [
            x: [
                #"^"" any PubidChar #"^""
                | 
                #"'" any PubidChar2 #"'"
            ] y:
            (
                v-PubidLiteral: copy/part next x back y
            )
        ]

        ; Character Data
        ; [14]   	CharData	   ::=   	[^<&]* - ([^<&]* ']]>' [^<&]*)
        nCharDataChar: charset [ not "<&" ]
        CharData: [
            f: any [ not ahead "]]>" nCharDataChar ] l:
            (
                if f <> l [
                    mark 'CharData f l
                    if check-handler 'content-handler 'characters [
                        either normalise-characters/test f (offset? f l) [
                            content-handler/characters v: normalise-characters f (offset? f l) length? v
                        ][
                            content-handler/characters f (offset? f l)
                        ]
                    ]
                ]
            )
        ]

        ; Comments
        ; [15]   	Comment	   ::=   	'<!--' ((Char - '-') | ('-' (Char - '-')))* '-->'
        Comment: [ 
            f: "<!--" x: to "--" y: "-->" l:
            (
                mark 'Comment f l
                if check-handler 'lexical-handler 'xml-comment [
                    v: resolve-charrefs x y
                    lexical-handler/xml-comment v/1 (offset? v/1 v/2)
                ]
            )
        ]

        ; Processing Instructions
        ; [16]   	PI	   ::=   	'<?' PITarget (S (Char* - (Char* '?>' Char*)))? '?>'
        ; [17]   	PITarget	   ::=   	Name - (('X' | 'x') ('M' | 'm') ('L' | 'l'))
        PI: [
            f: "<?" x1: PITarget y1: x2: to "?>" y2: "?>" l:
            (
                mark 'PI f l
                if check-handler 'content-handler 'processing-instruction [
                    v1: copy/part x1 y1
                    v2: copy/part x2 y2 
                    v2: resolve-charrefs v2 tail v2
                    content-handler/processing-instruction v1 v2/1
                ]
            )
        ]
        PITarget: [ copy v1 Name if ( not equal? v1 "xml" ) ] ; case sensitive check

        ; CDATA Sections
        ; [18]   	CDSect	   ::=   	CDStart CData CDEnd
        ; [19]   	CDStart	   ::=   	'<![CDATA['
        ; [20]   	CData	   ::=   	(Char* - (Char* ']]>' Char*))
        ; [21]   	CDEnd	   ::=   	']]>'
        CDSect: [
            f: CDStart x: CData y: CDEnd l:
            (
                mark 'CDSect f l
                if check-handler 'lexical-handler 'start-CDATA [
                    lexical-handler/start-CDATA
                ]
                if all [
                    ( offset? x y ) > 0
                    check-handler 'content-handler 'characters
                ][
                    content-handler/characters x ( offset? x y )
                ]
                if check-handler 'lexical-handler 'end-CDATA [
                    lexical-handler/end-CDATA
                ]
            )
        ]
        CDStart: "<![CDATA["
        CData: [ any [ not ahead CDEnd Char ] ]
        CDEnd: "]]>"

        ; Prolog
        ; [22]   	prolog	   ::=   	XMLDecl? Misc* (doctypedecl Misc*)?
        ; [23]   	XMLDecl	   ::=   	'<?xml' VersionInfo EncodingDecl? SDDecl? S? '?>'
        ; [24]   	VersionInfo	   ::=   	S 'version' Eq ("'" VersionNum "'" | '"' VersionNum '"')
        ; [25]   	Eq	   ::=   	S? '=' S?
        ; [26]   	VersionNum	   ::=   	'1.' [0-9]+
        ; [27]   	Misc	   ::=   	Comment | PI | S 
        prolog: [ opt XMLDecl any Misc opt [ doctypedecl any Misc ] ]
        XMLDecl: [
            ( 
                v-encoding: none
                v-version: none
                v-standalone: none
            )
            f: "<?xml" VersionInfo opt EncodingDecl opt SDDecl opt S "?>" l:
            (
                mark 'XMLDecl f l
                if check-handler 'extended-handler 'xml-declaration [
                    extended-handler/xml-declaration v-version v-encoding v-standalone
                ]
            )
        ]
        VersionInfo: [ 
            S "version" Eq x: [ "'" VersionNum "'" | #"^"" VersionNum #"^"" ] y:
            ( 
                v-version: copy/part next x back y
            )
        ]
        Eq: [ opt S #"=" opt S ]
        nDigit: charset [ #"0" - #"9" ]
        VersionNum: [ "1." some nDigit ]
        Misc: [ 
            Comment | PI | 
            f: S l:
            (
                mark 'Misc-S f l
            )
        ]

        ; Document Type Definition
        ; [28]   	doctypedecl	   ::=   	'<!DOCTYPE' S Name (S ExternalID)? S? ('[' intSubset ']' S?)? '>'	[VC: Root Element Type]
        ;                 [WFC: External Subset]
        ; [28a]   	DeclSep	   ::=   	PEReference | S 	[WFC: PE Between Declarations]
        ; [28b]   	intSubset	   ::=   	(markupdecl | DeclSep)*
        ; [29]   	markupdecl	   ::=   	elementdecl | AttlistDecl | EntityDecl | NotationDecl | PI | Comment 	[VC: Proper Declaration/PE Nesting]
        ;                 [WFC: PEs in Internal Subset]
        doctypedecl: [
            (
                v-PubidLiteral: none
                v-SystemLiteral: none
            )
            ; opening a dtd
            f1: "<!DOCTYPE" S x1: Name y1: opt [S ExternalID] l1:
            (
                comment [ ; @ZWT DTD support pending
                mark 'doctypedecl-1 f1 l1
                v: either v-SystemLiteral [ resolve-system-id v-SystemLiteral ] [ none ]
                ; keep track of the system-id uri, in case it is needed for relative ref.
                append/only stack reduce [ 'uri v ]
                if check-handler 'lexical-handler 'start-DTD [
                    lexical-handler/start-DTD 
                        copy/part x1 y1 ; name
                        v-PubidLiteral ; public-id
                        to-string v ; system-id
                ]
                ]
            )
            opt S opt [ #"[" intSubset #"]" opt S ] 
            ; closing dtd
            f2: #">" l2:
            (
                comment [ ; @ZWT DTD support pending
                mark 'doctypedecl-2 f2 l2
                if 'uri == select last stack 1 [
                    take/last stack
                ]                    
                if check-handler 'lexical-handler 'end-DTD [
                    lexical-handler/end-DTD 
                ]
                ]
            )
        ]
        DeclSep: [ PEReference | S ]
        intSubset: [ any [ markupdecl | DeclSep ] ]
        markupdecl: [ elementdecl | AttlistDecl | EntityDecl | NotationDecl | PI | Comment ]

        ; External Subset
        ; [30]   	extSubset	   ::=   	TextDecl? extSubsetDecl
        ; [31]   	extSubsetDecl	   ::=   	( markupdecl | conditionalSect | DeclSep)*
        extSubset: [ opt TextDecl extSubsetDecl ]
        extSubsetDecl: [ any [ markupdecl | conditionalSect | DeclSep ] ]

        ; Standalone Document Declaration
        ; [32]   	SDDecl	   ::=   	S 'standalone' Eq (("'" ('yes' | 'no') "'") | ('"' ('yes' | 'no') '"')) 	[VC: Standalone Document Declaration]
        SDDecl: [ 
            S "standalone" Eq x: [ [ #"'" [ "yes" | "no" ] #"'" ] | [ #"^"" [ "yes" | "no" ] #"^"" ] ]
            (
                v-standalone: either find/match/tail next x "yes" [ true ] [ false ]
            )
        ]

        ; Element
        ; [39]   	element	   ::=   	EmptyElemTag
        ;             | STag content ETag 	[WFC: Element Type Match]
        ;                 [VC: Element Valid]

        ; @ZWT - Merge EmptyElemTag and STag
        ;element: [ EmptyElemTag | STag content ETag ]
        element: [ 
            ( v-opened?: false )
            STag [ if ( v-opened? ) content ETag | none ] 
        ]

        ; Start-tag
        ; [40]   	STag	   ::=   	'<' Name (S Attribute)* S? '>'	[WFC: Unique Att Spec]
        ; [41]   	Attribute	   ::=   	Name Eq AttValue 	[VC: Attribute Value Type]
        ;                 [WFC: No External Entity References]
        ;                 [WFC: No < in Attribute Values]
        STag: [
            ( attributes/flush )
            f: #"<" x: Name y: any [ S Attribute ] opt S [ #">" (v-opened?: true) | "/>" ] l:
            (
                mark 'STag f l
                open-element 
                    copy/part x y ; qname
                    attributes
                    not v-opened?
            )
        ]
        Attribute: [
            x1: Name y1: Eq x2: AttValue y2:
            (
                v1: copy/part x1 y1
                v2: copy/part next x2 back y2 ; removes "<values>" or '<values>'
                v2: normalise-attr v2 tail v2
                attributes/add v1 v2
            )
        ]

        ; End-tag
        ; [42]   	ETag	   ::=   	'</' Name S? '>'
        ETag: [ 
            f: "</" x: Name y: opt S #">" l:
            (
                mark 'ETag f l
                close-element copy/part x y ; qname
            )
        ]

        ; Content of Elements
        ; [43]   	content	   ::=   	CharData? ((element | Reference | CDSect | PI | Comment) CharData?)*
        content: [ opt CharData any [ [ element | nReference | CDSect | PI | Comment ] opt CharData ] ]
        nReference: [
            f: Reference l:
            (
                mark 'nReference f l
                v1: get-charref f
                either v1 [
                    v2: copy ""
                    insert v2 v1/1
                    if check-handler 'content-handler 'characters [ 
                        content-handler/characters v2 1
                    ]
                ][
                    if check-handler 'content-handler 'characters [ 
                        content-handler/characters f (offset? f l)
                    ]
                ]
            )
        ]

        ; Tags for Empty Elements
        ; [44]   	EmptyElemTag	   ::=   	'<' Name (S Attribute)* S? '/>'	[WFC: Unique Att Spec]

        ; @ZWT - merged with STag - see above
        ; EmptyElemTag: [ #"<" Name any [ S Attribute ] opt S "/>" ]

        ; Element Type Declaration
        ; [45]   	elementdecl	   ::=   	'<!ELEMENT' S Name S contentspec S? '>'	[VC: Unique Element Type Declaration]
        ; [46]   	contentspec	   ::=   	'EMPTY' | 'ANY' | Mixed | children 
        elementdecl: [ "<!ELEMENT" S Name S contentspec opt S #">" ]
        contentspec: [ "EMPTY" | "ANY" | Mixed | children ]

        ; Element-content Models
        ; [47]   	children	   ::=   	(choice | seq) ('?' | '*' | '+')?
        ; [48]   	cp	   ::=   	(Name | choice | seq) ('?' | '*' | '+')?
        ; [49]   	choice	   ::=   	'(' S? cp ( S? '|' S? cp )+ S? ')'	[VC: Proper Group/PE Nesting]
        ; [50]   	seq	   ::=   	'(' S? cp ( S? ',' S? cp )* S? ')'	[VC: Proper Group/PE Nesting]
        children: [ [ choice | seq ] opt [ #"?" | #"*" | #"+" ] ]
        cp: [ [ Name | choice | seq ] opt [ #"?" | #"*" | #"+" ] ]
        choice: [ #"(" opt S cp some [ opt S #"|" opt S cp ] opt S #")" ]
        seq: [ #"(" opt S cp any [ opt S #"," opt S cp ] opt S #")" ]

        ; Mixed-content Declaration
        ; [51]   	Mixed	   ::=   	'(' S? '#PCDATA' (S? '|' S? Name)* S? ')*'
        ;             | '(' S? '#PCDATA' S? ')' 	[VC: Proper Group/PE Nesting]
        ;                 [VC: No Duplicate Types]
        Mixed: [ #"(" opt S "#PCDATA" any [ opt S #"|" opt S Name ] opt S ")*" | #"(" opt S "#PCDATA" opt S #")" ]

        ; Attribute-list Declaration
        ; [52]   	AttlistDecl	   ::=   	'<!ATTLIST' S Name AttDef* S? '>'
        ; [53]   	AttDef	   ::=   	S Name S AttType S DefaultDecl 
        AttlistDecl: [
            f: "<!ATTLIST" S x: Name y: any AttDef opt S #">" l:
            (
                comment [
                    ; @ZWT DTD support pending
                    if check-handler 'decl-handler 'attribute-decl [
                        decl-handler/attribute-decl
                            ; element name
                            copy/part x y ; attribute name
                            ; type
                            ; mode
                            ; value
                    ]
                ]
            )
        ]
        AttDef: [ S Name S AttType S DefaultDecl ]

        ; Attribute Types
        ; [54]   	AttType	   ::=   	StringType | TokenizedType | EnumeratedType
        ; [55]   	StringType	   ::=   	'CDATA'
        ; [56]   	TokenizedType	   ::=   	'ID'	[VC: ID]
        ;                 [VC: One ID per Element Type]
        ;                 [VC: ID Attribute Default]
        ;             | 'IDREF'	[VC: IDREF]
        ;             | 'IDREFS'	[VC: IDREF]
        ;             | 'ENTITY'	[VC: Entity Name]
        ;             | 'ENTITIES'	[VC: Entity Name]
        ;             | 'NMTOKEN'	[VC: Name Token]
        ;             | 'NMTOKENS'	[VC: Name Token]
        AttType: [ StringType | TokenizedType | EnumeratedType ]
        StringType: [ "CDATA" ]
        TokenizedType: [ "ID" | "IDREF" | "IDREFS" | "ENTITY" | "ENTITIES" | "NMTOKEN" | "NMTOKENS" ]

        ; Enumerated Attribute Types
        ; [57]   	EnumeratedType	   ::=   	NotationType | Enumeration
        ; [58]   	NotationType	   ::=   	'NOTATION' S '(' S? Name (S? '|' S? Name)* S? ')' 	[VC: Notation Attributes]
        ;                 [VC: One Notation Per Element Type]
        ;                 [VC: No Notation on Empty Element]
        ;                 [VC: No Duplicate Tokens]
        ; [59]   	Enumeration	   ::=   	'(' S? Nmtoken (S? '|' S? Nmtoken)* S? ')'	[VC: Enumeration]
        ;                 [VC: No Duplicate Tokens]
        EnumeratedType: [ NotationType | Enumeration ]
        NotationType: [ "NOTATION" S #"(" opt S Name any [ opt S #"|" opt S Name ] opt S #")" ]
        Enumeration: [ #"(" opt S Nmtoken any [ opt S #"|" opt S Nmtoken ] opt S #")" ]

        ; Attribute Defaults
        ; [60]   	DefaultDecl	   ::=   	'#REQUIRED' | '#IMPLIED'
        ;             | (('#FIXED' S)? AttValue)	[VC: Required Attribute]
        ;                 [VC: Attribute Default Value Syntactically Correct]
        ;                 [WFC: No < in Attribute Values]
        ;                 [VC: Fixed Attribute Default]
        ;                 [WFC: No External Entity References]
        DefaultDecl: [ "#REQUIRED" | "#IMPLIED" | [ opt [ "#FIXED" S ] AttValue ] ]

        ; Conditional Section
        ; [61]   	conditionalSect	   ::=   	includeSect | ignoreSect
        ; [62]   	includeSect	   ::=   	'<![' S? 'INCLUDE' S? '[' extSubsetDecl ']]>' 	[VC: Proper Conditional Section/PE Nesting]
        ; [63]   	ignoreSect	   ::=   	'<![' S? 'IGNORE' S? '[' ignoreSectContents* ']]>'	[VC: Proper Conditional Section/PE Nesting]
        ; [64]   	ignoreSectContents	   ::=   	Ignore ('<![' ignoreSectContents ']]>' Ignore)*
        ; [65]   	Ignore	   ::=   	Char* - (Char* ('<![' | ']]>') Char*) 
        conditionalSect: [ includeSect | ignoreSect ]
        includeSect: [ "<![" opt S "INCLUDE" opt S #"[" extSubsetDecl "]]>" ]
        ignoreSect: [ "<![" opt S "IGNORE" opt S #"[" any ignoreSectContents "]]>" ]
        ignoreSectContents: [ Ignore any [ "<![" ignoreSectContents "]]>" Ignore ] ]
        Ignore: [ any Char [ "<![" | "]]>" ] any Char 'nope | any Char ]

        ; Character Reference
        ; [66]   	CharRef	   ::=   	'&#' [0-9]+ ';'
        ;             | '&#x' [0-9a-fA-F]+ ';'	[WFC: Legal Character]
        nCharRefChar1: charset [ #"0" - #"9" ]
        nCharRefChar2: charset [ #"0" - #"9" #"a" - #"f" #"A" - #"F" ]
        CharRef: [ [ "&#" some nCharRefChar1 #";" | "&#x" some nCharRefChar2 #";" ] ]

        ; Entity Reference
        ; [67]   	Reference	   ::=   	EntityRef | CharRef
        ; [68]   	EntityRef	   ::=   	'&' Name ';'	[WFC: Entity Declared]
        ;                 [VC: Entity Declared]
        ;                 [WFC: Parsed Entity]
        ;                 [WFC: No Recursion]
        ; [69]   	PEReference	   ::=   	'%' Name ';'	[VC: Entity Declared]
        ;                 [WFC: No Recursion]
        ;                 [WFC: In DTD]
        Reference: [ EntityRef | CharRef ]
        EntityRef: [ #"&" Name #";" ]
        PEReference: [ #"%" Name #";" ]

        ; Entity Declaration
        ; [70]   	EntityDecl	   ::=   	GEDecl | PEDecl
        ; [71]   	GEDecl	   ::=   	'<!ENTITY' S Name S EntityDef S? '>'
        ; [72]   	PEDecl	   ::=   	'<!ENTITY' S '%' S Name S PEDef S? '>'
        ; [73]   	EntityDef	   ::=   	EntityValue | (ExternalID NDataDecl?)
        ; [74]   	PEDef	   ::=   	EntityValue | ExternalID 
        EntityDecl: [ GEDecl | PEDecl ]
        GEDecl: [ ; general entities - used within the doc.
            ( 
                comment [ ; @ZWT DTD support pending
                    v-NDataDecl: none
                    v-PubidLiteral: none
                    v-SystemLiteral: none
                    v-EntityValue: none
                ]
            )
            f: "<!ENTITY" S x: Name y: S EntityDef opt S #">" l:
            (
                comment [ ; @ZWT DTD support pending
                    mark 'GEDecl f l
                    either v-NDataDecl [
                        ; unparsed entity
                        either not select/case notations v-NDataDecl [
                            ; @ZWT warning or error if unknown notation
                            print ["Unknown notation" v-NDataDecl]
                        ][
                            if check-handler 'dtd-handler 'unparsed-entity-decl [
                                v: either v-SystemLiteral [ resolve-system-id v-SystemLiteral ] [ none ]
                                dtd-handler/unparsed-entity-decl
                                    copy/part x y   ; name
                                    v-PubidLiteral  ; public-id
                                    v               ; system-id,
                                    v-NDataDecl     ; notation-name
                            ]
                        ]
                    ][
                        either v-EntityValue [
                            if check-handler 'decl-handler 'internal-entity-decl [
                                decl-handler/internal-entity-decl
                                    copy/part x y   ; name
                                    v-EntityValue   ; value
                            ]
                        ][
                            either v-SystemLiteral [
                                v: resolve-system-id v-SystemLiteral
                                if check-handler 'decl-handler 'external-entity-decl [
                                    decl-handler/external-entity-decl
                                        copy/part x y   ; name
                                        v-PubidLiteral  ; public-id
                                        v               ; system-id
                                ]
                            ][
                                ;
                            ]
                        ]
                    ]
                ]
            )
        ]
        PEDecl: [
            ; parameter entity, used within the dtd
            (
                comment [ ; @ZWT DTD support pending
                    v-PubidLiteral: none
                    v-SystemLiteral: none
                    v-EntityValue: none
                ]
            )
            f: "<!ENTITY" S #"%" S x: Name y: S PEDef opt S #">" l:
            (
                comment [  ; @ZWT DTD support pending
                    mark 'GEDecl f l
                    either v-EntityValue [
                        if check-handler 'decl-handler 'internal-entity-decl [
                            decl-handler/internal-entity-decl
                                copy/part x y   ; name
                                v-EntityValue   ; value
                        ]
                    ][
                        v: resolve-system-id v-SystemLiteral
                        if check-handler 'decl-handler 'external-entity-decl [
                            decl-handler/external-entity-decl
                                copy/part x y   ; name
                                v-PubidLiteral  ; public-id
                                v               ; system-id
                        ]
                    ]
                ]
            )
        ]
        EntityDef: [ EntityValue | [ ExternalID opt NDataDecl ] ]
        PEDef: [ EntityValue | ExternalID ]

        ; External Entity Declaration
        ; [75]   	ExternalID	   ::=   	'SYSTEM' S SystemLiteral
        ;             | 'PUBLIC' S PubidLiteral S SystemLiteral
        ; [76]   	NDataDecl	   ::=   	S 'NDATA' S Name 	[VC: Notation Declared]
        ExternalID: [ "SYSTEM" S SystemLiteral | "PUBLIC" S PubidLiteral S SystemLiteral ]
        NDataDecl: [ 
            S "NDATA" S x: Name y:
            (
                comment [  ; @ZWT DTD support pending
                    v-NDataDecl: copy/part x y
                ]
            )
        ]

        ; Text Declaration
        ; [77]   	TextDecl	   ::=   	'<?xml' VersionInfo? EncodingDecl S? '?>'
        TextDecl: [ "<?xml" opt VersionInfo EncodingDecl opt S "?>" ]

        ; Well-Formed External Parsed Entity
        ; [78]   	extParsedEnt	   ::=   	TextDecl? content 
        extParsedEnt: [ opt TextDecl content ]

        ; Encoding Declaration
        ; [80]   	EncodingDecl	   ::=   	S 'encoding' Eq ('"' EncName '"' | "'" EncName "'" )
        ; [81]   	EncName	   ::=   	[A-Za-z] ([A-Za-z0-9._] | '-')*	/* Encoding name contains only Latin characters */
        EncodingDecl: [ 
            S "encoding" Eq x: [ #"^"" EncName #"^"" | #"'" EncName #"'" ] y:
            ( 
                v-encoding: copy/part next x back y 
            )
        ]
        nEncNameChar1: charset [ #"A" - #"Z" #"a" - #"z" ]
        nEncNameChar2: charset [ #"A" - #"Z" #"a" - #"z" #"0" - #"9" #"." #"_" ]
        EncName: [ nEncNameChar1 any [ nEncNameChar2 | #"-" ] ]

        ; Notation Declarations
        ; [82]   	NotationDecl	   ::=   	'<!NOTATION' S Name S (ExternalID | PublicID) S? '>'	[VC: Unique Notation Name]
        ; [83]   	PublicID	   ::=   	'PUBLIC' S PubidLiteral 
        NotationDecl: [
            (
                comment [
                    v-PubidLiteral: none
                    v-SystemLiteral: none
                ]
            )
            f: "<!NOTATION" S x: Name y: S [ ExternalID | PublicID ] opt S #">" l:
            (
                comment [
                    mark 'NotationDecl f l
                    if all [ not v-PubidLiteral not v-SystemLiteral ][
                        ; @ZWT warning or failed rule
                    ]
                    v: either v-SystemLiteral [ resolve-system-id v-SystemLiteral ] [ none ]
                    if check-handler 'dtd-handler 'notation-decl [
                        dtd-handler/notation-decl 
                            copy/part x y ; name 
                            v-PubidLiteral ; public-id
                            v ; system-id
                    ]
                ]
            )
        ]
        PublicID: [ "PUBLIC" S PubidLiteral ]

        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        ;; 
        ;; Additional processing rules for namespaces - see XML Names
        ;; https://www.w3.org/TR/xml-names/ (Third Edition)
        ;; They are meant to be commented, as they are implemented in the code
        ;; rather than by means of parse rules.
        ;;
        ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

        ; Attribute Names for Namespace Declaration
        ; [1]   	NSAttName	   ::=   	PrefixedAttName
        ; 			| DefaultAttName
        ; [2]   	PrefixedAttName	   ::=   	'xmlns:' NCName	[NSC: Reserved Prefixes and Namespace Names]
        ; [3]   	DefaultAttName	   ::=   	'xmlns'
        ; [4]   	NCName	   ::=   	Name - (Char* ':' Char*)	/* An XML Name, minus the ":" */

        ; Qualified Name
        ; [7]   	QName	   ::=   	PrefixedName
        ; 			| UnprefixedName
        ; [8]   	PrefixedName	   ::=   	Prefix ':' LocalPart
        ; [9]   	UnprefixedName	   ::=   	LocalPart
        ; [10]   	Prefix	   ::=   	NCName
        ; [11]   	LocalPart	   ::=   	NCName

        ; Element Names
        ; [12]   	STag	   ::=   	'<' QName (S Attribute)* S? '>' 	[NSC: Prefix Declared]
        ; [13]   	ETag	   ::=   	'</' QName S? '>'	[NSC: Prefix Declared]
        ; [14]   	EmptyElemTag	   ::=   	'<' QName (S Attribute)* S? '/>'	[NSC: Prefix Declared]

        ; Attribute
        ; [15]   	Attribute	   ::=   	NSAttName Eq AttValue
        ; 			| QName Eq AttValue	[NSC: Prefix Declared]
        ; 				[NSC: No Prefix Undeclaring]
        ; 				[NSC: Attributes Unique]

        ; Qualified Names in Declarations
        ; [16]   	doctypedecl	   ::=   	'<!DOCTYPE' S QName (S ExternalID)? S? ('[' (markupdecl | PEReference | S)* ']' S?)? '>'
        ; [17]   	elementdecl	   ::=   	'<!ELEMENT' S QName S contentspec S? '>'
        ; [18]   	cp	   ::=   	(QName | choice | seq) ('?' | '*' | '+')?
        ; [19]   	Mixed	   ::=   	'(' S? '#PCDATA' (S? '|' S? QName)* S? ')*'
        ; 			| '(' S? '#PCDATA' S? ')'
        ; [20]   	AttlistDecl	   ::=   	'<!ATTLIST' S QName AttDef* S? '>'
        ; [21]   	AttDef	   ::=   	S (QName | NSAttName) S AttType S DefaultDecl

    ];rules

];reader

];sax
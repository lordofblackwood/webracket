#lang webracket/base

;; Browser smoke for optional/deprecated document host functions.

(require (only-in webracket/unsafe/document
                  js-adopt-node
                  js-caret-range-from-point
                  js-close
                  js-create-attribute
                  js-create-attribute-ns
                  js-create-cdata-section
                  js-create-comment
                  js-create-document-fragment
                  js-create-element
                  js-create-element-ns
                  js-create-expression
                  js-create-node-iterator
                  js-create-processing-instruction
                  js-create-range
                  js-create-text-node
                  js-create-tree-walker
                  js-document-body
                  js-document-element
                  js-document-head
                  js-element-from-point
                  js-elements-from-point
                  js-enable-style-sheets-for-set
                  js-evaluate
                  js-exit-fullscreen
                  js-exit-picture-in-picture
                  js-exit-pointer-lock
                  js-get-element-by-id
                  js-get-elements-by-class-name
                  js-get-elements-by-name
                  js-get-elements-by-tag-name
                  js-get-elements-by-tag-name-ns
                  js-get-selection
                  js-has-focus
                  js-import-node
                  js-open
                  js-query-selector
                  js-query-selector-all
                  js-release-events)
         (only-in webracket/unsafe/standard
                  js-eval))

(define (check-true got label)
  (unless got
    (error 'check-true label)))

(define (catch-message thunk)
  (with-handlers ([exn:fail? exn-message])
    (thunk)
    #f))

(define (string-contains/simple? haystack needle)
  (define haystack-length (string-length haystack))
  (define needle-length (string-length needle))
  (let loop ([index 0])
    (cond
      [(> (+ index needle-length) haystack-length) #f]
      [(string=? (substring haystack index (+ index needle-length)) needle) #t]
      [else (loop (add1 index))])))

(define (check-message message needle label)
  (check-true (and message
                   (string-contains/simple? message needle))
              label))

(define js-null (js-eval "null"))
(define js-document (js-eval "document"))

(js-eval
 "globalThis.__wrDocumentValueBoundaryNames = [
    'head',
    'body',
    'documentElement'
  ];
  globalThis.__wrDocumentValueBoundary = {};
  for (const name of globalThis.__wrDocumentValueBoundaryNames) {
    globalThis.__wrDocumentValueBoundary[name] = {
      descriptor: Object.getOwnPropertyDescriptor(document, name)
    };
    Object.defineProperty(document, name, {
      value: undefined,
      configurable: true,
      writable: true
    });
  }")

(define head-message
  (catch-message
   (lambda ()
     (js-document-head))))

(define body-message
  (catch-message
   (lambda ()
     (js-document-body))))

(define document-element-message
  (catch-message
   (lambda ()
     (js-document-element))))

(js-eval
 "for (const name of globalThis.__wrDocumentValueBoundaryNames) {
    const saved = globalThis.__wrDocumentValueBoundary[name];
    if (saved.descriptor) {
      Object.defineProperty(document, name, saved.descriptor);
    } else {
      delete document[name];
    }
  }
  delete globalThis.__wrDocumentValueBoundary;
  delete globalThis.__wrDocumentValueBoundaryNames;")

(js-eval
 "globalThis.__wrDocumentBoundaryNames = [
    'adoptNode',
    'caretRangeFromPoint',
    'close',
    'createAttribute',
    'createAttributeNS',
    'createCDATASection',
    'createComment',
    'createDocumentFragment',
    'createElement',
    'createElementNS',
    'createExpression',
    'createNodeIterator',
    'createProcessingInstruction',
    'createRange',
    'createTextNode',
    'createTreeWalker',
    'elementFromPoint',
    'elementsFromPoint',
    'enableStyleSheetsForSet',
    'evaluate',
    'exitFullscreen',
    'exitPictureInPicture',
    'exitPointerLock',
    'getElementById',
    'getElementsByClassName',
    'getElementsByName',
    'getElementsByTagName',
    'getElementsByTagNameNS',
    'getSelection',
    'hasFocus',
    'importNode',
    'open',
    'querySelector',
    'querySelectorAll',
    'releaseEvents'
  ];
  globalThis.__wrDocumentBoundary = {};
  for (const name of globalThis.__wrDocumentBoundaryNames) {
    globalThis.__wrDocumentBoundary[name] = {
      descriptor: Object.getOwnPropertyDescriptor(document, name)
    };
    Object.defineProperty(document, name, {
      value: undefined,
      configurable: true,
      writable: true
    });
  }")

(define adopt-node-message
  (catch-message
   (lambda ()
     (js-adopt-node js-null))))

(define caret-message
  (catch-message
   (lambda ()
     (js-caret-range-from-point 0.0 0.0))))

(define close-message
  (catch-message
   (lambda ()
     (js-close))))

(define create-attribute-message
  (catch-message
   (lambda ()
     (js-create-attribute "data-wr-test"))))

(define create-attribute-ns-message
  (catch-message
   (lambda ()
     (js-create-attribute-ns "http://www.w3.org/1999/xhtml" "data-wr-test"))))

(define create-cdata-section-message
  (catch-message
   (lambda ()
     (js-create-cdata-section "test"))))

(define create-comment-message
  (catch-message
   (lambda ()
     (js-create-comment "test"))))

(define create-document-fragment-message
  (catch-message
   (lambda ()
     (js-create-document-fragment))))

(define create-element-message
  (catch-message
   (lambda ()
     (js-create-element "div"))))

(define create-element-ns-message
  (catch-message
   (lambda ()
     (js-create-element-ns "http://www.w3.org/1999/xhtml" "div"))))

(define create-expression-message
  (catch-message
   (lambda ()
     (js-create-expression "//*" js-null))))

(define create-node-iterator-message
  (catch-message
   (lambda ()
     (js-create-node-iterator js-document 1 js-null))))

(define create-processing-instruction-message
  (catch-message
   (lambda ()
     (js-create-processing-instruction "xml-stylesheet" "href=\"x\""))))

(define create-range-message
  (catch-message
   (lambda ()
     (js-create-range))))

(define create-text-node-message
  (catch-message
   (lambda ()
     (js-create-text-node "test"))))

(define create-tree-walker-message
  (catch-message
   (lambda ()
     (js-create-tree-walker js-document 1 js-null))))

(define element-from-point-message
  (catch-message
   (lambda ()
     (js-element-from-point 0.0 0.0))))

(define elements-from-point-message
  (catch-message
   (lambda ()
     (js-elements-from-point 0.0 0.0))))

(define enable-style-sheets-message
  (catch-message
   (lambda ()
     (js-enable-style-sheets-for-set "missing"))))

(define evaluate-message
  (catch-message
   (lambda ()
     (js-evaluate "//*" js-document js-null 0 js-null))))

(define exit-fullscreen-message
  (catch-message
   (lambda ()
     (js-exit-fullscreen))))

(define exit-picture-in-picture-message
  (catch-message
   (lambda ()
     (js-exit-picture-in-picture))))

(define exit-pointer-lock-message
  (catch-message
   (lambda ()
     (js-exit-pointer-lock))))

(define get-element-by-id-message
  (catch-message
   (lambda ()
     (js-get-element-by-id "missing"))))

(define get-elements-by-class-name-message
  (catch-message
   (lambda ()
     (js-get-elements-by-class-name "missing"))))

(define get-elements-by-name-message
  (catch-message
   (lambda ()
     (js-get-elements-by-name "missing"))))

(define get-elements-by-tag-name-message
  (catch-message
   (lambda ()
     (js-get-elements-by-tag-name "div"))))

(define get-elements-by-tag-name-ns-message
  (catch-message
   (lambda ()
     (js-get-elements-by-tag-name-ns "http://www.w3.org/1999/xhtml" "div"))))

(define get-selection-message
  (catch-message
   (lambda ()
     (js-get-selection))))

(define has-focus-message
  (catch-message
   (lambda ()
     (js-has-focus))))

(define import-node-message
  (catch-message
   (lambda ()
     (js-import-node js-null 0))))

(define open-message
  (catch-message
   (lambda ()
     (js-open))))

(define query-selector-message
  (catch-message
   (lambda ()
     (js-query-selector "body"))))

(define query-selector-all-message
  (catch-message
   (lambda ()
     (js-query-selector-all "body"))))

(define release-events-message
  (catch-message
   (lambda ()
     (js-release-events))))

(js-eval
 "for (const name of globalThis.__wrDocumentBoundaryNames) {
    const saved = globalThis.__wrDocumentBoundary[name];
    if (saved.descriptor) {
      Object.defineProperty(document, name, saved.descriptor);
    } else {
      delete document[name];
    }
  }
  delete globalThis.__wrDocumentBoundary;
  delete globalThis.__wrDocumentBoundaryNames;")

(check-message head-message
               "document.head not available in this environment"
               "missing document.head message")
(check-message body-message
               "document.body not available in this environment"
               "missing document.body message")
(check-message document-element-message
               "document.documentElement not available in this environment"
               "missing document.documentElement message")

(check-message adopt-node-message
               "document.adoptNode not available in this environment"
               "missing adoptNode message")
(check-message caret-message
               "document.caretRangeFromPoint not available in this environment"
               "missing caretRangeFromPoint message")
(check-message close-message
               "document.close not available in this environment"
               "missing close message")
(check-message create-attribute-message
               "document.createAttribute not available in this environment"
               "missing createAttribute message")
(check-message create-attribute-ns-message
               "document.createAttributeNS not available in this environment"
               "missing createAttributeNS message")
(check-message create-cdata-section-message
               "document.createCDATASection not available in this environment"
               "missing createCDATASection message")
(check-message create-comment-message
               "document.createComment not available in this environment"
               "missing createComment message")
(check-message create-document-fragment-message
               "document.createDocumentFragment not available in this environment"
               "missing createDocumentFragment message")
(check-message create-element-message
               "document.createElement not available in this environment"
               "missing createElement message")
(check-message create-element-ns-message
               "document.createElementNS not available in this environment"
               "missing createElementNS message")
(check-message create-expression-message
               "document.createExpression not available in this environment"
               "missing createExpression message")
(check-message create-node-iterator-message
               "document.createNodeIterator not available in this environment"
               "missing createNodeIterator message")
(check-message create-processing-instruction-message
               "document.createProcessingInstruction not available in this environment"
               "missing createProcessingInstruction message")
(check-message create-range-message
               "document.createRange not available in this environment"
               "missing createRange message")
(check-message create-text-node-message
               "document.createTextNode not available in this environment"
               "missing createTextNode message")
(check-message create-tree-walker-message
               "document.createTreeWalker not available in this environment"
               "missing createTreeWalker message")
(check-message element-from-point-message
               "document.elementFromPoint not available in this environment"
               "missing elementFromPoint message")
(check-message elements-from-point-message
               "document.elementsFromPoint not available in this environment"
               "missing elementsFromPoint message")
(check-message enable-style-sheets-message
               "document.enableStyleSheetsForSet not available in this environment"
               "missing enableStyleSheetsForSet message")
(check-message evaluate-message
               "document.evaluate not available in this environment"
               "missing evaluate message")
(check-message exit-fullscreen-message
               "document.exitFullscreen not available in this environment"
               "missing exitFullscreen message")
(check-message exit-picture-in-picture-message
               "document.exitPictureInPicture not available in this environment"
               "missing exitPictureInPicture message")
(check-message exit-pointer-lock-message
               "document.exitPointerLock not available in this environment"
               "missing exitPointerLock message")
(check-message get-element-by-id-message
               "document.getElementById not available in this environment"
               "missing getElementById message")
(check-message get-elements-by-class-name-message
               "document.getElementsByClassName not available in this environment"
               "missing getElementsByClassName message")
(check-message get-elements-by-name-message
               "document.getElementsByName not available in this environment"
               "missing getElementsByName message")
(check-message get-elements-by-tag-name-message
               "document.getElementsByTagName not available in this environment"
               "missing getElementsByTagName message")
(check-message get-elements-by-tag-name-ns-message
               "document.getElementsByTagNameNS not available in this environment"
               "missing getElementsByTagNameNS message")
(check-message get-selection-message
               "document.getSelection not available in this environment"
               "missing getSelection message")
(check-message has-focus-message
               "document.hasFocus not available in this environment"
               "missing hasFocus message")
(check-message import-node-message
               "document.importNode not available in this environment"
               "missing importNode message")
(check-message open-message
               "document.open not available in this environment"
               "missing open message")
(check-message query-selector-message
               "document.querySelector not available in this environment"
               "missing querySelector message")
(check-message query-selector-all-message
               "document.querySelectorAll not available in this environment"
               "missing querySelectorAll message")
(check-message release-events-message
               "document.releaseEvents not available in this environment"
               "missing releaseEvents message")

(js-log "document-missing-host-ffi-ok")
#t

#lang racket/base

;; Generated from a WebRacket .ffi declaration file.
;; Raw exports are compiler-recognized aliases for active .ffi primitives.

(require (only-in "../private/ffi.rkt" unsafe-ffi-primitive))

(provide
 js-document
 js-document-head
 js-document-body
 js-document-element
 js-create-element
 js-create-text-node
 js-adopt-node
 js-caret-range-from-point
 js-close
 js-create-attribute
 js-create-attribute-ns
 js-create-cdata-section
 js-create-comment
 js-create-document-fragment
 js-create-element-ns
 js-create-expression
 js-create-node-iterator
 js-create-processing-instruction
 js-create-range
 js-create-tree-walker
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

;; js-document : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/document.
(define js-document (unsafe-ffi-primitive 'js-document))

;; js-document-head : ffi () -> (extern)
;;   Raw binding generated for webracket/unsafe/document.
(define js-document-head (unsafe-ffi-primitive 'js-document-head))

;; js-document-body : ffi () -> (extern)
;;   Raw binding generated for webracket/unsafe/document.
(define js-document-body (unsafe-ffi-primitive 'js-document-body))

;; js-document-element : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/document.
(define js-document-element (unsafe-ffi-primitive 'js-document-element))

;; js-create-element : ffi (string) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/document.
(define js-create-element (unsafe-ffi-primitive 'js-create-element))

;; js-create-text-node : ffi (string) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/document.
(define js-create-text-node (unsafe-ffi-primitive 'js-create-text-node))

;; js-adopt-node : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/document.
(define js-adopt-node (unsafe-ffi-primitive 'js-adopt-node))

;; js-caret-range-from-point : ffi (f64 f64) -> (extern)
;;   Raw binding generated for webracket/unsafe/document.
(define js-caret-range-from-point (unsafe-ffi-primitive 'js-caret-range-from-point))

;; js-close : ffi () -> ()
;;   Raw binding generated for webracket/unsafe/document.
(define js-close (unsafe-ffi-primitive 'js-close))

;; js-create-attribute : ffi (string) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/document.
(define js-create-attribute (unsafe-ffi-primitive 'js-create-attribute))

;; js-create-attribute-ns : ffi (string string) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/document.
(define js-create-attribute-ns (unsafe-ffi-primitive 'js-create-attribute-ns))

;; js-create-cdata-section : ffi (string) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/document.
(define js-create-cdata-section (unsafe-ffi-primitive 'js-create-cdata-section))

;; js-create-comment : ffi (string) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/document.
(define js-create-comment (unsafe-ffi-primitive 'js-create-comment))

;; js-create-document-fragment : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/document.
(define js-create-document-fragment (unsafe-ffi-primitive 'js-create-document-fragment))

;; js-create-element-ns : ffi (string string) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/document.
(define js-create-element-ns (unsafe-ffi-primitive 'js-create-element-ns))

;; js-create-expression : ffi (string extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/document.
(define js-create-expression (unsafe-ffi-primitive 'js-create-expression))

;; js-create-node-iterator : ffi (extern u32 extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/document.
(define js-create-node-iterator (unsafe-ffi-primitive 'js-create-node-iterator))

;; js-create-processing-instruction : ffi (string string) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/document.
(define js-create-processing-instruction (unsafe-ffi-primitive 'js-create-processing-instruction))

;; js-create-range : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/document.
(define js-create-range (unsafe-ffi-primitive 'js-create-range))

;; js-create-tree-walker : ffi (extern u32 extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/document.
(define js-create-tree-walker (unsafe-ffi-primitive 'js-create-tree-walker))

;; js-element-from-point : ffi (f64 f64) -> (extern)
;;   Raw binding generated for webracket/unsafe/document.
(define js-element-from-point (unsafe-ffi-primitive 'js-element-from-point))

;; js-elements-from-point : ffi (f64 f64) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/document.
(define js-elements-from-point (unsafe-ffi-primitive 'js-elements-from-point))

;; js-enable-style-sheets-for-set : ffi (string) -> ()
;;   Raw binding generated for webracket/unsafe/document.
(define js-enable-style-sheets-for-set (unsafe-ffi-primitive 'js-enable-style-sheets-for-set))

;; js-evaluate : ffi (string extern extern i32 extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/document.
(define js-evaluate (unsafe-ffi-primitive 'js-evaluate))

;; js-exit-fullscreen : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/document.
(define js-exit-fullscreen (unsafe-ffi-primitive 'js-exit-fullscreen))

;; js-exit-picture-in-picture : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/document.
(define js-exit-picture-in-picture (unsafe-ffi-primitive 'js-exit-picture-in-picture))

;; js-exit-pointer-lock : ffi () -> ()
;;   Raw binding generated for webracket/unsafe/document.
(define js-exit-pointer-lock (unsafe-ffi-primitive 'js-exit-pointer-lock))

;; js-get-element-by-id : ffi (string) -> (extern)
;;   Raw binding generated for webracket/unsafe/document.
(define js-get-element-by-id (unsafe-ffi-primitive 'js-get-element-by-id))

;; js-get-elements-by-class-name : ffi (string) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/document.
(define js-get-elements-by-class-name (unsafe-ffi-primitive 'js-get-elements-by-class-name))

;; js-get-elements-by-name : ffi (string) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/document.
(define js-get-elements-by-name (unsafe-ffi-primitive 'js-get-elements-by-name))

;; js-get-elements-by-tag-name : ffi (string) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/document.
(define js-get-elements-by-tag-name (unsafe-ffi-primitive 'js-get-elements-by-tag-name))

;; js-get-elements-by-tag-name-ns : ffi (string string) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/document.
(define js-get-elements-by-tag-name-ns (unsafe-ffi-primitive 'js-get-elements-by-tag-name-ns))

;; js-get-selection : ffi () -> (extern)
;;   Raw binding generated for webracket/unsafe/document.
(define js-get-selection (unsafe-ffi-primitive 'js-get-selection))

;; js-has-focus : ffi () -> (i32)
;;   Raw binding generated for webracket/unsafe/document.
(define js-has-focus (unsafe-ffi-primitive 'js-has-focus))

;; js-import-node : ffi (extern i32) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/document.
(define js-import-node (unsafe-ffi-primitive 'js-import-node))

;; js-open : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/document.
(define js-open (unsafe-ffi-primitive 'js-open))

;; js-query-selector : ffi (string) -> (extern)
;;   Raw binding generated for webracket/unsafe/document.
(define js-query-selector (unsafe-ffi-primitive 'js-query-selector))

;; js-query-selector-all : ffi (string) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/document.
(define js-query-selector-all (unsafe-ffi-primitive 'js-query-selector-all))

;; js-release-events : ffi () -> ()
;;   Raw binding generated for webracket/unsafe/document.
(define js-release-events (unsafe-ffi-primitive 'js-release-events))

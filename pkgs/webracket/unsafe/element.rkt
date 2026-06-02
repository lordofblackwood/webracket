#lang racket/base

;; Generated from a WebRacket .ffi declaration file.
;; Raw exports are compiler-recognized aliases for active .ffi primitives.

(require (only-in "../private/ffi.rkt" unsafe-ffi-primitive))

(provide
 js-element-class-list
 js-element-id
 js-set-element-id!
 js-element-class-name
 js-set-element-class-name!
 js-element-tag-name
 js-element-local-name
 js-element-namespace-uri
 js-element-prefix
 js-element-is-connected
 js-element-children
 js-element-scroll-top
 js-set-element-scroll-top!
 js-element-scroll-left
 js-set-element-scroll-left!
 js-element-scroll-width
 js-element-scroll-height
 js-element-client-width
 js-element-client-height
 js-element-offset-width
 js-element-offset-height
 js-element-child-element-count
 js-element-first-element-child
 js-element-last-element-child
 js-element-parent-element
 js-element-previous-element-sibling
 js-element-next-element-sibling
 js-element-inner-html
 js-set-element-inner-html!
 js-element-outer-html
 js-set-element-outer-html!
 js-element-text-content
 js-set-element-text-content!
 js-element-shadow-root
 js-dom-token-list-value
 js-dom-token-list-length
 js-node-list-length
 js-node-list-item
 js-html-collection-length
 js-html-collection-item
 js-html-collection-named-item
 js-shadow-root-host
 js-shadow-root-mode
 js-shadow-root-delegates-focus
 js-dom-rect-list-length
 js-dom-rect-list-item
 js-append-child!
 js-set-attribute!
 js-after!
 js-animate
 js-append!
 js-attach-shadow!
 js-before!
 js-closest
 js-computed-style-map
 js-get-animations
 js-get-attribute
 js-get-attribute-ns
 js-get-attribute-names
 js-dom-token-list-item
 js-get-attribute-node
 js-get-attribute-node-ns
 js-get-bounding-client-rect
 js-get-client-rects
 js-element-get-elements-by-class-name
 js-element-get-elements-by-tag-name
 js-element-get-elements-by-tag-name-ns
 js-has-attribute
 js-has-attribute-ns
 js-has-attributes
 js-has-pointer-capture
 js-insert-adjacent-element!
 js-insert-adjacent-html!
 js-insert-adjacent-text!
 js-matches
 js-prepend!
 js-element-query-selector
 js-element-query-selector-all
 js-release-pointer-capture!
 js-remove!
 js-remove-attribute!
 js-remove-attribute-ns!
 js-remove-attribute-node!
 js-replace-children!
 js-replace-with!
 js-request-fullscreen
 js-request-pointer-lock
 js-scroll!
 js-scroll-by!
 js-scroll-into-view!
 js-scroll-to!
 js-set-attribute-ns!
 js-set-attribute-node!
 js-set-attribute-node-ns!
 js-set-pointer-capture!
 js-toggle-attribute!
 js-toggle-attribute)

;; js-element-class-list : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/element.
(define js-element-class-list (unsafe-ffi-primitive 'js-element-class-list))

;; js-element-id : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/element.
(define js-element-id (unsafe-ffi-primitive 'js-element-id))

;; js-set-element-id! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/element.
(define js-set-element-id! (unsafe-ffi-primitive 'js-set-element-id!))

;; js-element-class-name : ffi (extern) -> (value)
;;   Raw binding generated for webracket/unsafe/element.
(define js-element-class-name (unsafe-ffi-primitive 'js-element-class-name))

;; js-set-element-class-name! : ffi (extern value) -> ()
;;   Raw binding generated for webracket/unsafe/element.
(define js-set-element-class-name! (unsafe-ffi-primitive 'js-set-element-class-name!))

;; js-element-tag-name : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/element.
(define js-element-tag-name (unsafe-ffi-primitive 'js-element-tag-name))

;; js-element-local-name : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/element.
(define js-element-local-name (unsafe-ffi-primitive 'js-element-local-name))

;; js-element-namespace-uri : ffi (extern) -> (value)
;;   Raw binding generated for webracket/unsafe/element.
(define js-element-namespace-uri (unsafe-ffi-primitive 'js-element-namespace-uri))

;; js-element-prefix : ffi (extern) -> (value)
;;   Raw binding generated for webracket/unsafe/element.
(define js-element-prefix (unsafe-ffi-primitive 'js-element-prefix))

;; js-element-is-connected : ffi (extern) -> (boolean)
;;   Raw binding generated for webracket/unsafe/element.
(define js-element-is-connected (unsafe-ffi-primitive 'js-element-is-connected))

;; js-element-children : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/element.
(define js-element-children (unsafe-ffi-primitive 'js-element-children))

;; js-element-scroll-top : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/element.
(define js-element-scroll-top (unsafe-ffi-primitive 'js-element-scroll-top))

;; js-set-element-scroll-top! : ffi (extern f64) -> ()
;;   Raw binding generated for webracket/unsafe/element.
(define js-set-element-scroll-top! (unsafe-ffi-primitive 'js-set-element-scroll-top!))

;; js-element-scroll-left : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/element.
(define js-element-scroll-left (unsafe-ffi-primitive 'js-element-scroll-left))

;; js-set-element-scroll-left! : ffi (extern f64) -> ()
;;   Raw binding generated for webracket/unsafe/element.
(define js-set-element-scroll-left! (unsafe-ffi-primitive 'js-set-element-scroll-left!))

;; js-element-scroll-width : ffi (extern) -> (u32)
;;   Raw binding generated for webracket/unsafe/element.
(define js-element-scroll-width (unsafe-ffi-primitive 'js-element-scroll-width))

;; js-element-scroll-height : ffi (extern) -> (u32)
;;   Raw binding generated for webracket/unsafe/element.
(define js-element-scroll-height (unsafe-ffi-primitive 'js-element-scroll-height))

;; js-element-client-width : ffi (extern) -> (u32)
;;   Raw binding generated for webracket/unsafe/element.
(define js-element-client-width (unsafe-ffi-primitive 'js-element-client-width))

;; js-element-client-height : ffi (extern) -> (u32)
;;   Raw binding generated for webracket/unsafe/element.
(define js-element-client-height (unsafe-ffi-primitive 'js-element-client-height))

;; js-element-offset-width : ffi (extern) -> (u32)
;;   Raw binding generated for webracket/unsafe/element.
(define js-element-offset-width (unsafe-ffi-primitive 'js-element-offset-width))

;; js-element-offset-height : ffi (extern) -> (u32)
;;   Raw binding generated for webracket/unsafe/element.
(define js-element-offset-height (unsafe-ffi-primitive 'js-element-offset-height))

;; js-element-child-element-count : ffi (extern) -> (u32)
;;   Raw binding generated for webracket/unsafe/element.
(define js-element-child-element-count (unsafe-ffi-primitive 'js-element-child-element-count))

;; js-element-first-element-child : ffi (extern) -> (extern)
;;   Raw binding generated for webracket/unsafe/element.
(define js-element-first-element-child (unsafe-ffi-primitive 'js-element-first-element-child))

;; js-element-last-element-child : ffi (extern) -> (extern)
;;   Raw binding generated for webracket/unsafe/element.
(define js-element-last-element-child (unsafe-ffi-primitive 'js-element-last-element-child))

;; js-element-parent-element : ffi (extern) -> (extern)
;;   Raw binding generated for webracket/unsafe/element.
(define js-element-parent-element (unsafe-ffi-primitive 'js-element-parent-element))

;; js-element-previous-element-sibling : ffi (extern) -> (extern)
;;   Raw binding generated for webracket/unsafe/element.
(define js-element-previous-element-sibling (unsafe-ffi-primitive 'js-element-previous-element-sibling))

;; js-element-next-element-sibling : ffi (extern) -> (extern)
;;   Raw binding generated for webracket/unsafe/element.
(define js-element-next-element-sibling (unsafe-ffi-primitive 'js-element-next-element-sibling))

;; js-element-inner-html : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/element.
(define js-element-inner-html (unsafe-ffi-primitive 'js-element-inner-html))

;; js-set-element-inner-html! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/element.
(define js-set-element-inner-html! (unsafe-ffi-primitive 'js-set-element-inner-html!))

;; js-element-outer-html : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/element.
(define js-element-outer-html (unsafe-ffi-primitive 'js-element-outer-html))

;; js-set-element-outer-html! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/element.
(define js-set-element-outer-html! (unsafe-ffi-primitive 'js-set-element-outer-html!))

;; js-element-text-content : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/element.
(define js-element-text-content (unsafe-ffi-primitive 'js-element-text-content))

;; js-set-element-text-content! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/element.
(define js-set-element-text-content! (unsafe-ffi-primitive 'js-set-element-text-content!))

;; js-element-shadow-root : ffi (extern) -> (extern)
;;   Raw binding generated for webracket/unsafe/element.
(define js-element-shadow-root (unsafe-ffi-primitive 'js-element-shadow-root))

;; js-dom-token-list-value : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/element.
(define js-dom-token-list-value (unsafe-ffi-primitive 'js-dom-token-list-value))

;; js-dom-token-list-length : ffi (extern) -> (u32)
;;   Raw binding generated for webracket/unsafe/element.
(define js-dom-token-list-length (unsafe-ffi-primitive 'js-dom-token-list-length))

;; js-node-list-length : ffi (extern) -> (u32)
;;   Raw binding generated for webracket/unsafe/element.
(define js-node-list-length (unsafe-ffi-primitive 'js-node-list-length))

;; js-node-list-item : ffi (extern i32) -> (extern)
;;   Raw binding generated for webracket/unsafe/element.
(define js-node-list-item (unsafe-ffi-primitive 'js-node-list-item))

;; js-html-collection-length : ffi (extern) -> (u32)
;;   Raw binding generated for webracket/unsafe/element.
(define js-html-collection-length (unsafe-ffi-primitive 'js-html-collection-length))

;; js-html-collection-item : ffi (extern i32) -> (extern)
;;   Raw binding generated for webracket/unsafe/element.
(define js-html-collection-item (unsafe-ffi-primitive 'js-html-collection-item))

;; js-html-collection-named-item : ffi (extern string) -> (extern)
;;   Raw binding generated for webracket/unsafe/element.
(define js-html-collection-named-item (unsafe-ffi-primitive 'js-html-collection-named-item))

;; js-shadow-root-host : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/element.
(define js-shadow-root-host (unsafe-ffi-primitive 'js-shadow-root-host))

;; js-shadow-root-mode : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/element.
(define js-shadow-root-mode (unsafe-ffi-primitive 'js-shadow-root-mode))

;; js-shadow-root-delegates-focus : ffi (extern) -> (boolean)
;;   Raw binding generated for webracket/unsafe/element.
(define js-shadow-root-delegates-focus (unsafe-ffi-primitive 'js-shadow-root-delegates-focus))

;; js-dom-rect-list-length : ffi (extern) -> (u32)
;;   Raw binding generated for webracket/unsafe/element.
(define js-dom-rect-list-length (unsafe-ffi-primitive 'js-dom-rect-list-length))

;; js-dom-rect-list-item : ffi (extern i32) -> (extern)
;;   Raw binding generated for webracket/unsafe/element.
(define js-dom-rect-list-item (unsafe-ffi-primitive 'js-dom-rect-list-item))

;; js-append-child! : ffi (extern extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/element.
(define js-append-child! (unsafe-ffi-primitive 'js-append-child!))

;; js-set-attribute! : ffi (extern string string) -> ()
;;   Raw binding generated for webracket/unsafe/element.
(define js-set-attribute! (unsafe-ffi-primitive 'js-set-attribute!))

;; js-after! : ffi (extern value) -> ()
;;   Raw binding generated for webracket/unsafe/element.
(define js-after! (unsafe-ffi-primitive 'js-after!))

;; js-animate : ffi (extern extern extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/element.
(define js-animate (unsafe-ffi-primitive 'js-animate))

;; js-append! : ffi (extern value) -> ()
;;   Raw binding generated for webracket/unsafe/element.
(define js-append! (unsafe-ffi-primitive 'js-append!))

;; js-attach-shadow! : ffi (extern extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/element.
(define js-attach-shadow! (unsafe-ffi-primitive 'js-attach-shadow!))

;; js-before! : ffi (extern value) -> ()
;;   Raw binding generated for webracket/unsafe/element.
(define js-before! (unsafe-ffi-primitive 'js-before!))

;; js-closest : ffi (extern string) -> (extern)
;;   Raw binding generated for webracket/unsafe/element.
(define js-closest (unsafe-ffi-primitive 'js-closest))

;; js-computed-style-map : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/element.
(define js-computed-style-map (unsafe-ffi-primitive 'js-computed-style-map))

;; js-get-animations : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/element.
(define js-get-animations (unsafe-ffi-primitive 'js-get-animations))

;; js-get-attribute : ffi (extern string) -> (string)
;;   Raw binding generated for webracket/unsafe/element.
(define js-get-attribute (unsafe-ffi-primitive 'js-get-attribute))

;; js-get-attribute-ns : ffi (extern string string) -> (string)
;;   Raw binding generated for webracket/unsafe/element.
(define js-get-attribute-ns (unsafe-ffi-primitive 'js-get-attribute-ns))

;; js-get-attribute-names : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/element.
(define js-get-attribute-names (unsafe-ffi-primitive 'js-get-attribute-names))

;; js-dom-token-list-item : ffi (extern i32) -> (string)
;;   Raw binding generated for webracket/unsafe/element.
(define js-dom-token-list-item (unsafe-ffi-primitive 'js-dom-token-list-item))

;; js-get-attribute-node : ffi (extern string) -> (extern)
;;   Raw binding generated for webracket/unsafe/element.
(define js-get-attribute-node (unsafe-ffi-primitive 'js-get-attribute-node))

;; js-get-attribute-node-ns : ffi (extern string string) -> (extern)
;;   Raw binding generated for webracket/unsafe/element.
(define js-get-attribute-node-ns (unsafe-ffi-primitive 'js-get-attribute-node-ns))

;; js-get-bounding-client-rect : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/element.
(define js-get-bounding-client-rect (unsafe-ffi-primitive 'js-get-bounding-client-rect))

;; js-get-client-rects : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/element.
(define js-get-client-rects (unsafe-ffi-primitive 'js-get-client-rects))

;; js-element-get-elements-by-class-name : ffi (extern string) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/element.
(define js-element-get-elements-by-class-name (unsafe-ffi-primitive 'js-element-get-elements-by-class-name))

;; js-element-get-elements-by-tag-name : ffi (extern string) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/element.
(define js-element-get-elements-by-tag-name (unsafe-ffi-primitive 'js-element-get-elements-by-tag-name))

;; js-element-get-elements-by-tag-name-ns : ffi (extern string string) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/element.
(define js-element-get-elements-by-tag-name-ns (unsafe-ffi-primitive 'js-element-get-elements-by-tag-name-ns))

;; js-has-attribute : ffi (extern string) -> (i32)
;;   Raw binding generated for webracket/unsafe/element.
(define js-has-attribute (unsafe-ffi-primitive 'js-has-attribute))

;; js-has-attribute-ns : ffi (extern string string) -> (i32)
;;   Raw binding generated for webracket/unsafe/element.
(define js-has-attribute-ns (unsafe-ffi-primitive 'js-has-attribute-ns))

;; js-has-attributes : ffi (extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/element.
(define js-has-attributes (unsafe-ffi-primitive 'js-has-attributes))

;; js-has-pointer-capture : ffi (extern i32) -> (i32)
;;   Raw binding generated for webracket/unsafe/element.
(define js-has-pointer-capture (unsafe-ffi-primitive 'js-has-pointer-capture))

;; js-insert-adjacent-element! : ffi (extern string extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/element.
(define js-insert-adjacent-element! (unsafe-ffi-primitive 'js-insert-adjacent-element!))

;; js-insert-adjacent-html! : ffi (extern string string) -> ()
;;   Raw binding generated for webracket/unsafe/element.
(define js-insert-adjacent-html! (unsafe-ffi-primitive 'js-insert-adjacent-html!))

;; js-insert-adjacent-text! : ffi (extern string string) -> ()
;;   Raw binding generated for webracket/unsafe/element.
(define js-insert-adjacent-text! (unsafe-ffi-primitive 'js-insert-adjacent-text!))

;; js-matches : ffi (extern string) -> (i32)
;;   Raw binding generated for webracket/unsafe/element.
(define js-matches (unsafe-ffi-primitive 'js-matches))

;; js-prepend! : ffi (extern value) -> ()
;;   Raw binding generated for webracket/unsafe/element.
(define js-prepend! (unsafe-ffi-primitive 'js-prepend!))

;; js-element-query-selector : ffi (extern string) -> (extern)
;;   Raw binding generated for webracket/unsafe/element.
(define js-element-query-selector (unsafe-ffi-primitive 'js-element-query-selector))

;; js-element-query-selector-all : ffi (extern string) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/element.
(define js-element-query-selector-all (unsafe-ffi-primitive 'js-element-query-selector-all))

;; js-release-pointer-capture! : ffi (extern i32) -> ()
;;   Raw binding generated for webracket/unsafe/element.
(define js-release-pointer-capture! (unsafe-ffi-primitive 'js-release-pointer-capture!))

;; js-remove! : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/element.
(define js-remove! (unsafe-ffi-primitive 'js-remove!))

;; js-remove-attribute! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/element.
(define js-remove-attribute! (unsafe-ffi-primitive 'js-remove-attribute!))

;; js-remove-attribute-ns! : ffi (extern string string) -> ()
;;   Raw binding generated for webracket/unsafe/element.
(define js-remove-attribute-ns! (unsafe-ffi-primitive 'js-remove-attribute-ns!))

;; js-remove-attribute-node! : ffi (extern extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/element.
(define js-remove-attribute-node! (unsafe-ffi-primitive 'js-remove-attribute-node!))

;; js-replace-children! : ffi (extern extern) -> ()
;;   Raw binding generated for webracket/unsafe/element.
(define js-replace-children! (unsafe-ffi-primitive 'js-replace-children!))

;; js-replace-with! : ffi (extern extern) -> ()
;;   Raw binding generated for webracket/unsafe/element.
(define js-replace-with! (unsafe-ffi-primitive 'js-replace-with!))

;; js-request-fullscreen : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/element.
(define js-request-fullscreen (unsafe-ffi-primitive 'js-request-fullscreen))

;; js-request-pointer-lock : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/element.
(define js-request-pointer-lock (unsafe-ffi-primitive 'js-request-pointer-lock))

;; js-scroll! : ffi (extern f64 f64) -> ()
;;   Raw binding generated for webracket/unsafe/element.
(define js-scroll! (unsafe-ffi-primitive 'js-scroll!))

;; js-scroll-by! : ffi (extern f64 f64) -> ()
;;   Raw binding generated for webracket/unsafe/element.
(define js-scroll-by! (unsafe-ffi-primitive 'js-scroll-by!))

;; js-scroll-into-view! : ffi (extern i32) -> ()
;;   Raw binding generated for webracket/unsafe/element.
(define js-scroll-into-view! (unsafe-ffi-primitive 'js-scroll-into-view!))

;; js-scroll-to! : ffi (extern f64 f64) -> ()
;;   Raw binding generated for webracket/unsafe/element.
(define js-scroll-to! (unsafe-ffi-primitive 'js-scroll-to!))

;; js-set-attribute-ns! : ffi (extern string string string) -> ()
;;   Raw binding generated for webracket/unsafe/element.
(define js-set-attribute-ns! (unsafe-ffi-primitive 'js-set-attribute-ns!))

;; js-set-attribute-node! : ffi (extern extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/element.
(define js-set-attribute-node! (unsafe-ffi-primitive 'js-set-attribute-node!))

;; js-set-attribute-node-ns! : ffi (extern extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/element.
(define js-set-attribute-node-ns! (unsafe-ffi-primitive 'js-set-attribute-node-ns!))

;; js-set-pointer-capture! : ffi (extern i32) -> ()
;;   Raw binding generated for webracket/unsafe/element.
(define js-set-pointer-capture! (unsafe-ffi-primitive 'js-set-pointer-capture!))

;; js-toggle-attribute! : ffi (extern string i32) -> (i32)
;;   Raw binding generated for webracket/unsafe/element.
(define js-toggle-attribute! (unsafe-ffi-primitive 'js-toggle-attribute!))

;; js-toggle-attribute : ffi (extern string) -> (i32)
;;   Raw binding generated for webracket/unsafe/element.
(define js-toggle-attribute (unsafe-ffi-primitive 'js-toggle-attribute))

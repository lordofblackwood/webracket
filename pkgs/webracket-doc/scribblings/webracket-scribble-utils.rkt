#lang at-exp racket
(require scribble/manual
         scribble/core
         scribble/html-properties)

(provide wiki
          margin-wiki
          em
          literal-tt
          flag
          how-to-require
          compile-option-bar
          warning-bar
          legacy-module-warning
          mdn-bar
          jsx-doc-url
          jsx-bar)

(define (wiki title page)
   (hyperlink
    (string-append "https://en.wikipedia.org/wiki/" page)
    (list title " Ⓦ")))

(define (margin-wiki title page)
   (margin-note
    (hyperlink
     (string-append "https://en.wikipedia.org/wiki/" page)
     (list "Ⓦ " title))))

(define (em . xs) (apply italic xs))

(define (literal-tt s)
  (apply tt (map string (string->list s))))

(define (flag s)
  (literal-tt s))

(define-syntax-rule (how-to-require req-form name mod-path)
  @defmodule[#:require-form (lambda (modname)
                               (list (racket (req-form name))))
             mod-path
             #:link-target? #f
             #:packages ()
             #:no-declare])

;; compile-option-bar : string? string? -> block?
;;   Render a compile-option banner styled like the module require bar.
(define (compile-option-bar label options)
  (make-table
   (make-style "defmodule"
               (list (background-color-property "#eef5ff")))
   (list (list (para (list (hspace 1)
                           (literal-tt label)
                           (hspace 1)
                           (literal-tt options)))))))

;; warning-bar : content? ... -> block?
;;   Render a high-visibility warning banner.
(define (warning-bar . content)
  (make-table
   (make-style "defmodule"
               (list (background-color-property "#fff1f2")))
   (list (list (para (append (list (hspace 1))
                             content))))))

;; legacy-module-warning : -> block?
;;   Warn that a section still documents the pre-module library interface.
(define (legacy-module-warning)
  (warning-bar
   (bold "Warning: module migration pending. ")
   "This section still documents the legacy top-level API based on "
   (tt "include-lib")
   " or "
   (tt "require-lib")
   ". It has not yet been rewritten for module-based programs. For new code, "
   "use "
   (tt "#lang webracket/base")
   " and ordinary "
   (tt "require")
   " where a module-based library is available."))

;; mdn-bar : string? string? -> block?
;;   Render an MDN banner linking to a browser API page.
(define (mdn-bar label url)
  (make-table
   (make-style "defmodule"
               (list (background-color-property "#f7fbff")))
   (list (list (para (list (hspace 1)
                           (tt "MDN")
                           (hspace 2)
                           (hyperlink url (tt label))))))))

;; jsx-doc-url : string? -> string?
;;   Build a JSXGraph documentation URL for a symbols page.
(define (jsx-doc-url page)
  (string-append "https://jsxgraph.org/docs/symbols/" page ".html"))

;; jsx-bar : string? string? -> block?
;;   Render a JSXGraph banner linking to the corresponding JSX docs page.
(define (jsx-bar label url)
  (make-table
   (make-style "defmodule"
               (list (background-color-property "#f7fff4")))
   (list (list (para (list (hspace 1)
                           (tt "JSXGraph")
                           (hspace 2)
                           (hyperlink url (tt label))))))))

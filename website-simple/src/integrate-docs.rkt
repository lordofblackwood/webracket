#lang racket/base

(require racket/cmdline
         racket/file
         racket/list
         racket/path
         racket/string)

;; docs-dir : path-string?
;;   Directory containing rendered Scribble HTML files.
(define docs-dir
  (command-line
   #:args (docs-dir)
   docs-dir))

;; header-html : string?
;;   Static simple-site header inserted into rendered Scribble pages.
(define header-html
  (string-append
   "<header class=\"wr-doc-header\">"
   "<nav class=\"wr-doc-nav\">"
   "<a class=\"wr-doc-wordmark\" href=\"../../site.html\" aria-label=\"WebRacket home\">"
   "<img class=\"wr-doc-logo\" src=\"../../assets/hex-racket-wasm-logo.svg\" alt=\"\"/>"
   "<span class=\"wr-doc-wordmark-muted\">Web</span>"
   "<span class=\"wr-doc-wordmark-strong\">Racket</span>"
   "</a>"
   "<div class=\"wr-doc-links\">"
   "<a href=\"../../site.html#quick-start\">Quick Start</a>"
   "<a href=\"../../site.html#examples\">Examples</a>"
   "<a href=\"index.html\">Documentation</a>"
   "<a href=\"https://github.com/soegaard/webracket\">GitHub</a>"
   "</div>"
   "</nav>"
   "</header>"))

;; html-file? : path? -> boolean?
;;   Check whether path names an HTML file.
(define (html-file? path)
  (string-suffix? (path->string path) ".html"))

;; inject-doc-css : string? -> string?
;;   Add the docs integration stylesheet to the rendered head.
(define (inject-doc-css html)
  (if (string-contains? html "href=\"docs.css\"")
      html
      (regexp-replace #rx"</head>"
                      html
                      "<link rel=\"stylesheet\" type=\"text/css\" href=\"docs.css\" title=\"default\"/></head>")))

;; inject-doc-header : string? -> string?
;;   Add the simple-site header immediately after the opening body tag.
(define (inject-doc-header html)
  (if (string-contains? html "class=\"wr-doc-header\"")
      html
      (regexp-replace #rx"(<body[^>]*>)"
                      html
                      (string-append "\\1" header-html))))

;; integrate-file! : path? -> void?
;;   Apply simple-site integration to one rendered Scribble HTML file.
(define (integrate-file! path)
  (define html (file->string path))
  (define updated (inject-doc-header (inject-doc-css html)))
  (display-to-file updated path #:exists 'truncate/replace))

(for ([path (in-list (sort (find-files html-file? docs-dir)
                           string<?
                           #:key path->string))])
  (integrate-file! path))

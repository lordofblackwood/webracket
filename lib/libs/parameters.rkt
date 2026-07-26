#lang webracket

;;;
;;; Parameters
;;;

;; Legacy script-library compatibility wrapper for the small parameter
;; procedure used by libraries such as web-pict.
(include/reader "../../pkgs/webracket-lib/compiler/legacy-stdlib/parameters.rkt"
                read-syntax/skip-first-line)

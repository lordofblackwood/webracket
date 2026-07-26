#lang webracket

;;;
;;; Shared DOM wrapper structs
;;;

(require webracket/unsafe/standard)

;; Keep the legacy include-lib DOM wrappers aligned with the canonical
;; browser/private shared wrapper definitions.
(include "../../pkgs/browser/private/shared-library-structs-body.rkt")

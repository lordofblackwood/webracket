#lang webracket/base

(require intersection-observer)

(void
 intersection-observer
 intersection-observer?
 intersection-observer-supported?
 intersection-observer-raw
 make-intersection-observer-options
 intersection-observer-options?
 intersection-observer-options-root
 intersection-observer-options-root-margin
 intersection-observer-options-threshold
 make-intersection-observer
 intersection-observer-observe!
 intersection-observer-unobserve!
 intersection-observer-disconnect!
 intersection-observer-entry
 intersection-observer-entry?
 intersection-observer-entry-raw
 intersection-observer-entry-target
 intersection-observer-entry-is-intersecting?
 intersection-observer-entry-intersection-ratio
 intersection-observer-entry-bounding-client-rect
 intersection-observer-entry-intersection-rect
 intersection-observer-entry-root-bounds
 intersection-observer-entry-time)

#t

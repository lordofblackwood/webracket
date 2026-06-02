#lang racket/base

;; Generated from a WebRacket .ffi declaration file.
;; Raw exports are compiler-recognized aliases for active .ffi primitives.

(require (only-in "../private/ffi.rkt" unsafe-ffi-primitive))

(provide
 js-media-audio-tracks
 js-media-autoplay
 js-set-media-autoplay!
 js-media-buffered
 js-media-controls
 js-set-media-controls!
 js-media-controls-list
 js-media-cross-origin
 js-set-media-cross-origin!
 js-media-current-src
 js-media-current-time
 js-set-media-current-time!
 js-media-default-muted
 js-set-media-default-muted!
 js-media-default-playback-rate
 js-set-media-default-playback-rate!
 js-media-disable-remote-playback
 js-set-media-disable-remote-playback!
 js-media-duration
 js-media-ended
 js-media-error
 js-media-loop
 js-set-media-loop!
 js-media-media-keys
 js-media-media-group
 js-set-media-media-group!
 js-media-muted
 js-set-media-muted!
 js-media-network-state
 js-media-paused
 js-media-playback-rate
 js-set-media-playback-rate!
 js-media-played
 js-media-preload
 js-set-media-preload!
 js-media-preserves-pitch
 js-set-media-preserves-pitch!
 js-media-ready-state
 js-media-seekable
 js-media-seeking
 js-media-sink-id
 js-media-src
 js-set-media-src!
 js-media-src-object
 js-set-media-src-object!
 js-media-text-tracks
 js-media-video-tracks
 js-media-volume
 js-set-media-volume!
 js-media-add-text-track!
 js-media-can-play-type
 js-media-capture-stream
 js-media-fast-seek!
 js-media-load!
 js-media-pause
 js-media-play
 js-media-set-media-keys!
 js-media-set-sink-id!)

;; js-media-audio-tracks : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/media.
(define js-media-audio-tracks (unsafe-ffi-primitive 'js-media-audio-tracks))

;; js-media-autoplay : ffi (extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/media.
(define js-media-autoplay (unsafe-ffi-primitive 'js-media-autoplay))

;; js-set-media-autoplay! : ffi (extern i32) -> ()
;;   Raw binding generated for webracket/unsafe/media.
(define js-set-media-autoplay! (unsafe-ffi-primitive 'js-set-media-autoplay!))

;; js-media-buffered : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/media.
(define js-media-buffered (unsafe-ffi-primitive 'js-media-buffered))

;; js-media-controls : ffi (extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/media.
(define js-media-controls (unsafe-ffi-primitive 'js-media-controls))

;; js-set-media-controls! : ffi (extern i32) -> ()
;;   Raw binding generated for webracket/unsafe/media.
(define js-set-media-controls! (unsafe-ffi-primitive 'js-set-media-controls!))

;; js-media-controls-list : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/media.
(define js-media-controls-list (unsafe-ffi-primitive 'js-media-controls-list))

;; js-media-cross-origin : ffi (extern) -> (value)
;;   Raw binding generated for webracket/unsafe/media.
(define js-media-cross-origin (unsafe-ffi-primitive 'js-media-cross-origin))

;; js-set-media-cross-origin! : ffi (extern value) -> ()
;;   Raw binding generated for webracket/unsafe/media.
(define js-set-media-cross-origin! (unsafe-ffi-primitive 'js-set-media-cross-origin!))

;; js-media-current-src : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/media.
(define js-media-current-src (unsafe-ffi-primitive 'js-media-current-src))

;; js-media-current-time : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/media.
(define js-media-current-time (unsafe-ffi-primitive 'js-media-current-time))

;; js-set-media-current-time! : ffi (extern f64) -> ()
;;   Raw binding generated for webracket/unsafe/media.
(define js-set-media-current-time! (unsafe-ffi-primitive 'js-set-media-current-time!))

;; js-media-default-muted : ffi (extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/media.
(define js-media-default-muted (unsafe-ffi-primitive 'js-media-default-muted))

;; js-set-media-default-muted! : ffi (extern i32) -> ()
;;   Raw binding generated for webracket/unsafe/media.
(define js-set-media-default-muted! (unsafe-ffi-primitive 'js-set-media-default-muted!))

;; js-media-default-playback-rate : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/media.
(define js-media-default-playback-rate (unsafe-ffi-primitive 'js-media-default-playback-rate))

;; js-set-media-default-playback-rate! : ffi (extern f64) -> ()
;;   Raw binding generated for webracket/unsafe/media.
(define js-set-media-default-playback-rate! (unsafe-ffi-primitive 'js-set-media-default-playback-rate!))

;; js-media-disable-remote-playback : ffi (extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/media.
(define js-media-disable-remote-playback (unsafe-ffi-primitive 'js-media-disable-remote-playback))

;; js-set-media-disable-remote-playback! : ffi (extern i32) -> ()
;;   Raw binding generated for webracket/unsafe/media.
(define js-set-media-disable-remote-playback! (unsafe-ffi-primitive 'js-set-media-disable-remote-playback!))

;; js-media-duration : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/media.
(define js-media-duration (unsafe-ffi-primitive 'js-media-duration))

;; js-media-ended : ffi (extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/media.
(define js-media-ended (unsafe-ffi-primitive 'js-media-ended))

;; js-media-error : ffi (extern) -> (extern)
;;   Raw binding generated for webracket/unsafe/media.
(define js-media-error (unsafe-ffi-primitive 'js-media-error))

;; js-media-loop : ffi (extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/media.
(define js-media-loop (unsafe-ffi-primitive 'js-media-loop))

;; js-set-media-loop! : ffi (extern i32) -> ()
;;   Raw binding generated for webracket/unsafe/media.
(define js-set-media-loop! (unsafe-ffi-primitive 'js-set-media-loop!))

;; js-media-media-keys : ffi (extern) -> (extern)
;;   Raw binding generated for webracket/unsafe/media.
(define js-media-media-keys (unsafe-ffi-primitive 'js-media-media-keys))

;; js-media-media-group : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/media.
(define js-media-media-group (unsafe-ffi-primitive 'js-media-media-group))

;; js-set-media-media-group! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/media.
(define js-set-media-media-group! (unsafe-ffi-primitive 'js-set-media-media-group!))

;; js-media-muted : ffi (extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/media.
(define js-media-muted (unsafe-ffi-primitive 'js-media-muted))

;; js-set-media-muted! : ffi (extern i32) -> ()
;;   Raw binding generated for webracket/unsafe/media.
(define js-set-media-muted! (unsafe-ffi-primitive 'js-set-media-muted!))

;; js-media-network-state : ffi (extern) -> (u32)
;;   Raw binding generated for webracket/unsafe/media.
(define js-media-network-state (unsafe-ffi-primitive 'js-media-network-state))

;; js-media-paused : ffi (extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/media.
(define js-media-paused (unsafe-ffi-primitive 'js-media-paused))

;; js-media-playback-rate : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/media.
(define js-media-playback-rate (unsafe-ffi-primitive 'js-media-playback-rate))

;; js-set-media-playback-rate! : ffi (extern f64) -> ()
;;   Raw binding generated for webracket/unsafe/media.
(define js-set-media-playback-rate! (unsafe-ffi-primitive 'js-set-media-playback-rate!))

;; js-media-played : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/media.
(define js-media-played (unsafe-ffi-primitive 'js-media-played))

;; js-media-preload : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/media.
(define js-media-preload (unsafe-ffi-primitive 'js-media-preload))

;; js-set-media-preload! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/media.
(define js-set-media-preload! (unsafe-ffi-primitive 'js-set-media-preload!))

;; js-media-preserves-pitch : ffi (extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/media.
(define js-media-preserves-pitch (unsafe-ffi-primitive 'js-media-preserves-pitch))

;; js-set-media-preserves-pitch! : ffi (extern i32) -> ()
;;   Raw binding generated for webracket/unsafe/media.
(define js-set-media-preserves-pitch! (unsafe-ffi-primitive 'js-set-media-preserves-pitch!))

;; js-media-ready-state : ffi (extern) -> (u32)
;;   Raw binding generated for webracket/unsafe/media.
(define js-media-ready-state (unsafe-ffi-primitive 'js-media-ready-state))

;; js-media-seekable : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/media.
(define js-media-seekable (unsafe-ffi-primitive 'js-media-seekable))

;; js-media-seeking : ffi (extern) -> (i32)
;;   Raw binding generated for webracket/unsafe/media.
(define js-media-seeking (unsafe-ffi-primitive 'js-media-seeking))

;; js-media-sink-id : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/media.
(define js-media-sink-id (unsafe-ffi-primitive 'js-media-sink-id))

;; js-media-src : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/media.
(define js-media-src (unsafe-ffi-primitive 'js-media-src))

;; js-set-media-src! : ffi (extern string) -> ()
;;   Raw binding generated for webracket/unsafe/media.
(define js-set-media-src! (unsafe-ffi-primitive 'js-set-media-src!))

;; js-media-src-object : ffi (extern) -> (extern)
;;   Raw binding generated for webracket/unsafe/media.
(define js-media-src-object (unsafe-ffi-primitive 'js-media-src-object))

;; js-set-media-src-object! : ffi (extern extern) -> ()
;;   Raw binding generated for webracket/unsafe/media.
(define js-set-media-src-object! (unsafe-ffi-primitive 'js-set-media-src-object!))

;; js-media-text-tracks : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/media.
(define js-media-text-tracks (unsafe-ffi-primitive 'js-media-text-tracks))

;; js-media-video-tracks : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/media.
(define js-media-video-tracks (unsafe-ffi-primitive 'js-media-video-tracks))

;; js-media-volume : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/media.
(define js-media-volume (unsafe-ffi-primitive 'js-media-volume))

;; js-set-media-volume! : ffi (extern f64) -> ()
;;   Raw binding generated for webracket/unsafe/media.
(define js-set-media-volume! (unsafe-ffi-primitive 'js-set-media-volume!))

;; js-media-add-text-track! : ffi (extern string value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/media.
(define js-media-add-text-track! (unsafe-ffi-primitive 'js-media-add-text-track!))

;; js-media-can-play-type : ffi (extern string) -> (string)
;;   Raw binding generated for webracket/unsafe/media.
(define js-media-can-play-type (unsafe-ffi-primitive 'js-media-can-play-type))

;; js-media-capture-stream : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/media.
(define js-media-capture-stream (unsafe-ffi-primitive 'js-media-capture-stream))

;; js-media-fast-seek! : ffi (extern f64) -> ()
;;   Raw binding generated for webracket/unsafe/media.
(define js-media-fast-seek! (unsafe-ffi-primitive 'js-media-fast-seek!))

;; js-media-load! : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/media.
(define js-media-load! (unsafe-ffi-primitive 'js-media-load!))

;; js-media-pause : ffi (extern) -> ()
;;   Raw binding generated for webracket/unsafe/media.
(define js-media-pause (unsafe-ffi-primitive 'js-media-pause))

;; js-media-play : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/media.
(define js-media-play (unsafe-ffi-primitive 'js-media-play))

;; js-media-set-media-keys! : ffi (extern extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/media.
(define js-media-set-media-keys! (unsafe-ffi-primitive 'js-media-set-media-keys!))

;; js-media-set-sink-id! : ffi (extern string) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/media.
(define js-media-set-sink-id! (unsafe-ffi-primitive 'js-media-set-sink-id!))

#lang racket/base

;; Generated from a WebRacket .ffi declaration file.
;; Raw exports are compiler-recognized aliases for active .ffi primitives.

(require (only-in "../private/ffi.rkt" unsafe-ffi-primitive))

(provide
 js-audio-context-new
 js-audio-context-close
 js-audio-context-resume
 js-audio-context-suspend
 js-audio-context-state
 js-audio-context-current-time
 js-audio-context-sample-rate
 js-audio-context-base-latency
 js-audio-context-output-latency
 js-audio-context-destination
 js-audio-context-listener
 js-audio-context-create-gain
 js-audio-context-create-oscillator
 js-audio-context-create-buffer-source
 js-audio-context-create-analyser
 js-audio-context-create-biquad-filter
 js-audio-context-create-constant-source
 js-audio-context-create-channel-splitter
 js-audio-context-create-channel-merger
 js-audio-context-create-dynamics-compressor
 js-audio-context-create-panner
 js-audio-context-create-stereo-panner
 js-audio-context-create-buffer
 js-audio-context-create-periodic-wave
 js-audio-context-decode-audio-data
 js-audio-node-context
 js-audio-node-connect
 js-audio-node-disconnect
 js-audio-param-value
 js-audio-param-set-value!
 js-audio-param-set-value-at-time!
 js-audio-param-linear-ramp-to-value-at-time!
 js-audio-param-exponential-ramp-to-value-at-time!
 js-audio-param-set-target-at-time!
 js-audio-param-set-value-curve-at-time!
 js-audio-param-cancel-scheduled-values!
 js-audio-param-cancel-and-hold-at-time!
 js-audio-buffer-length
 js-audio-buffer-duration
 js-audio-buffer-sample-rate
 js-audio-buffer-number-of-channels
 js-audio-buffer-get-channel-data
 js-audio-gain-node-gain
 js-audio-oscillator-node-type
 js-audio-oscillator-node-set-type!
 js-audio-oscillator-node-frequency
 js-audio-oscillator-node-detune
 js-audio-oscillator-node-start!
 js-audio-oscillator-node-stop!
 js-audio-oscillator-node-set-periodic-wave!
 js-audio-audio-buffer-source-node-buffer
 js-audio-audio-buffer-source-node-set-buffer!
 js-audio-audio-buffer-source-node-playback-rate
 js-audio-audio-buffer-source-node-detune
 js-audio-audio-buffer-source-node-loop
 js-audio-audio-buffer-source-node-set-loop!
 js-audio-audio-buffer-source-node-loop-start
 js-audio-audio-buffer-source-node-set-loop-start!
 js-audio-audio-buffer-source-node-loop-end
 js-audio-audio-buffer-source-node-set-loop-end!
 js-audio-audio-buffer-source-node-start!
 js-audio-audio-buffer-source-node-stop!
 js-audio-analyser-node-fft-size
 js-audio-analyser-node-set-fft-size!
 js-audio-analyser-node-frequency-bin-count
 js-audio-analyser-node-min-decibels
 js-audio-analyser-node-set-min-decibels!
 js-audio-analyser-node-max-decibels
 js-audio-analyser-node-set-max-decibels!
 js-audio-analyser-node-smoothing-time-constant
 js-audio-analyser-node-set-smoothing-time-constant!
 js-audio-analyser-node-get-byte-frequency-data!
 js-audio-analyser-node-get-byte-time-domain-data!
 js-audio-analyser-node-get-float-frequency-data!
 js-audio-analyser-node-get-float-time-domain-data!
 js-audio-biquad-filter-node-type
 js-audio-biquad-filter-node-set-type!
 js-audio-biquad-filter-node-frequency
 js-audio-biquad-filter-node-detune
 js-audio-biquad-filter-node-q
 js-audio-biquad-filter-node-gain
 js-audio-constant-source-node-offset
 js-audio-constant-source-node-start!
 js-audio-constant-source-node-stop!
 js-audio-dynamics-compressor-node-threshold
 js-audio-dynamics-compressor-node-knee
 js-audio-dynamics-compressor-node-ratio
 js-audio-dynamics-compressor-node-reduction
 js-audio-dynamics-compressor-node-attack
 js-audio-dynamics-compressor-node-release
 js-audio-panner-node-panning-model
 js-audio-panner-node-set-panning-model!
 js-audio-panner-node-distance-model
 js-audio-panner-node-set-distance-model!
 js-audio-panner-node-position-x
 js-audio-panner-node-position-y
 js-audio-panner-node-position-z
 js-audio-panner-node-orientation-x
 js-audio-panner-node-orientation-y
 js-audio-panner-node-orientation-z
 js-audio-panner-node-ref-distance
 js-audio-panner-node-set-ref-distance!
 js-audio-panner-node-max-distance
 js-audio-panner-node-set-max-distance!
 js-audio-panner-node-rolloff-factor
 js-audio-panner-node-set-rolloff-factor!
 js-audio-panner-node-cone-inner-angle
 js-audio-panner-node-set-cone-inner-angle!
 js-audio-panner-node-cone-outer-angle
 js-audio-panner-node-set-cone-outer-angle!
 js-audio-panner-node-cone-outer-gain
 js-audio-panner-node-set-cone-outer-gain!
 js-audio-stereo-panner-node-pan)

;; js-audio-context-new : ffi () -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-context-new (unsafe-ffi-primitive 'js-audio-context-new))

;; js-audio-context-close : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-context-close (unsafe-ffi-primitive 'js-audio-context-close))

;; js-audio-context-resume : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-context-resume (unsafe-ffi-primitive 'js-audio-context-resume))

;; js-audio-context-suspend : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-context-suspend (unsafe-ffi-primitive 'js-audio-context-suspend))

;; js-audio-context-state : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-context-state (unsafe-ffi-primitive 'js-audio-context-state))

;; js-audio-context-current-time : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-context-current-time (unsafe-ffi-primitive 'js-audio-context-current-time))

;; js-audio-context-sample-rate : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-context-sample-rate (unsafe-ffi-primitive 'js-audio-context-sample-rate))

;; js-audio-context-base-latency : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-context-base-latency (unsafe-ffi-primitive 'js-audio-context-base-latency))

;; js-audio-context-output-latency : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-context-output-latency (unsafe-ffi-primitive 'js-audio-context-output-latency))

;; js-audio-context-destination : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-context-destination (unsafe-ffi-primitive 'js-audio-context-destination))

;; js-audio-context-listener : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-context-listener (unsafe-ffi-primitive 'js-audio-context-listener))

;; js-audio-context-create-gain : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-context-create-gain (unsafe-ffi-primitive 'js-audio-context-create-gain))

;; js-audio-context-create-oscillator : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-context-create-oscillator (unsafe-ffi-primitive 'js-audio-context-create-oscillator))

;; js-audio-context-create-buffer-source : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-context-create-buffer-source (unsafe-ffi-primitive 'js-audio-context-create-buffer-source))

;; js-audio-context-create-analyser : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-context-create-analyser (unsafe-ffi-primitive 'js-audio-context-create-analyser))

;; js-audio-context-create-biquad-filter : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-context-create-biquad-filter (unsafe-ffi-primitive 'js-audio-context-create-biquad-filter))

;; js-audio-context-create-constant-source : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-context-create-constant-source (unsafe-ffi-primitive 'js-audio-context-create-constant-source))

;; js-audio-context-create-channel-splitter : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-context-create-channel-splitter (unsafe-ffi-primitive 'js-audio-context-create-channel-splitter))

;; js-audio-context-create-channel-merger : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-context-create-channel-merger (unsafe-ffi-primitive 'js-audio-context-create-channel-merger))

;; js-audio-context-create-dynamics-compressor : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-context-create-dynamics-compressor (unsafe-ffi-primitive 'js-audio-context-create-dynamics-compressor))

;; js-audio-context-create-panner : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-context-create-panner (unsafe-ffi-primitive 'js-audio-context-create-panner))

;; js-audio-context-create-stereo-panner : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-context-create-stereo-panner (unsafe-ffi-primitive 'js-audio-context-create-stereo-panner))

;; js-audio-context-create-buffer : ffi (extern value value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-context-create-buffer (unsafe-ffi-primitive 'js-audio-context-create-buffer))

;; js-audio-context-create-periodic-wave : ffi (extern value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-context-create-periodic-wave (unsafe-ffi-primitive 'js-audio-context-create-periodic-wave))

;; js-audio-context-decode-audio-data : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-context-decode-audio-data (unsafe-ffi-primitive 'js-audio-context-decode-audio-data))

;; js-audio-node-context : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-node-context (unsafe-ffi-primitive 'js-audio-node-context))

;; js-audio-node-connect : ffi (extern value value value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-node-connect (unsafe-ffi-primitive 'js-audio-node-connect))

;; js-audio-node-disconnect : ffi (extern value value value) -> ()
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-node-disconnect (unsafe-ffi-primitive 'js-audio-node-disconnect))

;; js-audio-param-value : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-param-value (unsafe-ffi-primitive 'js-audio-param-value))

;; js-audio-param-set-value! : ffi (extern value) -> ()
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-param-set-value! (unsafe-ffi-primitive 'js-audio-param-set-value!))

;; js-audio-param-set-value-at-time! : ffi (extern value value) -> ()
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-param-set-value-at-time! (unsafe-ffi-primitive 'js-audio-param-set-value-at-time!))

;; js-audio-param-linear-ramp-to-value-at-time! : ffi (extern value value) -> ()
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-param-linear-ramp-to-value-at-time! (unsafe-ffi-primitive 'js-audio-param-linear-ramp-to-value-at-time!))

;; js-audio-param-exponential-ramp-to-value-at-time! : ffi (extern value value) -> ()
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-param-exponential-ramp-to-value-at-time! (unsafe-ffi-primitive 'js-audio-param-exponential-ramp-to-value-at-time!))

;; js-audio-param-set-target-at-time! : ffi (extern value value value) -> ()
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-param-set-target-at-time! (unsafe-ffi-primitive 'js-audio-param-set-target-at-time!))

;; js-audio-param-set-value-curve-at-time! : ffi (extern value value value) -> ()
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-param-set-value-curve-at-time! (unsafe-ffi-primitive 'js-audio-param-set-value-curve-at-time!))

;; js-audio-param-cancel-scheduled-values! : ffi (extern value) -> ()
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-param-cancel-scheduled-values! (unsafe-ffi-primitive 'js-audio-param-cancel-scheduled-values!))

;; js-audio-param-cancel-and-hold-at-time! : ffi (extern value) -> ()
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-param-cancel-and-hold-at-time! (unsafe-ffi-primitive 'js-audio-param-cancel-and-hold-at-time!))

;; js-audio-buffer-length : ffi (extern) -> (u32)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-buffer-length (unsafe-ffi-primitive 'js-audio-buffer-length))

;; js-audio-buffer-duration : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-buffer-duration (unsafe-ffi-primitive 'js-audio-buffer-duration))

;; js-audio-buffer-sample-rate : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-buffer-sample-rate (unsafe-ffi-primitive 'js-audio-buffer-sample-rate))

;; js-audio-buffer-number-of-channels : ffi (extern) -> (u32)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-buffer-number-of-channels (unsafe-ffi-primitive 'js-audio-buffer-number-of-channels))

;; js-audio-buffer-get-channel-data : ffi (extern value) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-buffer-get-channel-data (unsafe-ffi-primitive 'js-audio-buffer-get-channel-data))

;; js-audio-gain-node-gain : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-gain-node-gain (unsafe-ffi-primitive 'js-audio-gain-node-gain))

;; js-audio-oscillator-node-type : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-oscillator-node-type (unsafe-ffi-primitive 'js-audio-oscillator-node-type))

;; js-audio-oscillator-node-set-type! : ffi (extern value) -> ()
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-oscillator-node-set-type! (unsafe-ffi-primitive 'js-audio-oscillator-node-set-type!))

;; js-audio-oscillator-node-frequency : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-oscillator-node-frequency (unsafe-ffi-primitive 'js-audio-oscillator-node-frequency))

;; js-audio-oscillator-node-detune : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-oscillator-node-detune (unsafe-ffi-primitive 'js-audio-oscillator-node-detune))

;; js-audio-oscillator-node-start! : ffi (extern value) -> ()
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-oscillator-node-start! (unsafe-ffi-primitive 'js-audio-oscillator-node-start!))

;; js-audio-oscillator-node-stop! : ffi (extern value) -> ()
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-oscillator-node-stop! (unsafe-ffi-primitive 'js-audio-oscillator-node-stop!))

;; js-audio-oscillator-node-set-periodic-wave! : ffi (extern value) -> ()
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-oscillator-node-set-periodic-wave! (unsafe-ffi-primitive 'js-audio-oscillator-node-set-periodic-wave!))

;; js-audio-audio-buffer-source-node-buffer : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-audio-buffer-source-node-buffer (unsafe-ffi-primitive 'js-audio-audio-buffer-source-node-buffer))

;; js-audio-audio-buffer-source-node-set-buffer! : ffi (extern value) -> ()
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-audio-buffer-source-node-set-buffer! (unsafe-ffi-primitive 'js-audio-audio-buffer-source-node-set-buffer!))

;; js-audio-audio-buffer-source-node-playback-rate : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-audio-buffer-source-node-playback-rate (unsafe-ffi-primitive 'js-audio-audio-buffer-source-node-playback-rate))

;; js-audio-audio-buffer-source-node-detune : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-audio-buffer-source-node-detune (unsafe-ffi-primitive 'js-audio-audio-buffer-source-node-detune))

;; js-audio-audio-buffer-source-node-loop : ffi (extern) -> (boolean)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-audio-buffer-source-node-loop (unsafe-ffi-primitive 'js-audio-audio-buffer-source-node-loop))

;; js-audio-audio-buffer-source-node-set-loop! : ffi (extern value) -> ()
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-audio-buffer-source-node-set-loop! (unsafe-ffi-primitive 'js-audio-audio-buffer-source-node-set-loop!))

;; js-audio-audio-buffer-source-node-loop-start : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-audio-buffer-source-node-loop-start (unsafe-ffi-primitive 'js-audio-audio-buffer-source-node-loop-start))

;; js-audio-audio-buffer-source-node-set-loop-start! : ffi (extern value) -> ()
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-audio-buffer-source-node-set-loop-start! (unsafe-ffi-primitive 'js-audio-audio-buffer-source-node-set-loop-start!))

;; js-audio-audio-buffer-source-node-loop-end : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-audio-buffer-source-node-loop-end (unsafe-ffi-primitive 'js-audio-audio-buffer-source-node-loop-end))

;; js-audio-audio-buffer-source-node-set-loop-end! : ffi (extern value) -> ()
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-audio-buffer-source-node-set-loop-end! (unsafe-ffi-primitive 'js-audio-audio-buffer-source-node-set-loop-end!))

;; js-audio-audio-buffer-source-node-start! : ffi (extern value value value) -> ()
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-audio-buffer-source-node-start! (unsafe-ffi-primitive 'js-audio-audio-buffer-source-node-start!))

;; js-audio-audio-buffer-source-node-stop! : ffi (extern value) -> ()
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-audio-buffer-source-node-stop! (unsafe-ffi-primitive 'js-audio-audio-buffer-source-node-stop!))

;; js-audio-analyser-node-fft-size : ffi (extern) -> (u32)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-analyser-node-fft-size (unsafe-ffi-primitive 'js-audio-analyser-node-fft-size))

;; js-audio-analyser-node-set-fft-size! : ffi (extern value) -> ()
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-analyser-node-set-fft-size! (unsafe-ffi-primitive 'js-audio-analyser-node-set-fft-size!))

;; js-audio-analyser-node-frequency-bin-count : ffi (extern) -> (u32)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-analyser-node-frequency-bin-count (unsafe-ffi-primitive 'js-audio-analyser-node-frequency-bin-count))

;; js-audio-analyser-node-min-decibels : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-analyser-node-min-decibels (unsafe-ffi-primitive 'js-audio-analyser-node-min-decibels))

;; js-audio-analyser-node-set-min-decibels! : ffi (extern value) -> ()
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-analyser-node-set-min-decibels! (unsafe-ffi-primitive 'js-audio-analyser-node-set-min-decibels!))

;; js-audio-analyser-node-max-decibels : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-analyser-node-max-decibels (unsafe-ffi-primitive 'js-audio-analyser-node-max-decibels))

;; js-audio-analyser-node-set-max-decibels! : ffi (extern value) -> ()
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-analyser-node-set-max-decibels! (unsafe-ffi-primitive 'js-audio-analyser-node-set-max-decibels!))

;; js-audio-analyser-node-smoothing-time-constant : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-analyser-node-smoothing-time-constant (unsafe-ffi-primitive 'js-audio-analyser-node-smoothing-time-constant))

;; js-audio-analyser-node-set-smoothing-time-constant! : ffi (extern value) -> ()
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-analyser-node-set-smoothing-time-constant! (unsafe-ffi-primitive 'js-audio-analyser-node-set-smoothing-time-constant!))

;; js-audio-analyser-node-get-byte-frequency-data! : ffi (extern value) -> ()
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-analyser-node-get-byte-frequency-data! (unsafe-ffi-primitive 'js-audio-analyser-node-get-byte-frequency-data!))

;; js-audio-analyser-node-get-byte-time-domain-data! : ffi (extern value) -> ()
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-analyser-node-get-byte-time-domain-data! (unsafe-ffi-primitive 'js-audio-analyser-node-get-byte-time-domain-data!))

;; js-audio-analyser-node-get-float-frequency-data! : ffi (extern value) -> ()
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-analyser-node-get-float-frequency-data! (unsafe-ffi-primitive 'js-audio-analyser-node-get-float-frequency-data!))

;; js-audio-analyser-node-get-float-time-domain-data! : ffi (extern value) -> ()
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-analyser-node-get-float-time-domain-data! (unsafe-ffi-primitive 'js-audio-analyser-node-get-float-time-domain-data!))

;; js-audio-biquad-filter-node-type : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-biquad-filter-node-type (unsafe-ffi-primitive 'js-audio-biquad-filter-node-type))

;; js-audio-biquad-filter-node-set-type! : ffi (extern value) -> ()
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-biquad-filter-node-set-type! (unsafe-ffi-primitive 'js-audio-biquad-filter-node-set-type!))

;; js-audio-biquad-filter-node-frequency : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-biquad-filter-node-frequency (unsafe-ffi-primitive 'js-audio-biquad-filter-node-frequency))

;; js-audio-biquad-filter-node-detune : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-biquad-filter-node-detune (unsafe-ffi-primitive 'js-audio-biquad-filter-node-detune))

;; js-audio-biquad-filter-node-q : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-biquad-filter-node-q (unsafe-ffi-primitive 'js-audio-biquad-filter-node-q))

;; js-audio-biquad-filter-node-gain : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-biquad-filter-node-gain (unsafe-ffi-primitive 'js-audio-biquad-filter-node-gain))

;; js-audio-constant-source-node-offset : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-constant-source-node-offset (unsafe-ffi-primitive 'js-audio-constant-source-node-offset))

;; js-audio-constant-source-node-start! : ffi (extern value) -> ()
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-constant-source-node-start! (unsafe-ffi-primitive 'js-audio-constant-source-node-start!))

;; js-audio-constant-source-node-stop! : ffi (extern value) -> ()
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-constant-source-node-stop! (unsafe-ffi-primitive 'js-audio-constant-source-node-stop!))

;; js-audio-dynamics-compressor-node-threshold : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-dynamics-compressor-node-threshold (unsafe-ffi-primitive 'js-audio-dynamics-compressor-node-threshold))

;; js-audio-dynamics-compressor-node-knee : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-dynamics-compressor-node-knee (unsafe-ffi-primitive 'js-audio-dynamics-compressor-node-knee))

;; js-audio-dynamics-compressor-node-ratio : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-dynamics-compressor-node-ratio (unsafe-ffi-primitive 'js-audio-dynamics-compressor-node-ratio))

;; js-audio-dynamics-compressor-node-reduction : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-dynamics-compressor-node-reduction (unsafe-ffi-primitive 'js-audio-dynamics-compressor-node-reduction))

;; js-audio-dynamics-compressor-node-attack : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-dynamics-compressor-node-attack (unsafe-ffi-primitive 'js-audio-dynamics-compressor-node-attack))

;; js-audio-dynamics-compressor-node-release : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-dynamics-compressor-node-release (unsafe-ffi-primitive 'js-audio-dynamics-compressor-node-release))

;; js-audio-panner-node-panning-model : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-panner-node-panning-model (unsafe-ffi-primitive 'js-audio-panner-node-panning-model))

;; js-audio-panner-node-set-panning-model! : ffi (extern value) -> ()
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-panner-node-set-panning-model! (unsafe-ffi-primitive 'js-audio-panner-node-set-panning-model!))

;; js-audio-panner-node-distance-model : ffi (extern) -> (string)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-panner-node-distance-model (unsafe-ffi-primitive 'js-audio-panner-node-distance-model))

;; js-audio-panner-node-set-distance-model! : ffi (extern value) -> ()
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-panner-node-set-distance-model! (unsafe-ffi-primitive 'js-audio-panner-node-set-distance-model!))

;; js-audio-panner-node-position-x : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-panner-node-position-x (unsafe-ffi-primitive 'js-audio-panner-node-position-x))

;; js-audio-panner-node-position-y : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-panner-node-position-y (unsafe-ffi-primitive 'js-audio-panner-node-position-y))

;; js-audio-panner-node-position-z : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-panner-node-position-z (unsafe-ffi-primitive 'js-audio-panner-node-position-z))

;; js-audio-panner-node-orientation-x : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-panner-node-orientation-x (unsafe-ffi-primitive 'js-audio-panner-node-orientation-x))

;; js-audio-panner-node-orientation-y : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-panner-node-orientation-y (unsafe-ffi-primitive 'js-audio-panner-node-orientation-y))

;; js-audio-panner-node-orientation-z : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-panner-node-orientation-z (unsafe-ffi-primitive 'js-audio-panner-node-orientation-z))

;; js-audio-panner-node-ref-distance : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-panner-node-ref-distance (unsafe-ffi-primitive 'js-audio-panner-node-ref-distance))

;; js-audio-panner-node-set-ref-distance! : ffi (extern value) -> ()
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-panner-node-set-ref-distance! (unsafe-ffi-primitive 'js-audio-panner-node-set-ref-distance!))

;; js-audio-panner-node-max-distance : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-panner-node-max-distance (unsafe-ffi-primitive 'js-audio-panner-node-max-distance))

;; js-audio-panner-node-set-max-distance! : ffi (extern value) -> ()
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-panner-node-set-max-distance! (unsafe-ffi-primitive 'js-audio-panner-node-set-max-distance!))

;; js-audio-panner-node-rolloff-factor : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-panner-node-rolloff-factor (unsafe-ffi-primitive 'js-audio-panner-node-rolloff-factor))

;; js-audio-panner-node-set-rolloff-factor! : ffi (extern value) -> ()
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-panner-node-set-rolloff-factor! (unsafe-ffi-primitive 'js-audio-panner-node-set-rolloff-factor!))

;; js-audio-panner-node-cone-inner-angle : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-panner-node-cone-inner-angle (unsafe-ffi-primitive 'js-audio-panner-node-cone-inner-angle))

;; js-audio-panner-node-set-cone-inner-angle! : ffi (extern value) -> ()
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-panner-node-set-cone-inner-angle! (unsafe-ffi-primitive 'js-audio-panner-node-set-cone-inner-angle!))

;; js-audio-panner-node-cone-outer-angle : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-panner-node-cone-outer-angle (unsafe-ffi-primitive 'js-audio-panner-node-cone-outer-angle))

;; js-audio-panner-node-set-cone-outer-angle! : ffi (extern value) -> ()
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-panner-node-set-cone-outer-angle! (unsafe-ffi-primitive 'js-audio-panner-node-set-cone-outer-angle!))

;; js-audio-panner-node-cone-outer-gain : ffi (extern) -> (f64)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-panner-node-cone-outer-gain (unsafe-ffi-primitive 'js-audio-panner-node-cone-outer-gain))

;; js-audio-panner-node-set-cone-outer-gain! : ffi (extern value) -> ()
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-panner-node-set-cone-outer-gain! (unsafe-ffi-primitive 'js-audio-panner-node-set-cone-outer-gain!))

;; js-audio-stereo-panner-node-pan : ffi (extern) -> (extern/raw)
;;   Raw binding generated for webracket/unsafe/audio.
(define js-audio-stereo-panner-node-pan (unsafe-ffi-primitive 'js-audio-stereo-panner-node-pan))

#lang webracket/base

(require geolocation)

(void
 geolocation
 geolocation?
 geolocation-supported?
 geolocation-raw
 make-geolocation-options
 geolocation-options?
 geolocation-options-enable-high-accuracy
 geolocation-options-timeout
 geolocation-options-maximum-age
 geolocation-get-current-position
 geolocation-watch-position
 geolocation-clear-watch!
 geolocation-position
 geolocation-position?
 geolocation-position-raw
 geolocation-position-coordinates
 geolocation-position-timestamp
 geolocation-coordinates
 geolocation-coordinates?
 geolocation-coordinates-raw
 geolocation-coordinates-latitude
 geolocation-coordinates-longitude
 geolocation-coordinates-accuracy
 geolocation-coordinates-altitude
 geolocation-coordinates-altitude-accuracy
 geolocation-coordinates-heading
 geolocation-coordinates-speed
 geolocation-position-error
 geolocation-position-error?
 geolocation-position-error-raw
 geolocation-position-error-code
 geolocation-position-error-message)

#t

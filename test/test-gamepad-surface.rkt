#lang webracket/base

(require gamepad)

(void
 gamepads
 gamepad?
 gamepad-raw
 gamepad-supported?
 gamepad-event-gamepad
 gamepad-id
 gamepad-index
 gamepad-connected?
 gamepad-timestamp
 gamepad-mapping
 gamepad-axes
 gamepad-buttons
 gamepad-button?
 gamepad-button-raw
 gamepad-button-pressed?
 gamepad-button-touched?
 gamepad-button-value
 gamepad-add-connected-listener!
 gamepad-remove-connected-listener!
 gamepad-add-disconnected-listener!
 gamepad-remove-disconnected-listener!)

#t

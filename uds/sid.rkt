#lang racket/base

;; Service identifiers (SID) of ISO 14229-1 and the sub-function byte.
;;
;; Every numeric value was cross-checked against the public python-udsoncan
;; implementation (MIT, pylessard/python-udsoncan, service files' `id` and
;; `_use_subfunction` attributes) against the ISO 14229-1 service table.

(require racket/contract)

(provide (contract-out
          (sid:diagnostic-session-control        (integer-in 0 255))
          (sid:ecu-reset                         (integer-in 0 255))
          (sid:clear-diagnostic-information      (integer-in 0 255))
          (sid:read-dtc-information              (integer-in 0 255))
          (sid:read-data-by-identifier           (integer-in 0 255))
          (sid:read-memory-by-address            (integer-in 0 255))
          (sid:read-scaling-data-by-identifier   (integer-in 0 255))
          (sid:security-access                   (integer-in 0 255))
          (sid:communication-control             (integer-in 0 255))
          (sid:read-data-by-periodic-identifier  (integer-in 0 255))
          (sid:dynamically-define-data-identifier (integer-in 0 255))
          (sid:define-data-by-identifier         (integer-in 0 255))
          (sid:write-data-by-identifier          (integer-in 0 255))
          (sid:input-output-control-by-identifier (integer-in 0 255))
          (sid:routine-control                   (integer-in 0 255))
          (sid:request-download                  (integer-in 0 255))
          (sid:request-upload                    (integer-in 0 255))
          (sid:transfer-data                     (integer-in 0 255))
          (sid:request-transfer-exit             (integer-in 0 255))
          (sid:request-file-transfer             (integer-in 0 255))
          (sid:write-memory-by-address           (integer-in 0 255))
          (sid:tester-present                    (integer-in 0 255))
          (sid:access-timing-parameter           (integer-in 0 255))
          (sid:secured-data-transmission         (integer-in 0 255))
          (sid:control-dtc-setting               (integer-in 0 255))
          (sid:response-on-event                 (integer-in 0 255))
          (sid:link-control                      (integer-in 0 255))
          (sid:authentication                    (integer-in 0 255))
          [positive-sid (-> (integer-in 0 255) (integer-in 0 255))]
          [response-sid->request-sid (-> (integer-in 0 255) (integer-in 0 255))]
          [service-name (-> (integer-in 0 255) (or/c symbol? #f))]
          [service-supported? (-> (integer-in 0 255) boolean?)]
          [service-uses-sub-function? (-> (integer-in 0 255) boolean?)]
          [make-sub-function-byte (-> (integer-in 0 127) boolean? (integer-in 0 255))]
          [parse-sub-function-byte (-> (integer-in 0 255) (values (integer-in 0 127) boolean?))]
          [suppress-bit-mask (integer-in 0 255)]))

(define sid:diagnostic-session-control         #x10)
(define sid:ecu-reset                          #x11)
(define sid:clear-diagnostic-information       #x14)
(define sid:read-dtc-information               #x19)
(define sid:read-data-by-identifier            #x22)
(define sid:read-memory-by-address             #x23)
(define sid:read-scaling-data-by-identifier    #x24)
(define sid:security-access                    #x27)
(define sid:authentication                     #x29)
(define sid:communication-control              #x28)
(define sid:read-data-by-periodic-identifier   #x2A)
(define sid:dynamically-define-data-identifier #x2C)
;; 0x2D is not implemented by python-udsoncan; value per ISO 14229-1.
(define sid:define-data-by-identifier          #x2D)
(define sid:write-data-by-identifier           #x2E)
(define sid:input-output-control-by-identifier #x2F)
(define sid:routine-control                    #x31)
(define sid:request-download                   #x34)
(define sid:request-upload                     #x35)
(define sid:transfer-data                      #x36)
(define sid:request-transfer-exit              #x37)
(define sid:request-file-transfer              #x38)
(define sid:write-memory-by-address            #x3D)
(define sid:tester-present                     #x3E)
(define sid:access-timing-parameter            #x83)
(define sid:secured-data-transmission          #x84)
(define sid:control-dtc-setting                #x85)
(define sid:response-on-event                  #x86)
(define sid:link-control                       #x87)

;; SID | 0x40 is the positive-response marker; the high bit doubles as the
;; suppressPosRspMsgIndicationBit in *request* sub-function bytes.
(define suppress-bit-mask #x80)

(define (positive-sid sid) (bitwise-ior sid #x40))
(define (response-sid->request-sid sid) (bitwise-and sid #xBF))

;; sid → symbol, for diagnostics and error messages.
(define +service-names+
  (hasheq sid:diagnostic-session-control 'diagnostic-session-control
          sid:ecu-reset 'ecu-reset
          sid:clear-diagnostic-information 'clear-diagnostic-information
          sid:read-dtc-information 'read-dtc-information
          sid:read-data-by-identifier 'read-data-by-identifier
          sid:read-memory-by-address 'read-memory-by-address
          sid:read-scaling-data-by-identifier 'read-scaling-data-by-identifier
          sid:security-access 'security-access
          sid:authentication 'authentication
          sid:communication-control 'communication-control
          sid:read-data-by-periodic-identifier 'read-data-by-periodic-identifier
          sid:dynamically-define-data-identifier 'dynamically-define-data-identifier
          sid:define-data-by-identifier 'define-data-by-identifier
          sid:write-data-by-identifier 'write-data-by-identifier
          sid:input-output-control-by-identifier 'input-output-control-by-identifier
          sid:routine-control 'routine-control
          sid:request-download 'request-download
          sid:request-upload 'request-upload
          sid:transfer-data 'transfer-data
          sid:request-transfer-exit 'request-transfer-exit
          sid:request-file-transfer 'request-file-transfer
          sid:write-memory-by-address 'write-memory-by-address
          sid:tester-present 'tester-present
          sid:access-timing-parameter 'access-timing-parameter
          sid:secured-data-transmission 'secured-data-transmission
          sid:control-dtc-setting 'control-dtc-setting
          sid:response-on-event 'response-on-event
          sid:link-control 'link-control))

(define (service-name sid) (hash-ref +service-names+ sid #f))
(define (service-supported? sid) (hash-has-key? +service-names+ sid))

;; Services whose byte 1 is a sub-function (cross-checked against
;; python-udsoncan `_use_subfunction` on every service).
(define +sub-function-services+
  (list sid:diagnostic-session-control
        sid:ecu-reset
        sid:read-dtc-information
        sid:security-access
        sid:communication-control
        sid:read-data-by-periodic-identifier
        sid:dynamically-define-data-identifier
        sid:routine-control
        sid:tester-present
        sid:access-timing-parameter
        sid:secured-data-transmission
        sid:control-dtc-setting
        sid:response-on-event
        sid:link-control))

(define (service-uses-sub-function? sid)
  (and (memv sid +sub-function-services+) #t))

;; The request's sub-function byte: bits 0-6 carry the sub-function, bit 7
;; is suppressPosRspMsgIndicationBit.
(define (make-sub-function-byte sub suppress?)
  (bitwise-ior sub (if suppress? suppress-bit-mask 0)))

(define (parse-sub-function-byte b)
  (values (bitwise-and b #x7F) (not (zero? (bitwise-and b suppress-bit-mask)))))

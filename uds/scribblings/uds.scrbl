#lang scribble/doc

@(require scribble/manual
          (for-label uds
                     racket/base
                     racket/contract))

@title{uds: ISO 14229 (Unified Diagnostic Services) in pure Racket}
@author{@(author+email "turinglambdaai" "turinglambdaai@users.noreply.github.com")}

@defmodule[uds]

This package implements the @emph{message layer} of
@hyperlink["https://www.iso.org/standard/76443.html"]{ISO 14229-1} —
@deftech{UDS} (Unified Diagnostic Services), the application protocol spoken
by automotive ECUs over ISO-TP (@hyperlink["https://pkgs.racket-lang.org/package/isotp"]{@tt{isotp}}) or DoIP.  It covers
service identifiers, negative response codes, diagnostic trouble codes, and
request/response construction and parsing.

The library is @emph{transport-agnostic and pure}: builders return the
payload bytes of one ISO-TP message and parsers consume them; timing,
transport and security-algorithm concerns stay with the caller.  There is no
FFI and no system dependency.

@section{Quick start}

@racketblock[
(require uds)

;; Ask for the extended diagnostic session:
(diagnostic-session-control 'extended)          ; => #"\20\3"

;; Read the VIN (DID 0xF190):
(read-data-by-identifier '(#xF190))             ; => #"\42\361\220"

;; A response arrives as ISO-TP payload bytes:
(response-parse #"\120\3\000\062\000\310")      ; => positive 0x50, sub 3
(define parsed (response-parse #"\\120\\3\\000\\062\\000\\310"))
(define record
  (bytes-append (bytes (positive-response-sub-function parsed))
                (positive-response-data parsed)))
(define-values (session p2-ms p2-star-ms) (session-control-response record))
(list session p2-ms p2-star-ms)
;; => 3, 50, 2000   (session, P2 ms, P2* ms)
]

@section{Service identifiers}

The @racket[sid:*] bindings name every ISO 14229-1 service
(@racket[sid:diagnostic-session-control], @racket[sid:read-data-by-identifier],
…).  @racket[service-name] maps an ID back to a symbol, and
@racket[service-uses-sub-function?] tells whether the service's second byte
is a sub-function — the distinction that drives generic framing.

The full service-identifier table, as exported constants:

@defthing[sid:diagnostic-session-control (integer-in 0 255)]{}
@defthing[sid:ecu-reset (integer-in 0 255)]{}
@defthing[sid:clear-diagnostic-information (integer-in 0 255)]{}
@defthing[sid:read-dtc-information (integer-in 0 255)]{}
@defthing[sid:read-data-by-identifier (integer-in 0 255)]{}
@defthing[sid:read-memory-by-address (integer-in 0 255)]{}
@defthing[sid:read-scaling-data-by-identifier (integer-in 0 255)]{}
@defthing[sid:security-access (integer-in 0 255)]{}
@defthing[sid:authentication (integer-in 0 255)]{}
@defthing[sid:communication-control (integer-in 0 255)]{}
@defthing[sid:read-data-by-periodic-identifier (integer-in 0 255)]{}
@defthing[sid:dynamically-define-data-identifier (integer-in 0 255)]{}
@defthing[sid:define-data-by-identifier (integer-in 0 255)]{}
@defthing[sid:write-data-by-identifier (integer-in 0 255)]{}
@defthing[sid:input-output-control-by-identifier (integer-in 0 255)]{}
@defthing[sid:routine-control (integer-in 0 255)]{}
@defthing[sid:request-download (integer-in 0 255)]{}
@defthing[sid:request-upload (integer-in 0 255)]{}
@defthing[sid:transfer-data (integer-in 0 255)]{}
@defthing[sid:request-transfer-exit (integer-in 0 255)]{}
@defthing[sid:request-file-transfer (integer-in 0 255)]{}
@defthing[sid:write-memory-by-address (integer-in 0 255)]{}
@defthing[sid:tester-present (integer-in 0 255)]{}
@defthing[sid:access-timing-parameter (integer-in 0 255)]{}
@defthing[sid:secured-data-transmission (integer-in 0 255)]{}
@defthing[sid:control-dtc-setting (integer-in 0 255)]{}
@defthing[sid:response-on-event (integer-in 0 255)]{}
@defthing[sid:link-control (integer-in 0 255)]{}

@defproc[(service-name [sid (integer-in 0 255)]) (or/c symbol? #f)]{
 The ISO name of the service as a symbol (e.g. @racket['read-data-by-identifier]),
 or @racket[#f] for codes outside the table.}

@defproc[(service-uses-sub-function? [sid (integer-in 0 255)]) boolean?]{
 Does this service carry a sub-function byte?  The distinction that drives
 the generic framing in @racket[make-request] and @racket[request-parse].}

@defproc[(positive-sid [sid (integer-in 0 255)]) (integer-in 0 255)]{
The positive-response marker: @racket[sid] | @racket[#x40].
}

@defproc[(response-sid->request-sid [sid (integer-in 0 255)]) (integer-in 0 255)]{
Inverse of @racket[positive-sid] (clears the marker bit).
}

@defproc[(make-sub-function-byte [sub (integer-in 0 127)] [suppress? boolean?])
         (integer-in 0 255)]{
@defproc[(parse-sub-function-byte [b (integer-in 0 255)])
         (values (integer-in 0 127) boolean?)]{
Encode/decode the sub-function byte: bits 0–6 carry the sub-function, bit 7
is @tt{suppressPosRspMsgIndicationBit}.
}}

@section{Negative response codes}

Negative responses are framed as @tt{7F <echoed SID> <NRC>}.

@defstruct*[negative-response ([sid (integer-in 0 255)]
                               [nrc (integer-in 0 255)])]{
The parsed negative response.  @racket[negative-response-parse] and
@racket[negative-response-bytes] convert to and from wire bytes;
@racket[nrc-name] maps a code to a symbol
(@racket[nrc:request-out-of-range], @racket[nrc:security-access-denied],
…); @racket[response-pending?] recognizes the
@tt{requestCorrectlyReceived-ResponsePending} code (0x78) that tells the
tester to keep waiting.
}

@defproc[(negative-response-parse [payload bytes?]) negative-response?]{
 Parses a @tt{7F <SID> <NRC>} payload; raises on anything else.}

@defproc[(negative-response-bytes [sid (integer-in 0 255)] [nrc (integer-in 0 255)]) bytes?]{
 Builds the negative-response payload.}

@defproc[(nrc-name [nrc (integer-in 0 255)]) (or/c symbol? #f)]{
 The ISO name of the negative response code as a symbol (SDF naming:
 @racket['requestOutOfRange], @racket['securityAccessDenied], ...), or
 @racket[#f] when the code is not in the table.}

@defproc[(response-pending? [payload bytes?]) boolean?]{
 Recognizes the @tt{requestCorrectlyReceived-ResponsePending} negative
 response (NRC 0x78) that tells the tester to keep waiting.}

The exported NRC constants:

@defthing[nrc:general-reject (integer-in 0 255)]{}
@defthing[nrc:service-not-supported (integer-in 0 255)]{}
@defthing[nrc:sub-function-not-supported (integer-in 0 255)]{}
@defthing[nrc:incorrect-message-length-or-invalid-format (integer-in 0 255)]{}
@defthing[nrc:response-too-long (integer-in 0 255)]{}
@defthing[nrc:busy-repeat-request (integer-in 0 255)]{}
@defthing[nrc:conditions-not-correct (integer-in 0 255)]{}
@defthing[nrc:request-sequence-error (integer-in 0 255)]{}
@defthing[nrc:no-response-from-subnet-component (integer-in 0 255)]{}
@defthing[nrc:failure-prevents-execution-of-requested-action (integer-in 0 255)]{}
@defthing[nrc:request-out-of-range (integer-in 0 255)]{}
@defthing[nrc:security-access-denied (integer-in 0 255)]{}
@defthing[nrc:authentication-required (integer-in 0 255)]{}
@defthing[nrc:invalid-key (integer-in 0 255)]{}
@defthing[nrc:exceed-number-of-attempts (integer-in 0 255)]{}
@defthing[nrc:required-time-delay-not-expired (integer-in 0 255)]{}
@defthing[nrc:secure-data-transmission-required (integer-in 0 255)]{}
@defthing[nrc:secure-data-transmission-not-allowed (integer-in 0 255)]{}
@defthing[nrc:secure-data-verification-failed (integer-in 0 255)]{}
@defthing[nrc:ownership-verification-failed (integer-in 0 255)]{}
@defthing[nrc:challenge-calculation-failed (integer-in 0 255)]{}
@defthing[nrc:setting-access-rights-failed (integer-in 0 255)]{}
@defthing[nrc:session-key-creation-derivation-failed (integer-in 0 255)]{}
@defthing[nrc:configuration-data-usage-failed (integer-in 0 255)]{}
@defthing[nrc:de-authentication-failed (integer-in 0 255)]{}
@defthing[nrc:upload-download-not-accepted (integer-in 0 255)]{}
@defthing[nrc:transfer-data-suspended (integer-in 0 255)]{}
@defthing[nrc:general-programming-failure (integer-in 0 255)]{}
@defthing[nrc:wrong-block-sequence-counter (integer-in 0 255)]{}
@defthing[nrc:request-correctly-received-response-pending (integer-in 0 255)]{}
@defthing[nrc:sub-function-not-supported-in-active-session (integer-in 0 255)]{}
@defthing[nrc:service-not-supported-in-active-session (integer-in 0 255)]{}
@defthing[nrc:rpm-too-high (integer-in 0 255)]{}
@defthing[nrc:rpm-too-low (integer-in 0 255)]{}
@defthing[nrc:engine-is-running (integer-in 0 255)]{}
@defthing[nrc:engine-is-not-running (integer-in 0 255)]{}
@defthing[nrc:engine-run-time-too-low (integer-in 0 255)]{}
@defthing[nrc:temperature-too-high (integer-in 0 255)]{}
@defthing[nrc:temperature-too-low (integer-in 0 255)]{}
@defthing[nrc:vehicle-speed-too-high (integer-in 0 255)]{}
@defthing[nrc:vehicle-speed-too-low (integer-in 0 255)]{}
@defthing[nrc:throttle-pedal-too-high (integer-in 0 255)]{}
@defthing[nrc:throttle-pedal-too-low (integer-in 0 255)]{}
@defthing[nrc:transmission-range-not-in-neutral (integer-in 0 255)]{}
@defthing[nrc:transmission-range-not-in-gear (integer-in 0 255)]{}
@defthing[nrc:brake-switch-not-closed (integer-in 0 255)]{}
@defthing[nrc:shifter-lever-not-in-park (integer-in 0 255)]{}
@defthing[nrc:torque-converter-clutch-locked (integer-in 0 255)]{}
@defthing[nrc:voltage-too-high (integer-in 0 255)]{}
@defthing[nrc:voltage-too-low (integer-in 0 255)]{}
@defthing[nrc:resource-temporarily-not-available (integer-in 0 255)]{}

@section{Diagnostic trouble codes}

@defstruct*[dtc ((number (integer-in 0 65535))
                 (status-byte (integer-in 0 255)))]{
One trouble code: a 16-bit number and a status byte.  The number's text
form (@tt{"P0123"}) maps through @racket[dtc-text->number] /
@racket[dtc-number->text]: bits 15–14 encode the system letter
(P/C/B/U), bits 13–12 the first digit, and the remaining three digits
occupy one BCD nibble each.  @racket[parse-dtc-records] reads the 3-byte
record runs of ReadDTCInformation responses.
}

@defstruct*[dtc-status ([test-failed boolean?]
                        [test-failed-this-operation-cycle boolean?]
                        [pending boolean?]
                        [confirmed boolean?]
                        [test-not-completed-since-last-clear boolean?]
                        [test-failed-since-last-clear boolean?]
                        [test-not-completed-this-operation-cycle boolean?]
                        [warning-indicator-requested boolean?])]{
The status byte (ISO 14229-1 Annex D) as flags; @racket[make-dtc-status],
@racket[dtc-status->byte] and @racket[byte->dtc-status] convert.
@racket[+dtc-group-all+] (0xFFFFFF) is the "all DTCs" group for
ClearDiagnosticInformation.
}

@defproc[(dtc-text->number [s string?]) (integer-in 0 65535)]{
 Parses the three-letter text form (@tt{"P0123"}) into the 16-bit number.}

@defproc[(dtc-number->text [n (integer-in 0 65535)]) string?]{
 Renders the 16-bit number as the three-letter text form.}

@defproc[(parse-dtc-records [payload bytes?]) (listof dtc?)]{
 Reads the run of 3-byte @tt{[number_hi number_lo status]} records that
 ReadDTCInformation responses carry.}

@defproc[(make-dtc-status
          [#:test-failed test-failed boolean? #f]
          [#:test-failed-this-operation-cycle test-failed-this-operation-cycle boolean? #f]
          [#:pending pending boolean? #f]
          [#:confirmed confirmed boolean? #f]
          [#:test-not-completed-since-last-clear test-not-completed-since-last-clear boolean? #f]
          [#:test-failed-since-last-clear test-failed-since-last-clear boolean? #f]
          [#:test-not-completed-this-operation-cycle test-not-completed-this-operation-cycle boolean? #f]
          [#:warning-indicator-requested warning-indicator-requested boolean? #f])
         dtc-status?]{
 Builds a status byte by keyword; unset flags default to @racket[#f].}

@defproc[(dtc-status->byte [s dtc-status?]) (integer-in 0 255)]{
 Packs the flags into the wire byte.}

@defproc[(byte->dtc-status [b (integer-in 0 255)]) dtc-status?]{
 Unpacks the wire byte into flags.}

@defthing[+dtc-group-all+ (integer-in 0 16777215)]{
 The 0xFFFFFF ``all DTCs'' group for @racket[clear-diagnostic-information].}

@section{Requests}

@defstruct*[request ([sid (integer-in 0 255)]
                     [sub-function (or/c #f (integer-in 0 127))]
                     [suppress? boolean?]
                     [data bytes?])]{
A parsed request: @racket[request-parse] decodes any payload, resolving the
sub-function/suppress-bit split for sub-function services.
}

@defproc[(request-parse [payload bytes?]) request?]{
 Decodes any request payload, resolving the sub-function/suppress-bit
 split for sub-function services.}

@defproc[(make-request [sid (integer-in 0 255)]
                       [#:sub-function sub (or/c #f (integer-in 0 127)) #f]
                       [#:suppress? suppress? boolean? #f]
                       [#:data data bytes? #""])
         bytes?]{
Generic request framing; raises when the service does not use sub-functions
but one (or the suppress bit) is requested.  The typed builders below are
preferred.
}

@defproc[(diagnostic-session-control [type (or/c 'default 'programming 'extended (integer-in 0 127))]
                                     [#:suppress? suppress? boolean? #f]) bytes?]{
@defproc[(ecu-reset [type (or/c 'hard 'key-off-on 'soft (integer-in 0 127))]
                    [#:suppress? suppress? boolean? #f]) bytes?]{
@defproc[(tester-present [#:suppress? suppress? boolean? #f]) bytes?]{
@defproc[(control-dtc-setting [mode (or/c 'on 'off (integer-in 0 127))]
                              [#:suppress? suppress? boolean? #f]
                              [#:data data bytes? #""]) bytes?]{
@defproc[(clear-diagnostic-information [group (integer-in 0 16777215)]) bytes?]{
Typed builders for the session-management services.
}}}}
}

@defproc[(read-dtc-by-status-mask [mask (integer-in 0 255)]) bytes?]{
@defproc[(report-number-of-dtc-by-status-mask [mask (integer-in 0 255)]) bytes?]{
@defproc[(report-supported-dtc [#:suppress? suppress? boolean? #f]) bytes?]{
ReadDTCInformation builders for the three most used sub-functions.
}}}

@defproc[(security-access-request-seed [level (integer-in 0 63)]) bytes?]{
@defproc[(security-access-send-key [level (integer-in 0 63)] [key bytes?]) bytes?]{
SecurityAccess framing.  Levels pair up: odd levels request a seed, the
following even level sends the key; the builders enforce the parity.
}
}

@defproc[(read-data-by-identifier [dids (listof (integer-in 0 65535))]) bytes?]{
@defproc[(write-data-by-identifier [did (integer-in 0 65535)] [data bytes?]) bytes?]{
@defproc[(input-output-control-by-identifier [did (integer-in 0 65535)] [data bytes?]) bytes?]{
Data-identifier services; DIDs are 16-bit big-endian.
}}}

@defproc[(routine-control [action (or/c 'start 'stop 'request-results (integer-in 0 127))]
                          [routine-id (integer-in 0 65535)]
                          [#:record record bytes? #""]
                          [#:suppress? suppress? boolean? #f]) bytes?]{}

@defproc[(read-memory-by-address [address integer?] [address-bytes (integer-in 1 15)]
                                 [size integer?] [size-bytes (integer-in 1 15)]) bytes?]{
@defproc[(write-memory-by-address [address integer?] [address-bytes (integer-in 1 15)]
                                  [data bytes?]) bytes?]{
@defproc[(request-download [data-format-id (integer-in 0 255)]
                           [address integer?] [address-bytes (integer-in 1 15)]
                           [size integer?] [size-bytes (integer-in 1 15)]) bytes?]{
@defproc[(transfer-data [counter (integer-in 0 255)] [#:data data bytes? #""]) bytes?]{
@defproc[(request-transfer-exit [#:data data bytes? #""]) bytes?]{
Memory and transfer services.  The
@tt{addressAndLengthFormatIdentifier} (high nibble: address byte count, low
nibble: size byte count) is built by @racket[encode-address-and-length] and
read back by @racket[decode-address-and-length].

@defproc[(encode-address-and-length [address integer?] [address-bytes (integer-in 1 15)]
                                    [size integer?] [size-bytes (integer-in 1 15)]) bytes?]{
 Builds the @tt{addressAndLengthFormatIdentifier} followed by the big-endian
 address and size.}

@defproc[(decode-address-and-length [payload bytes?])
         (values integer? integer?)]{
 Inverse of @racket[encode-address-and-length]: returns the address and
 the size.}
}}}}
}

@section{Responses}

@defproc[(response-parse [payload bytes?])
         (or/c positive-response? negative-response?)]{
Classifies one response payload: bytes starting with @tt{7F} become a
@racket[negative-response]; everything else must be a positive response
(@tt{SID | 0x40}) and is split into echoed sub-function (for sub-function
services) and the response record.
}

@defstruct*[positive-response ([sid (integer-in 0 255)]
                               [sub-function (or/c #f (integer-in 0 127))]
                               [data bytes?])]{
A parsed positive response; @racket[sid] is the request service ID.
}

Record decoders for common positive responses. Most take the
@racket[positive-response]-data byte string; for services with echoed
sub-functions, @racket[session-control-response] and
@racket[security-seed-response] expect the sub-function byte prepended to
that data (the parsed structure stores it separately).
Length mismatches raise an exception.

@defproc[(session-control-response [data bytes?])
         (values (integer-in 0 255) exact-nonnegative-integer? exact-nonnegative-integer?)]{
 DiagnosticSessionControl: input must contain the echoed session
 sub-function byte followed by P2 (two bytes) and P2* (two bytes).
 The parser stores the echoed sub-function in
 @racket[positive-response-sub-function] separately from
 @racket[positive-response-data]. The returned three values are session
 type, P2 milliseconds and P2* milliseconds (wire P2* units are 10 ms).
 A record shorter than five bytes raises an exception.}

@defproc[(security-seed-response [data bytes?]) bytes?]{
 SecurityAccess @tt{requestSeed}: the seed bytes.}

@defproc[(max-block-length-response [data bytes?]) exact-nonnegative-integer?]{
 RequestDownload/RequestUpload: @tt{maxNumberOfBlockLength}.}

@defproc[(number-of-dtc-response [data bytes?])
         (values (integer-in 0 255) exact-nonnegative-integer?)]{
 ReadDTCInformation @tt{reportNumberOfDTCByStatusMask}: DTC format
 identifier and the 24-bit DTC count.}

@defproc[(dtc-list-response [data bytes?]) (listof dtc?)]{
 ReadDTCInformation @tt{reportDTCByStatusMask} /
 @tt{reportSupportedDTC}: the DTC records as @racket[dtc?] values.}

@defproc[(transfer-data-response [data bytes?])
         (values (integer-in 0 255) bytes?)]{
 TransferData: the echoed block sequence counter and the response
 record.}

@section{Caveats}

@itemlist[
 @item{Authentication (SID 0x29) framing is included in the service table
  but no typed builder yet; use @racket[make-request].}
 @item{Security algorithms (seed/key) are ECU-specific by design and stay
  with the caller.}
 @item{The library does not manage sessions, timing (P2/P2*) or
  retransmission; pair it with @hyperlink["https://pkgs.racket-lang.org/package/isotp"]{@tt{isotp}} for the transport layer.}
]

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
(session-control-response (positive-response-data (response-parse #"\120\3\000\062\000\310")))
;; => 3, 50, 2000   (session, P2 ms, P2* ms)
]

@section{Service identifiers}

The @racket[sid:*] bindings name every ISO 14229-1 service
(@racket[sid:diagnostic-session-control], @racket[sid:read-data-by-identifier],
…).  @racket[service-name] maps an ID back to a symbol, and
@racket[service-uses-sub-function?] tells whether the service's second byte
is a sub-function — the distinction that drives generic framing.

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

@section{Requests}

@defstruct*[request ([sid (integer-in 0 255)]
                     [sub-function (or/c #f (integer-in 0 127))]
                     [suppress? boolean?]
                     [data bytes?])]{
A parsed request: @racket[request-parse] decodes any payload, resolving the
sub-function/suppress-bit split for sub-function services.
}

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

Record decoders for the common positive responses:

@itemlist[
 @item{@racket[session-control-response] — session type, P2 (ms) and P2*
  (ms; wire value × 10).}
 @item{@racket[security-seed-response] — the seed bytes.}
 @item{@racket[max-block-length-response] — maxNumberOfBlockLength.}
 @item{@racket[number-of-dtc-response] — format identifier and DTC count.}
 @item{@racket[dtc-list-response] — the DTC records as @racket[dtc?] values.}
 @item{@racket[transfer-data-response] — echoed block counter and record.}
]

@section{Caveats}

@itemlist[
 @item{Authentication (SID 0x29) framing is included in the service table
  but no typed builder yet; use @racket[make-request].}
 @item{Security algorithms (seed/key) are ECU-specific by design and stay
  with the caller.}
 @item{The library does not manage sessions, timing (P2/P2*) or
  retransmission; pair it with @hyperlink["https://pkgs.racket-lang.org/package/isotp"]{@tt{isotp}} for the transport layer.}
]

(impl-trait .xcall-impl-trait.xcall-impl-trait)
(use-trait xcall-common-trait .xcall-common-trait.xcall-common-trait)
(use-trait xcall-receiver-trait .xcall-receiver-trait.xcall-receiver-trait)

(define-constant ERR_INVALID_NETWORK_ADDRESS (err u200))
(define-constant ERR_INVALID_NETWORK_ID (err u201))
(define-constant ERR_INVALID_ACCOUNT (err u202))
(define-constant ERR_MESSAGE_NOT_FOUND (err u203))
(define-constant ERR_NOT_ADMIN (err u204))
(define-constant ERR_ALREADY_INITIALIZED (err u205))
(define-constant ERR_NOT_INITIALIZED (err u206))
(define-constant ERR_INVALID_MESSAGE_TYPE (err u207))
(define-constant ERR_INVALID_RESPONSE (err u208))
(define-constant ERR_NO_ROLLBACK_DATA (err u209))
(define-constant ERR_INVALID_REPLY (err u210))
(define-constant ERR_NO_DEFAULT_CONNECTION (err u211))
(define-constant ERR_UNVERIFIED_PROTOCOL (err u212))
(define-constant ERR_INVALID_MESSAGE (err u213))
(define-constant ERR_INVALID_RECEIVER (err u214))
(define-constant ERR_ADDRESS_TO_PRINCIPAL_FAILED (err u215))

(define-constant CS_MESSAGE_RESULT_FAILURE u0)
(define-constant CS_MESSAGE_RESULT_SUCCESS u1)
(define-constant CS_MESSAGE_TYPE_REQUEST u1)
(define-constant CS_MESSAGE_TYPE_RESULT u2)

(define-data-var admin principal tx-sender)
(define-data-var protocol-fee uint u0)
(define-data-var protocol-fee-handler principal tx-sender)
(define-data-var current-network-id (string-ascii 128) "")
(define-data-var current-rollback bool false)
(define-data-var sn-counter uint u0)
(define-data-var req-id-counter uint u0)
(define-data-var reply-state
  (optional {
    from-nid: (string-ascii 128),
    protocols: (list 10 (string-ascii 128))
  })
  none
)
(define-data-var call-reply (optional (buff 2048)) none)
(define-data-var network-id (optional (string-ascii 128)) none)
(define-data-var contract-address (optional (string-ascii 128)) none)

(define-map default-connections 
  { nid: (string-ascii 128) } 
  { address: (string-ascii 128) }
)

(define-map trusted-protocols
  { nid: (string-ascii 128) }
  { protocols: (list 10 (string-ascii 128)) }
)

(define-map pending-messages 
  { msg-hash: (buff 32), protocol: principal }
  { confirmed: bool }
)

(define-map outgoing-messages 
  { sn: uint }
  {
    to: (string-ascii 128),
    data: (buff 2048),
    rollback: (optional (buff 1024)),
    sources: (optional (list 10 (string-ascii 128))),
    destinations: (optional (list 10 (string-ascii 128))),
  }
)

(define-map incoming-messages
  { req-id: uint }
  {
    from: (string-ascii 128),
    to: (string-ascii 128),
    sn: uint,
    type: uint,
    data-hash: (buff 32),
    protocols: (list 10 (string-ascii 128))
  }
)

(define-map successful-responses
  { sn: uint }
  { value: bool }
)

(define-public (init (nid (string-ascii 128)) (addr (string-ascii 128)))
  (begin
    (asserts! (is-none (var-get network-id)) ERR_ALREADY_INITIALIZED)
    (asserts! (is-eq (var-get admin) tx-sender) ERR_NOT_ADMIN)
    
    (var-set network-id (some nid))
    (var-set contract-address (some addr))
    
    (ok true)
  )
)

(define-read-only (get-network-id)
  (match (var-get network-id)
    some-network-id (ok some-network-id)
    ERR_NOT_INITIALIZED
  )
)

(define-read-only (get-network-address)
  (match (var-get network-id)
    some-network-id
      (match (var-get contract-address)
        some-network-addr 
          (ok (unwrap! 
            (as-max-len? (concat (concat some-network-id "/") some-network-addr) u128)
            ERR_INVALID_NETWORK_ADDRESS))
        ERR_NOT_INITIALIZED
      )
    ERR_NOT_INITIALIZED
  )
)

(define-read-only (get-outgoing-message (sn uint))
  (map-get? outgoing-messages { sn: sn })
)

(define-read-only (is-reply (network-id-in (string-ascii 128)) (sources (optional (list 10 (string-ascii 128)))))
  (match (var-get reply-state)
    state (and 
            (is-eq (get from-nid state) network-id-in)
            (is-eq (get protocols state) (default-to (list) sources)))
    false)
)

(define-private (is-admin)
  (is-eq (var-get admin) tx-sender)
)

(define-private (get-next-sn)
  (let 
    ((current-sn (var-get sn-counter)))
    (var-set sn-counter (+ current-sn u1))
    (ok (+ current-sn u1))
  )
)

(define-private (get-next-req-id)
  (let (
    (current-id (var-get req-id-counter))
  )
    (var-set req-id-counter (+ current-id u1))
    (ok (+ current-id u1))
  )
)

(define-private (validate-network-address (address (string-ascii 257)))
  (match (index-of? address "/")
    index 
      (let 
        (
          (network-id-in (slice? address u0 index))
          (account (slice? address (+ index u1) (len address)))
        )
        (and 
          (is-some network-id-in)
          (is-some account)
          (> (len (unwrap! network-id-in false)) u0)
          (> (len (unwrap! account false)) u0)
        )
      )
    false
  )
)

(define-private (parse-network-address (address (string-ascii 257)))
  (if (validate-network-address address)
    (match (index-of? address "/")
      index 
        (let 
          (
            (network-id-in (unwrap-panic (as-max-len? (unwrap-panic (slice? address u0 index)) u128)))
            (account (unwrap-panic (slice? address (+ index u1) (len address))))
          )
          (ok {network-id: network-id-in, account: account})
        )
      ERR_INVALID_NETWORK_ADDRESS
    )
    ERR_INVALID_NETWORK_ADDRESS
  )
)

(define-public (set-trusted-protocols (nid (string-ascii 128)) (protocols (list 10 (string-ascii 128))))
  (begin
    (asserts! (is-admin) ERR_NOT_ADMIN)
    (ok (map-set trusted-protocols { nid: nid } { protocols: protocols }))
  )
)

(define-private (emit-call-message-received-event (from (string-ascii 128)) (to (string-ascii 128)) (sn uint) (req-id uint) (data (buff 2048)))
  (print
    {
      event: "CallMessage",
      from: from,
      to: to,
      sn: sn,
      req-id: req-id,
      data: data,
    }
  )
)

(define-private (emit-call-executed-event (req-id uint) (code uint) (message (string-ascii 128)))
  (print
    {
      event: "CallExecuted",
      req-id: req-id,
      code: code,
      msg: message
    }
  )
)

(define-private (emit-call-message-sent-event (from principal) (to (string-ascii 128)) (sn uint) (data (buff 2048)) (sources (optional (list 10 (string-ascii 128)))) (destinations (optional (list 10 (string-ascii 128)))))
  (print
    {
      event: "CallMessageSent",
      from: tx-sender,
      to: to,
      sn: sn,
      data: data,
      sources: (default-to (list) sources),
      destinations: (default-to (list) destinations)
    }
  )
)


(define-private (emit-response-message-event (sn uint) (code uint))
  (print 
    {
      event: "ResponseMessage",
      sn: sn,
      code: code
    }
  )
)

(define-private (emit-rollback-message-received-event (sn uint))
  (print 
    {
      event: "RollbackMessage",
      sn: sn,
    }
  )
)

(define-private (emit-rollback-executed-event (sn uint))
  (print 
    {
      event: "RollbackExecuted",
      sn: sn
    }
  )
)

(define-read-only (get-default-connection (nid (string-ascii 128)))
  (match (map-get? default-connections { nid: nid })
    connection (ok (some connection))
    ERR_NO_DEFAULT_CONNECTION)
)

(define-public (send-call 
  (to (string-ascii 128)) 
  (data (buff 2048))
)
  (begin
    (send-call-message to data none none none)
  )
)

(define-private (encode-protocol-string (protocol (string-ascii 128)))
  (contract-call? .rlp-encode encode-string protocol))

(define-public (send-call-message 
  (to (string-ascii 128))
  (data (buff 2048))
  (rollback (optional (buff 1024)))
  (sources (optional (list 10 (string-ascii 128))))
  (destinations (optional (list 10 (string-ascii 128))))
)
  (let
    (
      (fee (var-get protocol-fee))
      (fee-to (var-get protocol-fee-handler))
      (next-sn (unwrap-panic (get-next-sn)))
      (parsed-address (try! (parse-network-address to)))
      (dst-network-id (get network-id parsed-address))
      (connection-result (unwrap-panic (get-default-connection dst-network-id)))
      (from-address (unwrap! (get-network-address) ERR_NOT_INITIALIZED))

      (source-contract (contract-call? .rlp-encode encode-string from-address))
      (dest-address (contract-call? .rlp-encode encode-string (get account parsed-address)))
      (sn (contract-call? .rlp-encode encode-uint next-sn))
      (msg-type (contract-call? .rlp-encode encode-uint CS_MESSAGE_TYPE_REQUEST))
      (message-data (contract-call? .rlp-encode encode-buff 
                      (unwrap! (as-max-len? data u1024) ERR_INVALID_MESSAGE)))

      (protocol-list-raw (map encode-protocol-string
          (default-to (list) destinations)))
      (protocol-list (contract-call? .rlp-encode encode-arr protocol-list-raw))

      (inner-message-raw (list
          source-contract
          dest-address 
          sn
          msg-type
          message-data
          protocol-list))
      (inner-message (contract-call? .rlp-encode encode-arr inner-message-raw))
      
      (final-list-raw (list 
          (contract-call? .rlp-encode encode-uint CS_MESSAGE_TYPE_REQUEST)
          inner-message))
      (cs-message-request (contract-call? .rlp-encode encode-arr final-list-raw))
    )
    (asserts! (is-some connection-result) ERR_INVALID_NETWORK_ADDRESS)
    
    (emit-call-message-sent-event tx-sender to next-sn cs-message-request sources destinations)
    
    (if (is-some rollback)
      (map-set outgoing-messages
        { sn: next-sn }
        {
          to: to,
          data: cs-message-request,
          rollback: rollback,
          sources: sources,
          destinations: destinations
        }
      )
      true
    )
    
    (if (and (is-reply dst-network-id sources) (is-none rollback))
      (begin
        (var-set reply-state none)
        (var-set call-reply (some cs-message-request))
      )
      true
    )
    
    (try! (stx-transfer? fee tx-sender fee-to))
    (ok next-sn)
  )
)

(define-public (handle-message (src-network-id (string-ascii 128)) (msg (buff 2048)))
  (let (
    (cs-message (unwrap-panic (parse-cs-message msg)))
    (msg-type (get type cs-message))
    (msg-data (get data cs-message))
  )
    (if (is-eq msg-type CS_MESSAGE_TYPE_REQUEST)
      (handle-request src-network-id msg-data)
      (if (is-eq msg-type CS_MESSAGE_TYPE_RESULT)
        (handle-result msg-data)
        ERR_INVALID_MESSAGE_TYPE
      )
    )
  )
)

(define-private (handle-request (src-network-id (string-ascii 128)) (data (buff 2048)))
  (let (
    (msg-req (unwrap-panic (parse-cs-message-request data)))
    (hash (keccak256 data))
  )
    (asserts! (is-eq (get network-id (unwrap-panic (parse-network-address (get from msg-req)))) src-network-id) ERR_INVALID_NETWORK_ADDRESS)
    (asserts! (verify-protocols src-network-id (get protocols msg-req) hash) ERR_UNVERIFIED_PROTOCOL)
    
    (let (
      (req-id (unwrap-panic (get-next-req-id)))
      (data-hash (keccak256 (get data msg-req)))
    )
      (emit-call-message-received-event (get from msg-req) (get to msg-req) (get sn msg-req) req-id (get data msg-req))
      (map-set incoming-messages
        { req-id: req-id }
        {
          from: (get from msg-req),
          to: (get to msg-req),
          sn: (get sn msg-req),
          type: (get type msg-req),
          data-hash: data-hash,
          protocols: (get protocols msg-req)
        }
      )
      (ok true)
    )
  )
)

(define-private (handle-result (data (buff 2048)))
  (let (
    (msg-res (unwrap-panic (parse-cs-message-result data)))
    (res-sn (get sn msg-res))
    (rollback (unwrap! (map-get? outgoing-messages { sn: res-sn }) ERR_MESSAGE_NOT_FOUND))
    (dst-network-id (get network-id (unwrap-panic (parse-network-address (get to rollback)))))
    (code (get code msg-res))
  )
    (asserts! (verify-protocols dst-network-id (default-to (list) (get sources rollback)) (keccak256 data)) ERR_UNVERIFIED_PROTOCOL)
    
    (emit-response-message-event res-sn (get code msg-res))
    (if (is-eq code CS_MESSAGE_RESULT_SUCCESS)
      (handle-success res-sn msg-res rollback)
      (if (is-eq code CS_MESSAGE_RESULT_FAILURE)
        (handle-failure res-sn rollback)
        ERR_INVALID_RESPONSE
      )
    )
  )
)

(define-public (handle-error (sn uint))
  (let (
    (error-result (create-cs-message-result sn CS_MESSAGE_RESULT_FAILURE none))
    (encoded-result (unwrap-panic (encode-cs-message-result error-result)))
  )
    (handle-result encoded-result)
  )
)

(define-private (create-cs-message-result (sn uint) (code uint) (msg (optional (buff 2048))))
  {
    sn: sn,
    code: code,
    msg: msg
  }
)

(define-private (encode-cs-message-result (result {sn: uint, code: uint, msg: (optional (buff 2048))}))
  (ok (concat
    (contract-call? .rlp-encode encode-uint (get sn result))
    (contract-call? .rlp-encode encode-uint (get code result))))
)

(define-private (handle-success (sn uint) (msg-res { sn: uint, code: uint, msg: (optional (buff 2048)) }) (rollback { to: (string-ascii 128), data: (buff 2048), rollback: (optional (buff 1024)), sources: (optional (list 10 (string-ascii 128))), destinations: (optional (list 10 (string-ascii 128))) }))
(begin
  (map-delete outgoing-messages { sn: sn })
  (map-set successful-responses { sn: sn } { value: true })
  (if (is-some (get msg msg-res))
    (let (
      (reply-data (unwrap-panic (get msg msg-res)))
      (parsed-reply-data (unwrap-panic (parse-cs-message-request reply-data)))
    )
      (handle-reply rollback parsed-reply-data)
    )
    (ok true)
  )
)
)

(define-private (handle-reply (rollback { to: (string-ascii 128), data: (buff 2048), rollback: (optional (buff 1024)), sources: (optional (list 10 (string-ascii 128))), destinations: (optional (list 10 (string-ascii 128))) })
                               (reply { from: (string-ascii 128), to: (string-ascii 128), sn: uint, type: uint, data: (buff 2048), protocols: (list 10 (string-ascii 128)) }))
  (let (
    (rollback-to (try! (parse-network-address (get to rollback))))
    (reply-from (try! (parse-network-address (get from reply))))
  )
    (asserts! (is-eq (get network-id rollback-to) (get network-id reply-from)) ERR_INVALID_REPLY)
    
    (let (
      (updated-reply (merge reply { protocols: (default-to (list) (get sources rollback)) }))
      (req-id (unwrap-panic (get-next-req-id)))
      (data-hash (keccak256 (get data updated-reply)))
    )
      (emit-call-message-received-event (get from updated-reply) (get to updated-reply) (get sn updated-reply) req-id (get data updated-reply))
      
      (map-set incoming-messages
        { req-id: req-id }
        {
          from: (get from updated-reply),
          to: (get to updated-reply),
          sn: (get sn updated-reply),
          type: (get type updated-reply),
          data-hash: data-hash,
          protocols: (get protocols updated-reply)
        }
      )
      (ok true)
    )
  )
)

(define-private (handle-failure (sn uint) (rollback { to: (string-ascii 128), data: (buff 2048), rollback: (optional (buff 1024)), sources: (optional (list 10 (string-ascii 128))), destinations: (optional (list 10 (string-ascii 128))) }))
  (match (get rollback rollback)
    rollback-data (begin
      (map-set outgoing-messages { sn: sn } (merge rollback { data: rollback-data }))
      (emit-rollback-message-received-event sn)
      (ok true)
    )
    ERR_NO_ROLLBACK_DATA
  )
)

(define-private (parse-cs-message (msg (buff 2048)))
  (let (
    (decoded (contract-call? .rlp-decode rlp-to-list msg))
    (type (contract-call? .rlp-decode rlp-decode-uint decoded u0))
    (data (unwrap-panic (element-at decoded u1)))
  )
    (ok {
      type: type,
      data: data
    })
  )
)

(define-private (parse-protocol (protocol (buff 2048)))
  (unwrap-panic (as-max-len? (unwrap-panic (contract-call? .rlp-decode decode-string protocol)) u128))
)

(define-public (parse-cs-message-request (data (buff 2048)))
  (let (
    (decoded (contract-call? .rlp-decode rlp-to-list data))
    (from (unwrap-panic (as-max-len? (unwrap-panic (contract-call? .rlp-decode rlp-decode-string decoded u0)) u128)))
    (to (unwrap-panic (as-max-len? (unwrap-panic (contract-call? .rlp-decode rlp-decode-string decoded u1)) u128)))
    (sn (contract-call? .rlp-decode rlp-decode-uint decoded u2))
    (type (contract-call? .rlp-decode rlp-decode-uint decoded u3))
    (msg-data (contract-call? .rlp-decode rlp-decode-buff decoded u4))
    (protocols-list (contract-call? .rlp-decode rlp-decode-list decoded u5))
    (protocols (map parse-protocol protocols-list))
  )
    (ok {
      from: from,
      to: to,
      sn: sn,
      type: type,
      data: msg-data,
      protocols: protocols
    })
  )
)

(define-private (parse-cs-message-result (data (buff 2048)))
  (let (
    (decoded (contract-call? .rlp-decode rlp-to-list data))
  )
    (ok {
      sn: (contract-call? .rlp-decode rlp-decode-uint decoded u0),
      code: (contract-call? .rlp-decode rlp-decode-uint decoded u1),
      msg: (if (> (len decoded) u2)
             (some (contract-call? .rlp-decode rlp-decode-buff decoded u2))
             none
           )
    })
  )
)

(define-read-only (verify-success (sn uint))
  (match (map-get? successful-responses { sn: sn })
    success-response (ok (get value success-response))
    (ok false)
  )
)

(define-public (execute-call (req-id uint) (data (buff 2048)) (receiver <xcall-receiver-trait>) (common <xcall-common-trait>))
  (let 
    (
      (req (unwrap! (map-get? incoming-messages { req-id: req-id }) ERR_MESSAGE_NOT_FOUND))
      (from (get from req))
      (to (get to req))
      (sn (get sn req))
      (msg-type (get type req))
      (stored-data-hash (get data-hash req))
      (protocols (get protocols req))
      (parsed-to (unwrap! (parse-network-address to) ERR_INVALID_NETWORK_ADDRESS))
      (to-account (unwrap! (as-max-len? (get account parsed-to) u128) ERR_INVALID_ACCOUNT))
      (to-principal (unwrap! (contract-call? .util address-string-to-principal to-account) ERR_ADDRESS_TO_PRINCIPAL_FAILED))
      (receiver-principal (contract-of receiver))
    )
    (asserts! (is-eq (keccak256 data) stored-data-hash) ERR_MESSAGE_NOT_FOUND)
    (asserts! (is-eq to-principal receiver-principal) ERR_INVALID_RECEIVER)
    
    (match (contract-call? receiver handle-call-message from data protocols common)
      success-response (begin 
        (emit-call-executed-event req-id CS_MESSAGE_RESULT_SUCCESS "")
        (map-delete incoming-messages { req-id: req-id })
        (ok true))
      error-value (begin
        (emit-call-executed-event req-id CS_MESSAGE_RESULT_FAILURE (int-to-ascii error-value))
        (match (map-get? outgoing-messages { sn: sn })
          msg (match (get rollback msg)
                rb (begin 
                    (emit-rollback-message-received-event sn)
                    (err error-value))
                (err error-value))
          (err error-value)))))
)

(define-public (execute-rollback (sn uint) (receiver <xcall-receiver-trait>) (common <xcall-common-trait>))
  (let 
    (
        (message (unwrap! (map-get? outgoing-messages { sn: sn }) ERR_MESSAGE_NOT_FOUND))
        (to (get to message))
        (parsed-to (unwrap! (parse-network-address to) ERR_INVALID_NETWORK_ADDRESS))
        (to-account (unwrap! (as-max-len? (get account parsed-to) u128) ERR_INVALID_ACCOUNT))
        (to-principal (unwrap! (contract-call? .util address-string-to-principal to-account) ERR_ADDRESS_TO_PRINCIPAL_FAILED))
        (receiver-principal (contract-of receiver))
        (from (unwrap! (as-max-len? (unwrap! (get-network-address) ERR_NOT_INITIALIZED) u128) ERR_ADDRESS_TO_PRINCIPAL_FAILED))
        (protocols (default-to (list) (get sources message)))
        (rollback (unwrap! (get rollback message) ERR_NO_ROLLBACK_DATA))
    )
    (asserts! (is-eq to-principal receiver-principal) ERR_INVALID_RECEIVER)
    (try! (contract-call? receiver handle-call-message from rollback protocols common))
    (emit-rollback-executed-event sn)
    (map-delete outgoing-messages { sn: sn })
    (ok true)
  )
)

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-admin) ERR_NOT_ADMIN)
    (var-set admin new-admin)
    (ok true)
  )
)

(define-public (set-protocol-fee-handler (new-handler principal))
  (begin
    (asserts! (is-admin) ERR_NOT_ADMIN)
    (var-set protocol-fee-handler new-handler)
    (ok true)
  )
)

(define-public (set-protocol-fee (new-fee uint))
  (begin
    (asserts! (is-admin) ERR_NOT_ADMIN)
    (var-set protocol-fee new-fee)
    (ok true)
  )
)

(define-public (set-default-connection (nid (string-ascii 128)) (connection (string-ascii 128)))
  (begin
    (asserts! (is-admin) ERR_NOT_ADMIN)
    (map-set default-connections 
      { nid: nid } 
      { address: connection }
    )
    (ok true)
  )
)

(define-read-only (get-protocol-fee)
  (ok (var-get protocol-fee))
)

(define-public (get-fee (network-id-in (string-ascii 128)) (rollback bool) (sources (optional (list 10 (string-ascii 128)))))
  (let
    (
      (cumulative-fee (var-get protocol-fee))
    )
    (var-set current-network-id network-id-in)
    (var-set current-rollback rollback)
    (if (and (is-reply network-id-in sources) (not rollback))
      (ok u0)
      (ok (+ cumulative-fee (get-connection-fee network-id-in rollback sources)))
    )
  )
)

(define-private (sum-fees (source (string-ascii 128)) (acc uint))
  (+ acc (get-fee-from-source source))
)

(define-private (get-connection-fee (network-id-in (string-ascii 128)) (rollback bool) (sources (optional (list 10 (string-ascii 128)))))
  (match sources
    some-sources (fold sum-fees some-sources u0)
    (let
      (
        (default-connection (unwrap-panic (get-default-connection network-id-in)))
      )
      (match default-connection
        some-connection (get-fee-from-source (get address some-connection))
        u0
      )
    )
  )
)

(define-private (get-fee-from-source (source (string-ascii 128)))
  (unwrap-panic (contract-call? .centralized-connection get-fee (var-get current-network-id) (var-get current-rollback)))
)

(define-read-only (get-incoming-message (req-id uint))
  (match (map-get? incoming-messages { req-id: req-id })
    message (ok message)
    (err ERR_MESSAGE_NOT_FOUND)
  )
)

(define-private (verify-protocols (src-network-id (string-ascii 128)) (protocols (list 10 (string-ascii 128))) (data (buff 2048)))
  (let 
    (
      (source tx-sender)
      (msg-hash (keccak256 data))
    )
    (if (> (len protocols) u0)
      (if (> (len protocols) u1)
        (let
          (
            (set-confirmation (map-set pending-messages { msg-hash: msg-hash, protocol: source } { confirmed: true }))
            (all-confirmed (fold check-protocol protocols { msg-hash: msg-hash, all-valid: true }))
          )
          (and 
            (get all-valid all-confirmed)
            (begin 
              (map clear-pending-message msg-hash protocols)
              true
            )
          )
        )
        (is-eq source (unwrap! (contract-call? .util address-string-to-principal (unwrap-panic (element-at protocols u0))) false))
      )
      (match (map-get? default-connections { nid: src-network-id })
        default-connection 
          (is-eq
            source
            (unwrap! (contract-call? .util address-string-to-principal (get address default-connection)) false)
          )
        false
      )
    )
  )
)

(define-private (check-protocol (protocol (string-ascii 128)) (accumulator { msg-hash: (buff 32), all-valid: bool }))
  (let
    (
      (protocol-principal (unwrap! (contract-call? .util address-string-to-principal protocol) accumulator))
      (is-confirmed (default-to false (get confirmed (map-get? pending-messages { msg-hash: (get msg-hash accumulator), protocol: protocol-principal }))))
    )
    {
      msg-hash: (get msg-hash accumulator),
      all-valid: (and (get all-valid accumulator) is-confirmed)
    }
  )
)

(define-private (clear-pending-message (msg-hash (buff 32)) (protocol (string-ascii 128)))
  (let
    (
      (protocol-principal (unwrap! (contract-call? .util address-string-to-principal protocol) false))
    )
    (map-delete pending-messages { 
      msg-hash: msg-hash, 
      protocol: protocol-principal
    })
  )
)
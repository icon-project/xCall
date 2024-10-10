(define-constant CONTRACT_NAME "xcall-impl")

(impl-trait .xcall-impl-trait.xcall-impl-trait)

(define-constant ERR_INVALID_NETWORK_ADDRESS (err u100))
(define-constant ERR_INVALID_NETWORK_ID (err u101))
(define-constant ERR_INVALID_ACCOUNT (err u102))
(define-constant ERR_MESSAGE_NOT_FOUND (err u103))
(define-constant ERR_NOT_ADMIN (err u104))
(define-constant ERR_ALREADY_INITIALIZED (err u105))
(define-constant ERR_NOT_INITIALIZED (err u106))
(define-constant ERR_INVALID_MESSAGE_TYPE (err u107))
(define-constant ERR_INVALID_RESPONSE (err u108))
(define-constant ERR_NO_ROLLBACK_DATA (err u109))
(define-constant ERR_INVALID_REPLY (err u110))
(define-constant ERR_NO_DEFAULT_CONNECTION (err u111))

(define-constant CS_MESSAGE_RESULT_FAILURE u0)
(define-constant CS_MESSAGE_RESULT_SUCCESS u1)
(define-constant CS_MESSAGE_TYPE_REQUEST u1)
(define-constant CS_MESSAGE_TYPE_RESULT u2)

(define-data-var admin principal tx-sender)
(define-data-var protocol-fee uint u0)
(define-data-var protocol-fee-handler principal tx-sender)
(define-data-var current-net (string-ascii 64) "")
(define-data-var current-rollback bool false)
(define-data-var sn-counter uint u0)
(define-data-var req-id-counter uint u0)
(define-data-var reply-state
  (optional {
    from-nid: (string-ascii 64),
    protocols: (list 10 (string-ascii 64))
  })
  none
)
(define-data-var call-reply (optional (buff 2048)) none)
(define-data-var network-id (optional (string-ascii 64)) none)
(define-data-var contract-address (optional (string-ascii 64)) none)

(define-map default-connections 
  { nid: (string-ascii 64) } 
  { address: (string-ascii 64) }
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
    data: (buff 2048),
  }
)

(define-map successful-responses
  { sn: uint }
  { value: bool }
)

(define-public (init (nid (string-ascii 64)) (addr (string-ascii 64)))
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
    some-id (ok some-id)
    ERR_NOT_INITIALIZED
  )
)

(define-read-only (get-network-address)
  (match (var-get network-id)
    some-id
      (match (var-get contract-address)
        some-addr (ok (concat (concat some-id "/") some-addr))
        ERR_NOT_INITIALIZED
      )
    ERR_NOT_INITIALIZED
  )
)

(define-read-only (get-outgoing-message (sn uint))
  (map-get? outgoing-messages { sn: sn })
)

(define-read-only (is-reply (net-id (string-ascii 64)) (sources (optional (list 100 (string-ascii 64)))))
  (match (var-get reply-state)
    state (and 
            (is-eq (get from-nid state) net-id)
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

(define-private (validate-network-address (address (string-ascii 128)))
  (match (index-of? address "/")
    index 
      (let 
        (
          (net (slice? address u0 index))
          (account (slice? address (+ index u1) (len address)))
        )
        (and 
          (is-some net)
          (is-some account)
          (> (len (unwrap! net false)) u0)
          (> (len (unwrap! account false)) u0)
        )
      )
    false
  )
)

(define-private (parse-network-address (address (string-ascii 128)))
  (if (validate-network-address address)
    (match (index-of? address "/")
      index 
        (let 
          (
            (net (unwrap-panic (as-max-len? (unwrap-panic (slice? address u0 index)) u64)))
            (account (unwrap-panic (slice? address (+ index u1) (len address))))
          )
          (ok {net: net, account: account})
        )
      ERR_INVALID_NETWORK_ADDRESS
    )
    ERR_INVALID_NETWORK_ADDRESS
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
      data: data
    }
  )
)

(define-private (emit-call-executed-event (req-id uint) (code uint) (message (string-ascii 100)))
  (print 
    {
      event: "CallExecuted",
      req-id: req-id,
      code: code,
      msg: message
    }
  )
)

(define-private (emit-call-message-sent-event (from principal) (to (string-ascii 100)) (sn uint))
  (print
    {
      event: "CallMessageSent",
        from: tx-sender,
        to: to,
        sn: sn,
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

(define-private (emit-rollback-message-event (sn uint))
  (print 
    {
      event: "RollbackMessage",
      sn: sn
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

(define-read-only (get-default-connection (nid (string-ascii 64)))
  (match (map-get? default-connections { nid: nid })
    connection (ok (some connection))
    ERR_NO_DEFAULT_CONNECTION)
)

(define-public (send-call 
  (to (string-ascii 100)) 
  (data (buff 2048))
)
  (begin
    (send-call-message to data none none none)
  )
)

(define-public (send-call-message 
  (to (string-ascii 100)) 
  (data (buff 2048)) 
  (rollback (optional (buff 1024))) 
  (sources (optional (list 10 (string-ascii 64)))) 
  (destinations (optional (list 10 (string-ascii 64))))
)
  (let
    (
      (fee (var-get protocol-fee))
      (fee-to (var-get protocol-fee-handler))
      (next-sn (unwrap-panic (get-next-sn)))
      (parsed-address (try! (parse-network-address to)))
      (dst (get net parsed-address))
      (connection-result (unwrap-panic (get-default-connection dst)))
    )
    (asserts! (is-some connection-result) ERR_INVALID_NETWORK_ADDRESS)
    (emit-call-message-sent-event tx-sender to next-sn)
    (map-set outgoing-messages
      { sn: next-sn }
      {
        to: to,
        data: data,
        rollback: rollback,
        sources: sources,
        destinations: destinations
      }
    )
    (if (and (is-reply dst sources) (is-none rollback))
      (begin
        (var-set reply-state none)
        (var-set call-reply (some data))
      )
      true
    )
    (try! (stx-transfer? fee tx-sender fee-to))
    (ok next-sn)
  )
)

(define-public (handle-message (from (string-ascii 64)) (msg (buff 2048)))
  (let (
    (cs-message (unwrap-panic (parse-cs-message msg)))
    (msg-type (get type cs-message))
    (msg-data (get data cs-message))
  )
    (if (is-eq msg-type CS_MESSAGE_TYPE_REQUEST)
      (handle-request from msg-data)
      (if (is-eq msg-type CS_MESSAGE_TYPE_RESULT)
        (handle-result msg-data)
        ERR_INVALID_MESSAGE_TYPE
      )
    )
  )
)

(define-private (handle-request (from (string-ascii 64)) (data (buff 2048)))
  (let (
    (msg-req (unwrap-panic (parse-cs-message-request data)))
    (hash (sha256 data))
  )
    (asserts! (is-eq (get net (unwrap-panic (parse-network-address (get from msg-req)))) from) ERR_INVALID_NETWORK_ADDRESS)
    ;; (asserts! (verify-protocols from (get protocols msg-req) hash) ERR_UNAUTHORIZED)
    
    (let (
      (req-id (unwrap-panic (get-next-req-id)))
    )
      (emit-call-message-received-event (get from msg-req) (get to msg-req) (get sn msg-req) req-id (get data msg-req))
      (map-set incoming-messages { req-id: req-id } { from: (get from msg-req), data: (get data msg-req) })
      (ok true)
    )
  )
)

(define-private (handle-result (data (buff 2048)))
  (let (
    (msg-res (unwrap-panic (parse-cs-message-result data)))
    (res-sn (get sn msg-res))
    (rollback (unwrap! (map-get? outgoing-messages { sn: res-sn }) ERR_MESSAGE_NOT_FOUND))
    (code (get code msg-res))
  )
    ;; (asserts! (verify-protocols (get to rollback) (default-to (list) (get sources rollback)) (sha256 data)) ERR_UNAUTHORIZED)
    
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
                               (reply { from: (string-ascii 128), to: (string-ascii 128), sn: uint, type: uint, data: (buff 2048), protocols: (list 50 (string-ascii 128)) }))
  (let (
    (rollback-to (try! (parse-network-address (get to rollback))))
    (reply-from (try! (parse-network-address (get from reply))))
  )
    (asserts! (is-eq (get net rollback-to) (get net reply-from)) ERR_INVALID_REPLY)
    
    (let (
      (updated-reply (merge reply { protocols: (default-to (list) (get sources rollback)) }))
      (req-id (unwrap-panic (get-next-req-id)))
    )
      (emit-call-message-received-event (get from updated-reply) (get to updated-reply) (get sn updated-reply) req-id (get data updated-reply))
      
      (map-set incoming-messages
        { req-id: req-id }
        { from: (get from updated-reply), data: (sha256 (get data updated-reply)) }
      )
      
      (ok true)
    )
  )
)

(define-private (handle-failure (sn uint) (rollback { to: (string-ascii 128), data: (buff 2048), rollback: (optional (buff 1024)), sources: (optional (list 10 (string-ascii 128))), destinations: (optional (list 10 (string-ascii 128))) }))
  (match (get rollback rollback)
    rollback-data (begin
      (map-set outgoing-messages { sn: sn } (merge rollback { data: rollback-data }))
      (emit-rollback-message-event sn)
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
  (unwrap-panic (as-max-len? (contract-call? .rlp-decode decode-string protocol) u128))
)

(define-private (parse-cs-message-request (data (buff 2048)))
  (let (
    (decoded (contract-call? .rlp-decode rlp-to-list data))
    (from (unwrap-panic (as-max-len? (contract-call? .rlp-decode rlp-decode-string decoded u0) u128)))
    (to (unwrap-panic (as-max-len? (contract-call? .rlp-decode rlp-decode-string decoded u1) u128)))
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

(define-public (execute-call (req-id uint) (data (buff 2048)))
  (let 
    (
      (message (map-get? incoming-messages { req-id: req-id }))
      (stored-data (get data (unwrap! message ERR_MESSAGE_NOT_FOUND)))
    )
      (asserts! (is-eq (keccak256 data) (keccak256 stored-data)) ERR_MESSAGE_NOT_FOUND)
      (emit-call-executed-event req-id CS_MESSAGE_RESULT_SUCCESS "")
      (map-delete incoming-messages { req-id: req-id })
      (ok true)
  )
)

(define-public (execute-rollback (sn uint))
  (let 
    (
        (message (map-get? outgoing-messages { sn: sn }))
    )
    (asserts! (is-some message) ERR_MESSAGE_NOT_FOUND)
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

(define-public (set-default-connection (nid (string-ascii 64)) (connection (string-ascii 64)))
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

(define-public (get-fee (net (string-ascii 64)) (rollback bool) (sources (optional (list 100 (string-ascii 64)))))
  (let
    (
      (cumulative-fee (var-get protocol-fee))
    )
    (var-set current-net net)
    (var-set current-rollback rollback)
    (if (and (is-reply net sources) (not rollback))
      (ok u0)
      (ok (+ cumulative-fee (get-connection-fee net rollback sources)))
    )
  )
)

(define-private (sum-fees (source (string-ascii 64)) (acc uint))
  (+ acc (get-fee-from-source source))
)

(define-private (get-connection-fee (net (string-ascii 64)) (rollback bool) (sources (optional (list 100 (string-ascii 64)))))
  (match sources
    some-sources (fold sum-fees some-sources u0)
    (let
      (
        (default-connection (unwrap-panic (get-default-connection net)))
      )
      (match default-connection
        some-connection (get-fee-from-source (get address some-connection))
        u0
      )
    )
  )
)

(define-private (get-fee-from-source (source (string-ascii 64)))
  (unwrap-panic (contract-call? .centralized-connection get-fee (var-get current-net) (var-get current-rollback)))
)

(define-read-only (get-incoming-message (req-id uint))
  (match (map-get? incoming-messages { req-id: req-id })
    message (ok message)
    (err ERR_MESSAGE_NOT_FOUND)
  )
)
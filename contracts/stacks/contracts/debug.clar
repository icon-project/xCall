(define-public (debug-execute-call-failure)
    (let
        (
            ;; Initialize xcall-impl
            (init-impl-result (unwrap! (contract-call? .xcall-impl init "stacks" "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.xcall-impl") (err u800)))
            
            ;; Set admin for xcall-impl
            (set-admin-result (unwrap! (contract-call? .xcall-impl set-admin tx-sender) (err u800)))
            
            ;; Initialize mock-dapp
            (init-result (unwrap! (contract-call? .mock-dapp initialize .xcall-proxy) (err u800)))
            
            ;; Upgrade proxy to implementation
            (upgrade-result (unwrap! (contract-call? .xcall-proxy upgrade .xcall-impl none) (err u800)))
            
            ;; Initialize centralized connection
            (init-connection-result (unwrap! (contract-call? .centralized-connection initialize .xcall-proxy tx-sender) (err u800)))
            
            ;; Set default connections
            (set-default-connection-stacks (unwrap! (contract-call? .xcall-proxy set-default-connection 
                "stacks" 
                "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.centralized-connection" 
                .xcall-impl) 
                (err u800)))
            
            (set-default-connection-test (unwrap! (contract-call? .xcall-proxy set-default-connection 
                "test" 
                "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.centralized-connection" 
                .xcall-impl) 
                (err u800)))

            ;; Set protocol fee handler
            (set-protocol-fee-handler-result (unwrap! (contract-call? .xcall-proxy set-protocol-fee-handler 
                .centralized-connection 
                .xcall-impl) 
                (err u800)))

            ;; Set fees for both networks
            (set-fee-stacks-result (unwrap! (contract-call? .centralized-connection set-fee 
                "stacks" 
                u500000 
                u250000) 
                (err u800)))
            
            (set-fee-icon-result (unwrap! (contract-call? .centralized-connection set-fee 
                "test" 
                u1000000 
                u500000) 
                (err u800)))

            ;; Set protocol fee
            (set-protocol-fee-result (unwrap! (contract-call? .xcall-proxy set-protocol-fee 
                u100000 
                .xcall-impl) 
                (err u800)))

            ;; Set up mock-dapp connections
            (add-dapp-connection-stacks (unwrap! (contract-call? .mock-dapp add-connection
                "stacks"
                "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.centralized-connection"
                "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.centralized-connection") 
                (err u800)))

            (add-dapp-connection-icon (unwrap! (contract-call? .mock-dapp add-connection
                "test"
                "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.centralized-connection"
                "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.centralized-connection") 
                (err u800)))

            ;; Rest of the original code...
            (encoded-result (contract-call? .rlp-encode encode-string "rollback"))
            (test-protocols (list))
            (from-address "stacks/ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM")
            (req-id u1)
            (from "stacks/ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM")
            (to "test/ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM")
            (sn u1)
            (messageData (contract-call? .rlp-encode encode-arr 
                (list 
                    (contract-call? .rlp-encode encode-string from)
                    (contract-call? .rlp-encode encode-string to)
                    (contract-call? .rlp-encode encode-uint sn)
                    (contract-call? .rlp-encode encode-uint req-id)
                    encoded-result
                    (contract-call? .rlp-encode encode-arr (list))
                )))
            (messageData-prefix (unwrap-panic (element-at? messageData u0)))
            (csMessageRequest (contract-call? .rlp-encode encode-arr 
                (list 
                    (contract-call? .rlp-encode encode-uint u1)  ;; CS_MESSAGE_TYPE_REQUEST
                    messageData
                )))
            (csMessageRequest-prefix (unwrap-panic (element-at? csMessageRequest u0)))
            (prefixes {
                message-prefix: messageData-prefix,
                request-prefix: csMessageRequest-prefix
            })
            (handle-result (unwrap-panic (contract-call? .xcall-proxy handle-message "stacks" csMessageRequest .xcall-impl)))
        )
        (contract-call? 
            .xcall-proxy 
            execute-call
            req-id
            encoded-result
            .mock-dapp
            .xcall-impl
            .xcall-impl
        )
    )
)

(define-public (debug-address-conversion)
    (contract-call? 
        .util 
        address-string-to-principal 
        "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.centralized-connection"
    )
)
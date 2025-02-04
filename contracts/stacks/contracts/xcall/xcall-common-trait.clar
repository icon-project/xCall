(define-trait xcall-common-trait
  (
    (get-network-address () (response (string-ascii 128) uint))
    (send-call-message ((string-ascii 128) (buff 2048) (optional (buff 1024)) (optional (list 10 (string-ascii 128))) (optional (list 10 (string-ascii 128)))) (response uint uint))
  )
)
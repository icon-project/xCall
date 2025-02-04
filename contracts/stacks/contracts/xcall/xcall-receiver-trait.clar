(use-trait xcall-common-trait .xcall-common-trait.xcall-common-trait)

(define-trait xcall-receiver-trait
  (
    (handle-call-message ((string-ascii 128) (buff 2048) (list 10 (string-ascii 128)) <xcall-common-trait>) (response bool uint))
  )
)
(define-private (check-length (data (buff 4092)))
  (unwrap-panic (as-max-len? data u1024))
)

(define-private (encode-buff-arr (objects (list 500 (buff 1024))))
    (fold concat-buff objects 0x)
)

(define-private (concat-buff (a (buff 1024)) (b (buff 1024)))
    (check-length (concat b a))
)

(define-private (rm-lead (num (buff 1)) (buffer (buff 1024)))
    (if (is-eq 0x00 buffer)
        num
        (check-length (concat buffer num))
    )
)

(define-read-only (encode-string (message (string-ascii 1024)))
   (let (
       (encoded (unwrap-panic (to-consensus-buff? message)))
       )
       (if (is-eq (len encoded) u5)
           ;; Special case for empty string
           0x80
           (let (
               ;; Remove type prefix and length bytes
               (encoded-length (- (len encoded) u5))
               (string-content (unwrap-panic (slice? encoded u5 (len encoded))))
           )
               (if (> encoded-length u55)
                   ;; Long string case (>55 bytes)
                   (let (
                       (length-bytes (unwrap-panic (to-consensus-buff? encoded-length)))
                       (length-byte (unwrap-panic (element-at? length-bytes u16)))
                       (length-hex (unwrap-panic (slice? length-bytes u1 (len length-bytes))))
                       (prefix (if (> encoded-length u255)
                           0xb9  ;; Two bytes needed for length
                           0xb8  ;; One byte needed for length
                       ))
                   )
                   (check-length (concat 
                       (if (> encoded-length u255)
                           (concat prefix length-hex)  ;; Use full length for large strings
                           (concat prefix length-byte)  ;; Use single byte for smaller strings
                       )
                       string-content)))
                   ;; Short string case (<=55 bytes)
                   (let (
                       (id (unwrap-panic (to-consensus-buff? (+ u128 encoded-length))))
                       (prefix (unwrap-panic (element-at? id u16)))
                       (res (concat prefix string-content))
                   )
                   (check-length res))
               )
           )
       )
   )
)

(define-private (encode-uint-raw (data uint))
    (if (is-eq data u0)
        0x00
        (let (
            (encoded (unwrap-panic (to-consensus-buff? data)))
            (sliced (unwrap-panic (slice? encoded u1 (len encoded))))
            (stripped (fold rm-lead sliced 0x00))
            )
            (if (>= data (pow u256 u3))
                (check-length (concat 0x00 stripped))
                stripped)
        )
    )
)

(define-read-only (encode-uint (data uint))
    (if (>= data (pow u256 u15))
        (check-length (concat 0x91 (encode-uint-raw data)))
        (if (>= data (pow u256 u14))
            (check-length (concat 0x90 (encode-uint-raw data)))
            (if (>= data (pow u256 u13))
                (check-length (concat 0x8f (encode-uint-raw data)))
                (if (>= data (pow u256 u12))
                    (check-length (concat 0x8e (encode-uint-raw data)))
                    (if (>= data (pow u256 u11))
                        (check-length (concat 0x8d (encode-uint-raw data)))
                        (if (>= data (pow u256 u10))
                            (check-length (concat 0x8c (encode-uint-raw data)))
                            (if (>= data (pow u256 u9))
                                (check-length (concat 0x8b (encode-uint-raw data)))
                                (if (>= data (pow u256 u8))
                                    (check-length (concat 0x8a (encode-uint-raw data)))
                                    (if (>= data (pow u256 u7))
                                        (check-length (concat 0x89 (encode-uint-raw data)))
                                        (if (>= data (pow u256 u6))
                                            (check-length (concat 0x88 (encode-uint-raw data)))
                                            (if (>= data (pow u256 u5))
                                                (check-length (concat 0x87 (encode-uint-raw data)))
                                                (if (>= data (pow u256 u4))
                                                    (check-length (concat 0x86 (encode-uint-raw data)))
                                                    (if (>= data (pow u256 u3))
                                                        (check-length (concat 0x85 (encode-uint-raw data)))
                                                        (if (>= data (pow u256 u2))
                                                            (check-length (concat 0x83 (encode-uint-raw data)))
                                                            (if (>= data u256)
                                                                (check-length (concat 0x82 (encode-uint-raw data)))
                                                                (if (>= data u128)
                                                                    (check-length (concat 0x81 (encode-uint-raw data)))
                                                                    (encode-uint-raw data)))))))))))))))))
)

(define-private (make-long-list-prefix (data (buff 1024)))
    (let (
        (length-bytes (unwrap-panic (to-consensus-buff? (len data))))
        (length-byte (unwrap-panic (element-at? length-bytes u16)))
    )
    (check-length (concat 0xf8 length-byte)))
)

(define-read-only (encode-arr (objects (list 500 (buff 1024))))
    (let (
        (encoded-data (encode-buff-arr objects))
        (total-length (len encoded-data))
    )
    (if (and (> total-length u55) (is-eq (len objects) u2))
        (let (
            (first-element (unwrap-panic (element-at? objects u0)))
            (second-element (unwrap-panic (element-at? objects u1)))
            (second-length (len second-element))
        )
        (if (> second-length u55)
            ;; Handle case where second element is a long string/list
            (let (
                ;; Total bytes calculation:
                ;; 1 (first element) + 
                ;; 2 (0xb8 + length byte for inner) +
                ;; second_length
                (total-bytes (+ u1 (+ u2 second-length)))
                (total-length-bytes (unwrap-panic (to-consensus-buff? total-bytes)))
                (total-length-byte (unwrap-panic (element-at? total-length-bytes u16)))
                (inner-length-bytes (unwrap-panic (to-consensus-buff? second-length)))
                (inner-length-byte (unwrap-panic (element-at? inner-length-bytes u16)))
            )
            (check-length (concat 
                0xf8 
                (concat total-length-byte 
                    (concat first-element 
                        (concat 0xb8 
                            (concat inner-length-byte second-element)))))))
            (check-length (concat (make-long-list-prefix encoded-data) encoded-data))))
        (if (> total-length u55)
            (check-length (concat (make-long-list-prefix encoded-data) encoded-data))
            (check-length (concat (encode-uint-raw (+ u192 total-length)) encoded-data)))
    ))
)



(define-read-only (encode-buff (data (buff 1024)))
    (if (< u1 (len data))
      (encode-buff-long data)
      data
    )
)

(define-private (encode-buff-long (data (buff 1024)))
  (let
        ((prefix (unwrap-panic  (element-at?  (unwrap-panic (to-consensus-buff? (+ u128 (len data))))  u16) )))
        (check-length (concat prefix data))
    )
)
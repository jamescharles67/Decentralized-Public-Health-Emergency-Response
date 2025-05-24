;; Resource Allocation Contract
;; Manages emergency supplies and resource distribution

(define-constant ERR_UNAUTHORIZED (err u300))
(define-constant ERR_INSUFFICIENT_RESOURCES (err u301))
(define-constant ERR_INVALID_ALLOCATION (err u302))
(define-constant ERR_RESOURCE_NOT_FOUND (err u303))

;; Resource types
(define-constant RESOURCE_MEDICAL_SUPPLIES u1)
(define-constant RESOURCE_PERSONNEL u2)
(define-constant RESOURCE_EQUIPMENT u3)
(define-constant RESOURCE_FUNDING u4)

;; Data structures
(define-map resource-inventory
  {resource-type: uint, location: (string-ascii 50)}
  {
    quantity: uint,
    unit: (string-ascii 20),
    last-updated: uint,
    managed-by: principal
  }
)

(define-map resource-allocations
  uint
  {
    allocation-id: uint,
    emergency-id: uint,
    resource-type: uint,
    quantity: uint,
    from-location: (string-ascii 50),
    to-location: (string-ascii 50),
    allocated-by: principal,
    allocated-at: uint,
    status: uint
  }
)

(define-map allocation-requests
  uint
  {
    request-id: uint,
    emergency-id: uint,
    requested-by: principal,
    resource-type: uint,
    quantity: uint,
    location: (string-ascii 50),
    priority: uint,
    requested-at: uint,
    status: uint
  }
)

(define-data-var allocation-counter uint u0)
(define-data-var request-counter uint u0)

;; Allocation status
(define-constant ALLOCATION_PENDING u1)
(define-constant ALLOCATION_APPROVED u2)
(define-constant ALLOCATION_DELIVERED u3)
(define-constant ALLOCATION_CANCELLED u4)

;; Read-only functions
(define-read-only (get-resource-inventory (resource-type uint) (location (string-ascii 50)))
  (map-get? resource-inventory {resource-type: resource-type, location: location})
)

(define-read-only (get-allocation (allocation-id uint))
  (map-get? resource-allocations allocation-id)
)

(define-read-only (get-allocation-request (request-id uint))
  (map-get? allocation-requests request-id)
)

;; Public functions
(define-public (add-resource-inventory
  (resource-type uint)
  (location (string-ascii 50))
  (quantity uint)
  (unit (string-ascii 20))
)
  (begin
    (map-set resource-inventory {resource-type: resource-type, location: location} {
      quantity: quantity,
      unit: unit,
      last-updated: block-height,
      managed-by: tx-sender
    })
    (ok true)
  )
)

(define-public (request-resources
  (emergency-id uint)
  (resource-type uint)
  (quantity uint)
  (location (string-ascii 50))
  (priority uint)
)
  (let ((request-id (+ (var-get request-counter) u1)))
    (begin
      (map-set allocation-requests request-id {
        request-id: request-id,
        emergency-id: emergency-id,
        requested-by: tx-sender,
        resource-type: resource-type,
        quantity: quantity,
        location: location,
        priority: priority,
        requested-at: block-height,
        status: ALLOCATION_PENDING
      })

      (var-set request-counter request-id)
      (ok request-id)
    )
  )
)

(define-public (allocate-resources
  (request-id uint)
  (from-location (string-ascii 50))
  (to-location (string-ascii 50))
)
  (let (
    (request (unwrap! (map-get? allocation-requests request-id) ERR_RESOURCE_NOT_FOUND))
    (allocation-id (+ (var-get allocation-counter) u1))
    (resource-key {resource-type: (get resource-type request), location: from-location})
    (inventory (unwrap! (map-get? resource-inventory resource-key) ERR_RESOURCE_NOT_FOUND))
  )
    (begin
      (asserts! (>= (get quantity inventory) (get quantity request)) ERR_INSUFFICIENT_RESOURCES)

      ;; Update inventory
      (map-set resource-inventory resource-key
        (merge inventory {
          quantity: (- (get quantity inventory) (get quantity request)),
          last-updated: block-height
        })
      )

      ;; Create allocation record
      (map-set resource-allocations allocation-id {
        allocation-id: allocation-id,
        emergency-id: (get emergency-id request),
        resource-type: (get resource-type request),
        quantity: (get quantity request),
        from-location: from-location,
        to-location: to-location,
        allocated-by: tx-sender,
        allocated-at: block-height,
        status: ALLOCATION_APPROVED
      })

      ;; Update request status
      (map-set allocation-requests request-id
        (merge request {status: ALLOCATION_APPROVED})
      )

      (var-set allocation-counter allocation-id)
      (ok allocation-id)
    )
  )
)

(define-public (confirm-delivery (allocation-id uint))
  (let ((allocation (unwrap! (map-get? resource-allocations allocation-id) ERR_RESOURCE_NOT_FOUND)))
    (begin
      (map-set resource-allocations allocation-id
        (merge allocation {status: ALLOCATION_DELIVERED})
      )
      (ok true)
    )
  )
)

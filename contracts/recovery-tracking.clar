;; Recovery Tracking Contract
;; Monitors post-emergency recovery progress and metrics

(define-constant ERR_UNAUTHORIZED (err u500))
(define-constant ERR_RECOVERY_NOT_FOUND (err u501))
(define-constant ERR_INVALID_METRIC (err u502))
(define-constant ERR_INVALID_STATUS (err u503))

;; Recovery phases
(define-constant PHASE_IMMEDIATE u1)
(define-constant PHASE_SHORT_TERM u2)
(define-constant PHASE_LONG_TERM u3)
(define-constant PHASE_COMPLETE u4)

;; Recovery areas
(define-constant AREA_HEALTH_SERVICES u1)
(define-constant AREA_INFRASTRUCTURE u2)
(define-constant AREA_ECONOMIC u3)
(define-constant AREA_SOCIAL u4)
(define-constant AREA_ENVIRONMENTAL u5)

;; Data structures
(define-map recovery-plans
  uint
  {
    plan-id: uint,
    emergency-id: uint,
    title: (string-ascii 200),
    description: (string-ascii 500),
    lead-coordinator: principal,
    created-at: uint,
    target-completion: uint,
    current-phase: uint,
    overall-progress: uint
  }
)

(define-map recovery-metrics
  {plan-id: uint, area: uint}
  {
    area-name: (string-ascii 50),
    target-value: uint,
    current-value: uint,
    unit: (string-ascii 20),
    last-updated: uint,
    updated-by: principal
  }
)

(define-map recovery-milestones
  uint
  {
    milestone-id: uint,
    plan-id: uint,
    title: (string-ascii 100),
    description: (string-ascii 300),
    target-date: uint,
    completion-date: uint,
    status: uint,
    responsible-party: principal
  }
)

(define-map progress-reports
  uint
  {
    report-id: uint,
    plan-id: uint,
    reporting-period: uint,
    overall-progress: uint,
    challenges: (string-ascii 300),
    next-steps: (string-ascii 300),
    reported-by: principal,
    reported-at: uint
  }
)

(define-data-var plan-counter uint u0)
(define-data-var milestone-counter uint u0)
(define-data-var report-counter uint u0)

;; Milestone status
(define-constant MILESTONE_PLANNED u1)
(define-constant MILESTONE_IN_PROGRESS u2)
(define-constant MILESTONE_COMPLETED u3)
(define-constant MILESTONE_DELAYED u4)

;; Read-only functions
(define-read-only (get-recovery-plan (plan-id uint))
  (map-get? recovery-plans plan-id)
)

(define-read-only (get-recovery-metric (plan-id uint) (area uint))
  (map-get? recovery-metrics {plan-id: plan-id, area: area})
)

(define-read-only (get-milestone (milestone-id uint))
  (map-get? recovery-milestones milestone-id)
)

(define-read-only (get-progress-report (report-id uint))
  (map-get? progress-reports report-id)
)

(define-read-only (calculate-area-progress (plan-id uint) (area uint))
  (match (map-get? recovery-metrics {plan-id: plan-id, area: area})
    metric (if (> (get target-value metric) u0)
             (/ (* (get current-value metric) u100) (get target-value metric))
             u0)
    u0
  )
)

;; Public functions
(define-public (create-recovery-plan
  (emergency-id uint)
  (title (string-ascii 200))
  (description (string-ascii 500))
  (target-completion uint)
)
  (let ((plan-id (+ (var-get plan-counter) u1)))
    (begin
      (map-set recovery-plans plan-id {
        plan-id: plan-id,
        emergency-id: emergency-id,
        title: title,
        description: description,
        lead-coordinator: tx-sender,
        created-at: block-height,
        target-completion: target-completion,
        current-phase: PHASE_IMMEDIATE,
        overall-progress: u0
      })

      (var-set plan-counter plan-id)
      (ok plan-id)
    )
  )
)

(define-public (set-recovery-metric
  (plan-id uint)
  (area uint)
  (area-name (string-ascii 50))
  (target-value uint)
  (current-value uint)
  (unit (string-ascii 20))
)
  (begin
    (asserts! (is-some (map-get? recovery-plans plan-id)) ERR_RECOVERY_NOT_FOUND)
    (asserts! (<= area AREA_ENVIRONMENTAL) ERR_INVALID_METRIC)

    (map-set recovery-metrics {plan-id: plan-id, area: area} {
      area-name: area-name,
      target-value: target-value,
      current-value: current-value,
      unit: unit,
      last-updated: block-height,
      updated-by: tx-sender
    })

    (ok true)
  )
)

(define-public (update-metric-progress
  (plan-id uint)
  (area uint)
  (new-value uint)
)
  (let ((metric (unwrap! (map-get? recovery-metrics {plan-id: plan-id, area: area}) ERR_RECOVERY_NOT_FOUND)))
    (begin
      (map-set recovery-metrics {plan-id: plan-id, area: area}
        (merge metric {
          current-value: new-value,
          last-updated: block-height,
          updated-by: tx-sender
        })
      )
      (ok true)
    )
  )
)

(define-public (create-milestone
  (plan-id uint)
  (title (string-ascii 100))
  (description (string-ascii 300))
  (target-date uint)
  (responsible-party principal)
)
  (let ((milestone-id (+ (var-get milestone-counter) u1)))
    (begin
      (asserts! (is-some (map-get? recovery-plans plan-id)) ERR_RECOVERY_NOT_FOUND)

      (map-set recovery-milestones milestone-id {
        milestone-id: milestone-id,
        plan-id: plan-id,
        title: title,
        description: description,
        target-date: target-date,
        completion-date: u0,
        status: MILESTONE_PLANNED,
        responsible-party: responsible-party
      })

      (var-set milestone-counter milestone-id)
      (ok milestone-id)
    )
  )
)

(define-public (complete-milestone (milestone-id uint))
  (let ((milestone (unwrap! (map-get? recovery-milestones milestone-id) ERR_RECOVERY_NOT_FOUND)))
    (begin
      (map-set recovery-milestones milestone-id
        (merge milestone {
          completion-date: block-height,
          status: MILESTONE_COMPLETED
        })
      )
      (ok true)
    )
  )
)

(define-public (submit-progress-report
  (plan-id uint)
  (reporting-period uint)
  (overall-progress uint)
  (challenges (string-ascii 300))
  (next-steps (string-ascii 300))
)
  (let ((report-id (+ (var-get report-counter) u1)))
    (begin
      (asserts! (is-some (map-get? recovery-plans plan-id)) ERR_RECOVERY_NOT_FOUND)
      (asserts! (<= overall-progress u100) ERR_INVALID_METRIC)

      (map-set progress-reports report-id {
        report-id: report-id,
        plan-id: plan-id,
        reporting-period: reporting-period,
        overall-progress: overall-progress,
        challenges: challenges,
        next-steps: next-steps,
        reported-by: tx-sender,
        reported-at: block-height
      })

      ;; Update plan progress
      (map-set recovery-plans plan-id
        (merge (unwrap-panic (map-get? recovery-plans plan-id))
               {overall-progress: overall-progress})
      )

      (var-set report-counter report-id)
      (ok report-id)
    )
  )
)

(define-public (advance-recovery-phase (plan-id uint))
  (let ((plan (unwrap! (map-get? recovery-plans plan-id) ERR_RECOVERY_NOT_FOUND)))
    (begin
      (asserts! (< (get current-phase plan) PHASE_COMPLETE) ERR_INVALID_STATUS)

      (map-set recovery-plans plan-id
        (merge plan {current-phase: (+ (get current-phase plan) u1)})
      )
      (ok true)
    )
  )
)

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'uq_schedule_loan_installment'
    ) THEN
        ALTER TABLE payment_schedules
        ADD CONSTRAINT uq_schedule_loan_installment
        UNIQUE (loan_id, installment_number);
    END IF;
END $$;
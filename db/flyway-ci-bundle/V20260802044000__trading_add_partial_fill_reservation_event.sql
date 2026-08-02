ALTER TYPE "trading"."reservation_event_type"
    ADD VALUE IF NOT EXISTS 'CONSUMED_BY_FILL' AFTER 'CREATED';

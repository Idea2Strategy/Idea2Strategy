-- Root #181: the existing composite foreign key contains nullable partition_id.
-- PostgreSQL treats a composite FK with any NULL component as satisfied, so bot-wide
-- initial-capital entries need this direct header relationship as well.
ALTER TABLE trading.ledger_entries
    ADD CONSTRAINT ledger_entry_transaction_header_fk
    FOREIGN KEY (transaction_id)
    REFERENCES trading.ledger_transactions(id)
    ON DELETE RESTRICT
    DEFERRABLE INITIALLY IMMEDIATE;

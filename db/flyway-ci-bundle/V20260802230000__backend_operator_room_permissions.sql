-- E30 approved permission catalog entries. Roles remain explicitly assigned by operations.
INSERT INTO operations.permissions (id, code, description, sensitivity)
VALUES
    ('e3000000-0000-4000-8000-000000000001',
     'COMPETITION_ROOM_READ',
     'Read operator-safe official competition room state and result provenance',
     'SENSITIVE'),
    ('e3000000-0000-4000-8000-000000000002',
     'COMPETITION_ROOM_MANAGE',
     'Cancel or invalidate official competition rooms through audited commands',
     'HIGH')
ON CONFLICT (code) DO NOTHING;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM operations.permissions
        WHERE code = 'COMPETITION_ROOM_READ'
          AND description = 'Read operator-safe official competition room state and result provenance'
          AND sensitivity = 'SENSITIVE'
    ) THEN
        RAISE EXCEPTION 'COMPETITION_ROOM_READ conflicts with the approved E30 catalog';
    END IF;
    IF NOT EXISTS (
        SELECT 1
        FROM operations.permissions
        WHERE code = 'COMPETITION_ROOM_MANAGE'
          AND description = 'Cancel or invalidate official competition rooms through audited commands'
          AND sensitivity = 'HIGH'
    ) THEN
        RAISE EXCEPTION 'COMPETITION_ROOM_MANAGE conflicts with the approved E30 catalog';
    END IF;
END
$$;

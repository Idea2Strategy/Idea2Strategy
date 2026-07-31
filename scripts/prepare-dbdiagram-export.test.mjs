import assert from 'node:assert/strict';
import test from 'node:test';

import { removeRecordsBlocks } from './prepare-dbdiagram-export.mjs';

test('removes table-scoped and external Records blocks without changing schema definitions', () => {
  const source = `Project Example {
  database_type: 'PostgreSQL'
}

Table public.users {
  id uuid [pk]
  name varchar(50)

  Records (id, name) {
    '00000000-0000-4000-8000-000000000001', 'Example'
  }

  checks {
    \`char_length(name) > 0\` [name: 'users_name_not_empty']
  }
}

Records public.users(id, name) {
  '00000000-0000-4000-8000-000000000002', 'Second'
}
`;

  const result = removeRecordsBlocks(source);

  assert.equal(result.removedBlocks, 2);
  assert.doesNotMatch(result.dbml, /\bRecords\b/i);
  assert.match(result.dbml, /Table public\.users/);
  assert.match(result.dbml, /checks \{/);
  assert.match(result.dbml, /users_name_not_empty/);
});

test('rejects an unclosed Records block', () => {
  assert.throws(
    () => removeRecordsBlocks("Table users {\n  id int\n  Records (id) {\n    1\n"),
    /Unclosed Records block/,
  );
});

import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

export function removeRecordsBlocks(source) {
  const lines = source.split(/\r?\n/);
  const output = [];
  let inRecords = false;
  let removedBlocks = 0;

  for (const line of lines) {
    if (
      !inRecords
      && /^\s*Records(?:\s+[A-Za-z_][\w."]*)?(?:\s*\([^)]*\))?\s*\{\s*$/i.test(line)
    ) {
      inRecords = true;
      removedBlocks += 1;
      continue;
    }

    if (inRecords) {
      if (/^\s*}\s*$/.test(line)) {
        inRecords = false;
      }
      continue;
    }

    output.push(line);
  }

  if (inRecords) {
    throw new Error('Unclosed Records block in DBML source.');
  }

  return {
    dbml: output.join('\n'),
    removedBlocks,
  };
}

export async function prepareDbdiagramExport(inputPath, outputPath) {
  const source = await readFile(inputPath, 'utf8');
  const result = removeRecordsBlocks(source);

  if (result.removedBlocks === 0) {
    throw new Error('No Records blocks were found; refusing to create an unexpected export copy.');
  }

  await mkdir(dirname(outputPath), { recursive: true });
  await writeFile(outputPath, result.dbml, 'utf8');
  return result;
}

const currentFile = fileURLToPath(import.meta.url);
const invokedFile = process.argv[1] ? resolve(process.argv[1]) : '';

if (currentFile === invokedFile) {
  const inputPath = resolve(process.argv[2] ?? 'db/schema.dbml');
  const outputPath = resolve(
    process.argv[3] ?? '.harness/local/artifacts/dbml-export/schema.no-records.dbml',
  );
  const result = await prepareDbdiagramExport(inputPath, outputPath);
  process.stdout.write(
    `${JSON.stringify({
      input: inputPath,
      output: outputPath,
      removedRecordsBlocks: result.removedBlocks,
    })}\n`,
  );
}

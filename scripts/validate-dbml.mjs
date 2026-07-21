import { readFile } from 'node:fs/promises';
import process from 'node:process';
import { Parser } from '@dbml/core';

const entry = process.argv[2] ?? 'db/schema.dbml';
const source = await readFile(entry, 'utf8');
const database = Parser.parse(source, 'dbmlv2');

const populatedSchemas = database.schemas.filter((schema) => schema.tables.length > 0);
const schemas = populatedSchemas.map((schema) => schema.name);
const tables = populatedSchemas.flatMap((schema) => schema.tables);

process.stdout.write(`${JSON.stringify({ entry, schemas, tableCount: tables.length })}\n`);

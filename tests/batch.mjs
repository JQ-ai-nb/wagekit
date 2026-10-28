#!/usr/bin/env node
// Batch runner for the Python oracle: read an array of wire documents and
// print the array of reports, in order. One node process for all cases.
//
//   node tests/batch.mjs cases.json
import {readFileSync} from 'node:fs';
import {pathToFileURL} from 'node:url';
import {resolve} from 'node:path';

const core = await import(pathToFileURL(resolve(import.meta.dirname, '../dist/wagekit.js')).href);
const cases = JSON.parse(readFileSync(resolve(process.argv[2]), 'utf8'));
const reports = cases.map((c) => JSON.parse(core.run(JSON.stringify(c))));
process.stdout.write(JSON.stringify(reports));

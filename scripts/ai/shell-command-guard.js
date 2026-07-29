#!/usr/bin/env node
'use strict';

let input = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', (chunk) => { input += chunk; });
process.stdin.on('end', () => {
  let event;
  try {
    event = JSON.parse(input);
  } catch (_error) {
    console.error('Blocked: the AI shell safety hook received invalid input.');
    process.exitCode = 2;
    return;
  }

  if (event.tool_name && event.tool_name !== 'Bash') return;
  const command = event.tool_input && event.tool_input.command;
  if (typeof command !== 'string') {
    console.error('Blocked: the AI shell safety hook could not inspect this command.');
    process.exitCode = 2;
    return;
  }

  const normalized = command.replace(/\\\r?\n/g, ' ').replace(/''|""/g, '').replace(/\\(?=(?:[^\s/]+\/)*rm(?:\s|$))/g, '');
  const block = (message) => {
    console.error(message);
    process.exitCode = 2;
  };
  const rmToken = /(?:^|[\s;&|()'"`])(?:[^\s;&|()'"`]+\/)?rm(?=$|[\s;&|()'"`])/g;
  let match;
  while ((match = rmToken.exec(normalized)) !== null) {
    const tail = normalized.slice(match.index + match[0].length).split(/[;&|)\n]/, 1)[0];
    // The flag class includes `{`, `,`, `}` so brace-expanded flags such as
    // `-r{f,}` or `-{r,R}f` (which the shell expands to recursive forms) still
    // fail closed.
    if (/(?:^|\s)--recursive(?:\s|$)/.test(tail) || /(?:^|\s)-[A-Za-z{},]*[rR][A-Za-z{},]*(?:\s|$)/.test(tail)) {
      block('Blocked: AI agents may not run recursive rm. Use lazy-safe-rm with a target inside the current Git workspace.');
      return;
    }
  }

  // `find -delete` removes whole trees without ever spelling `rm`. Scan each
  // command segment (split on ; & | and newlines) for a find carrying -delete.
  for (const segment of normalized.split(/[;&|\n]+/)) {
    if (/(?:^|[\s'"`(])find(?:\s|$)/.test(segment) && /(?:^|\s)-delete(?:\s|$)/.test(segment)) {
      block('Blocked: AI agents may not run recursive deletion via find -delete. Use lazy-safe-rm with a target inside the current Git workspace.');
      return;
    }
  }
});

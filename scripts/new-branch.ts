#!/usr/bin/env npx tsx

/**
 * New Branch Script
 *
 * Branch format: username/TICKET-ID/type-N (e.g. cjatkinson/CRANE-660/feature-1).
 * Types: task, feature, bugfix, misc. N starts at 1 and increments when branches exist; prompts to confirm when N > 1.
 * Initial commit: "TICKET: <Linear issue title>" (e.g. CRANE-660: Fix RLS policy for CRM tables).
 * Optionally creates a PR with that same title (so it reads well in GitHub instead of the branch-name default).
 *
 * Usage: npm run new-branch [-- --ticket CRANE-660]
 */

import { execSync, spawnSync } from 'node:child_process'
import inquirer from 'inquirer'
import yargs from 'yargs'
import { hideBin } from 'yargs/helpers'

const LINEAR_TICKET_PATTERN = /^[A-Za-z]+-\d+$/
const BRANCH_TYPES = ['task', 'feature', 'bugfix', 'misc'] as const
type BranchType = (typeof BRANCH_TYPES)[number]

const ISSUE_HEADING = /^#\s*[A-Za-z]+-\d+\s*:?\s*(.+)$/

/** Parse Linear CLI "issue view" stdout; returns title or null. Exported for tests. */
export function parseLinearIssueTitle(stdout: string): string | null {
  const out = stdout.trim()
  const line = out
    .split('\n')
    .map(l => l.trim())
    .find(l => ISSUE_HEADING.test(l))
  const m = line?.match(ISSUE_HEADING)
  return m ? m[1].trim() : null
}

function getGitHubUsername(): string | null {
  try {
    execSync('which gh', { encoding: 'utf8', stdio: 'pipe' })
    return (
      execSync('gh api user -q .login', { encoding: 'utf8' }).trim() || null
    )
  } catch {
    return null
  }
}

export function normalizeTicket(input: string): string {
  const t = input.trim()
  const m = t.match(/^([A-Za-z]+)-(\d+)$/)
  return m ? `${m[1].toUpperCase()}-${m[2]}` : t
}

export function branchExists(name: string): boolean {
  return (
    spawnSync('git', ['rev-parse', '--verify', `refs/heads/${name}`], {
      encoding: 'utf8',
      stdio: 'pipe',
    }).status === 0
  )
}

/** Return next available base-1, base-2, …; isNumbered when n > 1. Exported for tests; existsFn is injectable. */
export function resolveBranchName(
  base: string,
  existsFn: (name: string) => boolean = branchExists
): { name: string; isNumbered: boolean } {
  let n = 1
  while (existsFn(`${base}-${n}`)) n++
  return { name: `${base}-${n}`, isNumbered: n > 1 }
}

function getIssueTitleFromLinearCli(ticket: string): string | null {
  try {
    const r = spawnSync(
      'npx',
      [
        'dotenvx',
        'run',
        '--',
        'deno',
        'run',
        '-A',
        'jsr:@schpet/linear-cli',
        'issue',
        'view',
        ticket,
      ],
      { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }
    )
    const out = (r.stdout ?? '').trim()
    const err = (r.stderr ?? '').trim()

    if (r.status !== 0 || !out) {
      if (r.status !== 0)
        console.error(
          `[new:branch] Linear CLI exit ${r.status} for "${ticket}".`
        )
      if (err) console.error('[new:branch] stderr:', err)
      if (out) console.error('[new:branch] stdout:', out.slice(0, 400))
      return null
    }

    const title = parseLinearIssueTitle(out)
    if (!title)
      console.error('[new:branch] No "# TICKET-ID: Title" line in output.')
    return title
  } catch (e) {
    console.error('[new:branch] Linear CLI error:', e)
    return null
  }
}

async function main(): Promise<void> {
  const argv = await yargs(hideBin(process.argv))
    .option('ticket', {
      type: 'string',
      alias: 't',
      description: 'Linear ticket (e.g. CRANE-660)',
    })
    .strict()
    .parse()

  const ghUser = getGitHubUsername()

  let ticket: string
  if (argv.ticket) {
    ticket = normalizeTicket(argv.ticket)
    if (!LINEAR_TICKET_PATTERN.test(ticket)) {
      console.error('Invalid ticket. Use TEAM-123 (e.g. CRANE-660).')
      process.exit(1)
    }
  } else {
    const { linearTicket } = await inquirer.prompt<{ linearTicket: string }>([
      {
        type: 'input',
        name: 'linearTicket',
        message: 'Linear ticket (e.g. CRANE-660):',
        validate: (v: string) =>
          LINEAR_TICKET_PATTERN.test(normalizeTicket(v)) ||
          'Use format TEAM-123 (e.g. CRANE-660)',
        filter: (v: string) => v.trim(),
      },
    ])
    ticket = normalizeTicket(linearTicket)
  }

  const { branchType } = await inquirer.prompt<{ branchType: BranchType }>([
    {
      type: 'list',
      name: 'branchType',
      message: 'Branch type:',
      choices: [...BRANCH_TYPES],
    },
  ])

  let username: string
  if (ghUser) {
    username = ghUser
  } else {
    console.log(
      '\nGitHub CLI (gh) not found — enter your username below. To auto-detect next time: https://cli.github.com/\n'
    )
    const { githubUsername } = await inquirer.prompt<{
      githubUsername: string
    }>([
      {
        type: 'input',
        name: 'githubUsername',
        message: 'GitHub username:',
        validate: (v: string) => {
          const s = (v ?? '').trim()
          return (
            (s && /^[a-zA-Z0-9-]+$/.test(s)) || 'GitHub username is required'
          )
        },
      },
    ])
    username = githubUsername.trim()
  }

  const baseName = `${username}/${ticket}/${branchType}`
  const { name: branchName, isNumbered } = resolveBranchName(baseName)

  if (isNumbered) {
    const { proceed } = await inquirer.prompt<{ proceed: boolean }>([
      {
        type: 'confirm',
        name: 'proceed',
        message: `Branches for this ticket already exist. Create "${branchName}"?`,
        default: true,
      },
    ])
    if (!proceed) {
      console.log('Aborted.')
      process.exit(0)
    }
  }

  console.log(`\nBranch: ${branchName}\n`)

  if (
    spawnSync('git', ['checkout', '-b', branchName], { stdio: 'inherit' })
      .status !== 0
  ) {
    process.exit(1)
  }

  let commitTitle = getIssueTitleFromLinearCli(ticket)
  if (!commitTitle) {
    console.log(
      '\n⚠️  Could not fetch title from Linear. Next time: add LINEAR_API_KEY to .env and run npm run linear:config\n'
    )
    commitTitle = (
      await inquirer.prompt<{ title: string }>([
        {
          type: 'input',
          name: 'title',
          message: 'Issue title (for initial commit):',
          validate: (v: string) => (v?.trim() ? true : 'Enter the Linear issue title'),
        },
      ])
    ).title.trim()
  }

  const commitMessage = `${ticket}: ${commitTitle}`
  if (
    spawnSync('git', ['commit', '--allow-empty', '-m', commitMessage], {
      stdio: 'inherit',
    }).status !== 0
  ) {
    process.exit(1)
  }
  console.log(`\nInitial commit: ${commitMessage}\n`)

  const { createPr } = await inquirer.prompt<{ createPr: boolean }>([
    {
      type: 'confirm',
      name: 'createPr',
      message: `Create a pull request? (Title will be: ${commitMessage})`,
      default: true,
    },
  ])

  if (createPr) {
    const push = spawnSync('git', ['push', '-u', 'origin', branchName], {
      encoding: 'utf8',
      stdio: 'inherit',
    })
    if (push.status !== 0) {
      console.error(
        '\nCould not push branch. Fix the error above and run: gh pr create --title "..." --body ""\n'
      )
      process.exit(1)
    }
    const pr = spawnSync(
      'gh',
      [
        'pr',
        'create',
        '--title',
        commitMessage,
        '--body',
        '',
        '--assignee',
        '@me',
      ],
      { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }
    )
    const out = (pr.stdout ?? '').trim()
    const err = (pr.stderr ?? '').trim()
    if (pr.status === 0) {
      const url = out.split('\n').find(line => line.startsWith('http'))
      console.log(url ? `\nPR created: ${url}\n` : `\n${out}\n`)
    } else {
      console.error(
        '\nCould not create PR. Ensure GitHub CLI (gh) is installed and logged in: https://cli.github.com/\n'
      )
      if (err) console.error(err)
    }
  }
}

// Only run when executed as script (not when imported by tests)
if (
  typeof process !== 'undefined' &&
  process.argv[1]?.includes('new-branch.ts')
) {
  main().catch(err => {
    console.error(err)
    process.exit(1)
  })
}

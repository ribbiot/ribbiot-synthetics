import { describe, it, expect, vi } from 'vitest'
import {
  parseLinearIssueTitle,
  normalizeTicket,
  branchExists,
  resolveBranchName,
} from './new-branch'

describe('new-branch script', () => {
  describe('parseLinearIssueTitle', () => {
    it('extracts title from "# TICKET-ID: Title" line', () => {
      const out = '# CRANE-660: Fix RLS policy for CRM tables\n\nSome body'
      expect(parseLinearIssueTitle(out)).toBe('Fix RLS policy for CRM tables')
    })

    it('extracts title when no colon after ticket', () => {
      const out = '# CRANE-660 Fix RLS policy\n\nBody'
      expect(parseLinearIssueTitle(out)).toBe('Fix RLS policy')
    })

    it('returns null when no matching heading', () => {
      expect(parseLinearIssueTitle('Just some text')).toBe(null)
      expect(parseLinearIssueTitle('')).toBe(null)
    })

    it('trims whitespace in title', () => {
      expect(parseLinearIssueTitle('# CRANE-660:   Spaced title  ')).toBe(
        'Spaced title'
      )
    })
  })

  describe('normalizeTicket', () => {
    it('uppercases team prefix', () => {
      expect(normalizeTicket('crane-660')).toBe('CRANE-660')
      expect(normalizeTicket('CRANE-660')).toBe('CRANE-660')
    })

    it('trims input', () => {
      expect(normalizeTicket('  CRANE-660  ')).toBe('CRANE-660')
    })

    it('returns input as-is when not TEAM-N format', () => {
      expect(normalizeTicket('foo')).toBe('foo')
      expect(normalizeTicket('CRANE')).toBe('CRANE')
    })
  })

  describe('resolveBranchName', () => {
    it('returns base-1 when no branch exists', () => {
      const neverExists = vi.fn(() => false)
      expect(resolveBranchName('user/CRANE-660/feature', neverExists)).toEqual({
        name: 'user/CRANE-660/feature-1',
        isNumbered: false,
      })
    })

    it('increments N when base-N exists', () => {
      const exists = vi.fn((name: string) => name === 'user/CRANE-660/feature-1')
      expect(resolveBranchName('user/CRANE-660/feature', exists)).toEqual({
        name: 'user/CRANE-660/feature-2',
        isNumbered: true,
      })
    })

    it('sets isNumbered true when N > 1', () => {
      const exists = vi.fn(
        (name: string) =>
          name === 'user/CRANE-660/feature-1' || name === 'user/CRANE-660/feature-2'
      )
      expect(resolveBranchName('user/CRANE-660/feature', exists)).toEqual({
        name: 'user/CRANE-660/feature-3',
        isNumbered: true,
      })
    })
  })
})

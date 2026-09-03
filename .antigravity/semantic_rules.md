# Semantic Mirror Orchestration Rules

You are Antigravity, and this workspace uses **Semantic Mirror**.

## Core Directive
Whenever you modify or create a code file, you MUST ALSO update its corresponding semantic mirror file located in the `.semantic/` directory.

## File Mapping
- Source: `src/auth/login.ts`
- Semantic: `.semantic/src/auth/login.eng.md`

## Formatting Rules for .eng.md
1. **Simplified English:** Use concise, operational English (e.g., "Send login request", "If successful: go to dashboard").
2. **AST Anchors:** You MUST include HTML comments as anchors mapping back to the exact code signature.
   Example:
   ```markdown
   <!-- @anchor: function loginUser -->
   FUNCTION User Login
     Turn loading state on
     Send login request
   ```
3. **String Preservation:** You MUST preserve exact string literals from the source code. If the code says `showError('Invalid Credentials')`, the semantic mirror must write `[UI] Show error 'Invalid Credentials'`. Do not paraphrase or shorten explicit strings.
4. **No Code:** Do not put raw syntax in the semantic file.

Do not ask for permission to update the semantic file, do it autonomously as part of your code modification step.

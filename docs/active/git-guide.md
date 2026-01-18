# Git Workflow & Standards (Windows/PowerShell)

## 🚨 CRITICAL PROTOCOL: Commit Messages
**Environment:** Windows 11 + VS Code + PowerShell.
**Constraint:** PowerShell interprets hyphens (`-`) at the start of lines as command parameters. This causes standard multi-line `git commit -m "..."` commands to fail.

### ✅ The ONLY Allowed Syntax
When generating commit commands, **ALWAYS** assign the message to a variable using a PowerShell "Here-String" (`@" ... "@`), then pass the variable.

**Example Block:**
```powershell
$msg = @"
feat: Implement Friend Request Logic

Frontend:
- Updated find-friends.jsx to use .upsert()
- Changed rejection logic to Hard Delete

Database:
- Added RLS policies for INSERT/UPDATE/DELETE
"@

git commit -m $msg
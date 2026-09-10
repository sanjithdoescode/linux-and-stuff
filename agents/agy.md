 The Antigravity Customization System allows you to tailor agent behavior, enforce codebase guidelines, teach workflows, and integrate external tools.
  ──────
  ### Customization Types

   Type                         | Location / Format                        | Best For                                                                   | Scope
  ------------------------------|------------------------------------------|----------------------------------------------------------------------------|-----------------------------
   Rules                        | GEMINI.md, AGENTS.md, .agents/rules/*.md | Enforcing coding styles, architectural patterns, constraints               | Contextual / Hierarchical
   Skills                       | .agents/skills/<name>/SKILL.md           | Teaching multi-step workflows, runbooks, and procedures                    | Progressive / On-demand
   Plugins                      | .agents/plugins/<name>/plugin.json       | Packaging related skills, rules, and MCP configs into a bundle             | Workspace / Global
   Hooks                        | hooks.json                               | Running scripts/commands on lifecycle events (e.g., pre-tool execution)    | Lifecycle Event
   MCP Servers                  | mcp_config.json                          | Connecting the agent to external tools and APIs via Model Context Protocol | Tool Integration
  ──────
  ### Discovery & Precedence

  Antigravity checks for customizations across workspace and machine-level locations:

  1. Workspace Project (Highest Priority): .agents/ directory traversing from CWD up to repository root (.git).
  2. Directory & File Rules: GEMINI.md / AGENTS.md in project subdirectories.
  3. Declared Configs: Registered explicitly in skills.json or plugins.json.
  4. Global Configuration: ~/.gemini/config/ (Applies across all projects on your machine).
  5. Built-in System Skills: Bundled default skills mounted by name.
  ──────
  ### Progressive Disclosure

  To preserve context window capacity:

  • Skills: Only names and descriptions are initially loaded into context. Full skill contents load dynamically when activated.
  • Rules: always_on rules load unconditionally; model_decision rules load dynamically when relevant.
  ──────
  ### How can I help you customize your environment?

  • Create a Workspace Rule (GEMINI.md or .agents/rules/)
  • Build a Custom Skill (.agents/skills/<name>/SKILL.md)
  • Configure an MCP Server (mcp_config.json)
  • Set up Lifecycle Hooks (hooks.json)

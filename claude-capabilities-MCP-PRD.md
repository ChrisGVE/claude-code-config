# claude-capabilities MCP - Product Requirements Document

## Overview

The claude-capabilities MCP is a specialized MCP server that handles dynamic capability management for Claude Code projects. It detects project capabilities from PRDs, installs required MCPs and subagents, and manages the project initialization lifecycle.

## Core Functionality

### Scope Definition

**Core Capabilities**:
- **Capability Detection**: Parse PRDs to identify required project capabilities
- **Capability Installation**: Deploy matching MCPs and subagents based on registry
- **Project Initialization**: Set up complete project structure and configuration

**Extended Capabilities**:
- **Capability Uplift**: Add new capabilities during development phases
- **Agent Customization Pipeline**: Integrate with community agent ecosystem

**Implementation Requirements**:
- **Python-based**: Built using claude-code-sdk
- **Dual-mode**: Functions as both stdio MCP server AND standalone CLI tool
- **Registry-driven**: Uses `resources/registry.yaml` for capability mapping

## Technical Specifications

### Project Initialization Flow

**Dual-Mode Operation**:
The claude-capabilities MCP handles two distinct initialization scenarios through a single MCP API entry point.

**Input**: PRD content + project root path + initialization context
**Output**: Fully configured Claude Code project + status report

**Mode Detection**:
```python
def detect_initialization_mode(project_root: Path) -> InitMode:
    """Determine if this is new project or existing project initialization"""
    if (project_root / ".claude").exists():
        return InitMode.EXISTING_PROJECT
    else:
        return InitMode.NEW_PROJECT
```

#### **Mode A: Brand New Project**
**Scenario**: Single PRD file (template/draft), potentially some pre-installed agents/MCPs
**Key Principle**: Registry-driven workflow with complete scaffolding setup

**Trigger**: System prompt triggers claude-capabilities MCP with:
- PRD file location 
- Project type indicator: `new_project`

**Registry-Driven Execution**: All steps and tasks defined in global registry workflows section

#### **Workflow A: Brand New Project Initialization**

**Overview**: Multi-phase iterative workflow with dynamic capability management and task-driven configuration.

## **STEP 1: Project Scaffolding Setup**

**Purpose**: Hook up new project with scaffolding infrastructure (no configuration yet)

**Registry Configuration**: `workflows.new_project.step.1`

**Task Sequence**:

**Task 1 - Git Repository Check:**
- Check if repository initialized
- If staged files exist: commit with message "Committing staged files before setting up project"
- If no repository: skip task
- **Registry Syntax**: `git: dirty: yes, command: "git commit -am", message: "..."`

**Task 2 - CLAUDE.md Backup:**
- Check existence of CLAUDE.md
- If exists: backup as CLAUDE.md.backup (preserve user's existing configuration)
- **Registry Syntax**: `file: action: "move_within_project", source: "CLAUDE.md", target: "CLAUDE.md.backup", if_exists: yes`

**Task 3 - Folder and File Creation:**
- Create required folder structure: `.claude/agents/`, `.claude/hooks/`, `.claude/commands/`
- Create files: registry template, task-master standard configuration
- Copy specialized Step 2 system prompt into CLAUDE.md (prepare for next step)
- **Registry Syntax**: `directory:` and `file: action: "copy_into_project"` operations with global template sources

**Task 4 - Project Registry Population:**
- Populate project registry with agents already installed in `.claude/agents/`
- Check existing project MCPs from `.claude.json`  
- **Registry Syntax**: `project_registry: action: "sync"`

**Task 5 - Agent Installation:**
- Install necessary agents (defined in global registry workflows section)
- Hook agents up to project registry
- **Registry Syntax**: `project_registry: action: "deploy_agent", agent_name: "planner"`

**Process**:
```python
def step1_scaffolding_setup(project_root: Path, prd_location: str) -> ScaffoldingResult:
    """Execute registry-defined scaffolding tasks"""
    # Load workflow from registry
    workflow = load_registry_workflow("new_project", step=1)
    
    # Execute each task in sequence
    for task in workflow.tasks:
        execute_registry_task(task, project_root)
    
    return ScaffoldingResult(
        agents_installed=True,
        project_structure_created=True,
        step2_ready=True
    )
```

## **STEP 2: PRD Iterative Refinement**

**Purpose**: Work iteratively with user on PRD until complete and confirmed

**Registry Configuration**: `workflows.new_project.step.2`

**Task Sequence**:

**Task 1 - Context Clear:**
- Clear context to load agents installed in Step 1 (equivalent of `/clear` command)
- **Registry Syntax**: `claude: action: clear_context` (pending SDK capability research)
- **Fallback**: Prompt user to quit and relaunch Claude if SDK doesn't support automation

**Task 2 - Prompt Injection and User Handoff:**
- Inject specialized PRD refinement prompt from `prompts/CLAUDE.md.step2`
- Hand control to Claude for iterative user interaction
- **Registry Syntax**: `claude: action: prompt_and_over_to_user, prompt: "[PRD refinement prompt]"`

**Iterative Process**:
- Available agents: research agents, prompt specialist, architect, etc.
- Process varies by PRD state:
  - **Empty template**: Everything must be defined
  - **Existing draft**: Review, identify gaps, contradictions, challenge design
- Continue until PRD complete and user confirms readiness

**Process**:
```python
def step2_prd_refinement(project_root: Path) -> PRDRefinementResult:
    """Execute context clear and prompt injection, hand control to Claude"""
    # Load Step 2 workflow from registry
    workflow = load_registry_workflow("new_project", step=2)
    
    # Execute context clear (if SDK supports)
    if claude_sdk_supports_context_clear():
        execute_claude_action("clear_context")
    else:
        prompt_user_to_restart_claude()
    
    # Inject PRD refinement prompt and hand control to user
    prd_prompt = load_step2_prompt()
    execute_claude_action("prompt_and_over_to_user", prompt=prd_prompt)
    
    # Control handed to Claude for iterative PRD work with user
    # Return when system prompt detects PRD completion and user confirmation
    return PRDRefinementResult(prd_ready_for_step3=True)
```

**Completion Trigger**: System prompt detects PRD completion and user confirmation, then triggers Step 3

**SDK Research Dependencies**:
- Context clearing automation capability
- Prompt injection and control handoff capability
- Message sending capability for user communication

## **STEP 3: Task-master Initialization and Execution Setup**

**Purpose**: Initialize task-master, generate capability requirements, deploy for execution

**Registry Configuration**: `workflows.new_project.step.3`

**Task Sequence**:

**Task 1 - Task-master Initialization:**
- Initialize task-master with refined PRD (variable filename received from Claude)
- Task-master generates complete task DAG according to PRD specifications
- **Registry Syntax**: `task-master: action: init, prd_file: [dynamic]` (syntax TBD based on integration approach)

**Task 2 - Capability Requirements Generation:**
- Retrieve each task from task-master (CLI/MCP-to-MCP/direct integration)
- Deploy capability analysis subagent to generate required capabilities per task
- Update tasks with capability requirements for dynamic deployment
- **Integration Dependencies**: TBD based on task-master integration research and capability storage solution

**Task 3 - System Prompt Replacement and Agent Cleanup:**
- Replace CLAUDE.md with main production system prompt
- Undeploy initialization-specific subagents (planner, architect, etc.)
- **Registry Syntax**: `project_registry: action: undeploy_agent, name: ["planner", "architect", "prompt-specialist"]`

**Task 4 - Task 1 Execution Preparation:**
- Deploy agents/MCPs needed for task-master's first task execution
- **Implementation**: TBD based on chosen task-master integration approach
- **Registry Syntax**: `project_registry: action: deploy_agent, name: [task1_required_agents]`

**Task 5 - Context Clear:**
- Clear context for production execution phase
- **Registry Syntax**: `claude: action: clear_context`

**Task 6 - Final User Handoff:**
- Hand complete control back to user with full system operational
- **Registry Syntax**: `claude: action: prompt_and_over_to_user, prompt: "Project initialization complete..."`

**Process**:
```python
def step3_taskmaster_initialization(project_root: Path, prd_file: str) -> InitializationResult:
    """Execute complete task-master setup and capability deployment"""
    # Load Step 3 workflow from registry
    workflow = load_registry_workflow("new_project", step=3)
    
    # Initialize task-master with refined PRD
    taskmaster_result = execute_taskmaster_action("init", prd_file=prd_file)
    
    # Generate capability requirements for each task
    tasks = get_all_tasks_from_taskmaster()
    for task in tasks:
        capabilities = generate_task_capabilities(task)
        update_task_capabilities(task.id, capabilities)
    
    # System cleanup and deployment
    cleanup_initialization_agents()
    deploy_task1_capabilities(tasks[0])
    
    # Final handoff
    execute_claude_action("clear_context")
    execute_claude_action("prompt_and_over_to_user", 
                         prompt="Project initialization complete. All systems ready.")
    
    return InitializationResult(
        taskmaster_initialized=True,
        capabilities_mapped=True,
        user_ready=True
    )
```

**Completion**: All initialization complete, user has control with task-master and full capability system operational

**Research Dependencies**:
- Task-master integration approach (CLI/MCP-to-MCP/direct)
- Capability storage and retrieval mechanism  
- Dynamic capability deployment on task transitions

## **STEP 2: Project Planning & Task Generation Phase**

**Dynamic Reconfiguration**:
- **Reconfigure agents, MCPs, and prompts** according to Step 2 registry configuration
- **Capability-aware task planning** with embedded capability requirements

**Process**:
```python
def step2_project_planning(project_root: Path, refined_prd: str) -> ProjectPlan:
    """Generate tasks with embedded capability requirements"""
    # Reconfigure environment for Step 2
    step2_config = get_registry_step_config("step2")
    reconfigure_environment(step2_config, project_root)
    
    # Pass PRD to task-master via CLI
    tasks_json = call_task_master_cli(
        command="parse-prd",
        prd_content=refined_prd,
        project_root=project_root
    )
    
    # Fetch generated tasks via CLI
    raw_tasks = call_task_master_cli(
        command="get-tasks", 
        project_root=project_root
    )
    
    # Analyze each task for capability requirements
    for task in raw_tasks:
        task.required_capabilities = analyze_task_capabilities(
            task_description=task.description,
            task_details=task.details,
            registry_capabilities=get_all_registry_capabilities()
        )
        
        # Store capability requirements as part of task record
        update_task_with_capabilities(task.id, task.required_capabilities)
    
    return ProjectPlan(
        tasks=raw_tasks,
        capability_manifest=aggregate_capabilities(raw_tasks)
    )
```

## **STEP 3: Project Start & Task Execution Setup**

**Dynamic System Configuration**:
- **Configure system for first task execution**
- **Embed capability management in task execution prompt**
- **Context management integration** (clear context via API, MCP on/off)

**Process**:
```python
def step3_execution_setup(project_plan: ProjectPlan, project_root: Path) -> ExecutionSetup:
    """Setup dynamic task execution with capability management"""
    # Configure for first task
    first_task = project_plan.get_next_task()
    
    # Setup capability-aware execution environment
    setup_task_execution_environment(
        task=first_task,
        required_capabilities=first_task.required_capabilities,
        project_root=project_root
    )
    
    # Configure prompt to call our MCP before each task
    execution_prompt = generate_task_execution_prompt(
        base_prompt=get_registry_execution_prompt(),
        mcp_integration=True,
        capability_management=True
    )
    
    # Test context management APIs
    context_apis = test_context_management_apis()
    
    return ExecutionSetup(
        execution_prompt=execution_prompt,
        context_management=context_apis,
        first_task_ready=True
    )
```

## **ITERATIVE EXECUTION CYCLE**

**Per-Task Dynamic Reconfiguration**:
```python
def execute_task_with_capability_management(task: Task) -> TaskResult:
    """Execute task with pre-task capability reconfiguration"""
    # Before task execution: reconfigure capabilities
    if task.required_capabilities != current_environment.capabilities:
        # Call our MCP to reconfigure
        reconfigure_result = claude_capabilities_mcp.reconfigure(
            current_capabilities=current_environment.capabilities,
            required_capabilities=task.required_capabilities,
            project_root=project_root
        )
        
        # Handle context clearing if needed
        if reconfigure_result.requires_context_clear:
            clear_context_via_api()
            toggle_mcps(off=reconfigure_result.mcps_to_disable)
            toggle_mcps(on=reconfigure_result.mcps_to_enable)
    
    # Deploy necessary subagents for task execution
    deploy_task_subagents(task.required_capabilities)
    
    # Execute task
    result = claude_execute_task(task)
    
    return result
```

**Critical Integration Points**:
1. **Context Management API**: Can we clear context programmatically?
2. **MCP Toggle Control**: Can we turn MCPs on/off dynamically?
3. **Task-Capability Binding**: Store capability requirements with each task
4. **Dynamic Reconfiguration**: Change environment between tasks

#### **Mode B: Existing Project** 
**Scenario**: Project with/without framework installed
**Key Principle**: Check existing state, fill gaps incrementally

**Workflow B**:
- Audit existing `.claude/` structure
- Identify missing components vs registry requirements
- Incremental installation of missing pieces
- Preserve existing configurations

### Capability Detection Algorithm

**Registry Structure Reference**:
```yaml
mcps:
  qa-mcp:
    capabilities: ["testing", "qa", "e2e"]
    integration: "qa-mcp --port 8082"
  corrode:
    capabilities: ["rust", "cargo.toml"]
    integration: "corrode-mcp"

subagents:
  backend-engineer:
    capabilities: ["backend", "api", "database"]
    phases: ["development", "implementation"]
    deployment: "on-demand"
```

**Detection Process**:
1. Load registry.yaml from `resources/registry.yaml`
2. Scan PRD text for capability keywords
3. Map detected capabilities to required MCPs and subagents
4. Return installation manifest

### Project Structure Creation

**Registry-Driven Structure**:
All project structure is defined in the registry, not hardcoded in the MCP.

**Registry Structure Processing**:
```python
def create_project_structure(registry: Dict, project_root: Path) -> None:
    """Create complete project structure from registry specification"""
    
    # Create directories
    for folder in registry.get("folders", []):
        (project_root / folder).mkdir(parents=True, exist_ok=True)
    
    # Create files (both inline content and source-copied)
    for file_spec in registry.get("files", []):
        target_path = project_root / file_spec["file"]
        
        if "content" in file_spec:
            # Inline content - write directly
            target_path.write_text(file_spec["content"])
        elif "source" in file_spec:
            # Copy from source file
            source_path = Path(file_spec["source"])
            shutil.copy2(source_path, target_path)
        else:
            raise ValueError(f"File spec missing 'content' or 'source': {file_spec}")
    
    # Copy template files (prompts section)
    for prompt_name, prompt_spec in registry.get("prompts", {}).items():
        source_path = Path(prompt_spec["source"])
        target_path = project_root / prompt_spec["target"]
        shutil.copy2(source_path, target_path)
```

**Enhanced Registry File Specification**:
```yaml
folders:
  - ".claude/agents"
  - ".claude/hooks"
  - ".claude/commands"

files:
  # Content-defined files (inline content)
  - file: ".claude/settings.json"
    content: "{}"
  
  # Source-copied files (copy from source to target)
  - file: ".gitignore"
    source: "/Users/chris/dev/ai/claude-code-cfg/templates/.gitignore.template"
  
  - file: "CLAUDE.md"
    source: "/Users/chris/dev/ai/claude-code-cfg/prompts/CLAUDE.md.template"
    
  - file: "CLAUDE_SYSTEM.md" 
    source: "/Users/chris/dev/ai/claude-code-cfg/prompts/CLAUDE_SYSTEM.md"

prompts:
  # Legacy support - consider migrating to files section
  claude-md:
    source: "/Users/chris/dev/ai/claude-code-cfg/prompts/CLAUDE.md.template"
    target: "CLAUDE.md"
```

**File Creation Flexibility**:
- **Inline Content**: Simple configurations, empty files, JSON templates
- **Source Copying**: Complex templates, boilerplate files, system prompts
- **No Hardcoding**: All project structure comes from registry specification

### MCP Installation Process

**Command Format**:
```bash
claude mcp add {mcp_name} -- {integration_command}
```

**Error Handling**:
- Continue with remaining MCPs if individual installation fails
- Report failed installations to user
- Do not block project initialization on MCP failures

**Validation**:
- Execute `claude mcp list` after all installations
- Parse output to identify connected vs failed servers
- Report status summary to user

## Integration Patterns

### Claude Code SDK Integration

**Required SDK Components**:
- MCP server framework for stdio mode
- CLI argument parsing for standalone mode
- File system operations for project structure creation
- Process execution for MCP installation commands

### Registry Management

**Registry Location**: `/Users/chris/dev/ai/claude-code-cfg/resources/registry.yaml`  
**Global Registry Parameter**: Defined globally when starting the claude-capabilities MCP server

**Registry Schema** (extensible YAML structure):
- **MCPs**: capability mapping, integration commands, replacement patterns
- **Subagents**: capability mapping, phase assignment, deployment configuration
- **Templates**: system prompt and project file templates
- **Project Structure**: required folders and default files
- **Step Configurations**: step1/step2/step3 specific agent/MCP/prompt configurations (extensible)

**Research Dependencies**:
- **Task-master Analysis**: Phase 1 prerequisite for understanding CLI commands and integration patterns
- **Documentation Sources**:
  - Task-master repository: https://github.com/eyaltoledano/claude-task-master
  - Task-master docs: https://docs.task-master.dev/introduction
  - Claude Code SDK: https://docs.anthropic.com/en/docs/claude-code/sdk  
  - Claude API: https://docs.anthropic.com/en/api/overview
- **Memory Storage**: All research findings stored in Qdrant for claude-capabilities MCP design

### Error Recovery Strategy

**Philosophy**: Graceful degradation - continue initialization even if components fail

**Error Categories**:
1. **Registry Parse Errors**: Fail fast with clear error message
2. **File System Errors**: Retry with fallback paths, report specific failures
3. **MCP Installation Errors**: Continue with remaining MCPs, report failures
4. **Validation Errors**: Report but don't block completion

## User Experience

### Initialization Workflow

**New Project**:
1. User creates project directory and adds PRD.txt
2. User invokes claude-capabilities MCP (via Claude Code system prompt)
3. MCP analyzes PRD, creates project structure, installs capabilities
4. User receives summary of installed components and any failures
5. Project ready for Claude Code development workflow

**Existing Project Upgrade**:
1. PRD updated with new requirements
2. User invokes capability uplift
3. MCP detects new capabilities, installs additional components
4. Existing configuration preserved, new capabilities added

### Command Interface

**Stdio MCP Mode** (primary):
- Integrated into Claude Code MCP ecosystem
- Called automatically during project initialization
- Provides structured responses for Claude Code consumption

**CLI Mode** (debugging/standalone):
- `claude-capabilities init <project_path>` - Initialize new project
- `claude-capabilities uplift <project_path>` - Add new capabilities
- `claude-capabilities validate <project_path>` - Check project status

## Development Requirements

### Dependencies

**Core Requirements**:
- Python 3.9+
- claude-code-sdk
- PyYAML (registry parsing)
- pathlib (file operations)

**Optional Dependencies**:
- subprocess (MCP installation)
- json (configuration files)

### Testing Strategy

**Unit Tests**:
- Registry parsing logic
- Capability detection algorithms
- Project structure creation
- Configuration file generation

**Integration Tests**:
- End-to-end project initialization
- MCP installation validation
- Error recovery scenarios
- Registry format compatibility

**Manual Testing**:
- Claude Code integration
- Real project initialization flows
- Community registry compatibility

## Future Enhancements

### Phase 2 Extensions

**Advanced Capability Detection**:
- Semantic analysis of PRD content
- Dependency graph resolution
- Capability conflict detection

**Enhanced Registry Features**:
- Version constraints and compatibility matrix
- Community registry federation
- Automatic registry updates

**Dynamic Reconfiguration**:
- Mid-project capability changes
- Context reset workflows
- State preservation during reconfiguration

## Success Metrics

**Primary Metrics**:
- Successful project initialization rate (target: >95%)
- Time to complete initialization (target: <30 seconds)
- MCP installation success rate (target: >90%)

**Secondary Metrics**:
- User error recovery rate
- Registry accuracy (capabilities match actual project needs)
- Community adoption of registry format
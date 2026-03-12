---
name: langgraph
description: LangGraph — state graphs, tool orchestration, reasoning loops, human-in-the-loop, memory, streaming, and sub-graphs.
---

# LangGraph

## When to Use

Use this skill when building agentic workflows with LangGraph 0.2+. Covers state graph construction, tool integration, reasoning and routing patterns, human-in-the-loop flows, memory/checkpointing, streaming, and sub-graph composition.

For Cypher query patterns, see the **neo4j-cypher** skill. For graph data modeling, see the **neo4j-data-models** skill. For Neo4j Python driver specifics, see the **neo4j-driver-python** skill. For API endpoints that serve your agent, see the **fastapi** skill. For testing agent workflows, see the **testing-pytest** skill.

## 1. State Graphs

### Defining State

State is a `TypedDict` (or Pydantic `BaseModel`) shared across all nodes. Use `Annotated` with reducer functions to control how nodes update list-type fields.

```python
from typing import Annotated, TypedDict
from langchain_core.messages import BaseMessage
import operator

class AgentState(TypedDict):
    messages: Annotated[list[BaseMessage], operator.add]
    query: str
    results: Annotated[list[dict], operator.add]
    is_sufficient: bool
    research_loop_count: int
```

Without a reducer, each node's return value **replaces** the field. With `operator.add`, returned lists are **appended** to the existing value.

### Building and Compiling

```python
from langgraph.graph import StateGraph, START, END

builder = StateGraph(AgentState)

# Add nodes — each is a function(state) -> partial state dict
builder.add_node("research", research_node)
builder.add_node("evaluate", evaluate_node)
builder.add_node("respond", respond_node)

# Add edges — fixed transitions
builder.add_edge(START, "research")
builder.add_edge("respond", END)

# Add conditional edges — dynamic routing
builder.add_conditional_edges(
    "evaluate",
    route_after_evaluation,
    {"research": "research", "respond": "respond"},
)
builder.add_edge("research", "evaluate")

graph = builder.compile()
```

### Invoking

```python
result = graph.invoke({
    "messages": [],
    "query": "Do we have a Customer 360 use case for telco?",
    "results": [],
    "is_sufficient": False,
    "research_loop_count": 0,
})
```

## 2. Tool Integration

### Defining Tools

The `@tool` decorator creates tools the LLM can call. **Docstrings are critical** — the LLM reads them to decide which tool to use and how to call it.

```python
import os
from langchain_core.tools import tool
from neo4j import AsyncGraphDatabase

driver = AsyncGraphDatabase.driver(
    os.environ["NEO4J_URI"],
    auth=(os.environ["NEO4J_USER"], os.environ["NEO4J_PASSWORD"]),
)

@tool
async def search_use_cases(vertical: str, topic: str) -> str:
    """Search the knowledge graph for use cases matching a vertical and topic.

    Use when someone asks "do we have a use case for X?" or "what assets
    exist for Y vertical?". Returns use case titles, descriptions, and
    links to source materials.

    Args:
        vertical: Industry vertical (e.g. "financial-services", "pharma", "telco")
        topic: Use case topic (e.g. "customer-360", "fraud-detection", "supply-chain")
    """
    async with driver.session() as session:
        result = await session.run(
            """
            MATCH (uc:UseCase)-[:TARGETS]->(v:Vertical {name: $vertical})
            WHERE uc.topic CONTAINS $topic OR uc.title CONTAINS $topic
            OPTIONAL MATCH (uc)-[:HAS_ASSET]->(a:Asset)
            RETURN uc.title AS title, uc.description AS description,
                   collect(a.url) AS assets
            ORDER BY uc.updatedAt DESC
            LIMIT 10
            """,
            vertical=vertical,
            topic=topic,
        )
        records = [r.data() async for r in result]
    if not records:
        return f"No use cases found for {vertical} / {topic}."
    return "\n".join(
        f"- {r['title']}: {r['description']} (assets: {', '.join(r['assets'])})"
        for r in records
    )


@tool
async def search_reference_customers(
    vertical: str, use_case: str
) -> str:
    """Find reference customers for a specific vertical and use case.

    Use when someone asks "do we have a reference customer for X?" or
    "who's using Neo4j for Y?". Returns customer names and brief descriptions.

    Args:
        vertical: Industry vertical
        use_case: The use case they implemented
    """
    async with driver.session() as session:
        result = await session.run(
            """
            MATCH (c:Customer)-[:IMPLEMENTED]->(uc:UseCase)-[:TARGETS]->(v:Vertical {name: $vertical})
            WHERE uc.topic CONTAINS $use_case AND c.isPublicReference = true
            RETURN c.name AS customer, uc.title AS useCase, c.summary AS summary
            LIMIT 5
            """,
            vertical=vertical,
            use_case=use_case,
        )
        records = [r.data() async for r in result]
    if not records:
        return f"No public references found for {vertical} / {use_case}."
    return "\n".join(
        f"- {r['customer']}: {r['useCase']} — {r['summary']}"
        for r in records
    )


@tool
async def get_newest_content(limit: int = 5) -> str:
    """Get the most recently published or updated content and use cases.

    Use when someone asks "what's new?" or "what are the newest use cases?"
    or "what content was published recently?".

    Args:
        limit: Number of recent items to return (default 5)
    """
    async with driver.session() as session:
        result = await session.run(
            """
            MATCH (uc:UseCase)
            OPTIONAL MATCH (uc)-[:TARGETS]->(v:Vertical)
            RETURN uc.title AS title, uc.description AS description,
                   collect(v.name) AS verticals, uc.updatedAt AS updated
            ORDER BY uc.updatedAt DESC
            LIMIT $limit
            """,
            limit=limit,
        )
        records = [r.data() async for r in result]
    if not records:
        return "No recent content found."
    return "\n".join(
        f"- [{r['updated']}] {r['title']} ({', '.join(r['verticals'])})"
        for r in records
    )
```

### Binding Tools to a Model

```python
from langchain_anthropic import ChatAnthropic

model = ChatAnthropic(model="claude-sonnet-4-20250514")

tools = [search_use_cases, search_reference_customers, get_newest_content]
model_with_tools = model.bind_tools(tools)
```

### ToolNode for Automatic Execution

`ToolNode` executes whatever tool the LLM selected — no manual dispatching needed.

```python
from langgraph.prebuilt import ToolNode

tool_node = ToolNode(tools)
```

When the LLM returns a message with `tool_calls`, pass that message to `ToolNode` and it invokes the correct tool with the correct arguments.

## 3. Reasoning and Routing

This section covers the most critical aspect of agentic design: **how the agent decides what it knows, what it still needs, and which tool to call next.**

### How LLMs Select Tools

When you call `model.bind_tools(tools)`, LangGraph sends the tool schemas (name, description, parameters) to the LLM alongside the conversation. The LLM then either:

1. **Returns a regular message** — it has enough information to answer directly
2. **Returns a message with `tool_calls`** — it needs more information from a specific tool

The LLM picks tools based on the **docstring** and **parameter descriptions**. This is why tool docstrings must clearly state: what the tool does, when to use it, and what each parameter means.

### The Core Routing Function

The most fundamental routing pattern checks whether the LLM wants to call a tool or respond directly.

```python
from langchain_core.messages import AIMessage

def should_continue(state: AgentState) -> str:
    """Route based on whether the LLM made a tool call."""
    last_message = state["messages"][-1]
    if isinstance(last_message, AIMessage) and last_message.tool_calls:
        return "tools"
    return "respond"

builder.add_conditional_edges(
    "agent",
    should_continue,
    {"tools": "tool_node", "respond": "respond"},
)
```

### The Agent-Tool Loop

The standard agentic loop lets the LLM call tools repeatedly until it decides it has enough information.

```python
from langgraph.graph import StateGraph, START, END
from langgraph.prebuilt import ToolNode
from langchain_core.messages import AIMessage, SystemMessage

async def agent_node(state: AgentState) -> dict:
    """Invoke the LLM with tools and the current conversation."""
    system = SystemMessage(content=(
        "You are a knowledge assistant for Neo4j's Industries team. "
        "You help field teams find use cases, presentations, demos, "
        "reference customers, and enablement materials. "
        "Search the knowledge graph before answering. "
        "If results seem incomplete, try different search terms or "
        "check adjacent verticals."
    ))
    messages = [system] + state["messages"]
    response = await model_with_tools.ainvoke(messages)
    return {"messages": [response]}


def should_continue(state: AgentState) -> str:
    last_message = state["messages"][-1]
    if isinstance(last_message, AIMessage) and last_message.tool_calls:
        return "tools"
    return END


builder = StateGraph(AgentState)
builder.add_node("agent", agent_node)
builder.add_node("tools", ToolNode(tools))
builder.add_edge(START, "agent")
builder.add_conditional_edges("agent", should_continue, {"tools": "tools", END: END})
builder.add_edge("tools", "agent")  # After tools run, go back to agent

graph = builder.compile()
```

The agent naturally loops: call LLM → LLM picks tool → execute tool → return to LLM → LLM picks another tool or responds. The LLM itself decides when to stop calling tools.

### Information Sufficiency Pattern

For complex research tasks, add an explicit **reflection node** that evaluates whether gathered information is sufficient before responding.

```python
import json
from typing import Annotated, TypedDict
import operator

class ResearchState(TypedDict):
    messages: Annotated[list[BaseMessage], operator.add]
    query: str
    results: Annotated[list[dict], operator.add]
    is_sufficient: bool
    knowledge_gap: str
    research_loop_count: int
    max_research_loops: int

async def research_node(state: ResearchState) -> dict:
    """Gather information using tools."""
    system = SystemMessage(content=(
        "Search for information relevant to the user's query. "
        "If previous results were insufficient, try: "
        "1) Different search terms, 2) Adjacent verticals, "
        "3) Broader or narrower topic scope. "
        f"Knowledge gap to address: {state.get('knowledge_gap', 'none identified yet')}"
    ))
    messages = [system] + state["messages"]
    response = await model_with_tools.ainvoke(messages)
    return {"messages": [response], "research_loop_count": state["research_loop_count"] + 1}


async def reflect_node(state: ResearchState) -> dict:
    """Evaluate whether gathered information is sufficient to answer."""
    reflection_prompt = SystemMessage(content=(
        "Review the information gathered so far. Evaluate:\n"
        "1. Does the information directly answer the user's query?\n"
        "2. Are there important aspects of the query not yet covered?\n"
        "3. Would searching with different terms or in adjacent verticals help?\n\n"
        "Respond with a JSON object:\n"
        '{"is_sufficient": true/false, "knowledge_gap": "what is still missing"}'
    ))
    messages = [reflection_prompt] + state["messages"]
    response = await model.ainvoke(messages)  # No tools — pure reasoning
    try:
        evaluation = json.loads(response.content)
        return {
            "messages": [response],
            "is_sufficient": evaluation["is_sufficient"],
            "knowledge_gap": evaluation.get("knowledge_gap", ""),
        }
    except (json.JSONDecodeError, KeyError):
        return {
            "messages": [response],
            "is_sufficient": False,
            "knowledge_gap": "reflection parse error — retrying",
        }


def route_after_reflection(state: ResearchState) -> str:
    """Decide: continue researching or finalize the answer."""
    if state["research_loop_count"] >= state.get("max_research_loops", 3):
        return "respond"  # Hit max loops — answer with what we have
    if state["is_sufficient"]:
        return "respond"
    return "research"  # Keep looking


async def respond_node(state: ResearchState) -> dict:
    """Generate final response from gathered information."""
    system = SystemMessage(content=(
        "Based on all the information gathered, provide a comprehensive "
        "answer to the user's query. Include specific asset links where "
        "available. If information is incomplete, say so explicitly."
    ))
    messages = [system] + state["messages"]
    response = await model.ainvoke(messages)
    return {"messages": [response]}


builder = StateGraph(ResearchState)
builder.add_node("research", research_node)
builder.add_node("tools", ToolNode(tools))
builder.add_node("reflect", reflect_node)
builder.add_node("respond", respond_node)

def route_after_research(state: ResearchState) -> str:
    """Route to tools if LLM made a tool call, otherwise reflect."""
    last_message = state["messages"][-1]
    if isinstance(last_message, AIMessage) and last_message.tool_calls:
        return "tools"
    return "reflect"


builder.add_edge(START, "research")
builder.add_conditional_edges(
    "research",
    route_after_research,
    {"tools": "tools", "reflect": "reflect"},
)
builder.add_edge("tools", "research")
builder.add_conditional_edges(
    "reflect",
    route_after_reflection,
    {"research": "research", "respond": "respond"},
)
builder.add_edge("respond", END)

graph = builder.compile()
```

### Multi-Tool Routing with Command

When different tools need different post-processing, route explicitly with `Command`.

```python
from langgraph.types import Command
from typing import Literal

async def router_node(
    state: AgentState,
) -> Command[Literal["neo4j_lookup", "web_search", "respond"]]:
    """Decide which tool category to use based on the query."""
    system = SystemMessage(content=(
        "Classify the user's intent:\n"
        "- 'neo4j_lookup': Questions about existing use cases, assets, "
        "references, or content in our knowledge graph\n"
        "- 'web_search': Questions about external market data, competitor "
        "info, or topics not in our knowledge graph\n"
        "- 'respond': Simple greetings, clarifications, or questions "
        "you can answer from conversation context alone\n\n"
        "Respond with exactly one of: neo4j_lookup, web_search, respond"
    ))
    messages = [system] + state["messages"]
    response = await model.ainvoke(messages)
    route = response.content.strip().lower()

    if route == "web_search":
        return Command(goto="web_search", update={"messages": [response]})
    elif route == "neo4j_lookup":
        return Command(goto="neo4j_lookup", update={"messages": [response]})
    return Command(goto="respond", update={"messages": [response]})
```

### Enhancing Tool Selection with Rich Docstrings

The LLM's tool selection is only as good as its understanding of each tool. Write docstrings that include:

```python
@tool
async def search_cross_vertical(query: str) -> str:
    """Search for use cases and assets across ALL verticals, not just one.

    Use when:
    - The user doesn't specify a vertical
    - The user asks "has anyone built X?" without vertical context
    - A specific vertical search returned no results — try cross-vertical
    - Looking for reusable patterns (e.g., Customer 360 works across
      FinServ, Telco, and Retail)

    Returns matching use cases with their associated verticals, so the
    user can see which vertical's version best fits their need.

    Args:
        query: Free-text search term (e.g. "customer 360", "fraud ring")
    """
    async with driver.session() as session:
        result = await session.run(
            """
            MATCH (uc:UseCase)-[:TARGETS]->(v:Vertical)
            WHERE uc.title CONTAINS $query
               OR uc.description CONTAINS $query
               OR uc.topic CONTAINS $query
            OPTIONAL MATCH (uc)-[:HAS_ASSET]->(a:Asset)
            RETURN uc.title AS title, uc.description AS description,
                   collect(DISTINCT v.name) AS verticals,
                   collect(DISTINCT a.url) AS assets
            ORDER BY uc.updatedAt DESC
            LIMIT 10
            """,
            query=query,
        )
        records = [r.data() async for r in result]
    if not records:
        return f"No cross-vertical results found for '{query}'."
    return "\n".join(
        f"- {r['title']} ({', '.join(r['verticals'])}): "
        f"{r['description']} (assets: {', '.join(r['assets'])})"
        for r in records
    )
```

## 4. Human-in-the-Loop

### The interrupt() Function

`interrupt()` pauses graph execution, returns data to the caller, and waits for a human response. **Requires a checkpointer.**

```python
from langgraph.types import interrupt
from langgraph.checkpoint.memory import InMemorySaver

async def approval_node(state: AgentState) -> dict:
    """Pause for human approval before taking an action."""
    last_message = state["messages"][-1]
    decision = interrupt({
        "question": "The agent wants to perform this action. Approve?",
        "proposed_action": last_message.content,
    })
    return {"messages": [AIMessage(content=f"Human decided: {decision}")]}

graph = builder.compile(checkpointer=InMemorySaver())
```

### Invoking and Resuming

```python
from langgraph.types import Command

config = {"configurable": {"thread_id": "slack-channel-C04ABC123"}}

# First invocation — runs until interrupt
result = graph.invoke(
    {"messages": [HumanMessage(content="Send a summary to #general")]},
    config=config,
)
# result contains __interrupt__ with the approval question

# Human approves in Slack — resume with their response
resumed = graph.invoke(
    Command(resume=True),
    config=config,
)
```

### Approval Before Tool Execution

Use `interrupt_before` to pause before a specific node runs — useful for approving tool calls before they execute.

```python
graph = builder.compile(
    checkpointer=InMemorySaver(),
    interrupt_before=["send_slack_message"],  # Pause before this node
)

config = {"configurable": {"thread_id": "thread-1"}}

# Runs up to (but not into) send_slack_message
result = graph.invoke(inputs, config=config)

# Inspect what the agent wants to send
pending_state = graph.get_state(config)
print(pending_state.next)  # ('send_slack_message',)

# Approve — resume execution
graph.invoke(None, config=config)
```

### Approval Workflow with Routing

Combine `interrupt()` with `Command` to route based on human decisions.

```python
from langgraph.types import Command, interrupt
from typing import Literal

async def human_review_node(
    state: AgentState,
) -> Command[Literal["execute", "revise", "cancel"]]:
    """Present gathered results for human review before responding."""
    decision = interrupt({
        "message": "I found the following information. What should I do?",
        "results": state["results"],
        "options": ["execute — send this response", "revise — search more", "cancel"],
    })

    if decision == "execute":
        return Command(goto="execute")
    elif decision == "revise":
        return Command(goto="revise", update={
            "research_loop_count": 0,  # Reset loop counter
            "is_sufficient": False,
        })
    return Command(goto="cancel")
```

### Validation Loop

Keep interrupting until the human provides valid input.

```python
async def get_vertical_node(state: AgentState) -> dict:
    """Ask the human to specify a vertical if the query is ambiguous."""
    valid_verticals = [
        "financial-services", "pharma", "telco", "retail", "cyber",
    ]
    prompt = (
        f"Which vertical? Options: {', '.join(valid_verticals)}"
    )
    while True:
        answer = interrupt(prompt)
        if answer in valid_verticals:
            break
        prompt = f"'{answer}' is not valid. Choose from: {', '.join(valid_verticals)}"
    return {"vertical": answer}
```

### Combining HITL with Sufficiency

The most powerful pattern: the agent gathers information, reflects on sufficiency, and if unsure, **asks the human** whether to keep searching or answer with what it has.

```python
async def human_sufficiency_check(
    state: ResearchState,
) -> Command[Literal["research", "respond"]]:
    """Let the human decide if gathered info is sufficient."""
    if state["research_loop_count"] < 2:
        # Don't bother human on first pass — let agent self-reflect
        if state["is_sufficient"]:
            return Command(goto="respond")
        return Command(goto="research")

    # After 2+ loops, ask the human
    decision = interrupt({
        "message": "I've searched multiple times. Here's what I found so far.",
        "results_count": len(state["results"]),
        "knowledge_gap": state["knowledge_gap"],
        "options": ["respond with what we have", "keep searching"],
    })

    if decision == "keep searching":
        return Command(goto="research")
    return Command(goto="respond")
```

## 5. Memory and Checkpointing

### Development — InMemorySaver

```python
from langgraph.checkpoint.memory import InMemorySaver

checkpointer = InMemorySaver()
graph = builder.compile(checkpointer=checkpointer)
```

### Local — SqliteSaver

```python
# pip install langgraph-checkpoint-sqlite
from langgraph.checkpoint.sqlite.aio import AsyncSqliteSaver

checkpointer = AsyncSqliteSaver.from_conn_string("checkpoints.db")
graph = builder.compile(checkpointer=checkpointer)
```

### Production — PostgresSaver

```python
# pip install langgraph-checkpoint-postgres
import os
from langgraph.checkpoint.postgres.aio import AsyncPostgresSaver

checkpointer = AsyncPostgresSaver.from_conn_string(
    os.environ["DATABASE_URL"]
)
await checkpointer.asetup()  # Creates checkpoint tables
graph = builder.compile(checkpointer=checkpointer)
```

### Thread-Based Conversations

Each `thread_id` maintains its own conversation state. Use this for per-channel or per-user conversations in Slack.

```python
# Slack channel thread — each channel gets its own memory
config_channel = {"configurable": {"thread_id": f"slack-{channel_id}"}}

# First message
await graph.ainvoke(
    {"messages": [HumanMessage(content="Do we have fraud use cases?")]},
    config=config_channel,
)

# Follow-up on same thread — agent remembers previous context
await graph.ainvoke(
    {"messages": [HumanMessage(content="What about for telco specifically?")]},
    config=config_channel,
)
```

### State History and Time Travel

```python
# Browse conversation history
history = []
async for state in graph.aget_state_history(config):
    history.append(state)

# Replay from a specific checkpoint
old_config = {
    "configurable": {
        "thread_id": "slack-C04ABC123",
        "checkpoint_id": history[3].config["configurable"]["checkpoint_id"],
    }
}
await graph.ainvoke(None, config=old_config)
```

## 6. Streaming

### Stream Modes

```python
# Full state after each node
async for state in graph.astream(inputs, config, stream_mode="values"):
    print(state["messages"][-1].content)

# Only the changes from each node
async for update in graph.astream(inputs, config, stream_mode="updates"):
    for node_name, node_output in update.items():
        print(f"{node_name}: {node_output}")

# Token-level streaming for chat UIs
async for event in graph.astream(inputs, config, stream_mode="messages"):
    message_chunk, metadata = event
    if metadata["langgraph_node"] == "agent":
        print(message_chunk.content, end="", flush=True)
```

### Streaming for Slack

Slack messages have a 3-second response window. Use streaming to send an initial acknowledgment, then update the message as tokens arrive.

```python
async def stream_to_slack(query: str, channel_id: str, slack_client):
    """Stream agent response to a Slack message, updating in place."""
    config = {"configurable": {"thread_id": f"slack-{channel_id}"}}
    inputs = {"messages": [HumanMessage(content=query)]}

    # Post initial "thinking" message
    response = await slack_client.chat_postMessage(
        channel=channel_id,
        text=":hourglass: Searching...",
    )
    ts = response["ts"]

    collected = []
    async for event in graph.astream(inputs, config, stream_mode="messages"):
        chunk, metadata = event
        if metadata["langgraph_node"] == "respond" and chunk.content:
            collected.append(chunk.content)
            # Update message periodically (avoid rate limits)
            if len(collected) % 20 == 0:
                await slack_client.chat_update(
                    channel=channel_id,
                    ts=ts,
                    text="".join(collected),
                )

    # Final update with complete response
    await slack_client.chat_update(
        channel=channel_id,
        ts=ts,
        text="".join(collected),
    )
```

### Multiple Stream Modes

```python
async for event in graph.astream(
    inputs,
    config,
    stream_mode=["values", "updates"],
):
    mode, data = event
    if mode == "updates":
        print(f"Node update: {data}")
    elif mode == "values":
        print(f"Full state: {data}")
```

## 7. Sub-graphs

### Shared State Keys

When parent and child graphs share state keys (like `messages`), pass the compiled subgraph directly as a node.

```python
# Research subgraph — handles multi-step Neo4j lookups
research_builder = StateGraph(AgentState)
research_builder.add_node("search", search_node)
research_builder.add_node("tools", ToolNode(neo4j_tools))
research_builder.add_edge(START, "search")
research_builder.add_conditional_edges("search", should_continue)
research_builder.add_edge("tools", "search")
research_subgraph = research_builder.compile()

# Parent graph — orchestrates subgraphs
parent_builder = StateGraph(AgentState)
parent_builder.add_node("router", router_node)
parent_builder.add_node("research", research_subgraph)  # Subgraph as node
parent_builder.add_node("respond", respond_node)
parent_builder.add_edge(START, "router")
parent_builder.add_conditional_edges("router", route_query)
parent_builder.add_edge("research", "respond")
parent_builder.add_edge("respond", END)
```

### Different State Schemas

When a subgraph needs private state, wrap it in a transformation function.

```python
class ResearchSubState(TypedDict):
    """Private state for the research subgraph."""
    research_messages: Annotated[list[BaseMessage], operator.add]
    sources: Annotated[list[str], operator.add]

research_builder = StateGraph(ResearchSubState)
# ... build subgraph with its own state ...
research_subgraph = research_builder.compile()

async def research_wrapper(state: AgentState) -> dict:
    """Transform parent state -> subgraph state -> parent state."""
    sub_result = await research_subgraph.ainvoke({
        "research_messages": state["messages"][-3:],  # Only recent context
        "sources": [],
    })
    return {
        "messages": sub_result["research_messages"],
        "results": [{"sources": sub_result["sources"]}],
    }

parent_builder.add_node("research", research_wrapper)
```

### When to Use Sub-graphs

- **Specialized agents**: Each subgraph owns a domain (Neo4j lookup, web search, content generation)
- **State isolation**: Keep research scratchpad separate from main conversation
- **Reusability**: Same research subgraph used across different parent workflows
- **Independent checkpointing**: Each subgraph can have its own persistence:

```python
research_subgraph = research_builder.compile(checkpointer=True)
```

## 8. Prebuilt Agents

### create_react_agent

For simple tool-calling agents that don't need custom routing or reflection, use the prebuilt ReAct agent.

```python
from langgraph.prebuilt import create_react_agent
from langchain_anthropic import ChatAnthropic

model = ChatAnthropic(model="claude-sonnet-4-20250514")

agent = create_react_agent(
    model,
    tools=[search_use_cases, search_reference_customers, get_newest_content],
    prompt="You are a knowledge assistant for Neo4j's Industries team.",
)

result = await agent.ainvoke({
    "messages": [HumanMessage(content="What fraud use cases do we have?")],
})
```

### When to Use Prebuilt vs Custom

| Use prebuilt when            | Use custom StateGraph when            |
| ---------------------------- | ------------------------------------- |
| Simple tool-calling loop     | Need reflection / sufficiency checks  |
| Single agent, no routing     | Multi-agent or multi-tool routing     |
| No human-in-the-loop         | Need interrupt() or approval flows    |
| Prototype / proof of concept | Production with streaming, sub-graphs |

### Adding Memory to Prebuilt

```python
from langgraph.checkpoint.memory import InMemorySaver

agent = create_react_agent(
    model,
    tools=tools,
    prompt="You are a knowledge assistant.",
    checkpointer=InMemorySaver(),
)

config = {"configurable": {"thread_id": "slack-C04ABC123"}}
await agent.ainvoke(
    {"messages": [HumanMessage(content="Find telco use cases")]},
    config=config,
)
```

## Anti-Patterns

| Anti-Pattern                                      | Why It Fails                                                                                                              | Fix                                                                                                            |
| ------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| Routing logic in edge functions instead of nodes  | Edge functions can't invoke LLMs, access async resources, or update state — they only read state and return a string      | Use `Command(goto=)` inside nodes for complex routing; reserve edge functions for simple state-field checks    |
| No max iteration on research loops                | Agent loops indefinitely gathering marginally useful information, wasting tokens and time                                 | Add `research_loop_count` and `max_research_loops` to state; cap at 3-5 iterations in `route_after_reflection` |
| Missing checkpointer with interrupt()             | `interrupt()` raises an error because there's no persistence to save/restore execution state                              | Always `compile(checkpointer=...)` when using any HITL pattern                                                 |
| Giant monolithic state shared across all nodes    | Every node processes irrelevant fields; state grows unwieldy; refactoring one node risks breaking others                  | Split into focused sub-graphs with private state; share only `messages` at the parent level                    |
| Vague tool docstrings                             | LLM can't distinguish between similar tools (e.g., `search_use_cases` vs `search_cross_vertical`) and picks the wrong one | Include "Use when..." conditions, example inputs, and expected output format in every docstring                |
| Synchronous Neo4j driver in async graph           | `driver.session()` blocks the event loop, killing throughput for concurrent requests                                      | Use `AsyncGraphDatabase.driver()` and `async with driver.session()` with `await session.run()`                 |
| Skipping reflection/sufficiency check             | Agent answers with partial info after one tool call, or loops too many times without evaluating what it has               | Add explicit reflection node between research and response; evaluate completeness before answering             |
| Storing formatted responses in state              | Wastes tokens carrying rendered text through subsequent nodes; can't reformat for different channels (Slack vs email)     | Store raw data (dicts/lists) in state; format only in the final response node                                  |
| Hardcoding thread_id                              | All conversations share the same memory; messages from different users/channels bleed together                            | Derive `thread_id` from the source: Slack channel ID, user ID, or conversation-specific identifier             |
| Using interrupt_before for complex approval flows | `interrupt_before` only pauses — it can't pass context to the human or route based on their response                      | Use `interrupt()` inside a node with `Command(goto=)` for approval workflows that need context and routing     |
